import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/features/push_settings.dart';
import 'api_test.dart' show response;
import 'workspaces_test.dart' show workspaceApi;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

void main() {
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'push settings explain incomplete server configuration at phone width (dark $dark)',
      (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final api = await workspaceApi(
          'Student',
          (_) async => response(200, {
            'serverEnabled': true,
            'providerConfigured': false,
            'activeDevices': 0,
          }),
        );
        api.pushAvailable = true;
        api.pushStatus =
            'خدمات Google Play غير متوفرة أو غير متوافقة على الجهاز.';
        var retries = 0;
        api.enablePush = () async {
          retries++;
        };
        await t.pumpWidget(host(PushSettingsPage(api: api), dark: dark));
        await t.pumpAndSettle();
        expect(
          find.text('إعداد خدمة الإشعارات في السنتر غير مكتمل.'),
          findsOneWidget,
        );
        expect(find.textContaining('Google Play'), findsWidgets);
        await screenshot(
          t,
          dark ? 'push-settings-dark' : 'push-settings-light',
        );
        await t.tap(find.text('تفعيل أو إعادة المحاولة'));
        await t.pumpAndSettle();
        expect(retries, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await api.live.stop(clear: true);
      },
    );
  }
}
