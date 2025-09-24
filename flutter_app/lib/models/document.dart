/// Document data model for Flutter UI layer
///
/// This file defines the Document model representing a complete mindmap
/// with all its nodes, edges, and metadata.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'node.dart';
import 'edge.dart';

part 'document.g.dart';

/// Document model representing a complete mindmap
@JsonSerializable()
@immutable
class Document {
  const Document({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.description,
    this.metadata = const {},
    this.nodes = const [],
    this.edges = const [],
    this.rootNodeId,
    this.settings = const DocumentSettings(),
    this.version = '1.0',
    this.filePath,
    this.isDirty = false,
    this.isReadOnly = false,
  });

  /// Unique identifier for the document
  final String id;

  /// Document title
  final String? title;

  /// Document description
  final String? description;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last updated timestamp
  final DateTime updatedAt;

  /// Additional metadata
  final Map<String, String> metadata;

  /// All nodes in the document
  final List<Node> nodes;

  /// All edges in the document
  final List<Edge> edges;

  /// ID of the root node (if any)
  final String? rootNodeId;

  /// Document-specific settings
  final DocumentSettings settings;

  /// Document format version
  final String version;

  /// File path (if saved to disk)
  final String? filePath;

  /// Whether document has unsaved changes
  final bool isDirty;

  /// Whether document is read-only
  final bool isReadOnly;

  /// Get document display title
  String get displayTitle => title?.isNotEmpty == true ? title! : 'Untitled';

  /// Get document file name
  String get fileName {
    if (filePath != null) {
      return path.basename(filePath!);
    }
    return '${displayTitle.replaceAll(RegExp(r'[^\w\s-]'), '')}.mindmap';
  }

  /// Get document directory
  String? get directory {
    if (filePath != null) {
      return path.dirname(filePath!);
    }
    return null;
  }

  /// Check if document has a title
  bool get hasTitle => title != null && title!.isNotEmpty;

  /// Check if document has a description
  bool get hasDescription => description != null && description!.isNotEmpty;

  /// Check if document has metadata
  bool get hasMetadata => metadata.isNotEmpty;

  /// Check if document has nodes
  bool get hasNodes => nodes.isNotEmpty;

  /// Check if document has edges
  bool get hasEdges => edges.isNotEmpty;

  /// Check if document has a root node
  bool get hasRootNode => rootNodeId != null && findNodeById(rootNodeId!) != null;

  /// Check if document is empty
  bool get isEmpty => !hasNodes && !hasEdges;

  /// Check if document is saved to disk
  bool get isSaved => filePath != null && !isDirty;

  /// Get document age
  Duration get age => DateTime.now().difference(createdAt);

  /// Get time since last update
  Duration get timeSinceUpdate => DateTime.now().difference(updatedAt);

  /// Get document statistics
  DocumentStats get stats => DocumentStats(
        nodeCount: nodes.length,
        edgeCount: edges.length,
        selectedNodeCount: nodes.where((n) => n.isSelected).length,
        selectedEdgeCount: edges.where((e) => e.isSelected).length,
        rootNodeCount: nodes.where((n) => n.isRoot).length,
        leafNodeCount: nodes.where((n) => isLeafNode(n.id)).length,
      );

