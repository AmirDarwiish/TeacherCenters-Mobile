import '../core/brand.dart';
import '../core/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';

String videoTime(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
String noteText(dynamic value) => '$value'
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
int? questionTime(dynamic value) {
  final match = RegExp(r'^\[عند (\d+):(\d{2})\]').firstMatch('$value');
  return match == null
      ? null
      : int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

/// Student-only tools. Notes remain private; questions are visible to course members.
class LessonDiscussion extends StatefulWidget {
  const LessonDiscussion({
    super.key,
    required this.api,
    required this.courseId,
    required this.lessonId,
    required this.position,
    required this.onSeek,
    this.onPause,
  });
  final Api api;
  final String courseId, lessonId;
  final ValueListenable<Duration> position;
  final ValueChanged<int> onSeek;
  final VoidCallback? onPause;
  @override
  State<LessonDiscussion> createState() => _LessonDiscussionState();
}

class _LessonDiscussionState extends State<LessonDiscussion> {
  bool notes = true, loading = false, more = false;
  int page = 1, generation = 0;
  List<Json> items = [];
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    final epoch = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final nextPage = append ? page + 1 : 1;
      final data = await widget.api.get(
        '/portal/courses/${widget.courseId}/${notes ? 'notes' : 'questions'}',
        query: notes
            ? null
            : {'lessonId': widget.lessonId, 'page': nextPage, 'pageSize': 20},
      );
      if (!mounted || epoch != generation) return;
      final next = rows(data)
          .where((item) => !notes || '${item['lessonId']}' == widget.lessonId)
          .toList();
      setState(() {
        items = append ? [...items, ...next] : next;
        page = nextPage;
        more =
            !notes &&
            items.length < (obj(data)['total'] as num? ?? items.length);
      });
    } catch (e) {
      if (mounted && epoch == generation) setState(() => error = e);
    } finally {
      if (mounted && epoch == generation) setState(() => loading = false);
    }
  }

  Future<void> compose({Json? existing}) async {
    widget.onPause?.call();
    final captured = widget.position.value.inSeconds;
    final text = TextEditingController(
      text: existing == null ? '' : noteText(existing['body']),
    );
    final title = TextEditingController();
    final form = GlobalKey<FormState>();
    var saving = false;
    String? failure;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => PopScope(
          canPop: !saving,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              24,
              22,
              MediaQuery.viewInsetsOf(sheet).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      notes
                          ? (existing == null
                                ? 'ملاحظة جديدة'
                                : 'تعديل الملاحظة')
                          : 'اسأل المدرس',
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notes
                          ? 'ملاحظتك خاصة بيك ومحفوظة عند ${videoTime(existing?['positionSeconds'] as int? ?? captured)}'
                          : 'سؤالك مرتبط بالدرس عند ${videoTime(captured)} ويظهر للمشتركين',
                    ),
                    const SizedBox(height: 18),
                    if (!notes)
                      TextFormField(
                        controller: title,
                        enabled: !saving,
                        maxLength: 170,
                        decoration: const InputDecoration(
                          labelText: 'عنوان السؤال',
                        ),
                        validator: (v) => v?.trim().isNotEmpty == true
                            ? null
                            : 'اكتب عنوان السؤال',
                      ),
                    TextFormField(
                      controller: text,
                      enabled: !saving,
                      minLines: 3,
                      maxLines: 7,
                      maxLength: notes ? 10000 : 4800,
                      decoration: InputDecoration(
                        labelText: notes ? 'اكتب ملاحظتك' : 'اشرح سؤالك',
                      ),
                      validator: (v) => v?.trim().isNotEmpty == true
                          ? null
                          : 'اكتب المحتوى أولاً',
                    ),
                    if (failure != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          failure!,
                          style: TextStyle(
                            color: Theme.of(sheet).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!form.currentState!.validate()) return;
                              update(() {
                                saving = true;
                                failure = null;
                              });
                              try {
                                await widget.api.call(
                                  existing == null ? 'POST' : 'PUT',
                                  existing != null
                                      ? '/portal/notes/${existing['id']}'
                                      : '/portal/courses/${widget.courseId}/${notes ? 'notes' : 'questions'}',
                                  data: notes
                                      ? {
                                          if (existing == null) ...{
                                            'lessonId': widget.lessonId,
                                            'positionSeconds': captured,
                                          },
                                          'body': text.text.trim(),
                                        }
                                      : {
                                          'title': title.text.trim(),
                                          'body':
                                              '[عند ${videoTime(captured)}]\n${text.text.trim()}',
                                          'lessonId': widget.lessonId,
                                        },
                                );
                                if (sheet.mounted) Navigator.pop(sheet, true);
                              } catch (e) {
                                if (sheet.mounted) {
                                  update(() {
                                    saving = false;
                                    failure = '$e';
                                  });
                                }
                              }
                            },
                      icon: const Icon(AppIcons.saveOutlined),
                      label: Text(
                        saving
                            ? 'جارٍ الحفظ…'
                            : notes
                            ? 'حفظ الملاحظة'
                            : 'إرسال السؤال',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Dispose after the closing animation has released its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
    title.dispose();
    if (saved == true && mounted) load();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 36),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: true,
            icon: Icon(AppIcons.editNoteRounded),
            label: Text('ملاحظاتي'),
          ),
          ButtonSegment(
            value: false,
            icon: Icon(AppIcons.questionAnswerOutlined),
            label: Text('أسئلة الدرس'),
          ),
        ],
        selected: {notes},
        onSelectionChanged: (values) {
          if (values.first == notes) return;
          setState(() {
            notes = values.first;
            items = [];
          });
          load();
        },
      ),
      const SizedBox(height: 14),
      ValueListenableBuilder<Duration>(
        valueListenable: widget.position,
        builder: (_, position, child) => OutlinedButton.icon(
          onPressed: () => compose(),
          icon: Icon(notes ? AppIcons.addRounded : AppIcons.chatBubbleOutline),
          label: Text(
            '${notes ? 'أضف ملاحظة' : 'اسأل المدرس'} عند ${videoTime(position.inSeconds)}',
          ),
        ),
      ),
      if (loading && items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (error != null)
        BrandCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('$error'),
                TextButton(
                  onPressed: () => load(),
                  child: const Text('حاول تاني'),
                ),
              ],
            ),
          ),
        ),
      if (!loading && error == null && items.isEmpty)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            notes
                ? 'دوّن الأفكار المهمة وارجع للحظة الشرح بضغطة.'
                : 'عندك سؤال في الشرح؟ اسأله هنا وتابع رد المدرس.',
            textAlign: TextAlign.center,
          ),
        ),
      for (final item in items)
        BrandCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (notes || questionTime(item['body']) != null)
                      ActionChip(
                        avatar: const Icon(AppIcons.playArrowRounded, size: 18),
                        label: Text(
                          videoTime(
                            notes
                                ? (item['positionSeconds'] as num).toInt()
                                : questionTime(item['body'])!,
                          ),
                        ),
                        onPressed: () => widget.onSeek(
                          notes
                              ? (item['positionSeconds'] as num).toInt()
                              : questionTime(item['body'])!,
                        ),
                      ),
                    const Spacer(),
                    if (notes)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            compose(existing: item);
                            return;
                          }
                          if (!await confirm(context, 'حذف الملاحظة؟') ||
                              !context.mounted) {
                            return;
                          }
                          await action(context, () async {
                            await widget.api.call(
                              'DELETE',
                              '/portal/notes/${item['id']}',
                            );
                            if (mounted) load();
                          });
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                  ],
                ),
                if (!notes)
                  Text(
                    label(item),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 8),
                Text(
                  noteText(item['body']),
                  style: const TextStyle(height: 1.7),
                ),
                if (!notes)
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonQuestionPage(
                            api: widget.api,
                            id: '${item['id']}',
                          ),
                        ),
                      );
                      if (mounted) load();
                    },
                    icon: const Icon(AppIcons.forumOutlined),
                    label: Text(
                      '${item['answersCount'] ?? 0} ردود • ${item['hasInstructorAnswer'] == true ? 'رد المدرس' : 'عرض المناقشة'}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (more)
        TextButton(
          onPressed: loading ? null : () => load(append: true),
          child: const Text('تحميل المزيد من الأسئلة'),
        ),
    ],
  );
}

