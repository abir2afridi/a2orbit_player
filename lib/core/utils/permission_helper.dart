import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    try {
      List<Permission> permissions = [];

      if (Platform.isAndroid) {
        // For Android 13+ (API 33+)
        permissions.addAll([
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ]);

        // For older Android versions
        permissions.add(Permission.storage);
      }

      final requestResults = await permissions.request();

      // Check if any permission was granted
      for (var permission in permissions) {
        if (requestResults[permission] == PermissionStatus.granted) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  static Future<bool> checkStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        // Check Android 13+ permissions first
        final photos = await Permission.photos.status;
        final videos = await Permission.videos.status;
        final audio = await Permission.audio.status;

        if (photos.isGranted || videos.isGranted || audio.isGranted) {
          return true;
        }

        // Check legacy storage permission
        final storage = await Permission.storage.status;
        return storage.isGranted;
      }

      return false;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
