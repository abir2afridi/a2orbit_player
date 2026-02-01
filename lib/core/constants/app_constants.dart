class AppConstants {
  // App Info
  static const String appName = 'A2Orbit Player';
  static const String appVersion = '1.0.0';
  
  // Storage
  static const String dbName = 'a2orbit_player.db';
  static const String preferencesKey = 'a2orbit_preferences';
  static const String recentVideosKey = 'recent_videos';
  static const String settingsKey = 'app_settings';
  
  // Video Formats
  static const List<String> supportedVideoFormats = [
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.3gp'
  ];
  
  // Audio Formats
  static const List<String> supportedAudioFormats = [
    '.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma'
  ];
  
  // Subtitle Formats
  static const List<String> supportedSubtitleFormats = [
    '.srt', '.ass', '.ssa', '.vtt'
  ];
  
  // Player Settings
  static const double defaultPlaybackSpeed = 1.0;
  static const double minPlaybackSpeed = 0.25;
  static const double maxPlaybackSpeed = 3.0;
  static const int defaultSeekDuration = 10000; // 10 seconds
  static const int fastSeekDuration = 30000; // 30 seconds
  
  // UI Settings
  static const int controlsHideDelay = 3000; // 3 seconds
  static const double defaultVolume = 1.0;
  static const double defaultBrightness = 0.5;
  
  // File System
  static const String hiddenFolderPrefix = '.';
  static const int maxRecentVideos = 50;
  
  // Security
  static const int maxPinAttempts = 5;
  static const Duration pinLockDuration = Duration(minutes: 5);
  
  // PiP Settings
  static const double pipDefaultWidth = 240.0;
  static const double pipDefaultHeight = 135.0;
  static const double pipMinWidth = 120.0;
  static const double pipMinHeight = 67.5;
}
