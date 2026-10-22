import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'shell.dart' show StudentCard;
import 'session_check_in.dart';

String sessionStatus(dynamic value) =>
    const {
      'Open': 'مجدولة',
      'InProgress': 'جارية الآن',
      'Closed': 'انتهت',
      'Completed': 'انتهت',
      'Cancelled': 'ملغاة',
      'Canceled': 'ملغاة',
      'Upcoming': 'قادمة',
      'Ended': 'انتهت',
    }[value] ??
    'مجدولة';
String attendanceStatus(dynamic value) =>
    const {
      'Present': 'حاضر',
      'Absent': 'غائب',
      'Late': 'حاضر متأخر',
      'Excused': 'غياب بعذر',
    }[value] ??
    'لم يُسجّل الحضور بعد';

class StudentSessionPage extends StatelessWidget {
  const StudentSessionPage({
    super.key,
    required this.api,
    required this.studentId,
    required this.session,
  });
  final Api api;
  final String studentId;
  final Json session;
  Future<dynamic> load() async {
    try {
      return await api.get(
        '/portal/students/$studentId/sessions/${session['id']}',
      );
    } on ApiFailure catch (e) {
      if (e.status == 404) return session;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تفاصيل الحصة')),
    body: AsyncPanel(
      load: load,
      builder: (value, refresh) {
        final s = {...session, ...obj(value)},
            colors = Theme.of(context).colorScheme;
        final start = DateTime.tryParse('${s['startsAtUtc']}');
        final end =
            DateTime.tryParse('${s['endsAtUtc']}') ??
            start?.add(
              Duration(minutes: (s['durationMinutes'] as num? ?? 0).toInt()),
            );
        final status = s['effectiveStatus'] ?? s['status'];
        final cancelled = ['Cancelled', 'Canceled'].contains(status);
        final grades = rows(s['quizzes']);
        return ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    avatar: Icon(
                      cancelled
                          ? Icons.event_busy_outlined
                          : Icons.schedule_outlined,
                      size: 18,
                    ),
                    label: Text(sessionStatus(status)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${s['topic'] ?? s['groupName'] ?? 'حصة دراسية'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  if (s['groupName'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${s['groupName']}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'الميعاد والمكان',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  _row(
                    Icons.calendar_month_outlined,
                    'بداية الحصة',
                    when(s['startsAtUtc']),
                  ),
                  if (end != null)
                    _row(
                      Icons.schedule_rounded,
                      'نهاية الحصة',
                      when(end.toIso8601String()),
                    ),
                  if ((s['durationMinutes'] as num? ?? 0) > 0)
                    _row(
                      Icons.timelapse_rounded,
                      'المدة',
                      '${s['durationMinutes']} دقيقة',
                    ),
                  _row(
                    Icons.meeting_room_outlined,
                    'القاعة',
                    '${s['hallName'] ?? 'لم يحدد السنتر قاعة للعرض بعد'}',
                  ),
                  if (s['branchName'] != null)
                    _row(
                      Icons.location_on_outlined,
                      'الفرع',
                      '${s['branchName']}',
                    ),
                  if (s['teacherName'] != null)
                    _row(
                      Icons.school_outlined,
                      'المدرس',
                      '${s['teacherName']}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'الحضور',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      s['attendance'] == 'Present' || s['attendance'] == 'Late'
                          ? Icons.check_circle_outline
                          : Icons.fact_check_outlined,
                      size: 32,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attendanceStatus(s['attendance']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cancelled
                                ? 'الحصة ملغاة؛ راجع الجدول لأي موعد بديل.'
                                : s['attendance'] == null
                                ? 'يحدّث السنتر حالة حضورك بعد التسجيل.'
                                : 'هذه الحالة مسجلة لدى السنتر.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (api.role == 'Student' &&
                !cancelled &&
                !['Present', 'Late', 'Excused'].contains(s['attendance']))
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionCheckInPage(
                        api: api,
                        studentId: studentId,
                        sessionId: '${s['id']}',
                      ),
                    ),
                  );
                  if (context.mounted) refresh();
                },
                icon: const Icon(Icons.pin_drop_outlined),
                label: const Text('تسجيل حضوري بالموقع والصورة'),
              ),
            if (!api.guardian && !cancelled && s['attendance'] == null)
              OutlinedButton.icon(
                onPressed: () => open(context, StudentCard(api: api)),
                icon: const Icon(Icons.qr_code_rounded),
                label: const Text('اعرض بطاقة الحضور'),
              ),
            const SizedBox(height: 24),
            Text(
              'اختبارات الحصة ونتائجك',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            if (grades.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.assignment_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'مفيش نتائج منشورة للحصة دي حتى الآن. هتظهر هنا بعد اعتمادها من المدرس.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            for (final q in grades)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.quiz_outlined),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label(q),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        q['score'] == null
                            ? 'لم تُنشر درجتك'
                            : '${q['score']} / ${q['maxScore'] ?? '—'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _row(IconData icon, String title, String value) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(value),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  );
}
