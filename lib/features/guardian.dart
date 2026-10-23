import '../core/app_icons.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/widgets.dart';
import 'shell.dart';

/// Guardian identity is verified once; switching children only changes read scope.
class GuardianPortal extends StatefulWidget {
  const GuardianPortal({super.key, required this.api, required this.onTheme});
  final Api api;
  final VoidCallback onTheme;
  @override
  State<GuardianPortal> createState() => _GuardianPortalState();
}

class _GuardianPortalState extends State<GuardianPortal> {
  @override
  Widget build(BuildContext context) => Material(
    child: SafeArea(
      bottom: false,
      child: AsyncPanel(
        load: () => widget.api.get('/portal/me'),
        builder: (data, refresh) {
          final students = rows(obj(data)['students']);
          if (students.isEmpty) {
            return const Center(
              child: Empty(
                text: 'لا يوجد طالب مرتبط بهذا الحساب حالياً. تواصل مع السنتر.',
              ),
            );
          }
          final selected =
              students
                  .where((s) => '${s['id']}' == widget.api.portalStudentId)
                  .firstOrNull ??
              students.first;
          widget.api.portalStudentId = '${selected['id']}';
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: '${selected['id']}',
                  decoration: const InputDecoration(
                    labelText: 'متابعة الطالب',
                    prefixIcon: Icon(AppIcons.familyRestroomOutlined),
                  ),
                  items: students
                      .map(
                        (s) => DropdownMenuItem(
                          value: '${s['id']}',
                          child: Text(label(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (id) =>
                      setState(() => widget.api.portalStudentId = id),
                ),
              ),
              Expanded(
                child: Shell(
                  key: ValueKey(widget.api.portalStudentId),
                  api: widget.api,
                  onTheme: widget.onTheme,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
