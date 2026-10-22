import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/widgets.dart';

class AttendanceLocation {
  const AttendanceLocation(
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt, {
    this.isMocked = false,
  });
  final double latitude, longitude, accuracyMeters;
  final DateTime capturedAt;
  final bool isMocked;
}

abstract class AttendanceDevice {
  Future<AttendanceLocation> locate();
  Future<Uint8List?> photograph();
}

class NativeAttendanceDevice implements AttendanceDevice {
  const NativeAttendanceDevice();
  @override
  Future<AttendanceLocation> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiFailure('شغّل خدمة الموقع في الموبايل ثم حاول مرة أخرى.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (![
      LocationPermission.always,
      LocationPermission.whileInUse,
    ].contains(permission)) {
      throw ApiFailure(
        'اسمح بالموقع الدقيق أثناء استخدام التطبيق من إعدادات الموبايل.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
    return AttendanceLocation(
      position.latitude,
      position.longitude,
      position.accuracy,
      position.timestamp.toUtc(),
      isMocked: position.isMocked,
    );
  }

  @override
  Future<Uint8List?> photograph() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    return photo?.readAsBytes();
  }
}

String? attendancePhotoMime(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

class SessionCheckInPage extends StatefulWidget {
  const SessionCheckInPage({
    super.key,
    required this.api,
    required this.studentId,
    required this.sessionId,
    this.device = const NativeAttendanceDevice(),
  });
  final Api api;
  final String studentId, sessionId;
  final AttendanceDevice device;
  @override
  State<SessionCheckInPage> createState() => _SessionCheckInPageState();
}

class _SessionCheckInPageState extends State<SessionCheckInPage> {
  Json? policy, challenge;
  AttendanceLocation? location;
  Uint8List? photo;
  DateTime? photoAt;
  Object? error;
  bool loading = true, working = false;
  String key = newKey();
  static String newKey() => base64Url
      .encode(List.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  String get path =>
      '/portal/students/${widget.studentId}/sessions/${widget.sessionId}/check-in';
  Json get center => obj(policy?['center']);
  Json get verification => obj(policy?['verification']);
  bool get submitted =>
      ['PendingReview', 'Approved'].contains(verification['status']);
  double? get distance =>
      location == null ||
          center['latitude'] is! num ||
          center['longitude'] is! num
      ? null
      : Geolocator.distanceBetween(
          location!.latitude,
          location!.longitude,
          (center['latitude'] as num).toDouble(),
          (center['longitude'] as num).toDouble(),
        );
  double get radius => (center['allowedRadiusMeters'] as num? ?? 0).toDouble();
  double get maxAccuracy =>
      (policy?['maxAccuracyMeters'] as num? ?? 0).toDouble();
  bool get ready =>
      policy?['enabled'] == true &&
      policy?['canSubmit'] == true &&
      !submitted &&
      center['latitude'] is num &&
      center['longitude'] is num &&
      radius > 0 &&
      maxAccuracy > 0;
  bool get locationValid =>
      location != null &&
      !location!.isMocked &&
      location!.accuracyMeters > 0 &&
      location!.accuracyMeters <= maxAccuracy &&
      distance != null &&
      distance! + location!.accuracyMeters <= radius;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (widget.api.guardian || widget.api.role != 'Student') {
        throw ApiFailure('تسجيل الحضور متاح من حساب الطالب فقط.');
      }
      final data = obj(await widget.api.get(path));
      if (mounted) setState(() => policy = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure && [404, 501].contains(e.status)
              ? ApiFailure(
                  'تسجيل الحضور بالموقع والصورة لم يُفعّل في السنتر بعد. استخدم بطاقة الحضور مؤقتًا.',
                )
              : e,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> ensureChallenge() async {
    final expires = DateTime.tryParse('${challenge?['expiresAtUtc']}');
    if (challenge != null &&
        expires != null &&
        expires.isAfter(DateTime.now().toUtc())) {
      return;
    }
    final value = obj(await widget.api.call('POST', '$path/challenge'));
    if (value['challengeId'] == null || value['captureToken'] == null) {
      throw ApiFailure('تعذر تجهيز طلب الحضور. حاول مرة أخرى.');
    }
    challenge = value;
    key = newKey();
    location = null;
    photo = null;
    photoAt = null;
  }

  Future<void> capture(bool gps) async {
    if (working || !ready) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await ensureChallenge();
      if (gps) {
        final next = await widget.device.locate();
        if (mounted) {
          setState(() {
            location = next;
            key = newKey();
          });
        }
      } else {
        final bytes = await widget.device.photograph();
        if (bytes != null) {
          if (bytes.length > 5 * 1024 * 1024 ||
              attendancePhotoMime(bytes) == null) {
            throw ApiFailure(
              'التقط صورة JPEG أو PNG أو WebP لا تزيد عن 5 ميجابايت.',
            );
          }
          if (mounted) {
            setState(() {
              photo = bytes;
              photoAt = DateTime.now().toUtc();
              key = newKey();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> submit() async {
    if (working || !ready || !locationValid || photo == null) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      final now = DateTime.now().toUtc();
      final expires = DateTime.tryParse('${challenge?['expiresAtUtc']}');
      if (expires == null || !expires.isAfter(now)) {
        throw ApiFailure('انتهت مهلة التصوير. حدّث الموقع والتقط صورة جديدة.');
      }
      if (now.difference(location!.capturedAt).inSeconds.abs() > 60) {
        throw ApiFailure(
          'حدّث موقعك قبل الإرسال؛ آخر قراءة مرّ عليها أكثر من دقيقة.',
        );
      }
      if (photoAt == null || now.difference(photoAt!).inMinutes >= 5) {
        throw ApiFailure('التقط صورة جديدة قبل الإرسال.');
      }
      final mime = attendancePhotoMime(photo!)!;
      final response = obj(
        await widget.api.call(
          'POST',
          path,
          headers: {'Idempotency-Key': key},
          data: FormData.fromMap({
            'challengeId': challenge!['challengeId'],
            'captureToken': challenge!['captureToken'],
            'latitude': location!.latitude,
            'longitude': location!.longitude,
            'accuracyMeters': location!.accuracyMeters,
            'isMocked': location!.isMocked,
            'locationCapturedAtUtc': location!.capturedAt.toIso8601String(),
            'photoCapturedAtUtc': photoAt!.toIso8601String(),
            'photo': MultipartFile.fromBytes(
              photo!,
              filename:
                  'attendance.${mime == 'image/jpeg' ? 'jpg' : mime.split('/').last}',
              contentType: MediaType.parse(mime),
            ),
          }),
        ),
      );
      if (response['id'] == null ||
          ![
            'Approved',
            'PendingReview',
          ].contains(response['verificationStatus'])) {
        throw ApiFailure(
          'تعذر تأكيد نتيجة الطلب. حدّث حالة الحضور قبل إعادة الإرسال.',
        );
      }
      if (!mounted) return;
      setState(() {
        policy = {
          ...?policy,
          'verification': {
            'id': response['id'],
            'status': response['verificationStatus'],
          },
        };
        photo = null;
        location = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !working,
    child: Scaffold(
      appBar: AppBar(title: const Text('تسجيل حضوري')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  'أكد وجودك في السنتر',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'بنستخدم موقعك وقت تسجيل الحضور فقط. صوّر علامة مميزة زي لافتة القاعة أو شعار السنتر، وتجنب تصوير أشخاص أو أوراق فيها بيانات شخصية.',
                ),
                const SizedBox(height: 20),
                if (submitted)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Icon(Icons.fact_check_outlined, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            verification['status'] == 'Approved'
                                ? 'تم تأكيد حضورك'
                                : 'تم إرسال طلبك لمراجعة السنتر',
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('العودة للحصة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!submitted && policy != null) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text('${center['name'] ?? 'فرع الحصة'}'),
                      subtitle: Text(
                        ready
                            ? 'النطاق المسموح ${radius.round()} متر'
                            : '${policy?['reason'] ?? 'الحضور غير متاح في هذا الوقت أو لم يكتمل إعداد موقع الفرع.'}',
                      ),
                    ),
                  ),
                  if (policy?['opensAtUtc'] != null)
                    Text('بداية تسجيل الحضور: ${when(policy?['opensAtUtc'])}'),
                  if (policy?['closesAtUtc'] != null)
                    Text('آخر موعد: ${when(policy?['closesAtUtc'])}'),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: !ready || working ? null : () => capture(true),
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      location == null
                          ? '١. تحديد موقعي الحالي'
                          : 'تحديث موقعي',
                    ),
                  ),
                  if (location != null)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          locationValid
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                        ),
                        title: Text(
                          location!.isMocked
                              ? 'موقع تجريبي غير مقبول'
                              : locationValid
                              ? 'أنت داخل نطاق السنتر'
                              : 'لم يتأكد وجودك داخل النطاق',
                        ),
                        subtitle: Text(
                          'المسافة ${distance?.round() ?? '—'} متر • دقة الموقع ${location!.accuracyMeters.round()} متر\n${location!.accuracyMeters > maxAccuracy ? 'فعّل الموقع الدقيق أو انتقل لمكان أوضح ثم حدّث الموقع.' : 'المسافة تقديرية؛ السنتر يؤكد نتيجة التسجيل.'}',
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: !ready || working ? null : () => capture(false),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      photo == null
                          ? '٢. تصوير علامة مميزة بالكاميرا'
                          : 'إعادة التقاط الصورة',
                    ),
                  ),
                  if (policy?['landmarkPrompt'] != null)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('${policy?['landmarkPrompt']}'),
                    ),
                  if (photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        photo!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed:
                        !ready || working || !locationValid || photo == null
                        ? null
                        : submit,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      working ? 'جارٍ تجهيز طلبك…' : '٣. إرسال وتأكيد الحضور',
                    ),
                  ),
                ],
                if (error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '$error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: working ? null : load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث حالة الطلب'),
                ),
              ],
            ),
    ),
  );
}
