import 'dart:async';

import 'package:flutter/services.dart';

/// Robust Dart-side bridge to the native ExoPlayer implementation
class RobustPlayerController {
  static const String _methodChannelName = 'com.a2orbit.player/robust_channel';
  static const String _eventChannelName = 'com.a2orbit.player/robust_events';

  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static final Stream<dynamic> _eventBroadcastStream = const EventChannel(
    _eventChannelName,
  ).receiveBroadcastStream().asBroadcastStream();

  final StreamController<RobustPlayerEvent> _eventController =
      StreamController.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  int? _viewId;

  RobustPlayerController() {
    _eventSubscription = _eventBroadcastStream.listen(_handleEvent);
  }

  bool get isAttached => _viewId != null;

  Stream<RobustPlayerEvent> get events => _eventController.stream;

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
        await _methodChannel.invokeMethod<void>('disposePlayer', {
          'viewId': viewId,
        });
      } catch (e) {
        // Native side may already be disposed; ignore.
      }
    }
  }

  Future<void> setSource(String path, {List<String> subtitles = const []}) async {
    await _invoke<void>('setDataSource', {'path': path, 'subtitles': subtitles});
  }

  Future<void> play() async {
    await _invoke<void>('play');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> pause() async => _invoke<void>('pause');

  Future<void> seekTo(Duration position) async =>
      _invoke<void>('seekTo', {'position': position.inMilliseconds});

  Future<void> setPlaybackSpeed(double speed) async =>
      _invoke<void>('setPlaybackSpeed', {'speed': speed});

  Future<void> setAspectRatio(int resizeMode) async =>
      _invoke<void>('setAspectRatio', {'resizeMode': resizeMode});

  Future<void> enterPictureInPicture() async => _invoke<void>('enterPiP');

  Future<void> lockRotation(bool lock) async =>
      _invoke<void>('lockRotation', {'lock': lock});

  Future<void> setGesturesEnabled(bool enabled) async =>
      _invoke<void>('enableGestures', {'enabled': enabled});

  Future<Map<String, dynamic>?> getVideoInformation() async {
    final result = await _invoke<Map<dynamic, dynamic>>('getVideoInformation');
    return result?.cast<String, dynamic>();
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
        final isPlaying = event['isPlaying'] as bool? ?? false;
        final isBuffering = event['isBuffering'] as bool? ?? false;
        final isEnded = event['isEnded'] as bool? ?? false;
        _eventController.add(
          RobustPlaybackStateEvent(
            state: state,
            isPlaying: isPlaying,
            isBuffering: isBuffering,
            isEnded: isEnded,
          ),
        );
        break;
      case 'position':
        final position = Duration(
          milliseconds: (event['position'] as num?)?.toInt() ?? 0,
        );
        final duration = Duration(
          milliseconds: (event['duration'] as num?)?.toInt() ?? 0,
        );
        _eventController.add(
          RobustPositionEvent(position: position, duration: duration),
        );
        break;
      case 'error':
        _eventController.add(
          RobustErrorEvent(
            code: event['code']?.toString() ?? 'unknown',
            message: event['message']?.toString() ?? 'Unknown error',
          ),
        );
        break;
      case 'tracksChanged':
        final audioTracks = (event['audioTracks'] as List<dynamic>?)
                ?.map((e) => RobustAudioTrack.fromMap(e as Map<dynamic, dynamic>))
                .toList() ??
            [];
        final subtitleTracks = (event['subtitleTracks'] as List<dynamic>?)
                ?.map((e) => RobustSubtitleTrack.fromMap(e as Map<dynamic, dynamic>))
                .toList() ??
            [];
        _eventController.add(
          RobustTracksChangedEvent(audioTracks: audioTracks, subtitleTracks: subtitleTracks),
        );
        break;
      case 'gesture':
        final action = event['action']?.toString();
        final value = event['value']?.toString() ?? '';
        if (action != null) {
          _eventController.add(RobustGestureEvent(action, value));
        }
        break;
      default:
        break;
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) {
    final viewId = _viewId;
    if (viewId == null) {
      throw StateError('Robust player view has not been attached yet.');
    }
    final Map<String, dynamic> payload = {'viewId': viewId};
    if (arguments != null) {
      payload.addAll(arguments);
    }
    return _methodChannel.invokeMethod<T>(method, payload);
  }
}

// Event classes
abstract class RobustPlayerEvent {
  const RobustPlayerEvent();
}

class RobustPlaybackStateEvent extends RobustPlayerEvent {
  const RobustPlaybackStateEvent({
    required this.state,
    required this.isPlaying,
    required this.isBuffering,
    required this.isEnded,
  });

  final int state;
  final bool isPlaying;
  final bool isBuffering;
  final bool isEnded;
}

class RobustPositionEvent extends RobustPlayerEvent {
  const RobustPositionEvent({required this.position, required this.duration});

  final Duration position;
  final Duration duration;
}

class RobustErrorEvent extends RobustPlayerEvent {
  const RobustErrorEvent({required this.code, required this.message});

  final String code;
  final String message;
}

class RobustTracksChangedEvent extends RobustPlayerEvent {
  const RobustTracksChangedEvent({
    required this.audioTracks,
    required this.subtitleTracks,
  });

  final List<RobustAudioTrack> audioTracks;
  final List<RobustSubtitleTrack> subtitleTracks;
}

class RobustGestureEvent extends RobustPlayerEvent {
  const RobustGestureEvent(this.action, this.value);

  final String action;
  final String value;
}

class RobustAudioTrack {
  RobustAudioTrack({
    required this.groupIndex,
    required this.trackIndex,
    required this.id,
    required this.language,
    required this.label,
  });

  factory RobustAudioTrack.fromMap(Map<dynamic, dynamic> map) => RobustAudioTrack(
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

class RobustSubtitleTrack {
  RobustSubtitleTrack({
    required this.groupIndex,
    required this.trackIndex,
    required this.language,
    required this.label,
  });

  factory RobustSubtitleTrack.fromMap(Map<dynamic, dynamic> map) => RobustSubtitleTrack(
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
