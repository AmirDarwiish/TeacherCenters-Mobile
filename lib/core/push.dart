import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';

enum PushPermission { allowed, denied, unknown }

class ChatPushTarget {
  const ChatPushTarget(this.tenantId, this.recipientId, this.conversationId);
  final String tenantId, recipientId, conversationId;
  static ChatPushTarget? parse(Map<String, dynamic> data) {
    final guid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final tenant = '${data['tenantId'] ?? ''}',
        recipient = '${data['recipientId'] ?? ''}',
        room = '${data['conversationId'] ?? ''}';
    if (data['type'] != 'chat.message' ||
        ![tenant, recipient, room].every(guid.hasMatch)) {
      return null;
    }
    return ChatPushTarget(
      tenant.toLowerCase(),
      recipient.toLowerCase(),
      room.toLowerCase(),
    );
  }

  bool matches(Api api) =>
      api.signedIn &&
      recipientId == api.actorId.toLowerCase() &&
      tenantId == pushTenant(api);
}

String pushTenant(Api api) {
  try {
    final parts = api.token.split('.');
    if (parts.length != 3) return '';
    // Only a routing guard. The API still verifies the JWT and room membership.
    final claims = obj(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))),
    );
    return '${claims['tenant_id'] ?? ''}'.toLowerCase();
  } catch (_) {
    return '';
  }
}

abstract class PushTransport {
  Future<bool> initialize();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get refreshedTokens;
  Stream<Map<String, dynamic>> get opened;
  Stream<Map<String, dynamic>> get foreground;
  Future<Map<String, dynamic>?> initial();
  String get platform;
}

class FirebasePushTransport implements PushTransport {
  FirebaseMessaging get messaging => FirebaseMessaging.instance;
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Future<bool> initialize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform) ||
        !const bool.fromEnvironment('PUSH_ENABLED')) {
      return false;
    }
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const sender = String.fromEnvironment('FIREBASE_SENDER_ID');
    final appId = ios
        ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
        : const String.fromEnvironment('FIREBASE_APP_ID');
    if ([apiKey, project, sender, appId].any((v) => v.isEmpty)) return false;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: sender,
        projectId: project,
        iosBundleId: ios ? 'com.zeiia.teacherCentersMobile' : null,
      ),
    );
    // Foreground uses an in-app banner, preventing duplicate alerts on iOS.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    return true;
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermission.allowed,
      AuthorizationStatus.denied => PushPermission.denied,
      _ => PushPermission.unknown,
    };
  }

  @override
  Future<String?> token() async {
    if (platform == 'ios' && await messaging.getAPNSToken() == null) {
      return null;
    }
    return messaging.getToken();
  }

  @override
  Future<void> deleteToken() => messaging.deleteToken();
  @override
  Stream<String> get refreshedTokens => messaging.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
  @override
  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((m) => m.data);
  @override
  Future<Map<String, dynamic>?> initial() async =>
      (await messaging.getInitialMessage())?.data;
}

class ChatPushCoordinator {
  ChatPushCoordinator(
    this.api,
    this.transport, {
    required this.open,
    required this.banner,
  });
  final Api api;
  final PushTransport transport;
  final Future<void> Function(ChatPushTarget) open;
  final void Function(ChatPushTarget) banner;
  final List<StreamSubscription<dynamic>> subscriptions = [];
  ChatPushTarget? pending;
  String? registeredToken, registeredIdentity;
  bool ready = false, disposed = false, working = false, again = false;
  String get identity =>
      api.signedIn ? '${pushTenant(api)}:${api.actorId}:${api.role}' : '';
  Future<void> start() async {
    api.addListener(authChanged);
    api.enablePush = enable;
    api.beforeLogout = detach;
    try {
      ready = await transport.initialize();
      if (disposed) return;
      api.pushAvailable = ready;
      if (!ready) {
        status('إشعارات الجهاز غير مفعّلة في هذه النسخة');
        return;
      }
      subscriptions.add(transport.opened.listen(receive));
      subscriptions.add(
        transport.foreground.listen((data) {
          final target = ChatPushTarget.parse(data);
          if (target != null && target.matches(api)) {
            api.live.emit('ChatChanged');
            banner(target);
          }
        }),
      );
      subscriptions.add(transport.refreshedTokens.listen((_) => sync()));
      final initial = await transport.initial();
      if (initial != null) receive(initial);
      await sync();
    } catch (_) {
      status('تعذر تجهيز إشعارات الجهاز؛ يمكنك إعادة المحاولة');
    }
  }

