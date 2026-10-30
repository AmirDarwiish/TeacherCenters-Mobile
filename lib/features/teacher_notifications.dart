import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/brand.dart';
import '../core/app_icons.dart';
import 'scoped_chat.dart' show messageKey;

class TeacherNotificationsPage extends StatefulWidget {
  const TeacherNotificationsPage({super.key, required this.api});
  final Api api;
  @override
  State<TeacherNotificationsPage> createState() =>
      _TeacherNotificationsPageState();
}

class _TeacherNotificationsPageState extends State<TeacherNotificationsPage> {
  final title = TextEditingController(),
      body = TextEditingController(),
      search = TextEditingController();
  final selected = <String, Json>{};
  List<Json> groups = [], students = [];
  String mode = 'Group', audience = 'Both', requestId = messageKey();
  String? groupId, imageId, error;
  Uint8List? imageBytes;
  bool busy = false, loading = true;
  int page = 1, pages = 1;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = rows(await widget.api.get('/teacher-notifications/groups'));
      if (mounted) {
        setState(() {
          groups = data;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> loadStudents({int next = 1}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = obj(
        await widget.api.get(
          '/teacher-notifications/students',
          query: {'search': search.text.trim(), 'page': next, 'pageSize': 30},
        ),
      );
      if (mounted) {
        setState(() {
          students = rows(data);
          page = next;
          pages = (data['totalPages'] as num? ?? 1).toInt();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (pick == null || !mounted) return;
    final f = pick.files.single;
    if (f.size > 3 * 1024 * 1024 || f.bytes == null) {
      setState(() => error = 'اختار صورة حجمها لحد ٣ ميجابايت.');
      return;
    }
    setState(() {
      imageBytes = f.bytes;
      imageId = null;
      requestId = messageKey();
    });
  }

  Json payload() => {
    'requestId': requestId,
    'groupId': mode == 'Group' ? groupId : null,
    'studentIds': mode == 'Students' ? selected.keys.toList() : null,
    'audience': audience,
    'title': title.text.trim(),
    'body': body.text.trim(),
    'imageId': imageId,
  };
  Future<void> preview() async {
    if (title.text.trim().length < 2 ||
        body.text.trim().length < 2 ||
        (mode == 'Group' ? groupId == null : selected.isEmpty)) {
      setState(() => error = 'اكتب عنوان ونص الإشعار واختار المستلمين.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final count = obj(
        await widget.api.call(
          'POST',
          '/teacher-notifications/preview',
          data: payload(),
        ),
      );
      if (!mounted) return;
      if ((count['recipients'] as num? ?? 0) == 0) {
        setState(() => error = 'مفيش مستلمين مطابقين للاختيار.');
        return;
      }
      final agreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('معاينة الإشعار'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('هيتبعت لـ ${count['recipients']} مستلم'),
                const SizedBox(height: 16),
                Text(
                  'رواق | ${title.text.trim()}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(body.text.trim()),
                if (imageBytes != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      imageBytes!,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تعديل'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال الإشعار'),
            ),
          ],
        ),
      );
      if (agreed != true || !mounted) return;
      if (imageBytes != null && imageId == null) {
        final uploaded = obj(
          await widget.api.call(
            'POST',
            '/teacher-notifications/images',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(
                imageBytes!,
                filename: 'notification.png',
              ),
            }),
          ),
        );
        imageId = '${uploaded['id']}';
      }
      await widget.api.call('POST', '/teacher-notifications', data: payload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تجهيز الإشعار وإضافته للمستلمين. وصول التنبيه يعتمد على إعدادات أجهزتهم.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('إرسال إشعار'),
    ),
    body: AbsorbPointer(
      absorbing: busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'رسالة من المدرس',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'بلّغ طلابك وأولياء أمورهم بالتحديثات المهمة. اختار المستلمين وراجع الإشعار قبل إرساله.',
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Group', label: Text('مجموعة')),
              ButtonSegment(value: 'Students', label: Text('طلاب محددين')),
            ],
            selected: {mode},
            onSelectionChanged: (v) {
              setState(() => mode = v.first);
              if (mode == 'Students') loadStudents();
            },
          ),
          const SizedBox(height: 16),
          if (mode == 'Group')
            DropdownButtonFormField<String>(
              icon: const Icon(AppIcons.arrowDownward),
              initialValue: groupId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المجموعة',
                hintText: 'اكتب هنا…',
              ),
              items: groups
                  .map(
                    (g) => DropdownMenuItem(
                      value: '${g['id']}',
                      child: Text(label(g), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => groupId = v),
            ),
          if (mode == 'Students') ...[
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: 'ابحث باسم الطالب أو الكود',
                hintText: 'اكتب الاسم',
                suffixIcon: IconButton(
                  onPressed: () => loadStudents(),
                  icon: const Icon(AppIcons.searchRounded),
                ),
              ),
              onSubmitted: (_) => loadStudents(),
            ),
            const SizedBox(height: 8),
            Text('المحدد: ${selected.length} طالب'),
            for (final s in students)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label(s)),
                subtitle: Text('${s['code'] ?? ''}'),
                value: selected.containsKey('${s['id']}'),
                onChanged: (v) => setState(() {
                  if (v == true && selected.length < 500) {
                    selected['${s['id']}'] = s;
                  } else {
                    selected.remove('${s['id']}');
                  }
                }),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: page > 1
                      ? () => loadStudents(next: page - 1)
                      : null,
                  child: const Text('السابق'),
                ),
                Text('$page / ${pages < 1 ? 1 : pages}'),
                TextButton(
                  onPressed: page < pages
                      ? () => loadStudents(next: page + 1)
                      : null,
                  child: const Text('التالي'),
                ),
              ],
            ),
          ],
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            icon: const Icon(AppIcons.arrowDownward),
            initialValue: audience,
            decoration: const InputDecoration(
              labelText: 'يوصل لمين؟',
              hintText: 'اكتب هنا…',
            ),
            items: const [
              DropdownMenuItem(
                value: 'Both',
                child: Text('الطلاب وأولياء الأمور'),
              ),
              DropdownMenuItem(value: 'Students', child: Text('الطلاب فقط')),
              DropdownMenuItem(
                value: 'Guardians',
                child: Text('أولياء الأمور فقط — خاص'),
              ),
            ],
            onChanged: (v) => setState(() => audience = v!),
          ),
          const SizedBox(height: 16),
          if (audience == 'Guardians')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'الإشعار خاص بولي الأمر. الطالب مش هيوصله تنبيه ومش هيظهر في سجل إشعاراته.',
              ),
            ),
          TextField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'عنوان الإشعار',
              hintText: 'مثال: مراجعة قبل الامتحان',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: body,
            maxLength: 1500,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'نص الرسالة',
              hintText: 'اكتب هنا…',
            ),
          ),
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(imageBytes!, height: 180, fit: BoxFit.cover),
            ),
            TextButton(
              onPressed: () => setState(() {
                imageBytes = null;
                imageId = null;
              }),
              child: const Text('إزالة الصورة'),
            ),
          ],
          OutlinedButton.icon(
            onPressed: pickImage,
            icon: const Icon(AppIcons.imageOutlined),
            label: const Text('إضافة صورة اختيارية'),
          ),
          const Text(
            'الصورة هتظهر في الإشعار؛ تجنّب إضافة بيانات خاصة بالطلاب داخلها.',
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy || loading ? null : preview,
            icon: const Icon(AppIcons.notificationsActiveOutlined),
            label: Text(busy ? 'جاري التجهيز…' : 'معاينة وإرسال'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
