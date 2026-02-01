import 'dart:async';

class AppUtils {
  // Format duration in milliseconds to readable string
  static String formatDuration(int milliseconds) {
    if (milliseconds < 0) return '00:00';

    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Format file size to readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Get file extension from file path
  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  // Check if file is video based on extension
  static bool isVideoFile(String filePath) {
    final extension = getFileExtension(filePath);
    const videoExtensions = [
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      'm4v',
      '3gp',
    ];
    return videoExtensions.contains(extension);
  }

  // Check if file is audio based on extension
  static bool isAudioFile(String filePath) {
    final extension = getFileExtension(filePath);
    const audioExtensions = ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'];
    return audioExtensions.contains(extension);
  }

  // Check if file is subtitle based on extension
  static bool isSubtitleFile(String filePath) {
    final extension = getFileExtension(filePath);
    const subtitleExtensions = ['srt', 'ass', 'ssa', 'vtt'];
    return subtitleExtensions.contains(extension);
  }

  // Get file name from full path
  static String getFileName(String filePath) {
    return filePath.split('/').last.split('\\').last;
  }

  // Get file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    final fileName = getFileName(filePath);
    final lastDotIndex = fileName.lastIndexOf('.');
    return lastDotIndex != -1 ? fileName.substring(0, lastDotIndex) : fileName;
  }

  // Format date for display
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    }
  }

  // Validate PIN
  static bool isValidPin(String pin) {
    return pin.length >= 4 && pin.length <= 6 && RegExp(r'^\d+$').hasMatch(pin);
  }

  // Generate random ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Debounce function
  static Function debounce(Function func, Duration delay) {
    Timer? timer;
    return () {
      if (timer != null) timer!.cancel();
      timer = Timer(delay, () => func());
    };
  }

  // Throttle function
  static Function throttle(Function func, Duration delay) {
    bool isThrottled = false;
    return () {
      if (!isThrottled) {
        func();
        isThrottled = true;
        Future.delayed(delay, () => isThrottled = false);
      }
    };
  }
}
