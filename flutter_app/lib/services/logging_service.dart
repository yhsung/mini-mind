/// Logging service for comprehensive application logging
///
/// This service provides structured logging capabilities with support for
/// different log levels, file logging, and platform-specific optimizations.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Centralized logging service for the application
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static LoggingService get instance => _instance;

  Logger? _logger;
  LogOutput? _fileOutput;
  bool _isInitialized = false;

  /// Initialize the logging service
  Future<void> initialize({
    Level logLevel = Level.info,
    bool enableFileLogging = true,
    int maxLogFiles = 5,
  }) async {
    if (_isInitialized) return;

    final outputs = <LogOutput>[];

    // Always add console output
    outputs.add(ConsoleOutput());

    // Add file output if supported and enabled
    if (enableFileLogging && !kIsWeb) {
      try {
        _fileOutput = await _createFileOutput(maxLogFiles);
        outputs.add(_fileOutput!);
      } catch (e) {
        // If file logging fails, continue with console only
        if (kDebugMode) {
          print('Failed to initialize file logging: $e');
        }
      }
    }

    _logger = Logger(
      level: logLevel,
      printer: _createPrinter(),
      output: outputs.length == 1 ? outputs.first : MultiOutput(outputs),
      filter: _createFilter(),
    );

    _isInitialized = true;
  }

  /// Get the logger instance
  Logger get logger {
    if (!_isInitialized || _logger == null) {
      throw StateError('LoggingService must be initialized before use');
    }
    return _logger!;
  }

  /// Update log level at runtime
  void setLogLevel(Level level) {
    if (_logger != null) {
      _logger = Logger(
        level: level,
        printer: _logger!.printer,
        output: _logger!.output,
        filter: _logger!.filter,
      );
    }
  }

  /// Create appropriate printer based on platform and build mode
  LogPrinter _createPrinter() {
    if (kDebugMode) {
      return PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: !kIsWeb, // Colors don't work well in web console
        printEmojis: true,
        printTime: true,
        excludeBox: const {},
        excludePaths: ['package:flutter/'],
      );
    } else {
      // Production logging should be more compact
      return SimplePrinter(
        colors: false,
        printTime: true,
      );
    }
  }

  /// Create log filter for controlling what gets logged
  LogFilter _createFilter() {
    if (kDebugMode) {
      return DevelopmentFilter();
    } else {
      return ProductionFilter();
    }
  }

  /// Create file output for persistent logging
  Future<LogOutput> _createFileOutput(int maxLogFiles) async {
    final directory = await getApplicationSupportDirectory();
    final logDir = Directory(path.join(directory.path, 'logs'));

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return AdvancedFileOutput(
      path: path.join(logDir.path, 'app.log'),
      maxLogFiles: maxLogFiles,
    );
  }

  /// Clear all log files
  Future<void> clearLogFiles() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationSupportDirectory();
      final logDir = Directory(path.join(directory.path, 'logs'));

      if (await logDir.exists()) {
        final files = await logDir.list().toList();
        for (final file in files) {
          if (file is File && file.path.endsWith('.log')) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear log files: $e');
      }
    }
  }

  /// Get log files for sharing/debugging
  Future<List<File>> getLogFiles() async {
    if (kIsWeb) return [];

    try {
      final directory = await getApplicationSupportDirectory();
      final logDir = Directory(path.join(directory.path, 'logs'));

      if (!await logDir.exists()) return [];

      final files = await logDir.list().toList();
      return files.whereType<File>().where((file) => file.path.endsWith('.log')).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get log files: $e');
      }
      return [];
    }
  }

  /// Get recent logs as string (useful for error reporting)
  Future<String> getRecentLogsAsString({int maxLines = 100}) async {
    if (kIsWeb) return 'Log files not available on web';

    try {
      final logFiles = await getLogFiles();
      if (logFiles.isEmpty) return 'No log files found';

      // Get the most recent log file
      logFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final recentFile = logFiles.first;

      final lines = await recentFile.readAsLines();
      final recentLines = lines.length > maxLines ? lines.skip(lines.length - maxLines) : lines;

      return recentLines.join('\n');
    } catch (e) {
      return 'Failed to read log files: $e';
    }
  }
}

/// Advanced file output with rotation and size management
class AdvancedFileOutput extends LogOutput {
  AdvancedFileOutput({
    required this.path,
    this.maxLogFiles = 5,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
  });

  final String path;
  final int maxLogFiles;
  final int maxFileSize;

  File? _file;

  @override
  void output(OutputEvent event) {
    try {
      _file ??= File(path);

      final logString = event.lines.join('\n');

      // Check if file rotation is needed
      if (_file!.existsSync() && _file!.lengthSync() > maxFileSize) {
        _rotateLogFiles();
      }

      // Write to file
      _file!.writeAsStringSync(
        '$logString\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to write to log file: $e');
      }
    }
  }

  /// Rotate log files when size limit is reached
  void _rotateLogFiles() {
    try {
      final directory = Directory(path.substring(0, path.lastIndexOf('/')));
      final baseName = path.substring(path.lastIndexOf('/') + 1);
      final nameWithoutExtension = baseName.substring(0, baseName.lastIndexOf('.'));
      final extension = baseName.substring(baseName.lastIndexOf('.'));

      // Rotate existing files
      for (int i = maxLogFiles - 1; i > 0; i--) {
        final oldFile = File('${directory.path}/$nameWithoutExtension.$i$extension');
        final newFile = File('${directory.path}/$nameWithoutExtension.${i + 1}$extension');

        if (oldFile.existsSync()) {
          if (newFile.existsSync()) {
            newFile.deleteSync();
          }
          oldFile.renameSync(newFile.path);
        }
      }

      // Move current file to .1
      if (_file!.existsSync()) {
        final rotatedFile = File('${directory.path}/$nameWithoutExtension.1$extension');
        if (rotatedFile.existsSync()) {
          rotatedFile.deleteSync();
        }
        _file!.renameSync(rotatedFile.path);
      }

      // Create new current file
      _file = File(path);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to rotate log files: $e');
      }
    }
  }
}

/// Simple printer for production builds
class SimplePrinter extends LogPrinter {
  SimplePrinter({
    this.colors = false,
    this.printTime = true,
  });

  final bool colors;
  final bool printTime;

  @override
  List<String> log(LogEvent event) {
    final color = colors ? _getColor(event.level) : '';
    final reset = colors ? '\x1b[0m' : '';
    final time = printTime ? '[${DateTime.now().toIso8601String()}] ' : '';
    final level = '[${event.level.name.toUpperCase()}] ';

    return ['$color$time$level${event.message}$reset'];
  }

  String _getColor(Level level) {
    switch (level) {
      case Level.verbose:
        return '\x1b[90m'; // Bright black
      case Level.debug:
        return '\x1b[36m'; // Cyan
      case Level.info:
        return '\x1b[32m'; // Green
      case Level.warning:
        return '\x1b[33m'; // Yellow
      case Level.error:
        return '\x1b[31m'; // Red
      case Level.wtf:
        return '\x1b[35m'; // Magenta
      default:
        return '';
    }
  }
}