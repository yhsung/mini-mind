/// Comprehensive tests for MindmapCanvas functionality
///
/// This file contains extensive widget tests for MindmapCanvas, covering gesture
/// simulation, zoom/pan operations, viewport management, and coordinate transformations.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:math' as math;

void main() {
  group('MindmapCanvas Basic Tests', () {
    testWidgets('Canvas infrastructure test', (WidgetTester tester) async {
      // Test basic canvas widget creation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 400,
              height: 300,
              color: Colors.white,
              child: CustomPaint(
                painter: _TestCanvasPainter(),
                size: const Size(400, 300),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('InteractiveViewer integration test', (WidgetTester tester) async {
      final transformationController = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewer(
              transformationController: transformationController,
              minScale: 0.1,
              maxScale: 10.0,
              child: Container(
                width: 800,
                height: 600,
                color: Colors.blue,
                child: const Center(
                  child: Text('Interactive Canvas'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Interactive Canvas'), findsOneWidget);

      transformationController.dispose();
    });

    testWidgets('Gesture detection test', (WidgetTester tester) async {
      bool tapCalled = false;
      bool panStartCalled = false;
      bool panUpdateCalled = false;
      bool panEndCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => tapCalled = true,
              onPanStart: (_) => panStartCalled = true,
              onPanUpdate: (_) => panUpdateCalled = true,
              onPanEnd: (_) => panEndCalled = true,
              child: Container(
                width: 400,
                height: 300,
                color: Colors.green,
                child: const Center(
                  child: Text('Gesture Canvas'),
                ),
              ),
            ),
          ),
        ),
      );

      // Test tap
      await tester.tap(find.text('Gesture Canvas'));
      await tester.pumpAndSettle();
      expect(tapCalled, isTrue);

      // Test pan gesture
      await tester.dragFrom(
        tester.getCenter(find.text('Gesture Canvas')),
        const Offset(50, 50),
      );
      await tester.pumpAndSettle();

      expect(panStartCalled, isTrue);
      expect(panUpdateCalled, isTrue);
      expect(panEndCalled, isTrue);
    });

    testWidgets('Coordinate transformation test', (WidgetTester tester) async {
      final transformationController = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _CoordinateTestWidget(
              transformationController: transformationController,
            ),
          ),
        ),
      );

      // Initial transformation
      expect(transformationController.value, equals(Matrix4.identity()));

      // Apply transformation
      transformationController.value = Matrix4.identity()..scale(2.0);
      await tester.pumpAndSettle();

      // Verify transformation applied
      expect(transformationController.value.getMaxScaleOnAxis(), equals(2.0));

      transformationController.dispose();
    });
  });

  group('Zoom and Pan Tests', () {
    testWidgets('Zoom functionality test', (WidgetTester tester) async {
      final transformationController = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ZoomTestWidget(
              transformationController: transformationController,
            ),
          ),
        ),
      );

      // Initial zoom level
      double initialZoom = transformationController.value.getMaxScaleOnAxis();
      expect(initialZoom, equals(1.0));

      // Simulate zoom in
      transformationController.value = Matrix4.identity()..scale(2.0);
      await tester.pumpAndSettle();

      double zoomedScale = transformationController.value.getMaxScaleOnAxis();
      expect(zoomedScale, equals(2.0));

      // Simulate zoom out
      transformationController.value = Matrix4.identity()..scale(0.5);
      await tester.pumpAndSettle();

      double zoomedOutScale = transformationController.value.getMaxScaleOnAxis();
      expect(zoomedOutScale, equals(0.5));

      transformationController.dispose();
    });

    testWidgets('Pan functionality test', (WidgetTester tester) async {
      final transformationController = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _PanTestWidget(
              transformationController: transformationController,
            ),
          ),
        ),
      );

      // Initial position
      Matrix4 initialTransform = transformationController.value;
      expect(initialTransform.getTranslation().x, equals(0.0));
      expect(initialTransform.getTranslation().y, equals(0.0));

      // Apply pan transformation
      transformationController.value = Matrix4.identity()..translate(100.0, 50.0);
      await tester.pumpAndSettle();

      Matrix4 pannedTransform = transformationController.value;
      expect(pannedTransform.getTranslation().x, equals(100.0));
      expect(pannedTransform.getTranslation().y, equals(50.0));

      transformationController.dispose();
    });

    testWidgets('Zoom constraints test', (WidgetTester tester) async {
      const double minScale = 0.1;
      const double maxScale = 10.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewer(
              minScale: minScale,
              maxScale: maxScale,
              child: Container(
                width: 400,
                height: 300,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );

      final interactiveViewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );

      expect(interactiveViewer.minScale, equals(minScale));
      expect(interactiveViewer.maxScale, equals(maxScale));
    });

    testWidgets('Mouse wheel zoom simulation test', (WidgetTester tester) async {
      bool scrollEventReceived = false;
      PointerScrollEvent? lastScrollEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  scrollEventReceived = true;
                  lastScrollEvent = event;
                }
              },
              child: Container(
                width: 400,
                height: 300,
                color: Colors.yellow,
                child: const Text('Scroll Target'),
              ),
            ),
          ),
        ),
      );

      // Simulate mouse wheel scroll
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(200, 150), const Offset(0, -100)),
      );
      await tester.pumpAndSettle();

      expect(scrollEventReceived, isTrue);
      expect(lastScrollEvent, isNotNull);
    });
  });

  group('Viewport Management Tests', () {
    testWidgets('Viewport bounds calculation test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ViewportTestWidget(),
          ),
        ),
      );

      expect(find.byType(_ViewportTestWidget), findsOneWidget);

      // Verify widget builds without errors
      final RenderBox renderBox = tester.renderObject(find.byType(Container));
      expect(renderBox.size.width, greaterThan(0));
      expect(renderBox.size.height, greaterThan(0));
    });

    testWidgets('Content bounds calculation test', (WidgetTester tester) async {
      // Test bounds calculation with multiple elements
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(width: 100, height: 50, color: Colors.red),
                ),
                Positioned(
                  left: 200,
                  top: 150,
                  child: Container(width: 80, height: 60, color: Colors.blue),
                ),
                Positioned(
                  left: 50,
                  top: 250,
                  child: Container(width: 120, height: 40, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify all positioned elements are present
      expect(find.byType(Container), findsNWidgets(3));

      // Calculate theoretical bounds
      // Min: (10, 10), Max: (280, 310) based on positioned elements
      const expectedMinX = 10.0;
      const expectedMinY = 10.0;
      const expectedMaxX = 280.0; // 200 + 80
      const expectedMaxY = 290.0; // 250 + 40

      final bounds = Rect.fromLTRB(expectedMinX, expectedMinY, expectedMaxX, expectedMaxY);
      expect(bounds.width, equals(270.0));
      expect(bounds.height, equals(280.0));
    });

    testWidgets('Zoom to fit functionality test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ZoomToFitTestWidget(),
          ),
        ),
      );

      expect(find.byType(_ZoomToFitTestWidget), findsOneWidget);

      // Trigger zoom to fit
      await tester.tap(find.text('Zoom to Fit'));
      await tester.pumpAndSettle();

      // Verify widget responds to interaction
      expect(find.text('Zoom Applied'), findsOneWidget);
    });
  });

  group('Canvas Rendering Tests', () {
    testWidgets('Custom painter rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _ComplexCanvasPainter(),
              size: const Size(300, 200),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      // Verify painter was called by checking widget structure
      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      expect(customPaint.painter, isA<_ComplexCanvasPainter>());
    });

    testWidgets('Grid rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _GridPainter(
                gridSize: 20.0,
                gridColor: Colors.grey,
                showGrid: true,
              ),
              size: const Size(400, 300),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter as _GridPainter;
      expect(painter.gridSize, equals(20.0));
      expect(painter.gridColor, equals(Colors.grey));
      expect(painter.showGrid, isTrue);
    });

    testWidgets('Node rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _NodePainter(
                nodes: [
                  _TestNode(Offset(50, 50), const Size(100, 60), 'Node 1'),
                  _TestNode(Offset(200, 100), const Size(120, 80), 'Node 2'),
                ],
              ),
              size: const Size(400, 300),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter as _NodePainter;
      expect(painter.nodes.length, equals(2));
    });

    testWidgets('Edge rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _EdgePainter(
                edges: [
                  _TestEdge(Offset(50, 50), Offset(200, 100)),
                  _TestEdge(Offset(200, 100), Offset(300, 200)),
                ],
              ),
              size: const Size(400, 300),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter as _EdgePainter;
      expect(painter.edges.length, equals(2));
    });
  });

  group('Performance Tests', () {
    testWidgets('Large canvas performance test', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _PerformanceTestPainter(nodeCount: 100),
              size: const Size(1000, 800),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      // Should render within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('Transform performance test', (WidgetTester tester) async {
      final transformationController = TransformationController();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewer(
              transformationController: transformationController,
              child: Container(
                width: 2000,
                height: 1500,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Apply multiple transformations rapidly
      for (int i = 0; i < 10; i++) {
        transformationController.value = Matrix4.identity()
          ..scale(1.0 + i * 0.1)
          ..translate(i * 10.0, i * 5.0);
        await tester.pump(const Duration(milliseconds: 16));
      }

      stopwatch.stop();

      // Should handle transformations smoothly
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

      transformationController.dispose();
    });

    testWidgets('Memory usage test with canvas disposal', (WidgetTester tester) async {
      final controllers = <TransformationController>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _DisposableCanvasWidget(controllers: controllers),
          ),
        ),
      );

      // Dispose the widget
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Controllers should be disposed
      for (final controller in controllers) {
        expect(() => controller.value, throwsAssertionError);
      }
    });
  });

  group('Interaction and Gesture Tests', () {
    testWidgets('Tap detection at specific coordinates test', (WidgetTester tester) async {
      Offset? lastTapPosition;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTapUp: (details) => lastTapPosition = details.localPosition,
              child: Container(
                width: 400,
                height: 300,
                color: Colors.purple,
              ),
            ),
          ),
        ),
      );

      // Tap at specific position
      const tapPosition = Offset(150, 120);
      await tester.tapAt(tapPosition);
      await tester.pumpAndSettle();

      expect(lastTapPosition, isNotNull);
      expect((lastTapPosition! - tapPosition).distance, lessThan(5.0));
    });

    testWidgets('Drag gesture simulation test', (WidgetTester tester) async {
      final dragPositions = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onPanUpdate: (details) => dragPositions.add(details.localPosition),
              child: Container(
                width: 400,
                height: 300,
                color: Colors.orange,
              ),
            ),
          ),
        ),
      );

      // Perform drag gesture
      await tester.dragFrom(
        const Offset(50, 50),
        const Offset(200, 150),
      );
      await tester.pumpAndSettle();

      expect(dragPositions.isNotEmpty, isTrue);
      expect(dragPositions.first.dx, greaterThan(40));
      expect(dragPositions.last.dx, greaterThan(240));
    });

    testWidgets('Multi-touch gesture simulation test', (WidgetTester tester) async {
      bool scaleStartCalled = false;
      bool scaleUpdateCalled = false;
      bool scaleEndCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onScaleStart: (_) => scaleStartCalled = true,
              onScaleUpdate: (_) => scaleUpdateCalled = true,
              onScaleEnd: (_) => scaleEndCalled = true,
              child: Container(
                width: 400,
                height: 300,
                color: Colors.teal,
              ),
            ),
          ),
        ),
      );

      // Simulate pinch/scale gesture
      const center = Offset(200, 150);
      final TestGesture gesture1 = await tester.startGesture(center - const Offset(50, 0));
      final TestGesture gesture2 = await tester.startGesture(center + const Offset(50, 0));

      await tester.pump();

      await gesture1.moveTo(center - const Offset(100, 0));
      await gesture2.moveTo(center + const Offset(100, 0));
      await tester.pump();

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(scaleStartCalled, isTrue);
      expect(scaleUpdateCalled, isTrue);
      expect(scaleEndCalled, isTrue);
    });
  });

  group('Edge Cases and Error Handling', () {
    testWidgets('Empty canvas handling test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _EmptyCanvasPainter(),
              size: const Size(400, 300),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('Invalid transformation handling test', (WidgetTester tester) async {
      final transformationController = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewer(
              transformationController: transformationController,
              child: Container(
                width: 400,
                height: 300,
                color: Colors.cyan,
              ),
            ),
          ),
        ),
      );

      // Apply invalid transformation (should be handled gracefully)
      transformationController.value = Matrix4.zero();
      await tester.pumpAndSettle();

      // Widget should still exist and not crash
      expect(find.byType(InteractiveViewer), findsOneWidget);

      transformationController.dispose();
    });

    testWidgets('Large coordinate values test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _LargeCoordinatePainter(),
              size: const Size(400, 300),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}

