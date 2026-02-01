import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    _eventSubscription = _robustController.events.listen(_handleRobustEvent);
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
    final children = <Widget>[
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
      if (_isLocked) {
        children.add(_buildLockIndicator());
      }
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
              onPressed: _showAspectRatioSelector,
              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
            ),
            IconButton(
              onPressed: _showVideoInfo,
              icon: const Icon(Icons.info_outline, color: Colors.white),
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
                  _robustController.seekTo(
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
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'speed',
                      child: Text('Playback speed'),
                    ),
                    PopupMenuItem(value: 'ratio', child: Text('Aspect ratio')),
                    PopupMenuItem(value: 'info', child: Text('Video info')),
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
