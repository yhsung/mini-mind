/// Central providers file for all application state management
///
/// This file provides a centralized location for all Riverpod providers
/// and state management utilities used throughout the application.

export 'mindmap_state.dart';
export 'app_state.dart';
export 'state_persistence.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/mindmap_bridge.dart';
import 'app_state.dart';
import 'mindmap_state.dart';

/// Initialize all providers and state management
class StateProviders {
  StateProviders._();

  /// Initialize SharedPreferences and return the override
  static Future<Override> initializeSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return sharedPreferencesProvider.overrideWithValue(prefs);
  }

  /// Initialize MindmapBridge and return the override
  static Future<Override> initializeMindmapBridge() async {
    final bridge = MindmapBridge.instance;
    await bridge.initialize();
    return mindmapBridgeProvider.overrideWithValue(bridge);
  }

  /// Get all provider overrides for app initialization
  static Future<List<Override>> getAllOverrides() async {
    return [
      await initializeSharedPreferences(),
      await initializeMindmapBridge(),
    ];
  }
}

/// Additional utility providers

/// Provider for checking if the app is in debug mode
final debugModeProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).settings.enableDebugMode;
});

/// Provider for checking if animations are enabled
final animationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).settings.enableAnimations;
});

/// Provider for checking if haptic feedback is enabled
final hapticFeedbackEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).settings.enableHapticFeedback;
});

/// Provider for auto-save enabled state
final autoSaveEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).settings.autoSave;
});

/// Provider for auto-save interval
final autoSaveIntervalProvider = Provider<Duration>((ref) {
  return ref.watch(appStateProvider).settings.autoSaveInterval;
});

/// Provider for maximum recent files
final maxRecentFilesProvider = Provider<int>((ref) {
  return ref.watch(appStateProvider).settings.maxRecentFiles;
});

/// Provider for grid snap enabled state
final gridSnapEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).uiPreferences.enableGridSnap;
});

/// Provider for grid size
final gridSizeProvider = Provider<double>((ref) {
  return ref.watch(appStateProvider).uiPreferences.gridSize;
});

/// Provider for default font size
final defaultFontSizeProvider = Provider<double>((ref) {
  return ref.watch(appStateProvider).uiPreferences.defaultFontSize;
});

/// Provider for current zoom level
final zoomLevelProvider = Provider<double>((ref) {
  return ref.watch(appStateProvider).uiPreferences.zoomLevel;
});

/// Provider for pan sensitivity
final panSensitivityProvider = Provider<double>((ref) {
  return ref.watch(appStateProvider).uiPreferences.panSensitivity;
});

/// Provider for zoom sensitivity
final zoomSensitivityProvider = Provider<double>((ref) {
  return ref.watch(appStateProvider).uiPreferences.zoomSensitivity;
});

/// Provider for toolbar visibility
final toolbarVisibleProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).uiPreferences.showToolbar;
});

/// Provider for status bar visibility
final statusBarVisibleProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).uiPreferences.showStatusBar;
});

/// Provider for minimap visibility
final minimapVisibleProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).uiPreferences.showMinimap;
});

/// Provider for rulers visibility
final rulersVisibleProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).uiPreferences.enableRulers;
});

/// Provider for node style
final nodeStyleProvider = Provider<NodeStyle>((ref) {
  return ref.watch(appStateProvider).uiPreferences.nodeStyle;
});

/// Provider for default export format
final defaultExportFormatProvider = Provider<ExportFormat>((ref) {
  return ref.watch(appStateProvider).settings.defaultExportFormat;
});

/// Provider that combines mindmap and app loading states
final globalLoadingProvider = Provider<bool>((ref) {
  final mindmapLoading = ref.watch(isLoadingProvider);
  // Add other loading states here if needed
  return mindmapLoading;
});

/// Provider that combines all error states
final globalErrorProvider = Provider<Exception?>((ref) {
  final mindmapError = ref.watch(errorProvider);
  // Add other error states here if needed
  return mindmapError;
});

