import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';

String money(dynamic amount) =>
    '${NumberFormat('#,##0.##', 'ar').format(amount is num ? amount : 0)} ج.م';
String paymentMethod(String value) =>
    const {
      'Card': 'بطاقة بنكية',
      'Wallet': 'محفظة إلكترونية',
      'Kiosk': 'كود دفع نقدي',
    }[value] ??
    'دفع إلكتروني';
String paymentState(dynamic value) =>
    const {
      'Pending': 'في انتظار الدفع',
      'Paid': 'تم الدفع',
      'Failed': 'لم يكتمل الدفع',
      'Expired': 'انتهت مهلة الدفع',
      'Cancelled': 'ملغاة',
      'Canceled': 'ملغاة',
      'Refunded': 'تم الاسترداد',
      'PartiallyRefunded': 'استرداد جزئي',
      'NeedsReview': 'قيد المراجعة',
    }[value] ??
    'جارٍ التأكيد';
Future<String> portalPayer(Api api) async {
  if (api.portalStudentId != null) return api.portalStudentId!;
  final students = rows(obj(await api.get('/portal/me'))['students']);
  if (students.isEmpty) throw ApiFailure('الحساب غير مرتبط بطالب نشط.');
  return '${students.first['id']}';
}

String chargeTitle(Json charge) =>
    '${charge['title'] ?? (charge['period'] == 'course' ? 'اشتراك كورس' : 'مستحقات دراسية')}';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key, required this.api});
  final Api api;
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  Set<String>? selected;
  String filter = 'غير المسددة';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حسابي المالي')),
    body: AsyncPanel(
      load: () async {
        final id = await portalPayer(widget.api);
        return {
          'studentId': id,
          'overview': await widget.api.get('/portal/students/$id/overview'),
        };
      },
      builder: (data, refresh) {
        final root = obj(data),
            overview = obj(root['overview']),
            balance = obj(overview['balance']);
        final charges = rows(balance['charges']),
            colors = Theme.of(context).colorScheme;
        final unpaid = charges
            .where((c) => (c['remaining'] as num? ?? 0) > 0)
            .map((c) => '${c['id']}')
            .toSet();
        selected ??= Set.of(unpaid);
        selected!.retainAll(unpaid);
        final paid = charges.fold<num>(
          0,
          (n, c) => n + (c['paid'] as num? ?? 0),
        );
        final chosen = charges
            .where((c) => selected!.contains('${c['id']}'))
            .toList();
        final amount = chosen.fold<num>(
          0,
          (n, c) => n + (c['remaining'] as num? ?? 0),
        );
        final visible = charges
            .where(
              (c) =>
                  filter == 'الكل' ||
                  (filter == 'غير المسددة'
                      ? (c['remaining'] as num? ?? 0) > 0
                      : (c['remaining'] as num? ?? 0) <= 0),
            )
            .toList();
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المطلوب سداده',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: .8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          money(balance['totalDue']),
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'إجمالي المسدد ${money(paid)}',
                          style: TextStyle(color: colors.onPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${unpaid.length} بنود متبقية',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: .8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => open(
                      context,
                      PaymentHistoryPage(
                        api: widget.api,
                        studentId: '${root['studentId']}',
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('سجل عمليات الدفع'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'تفاصيل المستحقات',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (unpaid.isNotEmpty && !widget.api.guardian)
                        TextButton(
                          onPressed: () => setState(
                            () => selected = selected!.length == unpaid.length
                                ? {}
                                : Set.of(unpaid),
                          ),
                          child: Text(
                            selected!.length == unpaid.length
                                ? 'إلغاء التحديد'
                                : 'تحديد الكل',
                          ),
                        ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['غير المسددة', 'مدفوعة', 'الكل']
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: filter == f,
                                onSelected: (_) => setState(() => filter = f),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    Empty(
                      text: charges.isEmpty
                          ? 'لا توجد مستحقات مسجلة حالياً.'
                          : filter == 'غير المسددة'
                          ? 'كل مستحقاتك مسددة. حسابك مفيهوش مبالغ متبقية.'
                          : 'لا توجد بنود في هذا القسم.',
                    ),
                  for (final c in visible)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if ((c['remaining'] as num? ?? 0) > 0 &&
                                    !widget.api.guardian)
                                  Checkbox(
                                    value: selected!.contains('${c['id']}'),
                                    onChanged: (v) => setState(() {
                                      v == true
                                          ? selected!.add('${c['id']}')
                                          : selected!.remove('${c['id']}');
                                    }),
                                  ),
                                Expanded(
                                  child: Text(
                                    chargeTitle(c),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    (c['remaining'] as num? ?? 0) <= 0
                                        ? 'مسدد'
                                        : (c['paid'] as num? ?? 0) > 0
                                        ? 'سداد جزئي'
                                        : 'مستحق',
                                  ),
                                ),
                              ],
                            ),
                            if (c['period'] != null && c['period'] != 'course')
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text('الفترة: ${c['period']}'),
                              ),
                            const Divider(),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 22,
                              runSpacing: 12,
                              children: [
                                _amount(context, 'الإجمالي', c['amount']),
                                _amount(context, 'المدفوع', c['paid']),
                                _amount(context, 'المتبقي', c['remaining']),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!widget.api.guardian && unpaid.isNotEmpty)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: colors.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${selected!.length} بنود محددة'),
                            Text(
                              money(amount),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: selected!.isEmpty
                            ? null
                            : () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutPage(
                                      api: widget.api,
                                      studentId: '${root['studentId']}',
                                      chargeIds: selected!.toList(),
                                    ),
                                  ),
                                );
                                if (context.mounted) refresh();
                              },
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('سداد المحدد'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _amount(BuildContext context, String title, dynamic value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      Text(money(value), style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({
    super.key,
    required this.api,
    required this.studentId,
  });
  final Api api;
  final String studentId;
  @override
  Widget build(BuildContext context) => PageViewList(
    api: api,
    path: '/portal/payments',
    query: {'studentId': studentId},
    title: 'سجل عمليات الدفع',
    item: (p) => Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Icon(
          p['status'] == 'Paid'
              ? Icons.check_circle_outline
              : Icons.receipt_long_outlined,
        ),
        title: Text(
          money(p['amount']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${paymentState(p['status'])} • ${paymentMethod('${p['method']}')}\n${when(p['createdAt'])}',
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () =>
            open(context, PaymentStatusPage(api: api, id: '${p['id']}')),
      ),
    ),
  );
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.api,
    this.courseId,
    this.studentId,
    this.chargeIds,
  });
  final Api api;
  final String? courseId, studentId;
  final List<String>? chargeIds;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? method;
  bool busy = false;
  final coupon = TextEditingController();
  String key = _key();
  static String _key() => base64Url
      .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  @override
  void dispose() {
    coupon.dispose();
    super.dispose();
  }

  Future<Json> load() async {
    final student = widget.studentId ?? await portalPayer(widget.api);
    final config = await widget.api.get('/portal/payments/config');
    final detail = obj(
      await widget.api.get(
        widget.courseId == null
            ? '/portal/students/$student/overview'
            : '/portal/courses/${widget.courseId}',
      ),
    );
    final charges = rows(obj(detail['balance'])['charges'])
        .where(
          (c) =>
              (c['remaining'] as num? ?? 0) > 0 &&
              (widget.chargeIds == null ||
                  widget.chargeIds!.contains('${c['id']}')),
        )
        .toList();
    return {
      'studentId': student,
      'config': config,
      'detail': detail,
      'charges': charges,
    };
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('مراجعة الدفع')),
      body: AsyncPanel(
        load: load,
        builder: (data, refresh) {
          final root = obj(data),
              config = obj(root['config']),
              detail = obj(root['detail']),
              charges = rows(root['charges']);
          final methods = (config['methods'] as List? ?? [])
              .map((m) => m is Map ? '${m['key'] ?? ''}' : '$m')
              .where((m) => ['Card', 'Wallet', 'Kiosk'].contains(m))
              .toSet()
              .toList();
          final amount = widget.courseId == null
              ? charges.fold<num>(
                  0,
                  (n, c) => n + (c['remaining'] as num? ?? 0),
                )
              : detail['price'] as num? ?? 0;
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                'راجع طلبك قبل الدفع',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'اختر وسيلة مناسبة ليك. تقدر تراجع حالة العملية لما ترجع للتطبيق.',
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.courseId == null
                            ? 'سداد المستحقات'
                            : label(detail),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      if (widget.courseId == null)
                        ...charges.map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(chargeTitle(c))),
                                Text(money(c['remaining'])),
                              ],
                            ),
                          ),
                        ),
                      const Divider(),
                      Text(
                        'الإجمالي ${money(amount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 23,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (config['enabled'] != true)
                const Empty(
                  text:
                      'الدفع الإلكتروني مش متاح في السنتر حالياً. تواصل مع السنتر لطرق السداد المتاحة.',
                )
              else if (methods.isEmpty)
                const Empty(
                  text:
                      'لا توجد وسيلة دفع متاحة لهذا الطلب. حدّث الصفحة أو تواصل مع السنتر.',
                )
              else if (amount <= 0)
                const Empty(text: 'لا توجد مبالغ متبقية للدفع.')
              else ...[
                Text(
                  'وسيلة الدفع',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final m in methods)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        m == 'Card'
                            ? Icons.credit_card
                            : m == 'Wallet'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.qr_code_rounded,
                      ),
                      title: Text(paymentMethod(m)),
                      subtitle: Text(
                        m == 'Card'
                            ? 'أكمل بيانات بطاقتك في صفحة الدفع'
                            : m == 'Wallet'
                            ? 'الدفع من محفظتك الإلكترونية'
                            : 'استخدم كود العملية لدى منفذ الدفع',
                      ),
                      trailing: Icon(
                        method == m
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: method == m
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      onTap: busy
                          ? null
                          : () => setState(() {
                              method = m;
                              key = _key();
                            }),
                    ),
                  ),
                if (widget.courseId != null)
                  TextField(
                    controller: coupon,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'كود خصم — اختياري',
                    ),
                    onChanged: (_) => key = _key(),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'فتح صفحة الدفع لا يعني نجاح العملية. بنعرض التأكيد والإيصال بعد تسجيل النتيجة لدى السنتر.',
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy || method == null
                      ? null
                      : () => checkout(root),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(busy ? 'جارٍ تجهيز العملية…' : 'المتابعة للدفع'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
  Future<void> checkout(Json root) async {
    setState(() => busy = true);
    await action(context, () async {
      final result = obj(
        await widget.api.call(
          'POST',
          widget.courseId == null
              ? '/portal/payments/checkout'
              : '/portal/courses/${widget.courseId}/checkout',
          headers: {'Idempotency-Key': key},
          data: {
            'studentId': root['studentId'],
            'method': method,
            'returnTo': 'portal',
            if (widget.courseId == null)
              'chargeIds': rows(root['charges']).map((c) => c['id']).toList(),
            if (widget.courseId != null && coupon.text.trim().isNotEmpty)
              'couponCode': coupon.text.trim(),
          },
        ),
      );
      if (result['paymentId'] == null) {
        throw ApiFailure(
          'تعذر تأكيد إنشاء العملية. راجع سجل الدفع قبل إعادة المحاولة.',
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PaymentStatusPage(
            api: widget.api,
            id: '${result['paymentId']}',
            checkoutUrl: result['checkoutUrl'] as String?,
          ),
        ),
      );
    });
    if (mounted) setState(() => busy = false);
  }
}

