import '../core/brand.dart';
import '../core/app_icons.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'teaching.dart';
import 'push_settings.dart';
import 'teacher_notifications.dart';
import 'notification_detail.dart';
export 'scoped_chat.dart' show ThreadsPage;

class LegacyThreadsPage extends StatefulWidget {
  const LegacyThreadsPage({
    super.key,
    required this.api,
    this.embedded = false,
  });
  final bool embedded;
  final Api api;
  @override
  State<LegacyThreadsPage> createState() => _LegacyThreadsPageState();
}

class _LegacyThreadsPageState extends State<LegacyThreadsPage> {
  final int revision = 0;
  String? status;
  late final String? studentId = widget.api.portalStudentId;
  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final list = Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              for (final value in [null, 'Open', 'Closed'])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(
                      value == null
                          ? 'الكل'
                          : value == 'Open'
                          ? 'مفتوحة'
                          : 'مغلقة',
                    ),
                    selected: status == value,
                    onSelected: (_) => setState(() => status = value),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey('$revision-$status'),
            api: api,
            path: api.student ? '/portal/threads' : '/threads',
            query: {
              if (api.guardian && studentId != null) 'studentId': studentId,
              if (status != null) 'status': status,
            },
            item: (t) => BrandCard(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(AppIcons.chatBubbleOutline),
                ),
                title: Text(label(t)),
                subtitle: Text(
                  '${api.student ? t['teacherName'] : t['studentName']} · ${t['status'] == 'Closed' ? 'مغلقة' : 'مفتوحة'}',
                ),
                trailing: const Icon(AppIcons.chevronLeft),
                onTap: () =>
                    open(context, ConversationPage(api: api, thread: t)),
              ),
            ),
          ),
        ),
      ],
    );
    if (widget.embedded) return list;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const BrandHeader(),
        title: const Text('الرسائل'),
      ),
      body: list,
    );
  }
}

