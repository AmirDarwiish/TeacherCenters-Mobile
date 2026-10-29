import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/guardian.dart';
import 'package:teacher_centers_mobile/features/community.dart';
import 'package:teacher_centers_mobile/features/excuses.dart';
import 'package:teacher_centers_mobile/features/teacher_workspace.dart';
import 'package:teacher_centers_mobile/features/teaching.dart';
import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

const children = [
  {'id': 'a', 'fullName': 'أحمد محمد', 'grade': 'الثالث الإعدادي'},
  {'id': 'b', 'fullName': 'مريم محمد', 'grade': 'الأول الثانوي'},
];
Future<Api> workspaceApi(
  String role,
  Future<ResponseBody> Function(RequestOptions) handler, {
  MemoryStore? storage,
}) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = FakeAdapter(handler);
  final api = Api(client: dio, storage: storage ?? MemoryStore())
    ..slug = 'demo';
  final auth = session('token', 'refresh')
    ..['profile'] = {
      'id': role == 'Guardian' ? 'guardian' : 'teacher',
      'role': role,
    }
    ..['tenant'] = {'id': 'tenant-a', 'name': 'سنتر المستقبل'};
  await api.accept(auth);
  return api;
}

Json overview(String id) => {
  'student': children.firstWhere((s) => s['id'] == id),
  'attendancePercent': 92,
  'averageScore': 18,
  'balance': {'totalDue': id == 'a' ? 350 : 600, 'charges': []},
};

