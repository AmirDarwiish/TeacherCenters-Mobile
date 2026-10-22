import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => PageViewList(
    api: api,
    path: '/groups',
    title: 'مجموعاتي',
    item: (g) => Card(
      child: ListTile(
        leading: const Icon(Icons.groups_rounded),
        title: Text(label(g)),
        subtitle: Text('${g['subject'] ?? ''} · ${g['grade'] ?? ''}'),
        trailing: const Icon(Icons.chevron_left),
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
    appBar: AppBar(title: Text(label(group))),
    body: ListView(
      padding: const EdgeInsets.all(20),
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
          icon: const Icon(Icons.calendar_month),
          label: const Text('حصص المجموعة'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => open(
            context,
            NewSessionPage(api: api, groupId: '${group['id']}'),
          ),
          icon: const Icon(Icons.add),
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
            item: (s) => Card(
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
    appBar: AppBar(title: Text(label(student))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DetailFields(student),
        ListTile(
          title: const Text('سجل الحضور'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => open(
            context,
            PageViewList(
              api: api,
              path: '/students/${student['id']}/attendance',
              title: 'سجل الحضور',
              item: (a) => Card(
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
          trailing: const Icon(Icons.chevron_left),
          onTap: () => open(
            context,
            PageViewList(
              api: api,
              path: '/students/${student['id']}/grades',
              title: 'الدرجات',
              item: (a) => Card(child: DetailFields(a)),
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
  DateTime start = DateTime.now().subtract(const Duration(days: 7));
  DateTime end = DateTime.now().add(const Duration(days: 30));
  String? studentId;
  Future<dynamic> load() async {
    if (widget.api.student && studentId == null) {
      final me = obj(await widget.api.get('/portal/me'));
      final list = rows(me['students']);
      if (list.isEmpty) throw ApiFailure('لا يوجد طالب نشط مرتبط بالحساب.');
      studentId = widget.api.portalStudentId ?? '${list.first['id']}';
    }
    return studentId;
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.date_range),
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
            load: load,
            builder: (_, refresh) => PagedList(
              key: ValueKey('$start$end$studentId'),
              api: widget.api,
              path: widget.api.student
                  ? '/portal/students/$studentId/sessions'
                  : '/sessions',
              query: {
                'from': start.toIso8601String().substring(0, 10),
                'to': end.toIso8601String().substring(0, 10),
                if (widget.groupId != null) 'groupId': widget.groupId,
              },
              item: (s) => Card(
                child: ListTile(
                  leading: Icon(
                    widget.api.student
                        ? Icons.event_outlined
                        : Icons.fact_check_outlined,
                  ),
                  title: Text(
                    '${s['topic'] ?? s['groupName'] ?? 'حصة دراسية'}',
                  ),
                  subtitle: Text(
                    '${when(s['startsAtUtc'])}\n${s['hallName'] ?? ''} · ${s['effectiveStatus'] ?? s['status'] ?? ''}${s['attendance'] == null ? '' : '\nالحضور: ${s['attendance']}'}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => open(
                    context,
                    widget.api.student
                        ? Scaffold(
                            appBar: AppBar(title: const Text('تفاصيل الحصة')),
                            body: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                Text(when(s['startsAtUtc'])),
                                DetailFields({
                                  'status': s['status'],
                                  'attendance': s['attendance'],
                                }),
                                ...rows(
                                  s['quizzes'],
                                ).map((q) => Card(child: DetailFields(q))),
                              ],
                            ),
                          )
                        : AttendancePage(api: widget.api, session: s),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return widget.standalone
        ? Scaffold(
            appBar: AppBar(title: const Text('الحصص')),
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

class _AttendancePageState extends State<AttendancePage> {
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

  final Set<String> saving = {};
  bool all = false;
  @override
  Widget build(BuildContext context) {
    final id = widget.session['id'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف الحضور'),
        actions: [
          IconButton(
            tooltip: 'تبديل الكشف',
            onPressed: () => setState(() => all = !all),
            icon: Icon(all ? Icons.pending_actions : Icons.list_alt),
          ),
        ],
      ),
      body: AsyncPanel(
        key: ValueKey(all),
        changes: widget.api.live.events.where(
          (e) => e == 'AttendanceChanged' || e == 'Reconnected',
        ),
        load: () =>
            widget.api.get('/sessions/$id/attendance${all ? '' : '/pending'}'),
        builder: (data, refresh) {
          final d = obj(data);
          final students = all
              ? rows(
                  data is List
                      ? data
                      : d['items'] ?? d['students'] ?? d['records'],
                )
              : rows(d['students']);
          final canRecord =
              (d['canRecordAttendance'] ??
                  widget.session['canRecordAttendance']) ==
              true;
          return ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                '${widget.session['topic'] ?? 'الحصة'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(when(widget.session['startsAtUtc'])),
              const SizedBox(height: 16),
              if (!canRecord)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'تسجيل الحضور متاح فقط خلال نافذة الحصة التي يحددها السنتر.',
                    ),
                  ),
                ),
              if (students.isEmpty)
                const Empty(text: 'لا يوجد طلاب في هذا الكشف'),
              ...students.map((s) {
                final sid = '${s['studentId'] ?? s['id']}';
                return Card(
                  child: ListTile(
                    title: Text(
                      '${s['fullName'] ?? s['studentName'] ?? label(s)}',
                    ),
                    subtitle: Text('${s['status'] ?? s['code'] ?? ''}'),
                    trailing: all
                        ? null
                        : PopupMenuButton<String>(
                            enabled: canRecord && !saving.contains(sid),
                            onSelected: (status) async {
                              String? reason;
                              if (status == 'Excused') {
                                reason = await askText(context, 'سبب العذر');
                              }
                              if (status == 'Excused' &&
                                  (reason == null || reason.trim().isEmpty)) {
                                return;
                              }
                              setState(() => saving.add(sid));
                              if (!context.mounted) return;
                              await action(context, () async {
                                await widget.api.call(
                                  'POST',
                                  '/sessions/$id/attendance/manual',
                                  data: {
                                    'studentId': sid,
                                    'status': status,
                                    'reason': ?reason,
                                  },
                                );
                                refresh();
                              });
                              if (mounted) setState(() => saving.remove(sid));
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'Present',
                                child: Text('حاضر'),
                              ),
                              PopupMenuItem(
                                value: 'Late',
                                child: Text('متأخر'),
                              ),
                              PopupMenuItem(
                                value: 'Absent',
                                child: Text('غائب'),
                              ),
                              PopupMenuItem(
                                value: 'Excused',
                                child: Text('بعذر'),
                              ),
                            ],
                          ),
                  ),
                );
              }),
              if (!all)
                OutlinedButton(
                  onPressed: () async {
                    if (await confirm(
                          context,
                          'إغلاق الحصة وتسجيل غياب الطلاب المتبقين؟',
                        ) &&
                        context.mounted) {
                      await action(context, () async {
                        await widget.api.call(
                          'POST',
                          '/sessions/$id/close',
                          data: {'notifyAbsent': true},
                        );
                        refresh();
                      }, success: 'تم إغلاق الحصة');
                    }
                  },
                  child: const Text('إغلاق الحصة'),
                ),
            ],
          );
        },
      ),
    );
  }
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
    appBar: AppBar(title: const Text('إضافة حصة')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: topic,
          decoration: const InputDecoration(labelText: 'موضوع الحصة'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المدة بالدقائق'),
        ),
        ListTile(
          title: Text(
            date == null
                ? 'حدد الموعد بالتوقيت المحلي للجهاز'
                : when(date!.toIso8601String()),
          ),
          trailing: const Icon(Icons.calendar_month),
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
