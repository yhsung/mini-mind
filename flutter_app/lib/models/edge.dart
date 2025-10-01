/// Edge data model for Flutter UI layer
///
/// This file defines the Dart equivalent of the Rust Edge model,
/// representing connections between nodes in the mindmap.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'node.dart';
import '../utils/color_converter.dart';

part 'edge.g.dart';

/// Edge model representing connections between nodes
@JsonSerializable()
@immutable
class Edge {
  const Edge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.createdAt,
    required this.updatedAt,
    this.label,
    this.metadata = const {},
    this.style = const EdgeStyle(),
    this.isVisible = true,
    this.isSelected = false,
    this.isHovered = false,
    this.isAnimating = false,
    this.weight = 1.0,
  });

  /// Unique identifier for the edge
  final String id;

  /// Source node ID
  final String sourceId;

  /// Target node ID
  final String targetId;

  /// Optional label for the edge
  final String? label;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last updated timestamp
  final DateTime updatedAt;

  /// Additional metadata
  final Map<String, String> metadata;

  /// Visual styling for the edge
  final EdgeStyle style;

  /// Visibility state
  final bool isVisible;

  /// Selection state (for UI interactions)
  final bool isSelected;

  /// Hover state (for mouse interactions)
  final bool isHovered;

  /// Animation state
  final bool isAnimating;

  /// Edge weight (for layout algorithms)
  final double weight;

  /// Check if edge has a label
  bool get hasLabel => label != null && label!.isNotEmpty;

  /// Check if edge has metadata
  bool get hasMetadata => metadata.isNotEmpty;

  /// Get display label with fallback
  String get displayLabel => label ?? '';

  /// Get creation date as formatted string
  String get createdDateString => _formatDate(createdAt);

  /// Get updated date as formatted string
  String get updatedDateString => _formatDate(updatedAt);

  /// Check if edge was recently created (within last hour)
  bool get isRecentlyCreated =>
      DateTime.now().difference(createdAt).inHours < 1;

  /// Check if edge was recently updated (within last hour)
  bool get isRecentlyUpdated =>
      DateTime.now().difference(updatedAt).inHours < 1;

  /// Get age of the edge
  Duration get age => DateTime.now().difference(createdAt);

  /// Get time since last update
  Duration get timeSinceUpdate => DateTime.now().difference(updatedAt);

  /// Check if edge is in an interactive state
  bool get isInteractive => isSelected || isHovered || isAnimating;

  /// Check if edge connects the given nodes (in either direction)
  bool connects(String nodeId1, String nodeId2) {
    return (sourceId == nodeId1 && targetId == nodeId2) ||
           (sourceId == nodeId2 && targetId == nodeId1);
  }

  /// Check if edge connects to a specific node
  bool connectsTo(String nodeId) {
    return sourceId == nodeId || targetId == nodeId;
  }

  /// Get the other end of the edge given one node ID
  String? otherEnd(String nodeId) {
    if (sourceId == nodeId) return targetId;
    if (targetId == nodeId) return sourceId;
    return null;
  }

  /// Copy with updated fields
  Edge copyWith({
    String? id,
    String? sourceId,
    String? targetId,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? metadata,
    EdgeStyle? style,
    bool? isVisible,
    bool? isSelected,
    bool? isHovered,
    bool? isAnimating,
    double? weight,
  }) {
    return Edge(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      style: style ?? this.style,
      isVisible: isVisible ?? this.isVisible,
      isSelected: isSelected ?? this.isSelected,
      isHovered: isHovered ?? this.isHovered,
      isAnimating: isAnimating ?? this.isAnimating,
      weight: weight ?? this.weight,
    );
  }

  /// Copy with updated label
  Edge updateLabel(String? newLabel) {
    return copyWith(
      label: newLabel,
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with updated metadata
  Edge updateMetadata(String key, String value) {
    return copyWith(
      metadata: {...metadata, key: value},
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with removed metadata
  Edge removeMetadata(String key) {
    final newMetadata = Map<String, String>.from(metadata);
    newMetadata.remove(key);
    return copyWith(
      metadata: newMetadata,
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with updated weight
  Edge updateWeight(double newWeight) {
    return copyWith(
      weight: newWeight.clamp(0.0, 10.0),
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with selection state
  Edge select() => copyWith(isSelected: true);
  Edge deselect() => copyWith(isSelected: false);

  /// Copy with hover state
  Edge hover() => copyWith(isHovered: true);
  Edge unhover() => copyWith(isHovered: false);

  /// Copy with animation state
  Edge startAnimation() => copyWith(isAnimating: true);
  Edge stopAnimation() => copyWith(isAnimating: false);

  /// Copy with visibility state
  Edge show() => copyWith(isVisible: true);
  Edge hide() => copyWith(isVisible: false);

  /// JSON serialization
  factory Edge.fromJson(Map<String, dynamic> json) => _$EdgeFromJson(json);
  Map<String, dynamic> toJson() => _$EdgeToJson(this);

  /// Create a new edge with default values
  factory Edge.create({
    required String sourceId,
    required String targetId,
    String? label,
    Map<String, String>? metadata,
    EdgeStyle? style,
    double? weight,
  }) {
    final now = DateTime.now();
    return Edge(
      id: 'edge_${now.millisecondsSinceEpoch}',
      sourceId: sourceId,
      targetId: targetId,
      label: label,
      createdAt: now,
      updatedAt: now,
      metadata: metadata ?? {},
      style: style ?? const EdgeStyle(),
      weight: weight ?? 1.0,
    );
  }

  /// Create a parent-child edge
  factory Edge.createParentChild({
    required String parentId,
    required String childId,
    EdgeStyle? style,
  }) {
    return Edge.create(
      sourceId: parentId,
      targetId: childId,
      style: style ?? const EdgeStyle(
        type: EdgeType.parentChild,
        color: Colors.grey,
        width: 2.0,
      ),
    );
  }

  /// Create an association edge
  factory Edge.createAssociation({
    required String sourceId,
    required String targetId,
    String? label,
    EdgeStyle? style,
  }) {
    return Edge.create(
      sourceId: sourceId,
      targetId: targetId,
      label: label,
      style: style ?? const EdgeStyle(
        type: EdgeType.association,
        color: Colors.blue,
        width: 1.5,
        strokeType: StrokeType.dashed,
      ),
    );
  }

  /// Calculate the path between two nodes
  EdgePath calculatePath(Node sourceNode, Node targetNode) {
    return EdgePath.calculate(
      sourceNode: sourceNode,
      targetNode: targetNode,
      style: style,
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  String toString() {
    return 'Edge('
        'id: $id, '
        'source: $sourceId, '
        'target: $targetId, '
        'label: "$label", '
        'selected: $isSelected'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Edge && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Edge visual style configuration
@JsonSerializable()
@immutable
class EdgeStyle {
  const EdgeStyle({
    this.type = EdgeType.straight,
    this.color = Colors.grey,
    this.width = 1.5,
    this.strokeType = StrokeType.solid,
    this.opacity = 1.0,
    this.arrowType = ArrowType.none,
    this.curvature = 0.0,
    this.animated = false,
    this.animationSpeed = 1.0,
    this.labelStyle = const EdgeLabelStyle(),
  });

  final EdgeType type;
  @ColorConverter()
  final Color color;
  final double width;
  final StrokeType strokeType;
  final double opacity;
  final ArrowType arrowType;
  final double curvature; // 0.0 = straight, 1.0 = very curved
  final bool animated;
  final double animationSpeed;
  final EdgeLabelStyle labelStyle;

  /// Copy with updated fields
  EdgeStyle copyWith({
    EdgeType? type,
    Color? color,
    double? width,
    StrokeType? strokeType,
    double? opacity,
    ArrowType? arrowType,
    double? curvature,
    bool? animated,
    double? animationSpeed,
    EdgeLabelStyle? labelStyle,
  }) {
    return EdgeStyle(
      type: type ?? this.type,
      color: color ?? this.color,
      width: width ?? this.width,
      strokeType: strokeType ?? this.strokeType,
      opacity: opacity ?? this.opacity,
      arrowType: arrowType ?? this.arrowType,
      curvature: curvature ?? this.curvature,
      animated: animated ?? this.animated,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      labelStyle: labelStyle ?? this.labelStyle,
    );
  }

  /// Create style for selected state
  EdgeStyle asSelected() {
    return copyWith(
      color: Colors.blue,
      width: width + 1.0,
    );
  }

  /// Create style for hovered state
  EdgeStyle asHovered() {
    return copyWith(
      color: color.withOpacity(0.8),
      width: width + 0.5,
    );
  }

  /// Create style for disabled state
  EdgeStyle asDisabled() {
    return copyWith(
      opacity: 0.3,
      color: Colors.grey,
    );
  }

  /// JSON serialization
  factory EdgeStyle.fromJson(Map<String, dynamic> json) => _$EdgeStyleFromJson(json);
  Map<String, dynamic> toJson() => _$EdgeStyleToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeStyle &&
          type == other.type &&
          color == other.color &&
          width == other.width &&
          strokeType == other.strokeType &&
          opacity == other.opacity &&
          arrowType == other.arrowType &&
          curvature == other.curvature &&
          animated == other.animated &&
          animationSpeed == other.animationSpeed &&
          labelStyle == other.labelStyle;

  @override
  int get hashCode => Object.hash(
        type,
        color,
        width,
        strokeType,
        opacity,
        arrowType,
        curvature,
        animated,
        animationSpeed,
        labelStyle,
      );
}

/// Edge label style configuration
@JsonSerializable()
@immutable
class EdgeLabelStyle {
  const EdgeLabelStyle({
    this.fontSize = 12.0,
    this.fontWeight = FontWeight.normal,
    this.color = Colors.black,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(4.0),
    this.borderRadius = 4.0,
    this.position = 0.5, // 0.0 = at source, 1.0 = at target, 0.5 = center
    this.rotation = 0.0, // Rotation in radians
    this.visible = true,
  });

  final double fontSize;
  @FontWeightConverter()
  final FontWeight fontWeight;
  @ColorConverter()
  final Color color;
  @ColorConverter()
  final Color backgroundColor;
  @EdgeInsetsConverter()
  final EdgeInsets padding;
  final double borderRadius;
  final double position; // Position along the edge (0.0 to 1.0)
  final double rotation; // Label rotation in radians
  final bool visible;

  EdgeLabelStyle copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    Color? backgroundColor,
    EdgeInsets? padding,
    double? borderRadius,
    double? position,
    double? rotation,
    bool? visible,
  }) {
    return EdgeLabelStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      visible: visible ?? this.visible,
    );
  }

  factory EdgeLabelStyle.fromJson(Map<String, dynamic> json) => _$EdgeLabelStyleFromJson(json);
  Map<String, dynamic> toJson() => _$EdgeLabelStyleToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeLabelStyle &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          color == other.color &&
          backgroundColor == other.backgroundColor &&
          padding == other.padding &&
          borderRadius == other.borderRadius &&
          position == other.position &&
          rotation == other.rotation &&
          visible == other.visible;

  @override
  int get hashCode => Object.hash(
        fontSize,
        fontWeight,
        color,
        backgroundColor,
        padding,
        borderRadius,
        position,
        rotation,
        visible,
      );
}

/// Edge type enumeration
enum EdgeType {
  straight,
  curved,
  bezier,
  orthogonal,
  parentChild,
  association,
  dependency,
}

/// Stroke type enumeration
enum StrokeType {
  solid,
  dashed,
  dotted,
}

/// Arrow type enumeration
enum ArrowType {
  none,
  target,
  source,
  both,
  diamond,
  circle,
}

/// Edge path calculation utility
class EdgePath {
  const EdgePath({
    required this.points,
    required this.controlPoints,
    required this.labelPosition,
    required this.labelRotation,
  });

  final List<Point> points;
  final List<Point> controlPoints;
  final Point labelPosition;
  final double labelRotation;

  /// Calculate path between two nodes
  static EdgePath calculate({
    required Node sourceNode,
    required Node targetNode,
    required EdgeStyle style,
  }) {
    final sourceCenter = sourceNode.center;
    final targetCenter = targetNode.center;

    switch (style.type) {
      case EdgeType.straight:
        return _calculateStraightPath(sourceCenter, targetCenter, style);
      case EdgeType.curved:
        return _calculateCurvedPath(sourceCenter, targetCenter, style);
      case EdgeType.bezier:
        return _calculateBezierPath(sourceCenter, targetCenter, style);
      case EdgeType.orthogonal:
        return _calculateOrthogonalPath(sourceCenter, targetCenter, style);
      default:
        return _calculateStraightPath(sourceCenter, targetCenter, style);
    }
  }

  static EdgePath _calculateStraightPath(Point source, Point target, EdgeStyle style) {
    final labelPos = source.lerp(target, style.labelStyle.position);
    final angle = (target - source).atan2();

    return EdgePath(
      points: [source, target],
      controlPoints: [],
      labelPosition: labelPos,
      labelRotation: angle,
    );
  }

  static EdgePath _calculateCurvedPath(Point source, Point target, EdgeStyle style) {
    final midPoint = source.lerp(target, 0.5);
    final perpendicular = Point(
      -(target.y - source.y) * style.curvature * 0.2,
      (target.x - source.x) * style.curvature * 0.2,
    );
    final curvePoint = midPoint + perpendicular;

    final labelPos = source.lerp(target, style.labelStyle.position);
    final angle = (target - source).atan2();

    return EdgePath(
      points: [source, curvePoint, target],
      controlPoints: [curvePoint],
      labelPosition: labelPos,
      labelRotation: angle,
    );
  }

  static EdgePath _calculateBezierPath(Point source, Point target, EdgeStyle style) {
    final dx = (target.x - source.x) * 0.3;
    final control1 = Point(source.x + dx, source.y);
    final control2 = Point(target.x - dx, target.y);

    final labelPos = source.lerp(target, style.labelStyle.position);
    final angle = (target - source).atan2();

    return EdgePath(
      points: [source, target],
      controlPoints: [control1, control2],
      labelPosition: labelPos,
      labelRotation: angle,
    );
  }

  static EdgePath _calculateOrthogonalPath(Point source, Point target, EdgeStyle style) {
    final midX = (source.x + target.x) / 2;
    final corner1 = Point(midX, source.y);
    final corner2 = Point(midX, target.y);

    final labelPos = source.lerp(target, style.labelStyle.position);

    return EdgePath(
      points: [source, corner1, corner2, target],
      controlPoints: [],
      labelPosition: labelPos,
      labelRotation: 0.0, // Keep labels horizontal for orthogonal edges
    );
  }
}

/// Extension methods for edge operations
extension EdgeExtensions on Edge {
  /// Check if point is near the edge path
  bool isPointNear(Point point, EdgePath path, double tolerance) {
    // Simplified distance check - in a real implementation,
    // this would calculate distance to the actual path
    for (int i = 0; i < path.points.length - 1; i++) {
      final segmentStart = path.points[i];
      final segmentEnd = path.points[i + 1];
      final distance = _distanceToLineSegment(point, segmentStart, segmentEnd);
      if (distance <= tolerance) return true;
    }
    return false;
  }

  double _distanceToLineSegment(Point point, Point start, Point end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final length = math.sqrt(dx * dx + dy * dy);

    if (length == 0) return point.distanceTo(start);

    final t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / (length * length);
    final clampedT = t.clamp(0.0, 1.0);

    final projection = Point(
      start.x + clampedT * dx,
      start.y + clampedT * dy,
    );

    return point.distanceTo(projection);
  }
}

/// Edge collection utilities
extension EdgeListExtensions on List<Edge> {
  /// Find edge by ID
  Edge? findById(String id) {
    try {
      return firstWhere((edge) => edge.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Find edges connected to a node
  List<Edge> connectedTo(String nodeId) {
    return where((edge) => edge.connectsTo(nodeId)).toList();
  }

  /// Find edges between two nodes
  List<Edge> between(String nodeId1, String nodeId2) {
    return where((edge) => edge.connects(nodeId1, nodeId2)).toList();
  }

  /// Find outgoing edges from a node
  List<Edge> outgoingFrom(String nodeId) {
    return where((edge) => edge.sourceId == nodeId).toList();
  }

  /// Find incoming edges to a node
  List<Edge> incomingTo(String nodeId) {
    return where((edge) => edge.targetId == nodeId).toList();
  }

  /// Filter selected edges
  List<Edge> get selected => where((edge) => edge.isSelected).toList();

  /// Filter visible edges
  List<Edge> get visible => where((edge) => edge.isVisible).toList();

  /// Filter by edge type
  List<Edge> ofType(EdgeType type) {
    return where((edge) => edge.style.type == type).toList();
  }

  /// Sort by creation date
  List<Edge> sortedByCreation() {
    final sorted = List<Edge>.from(this);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Sort by weight
  List<Edge> sortedByWeight() {
    final sorted = List<Edge>.from(this);
    sorted.sort((a, b) => b.weight.compareTo(a.weight));
    return sorted;
  }
}

/// Point extension for angle calculation
extension PointAngles on Point {
  double atan2() => math.atan2(y, x);
}