/// Bridge type definitions for Flutter-Rust FFI communication
///
/// This file defines Dart equivalents of Rust FFI types and provides
/// conversion utilities for seamless data exchange between Flutter UI
/// and the Rust core engine.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'bridge_types.g.dart';

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

/// FFI-compatible export format types
enum ExportFormat {
  pdf,
  svg,
  png,
  opml,
  markdown,
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

  factory FfiPoint.fromJson(Map<String, dynamic> json) =>
      _$FfiPointFromJson(json);

  Map<String, dynamic> toJson() => _$FfiPointToJson(this);

  factory FfiPoint.zero() => const FfiPoint(x: 0.0, y: 0.0);

  FfiPoint operator +(FfiPoint other) => FfiPoint(
        x: x + other.x,
        y: y + other.y,
      );

  FfiPoint operator -(FfiPoint other) => FfiPoint(
        x: x - other.x,
        y: y - other.y,
      );

  FfiPoint operator *(double scalar) => FfiPoint(
        x: x * scalar,
        y: y * scalar,
      );

  double distanceTo(FfiPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return (dx * dx + dy * dy).sqrt();
  }

  @override
  String toString() => 'FfiPoint($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// FFI-compatible node data structure
@JsonSerializable()
class FfiNodeData {
  const FfiNodeData({
    required this.id,
    required this.text,
    required this.position,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
    this.parentId,
  });

  final String id;
  final String? parentId;
  final String text;
  final FfiPoint position;
  final List<String> tags;
  final int createdAt; // Unix timestamp
  final int updatedAt; // Unix timestamp
  final Map<String, String> metadata;

  factory FfiNodeData.fromJson(Map<String, dynamic> json) =>
      _$FfiNodeDataFromJson(json);

  Map<String, dynamic> toJson() => _$FfiNodeDataToJson(this);

