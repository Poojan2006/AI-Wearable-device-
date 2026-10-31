class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  @override
  String toString() => "AppException[$code]: $message";
}

class BleException extends AppException {
  BleException(super.message, {super.code, super.details});
}

class AppDatabaseException extends AppException {
  AppDatabaseException(super.message, {super.code, super.details});
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.details});
}

class SyncException extends AppException {
  SyncException(super.message, {super.code, super.details});
}

class AiException extends AppException {
  AiException(super.message, {super.code, super.details});
}
