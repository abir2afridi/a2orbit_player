import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
// Android-specific imports
import 'package:android/content.dart' as android_content;
import 'package:android/database.dart' as android_database;
import 'package:android/os.dart' as android_os;
import 'package:android/provider.dart' as android_provider;

/// MediaStore-based video discovery service for Android 11+
/// Replaces manual filesystem recursion with MediaStore queries
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

  /// Performs the actual MediaStore query
  static Future<Map<String, List<File>>> _performMediaStoreScan() async {
    final Map<String, List<File>> foldersWithVideos = {};

    try {
      if (!Platform.isAndroid) {
        debugPrint('MediaStoreService: Not on Android, returning empty result');
        return foldersWithVideos;
      }

      // Build the MediaStore query
      final uri = android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
      final projection = [
        android.provider.MediaStore.Video.Media._ID,
        android.provider.MediaStore.Video.Media.DATA,
        android.provider.MediaStore.Video.Media.RELATIVE_PATH,
        android.provider.MediaStore.Video.Media.BUCKET_ID,
        android.provider.MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
        android.provider.MediaStore.Video.Media.MIME_TYPE,
        android.provider.MediaStore.Video.Media.SIZE,
        android.provider.MediaStore.Video.Media.DATE_MODIFIED,
      ];

      // Build selection for supported video formats
      final selection = _buildMimeTypeSelection();

      debugPrint('MediaStoreService: Starting query...');

      // Query MediaStore
      final cursor = await android.database.ContentResolver.query(
        uri,
        projection,
        selection,
        null,
        '${android.provider.MediaStore.Video.Media.BUCKET_DISPLAY_NAME} ASC, ${android.provider.MediaStore.Video.Media.DISPLAY_NAME} ASC',
      );

      if (cursor == null) {
        debugPrint('MediaStoreService: Query returned null cursor');
        return foldersWithVideos;
      }

      debugPrint('MediaStoreService: Processing cursor...');

      // Process results
      while (await cursor.moveToNext()) {
        try {
          final dataIndex = cursor.getColumnIndex(
            android.provider.MediaStore.Video.Media.DATA,
          );
          final bucketIdIndex = cursor.getColumnIndex(
            android.provider.MediaStore.Video.Media.BUCKET_ID,
          );
          final bucketNameIndex = cursor.getColumnIndex(
            android.provider.MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
          );

          if (dataIndex == -1 || bucketIdIndex == -1 || bucketNameIndex == -1) {
            continue;
          }

          final data = await cursor.getString(dataIndex);
          final bucketId = await cursor.getString(bucketIdIndex);
          final bucketName = await cursor.getString(bucketNameIndex);

          if (data == null || bucketId == null || bucketName == null) {
            continue;
          }

          final file = File(data);

          // Verify file exists and is a video
          if (await file.exists() && _isVideoFile(file.path)) {
            // Use bucket path as key (folder path)
            final folderPath = file.parent.path;

            if (!foldersWithVideos.containsKey(folderPath)) {
              foldersWithVideos[folderPath] = [];
            }
            foldersWithVideos[folderPath]!.add(file);
          }
        } catch (e) {
          debugPrint('MediaStoreService: Error processing cursor row: $e');
          continue;
        }
      }

      await cursor.close();

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
      return foldersWithVideos;
    }
  }

  /// Builds MIME type selection for supported video formats
  static String _buildMimeTypeSelection() {
    final mimeTypes = _supportedVideoExtensions
        .map((ext) => 'video/$ext')
        .toList();
    final selection = mimeTypes
        .map(
          (mimeType) =>
              '${android.provider.MediaStore.Video.Media.MIME_TYPE} = ?',
        )
        .join(' OR ');
    return selection;
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
      if (await _isAndroid13OrHigher()) {
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

  /// Checks if Android version is 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      final deviceInfo = await android.os.Build.VERSION.SDK_INT;
      return deviceInfo >= 33;
    } catch (e) {
      debugPrint('MediaStoreService: Could not determine Android version: $e');
      return false;
    }
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
