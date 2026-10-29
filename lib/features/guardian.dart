import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_icons.dart';
import '../core/brand.dart';
import '../core/widgets.dart';
import 'shell.dart';

/// Each tab is recreated on a scope change; the selected tab itself is retained.
class GuardianPortal extends StatefulWidget {
  const GuardianPortal({super.key, required this.api, required this.onTheme});
  final Api api;
  final VoidCallback onTheme;
  @override
  State<GuardianPortal> createState() => _GuardianPortalState();
}

class _GuardianPortalState extends State<GuardianPortal> {
  Future<void> choose(List<Json> students) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => ChildPicker(
        students: students,
        selectedId: widget.api.portalStudentId,
      ),
    );
    if (id == null || id == widget.api.portalStudentId || !mounted) return;
    if (!students.any((s) => '${s['id']}' == id)) return;
    await action(context, () async {
      await widget.api.selectPortalStudent(id);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () => widget.api.get('/portal/me'),
    builder: (data, refresh) {
      final students = rows(obj(data)['students']);
      if (students.isEmpty) {
        widget.api.portalStudentId = null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('أبنائي'),
            actions: [
              IconButton(
                tooltip: 'تسجيل الخروج',
                icon: const Icon(AppIcons.logout),
                onPressed: () => action(context, widget.api.logout),
              ),
            ],
          ),
          body: ListView(
            children: [
              Empty(
                text:
                    'لا يوجد طالب مرتبط بهذا الحساب حالياً. تواصل مع إدارة السنتر لربط أبنائك.',
                onAction: refresh,
                actionLabel: 'تحديث الأبناء',
              ),
            ],
          ),
        );
      }
      final selected =
          students
              .where((s) => '${s['id']}' == widget.api.portalStudentId)
              .firstOrNull ??
          students.first;
      widget.api.portalStudentId = '${selected['id']}';
      return Shell(
        api: widget.api,
        studentId: '${selected['id']}',
        onTheme: widget.onTheme,
        studentHeader: ChildIdentityHeader(
          student: selected,
          height:
              88 +
              (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 32) *
                  3,
          onChoose: students.length > 1 ? () => choose(students) : null,
        ),
      );
    },
  );
}

class ChildIdentityHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const ChildIdentityHeader({
    super.key,
    required this.student,
    this.onChoose,
    this.height = 88,
  });
  final Json student;
  final double height;
  final VoidCallback? onChoose;
  @override
  Size get preferredSize => Size.fromHeight(height);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
    child: Material(
      color: context.brand.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.brand.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onChoose,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ChildAvatar(name: label(student)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label(student),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${student['grade'] ?? 'متابعة الطالب'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onChoose != null) ...[
                const SizedBox(width: 8),
                const Text('تغيير الابن', style: TextStyle(fontSize: 12)),
                const Icon(AppIcons.swapHorizRounded, size: 18),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: context.brand.primaryTint,
    foregroundColor: context.brand.primary,
    child: Text(name.trim().isEmpty ? 'ط' : name.trim().characters.first),
  );
}

class ChildPicker extends StatefulWidget {
  const ChildPicker({super.key, required this.students, this.selectedId});
  final List<Json> students;
  final String? selectedId;
  @override
  State<ChildPicker> createState() => _ChildPickerState();
}

class _ChildPickerState extends State<ChildPicker> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final visible = widget.students
        .where((s) => label(s).contains(search))
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'أبنائي',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            const Text('اختر الابن الذي تريد متابعة حضوره وتعلمه ومستحقاته.'),
            const SizedBox(height: 12),
            if (widget.students.length > 5)
              TextField(
                onChanged: (v) => setState(() => search = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم الابن',
                  prefixIcon: Icon(AppIcons.searchRounded),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (visible.isEmpty)
                    const Empty(text: 'لا يوجد ابن بهذا الاسم'),
                  for (final s in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: '${s['id']}' == widget.selectedId
                            ? context.brand.primaryTint
                            : context.brand.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          selected: '${s['id']}' == widget.selectedId,
                          leading: ChildAvatar(name: label(s)),
                          title: Text(label(s)),
                          subtitle: Text('${s['grade'] ?? ''}'),
                          trailing: '${s['id']}' == widget.selectedId
                              ? const Icon(AppIcons.checkCircle)
                              : null,
                          onTap: () => Navigator.pop(context, '${s['id']}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
