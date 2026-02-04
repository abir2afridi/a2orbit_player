import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../../../core/providers/app_providers.dart';
import '../services/playback_history_service.dart';
import '../services/player_preference_service.dart';
import 'robust_player_controller.dart';
import '../services/timeline_preview_service.dart';

enum PlayerOrientationMode { portrait, landscape }

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

class _AspectMenuSheet extends StatefulWidget {
  const _AspectMenuSheet({
    required this.controller,
    required this.activeMode,
    required this.activeRatio,
    required this.applyToAll,
    required this.onCycleNext,
    required this.onResetDefault,
    required this.onToggleApplyAll,
    required this.onApplyMode,
  });

  final DraggableScrollableController controller;
  final String activeMode;
  final double? activeRatio;
  final bool applyToAll;
  final VoidCallback onCycleNext;
  final VoidCallback onResetDefault;
  final ValueChanged<bool> onToggleApplyAll;
  final void Function(
    String mode,
    double? ratio,
    bool persistSelection,
    bool applyGlobally,
  )
  onApplyMode;

  @override
  State<_AspectMenuSheet> createState() => _AspectMenuSheetState();
}

class _AspectMenuSheetState extends State<_AspectMenuSheet> {
  late bool _persistSelection;
  late bool _applyToAll;

  @override
  void initState() {
    super.initState();
    _persistSelection = true;
    _applyToAll = widget.applyToAll;
  }

  bool _isOptionSelected(_AspectOption option) {
    if (option.mode == 'cycle') return false;
    if (option.mode == 'ratio') {
      if (widget.activeMode != 'ratio') {
        return option.isCustom && widget.activeRatio != null;
      }
      if (option.isCustom) {
        return widget.activeRatio != null;
      }
      if (option.ratio == null || widget.activeRatio == null) return false;
      return (option.ratio! - widget.activeRatio!).abs() <=
          _aspectRatioTolerance;
    }
    return widget.activeMode == option.mode;
  }

