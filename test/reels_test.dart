import 'package:teacher_centers_mobile/core/app_icons.dart';

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/core/brand.dart';
import 'package:teacher_centers_mobile/core/reels_feed.dart';
import 'package:teacher_centers_mobile/features/reels.dart';
import 'package:teacher_centers_mobile/features/shell.dart';
import 'package:teacher_centers_mobile/features/courses.dart';

import 'api_test.dart' show MemoryStore, FakeAdapter, response, session;
import 'course_experience_test.dart' show host, loadTestFonts, screenshot;

Json catalogCourse(String id, {int count = 26, bool preview = true}) => {
  'id': id,
  'title': 'الفيزياء ببساطة',
  'status': 'Published',
  'audience': 'Open',
  'teacherName': 'أحمد محمود',
  'sections': [
    {
      'lessons': List<Json>.generate(
        count,
        (i) => {
          'id': '$id-$i',
          'title': 'قوانين الحركة — تدريب ${i + 1}',
          'type': 'Video',
          'isPreview': preview,
          'previewUrl':
              '/api/v1/public/t/demo/courses/$id/lessons/$id-$i/preview.mp4',
        },
      ),
    },
  ],
};

Future<Api> apiWith(
  Future<ResponseBody> Function(RequestOptions) handler,
) async {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  client.httpClientAdapter = FakeAdapter(handler);
  final api = Api(client: client, storage: MemoryStore())..slug = 'demo';
  await api.accept(session('token', 'refresh'));
  return api;
}

class TestPlayback implements ReelPlayback {
  TestPlayback(this.uri, this.onDispose, {this.initializeGate});
  final Uri uri;
  final VoidCallback onDispose;
  final Future<void>? initializeGate;
  int plays = 0;
  bool disposed = false;
  double volume = 1;
  @override
  final ValueNotifier<VideoPlayerValue> value = ValueNotifier(
    const VideoPlayerValue(duration: Duration(minutes: 2)),
  );
  @override
  Widget get view => const ColoredBox(
    color: Color(0xff173a58),
    child: Center(
      child: Icon(AppIcons.schoolOutlined, size: 100, color: Colors.white38),
    ),
  );
  @override
  Future<void> initialize() async {
    await initializeGate;
    if (disposed) return;
    value.value = value.value.copyWith(
      isInitialized: true,
      size: const Size(720, 1280),
    );
  }

  @override
  Future<void> play() async {
    if (!disposed) {
      plays++;
      value.value = value.value.copyWith(isPlaying: true);
    }
  }

