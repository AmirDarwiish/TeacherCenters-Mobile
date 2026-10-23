import '../core/brand.dart';
import '../core/brand_logo.dart';
import '../core/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/widgets.dart';
import 'courses.dart';
import 'teaching.dart';
import 'community.dart';
import 'payments.dart';
import 'quiz.dart';
import 'reels.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.api, required this.onTheme});
  final Api api;
  final VoidCallback onTheme;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int index = 0;
  bool overlay = false;
  final Map<int, Widget> visited = {};

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

  Future<void> openOverlay(Widget page) async {
    setState(() => overlay = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } finally {
      if (mounted) setState(() => overlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final hasReels = api.student;
    final immersive = hasReels && index == 2;
    final titles = [
      'الرئيسية',
      'الكورسات',
      hasReels ? 'ريلز' : 'الحصص',
      hasReels ? 'الحصص' : 'الرسائل',
      'المزيد',
    ];
    Widget page(int tab) {
      // This widget must receive visibility updates even inside IndexedStack.
      if (hasReels && tab == 2) {
        return ReelsPage(
          key: const ValueKey('course-reels'),
          api: api,
          active: index == 2 && !overlay,
        );
      }
      return visited.putIfAbsent(
        tab,
        () => switch (tab) {
          0 => HomePage(
            api: api,
            onCourses: () => setState(() => index = 1),
            onSessions: () => setState(() => index = hasReels ? 3 : 2),
          ),
          1 => CoursesPage(api: api),
          2 => SessionsPage(api: api),
          3 when hasReels => SessionsPage(api: api),
          3 => ThreadsPage(api: api),
          _ => AccountPage(api: api, onTheme: widget.onTheme),
        },
      );
    }

    if (!(hasReels && index == 2)) page(index);
    return Scaffold(
      backgroundColor: immersive ? BrandColors.night : null,
      appBar: AppBar(
        flexibleSpace: immersive ? null : const BrandHeader(),
        titleTextStyle: immersive
            ? Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: BrandColors.white)
            : null,
        actionsIconTheme: immersive
            ? const IconThemeData(color: BrandColors.white, size: 20)
            : null,
        backgroundColor: immersive ? BrandColors.night : null,
        foregroundColor: immersive ? BrandColors.white : null,
        title: index == 0 ? const SentrakLogo(size: 32) : Text(titles[index]),
        actions: [
          if (!api.guardian)
            IconButton(
              tooltip: 'الرسائل',
              onPressed: () => openOverlay(ThreadsPage(api: api)),
              icon: const Icon(AppIcons.chatBubbleOutlineRounded),
            ),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => openOverlay(NotificationsPage(api: api)),
            icon: const Icon(AppIcons.notificationsNoneRounded),
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
            5,
            (i) => TickerMode(
              enabled: i == index,
              child:
                  hasReels && i == 2 && (index == 2 || visited.containsKey(2))
                  ? page(2)
                  : visited[i] ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SentrakNavigationBar(
        selectedIndex: index,
        hasReels: hasReels,
        immersive: immersive,
        onSelected: (i) => setState(() {
          index = i;
          // Mark the feed visited while keeping its active property dynamic.
          if (hasReels && i == 2) {
            visited.putIfAbsent(2, () => const SizedBox.shrink());
          }
        }),
      ),
    );
  }
}

class SentrakNavigationBar extends StatelessWidget {
  const SentrakNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.hasReels = true,
    this.immersive = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool hasReels, immersive;
  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final labels = [
      'الرئيسية',
      'الكورسات',
      hasReels ? 'ريلز' : 'الحصص',
      hasReels ? 'الحصص' : 'الرسائل',
      'المزيد',
    ];
    final icons = [
      AppIcons.homeOutlined,
      AppIcons.autoStoriesOutlined,
      hasReels ? AppIcons.playCircle : AppIcons.calendarMonthOutlined,
      hasReels
          ? AppIcons.calendarMonthOutlined
          : AppIcons.chatBubbleOutlineRounded,
      AppIcons.personOutlineRounded,
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: BrandColors.night.withValues(alpha: .04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: BrandColors.logoBlue.withValues(alpha: .16),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: BrandGlass(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: b.line),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i == selectedIndex;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: active,
                      label: labels[i],
                      excludeSemantics: true,
                      child: Tooltip(
                        message: labels[i],
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelected(i),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 64,
                              minWidth: 44,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: BrandMotion.duration(context),
                                  curve: BrandMotion.curve,
                                  transform: Matrix4.translationValues(
                                    0,
                                    active ? -6 : 0,
                                    0,
                                  ),
                                  width: 40,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: active
                                        ? const LinearGradient(
                                            begin: Alignment.topRight,
                                            end: Alignment.bottomLeft,
                                            colors: [
                                              BrandColors.navStart,
                                              BrandColors.navEnd,
                                            ],
                                          )
                                        : null,
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: BrandColors.logoBlue
                                                  .withValues(alpha: .16),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    icons[i],
                                    size: 20,
                                    color: active ? BrandColors.white : b.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      labels[i],
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 12,
                                        color: active ? b.primary : b.muted,
                                        fontWeight: active
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
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
            appBar: AppBar(
              flexibleSpace: const BrandHeader(),
              title: const Text('الكورسات'),
            ),
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
                      'أهلاً بعودتك',
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
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [BrandColors.logoBlue, BrandColors.logoCyan],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      AppIcons.autoAwesomeOutlined,
                      size: 18,
                      color: BrandColors.primaryTintFixed,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'كل خطوة بتفرق',
                      style: TextStyle(color: BrandColors.primaryTintFixed),
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
                    fontFamily: 'Alexandria',
                    fontSize: 27,
                    color: BrandColors.white,
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
                  style: const TextStyle(
                    color: BrandColors.whiteMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandColors.primaryTintFixed,
                    foregroundColor: BrandColors.primaryHoverFixed,
                  ),
                  onPressed: () => courses(context),
                  icon: const Icon(AppIcons.arrowBackRounded, size: 18),
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
                        appBar: AppBar(
                          flexibleSpace: const BrandHeader(),
                          title: const Text('الحصص'),
                        ),
                        body: SessionsPage(api: api),
                      ),
                    ),
                child: const Text('الجدول'),
              ),
            ],
          ),
          if (next.isNotEmpty)
            BrandCard(
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
                        AppIcons.calendarMonthOutlined,
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
            BrandCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(AppIcons.eventAvailableOutlined, size: 28),
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
                      ? AppIcons.howToRegOutlined
                      : AppIcons.groupsOutlined,
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
                      ? AppIcons.insightsOutlined
                      : AppIcons.calendarTodayOutlined,
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
                  icon: AppIcons.autoStoriesOutlined,
                  onTap: () => courses(context),
                ),
                _HomeAction(
                  title: 'الحصص',
                  subtitle: api.student
                      ? 'مواعيدك وحضورك'
                      : 'الجدول وتسجيل الحضور',
                  icon: AppIcons.calendarMonthOutlined,
                  onTap:
                      onSessions ??
                      () => open(
                        context,
                        Scaffold(
                          appBar: AppBar(
                            flexibleSpace: const BrandHeader(),
                            title: const Text('الحصص'),
                          ),
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
                    icon: AppIcons.assignmentOutlined,
                    onTap: () => open(context, AssignmentsPage(api: api)),
                  ),
                if (api.student && !api.guardian)
                  _HomeAction(
                    title: 'الاختبارات',
                    subtitle: 'اختبر فهمك وتابع نتيجتك',
                    icon: AppIcons.quizOutlined,
                    onTap: () => open(
                      context,
                      PageViewList(
                        api: api,
                        path: '/portal/exams',
                        title: 'الاختبارات',
                        item: (e) => BrandCard(
                          child: ListTile(
                            title: Text(label(e)),
                            subtitle: Text(
                              'الإغلاق: ${when(e['closesAtUtc'])}',
                            ),
                            trailing: const Icon(AppIcons.chevronLeft),
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
                    icon: AppIcons.groupsOutlined,
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
            BrandCard(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const Icon(AppIcons.accountBalanceWalletOutlined),
                title: const Text('المستحقات الحالية'),
                subtitle: Text(money(obj(d['balance'])['totalDue'] ?? 0)),
                trailing: const Icon(AppIcons.chevronLeft),
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
  Widget build(BuildContext context) => BrandCard(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
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
    padding: const EdgeInsets.all(16),
    children: [
      const CircleAvatar(
        radius: 40,
        child: Icon(AppIcons.personOutline, size: 44),
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
        leading: const Icon(AppIcons.apartment),
        title: const Text('السنتر'),
        subtitle: Text('${obj(api.session?['tenant'])['name'] ?? api.slug}'),
      ),
      ListTile(
        leading: const Icon(AppIcons.darkModeOutlined),
        title: const Text('تغيير المظهر'),
        onTap: onTheme,
      ),
      if (!api.guardian)
        ListTile(
          leading: const Icon(AppIcons.chatBubbleOutlineRounded),
          title: const Text('الرسائل'),
          onTap: () => open(context, ThreadsPage(api: api)),
        ),
      if (api.student)
        ListTile(
          leading: const Icon(AppIcons.paymentsOutlined),
          title: const Text('المدفوعات والمستحقات'),
          onTap: () => open(context, PaymentsPage(api: api)),
        ),
      if (api.student && !api.guardian)
        ListTile(
          leading: const Icon(AppIcons.qrCode),
          title: const Text('بطاقتي'),
          onTap: () => open(context, StudentCard(api: api)),
        ),
      if (api.student)
        ListTile(
          leading: const Icon(AppIcons.swapHorizRounded),
          title: const Text('تغيير السنتر'),
          subtitle: const Text('أكد رقمك واختار من حساباتك المرتبطة'),
          onTap: () => action(context, api.logout),
        ),
      ListTile(
        leading: const Icon(AppIcons.logout),
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
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('بطاقة الطالب'),
    ),
    body: AsyncPanel(
      load: () => api.get('/portal/card'),
      builder: (data, refresh) {
        final d = obj(data);
        return ListView(
          padding: const EdgeInsets.all(16),
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
                  color: BrandColors.white,
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
          BrandCard(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
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
                      child: Icon(AppIcons.playArrowRounded, size: 32),
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
                            'أنجزت ${arNumber(course['progressPercent'] ?? 0)}٪ • استكمل من آخر درس',
                          ),
                        ],
                      ),
                    ),
                    const Icon(AppIcons.chevronLeftRounded),
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
