import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/session_check_in.dart';
import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'check_in_test.dart' show TestAttendanceDevice;
import 'course_experience_test.dart' show host;

class PermissionDevice extends TestAttendanceDevice {
  final permission = Completer<void>();
  @override
  Future<void> openCamera() async {
    await super.openCamera();
    await permission.future;
  }
}

class StaleDevice extends TestAttendanceDevice {
  @override
  Future<AttendanceLocation> locate() async {
    locations++;
    return AttendanceLocation(
      30,
      31,
      5,
      DateTime.now().toUtc().subtract(
        locations == 1 ? const Duration(seconds: 90) : Duration.zero,
      ),
    );
  }
}

class Harness {
  Harness({
    this.enabled = true,
    this.outsideReview = false,
    this.timeoutFirst = false,
    this.serverTime,
  });
  final bool enabled, outsideReview, timeoutFirst;
  final DateTime? serverTime;
  final fields = <Map<String, String>>[];
  final keys = <String>[];
  Future<Api> api() async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = FakeAdapter((r) async {
      final now = serverTime ?? DateTime.now().toUtc();
      if (r.path.endsWith('/challenge')) {
        return response(201, {
          'challengeId': 'proof-id',
          'captureToken': 'test-proof',
          'expiresAtUtc': now
              .add(const Duration(minutes: 5))
              .toIso8601String()
              .replaceAll('Z', ''),
        });
      }
      if (r.method == 'POST') {
        fields.add(Map.fromEntries((r.data as FormData).fields));
        keys.add(r.headers['Idempotency-Key'] as String);
        if (timeoutFirst && fields.length == 1) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return response(outsideReview ? 202 : 201, {
          'id': 'checkin',
          'verificationStatus': outsideReview ? 'PendingReview' : 'Approved',
          'attendance': outsideReview ? null : 'Present',
        });
      }
      return response(200, {
        'enabled': enabled,
        'canSubmit': enabled,
        'reason': enabled ? null : 'الحضور مش مفتوح للحصة دي دلوقتي',
        'serverNowUtc': now.toIso8601String(),
        'reviewOutsideRadius': outsideReview,
        'maxAccuracyMeters': 30,
        'center': {'latitude': 30, 'longitude': 31, 'allowedRadiusMeters': 100},
      });
    });
    final api = Api(client: dio, storage: MemoryStore());
    await api.accept(session('token', 'refresh'));
    return api;
  }
}

Future<void> showCheckIn(
  WidgetTester tester,
  Harness h,
  TestAttendanceDevice device,
) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    host(
      SessionCheckInPage(
        api: await h.api(),
        studentId: 'student',
        sessionId: 'lesson',
        device: device,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 160);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester) async {
  await tapLabel(tester, '١. تحديد موقعي الحالي');
  await tapLabel(tester, '٢. تصوير علامة مميزة بالكاميرا');
  await tapLabel(tester, 'التقاط الصورة الآن');
}

void main() {
  testWidgets(
    'camera permission inactive dialog does not cancel first camera initialization',
    (tester) async {
      final h = Harness(), device = PermissionDevice();
      await showCheckIn(tester, h, device);
      await tapLabel(tester, '٢. تصوير علامة مميزة بالكاميرا');
      final closed = device.cameraCloses;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      device.permission.complete();
      await tester.pumpAndSettle();
      expect(find.text('معاينة الكاميرا المباشرة'), findsOneWidget);
      expect(device.cameraCloses, closed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(device.cameraCloses, greaterThan(closed));
      expect(find.text('معاينة الكاميرا المباشرة'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'closed policy shows server reason and never asks for camera or GPS',
    (tester) async {
      final h = Harness(enabled: false), device = TestAttendanceDevice();
      await showCheckIn(tester, h, device);
      expect(find.text('الحضور مش مفتوح للحصة دي دلوقتي'), findsOneWidget);
      expect(find.text('١. تحديد موقعي الحالي'), findsNothing);
      expect(device.locations, 0);
      expect(device.cameraOpens, 0);
    },
  );
  testWidgets(
    'outside GPS can submit for staff review only when server explicitly permits it',
    (tester) async {
      final h = Harness(outsideReview: true),
          device = TestAttendanceDevice(outside: true);
      await showCheckIn(tester, h, device);
      await capture(tester);
      await tapLabel(tester, '٣. إرسال طلب الحضور للمراجعة');
      expect(h.fields.single['latitude'], '31.0');
      expect(find.text('تم إرسال طلبك لمراجعة السنتر'), findsOneWidget);
      expect(find.text('تم تأكيد حضورك'), findsNothing);
    },
  );
  testWidgets(
    'stale GPS is refreshed at send and evidence uses server clock with zone-less expiry',
    (tester) async {
      final server = DateTime.utc(2030, 1, 1, 12);
      final h = Harness(serverTime: server), device = StaleDevice();
      await showCheckIn(tester, h, device);
      await capture(tester);
      await tapLabel(tester, '٣. إرسال وتأكيد الحضور');
      expect(device.locations, 2);
      expect(
        DateTime.parse(
          h.fields.single['locationCapturedAtUtc']!,
        ).difference(server).inSeconds.abs(),
        lessThan(10),
      );
      expect(
        DateTime.parse(
          h.fields.single['photoCapturedAtUtc']!,
        ).difference(server).inSeconds.abs(),
        lessThan(10),
      );
      expect(find.text('تم تأكيد حضورك'), findsOneWidget);
    },
  );
  testWidgets(
    'retry after transport timeout keeps the same evidence and idempotency key',
    (tester) async {
      final h = Harness(timeoutFirst: true), device = TestAttendanceDevice();
      await showCheckIn(tester, h, device);
      await capture(tester);
      await tapLabel(tester, '٣. إرسال وتأكيد الحضور');
      expect(h.fields.length, 1);
      await tapLabel(tester, '٣. إرسال وتأكيد الحضور');
      expect(h.fields.length, 2);
      expect(h.keys[0], h.keys[1]);
      expect(h.fields[0], h.fields[1]);
      expect(find.text('تم تأكيد حضورك'), findsOneWidget);
    },
  );
}
