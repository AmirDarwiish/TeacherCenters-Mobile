import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/scoped_chat.dart';
import 'api_test.dart' show response;
import 'workspaces_test.dart' show workspaceApi;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

Json conversation({
  bool group = false,
  bool send = true,
  bool manage = false,
}) => {
  'id': 'room-1',
  'kind': group ? 'SessionGroup' : 'Direct',
  'title': group ? 'جروب مراجعة الجبر' : 'أستاذ أحمد',
  'studentName': 'أحمد الطالب',
  'groupName': group ? 'مجموعة الرياضيات' : null,
  'status': 'Open',
  'canSend': send,
  'canManage': manage,
  'allowStudentMessages': send,
  'sessionStartsAtUtc': '2026-10-29T15:00:00Z',
};
Json message(int id, {String? body}) => {
  'id': id,
  'clientMessageId': 'key-$id',
  'senderId': 'student',
  'senderRole': 'Student',
  'senderName': 'أحمد الطالب',
  'body': body ?? 'رسالة رقم $id',
  'createdAtUtc': '2026-10-29T15:00:00Z',
};
Future<void> close(WidgetTester t, Api api) async {
  await t.pumpWidget(const SizedBox());
  await api.live.stop(clear: true);
}

void main() {
  setUpAll(loadTestFonts);
  testWidgets(
    'teacher has start chat in embedded inbox and can choose student or guardian',
    (t) async {
      RequestOptions? created;
      final api = await workspaceApi('Teacher', (r) async {
        if (r.path == '/chat/contacts') {
          final guardian = r.queryParameters['contactRole'] == 'Guardian';
          return response(200, {
            'items': [
              {
                'userId': guardian ? 'parent-1' : 'student',
                'role': guardian ? 'Guardian' : 'Student',
                'studentId': 'child-a',
                'studentName': 'أحمد الطالب',
                'name': guardian ? 'والد أحمد' : 'أحمد الطالب',
                'teacherId': 'teacher',
              },
            ],
            'totalCount': 1,
          });
        }
        if (r.method == 'POST') {
          created = r;
          return response(200, conversation());
        }
        if (r.path.endsWith('/messages')) return response(200, {'items': []});
        if (r.path.endsWith('/room-1')) return response(200, conversation());
        return response(200, {'items': [], 'totalCount': 0});
      });
      await t.pumpWidget(
        host(Scaffold(body: ThreadsPage(api: api, embedded: true))),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('بدء محادثة'));
      await t.pumpAndSettle();
      expect(find.text('أحمد الطالب'), findsOneWidget);
      await t.tap(find.text('أولياء الأمور'));
      await t.pumpAndSettle();
      expect(find.text('والد أحمد'), findsOneWidget);
      await t.tap(find.text('والد أحمد'));
      await t.pumpAndSettle();
      expect(created!.path, '/chat/direct');
      expect(created!.data['guardianId'], 'parent-1');
      expect(created!.data['studentId'], 'child-a');
      expect(created!.data['teacherId'], 'teacher');
      await close(t, api);
    },
  );
  testWidgets(
    'guardian contact picker keeps selected child snapshot and has no group creation',
    (t) async {
      final requests = <RequestOptions>[];
      final api = await workspaceApi('Guardian', (r) async {
        requests.add(r);
        if (r.path == '/chat/contacts')
          return response(200, {
            'items': [
              {
                'userId': 'teacher-1',
                'teacherId': 'teacher-1',
                'role': 'Teacher',
                'studentId': 'a',
                'studentName': 'أحمد',
                'name': 'أستاذ أحمد',
              },
            ],
            'totalCount': 1,
          });
        if (r.path.endsWith('/messages')) return response(200, {'items': []});
        return response(200, conversation());
      });
      api.portalStudentId = 'b';
      await t.pumpWidget(host(StartChatPage(api: api, studentId: 'a')));
      await t.pumpAndSettle();
      expect(find.text('جروب حصة'), findsNothing);
      expect(find.text('أولياء الأمور'), findsNothing);
      expect(requests.first.queryParameters['studentId'], 'a');
      await t.tap(find.text('أستاذ أحمد'));
      await t.pumpAndSettle();
      final start = requests.singleWhere((r) => r.method == 'POST');
      expect(start.data['studentId'], 'a');
      expect(start.data.containsKey('guardianId'), false);
      await close(t, api);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'teacher creates session group with announcement controls at phone width (dark $dark)',
      (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => t.binding.setSurfaceSize(null));
        RequestOptions? created;
        final api = await workspaceApi('Teacher', (r) async {
          if (r.path == '/chat/session-options')
            return response(200, {
              'items': [
                {
                  'id': 'session',
                  'topic': 'مراجعة الجبر',
                  'groupName': 'مجموعة الرياضيات',
                  'startsAtUtc': '2026-10-29T15:00:00Z',
                },
              ],
              'totalCount': 1,
            });
          if (r.method == 'POST') {
            created = r;
            return response(201, conversation(group: true, manage: true));
          }
          if (r.path.endsWith('/messages'))
            return response(200, {
              'items': [message(1, body: 'أهلاً بكم في جروب الحصة')],
            });
          return response(200, conversation(group: true, manage: true));
        });
        await t.pumpWidget(host(StartChatPage(api: api), dark: dark));
        await t.pumpAndSettle();
        await t.tap(find.text('جروب حصة'));
        await t.pumpAndSettle();
        await t.tap(find.text('مراجعة الجبر'));
        await t.pumpAndSettle();
        await t.tap(find.byType(SwitchListTile));
        await t.pumpAndSettle();
        await screenshot(
          t,
          dark ? 'chat-group-create-dark' : 'chat-group-create-light',
        );
        await t.ensureVisible(find.text('إنشاء أو فتح جروب الحصة'));
        await t.tap(find.text('إنشاء أو فتح جروب الحصة'));
        await t.pumpAndSettle();
        expect(created!.path, '/chat/session-groups');
        expect(created!.data['sessionId'], 'session');
        expect(created!.data['allowStudentMessages'], false);
        await screenshot(t, dark ? 'chat-room-dark' : 'chat-room-light');
        expect(t.takeException(), isNull);
        await close(t, api);
      },
    );
  }
  testWidgets(
    'student announcement room is readable without composer or management controls',
    (t) async {
      final api = await workspaceApi(
        'Student',
        (r) async => r.path.endsWith('/messages')
            ? response(200, {
                'items': [message(1)],
              })
            : response(200, conversation(group: true, send: false)),
      );
      await t.pumpWidget(
        host(
          ChatConversationPage(
            api: api,
            conversation: conversation(group: true, send: false),
            pollInterval: Duration.zero,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('رسالة رقم 1'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('إعدادات الجروب'), findsNothing);
      expect(find.text('المحادثة متاحة للقراءة فقط حالياً'), findsOneWidget);
      await close(t, api);
    },
  );
  testWidgets(
    'failed send preserves text and retries same client message id without duplicate bubble',
    (t) async {
      final sends = <RequestOptions>[];
      bool saved = false;
      final api = await workspaceApi('Teacher', (r) async {
        if (r.method == 'POST') {
          sends.add(r);
          if (sends.length == 1)
            return response(500, {'message': 'تعذر التأكيد'});
          saved = true;
          return response(201, message(1, body: 'سؤال للمدرس'));
        }
        if (r.path.endsWith('/messages'))
          return response(200, {
            'items': saved ? [message(1, body: 'سؤال للمدرس')] : [],
          });
        return response(200, conversation());
      });
      await t.pumpWidget(
        host(
          ChatConversationPage(
            api: api,
            conversation: conversation(),
            pollInterval: Duration.zero,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'سؤال للمدرس');
      await t.tap(find.byTooltip('إرسال'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'سؤال للمدرس'), findsOneWidget);
      await t.tap(find.byTooltip('إرسال'));
      await t.pumpAndSettle();
      expect(
        sends[0].data['clientMessageId'],
        sends[1].data['clientMessageId'],
      );
      expect(find.text('سؤال للمدرس'), findsOneWidget);
      expect(
        (t.widget<TextField>(find.byType(TextField))).controller!.text,
        isEmpty,
      );
      await close(t, api);
    },
  );
  testWidgets(
    'revoked membership removes cached messages and input immediately on recheck',
    (t) async {
      bool revoked = false;
      final api = await workspaceApi('Student', (r) async {
        if (revoked) return response(404, {'message': 'غير متاح'});
        if (r.path.endsWith('/messages'))
          return response(200, {
            'items': [message(1, body: 'رسالة خاصة بالحصة')],
          });
        return response(200, conversation(group: true));
      });
      await t.pumpWidget(
        host(
          ChatConversationPage(
            api: api,
            conversation: conversation(group: true),
            pollInterval: Duration.zero,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('رسالة خاصة بالحصة'), findsOneWidget);
      revoked = true;
      api.live.emit('ChatChanged');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('رسالة خاصة بالحصة'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('المحادثة غير متاحة'), findsOneWidget);
      await close(t, api);
    },
  );
  testWidgets(
    'announcement change during send keeps read access and refreshes composer permissions',
    (t) async {
      bool announce = false;
      final api = await workspaceApi('Student', (r) async {
        if (r.method == 'POST') {
          announce = true;
          return response(403, {
            'message': 'الجروب للإعلانات فقط',
            'code': 'chat-announcements-only',
          });
        }
        if (r.path.endsWith('/messages'))
          return response(200, {
            'items': [message(1)],
          });
        return response(200, conversation(group: true, send: !announce));
      });
      await t.pumpWidget(
        host(
          ChatConversationPage(
            api: api,
            conversation: conversation(group: true),
            pollInterval: Duration.zero,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'رد على الإعلان');
      await t.tap(find.byTooltip('إرسال'));
      await t.pumpAndSettle();
      expect(find.text('رسالة رقم 1'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('المحادثة غير متاحة'), findsNothing);
      await close(t, api);
    },
  );
  testWidgets('incremental refresh drains every page of a message burst', (
    t,
  ) async {
    final cursors = <int>[];
    bool burst = false;
    final api = await workspaceApi('Teacher', (r) async {
      if (r.path.endsWith('/messages')) {
        final after = r.queryParameters['afterId'] as int?;
        if (after == null)
          return response(200, {
            'items': [message(1)],
          });
        cursors.add(after);
        if (burst && after == 1)
          return response(200, {
            'items': [message(2), message(3)],
            'nextAfterId': 3,
          });
        if (burst && after == 3)
          return response(200, {
            'items': [message(4)],
          });
        return response(200, {'items': []});
      }
      return response(200, conversation());
    });
    await t.pumpWidget(
      host(
        ChatConversationPage(
          api: api,
          conversation: conversation(),
          pollInterval: Duration.zero,
        ),
      ),
    );
    await t.pumpAndSettle();
    burst = true;
    api.live.emit('ChatChanged');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(cursors, [1, 3]);
    expect(find.text('رسالة رقم 4'), findsOneWidget);
    expect(find.text('رسالة رقم 1'), findsOneWidget);
    await close(t, api);
  });
}
