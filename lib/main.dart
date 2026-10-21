import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'features/login.dart';
import 'features/shell.dart';

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

  ThemeData theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xff635bda),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      colorScheme: colors,
      brightness: brightness,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff6f7fb)
          : const Color(0xff11121b),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TeacherCenters',
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
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
        ? Shell(
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