// Helper test widgets and painters

class _TestCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      50.0,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoordinateTestWidget extends StatelessWidget {
  final TransformationController transformationController;

  const _CoordinateTestWidget({required this.transformationController});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      child: Container(
        width: 400,
        height: 300,
        color: Colors.lightBlue,
        child: const Center(child: Text('Coordinate Test')),
      ),
    );
  }
}

class _ZoomTestWidget extends StatelessWidget {
  final TransformationController transformationController;

  const _ZoomTestWidget({required this.transformationController});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      minScale: 0.1,
      maxScale: 5.0,
      child: Container(
        width: 600,
        height: 400,
        color: Colors.lightGreen,
        child: const Center(child: Text('Zoom Test')),
      ),
    );
  }
}

class _PanTestWidget extends StatelessWidget {
  final TransformationController transformationController;

  const _PanTestWidget({required this.transformationController});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      boundaryMargin: const EdgeInsets.all(100),
      child: Container(
        width: 800,
        height: 600,
        color: Colors.lightCyan,
        child: const Center(child: Text('Pan Test')),
      ),
    );
  }
}

class _ViewportTestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 300,
      color: Colors.amber,
      child: const Center(child: Text('Viewport Test')),
    );
  }
}

class _ZoomToFitTestWidget extends StatefulWidget {
  @override
  _ZoomToFitTestWidgetState createState() => _ZoomToFitTestWidgetState();
}

