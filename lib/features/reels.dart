import '../core/brand.dart';
import '../core/app_icons.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/api.dart';
import '../core/reels_feed.dart';
import '../core/widgets.dart';
import 'courses.dart';

abstract class ReelPlayback {
  ValueListenable<VideoPlayerValue> get value;
  Widget get view;
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class NativeReelPlayback implements ReelPlayback {
  NativeReelPlayback(Uri uri)
    : controller = VideoPlayerController.networkUrl(uri);
  final VideoPlayerController controller;
  @override
  ValueListenable<VideoPlayerValue> get value => controller;
  @override
  Widget get view => VideoPlayer(controller);
  @override
  Future<void> initialize() async {
    await controller.initialize();
    await controller.setLooping(true);
  }

  @override
  Future<void> play() => controller.play();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> setVolume(double volume) => controller.setVolume(volume);
  @override
  Future<void> dispose() => controller.dispose();
}

class ReelsPage extends StatefulWidget {
  const ReelsPage({
    super.key,
    required this.api,
    this.active = true,
    this.playbackFactory,
  });
  final Api api;
  final bool active;
  final ReelPlayback Function(Uri)? playbackFactory;
  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with WidgetsBindingObserver {
  late ReelsFeed feed;
  final pages = PageController();
  final Map<String, Json> links = {};
  ReelPlayback? player;
  Timer? settle;
  Future<void> cleanup = Future.value();
  int index = 0, epoch = 0;
  bool foreground = true, covered = false, muted = false, busy = false;
  Object? error;
  Json video = {};
  bool get eligible => widget.active && foreground && !covered;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    feed = ReelsFeed(widget.api)..addListener(feedChanged);
    if (widget.active) feed.loadMore();
  }

  void feedChanged() {
    if (!mounted) return;
    setState(() {});
    if (feed.items.isNotEmpty && player == null && !busy && eligible) {
      schedule();
    }
  }

  @override
  void didUpdateWidget(covariant ReelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active && feed.items.isEmpty) feed.loadMore();
      schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    schedule();
  }

  void stop() {
    epoch++;
    settle?.cancel();
    final old = player;
    player = null;
    // Serialize disposal before allocating another decoder, including rapid swipes.
    cleanup = cleanup.then((_) async {
      try {
        await old?.dispose();
      } catch (_) {
        /* Already released by the platform. */
      }
    });
  }

  void schedule() {
    stop();
    busy = false;
    error = null;
    video = {};
    if (mounted) setState(() {});
    if (!eligible || index >= feed.items.length) return;
    final token = epoch;
    // Swipe past a card without requesting a signed playback link for it.
    settle = Timer(const Duration(milliseconds: 350), () => start(token));
  }

  bool valid(int token) => mounted && eligible && token == epoch;

