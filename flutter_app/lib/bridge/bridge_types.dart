/// Bridge type definitions for Flutter-Rust FFI communication
///
/// This file defines Dart equivalents of Rust FFI types and provides
/// conversion utilities for seamless data exchange between Flutter UI
/// and the Rust core engine.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import '../models/node.dart';
import '../models/edge.dart';
import '../models/document.dart';

part 'bridge_types.g.dart';

/// File formats supported for import/export
enum FileFormat {
  json,
  opml,
  markdown,
  xml,
  pdf,
  svg,
  png,
  html,
}

/// Node update types for FFI operations
@JsonSerializable()
class FfiNodeUpdate {
  const FfiNodeUpdate({
    required this.type,
    this.text,
    this.position,
    this.tags,
  });

  final String type;
  final String? text;
  final FfiPoint? position;
  final List<String>? tags;

  factory FfiNodeUpdate.text(String text) => FfiNodeUpdate(
    type: 'text',
    text: text,
  );

  factory FfiNodeUpdate.position(FfiPoint position) => FfiNodeUpdate(
    type: 'position',
    position: position,
  );

  factory FfiNodeUpdate.tags(List<String> tags) => FfiNodeUpdate(
    type: 'tags',
    tags: tags,
  );

  factory FfiNodeUpdate.fromJson(Map<String, dynamic> json) =>
      _$FfiNodeUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$FfiNodeUpdateToJson(this);
}

/// Mindmap data structure for FFI operations
@JsonSerializable()
class FfiMindmapData {
  const FfiMindmapData({
    required this.title,
    required this.rootNodeId,
    required this.nodes,
    required this.edges,
    this.metadata = const {},
  });

  final String title;
  final String rootNodeId;
  final List<FfiNodeData> nodes;
  final List<FfiEdgeData> edges;
  final Map<String, String> metadata;

  factory FfiMindmapData.fromJson(Map<String, dynamic> json) =>
      _$FfiMindmapDataFromJson(json);

  Map<String, dynamic> toJson() => _$FfiMindmapDataToJson(this);
}

/// File operation result for FFI operations
@JsonSerializable()
class FileOperationResult {
  const FileOperationResult({
    required this.success,
    this.filePath,
    this.error,
    this.data,
    this.format,
  });

  final bool success;
  final String? filePath;
  final String? error;
  final String? data;
  final FileFormat? format;

  factory FileOperationResult.fromJson(Map<String, dynamic> json) =>
      _$FileOperationResultFromJson(json);

  Map<String, dynamic> toJson() => _$FileOperationResultToJson(this);
}

/// File operation options for FFI operations
@JsonSerializable()
class FileOperationOptions {
  const FileOperationOptions({
    this.format,
    this.compress = false,
    this.includeMetadata = true,
  });

  final FileFormat? format;
  final bool compress;
  final bool includeMetadata;

  factory FileOperationOptions.fromJson(Map<String, dynamic> json) =>
      _$FileOperationOptionsFromJson(json);

  Map<String, dynamic> toJson() => _$FileOperationOptionsToJson(this);
}

/// Node types for classification
enum NodeType {
  root,
  branch,
  leaf,
}

/// FFI-compatible error types that match Rust BridgeError enum
enum BridgeErrorType {
  nodeNotFound,
  edgeNotFound,
  documentNotFound,
  invalidOperation,
  fileSystemError,
  serializationError,
  layoutComputationError,
  searchError,
  genericError,
}

/// Bridge error class for error handling across FFI boundary
@JsonSerializable()
class BridgeError implements Exception {
  const BridgeError({
    required this.type,
    required this.message,
    this.id,
  });

  final BridgeErrorType type;
  final String message;
  final String? id;

  factory BridgeError.fromJson(Map<String, dynamic> json) =>
      _$BridgeErrorFromJson(json);

  Map<String, dynamic> toJson() => _$BridgeErrorToJson(this);

  @override
  String toString() => 'BridgeError(${type.name}): $message';

  /// Create node not found error
  factory BridgeError.nodeNotFound(String id) => BridgeError(
        type: BridgeErrorType.nodeNotFound,
        message: 'Node with ID $id was not found',
        id: id,
      );

