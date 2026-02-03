import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/app_providers.dart';
import '../services/playback_history_service.dart';
import 'robust_player_controller.dart';

class RobustVideoPlayerWidget extends ConsumerStatefulWidget {
  const RobustVideoPlayerWidget({
    super.key,
    required this.videoPath,
    this.autoPlay = true,
    this.onVideoEnd,
  });

  final String videoPath;
  final bool autoPlay;
  final VoidCallback? onVideoEnd;

  @override
  ConsumerState<RobustVideoPlayerWidget> createState() =>
      _RobustVideoPlayerWidgetState();
}

class _RobustVideoPlayerWidgetState
    extends ConsumerState<RobustVideoPlayerWidget>
    with WidgetsBindingObserver {
  final RobustPlayerController _robustController = RobustPlayerController();
  StreamSubscription<RobustPlayerEvent>? _eventSubscription;
  ProviderSubscription<AppSettings>? _settingsSubscription;
  late PlaybackHistoryService _historyService;
  late SharedPreferences _prefs;

  bool _isPlayerReady = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  bool _isLocked = false;
  bool _isBuffering = false;
  bool _isAudioOnly = false;
  String _currentOrientation = 'AUTO';
  bool _autoRotateEnabled = true;
  bool _orientationLocked = false;
  bool _isControllerAttached = false;
  final GlobalKey _topBarKey = GlobalKey();
  final GlobalKey _bottomBarKey = GlobalKey();
  final GlobalKey _gestureOverlayKey = GlobalKey();

  bool _isSidebarExpanded = false;
  String? _errorMessage;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _resumePosition;

  static const double _defaultPlayerBrightness = 0.5;
  static const double _minPlayerBrightness = 0.05;
  static const String _playerBrightnessKey = 'player_brightness';

  double _playerBrightness = _defaultPlayerBrightness;
  double get _brightnessPercent => _playerBrightness.clamp(0.0, 1.0);
  double _volumePercent = 0.5;
  Duration? _seekPreviewDelta;
  bool _showGestureOverlay = false;
  String? _activeGesture;
  Timer? _gestureOverlayTimer;
  double? _brightnessGestureStart;
  double _brightnessGestureDelta = 0;
  double? _volumeGestureStart;
  double _volumeGestureDelta = 0;

  bool _isPlaying = false;

  AppSettings? _settings;

  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _prefs = ref.read(sharedPreferencesProvider);
    _historyService = PlaybackHistoryService(_prefs);
    _settings = ref.read(settingsProvider);
    _applySettings(_settings!);
    _loadResumePosition();

    final storedBrightness =
        _prefs.getDouble(_playerBrightnessKey) ?? _defaultPlayerBrightness;
    _playerBrightness = math.min(
      1.0,
      math.max(_minPlayerBrightness, storedBrightness),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _eventSubscription = _robustController.events.listen(_handleRobustEvent);
    _settingsSubscription = ref.listenManual<AppSettings>(settingsProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      _onSettingsChanged(previous, next);
    });
  }

  Future<void> _applyPlayerBrightnessToNative() async {
    final applied = await _robustController.setPlayerBrightness(
      _playerBrightness,
    );
    if (!mounted || applied == null) return;
    if ((applied - _playerBrightness).abs() > 0.0001) {
      setState(() {
        _playerBrightness = math.min(
          1.0,
          math.max(_minPlayerBrightness, applied),
        );
      });
    }
  }

  Future<void> _persistPlayerBrightness() async {
    await _prefs.setDouble(
      _playerBrightnessKey,
      math.min(1.0, math.max(_minPlayerBrightness, _playerBrightness)),
    );
  }

  void _handleVerticalGesture(DragUpdateDetails details) {
    if (_isLocked) return;
    final settings = _settings;
    if (settings == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = details.localPosition.dx < screenWidth / 2;
    final deltaPixels = -details.primaryDelta!;

    if (isLeftSide && settings.enableGestureBrightness) {
      _updateBrightness(deltaPixels);
    } else if (!isLeftSide && settings.enableGestureVolume) {
      _updateVolume(deltaPixels);
    }
  }

  void _handleHorizontalGesture(DragUpdateDetails details) {
    if (_isLocked) return;
    final settings = _settings;
    if (settings == null || !settings.enableGestureSeek) return;

    _updateSeek(details.primaryDelta!);
  }

  void _prepareBrightnessGesture() {
    final current = _playerBrightness.clamp(0.0, 1.0);
    _brightnessGestureStart = current;
    _brightnessGestureDelta = 0;
    setState(() {
      _activeGesture = 'brightness';
    });
  }

  void _prepareVolumeGesture() {
    final currentPercent = _volumePercent.clamp(0.0, 1.0);
    _volumeGestureStart = currentPercent;
    _volumeGestureDelta = 0;
    setState(() {
      _activeGesture = 'volume';
    });

    unawaited(() async {
      final info = await _robustController.prepareVolumeGesture();
      if (!mounted || info == null) return;
      final current = (info['current'] as num?)?.toDouble() ?? 0.0;
      final max = (info['max'] as num?)?.toDouble() ?? 0.0;
      final percent = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
      setState(() {
        _volumeGestureStart = percent;
        _volumePercent = percent;
        _volumeGestureDelta = 0;
        _activeGesture = 'volume';
      });
    }());
  }

  void _prepareVerticalGesture(DragStartDetails details) {
    if (_isLocked) return;
    final settings = _settings;
    if (settings == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = details.localPosition.dx < screenWidth / 2;

    if (isLeftSide && settings.enableGestureBrightness) {
      _prepareBrightnessGesture();
    } else if (!isLeftSide && settings.enableGestureVolume) {
      _prepareVolumeGesture();
    }
  }

  void _updateBrightness(double deltaPixels) {
    final height = MediaQuery.of(context).size.height;
    if (height <= 0) return;

    _brightnessGestureDelta += deltaPixels / height;
    final baseline = _brightnessGestureStart ?? _playerBrightness;
    final nextBrightness = (baseline + _brightnessGestureDelta).clamp(
      _minPlayerBrightness,
      1.0,
    );
    setState(() {
      _playerBrightness = nextBrightness;
      _activeGesture = 'brightness';
    });
    unawaited(() async {
      final applied = await _robustController.setPlayerBrightness(
        nextBrightness,
      );
      if (!mounted || applied == null) return;
      if ((applied - _playerBrightness).abs() > 0.0001) {
        setState(() {
          _playerBrightness = applied.clamp(_minPlayerBrightness, 1.0);
        });
      }
    }());
    _showGestureFeedback();
  }

  void _updateVolume(double deltaPixels) {
    final height = MediaQuery.of(context).size.height;
    if (height <= 0) return;

    _volumeGestureDelta += deltaPixels / height;
    final baseline = _volumeGestureStart ?? _volumePercent;
    final next = (baseline + _volumeGestureDelta).clamp(0.0, 1.0);
    setState(() {
      _volumePercent = next;
      _activeGesture = 'volume';
    });
    unawaited(_robustController.applyVolumeLevel(next));
    _showGestureFeedback();
  }

  void _updateSeek(double deltaPixels) {
    if (_duration <= Duration.zero) return;
    final width = MediaQuery.of(context).size.width;
    if (width <= 0) return;

    final fraction = deltaPixels / width;
    final deltaMs = (fraction * _duration.inMilliseconds).round();
    var cumulative =
        (_seekPreviewDelta ?? Duration.zero) + Duration(milliseconds: deltaMs);

    final current = _position;
    final total = _duration;
    final target = current + cumulative;
    if (target < Duration.zero) {
      cumulative = -current;
    } else if (total > Duration.zero && target > total) {
      cumulative = total - current;
    }

    setState(() {
      _activeGesture = 'seek';
      _seekPreviewDelta = cumulative;
    });
    _showGestureFeedback();
  }

  void _showGestureFeedback() {
    _gestureOverlayTimer?.cancel();
    setState(() {
      _showGestureOverlay = true;
    });

    _gestureOverlayTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _showGestureOverlay = false;
        _seekPreviewDelta = null;
        _activeGesture = null;
      });
    });
  }

  void _handleGestureEnd() {
    _gestureOverlayTimer?.cancel();

    final gesture = _activeGesture;
    final shouldSeek = gesture == 'seek';
    final seekDelta = _seekPreviewDelta;

    if (gesture == 'brightness') {
      _persistPlayerBrightness();
      _brightnessGestureStart = null;
      _brightnessGestureDelta = 0;
    } else if (gesture == 'volume') {
      final value = _volumePercent.clamp(0.0, 1.0);
      unawaited(_robustController.finalizeVolumeGesture(value));
      _volumeGestureStart = null;
      _volumeGestureDelta = 0;
    }

    unawaited(_robustController.resetGestureStates());

    if (shouldSeek && seekDelta != null && seekDelta != Duration.zero) {
      _seekRelative(seekDelta);
    }

    _gestureOverlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _showGestureOverlay = false;
        _seekPreviewDelta = null;
        _activeGesture = null;
      });
    });
  }

  Future<void> _toggleOrientation() async {
    await _robustController.toggleOrientation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _gestureOverlayTimer?.cancel();
    _eventSubscription?.cancel();
    _settingsSubscription?.close();
    _robustController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (!mounted) return;
        setState(() {
          _showControls = true;
        });
        _restartHideControlsTimer();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _handleBackgroundBehavior(isPaused: true);
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void didUpdateWidget(covariant RobustVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _resetStateForNewSource();
    }
  }

  Future<void> _loadResumePosition() async {
    final resume = await _historyService.getPosition(widget.videoPath);
    if (!mounted) return;
    setState(() {
      _resumePosition = resume;
    });
  }

  void _resetStateForNewSource() {
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _resumePosition = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlayerReady = false;
    _isPlaying = false;
    _hasError = false;
    _errorMessage = null;
    _isBuffering = false;
    _loadResumePosition();
  }

  void _onSettingsChanged(AppSettings? previous, AppSettings next) {
    final prev = previous ?? _settings;
    _applySettings(next);
    if (prev?.sleepTimerMinutes != next.sleepTimerMinutes) {
      _configureSleepTimer(next);
    }
  }

  void _applySettings(AppSettings settings) {
    _settings = settings;
    _isAudioOnly = settings.audioOnly;
    _updateOrientationPreference(settings.autoRotate);
  }

  Future<void> _refreshOrientationState() async {
    final results = await Future.wait([
      _robustController.getCurrentOrientation(),
      _robustController.isAutoRotateEnabled(),
      _robustController.isOrientationLocked(),
    ]);

    if (!mounted) return;
    setState(() {
      _currentOrientation = results[0] as String? ?? 'AUTO';
      _autoRotateEnabled = results[1] as bool? ?? true;
      _orientationLocked = results[2] as bool? ?? false;
    });
  }

  void _updateOrientationPreference(bool autoRotate) {
    final orientations = autoRotate
        ? DeviceOrientation.values
        : const [DeviceOrientation.portraitUp];
    SystemChrome.setPreferredOrientations(orientations);
  }

  void _handleRobustEvent(RobustPlayerEvent event) {
    if (!mounted) return;

    if (event is RobustPlaybackStateEvent) {
      final shouldShowControls = !event.isPlaying || event.isEnded;
      setState(() {
        _isPlaying = event.isPlaying && !event.isEnded;
        _isBuffering = event.isBuffering;
        if (shouldShowControls) {
          _showControls = true;
        }
        if (event.isEnded) {
          _historyService.clearPosition(widget.videoPath);
          widget.onVideoEnd?.call();
        }
      });
      if (_isPlaying && !_isLocked && _showControls) {
        _restartHideControlsTimer();
      } else if (shouldShowControls) {
        _hideControlsTimer?.cancel();
      }
      return;
    } else if (event is RobustPositionEvent) {
      setState(() {
        _position = event.position;
        _duration = event.duration;
      });
    } else if (event is RobustOrientationChangedEvent) {
      setState(() {
        _currentOrientation = event.orientation;
      });
    } else if (event is RobustGestureEvent) {
      if (event.action == 'single_tap') {
        _toggleControls();
      } else if (event.action == 'gesture_end') {
        if (_showControls && !_isLocked) {
          _restartHideControlsTimer();
        }
        _handleGestureEnd();
      }
    } else if (event is RobustBrightnessChangedEvent) {
      final brightness = event.brightness.clamp(_minPlayerBrightness, 1.0);
      setState(() {
        _playerBrightness = brightness;
      });
      if (_activeGesture == 'brightness') {
        _showGestureFeedback();
      }
    } else if (event is RobustVolumeChangedEvent) {
      final percent = event.maxVolume > 0
          ? (event.volume / event.maxVolume).clamp(0.0, 1.0)
          : 0.0;
      setState(() {
        _volumePercent = percent;
      });
      if (_activeGesture == 'volume') {
        _showGestureFeedback();
      }
    } else if (event is RobustAutoRotateChangedEvent) {
      setState(() {
        _autoRotateEnabled = event.enabled;
      });
    } else if (event is RobustOrientationLockChangedEvent) {
      setState(() {
        _orientationLocked = event.locked;
      });
    } else if (event is RobustDeviceOrientationChangedEvent) {
      setState(() {
        _currentOrientation = event.orientation;
      });
    } else if (event is RobustErrorEvent) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = '${event.code}: ${event.message}';
      });
    }
  }

  Future<void> _onPlatformViewCreated(int viewId) async {
    _robustController.attach(viewId);
    _isControllerAttached = true;
    try {
      await _robustController.setSource(widget.videoPath);

      if (_resumePosition != null && _resumePosition! > Duration.zero) {
        await _robustController.seekTo(_resumePosition!);
      }

      if (widget.autoPlay) {
        await _robustController.play();
      }

      if (!mounted) return;
      setState(() {
        _isPlayerReady = true;
        _isLoading = false;
        _hasError = false;
      });

      await _applyPlayerBrightnessToNative();
      _startProgressSaveTimer();
      _configureSleepTimer(_settings);
      _restartHideControlsTimer();
      await _refreshOrientationState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }

  void _handleBackgroundBehavior({required bool isPaused}) {
    final settings = _settings;
    if (settings == null) return;

    if (isPaused) {
      switch (settings.backgroundPlayOption) {
        case BackgroundPlayOption.stop:
          _robustController.pause();
          break;
        case BackgroundPlayOption.backgroundAudio:
          break;
        case BackgroundPlayOption.pictureInPicture:
          if (settings.autoEnterPip) {
            _robustController.enterPictureInPicture();
          }
          break;
      }
    } else {
      if (widget.autoPlay && !_isPlaying) {
        _robustController.play();
      }
    }
  }

  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isPlayerReady || !_isPlaying) return;
      await _historyService.savePosition(widget.videoPath, _position);
    });
  }

  void _configureSleepTimer(AppSettings? settings) {
    final targetSettings = settings ?? _settings;
    if (targetSettings == null) return;
    _sleepTimer?.cancel();
    if (targetSettings.sleepTimerMinutes > 0) {
      _sleepTimer = Timer(
        Duration(minutes: targetSettings.sleepTimerMinutes),
        () async {
          await _robustController.pause();
          if (!mounted) return;
          setState(() {
            _isPlaying = false;
            _showControls = true;
          });
        },
      );
    }
  }

  void _restartHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_showControls || _isLocked) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showControls = false;
      });
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _restartHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  bool _tapHitsControls(Offset globalPosition) {
    if (!_showControls) return false;
    final contexts = <BuildContext?>[
      _topBarKey.currentContext,
      _bottomBarKey.currentContext,
      _gestureOverlayKey.currentContext,
    ];

    for (final context in contexts) {
      if (context == null) continue;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        continue;
      }
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      if (rect.contains(globalPosition)) {
        return true;
      }
    }
    return false;
  }

  void _handlePlayerTapUp(TapUpDetails details) {
    if (_isLocked) return;
    final globalPosition = details.globalPosition;

    if (_tapHitsControls(globalPosition)) {
      _restartHideControlsTimer();
      return;
    }

    _toggleControls();
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _showControls = false;
      } else {
        _showControls = true;
        _restartHideControlsTimer();
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _robustController.pause();
    } else {
      _robustController.play();
    }
    _restartHideControlsTimer();
  }

  void _seekRelative(Duration delta) {
    final target = _position + delta;
    final totalMs = _duration > Duration.zero
        ? _duration.inMilliseconds
        : math.max(
            math.max(_position.inMilliseconds, target.inMilliseconds),
            0,
          );
    var clampedMs = target.inMilliseconds;
    if (clampedMs < 0) {
      clampedMs = 0;
    } else if (totalMs > 0 && clampedMs > totalMs) {
      clampedMs = totalMs;
    }
    _robustController.seekTo(Duration(milliseconds: clampedMs));
  }

  void _handleDoubleTap(double tapX, double width) {
    final isLeft = tapX < width / 2;
    final settings = _settings;
    if (settings == null) return;
    final jump = Duration(milliseconds: settings.seekDuration);
    _seekRelative(isLeft ? -jump : jump);
  }

  Duration _clampPosition(Duration value) {
    if (value < Duration.zero) {
      return Duration.zero;
    }
    if (_duration > Duration.zero && value > _duration) {
      return _duration;
    }
    return value;
  }

  Future<void> _showSpeedSheet() async {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5];
    final current = _settings?.playbackSpeed ?? 1.0;
    final result = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => _OptionSheet<double>(
        title: 'Playback speed',
        options: speeds,
        formatter: (value) => '${value.toStringAsFixed(2)}x',
        selected: current,
      ),
    );
    if (result != null) {
      await _robustController.setPlaybackSpeed(result);
      ref
          .read(settingsProvider.notifier)
          .updateSetting('playback_speed', result);
    }
  }

  Future<void> _showAspectRatioSelector() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _OptionSheet<int>(
        title: 'Aspect ratio',
        options: const [0, 1, 2, 3, 4],
        formatter: (mode) {
          switch (mode) {
            case 0:
              return 'Fit';
            case 1:
              return 'Fill';
            case 2:
              return 'Zoom';
            case 3:
              return '16:9';
            case 4:
              return '4:3';
            default:
              return 'Unknown';
          }
        },
        selected: 0,
      ),
    );
    if (result != null) {
      await _robustController.setAspectRatio(result);
    }
  }

  Future<void> _showVideoInfo() async {
    final info = await _robustController.getVideoInformation();
    if (!mounted || info == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              label: 'Codec',
              value: info['videoCodec']?.toString() ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Resolution',
              value: info['width'] != null && info['height'] != null
                  ? '${info['width']} x ${info['height']}'
                  : 'Unknown',
            ),
            _InfoRow(
              label: 'Frame rate',
              value: info['frameRate']?.toStringAsFixed(2) ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Audio',
              value: info['audioCodec']?.toString() ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Channels',
              value: info['audioChannels']?.toString() ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Sample rate',
              value: info['audioSampleRate'] != null
                  ? '${info['audioSampleRate']} Hz'
                  : 'Unknown',
            ),
            _InfoRow(
              label: 'Duration',
              value: _formatDuration(
                Duration(milliseconds: info['duration'] ?? 0),
              ),
            ),
            _InfoRow(
              label: 'Path',
              value: info['path']?.toString() ?? widget.videoPath,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String get _videoTitle {
    return widget.videoPath.split('/').last;
  }

  Widget _buildBody() {
    final overlayChildren = <Widget>[];

    if (_isLoading) {
      overlayChildren.add(_buildLoadingOverlay());
    }

    if (_hasError) {
      overlayChildren.add(_buildErrorOverlay());
    } else {
      if (_isAudioOnly) {
        overlayChildren.add(_buildAudioOnlyOverlay());
      }
      if (_showControls && !_isLocked) {
        overlayChildren.add(_buildControlsOverlay());
      }
      if (_isBuffering) {
        overlayChildren.add(_buildBufferingIndicator());
      }
      if (_isLocked) {
        overlayChildren.add(_buildLockIndicator());
      }
      overlayChildren.add(_buildGestureOverlay());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AndroidView(
            viewType: 'com.a2orbit.player/robust_texture',
            onPlatformViewCreated: _onPlatformViewCreated,
            creationParams: {
              'source': widget.videoPath,
              'subtitles': const <String>[],
              'startPosition': _resumePosition?.inMilliseconds ?? 0,
              'autoPlay': widget.autoPlay,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handlePlayerTapUp,
            onDoubleTapDown: (details) {
              if (_isLocked) return;
              final width = MediaQuery.of(context).size.width;
              _handleDoubleTap(details.localPosition.dx, width);
            },
            onVerticalDragStart: (details) {
              if (_isLocked) return;
              _gestureOverlayTimer?.cancel();
              _prepareVerticalGesture(details);
            },
            onVerticalDragUpdate: _handleVerticalGesture,
            onVerticalDragEnd: (details) {
              if (_isLocked) return;
              _handleGestureEnd();
            },
            onHorizontalDragStart: (details) {
              if (_isLocked) return;
              _gestureOverlayTimer?.cancel();
              _seekPreviewDelta = Duration.zero;
            },
            onHorizontalDragUpdate: _handleHorizontalGesture,
            onHorizontalDragEnd: (_) {
              if (_isLocked) return;
              _handleGestureEnd();
            },
            child: AbsorbPointer(
              absorbing: _isLocked,
              child: Stack(children: overlayChildren),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGestureOverlay() {
    if (!_showGestureOverlay) {
      return const SizedBox.shrink();
    }

    final gesture = _activeGesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    IconData icon;
    String label;
    String? secondary;

    switch (gesture) {
      case 'brightness':
        final percent = (_brightnessPercent * 100).clamp(0, 100).round();
        icon = Icons.brightness_6_outlined;
        label = '$percent%';
        break;
      case 'volume':
        final percent = (_volumePercent * 100).clamp(0, 100).round();
        icon = percent <= 0
            ? Icons.volume_off
            : percent < 50
            ? Icons.volume_down
            : Icons.volume_up;
        label = '$percent%';
        break;
      case 'seek':
        final delta = _seekPreviewDelta ?? Duration.zero;
        final seconds = delta.inMilliseconds.abs() / 1000;
        final formattedSeconds = seconds >= 10
            ? seconds.toStringAsFixed(0)
            : seconds.toStringAsFixed(1);
        icon = delta.isNegative ? Icons.fast_rewind : Icons.fast_forward;
        label = '${delta.isNegative ? '-' : '+'}$formattedSeconds s';

        final target = _clampPosition(_position + delta);
        secondary = _formatDuration(target);
        break;
      default:
        return const SizedBox.shrink();
    }

    final secondaryText = secondary;

    final overlayContent = <Widget>[
      Icon(icon, color: Colors.white, size: 40),
      const SizedBox(height: 10),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];

    if (secondaryText != null) {
      overlayContent.addAll([
        const SizedBox(height: 4),
        Text(
          secondaryText,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ]);
    }

    return Positioned.fill(
      key: _gestureOverlayKey,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: overlayContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Top Bar
          Align(
            alignment: Alignment.topCenter,
            child: KeyedSubtree(key: _topBarKey, child: _buildTopBar()),
          ),

          // Sidebar
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildSideBar(),
            ),
          ),

          // Bottom Section (Slider + Controls)
          Align(
            alignment: Alignment.bottomCenter,
            child: KeyedSubtree(key: _bottomBarKey, child: _buildBottomBar()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _videoTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.music_note, color: Colors.white),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'HW+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBar() {
    final speed = _settings?.playbackSpeed ?? 1.0;

    if (_isSidebarExpanded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SideBarButton(
            icon: Icons.headphones,
            isSelected: _isAudioOnly,
            onTap: () {
              setState(() {
                _isAudioOnly = !_isAudioOnly;
              });
              _restartHideControlsTimer();
            },
          ),
          const SizedBox(height: 12),
          _SideBarButton(
            icon: Icons.repeat_one,
            isSelected: true, // Example state
            onTap: () {
              _restartHideControlsTimer();
            },
          ),
          const SizedBox(height: 12),
          _SideBarButton(
            icon: Icons.picture_in_picture_alt,
            onTap: () {
              _robustController.enterPictureInPicture();
              _restartHideControlsTimer();
            },
          ),
          const SizedBox(height: 12),
          _SideBarButton(
            icon: Icons.chevron_left,
            onTap: () {
              setState(() {
                _isSidebarExpanded = false;
              });
              _restartHideControlsTimer();
            },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SideBarButton(
          child: Text(
            '${speed.toStringAsFixed(0)}X',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          onTap: _showSpeedSheet,
        ),
        const SizedBox(height: 12),
        _SideBarButton(
          icon: Icons.camera_alt_outlined,
          showBadge: true,
          onTap: () {
            _restartHideControlsTimer();
          },
        ),
        const SizedBox(height: 12),
        _SideBarButton(
          icon: Icons.screen_rotation,
          onTap: () async {
            await _toggleOrientation();
            await _refreshOrientationState();
            _restartHideControlsTimer();
          },
        ),
        const SizedBox(height: 12),
        _SideBarButton(
          icon: Icons.chevron_right,
          onTap: () {
            setState(() {
              _isSidebarExpanded = true;
            });
            _restartHideControlsTimer();
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final positionLabel = _formatDuration(_position);
    final durationLabel = _formatDuration(_duration);
    final durationMs = _duration.inMilliseconds.toDouble();
    final maxValue = math.max(durationMs, 1.0);
    final positionMs = _position.inMilliseconds.toDouble().clamp(0.0, maxValue);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slider Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    positionLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.blue.shade300,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        min: 0,
                        max: maxValue,
                        value: positionMs,
                        onChanged: (value) {
                          _robustController.seekTo(
                            Duration(milliseconds: value.round()),
                          );
                        },
                      ),
                    ),
                  ),
                  Text(
                    durationLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Controls Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleLock,
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_outline,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.skip_previous,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.skip_next,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showAspectRatioSelector,
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => _robustController.enterPictureInPicture(),
                    icon: const Icon(
                      Icons.picture_in_picture_alt,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return const Positioned.fill(
      child: IgnorePointer(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _buildAudioOnlyOverlay() {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.headphones, color: Colors.white, size: 72),
              SizedBox(height: 16),
              Text(
                'Audio-only mode',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Playback error',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _resetStateForNewSource(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIndicator() {
    return const Positioned.fill(
      child: Center(child: Icon(Icons.lock, color: Colors.white70, size: 48)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }
}

class _SideBarButton extends StatelessWidget {
  const _SideBarButton({
    this.icon,
    this.child,
    this.onTap,
    this.isSelected = false,
    this.showBadge = false,
  });

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: child ?? Icon(icon, color: Colors.white, size: 24),
          ),
          if (showBadge)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.formatter,
    required this.selected,
  });

  final String title;
  final List<T> options;
  final String Function(T) formatter;
  final T selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...options.map(
            (option) => ListTile(
              title: Text(formatter(option)),
              trailing: option == selected
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final seconds = totalSeconds % 60;
  final minutes = (totalSeconds / 60).floor() % 60;
  final hours = (totalSeconds / 3600).floor();

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } else {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
