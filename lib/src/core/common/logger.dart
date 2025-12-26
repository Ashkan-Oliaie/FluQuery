import 'dart:developer' as developer;

/// Log level for FluQuery
enum LogLevel {
  none,
  error,
  warn,
  info,
  debug,
}

/// Logger for FluQuery
class FluQueryLogger {
  static LogLevel level = LogLevel.warn;

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (level.index >= LogLevel.debug.index) {
      developer.log(
        message,
        name: 'FluQuery',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (level.index >= LogLevel.info.index) {
      developer.log(
        message,
        name: 'FluQuery',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void warn(String message, [Object? error, StackTrace? stackTrace]) {
    if (level.index >= LogLevel.warn.index) {
      developer.log(
        message,
        name: 'FluQuery',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (level.index >= LogLevel.error.index) {
      developer.log(
        message,
        name: 'FluQuery',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
