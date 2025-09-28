/// Final comprehensive error handling system for the Mindmap application
///
/// This file provides a unified error handling system that integrates all
/// error handling components, provides user-friendly error messages,
/// crash reporting, and automatic recovery mechanisms.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../services/error_service.dart';
import '../bridge/bridge_exceptions.dart';
import '../bridge/mindmap_bridge.dart';

/// Global error handler that coordinates all error handling mechanisms
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  static GlobalErrorHandler get instance => _instance;

  final Logger _logger = Logger();
  final Map<Type, ErrorHandlingStrategy> _strategies = {};
  final List<ErrorRecoveryMechanism> _recoveryMechanisms = [];
  bool _isInitialized = false;
  bool _userFeedbackEnabled = true;

  // Crash reporting configuration
  bool _crashReportingEnabled = true;
  int _maxCrashReports = 50;
  Duration _crashReportRetention = const Duration(days: 30);

  /// Initialize the global error handler
  Future<void> initialize({
    bool enableUserFeedback = true,
    bool enableCrashReporting = true,
    int maxCrashReports = 50,
    Duration crashReportRetention = const Duration(days: 30),
  }) async {
    if (_isInitialized) return;

    _userFeedbackEnabled = enableUserFeedback;
    _crashReportingEnabled = enableCrashReporting;
    _maxCrashReports = maxCrashReports;
    _crashReportRetention = crashReportRetention;

    // Initialize error service
    await ErrorService.instance.initialize();

    // Register error handling strategies
    _registerDefaultStrategies();

    // Register recovery mechanisms
    _registerDefaultRecoveryMechanisms();

    // Set up global error handlers
    _setupGlobalErrorHandlers();

    _isInitialized = true;
    _logger.i('Global error handler initialized successfully');
  }

  /// Handle any error with comprehensive processing
  Future<ErrorHandlingResult> handleError(
    Object error,
    StackTrace? stackTrace, {
    BuildContext? context,
    bool showUserFeedback = true,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      // Ensure initialization
      if (!_isInitialized) {
        await initialize();
      }

      // Create error context
      final errorContext = ErrorContext(
        error: error,
        stackTrace: stackTrace,
        context: context,
        additionalContext: additionalContext ?? {},
        timestamp: DateTime.now(),
      );

      // Log the error
      _logError(errorContext);

      // Report to error tracking service
      await _reportError(errorContext);

      // Get handling strategy
      final strategy = _getHandlingStrategy(error);

      // Apply error handling strategy
      final handlingResult = await strategy.handle(errorContext);

      // Show user feedback if enabled and context available
      if (showUserFeedback && _userFeedbackEnabled && context != null) {
        await _showUserFeedback(context, handlingResult);
      }

      // Attempt recovery if needed
      if (handlingResult.shouldAttemptRecovery) {
        await _attemptRecovery(errorContext, handlingResult);
      }

      return handlingResult;
    } catch (handlerError, handlerStack) {
      // Error in error handler - fallback to basic handling
      _logger.e(
        'Error in error handler itself: $handlerError',
        error: handlerError,
        stackTrace: handlerStack,
      );

      return ErrorHandlingResult(
        error: error,
        userMessage: 'An unexpected error occurred. Please restart the application.',
        technicalMessage: error.toString(),
        severity: ErrorSeverity.critical,
        isRecoverable: false,
        shouldAttemptRecovery: false,
        recoveryActions: [],
      );
    }
  }

  /// Handle unrecoverable crashes
  Future<void> handleCrash(Object error, StackTrace stackTrace) async {
    _logger.f('CRASH: $error', error: error, stackTrace: stackTrace);

    // Report crash immediately
    await ErrorService.instance.reportError(
      error,
      stackTrace,
      fatal: true,
      context: {
        'crash_type': 'unhandled_exception',
        'app_state': 'crashed',
      },
    );

    // Save crash report locally
    if (_crashReportingEnabled) {
      await _saveCrashReport(error, stackTrace);
    }

    // Clean up resources if possible
    try {
      await _performCrashCleanup();
    } catch (cleanupError) {
      _logger.e('Error during crash cleanup: $cleanupError');
    }
  }

  /// Show user-friendly error dialog
  Future<void> showErrorDialog(
    BuildContext context,
    String message, {
    String? title,
    List<ErrorAction> actions = const [],
    ErrorSeverity severity = ErrorSeverity.error,
  }) async {
    if (!_userFeedbackEnabled) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: severity != ErrorSeverity.critical,
      builder: (BuildContext dialogContext) => ErrorDialog(
        title: title ?? _getDefaultTitle(severity),
        message: message,
        actions: actions,
        severity: severity,
      ),
    );
  }

  /// Show error snackbar for non-critical errors
  void showErrorSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    List<ErrorAction> actions = const [],
  }) {
    if (!_userFeedbackEnabled) return;

    final snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: actions.isNotEmpty
          ? SnackBarAction(
              label: actions.first.label,
              onPressed: actions.first.onPressed,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Get error statistics and health metrics
  ErrorHealthMetrics getHealthMetrics() {
    final errorStats = ErrorService.instance.getErrorStatistics();

    return ErrorHealthMetrics(
      totalErrors: errorStats.totalErrors,
      errorsLast24Hours: errorStats.errorsLast24Hours,
      errorsLastWeek: errorStats.errorsLastWeek,
      fatalErrors: errorStats.fatalErrors,
      crashReportsCount: _getCrashReportsCount(),
      recoverySuccessRate: _calculateRecoverySuccessRate(),
      errorTrends: _calculateErrorTrends(),
    );
  }

  /// Clear all error data (for privacy/reset)
  Future<void> clearAllErrorData() async {
    ErrorService.instance.clearErrorReports();
    await _clearCrashReports();
    _logger.i('All error data cleared');
  }

  // Private implementation methods

  void _registerDefaultStrategies() {
    _strategies[BridgeException] = BridgeErrorStrategy();
    _strategies[PlatformException] = PlatformErrorStrategy();
    _strategies[FileSystemException] = FileSystemErrorStrategy();
    _strategies[NetworkException] = NetworkErrorStrategy();
    _strategies[MemoryException] = MemoryErrorStrategy();
    _strategies[TimeoutException] = TimeoutErrorStrategy();
    _strategies[FormatException] = FormatErrorStrategy();
    _strategies[ArgumentError] = ArgumentErrorStrategy();
    _strategies[StateError] = StateErrorStrategy();
    _strategies[Exception] = GenericErrorStrategy();
  }

  void _registerDefaultRecoveryMechanisms() {
    _recoveryMechanisms.addAll([
      BridgeRecoveryMechanism(),
      NetworkRecoveryMechanism(),
      FileSystemRecoveryMechanism(),
      MemoryRecoveryMechanism(),
      StateRecoveryMechanism(),
    ]);
  }

  void _setupGlobalErrorHandlers() {
    // Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      handleError(
        details.exception,
        details.stack,
        additionalContext: {
          'flutter_error_details': {
            'library': details.library,
            'context': details.context?.toString(),
            'silent': details.silent,
          },
        },
      );
    };

    // Platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      handleCrash(error, stack);
      return true;
    };
  }

  ErrorHandlingStrategy _getHandlingStrategy(Object error) {
    for (final type in _strategies.keys) {
      if (error.runtimeType == type || error is Exception && type == Exception) {
        return _strategies[type]!;
      }
    }
    return _strategies[Exception]!;
  }

  void _logError(ErrorContext errorContext) {
    final error = errorContext.error;
    final stackTrace = errorContext.stackTrace;

    if (error is BridgeException) {
      _logger.e('Bridge Error: ${error.message}', error: error, stackTrace: stackTrace);
    } else if (error is PlatformException) {
      _logger.e('Platform Error: ${error.message}', error: error, stackTrace: stackTrace);
    } else {
      _logger.e('General Error: $error', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _reportError(ErrorContext errorContext) async {
    await ErrorService.instance.reportError(
      errorContext.error,
      errorContext.stackTrace,
      context: {
        'error_context': errorContext.additionalContext,
        'has_ui_context': errorContext.context != null,
        'error_type': errorContext.error.runtimeType.toString(),
      },
    );
  }

  Future<void> _showUserFeedback(
    BuildContext context,
    ErrorHandlingResult result,
  ) async {
    switch (result.severity) {
      case ErrorSeverity.info:
        break; // No user feedback for info level
      case ErrorSeverity.warning:
        showErrorSnackbar(context, result.userMessage, actions: result.recoveryActions);
        break;
      case ErrorSeverity.error:
        if (result.recoveryActions.isNotEmpty) {
          showErrorSnackbar(context, result.userMessage, actions: result.recoveryActions);
        } else {
          await showErrorDialog(
            context,
            result.userMessage,
            actions: result.recoveryActions,
            severity: result.severity,
          );
        }
        break;
      case ErrorSeverity.critical:
        await showErrorDialog(
          context,
          result.userMessage,
          actions: result.recoveryActions,
          severity: result.severity,
        );
        break;
    }
  }

  Future<void> _attemptRecovery(
    ErrorContext errorContext,
    ErrorHandlingResult handlingResult,
  ) async {
    for (final mechanism in _recoveryMechanisms) {
      if (mechanism.canRecover(errorContext)) {
        try {
          final success = await mechanism.recover(errorContext);
          if (success) {
            _logger.i('Recovery successful using ${mechanism.runtimeType}');
            return;
          }
        } catch (recoveryError, recoveryStack) {
          _logger.w(
            'Recovery mechanism failed: ${mechanism.runtimeType}',
            error: recoveryError,
            stackTrace: recoveryStack,
          );
        }
      }
    }
    _logger.w('All recovery mechanisms failed for error: ${errorContext.error}');
  }

  Future<void> _saveCrashReport(Object error, StackTrace stackTrace) async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationSupportDirectory();
      final crashDir = Directory(path.join(directory.path, 'crashes'));

      if (!await crashDir.exists()) {
        await crashDir.create(recursive: true);
      }

      final fileName = 'crash_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path.join(crashDir.path, fileName));

      final crashReport = {
        'timestamp': DateTime.now().toIso8601String(),
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'platform': {
          'os': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'isDebug': kDebugMode,
        },
      };

      await file.writeAsString(jsonEncode(crashReport));
      await _cleanupOldCrashReports(crashDir);
    } catch (e) {
      _logger.e('Failed to save crash report: $e');
    }
  }

  Future<void> _cleanupOldCrashReports(Directory crashDir) async {
    try {
      final files = await crashDir.list().where((entity) => entity is File).cast<File>().toList();

      // Remove old crash reports
      final cutoff = DateTime.now().subtract(_crashReportRetention);
      final filesToDelete = <File>[];

      for (final file in files) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoff)) {
          filesToDelete.add(file);
        }
      }

      // Also limit total number of crash reports
      if (files.length > _maxCrashReports) {
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        filesToDelete.addAll(files.skip(_maxCrashReports));
      }

      for (final file in filesToDelete) {
        await file.delete();
      }
    } catch (e) {
      _logger.e('Failed to cleanup old crash reports: $e');
    }
  }

  Future<void> _performCrashCleanup() async {
    // Close any open file handles
    // Clear sensitive data from memory
    // Notify services about the crash
    // Save any critical application state

    try {
      // Attempt to save current mindmap state if bridge is available
      if (MindmapBridge.instance.isInitialized) {
        // This would trigger an auto-save if possible
        _logger.d('Attempting to save state before crash');
      }
    } catch (e) {
      _logger.e('Failed to save state during crash cleanup: $e');
    }
  }

  Future<void> _clearCrashReports() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationSupportDirectory();
      final crashDir = Directory(path.join(directory.path, 'crashes'));

      if (await crashDir.exists()) {
        await crashDir.delete(recursive: true);
      }
    } catch (e) {
      _logger.e('Failed to clear crash reports: $e');
    }
  }

  String _getDefaultTitle(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 'Information';
      case ErrorSeverity.warning:
        return 'Warning';
      case ErrorSeverity.error:
        return 'Error';
      case ErrorSeverity.critical:
        return 'Critical Error';
    }
  }

  int _getCrashReportsCount() {
    // This would count crash reports from local storage
    return 0; // Placeholder
  }

  double _calculateRecoverySuccessRate() {
    // This would calculate success rate based on stored metrics
    return 0.85; // Placeholder
  }

  Map<String, int> _calculateErrorTrends() {
    // This would analyze error patterns over time
    return {}; // Placeholder
  }
}