  /// Create a copy with updated fields
  FfiNodeData copyWith({
    String? id,
    String? parentId,
    String? text,
    FfiPoint? position,
    List<String>? tags,
    int? createdAt,
    int? updatedAt,
    Map<String, String>? metadata,
  }) {
    return FfiNodeData(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      text: text ?? this.text,
      position: position ?? this.position,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get creation date as DateTime
  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  /// Get updated date as DateTime
  DateTime get updatedDate => DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000);

  @override
  String toString() => 'FfiNodeData(id: $id, text: "$text")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiNodeData && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// FFI-compatible layout result data structure
@JsonSerializable()
class FfiLayoutResult {
  const FfiLayoutResult({
    required this.nodePositions,
    required this.layoutType,
    required this.computationTimeMs,
  });

  final Map<String, FfiPoint> nodePositions;
  final FfiLayoutType layoutType;
  final int computationTimeMs;

  factory FfiLayoutResult.fromJson(Map<String, dynamic> json) =>
      _$FfiLayoutResultFromJson(json);

  Map<String, dynamic> toJson() => _$FfiLayoutResultToJson(this);

  /// Get computation time as Duration
  Duration get computationTime => Duration(milliseconds: computationTimeMs);

  @override
  String toString() =>
      'FfiLayoutResult(${layoutType.name}, ${nodePositions.length} nodes, ${computationTimeMs}ms)';
}

/// FFI-compatible search result data structure
@JsonSerializable()
class FfiSearchResult {
  const FfiSearchResult({
    required this.nodeId,
    required this.text,
    required this.score,
    required this.matchPositions,
  });

  final String nodeId;
  final String text;
  final double score;
  final List<MatchPosition> matchPositions;

  factory FfiSearchResult.fromJson(Map<String, dynamic> json) =>
      _$FfiSearchResultFromJson(json);

  Map<String, dynamic> toJson() => _$FfiSearchResultToJson(this);

  @override
  String toString() => 'FfiSearchResult(nodeId: $nodeId, score: $score)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiSearchResult && nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// Match position for search results
@JsonSerializable()
class MatchPosition {
  const MatchPosition({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;

  factory MatchPosition.fromJson(Map<String, dynamic> json) =>
      _$MatchPositionFromJson(json);

  Map<String, dynamic> toJson() => _$MatchPositionToJson(this);

  int get length => end - start;

  @override
  String toString() => 'MatchPosition($start, $end)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchPosition && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// FFI-compatible mindmap data structure
@JsonSerializable()
class FfiMindmapData {
  const FfiMindmapData({
    required this.id,
    required this.title,
    required this.rootNodeId,
    required this.nodes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String rootNodeId;
  final List<FfiNodeData> nodes;
  final int createdAt; // Unix timestamp
  final int updatedAt; // Unix timestamp

  factory FfiMindmapData.fromJson(Map<String, dynamic> json) =>
      _$FfiMindmapDataFromJson(json);

  Map<String, dynamic> toJson() => _$FfiMindmapDataToJson(this);

  /// Get creation date as DateTime
  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  /// Get updated date as DateTime
  DateTime get updatedDate => DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000);

  /// Get root node
  FfiNodeData? get rootNode =>
      nodes.cast<FfiNodeData?>().firstWhere(
        (node) => node?.id == rootNodeId,
        orElse: () => null,
      );

  /// Get children of a node
  List<FfiNodeData> getChildren(String nodeId) =>
      nodes.where((node) => node.parentId == nodeId).toList();

  /// Get all descendants of a node
  List<FfiNodeData> getDescendants(String nodeId) {
    final descendants = <FfiNodeData>[];
    final children = getChildren(nodeId);

    for (final child in children) {
      descendants.add(child);
      descendants.addAll(getDescendants(child.id));
    }

    return descendants;
  }

  /// Get node by ID
  FfiNodeData? getNodeById(String id) =>
      nodes.cast<FfiNodeData?>().firstWhere(
        (node) => node?.id == id,
        orElse: () => null,
      );

  @override
  String toString() => 'FfiMindmapData(id: $id, title: "$title", ${nodes.length} nodes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FfiMindmapData && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// FFI-compatible update data for nodes
@JsonSerializable()
class FfiNodeUpdate {
  const FfiNodeUpdate({
    this.text,
    this.position,
    this.tags,
    this.metadata,
  });

  final String? text;
  final FfiPoint? position;
  final List<String>? tags;
  final Map<String, String>? metadata;

  factory FfiNodeUpdate.fromJson(Map<String, dynamic> json) =>
      _$FfiNodeUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$FfiNodeUpdateToJson(this);

  /// Create update with only text change
  factory FfiNodeUpdate.text(String text) => FfiNodeUpdate(text: text);

  /// Create update with only position change
  factory FfiNodeUpdate.position(FfiPoint position) =>
      FfiNodeUpdate(position: position);

  /// Create update with only tags change
  factory FfiNodeUpdate.tags(List<String> tags) => FfiNodeUpdate(tags: tags);

  /// Create update with only metadata change
  factory FfiNodeUpdate.metadata(Map<String, String> metadata) =>
      FfiNodeUpdate(metadata: metadata);

  /// Check if update has any changes
  bool get hasChanges => text != null || position != null || tags != null || metadata != null;

  @override
  String toString() => 'FfiNodeUpdate(${_describeChanges()})';

  String _describeChanges() {
    final changes = <String>[];
    if (text != null) changes.add('text');
    if (position != null) changes.add('position');
    if (tags != null) changes.add('tags');
    if (metadata != null) changes.add('metadata');
    return changes.join(', ');
  }
}

/// File format enumeration for import/export operations
enum FileFormat {
  json,
  opml,
  markdown,
  text,
}

/// File save/load options
@JsonSerializable()
class FileOperationOptions {
  const FileOperationOptions({
    this.format,
    this.preserveIds = false,
    this.includeMetadata = true,
    this.includeTimestamps = true,
    this.maxDepth,
    this.includeEmptyNodes = false,
    this.createBackup = false,
  });

  final FileFormat? format;
  final bool preserveIds;
  final bool includeMetadata;
  final bool includeTimestamps;
  final int? maxDepth;
  final bool includeEmptyNodes;
  final bool createBackup;

  factory FileOperationOptions.fromJson(Map<String, dynamic> json) =>
      _$FileOperationOptionsFromJson(json);

  Map<String, dynamic> toJson() => _$FileOperationOptionsToJson(this);

  /// Create default options for save operations
  factory FileOperationOptions.defaultSave() => const FileOperationOptions(
        includeMetadata: true,
        includeTimestamps: true,
        createBackup: true,
      );

  /// Create default options for load operations
  factory FileOperationOptions.defaultLoad() => const FileOperationOptions(
        preserveIds: false,
        includeMetadata: true,
        includeTimestamps: true,
      );

  @override
  String toString() => 'FileOperationOptions(format: $format, backup: $createBackup)';
}

/// Result of file operations
@JsonSerializable()
class FileOperationResult {
  const FileOperationResult({
    required this.filePath,
    required this.format,
    required this.fileSize,
    required this.nodeCount,
    required this.operationTimeMs,
    this.warnings = const [],
    this.backupCreated = false,
  });

  final String filePath;
  final FileFormat format;
  final int fileSize;
  final int nodeCount;
  final int operationTimeMs;
  final List<String> warnings;
  final bool backupCreated;

  factory FileOperationResult.fromJson(Map<String, dynamic> json) =>
      _$FileOperationResultFromJson(json);

  Map<String, dynamic> toJson() => _$FileOperationResultToJson(this);

  /// Get operation time as Duration
  Duration get operationTime => Duration(milliseconds: operationTimeMs);

  /// Get file size in a human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() =>
      'FileOperationResult($filePath, $nodeCount nodes, $fileSizeFormatted)';
}

/// Extension methods for working with FFI types
extension FfiPointExtensions on FfiPoint {
  /// Convert to Dart ui.Offset for Flutter widgets
  // Offset toOffset() => Offset(x, y);

  /// Create from Dart ui.Offset
  // static FfiPoint fromOffset(Offset offset) => FfiPoint(x: offset.dx, y: offset.dy);
}

extension FfiLayoutTypeExtensions on FfiLayoutType {
  /// Get display name for the layout type
  String get displayName {
    switch (this) {
      case FfiLayoutType.radial:
        return 'Radial';
      case FfiLayoutType.tree:
        return 'Tree';
      case FfiLayoutType.forceDirected:
        return 'Force Directed';
    }
  }

  /// Get description for the layout type
  String get description {
    switch (this) {
      case FfiLayoutType.radial:
        return 'Nodes arranged in concentric circles around the root';
      case FfiLayoutType.tree:
        return 'Hierarchical tree structure with clear parent-child relationships';
      case FfiLayoutType.forceDirected:
        return 'Physics-based layout with natural node positioning';
    }
  }

  /// Get icon for the layout type
  String get iconName {
    switch (this) {
      case FfiLayoutType.radial:
        return 'radio_button_unchecked';
      case FfiLayoutType.tree:
        return 'account_tree';
      case FfiLayoutType.forceDirected:
        return 'scatter_plot';
    }
  }
}

extension ExportFormatExtensions on ExportFormat {
  /// Get file extension for the format
  String get fileExtension {
    switch (this) {
      case ExportFormat.pdf:
        return '.pdf';
      case ExportFormat.svg:
        return '.svg';
      case ExportFormat.png:
        return '.png';
      case ExportFormat.opml:
        return '.opml';
      case ExportFormat.markdown:
        return '.md';
    }
  }

  /// Get display name for the format
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
        return 'Markdown';
    }
  }

  /// Check if format supports vector graphics
  bool get isVector => this == ExportFormat.svg;

  /// Check if format is an image
  bool get isImage => this == ExportFormat.png || this == ExportFormat.svg;
}