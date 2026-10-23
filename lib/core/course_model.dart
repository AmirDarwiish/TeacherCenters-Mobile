import 'api.dart';
import 'format.dart';

/// Presentation rules shared by library, course detail and tests.
class CourseInfo {
  CourseInfo(this.data);
  final Json data;
  String get id => '${data['id']}';
  String get title => label(data);
  double get progress =>
      ((data['progressPercent'] as num? ?? 0).toDouble()).clamp(0, 100);
  int get lessonCount => (data['lessonsCount'] as num? ?? 0).toInt();
  List<Json> get sections => rows(data['sections']);
  List<Json> get lessons => sections.expand((s) => rows(s['lessons'])).toList();
  bool get expired {
    final end = DateTime.tryParse('${data['accessEndsAt']}');
    return end != null && end.isBefore(DateTime.now());
  }

  Json? get resume {
    final available = lessons.where((l) => l['status'] != 'Locked').toList();
    if (available.isEmpty) return null;
    final id = data['resumeLessonId'];
    return available.where((l) => l['id'] == id).firstOrNull ??
        available.where((l) => l['status'] != 'Completed').firstOrNull ??
        available.first;
  }

  static String typeName(dynamic type) =>
      const {
        'Video': 'فيديو',
        'Quiz': 'اختبار',
        'Text': 'شرح مكتوب',
        'File': 'ملف دراسي',
      }[type] ??
      'درس';
  static String statusName(dynamic status) =>
      const {
        'Draft': 'مسودة',
        'Published': 'منشور',
        'Archived': 'مؤرشف',
        'Completed': 'مكتمل',
        'Locked': 'مغلق',
        'InProgress': 'قيد التعلم',
      }[status] ??
      'متاح';
  static String duration(dynamic seconds) {
    final n = (seconds as num? ?? 0).toInt();
    if (n <= 0) return '';
    return n < 60
        ? '${arNumber(n)} ثانية'
        : '${arNumber((n / 60).ceil())} دقيقة';
  }

  static String accessName(dynamic value) =>
      const {
        'Month': 'شهر',
        'ThreeMonths': '٣ شهور',
        'Lifetime': 'بدون حد زمني',
        'UntilTermEnd': 'حتى نهاية الترم',
      }[value] ??
      'حسب خطة الكورس';
}
