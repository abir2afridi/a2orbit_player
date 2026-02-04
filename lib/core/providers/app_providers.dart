import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/privacy/services/privacy_service.dart';

// SharedPreferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

// Privacy Service Provider
final privacyServiceProvider = Provider<PrivacyService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrivacyService(prefs);
});

// Theme Provider
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeData>((ref) {
  return ThemeNotifier(ref);
});

enum ThemeStyle { normal, dynamic, ahs }

class AppThemeData {
  final ThemeMode themeMode;
  final Color accentColor;
  final bool useDynamicColor;
  final bool useAmoled;
  final ThemeStyle style;
  final Color? headerColor;
  final Color? ahsColor;

  const AppThemeData({
    this.themeMode = ThemeMode.system,
    this.accentColor = const Color(0xFF1976D2),
    this.useDynamicColor = true,
    this.useAmoled = false,
    this.style = ThemeStyle.normal,
    this.headerColor,
    this.ahsColor,
  });

  AppThemeData copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    bool? useDynamicColor,
    bool? useAmoled,
    ThemeStyle? style,
    Color? headerColor,
    Color? ahsColor,
  }) {
    return AppThemeData(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      useAmoled: useAmoled ?? this.useAmoled,
      style: style ?? this.style,
      headerColor: headerColor ?? this.headerColor,
      ahsColor: ahsColor ?? this.ahsColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<AppThemeData> {
  final Ref ref;
  late SharedPreferences _prefs;

  ThemeNotifier(this.ref) : super(const AppThemeData()) {
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    _prefs = ref.read(sharedPreferencesProvider);

    final themeIndex = _prefs.getInt('theme_mode') ?? 0;
    final accentColorValue = _prefs.getInt('accent_color') ?? 0xFF1976D2;
    final useDynamicColor = _prefs.getBool('use_dynamic_color') ?? true;
    final useAmoled = _prefs.getBool('use_amoled_theme') ?? false;

    final styleIndex = _prefs.getInt('theme_style') ?? 0;
    final headerColorVal = _prefs.getInt('header_color');
    final ahsColorVal = _prefs.getInt('ahs_color');

    state = AppThemeData(
      themeMode: ThemeMode.values[themeIndex],
      accentColor: Color(accentColorValue),
      useDynamicColor: useDynamicColor,
      useAmoled: useAmoled,
      style: ThemeStyle.values[styleIndex],
      headerColor: headerColorVal != null ? Color(headerColorVal) : null,
      ahsColor: ahsColorVal != null ? Color(ahsColorVal) : null,
    );
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await _prefs.setInt('theme_mode', themeMode.index);
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    await _prefs.setInt('accent_color', color.value);
  }

  Future<void> setUseDynamicColor(bool useDynamicColor) async {
    state = state.copyWith(useDynamicColor: useDynamicColor);
    await _prefs.setBool('use_dynamic_color', useDynamicColor);
  }

  Future<void> setUseAmoled(bool useAmoled) async {
    state = state.copyWith(useAmoled: useAmoled);
    await _prefs.setBool('use_amoled_theme', useAmoled);
  }

  Future<void> setThemeStyle(ThemeStyle style) async {
    state = state.copyWith(style: style);
    await _prefs.setInt('theme_style', style.index);
  }

  Future<void> setHeaderColor(Color? color) async {
    state = state.copyWith(headerColor: color);
    if (color != null) {
      await _prefs.setInt('header_color', color.value);
    } else {
      await _prefs.remove('header_color');
    }
  }

  Future<void> setAhsColor(Color? color) async {
    state = state.copyWith(ahsColor: color);
    if (color != null) {
      await _prefs.setInt('ahs_color', color.value);
    } else {
      await _prefs.remove('ahs_color');
    }
  }
}

// App Lock Provider
final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((
  ref,
) {
  return AppLockNotifier(ref);
});

class AppLockState {
  final bool isEnabled;
  final bool hasPin;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool isUnlocked;
  final bool isLoading;
  final String? errorMessage;

  const AppLockState({
    this.isEnabled = false,
    this.hasPin = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.isUnlocked = true,
    this.isLoading = true,
    this.errorMessage,
  });

  AppLockState copyWith({
    bool? isEnabled,
    bool? hasPin,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? isUnlocked,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      hasPin: hasPin ?? this.hasPin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  final Ref ref;
  final LocalAuthentication _auth = LocalAuthentication();

  AppLockNotifier(this.ref) : super(const AppLockState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final privacyService = ref.read(privacyServiceProvider);
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    final usableBiometrics = canCheckBiometrics || isDeviceSupported;

    final isEnabled = privacyService.isAppLockEnabled;
    final hasPin = privacyService.hasPinSet;
    final biometricEnabled =
        isEnabled && hasPin && privacyService.isBiometricUnlockEnabled;

    state = state.copyWith(
      isEnabled: isEnabled && hasPin,
      hasPin: hasPin,
      biometricEnabled: biometricEnabled && usableBiometrics,
      biometricAvailable: usableBiometrics,
      isUnlocked: !(isEnabled && hasPin),
      isLoading: false,
      errorMessage: null,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await _initialize();
  }

  Future<void> setEnabled(bool enable) async {
    final privacyService = ref.read(privacyServiceProvider);
    if (enable && !privacyService.hasPinSet) {
      state = state.copyWith(
        errorMessage: 'Set a PIN before enabling App Lock.',
        isEnabled: false,
        isUnlocked: true,
      );
      return;
    }

    await privacyService.setAppLockEnabled(enable);
    state = state.copyWith(
      isEnabled: enable,
      isUnlocked: !enable,
      errorMessage: null,
    );
  }

  Future<void> setPin(String pin) async {
    final privacyService = ref.read(privacyServiceProvider);
    await privacyService.setPin(pin);
    await privacyService.setAppLockEnabled(true);
    state = state.copyWith(
      hasPin: true,
      isEnabled: true,
      isUnlocked: false,
      errorMessage: null,
    );
  }

  Future<void> clearPin() async {
    final privacyService = ref.read(privacyServiceProvider);
    await privacyService.clearPin();
    await privacyService.setAppLockEnabled(false);
    state = state.copyWith(
      hasPin: false,
      isEnabled: false,
      isUnlocked: true,
      biometricEnabled: false,
      errorMessage: null,
    );
  }

  Future<void> setBiometricEnabled(bool enable) async {
    if (!state.biometricAvailable) return;
    final privacyService = ref.read(privacyServiceProvider);
    await privacyService.setBiometricUnlockEnabled(enable);
    state = state.copyWith(biometricEnabled: enable, errorMessage: null);
  }

  Future<bool> unlockWithPin(String pin) async {
    final privacyService = ref.read(privacyServiceProvider);
    final success = privacyService.verifyPin(pin);
    if (success) {
      state = state.copyWith(isUnlocked: true, errorMessage: null);
    } else {
      state = state.copyWith(errorMessage: 'Incorrect PIN. Try again.');
    }
    return success;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometricEnabled || !state.biometricAvailable) {
      return false;
    }
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock A2Orbit Player',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        state = state.copyWith(isUnlocked: true, errorMessage: null);
      }
      return authenticated;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Biometric authentication failed. ${e.toString()}',
      );
      return false;
    }
  }
}

// Settings Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier(ref);
});

