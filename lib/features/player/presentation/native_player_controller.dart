import 'dart:async';

import 'package:flutter/services.dart';

/// Dart-side bridge to the native ExoPlayer implementation.
class NativePlayerController {
  static const String _methodChannelName = 'com.a2orbit.player/channel';
  static const String _eventChannelName = 'com.a2orbit.player/events';

  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static final Stream<dynamic> _eventBroadcastStream = const EventChannel(_eventChannelName)
      .receiveBroadcastStream()
      .asBroadcastStream();

  final StreamController<NativePlayerEvent> _eventController = StreamController.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  int? _viewId;

  NativePlayerController() {
    _eventSubscription = _eventBroadcastStream.listen(_handleEvent);
  }

  bool get isAttached => _viewId != null;

  Stream<NativePlayerEvent> get events => _eventController.stream;

  void attach(int viewId) {
    _viewId = viewId;
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _eventController.close();
    final viewId = _viewId;
    _viewId = null;
    if (viewId != null) {
      try {
        await _methodChannel.invokeMethod<void>('disposePlayer', {'viewId': viewId});
      } catch (_) {
        // Native side may already be disposed; ignore.
      }
    }
  }

  Future<void> setSource(String path, {List<String> subtitles = const []}) async {
    await _invoke<void>('setDataSource', {'path': path, 'subtitles': subtitles});
  }

  Future<void> play() async => _invoke<void>('play');

  Future<void> pause() async => _invoke<void>('pause');

  Future<void> seekTo(Duration position) async =>
      _invoke<void>('seekTo', {'position': position.inMilliseconds});

  Future<void> setPlaybackSpeed(double speed) async =>
      _invoke<void>('setPlaybackSpeed', {'speed': speed});

  Future<void> setDecoder(DecoderType decoder) async =>
      _invoke<void>('setDecoder', {'decoder': decoder.name});

  Future<List<NativeAudioTrack>> getAudioTracks() async {
    final result = await _invoke<List<dynamic>>('getAvailableAudioTracks');
    if (result == null) return [];
    return result
        .whereType<Map<dynamic, dynamic>>()
        .map((map) => NativeAudioTrack.fromMap(map))
        .toList(growable: false);
  }

  Future<void> switchAudioTrack(int groupIndex, int trackIndex) async =>
      _invoke<void>('switchAudioTrack', {'groupIndex': groupIndex, 'trackIndex': trackIndex});

  Future<List<NativeSubtitleTrack>> getSubtitleTracks() async {
    final result = await _invoke<List<dynamic>>('getSubtitleTracks');
    if (result == null) return [];
    return result
        .whereType<Map<dynamic, dynamic>>()
        .map((map) => NativeSubtitleTrack.fromMap(map))
        .toList(growable: false);
  }

  Future<void> selectSubtitleTrack({required int? groupIndex, required int? trackIndex}) async {
    await _invoke<void>('selectSubtitleTrack', {
      'groupIndex': groupIndex,
      'trackIndex': trackIndex,
    });
  }

  Future<void> setSubtitleDelay(Duration delay) async =>
      _invoke<void>('setSubtitleDelay', {'delayMs': delay.inMilliseconds});

  Future<void> setAudioDelay(Duration delay) async =>
      _invoke<void>('setAudioDelay', {'delayMs': delay.inMilliseconds});

  Future<void> setAspectRatio(AspectRatioMode mode) async =>
      _invoke<void>('setAspectRatio', {'resizeMode': mode.nativeValue});

  Future<void> enterPictureInPicture() async => _invoke<void>('enterPiP');

  Future<void> setAutoPiPEnabled(bool enabled) async =>
      _invoke<void>('togglePiP', {'enable': enabled});

  Future<void> lockRotation(bool lock) async =>
      _invoke<void>('lockRotation', {'lock': lock});

  Future<void> setGesturesEnabled(bool enabled) async =>
      _invoke<void>('enableGestures', {'enabled': enabled});

  Future<NativeVideoInformation?> getVideoInformation() async {
    final result = await _invoke<Map<dynamic, dynamic>>('getVideoInformation');
    return result == null ? null : NativeVideoInformation.fromMap(result);
  }