  /// Create document not found error
  factory BridgeError.documentNotFound(String id) => BridgeError(
        type: BridgeErrorType.documentNotFound,
        message: 'Document with ID $id was not found',
        id: id,
      );

  /// Create invalid operation error
  factory BridgeError.invalidOperation(String message) => BridgeError(
        type: BridgeErrorType.invalidOperation,
        message: message,
      );

  /// Create file system error
  factory BridgeError.fileSystemError(String message) => BridgeError(
        type: BridgeErrorType.fileSystemError,
        message: message,
      );
}

/// FFI-compatible layout types
enum FfiLayoutType {
  radial,
  tree,
  forceDirected,
}

extension FfiLayoutTypeExtension on FfiLayoutType {
  String get displayName {
    switch (this) {
      case FfiLayoutType.radial:
        return 'Radial Layout';
      case FfiLayoutType.tree:
        return 'Tree Layout';
      case FfiLayoutType.forceDirected:
        return 'Force-Directed Layout';
    }
  }
}

/// FFI-compatible export format types
enum ExportFormat {
  pdf,
  svg,
  png,
  opml,
  markdown,
}

extension ExportFormatExtension on ExportFormat {
  String get displayName {
    switch (this) {
      case ExportFormat.pdf:
        return 'PDF Document';
      case ExportFormat.svg:
        return 'SVG Vector';
      case ExportFormat.png:
        return 'PNG Image';
      case ExportFormat.opml:
        return 'OPML Outline';
      case ExportFormat.markdown:
        return 'Markdown Text';
    }
  }
}

/// FFI-compatible point structure
@JsonSerializable()
class FfiPoint {
  const FfiPoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  factory FfiPoint.fromJson(Map<String, dynamic> json) => _$FfiPointFromJson(json);
  Map<String, dynamic> toJson() => _$FfiPointToJson(this);

