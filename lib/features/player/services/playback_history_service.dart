import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists playback positions per media file so videos can resume later.
/// Keys are file paths and values are duration in milliseconds.
class PlaybackHistoryService {
  static const _historyKey = 'playback_history';
  final SharedPreferences _prefs;

  PlaybackHistoryService(this._prefs);

  Map<String, int> _cache = {};
  bool _isLoaded = false;

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    final raw = _prefs.getString(_historyKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cache = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        debugPrint('Failed to decode playback history: $e');
        _cache = {};
      }
    }
    _isLoaded = true;
  }

  Future<Duration?> getPosition(String videoPath) async {
    await _ensureLoaded();
    final millis = _cache[videoPath];
    if (millis == null) return null;
    return Duration(milliseconds: millis);
  }

  Future<void> savePosition(String videoPath, Duration position) async {
    await _ensureLoaded();
    _cache[videoPath] = position.inMilliseconds;
    await _prefs.setString(_historyKey, jsonEncode(_cache));
  }

  Future<void> clearPosition(String videoPath) async {
    await _ensureLoaded();
    _cache.remove(videoPath);
    await _prefs.setString(_historyKey, jsonEncode(_cache));
  }
}
