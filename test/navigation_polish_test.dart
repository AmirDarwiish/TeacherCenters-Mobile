import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/features/community.dart';
import 'package:teacher_centers_mobile/features/courses.dart';
import 'api_test.dart' show response;
import 'reels_test.dart' show apiWith;
import 'course_experience_test.dart'
    show host, course, loadTestFonts, screenshot;

void main() {
  setUpAll(loadTestFonts);
  testWidgets(
    'messages opened from another page have a visible working back button',
    (tester) async {
      final api = await apiWith((_) async => response(200, []));
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => ThreadsPage(api: api)),
                ),
                child: const Text('افتح الرسائل'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح الرسائل'));
      await tester.pumpAndSettle();
      expect(find.text('الرسائل'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('افتح الرسائل'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final teacher in [false, true]) {
    testWidgets(
      'course search and filters scroll away with content (teacher: $teacher)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = await apiWith(
          (_) async =>
              response(200, List.generate(20, (i) => {...course, 'id': '$i'})),
        );
        if (teacher) api.profile['role'] = 'Teacher';
        await tester.pumpWidget(host(Scaffold(body: CoursesPage(api: api))));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(TextField)).bottom, lessThan(220));
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        if (!teacher) await screenshot(tester, 'courses-scrolled');
        await tester.drag(find.byType(ListView).first, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
        if (!teacher) await screenshot(tester, 'courses-compact');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
