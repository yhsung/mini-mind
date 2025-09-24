/// Platform service for handling platform-specific functionality
///
/// This service provides a unified interface for accessing platform-specific
/// features and information across different platforms (mobile, desktop, web).

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Platform service singleton for managing platform-specific operations
class PlatformService {
  static final PlatformService _instance = PlatformService._internal();
  factory PlatformService() => _instance;
  PlatformService._internal();

  static PlatformService get instance => _instance;

  DeviceInfoPlugin? _deviceInfo;
  PackageInfo? _packageInfo;
  late PlatformInfo _platformInfo;

  bool _isInitialized = false;

  /// Initialize the platform service with device and package information
  Future<void> initialize({
    required DeviceInfoPlugin deviceInfo,
    required PackageInfo packageInfo,
  }) async {
    if (_isInitialized) return;

    _deviceInfo = deviceInfo;
    _packageInfo = packageInfo;

    // Gather platform-specific information
    _platformInfo = await _gatherPlatformInfo();

    _isInitialized = true;
  }

  /// Get current platform information
  PlatformInfo get platformInfo {
    if (!_isInitialized) {
      throw StateError('PlatformService must be initialized before use');
    }
    return _platformInfo;
  }

  /// Get app package information
  PackageInfo get packageInfo {
    if (!_isInitialized || _packageInfo == null) {
      throw StateError('PlatformService must be initialized before use');
    }
    return _packageInfo!;
  }

  /// Check if running on mobile platform
  bool get isMobile => kIsWeb ? false : (Platform.isAndroid || Platform.isIOS);

  /// Check if running on desktop platform
  bool get isDesktop => kIsWeb ? false : (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Check if running on web platform
  bool get isWeb => kIsWeb;

  /// Get platform name as string
  String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Check if dark mode is supported
  bool get supportsDarkMode => !kIsWeb || _platformInfo.supportsSystemTheme;

  /// Check if file system access is available
  bool get supportsFileSystem => !kIsWeb;

  /// Check if native dialogs are supported
  bool get supportsNativeDialogs => !kIsWeb;

  /// Gather comprehensive platform information
  Future<PlatformInfo> _gatherPlatformInfo() async {
    if (kIsWeb) {
      return PlatformInfo(
        platform: 'Web',
        version: 'Unknown',
        deviceModel: 'Web Browser',
        supportsSystemTheme: true,
        supportsFileAccess: false,
        supportsNativeDialogs: false,
        memoryLimitMB: null,
        screenDensity: 1.0,
      );
    }

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo!.androidInfo;
        return PlatformInfo(
          platform: 'Android',
          version: androidInfo.version.release,
          deviceModel: '${androidInfo.manufacturer} ${androidInfo.model}',
          supportsSystemTheme: androidInfo.version.sdkInt >= 29, // Android 10+
          supportsFileAccess: true,
          supportsNativeDialogs: true,
          memoryLimitMB: _estimateAndroidMemoryLimit(androidInfo),
          screenDensity: androidInfo.displayMetrics.density,
        );
      }

      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo!.iosInfo;
        return PlatformInfo(
          platform: 'iOS',
          version: iosInfo.systemVersion,
          deviceModel: iosInfo.model,
          supportsSystemTheme: _iosSupportsSystemTheme(iosInfo.systemVersion),
          supportsFileAccess: true,
          supportsNativeDialogs: true,
          memoryLimitMB: _estimateIosMemoryLimit(iosInfo.model),
          screenDensity: 1.0, // iOS handles density automatically
        );
      }