  void _handleEvent(dynamic event) {
    final viewId = _viewId;
    if (viewId == null) return;
    if (event is! Map) return;
    final eventViewId = (event['viewId'] as num?)?.toInt();
    if (eventViewId != viewId) return;
    final type = event['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'playbackState':
        final state = (event['state'] as num?)?.toInt() ?? 0;
        final playing = event['playing'] as bool? ?? false;
        _eventController.add(NativePlaybackStateEvent(state: state, isPlaying: playing));
        break;
      case 'position':
        final position = Duration(milliseconds: (event['position'] as num?)?.toInt() ?? 0);
        final duration = Duration(milliseconds: (event['duration'] as num?)?.toInt() ?? 0);
        _eventController.add(NativePositionEvent(position: position, duration: duration));
        break;
      case 'error':
        _eventController.add(NativeErrorEvent(
          code: event['code']?.toString() ?? 'unknown',
          message: event['message']?.toString() ?? 'Unknown error',
        ));
        break;
      case 'trackChanged':
        _eventController.add(const NativeTracksChangedEvent());
        break;
      case 'gesture':
        final action = event['action']?.toString();
        if (action != null) {
          _eventController.add(NativeGestureEvent(action));
        }
        break;
      default:
        break;
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) {
    final viewId = _viewId;
    if (viewId == null) {
      throw StateError('Native player view has not been attached yet.');
    }
    final Map<String, dynamic> payload = {'viewId': viewId};
    if (arguments != null) {
      payload.addAll(arguments);
    }
    return _methodChannel.invokeMethod<T>(method, payload);
  }
}

enum DecoderType { hardware, software }

enum AspectRatioMode {
  fit(0),
  fixedWidth(1),
  fixedHeight(2),
  fill(3),
  zoom(4);

  const AspectRatioMode(this.nativeValue);
  final int nativeValue;
}

abstract class NativePlayerEvent {
  const NativePlayerEvent();
}

class NativePlaybackStateEvent extends NativePlayerEvent {
  const NativePlaybackStateEvent({required this.state, required this.isPlaying});

  /// Matches ExoPlayer playback state constants.
  final int state;
  final bool isPlaying;

  bool get isEnded => state == 4; // STATE_ENDED
  bool get isBuffering => state == 2; // STATE_BUFFERING
}

class NativePositionEvent extends NativePlayerEvent {
  const NativePositionEvent({required this.position, required this.duration});

  final Duration position;
  final Duration duration;
}

class NativeErrorEvent extends NativePlayerEvent {
  const NativeErrorEvent({required this.code, required this.message});

  final String code;
  final String message;
}

class NativeTracksChangedEvent extends NativePlayerEvent {
  const NativeTracksChangedEvent();
}

class NativeGestureEvent extends NativePlayerEvent {
  const NativeGestureEvent(this.action);

  final String action;
}

class NativeAudioTrack {
  NativeAudioTrack({
    required this.groupIndex,
    required this.trackIndex,
    required this.id,
    required this.language,
    required this.label,
  });

  factory NativeAudioTrack.fromMap(Map<dynamic, dynamic> map) => NativeAudioTrack(
        groupIndex: (map['groupIndex'] as num?)?.toInt() ?? 0,
        trackIndex: (map['trackIndex'] as num?)?.toInt() ?? 0,
        id: map['id']?.toString() ?? '',
        language: map['language']?.toString() ?? 'Unknown',
        label: map['label']?.toString() ?? 'Track',
      );

  final int groupIndex;
  final int trackIndex;
  final String id;
  final String language;
  final String label;
}

class NativeSubtitleTrack {
  NativeSubtitleTrack({
    required this.groupIndex,
    required this.trackIndex,
    required this.language,
    required this.label,
  });

  factory NativeSubtitleTrack.fromMap(Map<dynamic, dynamic> map) => NativeSubtitleTrack(
        groupIndex: (map['groupIndex'] as num?)?.toInt() ?? 0,
        trackIndex: (map['trackIndex'] as num?)?.toInt() ?? 0,
        language: map['language']?.toString() ?? 'Unknown',
        label: map['label']?.toString() ?? 'Subtitle',
      );

  final int groupIndex;
  final int trackIndex;
  final String language;
  final String label;
}

class NativeVideoInformation {
  NativeVideoInformation({
    this.videoCodec,
    this.width,
    this.height,
    this.frameRate,
    this.audioCodec,
    this.audioChannels,
    this.audioSampleRate,
    this.duration,
    this.size,
    this.path,
  });

  factory NativeVideoInformation.fromMap(Map<dynamic, dynamic> map) => NativeVideoInformation(
        videoCodec: map['videoCodec']?.toString(),
        width: (map['width'] as num?)?.toInt(),
        height: (map['height'] as num?)?.toInt(),
        frameRate: (map['frameRate'] as num?)?.toDouble(),
        audioCodec: map['audioCodec']?.toString(),
        audioChannels: (map['audioChannels'] as num?)?.toInt(),
        audioSampleRate: (map['audioSampleRate'] as num?)?.toInt(),
        duration: (map['duration'] as num?)?.toInt(),
        size: (map['size'] as num?)?.toInt(),
        path: map['path']?.toString(),
      );

  final String? videoCodec;
  final int? width;
  final int? height;
  final double? frameRate;
  final String? audioCodec;
  final int? audioChannels;
  final int? audioSampleRate;
  final int? duration;
  final int? size;
  final String? path;
}