  /// Find node by ID
  Node? findNodeById(String id) {
    try {
      return nodes.firstWhere((node) => node.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Find edge by ID
  Edge? findEdgeById(String id) {
    try {
      return edges.firstWhere((edge) => edge.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get root node
  Node? get rootNode {
    if (rootNodeId != null) {
      return findNodeById(rootNodeId!);
    }
    // Fallback: find first root node
    try {
      return nodes.firstWhere((node) => node.isRoot);
    } catch (e) {
      return null;
    }
  }

  /// Get all selected nodes
  List<Node> get selectedNodes => nodes.where((node) => node.isSelected).toList();

  /// Get all selected edges
  List<Edge> get selectedEdges => edges.where((edge) => edge.isSelected).toList();

  /// Get all visible nodes
  List<Node> get visibleNodes => nodes.where((node) => node.isVisible).toList();

  /// Get all visible edges
  List<Edge> get visibleEdges => edges.where((edge) => edge.isVisible).toList();

  /// Get edges connected to a node
  List<Edge> getConnectedEdges(String nodeId) {
    return edges.where((edge) => edge.connectsTo(nodeId)).toList();
  }

  /// Get child nodes of a parent node
  List<Node> getChildNodes(String parentId) {
    final childEdges = edges.where((edge) => edge.sourceId == parentId).toList();
    return childEdges
        .map((edge) => findNodeById(edge.targetId))
        .where((node) => node != null)
        .cast<Node>()
        .toList();
  }

  /// Get parent node of a child node
  Node? getParentNode(String childId) {
    try {
      final parentEdge = edges.firstWhere((edge) => edge.targetId == childId);
      return findNodeById(parentEdge.sourceId);
    } catch (e) {
      return null;
    }
  }

  /// Check if node is a leaf node (has no children)
  bool isLeafNode(String nodeId) {
    return !edges.any((edge) => edge.sourceId == nodeId);
  }

  /// Get node depth (distance from root)
  int getNodeDepth(String nodeId) {
    var depth = 0;
    var currentId = nodeId;

    while (true) {
      final parent = getParentNode(currentId);
      if (parent == null) break;
      depth++;
      currentId = parent.id;

      // Prevent infinite loops
      if (depth > 100) break;
    }

    return depth;
  }

  /// Copy with updated fields
  Document copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? metadata,
    List<Node>? nodes,
    List<Edge>? edges,
    String? rootNodeId,
    DocumentSettings? settings,
    String? version,
    String? filePath,
    bool? isDirty,
    bool? isReadOnly,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      rootNodeId: rootNodeId ?? this.rootNodeId,
      settings: settings ?? this.settings,
      version: version ?? this.version,
      filePath: filePath ?? this.filePath,
      isDirty: isDirty ?? this.isDirty,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }

  /// Update basic info
  Document updateInfo({
    String? title,
    String? description,
  }) {
    return copyWith(
      title: title,
      description: description,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Add or update metadata
  Document updateMetadata(String key, String value) {
    return copyWith(
      metadata: {...metadata, key: value},
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Remove metadata
  Document removeMetadata(String key) {
    final newMetadata = Map<String, String>.from(metadata);
    newMetadata.remove(key);
    return copyWith(
      metadata: newMetadata,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Add a node
  Document addNode(Node node) {
    return copyWith(
      nodes: [...nodes, node],
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Update a node
  Document updateNode(Node updatedNode) {
    final newNodes = nodes.map((node) {
      return node.id == updatedNode.id ? updatedNode : node;
    }).toList();

    return copyWith(
      nodes: newNodes,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Remove a node and its connected edges
  Document removeNode(String nodeId) {
    final newNodes = nodes.where((node) => node.id != nodeId).toList();
    final newEdges = edges.where((edge) => !edge.connectsTo(nodeId)).toList();

    return copyWith(
      nodes: newNodes,
      edges: newEdges,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Add an edge
  Document addEdge(Edge edge) {
    return copyWith(
      edges: [...edges, edge],
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Update an edge
  Document updateEdge(Edge updatedEdge) {
    final newEdges = edges.map((edge) {
      return edge.id == updatedEdge.id ? updatedEdge : edge;
    }).toList();

    return copyWith(
      edges: newEdges,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Remove an edge
  Document removeEdge(String edgeId) {
    final newEdges = edges.where((edge) => edge.id != edgeId).toList();

    return copyWith(
      edges: newEdges,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Set root node
  Document setRootNode(String? nodeId) {
    return copyWith(
      rootNodeId: nodeId,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
  }

  /// Clear all selections
  Document clearSelections() {
    final newNodes = nodes.map((node) => node.deselect()).toList();
    final newEdges = edges.map((edge) => edge.deselect()).toList();

    return copyWith(
      nodes: newNodes,
      edges: newEdges,
    );
  }

  /// Select node
  Document selectNode(String nodeId, {bool clearOthers = true}) {
    final newNodes = nodes.map((node) {
      if (node.id == nodeId) {
        return node.select();
      } else if (clearOthers) {
        return node.deselect();
      }
      return node;
    }).toList();

    final newEdges = clearOthers ? edges.map((edge) => edge.deselect()).toList() : edges;

    return copyWith(
      nodes: newNodes,
      edges: newEdges,
    );
  }

  /// Select edge
  Document selectEdge(String edgeId, {bool clearOthers = true}) {
    final newEdges = edges.map((edge) {
      if (edge.id == edgeId) {
        return edge.select();
      } else if (clearOthers) {
        return edge.deselect();
      }
      return edge;
    }).toList();

    final newNodes = clearOthers ? nodes.map((node) => node.deselect()).toList() : nodes;

    return copyWith(
      nodes: newNodes,
      edges: newEdges,
    );
  }

  /// Mark as saved
  Document markSaved(String? path) {
    return copyWith(
      filePath: path ?? filePath,
      isDirty: false,
      updatedAt: DateTime.now(),
    );
  }

  /// Mark as dirty
  Document markDirty() {
    return copyWith(
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Export to JSON
  Map<String, dynamic> toJson() => _$DocumentToJson(this);

  /// Import from JSON
  factory Document.fromJson(Map<String, dynamic> json) => _$DocumentFromJson(json);

  /// Create new empty document
  factory Document.empty({
    String? title,
    String? description,
  }) {
    final now = DateTime.now();
    return Document(
      id: 'doc_${now.millisecondsSinceEpoch}',
      title: title,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Export to JSON string
  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  /// Import from JSON string
  static Document fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return Document.fromJson(json);
  }

  /// Load from file
  static Future<Document> fromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final document = fromJsonString(content);
    return document.copyWith(filePath: filePath, isDirty: false);
  }

  /// Save to file
  Future<void> saveToFile(String? path) async {
    final targetPath = path ?? filePath;
    if (targetPath == null) throw ArgumentError('No file path specified');

    final file = File(targetPath);
    await file.writeAsString(toJsonString());
  }

  @override
  String toString() {
    return 'Document('
        'id: $id, '
        'title: "$title", '
        'nodes: ${nodes.length}, '
        'edges: ${edges.length}, '
        'dirty: $isDirty'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Document && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Document settings and preferences
@JsonSerializable()
@immutable
class DocumentSettings {
  const DocumentSettings({
    this.autoSave = true,
    this.autoSaveInterval = const Duration(minutes: 5),
    this.maxUndoSteps = 50,
    this.enableVersioning = true,
    this.showGrid = true,
    this.snapToGrid = false,
    this.gridSize = 20.0,
    this.defaultNodeStyle = const NodeStyle(),
    this.defaultEdgeStyle = const EdgeStyle(),
    this.layoutAlgorithm = 'hierarchical',
    this.theme = 'default',
  });

  final bool autoSave;
  final Duration autoSaveInterval;
  final int maxUndoSteps;
  final bool enableVersioning;
  final bool showGrid;
  final bool snapToGrid;
  final double gridSize;
  final NodeStyle defaultNodeStyle;
  final EdgeStyle defaultEdgeStyle;
  final String layoutAlgorithm;
  final String theme;

  DocumentSettings copyWith({
    bool? autoSave,
    Duration? autoSaveInterval,
    int? maxUndoSteps,
    bool? enableVersioning,
    bool? showGrid,
    bool? snapToGrid,
    double? gridSize,
    NodeStyle? defaultNodeStyle,
    EdgeStyle? defaultEdgeStyle,
    String? layoutAlgorithm,
    String? theme,
  }) {
    return DocumentSettings(
      autoSave: autoSave ?? this.autoSave,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
      maxUndoSteps: maxUndoSteps ?? this.maxUndoSteps,
      enableVersioning: enableVersioning ?? this.enableVersioning,
      showGrid: showGrid ?? this.showGrid,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      gridSize: gridSize ?? this.gridSize,
      defaultNodeStyle: defaultNodeStyle ?? this.defaultNodeStyle,
      defaultEdgeStyle: defaultEdgeStyle ?? this.defaultEdgeStyle,
      layoutAlgorithm: layoutAlgorithm ?? this.layoutAlgorithm,
      theme: theme ?? this.theme,
    );
  }

  factory DocumentSettings.fromJson(Map<String, dynamic> json) => _$DocumentSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$DocumentSettingsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSettings &&
          autoSave == other.autoSave &&
          autoSaveInterval == other.autoSaveInterval &&
          maxUndoSteps == other.maxUndoSteps &&
          enableVersioning == other.enableVersioning &&
          showGrid == other.showGrid &&
          snapToGrid == other.snapToGrid &&
          gridSize == other.gridSize &&
          defaultNodeStyle == other.defaultNodeStyle &&
          defaultEdgeStyle == other.defaultEdgeStyle &&
          layoutAlgorithm == other.layoutAlgorithm &&
          theme == other.theme;

  @override
  int get hashCode => Object.hash(
        autoSave,
        autoSaveInterval,
        maxUndoSteps,
        enableVersioning,
        showGrid,
        snapToGrid,
        gridSize,
        defaultNodeStyle,
        defaultEdgeStyle,
        layoutAlgorithm,
        theme,
      );
}

/// Document statistics
@immutable
class DocumentStats {
  const DocumentStats({
    required this.nodeCount,
    required this.edgeCount,
    required this.selectedNodeCount,
    required this.selectedEdgeCount,
    required this.rootNodeCount,
    required this.leafNodeCount,
  });

  final int nodeCount;
  final int edgeCount;
  final int selectedNodeCount;
  final int selectedEdgeCount;
  final int rootNodeCount;
  final int leafNodeCount;

  int get totalElements => nodeCount + edgeCount;
  int get selectedElements => selectedNodeCount + selectedEdgeCount;
  bool get hasSelection => selectedElements > 0;

  @override
  String toString() {
    return 'DocumentStats('
        'nodes: $nodeCount, '
        'edges: $edgeCount, '
        'selected: $selectedElements, '
        'roots: $rootNodeCount, '
        'leaves: $leafNodeCount'
        ')';
  }
}