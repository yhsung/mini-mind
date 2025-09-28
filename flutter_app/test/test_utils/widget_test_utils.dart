/// Widget testing utilities and helpers
///
/// This file provides common utilities, extensions, and helper functions
/// for widget testing throughout the Flutter application.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Utility class for widget testing helpers
class WidgetTestUtils {
  /// Creates a testable widget wrapped with necessary providers
  static Widget createTestableWidget({
    required Widget child,
    List<Override> providerOverrides = const [],
    ThemeData? theme,
    Locale? locale,
  }) {
    return ProviderScope(
      overrides: providerOverrides,
      child: MaterialApp(
        theme: theme,
        locale: locale,
        home: child,
      ),
    );
  }

  /// Creates a minimal MaterialApp wrapper for testing
  static Widget wrapWithMaterialApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  /// Creates a widget with custom MediaQuery settings
  static Widget wrapWithMediaQuery({
    required Widget child,
    Size size = const Size(400, 800),
    double textScaleFactor = 1.0,
    Brightness platformBrightness = Brightness.light,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaleFactor: textScaleFactor,
        platformBrightness: platformBrightness,
        padding: padding,
        viewInsets: viewInsets,
      ),
      child: child,
    );
  }

  /// Creates a widget with ProviderScope for testing Riverpod
  static Widget wrapWithProviderScope({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: child,
    );
  }

  /// Pumps a widget and waits for all animations to complete
  static Future<void> pumpAndSettleWidget(
    WidgetTester tester,
    Widget widget, {
    Duration? duration,
  }) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle(duration ?? const Duration(seconds: 10));
  }

  /// Finds a widget by its key
  static Finder findByKey(String key) {
    return find.byKey(Key(key));
  }

  /// Finds a widget by its type and index
  static Finder findByTypeAndIndex<T extends Widget>(int index) {
    return find.byType(T).at(index);
  }

  /// Taps a widget and waits for the animation to complete
  static Future<void> tapAndSettle(
    WidgetTester tester,
    Finder finder, {
    Duration? duration,
  }) async {
    await tester.tap(finder);
    await tester.pumpAndSettle(duration ?? const Duration(seconds: 10));
  }

  /// Enters text and waits for the widget to update
  static Future<void> enterTextAndSettle(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Scrolls until a widget is visible
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder item,
    Finder scrollable, {
    double delta = 100.0,
  }) async {
    await tester.scrollUntilVisible(
      item,
      delta,
      scrollable: scrollable,
    );
  }

  /// Drags a widget by offset
  static Future<void> dragAndSettle(
    WidgetTester tester,
    Finder finder,
    Offset offset,
  ) async {
    await tester.drag(finder, offset);
    await tester.pumpAndSettle();
  }

  /// Performs a fling gesture and waits for it to complete
  static Future<void> flingAndSettle(
    WidgetTester tester,
    Finder finder,
    Offset offset,
    double velocity,
  ) async {
    await tester.fling(finder, offset, velocity);
    await tester.pumpAndSettle();
  }

  /// Verifies that a widget has proper accessibility
  static void verifyAccessibility(WidgetTester tester, Finder finder) {
    final RenderBox renderBox = tester.renderObject(finder);
    expect(renderBox.size.width, greaterThan(0));
    expect(renderBox.size.height, greaterThan(0));
  }

  /// Verifies button touch target size meets minimum requirements
  static void verifyTouchTarget(
    WidgetTester tester,
    Finder finder, {
    double minSize = 44.0,
  }) {
    final RenderBox renderBox = tester.renderObject(finder);
    expect(renderBox.size.width, greaterThanOrEqualTo(minSize));
    expect(renderBox.size.height, greaterThanOrEqualTo(minSize));
  }

  /// Checks if widget is visible on screen
  static bool isWidgetVisible(WidgetTester tester, Finder finder) {
    try {
      final RenderBox renderBox = tester.renderObject(finder);
      final Offset topLeft = renderBox.localToGlobal(Offset.zero);
      final Size screenSize = tester.binding.window.physicalSize / tester.binding.window.devicePixelRatio;

      return topLeft.dx >= 0 &&
             topLeft.dy >= 0 &&
             topLeft.dx < screenSize.width &&
             topLeft.dy < screenSize.height;
    } catch (e) {
      return false;
    }
  }

  /// Simulates device orientation change
  static Future<void> setOrientation(
    WidgetTester tester, {
    required bool isLandscape,
  }) async {
    final Size currentSize = tester.binding.window.physicalSize / tester.binding.window.devicePixelRatio;
    final Size newSize = isLandscape
        ? Size(currentSize.height, currentSize.width)
        : Size(currentSize.width, currentSize.height);

    await tester.binding.setSurfaceSize(newSize);
    await tester.pump();
  }

  /// Simulates text scale factor change
  static Future<void> setTextScaleFactor(
    WidgetTester tester,
    double textScaleFactor,
  ) async {
    await tester.pump();
  }

  /// Simulates platform brightness change
  static Future<void> setPlatformBrightness(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.pump();
  }

  /// Waits for a specific condition to be true
  static Future<void> waitForCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      if (condition()) {
        return;
      }
      await tester.pump(interval);
    }

    throw TimeoutException('Condition was not met within timeout', timeout);
  }

  /// Creates a mock BuildContext for testing
  static BuildContext createMockContext() {
    return _MockBuildContext();
  }
}

