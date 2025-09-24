/// Application state management for global settings and preferences
///
/// This file provides state management for application-wide settings,
/// preferences, UI state, and other global application concerns.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/bridge_types.dart';
import '../utils/platform_utils.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

/// Provider for app state
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppStateNotifier(prefs);
});

/// Provider for theme mode
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appStateProvider).themeMode;
});

/// Provider for selected layout type
final layoutTypeProvider = Provider<FfiLayoutType>((ref) {
  return ref.watch(appStateProvider).defaultLayoutType;
});

/// Provider for recent files
final recentFilesProvider = Provider<List<RecentFile>>((ref) {
  return ref.watch(appStateProvider).recentFiles;
});

/// Provider for app settings
final appSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(appStateProvider).settings;
});

/// Provider for UI preferences
final uiPreferencesProvider = Provider<UiPreferences>((ref) {
  return ref.watch(appStateProvider).uiPreferences;
});

/// Application state data class
@immutable
class AppState {
  const AppState({
    this.themeMode = ThemeMode.system,
    this.defaultLayoutType = FfiLayoutType.radial,
    this.recentFiles = const [],
    this.settings = const AppSettings(),
    this.uiPreferences = const UiPreferences(),
    this.isFirstLaunch = true,
    this.lastWindowSize,
    this.lastWindowPosition,
  });

  final ThemeMode themeMode;
  final FfiLayoutType defaultLayoutType;
  final List<RecentFile> recentFiles;
  final AppSettings settings;
  final UiPreferences uiPreferences;
  final bool isFirstLaunch;
  final Size? lastWindowSize;
  final Offset? lastWindowPosition;

  /// Check if dark mode is currently active
  bool isDarkMode(BuildContext context) {
    switch (themeMode) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

  /// Copy with updated fields
  AppState copyWith({
    ThemeMode? themeMode,
    FfiLayoutType? defaultLayoutType,
    List<RecentFile>? recentFiles,
    AppSettings? settings,
    UiPreferences? uiPreferences,
    bool? isFirstLaunch,
    Size? lastWindowSize,
    Offset? lastWindowPosition,
  }) {
    return AppState(
      themeMode: themeMode ?? this.themeMode,
      defaultLayoutType: defaultLayoutType ?? this.defaultLayoutType,
      recentFiles: recentFiles ?? this.recentFiles,
      settings: settings ?? this.settings,
      uiPreferences: uiPreferences ?? this.uiPreferences,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      lastWindowSize: lastWindowSize ?? this.lastWindowSize,
      lastWindowPosition: lastWindowPosition ?? this.lastWindowPosition,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'defaultLayoutType': defaultLayoutType.index,
      'recentFiles': recentFiles.map((f) => f.toJson()).toList(),
      'settings': settings.toJson(),
      'uiPreferences': uiPreferences.toJson(),
      'isFirstLaunch': isFirstLaunch,
      'lastWindowSize': lastWindowSize != null
          ? {'width': lastWindowSize!.width, 'height': lastWindowSize!.height}
          : null,
      'lastWindowPosition': lastWindowPosition != null
          ? {'dx': lastWindowPosition!.dx, 'dy': lastWindowPosition!.dy}
          : null,
    };
  }

  /// Create from JSON
  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      defaultLayoutType: FfiLayoutType.values[json['defaultLayoutType'] as int? ?? 0],
      recentFiles: (json['recentFiles'] as List<dynamic>?)
              ?.map((f) => RecentFile.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      settings: AppSettings.fromJson(
          json['settings'] as Map<String, dynamic>? ?? {}),
      uiPreferences: UiPreferences.fromJson(
          json['uiPreferences'] as Map<String, dynamic>? ?? {}),
      isFirstLaunch: json['isFirstLaunch'] as bool? ?? true,
      lastWindowSize: json['lastWindowSize'] != null
          ? Size(
              (json['lastWindowSize']['width'] as num).toDouble(),
              (json['lastWindowSize']['height'] as num).toDouble(),
            )
          : null,
      lastWindowPosition: json['lastWindowPosition'] != null
          ? Offset(
              (json['lastWindowPosition']['dx'] as num).toDouble(),
              (json['lastWindowPosition']['dy'] as num).toDouble(),
            )
          : null,
    );
  }

