import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key, required this.api});
  final Api api;
  Future<String> student() async {
    final me = obj(await api.get('/portal/me'));
    final list = rows(me['students']);
    if (list.isEmpty) throw ApiFailure('لا يوجد طالب مرتبط');
    return '${list.first['id']}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المدفوعات والمستحقات')),
    body: AsyncPanel(
      load: () async {
        final id = await student();
        return api.get('/portal/students/$id/overview');
      },
      builder: (data, refresh) {
        final balance = obj(obj(data)['balance']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Metric(
              'إجمالي المستحق',
              '${balance['totalDue'] ?? 0} جنيه',
              Icons.account_balance_wallet_outlined,
            ),
            ...rows(balance['charges']).map(
              (c) => Card(
                child: DetailFields({
                  for (final k in ['period', 'amount', 'paid', 'remaining'])
                    k: c[k],
                }),
              ),
            ),
            FilledButton(
              onPressed: () => open(context, CheckoutPage(api: api)),
              child: const Text('دفع المستحقات'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => action(context, () async {
                final id = await student();
                if (context.mounted) {
                  open(
                    context,
                    PageViewList(
                      api: api,
                      path: '/portal/payments',
                      query: {'studentId': id},
                      title: 'سجل المدفوعات',
                      item: (p) => Card(
                        child: ListTile(
                          title: Text('${p['amount']} جنيه · ${p['status']}'),
                          subtitle: Text(when(p['createdAt'])),
                          onTap: () => open(
                            context,
                            PaymentStatusPage(api: api, id: '${p['id']}'),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }),
              child: const Text('سجل عمليات الدفع'),
            ),
          ],
        );
      },
    ),
  );
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.api, this.courseId});
  final Api api;
  final String? courseId;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? method;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الدفع الآمن')),
    body: AsyncPanel(
      load: () => widget.api.get('/portal/payments/config'),
      builder: (data, refresh) {
        final d = obj(data);
        final methods = (d['methods'] as List? ?? []).map((x) => '$x').toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.verified_user_outlined, size: 64),
            const SizedBox(height: 20),
            const Text(
              'اختار طريقة الدفع، وبعدها هنفتح صفحة الدفع الآمنة. حالة العملية بتتأكد من السيرفر.',
            ),
            const SizedBox(height: 20),
            if (d['enabled'] != true || methods.isEmpty)
              const Empty(text: 'الدفع الإلكتروني غير متاح في السنتر حالياً')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: methods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: busy ? null : (m) => setState(() => method = m),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy || method == null
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await action(context, () async {
                          final me = obj(await widget.api.get('/portal/me'));
                          final students = rows(me['students']);
                          if (students.isEmpty) {
                            throw ApiFailure('لا يوجد طالب نشط');
                          }
                          final result = obj(
                            await widget.api.call(
                              'POST',
                              widget.courseId == null
                                  ? '/portal/payments/checkout'
                                  : '/portal/courses/${widget.courseId}/checkout',
                              data: {
                                'studentId': students.first['id'],
                                'method': method,
                                'returnTo': 'portal',
                              },
                            ),
                          );
                          if (result['checkoutUrl'] == null ||
                              result['paymentId'] == null) {
                            throw ApiFailure('لم يرجع السيرفر رابط دفع صالح.');
                          }
                          await launchResource(
                            widget.api,
                            '${result['checkoutUrl']}',
                          );
                          if (context.mounted) {
                            open(
                              context,
                              PaymentStatusPage(
                                api: widget.api,
                                id: '${result['paymentId']}',
                              ),
                            );
                          }
                        });
                        if (mounted) setState(() => busy = false);
                      },
                child: const Text('المتابعة للدفع'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class PaymentStatusPage extends StatelessWidget {
  const PaymentStatusPage({super.key, required this.api, required this.id});
  final Api api;
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حالة الدفع')),
    body: AsyncPanel(
      load: () => api.get('/portal/payments/$id'),
      builder: (data, refresh) {
        final d = obj(data);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              d['status'] == 'Paid'
                  ? Icons.check_circle_outline
                  : Icons.pending_outlined,
              size: 80,
            ),
            DetailFields({
              for (final k in [
                'status',
                'amount',
                'method',
                'receiptNumber',
                'kioskReference',
                'failureReason',
              ])
                k: d[k],
            }),
            FilledButton.tonal(
              onPressed: refresh,
              child: const Text('تحديث حالة العملية'),
            ),
          ],
        );
      },
    ),
  );
}