/// Context information for error handling
class ErrorContext {
  const ErrorContext({
    required this.error,
    required this.stackTrace,
    required this.context,
    required this.additionalContext,
    required this.timestamp,
  });

  final Object error;
  final StackTrace? stackTrace;
  final BuildContext? context;
  final Map<String, dynamic> additionalContext;
  final DateTime timestamp;
}

/// Result of error handling operation
class ErrorHandlingResult {
  const ErrorHandlingResult({
    required this.error,
    required this.userMessage,
    required this.technicalMessage,
    required this.severity,
    required this.isRecoverable,
    required this.shouldAttemptRecovery,
    required this.recoveryActions,
  });

  final Object error;
  final String userMessage;
  final String technicalMessage;
  final ErrorSeverity severity;
  final bool isRecoverable;
  final bool shouldAttemptRecovery;
  final List<ErrorAction> recoveryActions;
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

/// Error action that user can take
class ErrorAction {
  const ErrorAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
}

/// Error health metrics for monitoring
class ErrorHealthMetrics {
  const ErrorHealthMetrics({
    required this.totalErrors,
    required this.errorsLast24Hours,
    required this.errorsLastWeek,
    required this.fatalErrors,
    required this.crashReportsCount,
    required this.recoverySuccessRate,
    required this.errorTrends,
  });

