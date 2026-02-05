import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// MediaStore-based video discovery service for Android 11+
/// Uses MediaStore queries instead of manual filesystem recursion
class MediaStoreService {
  static const List<String> _supportedVideoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'm4v',
    '3gp',
    'ogv',
    'ts',
    'mts',
    'm2ts',
  ];

  static Map<String, List<File>> _cachedFolders = {};
  static Future<Map<String, List<File>>>? _ongoingScan;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const MethodChannel _channel = MethodChannel(
    'a2orbit_player/mediastore',
  );

  /// Gets cached folders if available
  static Map<String, List<File>> getCachedFolders() {
    return _cloneFolderMap(_cachedFolders);
  }

  /// Clears the cache
  static void clearCache() {
    _cachedFolders = {};
    _cacheTimestamp = null;
  }

  /// Scans MediaStore for video folders
  /// Uses MediaStore.Video as source of truth for all video files
  static Future<Map<String, List<File>>> scanFoldersWithVideos({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid()) {
      return getCachedFolders();
    }

    // Check permissions first
    if (!await _checkPermissions()) {
      return {};
    }

    if (_ongoingScan != null) {
      final result = await _ongoingScan!;
      return _cloneFolderMap(result);
    }

    _ongoingScan = _performMediaStoreScan();
    try {
      final result = await _ongoingScan!;
      _cachedFolders = _cloneFolderMap(result);
      _cacheTimestamp = DateTime.now();
      return getCachedFolders();
    } finally {
      _ongoingScan = null;
    }
  }

  /// Performs the actual MediaStore query in background
  static Future<Map<String, List<File>>> _performMediaStoreScan() async {
    return await compute(_scanMediaStoreIsolate, null);
  }

  /// Isolate function for MediaStore scanning
  static Future<Map<String, List<File>>> _scanMediaStoreIsolate(_) async {
    final Map<String, List<File>> foldersWithVideos = {};

    try {
      if (!Platform.isAndroid) {
        debugPrint('MediaStoreService: Not on Android, returning empty result');
        return foldersWithVideos;
      }

      // Use platform channel to query MediaStore
      final List<dynamic>? results;
      try {
        results = await _channel.invokeListMethod('scanVideoFolders');
      } catch (e) {
        debugPrint('MediaStoreService: Platform channel error: $e');
        // Fallback to basic scanning if platform channel fails
        return await _fallbackScan();
      }

      if (results == null) {
        debugPrint('MediaStoreService: No results from platform channel');
        return foldersWithVideos;
      }

      // Process results from native Android code
      for (final result in results) {
        try {
          final filePath = result['path'] as String?;
          final bucketPath = result['bucketPath'] as String?;

          if (filePath != null && bucketPath != null) {
            final file = File(filePath);

            // Verify file exists and is a video
            if (file.existsSync() && _isVideoFile(file.path)) {
              if (!foldersWithVideos.containsKey(bucketPath)) {
                foldersWithVideos[bucketPath] = [];
              }
              foldersWithVideos[bucketPath]!.add(file);
            }
          }
        } catch (e) {
          debugPrint('MediaStoreService: Error processing result: $e');
          continue;
        }
      }

      debugPrint(
        'MediaStoreService: Found ${foldersWithVideos.length} folders with videos',
      );

      // Log folder details for debugging
      for (final entry in foldersWithVideos.entries) {
        debugPrint(
          'MediaStoreService: Folder "${entry.key}" has ${entry.value.length} videos',
        );
      }

      return foldersWithVideos;
    } catch (e) {
      debugPrint('MediaStoreService: Error during scan: $e');
      return await _fallbackScan();
    }
  }

  /// Fallback scanning method for when MediaStore fails
  static Future<Map<String, List<File>>> _fallbackScan() async {
    debugPrint('MediaStoreService: Using fallback scan method');
    final Map<String, List<File>> foldersWithVideos = {};

    try {
      // Get external storage directories
      final List<Directory> externalDirs = [];
      if (Platform.isAndroid) {
        // Try to get common external storage paths
        final paths = [
          '/storage/emulated/0',
          '/sdcard',
          '/storage/sdcard0',
          '/storage/sdcard1',
        ];

        for (final path in paths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            externalDirs.add(dir);
          }
        }
      }

      // Scan each external directory
      for (final externalDir in externalDirs) {
        await _scanDirectoryRecursive(externalDir, foldersWithVideos);
      }

      return foldersWithVideos;
    } catch (e) {
      debugPrint('MediaStoreService: Fallback scan failed: $e');
      return {};
    }
  }

  /// Recursively scans directory for video files (fallback method)
  static Future<void> _scanDirectoryRecursive(
    Directory dir,
    Map<String, List<File>> foldersWithVideos,
  ) async {
    try {
      // Skip system directories
      final path = dir.path;
      if (_shouldExcludePath(path)) {
        return;
      }

      final List<File> videosInFolder = [];
      final List<Directory> subdirectories = [];

      // List all entities in directory
      await for (final entity in dir.list()) {
        try {
          if (entity is File) {
            // Check if it's a video file
            if (_isVideoFile(entity.path)) {
              videosInFolder.add(entity);
            }
          } else if (entity is Directory) {
            subdirectories.add(entity);
          }
        } catch (e) {
          // Skip files/folders we can't access
          continue;
        }
      }

      // If this folder has videos, add it to our map
      if (videosInFolder.isNotEmpty) {
        foldersWithVideos[dir.path] = videosInFolder;
        debugPrint(
          'Fallback: Found ${videosInFolder.length} videos in: ${dir.path}',
        );
      }

      // Recursively scan subdirectories (limit depth to prevent infinite loops)
      if (path.split('/').length < 8) {
        for (final subdir in subdirectories) {
          await _scanDirectoryRecursive(subdir, foldersWithVideos);
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
    }
  }

  /// Checks if a path should be excluded from scanning
  static bool _shouldExcludePath(String path) {
    const excludedPaths = [
      '/Android/data',
      '/Android/obb',
      '/data',
      '/system',
      '/proc',
      '/dev',
      '/sys',
      '/cache',
      '/mnt/asec',
      '/mnt/obb',
      '/mnt/secure',
      '/storage/emulated/0/Android',
    ];

    for (final excludedPath in excludedPaths) {
      if (path.startsWith(excludedPath)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if file is a supported video format
  static bool _isVideoFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return _supportedVideoExtensions.contains(extension);
  }

  /// Checks storage permissions based on Android version
  static Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ (API 33+) uses READ_MEDIA_VIDEO
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status =
            await Permission.photos.status; // READ_MEDIA_VIDEO maps to photos
        return status.isGranted;
      }
      // Android 11-12 uses READ_EXTERNAL_STORAGE
      else {
        final status = await Permission.storage.status;
        return status.isGranted;
      }
    }
    return false;
  }

  /// Gets folder name from path
  static String getFolderName(String folderPath) {
    return folderPath.split('/').last;
  }

  /// Gets video count for folder
  static int getVideoCount(
    Map<String, List<File>> foldersWithVideos,
    String folderPath,
  ) {
    return foldersWithVideos[folderPath]?.length ?? 0;
  }

  /// Gets first video file from folder
  static File? getFirstVideo(
    Map<String, List<File>> foldersWithVideos,
    String folderPath,
  ) {
    final videos = foldersWithVideos[folderPath];
    if (videos != null && videos.isNotEmpty) {
      return videos.first;
    }
    return null;
  }

  /// Checks if cache is still valid
  static bool _isCacheValid() {
    if (_cachedFolders.isEmpty || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheTtl;
  }

  /// Creates a deep copy of folder map
  static Map<String, List<File>> _cloneFolderMap(
    Map<String, List<File>> source,
  ) {
    return source.map((key, value) => MapEntry(key, List<File>.from(value)));
  }
}
