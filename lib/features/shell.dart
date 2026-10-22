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
  final Map<int, Widget> visited = {};
  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    Widget page(int tab) => visited.putIfAbsent(
      tab,
      () => switch (tab) {
        0 => HomePage(
          api: api,
          onCourses: () => setState(() => index = 1),
          onSessions: () => setState(() => index = 2),
        ),
        1 => CoursesPage(api: api),
        2 => SessionsPage(api: api),
        3 when !api.guardian => ThreadsPage(api: api),
        _ => AccountPage(api: api, onTheme: widget.onTheme),
      },
    );
    page(index);
    final count = api.guardian ? 4 : 5;
    final titles = [
      'الرئيسية',
      'الكورسات',
      'الحصص',
      if (!api.guardian) 'الرسائل',
      'حسابي',
    ];
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
      body: PopScope(
        canPop: index == 0,
        onPopInvokedWithResult: (popped, result) {
          if (!popped) setState(() => index = 0);
        },
        child: IndexedStack(
          index: index,
          children: List.generate(
            count,
            (i) => TickerMode(
              enabled: i == index,
              child: visited[i] ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(
            selectedIcon: Icon(Icons.grid_view_rounded),
            icon: Icon(Icons.grid_view_outlined),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.auto_stories_rounded),
            icon: Icon(Icons.auto_stories_outlined),
            label: 'الكورسات',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.calendar_month_rounded),
            icon: Icon(Icons.calendar_month_outlined),
            label: 'الحصص',
          ),
          if (!api.guardian)
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              label: 'الرسائل',
            ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded),
            icon: Icon(Icons.person_outline),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.api,
    this.onCourses,
    this.onSessions,
  });
  final Api api;
  final VoidCallback? onCourses, onSessions;
  void courses(BuildContext context) => onCourses != null
      ? onCourses!()
      : open(
          context,
          Scaffold(
            appBar: AppBar(title: const Text('الكورسات')),
            body: CoursesPage(api: api),
          ),
        );
  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () async {
      if (!api.student) return api.get('/dashboard/summary');
      final me = obj(await api.get('/portal/me'));
      final students = rows(me['students']);
      if (students.isEmpty) {
        throw ApiFailure('الحساب غير مرتبط بطالب نشط. تواصل مع السنتر.');
      }
      final student =
          students
              .where((s) => '${s['id']}' == api.portalStudentId)
              .firstOrNull ??
          students.first;
      return api.get('/portal/students/${student['id']}/overview');
    },
    builder: (data, refresh) {
      final d = obj(data), next = obj(d['nextSession']);
      final colors = Theme.of(context).colorScheme;
      final name =
          '${api.profile['name'] ?? api.profile['fullName'] ?? (api.student ? 'صديقنا' : 'أستاذنا')}';
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بعودتك 👋',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  name.trim().isEmpty ? 'ت' : name.trim()[0],
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xff1648c4), Color(0xff1d5bf0)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: Color(0xffdce8ff),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'كل خطوة بتفرق',
                      style: TextStyle(color: Color(0xffdce8ff)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  api.guardian
                      ? 'معاه في كل خطوة'
                      : api.student
                      ? 'فهم أعمق.\nوثقة في اللي جاي.'
                      : 'وقت أكتر للتدريس.\nوتفاصيل تحت السيطرة.',
                  style: const TextStyle(
                    fontSize: 27,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  api.guardian
                      ? 'تابع التعلم والحضور والنتائج من مكان واحد.'
                      : api.student
                      ? 'شرحك وتدريبك ومواعيدك، مترتبين على راحتك.'
                      : 'تابع طلابك، جهّز محتواك، ونظّم يومك.',
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffdce8ff),
                    foregroundColor: const Color(0xff1648c4),
                  ),
                  onPressed: () => courses(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    api.guardian
                        ? 'متابعة الكورسات'
                        : api.student
                        ? 'مساحة التعلم'
                        : 'إدارة الكورسات',
                  ),
                ),
              ],
            ),
          ),
          if (api.student) ContinueLearning(api: api),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  api.student ? 'موعدك الجاي' : 'الجدول والحصص',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed:
                    onSessions ??
                    () => open(
                      context,
                      Scaffold(
                        appBar: AppBar(title: const Text('الحصص')),
                        body: SessionsPage(api: api),
                      ),
                    ),
                child: const Text('الجدول'),
              ),
            ],
          ),
          if (next.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 58,
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        color: colors.onSecondaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${next['topic'] ?? next['groupName'] ?? 'الحصة القادمة'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(when(next['startsAtUtc'])),
                          if (next['groupName'] != null)
                            Text(
                              '${next['groupName']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_outlined, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        api.student
                            ? 'مفيش حصص قادمة ظاهرة حالياً. تقدر تراجع الجدول.'
                            : 'راجع الجدول لمواعيد الحصص وتسجيل الحضور.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            api.guardian ? 'متابعة المستوى' : 'نظرة على تقدمك',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Metric(
                  api.student ? 'نسبة الحضور' : 'الطلاب النشطون',
                  api.student
                      ? '${d['attendancePercent'] ?? '—'}٪'
                      : '${d['activeStudents'] ?? 0}',
                  api.student
                      ? Icons.how_to_reg_outlined
                      : Icons.groups_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Metric(
                  api.student ? 'متوسط الدرجات' : 'حصص اليوم',
                  api.student
                      ? '${d['averageScore'] ?? '—'}'
                      : '${obj(d['sessionsToday'])['total'] ?? 0}',
                  api.student
                      ? Icons.insights_outlined
                      : Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'كل اللي تحتاجه',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = <Widget>[
                _HomeAction(
                  title: api.student ? 'كورساتي' : 'محتواي',
                  subtitle: 'تعلم بخطة واضحة',
                  icon: Icons.auto_stories_outlined,
                  onTap: () => courses(context),
                ),
                _HomeAction(
                  title: 'الحصص',
                  subtitle: api.student
                      ? 'مواعيدك وحضورك'
                      : 'الجدول وتسجيل الحضور',
                  icon: Icons.calendar_month_outlined,
                  onTap:
                      onSessions ??
                      () => open(
                        context,
                        Scaffold(
                          appBar: AppBar(title: const Text('الحصص')),
                          body: SessionsPage(api: api),
                        ),
                      ),
                ),
                if (!api.guardian)
                  _HomeAction(
                    title: 'الواجبات',
                    subtitle: api.student
                        ? 'سلّم وراجع ملاحظاتك'
                        : 'التسليمات والتصحيح',
                    icon: Icons.assignment_outlined,
                    onTap: () => open(context, AssignmentsPage(api: api)),
                  ),
                if (api.student && !api.guardian)
                  _HomeAction(
                    title: 'الاختبارات',
                    subtitle: 'اختبر فهمك وتابع نتيجتك',
                    icon: Icons.quiz_outlined,
                    onTap: () => open(
                      context,
                      PageViewList(
                        api: api,
                        path: '/portal/exams',
                        title: 'الاختبارات',
                        item: (e) => Card(
                          child: ListTile(
                            title: Text(label(e)),
                            subtitle: Text(
                              'الإغلاق: ${when(e['closesAtUtc'])}',
                            ),
                            trailing: const Icon(Icons.chevron_left),
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
                if (!api.student)
                  _HomeAction(
                    title: 'مجموعاتي',
                    subtitle: 'طلابك ومتابعة مستواهم',
                    icon: Icons.groups_outlined,
                    onTap: () => open(context, GroupsPage(api: api)),
                  ),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 0,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (api.student)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('المستحقات الحالية'),
                subtitle: Text('${obj(d['balance'])['totalDue'] ?? 0} ج.م'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => open(context, PaymentsPage(api: api)),
              ),
            ),
        ],
      );
    },
  );
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 25,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    ),
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
      Center(
        child: Text(
          api.guardian
              ? 'ولي أمر'
              : api.student
              ? 'طالب'
              : 'مدرس',
        ),
      ),
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
      if (api.student && !api.guardian)
        ListTile(
          leading: const Icon(Icons.qr_code),
          title: const Text('بطاقتي'),
          onTap: () => open(context, StudentCard(api: api)),
        ),
      if (api.student)
        ListTile(
          leading: const Icon(Icons.swap_horiz_rounded),
          title: const Text('تغيير السنتر'),
          subtitle: const Text('أكد رقمك واختار من حساباتك المرتبطة'),
          onTap: () => action(context, api.logout),
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

class ContinueLearning extends StatefulWidget {
  const ContinueLearning({super.key, required this.api});
  final Api api;
  @override
  State<ContinueLearning> createState() => _ContinueLearningState();
}

class _ContinueLearningState extends State<ContinueLearning> {
  late final Future<dynamic> courses = widget.api.get('/portal/courses');
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: courses,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final active = rows(snapshot.data)
          .where(
            (c) =>
                (c['progressPercent'] as num? ?? 0) < 100 &&
                c['resumeLessonId'] != null,
          )
          .toList();
      active.sort(
        (a, b) => '${b['lastActivityAt'] ?? ''}'.compareTo(
          '${a['lastActivityAt'] ?? ''}',
        ),
      );
      if (active.isEmpty) return const SizedBox.shrink();
      final course = active.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            widget.api.guardian ? 'رحلة التعلم' : 'كمّل رحلتك',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => open(
                context,
                CoursePage(api: widget.api, id: '${course['id']}'),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      child: Icon(Icons.play_arrow_rounded, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label(course),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أنجزت ${course['progressPercent'] ?? 0}٪ • استكمل من آخر درس',
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
