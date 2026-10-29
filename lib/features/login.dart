import '../core/app_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/brand.dart';
import '../core/brand_logo.dart';
import '../core/otp_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api});
  final Api api;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phone = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  final form = GlobalKey<FormState>();
  bool student = true, guardian = false, busy = false;
  String? challenge, error, centerName;
  Json? centerSelection;
  String? loginTicket, lastOtpAttempt;
  DateTime? resendAt;
  Timer? timer;
  int get remaining => resendAt == null
      ? 0
      : resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 3600);
  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> acceptLogin(Json data) async {
    if (data['requiresCenterSelection'] == true) {
      centerSelection = data;
      final centers = rows(data['centers']);
      if (centers.length == 1 && rows(centers.single['accounts']).length == 1) {
        await issueCenter(
          centers.single,
          rows(centers.single['accounts']).single,
        );
      }
      return;
    }
    widget.api.slug = '${obj(data['tenant'])['slug'] ?? ''}';
    await widget.api.accept(data);
  }

  void completeOtp(String value) {
    if (!busy &&
        challenge != null &&
        centerSelection == null &&
        value != lastOtpAttempt) {
      submit();
    }
  }

  Future<void> submit() async {
    if (busy ||
        student && challenge == null && remaining > 0 ||
        !form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = widget.api;
      if (!student) {
        await acceptLogin(
          obj(
            await api.call(
              'POST',
              '/mobile/auth/staff/login',
              auth: false,
              data: {'phone': phone.text.trim(), 'password': password.text},
            ),
          ),
        );
      } else if (challenge == null) {
        final data = obj(
          await api.call(
            'POST',
            '/mobile/auth/otp/request',
            auth: false,
            data: {
              'phone': phone.text.trim(),
              'purpose': guardian ? 'guardian-login' : 'student-login',
            },
          ),
        );
        lastOtpAttempt = null;
        challenge = '${data['challengeId']}';
        loginTicket = data['loginTicket'] as String?;
        resendAt = DateTime.now().add(
          Duration(seconds: (data['resendAfterSeconds'] as num? ?? 60).toInt()),
        );
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      } else {
        lastOtpAttempt = code.text;
        await acceptLogin(
          obj(
            await api.call(
              'POST',
              '/mobile/auth/otp/verify',
              auth: false,
              data: {
                'loginTicket': loginTicket,
                'phone': phone.text.trim(),
                'purpose': guardian ? 'guardian-login' : 'student-login',
                'code': code.text.trim(),
              },
            ),
          ),
        );
      }
    } catch (e) {
      error = e is ApiFailure && e.status == 404
          ? 'خدمة الدخول الجديدة تحتاج نشر آخر تحديث على السيرفر.'
          : '$e';
      if (e is ApiFailure && e.status == 429) {
        resendAt = DateTime.now().add(Duration(seconds: e.retryAfter ?? 60));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> issueCenter(Json center, Json account) async {
    final tokens = obj(
      await widget.api.call(
        'POST',
        student
            ? '/mobile/auth/select-center'
            : '/mobile/auth/staff/select-center',
        auth: false,
        data: {
          'selectionToken': centerSelection!['selectionToken'],
          'tenantId': center['tenantId'],
          'subjectId': account['subjectId'],
        },
      ),
    );
    widget.api.slug = '${obj(tokens['tenant'])['slug'] ?? center['slug']}';
    await widget.api.accept(tokens);
  }

  Future<void> selectCenter(Json center, Json account) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await issueCenter(center, account);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: BrandColors.night,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RewaqLogo(inverse: true, stacked: true, size: 168),
                        SizedBox(height: 16),
                        Text(
                          'إدارة دروسك كلها من مكان واحد',
                          style: TextStyle(
                            color: BrandColors.onNavyMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'أهلًا بيك في رواق',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    centerName ?? 'دروسك وحضورك ومتابعتك، في مكان واحد',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'student',
                        label: Text('طالب'),
                        icon: Icon(AppIcons.schoolOutlined),
                      ),
                      ButtonSegment(
                        value: 'guardian',
                        label: Text('ولي أمر'),
                        icon: Icon(AppIcons.familyRestroomOutlined),
                      ),
                      ButtonSegment(
                        value: 'teacher',
                        label: Text('مدرس'),
                        icon: Icon(AppIcons.coPresentOutlined),
                      ),
                    ],
                    selected: {
                      !student
                          ? 'teacher'
                          : guardian
                          ? 'guardian'
                          : 'student',
                    },
                    onSelectionChanged:
                        busy || challenge != null || centerSelection != null
                        ? null
                        : (values) => setState(() {
                            student = values.first != 'teacher';
                            guardian = values.first == 'guardian';
                            error = null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: phone,
                    enabled: !busy && challenge == null,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    inputFormatters: [
                      const ArabicDigitsFormatter(),
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'رقم الموبايل',
                      counterText: '',
                      prefixIcon: Icon(AppIcons.phoneOutlined),
                    ),
                    validator: (v) => RegExp(r'^[0-9]{11}$').hasMatch(v ?? '')
                        ? null
                        : 'اكتب رقم الموبايل المكوّن من ١١ رقم',
                  ),
                  if (!student) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(AppIcons.lockOutline),
                      ),
                      validator: (v) =>
                          v?.isNotEmpty == true ? null : 'اكتب كلمة المرور',
                    ),
                  ],
                  if (challenge != null && centerSelection == null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'أدخل الرمز المرسل إلى ${phone.text}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OtpCodeField(
                      controller: code,
                      enabled: !busy,
                      onCompleted: completeOtp,
                    ),
                  ],
                  if (centerSelection != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'اختر السنتر',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'دي الحسابات المرتبطة برقمك. اختار المكان اللي تحب تدخل عليه.',
                    ),
                    const SizedBox(height: 14),
                    for (final c in rows(centerSelection!['centers']))
                      BrandCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: const Icon(AppIcons.apartmentRounded),
                              title: Text(
                                '${c['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            for (final account in rows(c['accounts']))
                              ListTile(
                                title: Text('${account['fullName']}'),
                                trailing: const Icon(AppIcons.arrowBackRounded),
                                enabled: !busy,
                                onTap: () => selectCenter(c, account),
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (centerSelection == null)
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                !student
                                    ? 'دخول المدرس'
                                    : challenge == null
                                    ? 'إرسال رمز التحقق'
                                    : 'تأكيد ودخول',
                              ),
                      ),
                    ),
                  if (challenge != null)
                    TextButton(
                      onPressed: busy || remaining > 0
                          ? null
                          : () {
                              setState(() {
                                challenge = null;
                                centerSelection = null;
                                loginTicket = null;
                                code.clear();
                              });
                              submit();
                            },
                      child: Text(
                        remaining > 0
                            ? 'إعادة الإرسال بعد $remaining ثانية'
                            : 'إرسال رمز جديد',
                      ),
                    ),
                  if (challenge != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              challenge = null;
                              centerSelection = null;
                              loginTicket = null;
                              code.clear();
                              error = null;
                            }),
                      child: const Text('تغيير بيانات الدخول'),
                    ),
                  if (!student)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('استعادة كلمة المرور'),
                                content: const Text(
                                  'تواصل مع إدارة السنتر لإعادة تعيين كلمة مرور حساب المدرس.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('تمام'),
                                  ),
                                ],
                              ),
                            ),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
