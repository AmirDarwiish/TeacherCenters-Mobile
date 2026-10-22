import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/session_detail.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

void main() {
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'session details remain readable on narrow RTL screen (dark: $dark)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
        client.httpClientAdapter = FakeAdapter(
          (_) async => response(200, {
            'id': 'session-1',
            'topic': 'مراجعة قوانين نيوتن وتطبيقاتها العملية',
            'groupName': 'المجموعة الأولى للصف الثالث الثانوي',
            'subjectName': 'الفيزياء',
            'gradeName': 'الصف الثالث الثانوي',
            'startsAtUtc': '2026-10-22T16:00:00Z',
            'durationMinutes': 90,
            'teacherName': 'أحمد محمود',
            'branchName': 'فرع طنطا',
            'hallName': 'قاعة ٢',
            'branchAddress': 'شارع البحر، طنطا',
            'description': 'شرح القوانين مع تدريبات تطبيقية.',
            'notes': 'أحضر أدواتك وكراسة التدريبات.',
            'status': 'Upcoming',
            'verification': {'status': 'PendingReview'},
          }),
        );
        final api = Api(client: client, storage: MemoryStore());
        await api.accept(session('token', 'refresh'));
        await tester.pumpWidget(
          host(
            StudentSessionPage(
              api: api,
              studentId: 'student-1',
              session: {'id': 'session-1'},
            ),
            dark: dark,
            scale: 1.4,
          ),
        );
        await tester.pumpAndSettle();
        await screenshot(tester, 'session-overview-${dark ? 'dark' : 'light'}');
        await tester.scrollUntilVisible(
          find.text('طلب حضورك قيد المراجعة'),
          200,
        );
        expect(find.text('تسجيل حضوري بالموقع والصورة'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('أحضر أدواتك وكراسة التدريبات.'),
          200,
        );
        expect(find.text('شرح القوانين مع تدريبات تطبيقية.'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('لا توجد نتائج منشورة حتى الآن'),
          200,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
