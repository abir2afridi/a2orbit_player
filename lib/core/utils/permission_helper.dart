import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionStatusDetail {
  final String title;
  final String description;
  final bool granted;

  const PermissionStatusDetail({
    required this.title,
    required this.description,
    required this.granted,
  });
}

class _PermissionDescriptor {
  final Permission permission;
  final String title;
  final String description;

  const _PermissionDescriptor(this.permission, this.title, this.description);
}

class PermissionHelper {
  static const List<_PermissionDescriptor> _requiredPermissions = [
    _PermissionDescriptor(
      Permission.videos,
      'Read Videos',
      'Required on Android 13+ to access your offline video library.',
    ),
    _PermissionDescriptor(
      Permission.storage,
      'Legacy Storage Access',
      'Needed on Android 12 and below to browse offline videos.',
    ),
  ];

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static int? _cachedAndroidSdkInt;

  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      if (await checkStoragePermissions()) {
        return true;
      }

      final permissions = await _resolveStoragePermissions();
      bool hasAnyGrant = false;

      for (final permission in permissions) {
        final status = await permission.status;
        if (_isGranted(status)) {
          hasAnyGrant = true;
          continue;
        }

        final result = await permission.request();
        if (_isGranted(result)) {
          hasAnyGrant = true;
        }
      }

      if (hasAnyGrant) {
        return true;
      }

      return await checkStoragePermissions();
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
      final permissions = await _resolveStoragePermissions(
        includeFallback: true,
      );

      for (final permission in permissions) {
        final status = await permission.status;
        if (_isGranted(status)) {
          return true;
        }
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Error checking permissions: $e\n$stackTrace');
      return false;
    }
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  static Future<List<PermissionStatusDetail>>
  getPermissionStatusDetails() async {
    final List<PermissionStatusDetail> statuses = [];

    for (final descriptor in _requiredPermissions) {
      try {
        final status = await descriptor.permission.status;
        final granted = _isGranted(status);
        statuses.add(
          PermissionStatusDetail(
            title: descriptor.title,
            description: descriptor.description,
            granted: granted,
          ),
        );
      } catch (e) {
        debugPrint('Error reading ${descriptor.permission}: $e');
        statuses.add(
          PermissionStatusDetail(
            title: descriptor.title,
            description: descriptor.description,
            granted: false,
          ),
        );
      }
    }

    return statuses;
  }

  static bool _isGranted(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  static Future<List<Permission>> _resolveStoragePermissions({
    bool includeFallback = false,
  }) async {
    final sdkInt = await _androidSdkInt();

    if (sdkInt != null) {
      if (sdkInt >= 33) {
        return includeFallback
            ? [Permission.videos, Permission.storage]
            : [Permission.videos];
      }
      return [Permission.storage];
    }

    // If we cannot determine the SDK version, include both to be safe for checks
    return includeFallback
        ? [Permission.videos, Permission.storage]
        : [Permission.videos];
  }

  static Future<int?> _androidSdkInt() async {
    if (_cachedAndroidSdkInt != null) {
      return _cachedAndroidSdkInt;
    }

    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      _cachedAndroidSdkInt = androidInfo.version.sdkInt;
      return _cachedAndroidSdkInt;
    } catch (e) {
      debugPrint('Error reading Android SDK version: $e');
      return null;
    }
  }
}
