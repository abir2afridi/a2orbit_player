import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../services/playback_history_service.dart';
import 'native_player_controller.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.videoPath,
    this.autoPlay = true,
    this.onVideoEnd,
  });

  final String videoPath;
  final bool autoPlay;
  final VoidCallback? onVideoEnd;

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget>
    with WidgetsBindingObserver {
  final NativePlayerController _nativeController = NativePlayerController();
  StreamSubscription<NativePlayerEvent>? _eventSubscription;
  ProviderSubscription<AppSettings>? _settingsSubscription;
  late PlaybackHistoryService _historyService;

  bool _isPlayerReady = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  bool _isLocked = false;
  bool _isBuffering = false;
  bool _isAudioOnly = false;

  String? _errorMessage;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _resumePosition;
  Duration _subtitleDelay = Duration.zero;
  Duration _audioDelay = Duration.zero;

  bool _isPlaying = false;

  AppSettings? _settings;

  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final prefs = ref.read(sharedPreferencesProvider);
    _historyService = PlaybackHistoryService(prefs);
    _settings = ref.read(settingsProvider);
    _applySettings(_settings!);
    _loadResumePosition();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _eventSubscription = _nativeController.events.listen(_handleNativeEvent);
    _settingsSubscription = ref.listenManual<AppSettings>(settingsProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      _onSettingsChanged(previous, next);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _eventSubscription?.cancel();
    _settingsSubscription?.close();
    _nativeController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground - restore controls visibility
        if (!mounted) return;
        setState(() {
          _showControls = true;
        });
        _restartHideControlsTimer();
        break;
      case AppLifecycleState.inactive:
        // Temporary state (e.g., incoming call, dialog) - don't trigger PiP
        break;
      case AppLifecycleState.paused:
        // App actually went to background - trigger Auto PiP if enabled
        _handleBackgroundBehavior(isPaused: true);
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
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
    _subtitleDelay = Duration.zero;
    _audioDelay = Duration.zero;
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
    if (_isPlayerReady) {
      _applyNativePreferences();
    }
    if (prev?.sleepTimerMinutes != next.sleepTimerMinutes) {
      _configureSleepTimer(next);
    }
  }

  void _applySettings(AppSettings settings) {
    _settings = settings;
    _isAudioOnly = settings.audioOnly;
    _updateOrientationPreference(settings.autoRotateVideo);
  }

  void _updateOrientationPreference(bool autoRotateVideo) {
    final orientations = autoRotateVideo
        ? DeviceOrientation.values
        : const [DeviceOrientation.portraitUp];
    SystemChrome.setPreferredOrientations(orientations);
  }

  void _handleNativeEvent(NativePlayerEvent event) {
    if (!mounted) return;
    if (event is NativePlaybackStateEvent) {
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
    } else if (event is NativePositionEvent) {
      setState(() {
        _position = event.position;
        _duration = event.duration;
      });
    } else if (event is NativeErrorEvent) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = '${event.code}: ${event.message}';
      });
    }
  }

  Future<void> _onPlatformViewCreated(int viewId) async {
    _nativeController.attach(viewId);
    try {
      final subtitles = await _loadSubtitlePaths();
      await _nativeController.setSource(widget.videoPath, subtitles: subtitles);

      if (_resumePosition != null && _resumePosition! > Duration.zero) {
        await _nativeController.seekTo(_resumePosition!);
      }

      await _applyNativePreferences();

      if (widget.autoPlay) {
        await _nativeController.play();
      }

      if (!mounted) return;
      setState(() {
        _isPlayerReady = true;
        _isLoading = false;
        _hasError = false;
      });

      _startProgressSaveTimer();
      _configureSleepTimer(_settings);
      _restartHideControlsTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }

  Future<void> _applyNativePreferences() async {
    final settings = _settings;
    if (settings == null) return;

    await _nativeController.setPlaybackSpeed(settings.playbackSpeed);
    await _nativeController.setGesturesEnabled(
      settings.enableGestureSeek ||
          settings.enableGestureVolume ||
          settings.enableGestureBrightness,
    );

    await _nativeController.setDecoder(
      settings.enableHardwareAcceleration
          ? DecoderType.hardware
          : DecoderType.software,
    );
  }

  void _handleBackgroundBehavior({required bool isPaused}) {
    final settings = _settings;
    if (settings == null) return;

    if (isPaused) {
      switch (settings.backgroundPlayOption) {
        case BackgroundPlayOption.stop:
          _nativeController.pause();
          break;
        case BackgroundPlayOption.backgroundAudio:
          // allow playback to continue in background
          break;
        case BackgroundPlayOption.pictureInPicture:
          if (settings.autoEnterPip) {
            _nativeController.enterPictureInPicture();
          }
          break;
      }
    } else {
      if (widget.autoPlay && !_isPlaying) {
        _nativeController.play();
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
          await _nativeController.pause();
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
      _nativeController.pause();
    } else {
      _nativeController.play();
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
    _nativeController.seekTo(Duration(milliseconds: clampedMs));
  }

  void _handleDoubleTap(double tapX, double width) {
    final isLeft = tapX < width / 2;
    final settings = _settings;
    if (settings == null) return;
    final jump = Duration(milliseconds: settings.seekDuration);
    _seekRelative(isLeft ? -jump : jump);
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
      await _nativeController.setPlaybackSpeed(result);
      ref
          .read(settingsProvider.notifier)
          .updateSetting('playback_speed', result);
    }
  }

  Future<void> _showDecoderSelector() async {
    final hardware = _settings?.enableHardwareAcceleration ?? true;
    final result = await showModalBottomSheet<DecoderType>(
      context: context,
      builder: (context) => _OptionSheet<DecoderType>(
        title: 'Decoder',
        options: const [DecoderType.hardware, DecoderType.software],
        formatter: (value) =>
            value == DecoderType.hardware ? 'Hardware' : 'Software',
        selected: hardware ? DecoderType.hardware : DecoderType.software,
      ),
    );
    if (result != null) {
      await _nativeController.setDecoder(result);
      ref
          .read(settingsProvider.notifier)
          .updateSetting(
            'hardware_acceleration',
            result == DecoderType.hardware,
          );
    }
  }

  Future<void> _showAspectRatioSelector() async {
    final result = await showModalBottomSheet<AspectRatioMode>(
      context: context,
      builder: (context) => _OptionSheet<AspectRatioMode>(
        title: 'Aspect ratio',
        options: const [
          AspectRatioMode.fit,
          AspectRatioMode.fixedWidth,
          AspectRatioMode.fixedHeight,
          AspectRatioMode.fill,
          AspectRatioMode.zoom,
        ],
        formatter: (mode) {
          switch (mode) {
            case AspectRatioMode.fit:
              return 'Fit';
            case AspectRatioMode.fixedWidth:
              return '16:9';
            case AspectRatioMode.fixedHeight:
              return '4:3';
            case AspectRatioMode.fill:
              return 'Stretch';
            case AspectRatioMode.zoom:
              return 'Zoom';
          }
        },
        selected: AspectRatioMode.fit,
      ),
    );
    if (result != null) {
      await _nativeController.setAspectRatio(result);
    }
  }

  Future<void> _openTracksSheet() async {
    final audioTracks = await _nativeController.getAudioTracks();
    final subtitleTracks = await _nativeController.getSubtitleTracks();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _TracksSheet(
        audioTracks: audioTracks,
        subtitleTracks: subtitleTracks,
        onAudioSelected: (track) {
          _nativeController.switchAudioTrack(
            track.groupIndex,
            track.trackIndex,
          );
        },
        onSubtitleSelected: (track) {
          if (track == null) {
            _nativeController.selectSubtitleTrack(
              groupIndex: null,
              trackIndex: null,
            );
          } else {
            _nativeController.selectSubtitleTrack(
              groupIndex: track.groupIndex,
              trackIndex: track.trackIndex,
            );
          }
        },
      ),
    );
  }

  Future<void> _showVideoInfo() async {
    final info = await _nativeController.getVideoInformation();
    if (!mounted || info == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Codec', value: info.videoCodec ?? 'Unknown'),
            _InfoRow(
              label: 'Resolution',
              value: info.width != null && info.height != null
                  ? '${info.width} x ${info.height}'
                  : 'Unknown',
            ),
            _InfoRow(
              label: 'Frame rate',
              value: info.frameRate?.toStringAsFixed(2) ?? 'Unknown',
            ),
            _InfoRow(label: 'Audio', value: info.audioCodec ?? 'Unknown'),
            _InfoRow(
              label: 'Channels',
              value: info.audioChannels?.toString() ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Sample rate',
              value: info.audioSampleRate != null
                  ? '${info.audioSampleRate} Hz'
                  : 'Unknown',
            ),
            _InfoRow(
              label: 'Duration',
              value: _formatDuration(
                Duration(milliseconds: info.duration ?? 0),
              ),
            ),
            _InfoRow(
              label: 'Size',
              value: info.size != null
                  ? _formatFileSize(info.size!)
                  : 'Unknown',
            ),
            _InfoRow(label: 'Path', value: info.path ?? widget.videoPath),
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

  Future<void> _showSleepTimerDialog() async {
    const durations = [0, 15, 30, 45, 60, 90, 120];
    final current = _settings?.sleepTimerMinutes ?? 0;
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _OptionSheet<int>(
        title: 'Sleep timer',
        options: durations,
        formatter: (minutes) => minutes == 0 ? 'Off' : '$minutes minutes',
        selected: current,
      ),
    );
    if (result != null) {
      ref
          .read(settingsProvider.notifier)
          .updateSetting('sleep_timer_minutes', result);
    }
  }

  void _adjustSubtitleDelay(bool increase) {
    final delta = const Duration(milliseconds: 250);
    setState(() {
      _subtitleDelay += increase ? delta : -delta;
    });
    _nativeController.setSubtitleDelay(_subtitleDelay);
  }

  void _adjustAudioDelay(bool increase) {
    final delta = const Duration(milliseconds: 250);
    setState(() {
      _audioDelay += increase ? delta : -delta;
    });
    _nativeController.setAudioDelay(_audioDelay);
  }

  // ===== GESTURE CONTROL STATE & METHODS =====

  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  Duration? _seekPreviewDelta;
  bool _showGestureOverlay = false;
  String _gestureType = '';

  void _adjustBrightness(double delta) {
    setState(() {
      _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
      _showGestureOverlay = true;
      _gestureType = 'brightness';
    });

    // Apply brightness change via platform channel
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: _currentBrightness > 0.5
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    _restartHideControlsTimer();
  }

  void _adjustVolume(double delta) {
    setState(() {
      _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
      _showGestureOverlay = true;
      _gestureType = 'volume';
    });

    // Volume adjustment feedback (actual volume control would use a plugin)
    _restartHideControlsTimer();
  }

  void _showSeekPreview(Duration delta) {
    setState(() {
      _seekPreviewDelta = delta;
      _showGestureOverlay = true;
      _gestureType = 'seek';
    });
    _restartHideControlsTimer();
  }

  void _applySeekPreview() {
    final delta = _seekPreviewDelta;
    if (delta != null) {
      _seekRelative(delta);
    }
    _hideGestureOverlay();
  }

  void _hideGestureOverlay() {
    setState(() {
      _showGestureOverlay = false;
      _gestureType = '';
      _seekPreviewDelta = null;
    });
  }

  Future<List<String>> _loadSubtitlePaths() async {
    final source = File(widget.videoPath);
    if (!await source.exists()) return [];
    final directory = source.parent;
    final subtitleFiles = directory.listSync().whereType<File>().where((file) {
      final lower = file.path.toLowerCase();
      return lower.endsWith('.srt') ||
          lower.endsWith('.ass') ||
          lower.endsWith('.ssa');
    }).toList()..sort((a, b) => a.path.compareTo(b.path));
    return subtitleFiles.map((file) => file.path).toList();
  }

  Widget _buildBody() {
    final children = <Widget>[
      Positioned.fill(
        child: AndroidView(
          viewType: 'com.a2orbit.player/texture',
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
    ];

    if (_isLoading) {
      children.add(_buildLoadingOverlay());
    }

    if (_hasError) {
      children.add(_buildErrorOverlay());
    } else {
      if (_isAudioOnly) {
        children.add(_buildAudioOnlyOverlay());
      }
      if (_showControls && !_isLocked) {
        children.add(_buildControlsOverlay());
      }
      if (_isBuffering) {
        children.add(_buildBufferingIndicator());
      }
      // Show lock indicator when locked
      if (_isLocked) {
        children.add(_buildLockIndicator());
      }
      // Show gesture feedback overlay
      children.add(_buildGestureOverlay());
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_isLocked) {
          _toggleControls();
        }
      },
      onDoubleTapDown: (details) {
        if (_isLocked) return;
        final width = MediaQuery.of(context).size.width;
        _handleDoubleTap(details.localPosition.dx, width);
      },
      onVerticalDragUpdate: (details) {
        if (_isLocked) return;
        final settings = _settings;
        if (settings == null) return;

        final screenWidth = MediaQuery.of(context).size.width;
        final isLeftSide = details.localPosition.dx < screenWidth / 2;

        // Normalize delta to 0-1 range (negative delta = swipe up = increase)
        final delta = -details.primaryDelta! / 300;

        if (isLeftSide && settings.enableGestureBrightness) {
          _adjustBrightness(delta);
        } else if (!isLeftSide && settings.enableGestureVolume) {
          _adjustVolume(delta);
        }
      },
      onVerticalDragEnd: (_) {
        if (_isLocked) return;
        _hideGestureOverlay();
      },
      onHorizontalDragUpdate: (details) {
        if (_isLocked) return;
        final settings = _settings;
        if (settings == null || !settings.enableGestureSeek) return;

        // Calculate seek delta based on horizontal drag
        final delta = details.primaryDelta! / MediaQuery.of(context).size.width;
        final seekMs = (delta * _duration.inMilliseconds).round();
        _showSeekPreview(Duration(milliseconds: seekMs));
      },
      onHorizontalDragEnd: (details) {
        if (_isLocked) return;
        _applySeekPreview();
      },
      child: Stack(children: children),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: _isLocked,
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
            const Spacer(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _videoTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: _openTracksSheet,
              icon: const Icon(Icons.subtitles, color: Colors.white),
            ),
            IconButton(
              onPressed: _showDecoderSelector,
              icon: const Icon(
                Icons.settings_input_component,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: _enterPictureInPicture,
              icon: const Icon(
                Icons.picture_in_picture_alt,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: _toggleLock,
              icon: Icon(
                _isLocked ? Icons.lock : Icons.lock_open,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    final settings = _settings;
    final seekDuration = settings?.seekDuration ?? 10000;
    final jump = Duration(milliseconds: seekDuration);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundIconButton(
          icon: Icons.replay_10,
          onPressed: () => _seekRelative(-jump),
        ),
        const SizedBox(width: 32),
        _PlayPauseButton(isPlaying: _isPlaying, onPressed: _togglePlayPause),
        const SizedBox(width: 32),
        _RoundIconButton(
          icon: Icons.forward_10,
          onPressed: () => _seekRelative(jump),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                min: 0,
                max: math.max(durationMs, 1),
                value: positionMs,
                onChanged: (value) {
                  _nativeController.seekTo(
                    Duration(milliseconds: value.round()),
                  );
                },
              ),
            ),
            Row(
              children: [
                Text(
                  '$positionLabel / $durationLabel',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _adjustSubtitleDelay(false),
                  icon: const Icon(Icons.subtitles_off, color: Colors.white),
                ),
                Text(
                  '${(_subtitleDelay.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                IconButton(
                  onPressed: () => _adjustSubtitleDelay(true),
                  icon: const Icon(Icons.subtitles, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => _adjustAudioDelay(false),
                  icon: const Icon(Icons.volume_down, color: Colors.white),
                ),
                Text(
                  '${(_audioDelay.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                IconButton(
                  onPressed: () => _adjustAudioDelay(true),
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'speed':
                        _showSpeedSheet();
                        break;
                      case 'ratio':
                        _showAspectRatioSelector();
                        break;
                      case 'info':
                        _showVideoInfo();
                        break;
                      case 'sleep':
                        _showSleepTimerDialog();
                        break;
                      case 'pip':
                        _enterPictureInPicture();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'speed',
                      child: Text('Playback speed'),
                    ),
                    PopupMenuItem(value: 'ratio', child: Text('Aspect ratio')),
                    PopupMenuItem(value: 'info', child: Text('Video info')),
                    PopupMenuItem(value: 'sleep', child: Text('Sleep timer')),
                    PopupMenuItem(
                      value: 'pip',
                      child: Text('Picture-in-Picture'),
                    ),
                  ],
                ),
              ],
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

  void _enterPictureInPicture() {
    _nativeController.enterPictureInPicture();
  }

  String get _videoTitle => File(widget.videoPath).uri.pathSegments.last;

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) return '00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(1)} ${units[index]}';
  }

  Widget _buildLockIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: GestureDetector(
        onTap: _toggleLock,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildGestureOverlay() {
    if (!_showGestureOverlay) return const SizedBox.shrink();

    IconData icon;
    String text;

    switch (_gestureType) {
      case 'brightness':
        icon = Icons.brightness_6;
        text = '${(_currentBrightness * 100).round()}%';
        break;
      case 'volume':
        icon = _currentVolume == 0 ? Icons.volume_off : Icons.volume_up;
        text = '${(_currentVolume * 100).round()}%';
        break;
      case 'seek':
        final delta = _seekPreviewDelta;
        if (delta == null) return const SizedBox.shrink();
        icon = delta.isNegative ? Icons.fast_rewind : Icons.fast_forward;
        final seconds = delta.inSeconds.abs();
        text = '${delta.isNegative ? '-' : '+'}$seconds s';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 36,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
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
    return InkResponse(
      onTap: onPressed,
      radius: 40,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 1.6),
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 42,
          color: Colors.white,
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
  final String Function(T value) formatter;
  final T selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...options.map(
            (option) => RadioListTile<T>(
              value: option,
              groupValue: selected,
              onChanged: (value) => Navigator.of(context).pop(value),
              title: Text(formatter(option)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TracksSheet extends StatelessWidget {
  const _TracksSheet({
    required this.audioTracks,
    required this.subtitleTracks,
    required this.onAudioSelected,
    required this.onSubtitleSelected,
  });

  final List<NativeAudioTrack> audioTracks;
  final List<NativeSubtitleTrack> subtitleTracks;
  final ValueChanged<NativeAudioTrack> onAudioSelected;
  final ValueChanged<NativeSubtitleTrack?> onSubtitleSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio tracks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (audioTracks.isEmpty)
              const Text('No alternate audio tracks found.'),
            ...audioTracks.map(
              (track) => ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(track.label),
                subtitle: Text(track.language),
                onTap: () {
                  onAudioSelected(track);
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Subtitles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('None'),
              onTap: () {
                onSubtitleSelected(null);
                Navigator.of(context).pop();
              },
            ),
            ...subtitleTracks.map(
              (track) => ListTile(
                leading: const Icon(Icons.subtitles),
                title: Text(track.label),
                subtitle: Text(track.language),
                onTap: () {
                  onSubtitleSelected(track);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
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
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
