import '../core/brand.dart';
import '../core/app_icons.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import '../core/course_model.dart';
import 'courses.dart';

Future<void> uploadCourseCover(Api api, Json course) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    withReadStream: true,
    withData: false,
  );
  if (result == null) return;
  final file = result.files.single;
  if (file.size > 3 * 1024 * 1024) {
    throw ApiFailure('اختر غلافاً حجمه حتى ٣ ميجابايت.');
  }
  if (file.readStream == null) {
    throw ApiFailure('تعذر قراءة الصورة. اخترها مرة أخرى.');
  }
  await api.refresh();
  await api.call(
    'POST',
    '/courses/${course['id']}/cover',
    retry: false,
    headers: versionHeader(course),
    data: FormData.fromMap({
      'file': MultipartFile.fromStream(
        () => file.readStream!,
        file.size,
        filename: file.name,
      ),
    }),
  );
}

/// Reorders a complete curriculum snapshot; never drops hidden sections/lessons.
class CurriculumPage extends StatefulWidget {
  const CurriculumPage({super.key, required this.api, required this.course});
  final Api api;
  final Json course;
  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage> {
  late final List<Json> sections = rows(widget.course['sections'])
      .map(
        (s) => <String, dynamic>{
          ...s,
          'lessons': rows(
            s['lessons'],
          ).map((l) => <String, dynamic>{...l}).toList(),
        },
      )
      .toList();
  bool dirty = false, busy = false;
  void move(List<Json> list, int from, int to) => setState(() {
    final value = list.removeAt(from);
    list.insert(to, value);
    dirty = true;
  });
  Widget controls(List<Json> list, int index) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'نقل لأعلى',
        onPressed: busy || index == 0
            ? null
            : () => move(list, index, index - 1),
        icon: const Icon(AppIcons.arrowUpwardRounded, size: 20),
      ),
      IconButton(
        tooltip: 'نقل لأسفل',
        onPressed: busy || index == list.length - 1
            ? null
            : () => move(list, index, index + 1),
        icon: const Icon(AppIcons.arrowDownwardRounded, size: 20),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty || busy,
    onPopInvokedWithResult: (popped, result) async {
      if (popped) return;
      if (await confirm(context, 'الخروج بدون حفظ ترتيب المنهج؟') &&
          context.mounted) {
        setState(() => dirty = false);
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(
        flexibleSpace: const BrandHeader(),
        title: const Text('تنظيم المنهج'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'رتّب الوحدات والدروس بالترتيب الذي يساعد طلابك على التعلم خطوة بخطوة.',
          ),
          const SizedBox(height: 20),
          for (final (index, section) in sections.indexed)
            BrandCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label(section),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        controls(sections, index),
                      ],
                    ),
                    const Divider(),
                    for (final (position, lesson)
                        in (section['lessons'] as List<Json>).indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(label(lesson)),
                        subtitle: Text(CourseInfo.typeName(lesson['type'])),
                        trailing: controls(
                          section['lessons'] as List<Json>,
                          position,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: !dirty || busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await action(context, () async {
                      await widget.api.call(
                        'PUT',
                        '/courses/${widget.course['id']}/curriculum',
                        headers: versionHeader(widget.course),
                        data: {
                          'sections': sections
                              .map(
                                (s) => {
                                  'id': s['id'],
                                  'lessonIds': rows(
                                    s['lessons'],
                                  ).map((l) => l['id']).toList(),
                                },
                              )
                              .toList(),
                        },
                      );
                      if (context.mounted) {
                        setState(() => dirty = false);
                        Navigator.pop(context);
                      }
                    }, success: 'تم حفظ ترتيب المنهج');
                    if (mounted) setState(() => busy = false);
                  },
            icon: const Icon(AppIcons.check),
            label: Text(busy ? 'جارٍ الحفظ…' : 'حفظ ترتيب المنهج'),
          ),
        ),
      ),
    ),
  );
}
