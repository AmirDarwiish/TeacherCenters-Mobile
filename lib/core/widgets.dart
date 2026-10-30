import 'brand.dart';
import 'app_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'format.dart';
import 'motion.dart';
export 'format.dart';
export 'motion.dart';

import 'api.dart';

String when(dynamic value) => cairoWhen(value);

void open(BuildContext context, Widget child) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => child));
void toast(BuildContext context, Object text) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text('$text')));
Future<void> action(
  BuildContext context,
  Future<void> Function() work, {
  String? success,
}) async {
  try {
    await work();
    if (context.mounted && success != null) toast(context, success);
  } catch (e) {
    if (context.mounted) toast(context, e);
  }
}

Future<bool> confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ??
    false;

class AsyncPanel extends StatefulWidget {
  const AsyncPanel({
    super.key,
    required this.load,
    this.changes,
    required this.builder,
  });
  final Stream<String>? changes;
  final Future<dynamic> Function() load;
  final Widget Function(dynamic data, VoidCallback refresh) builder;
  @override
  State<AsyncPanel> createState() => _AsyncPanelState();
}

class _AsyncPanelState extends State<AsyncPanel> {
  late Future<dynamic> data;
  StreamSubscription<String>? subscription;
  @override
  void initState() {
    super.initState();
    subscription = widget.changes?.listen((_) {
      if (mounted) setState(reload);
    });
    reload();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void reload() {
    data = widget.load();
  }

  @override
  void didUpdateWidget(covariant AsyncPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: data,
    builder: (context, s) {
      void refresh() => setState(reload);
      if (s.connectionState != ConnectionState.done) {
        return const BrandLoading();
      }
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.cloudOffRounded, size: 48),
                const SizedBox(height: 16),
                Text('${s.error}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: refresh,
                  child: const Text('حاول تاني'),
                ),
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          refresh();
          await data;
        },
        child: widget.builder(s.data, refresh),
      );
    },
  );
}

class BrandLoading extends StatelessWidget {
  const BrandLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'جارٍ تحميل المحتوى',
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ExcludeSemantics(
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final height in [40.0, 120.0, 120.0, 80.0])
                Container(
                  height: height,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.brand.skeleton,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Empty extends StatelessWidget {
  const Empty({
    super.key,
    this.text = 'مفيش بيانات لعرضها دلوقتي',
    this.onAction,
    this.actionLabel = 'تحديث',
  });
  final String text, actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.brand.primaryTint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            AppIcons.inboxOutlined,
            size: 64,
            color: context.brand.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        if (onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(this.title, this.value, this.icon, {super.key});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => BrandCard(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            arNumber(value),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(title),
        ],
      ),
    ),
  );
}

class PageViewList extends StatelessWidget {
  const PageViewList({
    super.key,
    required this.api,
    required this.path,
    required this.title,
    required this.item,
    this.query = const {},
  });
  final Api api;
  final String path, title;
  final Json query;
  final Widget Function(Json) item;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(flexibleSpace: const BrandHeader(), title: Text(title)),
    body: PagedList(api: api, path: path, query: query, item: item),
  );
}

class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.api,
    required this.path,
    required this.item,
    this.query = const {},
  });
  final Api api;
  final String path;
  final Json query;
  final Widget Function(Json) item;
  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  final List<Json> items = [];
  int page = 1;
  bool busy = false, more = true;
  Object? error;
  int epoch = 0;
  StreamSubscription<String>? subscription;
  @override
  void initState() {
    super.initState();
    subscription = widget.api.live.events.listen((event) {
      final path = widget.path;
      if (event == 'Reconnected' ||
          event == 'ThreadChanged' && path.contains('threads') ||
          event == 'ChatChanged' && path.startsWith('/chat/') ||
          event == 'NotificationsChanged' && path.contains('notifications')) {
        fetch(reset: true);
      }
    });
    fetch(reset: true);
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.query.toString() != widget.query.toString()) {
      fetch(reset: true);
    }
  }

  Future<void> fetch({bool reset = false}) async {
    if (busy && !reset) return;
    if (reset) {
      epoch++;
      items.clear();
      page = 1;
      more = true;
    }
    final request = epoch;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.api.get(
        widget.path,
        query: {...widget.query, 'page': page, 'pageSize': 20},
      );
      if (!mounted || request != epoch) return;
      final next = rows(data);
      setState(() {
        items.addAll(next);
        final total = obj(data)['totalCount'];
        more =
            data is! List &&
            next.isNotEmpty &&
            (total is num ? items.length < total : next.length == 20);
        page++;
      });
    } catch (e) {
      if (mounted && request == epoch) setState(() => error = e);
    } finally {
      if (mounted && request == epoch) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => fetch(reset: true),
    child: ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ...items.map(widget.item),
        if (!busy && items.isEmpty && error == null)
          Empty(onAction: () => fetch(reset: true)),
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!busy && (more || error != null))
          TextButton(
            onPressed: fetch,
            child: Text(error != null ? 'حاول تاني' : 'عرض المزيد'),
          ),
      ],
    ),
  );
}

