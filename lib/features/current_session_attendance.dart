import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_icons.dart';
import '../core/session_schedule.dart';
import '../core/widgets.dart';
import 'session_check_in.dart';

class CurrentSessionAttendance extends StatefulWidget {
  const CurrentSessionAttendance({
    super.key,
    required this.api,
    required this.studentId,
    required this.onChanged,
  });
  final Api api;
  final String studentId;
  final VoidCallback onChanged;

  @override
  State<CurrentSessionAttendance> createState() =>
      _CurrentSessionAttendanceState();
}

class _CurrentSessionAttendanceState extends State<CurrentSessionAttendance> {
  bool busy = false;
  Object? error;

  Future<void> attend() async {
    if (busy || widget.api.role != 'Student') return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final day = cairoDate(DateTime.now());
      final sessions = await loadSessionRange(
        widget.api,
        studentId: widget.studentId,
        from: cairoMidnightUtc(DateTime(day.year, day.month, day.day - 1)),
        to: cairoMidnightUtc(DateTime(day.year, day.month, day.day + 2)),
      );
      final now = scheduleNow(sessions);
      final current = sessions.where((s) => sessionRunning(s, now)).toList();
      final available = current.isNotEmpty
          ? current
          : sessions.where((s) => sessionAttendanceOpen(s, now)).toList();
      if (!mounted) return;
      if (available.isEmpty) {
        throw ApiFailure(
          'مفيش حصة مفتوح تسجيل حضورها دلوقتي. حدّث جدول الحصص وراجع ميعاد الحصة.',
        );
      }
      Json? selected = available.singleOrNull;
      if (available.length > 1) {
        selected = await showModalBottomSheet<Json>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('اختار الحصة اللي هتسجّل حضورها')),
                for (final s in available)
                  ListTile(
                    title: Text(
                      '${s['topic'] ?? s['groupName'] ?? 'حصة دراسية'}',
                    ),
                    subtitle: Text(
                      '${s['groupName'] ?? ''} • ${when(s['startsAtUtc'])}',
                    ),
                    onTap: () => Navigator.pop(context, s),
                  ),
              ],
            ),
          ),
        );
      }
      if (!mounted || selected == null) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SessionCheckInPage(
            api: widget.api,
            studentId: widget.studentId,
            sessionId: '${selected!['id']}',
          ),
        ),
      );
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
        onPressed: busy ? null : attend,
        icon: const Icon(AppIcons.pinDropOutlined),
        label: Text(
          busy ? 'بندور على حصتك الحالية…' : 'سجّل حضوري للحصة الحالية',
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '$error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
