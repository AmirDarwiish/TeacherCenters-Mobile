import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/current_session_attendance.dart';
import 'package:teacher_centers_mobile/features/session_check_in.dart';
import 'package:teacher_centers_mobile/features/session_detail.dart';
import 'package:teacher_centers_mobile/features/shell.dart';
import 'package:teacher_centers_mobile/features/teaching.dart';
import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host;

void main() {
  Future<Api> makeApi({
    String role = 'Student',
    bool multiple = false,
    bool includeLive = true,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = FakeAdapter((r) async {
      final now = DateTime.now().toUtc();
      final live = {
        'id': 'live',
        'topic': 'الحصة الحالية',
        'startsAtUtc': now
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
        'durationMinutes': 90,
        'status': 'Open',
        'serverNowUtc': now.toIso8601String(),
      };
      if (r.path.endsWith('/portal/me')) {
        return response(200, {
          'students': [
            {'id': 'student-1'},
          ],
        });
      }
      if (r.path.endsWith('/overview')) {
        return response(200, {
          'nextSession': {
            'id': 'future',
            'topic': 'حصة جاية',
            'startsAtUtc': now.add(const Duration(hours: 2)).toIso8601String(),
            'durationMinutes': 60,
          },
        });
      }
      if (r.path.endsWith('/sessions')) {
        return response(200, [
          {
            'id': 'old',
            'topic': 'حصة قديمة',
            'startsAtUtc': now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'durationMinutes': 60,
          },
          {
            'id': 'future',
            'topic': 'حصة جاية',
            'startsAtUtc': now.add(const Duration(hours: 2)).toIso8601String(),
            'durationMinutes': 60,
          },
          if (includeLive) live,
          if (multiple) {...live, 'id': 'live-two', 'topic': 'حصة حالية تانية'},
        ]);
      }
      if (r.path.endsWith('/check-in')) {
        return response(200, {
          'enabled': false,
          'canSubmit': false,
          'reason': 'الحضور مقفول من الفرع',
        });
      }
      if (r.path.endsWith('/live')) return response(200, live);
      return response(200, []);
    });
    final api = Api(client: dio, storage: MemoryStore());
    final auth = session('token', 'refresh');
    auth['profile'] = {'id': 'student-1', 'role': role};
    await api.accept(auth);
    return api;
  }

  testWidgets(
    'quick attendance opens current lesson and does not request student QR',
    (tester) async {
      final api = await makeApi();
      await tester.pumpWidget(
        host(
          Scaffold(
            body: CurrentSessionAttendance(
              api: api,
              studentId: 'student-1',
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('سجّل حضوري للحصة الحالية'));
      await tester.pumpAndSettle();
      final page = tester.widget<SessionCheckInPage>(
        find.byType(SessionCheckInPage),
      );
      expect(page.sessionId, 'live');
      expect(page.studentId, 'student-1');
      expect(find.text('الحضور مقفول من الفرع'), findsOneWidget);
    },
  );
  testWidgets(
    'home card prefers live lesson over future overview and opens details',
    (tester) async {
      final api = await makeApi();
      await tester.pumpWidget(host(Scaffold(body: HomePage(api: api))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('الحصة الحالية'), 200);
      await tester.tap(find.text('الحصة الحالية'));
      await tester.pumpAndSettle();
      final page = tester.widget<StudentSessionPage>(
        find.byType(StudentSessionPage),
      );
      expect(page.session['id'], 'live');
      expect(page.studentId, 'student-1');
    },
  );
  testWidgets(
    'sessions display live first even when server returns old lessons ascending',
    (tester) async {
      final api = await makeApi();
      await tester.pumpWidget(host(Scaffold(body: SessionsPage(api: api))));
      await tester.pumpAndSettle();
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((w) => (w.title as Text).data)
          .toList();
      expect(titles.take(3), ['الحصة الحالية', 'حصة جاية', 'حصة قديمة']);
    },
  );
  testWidgets(
    'quick attendance explains no current lesson instead of opening an unrelated future one',
    (tester) async {
      final api = await makeApi(includeLive: false);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: CurrentSessionAttendance(
              api: api,
              studentId: 'student-1',
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('سجّل حضوري للحصة الحالية'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionCheckInPage), findsNothing);
      expect(find.textContaining('مفيش حصة مفتوح'), findsOneWidget);
    },
  );
  testWidgets(
    'overlapping current lessons require choosing the intended lesson',
    (tester) async {
      final api = await makeApi(multiple: true);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: CurrentSessionAttendance(
              api: api,
              studentId: 'student-1',
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('سجّل حضوري للحصة الحالية'));
      await tester.pumpAndSettle();
      expect(find.text('اختار الحصة اللي هتسجّل حضورها'), findsOneWidget);
      await tester.tap(find.text('حصة حالية تانية'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SessionCheckInPage>(find.byType(SessionCheckInPage))
            .sessionId,
        'live-two',
      );
    },
  );
  testWidgets('guardian home remains read-only for attendance', (tester) async {
    final api = await makeApi(role: 'Guardian');
    await tester.pumpWidget(host(Scaffold(body: HomePage(api: api))));
    await tester.pumpAndSettle();
    expect(find.byType(CurrentSessionAttendance), findsNothing);
  });
  testWidgets('staff sessions also prioritize current lessons', (tester) async {
    final api = await makeApi(role: 'Teacher');
    await tester.pumpWidget(host(Scaffold(body: SessionsPage(api: api))));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text).data)
          .take(3),
      ['الحصة الحالية', 'حصة جاية', 'حصة قديمة'],
    );
  });
}
