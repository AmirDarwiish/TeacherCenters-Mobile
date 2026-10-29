import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_icons.dart';
import '../core/brand.dart';
import '../core/widgets.dart';
import 'teaching.dart';
import 'community.dart';
import 'excuses.dart';
import 'family_workspace.dart';

String calendarDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String sessionState(dynamic s) =>
    const {
      'Open': 'قادمة',
      'Upcoming': 'قادمة',
      'InProgress': 'جارية',
      'Ongoing': 'جارية',
      'Closed': 'مغلقة',
      'Ended': 'انتهت',
      'Completed': 'مكتملة',
      'Cancelled': 'ملغاة',
      'Postponed': 'مؤجلة',
    }[s] ??
    'حصة دراسية';

class TeacherHomePage extends StatelessWidget {
  const TeacherHomePage({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () {
      final today = calendarDate(cairoDate(DateTime.now()));
      return api.get('/sessions', query: {'from': today, 'to': today});
    },
    builder: (data, refresh) {
      final sessions = rows(data);
      final active = sessions
          .where(
            (s) => !['Closed', 'Cancelled', 'Postponed'].contains(s['status']),
          )
          .toList();
      active.sort(
        (a, b) => '${a['startsAtUtc']}'.compareTo('${b['startsAtUtc']}'),
      );
      final next = active.where((s) {
        final start = DateTime.tryParse('${s['startsAtUtc']}');
        return start != null &&
            start
                .add(
                  Duration(
                    minutes: (s['durationMinutes'] as num? ?? 0).toInt(),
                  ),
                )
                .isAfter(DateTime.now());
      }).firstOrNull;
      return ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'يومك الدراسي',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${api.profile['name'] ?? api.profile['fullName'] ?? 'أستاذنا'} · ${obj(api.session?['tenant'])['name'] ?? api.slug}',
          ),
          const SizedBox(height: 20),
          WorkspaceHeading(
            'حصص اليوم',
            action: 'الجدول الأسبوعي',
            onTap: () => open(context, TeacherSchedulePage(api: api)),
          ),
          if (next != null)
            BrandCard(
              color: context.brand.primaryTint,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      next['canRecordAttendance'] == true
                          ? 'حصة متاحة لتسجيل الحضور'
                          : 'الحصة القادمة',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${next['groupName'] ?? next['topic'] ?? 'حصة دراسية'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(when(next['startsAtUtc'])),
                    if (next['hallName'] != null) Text('${next['hallName']}'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => open(
                        context,
                        AttendancePage(api: api, session: next),
                      ),
                      icon: const Icon(AppIcons.factCheckOutlined),
                      label: const Text('فتح كشف الحضور'),
                    ),
                  ],
                ),
              ),
            ),
          if (sessions.isEmpty)
            const BrandCard(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد حصص مسجلة لك اليوم في هذا السنتر.'),
              ),
            ),
          for (final s in sessions.where((s) => s['id'] != next?['id']))
            BrandCard(
              child: ListTile(
                title: Text('${s['groupName'] ?? s['topic'] ?? 'حصة دراسية'}'),
                subtitle: Text(
                  '${when(s['startsAtUtc'])}\n${sessionState(s['status'])}',
                ),
                trailing: const Icon(AppIcons.chevronLeft),
                onTap: () =>
                    open(context, AttendancePage(api: api, session: s)),
              ),
            ),
          const SizedBox(height: 24),
          Text('مساحة العمل', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          BrandCard(
            child: ListTile(
              leading: const Icon(AppIcons.groupsOutlined),
              title: const Text('مجموعاتي وطلابي'),
              subtitle: const Text('الحضور والدرجات وحصص كل مجموعة'),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: () => open(context, GroupsPage(api: api)),
            ),
          ),
          BrandCard(
            child: ListTile(
              leading: const Icon(AppIcons.assignmentOutlined),
              title: const Text('تسليمات الواجبات'),
              subtitle: const Text('مراجعة الحلول وإضافة الدرجات والتعليقات'),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: () => open(context, AssignmentsPage(api: api)),
            ),
          ),
          BrandCard(
            child: ListTile(
              leading: const Icon(AppIcons.eventBusyOutlined),
              title: const Text('مراجعة أعذار الغياب'),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: () => open(context, ExcusesPage(api: api)),
            ),
          ),
        ],
      );
    },
  );
}

