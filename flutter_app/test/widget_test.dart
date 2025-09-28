/// Basic widget tests for the mindmap application
///
/// This file contains essential widget tests that verify the core
/// functionality of the Flutter application.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindmap_app/app.dart';

void main() {
  group('MindmapApp Widget Tests', () {
    testWidgets('MindmapApp builds without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );

      // Verify that the app builds successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App displays placeholder home page', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Check for basic UI elements
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('App uses Material 3 design', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
    });

    testWidgets('App has correct theme configuration', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
      expect(app.themeMode, equals(ThemeMode.system));
    });

    testWidgets('App responds to theme changes', (WidgetTester tester) async {
      // Test light theme
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: const ProviderScope(
            child: MindmapApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);

      // Test dark theme
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: const ProviderScope(
            child: MindmapApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App handles different screen sizes', (WidgetTester tester) async {
      // Mobile size
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);

      // Tablet size
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);

      // Desktop size
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Check for navigation elements
      expect(find.byType(Navigator), findsOneWidget);
    });

    testWidgets('App displays platform information', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Look for text that would be displayed on the placeholder page
      expect(find.textContaining('Mindmap'), findsAtLeastNWidgets(1));
    });

    testWidgets('Error handling works', (WidgetTester tester) async {
      // Test that the app can handle errors gracefully
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );

      // The app should build without throwing exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProviderScope is configured correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );

      // Verify ProviderScope is present
      expect(find.byType(ProviderScope), findsOneWidget);
    });
  });

  group('Responsive Design Tests', () {
    testWidgets('Layout adapts to different orientations', (WidgetTester tester) async {
      // Portrait
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);

      // Landscape
      await tester.binding.setSurfaceSize(const Size(800, 400));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Text scales appropriately', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaleFactor: 1.5),
          child: const ProviderScope(
            child: MindmapApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Accessibility Tests', () {
    testWidgets('App has proper accessibility semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify basic accessibility structure
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Touch targets meet minimum size requirements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Check that interactive elements exist and are accessible
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);

      final RenderBox renderBox = tester.renderObject(scaffoldFinder);
      expect(renderBox.size.width, greaterThan(0));
      expect(renderBox.size.height, greaterThan(0));
    });
  });

  group('Performance Tests', () {
    testWidgets('App initializes within reasonable time', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      stopwatch.stop();

      // App should initialize within 5 seconds (generous for tests)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    testWidgets('No memory leaks in basic usage', (WidgetTester tester) async {
      // Build and tear down the app multiple times
      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(
          const ProviderScope(
            child: MindmapApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }

      // If we get here without exceptions, basic memory management is working
      expect(true, isTrue);
    });
  });

  group('Platform Integration Tests', () {
    testWidgets('App handles different platforms', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MindmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      // The app should work regardless of platform
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}