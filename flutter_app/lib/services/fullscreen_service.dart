/// Fullscreen service for managing fullscreen mode
///
/// Provides fullscreen toggle functionality that can be accessed
/// from menus and keyboard shortcuts.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Fullscreen controller for managing fullscreen state
class FullscreenController extends ChangeNotifier {
  static final Logger _logger = Logger();

  bool _isFullscreen = false;
  VoidCallback? _toggleCallback;

  /// Current fullscreen state
  bool get isFullscreen => _isFullscreen;

  /// Register toggle callback from the main screen
  void registerToggleCallback(VoidCallback callback) {
    _toggleCallback = callback;
    _logger.d('Fullscreen toggle callback registered');
  }

  /// Unregister callback when screen is disposed
  void unregisterCallback() {
    _toggleCallback = null;
    _logger.d('Fullscreen toggle callback unregistered');
  }

  /// Toggle fullscreen mode
  void toggleFullscreen() {
    if (_toggleCallback != null) {
      _toggleCallback!();
      _isFullscreen = !_isFullscreen;
      notifyListeners();
      _logger.d('Fullscreen toggled: $_isFullscreen');
    } else {
      _logger.w('Fullscreen toggle callback not registered');
    }
  }

  /// Enter fullscreen mode
  void enterFullscreen() {
    if (!_isFullscreen) {
      toggleFullscreen();
    }
  }

  /// Exit fullscreen mode
  void exitFullscreen() {
    if (_isFullscreen) {
      toggleFullscreen();
    }
  }

  /// Update fullscreen state (called by the screen)
  void updateState(bool isFullscreen) {
    if (_isFullscreen != isFullscreen) {
      _isFullscreen = isFullscreen;
      notifyListeners();
    }
  }
}

/// Provider for fullscreen controller
final fullscreenControllerProvider = ChangeNotifierProvider<FullscreenController>((ref) {
  return FullscreenController();
});

/// Provider for fullscreen state
final isFullscreenProvider = Provider<bool>((ref) {
  return ref.watch(fullscreenControllerProvider).isFullscreen;
});