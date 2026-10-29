import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/core/push.dart';
import 'api_test.dart' show FakeAdapter, MemoryStore, response;

const tenant = '11111111-1111-1111-1111-111111111111';
const actor = '22222222-2222-2222-2222-222222222222';
const room = '33333333-3333-3333-3333-333333333333';
Map<String, dynamic> notice({
  String recipient = actor,
  String center = tenant,
}) => {
  'type': 'chat.message',
  'tenantId': center,
  'recipientId': recipient,
  'conversationId': room,
};
Future<Api> signedApi(List<RequestOptions> requests) async {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
  client.httpClientAdapter = FakeAdapter((r) async {
    requests.add(r);
    return response(200, {});
  });
  final api = Api(client: client, storage: MemoryStore())..slug = 'demo';
  await api.accept({
    'accessToken':
        'header.${base64Url.encode(utf8.encode(jsonEncode({'tenant_id': tenant})))}.signature',
    'profile': {'id': actor, 'role': 'Student'},
  });
  return api;
}

class FakePush implements PushTransport {
  bool available = true;
  PushPermission allowed = PushPermission.unknown;
  int permissionRequests = 0, deletions = 0;
  String currentToken = 'fake-device-token-for-testing';
  Map<String, dynamic>? launch;
  final tokens = StreamController<String>.broadcast(sync: true);
  final taps = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final messages = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  String get platform => 'android';
  @override
  Future<bool> initialize() async => available;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) permissionRequests++;
    return allowed;
  }

  @override
  Future<String?> token() async => currentToken;
  @override
  Future<void> deleteToken() async {
    deletions++;
  }

  @override
  Stream<String> get refreshedTokens => tokens.stream;
  @override
  Stream<Map<String, dynamic>> get opened => taps.stream;
  @override
  Stream<Map<String, dynamic>> get foreground => messages.stream;
  @override
  Future<Map<String, dynamic>?> initial() async => launch;
  Future<void> close() async {
    await tokens.close();
    await taps.close();
    await messages.close();
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'refreshing the access session re-registers the same device for the new session',
    () async {
      final calls = <RequestOptions>[];
      final api = await signedApi(calls),
          native = FakePush()..allowed = PushPermission.allowed;
      final push = ChatPushCoordinator(
        api,
        native,
        open: (_) async {},
        banner: (_) {},
      );
      await push.start();
      expect(calls.length, 1);
      final fresh =
          'header.${base64Url.encode(utf8.encode(jsonEncode({'tenant_id': tenant, 'session_id': room})))}.signature';
      await api.accept({...api.session!, 'accessToken': fresh});
      await push.sync();
      expect(calls.length, greaterThanOrEqualTo(2));
      expect(calls.last.headers['Authorization'], 'Bearer $fresh');
      expect(calls.last.data['token'], native.currentToken);
      await push.dispose();
      await native.close();
    },
  );
  test(
    'routing accepts only valid chat IDs for the current account and tenant',
    () async {
      final api = await signedApi([]);
      expect(ChatPushTarget.parse(notice())!.matches(api), true);
      expect(
        ChatPushTarget.parse(notice(recipient: room))!.matches(api),
        false,
      );
      expect(ChatPushTarget.parse(notice(center: room))!.matches(api), false);
      expect(
        ChatPushTarget.parse({...notice(), 'conversationId': '../private'}),
        isNull,
      );
      expect(ChatPushTarget.parse({...notice(), 'type': 'url'}), isNull);
    },
  );
  test(
    'permission is requested only by explicit enable and denial never registers a token',
    () async {
      final calls = <RequestOptions>[];
      final api = await signedApi(calls), native = FakePush();
      final push = ChatPushCoordinator(
        api,
        native,
        open: (_) async {},
        banner: (_) {},
      );
      await push.start();
      expect(native.permissionRequests, 0);
      expect(calls, isEmpty);
      native.allowed = PushPermission.denied;
      await push.enable();
      expect(native.permissionRequests, 1);
      expect(calls, isEmpty);
      expect(api.pushStatus, contains('مقفولة'));
      await push.dispose();
      await native.close();
    },
  );
  test(
    'authorized token registers and refresh rebinds the new token',
    () async {
      final calls = <RequestOptions>[];
      final api = await signedApi(calls),
          native = FakePush()..allowed = PushPermission.allowed;
      final push = ChatPushCoordinator(
        api,
        native,
        open: (_) async {},
        banner: (_) {},
      );
      await push.start();
      expect(calls.single.path, '/devices');
      expect(calls.single.data['token'], native.currentToken);
      native.currentToken = 'rotated-device-token-for-testing';
      native.tokens.add(native.currentToken);
      await push.sync();
      expect(calls.last.data['token'], native.currentToken);
      await push.dispose();
      await native.close();
    },
  );
  test(
    'cold start and background taps route while wrong account and malformed pushes do nothing',
    () async {
      final api = await signedApi([]), native = FakePush()..launch = notice();
      final opened = <String>[];
      final push = ChatPushCoordinator(
        api,
        native,
        open: (t) async => opened.add(t.conversationId),
        banner: (_) {},
      );
      await push.start();
      await settle();
      expect(opened, [room]);
      native.taps.add(notice());
      await settle();
      expect(opened, [room, room]);
      native.taps.add(notice(recipient: room));
      native.taps.add({'type': 'chat.message'});
      await settle();
      expect(opened.length, 2);
      await push.dispose();
      await native.close();
    },
  );
  test(
    'foreground message hints refresh chat and show only the authorized generic banner',
    () async {
      final api = await signedApi([]), native = FakePush();
      final banners = <String>[];
      final push = ChatPushCoordinator(
        api,
        native,
        open: (_) async {},
        banner: (t) => banners.add(t.conversationId),
      );
      await push.start();
      native.messages.add(notice());
      native.messages.add(notice(center: room));
      expect(banners, [room]);
      await push.dispose();
      await native.close();
    },
  );
  test(
    'logout unregisters before revocation and deletes native token',
    () async {
      final calls = <RequestOptions>[];
      final api = await signedApi(calls),
          native = FakePush()..allowed = PushPermission.allowed;
      final push = ChatPushCoordinator(
        api,
        native,
        open: (_) async {},
        banner: (_) {},
      );
      await push.start();
      await api.logout();
      await settle();
      expect(
        calls.map((r) => r.method),
        containsAllInOrder(['POST', 'DELETE', 'POST']),
      );
      expect(calls[1].path, '/devices');
      expect(native.deletions, greaterThan(0));
      expect(api.signedIn, false);
      await push.dispose();
      await native.close();
    },
  );
  test(
    'a build without Firebase leaves normal login and chat usable',
    () async {
      final api = await signedApi([]), native = FakePush()..available = false;
      final push = ChatPushCoordinator(
        api,
        native,
        open: (_) async {},
        banner: (_) {},
      );
      await push.start();
      expect(api.signedIn, true);
      expect(api.pushAvailable, false);
      await push.dispose();
      await native.close();
    },
  );
}