class LessonQuestionPage extends StatefulWidget {
  const LessonQuestionPage({super.key, required this.api, required this.id});
  final Api api;
  final String id;
  @override
  State<LessonQuestionPage> createState() => _LessonQuestionPageState();
}

class _LessonQuestionPageState extends State<LessonQuestionPage> {
  final reply = TextEditingController();
  int revision = 0;
  bool busy = false;
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('مناقشة السؤال'),
    ),
    body: AsyncPanel(
      key: ValueKey(revision),
      load: () => widget.api.get('/portal/questions/${widget.id}'),
      builder: (data, refresh) {
        final question = obj(data);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              label(question),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            Text(noteText(question['body'])),
            const SizedBox(height: 20),
            for (final answer in rows(question['answers']))
              BrandCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${answer['authorName'] ?? ''}${answer['isInstructor'] == true ? ' • المدرس' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(noteText(answer['body'])),
                    ],
                  ),
                ),
              ),
            TextField(
              controller: reply,
              enabled: !busy,
              maxLength: 5000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'أضف ردك'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (reply.text.trim().isEmpty) return;
                      setState(() => busy = true);
                      await action(context, () async {
                        await widget.api.call(
                          'POST',
                          '/portal/questions/${widget.id}/answers',
                          data: {'body': reply.text.trim()},
                        );
                        reply.clear();
                        if (mounted) setState(() => revision++);
                      });
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(busy ? 'جارٍ الإرسال…' : 'إرسال الرد'),
            ),
          ],
        );
      },
    ),
  );
}
