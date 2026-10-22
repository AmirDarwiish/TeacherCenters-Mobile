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
  Json? selection, centerSelection;
  String? loginTicket;
  bool globalFlow = false;
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
      // Portal accounts always discover their centers after phone verification.
      // Never silently bind a guardian to the build-time demo center.
      globalFlow = student;
      if (!student) {
        api.slug = center.text.trim();
        if (api.slug.isEmpty) {
          throw ApiFailure(
            'تعذر تحديد جهة التعلم. الخدمة تحتاج تحديثًا لتفعيل اختيار السنترات.',
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
            globalFlow
                ? '/mobile/auth/otp/request'
                : '${api.authPath}/otp/request',
            auth: false,
            data: {
              'phone': phone.text.trim(),
              'purpose': guardian ? 'guardian-login' : 'student-login',
            },
          ),
        );
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
        final data = obj(
          await api.call(
            'POST',
            globalFlow
                ? '/mobile/auth/otp/verify'
                : '${api.authPath}/otp/verify',
            auth: false,
            data: {
              if (globalFlow)
                'loginTicket': loginTicket
              else
                'challengeId': challenge,
              'phone': phone.text.trim(),
              'purpose': guardian ? 'guardian-login' : 'student-login',
              'code': code.text.trim(),
            },
          ),
        );
        if (data['requiresCenterSelection'] == true) {
          centerSelection = data;
        } else if (data['requiresStudentSelection'] == true) {
          selection = data;
        } else {
          await api.accept(data);
        }
      }
    } catch (e) {
      error = student && e is ApiFailure && e.status == 404
          ? 'خدمة الدخول الجديدة لم تُنشر على السيرفر بعد. حاول مرة أخرى بعد تحديث الخدمة.'
          : '$e';
      if (e is ApiFailure && e.status == 429) {
        resendAt = DateTime.now().add(Duration(seconds: e.retryAfter ?? 60));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectCenter(Json center, Json account) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    await action(context, () async {
      final tokens = obj(
        await widget.api.call(
          'POST',
          '/mobile/auth/select-center',
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
    });
    if (mounted) setState(() => busy = false);
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
                      color: const Color(0xff1648c4),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xffdce8ff),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: Color(0xff1648c4),
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سنترك',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'تعلّمك أقرب. يومك أوضح.',
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
                    'خلّينا نبدأ',
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
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'student',
                        label: Text('طالب'),
                        icon: Icon(Icons.school_outlined),
                      ),
                      ButtonSegment(
                        value: 'guardian',
                        label: Text('ولي أمر'),
                        icon: Icon(Icons.family_restroom_outlined),
                      ),
                      ButtonSegment(
                        value: 'teacher',
                        label: Text('مدرس'),
                        icon: Icon(Icons.co_present_outlined),
                      ),
                    ],
                    selected: {
                      !student
                          ? 'teacher'
                          : guardian
                          ? 'guardian'
                          : 'student',
                    },
                    onSelectionChanged: busy || challenge != null
                        ? null
                        : (values) => setState(() {
                            student = values.first != 'teacher';
                            guardian = values.first == 'guardian';
                            error = null;
                          }),
                  ),
                  const SizedBox(height: 24),
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
                  if (challenge != null &&
                      selection == null &&
                      centerSelection == null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'أدخل الرمز المرسل إلى ${phone.text}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OtpCodeField(controller: code, enabled: !busy),
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
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.apartment_rounded),
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
                                trailing: const Icon(Icons.arrow_back_rounded),
                                enabled: !busy,
                                onTap: () => selectCenter(c, account),
                              ),
                          ],
                        ),
                      ),
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
                  if (selection == null && centerSelection == null)
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
                              selection = null;
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
