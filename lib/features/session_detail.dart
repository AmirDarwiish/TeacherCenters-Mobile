import 'excuses.dart';
import '../core/brand.dart';
import '../core/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      'Postponed': 'مؤجلة',
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
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('تفاصيل الحصة'),
    ),
    body: AsyncPanel(
      load: load,
      changes: api.live.events.where(
        (event) => [
          'AttendanceChanged',
          'CheckInChanged',
          'Reconnected',
        ].contains(event),
      ),
      builder: (value, refresh) {
        final s = {...session, ...obj(value)},
            colors = Theme.of(context).colorScheme;
        final start = apiUtc(s['startsAtUtc']);
        final end =
            apiUtc(s['endsAtUtc']) ??
            start?.add(
              Duration(minutes: (s['durationMinutes'] as num? ?? 0).toInt()),
            );
        final status = s['effectiveStatus'] ?? s['status'];
        final cancelled = ['Cancelled', 'Canceled'].contains(status);
        final grades = rows(s['quizzes']);
        final duration = start != null && end != null
            ? end.difference(start).inMinutes
            : (s['durationMinutes'] as num? ?? 0).toInt();
        final attended = ['Present', 'Late'].contains(s['attendance']);
        final verification = obj(s['verification']);
        final pending = verification['status'] == 'PendingReview';
        final approved = verification['status'] == 'Approved';
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (api.guardian && !cancelled && status != 'Postponed')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  icon: const Icon(AppIcons.eventBusyOutlined),
                  label: const Text('تقديم عذر لهذه الحصة'),
                  onPressed: () => open(
                    context,
                    ExcuseEditor(api: api, studentId: studentId, session: s),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [colors.primaryContainer, colors.secondaryContainer],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          cancelled
                              ? AppIcons.eventBusyOutlined
                              : AppIcons.scheduleOutlined,
                          size: 18,
                        ),
                        label: Text(sessionStatus(status)),
                      ),
                      if (s['subjectName'] != null)
                        Chip(label: Text('${s['subjectName']}')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${s['topic'] ?? s['groupName'] ?? 'حصة دراسية'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  if (s['groupName'] != null) ...[
                    const SizedBox(height: 8),
                    Text('${s['groupName']}'),
                  ],
                  const SizedBox(height: 20),
                  Divider(color: colors.onSurface.withValues(alpha: .15)),
                  const SizedBox(height: 8),
                  Text(
                    start == null
                        ? 'موعد الحصة لم يُحدد بعد'
                        : DateFormat(
                            'EEEE، d MMMM y',
                            'ar',
                          ).format(cairoDate(start)),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      if (start != null)
                        Text(
                          'البداية ${arDigits(DateFormat('h:mm a', 'ar_EG').format(cairoDate(start)))}',
                        ),
                      if (end != null)
                        Text(
                          'النهاية ${arDigits(DateFormat('h:mm a', 'ar_EG').format(cairoDate(end)))}',
                        ),
                      if (duration > 0) Text('${arNumber(duration)} دقيقة'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _heading(
              context,
              'حضورك في الحصة',
              'تابع حالتك وسجّل وجودك عند الوصول للسنتر',
            ),
            BrandCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: attended || approved
                                ? context.brand.successTint
                                : pending
                                ? context.brand.warningTint
                                : context.brand.primaryTint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            attended || approved
                                ? AppIcons.checkCircleOutline
                                : AppIcons.factCheckOutlined,
                            color: attended || approved
                                ? context.brand.success
                                : pending
                                ? context.brand.warning
                                : context.brand.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pending
                                    ? 'طلب حضورك قيد المراجعة'
                                    : approved
                                    ? 'تم تأكيد حضورك'
                                    : attendanceStatus(s['attendance']),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cancelled
                                    ? 'الحصة ملغاة؛ راجع الجدول لأي موعد بديل.'
                                    : pending
                                    ? 'استلم السنتر طلبك. ستظهر حالة الحضور بعد المراجعة.'
                                    : attended || approved
                                    ? 'تم تسجيل هذه الحالة لدى السنتر.'
                                    : 'يُتاح التسجيل حسب مواعيد الحضور وإعدادات فرع الحصة.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (api.role == 'Student' &&
                        !cancelled &&
                        !pending &&
                        !approved &&
                        ![
                          'Present',
                          'Late',
                          'Excused',
                        ].contains(s['attendance'])) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '١ تحديد موقعك داخل النطاق المسموح\n٢ تصوير علامة مميزة بالكاميرا داخل التطبيق\n٣ إرسال الطلب ومتابعة تأكيد السنتر',
                        style: TextStyle(height: 1.9),
                      ),
                      const SizedBox(height: 16),
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
                        icon: const Icon(AppIcons.pinDropOutlined),
                        label: const Text('تسجيل حضوري بالموقع والصورة'),
                      ),
                    ],
                    if (!api.guardian &&
                        !cancelled &&
                        !pending &&
                        !approved &&
                        s['attendance'] == null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => open(context, StudentCard(api: api)),
                        icon: const Icon(AppIcons.qrCodeRounded),
                        label: const Text('اعرض بطاقة الحضور'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _heading(
              context,
              'الميعاد والمكان',
              'كل التفاصيل التي تحتاجها قبل الوصول',
            ),
            BrandCard(
              child: Column(
                children: [
                  if (s['teacherName'] != null)
                    _row(
                      AppIcons.schoolOutlined,
                      'المدرس',
                      '${s['teacherName']}',
                    ),
                  if (s['gradeName'] != null)
                    _row(
                      AppIcons.menuBookOutlined,
                      'الصف الدراسي',
                      '${s['gradeName']}',
                    ),
                  _row(
                    AppIcons.locationOnOutlined,
                    'الفرع',
                    '${s['branchName'] ?? 'لم يُحدد الفرع بعد'}',
                  ),
                  _row(
                    AppIcons.meetingRoomOutlined,
                    'القاعة',
                    '${s['hallName'] ?? 'لم يحدد السنتر قاعة للعرض بعد'}',
                  ),
                  if (s['branchAddress'] != null)
                    _row(
                      AppIcons.mapOutlined,
                      'العنوان',
                      '${s['branchAddress']}',
                    ),
                  _row(
                    AppIcons.calendarMonthOutlined,
                    'بداية الحصة',
                    when(s['startsAtUtc']),
                  ),
                  if (end != null)
                    _row(
                      AppIcons.scheduleOutlined,
                      'نهاية الحصة',
                      when(end.toIso8601String()),
                    ),
                ],
              ),
            ),
            if ('${s['description'] ?? ''}'.trim().isNotEmpty ||
                '${s['notes'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _heading(
                context,
                'عن الحصة',
                'موضوع الحصة والتعليمات المتاحة لك',
              ),
              BrandCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ('${s['description'] ?? ''}'.trim().isNotEmpty)
                        Text(
                          '${s['description']}',
                          style: const TextStyle(height: 1.7),
                        ),
                      if ('${s['notes'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${s['notes']}',
                          style: const TextStyle(height: 1.7),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _heading(
              context,
              'اختبارات الحصة ونتائجك',
              'النتائج المنشورة من المدرس لهذه الحصة',
            ),
            if (grades.isEmpty)
              const BrandCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(AppIcons.assignmentOutlined, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد نتائج منشورة حتى الآن',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'ستظهر اختبارات الحصة ودرجاتك هنا بعد نشرها من المدرس.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            for (final q in grades)
              BrandCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(AppIcons.quizOutlined, color: colors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label(q),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          q['score'] == null
                              ? 'لم تُنشر درجتك'
                              : '${arNumber(q['score'])} / ${arNumber(q['maxScore'])}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
  Widget _heading(BuildContext context, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
  Widget _row(IconData icon, String title, String value) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(value),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  );
}