class DetailFields extends StatelessWidget {
  const DetailFields(this.data, {super.key});
  final Json data;
  @override
  Widget build(BuildContext context) => Column(
    children: data.entries
        .where(
          (e) =>
              fieldNames.containsKey(e.key) &&
              e.value != null &&
              e.value is! Map &&
              e.value is! List &&
              ![
                'rowVersion',
                'id',
                'studentId',
                'teacherId',
                'qrToken',
              ].contains(e.key),
        )
        .map(
          (e) => ListTile(
            title: Text(fieldNames[e.key] ?? e.key),
            subtitle: Text(
              e.value is bool
                  ? (e.value == true ? 'نعم' : 'لا')
                  : e.key == 'status'
                  ? (const {
                          'Published': 'منشور',
                          'Draft': 'مسودة',
                          'Pending': 'قيد الانتظار',
                          'Submitted': 'تم التسليم',
                          'Graded': 'تم التصحيح',
                          'Completed': 'مكتمل',
                          'Active': 'نشط',
                          'Closed': 'مغلق',
                          'Present': 'حاضر',
                          'Absent': 'غائب',
                          'Late': 'متأخر',
                        }[e.value] ??
                        '${e.value}')
                  : [
                      'phone',
                      'email',
                      'code',
                      'receiptNumber',
                      'kioskReference',
                      'certificateNumber',
                      'serialNumber',
                    ].contains(e.key)
                  ? '${e.value}'
                  : e.value is num
                  ? arNumber(e.value)
                  : '${e.value}',
              textDirection:
                  [
                    'phone',
                    'email',
                    'code',
                    'receiptNumber',
                    'kioskReference',
                    'certificateNumber',
                    'serialNumber',
                  ].contains(e.key)
                  ? TextDirection.ltr
                  : TextDirection.rtl,
            ),
          ),
        )
        .toList(),
  );
}

const fieldNames = {
  'status': 'الحالة',
  'score': 'الدرجة',
  'maxScore': 'الدرجة النهائية',
  'percent': 'النسبة',
  'passed': 'ناجح',
  'title': 'العنوان',
  'fullName': 'الاسم',
  'code': 'الكود',
  'grade': 'الصف',
  'phone': 'الموبايل',
  'email': 'البريد',
  'name': 'الاسم',
  'role': 'الدور',
  'amount': 'المبلغ',
  'remaining': 'المتبقي',
  'paid': 'المدفوع',
  'period': 'الفترة',
  'totalDue': 'إجمالي المستحق',
  'receiptNumber': 'رقم الإيصال',
  'method': 'طريقة الدفع',
  'failureReason': 'سبب التعثر',
  'kioskReference': 'كود الدفع',
  'progressPercent': 'التقدم',
  'requiredPercent': 'النسبة المطلوبة',
  'eligible': 'مستحق للشهادة',
  'quizzesPassed': 'اجتاز الامتحانات',
  'marks': 'درجة السؤال',
  'marksAwarded': 'الدرجة المكتسبة',
  'teacherComment': 'تعليق المدرس',
  'explanation': 'التفسير',
  'attendancePercent': 'نسبة الحضور',
  'averageScore': 'متوسط الدرجات',
  'startsAtUtc': 'موعد البداية',
  'endsAtUtc': 'موعد النهاية',
  'topic': 'موضوع الحصة',
  'studentName': 'الطالب',
  'groupName': 'المجموعة',
  'subjectName': 'المادة',
  'gradeName': 'الصف الدراسي',
  'durationMinutes': 'المدة بالدقائق',
  'total': 'الإجمالي',
  'comment': 'تعليق',
  'reason': 'السبب',
  'issuedAt': 'تاريخ الإصدار',
  'certificateNumber': 'رقم الشهادة',
  'serialNumber': 'الرقم المسلسل',
  'courseTitle': 'الكورس',
  'studentFullName': 'الطالب',
};

/// Audit reasons are required by the attendance and finance contracts.
Future<String?> requestReason(
  BuildContext context,
  String title, {
  String? initial,
}) async {
  final controller = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'السبب'),
          validator: (v) => (v?.trim().length ?? 0) < 5
              ? 'اكتب سببًا من ٥ أحرف على الأقل'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(c, controller.text.trim());
            }
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  // Let the dialog's reverse transition finish before disposing its editor.
  Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
  return result;
}