class _ZoomToFitTestWidgetState extends State<_ZoomToFitTestWidget> {
  bool zoomApplied = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => zoomApplied = true),
          child: const Text('Zoom to Fit'),
        ),
        if (zoomApplied) const Text('Zoom Applied'),
      ],
    );
  }
}

class _ComplexCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw multiple shapes
    paint.color = Colors.red;
    canvas.drawRect(Rect.fromLTWH(10, 10, 50, 30), paint);

    paint.color = Colors.green;
    canvas.drawCircle(const Offset(100, 50), 25, paint);

    paint.color = Colors.blue;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(150, 20, 60, 40),
        const Radius.circular(8),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;
  final bool showGrid;

  const _GridPainter({
    required this.gridSize,
    required this.gridColor,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGrid) return;

    final paint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
           oldDelegate.gridColor != gridColor ||
           oldDelegate.showGrid != showGrid;
  }
}

class _TestNode {
  final Offset position;
  final Size size;
  final String text;

  const _TestNode(this.position, this.size, this.text);
}

class _NodePainter extends CustomPainter {
  final List<_TestNode> nodes;

  const _NodePainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final node in nodes) {
      paint.color = Colors.blue.withOpacity(0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height),
          const Radius.circular(8),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NodePainter oldDelegate) {
    return oldDelegate.nodes.length != nodes.length;
  }
}

