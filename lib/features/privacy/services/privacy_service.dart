import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _appLockPinKey = 'app_lock_pin';
  static const _appLockSaltKey = 'app_lock_salt';
  static const _biometricUnlockKey = 'app_lock_biometric';
  static const _hiddenVideosKey = 'hidden_videos';
  static const _privateFolderPathKey = 'private_folder_path';
  static const _privateManifestKey = 'private_folder_manifest';

  final SharedPreferences _prefs;
  final Random _secureRandom = Random.secure();

  PrivacyService(this._prefs);

  bool get isAppLockEnabled => _prefs.getBool(_appLockEnabledKey) ?? false;

  bool get isBiometricUnlockEnabled =>
      _prefs.getBool(_biometricUnlockKey) ?? false;

  bool get hasPinSet =>
      _prefs.containsKey(_appLockPinKey) && _prefs.containsKey(_appLockSaltKey);

  Future<void> setBiometricUnlockEnabled(bool value) async {
    await _prefs.setBool(_biometricUnlockKey, value);
  }

  Future<void> setAppLockEnabled(bool value) async {
    await _prefs.setBool(_appLockEnabledKey, value);
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _prefs.setString(_appLockSaltKey, salt);
    await _prefs.setString(_appLockPinKey, hash);
  }

  Future<void> clearPin() async {
    await _prefs.remove(_appLockSaltKey);
    await _prefs.remove(_appLockPinKey);
  }

  bool verifyPin(String pin) {
    final salt = _prefs.getString(_appLockSaltKey);
    final storedHash = _prefs.getString(_appLockPinKey);
    if (salt == null || storedHash == null) {
      return false;
    }
    final hash = _hashPin(pin, salt);
    return hash == storedHash;
  }

  List<String> getHiddenVideos() {
    return _prefs.getStringList(_hiddenVideosKey) ?? <String>[];
  }

  bool isVideoHidden(String path) {
    return getHiddenVideos().contains(path);
  }

  Future<void> hideVideo(String path) async {
    final hidden = getHiddenVideos().toSet();
    hidden.add(path);
    await _prefs.setStringList(_hiddenVideosKey, hidden.toList());
  }

  Future<void> unhideVideo(String path) async {
    final hidden = getHiddenVideos().toSet();
    hidden.remove(path);
    await _prefs.setStringList(_hiddenVideosKey, hidden.toList());
  }

  Future<void> clearHiddenVideos() async {
    await _prefs.remove(_hiddenVideosKey);
  }

  Future<String> ensurePrivateFolder() async {
    final existing = _prefs.getString(_privateFolderPathKey);
    if (existing != null) {
      final dir = Directory(existing);
      if (await dir.exists()) {
        return existing;
      }
    }

    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('Unable to access external storage');
    }

    final rootPath = externalDir.path.split('Android').first;
    final privateFolder = Directory(
      p.join(rootPath, 'A2Orbit Player', 'Private'),
    );
    if (!await privateFolder.exists()) {
      await privateFolder.create(recursive: true);
    }

    await _prefs.setString(_privateFolderPathKey, privateFolder.path);
    return privateFolder.path;
  }

  String? getPrivateFolderPath() => _prefs.getString(_privateFolderPathKey);

  Future<List<File>> listPrivateVideos() async {
    final folderPath = await ensurePrivateFolder();
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      return [];
    }
    final manifest = _loadPrivateManifest();
    final entries = dir
        .listSync()
        .whereType<File>()
        .where((file) => manifest.containsKey(file.path))
        .toList();
    return entries;
  }

  Future<File> moveToPrivateFolder(File file) async {
    final folderPath = await ensurePrivateFolder();
    final target = await _uniqueTargetFile(
      folderPath,
      file.uri.pathSegments.last,
    );
    final movedFile = await _moveFile(file, target);
    await hideVideo(movedFile.path);

    final manifest = _loadPrivateManifest();
    manifest[movedFile.path] = file.path;
    await _savePrivateManifest(manifest);

    return movedFile;
  }

  Future<File> restoreFromPrivateFolder(
    File file, {
    String? destinationDir,
  }) async {
    final manifest = _loadPrivateManifest();
    final originalPath = manifest[file.path];
    final targetDirectory =
        destinationDir ??
        (originalPath != null ? File(originalPath).parent.path : null) ??
        await _defaultRestoreDirectory();
    final preferredName = originalPath != null
        ? p.basename(originalPath)
        : file.uri.pathSegments.last;

    final target = await _uniqueTargetFile(targetDirectory, preferredName);
    final restoredFile = await _moveFile(file, target);

    final hidden = getHiddenVideos().toSet();
    hidden.remove(file.path);
    hidden.remove(restoredFile.path);
    await _prefs.setStringList(_hiddenVideosKey, hidden.toList());

    manifest.remove(file.path);
    await _savePrivateManifest(manifest);

    return restoredFile;
  }

  Future<void> deletePrivateVideo(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    final manifest = _loadPrivateManifest();
    manifest.remove(file.path);
    await _savePrivateManifest(manifest);

    final hidden = getHiddenVideos().toSet();
    hidden.remove(file.path);
    await _prefs.setStringList(_hiddenVideosKey, hidden.toList());
  }

  Future<File> _uniqueTargetFile(String directoryPath, String fileName) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final name = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = File(p.join(directoryPath, '$name$extension'));
    var counter = 1;

    while (await candidate.exists()) {
      candidate = File(p.join(directoryPath, '$name($counter)$extension'));
      counter++;
    }

    return candidate;
  }

  Future<File> _moveFile(File source, File target) async {
    try {
      return await source.rename(target.path);
    } catch (_) {
      final newFile = await source.copy(target.path);
      await source.delete();
      return newFile;
    }
  }

  Map<String, String> _loadPrivateManifest() {
    final json = _prefs.getString(_privateManifestKey);
    if (json == null) {
      return {};
    }
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic>
          ? decoded.map((key, value) => MapEntry(key, value.toString()))
          : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePrivateManifest(Map<String, String> manifest) async {
    await _prefs.setString(_privateManifestKey, jsonEncode(manifest));
  }

  Future<String> _defaultRestoreDirectory() async {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      return Directory.systemTemp.path;
    }
    final rootPath = externalDir.path.split('Android').first;
    final restoreDir = Directory(p.join(rootPath, 'Movies'));
    if (!await restoreDir.exists()) {
      await restoreDir.create(recursive: true);
    }
    return restoreDir.path;
  }

  String _generateSalt() {
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, String> getPrivateManifest() {
    return Map.unmodifiable(_loadPrivateManifest());
  }
}
