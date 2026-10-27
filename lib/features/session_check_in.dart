import '../core/brand.dart';
import '../core/app_icons.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http_parser/http_parser.dart';
import 'package:camera/camera.dart';

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
  Future<void> openCamera() async {}
  Future<void> closeCamera() async {}
  Widget cameraPreview() =>
      const Center(child: Icon(AppIcons.cameraAltOutlined));
  Future<AttendanceLocation> locate();
  Future<Uint8List?> photograph();
}

class NativeAttendanceDevice extends AttendanceDevice {
  CameraController? _camera;

  @override
  Future<void> openCamera() async {
    await closeCamera();
    final cameras = await availableCameras();
    final rear = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (rear.isEmpty) {
      throw ApiFailure('الكاميرا الخلفية غير متاحة على هذا الجهاز.');
    }
    final controller = CameraController(
      rear.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _camera = controller;
    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        if (controller.value.hasError) rethrow;
      }
    } catch (_) {
      if (identical(_camera, controller)) await closeCamera();
      rethrow;
    }
  }

  @override
  Future<void> closeCamera() async {
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  @override
  Widget cameraPreview() {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: CameraPreview(camera));
  }

  @override
  Future<AttendanceLocation> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiFailure(
        'شغّل خدمة الموقع في الموبايل ثم حاول مرة أخرى.',
        code: 'location-disabled',
      );
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
        code: 'location-permission',
      );
    }
    final position =
        await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                timeLimit: Duration(seconds: 25),
              ),
            )
            .onError<TimeoutException>(
              (_, _) => throw ApiFailure(
                'تعذر الوصول لموقع دقيق. جرّب مكان أوضح وحدّد موقعك تاني.',
                code: 'location-timeout',
              ),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw ApiFailure(
                  'الموقع بياخد وقت أطول. جرّب مكان أوضح وحدّد موقعك تاني.',
                  code: 'location-timeout',
                );
              },
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
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      throw ApiFailure('افتح الكاميرا داخل التطبيق ثم التقط الصورة.');
    }
    final photo = await camera.takePicture();
    return photo.readAsBytes();
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
    this.device,
  });
  final Api api;
  final String studentId, sessionId;
  final AttendanceDevice? device;
  @override
  State<SessionCheckInPage> createState() => _SessionCheckInPageState();
}

