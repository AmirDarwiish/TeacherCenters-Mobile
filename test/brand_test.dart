import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/design.dart';
import 'package:teacher_centers_mobile/core/format.dart';
import 'package:teacher_centers_mobile/core/brand_logo.dart';

void main() {
  test(
    'theme uses exact supplied Sentrak palette and typography in both modes',
    () {
      final light = appTheme(Brightness.light),
          dark = appTheme(Brightness.dark);
      expect(light.colorScheme.primary, const Color(0xff1d5bf0));
      expect(light.scaffoldBackgroundColor, const Color(0xfff4f8fc));
      expect(dark.colorScheme.primary, const Color(0xff4c82f7));
      expect(dark.colorScheme.surface, const Color(0xff0e1b2c));
      expect(light.textTheme.headlineSmall!.fontFamily, 'Alexandria');
      expect(light.textTheme.headlineSmall!.fontSize, 24);
      expect(light.textTheme.bodyMedium!.fontFamily, 'IBM Plex Sans Arabic');
      expect(light.textTheme.bodyMedium!.fontSize, 16);
      expect(light.extension<BrandColors>()!.cyan, const Color(0xff13b5d6));
    },
  );
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
                return const Scaffold(body: Center(child: SentrakLogo()));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(duration, Duration.zero);
      final painter = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SentrakLogoPainter,
      );
      expect(tester.getSize(painter), const Size(40, 40));
      expect(tester.takeException(), isNull);
    },
  );
}
