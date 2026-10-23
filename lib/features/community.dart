import '../core/brand.dart';
import '../core/app_icons.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'teaching.dart';

class ThreadsPage extends StatelessWidget {
  const ThreadsPage({super.key, required this.api, this.embedded = false});
  final bool embedded;
  final Api api;
  @override
  Widget build(BuildContext context) {
    final list = PagedList(
      api: api,
      path: api.student ? '/portal/threads' : '/threads',
      item: (t) => BrandCard(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(AppIcons.chatBubbleOutline)),
          title: Text(label(t)),
          subtitle: Text(
            '${api.student ? t['teacherName'] : t['studentName']} · ${t['status']}',
          ),
          trailing: const Icon(AppIcons.chevronLeft),
          onTap: () => open(context, ConversationPage(api: api, thread: t)),
        ),
      ),
    );
    if (embedded) return list;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const BrandHeader(),
        title: const Text('الرسائل'),
      ),
      body: list,
    );
  }
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
            '${n['message'] ?? n['body'] ?? ''}\n${when(n['occurredAtUtc'] ?? n['createdAtUtc'])}',
          ),
          onTap: () => action(context, () async {
            await widget.api.call('POST', '/notifications/${n['id']}/read');
            setState(() => revision++);
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
                  decoration: const InputDecoration(labelText: 'حل الواجب'),
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
