import 'dart:collection';
import 'dart:developer';
import 'dart:typed_data';

class TimelinePreviewResult {
  TimelinePreviewResult({
    required this.position,
    required this.bytes,
    required this.fromCache,
    this.error,
  });

  final Duration position;
  final Uint8List? bytes;
  final bool fromCache;
  final Object? error;

  bool get isSuccess => bytes != null && bytes!.isNotEmpty;
}

typedef TimelinePreviewFetcher =
    Future<Uint8List?> Function({
      required int targetPositionMs,
      required int maxWidth,
      required int maxHeight,
      required int quality,
    });

class TimelinePreviewService {
  TimelinePreviewService._();

  static final TimelinePreviewService instance = TimelinePreviewService._();

  static const int _maxEntriesPerSource = 80;
  final Map<String, LinkedHashMap<int, Uint8List>> _cacheBySource = {};

  Future<TimelinePreviewResult> getPreview({
    required String videoSource,
    required Duration position,
    required TimelinePreviewFetcher fetcher,
    int precisionMs = 200,
    int maxWidth = 160,
    int maxHeight = 90,
    int quality = 75,
  }) async {
    final cacheKey = (position.inMilliseconds ~/ precisionMs) * precisionMs;
    final cache = _cacheBySource.putIfAbsent(
      videoSource,
      () => LinkedHashMap<int, Uint8List>(),
    );

    final cachedBytes = cache[cacheKey];
    if (cachedBytes != null) {
      cache
        ..remove(cacheKey)
        ..[cacheKey] = cachedBytes;
      return TimelinePreviewResult(
        position: Duration(milliseconds: cacheKey),
        bytes: cachedBytes,
        fromCache: true,
      );
    }

    try {
      final bytes = await fetcher(
        targetPositionMs: cacheKey,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      if (bytes == null || bytes.isEmpty) {
        log(
          'Timeline preview fetcher returned empty bytes for $videoSource @${cacheKey}ms',
          name: 'TimelinePreviewService',
        );
        return TimelinePreviewResult(
          position: Duration(milliseconds: cacheKey),
          bytes: null,
          fromCache: false,
          error: 'empty_bytes',
        );
      }

      final normalizedBytes = Uint8List.fromList(bytes);
      cache[cacheKey] = normalizedBytes;
      if (cache.length > _maxEntriesPerSource) {
        cache.remove(cache.keys.first);
      }

      return TimelinePreviewResult(
        position: Duration(milliseconds: cacheKey),
        bytes: normalizedBytes,
        fromCache: false,
      );
    } catch (error, stackTrace) {
      log(
        'Timeline preview fetch failed for $videoSource @${cacheKey}ms: $error',
        name: 'TimelinePreviewService',
        error: error,
        stackTrace: stackTrace,
      );
      return TimelinePreviewResult(
        position: Duration(milliseconds: cacheKey),
        bytes: null,
        fromCache: false,
        error: error,
      );
    }
  }

  void clearCache(String videoSource) {
    _cacheBySource.remove(videoSource);
  }

  void clearAll() {
    _cacheBySource.clear();
  }
}
