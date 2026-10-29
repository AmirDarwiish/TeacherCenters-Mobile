import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/brand.dart';

class PushSettingsPage extends StatefulWidget {
  const PushSettingsPage({super.key, required this.api});
  final Api api;
  @override
  State<PushSettingsPage> createState() => _PushSettingsPageState();
}

class _PushSettingsPageState extends State<PushSettingsPage> {
  late Future<Json> server = load();
  bool busy = false;
  Future<Json> load() async => obj(await widget.api.get('/devices/status'));
  Future<void> enable() async {
    setState(() => busy = true);
    try {
      await widget.api.enablePush?.call();
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          server = load();
        });
    }
  }

  String serverText(Json value) {
    if (value['serverEnabled'] != true)
      return 'إرسال الإشعارات غير مفعّل من السنتر.';
    if (value['providerConfigured'] != true)
      return 'إعداد خدمة الإشعارات في السنتر غير مكتمل.';
    if ((value['activeDevices'] as num? ?? 0) == 0)
      return 'خدمة السنتر جاهزة، لكن مفيش أجهزة متسجلة للحساب. فعّل الإشعارات وأعد المحاولة.';
    return 'خدمة السنتر جاهزة، وفيه أجهزة متسجلة للحساب.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إعداد الإشعارات')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اعرف حالة الإشعارات على جهازك، واسمح بيها عشان توصلك رسائل المدرس والتطبيق في الخلفية.',
          ),
          const SizedBox(height: 16),
          BrandCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: widget.api,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'حالة الجهاز',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(widget.api.pushStatus),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy || !widget.api.pushAvailable
                          ? null
                          : enable,
                      child: Text(
                        busy ? 'بنراجع الإعدادات…' : 'تفعيل أو إعادة المحاولة',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          BrandCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ربط الحساب بالسنتر',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Json>(
                    future: server,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done)
                        return const LinearProgressIndicator();
                      if (snapshot.hasError)
                        return const Text(
                          'تعذر التحقق من حالة السنتر. قد يحتاج تحديث خدمة الإشعارات أو إعادة الاتصال.',
                        );
                      return Text(serverText(snapshot.data ?? {}));
                    },
                  ),
                  TextButton(
                    onPressed: () => setState(() => server = load()),
                    child: const Text('تحديث الحالة'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'لو تنبيهات الرسائل مقفولة من إعدادات Android، فعّلها لتطبيق رواق. الإذن وحده مش كفاية لو خدمات Google Play غير متوفرة أو متوقفة.',
          ),
          const SizedBox(height: 24),
          Text(
            'رواق ${const String.fromEnvironment('APP_VERSION', defaultValue: '1.7.1+10')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
