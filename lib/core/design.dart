import 'package:flutter/material.dart';

/// Shared visual language. Semantic colors keep contrast in both themes.
ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xff1d5bf0),
    brightness: brightness,
    primary: dark ? const Color(0xff9abaff) : const Color(0xff1d5bf0),
    surface: dark ? const Color(0xff102438) : Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Tajawal',
    colorScheme: colors,
    brightness: brightness,
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xff081827)
        : const Color(0xfff4f7fc),
    textTheme: base.textTheme.apply(
      bodyColor: dark ? const Color(0xffe6eef7) : const Color(0xff0b2540),
      displayColor: dark ? const Color(0xffe6eef7) : const Color(0xff0b2540),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xff081827) : const Color(0xfff4f7fc),
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: colors.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colors.outlineVariant.withValues(alpha: .5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: .5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
      indicatorColor: colors.primaryContainer,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
