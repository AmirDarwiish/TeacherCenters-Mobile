import '../core/brand.dart';
import '../core/app_icons.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import '../core/session_schedule.dart';
import 'session_detail.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => PageViewList(
    api: api,
    path: '/groups',
    title: 'مجموعاتي',
    item: (g) => BrandCard(
      child: ListTile(
        leading: const Icon(AppIcons.groupsRounded),
        title: Text(label(g)),
        subtitle: Text('${g['subject'] ?? ''} · ${g['grade'] ?? ''}'),
        trailing: const Icon(AppIcons.chevronLeft),
        onTap: () => open(context, GroupPage(api: api, group: g)),
      ),
    ),
  );
}

class GroupPage extends StatelessWidget {
  const GroupPage({super.key, required this.api, required this.group});
  final Api api;
  final Json group;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: Text(label(group)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DetailFields({
          for (final key in [
            'name',
            'subject',
            'grade',
            'status',
            'capacity',
            'monthlyPrice',
          ])
            if (group[key] != null) key: group[key],
        }),
        FilledButton.tonalIcon(
          onPressed: () => open(
            context,
            SessionsPage(api: api, groupId: '${group['id']}', standalone: true),
          ),
          icon: const Icon(AppIcons.calendarMonth),
          label: const Text('حصص المجموعة'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => open(
            context,
            NewSessionPage(api: api, groupId: '${group['id']}'),
          ),
          icon: const Icon(AppIcons.add),
          label: const Text('إضافة حصة'),
        ),
        const SizedBox(height: 20),
        Text('طلاب المجموعة', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 480,
          child: PagedList(
            api: api,
            path: '/groups/${group['id']}/students',
            item: (s) => BrandCard(
              child: ListTile(
                title: Text(label(s)),
                subtitle: Text('${s['code'] ?? ''}'),
                onTap: () => open(context, StudentDetail(api: api, student: s)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class StudentDetail extends StatelessWidget {
  const StudentDetail({super.key, required this.api, required this.student});
  final Api api;
  final Json student;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: Text(label(student)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DetailFields(student),
        ListTile(
          title: const Text('سجل الحضور'),
          trailing: const Icon(AppIcons.chevronLeft),
          onTap: () => open(
            context,
            PageViewList(
              api: api,
              path: '/students/${student['id']}/attendance',
              title: 'سجل الحضور',
              item: (a) => BrandCard(
                child: ListTile(
                  title: Text('${a['status'] ?? ''}'),
                  subtitle: Text(when(a['startsAtUtc'] ?? a['recordedAtUtc'])),
                ),
              ),
            ),
          ),
        ),
        ListTile(
          title: const Text('الدرجات'),
          trailing: const Icon(AppIcons.chevronLeft),
          onTap: () => open(
            context,
            PageViewList(
              api: api,
              path: '/students/${student['id']}/grades',
              title: 'الدرجات',
              item: (a) => BrandCard(child: DetailFields(a)),
            ),
          ),
        ),
      ],
    ),
  );
}

class SessionsPage extends StatefulWidget {
  const SessionsPage({
    super.key,
    required this.api,
    this.groupId,
    this.standalone = false,
  });
  final Api api;
  final String? groupId;
  final bool standalone;
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  DateTime start = cairoDate(DateTime.now()).subtract(const Duration(days: 7));
  DateTime end = cairoDate(DateTime.now()).add(const Duration(days: 30));
  String? studentId;
  Future<dynamic> load() async {
    if (widget.api.student && studentId == null) {
      final me = obj(await widget.api.get('/portal/me'));
      final list = rows(me['students']);
      if (list.isEmpty) throw ApiFailure('لا يوجد طالب نشط مرتبط بالحساب.');
      studentId = widget.api.portalStudentId ?? '${list.first['id']}';
    }
    return loadSessionRange(
      widget.api,
      studentId: studentId,
      groupId: widget.groupId,
      from: cairoMidnightUtc(start),
      to: cairoMidnightUtc(DateTime(end.year, end.month, end.day + 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(AppIcons.dateRange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${start.day}/${start.month} — ${end.day}/${end.month}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                    initialDateRange: DateTimeRange(start: start, end: end),
                  );
                  if (range != null) {
                    setState(() {
                      start = range.start;
                      end = range.end;
                    });
                  }
                },
                child: const Text('الفترة'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncPanel(
            key: ValueKey(
              '$start$end${widget.groupId}${widget.api.portalStudentId}',
            ),
            load: load,
            changes: widget.api.live.events.where(
              (e) => [
                'AttendanceChanged',
                'CheckInChanged',
                'Reconnected',
              ].contains(e),
            ),
            builder: (data, refresh) => ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (rows(data).isEmpty)
                  const Empty(text: 'مفيش حصص في الفترة دي.'),
                for (final s in rows(data))
                  BrandCard(
                    child: ListTile(
                      leading: Icon(
                        widget.api.student
                            ? AppIcons.eventOutlined
                            : AppIcons.factCheckOutlined,
                      ),
                      title: Text(
                        '${s['topic'] ?? s['groupName'] ?? 'حصة دراسية'}',
                      ),
                      subtitle: Text(
                        '${when(s['startsAtUtc'])}\n${s['hallName'] ?? ''} · ${sessionStatus(s['effectiveStatus'] ?? s['status'])}${s['attendance'] == null ? '' : '\nالحضور: ${attendanceStatus(s['attendance'])}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(AppIcons.chevronLeft),
                      onTap: () => open(
                        context,
                        widget.api.student
                            ? StudentSessionPage(
                                api: widget.api,
                                studentId: studentId!,
                                session: s,
                              )
                            : AttendancePage(api: widget.api, session: s),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    return widget.standalone
        ? Scaffold(
            appBar: AppBar(
              flexibleSpace: const BrandHeader(),
              title: const Text('الحصص'),
            ),
            body: body,
          )
        : body;
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.api, required this.session});
  final Api api;
  final Json session;
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

String attendanceState(dynamic value) =>
    const {
      'Present': 'حاضر',
      'Late': 'متأخر',
      'Absent': 'غائب',
      'Excused': 'بعذر',
    }[value] ??
    'لم يُسجّل';

class _AttendancePageState extends State<AttendancePage> {
  final Set<String> saving = {};
  bool all = false, closing = false;
  String search = '';
  int revision = 0;
  @override
  void initState() {
    super.initState();
    widget.api.live.watchSession('${widget.session['id']}');
  }

  @override
  void dispose() {
    widget.api.live.watchSession(null);
    super.dispose();
  }

  Future<void> record(Json student, Json? record, String status) async {
    final sid = '${student['id']}';
    if (saving.contains(sid) || closing) return;
    final reason = await requestReason(
      context,
      record == null
          ? 'تأكيد تسجيل ${attendanceState(status)}'
          : 'سبب تصحيح الحضور',
      initial: record == null && status != 'Excused'
          ? 'تسجيل يدوي بواسطة المدرس'
          : null,
    );
    if (reason == null || !mounted) return;
    setState(() => saving.add(sid));
    await action(context, () async {
      await widget.api.call(
        record == null ? 'POST' : 'PUT',
        record == null
            ? '/sessions/${widget.session['id']}/attendance/manual'
            : '/attendance/${record['id']}',
        data: {
          if (record == null) 'studentId': sid,
          'status': status,
          'reason': reason,
        },
      );
      if (mounted) setState(() => revision++);
    }, success: 'تم حفظ ${label(student)}: ${attendanceState(status)}');
    if (mounted) setState(() => saving.remove(sid));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('كشف الحضور')),
    body: AsyncPanel(
      key: ValueKey(revision),
      changes: widget.api.live.events.where(
        (e) => e == 'AttendanceChanged' || e == 'Reconnected',
      ),
      load: () =>
          widget.api.get('/sessions/${widget.session['id']}/attendance'),
      builder: (data, refresh) {
        final d = obj(data), timing = obj(d['timing']);
        final records = rows(d['records']);
        final roster = rows(d['roster']);
        final byStudent = {for (final r in records) '${r['studentId']}': r};
        final canRecord = timing['canRecordAttendance'] == true;
        final started = DateTime.tryParse(
          '${timing['startsAtUtc'] ?? widget.session['startsAtUtc']}',
        );
        final now =
            DateTime.tryParse('${timing['serverNowUtc']}') ??
            DateTime.now().toUtc();
        final closed =
            sessionClosed ||
            timing['effectiveStatus'] == 'Closed' ||
            widget.session['status'] == 'Closed';
        final pending =
            d['pendingCount'] as num? ?? rows(d['pendingStudents']).length;
        final visible = roster
            .where(
              (student) =>
                  (all || !byStudent.containsKey('${student['id']}')) &&
                  (label(student).contains(search) ||
                      '${student['code'] ?? ''}'.contains(search)),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              '${widget.session['groupName'] ?? widget.session['topic'] ?? 'الحصة'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(when(widget.session['startsAtUtc'])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('المسجلون ${arNumber(d['expected'])}')),
                Chip(label: Text('حاضر ${arNumber(d['present'])}')),
                Chip(label: Text('غائب ${arNumber(d['absent'])}')),
                Chip(label: Text('لم يُسجّل ${arNumber(pending)}')),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث باسم الطالب أو الكود',
                prefixIcon: Icon(AppIcons.searchRounded),
              ),
              onChanged: (v) => setState(() => search = v.trim()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('لم يُسجّل'),
                  selected: !all,
                  onSelected: (_) => setState(() => all = false),
                ),
                ChoiceChip(
                  label: const Text('كشف الكل'),
                  selected: all,
                  onSelected: (_) => setState(() => all = true),
                ),
              ],
            ),
            if (!canRecord)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'تسجيل حالة جديدة متاح خلال نافذة الحصة. تصحيح سجل موجود يخضع لصلاحيتك ومدة التعديل التي يحددها السنتر.',
                ),
              ),
            if (visible.isEmpty)
              Empty(
                text: search.isNotEmpty
                    ? 'لا توجد نتائج بهذا الاسم أو الكود'
                    : all
                    ? 'لا يوجد طلاب في هذا الكشف'
                    : 'تم تسجيل حالة جميع الطلاب في الكشف',
              ),
            for (final student in visible)
              Builder(
                builder: (context) {
                  final r = byStudent['${student['id']}'];
                  final disabled =
                      closing || saving.contains('${student['id']}');
                  return BrandCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label(student),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${student['code'] ?? ''} · ${attendanceState(r?['status'])}',
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  r == null
                                      ? AppIcons.menu
                                      : AppIcons.editOutlined,
                                ),
                                tooltip: r == null
                                    ? 'اختيار حالة الحضور'
                                    : 'تصحيح الحالة',
                                enabled: !disabled && (r != null || canRecord),
                                onSelected: (v) => record(student, r, v),
                                itemBuilder: (_) =>
                                    ['Present', 'Late', 'Absent', 'Excused']
                                        .map(
                                          (v) => PopupMenuItem(
                                            value: v,
                                            child: Text(attendanceState(v)),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                          if (r == null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: disabled || !canRecord
                                    ? null
                                    : () => record(student, null, 'Present'),
                                icon: const Icon(AppIcons.checkCircle),
                                label: const Text('تسجيل حاضر'),
                              ),
                            ),
                          if (saving.contains('${student['id']}'))
                            const LinearProgressIndicator(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (!closed && started != null && !now.isBefore(started))
              OutlinedButton(
                onPressed: closing || saving.isNotEmpty
                    ? null
                    : () async {
                        if (!await confirm(
                              context,
                              'إغلاق الحصة؟ لم تُسجّل حالة ${arNumber(pending)} طالب. سيُحتسب غيابهم أو عذرهم المعتمد وتوضع إشعارات الغياب في قائمة الإرسال.',
                            ) ||
                            !context.mounted) {
                          return;
                        }
                        setState(() => closing = true);
                        await action(context, () async {
                          await widget.api.call(
                            'POST',
                            '/sessions/${widget.session['id']}/close',
                            data: {'notifyAbsent': true},
                          );
                          if (mounted) {
                            setState(() {
                              sessionClosed = true;
                              all = true;
                              revision++;
                            });
                          }
                        }, success: 'تم إغلاق الحصة');
                        if (mounted) setState(() => closing = false);
                      },
                child: Text(
                  closing ? 'جارٍ الإغلاق…' : 'إغلاق الحصة واحتساب المتبقي',
                ),
              ),
          ],
        );
      },
    ),
  );
  bool sessionClosed = false;
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final c = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  // Controller is disposed after the dialog's exit animation.
  Future<void>.delayed(const Duration(milliseconds: 300), c.dispose);
  return result;
}

class NewSessionPage extends StatefulWidget {
  const NewSessionPage({super.key, required this.api, required this.groupId});
  final Api api;
  final String groupId;
  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage> {
  final topic = TextEditingController(),
      minutes = TextEditingController(text: '90');
  DateTime? date;
  bool busy = false;
  @override
  void dispose() {
    topic.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('إضافة حصة'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: topic,
          decoration: const InputDecoration(
            labelText: 'موضوع الحصة',
            hintText: 'مثال: مراجعة الفصل الأول',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'المدة بالدقائق',
            hintText: 'مثال: 60',
          ),
        ),
        ListTile(
          title: Text(
            date == null
                ? 'حدد الموعد بالتوقيت المحلي للجهاز'
                : when(date!.toIso8601String()),
          ),
          trailing: const Icon(AppIcons.calendarMonth),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime(2040),
            );
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (t != null) {
              setState(
                () => date = DateTime(d.year, d.month, d.day, t.hour, t.minute),
              );
            }
          },
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final duration = int.tryParse(minutes.text);
                  if (date == null ||
                      duration == null ||
                      duration < 15 ||
                      duration > 360) {
                    toast(context, 'حدد الموعد ومدة من 15 إلى 360 دقيقة');
                    return;
                  }
                  setState(() => busy = true);
                  await action(context, () async {
                    await widget.api.call(
                      'POST',
                      '/sessions',
                      data: {
                        'groupId': widget.groupId,
                        'startsAtUtc': date!.toUtc().toIso8601String(),
                        'durationMinutes': duration,
                        'kind': 'Regular',
                        'topic': topic.text.trim(),
                      },
                    );
                    if (context.mounted) Navigator.pop(context);
                  }, success: null);
                  if (mounted) setState(() => busy = false);
                },
          child: const Text('إنشاء الحصة'),
        ),
      ],
    ),
  );
}