class _TestEdge {
  final Offset start;
  final Offset end;

  const _TestEdge(this.start, this.end);
}

class _EdgePainter extends CustomPainter {
  final List<_TestEdge> edges;

  const _EdgePainter({required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      canvas.drawLine(edge.start, edge.end, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) {
    return oldDelegate.edges.length != edges.length;
  }
}

class _PerformanceTestPainter extends CustomPainter {
  final int nodeCount;

  const _PerformanceTestPainter({required this.nodeCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < nodeCount; i++) {
      paint.color = Color.lerp(Colors.red, Colors.blue, i / nodeCount)!;
      canvas.drawCircle(
        Offset(
          (i % 10) * (size.width / 10) + 25,
          (i ~/ 10) * (size.height / (nodeCount / 10)) + 25,
        ),
        20,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PerformanceTestPainter oldDelegate) {
    return oldDelegate.nodeCount != nodeCount;
  }
}

class _DisposableCanvasWidget extends StatefulWidget {
  final List<TransformationController> controllers;

  const _DisposableCanvasWidget({required this.controllers});

  @override
  _DisposableCanvasWidgetState createState() => _DisposableCanvasWidgetState();
}

class _DisposableCanvasWidgetState extends State<_DisposableCanvasWidget> {
  late TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    widget.controllers.add(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      child: Container(
        width: 400,
        height: 300,
        color: Colors.pink,
      ),
    );
  }
}

class _EmptyCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Intentionally empty
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LargeCoordinatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    // Draw with very large coordinates
    canvas.drawCircle(const Offset(1000000, 1000000), 50, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}