  @override
  String toString() {
    return 'AppState('
        'themeMode: $themeMode, '
        'defaultLayoutType: $defaultLayoutType, '
        'recentFiles: ${recentFiles.length}, '
        'isFirstLaunch: $isFirstLaunch'
        ')';
  }
}

/// Recent file data class
@immutable
class RecentFile {
  const RecentFile({
    required this.path,
    required this.name,
    required this.lastOpened,
    this.size,
    this.nodeCount,
  });

  final String path;
  final String name;
  final DateTime lastOpened;
  final int? size; // File size in bytes
  final int? nodeCount;

  /// Get display name for the file
  String get displayName {
    if (name.isNotEmpty) return name;
    return path.split('/').last.split('\\').last;
  }

  /// Get formatted file size
  String? get formattedSize {
    if (size == null) return null;
    if (size! < 1024) return '${size}B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)}KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get relative time string
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(lastOpened);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'lastOpened': lastOpened.millisecondsSinceEpoch,
      'size': size,
      'nodeCount': nodeCount,
    };
  }

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      path: json['path'] as String,
      name: json['name'] as String,
      lastOpened: DateTime.fromMillisecondsSinceEpoch(json['lastOpened'] as int),
      size: json['size'] as int?,
      nodeCount: json['nodeCount'] as int?,
    );
  }

  @override
  String toString() => 'RecentFile($displayName, $relativeTime)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentFile && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// Application settings data class
@immutable
class AppSettings {
  const AppSettings({
    this.autoSave = true,
    this.autoSaveInterval = const Duration(minutes: 5),
    this.maxRecentFiles = 10,
    this.enableAnimations = true,
    this.enableHapticFeedback = true,
    this.defaultExportFormat = ExportFormat.png,
    this.enableDebugMode = false,
    this.logLevel = 'info',
    this.enableCrashReporting = true,
    this.enableAnalytics = false,
  });

  final bool autoSave;
  final Duration autoSaveInterval;
  final int maxRecentFiles;
  final bool enableAnimations;
  final bool enableHapticFeedback;
  final ExportFormat defaultExportFormat;
  final bool enableDebugMode;
  final String logLevel;
  final bool enableCrashReporting;
  final bool enableAnalytics;

  AppSettings copyWith({
    bool? autoSave,
    Duration? autoSaveInterval,
    int? maxRecentFiles,
    bool? enableAnimations,
    bool? enableHapticFeedback,
    ExportFormat? defaultExportFormat,
    bool? enableDebugMode,
    String? logLevel,
    bool? enableCrashReporting,
    bool? enableAnalytics,
  }) {
    return AppSettings(
      autoSave: autoSave ?? this.autoSave,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
      maxRecentFiles: maxRecentFiles ?? this.maxRecentFiles,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      enableDebugMode: enableDebugMode ?? this.enableDebugMode,
      logLevel: logLevel ?? this.logLevel,
      enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSave': autoSave,
      'autoSaveIntervalMinutes': autoSaveInterval.inMinutes,
      'maxRecentFiles': maxRecentFiles,
      'enableAnimations': enableAnimations,
      'enableHapticFeedback': enableHapticFeedback,
      'defaultExportFormat': defaultExportFormat.index,
      'enableDebugMode': enableDebugMode,
      'logLevel': logLevel,
      'enableCrashReporting': enableCrashReporting,
      'enableAnalytics': enableAnalytics,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoSave: json['autoSave'] as bool? ?? true,
      autoSaveInterval: Duration(
          minutes: json['autoSaveIntervalMinutes'] as int? ?? 5),
      maxRecentFiles: json['maxRecentFiles'] as int? ?? 10,
      enableAnimations: json['enableAnimations'] as bool? ?? true,
      enableHapticFeedback: json['enableHapticFeedback'] as bool? ?? true,
      defaultExportFormat: ExportFormat.values[
          json['defaultExportFormat'] as int? ?? ExportFormat.png.index],
      enableDebugMode: json['enableDebugMode'] as bool? ?? false,
      logLevel: json['logLevel'] as String? ?? 'info',
      enableCrashReporting: json['enableCrashReporting'] as bool? ?? true,
      enableAnalytics: json['enableAnalytics'] as bool? ?? false,
    );
  }
}

