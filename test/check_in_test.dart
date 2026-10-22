import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/session_check_in.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

class TestAttendanceDevice extends AttendanceDevice {
  TestAttendanceDevice({this.outside = false, this.mocked = false});
  final bool outside, mocked;
  int locations = 0, photos = 0, cameraOpens = 0, cameraCloses = 0;
  @override
  Future<void> openCamera() async {
    cameraOpens++;
  }

  @override
  Future<void> closeCamera() async {
    cameraCloses++;
  }

  @override
  Widget cameraPreview() =>
      const Center(child: Text('معاينة الكاميرا المباشرة'));
  @override
  Future<AttendanceLocation> locate() async {
    locations++;
    return AttendanceLocation(
      outside ? 31.0 : 30.0,
      31.0,
      5,
      DateTime.now().toUtc(),
      isMocked: mocked,
    );
  }

  @override
  Future<Uint8List?> photograph() async {
    photos++;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGOUjf7AgA0wYRUdtBIAHLQBeFXty+UAAAAASUVORK5CYII=',
    );
  }
}

void main() {
  setUpAll(loadTestFonts);
  for (final scenario in ['inside', 'outside', 'mocked']) {
    final allowed = scenario == 'inside';
    testWidgets(
      'attendance requires fresh inside location and camera photo (scenario: $scenario)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final device = TestAttendanceDevice(
          outside: scenario == 'outside',
          mocked: scenario == 'mocked',
        );
        final requests = <RequestOptions>[];
        final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
        client.httpClientAdapter = FakeAdapter((request) async {
          requests.add(request);
          if (request.path.endsWith('/challenge')) {
            return response(201, {
              'challengeId': 'challenge-1',
              'captureToken': 'proof',
              'expiresAtUtc': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 5))
                  .toIso8601String(),
            });
          }
          if (request.method == 'POST') {
            return response(202, {
              'id': 'check-in-1',
              'verificationStatus': 'PendingReview',
              'attendance': null,
            });
          }
          return response(200, {
            'enabled': true,
            'canSubmit': true,
            'maxAccuracyMeters': 30,
            'landmarkPrompt': 'صوّر لافتة القاعة',
            'center': {
              'name': 'فرع طنطا',
              'latitude': 30.0,
              'longitude': 31.0,
              'allowedRadiusMeters': 100,
            },
          });
        });
        final api = Api(client: client, storage: MemoryStore());
        await api.accept(session('token', 'refresh'));
        await tester.pumpWidget(
          host(
            SessionCheckInPage(
              api: api,
              studentId: 'student-1',
              sessionId: 'session-1',
              device: device,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(device.locations, 0);
        expect(device.photos, 0);
        await tester.ensureVisible(find.text('١. تحديد موقعي الحالي'));
        await tester.tap(find.text('١. تحديد موقعي الحالي'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('٢. تصوير علامة مميزة بالكاميرا'));
        await tester.tap(find.text('٢. تصوير علامة مميزة بالكاميرا'));
        await tester.pumpAndSettle();
        expect(device.photos, 0);
        expect(device.cameraOpens, 1);
        expect(find.text('معاينة الكاميرا المباشرة'), findsOneWidget);
        expect(find.textContaining('رفع صورة'), findsNothing);
        final closed = device.cameraCloses;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        expect(device.cameraCloses, greaterThan(closed));
        expect(find.text('معاينة الكاميرا المباشرة'), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('٢. تصوير علامة مميزة بالكاميرا'));
        await tester.tap(find.text('٢. تصوير علامة مميزة بالكاميرا'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('التقاط الصورة الآن'));
        await tester.tap(find.text('التقاط الصورة الآن'));
        await tester.pumpAndSettle();
        expect(device.photos, 1);
        final button = find.widgetWithText(
          FilledButton,
          '٣. إرسال وتأكيد الحضور',
        );
        expect(tester.widget<FilledButton>(button).onPressed != null, allowed);
        if (allowed) {
          await screenshot(tester, 'attendance-location-photo');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          final sent = requests.singleWhere(
            (r) => r.method == 'POST' && !r.path.endsWith('/challenge'),
          );
          final form = sent.data as FormData;
          final fields = Map.fromEntries(form.fields);
          expect(fields['challengeId'], 'challenge-1');
          expect(fields['latitude'], '30.0');
          expect(form.files.single.key, 'photo');
          expect(sent.headers['Idempotency-Key'], isNotEmpty);
          expect(find.text('تم إرسال طلبك لمراجعة السنتر'), findsOneWidget);
          expect(find.text('تم تأكيد حضورك'), findsNothing);
        } else {
          expect(
            requests.where(
              (r) => r.method == 'POST' && !r.path.endsWith('/challenge'),
            ),
            isEmpty,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('missing backend does not request location or open camera', (
    tester,
  ) async {
    final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
    client.httpClientAdapter = FakeAdapter((r) async => response(404, {}));
    final api = Api(client: client, storage: MemoryStore());
    await api.accept(session('token', 'refresh'));
    final device = TestAttendanceDevice();
    await tester.pumpWidget(
      host(
        SessionCheckInPage(
          api: api,
          studentId: 'student-1',
          sessionId: 'session-1',
          device: device,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('لم يُفعّل'), findsOneWidget);
    expect(device.locations, 0);
    expect(device.photos, 0);
  });
}
