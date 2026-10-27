import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/core/otp_field.dart';
import 'package:teacher_centers_mobile/features/login.dart';
import 'package:teacher_centers_mobile/features/shell.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart'
    show host, screenshot, course, loadTestFonts;

Future<Api> loginApi(List<RequestOptions> requests) async {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
  client.httpClientAdapter = FakeAdapter((o) async {
    requests.add(o);
    if (o.path.endsWith('/otp/request')) {
      return response(202, {
        'challengeId': 'challenge-a',
        'loginTicket': 'guardian-ticket',
        'resendAfterSeconds': 60,
      });
    }
    if (o.path.endsWith('/otp/verify')) {
      final data = session('token', 'refresh');
      if (o.data['purpose'] == 'guardian-login') {
        data['profile'] = {'id': 'guardian-1', 'role': 'Guardian'};
      }
      return response(200, data);
    }
    if (o.path.endsWith('/portal/me')) {
      return response(200, {
        'students': [
          {'id': 'student-1', 'fullName': 'عمر أحمد'},
        ],
      });
    }
    if (o.path.endsWith('/portal/courses')) {
      return response(200, [
        {...course, 'lastActivityAt': '2026-10-21T09:00:00Z'},
      ]);
    }
    if (o.path.endsWith('/overview')) {
      return response(200, {
        'attendancePercent': 94,
        'averageScore': 88,
        'nextSession': {
          'topic': 'تطبيقات قوانين نيوتن',
          'startsAtUtc': '2026-10-22T16:00:00Z',
        },
        'balance': {'totalDue': 0},
      });
    }
    if (o.path.endsWith('/dashboard/summary')) {
      return response(200, {
        'activeStudents': 128,
        'sessionsToday': {'total': 4},
      });
    }
    return response(200, {'name': 'أكاديمية آفاق'});
  });
  return Api(client: client, storage: MemoryStore())..slug = 'center-a';
}

void main() {
  setUpAll(loadTestFonts);
  testWidgets(
    'OTP accepts six pasted Arabic digits, limits length and keeps deletion native',
    (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        host(Scaffold(body: OtpCodeField(controller: controller))),
      );
      expect(find.text('—'), findsNWidgets(6));
      await tester.enterText(
        find.byKey(const ValueKey('otp-input')),
        '١٢٣٤٥٦٧',
      );
      await tester.pumpAndSettle();
      expect(controller.text, '123456');
      await tester.enterText(find.byKey(const ValueKey('otp-input')), '12345');
      await tester.pumpAndSettle();
      expect(controller.text, '12345');
      expect(find.text('—'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'student and guardian login hide center field and bind OTP purpose',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <RequestOptions>[];
      final api = await loginApi(requests);
      await tester.pumpWidget(host(LoginPage(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('رابط السنتر أو اسمه في الرابط'), findsNothing);
      await screenshot(tester, 'login');
      await tester.tap(find.text('ولي أمر'));
      await tester.enterText(find.byType(TextFormField), '01012345678');
      await tester.ensureVisible(find.text('إرسال رمز التحقق'));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      expect(requests.last.data['purpose'], 'guardian-login');
      expect(requests.last.path, '/mobile/auth/otp/request');
      expect(requests.any((r) => r.path.startsWith('/t/')), false);
      expect(requests.last.data.containsKey('tenantSlug'), false);
      expect(find.text('—'), findsNWidgets(6));
      await tester.enterText(find.byKey(const ValueKey('otp-input')), '١٢٣٤٥٦');
      await tester.pumpAndSettle();
      await screenshot(tester, 'otp');
      expect(requests.where((r) => r.path.endsWith('/otp/verify')).length, 1);
      expect(requests.last.path, '/mobile/auth/otp/verify');
      expect(requests.last.data['loginTicket'], 'guardian-ticket');
      expect(requests.last.data['code'], '123456');
      expect(requests.last.data['purpose'], 'guardian-login');
      expect(api.guardian, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'phone accepts exactly eleven normalized digits and rejects incomplete input',
    (tester) async {
      final requests = <RequestOptions>[];
      final api = await loginApi(requests);
      await tester.pumpWidget(host(LoginPage(api: api)));
      final field = find.byType(TextFormField);
      await tester.enterText(field, '٠١٠١٢٣٤٥٦٧');
      await tester.ensureVisible(find.text('إرسال رمز التحقق'));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(find.text('اكتب رقم الموبايل المكوّن من ١١ رقم'), findsOneWidget);
      await tester.enterText(field, '٠١٠١٢٣٤٥٦٧٨٩٩abc');
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '01012345678',
      );
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      expect(requests.single.data['phone'], '01012345678');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'OTP completion submits once while pending and permits correction after failure',
    (tester) async {
      final pending = Completer<ResponseBody>();
      var verifies = 0;
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((r) async {
        if (r.path.endsWith('/otp/request')) {
          return response(202, {'challengeId': 'a'});
        }
        verifies++;
        if (verifies == 1) return pending.future;
        return response(200, session('token', 'refresh'));
      });
      final api = Api(client: client, storage: MemoryStore());
      await tester.pumpWidget(host(LoginPage(api: api)));
      await tester.enterText(find.byType(TextFormField), '01012345678');
      await tester.ensureVisible(find.text('إرسال رمز التحقق'));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      final otp = find.byKey(const ValueKey('otp-input'));
      await tester.enterText(otp, '12345');
      await tester.pump();
      expect(verifies, 0);
      await tester.enterText(otp, '123456');
      await tester.pump();
      expect(verifies, 1);
      final button = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(button.onPressed, isNull);
      pending.complete(response(400, {'message': 'رمز غير صحيح'}));
      await tester.pumpAndSettle();
      await tester.enterText(otp, '123456');
      await tester.pumpAndSettle();
      expect(verifies, 1);
      await tester.enterText(otp, '654321');
      await tester.pumpAndSettle();
      expect(verifies, 2);
      expect(api.student, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home presents learning and upcoming class before secondary actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = await loginApi([]);
      final auth = session('token', 'refresh');
      auth['profile'] = {
        'id': 'student-1',
        'role': 'Student',
        'fullName': 'عمر أحمد',
      };
      await api.accept(auth);
      await tester.pumpWidget(
        host(
          Scaffold(
            appBar: AppBar(title: const Text('الرئيسية')),
            body: HomePage(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('كمّل رحلتك'), findsOneWidget);
      expect(find.text('تطبيقات قوانين نيوتن'), findsOneWidget);
      final banner = find
          .ancestor(
            of: find.text('فهم أعمق.\nوثقة في اللي جاي.'),
            matching: find.byType(Container),
          )
          .first;
      final attendanceCode = find.widgetWithText(
        FilledButton,
        'اعرض كود الحضور',
      );
      expect(
        tester.getTopLeft(attendanceCode).dy - tester.getBottomLeft(banner).dy,
        greaterThanOrEqualTo(12),
      );
      await screenshot(tester, 'home-student');
      await tester.binding.setSurfaceSize(const Size(390, 690));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(attendanceCode),
        alignment: 1,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(attendanceCode).dy - tester.getBottomLeft(banner).dy,
        greaterThanOrEqualTo(12),
      );
      await screenshot(tester, 'home-student-compact');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
