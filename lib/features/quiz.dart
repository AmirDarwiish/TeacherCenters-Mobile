import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'teaching.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.api,
    required this.quizId,
    this.legacy = false,
  });
  final Api api;
  final String quizId;
  final bool legacy;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  Json? attempt;
  Object? error;
  Timer? timer;
  bool submitting = false;
  final Map<String, Json> answers = {};
  final Set<String> dirty = {};
  final Map<String, Future<void>> queues = {};
  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    try {
      final d = obj(
        await widget.api.call(
          'POST',
          '/portal/${widget.legacy ? 'exams' : 'course-quizzes'}/${widget.quizId}/attempts',
        ),
      );
      if (widget.legacy) {
        d['attemptId'] = d['id'];
        d['expiresAt'] = d['expiresAtUtc'];
        d['questions'] = rows(d['questions'])
            .map((q) => {...q, 'questionId': q['id'], 'marks': q['points']})
            .toList();
        d['answers'] = {
          for (final a in rows(d['answers']))
            '${a['questionId']}': {
              'label': a['selectedLabel'],
              'text': a['essayText'],
            },
        };
      }
      if (!mounted) return;
      setState(() {
        attempt = d;
        obj(d['answers']).forEach((k, v) => answers[k] = obj(v));
        error = null;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (expired && !submitting) submit(automatic: true);
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  DateTime? get deadline => DateTime.tryParse('${attempt?['expiresAt']}');
  bool get expired => deadline != null && !deadline!.isAfter(DateTime.now());
  Future<void> save(String question, Json value) async {
    answers[question] = value;
    dirty.add(question);
    final previous = queues[question] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      try {
        await widget.api.call(
          'PUT',
          '/portal/attempts/${attempt!['attemptId']}/answers/$question',
          data: widget.legacy
              ? {
                  'selectedLabel': value['label'],
                  'essayText': value['text'],
                  'isFlagged': false,
                }
              : value,
        );
        if (identical(answers[question], value)) dirty.remove(question);
        if (mounted) setState(() => error = null);
      } catch (e) {
        if (mounted) setState(() => error = ApiFailure('الإجابة لم تتحفظ: $e'));
        rethrow;
      }
    });
    queues[question] = next;
    // Listener prevents unhandled asynchronous errors; the queue retains failure for submit.
    next.catchError((Object _) {});
  }

  Future<void> submit({bool automatic = false}) async {
    if (submitting || attempt == null) return;
    if (!automatic && !await confirm(context, 'تسليم الامتحان نهائيًا؟')) {
      return;
    }
    setState(() => submitting = true);
    try {
      if (!automatic) {
        for (final q in dirty.toList()) {
          await save(q, answers[q]!);
        }
        await Future.wait(queues.values);
        if (dirty.isNotEmpty) {
          throw ApiFailure('في إجابات لم تتحفظ. حاول حفظها قبل التسليم.');
        }
      }
      await widget.api.call(
        'POST',
        '/portal/attempts/${attempt!['attemptId']}/submit',
      );
      timer?.cancel();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ResultPage(
            api: widget.api,
            attemptId: '${attempt!['attemptId']}',
            legacy: widget.legacy,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e);
      if (automatic) timer?.cancel();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = rows(attempt?['questions']);
    final left = deadline?.difference(DateTime.now());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            await confirm(
              context,
              'الخروج مع الاحتفاظ بالإجابات المحفوظة؟ الوقت سيستمر.',
            ) &&
            context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: attempt == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$error'),
                          FilledButton(
                            onPressed: start,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (left != null)
                    Text(
                      'الوقت المتبقي: ${left.inMinutes.clamp(0, 999)}:${(left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  const Text(
                    'الإجابات تتحفظ عند الاختيار. في الأسئلة النصية اضغط حفظ الإجابة.',
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '$error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ...questions.asMap().entries.map((entry) {
                    final q = entry.value, id = '${q['questionId']}';
                    return QuestionEditor(
                      key: ValueKey(id),
                      question: q,
                      initial: answers[id] ?? {},
                      number: entry.key + 1,
                      enabled: !expired && !submitting,
                      onSave: (v) => save(id, v),
                    );
                  }),
                  FilledButton(
                    onPressed: submitting ? null : () => submit(),
                    child: Text(
                      submitting ? 'جاري التسليم…' : 'تسليم الامتحان',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class QuestionEditor extends StatefulWidget {
  const QuestionEditor({
    super.key,
    required this.question,
    required this.initial,
    required this.number,
    required this.enabled,
    required this.onSave,
  });
  final Json question, initial;
  final int number;
  final bool enabled;
  final Future<void> Function(Json) onSave;
  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  late Json answer = Map.of(widget.initial);
  late final text = TextEditingController(text: '${answer['text'] ?? ''}');
  late List<String> ordering =
      (answer['items'] as List? ?? widget.question['items'] as List? ?? [])
          .map((e) => '$e')
          .toList();
  final Map<String, String> matching = {};
  late final List<TextEditingController> blanks = List.generate(
    (widget.initial['blanks'] as List? ?? ['']).length,
    (i) => TextEditingController(
      text: '${(widget.initial['blanks'] as List? ?? [''])[i]}',
    ),
  );
  @override
  void initState() {
    super.initState();
    for (final p in rows(answer['pairs'])) {
      matching['${p['left']}'] = '${p['right']}';
    }
  }

  @override
  void dispose() {
    text.dispose();
    for (final c in blanks) {
      c.dispose();
    }
    super.dispose();
  }

  void send(Json value) {
    setState(() => answer = value);
    widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final type = q['type'];
    final options = rows(q['options']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.number}. ${q['text']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${q['marks']} درجة'),
            const SizedBox(height: 12),
            if (['MCQ', 'TrueFalse'].contains(type))
              ...options.map(
                (o) => ListTile(
                  leading: Icon(
                    answer['label'] == o['label']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text('${o['text'] ?? o['label']}'),
                  onTap: widget.enabled
                      ? () => send({'label': o['label']})
                      : null,
                ),
              ),
            if (type == 'MultiSelect')
              ...options.map(
                (o) => CheckboxListTile(
                  title: Text('${o['text'] ?? o['label']}'),
                  value: (answer['labels'] as List? ?? []).contains(o['label']),
                  onChanged: widget.enabled
                      ? (checked) {
                          final selected = List<String>.from(
                            answer['labels'] ?? [],
                          );
                          checked == true
                              ? selected.add('${o['label']}')
                              : selected.remove('${o['label']}');
                          send({'labels': selected});
                        }
                      : null,
                ),
              ),
            if (['Essay', 'Explain', 'ShortAnswer'].contains(type)) ...[
              TextField(
                controller: text,
                enabled: widget.enabled,
                maxLines: type == 'ShortAnswer' ? 2 : 5,
                decoration: const InputDecoration(labelText: 'إجابتك'),
              ),
              TextButton(
                onPressed: widget.enabled
                    ? () => send({'text': text.text})
                    : null,
                child: const Text('حفظ الإجابة'),
              ),
            ],
            if (type == 'Complete') ...[
              ...blanks.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: e.value,
                    enabled: widget.enabled,
                    decoration: InputDecoration(
                      labelText: 'الإجابة ${e.key + 1}',
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.enabled
                    ? () => setState(() => blanks.add(TextEditingController()))
                    : null,
                child: const Text('إضافة فراغ آخر'),
              ),
              TextButton(
                onPressed: widget.enabled
                    ? () => send({'blanks': blanks.map((c) => c.text).toList()})
                    : null,
                child: const Text('حفظ الإجابة'),
              ),
            ],
            if (type == 'Matching') ...[
              ...(obj(q['pairs'])['left'] as List? ?? []).map(
                (left) => DropdownButtonFormField<String>(
                  initialValue: matching['$left'],
                  decoration: InputDecoration(labelText: '$left'),
                  items: (obj(q['pairs'])['right'] as List? ?? [])
                      .map(
                        (right) => DropdownMenuItem(
                          value: '$right',
                          child: Text('$right'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.enabled
                      ? (v) {
                          setState(() => matching['$left'] = v!);
                        }
                      : null,
                ),
              ),
              TextButton(
                onPressed: widget.enabled
                    ? () => send({
                        'pairs': matching.entries
                            .map((e) => {'left': e.key, 'right': e.value})
                            .toList(),
                      })
                    : null,
                child: const Text('حفظ التوصيل'),
              ),
            ],
            if (type == 'Ordering') ...[
              ...ordering.asMap().entries.map(
                (e) => ListTile(
                  title: Text(e.value),
                  leading: Text('${e.key + 1}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: widget.enabled && e.key > 0
                            ? () => setState(() {
                                final v = ordering.removeAt(e.key);
                                ordering.insert(e.key - 1, v);
                              })
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        onPressed: widget.enabled && e.key < ordering.length - 1
                            ? () => setState(() {
                                final v = ordering.removeAt(e.key);
                                ordering.insert(e.key + 1, v);
                              })
                            : null,
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.enabled
                    ? () => send({'items': List.of(ordering)})
                    : null,
                child: const Text('حفظ الترتيب'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.api,
    required this.attemptId,
    this.teacher = false,
    this.legacy = false,
  });
  final Api api;
  final String attemptId;
  final bool teacher;
  final bool legacy;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نتيجة الاختبار')),
    body: AsyncPanel(
      load: () => api.get(
        teacher
            ? '/attempts/$attemptId'
            : '/portal/attempts/$attemptId${legacy ? '' : '/result'}',
      ),
      builder: (data, refresh) {
        final d = obj(data);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.insights, size: 64),
            DetailFields({
              for (final k in [
                'status',
                'score',
                'maxScore',
                'percent',
                'passed',
              ])
                k: d[k],
            }),
            ...rows(d['items']).map(
              (q) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${q['text']}'),
                      DetailFields({
                        for (final k in [
                          'marks',
                          'marksAwarded',
                          'teacherComment',
                          'explanation',
                        ])
                          k: q[k],
                      }),
                      if (q['yourAnswer'] != null)
                        Text('إجابتك: ${answerText(obj(q['yourAnswer']))}'),
                      if (q['correctAnswer'] != null)
                        Text(
                          'الإجابة الصحيحة: ${answerText(obj(q['correctAnswer']))}',
                        ),
                      if (teacher && ['Essay', 'Explain'].contains(q['type']))
                        TextButton(
                          onPressed: () => action(context, () async {
                            final marks = await askText(
                              context,
                              'الدرجة من ${q['marks']}',
                            );
                            final score = num.tryParse(marks ?? '');
                            if (score == null ||
                                score < 0 ||
                                score > (q['marks'] as num)) {
                              throw ApiFailure('أدخل درجة صحيحة');
                            }
                            if (!context.mounted) return;
                            final comment = await askText(
                              context,
                              'تعليق اختياري',
                            );
                            await api.call(
                              'POST',
                              '/attempts/$attemptId/answers/${q['questionId']}/grade',
                              data: {'marks': score, 'comment': comment},
                            );
                            refresh();
                          }),
                          child: const Text('تصحيح الإجابة'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

String answerText(Json a) => a.entries
    .where((e) => e.value != null)
    .map((e) => e.value is List ? (e.value as List).join('، ') : '${e.value}')
    .join(' · ');