enum BackgroundPlayOption { stop, backgroundAudio, pictureInPicture }

extension BackgroundPlayOptionX on BackgroundPlayOption {
  String get key {
    switch (this) {
      case BackgroundPlayOption.stop:
        return 'stop';
      case BackgroundPlayOption.backgroundAudio:
        return 'background_audio';
      case BackgroundPlayOption.pictureInPicture:
        return 'pip';
    }
  }

  static BackgroundPlayOption fromKey(String key) {
    switch (key) {
      case 'background_audio':
        return BackgroundPlayOption.backgroundAudio;
      case 'pip':
        return BackgroundPlayOption.pictureInPicture;
      case 'stop':
      default:
        return BackgroundPlayOption.stop;
    }
  }
}

class AppSettings {
  final String themeMode;
  final BackgroundPlayOption backgroundPlayOption;
  final bool enableScreenOffPlayback;
  final bool autoEnterPip;
  final bool audioOnly;
  final bool volumeBoost;
  final double playbackSpeed;
  final int seekDuration;
  final int sleepTimerMinutes;
  final bool enableABRepeat;
  final bool showGesturesHints;
  final bool autoRotateVideo;
  final bool gestureOneHandMode;
  final bool enableGestureSeek;
  final bool enableGestureBrightness;
  final bool enableGestureVolume;
  final bool keepScreenOn;
  final bool resumePlayback;
  final double subtitleFontSize;
  final int subtitleTextColor;
  final double subtitleBackgroundOpacity;
  final String defaultSubtitleLanguage;
  final String defaultAudioLanguage;
  final bool enableHardwareAcceleration;
  final bool enableTimelinePreviewThumbnail;
  final bool timelineRoundedThumbnail;
  final bool timelineShowTimestamp;
  final bool timelineSmoothAnimation;
  final bool timelineFastScrubOptimization;

