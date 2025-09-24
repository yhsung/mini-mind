/// Node data model for Flutter UI layer
///
/// This file defines the Dart equivalent of the Rust Node model,
/// optimized for UI operations, state management, and JSON serialization.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import '../bridge/bridge_types.dart';

part 'node.g.dart';

/// Node model for Flutter UI layer
@JsonSerializable()
@immutable
class Node {
  const Node({
    required this.id,
    required this.text,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.tags = const [],
    this.metadata = const {},
    this.style = const NodeStyle(),
    this.isVisible = true,
    this.isSelected = false,
    this.isFocused = false,
    this.isHovered = false,
    this.isEditing = false,
    this.isDragging = false,
    this.isCollapsed = false,
  });

  /// Unique identifier for the node
  final String id;

  /// Parent node ID (null for root node)
  final String? parentId;

  /// Text content of the node
  final String text;

  /// Position in the mindmap canvas
  final Point position;

  /// Tags associated with the node
  final List<String> tags;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last updated timestamp
  final DateTime updatedAt;

  /// Additional metadata
  final Map<String, String> metadata;

  /// Visual styling for the node
  final NodeStyle style;

  /// Visibility state
  final bool isVisible;

  /// Selection state (for UI interactions)
  final bool isSelected;

  /// Focus state (for keyboard navigation)
  final bool isFocused;

  /// Hover state (for mouse interactions)
  final bool isHovered;

  /// Editing state (when text is being edited)
  final bool isEditing;

  /// Dragging state (during drag operations)
  final bool isDragging;

  /// Collapsed state (children hidden)
  final bool isCollapsed;

  /// Check if this is a root node
  bool get isRoot => parentId == null;

  /// Get display text with fallback
  String get displayText => text.isEmpty ? 'Untitled' : text;

  /// Check if node has tags
  bool get hasTags => tags.isNotEmpty;

  /// Check if node has metadata
  bool get hasMetadata => metadata.isNotEmpty;

  /// Get creation date as formatted string
  String get createdDateString => _formatDate(createdAt);

  /// Get updated date as formatted string
  String get updatedDateString => _formatDate(updatedAt);

  /// Check if node was recently created (within last hour)
  bool get isRecentlyCreated =>
      DateTime.now().difference(createdAt).inHours < 1;

  /// Check if node was recently updated (within last hour)
  bool get isRecentlyUpdated =>
      DateTime.now().difference(updatedAt).inHours < 1;

  /// Get age of the node
  Duration get age => DateTime.now().difference(createdAt);

  /// Get time since last update
  Duration get timeSinceUpdate => DateTime.now().difference(updatedAt);

  /// Check if node is in an interactive state
  bool get isInteractive => isSelected || isFocused || isHovered || isEditing;

