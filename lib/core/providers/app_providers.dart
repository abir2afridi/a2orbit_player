import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

// SharedPreferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

// Theme Provider
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeData>((ref) {
  return ThemeNotifier(ref);
});

class AppThemeData {
  final ThemeMode themeMode;
  final Color accentColor;
  final bool useDynamicColor;

  const AppThemeData({
    this.themeMode = ThemeMode.system,
    this.accentColor = const Color(0xFF1976D2),
    this.useDynamicColor = true,
  });

  AppThemeData copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    bool? useDynamicColor,
  }) {
    return AppThemeData(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
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

    state = AppThemeData(
      themeMode: ThemeMode.values[themeIndex],
      accentColor: Color(accentColorValue),
      useDynamicColor: useDynamicColor,
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
}

// Settings Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier(ref);
});

class AppSettings {
  final bool backgroundPlay;
  final bool pipMode;
  final bool audioOnly;
  final bool volumeBoost;
  final double playbackSpeed;
  final int seekDuration;
  final bool showGesturesHints;
  final bool autoRotate;
  final bool keepScreenOn;
  final String defaultSubtitleLanguage;
  final String defaultAudioLanguage;
  final bool enableHardwareAcceleration;

  const AppSettings({
    this.backgroundPlay = true,
    this.pipMode = true,
    this.audioOnly = false,
    this.volumeBoost = false,
    this.playbackSpeed = 1.0,
    this.seekDuration = 10000,
    this.showGesturesHints = true,
    this.autoRotate = true,
    this.keepScreenOn = true,
    this.defaultSubtitleLanguage = 'en',
    this.defaultAudioLanguage = 'en',
    this.enableHardwareAcceleration = true,
  });

  AppSettings copyWith({
    bool? backgroundPlay,
    bool? pipMode,
    bool? audioOnly,
    bool? volumeBoost,
    double? playbackSpeed,
    int? seekDuration,
    bool? showGesturesHints,
    bool? autoRotate,
    bool? keepScreenOn,
    String? defaultSubtitleLanguage,
    String? defaultAudioLanguage,
    bool? enableHardwareAcceleration,
  }) {
    return AppSettings(
      backgroundPlay: backgroundPlay ?? this.backgroundPlay,
      pipMode: pipMode ?? this.pipMode,
      audioOnly: audioOnly ?? this.audioOnly,
      volumeBoost: volumeBoost ?? this.volumeBoost,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      seekDuration: seekDuration ?? this.seekDuration,
      showGesturesHints: showGesturesHints ?? this.showGesturesHints,
      autoRotate: autoRotate ?? this.autoRotate,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      defaultSubtitleLanguage:
          defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      defaultAudioLanguage: defaultAudioLanguage ?? this.defaultAudioLanguage,
      enableHardwareAcceleration:
          enableHardwareAcceleration ?? this.enableHardwareAcceleration,
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

    state = AppSettings(
      backgroundPlay: _prefs.getBool('background_play') ?? true,
      pipMode: _prefs.getBool('pip_mode') ?? true,
      audioOnly: _prefs.getBool('audio_only') ?? false,
      volumeBoost: _prefs.getBool('volume_boost') ?? false,
      playbackSpeed: _prefs.getDouble('playback_speed') ?? 1.0,
      seekDuration: _prefs.getInt('seek_duration') ?? 10000,
      showGesturesHints: _prefs.getBool('show_gestures_hints') ?? true,
      autoRotate: _prefs.getBool('auto_rotate') ?? true,
      keepScreenOn: _prefs.getBool('keep_screen_on') ?? true,
      defaultSubtitleLanguage:
          _prefs.getString('default_subtitle_language') ?? 'en',
      defaultAudioLanguage: _prefs.getString('default_audio_language') ?? 'en',
      enableHardwareAcceleration:
          _prefs.getBool('hardware_acceleration') ?? true,
    );
  }

  Future<void> updateSetting(String key, dynamic value) async {
    switch (key) {
      case 'background_play':
        state = state.copyWith(backgroundPlay: value);
        await _prefs.setBool(key, value);
        break;
      case 'pip_mode':
        state = state.copyWith(pipMode: value);
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
      case 'show_gestures_hints':
        state = state.copyWith(showGesturesHints: value);
        await _prefs.setBool(key, value);
        break;
      case 'auto_rotate':
        state = state.copyWith(autoRotate: value);
        await _prefs.setBool(key, value);
        break;
      case 'keep_screen_on':
        state = state.copyWith(keepScreenOn: value);
        await _prefs.setBool(key, value);
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
    }
  }
}
