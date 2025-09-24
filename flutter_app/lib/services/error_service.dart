/// Error tracking and reporting service
///
/// This service provides comprehensive error tracking, reporting, and
/// user-friendly error handling throughout the application.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Centralized error tracking service
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  static ErrorService get instance => _instance;

  final Logger _logger = Logger();
  final List<ErrorReport> _pendingReports = [];
  bool _isInitialized = false;

  /// Initialize the error service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // In a production app, you would initialize error tracking services here
    // such as Firebase Crashlytics, Sentry, Bugsnag, etc.

    _isInitialized = true;
  }

  /// Report an error with optional context
  Future<void> reportError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, dynamic>? context,
    String? userId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final errorReport = ErrorReport(
      error: error,
      stackTrace: stackTrace,
      fatal: fatal,
      timestamp: DateTime.now(),
      context: context ?? {},
      userId: userId,
      platform: _getPlatformInfo(),
    );

    // Log the error locally
    _logError(errorReport);

    // Store for potential upload
    _pendingReports.add(errorReport);

    // In production, send to error tracking service
    if (kReleaseMode) {
      await _sendErrorReport(errorReport);
    }

    // Save to local storage for offline reporting
    await _saveErrorReportLocally(errorReport);
  }

  /// Report a user-facing error with user-friendly message
  Future<void> reportUserError(
    String userMessage,
    Object technicalError, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    await reportError(
      technicalError,
      stackTrace,
      context: {
        'userMessage': userMessage,
        ...?context,
      },
    );
  }

  /// Report a performance issue
  Future<void> reportPerformanceIssue(
    String operation,
    Duration duration, {
    Map<String, dynamic>? context,
  }) async {
    await reportError(
      PerformanceException(operation, duration),
      null,
      context: context,
    );
  }

  /// Get recent error reports for debugging
  List<ErrorReport> getRecentErrors({int limit = 50}) {
    return _pendingReports.take(limit).toList();
  }

  /// Clear all stored error reports
  void clearErrorReports() {
    _pendingReports.clear();
  }

  /// Get error statistics
  ErrorStatistics getErrorStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final lastWeek = now.subtract(const Duration(days: 7));

    final errors24h = _pendingReports.where((e) => e.timestamp.isAfter(last24Hours)).length;
    final errorsWeek = _pendingReports.where((e) => e.timestamp.isAfter(lastWeek)).length;
    final fatalErrors = _pendingReports.where((e) => e.fatal).length;

    return ErrorStatistics(
      totalErrors: _pendingReports.length,
      errorsLast24Hours: errors24h,
      errorsLastWeek: errorsWeek,
      fatalErrors: fatalErrors,
    );
  }

  void _logError(ErrorReport report) {
    if (report.fatal) {
      _logger.e(
        'FATAL ERROR: ${report.error}',
        error: report.error,
        stackTrace: report.stackTrace,
      );
    } else {
      _logger.w(
        'ERROR: ${report.error}',
        error: report.error,
        stackTrace: report.stackTrace,
      );
    }
  }

  Future<void> _sendErrorReport(ErrorReport report) async {
    try {
      // In a real app, this would send to your error tracking service
      // For example, with Firebase Crashlytics:
      // await FirebaseCrashlytics.instance.recordError(
      //   report.error,
      //   report.stackTrace,
      //   fatal: report.fatal,
      // );

      // For now, we'll just log that we would send it
      _logger.d('Would send error report to tracking service: ${report.error}');
    } catch (e) {
      _logger.e('Failed to send error report: $e');
    }
  }

  Future<void> _saveErrorReportLocally(ErrorReport report) async {
    if (kIsWeb) return; // File system not available on web

    try {
      final directory = await getApplicationSupportDirectory();
      final errorDir = Directory(path.join(directory.path, 'errors'));

      if (!await errorDir.exists()) {
        await errorDir.create(recursive: true);
      }

      final fileName = 'error_${report.timestamp.millisecondsSinceEpoch}.json';
      final file = File(path.join(errorDir.path, fileName));

      final json = report.toJson();
      await file.writeAsString(jsonEncode(json));

      // Clean up old error files (keep only last 100)
      await _cleanUpOldErrorFiles(errorDir);
    } catch (e) {
      _logger.e('Failed to save error report locally: $e');
    }
  }

  Future<void> _cleanUpOldErrorFiles(Directory errorDir) async {
    try {
      final files = await errorDir.list().where((entity) => entity is File).cast<File>().toList();

      if (files.length > 100) {
        // Sort by last modified date and delete oldest files
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        for (int i = 100; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      _logger.e('Failed to clean up old error files: $e');
    }
  }

  Map<String, dynamic> _getPlatformInfo() {
    return {
      'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
      'version': kIsWeb ? 'Unknown' : Platform.operatingSystemVersion,
      'isDebug': kDebugMode,
      'isProfile': kProfileMode,
      'isRelease': kReleaseMode,
    };
  }
}

/// Error report data structure
class ErrorReport {
  const ErrorReport({
    required this.error,
    required this.stackTrace,
    required this.fatal,
    required this.timestamp,
    required this.context,
    required this.platform,
    this.userId,
  });

  final Object error;
  final StackTrace? stackTrace;
  final bool fatal;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final Map<String, dynamic> platform;
  final String? userId;

  Map<String, dynamic> toJson() {
    return {
      'error': error.toString(),
      'stackTrace': stackTrace?.toString(),
      'fatal': fatal,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'platform': platform,
      'userId': userId,
    };
  }

  factory ErrorReport.fromJson(Map<String, dynamic> json) {
    return ErrorReport(
      error: json['error'] as String,
      stackTrace: json['stackTrace'] != null
          ? StackTrace.fromString(json['stackTrace'] as String)
          : null,
      fatal: json['fatal'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      context: Map<String, dynamic>.from(json['context'] as Map),
      platform: Map<String, dynamic>.from(json['platform'] as Map),
      userId: json['userId'] as String?,
    );
  }
}

/// Error statistics for monitoring and debugging
class ErrorStatistics {
  const ErrorStatistics({
    required this.totalErrors,
    required this.errorsLast24Hours,
    required this.errorsLastWeek,
    required this.fatalErrors,
  });

  final int totalErrors;
  final int errorsLast24Hours;
  final int errorsLastWeek;
  final int fatalErrors;

  @override
  String toString() {
    return 'ErrorStatistics('
        'total: $totalErrors, '
        'last24h: $errorsLast24Hours, '
        'lastWeek: $errorsLastWeek, '
        'fatal: $fatalErrors'
        ')';
  }
}

/// Custom exception for performance issues
class PerformanceException implements Exception {
  const PerformanceException(this.operation, this.duration);

  final String operation;
  final Duration duration;

  @override
  String toString() {
    return 'PerformanceException: $operation took ${duration.inMilliseconds}ms';
  }
}

/// Custom exception for user-facing errors
class UserFacingException implements Exception {
  const UserFacingException(this.userMessage, this.technicalDetails);

  final String userMessage;
  final String technicalDetails;

  @override
  String toString() {
    return 'UserFacingException: $userMessage (Technical: $technicalDetails)';
  }
}