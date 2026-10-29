import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_icons.dart';
import '../core/brand.dart';
import '../core/widgets.dart';
import 'excuses.dart';
import 'session_detail.dart';

class FamilyHomePage extends StatelessWidget {
  const FamilyHomePage({
    super.key,
    required this.api,
    required this.studentId,
    required this.onCourses,
    required this.onSessions,
    required this.onPayments,
  });
  final Api api;
  final String studentId;
  final VoidCallback onCourses, onSessions, onPayments;
  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () => api.get('/portal/students/$studentId/overview'),
    builder: (data, refresh) {
      final d = obj(data),
          student = obj(d['student']),
          next = obj(d['nextSession']);
      final due = obj(d['balance'])['totalDue'];
      return ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'متابعة ${label(student)}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${obj(api.session?['tenant'])['name'] ?? api.slug} · حضور وتعلم ومدفوعات',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          WorkspaceHeading(
            'الحصة القادمة',
            action: 'الجدول',
            onTap: onSessions,
          ),
          if (next.isEmpty)
            const BrandCard(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد حصة قادمة مسجلة حالياً.'),
              ),
            )
          else
            BrandCard(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(AppIcons.calendarMonthOutlined),
                title: Text(
                  '${next['topic'] ?? next['groupName'] ?? 'الحصة القادمة'}',
                ),
                subtitle: Text(when(next['startsAtUtc'])),
                trailing: const Icon(AppIcons.chevronLeft),
                onTap: () => open(
                  context,
                  StudentSessionPage(
                    api: api,
                    studentId: studentId,
                    session: next,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'المتابعة الدراسية',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, size) {
              final metrics = [
                Metric(
                  'الحضور هذا الشهر',
                  d['attendancePercent'] == null
                      ? '—'
                      : '${arNumber(d['attendancePercent'])}٪',
                  AppIcons.howToRegOutlined,
                ),
                Metric(
                  'متوسط الدرجات المنشورة',
                  d['averageScore'] == null ? '—' : arNumber(d['averageScore']),
                  AppIcons.insightsOutlined,
                ),
              ];
              if (MediaQuery.textScalerOf(context).scale(16) > 22) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    metrics[0],
                    const SizedBox(height: 10),
                    metrics[1],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: metrics[0]),
                    const SizedBox(width: 12),
                    Expanded(child: metrics[1]),
                  ],
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'الدرجات المعروضة منشورة من السنتر؛ لا تشمل نتائج لم تُنشر بعد.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          BrandCard(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(AppIcons.paymentsOutlined),
              title: const Text('مستحقات الابن'),
              subtitle: Text(
                due == null ? 'لا تتوفر بيانات الرصيد الآن' : money(due),
              ),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: onPayments,
            ),
          ),
          const SizedBox(height: 12),
          BrandCard(
            child: ListTile(
              leading: const Icon(AppIcons.autoStoriesOutlined),
              title: const Text('متابعة الكورسات'),
              subtitle: const Text('التقدم والدروس والنتائج المتاحة'),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: onCourses,
            ),
          ),
          BrandCard(
            child: ListTile(
              leading: const Icon(AppIcons.eventBusyOutlined),
              title: const Text('أعذار الغياب'),
              subtitle: const Text('تقديم عذر ومتابعة قرار السنتر'),
              trailing: const Icon(AppIcons.chevronLeft),
              onTap: () =>
                  open(context, ExcusesPage(api: api, studentId: studentId)),
            ),
          ),
        ],
      );
    },
  );
}

class WorkspaceHeading extends StatelessWidget {
  const WorkspaceHeading(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}
