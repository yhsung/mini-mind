/// Gesture Handler - Comprehensive gesture management for mindmap interactions
///
/// This widget provides centralized gesture handling for the mindmap canvas,
/// including drag and drop, multi-touch gestures, and interaction coordination.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/node.dart';
import '../models/edge.dart';
import '../models/document.dart';
import '../state/providers.dart';

/// Gesture types for interaction handling
enum GestureType {
  tap,
  doubleTap,
  longPress,
  drag,
  pan,
  zoom,
  hover,
}

/// Gesture result containing information about the gesture
class GestureResult {
  const GestureResult({
    required this.type,
    required this.position,
    this.node,
    this.edge,
    this.delta,
    this.scale,
    this.velocity,
    this.details,
  });

  final GestureType type;
  final Offset position;
  final Node? node;
  final Edge? edge;
  final Offset? delta;
  final double? scale;
  final Velocity? velocity;
  final Map<String, dynamic>? details;
}

/// Comprehensive gesture handler for mindmap interactions
class MindmapGestureHandler extends ConsumerStatefulWidget {
  const MindmapGestureHandler({
    super.key,
    required this.child,
    this.onGesture,
    this.onNodeTapped,
    this.onNodeDoubleTapped,
    this.onNodeLongPressed,
    this.onNodeDragStart,
    this.onNodeDragUpdate,
    this.onNodeDragEnd,
    this.onCanvasTapped,
    this.onCanvasDoubleTapped,
    this.onCanvasLongPressed,
    this.onCanvasPanned,
    this.onCanvasZoomed,
    this.enableDragAndDrop = true,
    this.enableMultiSelect = true,
    this.enableContextMenu = true,
    this.dragThreshold = 10.0,
    this.longPressThreshold = const Duration(milliseconds: 500),
    this.doubleTapThreshold = const Duration(milliseconds: 300),
  });

  final Widget child;
  final Function(GestureResult result)? onGesture;
  final Function(Node node, Offset position)? onNodeTapped;
  final Function(Node node, Offset position)? onNodeDoubleTapped;
  final Function(Node node, Offset position)? onNodeLongPressed;
  final Function(Node node, Offset startPosition)? onNodeDragStart;
  final Function(Node node, Offset position, Offset delta)? onNodeDragUpdate;
  final Function(Node node, Offset endPosition, Velocity velocity)? onNodeDragEnd;
  final Function(Offset position)? onCanvasTapped;
  final Function(Offset position)? onCanvasDoubleTapped;
  final Function(Offset position)? onCanvasLongPressed;
  final Function(Offset delta)? onCanvasPanned;
  final Function(double scale, Offset focalPoint)? onCanvasZoomed;
  final bool enableDragAndDrop;
  final bool enableMultiSelect;
  final bool enableContextMenu;
  final double dragThreshold;
  final Duration longPressThreshold;
  final Duration doubleTapThreshold;

  @override
  ConsumerState<MindmapGestureHandler> createState() => _MindmapGestureHandlerState();
}

class _MindmapGestureHandlerState extends ConsumerState<MindmapGestureHandler> {
  // Gesture state tracking
  Node? _draggedNode;
  Offset? _dragStartPosition;
  Offset? _lastPanPosition;
  bool _isDragging = false;
  bool _isPanning = false;
  double _baseScale = 1.0;

  // Multi-touch state
  Map<int, Offset> _touchPositions = {};
  double? _initialDistance;
  Offset? _initialFocalPoint;

  // Tap gesture state
  Timer? _doubleTapTimer;
  Offset? _lastTapPosition;
  DateTime? _lastTapTime;

  // Long press state
  Timer? _longPressTimer;
  Offset? _longPressPosition;

  // Selection state
  final Set<String> _selectedNodeIds = {};
  bool _isMultiSelecting = false;

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// Convert screen coordinates to canvas coordinates
  Offset _screenToCanvas(Offset screenPosition) {
    // This would need to access the transformation matrix from the canvas
    // For now, return the position as-is
    return screenPosition;
  }