  const AppSettings({
    this.themeMode = 'system',
    this.backgroundPlayOption = BackgroundPlayOption.backgroundAudio,
    this.enableScreenOffPlayback = true,
    this.autoEnterPip = true,
    this.audioOnly = false,
    this.volumeBoost = false,
    this.playbackSpeed = 1.0,
    this.seekDuration = 10000,
    this.sleepTimerMinutes = 0,
    this.enableABRepeat = false,
    this.showGesturesHints = true,
    this.autoRotateVideo = true,
    this.gestureOneHandMode = false,
    this.enableGestureSeek = true,
    this.enableGestureBrightness = true,
    this.enableGestureVolume = true,
    this.keepScreenOn = true,
    this.resumePlayback = true,
    this.subtitleFontSize = 16.0,
    this.subtitleTextColor = 0xFFFFFFFF,
    this.subtitleBackgroundOpacity = 0.3,
    this.defaultSubtitleLanguage = 'en',
    this.defaultAudioLanguage = 'en',
    this.enableHardwareAcceleration = true,
    this.enableTimelinePreviewThumbnail = true,
    this.timelineRoundedThumbnail = true,
    this.timelineShowTimestamp = true,
    this.timelineSmoothAnimation = true,
    this.timelineFastScrubOptimization = true,
  });

