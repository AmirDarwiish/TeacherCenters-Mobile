import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/design.dart';
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

class _TeacherCentersAppState extends State<TeacherCentersApp> {
  ThemeMode mode = ThemeMode.system;
  bool ready = false;
  Object? startupError;
  int sessionEpoch = 0;
  @override
  void initState() {
    super.initState();
    widget.api.addListener(changed);
    restore();
  }

  void changed() {
    if (mounted) {
      setState(() {
        if (!widget.api.signedIn) sessionEpoch++;
      });
    }
  }

  Future<void> restore() async {
    try {
      await widget.api.restore();
      startupError = null;
    } catch (e) {
      startupError = e;
    } finally {
      if (mounted) setState(() => ready = true);
    }
  }

  @override
  void dispose() {
    widget.api.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'سنترك',
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: mode,
    // Replacing the keyed Navigator removes all private detail routes on logout.
    key: ValueKey(sessionEpoch),
    home: !ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
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
