/// Centralized logging utility for the mindmap application
///
/// Provides structured logging with different levels and platform-specific
/// output handling for debugging and production monitoring.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as logger_lib;

/// Logging levels for message categorization
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  wtf, // What a Terrible Failure
}

/// Application logger singleton
class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  static Logger get instance => _instance;

  late logger_lib.Logger _logger;
  bool _isInitialized = false;

  /// Initialize the logger with configuration
  void initialize({
    LogLevel level = kDebugMode ? LogLevel.debug : LogLevel.info,
    bool enableFileLogging = false,
  }) {
    if (_isInitialized) return;

    _logger = logger_lib.Logger(
      level: _mapLogLevel(level),
      printer: logger_lib.PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );

    _isInitialized = true;
  }

  /// Log verbose message
  void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log debug message
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log critical failure message
  void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Ensure logger is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }

  /// Map application log level to logger library level
  logger_lib.Level _mapLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return logger_lib.Level.trace;
      case LogLevel.debug:
        return logger_lib.Level.debug;
      case LogLevel.info:
        return logger_lib.Level.info;
      case LogLevel.warning:
        return logger_lib.Level.warning;
      case LogLevel.error:
        return logger_lib.Level.error;
      case LogLevel.wtf:
        return logger_lib.Level.fatal;
    }
  }
}