  /// Find node at the given position
  Node? _findNodeAtPosition(Offset position) {
    final document = ref.read(mindmapDataProvider);
    if (document == null) return null;

    final canvasPosition = _screenToCanvas(position);

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

  /// Find edge at the given position
  Edge? _findEdgeAtPosition(Offset position) {
    final document = ref.read(mindmapDataProvider);
    if (document == null) return null;

    const tolerance = 10.0;
    final canvasPosition = _screenToCanvas(position);

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

  /// Handle tap down
  void _handleTapDown(TapDownDetails details) {
    _longPressPosition = details.localPosition;
    _startLongPressTimer();
  }

  /// Handle tap up
  void _handleTapUp(TapUpDetails details) {
    _cancelLongPressTimer();

    final position = details.localPosition;
    final node = _findNodeAtPosition(position);
    final now = DateTime.now();

    // Check for double tap
    if (_lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!) < widget.doubleTapThreshold &&
        (position - _lastTapPosition!).distance < 20.0) {
      _handleDoubleTap(position, node);
      _lastTapTime = null;
      _lastTapPosition = null;
      return;
    }

    // Handle single tap
    _handleSingleTap(position, node);

    // Set up for potential double tap
    _lastTapTime = now;
    _lastTapPosition = position;
    _doubleTapTimer = Timer(widget.doubleTapThreshold, () {
      _lastTapTime = null;
      _lastTapPosition = null;
    });
  }

  /// Handle single tap
  void _handleSingleTap(Offset position, Node? node) {
    if (node != null) {
      _handleNodeTap(node, position);
    } else {
      _handleCanvasTap(position);
    }

    // Emit gesture result
    widget.onGesture?.call(GestureResult(
      type: GestureType.tap,
      position: position,
      node: node,
    ));
  }

  /// Handle double tap
  void _handleDoubleTap(Offset position, Node? node) {
    if (node != null) {
      widget.onNodeDoubleTapped?.call(node, position);
    } else {
      widget.onCanvasDoubleTapped?.call(position);
    }

    // Emit gesture result
    widget.onGesture?.call(GestureResult(
      type: GestureType.doubleTap,
      position: position,
      node: node,
    ));
  }

  /// Handle node tap
  void _handleNodeTap(Node node, Offset position) {
    // Handle multi-selection
    if (_isMultiSelecting && widget.enableMultiSelect) {
      if (_selectedNodeIds.contains(node.id)) {
        _selectedNodeIds.remove(node.id);
        ref.read(mindmapStateProvider.notifier).updateNode(node.deselect());
      } else {
        _selectedNodeIds.add(node.id);
        ref.read(mindmapStateProvider.notifier).updateNode(node.select());
      }
    } else {
      // Single selection
      _selectedNodeIds.clear();
      _selectedNodeIds.add(node.id);
      ref.read(mindmapStateProvider.notifier).selectNode(node.id);
    }

    widget.onNodeTapped?.call(node, position);
  }

  /// Handle canvas tap
  void _handleCanvasTap(Offset position) {
    // Clear selections
    _selectedNodeIds.clear();
    ref.read(mindmapStateProvider.notifier).clearSelections();

    widget.onCanvasTapped?.call(position);
  }

  /// Start long press timer
  void _startLongPressTimer() {
    _longPressTimer = Timer(widget.longPressThreshold, () {
      if (_longPressPosition != null) {
        _handleLongPress(_longPressPosition!);
      }
    });
  }

  /// Cancel long press timer
  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressPosition = null;
  }

  /// Handle long press
  void _handleLongPress(Offset position) {
    HapticFeedback.mediumImpact();

    final node = _findNodeAtPosition(position);

    if (node != null) {
      widget.onNodeLongPressed?.call(node, position);
    } else {
      widget.onCanvasLongPressed?.call(position);
    }

    // Show context menu if enabled
    if (widget.enableContextMenu) {
      _showContextMenu(position, node);
    }

    // Emit gesture result
    widget.onGesture?.call(GestureResult(
      type: GestureType.longPress,
      position: position,
      node: node,
    ));
  }

