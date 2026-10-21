import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';

class MemoryStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String input) async {
    value = input;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) => handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(int status, Object? data) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
Json session(String access, String refresh) => {
  'accessToken': access,
  'refreshToken': refresh,
  'profile': {'id': 'student-1', 'role': 'Student'},
  'tenant': {'slug': 'center-a'},
};
void main() {
  test(
    'concurrent 401 responses rotate refresh token once and replay with fresh access',
    () async {
      var refreshes = 0;
      final client = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      client.httpClientAdapter = FakeAdapter((o) async {
        if (o.path.endsWith('/refresh')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(o.headers.containsKey('Authorization'), false);
          expect(o.data['refreshToken'], 'old-refresh');
          return response(200, session('new-access', 'new-refresh'));
        }
        if (o.headers['Authorization'] == 'Bearer new-access') {
          return response(200, {'ok': true});
        }
        return response(401, {'message': 'expired'});
      });
      final store = MemoryStore();
      final api = Api(client: client, storage: store)..slug = 'center-a';
      await api.accept(session('old-access', 'old-refresh'));
      final results = await Future.wait([api.get('/one'), api.get('/two')]);
      expect(refreshes, 1);
      expect(results.every((r) => r['ok'] == true), true);
      expect(
        jsonDecode(store.value!)['session']['refreshToken'],
        'new-refresh',
      );
    },
  );
  test(
    'logout while refresh is pending cannot restore cleared session',
    () async {
      final gate = Completer<ResponseBody>();
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((_) => gate.future);
      final api = Api(client: client, storage: MemoryStore())..slug = 'a';
      await api.accept(session('old', 'refresh'));
      final pending = api.refresh();
      await Future<void>.delayed(Duration.zero);
      await api.clear();
      gate.complete(response(200, session('new', 'new-refresh')));
      await pending;
      expect(api.signedIn, false);
    },
  );
  test(
    'OTP request never receives stale bearer token and keeps challenge response',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((o) async {
        expect(o.headers.containsKey('Authorization'), false);
        return response(202, {
          'challengeId': 'challenge-1',
          'resendAfterSeconds': 60,
        });
      });
      final api = Api(client: client, storage: MemoryStore())
        ..slug = 'center-a';
      await api.accept(session('old', 'refresh'));
      final result = await api.call(
        'POST',
        '${api.authPath}/otp/request',
        auth: false,
        data: {'phone': '01012345678', 'purpose': 'student-login'},
      );
      expect(result['challengeId'], 'challenge-1');
    },
  );
  test('API preserves actionable business errors', () async {
    final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
    client.httpClientAdapter = FakeAdapter(
      (_) async =>
          response(409, {'code': 'session-closed', 'message': 'الحصة مغلقة'}),
    );
    final api = Api(client: client, storage: MemoryStore());
    await expectLater(
      api.get('/sessions'),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.code, 'code', 'session-closed')
            .having((e) => e.message, 'message', 'الحصة مغلقة'),
      ),
    );
  });
  test(
    'array and paginated lists share item decoding without losing records',
    () {
      expect(
        rows([
          {'id': 1},
        ]).single['id'],
        1,
      );
      expect(
        rows({
          'items': [
            {'id': 2},
          ],
          'totalCount': 1,
        }).single['id'],
        2,
      );
    },
  );
}
