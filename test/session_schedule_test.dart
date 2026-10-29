import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/core/format.dart';
import 'package:teacher_centers_mobile/core/session_schedule.dart';
import 'api_test.dart' show MemoryStore, FakeAdapter, response;
import 'package:dio/dio.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  Json lesson(String id, int offset, {String status = 'Open'}) => {
    'id': id,
    'startsAtUtc': now.add(Duration(minutes: offset)).toIso8601String(),
    'durationMinutes': 60,
    'status': status,
  };
  test(
    'UTC fields without offset keep their instant, Cairo display observes DST',
    () {
      expect(apiUtc('2026-10-27T12:00:00'), now);
      expect(apiUtc('2026-10-27T15:00:00+03:00'), now);
      expect(cairoDate(apiUtc('2026-10-27T12:00:00')!).hour, 15);
      expect(
        cairoMidnightUtc(DateTime(2026, 10, 27)),
        DateTime.utc(2026, 10, 26, 21),
      );
    },
  );
  test('live lessons lead, then nearest upcoming, then recent history', () {
    final input = [
      lesson('old', -300),
      lesson('far', 300),
      lesson('live', -10),
      lesson('near', 10),
      lesson('recent', -80),
      lesson('cancelled', 5, status: 'Cancelled'),
    ];
    expect(orderedSessions(input, now).map((s) => s['id']), [
      'live',
      'near',
      'far',
      'cancelled',
      'recent',
      'old',
    ]);
    expect(input.first['id'], 'old');
    expect(
      sessionRunning(lesson('closed', -10, status: 'Closed'), now),
      isFalse,
    );
    expect(sessionRunning(lesson('ended', -60), now), isFalse);
  });
  test(
    'server attendance window permits early check-in but honours denial',
    () {
      final s = {
        ...lesson('early', 5),
        'attendanceOpensAtUtc': now
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
        'canRecordAttendance': true,
      };
      expect(sessionRunning(s, now), isFalse);
      expect(sessionAttendanceOpen(s, now), isTrue);
      expect(
        sessionAttendanceOpen({...s, 'canRecordAttendance': false}, now),
        isFalse,
      );
    },
  );
  test('current lesson on page two is loaded before ordering', () async {
    final requested = <int>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = FakeAdapter((r) async {
      final page = r.queryParameters['page'] as int;
      requested.add(page);
      expect(r.queryParameters['from'], endsWith('Z'));
      expect(r.queryParameters['to'], endsWith('Z'));
      return response(200, {
        'items': page == 1 ? [lesson('future', 90)] : [lesson('live', -10)],
        'totalCount': 2,
        'totalPages': 2,
      });
    });
    final result = await loadSessionRange(
      Api(client: dio, storage: MemoryStore()),
      studentId: 'student',
      from: now.subtract(const Duration(days: 1)),
      to: now.add(const Duration(days: 1)),
    );
    expect(requested, [1, 2]);
    // Use the known server instant rather than the test machine's wall clock.
    expect(orderedSessions(result, now).first['id'], 'live');
  });
}
