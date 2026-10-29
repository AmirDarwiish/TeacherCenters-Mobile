import 'dart:async';
import 'dart:convert';

import 'live.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef Json = Map<String, dynamic>;
Json obj(dynamic x) => x is Map ? Map<String, dynamic>.from(x) : {};
List<Json> rows(dynamic x) {
  final v = x is List ? x : obj(x)['items'];
  return v is List ? v.map(obj).toList() : [];
}

String label(Json x) =>
    '${x['title'] ?? x['fullName'] ?? x['name'] ?? x['subject'] ?? x['code'] ?? ''}';

class ApiFailure implements Exception {
  ApiFailure(this.message, {this.status, this.code, this.retryAfter});
  final String message;
  final int? status;
  final String? code;
  final int? retryAfter;
  @override
  String toString() => message;
}

abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'teachercenters.session.v1');
  @override
  Future<void> write(String value) =>
      _storage.write(key: 'teachercenters.session.v1', value: value);
  @override
  Future<void> clear() => _storage.delete(key: 'teachercenters.session.v1');
}

class Api extends ChangeNotifier {
  Api({Dio? client, SessionStore? storage})
    : http =
          client ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'https://teachercenter.runasp.net/api/v1',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(minutes: 2),
            ),
          ),
      store = storage ?? SecureSessionStore();
  late final LiveUpdates live = LiveUpdates(this);
  final Dio http;
  final SessionStore store;
  Json? session;
  String slug = const String.fromEnvironment('TENANT_SLUG');
  Future<void>? _refreshing;
  int _generation = 0;
  Future<void> _storageTail = Future<void>.value();
  Future<void> _storeInOrder(Future<void> Function() work) {
    final next = _storageTail.then((_) => work());
    _storageTail = next.catchError((Object _) {});
    return next;
  }

  bool get signedIn => session != null;
  Json get profile => obj(session?['profile']);
  String get role => '${profile['role'] ?? ''}';
  bool get guardian => role == 'Guardian';
  bool get student => role == 'Student' || guardian;
  String? portalStudentId;
  bool can(String module, String operation) =>
      role == 'Owner' ||
      (profile['permissions'] as List? ?? []).contains('$module.$operation');
  String get actorId => '${profile['id'] ?? ''}';
  String get authPath => '/t/${Uri.encodeComponent(slug)}/auth';
  String get token => '${session?['accessToken'] ?? ''}';

  Future<void> restore() async {
    final raw = await store.read();
    if (raw == null) return;
    try {
      final saved = obj(jsonDecode(raw));
      if ((saved['slug'] as String? ?? '').isEmpty) {
        throw const FormatException();
      }
      slug = saved['slug'];
      session = obj(saved['session']);
      portalStudentId = saved['portalStudentId'] as String?;
      await refresh();
    } on ApiFailure catch (e) {
      if (e.status == 401 || e.status == 403) {
        await clear();
      } else {
        rethrow;
      }
    } on FormatException {
      await clear();
    }
  }

  Future<void> accept(Json data) async {
    final p = obj(data['profile']);
    if (data['accessToken'] == null ||
        !['Student', 'Guardian', 'Teacher', 'Owner'].contains(p['role'])) {
      throw ApiFailure('نوع الحساب غير مدعوم.');
    }
    final epoch = _generation;
    await _storeInOrder(() async {
      if (epoch != _generation) return;
      await store.write(
        jsonEncode({
          'slug': slug,
          'session': data,
          'portalStudentId': portalStudentId,
        }),
      );
      if (epoch == _generation) session = data;
    });
    if (epoch == _generation) notifyListeners();
  }

  /// Persist only a child returned by /portal/me. The server still authorizes every request.
  Future<void> selectPortalStudent(String id) async {
    final epoch = _generation;
    await _storeInOrder(() async {
      if (epoch != _generation || !signedIn) return;
      await store.write(
        jsonEncode({'slug': slug, 'session': session, 'portalStudentId': id}),
      );
      if (epoch == _generation && signedIn) portalStudentId = id;
    });
  }

  Future<void> clear() async {
    _generation++;
    await live.stop(clear: true);
    session = null;
    portalStudentId = null;
    notifyListeners();
    await _storeInOrder(store.clear);
  }

  Future<void> logout() async {
    try {
      await call(
        'POST',
        '/auth/logout',
        data: {'refreshToken': session?['refreshToken']},
      );
    } finally {
      await clear();
    }
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    final epoch = _generation;
    final refreshToken = session?['refreshToken'];
    if (refreshToken == null) {
      return Future.error(ApiFailure('سجل الدخول مرة أخرى.', status: 401));
    }
    final future = () async {
      try {
        final result = await call(
          'POST',
          '$authPath/refresh',
          auth: false,
          data: {'refreshToken': refreshToken},
        );
        if (_generation == epoch) await accept(obj(result));
      } on ApiFailure catch (e) {
        if ((e.status == 401 || e.status == 403) && _generation == epoch) {
          await clear();
        }
        rethrow;
      }
    }();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<dynamic> get(String path, {Json? query}) => call(
    'GET',
    path,
    query: {
      if (guardian && portalStudentId != null && path.startsWith('/portal/'))
        'studentId': portalStudentId,
      ...?query,
    },
  );
  Future<dynamic> call(
    String method,
    String path, {
    dynamic data,
    Json? query,
    bool auth = true,
    bool retry = true,
    Json? headers,
  }) async {
    final epoch = _generation;
    try {
      final response = await http.request(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            ...?headers,
            if (auth && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (auth &&
          retry &&
          e.response?.statusCode == 401 &&
          session != null &&
          epoch == _generation) {
        await refresh();
        if (session == null || epoch != _generation) {
          throw ApiFailure('انتهت الجلسة. سجل الدخول.', status: 401);
        }
        return call(
          method,
          path,
          data: data is FormData ? data.clone() : data,
          query: query,
          auth: auth,
          retry: false,
          headers: headers,
        );
      }
      final body = obj(e.response?.data);
      final errors = obj(
        body['errors'],
      ).values.expand((v) => v is List ? v : [v]).join('\n');
      throw ApiFailure(
        errors.isNotEmpty
            ? errors
            : '${body['message'] ?? body['detail'] ?? body['title'] ?? (e.response == null ? 'تعذر الاتصال. تحقق من الإنترنت وحاول مرة أخرى.' : 'تعذر تنفيذ الطلب (${e.response?.statusCode}).')}',
        status: e.response?.statusCode,
        code: body['code']?.toString(),
        retryAfter: int.tryParse(
          e.response?.headers.value('retry-after') ?? '',
        ),
      );
    }
  }

  Uri resolveUrl(String value) =>
      Uri.parse(http.options.baseUrl).resolve(value);
}
