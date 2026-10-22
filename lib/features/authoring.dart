import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';

class NewCoursePage extends StatefulWidget {
  const NewCoursePage({super.key, required this.api, this.existing});
  final Api api;
  final Json? existing;
  @override
  State<NewCoursePage> createState() => _NewCoursePageState();
}

class _NewCoursePageState extends State<NewCoursePage> {
  final form = GlobalKey<FormState>();
  late final fields = <String, TextEditingController>{
    for (final key in [
      'title',
      'subtitle',
      'description',
      'price',
      'outcomes',
      'requirements',
      'targetAudience',
    ])
      key: TextEditingController(
        text: widget.existing?[key] is List
            ? (widget.existing![key] as List).join('\n')
            : key == 'price'
            ? '${(widget.existing?[key] as num? ?? 0).toInt()}'
            : '${widget.existing?[key] ?? ''}',
      ),
  };
  late String access = '${widget.existing?['accessDuration'] ?? 'Month'}';
  late String level = '${widget.existing?['level'] ?? 'All'}';
  late String kind = '${widget.existing?['kind'] ?? 'Course'}';
  bool busy = false;
  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget heading(String number, String title, String note) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 20),
    child: Row(
      children: [
        CircleAvatar(radius: 20, child: Text(number)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(note, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
  Widget field(
    String key,
    String title, {
    String? hint,
    int lines = 1,
    int max = 1000,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: fields[key],
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      maxLength: max,
      keyboardType: key == 'price' ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: title,
        hintText: hint,
        alignLabelWithHint: true,
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        if (key == 'price' &&
            (int.tryParse(v ?? '') == null || int.parse(v!) < 0)) {
          return 'اكتب سعراً صحيحاً بالجنيه';
        }
        return null;
      },
    ),
  );
  Widget select(
    String title,
    String value,
    Map<String, String> items,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: busy ? null : (v) => changed(v!),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'صمّم كورسك' : 'إعدادات الكورس'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          heading('١', 'أول انطباع يفرق', 'عرّف الطالب بالكورس وما سيحققه منه'),
          field('title', 'اسم الكورس', max: 150, required: true),
          field('subtitle', 'وصف مختصر', max: 300),
          field('description', 'عن الكورس بالتفصيل', lines: 4, max: 10000),
          heading('٢', 'قيمة واضحة للطالب', 'اكتب كل نقطة في سطر مستقل'),
          field(
            'outcomes',
            'ماذا سيتعلم الطالب؟',
            lines: 3,
            hint: 'مثال: حل مسائل الحركة بثقة',
            max: 10000,
          ),
          field('requirements', 'المتطلبات قبل البدء', lines: 2, max: 10000),
          field('targetAudience', 'لمن هذا الكورس؟', lines: 2, max: 10000),
          heading('٣', 'خطة الوصول', 'حدد النوع والمستوى والسعر بوضوح'),
          select('نوع المحتوى', kind, {
            'Course': 'كورس كامل',
            'FinalReview': 'مراجعة نهائية',
            'Revision': 'مراجعة',
          }, (v) => setState(() => kind = v)),
          select('المستوى', level, {
            'All': 'كل المستويات',
            'Beginner': 'مبتدئ',
            'Intermediate': 'متوسط',
            'Advanced': 'متقدم',
          }, (v) => setState(() => level = v)),
          select('مدة الوصول', access, {
            'Month': 'شهر من بدء الاشتراك',
            'ThreeMonths': 'ثلاثة شهور',
            'UntilTermEnd': 'حتى نهاية الترم الحالي',
            'Lifetime': 'بدون حد زمني',
          }, (v) => setState(() => access = v)),
          field(
            'price',
            'السعر بالجنيه — صفر للكورس المجاني',
            max: 9,
            required: true,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                widget.existing == null
                    ? 'سيُحفظ الكورس كمسودة في كتالوج الكورسات. أضف المنهج والغلاف وراجع المحتوى قبل النشر.'
                    : 'التعديل يحافظ على جمهور الكورس وارتباطاته الحالية. نشر المحتوى يُدار من مساحة الكورس.',
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: const Icon(Icons.check_rounded),
            label: Text(
              busy
                  ? 'جارٍ الحفظ…'
                  : widget.existing == null
                  ? 'إنشاء المسودة'
                  : 'حفظ التعديلات',
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    List<String> points(String key) => fields[key]!.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final key in ['outcomes', 'requirements', 'targetAudience']) {
      if (points(key).length > 100 || points(key).any((s) => s.length > 1000)) {
        toast(context, 'كل قائمة حتى 100 نقطة، وكل نقطة حتى 1000 حرف.');
        return;
      }
    }
    setState(() => busy = true);
    await action(context, () async {
      final old = widget.existing;
      final result = obj(
        await widget.api.call(
          old == null ? 'POST' : 'PUT',
          old == null ? '/courses' : '/courses/${old['id']}',
          headers: old == null ? {} : versionHeader(old),
          data: {
            'title': fields['title']!.text.trim(),
            'subtitle': fields['subtitle']!.text.trim(),
            'description': fields['description']!.text.trim(),
            'teacherId': old?['teacherId'] ?? widget.api.actorId,
            'audience': old?['audience'] ?? 'Open',
            if (old?['groupIds'] != null) 'groupIds': old!['groupIds'],
            if (old?['subjectId'] != null) 'subjectId': old!['subjectId'],
            if (old?['gradeLevelId'] != null)
              'gradeLevelId': old!['gradeLevelId'],
            if (old?['certificate'] != null) 'certificate': old!['certificate'],
            'kind': kind,
            'level': level,
            'price': int.parse(fields['price']!.text),
            'accessDuration': access,
            'outcomes': points('outcomes'),
            'requirements': points('requirements'),
            'targetAudience': points('targetAudience'),
          },
        ),
      );
      if (!mounted) return;
      if (old != null) {
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CoursePage(api: widget.api, id: '${result['id']}'),
        ),
      );
    });
    if (mounted) setState(() => busy = false);
  }
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