  void status(String text) {
    if (disposed || api.pushStatus == text) return;
    api.pushStatus = text;
    api.notifyPushChanged();
  }

  void authChanged() {
    if (identity != registeredIdentity) unawaited(sync());
    if (api.signedIn && pending != null) unawaited(flush());
  }

  void receive(Map<String, dynamic> data) {
    final target = ChatPushTarget.parse(data);
    if (target == null || disposed) return;
    pending = target;
    unawaited(flush());
  }

  Future<void> flush() async {
    if (!api.signedIn || pending == null) return;
    final target = pending!;
    pending = null;
    // Never switch accounts or tenants as a side effect of tapping a push.
    if (target.matches(api)) await open(target);
  }

  Future<void> enable() async {
    if (!ready || !api.signedIn) return;
    try {
      final permission = await transport.permission(request: true);
      if (permission != PushPermission.allowed) {
        status('الإشعارات مقفولة؛ فعّلها من إعدادات الجهاز');
        return;
      }
      await sync();
    } catch (_) {
      status('تعذر تفعيل الإشعارات؛ حاول مرة أخرى');
    }
  }

  Future<void> sync() async {
    if (disposed || !ready) return;
    if (working) {
      again = true;
      return;
    }
    working = true;
    try {
      do {
        again = false;
        final expected = identity;
        if (expected.isEmpty) {
          registeredIdentity = null;
          registeredToken = null;
          try {
            await transport.deleteToken();
          } catch (_) {
            /* Server session revocation remains authoritative. */
          }
          continue;
        }
        final permission = await transport.permission();
        if (disposed || expected != identity) {
          again = true;
          continue;
        }
        if (permission != PushPermission.allowed) {
          registeredIdentity = expected;
          status(
            permission == PushPermission.denied
                ? 'الإشعارات مقفولة؛ فعّلها من إعدادات الجهاز'
                : 'فعّل إشعارات الشات عشان توصلك الرسائل والتطبيق مقفول',
          );
          continue;
        }
        final token = await transport.token();
        if (disposed || expected != identity) {
          again = true;
          continue;
        }
        if (token == null) {
          status('في انتظار تسجيل الجهاز للإشعارات');
          continue;
        }
        await api.call(
          'POST',
          '/devices',
          data: {'token': token, 'platform': transport.platform},
          retry: false,
        );
        if (disposed || expected != identity) {
          again = true;
          continue;
        }
        registeredIdentity = expected;
        registeredToken = token;
        status('إشعارات الشات مفعّلة');
      } while (again && !disposed);
    } catch (_) {
      status('تعذر ربط إشعارات الجهاز؛ اضغط لإعادة المحاولة');
    } finally {
      working = false;
    }
  }

  Future<void> detach() async {
    pending = null;
    final token = registeredToken;
    registeredToken = null;
    registeredIdentity = null;
    if (token != null && api.signedIn) {
      try {
        await api
            .call('DELETE', '/devices', data: {'token': token}, retry: false)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Logout also revokes the server session. */
      }
    }
    try {
      if (ready) {
        await transport.deleteToken().timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    disposed = true;
    api.removeListener(authChanged);
    api.enablePush = null;
    api.beforeLogout = null;
    for (final sub in subscriptions) {
      await sub.cancel();
    }
  }
}
