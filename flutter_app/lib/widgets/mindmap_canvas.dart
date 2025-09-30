/// Mindmap Canvas Widget - Core drawing and interaction surface
///
/// This widget provides the main canvas for rendering and interacting with
/// the mindmap using Flutter's CustomPainter for high-performance drawing.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as vector_math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../state/providers.dart';
import '../services/canvas_service.dart';

/// The main mindmap canvas widget with zoom, pan, and rendering capabilities
class MindmapCanvas extends ConsumerStatefulWidget {
  const MindmapCanvas({
    super.key,
    this.backgroundColor = Colors.white,
    this.gridColor = Colors.grey,
    this.showGrid = true,
    this.enableZoom = true,
    this.enablePan = true,
    this.minZoom = 0.1,
    this.maxZoom = 10.0,
    this.onNodeTapped,
    this.onEdgeTapped,
    this.onCanvasTapped,
    this.onNodeDragStart,
    this.onNodeDragUpdate,
    this.onNodeDragEnd,
  });

  final Color backgroundColor;
  final Color gridColor;
  final bool showGrid;
  final bool enableZoom;
  final bool enablePan;
  final double minZoom;
  final double maxZoom;
  final Function(Node node)? onNodeTapped;
  final Function(Edge edge)? onEdgeTapped;
  final Function(Offset position)? onCanvasTapped;
  final Function(Node node, Offset position)? onNodeDragStart;
  final Function(Node node, Offset position)? onNodeDragUpdate;
  final Function(Node node, Offset position)? onNodeDragEnd;

  @override
  ConsumerState<MindmapCanvas> createState() => _MindmapCanvasState();
}

