import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/push.dart';
import 'features/scoped_chat.dart';
import 'core/app_viewport.dart';
import 'core/design.dart';
import 'core/brand_logo.dart';
import 'features/login.dart';
import 'features/shell.dart';
import 'features/guardian.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TeacherCentersApp(api: Api()));
}

class TeacherCentersApp extends StatefulWidget {
  const TeacherCentersApp({super.key, required this.api});
  final Api api;
  @override
  State<TeacherCentersApp> createState() => _TeacherCentersAppState();
}

class _TeacherCentersAppState extends State<TeacherCentersApp>
    with WidgetsBindingObserver {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final ChatPushCoordinator push;
  ChatPushTarget? pendingPush;
  bool openingPush = false;
  ThemeMode mode = ThemeMode.system;
  bool ready = false;
  Object? startupError;
  int sessionEpoch = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.addListener(changed);
    push = ChatPushCoordinator(
      widget.api,
      FirebasePushTransport(),
      open: queuePush,
      banner: showPush,
    );
    push.start();
    restore();
  }

  void changed() {
    if (mounted) {
      setState(() {
        if (!widget.api.signedIn) {
          sessionEpoch++;
          pendingPush = null;
        }
      });
    }
  }

  void showPush(ChatPushTarget target) {
    if (!mounted ||
        !target.matches(widget.api) ||
        widget.api.visibleChatId == target.conversationId)
      return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('عندك رسالة جديدة على رواق'),
        action: SnackBarAction(
          label: 'فتح',
          onPressed: () => queuePush(target),
        ),
      ),
    );
  }

  Future<void> queuePush(ChatPushTarget target) async {
    pendingPush = target;
    WidgetsBinding.instance.addPostFrameCallback((_) => drainPush());
  }

  Future<void> drainPush() async {
    final target = pendingPush;
    if (!mounted ||
        !ready ||
        openingPush ||
        target == null ||
        navigatorKey.currentState == null)
      return;
    pendingPush = null;
    if (!target.matches(widget.api)) return;
    openingPush = true;
    try {
      final room = obj(
        await widget.api.get('/chat/conversations/${target.conversationId}'),
      );
      if (!mounted || !target.matches(widget.api)) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatConversationPage(api: widget.api, conversation: room),
        ),
      );
    } catch (_) {
      if (mounted && target.matches(widget.api)) {
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'المحادثة غير متاحة حاليًا. راجع تسجيل الطالب أو حاول من الرسائل.',
            ),
          ),
        );
      }
    } finally {
      openingPush = false;
      if (pendingPush != null)
        WidgetsBinding.instance.addPostFrameCallback((_) => drainPush());
    }
  }

  Future<void> restore() async {
    try {
      await widget.api.restore();
      startupError = null;
    } catch (e) {
      startupError = e;
    } finally {
      if (mounted) {
        setState(() => ready = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => drainPush());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) push.sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.api.removeListener(changed);
    push.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: messengerKey,
    title: 'رواق',
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: mode,
    builder: (context, child) =>
        AppViewport(child: child ?? const SizedBox.shrink()),
    // Replacing the keyed Navigator removes all private detail routes on logout.
    key: ValueKey(sessionEpoch),
    home: !ready
        ? const RewaqSplash()
        : startupError != null
        ? Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$startupError'),
                  FilledButton(
                    onPressed: restore,
                    child: const Text('إعادة الاتصال'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await widget.api.clear();
                      setState(() => startupError = null);
                    },
                    child: const Text('الدخول بحساب آخر'),
                  ),
                ],
              ),
            ),
          )
        : widget.api.signedIn
        ? widget.api.guardian
              ? GuardianPortal(
                  api: widget.api,
                  onTheme: () => setState(
                    () => mode = mode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                )
              : Shell(
                  api: widget.api,
                  onTheme: () => setState(
                    () => mode = mode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                )
        : LoginPage(api: widget.api),
  );
}

class RewaqSplash extends StatelessWidget {
  const RewaqSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BrandColors.night,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RewaqLogo(inverse: true, stacked: true, size: 240),
              const SizedBox(height: 24),
              Text(
                'إدارة دروسك كلها من مكان واحد',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BrandColors.onNavyMuted,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: BrandColors.gold,
                semanticsLabel: 'بنجهّز رواق',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
