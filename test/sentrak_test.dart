import 'package:teacher_centers_mobile/core/app_icons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/login.dart';
import 'package:teacher_centers_mobile/features/payments.dart';
import 'package:teacher_centers_mobile/features/session_detail.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host, screenshot, loadTestFonts;

void main() {
  setUpAll(loadTestFonts);
  for (final portalRole in ['Student', 'Guardian']) {
    testWidgets('verified $portalRole phone chooses center before session', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <RequestOptions>[];
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((o) async {
        requests.add(o);
        if (o.path.endsWith('/config')) {
          return response(200, {'globalOtp': true});
        }
        if (o.path.endsWith('/request')) {
          return response(202, {
            'challengeId': 'challenge',
            'loginTicket': 'opaque-ticket',
            'resendAfterSeconds': 60,
          });
        }
        if (o.path.endsWith('/verify')) {
          return response(200, {
            'requiresCenterSelection': true,
            'selectionToken': 'opaque-selection',
            'centers': [
              {
                'tenantId': 'center-1',
                'slug': 'first',
                'name': 'أكاديمية آفاق',
                'accounts': [
                  {'subjectId': 'student-a', 'fullName': 'عمر أحمد'},
                ],
              },
              {
                'tenantId': 'center-2',
                'slug': 'second',
                'name': 'سنتر النجاح',
                'accounts': [
                  {'subjectId': 'student-b', 'fullName': 'حساب سنتر النجاح'},
                ],
              },
            ],
          });
        }
        final tokens = session('token', 'refresh');
        tokens['profile'] = {'id': 'subject-b', 'role': portalRole};
        tokens['tenant'] = {'slug': 'second', 'name': 'سنتر النجاح'};
        return response(200, tokens);
      });
      final api = Api(client: client, storage: MemoryStore());
      await tester.pumpWidget(host(LoginPage(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('ولي أمر'), findsOneWidget);
      expect(find.text('طالب / ولي أمر'), findsNothing);
      expect(find.text('أكاديمية آفاق'), findsNothing);
      await screenshot(tester, 'sentrak-login');
      if (portalRole == 'Guardian') {
        await tester.tap(find.text('ولي أمر'));
        await tester.pumpAndSettle();
      }
      expect(find.text('رابط السنتر أو اسمه في الرابط'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '01012345678');
      await tester.ensureVisible(find.text('إرسال رمز التحقق'));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
      await tester.ensureVisible(find.text('تأكيد ودخول'));
      await tester.tap(find.text('تأكيد ودخول'));
      await tester.pumpAndSettle();
      expect(api.signedIn, false);
      expect(find.text('سنتر النجاح'), findsOneWidget);
      await screenshot(tester, 'center-picker');
      await tester.ensureVisible(find.text('حساب سنتر النجاح'));
      await tester.tap(find.text('حساب سنتر النجاح'));
      await tester.pumpAndSettle();
      expect(api.slug, 'second');
      expect(api.role, portalRole);
      expect(requests.any((r) => r.path.startsWith('/t/')), false);
      expect(
        requests
            .firstWhere((r) => r.path.endsWith('/otp/request'))
            .data['purpose'],
        portalRole == 'Guardian' ? 'guardian-login' : 'student-login',
      );
      expect(requests.last.data['tenantId'], 'center-2');
      expect(requests.last.headers.containsKey('Authorization'), false);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final objectMethods in [true, false]) {
    testWidgets('checkout reads enabled methods (objects: $objectMethods)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((o) async {
        if (o.path.endsWith('/config')) {
          return response(200, {
            'enabled': true,
            'methods': objectMethods
                ? [
                    {'key': 'Card', 'label': 'بطاقة بنكية'},
                    {'key': 'Wallet', 'label': 'محفظة'},
                  ]
                : ['Card', 'Wallet'],
          });
        }
        return response(200, {
          'balance': {
            'charges': [
              {'id': 'a', 'title': 'اشتراك الفيزياء', 'remaining': 350},
            ],
          },
        });
      });
      final api = Api(client: client, storage: MemoryStore());
      await api.accept(session('token', 'refresh'));
      await tester.pumpWidget(
        host(CheckoutPage(api: api, studentId: 'student-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('وسيلة الدفع'), findsOneWidget);
      expect(find.textContaining('الدفع الإلكتروني مش متاح'), findsNothing);
      expect(find.byIcon(AppIcons.creditCard), findsOneWidget);
      if (objectMethods) await screenshot(tester, 'checkout-blue');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'dues render paid and remaining amounts and allow selected charges only',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((o) async {
        if (o.path.endsWith('/me')) {
          return response(200, {
            'students': [
              {'id': 'student-1'},
            ],
          });
        }
        return response(200, {
          'balance': {
            'totalDue': 650,
            'charges': [
              {
                'id': 'a',
                'title': 'اشتراك الفيزياء',
                'period': '2026-10',
                'amount': 500,
                'paid': 150,
                'remaining': 350,
              },
              {
                'id': 'b',
                'title': 'اشتراك الرياضيات',
                'period': '2026-10',
                'amount': 300,
                'paid': 0,
                'remaining': 300,
              },
            ],
          },
        });
      });
      final api = Api(client: client, storage: MemoryStore());
      await api.accept(session('token', 'refresh'));
      await tester.pumpWidget(host(PaymentsPage(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('2 بنود محددة'), findsOneWidget);
      await screenshot(tester, 'dues');
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 بنود محددة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('session detail renders attendance, venue and published grade', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
    client.httpClientAdapter = FakeAdapter(
      (o) async => response(200, {
        'id': 'session-1',
        'topic': 'قوانين نيوتن وتطبيقاتها',
        'groupName': 'فيزياء — المجموعة الأولى',
        'startsAtUtc': '2026-10-22T16:00:00Z',
        'durationMinutes': 90,
        'hallName': 'قاعة ٢',
        'branchName': 'فرع طنطا',
        'teacherName': 'أحمد محمود',
        'attendance': 'Present',
        'status': 'Closed',
        'quizzes': [
          {'title': 'تطبيقات الحركة', 'score': 18, 'maxScore': 20},
        ],
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
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('قاعة ٢'), findsOneWidget);
    expect(find.text('حاضر'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('١٨ / ٢٠'), 300);
    await tester.pumpAndSettle();
    expect(find.text('١٨ / ٢٠'), findsOneWidget);
    await screenshot(tester, 'session-detail');
    expect(tester.takeException(), isNull);
  });
}
