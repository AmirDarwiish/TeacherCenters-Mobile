import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/features/teacher_notifications.dart';
import 'api_test.dart' show response;
import 'workspaces_test.dart' show workspaceApi;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

void main() {
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'guardian-only composer explains student privacy (dark $dark)',
      (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final api = await workspaceApi(
          'Teacher',
          (_) async => response(200, <dynamic>[]),
        );
        await t.pumpWidget(
          host(TeacherNotificationsPage(api: api), dark: dark),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('يوصل لمين؟'));
        await t.tap(find.text('الطلاب وأولياء الأمور'));
        await t.pumpAndSettle();
        await t.tap(find.text('أولياء الأمور فقط — خاص').last);
        await t.pumpAndSettle();
        expect(find.textContaining('الطالب مش هيوصله تنبيه'), findsOneWidget);
        await screenshot(
          t,
          dark ? 'teacher-notification-dark' : 'teacher-notification-light',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await api.live.stop(clear: true);
      },
    );
  }
}
