import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/core/course_model.dart';
import 'package:teacher_centers_mobile/core/design.dart';
import 'package:teacher_centers_mobile/features/courses.dart';
import 'package:teacher_centers_mobile/features/authoring.dart';
import 'package:teacher_centers_mobile/features/course_management.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;

final course = <String, dynamic>{
  'id': 'course-1',
  'title': 'الفيزياء ببساطة — من الفهم للإتقان',
  'subtitle': 'شرح مترابط، تدريب عملي، وثقة في كل سؤال.',
  'description':
      'رحلة متكاملة لفهم قوانين الحركة وتطبيقها خطوة بخطوة. شاهد الشرح، جرّب بنفسك، واختبر فهمك بعد كل وحدة.',
  'teacherId': 'teacher-1',
  'teacherName': 'أحمد محمود',
  'audience': 'Open',
  'status': 'Published',
  'kind': 'Course',
  'level': 'All',
  'price': 450,
  'accessDuration': 'ThreeMonths',
  'progressPercent': 35,
  'completedCount': 7,
  'lessonsCount': 20,
  'resumeLessonId': 'lesson-2',
  'outcomes': [
    'فهم قوانين الحركة وتطبيقها بثقة',
    'اختيار طريقة الحل المناسبة لكل مسألة',
  ],
  'requirements': ['أساسيات الجبر'],
  'targetAudience': ['طلاب الصف الثالث الثانوي'],
  'rowVersion': 'version-1',
  'groupIds': ['group-1'],
  'sections': [
    {
      'id': 'section-1',
      'title': 'الانطلاقة: أساسيات الحركة',
      'lessons': [
        {
          'id': 'lesson-1',
          'title': 'قبل ما نبدأ: خريطة الكورس',
          'type': 'Text',
          'status': 'Completed',
          'isPreview': true,
        },
        {
          'id': 'lesson-2',
          'title': 'الحركة في خط مستقيم',
          'type': 'Video',
          'status': 'InProgress',
          'positionSeconds': 245,
          'durationSeconds': 1320,
        },
        {
          'id': 'lesson-3',
          'title': 'اختبر فهمك — الوحدة الأولى',
          'type': 'Quiz',
          'status': 'Locked',
        },
      ],
    },
    {'id': 'section-2', 'title': 'قوانين نيوتن وتطبيقاتها', 'lessons': []},
  ],
};
Future<Api> fakeApi({
  bool teacher = false,
  bool enrolled = true,
  void Function(RequestOptions)? request,
}) async {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  client.httpClientAdapter = FakeAdapter((o) async {
    request?.call(o);
    if (o.path.endsWith('/refresh')) {
      return response(200, session('new', 'refresh'));
    }
    if (o.path.endsWith('/portal/courses')) {
      return response(200, enrolled ? [course] : []);
    }
    if (o.path.endsWith('/portal/catalog')) return response(200, [course]);
    if (o.path.endsWith('/courses')) {
      return response(200, {
        'items': [course],
        'totalCount': 1,
      });
    }
    if (o.path.contains('/portal/lessons/')) {
      return response(200, {
        'id': 'lesson-text',
        'title': 'قبل ما نبدأ: خريطة الكورس',
        'type': 'Text',
        'body':
            'أهلاً بيك في رحلتك لفهم الفيزياء.\n\nابدأ بفهم الفكرة قبل حفظ القانون. بعد كل شرح، حل مثالاً بنفسك ثم راجع خطواتك.\n\nفي الوحدة الأولى هنتعرف على الحركة في خط مستقيم ونربط بين المسافة والسرعة والزمن.',
        'nextLessonId': 'lesson-2',
      });
    }
    return response(200, course);
  });
  final api = Api(client: client, storage: MemoryStore())..slug = 'demo';
  final auth = session('token', 'refresh');
  if (teacher) auth['profile'] = {'id': 'teacher-1', 'role': 'Teacher'};
  await api.accept(auth);
  return api;
}

final shotKey = GlobalKey();
Widget host(
  Widget child, {
  bool dark = false,
  double scale = 1,
  bool captureNavigator = false,
}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: appTheme(dark ? Brightness.dark : Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: captureNavigator
        ? RepaintBoundary(key: shotKey, child: child!)
        : child!,
  ),
  home: captureNavigator ? child : RepaintBoundary(key: shotKey, child: child),
);
Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final boundary =
        shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

