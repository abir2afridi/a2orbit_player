import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AudioTrackSelection {
  const AudioTrackSelection({
    required this.groupIndex,
    required this.trackIndex,
  });

  final int groupIndex;
  final int trackIndex;

  Map<String, dynamic> toJson() => {'group': groupIndex, 'track': trackIndex};

  static AudioTrackSelection? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final group = json['group'];
    final track = json['track'];
    if (group is! int || track is! int) return null;
    return AudioTrackSelection(groupIndex: group, trackIndex: track);
  }
}

class AspectPreference {
  const AspectPreference({required this.mode, this.customRatio});

  final String mode;
  final double? customRatio;

  Map<String, dynamic> toJson() => {
    'mode': mode,
    if (customRatio != null) 'ratio': customRatio,
  };

  static AspectPreference? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final mode = json['mode'];
    if (mode is! String) return null;
    final ratio = json['ratio'];
    return AspectPreference(
      mode: mode,
      customRatio: ratio is num ? ratio.toDouble() : null,
    );
  }
}

class GlobalAspectPreference {
  const GlobalAspectPreference({this.preference, required this.applyToAll});

  final AspectPreference? preference;
  final bool applyToAll;
}

class PlayerPreferenceService {
  PlayerPreferenceService(this._prefs);

  final SharedPreferences _prefs;

  static const _audioKey = 'player_audio_track_selection';
  static const _aspectKey = 'player_aspect_mode_selection';
  static const _globalAspectModeKey = 'player_aspect_global_mode';
  static const _globalAspectApplyKey = 'player_aspect_apply_all';

  Map<String, dynamic>? _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore corrupt entries
    }
    return null;
  }

  Future<void> _encode(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  Future<void> saveAudioTrack(
    String videoPath,
    AudioTrackSelection selection,
  ) async {
    final map = _decode(_audioKey) ?? <String, dynamic>{};
    map[videoPath] = selection.toJson();
    await _encode(_audioKey, map);
  }

  AudioTrackSelection? getAudioTrack(String videoPath) {
    final map = _decode(_audioKey) ?? const <String, dynamic>{};
    final raw = map[videoPath];
    if (raw is Map<String, dynamic>) {
      return AudioTrackSelection.fromJson(raw);
    }
    return null;
  }

  Future<void> clearAudioTrack(String videoPath) async {
    final map = _decode(_audioKey) ?? <String, dynamic>{};
    if (map.remove(videoPath) != null) {
      await _encode(_audioKey, map);
    }
  }

  Future<void> saveAspectPreference(
    String videoPath,
    AspectPreference preference,
  ) async {
    final map = _decode(_aspectKey) ?? <String, dynamic>{};
    map[videoPath] = preference.toJson();
    await _encode(_aspectKey, map);
  }

  AspectPreference? getAspectPreference(String videoPath) {
    final map = _decode(_aspectKey) ?? const <String, dynamic>{};
    final raw = map[videoPath];
    if (raw is Map<String, dynamic>) {
      return AspectPreference.fromJson(raw);
    }
    return null;
  }

  Future<void> clearAspectPreference(String videoPath) async {
    final map = _decode(_aspectKey) ?? <String, dynamic>{};
    if (map.remove(videoPath) != null) {
      await _encode(_aspectKey, map);
    }
  }

  Future<void> setGlobalAspectPreference(AspectPreference? preference) async {
    if (preference == null) {
      await _prefs.remove(_globalAspectModeKey);
    } else {
      await _prefs.setString(
        _globalAspectModeKey,
        jsonEncode(preference.toJson()),
      );
    }
  }

  AspectPreference? getGlobalAspectPreference() {
    final raw = _prefs.getString(_globalAspectModeKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AspectPreference.fromJson(decoded);
      }
    } catch (_) {
      // Ignore corrupt entries
    }
    return null;
  }

  Future<void> setApplyAspectGlobally(bool value) async {
    await _prefs.setBool(_globalAspectApplyKey, value);
  }

  bool getApplyAspectGlobally() {
    return _prefs.getBool(_globalAspectApplyKey) ?? false;
  }

  GlobalAspectPreference readGlobalAspectState() {
    return GlobalAspectPreference(
      preference: getGlobalAspectPreference(),
      applyToAll: getApplyAspectGlobally(),
    );
  }

  static const _orientationModeKey = 'player_orientation_mode';

  static const _rotationKey = 'player_rotation_preference';

  Future<void> saveOrientationMode(String mode) async {
    await _prefs.setString(_orientationModeKey, mode.toUpperCase());
  }

  String getOrientationMode() {
    return _prefs.getString(_orientationModeKey)?.toUpperCase() ?? 'LANDSCAPE';
  }

  Future<void> saveRotationPreference(String videoPath, bool enabled) async {
    final map = _decode(_rotationKey) ?? <String, dynamic>{};
    map[videoPath] = enabled;
    await _encode(_rotationKey, map);
  }

  bool? getRotationPreference(String videoPath) {
    final map = _decode(_rotationKey) ?? const <String, dynamic>{};
    final val = map[videoPath];
    if (val is bool) return val;
    return null;
  }
}
