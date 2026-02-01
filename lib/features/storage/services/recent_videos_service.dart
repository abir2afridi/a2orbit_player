import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

class RecentVideoEntry {
  final String path;
  final String fileName;
  final String parentFolder;
  final DateTime lastPlayed;

  const RecentVideoEntry({
    required this.path,
    required this.fileName,
    required this.parentFolder,
    required this.lastPlayed,
  });

  factory RecentVideoEntry.fromJson(Map<String, dynamic> json) {
    return RecentVideoEntry(
      path: json['path'] as String,
      fileName: json['fileName'] as String,
      parentFolder: json['parentFolder'] as String,
      lastPlayed: DateTime.tryParse(json['lastPlayed'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'fileName': fileName,
        'parentFolder': parentFolder,
        'lastPlayed': lastPlayed.toIso8601String(),
      };
}

class RecentVideosService {
  final SharedPreferences _prefs;
  List<RecentVideoEntry>? _cache;

  RecentVideosService(this._prefs);

  Future<List<RecentVideoEntry>> _loadEntries() async {
    if (_cache != null) return _cache!;
    final raw = _prefs.getString(AppConstants.recentVideosKey);
    if (raw == null || raw.isEmpty) {
      _cache = <RecentVideoEntry>[];
      return _cache!;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _cache = decoded
          .map((item) => RecentVideoEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cache = <RecentVideoEntry>[];
    }
    return _cache!;
  }

  Future<List<RecentVideoEntry>> getRecentVideos() async {
    final entries = await _loadEntries();
    entries.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    return entries;
  }

  Future<void> addRecentVideo({
    required String path,
    required String fileName,
    required String parentFolder,
  }) async {
    final entries = await _loadEntries();
    final updated = <RecentVideoEntry>[...entries];
    final existingIndex =
        updated.indexWhere((entry) => entry.path == path);
    final newEntry = RecentVideoEntry(
      path: path,
      fileName: fileName,
      parentFolder: parentFolder,
      lastPlayed: DateTime.now(),
    );
    if (existingIndex != -1) {
      updated[existingIndex] = newEntry;
    } else {
      updated.insert(0, newEntry);
    }
    final trimmed = updated
        .sorted((a, b) => b.lastPlayed.compareTo(a.lastPlayed))
        .take(AppConstants.maxRecentVideos)
        .toList();
    _cache = trimmed;
    await _prefs.setString(
      AppConstants.recentVideosKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> removeRecent(String path) async {
    final entries = await _loadEntries();
    final updated = entries.where((entry) => entry.path != path).toList();
    _cache = updated;
    await _prefs.setString(
      AppConstants.recentVideosKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearRecents() async {
    _cache = <RecentVideoEntry>[];
    await _prefs.remove(AppConstants.recentVideosKey);
  }
}