Future<void> loadTestFonts() async {
  if (!const bool.fromEnvironment('SCREENSHOTS')) return;
  await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      ))
      .load();
  await (FontLoader('IBMPlexSansArabic')
        ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Medium.ttf'))
        ..addFont(
          rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf'),
        ))
      .load();
  await (FontLoader(
    'Alexandria',
  )..addFont(rootBundle.load('assets/fonts/Alexandria.ttf'))).load();
}

void main() {
  setUpAll(loadTestFonts);
  test(
    'resume never chooses a locked lesson; progress clamps invalid server values',
    () {
      expect(CourseInfo(course).resume?['id'], 'lesson-2');
      final lockedResume = {
        ...course,
        'resumeLessonId': 'lesson-3',
        'progressPercent': 130,
      };
      expect(CourseInfo(lockedResume).resume?['id'], 'lesson-2');
      expect(CourseInfo(lockedResume).progress, 100);
      expect(CourseInfo({'sections': []}).resume, isNull);
    },
  );
  testWidgets(
    'library searches the complete student collection and shows an empty result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = await fakeApi();
      await tester.pumpWidget(
        host(
          Scaffold(
            appBar: AppBar(title: const Text('الكورسات')),
            body: CoursesPage(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(course['title'] as String), findsOneWidget);
      await screenshot(tester, 'course-library');
      await tester.enterText(find.byType(TextField), 'كيمياء');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('لا توجد كورسات مطابقة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'enrolled course offers resume and never asks for another purchase',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = await fakeApi();
      await tester.pumpWidget(host(CoursePage(api: api, id: 'course-1')));
      await tester.pumpAndSettle();
      expect(find.text('استكمل التعلم'), findsOneWidget);
      expect(find.text('اشترك الآن'), findsNothing);
      await screenshot(tester, 'course-detail');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'catalog purchase state renders on narrow dark screen with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = await fakeApi(enrolled: false);
      await tester.pumpWidget(
        host(CoursePage(api: api, id: 'course-1'), dark: true, scale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(find.text('اشترك الآن'), findsOneWidget);
      expect(find.text('استكمل التعلم'), findsNothing);
      await screenshot(tester, 'course-detail-dark');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('teacher edits preserve audience and existing group links', (
    tester,
  ) async {
    RequestOptions? update;
    final api = await fakeApi(
      teacher: true,
      request: (o) {
        if (o.method == 'PUT') update = o;
      },
    );
    await tester.pumpWidget(
      host(NewCoursePage(api: api, existing: {...course, 'audience': 'Group'})),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('حفظ التعديلات'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();
    expect(update?.data['audience'], 'Group');
    expect(update?.data['groupIds'], ['group-1']);
    expect(update?.data['outcomes'], course['outcomes']);
    expect(update?.headers['If-Match'], '"version-1"');
  });
  testWidgets(
    'free enrollment uses purchase endpoint and never starts paid checkout',
    (tester) async {
      final original = course['price'];
      course['price'] = 0;
      addTearDown(() => course['price'] = original);
      final requests = <RequestOptions>[];
      final api = await fakeApi(enrolled: false, request: requests.add);
      await tester.pumpWidget(host(CoursePage(api: api, id: 'course-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اشترك الآن'));
      await tester.pumpAndSettle();
      expect(
        requests
            .where((r) => r.method == 'POST' && r.path.endsWith('/purchase'))
            .length,
        1,
      );
      expect(requests.any((r) => r.path.endsWith('/checkout')), false);
    },
  );
  testWidgets(
    'curriculum save includes every lesson exactly once after reorder',
    (tester) async {
      RequestOptions? update;
      final api = await fakeApi(
        teacher: true,
        request: (o) {
          if (o.method == 'PUT') update = o;
        },
      );
      await tester.pumpWidget(host(CurriculumPage(api: api, course: course)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('نقل لأسفل').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ ترتيب المنهج'));
      await tester.pumpAndSettle();
      final sections = rows(update?.data['sections']);
      expect(sections.map((s) => s['id']), ['section-2', 'section-1']);
      expect(sections.expand((s) => s['lessonIds'] as List).toSet(), {
        'lesson-1',
        'lesson-2',
        'lesson-3',
      });
    },
  );
  testWidgets('teacher tools and lesson reader render with Arabic layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final teacher = await fakeApi(teacher: true);
    await tester.pumpWidget(host(CoursePage(api: teacher, id: 'course-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المزيد'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -530));
    await tester.pumpAndSettle();
    await screenshot(tester, 'course-teacher');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(LessonPage(api: await fakeApi(), id: 'lesson-text')),
    );
    await tester.pumpAndSettle();
    await screenshot(tester, 'lesson-reader');
    expect(tester.takeException(), isNull);
  });
}