class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key, required this.api});
  final Api api;
  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  late DateTime start = () {
    final now = cairoDate(DateTime.now());
    final date = DateTime(now.year, now.month, now.day);
    return date.subtract(Duration(days: date.weekday % 7));
  }();
  @override
  Widget build(BuildContext context) {
    final end = start.add(const Duration(days: 6));
    return Scaffold(
      appBar: AppBar(title: const Text('جدولي الأسبوعي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'الأسبوع السابق',
                  onPressed: () => setState(
                    () => start = start.subtract(const Duration(days: 7)),
                  ),
                  icon: const Icon(AppIcons.arrowForwardRounded),
                ),
                Expanded(
                  child: Text(
                    '${arDigits(calendarDate(start))} — ${arDigits(calendarDate(end))}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'الأسبوع التالي',
                  onPressed: () => setState(
                    () => start = start.add(const Duration(days: 7)),
                  ),
                  icon: const Icon(AppIcons.arrowBackRounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncPanel(
              key: ValueKey(start),
              load: () => widget.api.get(
                '/teachers/me/schedule',
                query: {'from': calendarDate(start), 'to': calendarDate(end)},
              ),
              builder: (data, refresh) {
                final sessions = rows(data);
                final tenant = obj(widget.api.session?['tenant']);
                final tenantId = '${tenant['id'] ?? tenant['tenantId'] ?? ''}';
                return ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (sessions.isEmpty)
                      const Empty(text: 'لا توجد حصص في هذا الأسبوع.'),
                    for (final s in sessions)
                      BrandCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                when(s['startsAtUtc']),
                                style: TextStyle(color: context.brand.primary),
                              ),
                              Text(
                                '${s['groupName'] ?? 'حصة دراسية'}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${s['tenantName'] ?? ''} · ${s['hallName'] ?? 'القاعة غير محددة'}',
                              ),
                              Text(
                                '${sessionState(s['status'])} · ${arNumber(s['durationMinutes'])} دقيقة',
                              ),
                              Text(
                                'حاضر ${arNumber(s['present'])} · مسجل ${arNumber(s['expected'])}',
                              ),
                              if (tenantId.isNotEmpty &&
                                  tenantId == '${s['tenantId']}')
                                TextButton.icon(
                                  onPressed: () => open(
                                    context,
                                    AttendancePage(api: widget.api, session: s),
                                  ),
                                  icon: const Icon(AppIcons.factCheckOutlined),
                                  label: const Text('كشف الحضور'),
                                )
                              else
                                const Text(
                                  'افتح السنتر صاحب الحصة لإدارة حضورها.',
                                  style: TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String settlementState(dynamic s) =>
    const {
      'Draft': 'غير مصروفة',
      'Generated': 'غير مصروفة',
      'Pending': 'غير مصروفة',
      'Paid': 'تم الصرف',
      'Disputed': 'قيد الاعتراض',
    }[s] ??
    'غير مصروفة';

class TeacherSettlementsPage extends StatelessWidget {
  const TeacherSettlementsPage({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تسوياتي المالية')),
    body: PagedList(
      api: api,
      path: '/teachers/me/settlements',
      item: (s) => BrandCard(
        child: ListTile(
          leading: const Icon(AppIcons.receiptLongOutlined),
          title: Text('تسوية ${arDigits(s['month'])}'),
          subtitle: Text(
            '${money(s['netToTeacher'])} · ${settlementState(s['status'])}',
          ),
          trailing: const Icon(AppIcons.chevronLeft),
          onTap: () =>
              open(context, SettlementDetailPage(api: api, id: '${s['id']}')),
        ),
      ),
    ),
  );
}

class SettlementDetailPage extends StatefulWidget {
  const SettlementDetailPage({super.key, required this.api, required this.id});
  final Api api;
  final String id;
  @override
  State<SettlementDetailPage> createState() => _SettlementDetailPageState();
}

class _SettlementDetailPageState extends State<SettlementDetailPage> {
  int revision = 0;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تفاصيل التسوية')),
    body: AsyncPanel(
      key: ValueKey(revision),
      load: () => widget.api.get('/settlements/${widget.id}'),
      builder: (data, refresh) {
        final s = obj(data), net = s['netToTeacher'] as num?;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'تسوية ${arDigits(s['month'])}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(settlementState(s['status'])),
            const SizedBox(height: 16),
            Metric(
              net != null && net < 0 ? 'مبلغ على المدرس' : 'صافي مستحقاتك',
              net == null ? '—' : money(net.abs()),
              AppIcons.paymentsOutlined,
            ),
            ListTile(
              title: const Text('إجمالي التحصيل'),
              trailing: Text(money(s['grossCollected'])),
            ),
            ListTile(
              title: const Text('نصيب السنتر'),
              trailing: Text(money(s['centerShare'])),
            ),
            if (s['paidAtUtc'] != null)
              ListTile(
                title: const Text('تاريخ الصرف'),
                subtitle: Text(when(s['paidAtUtc'])),
              ),
            if (s['disputeNote'] != null)
              ListTile(
                title: const Text('سبب الاعتراض'),
                subtitle: Text('${s['disputeNote']}'),
              ),
            const Text(
              'المبالغ محسوبة وفق الاتفاقية المسجلة وقت توليد التسوية. أي اعتراض تراجعه إدارة السنتر.',
            ),
            if (widget.api.role == 'Teacher' &&
                !['Paid', 'Disputed'].contains(s['status']))
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final reason = await requestReason(
                          context,
                          'سبب الاعتراض',
                        );
                        if (reason == null || !context.mounted) return;
                        setState(() => busy = true);
                        await action(context, () async {
                          await widget.api.call(
                            'POST',
                            '/settlements/${widget.id}/dispute',
                            data: {'reason': reason},
                          );
                          if (mounted) setState(() => revision++);
                        }, success: 'تم إرسال الاعتراض');
                        if (mounted) setState(() => busy = false);
                      },
                child: Text(busy ? 'جارٍ الإرسال…' : 'تقديم اعتراض'),
              ),
          ],
        );
      },
    ),
  );
}
