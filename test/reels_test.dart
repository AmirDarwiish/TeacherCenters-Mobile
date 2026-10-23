import 'package:teacher_centers_mobile/core/app_icons.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:teacher_centers_mobile/core/api.dart';
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
  final api = Api(client: client, storage: MemoryStore());
  await api.accept(session('token', 'refresh'));
  return api;
}

class TestPlayback implements ReelPlayback {
  TestPlayback(this.uri, this.onDispose);
  final Uri uri;
  final VoidCallback onDispose;
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
    value.value = value.value.copyWith(
      isInitialized: true,
      size: const Size(720, 1280),
    );
  }

  @override
  Future<void> play() async {
    if (!disposed) value.value = value.value.copyWith(isPlaying: true);
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

  test(
    'legacy catalog is fetched once and only explicit preview videos are batched without duplicates',
    () async {
      var requests = 0;
      final c = catalogCourse('course');
      final lessons = ((c['sections'] as List).first as Map)['lessons'] as List;
      lessons.addAll(<Json>[
        {'id': 'private', 'type': 'Video', 'isPreview': false},
        {'id': 'text', 'type': 'Text', 'isPreview': true},
        {
          'id': 'locked',
          'type': 'Video',
          'isPreview': true,
          'status': 'Locked',
        },
        lessons.first,
      ]);
      final api = await apiWith((r) async {
        requests++;
        return response(200, [
          c,
          {...catalogCourse('draft'), 'status': 'Draft'},
        ]);
      });
      final feed = ReelsFeed(api);
      await feed.loadMore();
      expect(feed.items.length, 12);
      expect(feed.hasMore, isTrue);
      await feed.loadMore();
      await feed.loadMore();
      expect(feed.items.length, 26);
      expect(feed.items.map((e) => e.lessonId).toSet().length, 26);
      expect(feed.hasMore, isFalse);
      expect(requests, 1);
      feed.dispose();
    },
  );

  test(
    'paginated catalog skips empty preview pages, preserves retry page and stops at end',
    () async {
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
      expect(feed.hasMore, isFalse);
      feed.dispose();
    },
  );

  testWidgets(
    'vertical feed loads beyond first batch and owns only the visible decoder, stops off-tab and in background',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final signed = <String>[];
      final api = await apiWith((r) async {
        if (r.path.endsWith('/catalog')) {
          return response(200, [catalogCourse('open')]);
        }
        signed.add(r.path);
        return response(200, {
          'video': {
            'kind': 'mp4',
            'url': '/video/${r.path.split('/').last}.mp4',
            'watermarkText': 'الطالب • ١٢٣',
          },
        });
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
      expect(signed.length, 1);
      expect(alive, 1);
      expect(players.last.value.value.isPlaying, isTrue);
      await screenshot(tester, 'course-reels');
      await tester.tap(find.byTooltip('كتم الصوت'));
      await tester.pumpAndSettle();
      expect(players.last.volume, 0);
      for (var i = 0; i < 14; i++) {
        await tester.drag(find.byType(PageView), const Offset(0, -750));
        await settleReel(tester);
      }
      expect(signed.any((p) => p.endsWith('/open-14')), isTrue);
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

  testWidgets('late playback response cannot start a video swiped past', (
    tester,
  ) async {
    final delayed = Completer<ResponseBody>();
    final players = <TestPlayback>[];
    final api = await apiWith((r) async {
      if (r.path.endsWith('/catalog')) {
        return response(200, [catalogCourse('open', count: 2)]);
      }
      if (r.path.endsWith('/open-0')) return delayed.future;
      return response(200, {
        'video': {'kind': 'mp4', 'url': '/second.mp4'},
      });
    });
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ReelsPage(
            api: api,
            playbackFactory: (uri) {
              final p = TestPlayback(uri, () {});
              players.add(p);
              return p;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(PageView), const Offset(0, -650));
    await settleReel(tester);
    expect(players.length, 1);
    expect(players.single.uri.path, '/second.mp4');
    delayed.complete(
      response(200, {
        'video': {'kind': 'mp4', 'url': '/old.mp4'},
      }),
    );
    await tester.pumpAndSettle();
    expect(players.length, 1);
    expect(players.single.value.value.isPlaying, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(players.single.disposed, isTrue);
  });

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