/// UI preferences data class
@immutable
class UiPreferences {
  const UiPreferences({
    this.showToolbar = true,
    this.showStatusBar = true,
    this.showMinimap = false,
    this.enableGridSnap = true,
    this.gridSize = 20.0,
    this.enableRulers = false,
    this.nodeStyle = NodeStyle.rounded,
    this.defaultFontSize = 14.0,
    this.zoomLevel = 1.0,
    this.panSensitivity = 1.0,
    this.zoomSensitivity = 1.0,
  });

  final bool showToolbar;
  final bool showStatusBar;
  final bool showMinimap;
  final bool enableGridSnap;
  final double gridSize;
  final bool enableRulers;
  final NodeStyle nodeStyle;
  final double defaultFontSize;
  final double zoomLevel;
  final double panSensitivity;
  final double zoomSensitivity;

  UiPreferences copyWith({
    bool? showToolbar,
    bool? showStatusBar,
    bool? showMinimap,
    bool? enableGridSnap,
    double? gridSize,
    bool? enableRulers,
    NodeStyle? nodeStyle,
    double? defaultFontSize,
    double? zoomLevel,
    double? panSensitivity,
    double? zoomSensitivity,
  }) {
    return UiPreferences(
      showToolbar: showToolbar ?? this.showToolbar,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      showMinimap: showMinimap ?? this.showMinimap,
      enableGridSnap: enableGridSnap ?? this.enableGridSnap,
      gridSize: gridSize ?? this.gridSize,
      enableRulers: enableRulers ?? this.enableRulers,
      nodeStyle: nodeStyle ?? this.nodeStyle,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      panSensitivity: panSensitivity ?? this.panSensitivity,
      zoomSensitivity: zoomSensitivity ?? this.zoomSensitivity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showToolbar': showToolbar,
      'showStatusBar': showStatusBar,
      'showMinimap': showMinimap,
      'enableGridSnap': enableGridSnap,
      'gridSize': gridSize,
      'enableRulers': enableRulers,
      'nodeStyle': nodeStyle.index,
      'defaultFontSize': defaultFontSize,
      'zoomLevel': zoomLevel,
      'panSensitivity': panSensitivity,
      'zoomSensitivity': zoomSensitivity,
    };
  }

