/// Comprehensive application configuration and settings management
///
/// This file provides a unified configuration system that handles application
/// settings, theme management, platform-specific configurations, and
/// user preferences with validation and persistence capabilities.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../bridge/bridge_types.dart';
import '../utils/platform_utils.dart';
import '../utils/error_handler.dart';

/// Comprehensive application configuration manager
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  static AppConfig get instance => _instance;

  final Logger _logger = Logger();
  late SharedPreferences _prefs;
  late PackageInfo _packageInfo;
  late DeviceInfo _deviceInfo;

  bool _isInitialized = false;
  AppConfigData _config = AppConfigData.defaultConfig();

  /// Initialize the configuration system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize core dependencies
      _prefs = await SharedPreferences.getInstance();
      _packageInfo = await PackageInfo.fromPlatform();
      _deviceInfo = await _getDeviceInfo();

      // Load configuration
      await _loadConfiguration();

      // Apply platform-specific defaults
      _applyPlatformDefaults();

      // Validate configuration
      _validateConfiguration();

      _isInitialized = true;
      _logger.i('App configuration initialized successfully');
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        additionalContext: {'operation': 'config_initialization'},
      );

      // Fallback to default configuration
      _config = AppConfigData.defaultConfig();
      _isInitialized = true;
      _logger.w('Configuration initialization failed, using defaults');
    }
  }

  /// Get current configuration
  AppConfigData get config {
    if (!_isInitialized) {
      throw StateError('AppConfig must be initialized before use');
    }
    return _config;
  }

  /// Update configuration with validation
  Future<void> updateConfig(AppConfigData newConfig) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Validate new configuration
      final validatedConfig = _validateConfigurationData(newConfig);

      // Apply configuration
      _config = validatedConfig;

      // Save to persistence
      await _saveConfiguration();

      _logger.d('Configuration updated successfully');
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        additionalContext: {'operation': 'config_update'},
      );
      rethrow;
    }
  }

  /// Update specific configuration section
  Future<void> updateThemeConfig(ThemeConfiguration themeConfig) async {
    await updateConfig(_config.copyWith(theme: themeConfig));
  }

  Future<void> updateAppSettings(ApplicationSettings appSettings) async {
    await updateConfig(_config.copyWith(app: appSettings));
  }

  Future<void> updateUIPreferences(UIPreferences uiPreferences) async {
    await updateConfig(_config.copyWith(ui: uiPreferences));
  }

  Future<void> updatePlatformSettings(PlatformSpecificSettings platformSettings) async {
    await updateConfig(_config.copyWith(platform: platformSettings));
  }

  Future<void> updatePerformanceSettings(PerformanceSettings performanceSettings) async {
    await updateConfig(_config.copyWith(performance: performanceSettings));
  }

  Future<void> updateAccessibilitySettings(AccessibilitySettings accessibilitySettings) async {
    await updateConfig(_config.copyWith(accessibility: accessibilitySettings));
  }

  Future<void> updatePrivacySettings(PrivacySettings privacySettings) async {
    await updateConfig(_config.copyWith(privacy: privacySettings));
  }

  /// Reset configuration to defaults
  Future<void> resetToDefaults() async {
    _logger.i('Resetting configuration to defaults');

    final defaultConfig = AppConfigData.defaultConfig();
    await updateConfig(defaultConfig);
  }

  /// Reset specific configuration section to defaults
  Future<void> resetThemeToDefaults() async {
    await updateThemeConfig(ThemeConfiguration.defaultConfig());
  }

  Future<void> resetAppSettingsToDefaults() async {
    await updateAppSettings(ApplicationSettings.defaultConfig());
  }

  Future<void> resetUIPreferencesToDefaults() async {
    await updateUIPreferences(UIPreferences.defaultConfig());
  }

  /// Export configuration to JSON
  Map<String, dynamic> exportConfiguration() {
    return {
      'version': _packageInfo.version,
      'exported_at': DateTime.now().toIso8601String(),
      'platform': PlatformUtils.platformName,
      'config': _config.toJson(),
    };
  }

  /// Import configuration from JSON
  Future<void> importConfiguration(Map<String, dynamic> data) async {
    try {
      final configData = data['config'] as Map<String, dynamic>;
      final importedConfig = AppConfigData.fromJson(configData);

      // Validate imported configuration
      await updateConfig(importedConfig);

      _logger.i('Configuration imported successfully');
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        additionalContext: {'operation': 'config_import'},
      );
      rethrow;
    }
  }

  /// Get configuration health and validation status
  ConfigurationHealth getConfigurationHealth() {
    final validationResults = _performFullValidation(_config);

    return ConfigurationHealth(
      isValid: validationResults.every((result) => result.isValid),
      validationResults: validationResults,
      configVersion: _config.configVersion,
      lastUpdated: _config.lastUpdated,
      platform: PlatformUtils.platformName,
      appVersion: _packageInfo.version,
    );
  }

  /// Clear all configuration data
  Future<void> clearAllData() async {
    await _prefs.clear();
    _config = AppConfigData.defaultConfig();
    _logger.i('All configuration data cleared');
  }

  // Private methods

  Future<DeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (PlatformUtils.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return DeviceInfo(
        platform: 'Android',
        version: androidInfo.version.release,
        model: '${androidInfo.manufacturer} ${androidInfo.model}',
        supportedFeatures: _getAndroidFeatures(androidInfo),
      );
    } else if (PlatformUtils.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return DeviceInfo(
        platform: 'iOS',
        version: iosInfo.systemVersion,
        model: iosInfo.model,
        supportedFeatures: _getIOSFeatures(iosInfo),
      );
    } else if (PlatformUtils.isWeb) {
      final webInfo = await deviceInfoPlugin.webBrowserInfo;
      return DeviceInfo(
        platform: 'Web',
        version: webInfo.browserName ?? 'Unknown',
        model: webInfo.platform ?? 'Unknown',
        supportedFeatures: _getWebFeatures(webInfo),
      );
    } else {
      return DeviceInfo(
        platform: PlatformUtils.platformName,
        version: 'Unknown',
        model: 'Unknown',
        supportedFeatures: [],
      );
    }
  }

  List<String> _getAndroidFeatures(dynamic androidInfo) {
    return [
      'haptic_feedback',
      'file_system_access',
      'system_ui_control',
      'orientation_control',
      if (androidInfo.version.sdkInt >= 23) 'runtime_permissions',
      if (androidInfo.version.sdkInt >= 29) 'scoped_storage',
    ];
  }

  List<String> _getIOSFeatures(dynamic iosInfo) {
    return [
      'haptic_feedback',
      'file_system_access',
      'system_ui_control',
      'orientation_control',
      'app_store_integration',
    ];
  }

  List<String> _getWebFeatures(dynamic webInfo) {
    return [
      'clipboard_access',
      'download_support',
      'full_screen_api',
      if (webInfo.platform?.contains('mobile') == true) 'touch_interface',
    ];
  }

  Future<void> _loadConfiguration() async {
    try {
      final configJson = _prefs.getString('app_config');
      if (configJson != null) {
        final configData = jsonDecode(configJson) as Map<String, dynamic>;
        _config = AppConfigData.fromJson(configData);
        _logger.d('Configuration loaded from storage');
      } else {
        _config = AppConfigData.defaultConfig();
        _logger.d('No existing configuration, using defaults');
      }
    } catch (e) {
      _logger.w('Failed to load configuration, using defaults: $e');
      _config = AppConfigData.defaultConfig();
    }
  }

  Future<void> _saveConfiguration() async {
    try {
      final configJson = jsonEncode(_config.toJson());
      await _prefs.setString('app_config', configJson);
      _logger.v('Configuration saved to storage');
    } catch (e, stackTrace) {
      _logger.e('Failed to save configuration', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void _applyPlatformDefaults() {
    if (PlatformUtils.isMobile) {
      _config = _config.copyWith(
        ui: _config.ui.copyWith(
          enableTouchGestures: true,
          showMobileToolbar: true,
          compactMode: true,
        ),
        performance: _config.performance.copyWith(
          enableHardwareAcceleration: true,
          memoryOptimizationLevel: MemoryOptimizationLevel.aggressive,
        ),
      );
    } else if (PlatformUtils.isDesktop) {
      _config = _config.copyWith(
        ui: _config.ui.copyWith(
          enableTouchGestures: false,
          showDesktopMenuBar: true,
          compactMode: false,
        ),
        performance: _config.performance.copyWith(
          enableHardwareAcceleration: true,
          memoryOptimizationLevel: MemoryOptimizationLevel.balanced,
        ),
      );
    } else if (PlatformUtils.isWeb) {
      _config = _config.copyWith(
        ui: _config.ui.copyWith(
          enableWebOptimizations: true,
          compactMode: true,
        ),
        performance: _config.performance.copyWith(
          enableHardwareAcceleration: false,
          memoryOptimizationLevel: MemoryOptimizationLevel.conservative,
        ),
      );
    }
  }

  void _validateConfiguration() {
    try {
      _config = _validateConfigurationData(_config);
      _logger.d('Configuration validation completed');
    } catch (e) {
      _logger.w('Configuration validation failed, applying fixes: $e');
      _config = _config.copyWithValidDefaults();
    }
  }

  AppConfigData _validateConfigurationData(AppConfigData config) {
    final validationResults = _performFullValidation(config);
    final errors = validationResults.where((r) => !r.isValid).toList();

    if (errors.isNotEmpty) {
      throw ConfigurationValidationException(
        'Configuration validation failed',
        errors,
      );
    }

    return config;
  }

  List<ValidationResult> _performFullValidation(AppConfigData config) {
    final results = <ValidationResult>[];

    // Validate theme configuration
    results.addAll(_validateThemeConfig(config.theme));

    // Validate application settings
    results.addAll(_validateAppSettings(config.app));

    // Validate UI preferences
    results.addAll(_validateUIPreferences(config.ui));

    // Validate platform settings
    results.addAll(_validatePlatformSettings(config.platform));

    // Validate performance settings
    results.addAll(_validatePerformanceSettings(config.performance));

    // Validate accessibility settings
    results.addAll(_validateAccessibilitySettings(config.accessibility));

    // Validate privacy settings
    results.addAll(_validatePrivacySettings(config.privacy));

    return results;
  }

  List<ValidationResult> _validateThemeConfig(ThemeConfiguration theme) {
    final results = <ValidationResult>[];

    if (theme.primaryColor.value < 0 || theme.primaryColor.value > 0xFFFFFFFF) {
      results.add(ValidationResult(
        field: 'theme.primaryColor',
        isValid: false,
        message: 'Invalid primary color value',
      ));
    }

    if (theme.fontSize < 8.0 || theme.fontSize > 72.0) {
      results.add(ValidationResult(
        field: 'theme.fontSize',
        isValid: false,
        message: 'Font size must be between 8.0 and 72.0',
      ));
    }

    return results;
  }

  List<ValidationResult> _validateAppSettings(ApplicationSettings app) {
    final results = <ValidationResult>[];

    if (app.autoSaveInterval.inSeconds < 30 || app.autoSaveInterval.inHours > 24) {
      results.add(ValidationResult(
        field: 'app.autoSaveInterval',
        isValid: false,
        message: 'Auto-save interval must be between 30 seconds and 24 hours',
      ));
    }

    if (app.maxRecentFiles < 0 || app.maxRecentFiles > 100) {
      results.add(ValidationResult(
        field: 'app.maxRecentFiles',
        isValid: false,
        message: 'Max recent files must be between 0 and 100',
      ));
    }

    return results;
  }

  List<ValidationResult> _validateUIPreferences(UIPreferences ui) {
    final results = <ValidationResult>[];

    if (ui.zoomLevel < 0.1 || ui.zoomLevel > 10.0) {
      results.add(ValidationResult(
        field: 'ui.zoomLevel',
        isValid: false,
        message: 'Zoom level must be between 0.1 and 10.0',
      ));
    }

    if (ui.gridSize < 5.0 || ui.gridSize > 100.0) {
      results.add(ValidationResult(
        field: 'ui.gridSize',
        isValid: false,
        message: 'Grid size must be between 5.0 and 100.0',
      ));
    }

    return results;
  }

  List<ValidationResult> _validatePlatformSettings(PlatformSpecificSettings platform) {
    final results = <ValidationResult>[];

    // Platform-specific validation would go here
    // For now, all platform settings are considered valid

    return results;
  }

  List<ValidationResult> _validatePerformanceSettings(PerformanceSettings performance) {
    final results = <ValidationResult>[];

    if (performance.maxCacheSize < 1 || performance.maxCacheSize > 1000) {
      results.add(ValidationResult(
        field: 'performance.maxCacheSize',
        isValid: false,
        message: 'Max cache size must be between 1 and 1000 MB',
      ));
    }

    return results;
  }

  List<ValidationResult> _validateAccessibilitySettings(AccessibilitySettings accessibility) {
    final results = <ValidationResult>[];

    if (accessibility.textScale < 0.5 || accessibility.textScale > 3.0) {
      results.add(ValidationResult(
        field: 'accessibility.textScale',
        isValid: false,
        message: 'Text scale must be between 0.5 and 3.0',
      ));
    }

    return results;
  }

  List<ValidationResult> _validatePrivacySettings(PrivacySettings privacy) {
    final results = <ValidationResult>[];

    // Privacy settings validation would go here
    // For now, all privacy settings are considered valid

    return results;
  }
}

/// Main configuration data structure
@immutable
class AppConfigData {
  const AppConfigData({
    required this.configVersion,
    required this.lastUpdated,
    required this.theme,
    required this.app,
    required this.ui,
    required this.platform,
    required this.performance,
    required this.accessibility,
    required this.privacy,
  });

  final String configVersion;
  final DateTime lastUpdated;
  final ThemeConfiguration theme;
  final ApplicationSettings app;
  final UIPreferences ui;
  final PlatformSpecificSettings platform;
  final PerformanceSettings performance;
  final AccessibilitySettings accessibility;
  final PrivacySettings privacy;

  /// Create default configuration
  factory AppConfigData.defaultConfig() {
    return AppConfigData(
      configVersion: '1.0.0',
      lastUpdated: DateTime.now(),
      theme: ThemeConfiguration.defaultConfig(),
      app: ApplicationSettings.defaultConfig(),
      ui: UIPreferences.defaultConfig(),
      platform: PlatformSpecificSettings.defaultConfig(),
      performance: PerformanceSettings.defaultConfig(),
      accessibility: AccessibilitySettings.defaultConfig(),
      privacy: PrivacySettings.defaultConfig(),
    );
  }

  AppConfigData copyWith({
    String? configVersion,
    DateTime? lastUpdated,
    ThemeConfiguration? theme,
    ApplicationSettings? app,
    UIPreferences? ui,
    PlatformSpecificSettings? platform,
    PerformanceSettings? performance,
    AccessibilitySettings? accessibility,
    PrivacySettings? privacy,
  }) {
    return AppConfigData(
      configVersion: configVersion ?? this.configVersion,
      lastUpdated: lastUpdated ?? DateTime.now(),
      theme: theme ?? this.theme,
      app: app ?? this.app,
      ui: ui ?? this.ui,
      platform: platform ?? this.platform,
      performance: performance ?? this.performance,
      accessibility: accessibility ?? this.accessibility,
      privacy: privacy ?? this.privacy,
    );
  }

  /// Copy with valid defaults for any invalid fields
  AppConfigData copyWithValidDefaults() {
    return AppConfigData(
      configVersion: configVersion.isNotEmpty ? configVersion : '1.0.0',
      lastUpdated: lastUpdated,
      theme: theme.withValidDefaults(),
      app: app.withValidDefaults(),
      ui: ui.withValidDefaults(),
      platform: platform,
      performance: performance.withValidDefaults(),
      accessibility: accessibility.withValidDefaults(),
      privacy: privacy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'configVersion': configVersion,
      'lastUpdated': lastUpdated.toIso8601String(),
      'theme': theme.toJson(),
      'app': app.toJson(),
      'ui': ui.toJson(),
      'platform': platform.toJson(),
      'performance': performance.toJson(),
      'accessibility': accessibility.toJson(),
      'privacy': privacy.toJson(),
    };
  }

  factory AppConfigData.fromJson(Map<String, dynamic> json) {
    return AppConfigData(
      configVersion: json['configVersion'] as String? ?? '1.0.0',
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? DateTime.now(),
      theme: ThemeConfiguration.fromJson(json['theme'] as Map<String, dynamic>? ?? {}),
      app: ApplicationSettings.fromJson(json['app'] as Map<String, dynamic>? ?? {}),
      ui: UIPreferences.fromJson(json['ui'] as Map<String, dynamic>? ?? {}),
      platform: PlatformSpecificSettings.fromJson(json['platform'] as Map<String, dynamic>? ?? {}),
      performance: PerformanceSettings.fromJson(json['performance'] as Map<String, dynamic>? ?? {}),
      accessibility: AccessibilitySettings.fromJson(json['accessibility'] as Map<String, dynamic>? ?? {}),
      privacy: PrivacySettings.fromJson(json['privacy'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Theme configuration settings
@immutable
class ThemeConfiguration {
  const ThemeConfiguration({
    required this.themeMode,
    required this.primaryColor,
    required this.accentColor,
    required this.fontFamily,
    required this.fontSize,
    required this.useMaterialYou,
    required this.darkThemeVariant,
    required this.customColors,
  });

  final ThemeMode themeMode;
  final Color primaryColor;
  final Color accentColor;
  final String fontFamily;
  final double fontSize;
  final bool useMaterialYou;
  final DarkThemeVariant darkThemeVariant;
  final Map<String, Color> customColors;

  factory ThemeConfiguration.defaultConfig() {
    return ThemeConfiguration(
      themeMode: ThemeMode.system,
      primaryColor: Colors.blue,
      accentColor: Colors.blueAccent,
      fontFamily: 'System',
      fontSize: 14.0,
      useMaterialYou: true,
      darkThemeVariant: DarkThemeVariant.standard,
      customColors: {},
    );
  }

  ThemeConfiguration copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    Color? accentColor,
    String? fontFamily,
    double? fontSize,
    bool? useMaterialYou,
    DarkThemeVariant? darkThemeVariant,
    Map<String, Color>? customColors,
  }) {
    return ThemeConfiguration(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      useMaterialYou: useMaterialYou ?? this.useMaterialYou,
      darkThemeVariant: darkThemeVariant ?? this.darkThemeVariant,
      customColors: customColors ?? this.customColors,
    );
  }

  ThemeConfiguration withValidDefaults() {
    return ThemeConfiguration(
      themeMode: themeMode,
      primaryColor: primaryColor,
      accentColor: accentColor,
      fontFamily: fontFamily.isNotEmpty ? fontFamily : 'System',
      fontSize: (fontSize >= 8.0 && fontSize <= 72.0) ? fontSize : 14.0,
      useMaterialYou: useMaterialYou,
      darkThemeVariant: darkThemeVariant,
      customColors: customColors,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'primaryColor': primaryColor.value,
      'accentColor': accentColor.value,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'useMaterialYou': useMaterialYou,
      'darkThemeVariant': darkThemeVariant.index,
      'customColors': customColors.map((k, v) => MapEntry(k, v.value)),
    };
  }

  factory ThemeConfiguration.fromJson(Map<String, dynamic> json) {
    return ThemeConfiguration(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      primaryColor: Color(json['primaryColor'] as int? ?? Colors.blue.value),
      accentColor: Color(json['accentColor'] as int? ?? Colors.blueAccent.value),
      fontFamily: json['fontFamily'] as String? ?? 'System',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      useMaterialYou: json['useMaterialYou'] as bool? ?? true,
      darkThemeVariant: DarkThemeVariant.values[json['darkThemeVariant'] as int? ?? 0],
      customColors: (json['customColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Color(v as int)),
          ) ?? {},
    );
  }
}

/// Dark theme variants
enum DarkThemeVariant {
  standard,
  oled,
  highContrast,
}

/// Application settings
@immutable
class ApplicationSettings {
  const ApplicationSettings({
    required this.autoSave,
    required this.autoSaveInterval,
    required this.maxRecentFiles,
    required this.defaultLayoutType,
    required this.defaultExportFormat,
    required this.enableAnimations,
    required this.enableHapticFeedback,
    required this.enableSoundEffects,
    required this.language,
    required this.enableDebugMode,
  });

  final bool autoSave;
  final Duration autoSaveInterval;
  final int maxRecentFiles;
  final FfiLayoutType defaultLayoutType;
  final ExportFormat defaultExportFormat;
  final bool enableAnimations;
  final bool enableHapticFeedback;
  final bool enableSoundEffects;
  final String language;
  final bool enableDebugMode;

  factory ApplicationSettings.defaultConfig() {
    return ApplicationSettings(
      autoSave: true,
      autoSaveInterval: const Duration(minutes: 5),
      maxRecentFiles: 10,
      defaultLayoutType: FfiLayoutType.radial,
      defaultExportFormat: ExportFormat.png,
      enableAnimations: true,
      enableHapticFeedback: true,
      enableSoundEffects: false,
      language: 'system',
      enableDebugMode: kDebugMode,
    );
  }

  ApplicationSettings copyWith({
    bool? autoSave,
    Duration? autoSaveInterval,
    int? maxRecentFiles,
    FfiLayoutType? defaultLayoutType,
    ExportFormat? defaultExportFormat,
    bool? enableAnimations,
    bool? enableHapticFeedback,
    bool? enableSoundEffects,
    String? language,
    bool? enableDebugMode,
  }) {
    return ApplicationSettings(
      autoSave: autoSave ?? this.autoSave,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
      maxRecentFiles: maxRecentFiles ?? this.maxRecentFiles,
      defaultLayoutType: defaultLayoutType ?? this.defaultLayoutType,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enableSoundEffects: enableSoundEffects ?? this.enableSoundEffects,
      language: language ?? this.language,
      enableDebugMode: enableDebugMode ?? this.enableDebugMode,
    );
  }

  ApplicationSettings withValidDefaults() {
    return ApplicationSettings(
      autoSave: autoSave,
      autoSaveInterval: (autoSaveInterval.inSeconds >= 30 && autoSaveInterval.inHours <= 24)
          ? autoSaveInterval
          : const Duration(minutes: 5),
      maxRecentFiles: (maxRecentFiles >= 0 && maxRecentFiles <= 100) ? maxRecentFiles : 10,
      defaultLayoutType: defaultLayoutType,
      defaultExportFormat: defaultExportFormat,
      enableAnimations: enableAnimations,
      enableHapticFeedback: enableHapticFeedback,
      enableSoundEffects: enableSoundEffects,
      language: language.isNotEmpty ? language : 'system',
      enableDebugMode: enableDebugMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSave': autoSave,
      'autoSaveIntervalMinutes': autoSaveInterval.inMinutes,
      'maxRecentFiles': maxRecentFiles,
      'defaultLayoutType': defaultLayoutType.index,
      'defaultExportFormat': defaultExportFormat.index,
      'enableAnimations': enableAnimations,
      'enableHapticFeedback': enableHapticFeedback,
      'enableSoundEffects': enableSoundEffects,
      'language': language,
      'enableDebugMode': enableDebugMode,
    };
  }

  factory ApplicationSettings.fromJson(Map<String, dynamic> json) {
    return ApplicationSettings(
      autoSave: json['autoSave'] as bool? ?? true,
      autoSaveInterval: Duration(minutes: json['autoSaveIntervalMinutes'] as int? ?? 5),
      maxRecentFiles: json['maxRecentFiles'] as int? ?? 10,
      defaultLayoutType: FfiLayoutType.values[json['defaultLayoutType'] as int? ?? 0],
      defaultExportFormat: ExportFormat.values[json['defaultExportFormat'] as int? ?? 2],
      enableAnimations: json['enableAnimations'] as bool? ?? true,
      enableHapticFeedback: json['enableHapticFeedback'] as bool? ?? true,
      enableSoundEffects: json['enableSoundEffects'] as bool? ?? false,
      language: json['language'] as String? ?? 'system',
      enableDebugMode: json['enableDebugMode'] as bool? ?? kDebugMode,
    );
  }
}

/// UI preferences and layout settings
@immutable
class UIPreferences {
  const UIPreferences({
    required this.showToolbar,
    required this.showStatusBar,
    required this.showMinimap,
    required this.enableGridSnap,
    required this.gridSize,
    required this.zoomLevel,
    required this.panSensitivity,
    required this.zoomSensitivity,
    required this.enableTouchGestures,
    required this.showMobileToolbar,
    required this.showDesktopMenuBar,
    required this.compactMode,
    required this.enableWebOptimizations,
  });

  final bool showToolbar;
  final bool showStatusBar;
  final bool showMinimap;
  final bool enableGridSnap;
  final double gridSize;
  final double zoomLevel;
  final double panSensitivity;
  final double zoomSensitivity;
  final bool enableTouchGestures;
  final bool showMobileToolbar;
  final bool showDesktopMenuBar;
  final bool compactMode;
  final bool enableWebOptimizations;

  factory UIPreferences.defaultConfig() {
    return UIPreferences(
      showToolbar: true,
      showStatusBar: true,
      showMinimap: false,
      enableGridSnap: true,
      gridSize: 20.0,
      zoomLevel: 1.0,
      panSensitivity: 1.0,
      zoomSensitivity: 1.0,
      enableTouchGestures: PlatformUtils.isMobile,
      showMobileToolbar: PlatformUtils.isMobile,
      showDesktopMenuBar: PlatformUtils.isDesktop,
      compactMode: PlatformUtils.isMobile,
      enableWebOptimizations: PlatformUtils.isWeb,
    );
  }

  UIPreferences copyWith({
    bool? showToolbar,
    bool? showStatusBar,
    bool? showMinimap,
    bool? enableGridSnap,
    double? gridSize,
    double? zoomLevel,
    double? panSensitivity,
    double? zoomSensitivity,
    bool? enableTouchGestures,
    bool? showMobileToolbar,
    bool? showDesktopMenuBar,
    bool? compactMode,
    bool? enableWebOptimizations,
  }) {
    return UIPreferences(
      showToolbar: showToolbar ?? this.showToolbar,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      showMinimap: showMinimap ?? this.showMinimap,
      enableGridSnap: enableGridSnap ?? this.enableGridSnap,
      gridSize: gridSize ?? this.gridSize,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      panSensitivity: panSensitivity ?? this.panSensitivity,
      zoomSensitivity: zoomSensitivity ?? this.zoomSensitivity,
      enableTouchGestures: enableTouchGestures ?? this.enableTouchGestures,
      showMobileToolbar: showMobileToolbar ?? this.showMobileToolbar,
      showDesktopMenuBar: showDesktopMenuBar ?? this.showDesktopMenuBar,
      compactMode: compactMode ?? this.compactMode,
      enableWebOptimizations: enableWebOptimizations ?? this.enableWebOptimizations,
    );
  }

  UIPreferences withValidDefaults() {
    return UIPreferences(
      showToolbar: showToolbar,
      showStatusBar: showStatusBar,
      showMinimap: showMinimap,
      enableGridSnap: enableGridSnap,
      gridSize: (gridSize >= 5.0 && gridSize <= 100.0) ? gridSize : 20.0,
      zoomLevel: (zoomLevel >= 0.1 && zoomLevel <= 10.0) ? zoomLevel : 1.0,
      panSensitivity: panSensitivity.clamp(0.1, 5.0),
      zoomSensitivity: zoomSensitivity.clamp(0.1, 5.0),
      enableTouchGestures: enableTouchGestures,
      showMobileToolbar: showMobileToolbar,
      showDesktopMenuBar: showDesktopMenuBar,
      compactMode: compactMode,
      enableWebOptimizations: enableWebOptimizations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showToolbar': showToolbar,
      'showStatusBar': showStatusBar,
      'showMinimap': showMinimap,
      'enableGridSnap': enableGridSnap,
      'gridSize': gridSize,
      'zoomLevel': zoomLevel,
      'panSensitivity': panSensitivity,
      'zoomSensitivity': zoomSensitivity,
      'enableTouchGestures': enableTouchGestures,
      'showMobileToolbar': showMobileToolbar,
      'showDesktopMenuBar': showDesktopMenuBar,
      'compactMode': compactMode,
      'enableWebOptimizations': enableWebOptimizations,
    };
  }

  factory UIPreferences.fromJson(Map<String, dynamic> json) {
    return UIPreferences(
      showToolbar: json['showToolbar'] as bool? ?? true,
      showStatusBar: json['showStatusBar'] as bool? ?? true,
      showMinimap: json['showMinimap'] as bool? ?? false,
      enableGridSnap: json['enableGridSnap'] as bool? ?? true,
      gridSize: (json['gridSize'] as num?)?.toDouble() ?? 20.0,
      zoomLevel: (json['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      panSensitivity: (json['panSensitivity'] as num?)?.toDouble() ?? 1.0,
      zoomSensitivity: (json['zoomSensitivity'] as num?)?.toDouble() ?? 1.0,
      enableTouchGestures: json['enableTouchGestures'] as bool? ?? PlatformUtils.isMobile,
      showMobileToolbar: json['showMobileToolbar'] as bool? ?? PlatformUtils.isMobile,
      showDesktopMenuBar: json['showDesktopMenuBar'] as bool? ?? PlatformUtils.isDesktop,
      compactMode: json['compactMode'] as bool? ?? PlatformUtils.isMobile,
      enableWebOptimizations: json['enableWebOptimizations'] as bool? ?? PlatformUtils.isWeb,
    );
  }
}

/// Platform-specific settings
@immutable
class PlatformSpecificSettings {
  const PlatformSpecificSettings({
    required this.mobileSettings,
    required this.desktopSettings,
    required this.webSettings,
  });

  final MobileSettings mobileSettings;
  final DesktopSettings desktopSettings;
  final WebSettings webSettings;

  factory PlatformSpecificSettings.defaultConfig() {
    return PlatformSpecificSettings(
      mobileSettings: MobileSettings.defaultConfig(),
      desktopSettings: DesktopSettings.defaultConfig(),
      webSettings: WebSettings.defaultConfig(),
    );
  }

  PlatformSpecificSettings copyWith({
    MobileSettings? mobileSettings,
    DesktopSettings? desktopSettings,
    WebSettings? webSettings,
  }) {
    return PlatformSpecificSettings(
      mobileSettings: mobileSettings ?? this.mobileSettings,
      desktopSettings: desktopSettings ?? this.desktopSettings,
      webSettings: webSettings ?? this.webSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mobile': mobileSettings.toJson(),
      'desktop': desktopSettings.toJson(),
      'web': webSettings.toJson(),
    };
  }

  factory PlatformSpecificSettings.fromJson(Map<String, dynamic> json) {
    return PlatformSpecificSettings(
      mobileSettings: MobileSettings.fromJson(json['mobile'] as Map<String, dynamic>? ?? {}),
      desktopSettings: DesktopSettings.fromJson(json['desktop'] as Map<String, dynamic>? ?? {}),
      webSettings: WebSettings.fromJson(json['web'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Mobile-specific settings
@immutable
class MobileSettings {
  const MobileSettings({
    required this.enableOrientationLock,
    required this.preferredOrientation,
    required this.enableFullScreen,
    required this.enableStatusBarHiding,
    required this.hapticFeedbackIntensity,
  });

  final bool enableOrientationLock;
  final DeviceOrientation preferredOrientation;
  final bool enableFullScreen;
  final bool enableStatusBarHiding;
  final HapticIntensity hapticFeedbackIntensity;

  factory MobileSettings.defaultConfig() {
    return const MobileSettings(
      enableOrientationLock: false,
      preferredOrientation: DeviceOrientation.portraitUp,
      enableFullScreen: false,
      enableStatusBarHiding: false,
      hapticFeedbackIntensity: HapticIntensity.medium,
    );
  }

  MobileSettings copyWith({
    bool? enableOrientationLock,
    DeviceOrientation? preferredOrientation,
    bool? enableFullScreen,
    bool? enableStatusBarHiding,
    HapticIntensity? hapticFeedbackIntensity,
  }) {
    return MobileSettings(
      enableOrientationLock: enableOrientationLock ?? this.enableOrientationLock,
      preferredOrientation: preferredOrientation ?? this.preferredOrientation,
      enableFullScreen: enableFullScreen ?? this.enableFullScreen,
      enableStatusBarHiding: enableStatusBarHiding ?? this.enableStatusBarHiding,
      hapticFeedbackIntensity: hapticFeedbackIntensity ?? this.hapticFeedbackIntensity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableOrientationLock': enableOrientationLock,
      'preferredOrientation': preferredOrientation.index,
      'enableFullScreen': enableFullScreen,
      'enableStatusBarHiding': enableStatusBarHiding,
      'hapticFeedbackIntensity': hapticFeedbackIntensity.index,
    };
  }

  factory MobileSettings.fromJson(Map<String, dynamic> json) {
    return MobileSettings(
      enableOrientationLock: json['enableOrientationLock'] as bool? ?? false,
      preferredOrientation: DeviceOrientation.values[json['preferredOrientation'] as int? ?? 0],
      enableFullScreen: json['enableFullScreen'] as bool? ?? false,
      enableStatusBarHiding: json['enableStatusBarHiding'] as bool? ?? false,
      hapticFeedbackIntensity: HapticIntensity.values[json['hapticFeedbackIntensity'] as int? ?? 1],
    );
  }
}

/// Desktop-specific settings
@immutable
class DesktopSettings {
  const DesktopSettings({
    required this.enableWindowControls,
    required this.enableMinimizeToTray,
    required this.enableAutoStartup,
    required this.defaultWindowSize,
    required this.rememberWindowPosition,
  });

  final bool enableWindowControls;
  final bool enableMinimizeToTray;
  final bool enableAutoStartup;
  final Size? defaultWindowSize;
  final bool rememberWindowPosition;

  factory DesktopSettings.defaultConfig() {
    return const DesktopSettings(
      enableWindowControls: true,
      enableMinimizeToTray: false,
      enableAutoStartup: false,
      defaultWindowSize: Size(1200, 800),
      rememberWindowPosition: true,
    );
  }

  DesktopSettings copyWith({
    bool? enableWindowControls,
    bool? enableMinimizeToTray,
    bool? enableAutoStartup,
    Size? defaultWindowSize,
    bool? rememberWindowPosition,
  }) {
    return DesktopSettings(
      enableWindowControls: enableWindowControls ?? this.enableWindowControls,
      enableMinimizeToTray: enableMinimizeToTray ?? this.enableMinimizeToTray,
      enableAutoStartup: enableAutoStartup ?? this.enableAutoStartup,
      defaultWindowSize: defaultWindowSize ?? this.defaultWindowSize,
      rememberWindowPosition: rememberWindowPosition ?? this.rememberWindowPosition,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableWindowControls': enableWindowControls,
      'enableMinimizeToTray': enableMinimizeToTray,
      'enableAutoStartup': enableAutoStartup,
      'defaultWindowSize': defaultWindowSize != null
          ? {'width': defaultWindowSize!.width, 'height': defaultWindowSize!.height}
          : null,
      'rememberWindowPosition': rememberWindowPosition,
    };
  }

  factory DesktopSettings.fromJson(Map<String, dynamic> json) {
    return DesktopSettings(
      enableWindowControls: json['enableWindowControls'] as bool? ?? true,
      enableMinimizeToTray: json['enableMinimizeToTray'] as bool? ?? false,
      enableAutoStartup: json['enableAutoStartup'] as bool? ?? false,
      defaultWindowSize: json['defaultWindowSize'] != null
          ? Size(
              (json['defaultWindowSize']['width'] as num).toDouble(),
              (json['defaultWindowSize']['height'] as num).toDouble(),
            )
          : const Size(1200, 800),
      rememberWindowPosition: json['rememberWindowPosition'] as bool? ?? true,
    );
  }
}

/// Web-specific settings
@immutable
class WebSettings {
  const WebSettings({
    required this.enablePWAMode,
    required this.enableOfflineSupport,
    required this.enableServiceWorker,
    required this.cacheStrategy,
  });

  final bool enablePWAMode;
  final bool enableOfflineSupport;
  final bool enableServiceWorker;
  final CacheStrategy cacheStrategy;

  factory WebSettings.defaultConfig() {
    return const WebSettings(
      enablePWAMode: true,
      enableOfflineSupport: true,
      enableServiceWorker: true,
      cacheStrategy: CacheStrategy.aggressive,
    );
  }

  WebSettings copyWith({
    bool? enablePWAMode,
    bool? enableOfflineSupport,
    bool? enableServiceWorker,
    CacheStrategy? cacheStrategy,
  }) {
    return WebSettings(
      enablePWAMode: enablePWAMode ?? this.enablePWAMode,
      enableOfflineSupport: enableOfflineSupport ?? this.enableOfflineSupport,
      enableServiceWorker: enableServiceWorker ?? this.enableServiceWorker,
      cacheStrategy: cacheStrategy ?? this.cacheStrategy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enablePWAMode': enablePWAMode,
      'enableOfflineSupport': enableOfflineSupport,
      'enableServiceWorker': enableServiceWorker,
      'cacheStrategy': cacheStrategy.index,
    };
  }

  factory WebSettings.fromJson(Map<String, dynamic> json) {
    return WebSettings(
      enablePWAMode: json['enablePWAMode'] as bool? ?? true,
      enableOfflineSupport: json['enableOfflineSupport'] as bool? ?? true,
      enableServiceWorker: json['enableServiceWorker'] as bool? ?? true,
      cacheStrategy: CacheStrategy.values[json['cacheStrategy'] as int? ?? 2],
    );
  }
}

/// Performance settings
@immutable
class PerformanceSettings {
  const PerformanceSettings({
    required this.enableHardwareAcceleration,
    required this.maxCacheSize,
    required this.memoryOptimizationLevel,
    required this.enableFrameRateLimit,
    required this.targetFrameRate,
    required this.enableLazyLoading,
  });

  final bool enableHardwareAcceleration;
  final int maxCacheSize; // in MB
  final MemoryOptimizationLevel memoryOptimizationLevel;
  final bool enableFrameRateLimit;
  final int targetFrameRate;
  final bool enableLazyLoading;

  factory PerformanceSettings.defaultConfig() {
    return PerformanceSettings(
      enableHardwareAcceleration: !PlatformUtils.isWeb,
      maxCacheSize: 100,
      memoryOptimizationLevel: MemoryOptimizationLevel.balanced,
      enableFrameRateLimit: PlatformUtils.isMobile,
      targetFrameRate: 60,
      enableLazyLoading: true,
    );
  }

  PerformanceSettings copyWith({
    bool? enableHardwareAcceleration,
    int? maxCacheSize,
    MemoryOptimizationLevel? memoryOptimizationLevel,
    bool? enableFrameRateLimit,
    int? targetFrameRate,
    bool? enableLazyLoading,
  }) {
    return PerformanceSettings(
      enableHardwareAcceleration: enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      memoryOptimizationLevel: memoryOptimizationLevel ?? this.memoryOptimizationLevel,
      enableFrameRateLimit: enableFrameRateLimit ?? this.enableFrameRateLimit,
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      enableLazyLoading: enableLazyLoading ?? this.enableLazyLoading,
    );
  }

  PerformanceSettings withValidDefaults() {
    return PerformanceSettings(
      enableHardwareAcceleration: enableHardwareAcceleration,
      maxCacheSize: (maxCacheSize >= 1 && maxCacheSize <= 1000) ? maxCacheSize : 100,
      memoryOptimizationLevel: memoryOptimizationLevel,
      enableFrameRateLimit: enableFrameRateLimit,
      targetFrameRate: (targetFrameRate >= 30 && targetFrameRate <= 120) ? targetFrameRate : 60,
      enableLazyLoading: enableLazyLoading,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableHardwareAcceleration': enableHardwareAcceleration,
      'maxCacheSize': maxCacheSize,
      'memoryOptimizationLevel': memoryOptimizationLevel.index,
      'enableFrameRateLimit': enableFrameRateLimit,
      'targetFrameRate': targetFrameRate,
      'enableLazyLoading': enableLazyLoading,
    };
  }

  factory PerformanceSettings.fromJson(Map<String, dynamic> json) {
    return PerformanceSettings(
      enableHardwareAcceleration: json['enableHardwareAcceleration'] as bool? ?? !PlatformUtils.isWeb,
      maxCacheSize: json['maxCacheSize'] as int? ?? 100,
      memoryOptimizationLevel: MemoryOptimizationLevel.values[json['memoryOptimizationLevel'] as int? ?? 1],
      enableFrameRateLimit: json['enableFrameRateLimit'] as bool? ?? PlatformUtils.isMobile,
      targetFrameRate: json['targetFrameRate'] as int? ?? 60,
      enableLazyLoading: json['enableLazyLoading'] as bool? ?? true,
    );
  }
}

/// Accessibility settings
@immutable
class AccessibilitySettings {
  const AccessibilitySettings({
    required this.enableScreenReader,
    required this.enableHighContrast,
    required this.enableReducedMotion,
    required this.textScale,
    required this.enableKeyboardNavigation,
    required this.enableVoiceControl,
    required this.colorBlindnessType,
  });

  final bool enableScreenReader;
  final bool enableHighContrast;
  final bool enableReducedMotion;
  final double textScale;
  final bool enableKeyboardNavigation;
  final bool enableVoiceControl;
  final ColorBlindnessType colorBlindnessType;

  factory AccessibilitySettings.defaultConfig() {
    return const AccessibilitySettings(
      enableScreenReader: false,
      enableHighContrast: false,
      enableReducedMotion: false,
      textScale: 1.0,
      enableKeyboardNavigation: true,
      enableVoiceControl: false,
      colorBlindnessType: ColorBlindnessType.none,
    );
  }

  AccessibilitySettings copyWith({
    bool? enableScreenReader,
    bool? enableHighContrast,
    bool? enableReducedMotion,
    double? textScale,
    bool? enableKeyboardNavigation,
    bool? enableVoiceControl,
    ColorBlindnessType? colorBlindnessType,
  }) {
    return AccessibilitySettings(
      enableScreenReader: enableScreenReader ?? this.enableScreenReader,
      enableHighContrast: enableHighContrast ?? this.enableHighContrast,
      enableReducedMotion: enableReducedMotion ?? this.enableReducedMotion,
      textScale: textScale ?? this.textScale,
      enableKeyboardNavigation: enableKeyboardNavigation ?? this.enableKeyboardNavigation,
      enableVoiceControl: enableVoiceControl ?? this.enableVoiceControl,
      colorBlindnessType: colorBlindnessType ?? this.colorBlindnessType,
    );
  }

  AccessibilitySettings withValidDefaults() {
    return AccessibilitySettings(
      enableScreenReader: enableScreenReader,
      enableHighContrast: enableHighContrast,
      enableReducedMotion: enableReducedMotion,
      textScale: (textScale >= 0.5 && textScale <= 3.0) ? textScale : 1.0,
      enableKeyboardNavigation: enableKeyboardNavigation,
      enableVoiceControl: enableVoiceControl,
      colorBlindnessType: colorBlindnessType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableScreenReader': enableScreenReader,
      'enableHighContrast': enableHighContrast,
      'enableReducedMotion': enableReducedMotion,
      'textScale': textScale,
      'enableKeyboardNavigation': enableKeyboardNavigation,
      'enableVoiceControl': enableVoiceControl,
      'colorBlindnessType': colorBlindnessType.index,
    };
  }

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    return AccessibilitySettings(
      enableScreenReader: json['enableScreenReader'] as bool? ?? false,
      enableHighContrast: json['enableHighContrast'] as bool? ?? false,
      enableReducedMotion: json['enableReducedMotion'] as bool? ?? false,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      enableKeyboardNavigation: json['enableKeyboardNavigation'] as bool? ?? true,
      enableVoiceControl: json['enableVoiceControl'] as bool? ?? false,
      colorBlindnessType: ColorBlindnessType.values[json['colorBlindnessType'] as int? ?? 0],
    );
  }
}

/// Privacy settings
@immutable
class PrivacySettings {
  const PrivacySettings({
    required this.enableAnalytics,
    required this.enableCrashReporting,
    required this.enableUsageTracking,
    required this.dataRetentionDays,
    required this.enableDataExport,
    required this.enableDataDeletion,
  });

  final bool enableAnalytics;
  final bool enableCrashReporting;
  final bool enableUsageTracking;
  final int dataRetentionDays;
  final bool enableDataExport;
  final bool enableDataDeletion;

  factory PrivacySettings.defaultConfig() {
    return const PrivacySettings(
      enableAnalytics: false,
      enableCrashReporting: true,
      enableUsageTracking: false,
      dataRetentionDays: 30,
      enableDataExport: true,
      enableDataDeletion: true,
    );
  }

  PrivacySettings copyWith({
    bool? enableAnalytics,
    bool? enableCrashReporting,
    bool? enableUsageTracking,
    int? dataRetentionDays,
    bool? enableDataExport,
    bool? enableDataDeletion,
  }) {
    return PrivacySettings(
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
      enableUsageTracking: enableUsageTracking ?? this.enableUsageTracking,
      dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
      enableDataExport: enableDataExport ?? this.enableDataExport,
      enableDataDeletion: enableDataDeletion ?? this.enableDataDeletion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enableUsageTracking': enableUsageTracking,
      'dataRetentionDays': dataRetentionDays,
      'enableDataExport': enableDataExport,
      'enableDataDeletion': enableDataDeletion,
    };
  }

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      enableAnalytics: json['enableAnalytics'] as bool? ?? false,
      enableCrashReporting: json['enableCrashReporting'] as bool? ?? true,
      enableUsageTracking: json['enableUsageTracking'] as bool? ?? false,
      dataRetentionDays: json['dataRetentionDays'] as int? ?? 30,
      enableDataExport: json['enableDataExport'] as bool? ?? true,
      enableDataDeletion: json['enableDataDeletion'] as bool? ?? true,
    );
  }
}

// Enums and supporting types

enum HapticIntensity { light, medium, strong }
enum MemoryOptimizationLevel { conservative, balanced, aggressive }
enum CacheStrategy { minimal, normal, aggressive }
enum ColorBlindnessType { none, protanopia, deuteranopia, tritanopia }

/// Device information
@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.platform,
    required this.version,
    required this.model,
    required this.supportedFeatures,
  });

  final String platform;
  final String version;
  final String model;
  final List<String> supportedFeatures;
}

/// Configuration validation result
@immutable
class ValidationResult {
  const ValidationResult({
    required this.field,
    required this.isValid,
    required this.message,
  });

  final String field;
  final bool isValid;
  final String message;
}

/// Configuration health status
@immutable
class ConfigurationHealth {
  const ConfigurationHealth({
    required this.isValid,
    required this.validationResults,
    required this.configVersion,
    required this.lastUpdated,
    required this.platform,
    required this.appVersion,
  });

  final bool isValid;
  final List<ValidationResult> validationResults;
  final String configVersion;
  final DateTime lastUpdated;
  final String platform;
  final String appVersion;

  /// Get error count
  int get errorCount => validationResults.where((r) => !r.isValid).length;

  /// Get warning count (if any validation results have warnings)
  int get warningCount => 0; // Placeholder for future warning system
}

/// Configuration validation exception
class ConfigurationValidationException implements Exception {
  const ConfigurationValidationException(this.message, this.validationErrors);

  final String message;
  final List<ValidationResult> validationErrors;

  @override
  String toString() {
    final errorMessages = validationErrors.map((e) => '${e.field}: ${e.message}').join(', ');
    return 'ConfigurationValidationException: $message. Errors: $errorMessages';
  }
}