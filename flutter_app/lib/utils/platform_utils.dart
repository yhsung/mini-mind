/// Platform utility functions and helpers
///
/// This file provides utility functions for platform detection,
/// platform-specific behavior, and cross-platform compatibility.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Platform utility class with static helper methods
class PlatformUtils {
  PlatformUtils._(); // Private constructor to prevent instantiation

  /// Check if running on mobile platform (Android or iOS)
  static bool get isMobile => kIsWeb ? false : (Platform.isAndroid || Platform.isIOS);

  /// Check if running on desktop platform
  static bool get isDesktop => kIsWeb ? false : (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Check if running on web platform
  static bool get isWeb => kIsWeb;

  /// Check if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check if running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Check if running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Check if running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Get platform name as a string
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Get platform-appropriate file separator
  static String get fileSeparator => kIsWeb ? '/' : Platform.pathSeparator;

  /// Check if platform supports file system operations
  static bool get supportsFileSystem => !kIsWeb;

  /// Check if platform supports native dialogs
  static bool get supportsNativeDialogs => !kIsWeb;

  /// Check if platform supports system theme detection
  static bool get supportsSystemTheme {
    if (kIsWeb) return true; // Web browsers support prefers-color-scheme
    return true; // All supported native platforms support system theme
  }

  /// Check if platform supports window management
  static bool get supportsWindowManagement => isDesktop;

  /// Check if platform supports multiple windows
  static bool get supportsMultipleWindows => isDesktop;

  /// Check if platform supports keyboard shortcuts
  static bool get supportsKeyboardShortcuts => !isMobile;

  /// Check if platform supports context menus
  static bool get supportsContextMenus => true;

  /// Check if platform supports drag and drop
  static bool get supportsDragAndDrop => isDesktop || kIsWeb;

  /// Check if platform supports hover interactions
  static bool get supportsHover => !isMobile;

  /// Get platform-appropriate modifier key
  static String get modifierKey {
    if (isMacOS) return '⌘'; // Command key
    return 'Ctrl'; // Control key for all other platforms
  }

  /// Get platform-appropriate modifier key for keyboard shortcuts
  static LogicalKeyboardKey get primaryModifierKey {
    if (isMacOS) return LogicalKeyboardKey.metaLeft;
    return LogicalKeyboardKey.controlLeft;
  }

  /// Get platform-appropriate secondary modifier key
  static LogicalKeyboardKey get secondaryModifierKey {
    return LogicalKeyboardKey.shiftLeft;
  }

  /// Get platform-appropriate alt/option key
  static LogicalKeyboardKey get altModifierKey {
    return LogicalKeyboardKey.altLeft;
  }

  /// Check if we're running in a touch environment
  static bool get isTouchPrimary => isMobile;

  /// Check if we're running in a mouse/pointer environment
  static bool get isPointerPrimary => isDesktop || kIsWeb;

  /// Get default window width for the platform
  static double get defaultWindowWidth {
    if (isMobile) return double.infinity; // Full width on mobile
    return 1200.0; // Desktop default
  }

  /// Get default window height for the platform
  static double get defaultWindowHeight {
    if (isMobile) return double.infinity; // Full height on mobile
    return 800.0; // Desktop default
  }

  /// Get minimum window width for the platform
  static double get minimumWindowWidth {
    if (isMobile) return 0.0; // No minimum on mobile
    return 600.0; // Desktop minimum
  }

  /// Get minimum window height for the platform
  static double get minimumWindowHeight {
    if (isMobile) return 0.0; // No minimum on mobile
    return 400.0; // Desktop minimum
  }

  /// Get platform-appropriate edge insets for safe area
  static EdgeInsets get defaultPadding {
    if (isMobile) {
      return const EdgeInsets.all(16.0); // More padding on mobile for touch targets
    }
    return const EdgeInsets.all(12.0); // Less padding on desktop
  }

  /// Get platform-appropriate spacing between UI elements
  static double get defaultSpacing {
    if (isMobile) return 16.0; // Larger spacing for touch
    return 12.0; // Smaller spacing for desktop
  }

  /// Get platform-appropriate minimum touch target size
  static double get minimumTouchTargetSize {
    if (isMobile) return 48.0; // Material Design recommendation
    return 32.0; // Smaller targets acceptable on desktop
  }

  /// Check if platform supports haptic feedback
  static bool get supportsHaptics => isMobile && !kIsWeb;

  /// Provide haptic feedback if supported
  static Future<void> hapticFeedback({
    HapticFeedbackType type = HapticFeedbackType.selectionClick,
  }) async {
    if (supportsHaptics) {
      switch (type) {
        case HapticFeedbackType.lightImpact:
          await HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.mediumImpact:
          await HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavyImpact:
          await HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selectionClick:
          await HapticFeedback.selectionClick();
          break;
        case HapticFeedbackType.vibrate:
          await HapticFeedback.vibrate();
          break;
      }
    }
  }

  /// Get platform-appropriate animation duration
  static Duration get defaultAnimationDuration {
    if (isMobile) {
      return const Duration(milliseconds: 300); // Slightly longer for mobile
    }
    return const Duration(milliseconds: 200); // Faster on desktop
  }

  /// Get platform-appropriate page transition duration
  static Duration get pageTransitionDuration {
    if (isMobile) {
      return const Duration(milliseconds: 300);
    }
    return const Duration(milliseconds: 150); // Faster transitions on desktop
  }

  /// Check if platform prefers reduced motion
  static bool get prefersReducedMotion {
    // This would need platform-specific implementation to check accessibility settings
    // For now, return false as default
    return false;
  }

  /// Get platform-appropriate scroll behavior
  static ScrollBehavior get scrollBehavior {
    if (isDesktop || kIsWeb) {
      // Desktop scrolling with mouse wheel and scroll bars
      return const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
        },
      );
    } else {
      // Mobile touch scrolling
      return const MaterialScrollBehavior();
    }
  }

  /// Get platform-appropriate text scale factor limits
  static double get minTextScaleFactor => 0.8;
  static double get maxTextScaleFactor => isMobile ? 2.0 : 1.5;

  /// Check if platform supports multiple display outputs
  static bool get supportsMultipleDisplays => isDesktop;

  /// Check if platform supports notification badges
  static bool get supportsNotificationBadges => isMobile || isMacOS;

  /// Check if platform supports background processing
  static bool get supportsBackgroundProcessing => !kIsWeb;

  /// Get platform-appropriate debounce duration for search/input
  static Duration get searchDebounceDuration {
    if (isMobile) {
      return const Duration(milliseconds: 300); // Slightly longer for mobile typing
    }
    return const Duration(milliseconds: 200); // Faster response on desktop
  }

  /// Check if current environment is suitable for performance-intensive operations
  static bool get canHandleIntensiveOperations {
    // In a real app, this could check device specs, battery level, etc.
    // For now, assume desktop and web can handle more intensive operations
    return isDesktop || kIsWeb;
  }

  /// Get recommended maximum concurrent operations for the platform
  static int get maxConcurrentOperations {
    if (isMobile) return 2; // Limit concurrent ops on mobile
    if (kIsWeb) return 4; // Moderate limit for web
    return 8; // Higher limit for desktop
  }
}

/// Enumeration of haptic feedback types
enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}