  @override
  String toString() => 'FfiPoint($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// FFI-compatible size structure
@JsonSerializable()
class FfiSize {
  const FfiSize({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  factory FfiSize.fromJson(Map<String, dynamic> json) => _$FfiSizeFromJson(json);
  Map<String, dynamic> toJson() => _$FfiSizeToJson(this);

  @override
  String toString() => 'FfiSize($width, $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// FFI-compatible rectangle structure
@JsonSerializable()
class FfiRect {
  const FfiRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;
  FfiPoint get center => FfiPoint(x + width / 2, y + height / 2);

  factory FfiRect.fromJson(Map<String, dynamic> json) => _$FfiRectFromJson(json);
  Map<String, dynamic> toJson() => _$FfiRectToJson(this);

  @override
  String toString() => 'FfiRect($x, $y, $width, $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiRect && x == other.x && y == other.y &&
      width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// FFI-compatible node data structure
@JsonSerializable()
class FfiNodeData {
  const FfiNodeData({
    required this.id,
    required this.text,
    required this.position,
    required this.size,
    this.parentId,
    this.metadata = const {},
    this.tags = const [],
    this.nodeType = NodeType.branch,
    DateTime? createdDate,
    DateTime? updatedDate,
  }) : createdDate = createdDate ?? DateTime.now(),
       updatedDate = updatedDate ?? DateTime.now();

  final String id;
  final String text;
  final FfiPoint position;
  final FfiSize size;
  final String? parentId;
  final Map<String, String> metadata;
  final List<String> tags;
  final NodeType nodeType;
  final DateTime createdDate;
  final DateTime updatedDate;

  factory FfiNodeData.fromJson(Map<String, dynamic> json) => _$FfiNodeDataFromJson(json);
  Map<String, dynamic> toJson() => _$FfiNodeDataToJson(this);

  @override
  String toString() => 'FfiNodeData($id: "$text")';
}

/// FFI-compatible edge data structure
@JsonSerializable()
class FfiEdgeData {
  const FfiEdgeData({
    required this.id,
    required this.sourceId,
    required this.targetId,
    this.label,
    this.weight = 1.0,
    this.metadata = const {},
  });

  final String id;
  final String sourceId;
  final String targetId;
  final String? label;
  final double weight;
  final Map<String, String> metadata;

  factory FfiEdgeData.fromJson(Map<String, dynamic> json) => _$FfiEdgeDataFromJson(json);
  Map<String, dynamic> toJson() => _$FfiEdgeDataToJson(this);

  @override
  String toString() => 'FfiEdgeData($id: $sourceId -> $targetId)';
}

/// FFI-compatible layout result
@JsonSerializable()
class FfiLayoutResult {
  const FfiLayoutResult({
    required this.layoutType,
    required this.nodes,
    required this.computationTime,
    this.nodePositions = const {},
  });

  final FfiLayoutType layoutType;
  final List<FfiNodeData> nodes;
  final int computationTime; // Duration in milliseconds
  final Map<String, FfiPoint> nodePositions;

  Duration get computationTimeDuration => Duration(milliseconds: computationTime);
  int get computationTimeMs => computationTime;

  factory FfiLayoutResult.fromJson(Map<String, dynamic> json) => _$FfiLayoutResultFromJson(json);
  Map<String, dynamic> toJson() => _$FfiLayoutResultToJson(this);

  @override
  String toString() => 'FfiLayoutResult(${layoutType.name}: ${nodes.length} nodes, ${computationTime}ms)';
}

/// FFI-compatible search result
@JsonSerializable()
class FfiSearchResult {
  const FfiSearchResult({
    required this.nodeId,
    required this.text,
    required this.score,
    this.snippet,
  });

  final String nodeId;
  final String text;
  final double score;
  final String? snippet;

  factory FfiSearchResult.fromJson(Map<String, dynamic> json) => _$FfiSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$FfiSearchResultToJson(this);

  @override
  String toString() => 'FfiSearchResult($nodeId: $score)';
}

/// Extension methods for converting between Dart models and FFI types
extension NodeToFfi on Node {
  /// Convert Dart Node to FFI NodeData
  FfiNodeData toFfi() {
    return FfiNodeData(
      id: id,
      text: text,
      position: FfiPoint(x: position.x, y: position.y),
      size: FfiSize(width: size.width, height: size.height),
      parentId: parentId,
      metadata: metadata,
    );
  }
}

extension EdgeToFfi on Edge {
  /// Convert Dart Edge to FFI EdgeData
  FfiEdgeData toFfi() {
    return FfiEdgeData(
      id: id,
      sourceId: sourceId,
      targetId: targetId,
      label: label,
      weight: weight,
      metadata: metadata,
    );
  }
}

extension FfiNodeToModel on FfiNodeData {
  /// Convert FFI NodeData to Dart Node
  Node toModel() {
    final now = DateTime.now();
    return Node(
      id: id,
      text: text,
      position: Point(position.x, position.y),
      size: Size(size.width, size.height),
      parentId: parentId,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }
}

extension FfiEdgeToModel on FfiEdgeData {
  /// Convert FFI EdgeData to Dart Edge
  Edge toModel() {
    final now = DateTime.now();
    return Edge(
      id: id,
      sourceId: sourceId,
      targetId: targetId,
      label: label,
      weight: weight,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }
}

extension FfiPointToModel on FfiPoint {
  /// Convert FFI Point to Dart Point
  Point toModel() {
    return Point(x, y);
  }
}

extension PointToFfi on Point {
  /// Convert Dart Point to FFI Point
  FfiPoint toFfi() {
    return FfiPoint(x: x, y: y);
  }
}

extension FfiSizeToModel on FfiSize {
  /// Convert FFI Size to Dart Size
  Size toModel() {
    return Size(width, height);
  }
}

extension SizeToFfi on Size {
  /// Convert Dart Size to FFI Size
  FfiSize toFfi() {
    return FfiSize(width: width, height: height);
  }
}

extension FfiLayoutResultToModel on FfiLayoutResult {
  /// Convert FFI LayoutResult to Dart models
  List<Node> toNodeModels() {
    return nodes.map((ffiNode) => ffiNode.toModel()).toList();
  }
}

extension DocumentToFfi on Document {
  /// Convert Document to FFI-compatible data
  Map<String, dynamic> toFfiData() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'nodes': nodes.map((node) => node.toFfi().toJson()).toList(),
      'edges': edges.map((edge) => edge.toFfi().toJson()).toList(),
      'rootNodeId': rootNodeId,
      'metadata': metadata,
    };
  }
}