  /// Show context menu
  void _showContextMenu(Offset position, Node? node) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final globalPosition = renderBox.localToGlobal(position);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: _buildContextMenuItems(node),
    );
  }

  /// Build context menu items
  List<PopupMenuEntry<String>> _buildContextMenuItems(Node? node) {
    if (node != null) {
      return [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('Duplicate'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'addChild',
          child: ListTile(
            leading: Icon(Icons.add_circle_outline),
            title: Text('Add Child'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'addSibling',
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('Add Sibling'),
            dense: true,
          ),
        ),
      ];
    } else {
      return [
        const PopupMenuItem(
          value: 'addNode',
          child: ListTile(
            leading: Icon(Icons.add_circle),
            title: Text('Add Node'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'paste',
          child: ListTile(
            leading: Icon(Icons.paste),
            title: Text('Paste'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'zoomToFit',
          child: ListTile(
            leading: Icon(Icons.zoom_out_map),
            title: Text('Zoom to Fit'),
            dense: true,
          ),
        ),
      ];
    }
  }

  /// Handle pan start
  void _handlePanStart(DragStartDetails details) {
    _cancelLongPressTimer();

    final position = details.localPosition;
    final node = _findNodeAtPosition(position);

    if (node != null && widget.enableDragAndDrop) {
      // Start node drag
      _draggedNode = node;
      _dragStartPosition = position;
      _isDragging = false;

      // Haptic feedback for drag start
      HapticFeedback.selectionClick();
    } else {
      // Start canvas pan
      _lastPanPosition = position;
      _isPanning = true;
    }
  }

  /// Handle pan update
  void _handlePanUpdate(DragUpdateDetails details) {
    final position = details.localPosition;
    final delta = details.delta;

    if (_draggedNode != null && _dragStartPosition != null) {
      // Handle node drag
      final dragDistance = (position - _dragStartPosition!).distance;

      if (!_isDragging && dragDistance > widget.dragThreshold) {
        // Start dragging
        _isDragging = true;
        widget.onNodeDragStart?.call(_draggedNode!, _dragStartPosition!);

        // Emit gesture result
        widget.onGesture?.call(GestureResult(
          type: GestureType.drag,
          position: _dragStartPosition!,
          node: _draggedNode,
          details: {'phase': 'start'},
        ));
      }

      if (_isDragging) {
        // Update drag position
        widget.onNodeDragUpdate?.call(_draggedNode!, position, delta);

        // Update node position in state
        final canvasPosition = _screenToCanvas(position);
        final updatedNode = _draggedNode!.copyWith(
          position: Point(canvasPosition.dx, canvasPosition.dy),
        );
        ref.read(mindmapStateProvider.notifier).updateNode(updatedNode);

        // Emit gesture result
        widget.onGesture?.call(GestureResult(
          type: GestureType.drag,
          position: position,
          node: _draggedNode,
          delta: delta,
          details: {'phase': 'update'},
        ));
      }
    } else if (_isPanning && _lastPanPosition != null) {
      // Handle canvas pan
      widget.onCanvasPanned?.call(delta);

      // Emit gesture result
      widget.onGesture?.call(GestureResult(
        type: GestureType.pan,
        position: position,
        delta: delta,
      ));

      _lastPanPosition = position;
    }
  }

  /// Handle pan end
  void _handlePanEnd(DragEndDetails details) {
    if (_isDragging && _draggedNode != null) {
      // End node drag
      final velocity = details.velocity;
      widget.onNodeDragEnd?.call(_draggedNode!, Offset.zero, velocity);

      // Emit gesture result
      widget.onGesture?.call(GestureResult(
        type: GestureType.drag,
        position: Offset.zero,
        node: _draggedNode,
        velocity: velocity,
        details: {'phase': 'end'},
      ));
    }

    // Reset drag state
    _draggedNode = null;
    _dragStartPosition = null;
    _isDragging = false;
    _isPanning = false;
    _lastPanPosition = null;
  }

  /// Handle scale start
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = 1.0;
    _initialFocalPoint = details.focalPoint;
    _touchPositions.clear();
  }

  /// Handle scale update
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      // Handle zoom
      final scale = details.scale / _baseScale;
      widget.onCanvasZoomed?.call(scale, details.focalPoint);

      // Emit gesture result
      widget.onGesture?.call(GestureResult(
        type: GestureType.zoom,
        position: details.focalPoint,
        scale: scale,
      ));

      _baseScale = details.scale;
    } else if (details.pointerCount == 1) {
      // Handle single-finger pan during scale gesture
      final delta = details.focalPoint - (_initialFocalPoint ?? Offset.zero);
      widget.onCanvasPanned?.call(delta);
      _initialFocalPoint = details.focalPoint;
    }
  }

  /// Handle scale end
  void _handleScaleEnd(ScaleEndDetails details) {
    _baseScale = 1.0;
    _initialFocalPoint = null;
    _touchPositions.clear();
  }

  /// Handle pointer down for multi-touch tracking
  void _handlePointerDown(PointerDownEvent event) {
    _touchPositions[event.pointer] = event.localPosition;

    // Check for multi-select modifier
    if (event.kind == PointerDeviceKind.mouse) {
      _isMultiSelecting = HardwareKeyboard.instance.isControlPressed ||
                         HardwareKeyboard.instance.isMetaPressed;
    }
  }

  /// Handle pointer up for multi-touch tracking
  void _handlePointerUp(PointerUpEvent event) {
    _touchPositions.remove(event.pointer);

    if (_touchPositions.isEmpty) {
      _isMultiSelecting = false;
    }
  }

  /// Handle mouse hover for desktop interactions
  void _handleMouseHover(PointerHoverEvent event) {
    final node = _findNodeAtPosition(event.localPosition);
    final edge = _findEdgeAtPosition(event.localPosition);

    // Update hover states
    final document = ref.read(mindmapDataProvider);
    if (document != null) {
      for (final docNode in document.nodes) {
        final shouldHover = docNode.id == node?.id;
        if (docNode.isHovered != shouldHover) {
          ref.read(mindmapStateProvider.notifier).updateNode(
            docNode.copyWith(isHovered: shouldHover),
          );
        }
      }

      for (final docEdge in document.edges) {
        final shouldHover = docEdge.id == edge?.id;
        if (docEdge.isHovered != shouldHover) {
          ref.read(mindmapStateProvider.notifier).updateEdge(
            docEdge.copyWith(isHovered: shouldHover),
          );
        }
      }
    }

    // Emit gesture result
    widget.onGesture?.call(GestureResult(
      type: GestureType.hover,
      position: event.localPosition,
      node: node,
      edge: edge,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerHover: _handleMouseHover,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}

/// Specialized gesture detector for node interactions
class NodeGestureDetector extends StatefulWidget {
  const NodeGestureDetector({
    super.key,
    required this.node,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onHover,
    this.enableDrag = true,
    this.enableHover = true,
  });

  final Node node;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(Offset position)? onDragStart;
  final Function(Offset position, Offset delta)? onDragUpdate;
  final Function(Offset position, Velocity velocity)? onDragEnd;
  final Function(bool isHovered)? onHover;
  final bool enableDrag;
  final bool enableHover;

  @override
  State<NodeGestureDetector> createState() => _NodeGestureDetectorState();
}

class _NodeGestureDetectorState extends State<NodeGestureDetector> {
  bool _isDragging = false;
  Offset? _dragStartPosition;

  void _handleTap() {
    widget.onTap?.call();
  }

  void _handleDoubleTap() {
    widget.onDoubleTap?.call();
  }

  void _handleLongPress() {
    widget.onLongPress?.call();
    HapticFeedback.mediumImpact();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enableDrag) return;

    _dragStartPosition = details.localPosition;
    widget.onDragStart?.call(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enableDrag || _dragStartPosition == null) return;

    if (!_isDragging) {
      final distance = (details.localPosition - _dragStartPosition!).distance;
      if (distance > 10.0) {
        _isDragging = true;
        HapticFeedback.selectionClick();
      }
    }

    if (_isDragging) {
      widget.onDragUpdate?.call(details.localPosition, details.delta);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enableDrag) return;

    if (_isDragging) {
      widget.onDragEnd?.call(Offset.zero, details.velocity);
    }

    _isDragging = false;
    _dragStartPosition = null;
  }

  void _handleHover(bool isHovered) {
    if (!widget.enableHover) return;

    widget.onHover?.call(isHovered);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onLongPress: _handleLongPress,
        onPanStart: widget.enableDrag ? _handlePanStart : null,
        onPanUpdate: widget.enableDrag ? _handlePanUpdate : null,
        onPanEnd: widget.enableDrag ? _handlePanEnd : null,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      ),
    );
  }
}

/// Utility class for gesture configuration and management
class GestureConfiguration {
  const GestureConfiguration({
    this.enableDragAndDrop = true,
    this.enableMultiSelect = true,
    this.enableContextMenu = true,
    this.enableHover = true,
    this.dragThreshold = 10.0,
    this.longPressThreshold = const Duration(milliseconds: 500),
    this.doubleTapThreshold = const Duration(milliseconds: 300),
    this.hoverDelay = const Duration(milliseconds: 200),
  });

  final bool enableDragAndDrop;
  final bool enableMultiSelect;
  final bool enableContextMenu;
  final bool enableHover;
  final double dragThreshold;
  final Duration longPressThreshold;
  final Duration doubleTapThreshold;
  final Duration hoverDelay;

  /// Create configuration for touch devices
  factory GestureConfiguration.forTouch() {
    return const GestureConfiguration(
      enableHover: false,
      dragThreshold: 15.0,
      longPressThreshold: Duration(milliseconds: 600),
    );
  }

  /// Create configuration for desktop/mouse devices
  factory GestureConfiguration.forDesktop() {
    return const GestureConfiguration(
      enableHover: true,
      dragThreshold: 8.0,
      longPressThreshold: Duration(milliseconds: 400),
    );
  }

  /// Create configuration for accessibility
  factory GestureConfiguration.forAccessibility() {
    return const GestureConfiguration(
      dragThreshold: 20.0,
      longPressThreshold: Duration(milliseconds: 800),
      doubleTapThreshold: Duration(milliseconds: 500),
    );
  }
}