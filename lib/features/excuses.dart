import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_icons.dart';
import '../core/brand.dart';
import '../core/widgets.dart';

String excuseState(dynamic s) =>
    const {
      'Pending': 'قيد المراجعة',
      'Approved': 'مقبول',
      'Rejected': 'مرفوض',
      'Withdrawn': 'مسحوب',
    }[s] ??
    'غير محدد';

class ExcusesPage extends StatefulWidget {
  const ExcusesPage({super.key, required this.api, this.studentId});
  final Api api;
  final String? studentId;
  @override
  State<ExcusesPage> createState() => _ExcusesPageState();
}

class _ExcusesPageState extends State<ExcusesPage> {
  String status = 'Pending';
  int revision = 0;
  final Set<String> busy = {};
  final Map<String, Future<dynamic>> students = {};
  bool get guardian => widget.api.guardian;
  Future<void> edit({Json? existing, Json? session}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExcuseEditor(
          api: widget.api,
          studentId: widget.studentId!,
          existing: existing,
          session: session,
        ),
      ),
    );
    if (saved == true && mounted) setState(() => revision++);
  }

  Future<void> pickSession() async {
    final session = await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('اختر حصة العذر')),
          body: PagedList(
            api: widget.api,
            path: '/portal/students/${widget.studentId}/sessions',
            item: (s) => ListTile(
              title: Text('${s['topic'] ?? 'حصة دراسية'}'),
              subtitle: Text(when(s['startsAtUtc'])),
              enabled: !['Cancelled', 'Postponed'].contains(s['status']),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: () => Navigator.pop(context, s),
            ),
          ),
        ),
      ),
    );
    if (session != null && mounted) await edit(session: session);
  }

  Future<void> decide(Json e, String decision) async {
    final id = '${e['id']}';
    final title = guardian
        ? 'سحب العذر المعلّق؟'
        : decision == 'approve'
        ? 'قبول العذر وتحديث الغياب المرتبط به؟'
        : 'رفض هذا العذر؟';
    if (!await confirm(context, title) || !mounted) return;
    setState(() => busy.add(id));
    await action(context, () async {
      await widget.api.call(
        guardian ? 'DELETE' : 'POST',
        guardian ? '/portal/excuses/$id' : '/excuses/$id/$decision',
      );
      if (mounted) setState(() => revision++);
    }, success: guardian ? 'تم سحب العذر' : 'تم حفظ القرار');
    if (mounted) setState(() => busy.remove(id));
  }

  Widget studentName(Json e) {
    final id = '${e['studentId']}';
    return FutureBuilder<dynamic>(
      future: students.putIfAbsent(id, () => widget.api.get('/students/$id')),
      builder: (context, s) => Text(
        s.hasData ? label(obj(s.data)) : 'طلب عذر غياب',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('أعذار الغياب'),
      actions: [
        if (guardian)
          IconButton(
            tooltip: 'تقديم عذر',
            onPressed: pickSession,
            icon: const Icon(AppIcons.add),
          ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            guardian
                ? 'قدم عذرًا لحصة محددة وتابع قرار السنتر. طلب التعويض لا يعني تأكيد حصة بديلة.'
                : 'راجع أعذار طلابك المرتبطة بحصصك. أعذار اليوم غير المرتبطة بحصة تراجعها إدارة السنتر.',
          ),
        ),
        if (!guardian)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Pending', 'Approved', 'Rejected', 'All']
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(s == 'All' ? 'الكل' : excuseState(s)),
                        selected: status == s,
                        onSelected: (_) => setState(() => status = s),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(
          child: PagedList(
            key: ValueKey('$revision-$status'),
            api: widget.api,
            path: guardian
                ? '/portal/students/${widget.studentId}/excuses'
                : '/excuses',
            query: guardian ? {} : {'status': status},
            item: (e) {
              final pending = e['status'] == 'Pending';
              final own = '${e['requestedById']}' == widget.api.actorId;
              final canDecide =
                  !guardian &&
                  pending &&
                  (widget.api.role != 'Teacher' || e['sessionId'] != null);
              final saving = busy.contains('${e['id']}');
              return BrandCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!guardian) studentName(e),
                      Text(when(e['dateUtc'])),
                      const SizedBox(height: 8),
                      Text('${e['reason'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('الحالة: ${excuseState(e['status'])}'),
                      if (e['wantsMakeup'] == true)
                        const Text('يوجد طلب تعويض'),
                      if (saving) const LinearProgressIndicator(),
                      if (guardian && own && pending)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : () => edit(existing: e),
                              child: const Text('تعديل العذر'),
                            ),
                            TextButton(
                              onPressed: saving ? null : () => decide(e, ''),
                              child: const Text('سحب العذر'),
                            ),
                          ],
                        ),
                      if (canDecide)
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: saving
                                  ? null
                                  : () => decide(e, 'approve'),
                              child: const Text('قبول'),
                            ),
                            OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => decide(e, 'reject'),
                              child: const Text('رفض'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ExcuseEditor extends StatefulWidget {
  const ExcuseEditor({
    super.key,
    required this.api,
    required this.studentId,
    this.existing,
    this.session,
  });
  final Api api;
  final String studentId;
  final Json? existing, session;
  @override
  State<ExcuseEditor> createState() => _ExcuseEditorState();
}

class _ExcuseEditorState extends State<ExcuseEditor> {
  final form = GlobalKey<FormState>();
  late final reason = TextEditingController(text: widget.existing?['reason']);
  late bool makeup = widget.existing?['wantsMakeup'] == true;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'تقديم عذر غياب' : 'تعديل العذر'),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              when(
                widget.existing?['dateUtc'] ?? widget.session?['startsAtUtc'],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reason,
              enabled: !busy,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'سبب الغياب'),
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? 'اكتب سببًا من ٥ أحرف على الأقل'
                  : null,
            ),
            SwitchListTile(
              value: makeup,
              onChanged: busy ? null : (v) => setState(() => makeup = v),
              title: const Text('أرغب في تعويض الحصة'),
              subtitle: const Text('يخضع لموافقة السنتر وتوفر موعد مناسب'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'جارٍ الإرسال…' : 'إرسال العذر'),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!widget.api.guardian) {
        throw ApiFailure('هذا الإجراء متاح لولي الأمر فقط.');
      }
      final date = DateTime.tryParse(
        '${widget.existing?['dateUtc'] ?? widget.session?['startsAtUtc']}',
      );
      if (date == null) throw ApiFailure('تعذر تحديد تاريخ الحصة. أعد فتحها.');
      await widget.api.call(
        widget.existing == null ? 'POST' : 'PUT',
        widget.existing == null
            ? '/portal/students/${widget.studentId}/excuses'
            : '/portal/excuses/${widget.existing!['id']}',
        data: {
          'sessionId': widget.existing?['sessionId'] ?? widget.session?['id'],
          'dateUtc': date.toUtc().toIso8601String(),
          'reason': reason.text.trim(),
          'wantsMakeup': makeup,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