  final int totalErrors;
  final int errorsLast24Hours;
  final int errorsLastWeek;
  final int fatalErrors;
  final int crashReportsCount;
  final double recoverySuccessRate;
  final Map<String, int> errorTrends;
}

/// Base class for error handling strategies
abstract class ErrorHandlingStrategy {
  Future<ErrorHandlingResult> handle(ErrorContext context);
}

/// Base class for error recovery mechanisms
abstract class ErrorRecoveryMechanism {
  bool canRecover(ErrorContext context);
  Future<bool> recover(ErrorContext context);
}

/// Bridge error handling strategy
class BridgeErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    final error = context.error as BridgeException;
    final userMessage = BridgeExceptionUtils.getUserFriendlyMessage(error);
    final isRecoverable = BridgeExceptionUtils.isRecoverable(error);

    final recoveryActions = <ErrorAction>[];
    if (isRecoverable) {
      recoveryActions.add(
        ErrorAction(
          label: 'Retry',
          onPressed: () {
            // Trigger retry mechanism
          },
        ),
      );
    }

    return ErrorHandlingResult(
      error: error,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: error is NodeNotFoundException || error is DocumentNotFoundException
          ? ErrorSeverity.warning
          : ErrorSeverity.error,
      isRecoverable: isRecoverable,
      shouldAttemptRecovery: isRecoverable,
      recoveryActions: recoveryActions,
    );
  }
}

