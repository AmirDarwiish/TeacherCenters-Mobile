import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';

class CourseReel {
  const CourseReel({
    required this.lessonId,
    required this.courseId,
    required this.title,
    required this.courseTitle,
    required this.teacherName,
  });
  final String lessonId, courseId, title, courseTitle, teacherName;
}

/// Only explicit preview video lessons returned by the authorized catalog qualify.
/// Supports today's complete-list response and a paginated catalog response.
class ReelsFeed extends ChangeNotifier {
  ReelsFeed(this.api, {this.batchSize = 12, Random? random})
    : _random = random ?? Random();
  final Random _random;
  final Api api;
  final int batchSize;
  final List<CourseReel> items = [];
  final List<CourseReel> _pending = [], _pool = [];
  final Set<String> _seen = {}, _pages = {};
  bool loading = false, hasMore = true, _remoteMore = true, _disposed = false;
  Object? error;
  int _page = 1;
  static const pageSize = 12;

  Iterable<CourseReel> _extract(dynamic data) sync* {
    for (final course in rows(data)) {
      if (course['id'] == null ||
          course['status'] != null && course['status'] != 'Published') {
        continue;
      }
      for (final section in rows(course['sections'])) {
        for (final lesson in rows(section['lessons'])) {
          if (lesson['id'] == null ||
              lesson['type'] != 'Video' ||
              lesson['isPreview'] != true ||
              lesson['status'] == 'Locked') {
            continue;
          }
          final id = '${lesson['id']}';
          if (!_seen.add(id)) continue;
          yield CourseReel(
            lessonId: id,
            courseId: '${course['id']}',
            title: label(lesson),
            courseTitle: label(course),
            teacherName: '${course['teacherName'] ?? ''}',
          );
        }
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      // Empty batches (courses with no previews) must not strand the feed.
      while (_pending.isEmpty && _remoteMore && !_disposed) {
        final response = await api.get(
          '/portal/catalog',
          query: {'page': _page, 'pageSize': pageSize},
        );
        if (_disposed) return;
        final courses = rows(response);
        final fingerprint = courses.map((c) => '${c['id']}').join('|');
        if (courses.isEmpty || !_pages.add(fingerprint)) {
          _remoteMore = false;
          break;
        }
        final discovered = _extract(response).toList()..shuffle(_random);
        _pool.addAll(discovered);
        _pending.addAll(discovered);
        final metadata = obj(response);
        final total = metadata['totalCount'];
        _remoteMore =
            response is! List &&
            (metadata['hasMore'] is bool
                ? metadata['hasMore'] == true
                : total is num
                ? _page * pageSize < total
                : courses.length >= pageSize);
        _page++;
      }
      // A new shuffled round keeps the feed swipeable after all authorized
      // previews have been seen, without refetching the same catalog pages.
      if (_pending.isEmpty && !_remoteMore && _pool.isNotEmpty) {
        _pending.addAll(_pool.toList()..shuffle(_random));
        if (_pending.length > 1 &&
            items.isNotEmpty &&
            _pending.first.lessonId == items.last.lessonId) {
          final first = _pending.removeAt(0);
          _pending.add(first);
        }
      }
      final count = _pending.length < batchSize ? _pending.length : batchSize;
      items.addAll(_pending.take(count));
      _pending.removeRange(0, count);
      hasMore = _pool.isNotEmpty || _remoteMore;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
