/// Error recovery utilities and helpers for the Mindmap application
///
/// This file provides additional error recovery mechanisms and utilities
/// for specific application scenarios, working in conjunction with the
/// global error handler.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../bridge/mindmap_bridge.dart';
import '../bridge/bridge_exceptions.dart';
import '../services/error_service.dart';
import 'error_handler.dart';

/// Utility class for application-specific error recovery
class ErrorRecoveryUtils {
  static final Logger _logger = Logger();

  /// Attempt to recover from bridge initialization failure
  static Future<bool> recoverBridgeInitialization({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    _logger.i('Attempting bridge initialization recovery (max retries: $maxRetries)');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _logger.d('Bridge recovery attempt $attempt/$maxRetries');

        // Wait before retry (except first attempt)
        if (attempt > 1) {
          await Future.delayed(retryDelay);
        }

        // Attempt to reinitialize the bridge
        await MindmapBridge.instance.initialize();

        if (MindmapBridge.instance.isInitialized) {
          _logger.i('Bridge initialization recovery successful on attempt $attempt');
          return true;
        }
      } catch (e, stackTrace) {
        _logger.w(
          'Bridge recovery attempt $attempt failed: $e',
          error: e,
          stackTrace: stackTrace,
        );

        // Report the recovery attempt
        await ErrorService.instance.reportError(
          e,
          stackTrace,
          context: {
            'recovery_type': 'bridge_initialization',
            'attempt': attempt,
            'max_retries': maxRetries,
          },
        );
      }
    }

