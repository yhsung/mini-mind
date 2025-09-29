/// Settings screen with comprehensive AppConfig integration
///
/// This screen provides a complete interface for managing all application
/// settings through the AppConfig system, organized by categories with
/// real-time preview and validation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/platform_utils.dart';
import '../utils/error_handler.dart';
import '../bridge/bridge_types.dart';

/// Settings screen with categorized configuration options
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {

  late TabController _tabController;
  AppConfigData? _currentConfig;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    try {
      _currentConfig = AppConfig.instance.config;
      setState(() {});
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'load_settings_config'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentConfig == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_hasUnsavedChanges)
            TextButton(
              onPressed: _resetChanges,
              child: const Text('Reset'),
            ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _restoreDefaults,
            tooltip: 'Restore Defaults',
          ),
          if (_hasUnsavedChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.palette), text: 'Theme'),
            Tab(icon: Icon(Icons.settings), text: 'General'),
            Tab(icon: Icon(Icons.view_compact), text: 'Interface'),
            Tab(icon: Icon(Icons.speed), text: 'Performance'),
            Tab(icon: Icon(Icons.accessibility), text: 'Accessibility'),
            Tab(icon: Icon(Icons.privacy_tip), text: 'Privacy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildThemeSettings(),
          _buildGeneralSettings(),
          _buildInterfaceSettings(),
          _buildPerformanceSettings(),
          _buildAccessibilitySettings(),
          _buildPrivacySettings(),
        ],
      ),
    );
  }

  Widget _buildThemeSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Theme Mode'),
        Card(
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System'),
                subtitle: const Text('Follow system setting'),
                value: ThemeMode.system,
                groupValue: _currentConfig!.theme.themeMode,
                onChanged: (value) => _updateThemeMode(value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                subtitle: const Text('Always use light theme'),
                value: ThemeMode.light,
                groupValue: _currentConfig!.theme.themeMode,
                onChanged: (value) => _updateThemeMode(value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                subtitle: const Text('Always use dark theme'),
                value: ThemeMode.dark,
                groupValue: _currentConfig!.theme.themeMode,
                onChanged: (value) => _updateThemeMode(value!),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Colors'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Primary Color'),
                trailing: Container(
                  width: 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _currentConfig!.theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                onTap: () => _showColorPicker(
                  'Primary Color',
                  _currentConfig!.theme.primaryColor,
                  _updatePrimaryColor,
                ),
              ),
              SwitchListTile(
                title: const Text('Material You'),
                subtitle: const Text('Dynamic color support (Android 12+)'),
                value: _currentConfig!.theme.useMaterialYou,
                onChanged: _updateMaterialYou,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Typography'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Font Size'),
                subtitle: Text('${_currentConfig!.theme.fontSize.toInt()}pt'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _currentConfig!.theme.fontSize,
                    min: 8.0,
                    max: 24.0,
                    divisions: 16,
                    onChanged: _updateFontSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('File Operations'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Auto Save'),
                subtitle: const Text('Automatically save changes'),
                value: _currentConfig!.app.autoSave,
                onChanged: _updateAutoSave,
              ),
              if (_currentConfig!.app.autoSave)
                ListTile(
                  title: const Text('Auto Save Interval'),
                  subtitle: Text('${_currentConfig!.app.autoSaveInterval.inMinutes} minutes'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: _currentConfig!.app.autoSaveInterval.inMinutes.toDouble(),
                      min: 1.0,
                      max: 30.0,
                      divisions: 29,
                      onChanged: (value) => _updateAutoSaveInterval(
                        Duration(minutes: value.toInt()),
                      ),
                    ),
                  ),
                ),
              ListTile(
                title: const Text('Recent Files'),
                subtitle: Text('Keep ${_currentConfig!.app.maxRecentFiles} recent files'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _currentConfig!.app.maxRecentFiles.toDouble(),
                    min: 0.0,
                    max: 20.0,
                    divisions: 20,
                    onChanged: (value) => _updateMaxRecentFiles(value.toInt()),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Default Formats'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Layout Type'),
                subtitle: Text(_getLayoutTypeName(_currentConfig!.app.defaultLayoutType)),
                trailing: DropdownButton<FfiLayoutType>(
                  value: _currentConfig!.app.defaultLayoutType,
                  items: FfiLayoutType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getLayoutTypeName(type)),
                    );
                  }).toList(),
                  onChanged: _updateDefaultLayoutType,
                ),
              ),
              ListTile(
                title: const Text('Export Format'),
                subtitle: Text(_getExportFormatName(_currentConfig!.app.defaultExportFormat)),
                trailing: DropdownButton<ExportFormat>(
                  value: _currentConfig!.app.defaultExportFormat,
                  items: ExportFormat.values.map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Text(_getExportFormatName(format)),
                    );
                  }).toList(),
                  onChanged: _updateDefaultExportFormat,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Feedback'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Animations'),
                subtitle: const Text('Enable UI animations'),
                value: _currentConfig!.app.enableAnimations,
                onChanged: _updateEnableAnimations,
              ),
              SwitchListTile(
                title: const Text('Haptic Feedback'),
                subtitle: const Text('Vibration on interactions'),
                value: _currentConfig!.app.enableHapticFeedback,
                onChanged: _updateEnableHapticFeedback,
              ),
              SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Audio feedback'),
                value: _currentConfig!.app.enableSoundEffects,
                onChanged: _updateEnableSoundEffects,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInterfaceSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Display'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Show Toolbar'),
                value: _currentConfig!.ui.showToolbar,
                onChanged: _updateShowToolbar,
              ),
              SwitchListTile(
                title: const Text('Show Status Bar'),
                value: _currentConfig!.ui.showStatusBar,
                onChanged: _updateShowStatusBar,
              ),
              SwitchListTile(
                title: const Text('Show Minimap'),
                value: _currentConfig!.ui.showMinimap,
                onChanged: _updateShowMinimap,
              ),
              SwitchListTile(
                title: const Text('Compact Mode'),
                subtitle: const Text('Optimize for smaller screens'),
                value: _currentConfig!.ui.compactMode,
                onChanged: _updateCompactMode,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Canvas'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Grid Snap'),
                subtitle: const Text('Snap nodes to grid'),
                value: _currentConfig!.ui.enableGridSnap,
                onChanged: _updateEnableGridSnap,
              ),
              if (_currentConfig!.ui.enableGridSnap)
                ListTile(
                  title: const Text('Grid Size'),
                  subtitle: Text('${_currentConfig!.ui.gridSize.toInt()}px'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: _currentConfig!.ui.gridSize,
                      min: 5.0,
                      max: 50.0,
                      divisions: 45,
                      onChanged: _updateGridSize,
                    ),
                  ),
                ),
              ListTile(
                title: const Text('Zoom Sensitivity'),
                subtitle: Text('${(_currentConfig!.ui.zoomSensitivity * 100).toInt()}%'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _currentConfig!.ui.zoomSensitivity,
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    onChanged: _updateZoomSensitivity,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Acceleration'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Hardware Acceleration'),
                subtitle: const Text('Use GPU for rendering'),
                value: _currentConfig!.performance.enableHardwareAcceleration,
                onChanged: PlatformUtils.isWeb ? null : _updateEnableHardwareAcceleration,
              ),
              SwitchListTile(
                title: const Text('Lazy Loading'),
                subtitle: const Text('Load content on demand'),
                value: _currentConfig!.performance.enableLazyLoading,
                onChanged: _updateEnableLazyLoading,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Memory'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Cache Size'),
                subtitle: Text('${_currentConfig!.performance.maxCacheSize} MB'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _currentConfig!.performance.maxCacheSize.toDouble(),
                    min: 10.0,
                    max: 500.0,
                    divisions: 49,
                    onChanged: (value) => _updateMaxCacheSize(value.toInt()),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Memory Optimization'),
                subtitle: Text(_getMemoryOptimizationName(_currentConfig!.performance.memoryOptimizationLevel)),
                trailing: DropdownButton<MemoryOptimizationLevel>(
                  value: _currentConfig!.performance.memoryOptimizationLevel,
                  items: MemoryOptimizationLevel.values.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(_getMemoryOptimizationName(level)),
                    );
                  }).toList(),
                  onChanged: _updateMemoryOptimizationLevel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilitySettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Visual'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('High Contrast'),
                subtitle: const Text('Increase visual contrast'),
                value: _currentConfig!.accessibility.enableHighContrast,
                onChanged: _updateEnableHighContrast,
              ),
              SwitchListTile(
                title: const Text('Reduced Motion'),
                subtitle: const Text('Minimize animations'),
                value: _currentConfig!.accessibility.enableReducedMotion,
                onChanged: _updateEnableReducedMotion,
              ),
              ListTile(
                title: const Text('Text Scale'),
                subtitle: Text('${(_currentConfig!.accessibility.textScale * 100).toInt()}%'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _currentConfig!.accessibility.textScale,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    onChanged: _updateTextScale,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Interaction'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Screen Reader'),
                subtitle: const Text('Enable screen reader support'),
                value: _currentConfig!.accessibility.enableScreenReader,
                onChanged: _updateEnableScreenReader,
              ),
              SwitchListTile(
                title: const Text('Keyboard Navigation'),
                subtitle: const Text('Navigate with keyboard'),
                value: _currentConfig!.accessibility.enableKeyboardNavigation,
                onChanged: _updateEnableKeyboardNavigation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Data Collection'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Analytics'),
                subtitle: const Text('Help improve the app'),
                value: _currentConfig!.privacy.enableAnalytics,
                onChanged: _updateEnableAnalytics,
              ),
              SwitchListTile(
                title: const Text('Crash Reporting'),
                subtitle: const Text('Send crash reports'),
                value: _currentConfig!.privacy.enableCrashReporting,
                onChanged: _updateEnableCrashReporting,
              ),
              SwitchListTile(
                title: const Text('Usage Tracking'),
                subtitle: const Text('Track feature usage'),
                value: _currentConfig!.privacy.enableUsageTracking,
                onChanged: _updateEnableUsageTracking,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Data Management'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Data Retention'),
                subtitle: Text('${_currentConfig!.privacy.dataRetentionDays} days'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _currentConfig!.privacy.dataRetentionDays.toDouble(),
                    min: 1.0,
                    max: 365.0,
                    divisions: 364,
                    onChanged: (value) => _updateDataRetentionDays(value.toInt()),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Export Data'),
                subtitle: const Text('Export your settings and data'),
                trailing: const Icon(Icons.download),
                onTap: _exportData,
              ),
              ListTile(
                title: const Text('Clear Data'),
                subtitle: const Text('Delete all app data'),
                trailing: const Icon(Icons.delete_forever, color: Colors.red),
                onTap: _clearAllData,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Update methods
  void _updateThemeMode(ThemeMode mode) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        theme: _currentConfig!.theme.copyWith(themeMode: mode),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updatePrimaryColor(Color color) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        theme: _currentConfig!.theme.copyWith(primaryColor: color),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateMaterialYou(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        theme: _currentConfig!.theme.copyWith(useMaterialYou: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateFontSize(double size) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        theme: _currentConfig!.theme.copyWith(fontSize: size),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateAutoSave(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(autoSave: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateAutoSaveInterval(Duration interval) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(autoSaveInterval: interval),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateMaxRecentFiles(int count) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(maxRecentFiles: count),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateDefaultLayoutType(FfiLayoutType? type) {
    if (type == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(defaultLayoutType: type),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateDefaultExportFormat(ExportFormat? format) {
    if (format == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(defaultExportFormat: format),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableAnimations(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(enableAnimations: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableHapticFeedback(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(enableHapticFeedback: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableSoundEffects(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        app: _currentConfig!.app.copyWith(enableSoundEffects: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateShowToolbar(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(showToolbar: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateShowStatusBar(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(showStatusBar: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateShowMinimap(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(showMinimap: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateCompactMode(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(compactMode: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableGridSnap(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(enableGridSnap: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateGridSize(double size) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(gridSize: size),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateZoomSensitivity(double sensitivity) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        ui: _currentConfig!.ui.copyWith(zoomSensitivity: sensitivity),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableHardwareAcceleration(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        performance: _currentConfig!.performance.copyWith(enableHardwareAcceleration: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableLazyLoading(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        performance: _currentConfig!.performance.copyWith(enableLazyLoading: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateMaxCacheSize(int size) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        performance: _currentConfig!.performance.copyWith(maxCacheSize: size),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateMemoryOptimizationLevel(MemoryOptimizationLevel? level) {
    if (level == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        performance: _currentConfig!.performance.copyWith(memoryOptimizationLevel: level),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableHighContrast(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        accessibility: _currentConfig!.accessibility.copyWith(enableHighContrast: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableReducedMotion(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        accessibility: _currentConfig!.accessibility.copyWith(enableReducedMotion: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateTextScale(double scale) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        accessibility: _currentConfig!.accessibility.copyWith(textScale: scale),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableScreenReader(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        accessibility: _currentConfig!.accessibility.copyWith(enableScreenReader: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableKeyboardNavigation(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        accessibility: _currentConfig!.accessibility.copyWith(enableKeyboardNavigation: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableAnalytics(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        privacy: _currentConfig!.privacy.copyWith(enableAnalytics: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableCrashReporting(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        privacy: _currentConfig!.privacy.copyWith(enableCrashReporting: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateEnableUsageTracking(bool? value) {
    if (value == null) return;
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        privacy: _currentConfig!.privacy.copyWith(enableUsageTracking: value),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _updateDataRetentionDays(int days) {
    setState(() {
      _currentConfig = _currentConfig!.copyWith(
        privacy: _currentConfig!.privacy.copyWith(dataRetentionDays: days),
      );
      _hasUnsavedChanges = true;
    });
  }

  // Helper methods
  String _getLayoutTypeName(FfiLayoutType type) {
    switch (type) {
      case FfiLayoutType.radial:
        return 'Radial';
      case FfiLayoutType.tree:
        return 'Tree';
      case FfiLayoutType.forceDirected:
        return 'Force Directed';
    }
  }

  String _getExportFormatName(ExportFormat format) {
    switch (format) {
      case ExportFormat.opml:
        return 'OPML';
      case ExportFormat.png:
        return 'PNG Image';
      case ExportFormat.svg:
        return 'SVG Vector';
      case ExportFormat.pdf:
        return 'PDF Document';
      case ExportFormat.markdown:
        return 'Markdown';
    }
  }

  String _getMemoryOptimizationName(MemoryOptimizationLevel level) {
    switch (level) {
      case MemoryOptimizationLevel.conservative:
        return 'Conservative';
      case MemoryOptimizationLevel.balanced:
        return 'Balanced';
      case MemoryOptimizationLevel.aggressive:
        return 'Aggressive';
    }
  }

  // Action methods
  Future<void> _saveChanges() async {
    try {
      await AppConfig.instance.updateConfig(_currentConfig!);
      setState(() {
        _hasUnsavedChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'save_settings'},
      );
    }
  }

  void _resetChanges() {
    setState(() {
      _currentConfig = AppConfig.instance.config;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Defaults'),
        content: const Text('This will reset all settings to their default values. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AppConfig.instance.resetToDefaults();
        setState(() {
          _currentConfig = AppConfig.instance.config;
          _hasUnsavedChanges = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings restored to defaults')),
          );
        }
      } catch (e, stackTrace) {
        await GlobalErrorHandler.instance.handleError(
          e,
          stackTrace,
          context: context,
          additionalContext: {'operation': 'restore_defaults'},
        );
      }
    }
  }

  void _showColorPicker(String title, Color currentColor, Function(Color) onChanged) {
    // Simple color picker - in a real app, you might use a more sophisticated picker
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Color picker not implemented yet'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final data = AppConfig.instance.exportConfiguration();
      // In a real app, you would save this to a file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export functionality not implemented yet')),
        );
      }
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'export_data'},
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete all app data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AppConfig.instance.clearAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e, stackTrace) {
        await GlobalErrorHandler.instance.handleError(
          e,
          stackTrace,
          context: context,
          additionalContext: {'operation': 'clear_all_data'},
        );
      }
    }
  }
}