  Future<double?> _promptCustomRatio() async {
    final textController = TextEditingController(
      text: widget.activeMode == 'ratio' && widget.activeRatio != null
          ? widget.activeRatio!.toStringAsFixed(2)
          : '1.78',
    );

    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Custom aspect ratio'),
          content: TextField(
            controller: textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Enter ratio (e.g. 1.78)',
            ),
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(textController.text.trim());
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid ratio greater than 0'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleOptionTap(_AspectOption option) async {
    if (option.mode == 'cycle') {
      widget.onCycleNext();
      Navigator.of(context).pop();
      return;
    }

    double? ratio = option.ratio;
    String mode = option.mode;

    if (option.isCustom) {
      ratio = await _promptCustomRatio();
      if (ratio == null) return;
      mode = 'ratio';
    }

    widget.onApplyMode(mode, ratio, _persistSelection, _applyToAll);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: widget.controller,
      expand: false,
      minChildSize: 0.35,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF101012),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aspect Ratio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.activeMode == 'ratio' && widget.activeRatio != null
                          ? 'Current: ${widget.activeRatio!.toStringAsFixed(2)} : 1'
                          : 'Current: ${_aspectLabelText(widget.activeMode, widget.activeRatio)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _persistSelection,
                onChanged: (value) {
                  setState(() => _persistSelection = value);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: const Text('Remember this choice'),
                subtitle: const Text(
                  'Save and reapply automatically next time',
                ),
                activeColor: Colors.blueAccent,
              ),
              SwitchListTile.adaptive(
                value: _applyToAll,
                onChanged: (value) {
                  setState(() => _applyToAll = value);
                  widget.onToggleApplyAll(value);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: const Text('Apply to all videos'),
                subtitle: const Text('Overrides individual video settings'),
                activeColor: Colors.blueAccent,
              ),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.white70),
                title: const Text('Reset to default'),
                subtitle: const Text('Use the app default aspect setting'),
                onTap: () {
                  widget.onResetDefault();
                  Navigator.of(context).pop();
                },
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _aspectMenuOptions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final option = _aspectMenuOptions[index];
                    final selected = _isOptionSelected(option);
                    return ListTile(
                      leading: Icon(
                        option.mode == 'cycle'
                            ? Icons.shuffle
                            : option.mode == 'ratio'
                            ? Icons.aspect_ratio
                            : Icons.crop_free,
                        color: Colors.white70,
                      ),
                      title: Text(
                        option.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.blueAccent,
                            )
                          : null,
                      onTap: () => _handleOptionTap(option),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AspectOption {
  const _AspectOption({
    required this.key,
    required this.mode,
    required this.label,
    this.ratio,
    this.isCustom = false,
  });

  final String key;
  final String mode;
  final String label;
  final double? ratio;
  final bool isCustom;
}

const Map<String, String> _aspectDisplayNames = {
  'fit': 'Fit to Screen',
  'original': 'Original Size',
  'stretch': 'Stretch to Fill',
  'crop': 'Crop to Fill',
  'ratio': 'Custom Ratio',
  'default': 'Default',
};

const double _aspectRatioTolerance = 0.02;

const List<_AspectOption> _aspectMenuOptions = [
  _AspectOption(key: 'cycle', mode: 'cycle', label: 'Cycle Next'),
  _AspectOption(key: 'fit', mode: 'fit', label: 'Fit to Screen'),
  _AspectOption(key: 'original', mode: 'original', label: 'Original Size'),
  _AspectOption(key: 'stretch', mode: 'stretch', label: 'Stretch (Fill)'),
  _AspectOption(key: 'crop', mode: 'crop', label: 'Crop (Zoom)'),
  _AspectOption(
    key: 'ratio_1_1',
    mode: 'ratio',
    ratio: 1.0,
    label: '1:1 Square',
  ),
  _AspectOption(
    key: 'ratio_4_3',
    mode: 'ratio',
    ratio: 4.0 / 3.0,
    label: '4:3 Classic',
  ),
  _AspectOption(
    key: 'ratio_16_9',
    mode: 'ratio',
    ratio: 16.0 / 9.0,
    label: '16:9 Widescreen',
  ),
  _AspectOption(
    key: 'ratio_custom',
    mode: 'ratio',
    label: 'Custom…',
    isCustom: true,
  ),
];

class _AspectCycleEntry {
  const _AspectCycleEntry(this.mode, this.ratio);

  final String mode;
  final double? ratio;
}

String _aspectLabelText(String mode, [double? ratio]) {
  if (mode == 'ratio' && ratio != null) {
    return '${ratio.toStringAsFixed(2)} : 1';
  }
  return _aspectDisplayNames[mode] ?? mode.toUpperCase();
}

extension BorderRadiusClampExt on BorderRadius {
  BorderRadius clampBorderRadius() {
    final topLeftX = math.max(0.0, topLeft.x);
    final topLeftY = math.max(0.0, topLeft.y);
    final topRightX = math.max(0.0, topRight.x);
    final topRightY = math.max(0.0, topRight.y);
    final bottomLeftX = math.max(0.0, bottomLeft.x);
    final bottomLeftY = math.max(0.0, bottomLeft.y);
    final bottomRightX = math.max(0.0, bottomRight.x);
    final bottomRightY = math.max(0.0, bottomRight.y);

    return BorderRadius.only(
      topLeft: Radius.elliptical(topLeftX, topLeftY),
      topRight: Radius.elliptical(topRightX, topRightY),
      bottomLeft: Radius.elliptical(bottomLeftX, bottomLeftY),
      bottomRight: Radius.elliptical(bottomRightX, bottomRightY),
    );
  }
}

class _RobustVideoPlayerWidgetState
    extends ConsumerState<RobustVideoPlayerWidget>
    with WidgetsBindingObserver {
  final RobustPlayerController _robustController = RobustPlayerController();
  StreamSubscription<RobustPlayerEvent>? _eventSubscription;
  ProviderSubscription<AppSettings>? _settingsSubscription;
  late PlaybackHistoryService _historyService;
  late SharedPreferences _prefs;
  late PlayerPreferenceService _preferenceService;

  bool _isPlayerReady = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLocked = false;
  bool _isBuffering = false;
  bool _isAudioOnly = false;
  String _currentOrientation = 'LANDSCAPE';
  PlayerOrientationMode _playerOrientationMode =
      PlayerOrientationMode.landscape;
  bool _isControllerAttached = false;
  bool _showControls = true;
  final GlobalKey _topBarKey = GlobalKey();
  final GlobalKey _bottomBarKey = GlobalKey();
  final GlobalKey _gestureOverlayKey = GlobalKey();
  final GlobalKey _controlsOverlayKey = GlobalKey();
  final GlobalKey _sliderGlobalKey = GlobalKey();

  bool _isSidebarExpanded = false;
  String? _errorMessage;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _resumePosition;

  static const double _defaultPlayerBrightness = 0.5;
  static const double _minPlayerBrightness = 0.05;

  bool _hasRestoredAudio = false;
  bool _hasRestoredAspect = false;
  String _activeAspectMode = 'default';
  double? _activeAspectRatio;
  bool _applyAspectToAll = false;
  bool _audioPreferenceReady = false;
  bool _aspectPreferenceReady = false;
  bool _isApplyingAspectMode = false;
  String? _pendingAspectMode;
  double? _pendingAspectRatio;
  bool? _pendingAspectApplyAll;
  bool _pendingAspectShouldPersist = false;
  bool _restoringAspectPreference = false;
  bool _inflightAspectShouldPersist = false;
  bool? _inflightApplyAll;
  int _currentAspectCycleIndex = 0;

  String? _aspectPopupText;
  Timer? _aspectPopupTimer;

  static const String _defaultAspectMode = 'fit';

  static const List<_AspectCycleEntry> _aspectCycleOrder = [
    _AspectCycleEntry('original', null),
    _AspectCycleEntry('fit', null),
    _AspectCycleEntry('stretch', null),
    _AspectCycleEntry('crop', null),
    _AspectCycleEntry('ratio', 1.0),
    _AspectCycleEntry('ratio', 4.0 / 3.0),
    _AspectCycleEntry('ratio', 16.0 / 9.0),
    _AspectCycleEntry('ratio', null),
  ];

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

  bool _isUserScrubbing = false;
  double? _scrubPreviewPositionMs;
  bool _wasPlayingBeforeScrub = false;

  bool _timelinePreviewEnabled = true;
  bool _timelinePreviewRounded = true;
  bool _timelinePreviewShowTimestamp = true;
  bool _timelinePreviewSmoothAnimation = true;
  bool _timelineFastScrubOptimization = true;

  bool _showTimelinePreviewBubble = false;
  bool _timelinePreviewHasFrame = false;
  bool _timelinePreviewLoading = false;
  Uint8List? _timelinePreviewBytes;
  Duration _timelinePreviewPosition = Duration.zero;
  double _timelinePreviewPercent = 0.0;
  Timer? _timelinePreviewDebounceTimer;
  double? _pendingTimelinePreviewValueMs;
  int _timelinePreviewRequestToken = 0;

  AppSettings? _settings;

  List<RobustAudioTrack> _audioTracks = const [];
  RobustAudioTrack? _selectedAudioTrack;

  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Timer? _sleepTimer;

  DraggableScrollableController? _aspectSheetController;
  bool _aspectMenuVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _prefs = ref.read(sharedPreferencesProvider);
    _historyService = PlaybackHistoryService(_prefs);
    _preferenceService = PlayerPreferenceService(_prefs);
    _applyAspectToAll = _preferenceService.getApplyAspectGlobally();
    _playerOrientationMode = _parseOrientationMode(
      _preferenceService.getOrientationMode(),
    );
    _currentOrientation =
        _playerOrientationMode == PlayerOrientationMode.landscape
        ? 'LANDSCAPE'
        : 'PORTRAIT';
    _currentAspectCycleIndex = _findAspectCycleIndex(
      _activeAspectMode,
      _activeAspectRatio,
    );
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

  void _handleLiteCycleAspect() {
    if (_aspectMenuVisible) return;
    final nextIndex = (_currentAspectCycleIndex + 1) % _aspectCycleOrder.length;
    final entry = _aspectCycleOrder[nextIndex];
    final targetRatio = entry.mode == 'ratio'
        ? (entry.ratio ?? _activeAspectRatio ?? 1.78)
        : null;
    _currentAspectCycleIndex = nextIndex;
    _applyAspectMode(entry.mode, ratio: targetRatio, persistSelection: true);
  }

  void _cycleAspectFromIcon() {
    if (_aspectMenuVisible) return;
    _handleLiteCycleAspect();
  }

  PlayerOrientationMode _parseOrientationMode(String? value) {
    switch (value?.toUpperCase()) {
      case 'PORTRAIT':
        return PlayerOrientationMode.portrait;
      case 'LANDSCAPE':
      default:
        return PlayerOrientationMode.landscape;
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
    _audioTracks = const [];
    _selectedAudioTrack = null;
    _timelinePreviewDebounceTimer?.cancel();
    _timelinePreviewDebounceTimer = null;
    _pendingTimelinePreviewValueMs = null;
    _timelinePreviewRequestToken++;
    _timelinePreviewBytes = null;
    _timelinePreviewHasFrame = false;
    _timelinePreviewLoading = false;
    _timelinePreviewPercent = 0.0;
    _timelinePreviewPosition = Duration.zero;
    _showTimelinePreviewBubble = false;
    _loadResumePosition();
    _hasRestoredAudio = false;
    _hasRestoredAspect = false;
    _aspectPreferenceReady = false;
    _isApplyingAspectMode = false;
    _restoringAspectPreference = false;
    _activeAspectMode = _defaultAspectMode;
    _activeAspectRatio = null;
    _pendingAspectMode = null;
    _pendingAspectRatio = null;
    _pendingAspectApplyAll = null;
    _pendingAspectShouldPersist = false;
    _inflightAspectShouldPersist = false;
    _inflightApplyAll = null;
    _currentAspectCycleIndex = _findAspectCycleIndex(
      _activeAspectMode,
      _activeAspectRatio,
    );
    _applyAspectToAll = _preferenceService.getApplyAspectGlobally();
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

    final shouldDisableTimelinePreview =
        !settings.enableTimelinePreviewThumbnail;

    setState(() {
      _timelinePreviewEnabled = settings.enableTimelinePreviewThumbnail;
      _timelinePreviewRounded = settings.timelineRoundedThumbnail;
      _timelinePreviewShowTimestamp = settings.timelineShowTimestamp;
      _timelinePreviewSmoothAnimation = settings.timelineSmoothAnimation;
      _timelineFastScrubOptimization = settings.timelineFastScrubOptimization;
    });

    if (shouldDisableTimelinePreview) {
      _hideTimelinePreview(immediate: true);
    }
  }

  int _findAspectCycleIndex(String mode, double? ratio) {
    final normalizedMode = mode == 'default' ? 'original' : mode;
    for (var i = 0; i < _aspectCycleOrder.length; i++) {
      final entry = _aspectCycleOrder[i];
      if (entry.mode != normalizedMode) continue;
      if (normalizedMode == 'ratio') {
        if (entry.ratio == null) {
          if (ratio == null) return i;
          continue;
        }
        if (ratio != null &&
            (entry.ratio! - ratio).abs() <= _aspectRatioTolerance) {
          return i;
        }
      } else {
        return i;
      }
    }
    return 0;
  }

  Future<void> _initializeAspectPreference() async {
    if (_restoringAspectPreference) return;
    _restoringAspectPreference = true;
    _aspectPreferenceReady = false;

    final globalState = _preferenceService.readGlobalAspectState();
    _applyAspectToAll = globalState.applyToAll;

    AspectPreference? preference;
    if (_applyAspectToAll && globalState.preference != null) {
      preference = globalState.preference;
    } else {
      preference = _preferenceService.getAspectPreference(widget.videoPath);
    }

    if (preference == null) {
      _restoringAspectPreference = false;
      _aspectPreferenceReady = true;
      _applyDefaultAspectIfNeeded();
      return;
    }

    _pendingAspectMode = preference.mode;
    _pendingAspectRatio = preference.customRatio;
    _pendingAspectApplyAll = _applyAspectToAll;
    _pendingAspectShouldPersist = false;
    await _applyAspectMode(
      preference.mode,
      ratio: preference.customRatio,
      persistSelection: false,
      applyGlobally: _applyAspectToAll,
    );

    _restoringAspectPreference = false;
    _aspectPreferenceReady = true;
    _pendingAspectMode = null;
    _pendingAspectRatio = null;
    _pendingAspectApplyAll = null;
    _pendingAspectShouldPersist = false;
  }

  void _applyDefaultAspectIfNeeded() {
    if (_activeAspectMode != _defaultAspectMode || _activeAspectRatio != null) {
      return;
    }
    unawaited(_applyAspectMode(_defaultAspectMode, persistSelection: false));
  }

  String _aspectLabel(String mode, [double? ratio]) {
    return _aspectLabelText(mode, ratio);
  }

  void _showAspectFeedback(String mode, double? ratio) {
    if (!mounted) return;
    final label = _aspectLabel(mode, ratio);
    _showAspectPopup('Aspect Ratio: $label');
  }

  Future<void> _applyAspectMode(
    String mode, {
    double? ratio,
    bool persistSelection = true,
    bool? applyGlobally,
  }) async {
    if (_isApplyingAspectMode) {
      _pendingAspectMode = mode;
      _pendingAspectRatio = ratio;
      _pendingAspectApplyAll = applyGlobally;
      _pendingAspectShouldPersist = persistSelection;
      return;
    }

    _isApplyingAspectMode = true;
    _inflightAspectShouldPersist = persistSelection;
    _inflightApplyAll = applyGlobally;

    try {
      await _robustController.applyAspectMode(mode, ratio: ratio);
    } catch (error, stackTrace) {
      debugPrint('Failed to apply aspect mode $mode: $error\n$stackTrace');
      _isApplyingAspectMode = false;
      _inflightAspectShouldPersist = false;
      _inflightApplyAll = null;
    }
  }

  void _handleAspectModeChanged(String mode, double? ratio) {
    final normalizedMode = mode.isEmpty ? _defaultAspectMode : mode;
    final normalizedRatio = ratio != null && ratio > 0 ? ratio : null;

    final shouldPersist = _inflightAspectShouldPersist;
    final bool applyGlobally = _inflightApplyAll ?? _applyAspectToAll;

    _inflightAspectShouldPersist = false;
    _inflightApplyAll = null;
    _isApplyingAspectMode = false;

    setState(() {
      _activeAspectMode = normalizedMode;
      _activeAspectRatio = normalizedRatio;
      _applyAspectToAll = applyGlobally;
      _hasRestoredAspect = true;
      _aspectPreferenceReady = true;
      _currentAspectCycleIndex = _findAspectCycleIndex(
        normalizedMode,
        normalizedRatio,
      );
    });

    if (shouldPersist) {
      _persistAspectPreference(normalizedMode, normalizedRatio, applyGlobally);
    }

    _showAspectFeedback(normalizedMode, normalizedRatio);

    if (_pendingAspectMode != null) {
      final pendingMode = _pendingAspectMode!;
      final pendingRatio = _pendingAspectRatio;
      final pendingApplyAll = _pendingAspectApplyAll;
      final pendingPersist = _pendingAspectShouldPersist;
      _pendingAspectMode = null;
      _pendingAspectRatio = null;
      _pendingAspectApplyAll = null;
      _pendingAspectShouldPersist = false;
      unawaited(
        _applyAspectMode(
          pendingMode,
          ratio: pendingRatio,
          persistSelection: pendingPersist,
          applyGlobally: pendingApplyAll,
        ),
      );
    }
  }

  void _persistAspectPreference(
    String mode,
    double? ratio,
    bool applyGlobally,
  ) {
    if (!_aspectPreferenceReady) return;
    _applyAspectToAll = applyGlobally;
    unawaited(_preferenceService.setApplyAspectGlobally(applyGlobally));

    final preference = AspectPreference(mode: mode, customRatio: ratio);

    if (applyGlobally) {
      unawaited(_preferenceService.setGlobalAspectPreference(preference));
    } else {
      unawaited(
        _preferenceService.saveAspectPreference(widget.videoPath, preference),
      );
    }
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
    if (_isLocked || _isUserScrubbing) return;
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
    if (_isLocked || _isUserScrubbing) return;
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
    if (_isLocked || _isUserScrubbing) return;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _gestureOverlayTimer?.cancel();
    _timelinePreviewDebounceTimer?.cancel();
    _aspectPopupTimer?.cancel();
    _eventSubscription?.cancel();
    _settingsSubscription?.close();
    _isControllerAttached = false;
    _robustController.dispose();
    super.dispose();
  }

  Future<void> _applyPlayerOrientationMode({String? mode}) async {
    final resolvedMode = mode != null
        ? _parseOrientationMode(mode)
        : _playerOrientationMode;
    final targetString = resolvedMode == PlayerOrientationMode.landscape
        ? 'LANDSCAPE'
        : 'PORTRAIT';

    if (!_isControllerAttached) return;

    try {
      await _robustController.setAutoRotateEnabled(false);
      await _robustController.setOrientation(targetString);
      await _robustController.setOrientationLocked(true);
      await SystemChrome.setPreferredOrientations(
        resolvedMode == PlayerOrientationMode.landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      );
      if (!mounted) return;
      setState(() {
        _playerOrientationMode = resolvedMode;
        _currentOrientation = targetString;
      });
      unawaited(_preferenceService.saveOrientationMode(targetString));
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to apply orientation $targetString: $error\n$stackTrace',
      );
    }
  }

  void _toggleOrientationMode() {
    final next = _playerOrientationMode == PlayerOrientationMode.landscape
        ? PlayerOrientationMode.portrait
        : PlayerOrientationMode.landscape;
    _applyPlayerOrientationMode(
      mode: next == PlayerOrientationMode.landscape ? 'LANDSCAPE' : 'PORTRAIT',
    );
  }

  @override
  void didUpdateWidget(covariant RobustVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _resetStateForNewSource();
    }
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

  void _showAspectPopup(String message) {
    _aspectPopupTimer?.cancel();
    setState(() {
      _aspectPopupText = message;
    });
    _aspectPopupTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _aspectPopupText = null;
      });
    });
  }

  Widget _buildAspectPopup() {
    final text = _aspectPopupText;
    if (text == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSliderChangeStart(double value, double maxValue) {
    if (_isUserScrubbing) return;

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final clampedValue = value.clamp(0.0, maxValue).toDouble();
    final percent = (clampedValue / safeMax).clamp(0.0, 1.0);
    final targetPosition = Duration(milliseconds: clampedValue.round());
    final wasPlaying = _isPlaying;

    _hideControlsTimer?.cancel();
    _showGestureOverlay = false;
    _activeGesture = null;

    if (_timelinePreviewEnabled) {
      _timelinePreviewRequestToken++;
    }

    setState(() {
      _isUserScrubbing = true;
      _scrubPreviewPositionMs = clampedValue;
      _wasPlayingBeforeScrub = wasPlaying;

      if (_timelinePreviewEnabled) {
        _pendingTimelinePreviewValueMs = clampedValue;
        _timelinePreviewPercent = percent;
        _timelinePreviewPosition = targetPosition;
        _timelinePreviewBytes = null;
        _timelinePreviewHasFrame = false;
        _timelinePreviewLoading = true;
        _showTimelinePreviewBubble = true;
      }
    });

    if (wasPlaying) {
      unawaited(_robustController.pause());
    }

    if (_timelinePreviewEnabled) {
      _scheduleTimelinePreviewFetch(immediate: true);
    }
  }

  void _handleSliderChanged(double value, double maxValue) {
    if (!_isUserScrubbing) return;

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final clampedValue = value.clamp(0.0, maxValue).toDouble();
    final percent = (clampedValue / safeMax).clamp(0.0, 1.0);
    final targetPosition = Duration(milliseconds: clampedValue.round());

    setState(() {
      _scrubPreviewPositionMs = clampedValue;

      if (_timelinePreviewEnabled) {
        _pendingTimelinePreviewValueMs = clampedValue;
        _timelinePreviewPercent = percent;
        _timelinePreviewPosition = targetPosition;
        _showTimelinePreviewBubble = true;
      }
    });

    if (_timelinePreviewEnabled) {
      _scheduleTimelinePreviewFetch();
    }
  }

  void _handleSliderChangeEnd(double value, double maxValue) {
    if (!_isUserScrubbing) return;

    final clampedValue = value.clamp(0.0, maxValue).toDouble();
    final target = Duration(milliseconds: clampedValue.round());
    final resumePlayback = _wasPlayingBeforeScrub;

    setState(() {
      _isUserScrubbing = false;
      _position = target;
      _scrubPreviewPositionMs = null;
      _wasPlayingBeforeScrub = false;
    });

    _pendingTimelinePreviewValueMs = null;

    if (_timelinePreviewEnabled) {
      _hideTimelinePreview();
    }

    unawaited(() async {
      await _robustController.seekTo(target);
      if (resumePlayback) {
        await _robustController.play();
      }
    }());

    _restartHideControlsTimer();
  }

  void _scheduleTimelinePreviewFetch({bool immediate = false}) {
    if (!_timelinePreviewEnabled) return;

    final pendingMs = _pendingTimelinePreviewValueMs;
    if (pendingMs == null) return;

    _timelinePreviewDebounceTimer?.cancel();

    if (immediate) {
      _performTimelinePreviewFetch(Duration(milliseconds: pendingMs.round()));
      return;
    }

    final delay = _timelineFastScrubOptimization
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 90);

    _timelinePreviewDebounceTimer = Timer(delay, () {
      _timelinePreviewDebounceTimer = null;
      if (!mounted || !_timelinePreviewEnabled) return;
      final latest = _pendingTimelinePreviewValueMs;
      if (latest == null) return;
      _performTimelinePreviewFetch(Duration(milliseconds: latest.round()));
    });
  }

  void _performTimelinePreviewFetch(Duration target) {
    if (!_timelinePreviewEnabled || widget.videoPath.isEmpty) return;
    if (!_showTimelinePreviewBubble) return;

    final requestId = ++_timelinePreviewRequestToken;

    setState(() {
      _timelinePreviewLoading = true;
    });

    final service = TimelinePreviewService.instance;

    unawaited(() async {
      final result = await service.getPreview(
        videoSource: widget.videoPath,
        position: target,
        precisionMs: _timelineFastScrubOptimization ? 150 : 90,
        maxWidth: 240,
        maxHeight: 135,
        quality: 70,
        fetcher:
            ({
              required int targetPositionMs,
              required int maxWidth,
              required int maxHeight,
              required int quality,
            }) async {
              final response = await _robustController.getTimelinePreview(
                positionMs: targetPositionMs,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                quality: quality,
              );

              if (response == null) {
                return null;
              }

              final success = response['success'] == true;
              if (!success) {
                final error = response['error'];
                if (kDebugMode) {
                  debugPrint(
                    '[TimelinePreview] Fetch failed: position=$targetPositionMs error=$error',
                  );
                }
                return null;
              }

              final bytes = response['bytes'];
              if (bytes is Uint8List) {
                return bytes;
              }

              if (bytes is List<int>) {
                return Uint8List.fromList(bytes);
              }

              return null;
            },
      );

      if (!mounted || requestId != _timelinePreviewRequestToken) {
        return;
      }

      final hasFrame = result.isSuccess && result.bytes != null;

      setState(() {
        _timelinePreviewLoading = false;
        _timelinePreviewHasFrame = hasFrame;
        _timelinePreviewBytes = hasFrame ? result.bytes : null;
        _timelinePreviewPosition = result.position;
      });
    }());
  }

  void _hideTimelinePreview({bool immediate = false}) {
    _timelinePreviewDebounceTimer?.cancel();
    _timelinePreviewDebounceTimer = null;
    _pendingTimelinePreviewValueMs = null;
    _timelinePreviewRequestToken++;

    void resetState() {
      _showTimelinePreviewBubble = false;
      _timelinePreviewLoading = false;
      _timelinePreviewHasFrame = false;
      _timelinePreviewBytes = null;
      _timelinePreviewPercent = 0.0;
      _timelinePreviewPosition = Duration.zero;
    }

    if (!mounted) {
      resetState();
      return;
    }

    if (immediate || !_timelinePreviewSmoothAnimation) {
      setState(resetState);
      return;
    }

    setState(() {
      _showTimelinePreviewBubble = false;
    });

    final captureToken = _timelinePreviewRequestToken;
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_timelinePreviewRequestToken != captureToken) return;
      if (_showTimelinePreviewBubble) return;
      setState(() {
        _timelinePreviewLoading = false;
        _timelinePreviewHasFrame = false;
        _timelinePreviewBytes = null;
        _timelinePreviewPercent = 0.0;
        _timelinePreviewPosition = Duration.zero;
      });
    });
  }

  double _timelinePreviewBubbleBaseHeight(bool hasFrame) {
    final thumbnailHeight = hasFrame ? 118.0 : 66.0;
    final timestampHeight = _timelinePreviewShowTimestamp ? 30.0 : 0.0;
    return thumbnailHeight + timestampHeight + 22.0;
  }

  Widget _buildTimelinePreviewOverlay() {
    final hasFrame = _timelinePreviewHasFrame && _timelinePreviewBytes != null;
    final baseWidth = hasFrame ? 208.0 : 152.0;
    final baseHeight = _timelinePreviewBubbleBaseHeight(hasFrame);
    final controlsContext = _controlsOverlayKey.currentContext;
    final sliderContext = _sliderGlobalKey.currentContext;

    Widget buildAnimatedBubble(double width, double height) {
      return IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _showTimelinePreviewBubble ? 1.0 : 0.0,
          duration: _timelinePreviewSmoothAnimation
              ? const Duration(milliseconds: 140)
              : Duration.zero,
          curve: Curves.easeOut,
          child: _buildTimelinePreviewBubbleContent(
            hasFrame: hasFrame,
            bubbleWidth: width,
            bubbleHeight: height,
          ),
        ),
      );
    }

    if (controlsContext == null || sliderContext == null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 82),
          child: SizedBox(
            width: baseWidth,
            child: buildAnimatedBubble(baseWidth, baseHeight),
          ),
        ),
      );
    }

    final controlsBox = controlsContext.findRenderObject() as RenderBox?;
    final sliderBox = sliderContext.findRenderObject() as RenderBox?;

    if (controlsBox == null ||
        sliderBox == null ||
        !controlsBox.hasSize ||
        !sliderBox.hasSize) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 82),
          child: SizedBox(
            width: baseWidth,
            child: buildAnimatedBubble(baseWidth, baseHeight),
          ),
        ),
      );
    }

    final controlsOrigin = controlsBox.localToGlobal(Offset.zero);
    final sliderOrigin = sliderBox.localToGlobal(Offset.zero);
    final sliderOffset = sliderOrigin - controlsOrigin;
    final sliderWidth = sliderBox.size.width;
    final percent = _timelinePreviewPercent.clamp(0.0, 1.0);

    final maxBubbleWidth = controlsBox.size.width - 16;
    final maxBubbleHeight = controlsBox.size.height - 16;
    final spaceAboveSlider = sliderOffset.dy - 14.0;

    double bubbleWidth = baseWidth;
    if (maxBubbleWidth > 0) {
      bubbleWidth = math.min(bubbleWidth, maxBubbleWidth);
    }
    if (bubbleWidth <= 0) {
      bubbleWidth = math.min(baseWidth, controlsBox.size.width);
    }
    if (bubbleWidth < 80.0) {
      bubbleWidth = maxBubbleWidth > 0
          ? math.max(48.0, math.min(maxBubbleWidth, baseWidth))
          : 80.0;
    }

    double bubbleHeight = baseHeight;
    if (maxBubbleHeight > 0) {
      bubbleHeight = math.min(bubbleHeight, maxBubbleHeight);
    }
    if (spaceAboveSlider > 0) {
      bubbleHeight = math.min(bubbleHeight, spaceAboveSlider);
    }
    if (bubbleHeight <= 0) {
      bubbleHeight = math.min(
        baseHeight,
        maxBubbleHeight > 0 ? maxBubbleHeight : baseHeight,
      );
    }

    bubbleHeight = math.max(40.0, bubbleHeight);

    var left = sliderOffset.dx + sliderWidth * percent - bubbleWidth / 2;
    final maxLeft = math.max(0.0, controlsBox.size.width - bubbleWidth - 8);
    left = left.clamp(8.0, maxLeft);

    final topLimit = controlsBox.size.height - bubbleHeight - 8;
    var top = sliderOffset.dy - bubbleHeight - 14.0;
    top = top.clamp(8.0, math.max(8.0, topLimit));

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: bubbleWidth,
        child: buildAnimatedBubble(bubbleWidth, bubbleHeight),
      ),
    );
  }

  Widget _buildTimelinePreviewBubbleContent({
    required bool hasFrame,
    required double bubbleWidth,
    required double bubbleHeight,
  }) {
    final borderRadiusValue = _timelinePreviewRounded ? 16.0 : 6.0;
    final borderRadius = BorderRadius.circular(borderRadiusValue);
    final timestampLabel = _formatDuration(_timelinePreviewPosition);
    final boxShadows = _timelinePreviewRounded
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ];

    final verticalPadding = 20.0;
    final timestampVerticalPadding = _timelinePreviewShowTimestamp ? 6.0 : 0.0;
    final timestampChrome = _timelinePreviewShowTimestamp
        ? (timestampVerticalPadding * 2) + 16.0
        : 0.0;
    final timestampMargin = _timelinePreviewShowTimestamp ? 8.0 : 0.0;
    final availableForMedia = math.max(
      0.0,
      bubbleHeight - verticalPadding - timestampChrome - timestampMargin,
    );
    final baseThumbnailHeight = hasFrame ? 118.0 : 66.0;
    final thumbnailHeight = math.min(baseThumbnailHeight, availableForMedia);
    final innerWidth = math.max(0.0, bubbleWidth - 20.0);

    Widget mediaChild;
    if (hasFrame && thumbnailHeight > 0) {
      mediaChild = SizedBox(
        height: thumbnailHeight,
        width: innerWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            borderRadiusValue - 4,
          ).clampBorderRadius(),
          child: Image.memory(
            _timelinePreviewBytes!,
            gaplessPlayback: true,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      mediaChild = Container(
        height: math.max(0.0, thumbnailHeight),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            borderRadiusValue - 4,
          ).clampBorderRadius(),
          color: Colors.white.withOpacity(0.08),
        ),
        child: _timelinePreviewLoading
            ? const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.movie_outlined, color: Colors.white70, size: 24),
                  SizedBox(height: 6),
                  Text(
                    'Preview unavailable',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      );
    }

    final timestampWidget = _timelinePreviewShowTimestamp
        ? Container(
            margin: EdgeInsets.only(top: math.max(4.0, timestampMargin)),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: timestampVerticalPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(borderRadiusValue),
            ),
            child: Text(
              timestampLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          )
        : const SizedBox.shrink();

    final bubble = Container(
      width: bubbleWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.82),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: boxShadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mediaChild,
          if (_timelinePreviewShowTimestamp) timestampWidget,
        ],
      ),
    );

    return bubble;
  }

  Future<void> _refreshAudioTracks() async {
    final maps = await _robustController.getAudioTracks();
    if (!mounted) return;
    final tracks = maps
        .map((map) => RobustAudioTrack.fromMap(map))
        .toList(growable: false);
    _setAudioTracks(tracks);
  }

  void _setAudioTracks(List<RobustAudioTrack> tracks) {
    RobustAudioTrack? selected;
    if (tracks.isNotEmpty) {
      selected = tracks.firstWhere(
        (track) => track.isSelected,
        orElse: () => tracks.first,
      );
    }
    setState(() {
      _audioTracks = tracks;
      _selectedAudioTrack = selected;
    });
    if (tracks.isEmpty) {
      _audioPreferenceReady = true;
      _hasRestoredAudio = true;
      _persistAudioPreference(null);
      return;
    }
    unawaited(_maybeRestoreAudioPreference(tracks));
  }

  void _markSelectedAudioTrack(int groupIndex, int trackIndex) {
    if (_audioTracks.isEmpty) return;
    final updated = _audioTracks
        .map(
          (track) => track.copyWith(
            isSelected:
                track.groupIndex == groupIndex &&
                track.trackIndex == trackIndex,
          ),
        )
        .toList(growable: false);
    RobustAudioTrack? selected;
    if (updated.isNotEmpty) {
      selected = updated.firstWhere(
        (track) => track.isSelected,
        orElse: () => updated.first,
      );
    }
    setState(() {
      _audioTracks = updated;
      _selectedAudioTrack = selected;
    });
    _audioPreferenceReady = true;
    _hasRestoredAudio = true;
    _persistAudioPreference(selected);
  }

  Future<void> _maybeRestoreAudioPreference(
    List<RobustAudioTrack> tracks,
  ) async {
    if (_hasRestoredAudio) return;
    _audioPreferenceReady = true;
    final stored = _preferenceService.getAudioTrack(widget.videoPath);
    if (stored == null) {
      _hasRestoredAudio = true;
      return;
    }
    RobustAudioTrack? match;
    try {
      match = tracks.firstWhere(
        (track) =>
            track.groupIndex == stored.groupIndex &&
            track.trackIndex == stored.trackIndex,
      );
    } catch (_) {
      match = null;
    }
    if (match == null) {
      _hasRestoredAudio = true;
      return;
    }
    if (match.isSelected) {
      _hasRestoredAudio = true;
      _persistAudioPreference(match);
      return;
    }
    final success = await _robustController.selectAudioTrack(
      match.groupIndex,
      match.trackIndex,
    );
    if (!success) {
      _hasRestoredAudio = true;
    }
  }

  void _persistAudioPreference(RobustAudioTrack? track) {
    if (!_audioPreferenceReady) return;
    if (track == null) {
      unawaited(_preferenceService.clearAudioTrack(widget.videoPath));
      return;
    }
    final selection = AudioTrackSelection(
      groupIndex: track.groupIndex,
      trackIndex: track.trackIndex,
    );
    unawaited(_preferenceService.saveAudioTrack(widget.videoPath, selection));
  }

  Future<void> _refreshOrientationState() async {
    if (!mounted) return;
    final targetString =
        _playerOrientationMode == PlayerOrientationMode.landscape
        ? 'LANDSCAPE'
        : 'PORTRAIT';
    setState(() {
      _currentOrientation = targetString;
    });
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
      if (_isUserScrubbing) {
        setState(() {
          _duration = event.duration;
        });
      } else {
        setState(() {
          _position = event.position;
          _duration = event.duration;
        });
      }
    } else if (event is RobustOrientationChangedEvent) {
      // Ignore device orientation reports; rely on player-owned mode
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
    } else if (event is RobustAudioTracksChangedEvent) {
      final tracks = event.tracks
          .map(RobustAudioTrack.fromMap)
          .toList(growable: false);
      _setAudioTracks(tracks);
    } else if (event is RobustAudioTrackChangedEvent) {
      _markSelectedAudioTrack(event.groupIndex, event.trackIndex);
    } else if (event is RobustAspectModeChangedEvent) {
      _handleAspectModeChanged(event.mode, event.ratio);
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

      unawaited(_initializeAspectPreference());
      await _applyPlayerOrientationMode();

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
      unawaited(_refreshAudioTracks());
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
    _aspectSheetController ??= DraggableScrollableController();
    setState(() {
      _aspectMenuVisible = true;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) {
        return _AspectMenuSheet(
          controller: _aspectSheetController!,
          activeMode: _activeAspectMode,
          activeRatio: _activeAspectRatio,
          applyToAll: _applyAspectToAll,
          onCycleNext: _handleLiteCycleAspect,
          onResetDefault: () => _applyAspectMode(
            _defaultAspectMode,
            persistSelection: true,
            applyGlobally: _applyAspectToAll,
          ),
          onToggleApplyAll: (value) {
            setState(() {
              _applyAspectToAll = value;
            });
            unawaited(_preferenceService.setApplyAspectGlobally(value));
          },
          onApplyMode: (mode, ratio, persistSelection, applyGlobally) {
            _applyAspectMode(
              mode,
              ratio: ratio,
              persistSelection: persistSelection,
              applyGlobally: applyGlobally,
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _aspectMenuVisible = false;
        });
      } else {
        _aspectMenuVisible = false;
      }
    });
  }

  Future<void> _showAudioTrackSheet() async {
    final tracks = _audioTracks;
    if (tracks.length <= 1) {
      return;
    }
    final selected = _selectedAudioTrack;
    final result = await showModalBottomSheet<RobustAudioTrack>(
      context: context,
      builder: (context) =>
          _AudioTrackSheet(tracks: tracks, selected: selected),
    );

    if (result != null) {
      final success = await _robustController.selectAudioTrack(
        result.groupIndex,
        result.trackIndex,
      );
      if (success) {
        _markSelectedAudioTrack(result.groupIndex, result.trackIndex);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio switched to ${result.languageDisplay}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio track not supported'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
      overlayChildren.add(_buildAspectPopup());
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
        key: _controlsOverlayKey,
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
          if (_showTimelinePreviewBubble && _timelinePreviewEnabled)
            _buildTimelinePreviewOverlay(),
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
              onPressed: _audioTracks.length > 1 ? _showAudioTrackSheet : null,
              icon: const Icon(Icons.music_note, color: Colors.white),
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
              onPressed: _showMoreOptions,
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
          isSelected: _playerOrientationMode == PlayerOrientationMode.landscape,
          onTap: () async {
            _toggleOrientationMode();
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
    final durationMs = _duration.inMilliseconds.toDouble();
    final maxValue = math.max(durationMs, 1.0);
    final effectivePositionMs = _isUserScrubbing
        ? (_scrubPreviewPositionMs ?? _position.inMilliseconds.toDouble())
        : _position.inMilliseconds.toDouble();
    final clampedPositionMs = effectivePositionMs.clamp(0.0, maxValue);

    final positionLabel = _formatDuration(
      Duration(milliseconds: clampedPositionMs.round()),
    );
    final durationLabel = _formatDuration(_duration);

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
                        key: _sliderGlobalKey,
                        min: 0,
                        max: maxValue,
                        value: clampedPositionMs,
                        onChangeStart: (value) =>
                            _handleSliderChangeStart(value, maxValue),
                        onChanged: (value) =>
                            _handleSliderChanged(value, maxValue),
                        onChangeEnd: (value) =>
                            _handleSliderChangeEnd(value, maxValue),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  final iconPadding = EdgeInsets.all(isCompact ? 4 : 8);
                  final iconConstraints = BoxConstraints(
                    minHeight: isCompact ? 40 : 48,
                    minWidth: isCompact ? 40 : 48,
                  );
                  final middleSpacing = isCompact ? 8.0 : 20.0;

                  final primaryIconSize = isCompact ? 28.0 : 32.0;
                  final playIconSize = isCompact ? 34.0 : 40.0;

                  IconButton buildIconButton({
                    required VoidCallback onPressed,
                    required Icon icon,
                    String? tooltip,
                    double? iconSize,
                  }) {
                    return IconButton(
                      onPressed: onPressed,
                      padding: iconPadding,
                      constraints: iconConstraints,
                      tooltip: tooltip,
                      iconSize: iconSize ?? primaryIconSize,
                      icon: icon,
                    );
                  }

                  return Row(
                    children: [
                      buildIconButton(
                        onPressed: _toggleLock,
                        icon: Icon(
                          _isLocked ? Icons.lock : Icons.lock_outline,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      buildIconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                        ),
                        iconSize: primaryIconSize + (isCompact ? 0 : 2),
                      ),
                      SizedBox(width: middleSpacing),
                      buildIconButton(
                        onPressed: _togglePlayPause,
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        iconSize: playIconSize,
                      ),
                      SizedBox(width: middleSpacing),
                      buildIconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        iconSize: primaryIconSize + (isCompact ? 0 : 2),
                      ),
                      const Spacer(),
                      buildIconButton(
                        onPressed: _handleLiteCycleAspect,
                        icon: const Icon(
                          Icons.aspect_ratio,
                          color: Colors.white,
                        ),
                        tooltip: 'Cycle aspect ratio',
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    _hideControlsTimer?.cancel();

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      // Show as right sidebar in landscape
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'More Options',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 380, // Fixed width for sidebar
                height: double.infinity,
                child: _MoreOptionsSheet(
                  onOptionSelected: (option) {
                    Navigator.pop(context);
                    _handleMoreOptionSelection(option);
                  },
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ).then((_) => _restartHideControlsTimer());
    } else {
      // Show as bottom sheet in portrait
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _MoreOptionsSheet(
          onOptionSelected: (option) {
            Navigator.pop(context);
            _handleMoreOptionSelection(option);
          },
        ),
      ).then((_) => _restartHideControlsTimer());
    }
  }

  void _handleMoreOptionSelection(String option) {
    switch (option) {
      case 'aspect_ratio':
        _showAspectRatioSelector();
        break;
      case 'speed':
        _showSpeedSheet();
        break;
      case 'info':
        _showVideoInfo();
        break;
      case 'orientation':
        _toggleOrientationMode();
        break;
      case 'pip':
        _robustController.enterPictureInPicture();
        break;
      case 'share':
        // Implement share functionality
        break;
      // Add other cases as needed
    }
    _restartHideControlsTimer();
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
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(formatter(option)),
                  trailing: option == selected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioTrackSheet extends StatelessWidget {
  const _AudioTrackSheet({required this.tracks, this.selected});

  final List<RobustAudioTrack> tracks;
  final RobustAudioTrack? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Audio track',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return RadioListTile<RobustAudioTrack>(
                  value: track,
                  groupValue: selected,
                  onChanged: (_) => Navigator.of(context).pop(track),
                  title: Text(track.displayName),
                  subtitle: Text(track.languageDisplay),
                  secondary: track.channelDescription.isNotEmpty
                      ? Text(track.channelDescription)
                      : null,
                );
              },
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

class _MoreOptionsSheet extends StatefulWidget {
  const _MoreOptionsSheet({required this.onOptionSelected});

  final ValueChanged<String> onOptionSelected;

  @override
  State<_MoreOptionsSheet> createState() => _MoreOptionsSheetState();
}

class _MoreOptionsSheetState extends State<_MoreOptionsSheet> {
  // 'main' for the grid, 'more_list' for the textual list (Delete, Rename, etc.)
  String _currentView = 'main';

  // Mock state for the UI demo
  bool _videoDisplay = true;
  bool _shortcuts = true;

  final Map<String, bool> _shortcutStates = {
    'Screen Rotation': true,
    'Playback Speed': true,
    'Background Play': true,
    'Loop': true,
    'Mute': true,
    'Shuffle': true,
    'Equalizer': true,
    'Sleep Timer': true,
    'A - B Repeat': true,
    'Night Mode': true,
    'Customise Items': true,
    'Screenshot': true,
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              );
            },
            child: _currentView == 'main'
                ? _buildMainGrid()
                : _buildMoreListView(),
          ),
        ),
      ),
    );
  }

  Widget _buildMainGrid() {
    return SingleChildScrollView(
      key: const ValueKey('main'),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 24,
            crossAxisSpacing: 16,
            childAspectRatio: 0.70,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildOptionItem(
                Icons.aspect_ratio,
                'Aspect Ratio',
                'aspect_ratio',
              ),
              _buildOptionItem(
                Icons.fast_forward,
                'Speed FF\n(Long Press)',
                'speed',
                badge: '2.0X',
              ),
              _buildOptionItem(
                Icons.display_settings,
                'Display\nSettings',
                'display_settings',
              ),
              _buildOptionItem(Icons.playlist_play, 'Playlists', 'playlists'),
              _buildOptionItem(
                Icons.language,
                'Network\nStream',
                'network_stream',
              ),
              _buildOptionItem(Icons.info_outline, 'Information', 'info'),
              _buildOptionItem(Icons.share, 'Share', 'share'),
              _buildOptionItem(Icons.crop, 'Cut', 'cut'),
              _buildOptionItem(Icons.bookmark_border, 'Bookmark', 'bookmark'),
              _buildOptionItem(
                Icons.format_list_bulleted,
                'Chapter',
                'chapter',
              ),
              _buildOptionItem(Icons.lightbulb_outline, 'Tutorial', 'tutorial'),
              _buildOptionItem(Icons.chevron_right, 'More', 'more_view'),
            ],
          ),
          const SizedBox(height: 32),
          _buildSwitchRow('Video Display', _videoDisplay, (val) {
            setState(() => _videoDisplay = val);
          }),
          const SizedBox(height: 16),
          _buildSwitchRow('Shortcuts', _shortcuts, (val) {
            setState(() => _shortcuts = val);
          }),
          const SizedBox(height: 16),
          if (_shortcuts)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  _buildCheckboxRow('Screen Rotation', 'Playback Speed'),
                  const SizedBox(height: 16),
                  _buildCheckboxRow('Background Play', 'Loop'),
                  const SizedBox(height: 16),
                  _buildCheckboxRow('Mute', 'Shuffle'),
                  const SizedBox(height: 16),
                  _buildCheckboxRow('Equalizer', 'Sleep Timer'),
                  const SizedBox(height: 16),
                  _buildCheckboxRow('A - B Repeat', 'Night Mode'),
                  const SizedBox(height: 16),
                  _buildCheckboxRow('Customise Items', 'Screenshot'),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMoreListView() {
    return Column(
      key: const ValueKey('more_list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() => _currentView = 'main');
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'More',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildSectionHeader('Tools'),
              _buildListItem('Delete', onTap: () {}),
              _buildListItem('Rename', onTap: () {}),
              _buildListItem('Lock', onTap: () {}),
              const SizedBox(height: 8),
              _buildListItem('Settings', onTap: () {}),
              const SizedBox(height: 8),
              _buildSectionHeader('Help'),
              _buildListItem('FAQ', onTap: () {}),
              _buildListItem('Check for updates', onTap: () {}),
              _buildListItem('Bug Report', onTap: () {}),
              _buildListItem('About', onTap: () {}),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildListItem(String title, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blueAccent,
              activeTrackColor: Colors.blueAccent.withOpacity(0.3),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow(String label1, String label2) {
    return Row(
      children: [
        Expanded(child: _buildCheckboxItem(label1)),
        const SizedBox(width: 16),
        Expanded(child: _buildCheckboxItem(label2)),
      ],
    );
  }

  Widget _buildCheckboxItem(String label) {
    final isChecked = _shortcutStates[label] ?? false;
    return GestureDetector(
      onTap: () {
        setState(() {
          _shortcutStates[label] = !isChecked;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isChecked ? Colors.blueAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isChecked
                    ? Colors.blueAccent
                    : Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: isChecked
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String label,
    String id, {
    String? badge,
  }) {
    return InkWell(
      onTap: () {
        if (id == 'more_view') {
          setState(() {
            _currentView = 'more_list';
          });
        } else {
          widget.onOptionSelected(id);
        }
      },
      splashColor: Colors.white12,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              if (badge != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              height: 1.2,
              letterSpacing: 0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