  AppSettings copyWith({
    String? themeMode,
    BackgroundPlayOption? backgroundPlayOption,
    bool? enableScreenOffPlayback,
    bool? autoEnterPip,
    bool? audioOnly,
    bool? volumeBoost,
    double? playbackSpeed,
    int? seekDuration,
    int? sleepTimerMinutes,
    bool? enableABRepeat,
    bool? showGesturesHints,
    bool? autoRotateVideo,
    bool? gestureOneHandMode,
    bool? enableGestureSeek,
    bool? enableGestureBrightness,
    bool? enableGestureVolume,
    bool? keepScreenOn,
    bool? resumePlayback,
    double? subtitleFontSize,
    int? subtitleTextColor,
    double? subtitleBackgroundOpacity,
    String? defaultSubtitleLanguage,
    String? defaultAudioLanguage,
    bool? enableHardwareAcceleration,
    bool? enableTimelinePreviewThumbnail,
    bool? timelineRoundedThumbnail,
    bool? timelineShowTimestamp,
    bool? timelineSmoothAnimation,
    bool? timelineFastScrubOptimization,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      backgroundPlayOption: backgroundPlayOption ?? this.backgroundPlayOption,
      enableScreenOffPlayback:
          enableScreenOffPlayback ?? this.enableScreenOffPlayback,
      autoEnterPip: autoEnterPip ?? this.autoEnterPip,
      audioOnly: audioOnly ?? this.audioOnly,
      volumeBoost: volumeBoost ?? this.volumeBoost,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      seekDuration: seekDuration ?? this.seekDuration,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      enableABRepeat: enableABRepeat ?? this.enableABRepeat,
      showGesturesHints: showGesturesHints ?? this.showGesturesHints,
      autoRotateVideo: autoRotateVideo ?? this.autoRotateVideo,
      gestureOneHandMode: gestureOneHandMode ?? this.gestureOneHandMode,
      enableGestureSeek: enableGestureSeek ?? this.enableGestureSeek,
      enableGestureBrightness:
          enableGestureBrightness ?? this.enableGestureBrightness,
      enableGestureVolume: enableGestureVolume ?? this.enableGestureVolume,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      resumePlayback: resumePlayback ?? this.resumePlayback,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      subtitleBackgroundOpacity:
          subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
      defaultSubtitleLanguage:
          defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      defaultAudioLanguage: defaultAudioLanguage ?? this.defaultAudioLanguage,
      enableHardwareAcceleration:
          enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      enableTimelinePreviewThumbnail:
          enableTimelinePreviewThumbnail ?? this.enableTimelinePreviewThumbnail,
      timelineRoundedThumbnail:
          timelineRoundedThumbnail ?? this.timelineRoundedThumbnail,
      timelineShowTimestamp:
          timelineShowTimestamp ?? this.timelineShowTimestamp,
      timelineSmoothAnimation:
          timelineSmoothAnimation ?? this.timelineSmoothAnimation,
      timelineFastScrubOptimization:
          timelineFastScrubOptimization ?? this.timelineFastScrubOptimization,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref ref;
  late SharedPreferences _prefs;

  SettingsNotifier(this.ref) : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = ref.read(sharedPreferencesProvider);

    final legacyAutoRotate = _readBool('auto_rotate');
    if (legacyAutoRotate != null && !_prefs.containsKey('auto_rotate_video')) {
      await _prefs.setBool('auto_rotate_video', legacyAutoRotate);
    }

    state = AppSettings(
      themeMode: _readString('theme_mode') ?? 'system',
      backgroundPlayOption: BackgroundPlayOptionX.fromKey(
        _readString('background_play_option') ?? 'background_audio',
      ),
      enableScreenOffPlayback: _readBool('screen_off_playback') ?? true,
      autoEnterPip: _readBool('auto_enter_pip') ?? true,
      audioOnly: _readBool('audio_only') ?? false,
      volumeBoost: _readBool('volume_boost') ?? false,
      playbackSpeed: _readDouble('playback_speed') ?? 1.0,
      seekDuration: _readInt('seek_duration') ?? 10000,
      sleepTimerMinutes: _readInt('sleep_timer_minutes') ?? 0,
      enableABRepeat: _readBool('enable_ab_repeat') ?? false,
      showGesturesHints: _readBool('show_gestures_hints') ?? true,
      autoRotateVideo: _readBool('auto_rotate_video') ?? true,
      gestureOneHandMode: _readBool('gesture_one_hand') ?? false,
      enableGestureSeek: _readBool('gesture_seek') ?? true,
      enableGestureBrightness: _readBool('gesture_brightness') ?? true,
      enableGestureVolume: _readBool('gesture_volume') ?? true,
      keepScreenOn: _readBool('keep_screen_on') ?? true,
      resumePlayback: _readBool('resume_playback') ?? true,
      subtitleFontSize: _readDouble('subtitle_font_size') ?? 16.0,
      subtitleTextColor: _readInt('subtitle_text_color') ?? 0xFFFFFFFF,
      subtitleBackgroundOpacity:
          _readDouble('subtitle_background_opacity') ?? 0.3,
      defaultSubtitleLanguage: _readString('default_subtitle_language') ?? 'en',
      defaultAudioLanguage: _readString('default_audio_language') ?? 'en',
      enableHardwareAcceleration: _readBool('hardware_acceleration') ?? true,
      enableTimelinePreviewThumbnail:
          _readBool('timeline_preview_enabled') ?? true,
      timelineRoundedThumbnail: _readBool('timeline_preview_rounded') ?? true,
      timelineShowTimestamp: _readBool('timeline_preview_timestamp') ?? true,
      timelineSmoothAnimation: _readBool('timeline_preview_animation') ?? true,
      timelineFastScrubOptimization:
          _readBool('timeline_preview_fast_scrub') ?? true,
    );
  }

  Future<void> updateSetting(String key, dynamic value) async {
    switch (key) {
      case 'theme_mode':
        state = state.copyWith(themeMode: value);
        await _prefs.setString(key, value);
        break;
      case 'background_play_option':
        state = state.copyWith(backgroundPlayOption: value);
        await _prefs.setString(key, value.key);
        break;
      case 'screen_off_playback':
        state = state.copyWith(enableScreenOffPlayback: value);
        await _prefs.setBool(key, value);
        break;
      case 'auto_enter_pip':
        state = state.copyWith(autoEnterPip: value);
        await _prefs.setBool(key, value);
        break;
      case 'audio_only':
        state = state.copyWith(audioOnly: value);
        await _prefs.setBool(key, value);
        break;
      case 'volume_boost':
        state = state.copyWith(volumeBoost: value);
        await _prefs.setBool(key, value);
        break;
      case 'playback_speed':
        state = state.copyWith(playbackSpeed: value);
        await _prefs.setDouble(key, value);
        break;
      case 'seek_duration':
        state = state.copyWith(seekDuration: value);
        await _prefs.setInt(key, value);
        break;
      case 'sleep_timer_minutes':
        state = state.copyWith(sleepTimerMinutes: value);
        await _prefs.setInt(key, value);
        break;
      case 'enable_ab_repeat':
        state = state.copyWith(enableABRepeat: value);
        await _prefs.setBool(key, value);
        break;
      case 'show_gestures_hints':
        state = state.copyWith(showGesturesHints: value);
        await _prefs.setBool(key, value);
        break;
      case 'auto_rotate_video':
        state = state.copyWith(autoRotateVideo: value);
        await _prefs.setBool(key, value);
        break;
      case 'gesture_one_hand':
        state = state.copyWith(gestureOneHandMode: value);
        await _prefs.setBool(key, value);
        break;
      case 'gesture_seek':
        state = state.copyWith(enableGestureSeek: value);
        await _prefs.setBool(key, value);
        break;
      case 'gesture_brightness':
        state = state.copyWith(enableGestureBrightness: value);
        await _prefs.setBool(key, value);
        break;
      case 'gesture_volume':
        state = state.copyWith(enableGestureVolume: value);
        await _prefs.setBool(key, value);
        break;
      case 'keep_screen_on':
        state = state.copyWith(keepScreenOn: value);
        await _prefs.setBool(key, value);
        break;
      case 'resume_playback':
        state = state.copyWith(resumePlayback: value);
        await _prefs.setBool(key, value);
        break;
      case 'subtitle_font_size':
        state = state.copyWith(subtitleFontSize: value);
        await _prefs.setDouble(key, value);
        break;
      case 'subtitle_text_color':
        state = state.copyWith(subtitleTextColor: value);
        await _prefs.setInt(key, value);
        break;
      case 'subtitle_background_opacity':
        state = state.copyWith(subtitleBackgroundOpacity: value);
        await _prefs.setDouble(key, value);
        break;
      case 'default_subtitle_language':
        state = state.copyWith(defaultSubtitleLanguage: value);
        await _prefs.setString(key, value);
        break;
      case 'default_audio_language':
        state = state.copyWith(defaultAudioLanguage: value);
        await _prefs.setString(key, value);
        break;
      case 'hardware_acceleration':
        state = state.copyWith(enableHardwareAcceleration: value);
        await _prefs.setBool(key, value);
        break;
      case 'timeline_preview_enabled':
        state = state.copyWith(enableTimelinePreviewThumbnail: value);
        await _prefs.setBool(key, value);
        break;
      case 'timeline_preview_rounded':
        state = state.copyWith(timelineRoundedThumbnail: value);
        await _prefs.setBool(key, value);
        break;
      case 'timeline_preview_timestamp':
        state = state.copyWith(timelineShowTimestamp: value);
        await _prefs.setBool(key, value);
        break;
      case 'timeline_preview_animation':
        state = state.copyWith(timelineSmoothAnimation: value);
        await _prefs.setBool(key, value);
        break;
      case 'timeline_preview_fast_scrub':
        state = state.copyWith(timelineFastScrubOptimization: value);
        await _prefs.setBool(key, value);
        break;
    }
  }

  String? _readString(String key) {
    final value = _prefs.get(key);
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return value.toString();
  }

  bool? _readBool(String key) {
    final value = _prefs.get(key);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  double? _readDouble(String key) {
    final value = _prefs.get(key);
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is bool) return value ? 1.0 : 0.0;
    return null;
  }

  int? _readInt(String key) {
    final value = _prefs.get(key);
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is bool) return value ? 1 : 0;
    return null;
  }
}
