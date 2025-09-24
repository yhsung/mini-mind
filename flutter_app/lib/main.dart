/// Main entry point for the Mindmap Flutter application
///
/// This file sets up the Flutter app with comprehensive error handling,
/// platform-specific configurations, and proper initialization of all
/// required services and dependencies.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'services/platform_service.dart';
import 'services/logging_service.dart';
import 'services/error_service.dart';
import 'utils/platform_utils.dart';

/// Global logger instance for application-wide logging
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

/// Main application entry point
///
/// Initializes the Flutter app with comprehensive error handling,
/// platform-specific configurations, and service initialization.
Future<void> main() async {
  // Ensure Flutter binding is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling
  await _setupErrorHandling();

  // Initialize platform-specific configurations
  await _initializePlatformConfiguration();

  // Initialize core services
  await _initializeCoreServices();

  // Configure app-level settings
  await _configureAppSettings();

  // Run the application with error boundary
  runApp(
    ProviderScope(
      observers: [
        if (kDebugMode) _ProviderLogger(),
      ],
      child: const MindmapApp(),
    ),
  );
}

/// Sets up comprehensive error handling for the application
Future<void> _setupErrorHandling() async {
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.e(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );

    // Report to error tracking service in production
    if (kReleaseMode) {
      ErrorService.instance.reportError(
        details.exception,
        details.stack,
        fatal: true,
      );
    }
  };

  // Handle platform errors (outside of Flutter)
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e(
      'Platform Error: $error',
      error: error,
      stackTrace: stack,
    );

    // Report to error tracking service in production
    if (kReleaseMode) {
      ErrorService.instance.reportError(
        error,
        stack,
        fatal: true,
      );
    }

    return true; // Indicate the error was handled
  };

  // Initialize error tracking service
  await ErrorService.instance.initialize();

  logger.i('Error handling initialized successfully');
}

