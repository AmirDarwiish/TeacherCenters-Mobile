import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';

enum PushPermission { allowed, denied, unknown }

class PushSetupFailure implements Exception {
  const PushSetupFailure(this.message);
  final String message;
}

String pushFailureText(Object error) {
  if (error is PushSetupFailure) return error.message;
  final detail = error is FirebaseException
      ? '${error.code} ${error.message}'
      : '$error';
  if (detail.contains('MISSING_INSTANCEID_SERVICE')) {
    return 'خدمات Google Play غير متوفرة أو غير شغالة على الجهاز.';
  }
  if (detail.contains('SERVICE_NOT_AVAILABLE') ||
      detail.contains('network-request-failed')) {
    return 'تعذر الاتصال بخدمة الإشعارات. تحقق من الإنترنت وخدمات Google Play ثم أعد المحاولة.';
  }
  if (detail.contains('FIS_AUTH_ERROR') ||
      detail.contains('API_KEY_INVALID') ||
      detail.contains('app-not-authorized')) {
    return 'إعداد خدمة الإشعارات في التطبيق يحتاج مراجعة. تواصل مع دعم السنتر.';
  }
  return 'تعذر تسجيل الجهاز للإشعارات. اضغط لإعادة المحاولة.';
}

class ChatPushTarget {
  const ChatPushTarget(
    this.tenantId,
    this.recipientId,
    this.conversationId, {
    this.notificationId,
  });
  final String? notificationId;
  final String tenantId, recipientId, conversationId;
  static ChatPushTarget? parse(Map<String, dynamic> data) {
    final guid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final tenant = '${data['tenantId'] ?? ''}',
        recipient = '${data['recipientId'] ?? ''}',
        room = '${data['conversationId'] ?? ''}';
    if (data['type'] == 'notification') {
      final notice = '${data['notificationId'] ?? ''}';
      if (![tenant, recipient, notice].every(guid.hasMatch)) return null;
      return ChatPushTarget(
        tenant.toLowerCase(),
        recipient.toLowerCase(),
        '',
        notificationId: notice.toLowerCase(),
      );
    }
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

Json pushClaims(Api api) {
  try {
    final parts = api.token.split('.');
    if (parts.length != 3) return {};
    // Only a routing/lifecycle guard. The API still verifies the JWT.
    return obj(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))),
    );
  } catch (_) {
    return {};
  }
}

String pushTenant(Api api) =>
    '${pushClaims(api)['tenant_id'] ?? ''}'.toLowerCase();
String pushSession(Api api) => '${pushClaims(api)['session_id'] ?? ''}';

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
  static const channel = MethodChannel('rewaq/push_environment');
  Future<Map<String, dynamic>> environment() async {
    if (platform != 'android') return {};
    return Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('status') ?? {},
    );
  }

  Future<void> checkGoogleServices() async {
    final env = await environment();
    final code = env['googlePlayStatus'];
    if (code != null && code != 0) {
      throw PushSetupFailure(
        code == 2
            ? 'حدّث خدمات Google Play على الجهاز ثم أعد المحاولة.'
            : code == 3
            ? 'خدمات Google Play مقفولة على الجهاز. فعّلها ثم أعد المحاولة.'
            : 'خدمات Google Play غير متوفرة أو غير متوافقة على الجهاز. استخدم جهازًا أو إيميليتور يدعم Google Play.',
      );
    }
  }

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
    await checkGoogleServices();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: sender,
          projectId: project,
          storageBucket:
              const String.fromEnvironment('FIREBASE_STORAGE_BUCKET').isEmpty
              ? null
              : const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
          iosBundleId: ios ? 'com.zeiia.teacherCentersMobile' : null,
        ),
      );
    }
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
    await checkGoogleServices();
    if ((await environment())['chatChannelEnabled'] == false) {
      throw const PushSetupFailure(
        'تنبيهات الرسائل مقفولة من إعدادات الجهاز. فعّل قناة «رسائل رواق» ثم أعد المحاولة.',
      );
    }
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
  Completer<void>? inFlight;
  Timer? retryTimer;
  int retryAttempts = 0;
  bool attached = false, active = true;
  bool ready = false, disposed = false, working = false, again = false;
  String get identity => api.signedIn
      ? '${pushTenant(api)}:${api.actorId}:${api.role}:${pushSession(api)}'
      : '';
  Future<void> start() async {
    if (!attached) {
      api.addListener(authChanged);
      api.enablePush = enable;
      api.beforeLogout = detach;
      attached = true;
    }
    if (ready) {
      await sync();
      return;
    }
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
            api.live.emit('NotificationsChanged');
            if (target.notificationId == null) api.live.emit('ChatChanged');
            banner(target);
          }
        }),
      );
      subscriptions.add(transport.refreshedTokens.listen((_) => sync()));
      final initial = await transport.initial();
      if (initial != null) receive(initial);
      await sync();
    } catch (error) {
      api.pushAvailable = true;
      status(pushFailureText(error));
    }
  }

  void setActive(bool value) {
    active = value;
    if (!value) {
      retryTimer?.cancel();
    } else if (ready) {
      unawaited(sync());
    }
  }

  void scheduleRetry() {
    if (disposed || !active || !api.signedIn || retryAttempts >= 4) return;
    retryTimer?.cancel();
    final seconds = [3, 10, 30, 60][retryAttempts++];
    retryTimer = Timer(Duration(seconds: seconds), () => sync());
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
    if (!api.signedIn) return;
    retryAttempts = 0;
    if (!ready) await start();
    if (!ready) return;
    try {
      final permission = await transport.permission(request: true);
      if (permission != PushPermission.allowed) {
        status('الإشعارات مقفولة؛ فعّلها من إعدادات الجهاز');
        return;
      }
      await sync();
    } catch (error) {
      status(pushFailureText(error));
    }
  }

  Future<void> sync() async {
    if (disposed || !ready) return;
    if (working) {
      again = true;
      await inFlight?.future;
      return;
    }
    final operation = Completer<void>();
    inFlight = operation;
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
          scheduleRetry();
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
        retryAttempts = 0;
        retryTimer?.cancel();
        status('الجهاز متسجّل لإشعارات الشات');
      } while (again && !disposed);
    } catch (error) {
      status(pushFailureText(error));
      scheduleRetry();
    } finally {
      working = false;
      operation.complete();
    }
  }

  Future<void> detach() async {
    retryTimer?.cancel();
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
    retryTimer?.cancel();
    api.removeListener(authChanged);
    api.enablePush = null;
    api.beforeLogout = null;
    for (final sub in subscriptions) {
      await sub.cancel();
    }
  }
}
