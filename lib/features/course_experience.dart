import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import '../core/course_model.dart';
import 'courses.dart';
import 'authoring.dart';
import 'course_management.dart';
import 'payments.dart';
import 'teaching.dart' show askText;

class CourseCover extends StatelessWidget {
  const CourseCover({
    super.key,
    required this.api,
    required this.course,
    this.height = 170,
  });
  final Api api;
  final Json course;
  final double height;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xff123d3a), Color(0xff27766b)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -55,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 35),
              ),
            ),
          ),
          const Positioned(
            left: 28,
            bottom: 24,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 70,
              color: Color(0xffd4efbf),
            ),
          ),
          Positioned(
            right: 22,
            top: 24,
            child: Text(
              'TEACHER\nCENTERS',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
    if (course['coverUrl'] == null || '${course['coverUrl']}'.isEmpty) {
      return fallback;
    }
    return Image.network(
      api.resolveUrl('${course['coverUrl']}').toString(),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 1000,
      errorBuilder: (_, error, stack) => fallback,
    );
  }
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key, required this.api, this.catalog = false});
  final Api api;
  final bool catalog;
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  String search = '', filter = 'الكل';
  late bool catalog = widget.catalog;
  int revision = 0;
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void searchFor(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => search = value.trim().toLowerCase());
    });
  }

  Widget card(Json c) => CourseCard(
    api: widget.api,
    course: c,
    learning: widget.api.student && !catalog,
    onTap: () async {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CoursePage(api: widget.api, id: '${c['id']}'),
        ),
      );
      if (mounted) setState(() => revision++);
    },
  );

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          api.student
                              ? 'رحلتك تبدأ من هنا'
                              : 'محتوى يصنع الفرق',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          api.student
                              ? 'تعلم على مهلك. وكمل من مكان ما وقفت.'
                              : 'نظّم كورساتك وتابع تجربة طلابك.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (!api.student)
                    IconButton.filled(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewCoursePage(api: api),
                          ),
                        );
                        if (mounted) setState(() => revision++);
                      },
                      tooltip: 'كورس جديد',
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (api.student && !widget.catalog) ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('كورساتي'),
                        icon: Icon(Icons.bookmark_outline),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('اكتشف كورسات'),
                        icon: Icon(Icons.explore_outlined),
                      ),
                    ],
                    selected: {catalog},
                    onSelectionChanged: (v) => setState(() {
                      catalog = v.first;
                      filter = 'الكل';
                      search = '';
                    }),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                key: ValueKey(catalog),
                onChanged: searchFor,
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم الكورس أو المدرس',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      (api.student
                              ? (catalog
                                    ? ['الكل', 'مجاني', 'مدفوع']
                                    : ['الكل', 'قيد التعلم', 'مكتمل'])
                              : ['الكل', 'منشور', 'مسودة', 'مؤرشف'])
                          .map(
                            (v) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(v),
                                selected: filter == v,
                                onSelected: (_) => setState(() => filter = v),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: api.student
              ? AsyncPanel(
                  key: ValueKey('$catalog-$revision'),
                  load: () =>
                      api.get(catalog ? '/portal/catalog' : '/portal/courses'),
                  builder: (data, refresh) {
                    final courses = rows(data).where((c) {
                      final info = CourseInfo(c);
                      final match = '${label(c)} ${c['teacherName'] ?? ''}'
                          .toLowerCase()
                          .contains(search);
                      return match &&
                          switch (filter) {
                            'قيد التعلم' => info.progress < 100,
                            'مكتمل' => info.progress >= 100,
                            'مجاني' => (c['price'] as num? ?? 0) == 0,
                            'مدفوع' => (c['price'] as num? ?? 0) > 0,
                            _ => true,
                          };
                    }).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: courses.isEmpty ? 1 : courses.length + 1,
                      itemBuilder: (_, i) => courses.isEmpty
                          ? const Empty(
                              text:
                                  'لا توجد كورسات مطابقة. جرّب بحثاً مختلفاً أو غيّر الفلتر.',
                            )
                          : i == 0
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text('${courses.length} كورس في مساحتك'),
                            )
                          : card(courses[i - 1]),
                    );
                  },
                )
              : PagedList(
                  key: ValueKey(revision),
                  api: api,
                  path: '/courses',
                  query: {
                    'includeInactive': true,
                    if (search.isNotEmpty) 'search': search,
                    if (filter != 'الكل')
                      'status': {
                        'منشور': 'Published',
                        'مسودة': 'Draft',
                        'مؤرشف': 'Archived',
                      }[filter],
                  },
                  item: card,
                ),
        ),
      ],
    );
  }
}

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.api,
    required this.course,
    required this.learning,
    required this.onTap,
  });
  final Api api;
  final Json course;
  final bool learning;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = CourseInfo(course), colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CourseCover(api: api, course: course),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Chip(
                    side: BorderSide.none,
                    backgroundColor: colors.surface,
                    avatar: const Icon(Icons.auto_stories_outlined, size: 16),
                    label: Text(
                      api.student
                          ? '${c.lessonCount} درس'
                          : CourseInfo.statusName(course['status']),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${course['teacherName'] ?? 'فريق التدريس'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (learning) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.expired
                                ? 'انتهت صلاحية الوصول'
                                : c.progress >= 100
                                ? 'أحسنت! أكملت الكورس'
                                : 'تقدمك في الكورس',
                          ),
                        ),
                        Text(
                          '${c.progress.round()}٪',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: c.progress / 100,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.expired
                                ? 'راجع اشتراكك'
                                : c.progress > 0
                                ? 'استكمل التعلم'
                                : 'ابدأ رحلتك',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_back_rounded, size: 20),
                      ],
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (course['price'] as num? ?? 0) == 0
                                ? 'مجاني'
                                : '${course['price']} ج.م',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('${c.lessonCount} درس'),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_back_rounded, size: 20),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.api, required this.id});
  final Api api;
  final String id;
  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  int tab = 0;
  bool joining = false;
  Future<Json> load() async {
    final api = widget.api;
    final result = await Future.wait<dynamic>([
      api.get('${api.student ? '/portal' : ''}/courses/${widget.id}'),
      if (api.student) api.get('/portal/courses'),
    ]);
    return {
      'course': obj(result.first),
      'enrolled':
          api.student &&
          rows(result.last).any((c) => '${c['id']}' == widget.id),
    };
  }

  Future<void> lesson(Json l, VoidCallback refresh) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.api.student
            ? LessonPage(
                api: widget.api,
                id: '${l['id']}',
                position: (l['positionSeconds'] as num? ?? 0).toInt(),
              )
            : TeacherLessonPage(api: widget.api, lesson: l),
      ),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مساحة الكورس')),
    body: AsyncPanel(
      load: load,
      builder: (value, refresh) {
        final d = obj(value),
            c = obj(d['course']),
            info = CourseInfo(c),
            api = widget.api;
        final enrolled = d['enrolled'] == true;
        final canLearn = enrolled && !info.expired;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  CourseCover(api: api, course: c, height: 205),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                api.student
                                    ? 'مساحتك للتعلم'
                                    : CourseInfo.statusName(c['status']),
                              ),
                            ),
                            Chip(label: Text('${info.lessonCount} درس')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          info.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                        ),
                        if ('${c['subtitle'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('${c['subtitle']}'),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: const Icon(Icons.school_outlined),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${c['teacherName'] ?? 'فريق التدريس'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        if (enrolled) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'أنجزت ${c['completedCount'] ?? 0} من ${info.lessonCount} درس',
                                ),
                              ),
                              Text('${info.progress.round()}٪'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: info.progress / 100,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          if (c['accessEndsAt'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'صلاحية الوصول: ${when(c['accessEndsAt'])}',
                              ),
                            ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('المنهج')),
                              ButtonSegment(value: 1, label: Text('عن الكورس')),
                              ButtonSegment(value: 2, label: Text('المزيد')),
                            ],
                            selected: {tab},
                            onSelectionChanged: (v) =>
                                setState(() => tab = v.first),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (tab == 0) ...[
                          Text(
                            'خطتك للتعلم',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${info.sections.length} وحدات • ${info.lessonCount} درس',
                          ),
                          const SizedBox(height: 16),
                          if (info.sections.isEmpty)
                            const Empty(
                              text:
                                  'المنهج قيد الإعداد. سيظهر المحتوى هنا بمجرد إضافته.',
                            ),
                          for (final (index, section) in info.sections.indexed)
                            Card(
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                initiallyExpanded:
                                    index == 0 ||
                                    rows(section['lessons']).any(
                                      (l) => l['id'] == c['resumeLessonId'],
                                    ),
                                leading: CircleAvatar(
                                  radius: 18,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  label(section),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${rows(section['lessons']).length} دروس',
                                ),
                                children: [
                                  for (final l in rows(section['lessons']))
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 6,
                                          ),
                                      leading: Icon(
                                        l['status'] == 'Completed'
                                            ? Icons.check_circle_rounded
                                            : l['status'] == 'Locked'
                                            ? Icons.lock_outline_rounded
                                            : l['type'] == 'Video'
                                            ? Icons.play_circle_outline_rounded
                                            : l['type'] == 'Quiz'
                                            ? Icons.quiz_outlined
                                            : Icons.article_outlined,
                                        color: l['status'] == 'Completed'
                                            ? const Color(0xff21816b)
                                            : null,
                                      ),
                                      title: Text(label(l)),
                                      subtitle: Text(
                                        [
                                              CourseInfo.typeName(l['type']),
                                              CourseInfo.duration(
                                                l['durationSeconds'],
                                              ),
                                              if (l['isPreview'] == true)
                                                'معاينة مجانية',
                                            ]
                                            .where((s) => s.isNotEmpty)
                                            .join(' • '),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_left_rounded,
                                      ),
                                      onTap: l['status'] == 'Locked'
                                          ? () => toast(
                                              context,
                                              'اشترك في الكورس أو جدد صلاحية الوصول لفتح الدرس.',
                                            )
                                          : () => lesson(l, refresh),
                                    ),
                                  if (!api.student)
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Wrap(
                                        spacing: 8,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () async {
                                              await Navigator.push<void>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => NewLessonPage(
                                                    api: api,
                                                    section: section,
                                                  ),
                                                ),
                                              );
                                              if (mounted) refresh();
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('درس جديد'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () async {
                                              await Navigator.push<void>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => NewQuizPage(
                                                    api: api,
                                                    section: section,
                                                  ),
                                                ),
                                              );
                                              if (mounted) refresh();
                                            },
                                            icon: const Icon(
                                              Icons.quiz_outlined,
                                            ),
                                            label: const Text('اختبار'),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                        if (tab == 1) ...[
                          _section(
                            context,
                            'عن هذه الرحلة',
                            '${c['description'] ?? 'سيضيف المدرس وصف الكورس قريباً.'}',
                          ),
                          for (final (key, title) in [
                            ('outcomes', 'ماذا ستتعلم؟'),
                            ('requirements', 'قبل ما تبدأ'),
                            ('targetAudience', 'الكورس مناسب لمين؟'),
                          ])
                            if (c[key] is List &&
                                (c[key] as List).isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              for (final point in c[key] as List)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text('$point')),
                                    ],
                                  ),
                                ),
                            ],
                          const SizedBox(height: 22),
                          _section(
                            context,
                            'مدة الوصول',
                            CourseInfo.accessName(c['accessDuration']),
                          ),
                        ],
                        if (tab == 2) ...[
                          if (api.student && enrolled)
                            Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.workspace_premium_outlined,
                                ),
                                title: const Text('التقدم وشهادة الإتمام'),
                                subtitle: const Text(
                                  'راجع الشروط وتابع إنجازك',
                                ),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => open(
                                  context,
                                  CertificatePage(
                                    api: api,
                                    courseId: widget.id,
                                  ),
                                ),
                              ),
                            ),
                          if (!api.student) ...[
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.image_outlined),
                                title: const Text('غلاف الكورس'),
                                subtitle: const Text(
                                  'صورة واضحة تعبّر عن محتواك • حتى ٣ ميجابايت',
                                ),
                                trailing: const Icon(Icons.upload_outlined),
                                onTap: () => action(context, () async {
                                  await uploadCourseCover(api, c);
                                  if (mounted) refresh();
                                }),
                              ),
                            ),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.reorder_rounded),
                                title: const Text('تنظيم المنهج'),
                                subtitle: const Text(
                                  'رتّب الوحدات والدروس في مسار واضح',
                                ),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () async {
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CurriculumPage(api: api, course: c),
                                    ),
                                  );
                                  if (mounted) refresh();
                                },
                              ),
                            ),

                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.tune_rounded),
                                title: const Text('بيانات الكورس وخطة الوصول'),
                                subtitle: const Text(
                                  'الوصف والأهداف والمتطلبات والسعر',
                                ),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () async {
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          NewCoursePage(api: api, existing: c),
                                    ),
                                  );
                                  if (mounted) refresh();
                                },
                              ),
                            ),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.insights_rounded),
                                title: const Text('تقدم الطلاب'),
                                subtitle: const Text(
                                  'الإنجاز ومتوسط نتائج الاختبارات',
                                ),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => open(
                                  context,
                                  PageViewList(
                                    api: api,
                                    path: '/courses/${widget.id}/students',
                                    title: 'تقدم الطلاب',
                                    item: (s) => Card(
                                      child: ListTile(
                                        title: Text(label(s)),
                                        subtitle: Text(
                                          'أكمل ${s['completedLessons'] ?? 0} درس • متوسط الاختبارات ${s['quizAverage'] ?? '—'}',
                                        ),
                                        trailing: Text(
                                          '${s['progressPercent'] ?? 0}٪',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => action(context, () async {
                                final title = await askText(
                                  context,
                                  'اسم الوحدة الجديدة',
                                );
                                if (title == null || title.trim().isEmpty) {
                                  return;
                                }
                                await api.call(
                                  'POST',
                                  '/courses/${widget.id}/sections',
                                  data: {'title': title.trim()},
                                  headers: versionHeader(c),
                                );
                                refresh();
                              }),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة وحدة للمنهج'),
                            ),
                            if (c['status'] == 'Draft')
                              FilledButton.icon(
                                onPressed: () => action(context, () async {
                                  if (!await confirm(
                                    context,
                                    'نشر الكورس وإتاحته للطلاب؟',
                                  )) {
                                    return;
                                  }
                                  await api.call(
                                    'POST',
                                    '/courses/${widget.id}/publish',
                                    headers: versionHeader(c),
                                  );
                                  refresh();
                                }),
                                icon: const Icon(Icons.publish_outlined),
                                label: const Text('نشر الكورس'),
                              ),
                          ],
                          if (api.student && !enrolled)
                            _section(
                              context,
                              'اشتراكك',
                              'راجع المنهج والأهداف قبل الاشتراك. الدروس المتاحة للمعاينة تحمل علامة معاينة مجانية.',
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (api.student && !api.guardian)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              canLearn
                                  ? 'جاهز للخطوة الجاية؟'
                                  : info.expired
                                  ? 'انتهت صلاحية الوصول'
                                  : (c['price'] as num? ?? 0) == 0
                                  ? 'ابدأ مجاناً'
                                  : '${c['price']} ج.م',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              canLearn
                                  ? '${info.progress.round()}٪ من الرحلة'
                                  : CourseInfo.accessName(c['accessDuration']),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: FilledButton.icon(
                          icon: Icon(
                            canLearn
                                ? Icons.play_arrow_rounded
                                : Icons.arrow_back_rounded,
                          ),
                          label: Text(
                            joining
                                ? 'جارٍ الاشتراك…'
                                : canLearn
                                ? (info.progress > 0
                                      ? 'استكمل التعلم'
                                      : 'ابدأ التعلم')
                                : enrolled
                                ? 'راجع الاشتراك'
                                : 'اشترك الآن',
                          ),
                          onPressed: joining
                              ? null
                              : canLearn
                              ? (info.resume == null
                                    ? null
                                    : () => lesson(info.resume!, refresh))
                              : enrolled
                              ? () => toast(
                                  context,
                                  'تواصل مع السنتر لتجديد صلاحية الكورس.',
                                )
                              : () async {
                                  if ((c['price'] as num? ?? 0) > 0) {
                                    await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CheckoutPage(
                                          api: api,
                                          courseId: widget.id,
                                        ),
                                      ),
                                    );
                                    if (mounted) refresh();
                                    return;
                                  }
                                  setState(() => joining = true);
                                  await action(context, () async {
                                    await api.call(
                                      'POST',
                                      '/portal/courses/${widget.id}/purchase',
                                      data: {'method': 'Free'},
                                    );
                                    refresh();
                                  }, success: 'تم الاشتراك. رحلتك جاهزة!');
                                  if (mounted) setState(() => joining = false);
                                },
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
  Widget _section(BuildContext context, String title, String text) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      Text(text, style: const TextStyle(height: 1.8)),
    ],
  );
}