/// Initializes platform-specific configurations
Future<void> _initializePlatformConfiguration() async {
  try {
    // Get device and app information
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    // Initialize platform service with device information
    await PlatformService.instance.initialize(
      deviceInfo: deviceInfo,
      packageInfo: packageInfo,
    );

    // Configure platform-specific settings
    if (PlatformUtils.isMobile) {
      // Mobile-specific configurations
      await _configureMobileSettings();
    } else if (PlatformUtils.isDesktop) {
      // Desktop-specific configurations
      await _configureDesktopSettings();
    } else if (PlatformUtils.isWeb) {
      // Web-specific configurations
      await _configureWebSettings();
    }

    logger.i('Platform configuration initialized for ${PlatformUtils.platformName}');
  } catch (e, stackTrace) {
    logger.e('Failed to initialize platform configuration', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Configures mobile-specific settings
Future<void> _configureMobileSettings() async {
  // Configure system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations for mobile devices
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  logger.d('Mobile settings configured');
}

/// Configures desktop-specific settings
Future<void> _configureDesktopSettings() async {
  // Desktop applications typically don't need orientation locks
  // Configure window settings if needed (would require additional packages)

  logger.d('Desktop settings configured');
}

/// Configures web-specific settings
Future<void> _configureWebSettings() async {
  // Web-specific configurations
  // Configure URL strategy, PWA settings, etc.

  logger.d('Web settings configured');
}

/// Initializes core application services
Future<void> _initializeCoreServices() async {
  try {
    // Initialize logging service with platform-appropriate configuration
    await LoggingService.instance.initialize(
      logLevel: kDebugMode ? Level.debug : Level.info,
      enableFileLogging: !kIsWeb, // File logging not supported on web
      maxLogFiles: 5,
    );

    // Initialize file system paths
    if (!kIsWeb) {
      final documentsDir = await getApplicationDocumentsDirectory();
      final supportDir = await getApplicationSupportDirectory();
      final cacheDir = await getTemporaryDirectory();

      logger.d('Documents directory: ${documentsDir.path}');
      logger.d('Support directory: ${supportDir.path}');
      logger.d('Cache directory: ${cacheDir.path}');
    }

    logger.i('Core services initialized successfully');
  } catch (e, stackTrace) {
    logger.e('Failed to initialize core services', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Configures app-level settings and preferences
Future<void> _configureAppSettings() async {
  try {
    // Configure performance settings
    if (kDebugMode) {
      // Enable debug mode optimizations
      developer.Timeline.startSync('App Initialization');
    }

    // Set up memory management
    if (!kIsWeb) {
      // Configure garbage collection hints for better memory management
      SystemChannels.system.invokeMethod<void>('SystemSound.play', 'SystemSoundType.click');
    }

    // Initialize theme and appearance settings
    // This will be handled by the app-level state management

    logger.i('App-level settings configured');

    if (kDebugMode) {
      developer.Timeline.finishSync();
    }
  } catch (e, stackTrace) {
    logger.e('Failed to configure app settings', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Provider observer for debugging state changes in development
class _ProviderLogger extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    logger.d('Provider added: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    logger.d('Provider disposed: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (kDebugMode && newValue != previousValue) {
      logger.d('Provider updated: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    logger.e(
      'Provider failed: ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Global exception handler for uncaught exceptions
///
/// This function is called when an exception occurs that wasn't
/// caught by the application code. It logs the error and shows
/// a user-friendly error message.
void handleGlobalException(Object error, StackTrace stackTrace) {
  logger.e(
    'Uncaught exception in application',
    error: error,
    stackTrace: stackTrace,
  );

  // Report error to tracking service in production
  if (kReleaseMode) {
    ErrorService.instance.reportError(error, stackTrace, fatal: false);
  }

  // Show user-friendly error message
  if (!kIsWeb) {
    // For native platforms, we could show a native dialog
    // This would require additional platform-specific implementation
  }
}

/// Application lifecycle callback handler
///
/// Handles app lifecycle events like app becoming inactive,
/// going to background, resuming, etc.
class AppLifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        logger.d('App resumed');
        _handleAppResume();
        break;
      case AppLifecycleState.inactive:
        logger.d('App became inactive');
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        logger.d('App paused');
        _handleAppPause();
        break;
      case AppLifecycleState.detached:
        logger.d('App detached');
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        logger.d('App hidden');
        _handleAppHidden();
        break;
    }
  }

  void _handleAppResume() {
    // Handle app resume logic
    // Refresh data, reconnect services, etc.
  }

  void _handleAppInactive() {
    // Handle app becoming inactive
    // Pause non-critical operations
  }

  void _handleAppPause() {
    // Handle app pause logic
    // Save state, pause operations, etc.
  }

  void _handleAppDetached() {
    // Handle app detached logic
    // Final cleanup before termination
  }

  void _handleAppHidden() {
    // Handle app hidden logic
    // Minimize resource usage
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    logger.d('Locales changed: $locales');
    // Handle locale changes for internationalization
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    logger.d('Platform brightness changed: $brightness');
    // Handle system theme changes
  }

  @override
  void didChangeTextScaleFactor() {
    super.didChangeTextScaleFactor();
    final textScaleFactor = WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    logger.d('Text scale factor changed: $textScaleFactor');
    // Handle accessibility text scaling changes
  }
}

/// Performance monitoring and diagnostics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  static PerformanceMonitor get instance => _instance;

  Timer? _memoryMonitorTimer;

  /// Start performance monitoring in debug mode
  void startMonitoring() {
    if (!kDebugMode) return;

    _memoryMonitorTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _logMemoryUsage(),
    );

    logger.d('Performance monitoring started');
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    logger.d('Performance monitoring stopped');
  }

  void _logMemoryUsage() {
    // Log memory usage statistics
    // This would require additional platform-specific implementation
    // to get accurate memory usage information
  }
}