class NewConversationPage extends StatefulWidget {
  const NewConversationPage({
    super.key,
    required this.api,
    required this.studentId,
  });
  final Api api;
  final String studentId;
  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final form = GlobalKey<FormState>();
  final subject = TextEditingController();
  String? teacherId, error;
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    super.dispose();
  }

  Future<dynamic> teachers() async {
    try {
      return await widget.api.get(
        '/portal/students/${widget.studentId}/teachers',
      );
    } on ApiFailure catch (e) {
      if (e.status == 404) {
        throw ApiFailure(
          'بدء محادثة جديدة غير متاح حالياً. تواصل مع إدارة السنتر.',
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('محادثة جديدة')),
      body: AsyncPanel(
        load: teachers,
        builder: (data, refresh) {
          final choices = rows(data);
          return Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'تواصل مع مدرس من مجموعات الطالب النشطة. المحادثة تخص الطالب المختار.',
                ),
                const SizedBox(height: 16),
                if (choices.isEmpty)
                  const Empty(
                    text: 'لا يوجد مدرس مرتبط بمجموعة نشطة لهذا الطالب حالياً.',
                  )
                else ...[
                  for (final teacher in choices)
                    BrandCard(
                      child: ListTile(
                        leading: const Icon(AppIcons.schoolOutlined),
                        title: Text(label(teacher)),
                        trailing: Icon(
                          teacherId == '${teacher['id']}'
                              ? AppIcons.radioButtonChecked
                              : AppIcons.radioButtonOff,
                        ),
                        onTap: busy
                            ? null
                            : () => setState(
                                () => teacherId = '${teacher['id']}',
                              ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: subject,
                    enabled: !busy,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'موضوع المحادثة',
                      hintText: 'مثال: مراجعة الفصل الأول',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'اكتب موضوع المحادثة'
                        : null,
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: busy || teacherId == null
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              final thread = obj(
                                await widget.api.call(
                                  'POST',
                                  '/portal/threads',
                                  data: {
                                    'studentId': widget.studentId,
                                    'teacherId': teacherId,
                                    'subject': subject.text.trim(),
                                  },
                                ),
                              );
                              if (!context.mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ConversationPage(
                                    api: widget.api,
                                    thread: thread,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (mounted) setState(() => error = '$e');
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(busy ? 'جارٍ الإنشاء…' : 'بدء المحادثة'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.api, required this.thread});
  final Api api;
  final Json thread;
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  @override
  void initState() {
    super.initState();
    widget.api.live.watchThread('${widget.thread['id']}');
  }

  final message = TextEditingController();
  int revision = 0;
  bool sending = false;
  String get path =>
      '${widget.api.student ? '/portal/threads' : '/threads'}/${widget.thread['id']}';
  @override
  void dispose() {
    widget.api.live.watchThread(null);
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: Text(label(widget.thread)),
    ),
    body: Column(
      children: [
        Expanded(
          child: PagedList(
            key: ValueKey(revision),
            api: widget.api,
            path: '$path/messages',
            item: (m) {
              final own = '${m['senderId']}' == widget.api.actorId;
              return Align(
                alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: own
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['body']}'),
                      const SizedBox(height: 5),
                      Text(
                        when(m['createdAtUtc']),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.thread['status'] == 'Open')
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: message,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'إرسال',
                    onPressed: sending
                        ? null
                        : () async {
                            final text = message.text.trim();
                            if (text.isEmpty) return;
                            setState(() => sending = true);
                            await action(context, () async {
                              await widget.api.call(
                                'POST',
                                '$path/messages',
                                data: {'body': text},
                              );
                              message.clear();
                              if (mounted) setState(() => revision++);
                            });
                            if (mounted) setState(() => sending = false);
                          },
                    icon: const Icon(AppIcons.sendRounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.api});
  final Api api;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int revision = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('الإشعارات'),
      actions: [
        if (widget.api.role == 'Teacher')
          IconButton(
            tooltip: 'إرسال إشعار',
            icon: const Icon(AppIcons.notificationsActiveOutlined),
            onPressed: () =>
                open(context, TeacherNotificationsPage(api: widget.api)),
          ),
        IconButton(
          tooltip: 'إعداد الإشعارات',
          icon: const Icon(AppIcons.settingsOutlined),
          onPressed: () => open(context, PushSettingsPage(api: widget.api)),
        ),
        TextButton(
          onPressed: () => action(context, () async {
            await widget.api.call('POST', '/notifications/read-all');
            setState(() => revision++);
          }),
          child: const Text('قراءة الكل'),
        ),
      ],
    ),
    body: PagedList(
      key: ValueKey(revision),
      api: widget.api,
      path: '/notifications',
      item: (n) => BrandCard(
        child: ListTile(
          leading: Icon(
            n['isRead'] == true
                ? AppIcons.notificationsNone
                : AppIcons.notificationsActiveOutlined,
          ),
          title: Text(label(n)),
          subtitle: Text(
            '${n['message'] ?? n['body'] ?? ''}\n${when(n['createdAt'] ?? n['occurredAtUtc'] ?? n['createdAtUtc'])}',
          ),
          onTap: () => action(context, () async {
            await widget.api.call('POST', '/notifications/${n['id']}/read');
            if (!context.mounted) return;
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NotificationDetailPage(api: widget.api, id: '${n['id']}'),
              ),
            );
            if (mounted) setState(() => revision++);
          }),
        ),
      ),
    ),
  );
}

class AssignmentsPage extends StatelessWidget {
  const AssignmentsPage({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => PageViewList(
    api: api,
    path: api.student ? '/portal/assignments' : '/assignments',
    title: 'الواجبات',
    item: (a) => BrandCard(
      child: ListTile(
        leading: const Icon(AppIcons.assignmentOutlined),
        title: Text(label(a)),
        subtitle: Text(
          'التسليم: ${when(a['dueAtUtc'])}\n${a['effectiveStatus'] ?? a['status'] ?? ''}',
        ),
        onTap: () => open(context, AssignmentPage(api: api, assignment: a)),
      ),
    ),
  );
}

class AssignmentPage extends StatefulWidget {
  const AssignmentPage({
    super.key,
    required this.api,
    required this.assignment,
  });
  final Api api;
  final Json assignment;
  @override
  State<AssignmentPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<AssignmentPage> {
  final note = TextEditingController();
  bool busy = false;
  Json? submission;
  @override
  void initState() {
    super.initState();
    if (widget.api.student) load();
  }

  Future<void> load() async {
    try {
      final d = obj(
        await widget.api.get(
          '/portal/assignments/${widget.assignment['id']}/submission',
        ),
      );
      if (mounted) {
        setState(() {
          submission = d;
          note.text = '${d['note'] ?? ''}';
        });
      }
    } catch (e) {
      if (e is! ApiFailure || e.status != 404) {
        if (mounted) toast(context, e);
      }
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(flexibleSpace: const BrandHeader(), title: Text(label(a))),
      body: widget.api.student
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${a['description'] ?? ''}'),
                Text('آخر موعد: ${when(a['dueAtUtc'])}'),
                if (submission != null)
                  DetailFields({
                    for (final k in ['status', 'score', 'feedback'])
                      k: submission![k],
                  }),
                const SizedBox(height: 20),
                TextField(
                  controller: note,
                  enabled:
                      !busy &&
                      a['canSubmit'] == true &&
                      submission?['status'] != 'Graded',
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'حل الواجب',
                    hintText: 'اكتب إجابتك هنا',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      busy ||
                          a['canSubmit'] != true ||
                          submission?['status'] == 'Graded'
                      ? null
                      : () async {
                          if (note.text.trim().isEmpty) {
                            toast(context, 'اكتب حل الواجب');
                            return;
                          }
                          setState(() => busy = true);
                          await action(context, () async {
                            await widget.api.call(
                              'POST',
                              '/portal/assignments/${a['id']}/submission',
                              data: {'note': note.text.trim()},
                            );
                            await load();
                          }, success: 'تم حفظ التسليم');
                          if (mounted) setState(() => busy = false);
                        },
                  child: const Text('حفظ وتسليم'),
                ),
              ],
            )
          : PagedList(
              api: widget.api,
              path: '/assignments/${a['id']}/submissions',
              item: (s) => BrandCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s['studentName'] ?? s['fullName'] ?? ''}'),
                      Text('${s['note'] ?? ''}'),
                      DetailFields({
                        for (final k in ['score', 'status', 'feedback'])
                          k: s[k],
                      }),
                      TextButton(
                        onPressed: () => action(context, () async {
                          final input = await askText(
                            context,
                            'الدرجة من ${a['maxScore'] ?? '—'}',
                          );
                          if (input == null) return;
                          final score = num.tryParse(input);
                          if (score == null) {
                            throw ApiFailure('أدخل درجة صحيحة');
                          }
                          if (!context.mounted) return;
                          final feedback = await askText(
                            context,
                            'ملاحظة للطالب',
                          );
                          await widget.api.call(
                            'PUT',
                            '/submissions/${s['id']}/grade',
                            data: {'score': score, 'feedback': feedback},
                          );
                          if (context.mounted) {
                            toast(context, 'تم التصحيح. اسحب لتحديث القائمة.');
                          }
                        }),
                        child: const Text('تصحيح الواجب'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