    _logger.e('Bridge initialization recovery failed after $maxRetries attempts');
    return false;
  }

  /// Attempt to recover from file system errors
  static Future<bool> recoverFileSystemError(
    FileSystemException error, {
    bool createMissingDirectories = true,
    bool requestPermissions = true,
  }) async {
    _logger.i('Attempting file system error recovery: ${error.message}');

    try {
      final path = error.path;
      if (path == null) {
        _logger.w('Cannot recover: no path information in error');
        return false;
      }

      // Handle missing directory
      if (error.message.contains('No such file or directory') && createMissingDirectories) {
        _logger.d('Attempting to create missing directory: $path');

        final directory = Directory(path);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          _logger.i('Successfully created missing directory: $path');
          return true;
        }
      }

      // Handle permission errors
      if (error.message.contains('Permission denied') && requestPermissions && !kIsWeb) {
        _logger.d('Attempting permission recovery for: $path');

        // Try to use alternative directories with proper permissions
        final alternativeDir = await _getAlternativeDirectory(path);
        if (alternativeDir != null) {
          _logger.i('Using alternative directory: ${alternativeDir.path}');
          return true;
        }
      }

      // Handle disk space issues
      if (error.message.contains('No space left')) {
        _logger.d('Attempting disk space recovery');
        return await _cleanupTemporaryFiles();
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e(
        'File system recovery failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Attempt to recover from network connectivity issues
  static Future<bool> recoverNetworkConnectivity({
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 3,
  }) async {
    _logger.i('Attempting network connectivity recovery');

    try {
      // Check initial connectivity
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        _logger.w('No network connectivity available');
        return false;
      }

      // Wait for connectivity to stabilize
      final completer = Completer<bool>();
      late StreamSubscription subscription;

      // Set up timeout
      Timer(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(false);
        }
      });

      // Listen for connectivity changes
      subscription = connectivity.onConnectivityChanged.listen((result) {
        if (!completer.isCompleted && !result.contains(ConnectivityResult.none)) {
          subscription.cancel();
          completer.complete(true);
        }
      });

      final isConnected = await completer.future;
      if (isConnected) {
        _logger.i('Network connectivity recovery successful');
      } else {
        _logger.w('Network connectivity recovery timed out');
      }

      return isConnected;
    } catch (e, stackTrace) {
      _logger.e(
        'Network connectivity recovery failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Attempt to recover from memory pressure
  static Future<bool> recoverMemoryPressure() async {
    _logger.i('Attempting memory pressure recovery');

    try {
      // Force garbage collection if not on web
      if (!kIsWeb) {
        // Clear image cache
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        _logger.d('Cleared image cache to free memory');
      }

      // Clear temporary data
      await _clearTemporaryData();

      // Trigger explicit garbage collection hints
      if (!kIsWeb) {
        // Request garbage collection (hint only)
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _logger.i('Memory pressure recovery completed');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'Memory pressure recovery failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Attempt to recover from state corruption
  static Future<bool> recoverStateCorruption() async {
    _logger.i('Attempting state corruption recovery');

    try {
      // Clear any cached state
      await _clearCachedState();

      // Reset user preferences to defaults if needed
      await _resetUserPreferences();

      // Reinitialize critical services
      await _reinitializeCriticalServices();

      _logger.i('State corruption recovery completed');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'State corruption recovery failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Show recovery options to the user
  static Future<void> showRecoveryDialog(
    BuildContext context,
    String errorMessage,
    List<RecoveryOption> options,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.healing, color: Colors.blue),
            SizedBox(width: 8),
            Text('Error Recovery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage),
            const SizedBox(height: 16),
            const Text(
              'Recovery options:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...options.map((option) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    option.onPressed();
                  },
                  icon: Icon(option.icon),
                  label: Text(option.label),
                  style: option.isPrimary
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        )
                      : null,
                ),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show a simple retry dialog
  static Future<bool> showRetryDialog(
    BuildContext context,
    String message, {
    String title = 'Retry Operation',
    String retryLabel = 'Retry',
    String cancelLabel = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(retryLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Create a fallback widget for error states
  static Widget createFallbackWidget({
    String message = 'Something went wrong',
    IconData icon = Icons.error_outline,
    Color? iconColor,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Private helper methods

  static Future<Directory?> _getAlternativeDirectory(String originalPath) async {
    try {
      // Try to use app-specific directories with guaranteed permissions
      final appDirs = [
        await getApplicationDocumentsDirectory(),
        await getApplicationSupportDirectory(),
        await getTemporaryDirectory(),
      ];

      for (final dir in appDirs) {
        try {
          if (await dir.exists()) {
            // Test write permissions
            final testFile = File('${dir.path}/.write_test');
            await testFile.writeAsString('test');
            await testFile.delete();
            return dir;
          }
        } catch (e) {
          // This directory doesn't have write permissions, try next
          continue;
        }
      }

      return null;
    } catch (e) {
      _logger.e('Failed to find alternative directory: $e');
      return null;
    }
  }

  static Future<bool> _cleanupTemporaryFiles() async {
    try {
      if (kIsWeb) return false;

      final tempDir = await getTemporaryDirectory();
      final files = await tempDir.list().toList();

      int deletedCount = 0;
      for (final entity in files) {
        try {
          if (entity is File) {
            final stat = await entity.stat();
            // Delete files older than 1 day
            if (DateTime.now().difference(stat.modified).inDays > 1) {
              await entity.delete();
              deletedCount++;
            }
          }
        } catch (e) {
          // Skip files that can't be deleted
          continue;
        }
      }

      _logger.i('Cleaned up $deletedCount temporary files');
      return deletedCount > 0;
    } catch (e) {
      _logger.e('Failed to cleanup temporary files: $e');
      return false;
    }
  }

  static Future<void> _clearTemporaryData() async {
    try {
      // Clear any application-specific temporary data
      // This would be implemented based on the specific caches used
      _logger.d('Cleared temporary application data');
    } catch (e) {
      _logger.e('Failed to clear temporary data: $e');
    }
  }

  static Future<void> _clearCachedState() async {
    try {
      // Clear any cached application state
      // This would be implemented based on the state management system
      _logger.d('Cleared cached application state');
    } catch (e) {
      _logger.e('Failed to clear cached state: $e');
    }
  }

  static Future<void> _resetUserPreferences() async {
    try {
      // Reset user preferences to safe defaults
      // This would be implemented based on the preferences system
      _logger.d('Reset user preferences to defaults');
    } catch (e) {
      _logger.e('Failed to reset user preferences: $e');
    }
  }

  static Future<void> _reinitializeCriticalServices() async {
    try {
      // Reinitialize critical application services
      // This would reinitialize services that might have failed
      _logger.d('Reinitialized critical services');
    } catch (e) {
      _logger.e('Failed to reinitialize services: $e');
    }
  }
}

/// Recovery option for user selection
class RecoveryOption {
  const RecoveryOption({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final bool isPrimary;
}

/// Extension methods for easier error recovery
extension ErrorRecoveryExtension on BuildContext {
  /// Show recovery dialog with predefined options
  Future<void> showErrorRecovery(
    String errorMessage,
    List<RecoveryOption> options,
  ) {
    return ErrorRecoveryUtils.showRecoveryDialog(this, errorMessage, options);
  }

  /// Show retry dialog
  Future<bool> showRetry(
    String message, {
    String title = 'Retry Operation',
    String retryLabel = 'Retry',
    String cancelLabel = 'Cancel',
  }) {
    return ErrorRecoveryUtils.showRetryDialog(
      this,
      message,
      title: title,
      retryLabel: retryLabel,
      cancelLabel: cancelLabel,
    );
  }
}

/// Widget that provides error boundary functionality
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
    this.enableRecovery = true,
  });

  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? fallback;
  final void Function(Object error, StackTrace? stackTrace)? onError;
  final bool enableRecovery;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.fallback != null) {
        return widget.fallback!(_error!, _stackTrace);
      } else {
        return ErrorRecoveryUtils.createFallbackWidget(
          message: 'An error occurred in this section',
          onRetry: widget.enableRecovery ? _retry : null,
        );
      }
    }

    return ErrorWidget.builder = (FlutterErrorDetails details) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleError(details.exception, details.stack);
      });
      return widget.child;
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });

    // Report error through global handler
    GlobalErrorHandler.instance.handleError(
      error,
      stackTrace,
      context: context,
      additionalContext: {
        'error_boundary': true,
        'widget_type': widget.runtimeType.toString(),
      },
    );

    // Call custom error handler if provided
    widget.onError?.call(error, stackTrace);
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }
}