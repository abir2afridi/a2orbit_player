class AppExceptions implements Exception {
  final String message;
  final String? code;
  final dynamic details;
  
  const AppExceptions(this.message, {this.code, this.details});
  
  @override
  String toString() => 'AppException: $message';
}

class PlayerException extends AppExceptions {
  const PlayerException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class FileException extends AppExceptions {
  const FileException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class StorageException extends AppExceptions {
  const StorageException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class PermissionException extends AppExceptions {
  const PermissionException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class NetworkException extends AppExceptions {
  const NetworkException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class SecurityException extends AppExceptions {
  const SecurityException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}