void main() {
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'guardian switches child on financial tab without stale data (dark $dark)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = MemoryStore();
        final api = await workspaceApi('Guardian', (r) async {
          if (r.path == '/portal/me') {
            return response(200, {'students': children});
          }
          if (r.path.endsWith('/overview')) {
            return response(200, overview(r.path.contains('/a/') ? 'a' : 'b'));
          }
          return response(200, []);
        }, storage: store);
        await tester.pumpWidget(
          host(
            GuardianPortal(api: api, onTheme: () {}),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.text('ريلز'), findsNothing);
        expect(find.byTooltip('الرسائل'), findsOneWidget);
        await screenshot(
          tester,
          dark ? 'guardian-home-dark' : 'guardian-home-light',
        );
        await tester.tap(find.text('المدفوعات').last);
        await tester.pumpAndSettle();
        expect(find.text('مستحقات أحمد محمد'), findsOneWidget);
        await tester.tap(find.text('تغيير الابن'));
        await tester.pumpAndSettle();
        await screenshot(
          tester,
          dark ? 'guardian-children-dark' : 'guardian-children-light',
        );
        await tester.tap(find.text('مريم محمد'));
        await tester.pumpAndSettle();
        expect(find.text('مستحقات مريم محمد'), findsOneWidget);
        expect(find.text('مستحقات أحمد محمد'), findsNothing);
        expect(jsonDecode(store.value!)['portalStudentId'], 'b');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await api.live.stop(clear: true);
      },
    );
  }
  testWidgets('late old-child response cannot replace selected child content', (
    tester,
  ) async {
    final old = Completer<ResponseBody>();
    final api = await workspaceApi('Guardian', (r) async {
      if (r.path == '/portal/me') return response(200, {'students': children});
      if (r.path.contains('/students/a/')) return old.future;
      if (r.path.contains('/students/b/')) return response(200, overview('b'));
      return response(200, []);
    });
    await tester.pumpWidget(host(GuardianPortal(api: api, onTheme: () {})));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('تغيير الابن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مريم محمد'));
    await tester.pumpAndSettle();
    old.complete(response(200, overview('a')));
    await tester.pumpAndSettle();
    expect(find.text('متابعة مريم محمد'), findsOneWidget);
    expect(find.text('متابعة أحمد محمد'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await api.live.stop(clear: true);
  });
  testWidgets('single child has no redundant switch and supports large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = await workspaceApi(
      'Guardian',
      (r) async => r.path == '/portal/me'
          ? response(200, {
              'students': [children.first],
            })
          : response(200, overview('a')),
    );
    await tester.pumpWidget(
      host(GuardianPortal(api: api, onTheme: () {}), scale: 1.6),
    );
    await tester.pumpAndSettle();
    expect(find.text('تغيير الابن'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await api.live.stop(clear: true);
  });
  testWidgets('new conversation uses authorized teacher and child snapshot', (
    tester,
  ) async {
    RequestOptions? create;
    final api = await workspaceApi('Guardian', (r) async {
      if (r.path.endsWith('/teachers')) {
        return response(200, [
          {'id': 'teacher-1', 'name': 'أستاذ أحمد'},
        ]);
      }
      if (r.method == 'POST' && r.path == '/portal/threads') {
        create = r;
        return response(201, {
          'id': 'thread',
          'subject': 'متابعة الحضور',
          'status': 'Open',
        });
      }
      return response(200, []);
    });
    api.portalStudentId = 'b';
    await tester.pumpWidget(
      host(NewConversationPage(api: api, studentId: 'a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('أستاذ أحمد'));
    await tester.enterText(find.byType(TextFormField), 'متابعة الحضور');
    await tester.ensureVisible(find.text('بدء المحادثة'));
    await tester.tap(find.text('بدء المحادثة'));
    await tester.pumpAndSettle();
    expect(create!.data['studentId'], 'a');
    expect(create!.data['teacherId'], 'teacher-1');
    await tester.pumpWidget(const SizedBox());
    await api.live.stop(clear: true);
  });
  testWidgets(
    'guardian excuse is session-scoped and sends UTC without duplicate submissions',
    (tester) async {
      final sent = <RequestOptions>[];
      final api = await workspaceApi('Guardian', (r) async {
        sent.add(r);
        return response(201, {});
      });
      await tester.pumpWidget(
        host(
          ExcuseEditor(
            api: api,
            studentId: 'b',
            session: {'id': 'session-1', 'startsAtUtc': '2026-10-29T15:00:00Z'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ظرف صحي يمنع الحضور');
      await tester.tap(find.text('إرسال العذر'));
      await tester.pumpAndSettle();
      expect(sent.single.path, '/portal/students/b/excuses');
      expect(sent.single.data['sessionId'], 'session-1');
      expect('${sent.single.data['dateUtc']}'.endsWith('Z'), true);
    },
  );
  testWidgets(
    'attendance posts required reason and updates counts, correction uses record id',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool recorded = false;
      RequestOptions? write;
      final api = await workspaceApi('Teacher', (r) async {
        if (r.method != 'GET') {
          write = r;
          recorded = true;
          return response(200, {});
        }
        return response(200, {
          'roster': [
            {'id': 'student', 'fullName': 'أحمد الطالب', 'code': 'S1'},
          ],
          'records': recorded
              ? [
                  {
                    'id': 'record-1',
                    'studentId': 'student',
                    'status': 'Present',
                  },
                ]
              : [],
          'expected': 1,
          'present': recorded ? 1 : 0,
          'absent': 0,
          'pendingCount': recorded ? 0 : 1,
          'timing': {'canRecordAttendance': true},
        });
      });
      await tester.pumpWidget(
        host(
          AttendancePage(
            api: api,
            session: {'id': 'session', 'topic': 'حصة الجبر'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل حاضر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(write!.path, '/sessions/session/attendance/manual');
      expect(write!.data['reason'].length, greaterThanOrEqualTo(5));
      expect(find.text('تم تسجيل حالة جميع الطلاب في الكشف'), findsOneWidget);
      await tester.tap(find.text('كشف الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('تصحيح الحالة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('متأخر'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'تصحيح بعد مراجعة وقت الوصول',
      );
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(write!.method, 'PUT');
      expect(write!.path, '/attendance/record-1');
      expect(write!.data['status'], 'Late');
      await screenshot(tester, 'teacher-attendance');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await api.live.stop(clear: true);
    },
  );
  testWidgets('teacher schedule never opens cross-center attendance', (
    tester,
  ) async {
    final api = await workspaceApi(
      'Teacher',
      (_) async => response(200, [
        {
          'id': 's',
          'tenantId': 'other',
          'tenantName': 'سنتر آخر',
          'groupName': 'مجموعة أخرى',
          'startsAtUtc': '2026-10-29T15:00:00Z',
          'durationMinutes': 90,
          'present': 0,
          'expected': 10,
        },
      ]),
    );
    await tester.pumpWidget(host(TeacherSchedulePage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('كشف الحضور'), findsNothing);
    expect(find.text('افتح السنتر صاحب الحصة لإدارة حضورها.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('teacher home surfaces today attendance before content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = await workspaceApi(
      'Teacher',
      (_) async => response(200, [
        {
          'id': 's',
          'groupName': 'الرياضيات — الثالثة',
          'startsAtUtc': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'durationMinutes': 90,
          'canRecordAttendance': true,
        },
      ]),
    );
    await tester.pumpWidget(host(Scaffold(body: TeacherHomePage(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('فتح كشف الحضور'), findsOneWidget);
    await screenshot(tester, 'teacher-workspace');
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets('child picker layout is readable at phone width (dark $dark)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChildPicker(students: children, selectedId: 'a'),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('أحمد محمد'), findsOneWidget);
      expect(find.text('مريم محمد'), findsOneWidget);
      await screenshot(
        tester,
        dark ? 'child-picker-dark' : 'child-picker-light',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
