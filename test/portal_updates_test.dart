import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/login.dart';
import 'package:teacher_centers_mobile/features/payments.dart';
import 'package:teacher_centers_mobile/features/lesson_discussion.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

void main() {
  setUpAll(loadTestFonts);
  testWidgets('guardian pays the selected child and selected charges only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <RequestOptions>[];
    final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
    client.httpClientAdapter = FakeAdapter((request) async {
      requests.add(request);
      if (request.path.endsWith('/config')) {
        return response(200, {
          'enabled': true,
          'methods': [
            {'key': 'Card'},
          ],
        });
      }
      if (request.path.endsWith('/checkout')) {
        return response(200, {'paymentId': 'payment-1'});
      }
      if (request.path.endsWith('/payments/payment-1')) {
        return response(200, {'status': 'Paid', 'amount': 100});
      }
      return response(200, {
        'balance': {
          'totalDue': 100,
          'charges': [
            {
              'id': 'child-b-charge',
              'title': 'اشتراك الطالب الثاني',
              'amount': 100,
              'paid': 0,
              'remaining': 100,
            },
          ],
        },
      });
    });
    final api = Api(client: client, storage: MemoryStore())
      ..portalStudentId = 'child-b';
    final tokens = session('token', 'refresh')
      ..['profile'] = {'id': 'guardian', 'role': 'Guardian'};
    await api.accept(tokens);
    await tester.pumpWidget(host(PaymentsPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('سداد المحدد'), findsOneWidget);
    await screenshot(tester, 'guardian-dues');
    await tester.tap(find.text('سداد المحدد'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('بطاقة بنكية'));
    await tester.tap(find.text('بطاقة بنكية'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('المتابعة للدفع'));
    await tester.tap(find.text('المتابعة للدفع'));
    await tester.pumpAndSettle();
    final checkout = requests.singleWhere((r) => r.path.endsWith('/checkout'));
    expect(checkout.data['studentId'], 'child-b');
    expect(checkout.data['chargeIds'], ['child-b-charge']);
    expect(checkout.data['method'], 'Card');
    expect(requests.any((r) => r.path.contains('/students/guardian/')), false);
    await tester.pumpWidget(const SizedBox());
  });

  for (final teacher in [false, true]) {
    testWidgets('one center signs in automatically (teacher: $teacher)', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
      client.httpClientAdapter = FakeAdapter((request) async {
        requests.add(request);
        if (request.path.endsWith('/otp/request')) {
          return response(202, {
            'challengeId': 'challenge',
            'loginTicket': 'ticket',
          });
        }
        if (request.path.endsWith('/verify') ||
            request.path.endsWith('/staff/login')) {
          return response(200, {
            'requiresCenterSelection': true,
            'selectionToken': 'selection',
            'centers': [
              {
                'tenantId': 'tenant-a',
                'slug': 'actual-center',
                'name': 'سنتر واحد',
                'accounts': [
                  {'subjectId': 'subject-a', 'fullName': 'حساب واحد'},
                ],
              },
            ],
          });
        }
        final tokens = session('token', 'refresh');
        tokens['profile'] = {
          'id': 'subject-a',
          'role': teacher ? 'Teacher' : 'Student',
        };
        tokens['tenant'] = {'slug': 'actual-center'};
        return response(200, tokens);
      });
      final api = Api(client: client, storage: MemoryStore());
      await tester.pumpWidget(host(LoginPage(api: api)));
      if (teacher) {
        await tester.tap(find.text('مدرس'));
        await tester.pumpAndSettle();
      }
      expect(find.text('رابط السنتر أو اسمه في الرابط'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, '01012345678');
      if (teacher) {
        await tester.enterText(find.byType(TextFormField).last, 'password');
      }
      await tester.ensureVisible(
        find.text(teacher ? 'دخول المدرس' : 'إرسال رمز التحقق'),
      );
      await tester.tap(find.text(teacher ? 'دخول المدرس' : 'إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      if (!teacher) {
        await tester.enterText(
          find.byKey(const ValueKey('otp-input')),
          '123456',
        );
        await tester.ensureVisible(find.text('تأكيد ودخول'));
        await tester.tap(find.text('تأكيد ودخول'));
        await tester.pumpAndSettle();
      }
      expect(api.signedIn, true);
      expect(api.slug, 'actual-center');
      expect(
        requests.last.path,
        teacher
            ? '/mobile/auth/staff/select-center'
            : '/mobile/auth/select-center',
      );
      expect(requests.any((r) => r.path.startsWith('/t/')), false);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('video notes save an integer timestamp and seek back to it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final notes = <Json>[];
    RequestOptions? saved;
    client.httpClientAdapter = FakeAdapter((request) async {
      if (request.method == 'POST') {
        saved = request;
        notes.add({'id': 'note-1', ...obj(request.data)});
        return response(201, {'id': 'note-1'});
      }
      return response(200, notes);
    });
    final position = ValueNotifier(const Duration(seconds: 83));
    int? seek;
    final api = Api(client: client, storage: MemoryStore());
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ListView(
            children: [
              LessonDiscussion(
                api: api,
                courseId: 'course-1',
                lessonId: 'lesson-1',
                position: position,
                onSeek: (seconds) => seek = seconds,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('أضف ملاحظة عند 1:23'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'راجع المثال الثاني');
    await tester.ensureVisible(find.text('حفظ الملاحظة'));
    await tester.tap(find.text('حفظ الملاحظة'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(saved!.data['positionSeconds'], 83);
    expect(saved!.data['lessonId'], 'lesson-1');
    expect(find.text('راجع المثال الثاني'), findsOneWidget);
    await tester.tap(find.text('1:23'));
    expect(seek, 83);
    await screenshot(tester, 'video-notes');
    await tester.pumpWidget(const SizedBox());
    position.dispose();
  });
}