/// Provider for checking if there are any unsaved changes
final hasUnsavedChangesProvider = Provider<bool>((ref) {
  final mindmapState = ref.watch(mindmapStateProvider);
  return mindmapState.isDirty;
});

/// Provider for checking if undo is available
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(mindmapStateProvider).canUndo;
});

/// Provider for checking if redo is available
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(mindmapStateProvider).canRedo;
});

/// Provider for current mindmap title
final mindmapTitleProvider = Provider<String?>((ref) {
  return ref.watch(mindmapDataProvider)?.title;
});

/// Provider for mindmap node count
final mindmapNodeCountProvider = Provider<int>((ref) {
  return ref.watch(nodesProvider).length;
});

/// Provider for checking if a mindmap is loaded
final hasMindmapProvider = Provider<bool>((ref) {
  return ref.watch(mindmapDataProvider) != null;
});

/// Provider for checking if there's a selected node
final hasSelectedNodeProvider = Provider<bool>((ref) {
  return ref.watch(selectedNodeProvider) != null;
});

/// Provider for selected node ID
final selectedNodeIdProvider = Provider<String?>((ref) {
  return ref.watch(mindmapStateProvider).selectedNodeId;
});

/// Provider for search query (for UI state)
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search results count
final searchResultsCountProvider = Provider<int>((ref) {
  return ref.watch(searchResultsProvider).length;
});

/// Provider for checking if there are search results
final hasSearchResultsProvider = Provider<bool>((ref) {
  return ref.watch(searchResultsProvider).isNotEmpty;
});

/// Provider for current layout type from layout result
final currentLayoutTypeProvider = Provider<FfiLayoutType?>((ref) {
  return ref.watch(layoutResultProvider)?.layoutType;
});

/// Provider for layout computation time
final layoutComputationTimeProvider = Provider<Duration?>((ref) {
  final result = ref.watch(layoutResultProvider);
  return result?.computationTime;
});

/// Provider for checking if layout is available
final hasLayoutProvider = Provider<bool>((ref) {
  return ref.watch(layoutResultProvider) != null;
});

/// Combined provider for UI state that affects rendering
final renderStateProvider = Provider<RenderState>((ref) {
  return RenderState(
    zoomLevel: ref.watch(zoomLevelProvider),
    gridSnapEnabled: ref.watch(gridSnapEnabledProvider),
    gridSize: ref.watch(gridSizeProvider),
    showRulers: ref.watch(rulersVisibleProvider),
    nodeStyle: ref.watch(nodeStyleProvider),
    animationsEnabled: ref.watch(animationsEnabledProvider),
  );
});

/// Render state data class
class RenderState {
  const RenderState({
    required this.zoomLevel,
    required this.gridSnapEnabled,
    required this.gridSize,
    required this.showRulers,
    required this.nodeStyle,
    required this.animationsEnabled,
  });

  final double zoomLevel;
  final bool gridSnapEnabled;
  final double gridSize;
  final bool showRulers;
  final NodeStyle nodeStyle;
  final bool animationsEnabled;

  @override
  String toString() {
    return 'RenderState('
        'zoom: $zoomLevel, '
        'gridSnap: $gridSnapEnabled, '
        'gridSize: $gridSize, '
        'rulers: $showRulers, '
        'nodeStyle: $nodeStyle, '
        'animations: $animationsEnabled'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderState &&
          zoomLevel == other.zoomLevel &&
          gridSnapEnabled == other.gridSnapEnabled &&
          gridSize == other.gridSize &&
          showRulers == other.showRulers &&
          nodeStyle == other.nodeStyle &&
          animationsEnabled == other.animationsEnabled;

  @override
  int get hashCode => Object.hash(
        zoomLevel,
        gridSnapEnabled,
        gridSize,
        showRulers,
        nodeStyle,
        animationsEnabled,
      );
}