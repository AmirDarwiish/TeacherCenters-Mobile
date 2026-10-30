import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'brand.dart';
import 'app_icons.dart';
export 'brand.dart';

ThemeData appTheme(Brightness brightness) {
  final b = brightness == Brightness.dark
      ? BrandColors.dark
      : BrandColors.light;
  final colors = ColorScheme(
    brightness: brightness,
    primary: b.primary,
    onPrimary: b.primaryInk,
    primaryContainer: b.primaryTint,
    onPrimaryContainer: b.ink,
    secondary: b.accentText,
    onSecondary: brightness == Brightness.dark
        ? BrandColors.night
        : BrandColors.white,
    secondaryContainer: b.accentTint,
    onSecondaryContainer: b.accentText,
    tertiary: b.success,
    onTertiary: b.primaryInk,
    tertiaryContainer: b.successTint,
    onTertiaryContainer: b.success,
    error: b.danger,
    onError: b.primaryInk,
    errorContainer: b.dangerTint,
    onErrorContainer: b.danger,
    surface: b.surface,
    onSurface: b.ink,
    onSurfaceVariant: b.muted,
    outline: b.line,
    outlineVariant: b.line,
    shadow: BrandColors.night,
    scrim: b.overlay,
    surfaceTint: b.surface,
    surfaceContainerLowest: b.bg,
    surfaceContainerLow: b.bg,
    surfaceContainer: b.surface,
    surfaceContainerHigh: b.primaryTint,
    surfaceContainerHighest: b.skeleton,
  );
  const heading = TextStyle(
    fontFamily: 'Alexandria',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.25,
  );
  const section = TextStyle(
    fontFamily: 'Alexandria',
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.25,
  );
  const body = TextStyle(
    fontFamily: 'IBMPlexSansArabic',
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.6,
  );
  const small = TextStyle(
    fontFamily: 'IBMPlexSansArabic',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.6,
  );
  const hint = TextStyle(
    fontFamily: 'IBMPlexSansArabic',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.6,
  );
  final text = TextTheme(
    displayLarge: heading,
    displayMedium: heading,
    displaySmall: heading,
    headlineLarge: heading,
    headlineMedium: heading,
    headlineSmall: heading,
    titleLarge: section,
    titleMedium: section,
    titleSmall: small.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: hint,
    labelLarge: small,
    labelMedium: hint,
    labelSmall: hint,
  ).apply(bodyColor: b.ink, displayColor: b.ink);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: b.line),
  );
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    textStyle: const WidgetStatePropertyAll(small),
    animationDuration: const Duration(milliseconds: 150),
    mouseCursor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
    ),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    extensions: [b],
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => const Icon(AppIcons.arrowBackRounded),
      closeButtonIconBuilder: (_) => const Icon(AppIcons.close),
      drawerButtonIconBuilder: (_) => const Icon(AppIcons.menu),
      endDrawerButtonIconBuilder: (_) => const Icon(AppIcons.menu),
    ),
    fontFamily: 'IBMPlexSansArabic',
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: text,
    scaffoldBackgroundColor: b.bg,
    canvasColor: b.surface,
    disabledColor: b.muted.withValues(alpha: .55),
    iconTheme: IconThemeData(size: 20, color: b.muted),
    primaryIconTheme: IconThemeData(size: 20, color: b.primaryInk),
    dividerTheme: DividerThemeData(color: b.line, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: b.glass,
      foregroundColor: b.ink,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 48,
      titleSpacing: 16,
      titleTextStyle: section.copyWith(color: b.ink, fontSize: 18),
      iconTheme: IconThemeData(size: 20, color: b.muted),
    ),
    cardTheme: CardThemeData(
      color: b.surface,
      surfaceTintColor: b.surface,
      elevation: 1,
      shadowColor: BrandColors.night.withValues(alpha: .06),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: b.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b.surface,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: b.focus, width: 2),
      ),
      errorBorder: border.copyWith(borderSide: BorderSide(color: b.danger)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: b.danger, width: 2),
      ),
      disabledBorder: border,
      hintStyle: body.copyWith(
        color: brightness == Brightness.dark
            ? b.muted
            : b.muted.withValues(alpha: .7),
      ),
      errorStyle: hint.copyWith(color: b.danger),
      labelStyle: small.copyWith(color: b.muted),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: button.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? b.primary.withValues(alpha: .55)
              : s.contains(WidgetState.pressed)
              ? b.primaryHover
              : b.primary,
        ),
        foregroundColor: WidgetStatePropertyAll(b.primaryInk),
        elevation: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed) ? 2 : 0,
        ),
        shadowColor: WidgetStatePropertyAll(b.primary.withValues(alpha: .16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button.copyWith(
        foregroundColor: WidgetStatePropertyAll(b.ink),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.pressed) ? b.accent : b.line,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: button.copyWith(foregroundColor: WidgetStatePropertyAll(b.muted)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        iconSize: 20,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: b.primaryTint,
      selectedColor: b.primaryTint,
      labelStyle: hint.copyWith(color: b.primary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      selectedIcon: const Icon(AppIcons.check),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: b.primary,
      unselectedLabelColor: b.muted,
      labelStyle: small,
      unselectedLabelStyle: small,
      indicator: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: b.line,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: b.surface,
      barrierColor: b.overlay,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: b.surface,
      modalBarrierColor: b.overlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: b.ink,
      contentTextStyle: small.copyWith(color: b.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(textStyle: hint.copyWith(color: b.surface)),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