      if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo!.windowsInfo;
        return PlatformInfo(
          platform: 'Windows',
          version: windowsInfo.displayVersion,
          deviceModel: windowsInfo.computerName,
          supportsSystemTheme: _windowsSupportsSystemTheme(windowsInfo.buildNumber),
          supportsFileAccess: true,
          supportsNativeDialogs: true,
          memoryLimitMB: null, // Windows manages memory dynamically
          screenDensity: 1.0,
        );
      }

      if (Platform.isMacOS) {
        final macInfo = await _deviceInfo!.macOsInfo;
        return PlatformInfo(
          platform: 'macOS',
          version: macInfo.osRelease,
          deviceModel: macInfo.model,
          supportsSystemTheme: _macosSupportsSystemTheme(macInfo.majorVersion),
          supportsFileAccess: true,
          supportsNativeDialogs: true,
          memoryLimitMB: null, // macOS manages memory dynamically
          screenDensity: 1.0,
        );
      }

      if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo!.linuxInfo;
        return PlatformInfo(
          platform: 'Linux',
          version: linuxInfo.version ?? 'Unknown',
          deviceModel: linuxInfo.name,
          supportsSystemTheme: true, // Most modern Linux desktops support this
          supportsFileAccess: true,
          supportsNativeDialogs: true,
          memoryLimitMB: null, // Linux manages memory dynamically
          screenDensity: 1.0,
        );
      }
    } catch (e) {
      // Fallback for when device info cannot be retrieved
      return PlatformInfo(
        platform: platformName,
        version: 'Unknown',
        deviceModel: 'Unknown',
        supportsSystemTheme: !kIsWeb,
        supportsFileAccess: !kIsWeb,
        supportsNativeDialogs: !kIsWeb,
        memoryLimitMB: null,
        screenDensity: 1.0,
      );
    }

    // Fallback
    return PlatformInfo(
      platform: 'Unknown',
      version: 'Unknown',
      deviceModel: 'Unknown',
      supportsSystemTheme: false,
      supportsFileAccess: false,
      supportsNativeDialogs: false,
      memoryLimitMB: null,
      screenDensity: 1.0,
    );
  }

  /// Estimate Android memory limit based on device specs
  int? _estimateAndroidMemoryLimit(AndroidDeviceInfo androidInfo) {
    // This is a rough estimation based on Android SDK level and device class
    if (androidInfo.version.sdkInt >= 30) {
      return 512; // Modern Android devices typically have more available memory
    } else if (androidInfo.version.sdkInt >= 28) {
      return 256; // Older devices might have less available memory
    } else {
      return 128; // Very old devices
    }
  }

  /// Estimate iOS memory limit based on device model
  int? _estimateIosMemoryLimit(String model) {
    // iOS memory management is quite different, but we can provide estimates
    if (model.contains('iPhone')) {
      if (model.contains('14') || model.contains('15')) {
        return 1024; // Newer iPhones have more memory
      } else if (model.contains('12') || model.contains('13')) {
        return 512;
      } else {
        return 256; // Older iPhones
      }
    } else if (model.contains('iPad')) {
      return 1024; // iPads generally have more memory available for apps
    }
    return 256; // Conservative default
  }

  /// Check if iOS version supports system theme
  bool _iosSupportsSystemTheme(String version) {
    final parts = version.split('.');
    if (parts.isNotEmpty) {
      final majorVersion = int.tryParse(parts[0]) ?? 0;
      return majorVersion >= 13; // iOS 13+ supports system dark mode
    }
    return false;
  }

  /// Check if Windows version supports system theme
  bool _windowsSupportsSystemTheme(int buildNumber) {
    return buildNumber >= 17763; // Windows 10 version 1809 and later
  }

  /// Check if macOS version supports system theme
  bool _macosSupportsSystemTheme(int majorVersion) {
    return majorVersion >= 10; // macOS 10.14 Mojave and later
  }
}

/// Comprehensive platform information
class PlatformInfo {
  const PlatformInfo({
    required this.platform,
    required this.version,
    required this.deviceModel,
    required this.supportsSystemTheme,
    required this.supportsFileAccess,
    required this.supportsNativeDialogs,
    required this.memoryLimitMB,
    required this.screenDensity,
  });

  /// Platform name (Android, iOS, Windows, macOS, Linux, Web)
  final String platform;

  /// Platform version
  final String version;

  /// Device model or name
  final String deviceModel;

  /// Whether the platform supports system theme (dark/light mode)
  final bool supportsSystemTheme;

  /// Whether the platform supports file system access
  final bool supportsFileAccess;

  /// Whether the platform supports native dialogs
  final bool supportsNativeDialogs;

  /// Estimated memory limit for the app in MB (null if unlimited/unknown)
  final int? memoryLimitMB;

  /// Screen density factor
  final double screenDensity;

  @override
  String toString() {
    return 'PlatformInfo('
        'platform: $platform, '
        'version: $version, '
        'deviceModel: $deviceModel, '
        'supportsSystemTheme: $supportsSystemTheme, '
        'supportsFileAccess: $supportsFileAccess, '
        'supportsNativeDialogs: $supportsNativeDialogs, '
        'memoryLimitMB: $memoryLimitMB, '
        'screenDensity: $screenDensity'
        ')';
  }
}