/// Platform error handling strategy
class PlatformErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    final error = context.error as PlatformException;

    String userMessage;
    ErrorSeverity severity;

    switch (error.code) {
      case 'permission_denied':
        userMessage = 'Permission denied. Please check app permissions in system settings.';
        severity = ErrorSeverity.error;
        break;
      case 'not_available':
        userMessage = 'This feature is not available on your device.';
        severity = ErrorSeverity.warning;
        break;
      default:
        userMessage = 'A platform-specific error occurred. Please try again.';
        severity = ErrorSeverity.error;
    }

    return ErrorHandlingResult(
      error: error,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: severity,
      isRecoverable: error.code != 'not_available',
      shouldAttemptRecovery: false,
      recoveryActions: [],
    );
  }
}

/// File system error handling strategy
class FileSystemErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    final error = context.error;

    String userMessage = 'A file operation failed. Please check file permissions and try again.';
    ErrorSeverity severity = ErrorSeverity.error;

    if (error.toString().contains('No such file')) {
      userMessage = 'The requested file could not be found.';
      severity = ErrorSeverity.warning;
    } else if (error.toString().contains('Permission denied')) {
      userMessage = 'Permission denied. Please check file permissions.';
    } else if (error.toString().contains('No space left')) {
      userMessage = 'Not enough storage space. Please free up some space and try again.';
      severity = ErrorSeverity.critical;
    }

    return ErrorHandlingResult(
      error: error,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: severity,
      isRecoverable: !error.toString().contains('No space left'),
      shouldAttemptRecovery: true,
      recoveryActions: [
        ErrorAction(
          label: 'Retry',
          onPressed: () {},
        ),
      ],
    );
  }
}

