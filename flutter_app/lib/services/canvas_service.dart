/// Canvas service for controlling mindmap canvas operations
///
/// Provides zoom, pan, and view control functionality that can be
/// accessed from menus, toolbars, and keyboard shortcuts.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Canvas controller for managing zoom and pan operations
class CanvasController extends ChangeNotifier {
  static final Logger _logger = Logger();

  double _zoomLevel = 1.0;
  bool _isZooming = false;

  // Callback functions to be set by the canvas widget
  VoidCallback? _zoomInCallback;
  VoidCallback? _zoomOutCallback;
  VoidCallback? _zoomToFitCallback;
  void Function(double)? _setZoomCallback;

  /// Current zoom level
  double get zoomLevel => _zoomLevel;

  /// Whether a zoom operation is in progress
  bool get isZooming => _isZooming;

  /// Register canvas callbacks
  void registerCallbacks({
    VoidCallback? onZoomIn,
    VoidCallback? onZoomOut,
    VoidCallback? onZoomToFit,
    void Function(double)? onSetZoom,
  }) {
    _zoomInCallback = onZoomIn;
    _zoomOutCallback = onZoomOut;
    _zoomToFitCallback = onZoomToFit;
    _setZoomCallback = onSetZoom;
    _logger.d('Canvas callbacks registered');
  }

  /// Unregister callbacks when canvas is disposed
  void unregisterCallbacks() {
    _zoomInCallback = null;
    _zoomOutCallback = null;
    _zoomToFitCallback = null;
    _setZoomCallback = null;
    _logger.d('Canvas callbacks unregistered');
  }

  /// Zoom in by a standard factor
  void zoomIn() {
    if (_zoomInCallback != null) {
      _isZooming = true;
      notifyListeners();

      _zoomInCallback!();
      _updateZoomLevel(_zoomLevel * 1.2);

      _isZooming = false;
      notifyListeners();
      _logger.d('Zoom in to level: $_zoomLevel');
    } else {
      _logger.w('Zoom in callback not registered');
    }
  }

  /// Zoom out by a standard factor
  void zoomOut() {
    if (_zoomOutCallback != null) {
      _isZooming = true;
      notifyListeners();

      _zoomOutCallback!();
      _updateZoomLevel(_zoomLevel * 0.8);

      _isZooming = false;
      notifyListeners();
      _logger.d('Zoom out to level: $_zoomLevel');
    } else {
      _logger.w('Zoom out callback not registered');
    }
  }

  /// Zoom to fit all content
  void zoomToFit() {
    if (_zoomToFitCallback != null) {
      _isZooming = true;
      notifyListeners();

      _zoomToFitCallback!();

      // ZoomToFit will determine the appropriate zoom level
      // We'll update it when the canvas reports back
      _isZooming = false;
      notifyListeners();
      _logger.d('Zoom to fit requested');
    } else {
      _logger.w('Zoom to fit callback not registered');
    }
  }

  /// Set specific zoom level
  void setZoom(double level) {
    final clampedLevel = level.clamp(0.1, 10.0);
    if (_setZoomCallback != null) {
      _isZooming = true;
      notifyListeners();

      _setZoomCallback!(clampedLevel);
      _updateZoomLevel(clampedLevel);

      _isZooming = false;
      notifyListeners();
      _logger.d('Zoom set to level: $clampedLevel');
    } else {
      _logger.w('Set zoom callback not registered');
    }
  }

  /// Update zoom level (called by canvas)
  void _updateZoomLevel(double level) {
    if (_zoomLevel != level) {
      _zoomLevel = level;
      notifyListeners();
    }
  }

  /// Called by canvas to report current zoom level
  void reportZoomLevel(double level) {
    _updateZoomLevel(level);
  }

  /// Get zoom percentage for display
  int get zoomPercentage => (_zoomLevel * 100).round();

  /// Predefined zoom levels
  static const List<double> presetZoomLevels = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0
  ];

  /// Get next higher zoom level
  double getNextZoomLevel() {
    for (final level in presetZoomLevels) {
      if (level > _zoomLevel) {
        return level;
      }
    }
    return presetZoomLevels.last;
  }

  /// Get next lower zoom level
  double getPreviousZoomLevel() {
    for (int i = presetZoomLevels.length - 1; i >= 0; i--) {
      if (presetZoomLevels[i] < _zoomLevel) {
        return presetZoomLevels[i];
      }
    }
    return presetZoomLevels.first;
  }
}

/// Provider for canvas controller
final canvasControllerProvider = ChangeNotifierProvider<CanvasController>((ref) {
  return CanvasController();
});

/// Provider for current zoom level
final zoomLevelProvider = Provider<double>((ref) {
  return ref.watch(canvasControllerProvider).zoomLevel;
});

/// Provider for zoom percentage
final zoomPercentageProvider = Provider<int>((ref) {
  return ref.watch(canvasControllerProvider).zoomPercentage;
});