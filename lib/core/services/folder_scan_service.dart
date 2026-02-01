import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FolderScanService {
  static const List<String> _supportedVideoExtensions = [
    '.mp4', '.mkv', '.avi', '.mov'
  ];

  static const List<String> _excludedPaths = [
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

  /// Scans device storage and returns only folders that contain video files
  /// Returns Map<folderPath, List<videoFiles>>
  static Future<Map<String, List<File>>> scanFoldersWithVideos() async {
    final Map<String, List<File>> foldersWithVideos = {};
    
    try {
      // Get external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return foldersWithVideos;

      // Start from root of external storage
      final storagePath = externalDir.path.split('Android')[0];
      final storageDir = Directory(storagePath);

      if (!await storageDir.exists()) {
        print('Storage directory not found: $storagePath');
        return foldersWithVideos;
      }

      print('Starting scan from: $storagePath');
      
      // Scan recursively but collect only folders with videos
      await _scanDirectoryRecursive(storageDir, foldersWithVideos);
      
      // Filter out parent folders that have subfolders with videos
      final filteredFolders = _filterLastLevelFolders(foldersWithVideos);
      
      print('Found ${filteredFolders.length} folders with videos');
      return filteredFolders;
      
    } catch (e) {
      print('Error scanning folders: $e');
      return foldersWithVideos;
    }
  }

  /// Recursively scans directory for video files
  static Future<void> _scanDirectoryRecursive(
    Directory dir,
    Map<String, List<File>> foldersWithVideos,
  ) async {
    try {
      // Skip excluded paths
      if (_shouldExcludePath(dir.path)) {
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
        print('Found ${videosInFolder.length} videos in: ${dir.path}');
      }

      // Recursively scan subdirectories
      for (final subdir in subdirectories) {
        await _scanDirectoryRecursive(subdir, foldersWithVideos);
      }
      
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  /// Filters out parent folders that have subfolders with videos
  /// Returns only the last-level folders (deepest folders with videos)
  static Map<String, List<File>> _filterLastLevelFolders(
    Map<String, List<File>> foldersWithVideos,
  ) {
    final Map<String, List<File>> lastLevelFolders = {};
    final List<String> folderPaths = foldersWithVideos.keys.toList();
    
    // Sort paths by length (longest first = deepest)
    folderPaths.sort((a, b) => b.length.compareTo(a.length));
    
    for (final folderPath in folderPaths) {
      bool isLastLevel = true;
      
      // Check if this folder is a parent of any other folder
      for (final otherPath in folderPaths) {
        if (otherPath != folderPath && otherPath.startsWith('$folderPath/')) {
          // This folder is a parent of another folder with videos
          isLastLevel = false;
          break;
        }
      }
      
      if (isLastLevel) {
        lastLevelFolders[folderPath] = foldersWithVideos[folderPath]!;
      }
    }
    
    return lastLevelFolders;
  }

  /// Checks if a path should be excluded from scanning
  static bool _shouldExcludePath(String path) {
    for (final excludedPath in _excludedPaths) {
      if (path.startsWith(excludedPath)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if file is a supported video format
  static bool _isVideoFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return _supportedVideoExtensions.contains('.$extension');
  }

  /// Gets folder name from path
  static String getFolderName(String folderPath) {
    return folderPath.split('/').last;
  }

  /// Gets video count for folder
  static int getVideoCount(Map<String, List<File>> foldersWithVideos, String folderPath) {
    return foldersWithVideos[folderPath]?.length ?? 0;
  }

  /// Gets first video file from folder for thumbnail
  static File? getFirstVideo(Map<String, List<File>> foldersWithVideos, String folderPath) {
    final videos = foldersWithVideos[folderPath];
    if (videos != null && videos.isNotEmpty) {
      return videos.first;
    }
    return null;
  }

  /// Requests necessary permissions
  static Future<bool> requestPermissions() async {
    try {
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }
}