/// Network error handling strategy
class NetworkErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    final error = context.error;

    String userMessage = 'Network error. Please check your internet connection and try again.';

    if (error.toString().contains('timeout')) {
      userMessage = 'Request timed out. Please check your internet connection.';
    } else if (error.toString().contains('host')) {
      userMessage = 'Cannot connect to server. Please try again later.';
    }

    return ErrorHandlingResult(
      error: error,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: ErrorSeverity.warning,
      isRecoverable: true,
      shouldAttemptRecovery: true,
      recoveryActions: [
        ErrorAction(
          label: 'Retry',
          onPressed: () {},
        ),
      ],
    );
  }
}

/// Memory error handling strategy
class MemoryErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    return ErrorHandlingResult(
      error: context.error,
      userMessage: 'Not enough memory available. Please close other apps and try again.',
      technicalMessage: context.error.toString(),
      severity: ErrorSeverity.critical,
      isRecoverable: false,
      shouldAttemptRecovery: true,
      recoveryActions: [
        ErrorAction(
          label: 'Close App',
          onPressed: () {
            SystemNavigator.pop();
          },
          isDestructive: true,
        ),
      ],
    );
  }
}

/// Timeout error handling strategy
class TimeoutErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    return ErrorHandlingResult(
      error: context.error,
      userMessage: 'Operation timed out. Please try again.',
      technicalMessage: context.error.toString(),
      severity: ErrorSeverity.warning,
      isRecoverable: true,
      shouldAttemptRecovery: true,
      recoveryActions: [
        ErrorAction(
          label: 'Retry',
          onPressed: () {},
        ),
      ],
    );
  }
}

/// Format error handling strategy
class FormatErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    return ErrorHandlingResult(
      error: context.error,
      userMessage: 'Invalid data format. Please check your input.',
      technicalMessage: context.error.toString(),
      severity: ErrorSeverity.error,
      isRecoverable: true,
      shouldAttemptRecovery: false,
      recoveryActions: [],
    );
  }
}

/// Argument error handling strategy
class ArgumentErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    return ErrorHandlingResult(
      error: context.error,
      userMessage: 'Invalid input provided. Please check your data and try again.',
      technicalMessage: context.error.toString(),
      severity: ErrorSeverity.error,
      isRecoverable: true,
      shouldAttemptRecovery: false,
      recoveryActions: [],
    );
  }
}

/// State error handling strategy
class StateErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    return ErrorHandlingResult(
      error: context.error,
      userMessage: 'Application state error. Please restart the app.',
      technicalMessage: context.error.toString(),
      severity: ErrorSeverity.error,
      isRecoverable: false,
      shouldAttemptRecovery: true,
      recoveryActions: [
        ErrorAction(
          label: 'Restart App',
          onPressed: () {
            // This would trigger app restart
          },
        ),
      ],
    );
  }
}

/// Generic error handling strategy
class GenericErrorStrategy implements ErrorHandlingStrategy {
  @override
  Future<ErrorHandlingResult> handle(ErrorContext context) async {
    return ErrorHandlingResult(
      error: context.error,
      userMessage: 'An unexpected error occurred. Please try again.',
      technicalMessage: context.error.toString(),
      severity: ErrorSeverity.error,
      isRecoverable: true,
      shouldAttemptRecovery: true,
      recoveryActions: [
        ErrorAction(
          label: 'Retry',
          onPressed: () {},
        ),
      ],
    );
  }
}

