/// Main application widget and configuration
///
/// This file defines the root widget of the Flutter application,
/// including theme configuration, routing, and global app settings.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'utils/platform_utils.dart';
import 'screens/welcome_screen.dart';

/// Root application widget
///
/// This widget serves as the entry point for the entire Flutter application,
/// providing theme configuration, routing, and platform-adaptive behavior.
class MindmapApp extends ConsumerWidget {
  const MindmapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // App identity and metadata
      title: 'Mindmap',

      // Debug configuration
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: false,

      // Theme configuration
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,

      // Localization (placeholder - would be expanded with real i18n)
      locale: const Locale('en', 'US'),
      supportedLocales: const [
        Locale('en', 'US'),
      ],

      // Platform-adaptive scroll behavior
      scrollBehavior: PlatformUtils.scrollBehavior,

      // Navigation and routing
      home: const WelcomeScreen(),

      // Error handling
      builder: (context, child) {
        // Handle text scale factor bounds
        final mediaQuery = MediaQuery.of(context);
        final constrainedTextScaleFactor = mediaQuery.textScaleFactor.clamp(
          PlatformUtils.minTextScaleFactor,
          PlatformUtils.maxTextScaleFactor,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaleFactor: constrainedTextScaleFactor,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Build light theme configuration
  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF2196F3); // Blue
    const secondaryColor = Color(0xFF03DAC6); // Teal

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      secondary: secondaryColor,
    );

    return ThemeData(
      // Color scheme
      colorScheme: colorScheme,
      useMaterial3: true,

      // Visual density based on platform
      visualDensity: PlatformUtils.isMobile
          ? VisualDensity.standard
          : VisualDensity.compact,

      // Typography
      textTheme: _buildTextTheme(colorScheme),

      // Component themes
      appBarTheme: _buildAppBarTheme(colorScheme, Brightness.light),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme, Brightness.light),
      dialogTheme: _buildDialogTheme(colorScheme),
      bottomSheetTheme: _buildBottomSheetTheme(colorScheme),

      // Input decoration
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme, Brightness.light),

      // Platform adaptations
      platform: PlatformUtils.isIOS ? TargetPlatform.iOS : TargetPlatform.android,

      // Spacing and sizing
      materialTapTargetSize: PlatformUtils.isMobile
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Build dark theme configuration
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF90CAF9); // Light blue
    const secondaryColor = Color(0xFF03DAC6); // Teal

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      secondary: secondaryColor,
    );

    return ThemeData(
      // Color scheme
      colorScheme: colorScheme,
      useMaterial3: true,

      // Visual density based on platform
      visualDensity: PlatformUtils.isMobile
          ? VisualDensity.standard
          : VisualDensity.compact,

      // Typography
      textTheme: _buildTextTheme(colorScheme),

      // Component themes
      appBarTheme: _buildAppBarTheme(colorScheme, Brightness.dark),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme, Brightness.dark),
      dialogTheme: _buildDialogTheme(colorScheme),
      bottomSheetTheme: _buildBottomSheetTheme(colorScheme),

      // Input decoration
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme, Brightness.dark),

      // Platform adaptations
      platform: PlatformUtils.isIOS ? TargetPlatform.iOS : TargetPlatform.android,

      // Spacing and sizing
      materialTapTargetSize: PlatformUtils.isMobile
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Build text theme configuration
  TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Display text styles
      displayLarge: TextStyle(
        fontSize: PlatformUtils.isMobile ? 57 : 52,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: PlatformUtils.isMobile ? 45 : 42,
        fontWeight: FontWeight.w300,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: PlatformUtils.isMobile ? 36 : 34,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),

      // Headline text styles
      headlineLarge: TextStyle(
        fontSize: PlatformUtils.isMobile ? 32 : 30,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: PlatformUtils.isMobile ? 28 : 26,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: PlatformUtils.isMobile ? 24 : 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),

      // Body text styles
      bodyLarge: TextStyle(
        fontSize: PlatformUtils.isMobile ? 16 : 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: PlatformUtils.isMobile ? 14 : 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: PlatformUtils.isMobile ? 12 : 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Build app bar theme
  AppBarTheme _buildAppBarTheme(ColorScheme colorScheme, Brightness brightness) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: PlatformUtils.isIOS,
      titleSpacing: PlatformUtils.defaultSpacing,
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    );
  }

  /// Build elevated button theme
  ElevatedButtonThemeData _buildElevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(88, PlatformUtils.minimumTouchTargetSize),
        padding: EdgeInsets.symmetric(
          horizontal: PlatformUtils.defaultSpacing,
          vertical: PlatformUtils.isMobile ? 12 : 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Build outlined button theme
  OutlinedButtonThemeData _buildOutlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(88, PlatformUtils.minimumTouchTargetSize),
        padding: EdgeInsets.symmetric(
          horizontal: PlatformUtils.defaultSpacing,
          vertical: PlatformUtils.isMobile ? 12 : 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Build text button theme
  TextButtonThemeData _buildTextButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(88, PlatformUtils.minimumTouchTargetSize),
        padding: EdgeInsets.symmetric(
          horizontal: PlatformUtils.defaultSpacing,
          vertical: PlatformUtils.isMobile ? 12 : 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Build card theme
  CardThemeData _buildCardTheme(ColorScheme colorScheme, Brightness brightness) {
    return CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.all(PlatformUtils.defaultSpacing / 2),
    );
  }

  /// Build dialog theme
  DialogThemeData _buildDialogTheme(ColorScheme colorScheme) {
    return DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      titleTextStyle: TextStyle(
        fontSize: PlatformUtils.isMobile ? 20 : 18,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  /// Build bottom sheet theme
  BottomSheetThemeData _buildBottomSheetTheme(ColorScheme colorScheme) {
    return BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 8,
      modalBackgroundColor: colorScheme.surface,
    );
  }

  /// Build input decoration theme
  InputDecorationTheme _buildInputDecorationTheme(
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: PlatformUtils.defaultSpacing,
        vertical: PlatformUtils.isMobile ? 16 : 12,
      ),
    );
  }
}

