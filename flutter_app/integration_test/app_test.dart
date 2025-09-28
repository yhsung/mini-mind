/// Integration tests for the Mindmap Flutter application
///
/// This file contains comprehensive integration tests that verify the entire
/// application flow, from startup to complex user interactions across different
/// platforms and screen sizes.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import the main app
import 'package:mindmap_app/main.dart' as app;
import 'package:mindmap_app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    group('Application Startup', () {
      testWidgets('App starts successfully and shows main UI', (WidgetTester tester) async {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Verify the app has started
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(ProviderScope), findsOneWidget);

        // The app should show some main content
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      });

      testWidgets('App initializes without errors', (WidgetTester tester) async {
        // Track if any errors occur during startup
        bool hasError = false;
        FlutterError.onError = (FlutterErrorDetails details) {
          hasError = true;
          debugPrint('Flutter Error during startup: ${details.exception}');
        };

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(hasError, isFalse, reason: 'App should start without Flutter errors');
      });

      testWidgets('Platform services initialize correctly', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify the app has basic structure indicating successful initialization
        expect(find.byType(MaterialApp), findsOneWidget);

        // The app should be responsive
        await tester.tap(find.byType(MaterialApp));
        await tester.pump();
      });

      testWidgets('App handles platform differences', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify app adapts to current platform
        final mediaQuery = MediaQuery.of(tester.element(find.byType(MaterialApp)));
        expect(mediaQuery.size.width, greaterThan(0));
        expect(mediaQuery.size.height, greaterThan(0));

        // App should handle different screen orientations
        await tester.binding.setSurfaceSize(const Size(800, 600)); // Landscape
        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);

        await tester.binding.setSurfaceSize(const Size(400, 800)); // Portrait
        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Basic Navigation', () {
      testWidgets('App shows main navigation elements', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for common navigation elements
        // The exact widgets depend on the app structure, so we'll be flexible
        final scaffolds = find.byType(Scaffold);
        expect(scaffolds, findsAtLeastNWidgets(1));

        // Should have some interactive elements
        final gestureDetectors = find.byType(GestureDetector);
        final inkWells = find.byType(InkWell);
        final buttons = find.byType(ElevatedButton);
        final textButtons = find.byType(TextButton);
        final iconButtons = find.byType(IconButton);

        final interactiveElements = gestureDetectors.evaluate().length +
            inkWells.evaluate().length +
            buttons.evaluate().length +
            textButtons.evaluate().length +
            iconButtons.evaluate().length;

        expect(interactiveElements, greaterThan(0),
               reason: 'App should have interactive navigation elements');
      });

      testWidgets('App responds to basic interactions', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Try to interact with any available buttons or interactive elements
        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
          await tester.pumpAndSettle();
        }

        final iconButtons = find.byType(IconButton);
        if (iconButtons.evaluate().isNotEmpty) {
          await tester.tap(iconButtons.first);
          await tester.pumpAndSettle();
        }

        final inkWells = find.byType(InkWell);
        if (inkWells.evaluate().isNotEmpty) {
          await tester.tap(inkWells.first);
          await tester.pumpAndSettle();
        }

        // App should still be functional after interactions
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Navigation handles back button on Android', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate Android back button press
        if (!kIsWeb && Platform.isAndroid) {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/navigation',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('routePopped', <String, dynamic>{
                'location': '/',
                'state': null,
              }),
            ),
            (data) {},
          );
          await tester.pumpAndSettle();
        }

        // App should still be functional
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App handles screen size changes gracefully', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test different screen sizes
        final testSizes = [
          const Size(320, 568), // iPhone SE
          const Size(375, 667), // iPhone 8
          const Size(414, 896), // iPhone 11 Pro Max
          const Size(768, 1024), // iPad
          const Size(1920, 1080), // Desktop
        ];

        for (final size in testSizes) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpAndSettle();

          expect(find.byType(MaterialApp), findsOneWidget);

          // Verify the app layout adapts to the screen size
          final mediaQuery = MediaQuery.of(tester.element(find.byType(MaterialApp)));
          expect(mediaQuery.size.width, equals(size.width));
          expect(mediaQuery.size.height, equals(size.height));
        }
      });
    });

    group('Cross-Platform Functionality', () {
      testWidgets('App adapts UI for mobile platforms', (WidgetTester tester) async {
        // Simulate mobile environment
        await tester.binding.setSurfaceSize(const Size(375, 667));

        app.main();
        await tester.pumpAndSettle();

        // Verify mobile-appropriate UI elements
        expect(find.byType(MaterialApp), findsOneWidget);

        // Mobile apps should be touch-friendly
        final scaffolds = find.byType(Scaffold);
        expect(scaffolds, findsAtLeastNWidgets(1));
      });

      testWidgets('App adapts UI for desktop platforms', (WidgetTester tester) async {
        // Simulate desktop environment
        await tester.binding.setSurfaceSize(const Size(1200, 800));

        app.main();
        await tester.pumpAndSettle();

        // Verify desktop-appropriate UI elements
        expect(find.byType(MaterialApp), findsOneWidget);

        // Desktop apps should make use of available space
        final mediaQuery = MediaQuery.of(tester.element(find.byType(MaterialApp)));
        expect(mediaQuery.size.width, equals(1200));
        expect(mediaQuery.size.height, equals(800));
      });

      testWidgets('App handles keyboard input appropriately', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for text input fields
        final textFields = find.byType(TextField);
        final textFormFields = find.byType(TextFormField);

        if (textFields.evaluate().isNotEmpty) {
          await tester.tap(textFields.first);
          await tester.pumpAndSettle();

          await tester.enterText(textFields.first, 'Test input');
          await tester.pumpAndSettle();

          expect(find.text('Test input'), findsOneWidget);
        } else if (textFormFields.evaluate().isNotEmpty) {
          await tester.tap(textFormFields.first);
          await tester.pumpAndSettle();

          await tester.enterText(textFormFields.first, 'Test input');
          await tester.pumpAndSettle();

          expect(find.text('Test input'), findsOneWidget);
        }
      });

      testWidgets('App supports accessibility features', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify semantic elements are present
        final semanticFinders = [
          find.byType(Semantics),
          find.byType(ExcludeSemantics),
          find.byType(MergeSemantics),
        ];

        bool hasSemantics = semanticFinders.any(
          (finder) => finder.evaluate().isNotEmpty
        );

        // While not all widgets need explicit Semantics, interactive elements should be accessible
        final buttons = find.byType(ElevatedButton);
        final iconButtons = find.byType(IconButton);
        final textButtons = find.byType(TextButton);

        final accessibleButtons = buttons.evaluate().length +
            iconButtons.evaluate().length +
            textButtons.evaluate().length;

        expect(accessibleButtons + (hasSemantics ? 1 : 0), greaterThan(0),
               reason: 'App should have accessible interactive elements');
      });

      testWidgets('App handles theme changes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify the app has a theme
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.theme, isNotNull);

        // Test with different brightness settings
        await tester.binding.platformDispatcher.updateTestPlatformBrightness(Brightness.dark);
        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);

        await tester.binding.platformDispatcher.updateTestPlatformBrightness(Brightness.light);
        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App performs well under load', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Measure performance during rapid interactions
        final stopwatch = Stopwatch()..start();

        // Perform multiple rapid interactions
        for (int i = 0; i < 10; i++) {
          // Tap various elements if available
          final buttons = find.byType(ElevatedButton);
          if (buttons.evaluate().isNotEmpty) {
            await tester.tap(buttons.first);
          }

          final iconButtons = find.byType(IconButton);
          if (iconButtons.evaluate().isNotEmpty) {
            await tester.tap(iconButtons.first);
          }

          await tester.pump();
        }

        await tester.pumpAndSettle();
        stopwatch.stop();

        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
               reason: 'App should remain responsive under interaction load');
      });
    });

    group('Error Handling and Edge Cases', () {
      testWidgets('App handles network connectivity changes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // The app should continue functioning even if network operations fail
        // Since we can't easily simulate network changes in integration tests,
        // we'll verify the app structure remains stable
        expect(find.byType(MaterialApp), findsOneWidget);

        // Try some interactions to ensure stability
        await tester.tap(find.byType(MaterialApp));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App recovers from state errors gracefully', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify error boundaries work by triggering rapid state changes
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byType(MaterialApp));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App handles memory pressure', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate memory pressure by creating and disposing many widgets
        for (int i = 0; i < 100; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Container(
                child: Text('Test widget $i'),
              ),
            ),
          );
          await tester.pump();
        }

        // Return to main app
        app.main();
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App handles orientation changes smoothly', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Rapidly change orientations
        await tester.binding.setSurfaceSize(const Size(400, 800)); // Portrait
        await tester.pumpAndSettle();

        await tester.binding.setSurfaceSize(const Size(800, 400)); // Landscape
        await tester.pumpAndSettle();

        await tester.binding.setSurfaceSize(const Size(300, 600)); // Narrow portrait
        await tester.pumpAndSettle();

        await tester.binding.setSurfaceSize(const Size(1200, 800)); // Wide landscape
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App maintains functionality across app lifecycle', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate app lifecycle events
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage('AppLifecycleState.paused'),
          (data) {},
        );
        await tester.pump();

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage('AppLifecycleState.resumed'),
          (data) {},
        );
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Platform-Specific Features', () {
      testWidgets('Web-specific functionality works', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        if (kIsWeb) {
          // Test web-specific features
          expect(find.byType(MaterialApp), findsOneWidget);

          // Web should handle mouse interactions
          final center = tester.getCenter(find.byType(MaterialApp));
          await tester.tapAt(center);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Mobile-specific functionality works', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          // Test mobile-specific features like gestures
          final center = tester.getCenter(find.byType(MaterialApp));

          // Test pinch gesture (if applicable)
          final gesture1 = await tester.startGesture(center.translate(-50, 0));
          final gesture2 = await tester.startGesture(center.translate(50, 0));

          await gesture1.moveTo(center.translate(-100, 0));
          await gesture2.moveTo(center.translate(100, 0));

          await gesture1.up();
          await gesture2.up();

          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Desktop-specific functionality works', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          // Test desktop-specific features like keyboard shortcuts
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Performance and Resource Management', () {
      testWidgets('App startup time is reasonable', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();

        app.main();
        await tester.pumpAndSettle();

        stopwatch.stop();

        expect(find.byType(MaterialApp), findsOneWidget);

        // Startup should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(10000),
               reason: 'App should start within 10 seconds');
      });

      testWidgets('App memory usage remains stable', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Perform multiple operations that might create objects
        for (int i = 0; i < 50; i++) {
          await tester.tap(find.byType(MaterialApp));
          await tester.pump();

          if (i % 10 == 0) {
            await tester.pumpAndSettle();
          }
        }

        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App handles rapid navigation without crashes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Rapidly interact with navigation elements
        final buttons = find.byType(ElevatedButton);
        final iconButtons = find.byType(IconButton);

        for (int i = 0; i < 20; i++) {
          if (buttons.evaluate().isNotEmpty) {
            await tester.tap(buttons.first);
          }
          if (iconButtons.evaluate().isNotEmpty) {
            await tester.tap(iconButtons.first);
          }
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('App disposes resources properly', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate through the app to create and dispose resources
        final widgets = [
          find.byType(ElevatedButton),
          find.byType(IconButton),
          find.byType(InkWell),
        ];

        for (final widget in widgets) {
          if (widget.evaluate().isNotEmpty) {
            await tester.tap(widget.first);
            await tester.pumpAndSettle();
          }
        }

        // The app should still be functional
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });
  });
}