  @override
  Future<void> pause() async {
    if (!disposed) value.value = value.value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setVolume(double next) async {
    volume = next;
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    onDispose();
    value.dispose();
  }
}

Future<void> settleReel(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  test('authorized previews shuffle without duplicates per round and continue beyond catalog end', () async {
    var requests = 0;
    final c = catalogCourse('course');
    final lessons = ((c['sections'] as List).first as Map)['lessons'] as List;
    lessons.addAll(<Json>[
      {'id': 'private', 'type': 'Video', 'isPreview': false},
      {'id': 'text', 'type': 'Text', 'isPreview': true},
      {'id': 'locked', 'type': 'Video', 'isPreview': true, 'status': 'Locked'},
      {'id': 'no-link', 'type': 'Video', 'isPreview': true},
      lessons.first,
    ]);
    final api = await apiWith((r) async {
      requests++;
      expect(r.path, '/public/t/demo/courses');
      expect(r.headers.containsKey('Authorization'), isFalse);
      return response(200, [
        c,
        {...catalogCourse('draft'), 'status': 'Draft'},
        {...catalogCourse('group'), 'audience': 'Group'},
      ]);
    });
    final feed = ReelsFeed(api, random: Random(7));
    await feed.loadMore();
    expect(feed.items.length, 12);
    expect(feed.hasMore, isTrue);
    await feed.loadMore();
    await feed.loadMore();
    expect(feed.items.length, 26);
    expect(feed.items.map((e) => e.lessonId).toSet().length, 26);
    expect(feed.hasMore, isTrue);
    final firstRound = feed.items.map((e) => e.lessonId).toList();
    expect(firstRound, isNot(List.generate(26, (i) => 'course-$i')));
    for (var i = 0; i < 8; i++) {
      await feed.loadMore();
    }
    expect(feed.items.length, greaterThan(100));
    final secondRound = feed.items
        .skip(26)
        .take(26)
        .map((e) => e.lessonId)
        .toList();
    expect(secondRound.toSet().length, 26);
    expect(secondRound, isNot(firstRound));
    for (var i = 1; i < feed.items.length; i++) {
      expect(feed.items[i].lessonId, isNot(feed.items[i - 1].lessonId));
    }
    expect(requests, 1);
    feed.dispose();
  });

  test('paginated catalog skips empty pages, retries failures and continues after remote end', () async {
    final requested = <int>[];
    var failed = false;
    final api = await apiWith((r) async {
      final page = r.queryParameters['page'] as int;
      requested.add(page);
      if (page == 1) {
        return response(200, {
          'items': [catalogCourse('private', preview: false)],
          'hasMore': true,
        });
      }
      if (page == 2) {
        return response(200, {
          'items': [catalogCourse('open', count: 1)],
          'hasMore': true,
        });
      }
      if (!failed) {
        failed = true;
        return response(500, {'message': 'حاول مرة أخرى'});
      }
      return response(200, {
        'items': [catalogCourse('last', count: 1)],
        'hasMore': false,
      });
    });
    final feed = ReelsFeed(api);
    await feed.loadMore();
    expect(requested, [1, 2]);
    expect(feed.items.single.lessonId, 'open-0');
    await feed.loadMore();
    expect(feed.error, isNotNull);
    expect(feed.items.length, 1);
    await feed.loadMore();
    expect(requested, [1, 2, 3, 3]);
    expect(feed.items.length, 2);
    expect(feed.hasMore, isTrue);
    await feed.loadMore();
    expect(feed.items.length, 4);
    expect(requested, [1, 2, 3, 3]);
    feed.dispose();
  });

  test('empty catalog stops safely; one preview remains swipeable without more requests', () async {
    for (final count in [0, 1]) {
      var requests = 0;
      final api = await apiWith((_) async {
        requests++;
        return response(200, [catalogCourse('single', count: count)]);
      });
      final feed = ReelsFeed(api);
      for (var i = 0; i < 30; i++) {
        await feed.loadMore();
      }
      expect(requests, 1);
      expect(feed.items.length, count == 0 ? 0 : 30);
      expect(feed.hasMore, count == 1);
      feed.dispose();
    }
  });

  testWidgets(
    'vertical feed loads beyond first batch and owns only the visible decoder, stops off-tab and in background',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final signed = <String>[];
      final api = await apiWith((r) async {
        if (r.path.endsWith('/public/t/demo/courses')) {
          return response(200, [catalogCourse('open')]);
        }
        signed.add(r.path);
        return response(429, {'code': 'playback-limit'});
      });
      final players = <TestPlayback>[];
      var alive = 0, peak = 0;
      ReelPlayback create(Uri uri) {
        alive++;
        if (alive > peak) peak = alive;
        final p = TestPlayback(uri, () => alive--);
        players.add(p);
        return p;
      }

      Widget view(bool active) => host(
        Scaffold(
          body: ReelsPage(api: api, active: active, playbackFactory: create),
        ),
      );
      await tester.pumpWidget(view(true));
      await settleReel(tester);
      expect(signed, isEmpty);
      expect(alive, 1);
      expect(players.last.value.value.isPlaying, isTrue);
      await screenshot(tester, 'course-reels');
      await tester.tap(find.byTooltip('كتم الصوت'));
      await tester.pumpAndSettle();
      expect(players.last.volume, 0);
      for (var i = 0; i < 40; i++) {
        await tester.drag(find.byType(PageView), const Offset(0, -750));
        await settleReel(tester);
      }
      expect(players.length, 41);
      expect(signed, isEmpty);
      expect(players.map((p) => p.uri).toSet().length, 26);
      expect(peak, 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(alive, 0);
      await tester.pumpWidget(view(true));
      await settleReel(tester);
      expect(alive, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(alive, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleReel(tester);
      expect(alive, 1);
      expect(peak, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(alive, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late initialization cannot play a video swiped past', (
    tester,
  ) async {
    final delayed = Completer<void>();
    final players = <TestPlayback>[];
    final requests = <String>[];
    final api = await apiWith((r) async {
      requests.add(r.path);
      return response(200, [catalogCourse('open', count: 2)]);
    });
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ReelsPage(
            api: api,
            playbackFactory: (uri) {
              final p = TestPlayback(
                uri,
                () {},
                initializeGate: players.isEmpty ? delayed.future : null,
              );
              players.add(p);
              return p;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(players.length, 1);
    await tester.drag(find.byType(PageView), const Offset(0, -650));
    await settleReel(tester);
    expect(players.length, 2);
    expect(players.first.disposed, isTrue);
    expect(players.last.uri, isNot(players.first.uri));
    expect(players.last.plays, 1);
    delayed.complete();
    await tester.pumpAndSettle();
    expect(players.first.plays, 0);
    expect(players.last.value.value.isPlaying, isTrue);
    expect(requests, ['/public/t/demo/courses']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(players.last.disposed, isTrue);
  });

  testWidgets(
    'reels cover the viewport with overlay captions and survive theme changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = await apiWith(
        (r) async => r.path.endsWith('/public/t/demo/courses')
            ? response(200, [catalogCourse('open', count: 3)])
            : response(200, {
                'video': {
                  'kind': 'mp4',
                  'url': '/clip.mp4',
                  'watermarkText': 'الطالب ١٢٣',
                },
              }),
      );
      var created = 0;
      Widget view(bool dark) => host(
        Scaffold(
          body: ReelsPage(
            api: api,
            playbackFactory: (uri) {
              created++;
              return TestPlayback(uri, () {});
            },
          ),
        ),
        dark: dark,
      );
      await tester.pumpWidget(view(false));
      await settleReel(tester);
      for (final dark in [false, true, false]) {
        await tester.pumpWidget(view(dark));
        await tester.pumpAndSettle();
        final b = dark ? BrandColors.dark : BrandColors.light;
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('reels-background')),
              )
              .color,
          b.bg,
        );
        expect(
          tester.widget<Text>(find.text('دروس مفتوحة').first).style!.color,
          BrandColors.white,
        );
        expect(
          tester.widget<Text>(find.text('اسحب للمزيد').first).style!.color,
          BrandColors.whiteMuted,
        );
        final cover = find.byKey(const ValueKey('reel-video-cover')).first;
        expect(tester.widget<FittedBox>(cover).fit, BoxFit.cover);
        expect(tester.getSize(cover), const Size(360, 740));
        expect(find.byType(BrandCard), findsNothing);
        expect(created, 1);
        await screenshot(tester, 'reels-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(const Size(640, 320));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(created, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'reels loading and empty states follow the theme (dark: $dark)',
      (tester) async {
        final responseReady = Completer<ResponseBody>();
        final api = await apiWith((_) => responseReady.future);
        final b = dark ? BrandColors.dark : BrandColors.light;
        await tester.pumpWidget(
          host(
            Scaffold(body: ReelsPage(api: api)),
            dark: dark,
          ),
        );
        await tester.pump();
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .color,
          b.primary,
        );
        responseReady.complete(response(200, []));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('reels-background')),
              )
              .color,
          b.bg,
        );
        final text = find.text('لسه مفيش فيديوهات مفتوحة');
        expect(tester.widget<Text>(text).style!.color, b.ink);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'shell keeps bottom navigation available over the reels tab in both themes',
    (tester) async {
      final api = await apiWith((_) async => response(200, []));
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          host(
            Shell(api: api, onTheme: () {}),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        if (!dark) {
          await tester.tap(find.text('ريلز'));
          await tester.pumpAndSettle();
        }
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(SentrakNavigationBar), findsOneWidget);
        expect(find.byTooltip('رجوع'), findsOneWidget);
        final b = dark ? BrandColors.dark : BrandColors.light;
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('reels-background')),
              )
              .color,
          b.bg,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(SentrakNavigationBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inactive reels make no catalog or playback requests', (
    tester,
  ) async {
    var requests = 0;
    final api = await apiWith((_) async {
      requests++;
      return response(200, []);
    });
    await tester.pumpWidget(host(ReelsPage(api: api, active: false)));
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    testWidgets(
      'modern navigation keeps reels physically centered and usable (dark: $dark)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selected = -1;
        await tester.pumpWidget(
          host(
            Scaffold(
              bottomNavigationBar: SentrakNavigationBar(
                selectedIndex: 2,
                onSelected: (i) => selected = i,
              ),
            ),
            dark: dark,
            scale: 1.4,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.text('ريلز')).dx, closeTo(160, 1));
        await tester.tap(find.text('الحصص'));
        expect(selected, 3);
        await tester.pumpAndSettle();
        await screenshot(tester, 'navigation-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final rtl in [true, false]) {
    testWidgets(
      'lesson arrows point to actual previous and next directions (RTL: $rtl)',
      (tester) async {
        final visits = <String>[];
        final api = await apiWith((r) async {
          visits.add(r.path);
          return response(200, {
            'title': 'شرح الدرس',
            'type': 'Text',
            'prevLessonId': 'previous',
            'nextLessonId': 'next',
          });
        });
        await tester.pumpWidget(
          host(
            Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: LessonPage(api: api, id: 'current'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final previous = find.widgetWithText(OutlinedButton, 'السابق');
        final next = find.widgetWithText(FilledButton, 'الدرس التالي');
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: previous, matching: find.byType(Icon)),
              )
              .icon,
          rtl ? AppIcons.arrowForwardRounded : AppIcons.arrowBackRounded,
        );
        final nextIcon = tester.widget<Icon>(
          find.descendant(of: next, matching: find.byType(Icon)),
        );
        expect(
          nextIcon.icon,
          rtl ? AppIcons.arrowBackRounded : AppIcons.arrowForwardRounded,
        );
        expect(nextIcon.textDirection, TextDirection.ltr);
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(visits.last.endsWith('/next'), isTrue);
      },
    );
  }
}
