import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';
import 'teaching.dart';
import 'community.dart';
import 'payments.dart';
import 'quiz.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.api, required this.onTheme});
  final Api api;
  final VoidCallback onTheme;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.live.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.api.live.start();
    } else {
      widget.api.live.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.api.live.stop(clear: true);
    super.dispose();
  }

  int index = 0;
  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final pages = [
      HomePage(api: api),
      CoursesPage(api: api),
      SessionsPage(api: api),
      ThreadsPage(api: api),
      AccountPage(api: api, onTheme: widget.onTheme),
    ];
    final titles = ['الرئيسية', 'الكورسات', 'الحصص', 'الرسائل', 'حسابي'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => open(context, NotificationsPage(api: api)),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            label: 'الكورسات',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'الحصص',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'الرسائل',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () async {
      if (!api.student) return api.get('/dashboard/summary');
      final me = obj(await api.get('/portal/me'));
      final students = rows(me['students']);
      if (students.isEmpty) {
        throw ApiFailure('الحساب غير مرتبط بطالب نشط. تواصل مع السنتر.');
      }
      return api.get('/portal/students/${students.first['id']}/overview');
    },
    builder: (data, refresh) {
      final d = obj(data);
      final next = obj(d['nextSession']);
      return ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xff635bda), Color(0xff363083)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً، ${api.profile['name'] ?? api.profile['fullName'] ?? (api.student ? 'يا بطل' : 'أستاذنا')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  api.student
                      ? 'خطوة جديدة نحو نجاحك'
                      : 'كل تفاصيل يومك الدراسي',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TeacherCenters',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('نظرة سريعة', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (api.student)
            Row(
              children: [
                Expanded(
                  child: Metric(
                    'نسبة الحضور',
                    '${d['attendancePercent'] ?? '—'}%',
                    Icons.how_to_reg,
                  ),
                ),
                Expanded(
                  child: Metric(
                    'متوسط الدرجات',
                    '${d['averageScore'] ?? '—'}',
                    Icons.insights,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Metric(
                    'الطلاب النشطون',
                    '${d['activeStudents'] ?? 0}',
                    Icons.groups_outlined,
                  ),
                ),
                Expanded(
                  child: Metric(
                    'حصص اليوم',
                    '${obj(d['sessionsToday'])['total'] ?? 0}',
                    Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
          if (next.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('${next['topic'] ?? 'حصتك القادمة'}'),
                subtitle: Text(when(next['startsAtUtc'])),
              ),
            ),
          if (api.student)
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('المستحقات'),
                subtitle: Text('${obj(d['balance'])['totalDue'] ?? 0} جنيه'),
                onTap: () => open(context, PaymentsPage(api: api)),
              ),
            ),
          Text('وصول سريع', style: Theme.of(context).textTheme.titleLarge),
          if (api.student)
            Card(
              child: ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: const Text('امتحانات المجموعات'),
                onTap: () => open(
                  context,
                  PageViewList(
                    api: api,
                    path: '/portal/exams',
                    title: 'الامتحانات',
                    item: (e) => Card(
                      child: ListTile(
                        title: Text(label(e)),
                        subtitle: Text('الإغلاق: ${when(e['closesAtUtc'])}'),
                        onTap: () => open(
                          context,
                          QuizPage(
                            api: api,
                            quizId: '${e['id']}',
                            legacy: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!api.student)
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('مجموعاتي والطلاب'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => open(context, GroupsPage(api: api)),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('الواجبات والتسليمات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => open(context, AssignmentsPage(api: api)),
            ),
          ),
          if (api.student)
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('بطاقة الطالب'),
                onTap: () => open(context, StudentCard(api: api)),
              ),
            ),
          if (api.student)
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: const Text('استكشف الكورسات'),
                onTap: () => open(
                  context,
                  Scaffold(
                    appBar: AppBar(title: const Text('استكشف')),
                    body: CoursesPage(api: api, catalog: true),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.api, required this.onTheme});
  final Api api;
  final VoidCallback onTheme;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const CircleAvatar(
        radius: 40,
        child: Icon(Icons.person_outline, size: 44),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          '${api.profile['name'] ?? api.profile['fullName'] ?? 'حسابي'}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      Center(child: Text(api.student ? 'طالب' : 'مدرس')),
      const SizedBox(height: 24),
      ListTile(
        leading: const Icon(Icons.apartment),
        title: const Text('السنتر'),
        subtitle: Text('${obj(api.session?['tenant'])['name'] ?? api.slug}'),
      ),
      ListTile(
        leading: const Icon(Icons.dark_mode_outlined),
        title: const Text('تغيير المظهر'),
        onTap: onTheme,
      ),
      if (api.student)
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('المدفوعات والمستحقات'),
          onTap: () => open(context, PaymentsPage(api: api)),
        ),
      if (api.student)
        ListTile(
          leading: const Icon(Icons.qr_code),
          title: const Text('بطاقتي'),
          onTap: () => open(context, StudentCard(api: api)),
        ),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('تسجيل الخروج'),
        onTap: () async {
          if (await confirm(context, 'تسجيل الخروج من الحساب؟') &&
              context.mounted) {
            await action(context, api.logout);
          }
        },
      ),
    ],
  );
}

class StudentCard extends StatelessWidget {
  const StudentCard({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بطاقة الطالب')),
    body: AsyncPanel(
      load: () => api.get('/portal/card'),
      builder: (data, refresh) {
        final d = obj(data);
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Text(
              '${d['fullName']}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${d['code']} · ${d['grade'] ?? ''}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (d['qrToken'] != null)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: QrImageView(data: '${d['qrToken']}', size: 240),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'اعرض البطاقة لتسجيل الحضور في السنتر',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
  );
}
