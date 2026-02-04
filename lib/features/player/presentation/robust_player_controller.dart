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

  Future<void> setSource(
    String path, {
    List<String> subtitles = const [],
  }) async {
    await _invoke<void>('setDataSource', {
      'path': path,
      'subtitles': subtitles,
    });
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

  Future<bool> enterPictureInPicture() async {
    final result = await _invoke<bool>('enterPictureInPicture');
    return result ?? false;
  }

  Future<void> lockRotation(bool lock) async =>
      _invoke<void>('lockRotation', {'lock': lock});

  Future<void> setGesturesEnabled(bool enabled) async =>
      _invoke<void>('enableGestures', {'enabled': enabled});

  Future<void> applyAspectMode(String mode, {double? ratio}) async {
    await _invoke<void>('applyAspectMode', {
      'mode': mode,
      if (ratio != null) 'ratio': ratio,
    });
  }

  Future<double?> setPlayerBrightness(double brightness) async =>
      _invoke<double>('setPlayerBrightness', {'brightness': brightness});

  Future<Map<String, dynamic>?> prepareVolumeGesture() async {
    final result = await _invoke<Map<dynamic, dynamic>>('prepareVolumeGesture');
    return result?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> applyVolumeLevel(double level) async {
    final result = await _invoke<Map<dynamic, dynamic>>('applyVolumeLevel', {
      'level': level,
    });
    return result?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> finalizeVolumeGesture(double? level) async {
    final result = await _invoke<Map<dynamic, dynamic>>(
      'finalizeVolumeGesture',
      {'level': level},
    );
    return result?.cast<String, dynamic>();
  }

  Future<void> handleSeekGesture(double delta) async =>
      _invoke<void>('handleSeekGesture', {'delta': delta});

  Future<void> resetGestureStates() async =>
      _invoke<void>('resetGestureStates');

  Future<Map<String, dynamic>?> getTimelinePreview({
    required int positionMs,
    required int maxWidth,
    required int maxHeight,
    required int quality,
  }) async {
    final result = await _invoke<Map<dynamic, dynamic>>('getTimelinePreview', {
      'position': positionMs,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'quality': quality,
    });
    if (result == null) return null;
    return result.map((key, value) => MapEntry(key?.toString() ?? '', value));
  }

  Future<Map<String, dynamic>?> getVideoInformation() async {
    final result = await _invoke<Map<dynamic, dynamic>>('getVideoInformation');
    return result?.cast<String, dynamic>();
  }

  Future<void> loadSubtitles(List<String> subtitlePaths) async =>
      _invoke<void>('loadSubtitles', {'subtitlePaths': subtitlePaths});

  Future<void> setSubtitlesEnabled(bool enabled) async =>
      _invoke<void>('setSubtitlesEnabled', {'enabled': enabled});

  Future<void> selectSubtitleTrack(int index) async =>
      _invoke<void>('selectSubtitleTrack', {'index': index});

  Future<List<Map<String, dynamic>>> getSubtitleTracks() async {
    final result = await _invoke<List<dynamic>>('getSubtitleTracks');
    if (result == null) return const [];

    return result
        .map((entry) => _normalizePlatformMap(entry))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getAudioTracks() async {
    final result = await _invoke<List<dynamic>>('getAudioTracks');
    if (result == null) return const [];

    return result
        .map((entry) => _normalizePlatformMap(entry))
        .toList(growable: false);
  }

  Map<String, dynamic> _normalizePlatformMap(dynamic value) {
    if (value is Map<Object?, Object?>) {
      return value.map(
        (key, mapValue) => MapEntry(key?.toString() ?? '', mapValue),
      );
    }

    if (value is Map<dynamic, dynamic>) {
      return value.map(
        (key, mapValue) => MapEntry(key?.toString() ?? '', mapValue),
      );
    }

    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    throw ArgumentError(
      'Unsupported map structure received from platform channel: $value',
    );
  }

  Future<bool> selectAudioTrack(int groupIndex, int trackIndex) async {
    final result = await _invoke<bool>('selectAudioTrack', {
      'groupIndex': groupIndex,
      'trackIndex': trackIndex,
    });
    return result ?? false;
  }

  Future<RobustAudioTrack?> getCurrentAudioTrack() async {
    final result = await _invoke<Map<dynamic, dynamic>>('getCurrentAudioTrack');
    if (result == null) return null;
    return RobustAudioTrack.fromMap(result);
  }

  Future<void> exitPictureInPicture() async =>
      _invoke<void>('exitPictureInPicture');

  Future<bool> isInPictureInPictureMode() async {
    final result = await _invoke<bool>('isInPictureInPictureMode');
    return result ?? false;
  }

  Future<void> setBackgroundPlaybackEnabled(bool enabled) async =>
      _invoke<void>('setBackgroundPlaybackEnabled', {'enabled': enabled});

  Future<bool> isBackgroundPlaybackEnabled() async {
    final result = await _invoke<bool>('isBackgroundPlaybackEnabled');
    return result ?? false;
  }

  Future<void> enableAudioOnlyMode() async =>
      _invoke<void>('enableAudioOnlyMode');

  Future<void> disableAudioOnlyMode() async =>
      _invoke<void>('disableAudioOnlyMode');

  Future<void> onAppBackgrounded() async => _invoke<void>('onAppBackgrounded');

  Future<void> onAppForegrounded() async => _invoke<void>('onAppForegrounded');

  Future<void> setOrientation(String orientation) async =>
      _invoke<void>('setOrientation', {'orientation': orientation});

  Future<String> getCurrentOrientation() async {
    final result = await _invoke<String>('getCurrentOrientation');
    return result ?? 'AUTO';
  }

  Future<void> setAutoRotateEnabled(bool enabled) async =>
      _invoke<void>('setAutoRotateEnabled', {'enabled': enabled});

  Future<bool> isAutoRotateEnabled() async {
    final result = await _invoke<bool>('isAutoRotateEnabled');
    return result ?? true;
  }

  Future<void> setOrientationLocked(bool locked) async =>
      _invoke<void>('setOrientationLocked', {'locked': locked});

  Future<bool> isOrientationLocked() async {
    final result = await _invoke<bool>('isOrientationLocked');
    return result ?? false;
  }

  Future<void> toggleOrientation() async => _invoke<void>('toggleOrientation');

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
        final audioTracks =
            (event['audioTracks'] as List<dynamic>?)
                ?.map(
                  (e) => RobustAudioTrack.fromMap(e as Map<dynamic, dynamic>),
                )
                .toList() ??
            [];
        final subtitleTracks =
            (event['subtitleTracks'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      RobustSubtitleTrack.fromMap(e as Map<dynamic, dynamic>),
                )
                .toList() ??
            [];
        _eventController.add(
          RobustTracksChangedEvent(
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks,
          ),
        );
        break;
      case 'gesture':
        final action = event['action']?.toString();
        final value = event['value']?.toString() ?? '';
        if (action != null) {
          _eventController.add(RobustGestureEvent(action, value));
        }
        break;
      case 'brightnessChanged':
        final brightness = (event['brightness'] as num?)?.toDouble() ?? 0.0;
        _eventController.add(RobustBrightnessChangedEvent(brightness));
        break;
      case 'volumeChanged':
        final volume = (event['volume'] as num?)?.toInt() ?? 0;
        final maxVolume = (event['maxVolume'] as num?)?.toInt() ?? 15;
        _eventController.add(RobustVolumeChangedEvent(volume, maxVolume));
        break;
      case 'seek':
        final position = Duration(
          milliseconds: (event['position'] as num?)?.toInt() ?? 0,
        );
        final duration = Duration(
          milliseconds: (event['duration'] as num?)?.toInt() ?? 0,
        );
        _eventController.add(RobustSeekEvent(position, duration));
        break;
      case 'zoom':
        final scale = (event['scale'] as num?)?.toDouble() ?? 1.0;
        _eventController.add(RobustZoomEvent(scale));
        break;
      case 'subtitleStateChanged':
        final enabled = event['enabled'] as bool? ?? false;
        _eventController.add(RobustSubtitleStateChangedEvent(enabled));
        break;
      case 'subtitleTrackChanged':
        final index = (event['index'] as num?)?.toInt() ?? 0;
        _eventController.add(RobustSubtitleTrackChangedEvent(index));
        break;
      case 'audioTrackChanged':
        final groupIndex = (event['groupIndex'] as num?)?.toInt() ?? 0;
        final trackIndex = (event['trackIndex'] as num?)?.toInt() ?? 0;
        _eventController.add(
          RobustAudioTrackChangedEvent(groupIndex, trackIndex),
        );
        break;
      case 'audioTracksChanged':
        final tracks =
            (event['tracks'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _eventController.add(RobustAudioTracksChangedEvent(tracks));
        break;
      case 'pipModeChanged':
        final isInPiP = event['isInPiP'] as bool? ?? false;
        _eventController.add(RobustPiPModeChangedEvent(isInPiP));
        break;
      case 'backgroundPlaybackChanged':
        final enabled = event['enabled'] as bool? ?? false;
        _eventController.add(RobustBackgroundPlaybackChangedEvent(enabled));
        break;
      case 'audioOnlyModeChanged':
        final enabled = event['enabled'] as bool? ?? false;
        _eventController.add(RobustAudioOnlyModeChangedEvent(enabled));
        break;
      case 'kidsLockChanged':
        final enabled = event['enabled'] as bool? ?? false;
        _eventController.add(RobustKidsLockChangedEvent(enabled));
        break;
      case 'orientationChanged':
        final orientation = event['orientation'] as String? ?? 'AUTO';
        _eventController.add(RobustOrientationChangedEvent(orientation));
        break;
      case 'autoRotateChanged':
        final enabled = event['enabled'] as bool? ?? false;
        _eventController.add(RobustAutoRotateChangedEvent(enabled));
        break;
      case 'orientationLockChanged':
        final locked = event['locked'] as bool? ?? false;
        _eventController.add(RobustOrientationLockChangedEvent(locked));
        break;
      case 'deviceOrientationChanged':
        final orientation = event['orientation'] as String? ?? 'UNKNOWN';
        _eventController.add(RobustDeviceOrientationChangedEvent(orientation));
        break;
      case 'aspectModeChanged':
        final mode = event['mode']?.toString() ?? 'default';
        final ratio = (event['ratio'] as num?)?.toDouble();
        _eventController.add(RobustAspectModeChangedEvent(mode, ratio));
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

class RobustBrightnessChangedEvent extends RobustPlayerEvent {
  const RobustBrightnessChangedEvent(this.brightness);

  final double brightness;
}

class RobustVolumeChangedEvent extends RobustPlayerEvent {
  const RobustVolumeChangedEvent(this.volume, this.maxVolume);

  final int volume;
  final int maxVolume;
}

class RobustSeekEvent extends RobustPlayerEvent {
  const RobustSeekEvent(this.position, this.duration);

  final Duration position;
  final Duration duration;
}

class RobustZoomEvent extends RobustPlayerEvent {
  const RobustZoomEvent(this.scale);

  final double scale;
}

class RobustSubtitleStateChangedEvent extends RobustPlayerEvent {
  const RobustSubtitleStateChangedEvent(this.enabled);

  final bool enabled;
}

class RobustSubtitleTrackChangedEvent extends RobustPlayerEvent {
  const RobustSubtitleTrackChangedEvent(this.index);

  final int index;
}

class RobustAudioTrackChangedEvent extends RobustPlayerEvent {
  const RobustAudioTrackChangedEvent(this.groupIndex, this.trackIndex);

  final int groupIndex;
  final int trackIndex;
}

class RobustAudioTracksChangedEvent extends RobustPlayerEvent {
  const RobustAudioTracksChangedEvent(this.tracks);

  final List<Map<String, dynamic>> tracks;
}

class RobustPiPModeChangedEvent extends RobustPlayerEvent {
  const RobustPiPModeChangedEvent(this.isInPiP);

  final bool isInPiP;
}

class RobustBackgroundPlaybackChangedEvent extends RobustPlayerEvent {
  const RobustBackgroundPlaybackChangedEvent(this.enabled);

  final bool enabled;
}

class RobustAudioOnlyModeChangedEvent extends RobustPlayerEvent {
  const RobustAudioOnlyModeChangedEvent(this.enabled);

  final bool enabled;
}

class RobustKidsLockChangedEvent extends RobustPlayerEvent {
  const RobustKidsLockChangedEvent(this.enabled);

  final bool enabled;
}

class RobustOrientationChangedEvent extends RobustPlayerEvent {
  const RobustOrientationChangedEvent(this.orientation);

  final String orientation;
}

class RobustAutoRotateChangedEvent extends RobustPlayerEvent {
  const RobustAutoRotateChangedEvent(this.enabled);

  final bool enabled;
}

class RobustOrientationLockChangedEvent extends RobustPlayerEvent {
  const RobustOrientationLockChangedEvent(this.locked);

  final bool locked;
}

class RobustDeviceOrientationChangedEvent extends RobustPlayerEvent {
  const RobustDeviceOrientationChangedEvent(this.orientation);

  final String orientation;
}

class RobustAspectModeChangedEvent extends RobustPlayerEvent {
  const RobustAspectModeChangedEvent(this.mode, this.ratio);

  final String mode;
  final double? ratio;
}

class RobustAudioTrack {
  RobustAudioTrack({
    required this.groupIndex,
    required this.trackIndex,
    required this.id,
    required this.languageCode,
    required this.languageDisplay,
    required this.displayName,
    required this.mimeType,
    required this.channelCount,
    required this.channelDescription,
    this.bitrate,
    this.sampleRate,
    this.isSelected = false,
  });

  factory RobustAudioTrack.fromMap(Map<dynamic, dynamic> map) =>
      RobustAudioTrack(
        groupIndex: (map['groupIndex'] as num?)?.toInt() ?? 0,
        trackIndex: (map['trackIndex'] as num?)?.toInt() ?? 0,
        id: map['id']?.toString() ?? '',
        languageCode: map['language']?.toString() ?? 'und',
        languageDisplay: map['languageDisplay']?.toString() ?? 'Unknown',
        displayName: map['displayName']?.toString() ?? 'Track',
        mimeType: map['mimeType']?.toString() ?? '',
        channelCount: (map['channelCount'] as num?)?.toInt() ?? 0,
        channelDescription: map['channelDescription']?.toString() ?? '',
        bitrate: (map['bitrate'] as num?)?.toInt(),
        sampleRate: (map['sampleRate'] as num?)?.toInt(),
        isSelected: map['selected'] as bool? ?? false,
      );

  final int groupIndex;
  final int trackIndex;
  final String id;
  final String languageCode;
  final String languageDisplay;
  final String displayName;
  final String mimeType;
  final int channelCount;
  final String channelDescription;
  final int? bitrate;
  final int? sampleRate;
  final bool isSelected;

  RobustAudioTrack copyWith({bool? isSelected}) {
    return RobustAudioTrack(
      groupIndex: groupIndex,
      trackIndex: trackIndex,
      id: id,
      languageCode: languageCode,
      languageDisplay: languageDisplay,
      displayName: displayName,
      mimeType: mimeType,
      channelCount: channelCount,
      channelDescription: channelDescription,
      bitrate: bitrate,
      sampleRate: sampleRate,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RobustAudioTrack) return false;
    return groupIndex == other.groupIndex &&
        trackIndex == other.trackIndex &&
        id == other.id;
  }

  @override
  int get hashCode => Object.hash(groupIndex, trackIndex, id);
}

class RobustSubtitleTrack {
  RobustSubtitleTrack({
    required this.groupIndex,
    required this.trackIndex,
    required this.language,
    required this.label,
  });

  factory RobustSubtitleTrack.fromMap(Map<dynamic, dynamic> map) =>
      RobustSubtitleTrack(
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
