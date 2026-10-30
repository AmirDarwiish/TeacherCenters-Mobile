import '../core/brand.dart';
import '../core/app_icons.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({
    super.key,
    required this.api,
    required this.lessonId,
    required this.video,
    this.lesson = const {},
  });
  final Api api;
  final String lessonId;
  final bool video;
  final Json lesson;
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final duration = TextEditingController();
  bool busy = false, cancelled = false;
  double progress = 0;
  String status = 'اختار ملفاً للرفع';
  bool get active => mounted && !cancelled;
  void update(String text, [double? value]) {
    if (mounted) {
      setState(() {
        status = text;
        if (value != null) progress = value;
      });
    }
  }

  @override
  void dispose() {
    cancelled = true;
    duration.dispose();
    super.dispose();
  }

  Future<void> upload() async {
    if (widget.video && (int.tryParse(duration.text) ?? 0) <= 0) {
      toast(context, 'اكتب مدة الفيديو بالثواني لحفظ التقدم بدقة');
      return;
    }
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.video
          ? ['mp4', 'mov', 'webm']
          : [
              'pdf',
              'png',
              'jpg',
              'jpeg',
              'webp',
              'doc',
              'docx',
              'xls',
              'xlsx',
              'ppt',
              'pptx',
            ],
      withReadStream: true,
      withData: false,
    );
    if (selection == null || !mounted) return;
    final file = selection.files.single;
    if (file.size > (widget.video ? 2147483648 : 50 * 1024 * 1024)) {
      toast(context, 'حجم الملف أكبر من المسموح.');
      return;
    }
    if (file.readStream == null) {
      toast(context, 'تعذر قراءة الملف على هذا الجهاز.');
      return;
    }
    setState(() {
      busy = true;
      cancelled = false;
    });
    try {
      await widget.api.refresh();
      if (!widget.video) {
        update('جاري رفع الملف…', 0);
        await widget.api.call(
          'POST',
          '/lessons/${widget.lessonId}/file',
          retry: false,
          data: FormData.fromMap({
            'file': MultipartFile.fromStream(
              () => file.readStream!,
              file.size,
              filename: file.name,
            ),
          }),
        );
      } else {
        final ext = file.extension?.toLowerCase();
        final contentType = ext == 'mov'
            ? 'video/quicktime'
            : ext == 'webm'
            ? 'video/webm'
            : 'video/mp4';
        final init = obj(
          await widget.api.call(
            'POST',
            '/media/uploads',
            data: {
              'fileName': file.name,
              'size': file.size,
              'contentType': contentType,
              'durationSeconds': int.tryParse(duration.text) ?? 0,
            },
          ),
        );
        final uploadId = init['uploadId'];
        final mediaId = init['uploadId'];
        final chunkSize = (init['chunkSize'] as num? ?? 4 * 1024 * 1024)
            .toInt();
        if (uploadId == null || mediaId == null || chunkSize <= 0) {
          throw ApiFailure('استجابة تهيئة الرفع غير صحيحة');
        }
        final buffer = BytesBuilder(copy: false);
        int index = 0, sent = 0;
        Future<void> send(Uint8List bytes) async {
          if (!active) throw ApiFailure('تم إيقاف الرفع');
          // Exact duplicate bytes are idempotent on this endpoint.
          Object? last;
          for (var attempt = 0; attempt < 3; attempt++) {
            try {
              await widget.api.call(
                'PUT',
                '/media/uploads/$uploadId/chunks/$index',
                data: bytes,
                headers: {'Content-Type': 'application/octet-stream'},
              );
              last = null;
              break;
            } catch (e) {
              last = e;
              if (e is ApiFailure &&
                  e.status != null &&
                  e.status! >= 400 &&
                  e.status! < 500) {
                rethrow;
              }
            }
          }
          if (last != null) throw last;
          sent += bytes.length;
          index++;
          update(
            'تم رفع ${(100 * sent / file.size).round()}%',
            sent / file.size,
          );
        }

        await for (final piece in file.readStream!) {
          var offset = 0;
          while (offset < piece.length) {
            final count = (chunkSize - buffer.length).clamp(
              0,
              piece.length - offset,
            );
            buffer.add(piece.sublist(offset, offset + count));
            offset += count;
            if (buffer.length == chunkSize) await send(buffer.takeBytes());
          }
        }
        if (buffer.length > 0) await send(buffer.takeBytes());
        if (!active) throw ApiFailure('تم إيقاف الرفع');
        update('جاري تجهيز الفيديو…');
        await widget.api.call('POST', '/media/uploads/$uploadId/complete');
        final media = obj(await widget.api.get('/media/$mediaId'));
        if (media['status'] != 'Ready') {
          throw ApiFailure(
            'الفيديو قيد المعالجة. معرفه $mediaId. لا تعيد الرفع قبل مراجعة حالته.',
          );
        }
        final current = obj(
          await widget.api.get('/lessons/${widget.lessonId}'),
        );
        await widget.api.call(
          'PUT',
          '/lessons/${widget.lessonId}',
          headers: versionHeader(current),
          data: {
            'title': current['title'] ?? widget.lesson['title'],
            'type': 'Video',
            'isPreview': current['isPreview'] ?? false,
            'durationSeconds': media['durationSeconds'] ?? 0,
            'video': {'source': 'Upload', 'mediaId': mediaId},
          },
        );
      }
      update('اكتمل الرفع وربط الملف بالدرس', 1);
    } catch (e) {
      update('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: Text(widget.video ? 'رفع فيديو' : 'رفع ملف'),
    ),
    body: PopScope(
      canPop: !busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            widget.video
                ? AppIcons.cloudUploadOutlined
                : AppIcons.uploadFileOutlined,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(status, textAlign: TextAlign.center),
          if (widget.video)
            TextField(
              controller: duration,
              enabled: !busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مدة الفيديو بالثواني',
                hintText: 'مثال: 900',
              ),
            ),
          const SizedBox(height: 20),
          if (busy) LinearProgressIndicator(value: progress),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : upload,
            child: const Text('اختيار الملف ورفعه'),
          ),
          if (busy)
            TextButton(
              onPressed: () => setState(() => cancelled = true),
              child: const Text('إيقاف بعد الطلب الحالي'),
            ),
        ],
      ),
    ),
  );
}