  /// Copy with updated fields
  Node copyWith({
    String? id,
    String? parentId,
    String? text,
    Point? position,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? metadata,
    NodeStyle? style,
    bool? isVisible,
    bool? isSelected,
    bool? isFocused,
    bool? isHovered,
    bool? isEditing,
    bool? isDragging,
    bool? isCollapsed,
  }) {
    return Node(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      text: text ?? this.text,
      position: position ?? this.position,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      style: style ?? this.style,
      isVisible: isVisible ?? this.isVisible,
      isSelected: isSelected ?? this.isSelected,
      isFocused: isFocused ?? this.isFocused,
      isHovered: isHovered ?? this.isHovered,
      isEditing: isEditing ?? this.isEditing,
      isDragging: isDragging ?? this.isDragging,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }

  /// Copy with updated position
  Node moveToPosition(Point newPosition) {
    return copyWith(
      position: newPosition,
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with updated text
  Node updateText(String newText) {
    return copyWith(
      text: newText,
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with added tag
  Node addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(
      tags: [...tags, tag],
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with removed tag
  Node removeTag(String tag) {
    if (!tags.contains(tag)) return this;
    return copyWith(
      tags: tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with updated metadata
  Node updateMetadata(String key, String value) {
    return copyWith(
      metadata: {...metadata, key: value},
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with removed metadata
  Node removeMetadata(String key) {
    final newMetadata = Map<String, String>.from(metadata);
    newMetadata.remove(key);
    return copyWith(
      metadata: newMetadata,
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with selection state
  Node select() => copyWith(isSelected: true);
  Node deselect() => copyWith(isSelected: false);

  /// Copy with focus state
  Node focus() => copyWith(isFocused: true);
  Node unfocus() => copyWith(isFocused: false);

  /// Copy with hover state
  Node hover() => copyWith(isHovered: true);
  Node unhover() => copyWith(isHovered: false);

  /// Copy with editing state
  Node startEditing() => copyWith(isEditing: true);
  Node stopEditing() => copyWith(isEditing: false);

  /// Copy with dragging state
  Node startDragging() => copyWith(isDragging: true);
  Node stopDragging() => copyWith(isDragging: false);

  /// Copy with collapsed state
  Node collapse() => copyWith(isCollapsed: true);
  Node expand() => copyWith(isCollapsed: false);
  Node toggleCollapsed() => copyWith(isCollapsed: !isCollapsed);

  /// JSON serialization
  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);
  Map<String, dynamic> toJson() => _$NodeToJson(this);

  /// Create from FFI data
  factory Node.fromFfi(FfiNodeData ffiData) {
    return Node(
      id: ffiData.id,
      parentId: ffiData.parentId,
      text: ffiData.text,
      position: Point(ffiData.position.x, ffiData.position.y),
      tags: List.from(ffiData.tags),
      createdAt: ffiData.createdDate,
      updatedAt: ffiData.updatedDate,
      metadata: Map.from(ffiData.metadata),
    );
  }

  /// Convert to FFI data
  FfiNodeData toFfi() {
    return FfiNodeData(
      id: id,
      parentId: parentId,
      text: text,
      position: FfiPoint(x: position.x, y: position.y),
      tags: List.from(tags),
      createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
      updatedAt: updatedAt.millisecondsSinceEpoch ~/ 1000,
      metadata: Map.from(metadata),
    );
  }

  /// Create a new node with default values
  factory Node.create({
    required String text,
    String? parentId,
    Point? position,
    List<String>? tags,
    Map<String, String>? metadata,
    NodeStyle? style,
  }) {
    final now = DateTime.now();
    return Node(
      id: 'node_${now.millisecondsSinceEpoch}',
      parentId: parentId,
      text: text,
      position: position ?? const Point(0, 0),
      tags: tags ?? [],
      createdAt: now,
      updatedAt: now,
      metadata: metadata ?? {},
      style: style ?? const NodeStyle(),
    );
  }

  /// Create a root node
  factory Node.createRoot(String text) {
    return Node.create(
      text: text,
      position: const Point(0, 0),
      style: const NodeStyle(
        shape: NodeShape.circle,
        size: NodeSize.large,
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Create a child node
  factory Node.createChild({
    required String parentId,
    required String text,
    Point? position,
    NodeStyle? style,
  }) {
    return Node.create(
      text: text,
      parentId: parentId,
      position: position,
      style: style ?? const NodeStyle(),
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
    return 'Node('
        'id: $id, '
        'text: "$text", '
        'parent: $parentId, '
        'pos: $position, '
        'selected: $isSelected'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Point class for node positions
@JsonSerializable()
@immutable
class Point {
  const Point(this.x, this.y);

  final double x;
  final double y;

  /// Zero point
  static const Point zero = Point(0, 0);

  /// Distance to another point
  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return (dx * dx + dy * dy).sqrt();
  }

  /// Add points
  Point operator +(Point other) => Point(x + other.x, y + other.y);

  /// Subtract points
  Point operator -(Point other) => Point(x - other.x, y - other.y);

  /// Multiply by scalar
  Point operator *(double scalar) => Point(x * scalar, y * scalar);

  /// Divide by scalar
  Point operator /(double scalar) => Point(x / scalar, y / scalar);

  /// Linear interpolation
  Point lerp(Point other, double t) {
    return Point(
      x + (other.x - x) * t,
      y + (other.y - y) * t,
    );
  }

  /// Convert to Offset for Flutter widgets
  Offset toOffset() => Offset(x, y);

  /// Create from Offset
  factory Point.fromOffset(Offset offset) => Point(offset.dx, offset.dy);

  /// JSON serialization
  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);
  Map<String, dynamic> toJson() => _$PointToJson(this);

  @override
  String toString() => 'Point($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Node visual style configuration
@JsonSerializable()
@immutable
class NodeStyle {
  const NodeStyle({
    this.shape = NodeShape.roundedRectangle,
    this.size = NodeSize.medium,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.grey,
    this.textColor = Colors.black,
    this.borderWidth = 1.0,
    this.borderRadius = 8.0,
    this.elevation = 2.0,
    this.fontSize = 14.0,
    this.fontWeight = FontWeight.normal,
    this.padding = const EdgeInsets.all(12.0),
    this.opacity = 1.0,
  });

  final NodeShape shape;
  final NodeSize size;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final double borderWidth;
  final double borderRadius;
  final double elevation;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsets padding;
  final double opacity;

  /// Get computed width based on size
  double get width {
    switch (size) {
      case NodeSize.small:
        return 80;
      case NodeSize.medium:
        return 120;
      case NodeSize.large:
        return 160;
      case NodeSize.extraLarge:
        return 200;
    }
  }

  /// Get computed height based on size
  double get height {
    switch (size) {
      case NodeSize.small:
        return 40;
      case NodeSize.medium:
        return 60;
      case NodeSize.large:
        return 80;
      case NodeSize.extraLarge:
        return 100;
    }
  }

  /// Copy with updated fields
  NodeStyle copyWith({
    NodeShape? shape,
    NodeSize? size,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
    double? borderWidth,
    double? borderRadius,
    double? elevation,
    double? fontSize,
    FontWeight? fontWeight,
    EdgeInsets? padding,
    double? opacity,
  }) {
    return NodeStyle(
      shape: shape ?? this.shape,
      size: size ?? this.size,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      textColor: textColor ?? this.textColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      padding: padding ?? this.padding,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Create style for selected state
  NodeStyle asSelected() {
    return copyWith(
      borderColor: Colors.blue,
      borderWidth: 2.0,
      elevation: 4.0,
    );
  }

  /// Create style for focused state
  NodeStyle asFocused() {
    return copyWith(
      borderColor: Colors.blue.shade300,
      borderWidth: 2.0,
    );
  }

  /// Create style for hovered state
  NodeStyle asHovered() {
    return copyWith(
      elevation: elevation + 2.0,
      backgroundColor: backgroundColor.withOpacity(0.9),
    );
  }

  /// Create style for dragging state
  NodeStyle asDragging() {
    return copyWith(
      opacity: 0.7,
      elevation: elevation + 4.0,
    );
  }

  /// Create style for disabled state
  NodeStyle asDisabled() {
    return copyWith(
      opacity: 0.5,
      textColor: Colors.grey,
    );
  }

  /// JSON serialization
  factory NodeStyle.fromJson(Map<String, dynamic> json) => _$NodeStyleFromJson(json);
  Map<String, dynamic> toJson() => _$NodeStyleToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeStyle &&
          shape == other.shape &&
          size == other.size &&
          backgroundColor == other.backgroundColor &&
          borderColor == other.borderColor &&
          textColor == other.textColor &&
          borderWidth == other.borderWidth &&
          borderRadius == other.borderRadius &&
          elevation == other.elevation &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          padding == other.padding &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(
        shape,
        size,
        backgroundColor,
        borderColor,
        textColor,
        borderWidth,
        borderRadius,
        elevation,
        fontSize,
        fontWeight,
        padding,
        opacity,
      );
}

/// Node shape enumeration
enum NodeShape {
  rectangle,
  roundedRectangle,
  circle,
  ellipse,
  diamond,
  hexagon,
}

/// Node size enumeration
enum NodeSize {
  small,
  medium,
  large,
  extraLarge,
}

/// Extension methods for node operations
extension NodeExtensions on Node {
  /// Check if node contains a point
  bool containsPoint(Point point) {
    final bounds = Rect.fromCenter(
      center: position.toOffset(),
      width: style.width,
      height: style.height,
    );
    return bounds.contains(point.toOffset());
  }

  /// Get bounding rectangle
  Rect get bounds {
    return Rect.fromCenter(
      center: position.toOffset(),
      width: style.width,
      height: style.height,
    );
  }

  /// Get center point
  Point get center => position;

  /// Check if overlaps with another node
  bool overlapsWith(Node other) {
    return bounds.overlaps(other.bounds);
  }

  /// Get distance to another node
  double distanceToNode(Node other) {
    return position.distanceTo(other.position);
  }

  /// Check if within distance of another node
  bool isNear(Node other, double maxDistance) {
    return distanceToNode(other) <= maxDistance;
  }
}

/// Node collection utilities
extension NodeListExtensions on List<Node> {
  /// Find node by ID
  Node? findById(String id) {
    try {
      return firstWhere((node) => node.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Filter by parent ID
  List<Node> childrenOf(String? parentId) {
    return where((node) => node.parentId == parentId).toList();
  }

  /// Filter by tag
  List<Node> withTag(String tag) {
    return where((node) => node.tags.contains(tag)).toList();
  }

  /// Filter selected nodes
  List<Node> get selected => where((node) => node.isSelected).toList();

  /// Filter visible nodes
  List<Node> get visible => where((node) => node.isVisible).toList();

  /// Get root nodes
  List<Node> get roots => where((node) => node.isRoot).toList();

  /// Sort by creation date
  List<Node> sortedByCreation() {
    final sorted = List<Node>.from(this);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Sort by update date
  List<Node> sortedByUpdate() {
    final sorted = List<Node>.from(this);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// Get nodes within bounds
  List<Node> withinBounds(Rect bounds) {
    return where((node) => bounds.overlaps(node.bounds)).toList();
  }

  /// Get nodes near point
  List<Node> nearPoint(Point point, double maxDistance) {
    return where((node) => node.position.distanceTo(point) <= maxDistance).toList();
  }
}