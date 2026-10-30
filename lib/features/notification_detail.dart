import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/brand.dart';
import '../core/widgets.dart';
import 'community.dart' show AssignmentPage;
import 'course_experience.dart' show CoursePage;
import 'session_detail.dart';
import 'scoped_chat.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({
    super.key,
    required this.api,
    required this.id,
  });
  final Api api;
  final String id;
  Future<void> follow(BuildContext context, Json n) async {
    final link = '${n['link'] ?? ''}';
    final parts = link.split('/');
    if (parts.length != 3) return;
    final resource = parts[2];
    final child = '${n['studentId'] ?? ''}';
    if (api.guardian && child.isNotEmpty) {
      final me = obj(await api.get('/portal/me'));
      if (!rows(me['students']).any((s) => '${s['id']}' == child)) {
        throw ApiFailure('الطالب غير مرتبط بحسابك حاليًا.');
      }
      await api.selectPortalStudent(child);
    }
    if (!context.mounted) return;
    switch (parts[1]) {
      case 'chat':
        final room = obj(await api.get('/chat/conversations/$resource'));
        if (context.mounted) {
          open(context, ChatConversationPage(api: api, conversation: room));
        }
      case 'courses':
        open(context, CoursePage(api: api, id: resource));
      case 'sessions':
        final student = api.guardian ? child : api.actorId;
        if (student.isEmpty) {
          throw ApiFailure('اختار الطالب من الصفحة الرئيسية أولًا.');
        }
        final session = obj(
          await api.get('/portal/students/$student/sessions/$resource'),
        );
        if (context.mounted) {
          open(
            context,
            StudentSessionPage(api: api, studentId: student, session: session),
          );
        }
      case 'assignments':
        final assignment = obj(await api.get('/notifications/$id/assignment'));
        if (!context.mounted) return;
        if (api.guardian) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label(assignment)),
              content: SingleChildScrollView(
                child: Text(
                  '${assignment['description'] ?? ''}\nالتسليم: ${when(assignment['dueAtUtc'])}',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('تم'),
                ),
              ],
            ),
          );
        } else {
          open(context, AssignmentPage(api: api, assignment: assignment));
        }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      flexibleSpace: const BrandHeader(),
      title: const Text('تفاصيل الإشعار'),
    ),
    body: AsyncPanel(
      load: () => api.get('/notifications/$id'),
      builder: (data, refresh) {
        final n = obj(data);
        final image = '${n['imageUrl'] ?? ''}';
        final link = '${n['link'] ?? ''}';
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${n['title'] ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(when(n['createdAt'])),
            const SizedBox(height: 20),
            if (image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              '${n['body'] ?? ''}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (RegExp(
              r'^/(chat|courses|sessions|assignments)/[0-9a-fA-F-]+$',
            ).hasMatch(link))
              FilledButton(
                onPressed: () => action(context, () => follow(context, n)),
                child: const Text('فتح التفاصيل المرتبطة'),
              ),
          ],
        );
      },
    ),
  );
}
