import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
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
  late final center = TextEditingController(text: widget.api.slug);
  final form = GlobalKey<FormState>();
  bool student = true, guardian = false, busy = false;
  String? challenge, error, centerName;
  Json? selection;
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
    center.dispose();
    super.dispose();
  }

  Future<void> submit({String? studentId}) async {
    if (busy ||
        student && challenge == null && remaining > 0 ||
        studentId == null && !form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = widget.api;
      if (!student) api.slug = center.text.trim();
      if (api.slug.isEmpty) {
        throw ApiFailure(
          'تعذر تحديد جهة التعلم. افتح التطبيق من رابط السنتر أو استخدم نسخته المخصصة.',
        );
      }
      if (centerName == null) {
        final tenant = obj(
          await api.call(
            'GET',
            '/t/${Uri.encodeComponent(api.slug)}',
            auth: false,
          ),
        );
        centerName = '${tenant['name']}';
      }
      if (!student) {
        await api.accept(
          obj(
            await api.call(
              'POST',
              '${api.authPath}/login',
              auth: false,
              data: {'phone': phone.text.trim(), 'password': password.text},
            ),
          ),
        );
      } else if (studentId != null) {
        await api.accept(
          obj(
            await api.call(
              'POST',
              '${api.authPath}/otp/select-student',
              auth: false,
              data: {
                'selectionToken': selection!['selectionToken'],
                'studentId': studentId,
              },
            ),
          ),
        );
      } else if (challenge == null) {
        final data = obj(
          await api.call(
            'POST',
            '${api.authPath}/otp/request',
            auth: false,
            data: {
              'phone': phone.text.trim(),
              'purpose': guardian ? 'guardian-login' : 'student-login',
            },
          ),
        );
        challenge = '${data['challengeId']}';
        resendAt = DateTime.now().add(
          Duration(seconds: (data['resendAfterSeconds'] as num? ?? 60).toInt()),
        );
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      } else {
        final data = obj(
          await api.call(
            'POST',
            '${api.authPath}/otp/verify',
            auth: false,
            data: {
              'challengeId': challenge,
              'phone': phone.text.trim(),
              'purpose': guardian ? 'guardian-login' : 'student-login',
              'code': code.text.trim(),
            },
          ),
        );
        if (data['requiresStudentSelection'] == true) {
          selection = data;
        } else {
          await api.accept(data);
        }
      }
    } catch (e) {
      error = '$e';
      if (e is ApiFailure && e.status == 429) {
        resendAt = DateTime.now().add(Duration(seconds: e.retryAfter ?? 60));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                      color: const Color(0xff153f37),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xffd4efbf),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: Color(0xff153f37),
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TeacherCenters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'مساحة واحدة. فرص أكبر.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'مساحتك للتعلم',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    centerName ?? 'حضورك، دروسك، ونجاحك في مكان واحد',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('طالب / ولي أمر'),
                        icon: Icon(Icons.school_outlined),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('أنا مدرس'),
                        icon: Icon(Icons.co_present_outlined),
                      ),
                    ],
                    selected: {student},
                    onSelectionChanged: busy || challenge != null
                        ? null
                        : (v) => setState(() {
                            student = v.first;
                            error = null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  if (student && challenge == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('طالب')),
                          ButtonSegment(value: true, label: Text('ولي أمر')),
                        ],
                        selected: {guardian},
                        onSelectionChanged: busy
                            ? null
                            : (v) => setState(() {
                                guardian = v.first;
                                error = null;
                              }),
                      ),
                    ),
                  if (!student)
                    TextFormField(
                      controller: center,
                      enabled: !busy && challenge == null,
                      decoration: const InputDecoration(
                        labelText: 'رابط السنتر أو اسمه في الرابط',
                        hintText: 'teachercenter-demo',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      textDirection: TextDirection.ltr,
                      onChanged: (_) => centerName = null,
                      validator: (v) =>
                          RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'اكتب اسم السنتر الموجود في الرابط',
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phone,
                    enabled: !busy && challenge == null,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'رقم الموبايل',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        (v?.replaceAll(RegExp(r'\D'), '').length ?? 0) >= 10
                        ? null
                        : 'اكتب رقم موبايل صحيح',
                  ),
                  if (!student) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) =>
                          v?.isNotEmpty == true ? null : 'اكتب كلمة المرور',
                    ),
                  ],
                  if (challenge != null && selection == null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'أدخل الرمز المرسل إلى ${phone.text}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OtpCodeField(controller: code, enabled: !busy),
                  ],
                  if (selection != null) ...[
                    const SizedBox(height: 16),
                    const Text('اختار حساب الطالب'),
                    ...rows(selection!['students']).map(
                      (s) => Card(
                        child: ListTile(
                          title: Text('${s['fullName']}'),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: busy
                              ? null
                              : () => submit(studentId: '${s['studentId']}'),
                        ),
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
                  if (selection == null)
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
                                selection = null;
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
                              selection = null;
                              code.clear();
                              error = null;
                            }),
                      child: const Text('تغيير بيانات الدخول'),
                    ),
                  if (!student)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => action(context, () async {
                              widget.api.slug = center.text.trim();
                              await widget.api.call(
                                'POST',
                                '${widget.api.authPath}/password/forgot',
                                auth: false,
                                data: {'phone': phone.text.trim()},
                              );
                              if (context.mounted) {
                                toast(
                                  context,
                                  'تم طلب استعادة كلمة المرور. راجع وسيلة التواصل المسجلة.',
                                );
                              }
                            }),
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