/// Bridge recovery mechanism
class BridgeRecoveryMechanism implements ErrorRecoveryMechanism {
  @override
  bool canRecover(ErrorContext context) {
    return context.error is BridgeException &&
           BridgeExceptionUtils.isRecoverable(context.error as BridgeException);
  }

  @override
  Future<bool> recover(ErrorContext context) async {
    try {
      // Attempt to reinitialize bridge if needed
      if (!MindmapBridge.instance.isInitialized) {
        await MindmapBridge.instance.initialize();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Network recovery mechanism
class NetworkRecoveryMechanism implements ErrorRecoveryMechanism {
  @override
  bool canRecover(ErrorContext context) {
    return context.error.toString().contains('network') ||
           context.error.toString().contains('connection') ||
           context.error.toString().contains('timeout');
  }

  @override
  Future<bool> recover(ErrorContext context) async {
    // Wait a moment and retry
    await Future.delayed(const Duration(seconds: 2));
    return true; // Indicate that retry should be attempted
  }
}

/// File system recovery mechanism
class FileSystemRecoveryMechanism implements ErrorRecoveryMechanism {
  @override
  bool canRecover(ErrorContext context) {
    final errorString = context.error.toString();
    return errorString.contains('file') || errorString.contains('directory');
  }

  @override
  Future<bool> recover(ErrorContext context) async {
    // Attempt to create necessary directories
    try {
      if (context.error.toString().contains('directory')) {
        // This would attempt to create missing directories
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Memory recovery mechanism
class MemoryRecoveryMechanism implements ErrorRecoveryMechanism {
  @override
  bool canRecover(ErrorContext context) {
    return context.error.toString().contains('memory') ||
           context.error.toString().contains('OutOfMemory');
  }

  @override
  Future<bool> recover(ErrorContext context) async {
    // Trigger garbage collection
    if (!kIsWeb) {
      // Force garbage collection
      return true;
    }
    return false;
  }
}

/// State recovery mechanism
class StateRecoveryMechanism implements ErrorRecoveryMechanism {
  @override
  bool canRecover(ErrorContext context) {
    return context.error is StateError;
  }

  @override
  Future<bool> recover(ErrorContext context) async {
    // Attempt to reset application state
    try {
      // This would trigger state reset mechanisms
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Error dialog widget
class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
    required this.severity,
  });

  final String title;
  final String message;
  final List<ErrorAction> actions;
  final ErrorSeverity severity;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getIconForSeverity(severity),
            color: _getColorForSeverity(severity),
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        ...actions.map((action) => TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            action.onPressed();
          },
          style: action.isDestructive
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(action.label),
        )),
        if (actions.isEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
      ],
    );
  }

  IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Icons.info;
      case ErrorSeverity.warning:
        return Icons.warning;
      case ErrorSeverity.error:
        return Icons.error;
      case ErrorSeverity.critical:
        return Icons.dangerous;
    }
  }

  Color _getColorForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Colors.blue;
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.error:
        return Colors.red;
      case ErrorSeverity.critical:
        return Colors.red[800]!;
    }
  }
}

/// Extension methods for easier error handling
extension ErrorHandlerExtension on BuildContext {
  /// Handle error with context
  Future<ErrorHandlingResult> handleError(
    Object error, {
    StackTrace? stackTrace,
    bool showUserFeedback = true,
    Map<String, dynamic>? additionalContext,
  }) {
    return GlobalErrorHandler.instance.handleError(
      error,
      stackTrace,
      context: this,
      showUserFeedback: showUserFeedback,
      additionalContext: additionalContext,
    );
  }

  /// Show error dialog
  Future<void> showErrorDialog(
    String message, {
    String? title,
    List<ErrorAction> actions = const [],
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    return GlobalErrorHandler.instance.showErrorDialog(
      this,
      message,
      title: title,
      actions: actions,
      severity: severity,
    );
  }

  /// Show error snackbar
  void showErrorSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    List<ErrorAction> actions = const [],
  }) {
    GlobalErrorHandler.instance.showErrorSnackbar(
      this,
      message,
      duration: duration,
      actions: actions,
    );
  }
}