  Future<void> start(int token) async {
    await cleanup;
    if (!valid(token) || index >= feed.items.length) return;
    final reel = feed.items[index];
    setState(() {
      busy = true;
      error = null;
      video = {};
    });
    try {
      final cached = links[reel.lessonId];
      final expires = DateTime.tryParse('${cached?['expiresAt']}');
      var media = cached;
      if (media == null ||
          expires != null &&
              !expires.isAfter(
                DateTime.now().toUtc().add(const Duration(seconds: 30)),
              )) {
        final lesson = obj(
          await widget.api.get('/portal/lessons/${reel.lessonId}'),
        );
        media = obj(lesson['video']);
        if (!valid(token)) return;
        if (media['url'] == null || '${media['url']}'.trim().isEmpty) {
          throw ApiFailure('الفيديو غير جاهز للعرض حاليًا. جرّب فيديو آخر.');
        }
        links.remove(reel.lessonId);
        links[reel.lessonId] = media;
        while (links.length > 3) {
          links.remove(links.keys.first);
        }
      }
      if (!valid(token)) return;
      video = media;
      if (['youtube', 'vimeo'].contains(media['kind'])) return;
      final uri = widget.api.resolveUrl('${media['url']}');
      if (uri.scheme != 'https' &&
          !(uri.scheme == 'http' && uri.host == 'localhost')) {
        throw ApiFailure('رابط الفيديو غير صالح.');
      }
      final next = (widget.playbackFactory ?? NativeReelPlayback.new)(uri);
      player = next;
      await next.initialize();
      if (!valid(token)) return;
      await next.setVolume(muted ? 0 : 1);
      if (!valid(token)) return;
      await next.play();
    } catch (e) {
      if (valid(token)) {
        links.remove(reel.lessonId);
        stop();
        setState(() {
          busy = false;
          error = e is ApiFailure
              ? e
              : ApiFailure(
                  'تعذر تشغيل الفيديو. أعد المحاولة أو اسحب للفيديو التالي.',
                );
        });
      }
    } finally {
      if (mounted && token == epoch) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> goToCourse(CourseReel reel) async {
    covered = true;
    schedule();
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CoursePage(api: widget.api, id: reel.courseId),
        ),
      );
    } finally {
      covered = false;
      if (mounted) schedule();
    }
  }

  void refresh() {
    stop();
    feed.removeListener(feedChanged);
    feed.dispose();
    feed = ReelsFeed(widget.api)..addListener(feedChanged);
    index = 0;
    error = null;
    if (pages.hasClients) pages.jumpToPage(0);
    feed.loadMore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    feed.removeListener(feedChanged);
    feed.dispose();
    pages.dispose();
    super.dispose();
  }

  Widget message(
    String title, {
    String? subtitle,
    VoidCallback? retry,
    String button = 'حاول تاني',
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            AppIcons.videoCollectionOutlined,
            size: 48,
            color: BrandColors.whiteMuted,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BrandColors.whiteMuted),
            ),
          ],
          if (retry != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: retry, child: Text(button)),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: BrandColors.night,
    child: feed.items.isEmpty
        ? feed.loading
              ? const Center(
                  child: CircularProgressIndicator(color: BrandColors.white),
                )
              : message(
                  feed.error != null
                      ? 'تعذر تحميل الريلز'
                      : 'لسه مفيش فيديوهات مفتوحة',
                  subtitle: feed.error != null
                      ? '${feed.error}'
                      : 'الفيديوهات التي يتيحها المدرس للمعاينة هتظهر هنا.',
                  retry: feed.error != null ? () => feed.loadMore() : refresh,
                  button: feed.error != null ? 'حاول تاني' : 'تحديث',
                )
        : PageView.builder(
            controller: pages,
            scrollDirection: Axis.vertical,
            itemCount: feed.items.length + 1,
            onPageChanged: (value) {
              setState(() => index = value);
              schedule();
              if (value >= feed.items.length - 3 && feed.hasMore) {
                feed.loadMore();
              }
            },
            itemBuilder: (context, i) {
              if (i >= feed.items.length) {
                if (feed.loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: BrandColors.white),
                  );
                }
                return message(
                  feed.error != null
                      ? 'تعذر تحميل فيديوهات إضافية'
                      : feed.hasMore
                      ? 'شاهد المزيد'
                      : 'شفت كل الفيديوهات المتاحة',
                  subtitle: feed.error != null
                      ? '${feed.error}'
                      : 'تقدر ترجع لأي فيديو بالسحب لأسفل أو تحدّث القائمة.',
                  retry: feed.hasMore ? () => feed.loadMore() : refresh,
                  button: feed.hasMore ? 'تحميل المزيد' : 'تحديث الفيديوهات',
                );
              }
              return reelCard(feed.items[i], i == index);
            },
          ),
  );

  Widget reelCard(CourseReel reel, bool current) {
    final active = current ? player : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (active != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: active.value,
            builder: (_, value, child) {
              if (value.hasError) {
                return message('تعذر تشغيل الفيديو', retry: schedule);
              }
              if (!value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: BrandColors.white),
                );
              }
              return Semantics(
                button: true,
                label: value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل الفيديو',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => action(
                    context,
                    () => value.isPlaying ? active.pause() : active.play(),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: value.aspectRatio,
                          child: active.view,
                        ),
                      ),
                      if (!value.isPlaying)
                        const Center(
                          child: Icon(
                            AppIcons.playCircleFillRounded,
                            size: 64,
                            color: BrandColors.whiteMuted,
                          ),
                        ),
                      if (value.isBuffering)
                        const Center(
                          child: CircularProgressIndicator(
                            color: BrandColors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          )
        else if (current && busy)
          const Center(
            child: CircularProgressIndicator(color: BrandColors.white),
          )
        else if (current && error != null)
          message('$error', retry: schedule)
        else if (current && ['youtube', 'vimeo'].contains(video['kind']))
          message(
            'هذا الفيديو متاح على منصة خارجية',
            subtitle: 'افتح الكورس لمشاهدته من صفحة الدرس.',
          )
        else
          const Center(
            child: Icon(
              AppIcons.playCircleOutlineRounded,
              size: 64,
              color: BrandColors.whiteFaint,
            ),
          ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .3, .55, 1],
                  colors: [
                    BrandColors.nightOverlay,
                    BrandColors.transparent,
                    BrandColors.transparent,
                    BrandColors.nightDense,
                  ],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 16,
          start: 18,
          end: 18,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: BrandColors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'دروس مفتوحة',
                  style: TextStyle(
                    color: BrandColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (current && active != null)
                IconButton(
                  tooltip: muted ? 'تشغيل الصوت' : 'كتم الصوت',
                  onPressed: () async {
                    setState(() => muted = !muted);
                    await action(
                      context,
                      () => active.setVolume(muted ? 0 : 1),
                    );
                  },
                  icon: Icon(
                    muted
                        ? AppIcons.volumeOffRounded
                        : AppIcons.volumeUpRounded,
                    color: BrandColors.white,
                  ),
                ),
            ],
          ),
        ),
        if (current && video['watermarkText'] != null)
          PositionedDirectional(
            top: 76,
            start: 18,
            end: 18,
            child: IgnorePointer(
              child: Text(
                '${video['watermarkText']}',
                style: const TextStyle(
                  color: BrandColors.whiteMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        PositionedDirectional(
          start: 20,
          end: 20,
          bottom: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reel.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BrandColors.white,
                  fontSize: 23,
                  height: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  reel.teacherName,
                  reel.courseTitle,
                ].where((s) => s.isNotEmpty).join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BrandColors.whiteMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => goToCourse(reel),
                    icon: const Icon(AppIcons.autoStoriesOutlined, size: 18),
                    label: const Text('افتح الكورس'),
                  ),
                  const Spacer(),
                  const Icon(
                    AppIcons.swipeUpRounded,
                    size: 20,
                    color: BrandColors.whiteMuted,
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'اسحب للمزيد',
                      style: TextStyle(
                        color: BrandColors.whiteMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