class _SessionCheckInPageState extends State<SessionCheckInPage>
    with WidgetsBindingObserver {
  late final AttendanceDevice device =
      widget.device ?? NativeAttendanceDevice();
  bool cameraOpen = false;
  bool cameraBusy = false;
  bool foreground = true;
  int cameraEpoch = 0;
  Future<void> cameraTask = Future.value();

  Object deviceError(Object value) {
    if (value is! CameraException) return value;
    final code = value.code.toLowerCase();
    final denied = code.contains('denied') || code.contains('restricted');
    return ApiFailure(
      denied
          ? 'اسمح باستخدام الكاميرا من إعدادات التطبيق، وبعدها حاول تاني.'
          : 'الكاميرا مش جاهزة دلوقتي. اقفل أي تطبيق بيستخدمها وحاول تاني.',
      code: denied ? 'camera-permission' : 'camera-unavailable',
    );
  }

  void notifyError(Object value) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text('$value')));
  }

  Future<void> stopCamera() {
    cameraTask = cameraTask.then(
      (_) => device.closeCamera(),
      onError: (Object _, StackTrace _) => device.closeCamera(),
    );
    return cameraTask;
  }

  Future<void> openCamera() async {
    if (working || cameraBusy || !ready) return;
    final epoch = cameraEpoch;
    setState(() {
      cameraBusy = true;
      error = null;
    });
    try {
      await ensureChallenge();
      cameraTask = cameraTask.then((_) => device.openCamera());
      await cameraTask;
      if (!mounted || !foreground || epoch != cameraEpoch) {
        await stopCamera();
        return;
      }
      setState(() {
        cameraOpen = true;
        photo = null;
        photoAt = null;
      });
    } catch (e) {
      // Keep the operation queue usable after a denied permission or device error.
      cameraTask = Future.value();
      if (mounted) {
        setState(() => error = deviceError(e));
        notifyError(error ?? e);
      }
    } finally {
      if (mounted) setState(() => cameraBusy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android permission dialogs are transient inactive states, not backgrounding.
    if (state == AppLifecycleState.inactive &&
        !cameraOpen &&
        (cameraBusy || working)) {
      return;
    }
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      cameraEpoch++;
      setState(() => cameraOpen = false);
      stopCamera();
    }
  }

  @override
  void dispose() {
    cameraEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    stopCamera();
    super.dispose();
  }

  Json? policy, challenge;
  DateTime? serverTime;
  final serverClock = Stopwatch();
  DateTime get now =>
      serverTime?.add(serverClock.elapsed) ?? DateTime.now().toUtc();
  bool evidenceSent = false;
  AttendanceLocation normalizedLocation(AttendanceLocation value) =>
      AttendanceLocation(
        value.latitude,
        value.longitude,
        value.accuracyMeters,
        now.subtract(
          DateTime.now().toUtc().difference(value.capturedAt.toUtc()),
        ),
        isMocked: value.isMocked,
      );
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
      ['PendingReview', 'Approved'].contains(verification['status']) ||
      ['Present', 'Late'].contains(policy?['attendance']);
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
  bool get locationAccurate =>
      location != null &&
      !location!.isMocked &&
      location!.latitude.isFinite &&
      location!.longitude.isFinite &&
      location!.latitude.abs() <= 90 &&
      location!.longitude.abs() <= 180 &&
      location!.accuracyMeters.isFinite &&
      location!.accuracyMeters > 0 &&
      location!.accuracyMeters <= maxAccuracy;
  bool get insideRadius =>
      locationAccurate &&
      distance != null &&
      distance! + location!.accuracyMeters <= radius;
  bool get locationValid =>
      locationAccurate &&
      (insideRadius || policy?['reviewOutsideRadius'] == true);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    cameraEpoch++;
    cameraOpen = false;
    await stopCamera();
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (widget.api.guardian || widget.api.role != 'Student') {
        throw ApiFailure('تسجيل الحضور متاح من حساب الطالب فقط.');
      }
      final data = obj(await widget.api.get(path));
      if (mounted) {
        setState(() {
          final time = apiUtc(data['serverNowUtc']);
          serverTime = time;
          serverClock
            ..reset()
            ..start();
          policy = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure && e.status == 501
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
    final expires = apiUtc(challenge?['expiresAtUtc']);
    if (challenge != null && expires != null && expires.isAfter(now)) {
      return;
    }
    final value = obj(await widget.api.call('POST', '$path/challenge'));
    if (value['challengeId'] == null || value['captureToken'] == null) {
      throw ApiFailure('تعذر تجهيز طلب الحضور. حاول مرة أخرى.');
    }
    challenge = value;
    evidenceSent = false;
    key = newKey();
    location = null;
    photo = null;
    photoAt = null;
  }

  Future<void> capture(bool gps) async {
    if (working || cameraBusy || !ready) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      final epoch = cameraEpoch;
      await ensureChallenge();
      if (gps) {
        final next = await device.locate();
        if (mounted && foreground) {
          setState(() {
            location = normalizedLocation(next);
            evidenceSent = false;
            key = newKey();
          });
        }
      } else {
        if (!cameraOpen || !foreground) return;
        final bytes = await device.photograph();
        if (!mounted || !foreground || epoch != cameraEpoch) return;
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
              photoAt = now;
              evidenceSent = false;
              key = newKey();
              cameraOpen = false;
            });
            await stopCamera();
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = deviceError(e));
      notifyError(error ?? e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> submit() async {
    if (working || cameraBusy || !ready || !locationValid || photo == null) {
      return;
    }
    setState(() {
      working = true;
      error = null;
    });
    try {
      final expires = apiUtc(challenge?['expiresAtUtc']);
      if (!evidenceSent && (expires == null || !expires.isAfter(now))) {
        throw ApiFailure(
          'انتهت مهلة التصوير. حدّث الموقع والتقط صورة جديدة.',
          code: 'capture-expired',
        );
      }
      if (!evidenceSent &&
          now.difference(location!.capturedAt).inSeconds >= 45) {
        final fresh = normalizedLocation(await device.locate());
        if (!mounted || !foreground) return;
        setState(() {
          location = fresh;
          key = newKey();
        });
        if (!locationValid ||
            now.difference(fresh.capturedAt).inSeconds.abs() > 45) {
          throw ApiFailure(
            'الموقع الحالي مش دقيق كفاية. حدّد موقعك تاني قبل الإرسال.',
          );
        }
      }
      if (!evidenceSent &&
          (photoAt == null || now.difference(photoAt!).inMinutes >= 5)) {
        throw ApiFailure(
          'التقط صورة جديدة قبل الإرسال.',
          code: 'capture-expired',
        );
      }
      final mime = attendancePhotoMime(photo!)!;
      evidenceSent = true;
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
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
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
      if (mounted) {
        setState(() {
          error = e;
          if (e is ApiFailure && e.code == 'capture-expired') {
            challenge = null;
            location = null;
            photo = null;
            photoAt = null;
            evidenceSent = false;
          } else if (e is ApiFailure && e.code == 'location-inaccurate') {
            location = null;
            evidenceSent = false;
          }
        });
        notifyError(e);
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !working && !cameraBusy,
    child: Scaffold(
      appBar: AppBar(
        flexibleSpace: const BrandHeader(),
        title: const Text('تسجيل حضوري'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
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
                if (error != null)
                  BrandCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '$error',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          if (error is ApiFailure &&
                              [
                                'location-disabled',
                                'location-permission',
                                'camera-permission',
                              ].contains((error as ApiFailure).code))
                            TextButton(
                              onPressed: () async {
                                if ((error as ApiFailure).code ==
                                    'location-disabled') {
                                  await Geolocator.openLocationSettings();
                                } else {
                                  await Geolocator.openAppSettings();
                                }
                              },
                              child: Text(
                                (error as ApiFailure).code ==
                                        'location-disabled'
                                    ? 'افتح إعدادات الموقع'
                                    : 'افتح صلاحيات التطبيق',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (submitted)
                  BrandCard(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Icon(AppIcons.factCheckOutlined, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            (verification['status'] == 'Approved' ||
                                    [
                                      'Present',
                                      'Late',
                                    ].contains(policy?['attendance']))
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
                  BrandCard(
                    child: ListTile(
                      leading: const Icon(AppIcons.locationOnOutlined),
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
                  if (ready) ...[
                    OutlinedButton.icon(
                      onPressed: !ready || working ? null : () => capture(true),
                      icon: const Icon(AppIcons.myLocation),
                      label: Text(
                        location == null
                            ? '١. تحديد موقعي الحالي'
                            : 'تحديث موقعي',
                      ),
                    ),
                    if (location != null)
                      BrandCard(
                        child: ListTile(
                          leading: Icon(
                            locationValid
                                ? AppIcons.checkCircleOutline
                                : AppIcons.infoOutline,
                          ),
                          title: Text(
                            location!.isMocked
                                ? 'موقع تجريبي غير مقبول'
                                : insideRadius
                                ? 'أنت داخل نطاق السنتر'
                                : locationAccurate &&
                                      policy?['reviewOutsideRadius'] == true
                                ? 'موقعك خارج النطاق؛ الطلب هيتراجع من الموظف'
                                : 'لم يتأكد وجودك داخل النطاق',
                          ),
                          subtitle: Text(
                            'المسافة ${distance?.round() ?? '—'} متر • دقة الموقع ${location!.accuracyMeters.round()} متر\n${location!.accuracyMeters > maxAccuracy ? 'فعّل الموقع الدقيق أو انتقل لمكان أوضح ثم حدّث الموقع.' : 'المسافة تقديرية؛ السنتر يؤكد نتيجة التسجيل.'}',
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      '٢. صورة من داخل السنتر',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${policy?['landmarkPrompt'] ?? 'وجّه الكاميرا للافتة القاعة أو علامة مميزة في السنتر.'}',
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: photo != null
                              ? Image.memory(photo!, fit: BoxFit.contain)
                              : cameraOpen
                              ? device.cameraPreview()
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        AppIcons.cameraAltOutlined,
                                        size: 42,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        cameraBusy
                                            ? 'جارٍ فتح الكاميرا…'
                                            : 'الكاميرا المباشرة داخل التطبيق',
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'التقاط جديد فقط • لا يمكن رفع صورة',
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: !ready || working || cameraBusy
                          ? null
                          : cameraOpen
                          ? () => capture(false)
                          : openCamera,
                      icon: Icon(
                        cameraOpen
                            ? AppIcons.camera
                            : AppIcons.cameraAltOutlined,
                      ),
                      label: Text(
                        cameraOpen
                            ? 'التقاط الصورة الآن'
                            : photo == null
                            ? '٢. تصوير علامة مميزة بالكاميرا'
                            : 'إعادة التقاط الصورة',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.brand.success,
                        foregroundColor: context.brand.primaryInk,
                      ),
                      onPressed:
                          !ready ||
                              working ||
                              cameraBusy ||
                              !locationValid ||
                              photo == null
                          ? null
                          : submit,
                      icon: const Icon(AppIcons.sendOutlined),
                      label: Text(
                        working
                            ? 'جارٍ تجهيز طلبك…'
                            : locationAccurate &&
                                  !insideRadius &&
                                  policy?['reviewOutsideRadius'] == true
                            ? '٣. إرسال طلب الحضور للمراجعة'
                            : '٣. إرسال وتأكيد الحضور',
                      ),
                    ),
                  ],
                ],
                TextButton.icon(
                  onPressed: working || cameraBusy ? null : load,
                  icon: const Icon(AppIcons.refresh),
                  label: const Text('تحديث حالة الطلب'),
                ),
              ],
            ),
    ),
  );
}