class PaymentStatusPage extends StatefulWidget {
  const PaymentStatusPage({
    super.key,
    required this.api,
    required this.id,
    this.checkoutUrl,
  });
  final Api api;
  final String id;
  final String? checkoutUrl;
  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage>
    with WidgetsBindingObserver {
  Json? payment;
  Object? error;
  bool fetching = false, foreground = true;
  int polls = 0;
  Timer? timer;
  bool get terminal => [
    'Paid',
    'Failed',
    'Expired',
    'Cancelled',
    'Canceled',
    'Refunded',
    'PartiallyRefunded',
  ].contains(payment?['status']);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (foreground && !terminal && polls++ < 30) refresh();
    });
    if (widget.checkoutUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          action(
            context,
            () => launchResource(widget.api, widget.checkoutUrl!),
          );
        }
      });
    }
  }

  Future<void> refresh() async {
    if (fetching) return;
    setState(() => fetching = true);
    try {
      final next = obj(await widget.api.get('/portal/payments/${widget.id}'));
      if (mounted) {
        setState(() {
          payment = next;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => fetching = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = payment ?? {},
        success = p['status'] == 'Paid',
        colors = Theme.of(context).colorScheme;
    final expiry = DateTime.tryParse('${p['expiresAt']}');
    return Scaffold(
      appBar: AppBar(title: const Text('متابعة عملية الدفع')),
      body: payment == null && fetching
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: success
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        success
                            ? Icons.check_circle_rounded
                            : terminal
                            ? Icons.info_outline_rounded
                            : Icons.hourglass_top_rounded,
                        size: 65,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        payment == null
                            ? 'تعذر تحديث العملية'
                            : paymentState(p['status']),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (payment != null)
                        Text(
                          money(p['amount']),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      const SizedBox(height: 12),
                      Text(
                        success
                            ? 'تم تسجيل الدفع. راجع الإيصال وتفاصيل حسابك.'
                            : terminal
                            ? 'راجع تفاصيل العملية أدناه قبل بدء دفع جديد.'
                            : 'لو دفعت بالفعل، انتظر تأكيد العملية. لا تعيد الدفع أثناء انتظار النتيجة.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('$error'),
                    ),
                  ),
                if (p['method'] != null)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('وسيلة الدفع'),
                    subtitle: Text(paymentMethod('${p['method']}')),
                  ),
                if (p['receiptNumber'] != null)
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('رقم الإيصال'),
                    subtitle: SelectableText('${p['receiptNumber']}'),
                  ),
                if (p['kioskReference'] != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.qr_code_rounded),
                      title: const Text('كود السداد'),
                      subtitle: SelectableText(
                        '${p['kioskReference']}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'نسخ كود السداد',
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: '${p['kioskReference']}'),
                        ),
                        icon: const Icon(Icons.copy),
                      ),
                    ),
                  ),
                if (expiry != null)
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('مهلة الدفع'),
                    subtitle: Text(when(p['expiresAt'])),
                  ),
                if (p['failureReason'] != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('${p['failureReason']}'),
                    ),
                  ),
                if (!terminal &&
                    widget.checkoutUrl != null &&
                    (expiry == null || expiry.isAfter(DateTime.now())))
                  FilledButton.icon(
                    onPressed: () => action(
                      context,
                      () => launchResource(widget.api, widget.checkoutUrl!),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح صفحة الدفع'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: fetching ? null : refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    fetching ? 'جارٍ التحديث…' : 'تحديث حالة العملية',
                  ),
                ),
              ],
            ),
    );
  }
}