class _MindmapCanvasState extends ConsumerState<MindmapCanvas>
    with TickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _zoomAnimationController;
  late Animation<Matrix4> _zoomAnimation;

  // Interaction state
  Node? _draggedNode;
  Offset _lastPanPosition = Offset.zero;
  double _baseScaleFactor = 1.0;

  // Performance optimization
  bool _isTransforming = false;
  DateTime _lastRenderTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _setupZoomAnimation();
    _setupTransformationListener();
    _setupCanvasServiceCallbacks();
  }

  @override
  void dispose() {
    _unregisterCanvasServiceCallbacks();
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  void _setupZoomAnimation() {
    _zoomAnimation = Matrix4Tween().animate(
      CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _zoomAnimation.addListener(() {
      _transformationController.value = _zoomAnimation.value;
    });
  }

  void _setupTransformationListener() {
    _transformationController.addListener(() {
      if (mounted) {
        final renderState = ref.read(renderStateProvider);
        if (renderState.animationsEnabled) {
          setState(() {
            _isTransforming = true;
          });
          // Debounce transformation end
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _isTransforming = false;
              });
            }
          });
        }

        // Report zoom level to canvas service
        final canvasController = ref.read(canvasControllerProvider);
        canvasController.reportZoomLevel(_currentZoom);
      }
    });
  }

  void _setupCanvasServiceCallbacks() {
    if (mounted) {
      final canvasController = ref.read(canvasControllerProvider);
      canvasController.registerCallbacks(
        onZoomIn: _handleZoomIn,
        onZoomOut: _handleZoomOut,
        onZoomToFit: _handleZoomToFit,
        onSetZoom: _handleSetZoom,
      );
    }
  }

  void _unregisterCanvasServiceCallbacks() {
    if (mounted) {
      final canvasController = ref.read(canvasControllerProvider);
      canvasController.unregisterCallbacks();
    }
  }

  void _handleZoomIn() {
    final newZoom = (_currentZoom * 1.2).clamp(widget.minZoom, widget.maxZoom);
    final center = context.size != null
        ? Offset(context.size!.width / 2, context.size!.height / 2)
        : Offset.zero;
    zoomToPoint(center, newZoom);
  }

  void _handleZoomOut() {
    final newZoom = (_currentZoom * 0.8).clamp(widget.minZoom, widget.maxZoom);
    final center = context.size != null
        ? Offset(context.size!.width / 2, context.size!.height / 2)
        : Offset.zero;
    zoomToPoint(center, newZoom);
  }

  void _handleZoomToFit() {
    zoomToFit();
  }

  void _handleSetZoom(double zoom) {
    final center = context.size != null
        ? Offset(context.size!.width / 2, context.size!.height / 2)
        : Offset.zero;
    zoomToPoint(center, zoom);
  }

  /// Convert screen coordinates to canvas coordinates
  Offset _screenToCanvas(Offset screenPosition) {
    final Matrix4 transform = _transformationController.value;
    final Matrix4 inverse = Matrix4.inverted(transform);
    final vector_math.Vector3 canvasPosition = inverse.transform3(vector_math.Vector3(
      screenPosition.dx,
      screenPosition.dy,
      0.0,
    ));
    return Offset(canvasPosition.x, canvasPosition.y);
  }

  /// Convert canvas coordinates to screen coordinates
  Offset _canvasToScreen(Offset canvasPosition) {
    final Matrix4 transform = _transformationController.value;
    final vector_math.Vector3 screenPosition = transform.transform3(vector_math.Vector3(
      canvasPosition.dx,
      canvasPosition.dy,
      0.0,
    ));
    return Offset(screenPosition.x, screenPosition.y);
  }

  /// Get current zoom level
  double get _currentZoom {
    return _transformationController.value.getMaxScaleOnAxis();
  }

  /// Zoom to fit all content
  void zoomToFit({bool animate = true}) {
    final document = ref.read(mindmapDataProvider);
    if (document == null || document.nodes.isEmpty) return;

    final bounds = _calculateContentBounds(document);
    if (bounds == null) return;

    final canvasSize = context.size;
    if (canvasSize == null) return;

    final padding = 50.0;
    final targetZoom = math.min(
      (canvasSize.width - padding * 2) / bounds.width,
      (canvasSize.height - padding * 2) / bounds.height,
    ).clamp(widget.minZoom, widget.maxZoom);

    final targetOffset = Offset(
      (canvasSize.width - bounds.width * targetZoom) / 2 - bounds.left * targetZoom,
      (canvasSize.height - bounds.height * targetZoom) / 2 - bounds.top * targetZoom,
    );

    final targetTransform = Matrix4.identity()
      ..translate(targetOffset.dx, targetOffset.dy)
      ..scale(targetZoom);

    if (animate) {
      _animateToTransform(targetTransform);
    } else {
      _transformationController.value = targetTransform;
    }
  }

  /// Zoom to specific level at point
  void zoomToPoint(Offset point, double zoom, {bool animate = true}) {
    final clampedZoom = zoom.clamp(widget.minZoom, widget.maxZoom);
    final canvasPoint = _screenToCanvas(point);

    final targetTransform = Matrix4.identity()
      ..translate(point.dx, point.dy)
      ..scale(clampedZoom)
      ..translate(-canvasPoint.dx, -canvasPoint.dy);

    if (animate) {
      _animateToTransform(targetTransform);
    } else {
      _transformationController.value = targetTransform;
    }
  }

  /// Animate to target transform
  void _animateToTransform(Matrix4 targetTransform) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetTransform,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

    _zoomAnimationController.forward(from: 0.0);
  }

  /// Calculate bounds of all content
  Rect? _calculateContentBounds(Document document) {
    if (document.nodes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in document.nodes) {
      final left = node.position.x;
      final top = node.position.y;
      final right = left + node.size.width;
      final bottom = top + node.size.height;

      minX = math.min(minX, left);
      minY = math.min(minY, top);
      maxX = math.max(maxX, right);
      maxY = math.max(maxY, bottom);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Handle node tap
  void _handleNodeTap(Node node, Offset position) {
    widget.onNodeTapped?.call(node);

    // Select the node
    ref.read(mindmapStateProvider.notifier).selectNode(node.id);
  }

  /// Handle edge tap
  void _handleEdgeTap(Edge edge, Offset position) {
    widget.onEdgeTapped?.call(edge);

    // Select the edge
    ref.read(mindmapStateProvider.notifier).selectEdge(edge.id);
  }

  /// Handle canvas tap
  void _handleCanvasTap(Offset position) {
    final canvasPosition = _screenToCanvas(position);
    widget.onCanvasTapped?.call(canvasPosition);

    // Clear selections
    ref.read(mindmapStateProvider.notifier).clearSelections();
  }

  /// Find node at position
  Node? _findNodeAtPosition(Offset canvasPosition, Document document) {
    // Search in reverse order to get topmost node
    for (int i = document.nodes.length - 1; i >= 0; i--) {
      final node = document.nodes[i];
      if (!node.isVisible) continue;

      final nodeRect = Rect.fromLTWH(
        node.position.x,
        node.position.y,
        node.size.width,
        node.size.height,
      );

      if (nodeRect.contains(canvasPosition)) {
        return node;
      }
    }
    return null;
  }

  /// Find edge at position
  Edge? _findEdgeAtPosition(Offset canvasPosition, Document document) {
    const tolerance = 10.0;

    for (final edge in document.edges) {
      if (!edge.isVisible) continue;

      final sourceNode = document.findNodeById(edge.sourceId);
      final targetNode = document.findNodeById(edge.targetId);

      if (sourceNode == null || targetNode == null) continue;

      final path = edge.calculatePath(sourceNode, targetNode);
      final point = Point(canvasPosition.dx, canvasPosition.dy);

      if (edge.isPointNear(point, path, tolerance)) {
        return edge;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final document = ref.watch(mindmapDataProvider);
    final renderState = ref.watch(renderStateProvider);
    final globalLoading = ref.watch(globalLoadingProvider);

    return Listener(
      onPointerSignal: widget.enableZoom ? _handlePointerSignal : null,
      child: GestureDetector(
        onTapUp: _handleTapUp,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minZoom,
          maxScale: widget.maxZoom,
          panEnabled: widget.enablePan,
          scaleEnabled: widget.enableZoom,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(1000),
          child: Container(
            color: widget.backgroundColor,
            child: Stack(
              children: [
                // Main canvas
                CustomPaint(
                  painter: MindmapCanvasPainter(
                    document: document,
                    renderState: renderState,
                    showGrid: widget.showGrid,
                    gridColor: widget.gridColor,
                    isTransforming: _isTransforming,
                    currentZoom: _currentZoom,
                  ),
                  size: Size.infinite,
                ),

                // Loading indicator
                if (globalLoading)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      final zoomFactor = delta > 0 ? 0.9 : 1.1;
      final newZoom = (_currentZoom * zoomFactor).clamp(widget.minZoom, widget.maxZoom);

      zoomToPoint(event.localPosition, newZoom, animate: false);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final document = ref.read(mindmapDataProvider);
    if (document == null) return;

    final canvasPosition = _screenToCanvas(details.localPosition);

    // Check for node tap first
    final tappedNode = _findNodeAtPosition(canvasPosition, document);
    if (tappedNode != null) {
      _handleNodeTap(tappedNode, canvasPosition);
      return;
    }

    // Check for edge tap
    final tappedEdge = _findEdgeAtPosition(canvasPosition, document);
    if (tappedEdge != null) {
      _handleEdgeTap(tappedEdge, canvasPosition);
      return;
    }

    // Canvas tap
    _handleCanvasTap(details.localPosition);
  }

  void _handlePanStart(DragStartDetails details) {
    final document = ref.read(mindmapDataProvider);
    if (document == null) return;

    final canvasPosition = _screenToCanvas(details.localPosition);
    final node = _findNodeAtPosition(canvasPosition, document);

    if (node != null) {
      _draggedNode = node;
      widget.onNodeDragStart?.call(node, canvasPosition);
    } else {
      _lastPanPosition = details.localPosition;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedNode != null) {
      final canvasPosition = _screenToCanvas(details.localPosition);
      widget.onNodeDragUpdate?.call(_draggedNode!, canvasPosition);

      // Update node position
      final updatedNode = _draggedNode!.copyWith(
        position: Point(canvasPosition.dx, canvasPosition.dy),
      );

      ref.read(mindmapStateProvider.notifier).updateNode(updatedNode);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedNode != null) {
      widget.onNodeDragEnd?.call(_draggedNode!, Offset.zero);
      _draggedNode = null;
    }
  }
}

/// Custom painter for rendering the mindmap
class MindmapCanvasPainter extends CustomPainter {
  const MindmapCanvasPainter({
    required this.document,
    required this.renderState,
    required this.showGrid,
    required this.gridColor,
    required this.isTransforming,
    required this.currentZoom,
  });

  final Document? document;
  final RenderState renderState;
  final bool showGrid;
  final Color gridColor;
  final bool isTransforming;
  final double currentZoom;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    if (showGrid && renderState.gridSnapEnabled) {
      _drawGrid(canvas, size);
    }

    // Early return if no document
    if (document == null) return;

    // Draw edges first (behind nodes)
    _drawEdges(canvas, document!);

    // Draw nodes
    _drawNodes(canvas, document!);

    // Draw rulers if enabled
    if (renderState.showRulers) {
      _drawRulers(canvas, size);
    }
  }

  /// Draw background grid
  void _drawGrid(Canvas canvas, Size size) {
    final gridSize = renderState.gridSize;
    final paint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Calculate grid bounds based on current viewport
    final gridBounds = Rect.fromLTWH(-1000, -1000, size.width + 2000, size.height + 2000);

    // Draw vertical lines
    for (double x = (gridBounds.left / gridSize).floor() * gridSize;
         x <= gridBounds.right;
         x += gridSize) {
      canvas.drawLine(
        Offset(x, gridBounds.top),
        Offset(x, gridBounds.bottom),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = (gridBounds.top / gridSize).floor() * gridSize;
         y <= gridBounds.bottom;
         y += gridSize) {
      canvas.drawLine(
        Offset(gridBounds.left, y),
        Offset(gridBounds.right, y),
        paint,
      );
    }
  }

  /// Draw all edges
  void _drawEdges(Canvas canvas, Document document) {
    for (final edge in document.visibleEdges) {
      final sourceNode = document.findNodeById(edge.sourceId);
      final targetNode = document.findNodeById(edge.targetId);

      if (sourceNode == null || targetNode == null) continue;
      if (!sourceNode.isVisible || !targetNode.isVisible) continue;

      _drawEdge(canvas, edge, sourceNode, targetNode);
    }
  }

  /// Draw a single edge
  void _drawEdge(Canvas canvas, Edge edge, Node sourceNode, Node targetNode) {
    final style = edge.isSelected ? edge.style.asSelected() :
                 edge.isHovered ? edge.style.asHovered() :
                 edge.style;

    final paint = Paint()
      ..color = style.color.withOpacity(style.opacity)
      ..strokeWidth = style.width
      ..style = PaintingStyle.stroke;

    // Set stroke pattern
    switch (style.strokeType) {
      case StrokeType.dashed:
        paint.strokeCap = StrokeCap.round;
        // Note: Flutter doesn't have built-in dashed lines,
        // would need path_provider for complex patterns
        break;
      case StrokeType.dotted:
        paint.strokeCap = StrokeCap.round;
        break;
      case StrokeType.solid:
        paint.strokeCap = StrokeCap.round;
        break;
    }

    // Calculate edge path
    final path = edge.calculatePath(sourceNode, targetNode);

    // Draw the edge path
    final uiPath = Path();
    if (path.points.isNotEmpty) {
      uiPath.moveTo(path.points.first.x, path.points.first.y);

      if (path.controlPoints.isEmpty) {
        // Straight line or simple curve
        for (int i = 1; i < path.points.length; i++) {
          uiPath.lineTo(path.points[i].x, path.points[i].y);
        }
      } else {
        // Bezier curve
        if (path.controlPoints.length == 2 && path.points.length >= 2) {
          uiPath.cubicTo(
            path.controlPoints[0].x, path.controlPoints[0].y,
            path.controlPoints[1].x, path.controlPoints[1].y,
            path.points.last.x, path.points.last.y,
          );
        }
      }
    }

    canvas.drawPath(uiPath, paint);

    // Draw label if present and visible
    if (edge.hasLabel && style.labelStyle.visible) {
      _drawEdgeLabel(canvas, edge, path);
    }
  }

  /// Draw edge label
  void _drawEdgeLabel(Canvas canvas, Edge edge, EdgePath path) {
    final labelStyle = edge.style.labelStyle;

    final textPainter = TextPainter(
      text: TextSpan(
        text: edge.displayLabel,
        style: TextStyle(
          fontSize: labelStyle.fontSize,
          fontWeight: labelStyle.fontWeight,
          color: labelStyle.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Background
    final backgroundRect = Rect.fromCenter(
      center: Offset(path.labelPosition.x, path.labelPosition.y),
      width: textPainter.width + labelStyle.padding.horizontal,
      height: textPainter.height + labelStyle.padding.vertical,
    );

    final backgroundPaint = Paint()
      ..color = labelStyle.backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        backgroundRect,
        Radius.circular(labelStyle.borderRadius),
      ),
      backgroundPaint,
    );

    // Text
    canvas.save();
    canvas.translate(path.labelPosition.x, path.labelPosition.y);
    canvas.rotate(labelStyle.rotation);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  /// Draw all nodes
  void _drawNodes(Canvas canvas, Document document) {
    for (final node in document.visibleNodes) {
      _drawNode(canvas, node);
    }
  }

  /// Draw a single node
  void _drawNode(Canvas canvas, Node node) {
    final rect = Rect.fromLTWH(
      node.position.x,
      node.position.y,
      node.size.width,
      node.size.height,
    );

    final style = node.isSelected ? node.style.asSelected() :
                 node.isHovered ? node.style.asHovered() :
                 node.style;

    // Node background
    final backgroundPaint = Paint()
      ..color = style.backgroundColor.withOpacity(style.opacity)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(style.borderRadius)),
      backgroundPaint,
    );

    // Node border
    if (style.borderWidth > 0) {
      final borderPaint = Paint()
        ..color = style.borderColor
        ..strokeWidth = style.borderWidth
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(style.borderRadius)),
        borderPaint,
      );
    }

    // Node text
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: TextStyle(
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          color: style.textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: style.textAlign,
    );

    textPainter.layout(maxWidth: rect.width - style.padding.horizontal);

    final textOffset = Offset(
      rect.left + style.padding.left +
        (rect.width - style.padding.horizontal - textPainter.width) / 2,
      rect.top + style.padding.top +
        (rect.height - style.padding.vertical - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textOffset);

    // Selection indicator
    if (node.isSelected) {
      _drawSelectionIndicator(canvas, rect);
    }
  }

  /// Draw selection indicator around node
  void _drawSelectionIndicator(Canvas canvas, Rect rect) {
    final selectionPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final expandedRect = rect.inflate(4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(expandedRect, const Radius.circular(8.0)),
      selectionPaint,
    );
  }

  /// Draw rulers
  void _drawRulers(Canvas canvas, Size size) {
    final rulerPaint = Paint()
      ..color = Colors.grey.withOpacity(0.7)
      ..strokeWidth = 1.0;

    // Draw ruler marks
    const majorTickSize = 20.0;
    const minorTickSize = 10.0;
    const tickSpacing = 50.0;

    // Horizontal ruler
    for (double x = 0; x <= size.width; x += tickSpacing) {
      final isMajor = (x % (tickSpacing * 5)) == 0;
      final tickSize = isMajor ? majorTickSize : minorTickSize;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, tickSize),
        rulerPaint,
      );
    }

    // Vertical ruler
    for (double y = 0; y <= size.height; y += tickSpacing) {
      final isMajor = (y % (tickSpacing * 5)) == 0;
      final tickSize = isMajor ? majorTickSize : minorTickSize;

      canvas.drawLine(
        Offset(0, y),
        Offset(tickSize, y),
        rulerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(MindmapCanvasPainter oldDelegate) {
    return oldDelegate.document != document ||
           oldDelegate.renderState != renderState ||
           oldDelegate.isTransforming != isTransforming ||
           oldDelegate.currentZoom != currentZoom;
  }
}

/// Extensions for vector math
extension Vector3 on ui.Offset {
  Vector3 toVector3([double z = 0.0]) => Vector3(dx, dy, z);
}

/// Simple 3D vector class for transformations
class Vector3 {
  const Vector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

extension Matrix4Extensions on Matrix4 {
  Vector3 transform3(Vector3 vector) {
    final result = this * Column3(vector.x, vector.y, vector.z).xyz;
    return Vector3(result.x, result.y, result.z);
  }
}

extension Column3 on Vector3 {
  Vector3 get xyz => Vector3(x, y, z);
}