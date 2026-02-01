import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      if (await checkStoragePermissions()) {
        return true;
      }

      final permissionsToRequest = <Permission>[];

      final videosStatus = await Permission.videos.status;
      if (videosStatus.isDenied || videosStatus.isRestricted) {
        permissionsToRequest.add(Permission.videos);
      }

      final audioStatus = await Permission.audio.status;
      if (audioStatus.isDenied || audioStatus.isRestricted) {
        permissionsToRequest.add(Permission.audio);
      }

      final photosStatus = await Permission.photos.status;
      if (photosStatus.isDenied || photosStatus.isRestricted) {
        permissionsToRequest.add(Permission.photos);
      }

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied || storageStatus.isRestricted) {
        permissionsToRequest.add(Permission.storage);
      }

      if (permissionsToRequest.isNotEmpty) {
        bool granted = false;
        for (final permission in permissionsToRequest) {
          final result = await permission.request();
          if (result.isGranted || result.isLimited) {
            granted = true;
          }
        }

        if (granted && await checkStoragePermissions()) {
          return true;
        }
      }

      // Fallback for scoped storage (Android 11/12)
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) {
        return true;
      }

      if (manageStatus.isDenied || manageStatus.isRestricted) {
        final newStatus = await Permission.manageExternalStorage.request();
        if (newStatus.isGranted) {
          return true;
        }
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Error requesting permissions: $e\n$stackTrace');
      return false;
    }
  }

  static Future<bool> checkStoragePermissions() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final videos = await Permission.videos.status;
      final photos = await Permission.photos.status;
      final audio = await Permission.audio.status;
      final storage = await Permission.storage.status;
      final manage = await Permission.manageExternalStorage.status;

      return videos.isGranted ||
          photos.isGranted ||
          audio.isGranted ||
          storage.isGranted ||
          storage.isLimited ||
          manage.isGranted;
    } catch (e, stackTrace) {
      debugPrint('Error checking permissions: $e\n$stackTrace');
      return false;
    }
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