  factory UiPreferences.fromJson(Map<String, dynamic> json) {
    return UiPreferences(
      showToolbar: json['showToolbar'] as bool? ?? true,
      showStatusBar: json['showStatusBar'] as bool? ?? true,
      showMinimap: json['showMinimap'] as bool? ?? false,
      enableGridSnap: json['enableGridSnap'] as bool? ?? true,
      gridSize: (json['gridSize'] as num?)?.toDouble() ?? 20.0,
      enableRulers: json['enableRulers'] as bool? ?? false,
      nodeStyle: NodeStyle.values[json['nodeStyle'] as int? ?? 0],
      defaultFontSize: (json['defaultFontSize'] as num?)?.toDouble() ?? 14.0,
      zoomLevel: (json['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      panSensitivity: (json['panSensitivity'] as num?)?.toDouble() ?? 1.0,
      zoomSensitivity: (json['zoomSensitivity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Node style enumeration
enum NodeStyle {
  rounded,
  rectangular,
  circular,
  hexagonal,
}

/// Application state notifier
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this._prefs) : super(const AppState()) {
    _logger = Logger();
    _loadState();
  }

  final SharedPreferences _prefs;
  late final Logger _logger;

  static const String _stateKey = 'app_state';
  static const int _maxRecentFiles = 20;

  // Theme Management

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await _saveState();
    _logger.d('Theme mode changed to: $themeMode');
  }

  /// Toggle theme mode
  Future<void> toggleThemeMode() async {
    final newMode = switch (state.themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setThemeMode(newMode);
  }

  // Layout Management

  /// Set default layout type
  Future<void> setDefaultLayoutType(FfiLayoutType layoutType) async {
    state = state.copyWith(defaultLayoutType: layoutType);
    await _saveState();
    _logger.d('Default layout type changed to: ${layoutType.displayName}');
  }

  // Recent Files Management

  /// Add file to recent files list
  Future<void> addRecentFile(RecentFile file) async {
    final recentFiles = List<RecentFile>.from(state.recentFiles);

    // Remove existing entry if present
    recentFiles.removeWhere((f) => f.path == file.path);

    // Add to beginning of list
    recentFiles.insert(0, file);

    // Limit list size
    final limitedFiles = recentFiles.take(_maxRecentFiles).toList();

    state = state.copyWith(recentFiles: limitedFiles);
    await _saveState();

    _logger.d('Added recent file: ${file.displayName}');
  }

  /// Remove file from recent files list
  Future<void> removeRecentFile(String path) async {
    final recentFiles = state.recentFiles.where((f) => f.path != path).toList();
    state = state.copyWith(recentFiles: recentFiles);
    await _saveState();

    _logger.d('Removed recent file: $path');
  }

  /// Clear all recent files
  Future<void> clearRecentFiles() async {
    state = state.copyWith(recentFiles: []);
    await _saveState();
    _logger.d('Cleared all recent files');
  }

  // Settings Management

  /// Update app settings
  Future<void> updateSettings(AppSettings settings) async {
    state = state.copyWith(settings: settings);
    await _saveState();
    _logger.d('Updated app settings');
  }

  /// Update UI preferences
  Future<void> updateUiPreferences(UiPreferences preferences) async {
    state = state.copyWith(uiPreferences: preferences);
    await _saveState();
    _logger.d('Updated UI preferences');
  }

  // Window State Management (Desktop only)

  /// Set window size
  Future<void> setWindowSize(Size size) async {
    if (!PlatformUtils.supportsWindowManagement) return;

    state = state.copyWith(lastWindowSize: size);
    await _saveState();
  }

  /// Set window position
  Future<void> setWindowPosition(Offset position) async {
    if (!PlatformUtils.supportsWindowManagement) return;

    state = state.copyWith(lastWindowPosition: position);
    await _saveState();
  }

  // First Launch Management

  /// Mark first launch as completed
  Future<void> completeFirstLaunch() async {
    state = state.copyWith(isFirstLaunch: false);
    await _saveState();
    _logger.i('First launch completed');
  }

  // Quick Settings

  /// Toggle auto-save
  Future<void> toggleAutoSave() async {
    final newSettings = state.settings.copyWith(
      autoSave: !state.settings.autoSave,
    );
    await updateSettings(newSettings);
  }

  /// Toggle animations
  Future<void> toggleAnimations() async {
    final newSettings = state.settings.copyWith(
      enableAnimations: !state.settings.enableAnimations,
    );
    await updateSettings(newSettings);
  }

  /// Toggle haptic feedback
  Future<void> toggleHapticFeedback() async {
    final newSettings = state.settings.copyWith(
      enableHapticFeedback: !state.settings.enableHapticFeedback,
    );
    await updateSettings(newSettings);
  }

  /// Toggle toolbar visibility
  Future<void> toggleToolbar() async {
    final newPreferences = state.uiPreferences.copyWith(
      showToolbar: !state.uiPreferences.showToolbar,
    );
    await updateUiPreferences(newPreferences);
  }

  /// Toggle status bar visibility
  Future<void> toggleStatusBar() async {
    final newPreferences = state.uiPreferences.copyWith(
      showStatusBar: !state.uiPreferences.showStatusBar,
    );
    await updateUiPreferences(newPreferences);
  }

  /// Set zoom level
  Future<void> setZoomLevel(double zoomLevel) async {
    final clampedZoom = zoomLevel.clamp(0.1, 5.0);
    final newPreferences = state.uiPreferences.copyWith(zoomLevel: clampedZoom);
    await updateUiPreferences(newPreferences);
  }

  /// Reset zoom level
  Future<void> resetZoom() async {
    await setZoomLevel(1.0);
  }

  // Private Methods

  /// Load state from SharedPreferences
  Future<void> _loadState() async {
    try {
      final stateJson = _prefs.getString(_stateKey);
      if (stateJson != null) {
        final stateData = jsonDecode(stateJson) as Map<String, dynamic>;
        state = AppState.fromJson(stateData);
        _logger.d('Loaded app state from preferences');
      }
    } catch (e) {
      _logger.w('Failed to load app state, using defaults', error: e);
      state = const AppState();
    }
  }

  /// Save state to SharedPreferences
  Future<void> _saveState() async {
    try {
      final stateJson = jsonEncode(state.toJson());
      await _prefs.setString(_stateKey, stateJson);
      _logger.v('Saved app state to preferences');
    } catch (e) {
      _logger.e('Failed to save app state', error: e);
    }
  }
}