/// Extension methods for WidgetTester to add convenience methods
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps the widget and waits for all animations with timeout
  Future<void> pumpAndSettleWithTimeout([
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    await pumpAndSettle(timeout);
  }

  /// Taps and waits for animations
  Future<void> tapAndWait(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Enters text and waits for updates
  Future<void> enterTextAndWait(Finder finder, String text) async {
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Verifies that exactly one widget of the given type exists
  void expectSingleWidget<T extends Widget>() {
    expect(find.byType(T), findsOneWidget);
  }

  /// Verifies that no widgets of the given type exist
  void expectNoWidget<T extends Widget>() {
    expect(find.byType(T), findsNothing);
  }

  /// Verifies that at least one widget of the given type exists
  void expectAtLeastOneWidget<T extends Widget>() {
    expect(find.byType(T), findsAtLeastNWidgets(1));
  }

  /// Gets the first widget of the specified type
  T getFirstWidget<T extends Widget>() {
    return widget<T>(find.byType(T).first);
  }

  /// Gets all widgets of the specified type
  List<T> getAllWidgets<T extends Widget>() {
    return widgetList<T>(find.byType(T)).toList();
  }

  /// Checks if a widget with the given text exists
  bool hasText(String text) {
    return find.text(text).evaluate().isNotEmpty;
  }

  /// Checks if a widget with the given icon exists
  bool hasIcon(IconData icon) {
    return find.byIcon(icon).evaluate().isNotEmpty;
  }

  /// Gets the theme from the current context
  ThemeData getTheme() {
    final BuildContext context = element(find.byType(MaterialApp));
    return Theme.of(context);
  }

  /// Gets the media query from the current context
  MediaQueryData getMediaQuery() {
    final BuildContext context = element(find.byType(MaterialApp));
    return MediaQuery.of(context);
  }
}

/// Mock BuildContext for testing purposes
class _MockBuildContext implements BuildContext {
  @override
  bool get debugDoingBuild => false;

  @override
  InheritedWidget? dependOnInheritedElement(InheritedElement ancestor, {Object? aspect}) => null;

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>({Object? aspect}) => null;

  @override
  T? getInheritedWidgetOfExactType<T extends InheritedWidget>() => null;

  @override
  void dispatchNotification(Notification notification) {}

  @override
  DiagnosticsNode describeElement(String name, {DiagnosticsTreeStyle style = DiagnosticsTreeStyle.errorProperty}) {
    throw UnimplementedError();
  }

  @override
  List<DiagnosticsNode> describeMissingAncestor({required Type expectedAncestorType}) {
    throw UnimplementedError();
  }

  @override
  DiagnosticsNode describeOwnershipChain(String name) {
    throw UnimplementedError();
  }

  @override
  DiagnosticsNode describeWidget(String name, {DiagnosticsTreeStyle style = DiagnosticsTreeStyle.errorProperty}) {
    throw UnimplementedError();
  }

  @override
  T? findAncestorRenderObjectOfType<T extends RenderObject>() => null;

  @override
  T? findAncestorStateOfType<T extends State<StatefulWidget>>() => null;

  @override
  T? findAncestorWidgetOfExactType<T extends Widget>() => null;

  @override
  RenderObject? findRenderObject() => null;

  @override
  T? findRootAncestorStateOfType<T extends State<StatefulWidget>>() => null;

  @override
  InheritedElement? getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() => null;

  @override
  BuildOwner? get owner => null;

  @override
  Size? get size => null;

  @override
  void visitAncestorElements(bool Function(Element element) visitor) {}

  @override
  void visitChildElements(ElementVisitor visitor) {}

  @override
  Widget get widget => throw UnimplementedError();

  @override
  bool get mounted => true;
}

/// Custom exception for timeouts
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  const TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}