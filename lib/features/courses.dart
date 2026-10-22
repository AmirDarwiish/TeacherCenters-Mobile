import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import '../core/course_model.dart';
export 'course_experience.dart';
import 'quiz.dart';
import 'uploads.dart';

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

Json versionHeader(Json d) =>
    d['rowVersion'] == null ? {} : {'If-Match': '"${d['rowVersion']}"'};

class LessonPage extends StatefulWidget {
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
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  bool completing = false, completed = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مساحة التعلم')),
    body: AsyncPanel(
      load: () => widget.api.get('/portal/lessons/${widget.id}'),
      builder: (data, refresh) {
        final l = obj(data),
            v = obj(obj(data)['video']),
            q = obj(obj(data)['quiz']);
        return ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (v.isNotEmpty && !['youtube', 'vimeo'].contains(v['kind']))
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LessonPlayer(
                  key: ValueKey(v['url']),
                  api: widget.api,
                  id: widget.id,
                  video: v,
                  position: widget.position,
                  onRetry: refresh,
                ),
              )
            else if (v['url'] != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.smart_display_outlined, size: 54),
                      const SizedBox(height: 16),
                      const Text('شاهد الشرح على منصة الفيديو'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => action(
                          context,
                          () => launchResource(widget.api, '${v['url']}'),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('فتح الفيديو'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Chip(label: Text(CourseInfo.typeName(l['type']))),
                const SizedBox(width: 8),
                if (l['durationSeconds'] != null)
                  Text(CourseInfo.duration(l['durationSeconds'])),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label(l),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            if (l['body'] != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: SelectableText(
                    '${l['body']}',
                    style: const TextStyle(fontSize: 17, height: 1.9),
                  ),
                ),
              ),
            if (l['fileUrl'] != null)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const Icon(Icons.picture_as_pdf_outlined, size: 34),
                  title: const Text('المادة العلمية للدرس'),
                  subtitle: const Text('افتح الملف للمذاكرة والمراجعة'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => action(
                    context,
                    () => launchResource(widget.api, '${l['fileUrl']}'),
                  ),
                ),
              ),
            if (q['quizId'] != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.quiz_outlined, size: 34),
                      const SizedBox(height: 12),
                      Text(
                        '${q['title'] ?? 'اختبر فهمك'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text('${q['questionsCount'] ?? 0} سؤال'),
                          if (q['timeLimitMinutes'] != null)
                            Text('${q['timeLimitMinutes']} دقيقة'),
                          Text(
                            '${q['attemptsLeft'] ?? 'غير محدودة'} محاولة متبقية',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'جهّز وقتك واتصالك قبل البدء. المؤقت يبدأ مع فتح المحاولة.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              widget.api.guardian ||
                                  (q['attemptsLeft'] as num?) == 0
                              ? null
                              : () => open(
                                  context,
                                  QuizPage(
                                    api: widget.api,
                                    quizId: '${q['quizId']}',
                                  ),
                                ),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('ابدأ أو استكمل الاختبار'),
                        ),
                      ),
                      if (q['lastAttemptId'] != null)
                        TextButton(
                          onPressed: () => open(
                            context,
                            ResultPage(
                              api: widget.api,
                              attemptId: '${q['lastAttemptId']}',
                            ),
                          ),
                          child: const Text('راجع نتيجة آخر محاولة'),
                        ),
                    ],
                  ),
                ),
              ),
            if (!widget.api.guardian && ['Text', 'File'].contains(l['type']))
              FilledButton.icon(
                onPressed: completing || completed
                    ? null
                    : () async {
                        setState(() => completing = true);
                        await action(context, () async {
                          await widget.api.call(
                            'POST',
                            '/portal/lessons/${widget.id}/complete',
                          );
                          if (mounted) setState(() => completed = true);
                        }, success: 'خطوة جديدة! تم حفظ إكمال الدرس');
                        if (mounted) setState(() => completing = false);
                      },
                icon: Icon(completed ? Icons.check_circle : Icons.task_alt),
                label: Text(
                  completing
                      ? 'جارٍ حفظ تقدمك…'
                      : completed
                      ? 'تم إكمال الدرس'
                      : 'أنهيت الدرس',
                ),
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                if (l['prevLessonId'] != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => navigate('${l['prevLessonId']}'),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('السابق'),
                    ),
                  ),
                if (l['prevLessonId'] != null && l['nextLessonId'] != null)
                  const SizedBox(width: 12),
                if (l['nextLessonId'] != null)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => navigate('${l['nextLessonId']}'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('الدرس التالي'),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
  void navigate(String id) => Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(
      builder: (_) => LessonPage(api: widget.api, id: id),
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
    this.onRetry,
  });
  final VoidCallback? onRetry;
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
    if (widget.api.guardian || sending || !controller.value.isInitialized) {
      return;
    }
    sending = true;
    try {
      await widget.api.call(
        'PUT',
        '/portal/lessons/${widget.id}/progress',
        data: {'positionSeconds': controller.value.position.inSeconds},
      );
      if (mounted && error != null) setState(() => error = null);
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
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                controller.value.isInitialized
                    ? '$error'
                    : 'تعذر تشغيل الفيديو. أعد المحاولة لتحديث رابط المشاهدة.',
              ),
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
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
                tooltip: 'ملء الشاشة',
                onPressed: () => open(
                  context,
                  FullscreenVideo(
                    controller: controller,
                    watermark: widget.video['watermarkText'],
                  ),
                ),
                icon: const Icon(Icons.fullscreen),
              ),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [.75, 1.0, 1.25, 1.5, 2.0]
                .map(
                  (speed) => ChoiceChip(
                    label: Text('${speed}x'),
                    selected: controller.value.playbackSpeed == speed,
                    onSelected: (_) async {
                      await controller.setPlaybackSpeed(speed);
                      if (mounted) setState(() {});
                    },
                  ),
                )
                .toList(),
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
            if (!api.guardian &&
                d['eligible'] == true &&
                d['certificate'] == null)
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
        if (lesson['type'] != 'Quiz')
          OutlinedButton.icon(
            onPressed: () => open(
              context,
              NewLessonPage(
                api: api,
                section: {'id': lesson['sectionId']},
                existing: lesson,
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل محتوى الدرس وإعداداته'),
          ),
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
  const NewLessonPage({
    super.key,
    required this.api,
    required this.section,
    this.existing,
  });
  final Api api;
  final Json section;
  final Json? existing;
  @override
  State<NewLessonPage> createState() => _NewLessonPageState();
}

class _NewLessonPageState extends State<NewLessonPage> {
  final title = TextEditingController(),
      body = TextEditingController(),
      url = TextEditingController();
  String type = 'Text';
  final duration = TextEditingController();
  bool preview = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final l = widget.existing;
    if (l == null) return;
    title.text = label(l);
    body.text = '${l['body'] ?? ''}';
    url.text = '${obj(l['video'])['url'] ?? ''}';
    type = '${l['type']}';
    preview = l['isPreview'] == true;
    duration.text = '${l['durationSeconds'] ?? 0}';
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    url.dispose();
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'إضافة درس' : 'تعديل الدرس'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          maxLength: 150,
          controller: title,
          decoration: const InputDecoration(labelText: 'العنوان'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: type,
          items: ['Text', 'File', 'Video']
              .map(
                (x) => DropdownMenuItem(
                  value: x,
                  child: Text(CourseInfo.typeName(x)),
                ),
              )
              .toList(),
          onChanged: widget.existing != null
              ? null
              : (v) => setState(() => type = v!),
        ),
        const SizedBox(height: 16),
        if (type == 'Text')
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('معاينة مجانية'),
          subtitle: const Text('تسمح للطالب بتجربة الدرس قبل الاشتراك'),
          value: preview,
          onChanged: (v) => setState(() => preview = v),
        ),
        if (type == 'Video')
          TextField(
            controller: duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مدة الفيديو بالثواني',
              helperText: 'تُستخدم لحساب إكمال الدرس بدقة',
            ),
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
                  if (type == 'Text' && body.text.trim().isEmpty) {
                    toast(context, 'اكتب شرح الدرس');
                    return;
                  }
                  final uploaded =
                      widget.existing != null &&
                      obj(widget.existing!['video'])['source'] == 'Upload';
                  if (type == 'Video' &&
                      !uploaded &&
                      (!url.text.startsWith('https://') ||
                          (int.tryParse(duration.text) ?? 0) <= 0)) {
                    toast(context, 'اكتب رابط فيديو HTTPS ومدة صحيحة بالثواني');
                    return;
                  }
                  setState(() => busy = true);
                  await action(context, () async {
                    final lesson = obj(
                      await widget.api.call(
                        widget.existing == null ? 'POST' : 'PUT',
                        widget.existing == null
                            ? '/sections/${widget.section['id']}/lessons'
                            : '/lessons/${widget.existing!['id']}',
                        data: {
                          'title': title.text.trim(),
                          'type': type,
                          'isPreview': preview,
                          'durationSeconds': int.tryParse(duration.text) ?? 0,
                          if (widget.existing?['maxViewsPerStudent'] != null)
                            'maxViewsPerStudent':
                                widget.existing!['maxViewsPerStudent'],
                          if (type == 'File' &&
                              widget.existing?['fileUrl'] != null)
                            'fileUrl': widget.existing!['fileUrl'],
                          if (type == 'Text') 'body': body.text.trim(),
                          if (type == 'Video')
                            'video': uploaded
                                ? obj(widget.existing!['video'])
                                : {
                                    'source': 'Link',
                                    'provider':
                                        Uri.tryParse(
                                              url.text.trim(),
                                            )?.host.contains('youtu') ==
                                            true
                                        ? 'YouTube'
                                        : Uri.tryParse(
                                                url.text.trim(),
                                              )?.host.contains('vimeo.com') ==
                                              true
                                        ? 'Vimeo'
                                        : 'Other',
                                    'url': url.text.trim(),
                                  },
                        },
                        headers: versionHeader(
                          widget.existing ?? widget.section,
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    if (type == 'File' && widget.existing == null) {
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
          child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ الدرس'),
        ),
      ],
    ),
  );
}

class FullscreenVideo extends StatelessWidget {
  const FullscreenVideo({super.key, required this.controller, this.watermark});
  final VideoPlayerController controller;
  final dynamic watermark;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('المشاهدة'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  if (watermark != null)
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '$watermark',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: VideoProgressIndicator(controller, allowScrubbing: true),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, child) => IconButton(
              tooltip: 'تشغيل أو إيقاف',
              color: Colors.white,
              iconSize: 52,
              onPressed: () =>
                  value.isPlaying ? controller.pause() : controller.play(),
              icon: Icon(
                value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
