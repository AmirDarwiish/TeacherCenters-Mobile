import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'quiz.dart';
import 'teaching.dart';
import 'payments.dart';
import 'uploads.dart';
import 'authoring.dart';

Future<void> launchResource(Api api, String value) async {
  final uri = api.resolveUrl(value);
  if (!['https', 'http'].contains(uri.scheme) ||
      uri.scheme != 'https' && uri.host != 'localhost') {
    throw ApiFailure('رابط غير صالح.');
  }
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw ApiFailure('تعذر فتح الملف.');
  }
}

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key, required this.api, this.catalog = false});
  final Api api;
  final bool catalog;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!api.student)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: () => open(context, NewCoursePage(api: api)),
            icon: const Icon(Icons.add),
            label: const Text('كورس جديد'),
          ),
        ),
      Expanded(
        child: PagedList(
          api: api,
          path: api.student
              ? (catalog ? '/portal/catalog' : '/portal/courses')
              : '/courses',
          item: (c) => Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  open(context, CoursePage(api: api, id: '${c['id']}')),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c['coverUrl'] != null)
                    Image.network(
                      api.resolveUrl('${c['coverUrl']}').toString(),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (_, e, s) => const SizedBox(
                        height: 80,
                        child: Center(
                          child: Icon(Icons.auto_stories, size: 40),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label(c),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${c['teacherName'] ?? ''} · ${c['lessonsCount'] ?? 0} درس',
                        ),
                        const SizedBox(height: 12),
                        if (api.student && !catalog) ...[
                          LinearProgressIndicator(
                            value: ((c['progressPercent'] as num? ?? 0) / 100)
                                .clamp(0, 1),
                          ),
                          const SizedBox(height: 6),
                          Text('أنجزت ${c['progressPercent'] ?? 0}%'),
                        ] else
                          Text(
                            '${c['status'] ?? ''} · ${c['price'] ?? 0} جنيه',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class CoursePage extends StatelessWidget {
  const CoursePage({super.key, required this.api, required this.id});
  final Api api;
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تفاصيل الكورس')),
    body: AsyncPanel(
      load: () => api.get('${api.student ? '/portal' : ''}/courses/$id'),
      builder: (data, refresh) {
        final c = obj(data), sections = rows(obj(data)['sections']);
        return ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(label(c), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${c['description'] ?? c['subtitle'] ?? ''}'),
            const SizedBox(height: 16),
            if (api.student) ...[
              FilledButton.tonalIcon(
                onPressed: () =>
                    open(context, CertificatePage(api: api, courseId: id)),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('الشهادة والتقدم'),
              ),
              if (c['audience'] == 'Open')
                TextButton(
                  onPressed: () =>
                      open(context, CheckoutPage(api: api, courseId: id)),
                  child: const Text('الاشتراك في الكورس'),
                ),
              if (c['teacherId'] != null)
                TextButton(
                  onPressed: () => action(context, () async {
                    final subject = await askText(context, 'عنوان المحادثة');
                    if (subject == null || subject.isEmpty) return;
                    final me = obj(await api.get('/portal/me'));
                    final students = rows(me['students']);
                    if (students.isEmpty) throw ApiFailure('لا يوجد طالب نشط');
                    await api.call(
                      'POST',
                      '/portal/threads',
                      data: {
                        'studentId': students.first['id'],
                        'teacherId': c['teacherId'],
                        'subject': subject,
                      },
                    );
                    if (context.mounted) {
                      toast(context, 'تم فتح المحادثة. تقدر تكمل من الرسائل.');
                    }
                  }),
                  child: const Text('تواصل مع المدرس'),
                ),
            ] else ...[
              FilledButton.tonal(
                onPressed: () => open(
                  context,
                  PageViewList(
                    api: api,
                    path: '/courses/$id/students',
                    title: 'تقدم الطلاب',
                    item: (s) => Card(
                      child: ListTile(
                        title: Text(label(s)),
                        subtitle: Text(
                          'التقدم ${s['progressPercent'] ?? 0}% · متوسط الامتحانات ${s['quizAverage'] ?? '—'}',
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('متابعة الطلاب'),
              ),
              OutlinedButton(
                onPressed: () => action(context, () async {
                  final title = await askText(context, 'عنوان القسم');
                  if (title == null || title.isEmpty) return;
                  await api.call(
                    'POST',
                    '/courses/$id/sections',
                    data: {'title': title},
                    headers: versionHeader(c),
                  );
                  refresh();
                }),
                child: const Text('إضافة قسم'),
              ),
              if (c['status'] == 'Draft')
                OutlinedButton(
                  onPressed: () => action(context, () async {
                    if (!await confirm(context, 'نشر الكورس للطلاب؟')) return;
                    await api.call(
                      'POST',
                      '/courses/$id/publish',
                      headers: versionHeader(c),
                    );
                    refresh();
                  }),
                  child: const Text('نشر الكورس'),
                ),
            ],
            const SizedBox(height: 20),
            Text('محتوى الكورس', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (sections.isEmpty) const Empty(text: 'لم تتم إضافة محتوى بعد'),
            ...sections.map(
              (section) => Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(label(section)),
                  children: [
                    ...rows(section['lessons']).map(
                      (l) => ListTile(
                        leading: Icon(
                          l['status'] == 'Locked'
                              ? Icons.lock_outline
                              : l['type'] == 'Video'
                              ? Icons.play_circle_outline
                              : l['type'] == 'Quiz'
                              ? Icons.quiz_outlined
                              : Icons.description_outlined,
                        ),
                        title: Text(label(l)),
                        subtitle: Text('${l['type']} · ${l['status'] ?? ''}'),
                        onTap: l['status'] == 'Locked'
                            ? () => toast(
                                context,
                                'الدرس مقفول. راجع صلاحية اشتراكك.',
                              )
                            : () => open(
                                context,
                                api.student
                                    ? LessonPage(
                                        api: api,
                                        id: '${l['id']}',
                                        position:
                                            (l['positionSeconds'] as num? ?? 0)
                                                .toInt(),
                                      )
                                    : TeacherLessonPage(api: api, lesson: l),
                              ),
                      ),
                    ),
                    if (!api.student)
                      TextButton.icon(
                        onPressed: () => open(
                          context,
                          NewQuizPage(api: api, section: section),
                        ),
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('إضافة امتحان'),
                      ),
                    if (!api.student)
                      TextButton.icon(
                        onPressed: () => open(
                          context,
                          NewLessonPage(api: api, section: section),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة درس'),
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
}

Json versionHeader(Json d) =>
    d['rowVersion'] == null ? {} : {'If-Match': '"${d['rowVersion']}"'};

class LessonPage extends StatelessWidget {
  const LessonPage({
    super.key,
    required this.api,
    required this.id,
    this.position = 0,
  });
  final Api api;
  final String id;
  final int position;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الدرس')),
    body: AsyncPanel(
      load: () => api.get('/portal/lessons/$id'),
      builder: (data, refresh) {
        final l = obj(data),
            v = obj(obj(data)['video']),
            q = obj(obj(data)['quiz']);
        return ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(label(l), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (v.isNotEmpty && !['youtube', 'vimeo'].contains(v['kind']))
              LessonPlayer(
                key: ValueKey(v['url']),
                api: api,
                id: id,
                video: v,
                position: position,
              )
            else if (v['url'] != null)
              FilledButton.icon(
                onPressed: () =>
                    action(context, () => launchResource(api, '${v['url']}')),
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح الفيديو'),
              ),
            if (l['body'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SelectableText('${l['body']}'),
              ),
            if (l['fileUrl'] != null)
              FilledButton.tonalIcon(
                onPressed: () => action(
                  context,
                  () => launchResource(api, '${l['fileUrl']}'),
                ),
                icon: const Icon(Icons.description),
                label: const Text('عرض الملف'),
              ),
            if (q['quizId'] != null) ...[
              Text('المحاولات المتبقية: ${q['attemptsLeft'] ?? 'غير محدودة'}'),
              FilledButton(
                onPressed: () =>
                    open(context, QuizPage(api: api, quizId: '${q['quizId']}')),
                child: const Text('بدء أو استكمال الاختبار'),
              ),
              if (q['lastAttemptId'] != null)
                TextButton(
                  onPressed: () => open(
                    context,
                    ResultPage(api: api, attemptId: '${q['lastAttemptId']}'),
                  ),
                  child: const Text('نتيجة آخر محاولة'),
                ),
            ],
            if (['Text', 'File'].contains(l['type']))
              FilledButton(
                onPressed: () => action(context, () async {
                  await api.call('POST', '/portal/lessons/$id/complete');
                  refresh();
                }, success: 'تم حفظ إكمال الدرس'),
                child: const Text('أنهيت الدرس'),
              ),
            if (l['nextLessonId'] != null)
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        LessonPage(api: api, id: '${l['nextLessonId']}'),
                  ),
                ),
                child: const Text('الدرس التالي'),
              ),
          ],
        );
      },
    ),
  );
}

class LessonPlayer extends StatefulWidget {
  const LessonPlayer({
    super.key,
    required this.api,
    required this.id,
    required this.video,
    this.position = 0,
  });
  final Api api;
  final String id;
  final Json video;
  final int position;
  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer>
    with WidgetsBindingObserver {
  late VideoPlayerController controller;
  Timer? timer;
  Object? error;
  bool sending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = VideoPlayerController.networkUrl(
      widget.api.resolveUrl('${widget.video['url']}'),
    );
    controller
        .initialize()
        .then((_) async {
          if (widget.position > 0) {
            await controller.seekTo(Duration(seconds: widget.position));
          }
          if (mounted) setState(() {});
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = e);
        });
    timer = Timer.periodic(const Duration(seconds: 15), (_) => save());
  }

  Future<void> save() async {
    if (sending || !controller.value.isInitialized) return;
    sending = true;
    try {
      await widget.api.call(
        'PUT',
        '/portal/lessons/${widget.id}/progress',
        data: {'positionSeconds': controller.value.position.inSeconds},
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = ApiFailure('تعذر حفظ التقدم. سيحاول التطبيق مرة أخرى.'),
        );
      }
    } finally {
      sending = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      controller.pause();
      save();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    save();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (error != null) Text('$error'),
      if (controller.value.isInitialized) ...[
        Stack(
          alignment: Alignment.topRight,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            if (widget.video['watermarkText'] != null)
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(6),
                child: Text(
                  '${widget.video['watermarkText']}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (_, value, child) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'رجوع 10 ثواني',
                onPressed: () => controller.seekTo(
                  value.position - const Duration(seconds: 10),
                ),
                icon: const Icon(Icons.replay_10),
              ),
              IconButton(
                tooltip: 'تشغيل أو إيقاف',
                onPressed: () {
                  value.isPlaying ? controller.pause() : controller.play();
                },
                icon: Icon(
                  value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                ),
                iconSize: 42,
              ),
              IconButton(
                tooltip: 'تقدم 10 ثواني',
                onPressed: () => controller.seekTo(
                  value.position + const Duration(seconds: 10),
                ),
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
        ),
      ] else if (error == null)
        const Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
    ],
  );
}

class CertificatePage extends StatelessWidget {
  const CertificatePage({super.key, required this.api, required this.courseId});
  final Api api;
  final String courseId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الشهادة')),
    body: AsyncPanel(
      load: () => api.get('/portal/courses/$courseId/certificate'),
      builder: (data, refresh) {
        final d = obj(data);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.workspace_premium, size: 80),
            DetailFields(d),
            if (d['eligible'] == true && d['certificate'] == null)
              FilledButton(
                onPressed: () => action(context, () async {
                  await api.call(
                    'POST',
                    '/portal/courses/$courseId/certificate',
                  );
                  refresh();
                }),
                child: const Text('إصدار الشهادة'),
              ),
            if (d['certificate'] != null) DetailFields(obj(d['certificate'])),
          ],
        );
      },
    ),
  );
}

class TeacherLessonPage extends StatelessWidget {
  const TeacherLessonPage({super.key, required this.api, required this.lesson});
  final Api api;
  final Json lesson;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(label(lesson))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('${lesson['body'] ?? ''}'),
        if (lesson['fileUrl'] != null)
          TextButton(
            onPressed: () => action(
              context,
              () => launchResource(api, '${lesson['fileUrl']}'),
            ),
            child: const Text('فتح الملف'),
          ),
        if (lesson['quizId'] != null)
          SizedBox(
            height: 500,
            child: PagedList(
              api: api,
              path: '/course-quizzes/${lesson['quizId']}/results',
              item: (s) => Card(
                child: ListTile(
                  title: Text(label(s)),
                  subtitle: Text(
                    '${s['bestPercent'] ?? '—'}% · ${s['status']}',
                  ),
                  onTap: s['lastAttemptId'] == null
                      ? null
                      : () => open(
                          context,
                          ResultPage(
                            api: api,
                            attemptId: '${s['lastAttemptId']}',
                            teacher: true,
                          ),
                        ),
                ),
              ),
            ),
          ),
        if (lesson['type'] == 'File')
          FilledButton.tonal(
            onPressed: () => open(
              context,
              UploadPage(api: api, lessonId: '${lesson['id']}', video: false),
            ),
            child: const Text('رفع ملف للدرس'),
          ),
        if (lesson['type'] == 'Video')
          FilledButton.tonal(
            onPressed: () => open(
              context,
              UploadPage(
                api: api,
                lessonId: '${lesson['id']}',
                video: true,
                lesson: lesson,
              ),
            ),
            child: const Text('رفع فيديو للدرس'),
          ),
      ],
    ),
  );
}

class NewLessonPage extends StatefulWidget {
  const NewLessonPage({super.key, required this.api, required this.section});
  final Api api;
  final Json section;
  @override
  State<NewLessonPage> createState() => _NewLessonPageState();
}

class _NewLessonPageState extends State<NewLessonPage> {
  final title = TextEditingController(),
      body = TextEditingController(),
      url = TextEditingController();
  String type = 'Text';
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة درس')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'العنوان'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: type,
          items: [
            'Text',
            'File',
            'Video',
          ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) => setState(() => type = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: body,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'المحتوى والوصف'),
        ),
        if (type == 'Video')
          TextField(
            controller: url,
            decoration: const InputDecoration(labelText: 'رابط MP4 أو HLS'),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (title.text.trim().isEmpty) {
                    toast(context, 'اكتب عنوان الدرس');
                    return;
                  }
                  if (type == 'Video' && !url.text.startsWith('https://')) {
                    toast(context, 'اكتب رابط فيديو HTTPS');
                    return;
                  }
                  setState(() => busy = true);
                  await action(context, () async {
                    final lesson = obj(
                      await widget.api.call(
                        'POST',
                        '/sections/${widget.section['id']}/lessons',
                        data: {
                          'title': title.text.trim(),
                          'type': type,
                          if (type == 'Text') 'body': body.text.trim(),
                          if (type == 'Video')
                            'video': {
                              'source': 'Link',
                              'provider': 'Other',
                              'url': url.text.trim(),
                            },
                        },
                        headers: versionHeader(widget.section),
                      ),
                    );
                    if (!context.mounted) return;
                    if (type == 'File') {
                      open(
                        context,
                        UploadPage(
                          api: widget.api,
                          lessonId: '${lesson['id']}',
                          video: false,
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  }, success: 'تم إنشاء الدرس');
                  if (mounted) setState(() => busy = false);
                },
          child: const Text('حفظ الدرس'),
        ),
      ],
    ),
  );
}
