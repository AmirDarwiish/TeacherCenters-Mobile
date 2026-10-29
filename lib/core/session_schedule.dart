import 'api.dart';
import 'format.dart';

DateTime? sessionStart(Json session) => apiUtc(session['startsAtUtc']);
DateTime? sessionEnd(Json session) =>
    apiUtc(session['endsAtUtc']) ??
    sessionStart(session)?.add(
      Duration(minutes: (session['durationMinutes'] as num? ?? 0).toInt()),
    );

bool sessionInactive(Json session) => const {
  'Cancelled',
  'Canceled',
  'Postponed',
  'Closed',
  'Completed',
  'Ended',
}.contains(session['status'] ?? session['effectiveStatus']);

bool sessionRunning(Json session, DateTime now) {
  if (sessionInactive(session)) return false;
  final start = sessionStart(session), end = sessionEnd(session);
  return start != null &&
      end != null &&
      !now.isBefore(start) &&
      now.isBefore(end);
}

bool sessionAttendanceOpen(Json session, DateTime now) {
  if (sessionInactive(session) || session['canRecordAttendance'] == false) {
    return false;
  }
  final opens =
      apiUtc(session['attendanceOpensAtUtc']) ?? sessionStart(session);
  final closes =
      apiUtc(session['attendanceClosesAtUtc']) ?? sessionEnd(session);
  return opens != null &&
      closes != null &&
      !now.isBefore(opens) &&
      now.isBefore(closes);
}

/// Current lessons, then nearest upcoming lessons, then most recent history.
List<Json> orderedSessions(Iterable<Json> sessions, DateTime now) {
  int group(Json s) {
    if (sessionRunning(s, now)) return 0;
    if (!sessionInactive(s) && (sessionStart(s)?.isAfter(now) ?? false)) {
      return 1;
    }
    return 2;
  }

  final result = sessions.toList();
  result.sort((a, b) {
    final rank = group(a).compareTo(group(b));
    if (rank != 0) return rank;
    final x = sessionStart(a), y = sessionStart(b);
    if (x == null || y == null) {
      return x == y
          ? 0
          : x == null
          ? 1
          : -1;
    }
    final time = group(a) == 2 ? y.compareTo(x) : x.compareTo(y);
    return time != 0 ? time : '${a['id']}'.compareTo('${b['id']}');
  });
  return result;
}

DateTime scheduleNow(Iterable<Json> sessions) {
  for (final session in sessions) {
    final server = apiUtc(session['serverNowUtc']);
    if (server != null) return server;
  }
  return DateTime.now().toUtc();
}

/// Fetch all matching pages before ordering; sorting just page 1 hides live lessons.
Future<List<Json>> loadSessionRange(
  Api api, {
  String? studentId,
  String? groupId,
  required DateTime from,
  required DateTime to,
}) async {
  final result = <Json>[], seen = <String>{};
  for (var page = 1; ; page++) {
    final data = await api.get(
      studentId == null ? '/sessions' : '/portal/students/$studentId/sessions',
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'page': page,
        'pageSize': 100,
        'groupId': ?groupId,
      },
    );
    final batch = rows(data);
    for (final session in batch) {
      final id = '${session['id']}';
      if (!seen.add(id)) {
        throw ApiFailure('تعذر تحديث جدول الحصص. حاول تاني.');
      }
      final start = sessionStart(session);
      if (start == null || (!start.isBefore(from) && start.isBefore(to))) {
        result.add(session);
      }
    }
    final total = obj(data)['totalCount'];
    final pages = obj(data)['totalPages'];
    if (data is List ||
        batch.isEmpty ||
        (total is num && seen.length >= total) ||
        (pages is num && page >= pages) ||
        (total == null && pages == null && batch.length < 100)) {
      break;
    }
  }
  return orderedSessions(result, scheduleNow(result));
}
