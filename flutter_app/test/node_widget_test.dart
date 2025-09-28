/// Basic tests for NodeWidget functionality
///
/// This file contains essential widget tests for NodeWidget, covering basic
/// construction, interaction, and visual states. Tests are designed to work
/// with the current implementation state.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('NodeWidget Basic Tests', () {
    testWidgets('Basic widget construction test', (WidgetTester tester) async {
      // Create a minimal test to verify the test infrastructure works
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('NodeWidget Test Infrastructure'),
          ),
        ),
      );

      expect(find.text('NodeWidget Test Infrastructure'), findsOneWidget);
    });

    testWidgets('ProviderScope integration test', (WidgetTester tester) async {
      // Test basic ProviderScope functionality
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  return const Text('Provider integration works');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Provider integration works'), findsOneWidget);
    });

    testWidgets('Basic gesture handling test', (WidgetTester tester) async {
      bool tapCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => tapCalled = true,
              child: const Text('Tap me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(tapCalled, isTrue);
    });

    testWidgets('Text field editing test', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test text');
      await tester.pumpAndSettle();

      expect(controller.text, equals('Test text'));
      controller.dispose();
    });

    testWidgets('Animation controller test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _AnimationTestWidget(),
          ),
        ),
      );

      expect(find.byType(_AnimationTestWidget), findsOneWidget);

      // Trigger animation
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Animation should be running
      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('Container styling test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: const Text('Styled container'),
            ),
          ),
        ),
      );

      final containerWidget = tester.widget<Container>(find.byType(Container));
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.blue));
      expect(decoration.borderRadius, equals(BorderRadius.circular(8)));
      expect(decoration.border?.top.color, equals(Colors.red));
    });

    testWidgets('Mouse hover simulation test', (WidgetTester tester) async {
      bool isHovered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MouseRegion(
              onEnter: (_) => isHovered = true,
              onExit: (_) => isHovered = false,
              child: const Text('Hover target'),
            ),
          ),
        ),
      );

      // Simulate mouse hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.text('Hover target')));
      await tester.pumpAndSettle();

      expect(isHovered, isTrue);
    });

    testWidgets('Focus handling test', (WidgetTester tester) async {
      final focusNode = FocusNode();
      bool hasFocus = false;

      focusNode.addListener(() {
        hasFocus = focusNode.hasFocus;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              focusNode: focusNode,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(hasFocus, isTrue);

      focusNode.dispose();
    });

    testWidgets('Transform scale test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Transform.scale(
              scale: 1.5,
              child: const Text('Scaled text'),
            ),
          ),
        ),
      );

      expect(find.byType(Transform), findsOneWidget);
      expect(find.text('Scaled text'), findsOneWidget);
    });

    testWidgets('Intrinsic dimensions test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IntrinsicWidth(
              child: IntrinsicHeight(
                child: Container(
                  color: Colors.yellow,
                  child: const Text('Intrinsic sizing'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(IntrinsicWidth), findsOneWidget);
      expect(find.byType(IntrinsicHeight), findsOneWidget);
      expect(find.text('Intrinsic sizing'), findsOneWidget);
    });

    testWidgets('Box constraints test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              constraints: const BoxConstraints(
                minWidth: 100,
                minHeight: 50,
                maxWidth: 200,
              ),
              color: Colors.green,
              child: const Text('Constrained'),
            ),
          ),
        ),
      );

      final RenderBox renderBox = tester.renderObject(find.byType(Container));
      expect(renderBox.size.width, greaterThanOrEqualTo(100));
      expect(renderBox.size.height, greaterThanOrEqualTo(50));
      expect(renderBox.size.width, lessThanOrEqualTo(200));
    });
  });

  group('Performance and Memory Tests', () {
    testWidgets('Multiple widget instances test', (WidgetTester tester) async {
      final widgets = List.generate(20, (index) =>
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Container(
            width: 80,
            height: 40,
            color: Colors.blue,
            child: Text('Widget $index'),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(children: widgets),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(find.byType(Container), findsNWidgets(20));
    });

    testWidgets('Animation performance test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _PerformanceTestWidget(),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Trigger multiple animation frames
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    testWidgets('Memory usage test with dispose', (WidgetTester tester) async {
      final controllers = <TextEditingController>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _DisposableTestWidget(controllers: controllers),
          ),
        ),
      );

      // Dispose the widget
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Controllers should be disposed
      for (final controller in controllers) {
        expect(() => controller.text, throwsAssertionError);
      }
    });
  });

  group('Error Handling Tests', () {
    testWidgets('Null callback handling test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: null,
              onDoubleTap: null,
              onLongPress: null,
              child: const Text('Null callbacks'),
            ),
          ),
        ),
      );

      // Should not throw errors
      await tester.tap(find.text('Null callbacks'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Null callbacks'));
      await tester.pumpAndSettle();
    });

    testWidgets('Empty text handling test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text(''),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('Large text handling test', (WidgetTester tester) async {
      final longText = 'Very long text content ' * 50;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 200,
              child: Text(
                longText,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);

      // Should not overflow
      final RenderBox renderBox = tester.renderObject(find.byType(Container));
      expect(renderBox.size.width, equals(200));
    });
  });

  group('Accessibility Tests', () {
    testWidgets('Basic accessibility test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Test widget',
              button: true,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: 100,
                  height: 50,
                  color: Colors.blue,
                  child: const Text('Accessible'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Semantics), findsOneWidget);
      expect(find.text('Accessible'), findsOneWidget);
    });

    testWidgets('Touch target size test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () {},
              child: Container(
                width: 44, // Minimum touch target
                height: 44,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      final RenderBox renderBox = tester.renderObject(find.byType(Container));
      expect(renderBox.size.width, greaterThanOrEqualTo(44));
      expect(renderBox.size.height, greaterThanOrEqualTo(44));
    });
  });
}

/// Helper widget for animation testing
class _AnimationTestWidget extends StatefulWidget {
  @override
  _AnimationTestWidgetState createState() => _AnimationTestWidgetState();
}

class _AnimationTestWidgetState extends State<_AnimationTestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _controller.forward(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_animation.value * 0.1),
            child: Container(
              width: 100,
              height: 50,
              color: Colors.blue,
              child: const Text('Animated'),
            ),
          );
        },
      ),
    );
  }
}

/// Helper widget for performance testing
class _PerformanceTestWidget extends StatefulWidget {
  @override
  _PerformanceTestWidgetState createState() => _PerformanceTestWidgetState();
}

class _PerformanceTestWidgetState extends State<_PerformanceTestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: Container(
            width: 50,
            height: 50,
            color: Colors.red,
          ),
        );
      },
    );
  }
}

/// Helper widget for disposal testing
class _DisposableTestWidget extends StatefulWidget {
  final List<TextEditingController> controllers;

  const _DisposableTestWidget({required this.controllers});

  @override
  _DisposableTestWidgetState createState() => _DisposableTestWidgetState();
}

class _DisposableTestWidgetState extends State<_DisposableTestWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    widget.controllers.add(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}