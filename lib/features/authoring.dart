import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';

class NewCoursePage extends StatefulWidget {
  const NewCoursePage({super.key, required this.api});
  final Api api;
  @override
  State<NewCoursePage> createState() => _NewCoursePageState();
}

class _NewCoursePageState extends State<NewCoursePage> {
  final title = TextEditingController(),
      description = TextEditingController(),
      price = TextEditingController(text: '0');
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('كورس جديد')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'الكورس بيتحفظ كمسودة، وتقدر تضيف الأقسام والدروس قبل النشر.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: title,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'اسم الكورس'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: description,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'وصف الكورس'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر بالجنيه'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final amount = int.tryParse(price.text);
                  if (title.text.trim().isEmpty ||
                      amount == null ||
                      amount < 0) {
                    toast(context, 'اكتب اسم الكورس وسعراً صحيحاً');
                    return;
                  }
                  setState(() => busy = true);
                  await action(context, () async {
                    final result = obj(
                      await widget.api.call(
                        'POST',
                        '/courses',
                        data: {
                          'title': title.text.trim(),
                          'description': description.text.trim(),
                          'teacherId': widget.api.actorId,
                          'audience': 'Open',
                          'kind': 'Course',
                          'price': amount,
                          'accessDuration': 'Month',
                        },
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CoursePage(
                            api: widget.api,
                            id: '${result['id']}',
                          ),
                        ),
                      );
                    }
                  });
                  if (mounted) setState(() => busy = false);
                },
          child: const Text('إنشاء المسودة'),
        ),
      ],
    ),
  );
}

class NewQuizPage extends StatefulWidget {
  const NewQuizPage({super.key, required this.api, required this.section});
  final Api api;
  final Json section;
  @override
  State<NewQuizPage> createState() => _NewQuizPageState();
}

class _NewQuizPageState extends State<NewQuizPage> {
  final title = TextEditingController(),
      minutes = TextEditingController(text: '30'),
      attempts = TextEditingController(text: '1');
  final Map<String, Json> selected = {};
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    attempts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة امتحان من بنك الأسئلة')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'عنوان الامتحان'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المدة بالدقائق',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: attempts,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد المحاولات',
                      ),
                    ),
                  ),
                ],
              ),
              Text('تم اختيار ${selected.length} سؤال، درجة لكل سؤال'),
            ],
          ),
        ),
        Expanded(
          child: PagedList(
            api: widget.api,
            path: '/questions',
            item: (q) => Card(
              child: CheckboxListTile(
                title: Text('${q['text'] ?? q['title'] ?? ''}'),
                subtitle: Text('${q['type'] ?? ''}'),
                value: selected.containsKey('${q['id']}'),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        v == true
                            ? selected['${q['id']}'] = q
                            : selected.remove('${q['id']}');
                      }),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final duration = int.tryParse(minutes.text),
                          limit = int.tryParse(attempts.text);
                      if (title.text.trim().isEmpty ||
                          selected.isEmpty ||
                          duration == null ||
                          duration < 1 ||
                          duration > 240 ||
                          limit == null ||
                          limit < 0 ||
                          limit > 100) {
                        toast(
                          context,
                          'راجع العنوان والمدة والمحاولات واختار سؤالاً على الأقل',
                        );
                        return;
                      }
                      setState(() => busy = true);
                      await action(context, () async {
                        final quiz = obj(
                          await widget.api.call(
                            'POST',
                            '/course-quizzes',
                            data: {
                              'title': title.text.trim(),
                              'timeLimitMinutes': duration,
                              'attemptsAllowed': limit,
                              'passPercent': 50,
                              'showAnswers': 'Immediately',
                              'questions': selected.keys
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => {
                                      'questionId': e.value,
                                      'order': e.key,
                                      'marks': 1,
                                    },
                                  )
                                  .toList(),
                            },
                          ),
                        );
                        await widget.api.call(
                          'POST',
                          '/sections/${widget.section['id']}/lessons',
                          headers: versionHeader(widget.section),
                          data: {
                            'title': title.text.trim(),
                            'type': 'Quiz',
                            'quizId': quiz['id'],
                          },
                        );
                        if (context.mounted) Navigator.pop(context);
                      });
                      if (mounted) setState(() => busy = false);
                    },
              child: const Text('إنشاء الامتحان وربطه بالكورس'),
            ),
          ),
        ),
      ],
    ),
  );
}
