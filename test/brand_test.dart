import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/design.dart';
import 'package:teacher_centers_mobile/core/format.dart';
import 'package:teacher_centers_mobile/core/brand_logo.dart';

void main() {
  test('theme follows the Rewaq palette and typography', () {
    final light = appTheme(Brightness.light), dark = appTheme(Brightness.dark);
    expect(light.colorScheme.primary, const Color(0xff0b2540));
    expect(light.scaffoldBackgroundColor, const Color(0xfff4f8fc));
    expect(dark.colorScheme.primary, const Color(0xffc9a24a));
    expect(dark.colorScheme.surface, const Color(0xff0e1b2c));
    expect(light.textTheme.headlineSmall!.fontFamily, 'Alexandria');
    expect(light.textTheme.headlineSmall!.fontSize, 24);
    expect(light.textTheme.bodyMedium!.fontFamily, 'IBMPlexSansArabic');
    expect(light.textTheme.bodyMedium!.fontSize, 16);
    expect(light.appBarTheme.toolbarHeight, 48);
    expect(light.appBarTheme.titleTextStyle!.fontSize, 18);
    expect(light.extension<BrandColors>()!.accent, const Color(0xffc9a24a));
  });
  test('dark text and semantic button labels have readable contrast', () {
    final b = BrandColors.dark;
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    expect(contrast(b.ink, b.surface), greaterThanOrEqualTo(7));
    expect(contrast(b.muted, b.surface), greaterThanOrEqualTo(4.5));
    for (final background in [b.primary, b.success, b.warning, b.danger]) {
      expect(contrast(background, b.primaryInk), greaterThanOrEqualTo(4.5));
    }
    expect(b.surface.computeLuminance(), greaterThan(b.bg.computeLuminance()));
  });
  test(
    'display numbers and currency use Arabic digits; Cairo timezone observes DST',
    () {
      expect(arNumber(1000), '١٬٠٠٠');
      expect(money(1000.5), '١٬٠٠٠٫٥ ج.م');
      expect(cairoDate(DateTime.utc(2026, 10, 23, 12)).hour, 15);
      expect(cairoDate(DateTime.utc(2026, 12, 23, 12)).hour, 14);
    },
  );
  testWidgets(
    'reduced motion disables brand animations and logo renders at its native ratio',
    (tester) async {
      Duration? duration;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                duration = BrandMotion.duration(context, 400);
                return const Scaffold(body: Center(child: RewaqLogo()));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(duration, Duration.zero);
      final logo = tester.widget<Image>(find.byType(Image));
      expect(
        (logo.image as AssetImage).assetName,
        'assets/brand/rewaq-logo-horizontal-primary-1024.png',
      );
      expect(logo.matchTextDirection, isFalse);
      final size = tester.getSize(find.byType(Image));
      expect(size.width / size.height, closeTo(1024 / 546, .01));
      expect(size.width, greaterThanOrEqualTo(120));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dark theme uses original reverse artwork with a brand label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: const Scaffold(body: RewaqLogo()),
      ),
    );
    await tester.pumpAndSettle();
    final logo = tester.widget<Image>(find.byType(Image));
    expect(
      (logo.image as AssetImage).assetName,
      'assets/brand/rewaq-logo-horizontal-reverse-1024.png',
    );
    expect(find.bySemanticsLabel('رواق'), findsOneWidget);
    semantics.dispose();
  });
}
