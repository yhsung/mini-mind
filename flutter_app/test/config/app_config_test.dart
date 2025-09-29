import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/config/app_config.dart';
import '../../lib/bridge/bridge_types.dart';

void main() {
  group('AppConfig Tests', () {
    setUp(() {
      // Initialize SharedPreferences with empty data for each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Default configuration should be valid', () {
      final defaultConfig = AppConfigData.defaultConfig();

      expect(defaultConfig.configVersion, '1.0.0');
      expect(defaultConfig.theme.themeMode, ThemeMode.system);
      expect(defaultConfig.app.autoSave, true);
      expect(defaultConfig.ui.showToolbar, true);
      expect(defaultConfig.performance.enableHardwareAcceleration, isA<bool>());
      expect(defaultConfig.accessibility.enableScreenReader, false);
      expect(defaultConfig.privacy.enableAnalytics, false);
    });

    test('Configuration should support JSON serialization', () {
      final config = AppConfigData.defaultConfig();
      final json = config.toJson();
      final restored = AppConfigData.fromJson(json);

      expect(restored.configVersion, config.configVersion);
      expect(restored.theme.themeMode, config.theme.themeMode);
      expect(restored.app.autoSave, config.app.autoSave);
      expect(restored.ui.showToolbar, config.ui.showToolbar);
    });

    test('Theme configuration should support custom colors', () {
      final themeConfig = ThemeConfiguration.defaultConfig().copyWith(
        primaryColor: Colors.red,
        customColors: {'accent': Colors.green},
      );

      expect(themeConfig.primaryColor, Colors.red);
      expect(themeConfig.customColors['accent'], Colors.green);
    });

    test('Validation should catch invalid values', () {
      final appConfig = AppConfig();

      // Test invalid font size
      final invalidTheme = ThemeConfiguration.defaultConfig().copyWith(
        fontSize: 100.0, // Invalid - too large
      );

      final config = AppConfigData.defaultConfig().copyWith(theme: invalidTheme);

      expect(() => appConfig.updateConfig(config), throwsA(isA<ConfigurationValidationException>()));
    });

    test('Platform-specific settings should have correct defaults', () {
      final platformSettings = PlatformSpecificSettings.defaultConfig();

      expect(platformSettings.mobileSettings.enableOrientationLock, false);
      expect(platformSettings.desktopSettings.enableWindowControls, true);
      expect(platformSettings.webSettings.enablePWAMode, true);
    });

    test('Performance settings should validate cache size', () {
      final perfSettings = PerformanceSettings.defaultConfig().copyWith(
        maxCacheSize: 50, // Valid
      );

      expect(perfSettings.maxCacheSize, 50);

      final validatedSettings = perfSettings.withValidDefaults();
      expect(validatedSettings.maxCacheSize, 50);
    });

    test('Accessibility settings should validate text scale', () {
      final accessibilitySettings = AccessibilitySettings.defaultConfig().copyWith(
        textScale: 5.0, // Invalid - too large
      );

      final validatedSettings = accessibilitySettings.withValidDefaults();
      expect(validatedSettings.textScale, 1.0); // Should revert to default
    });

    test('Configuration health check should work', () async {
      final appConfig = AppConfig();
      await appConfig.initialize();

      final health = appConfig.getConfigurationHealth();

      expect(health.isValid, true);
      expect(health.configVersion, isNotEmpty);
      expect(health.platform, isNotEmpty);
      expect(health.appVersion, isNotEmpty);
    });
  });
}