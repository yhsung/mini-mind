/// Mindmap state management using Riverpod
///
/// This file provides comprehensive state management for mindmap documents,
/// nodes, layouts, and all mindmap-related operations using Riverpod providers.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../bridge/mindmap_bridge.dart';
import '../bridge/bridge_types.dart';
import '../bridge/bridge_exceptions.dart';

/// Provider for the mindmap bridge instance
final mindmapBridgeProvider = Provider<MindmapBridge>((ref) {
  return MindmapBridge.instance;
});

/// Provider for mindmap state
final mindmapStateProvider = StateNotifierProvider<MindmapStateNotifier, MindmapState>((ref) {
  final bridge = ref.watch(mindmapBridgeProvider);
  return MindmapStateNotifier(bridge);
});

/// Provider for current mindmap data
final mindmapDataProvider = Provider<FfiMindmapData?>((ref) {
  return ref.watch(mindmapStateProvider).mindmapData;
});

/// Provider for all nodes
final nodesProvider = Provider<List<FfiNodeData>>((ref) {
  return ref.watch(mindmapStateProvider).nodes;
});

/// Provider for selected node
final selectedNodeProvider = Provider<FfiNodeData?>((ref) {
  final state = ref.watch(mindmapStateProvider);
  if (state.selectedNodeId == null) return null;

  return state.nodes.cast<FfiNodeData?>().firstWhere(
    (node) => node?.id == state.selectedNodeId,
    orElse: () => null,
  );
});

/// Provider for root node
final rootNodeProvider = Provider<FfiNodeData?>((ref) {
  final mindmapData = ref.watch(mindmapDataProvider);
  if (mindmapData == null) return null;

  return ref.watch(nodesProvider).cast<FfiNodeData?>().firstWhere(
    (node) => node?.id == mindmapData.rootNodeId,
    orElse: () => null,
  );
});

/// Provider for layout result
final layoutResultProvider = Provider<FfiLayoutResult?>((ref) {
  return ref.watch(mindmapStateProvider).layoutResult;
});

/// Provider for search results
final searchResultsProvider = Provider<List<FfiSearchResult>>((ref) {
  return ref.watch(mindmapStateProvider).searchResults;
});

/// Provider for loading state
final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(mindmapStateProvider).isLoading;
});

/// Provider for error state
final errorProvider = Provider<BridgeException?>((ref) {
  return ref.watch(mindmapStateProvider).error;
});

/// Mindmap state data class
@immutable
class MindmapState {
  const MindmapState({
    this.mindmapData,
    this.nodes = const [],
    this.selectedNodeId,
    this.layoutResult,
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
    this.isDirty = false,
    this.lastSavedPath,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  final FfiMindmapData? mindmapData;
  final List<FfiNodeData> nodes;
  final String? selectedNodeId;
  final FfiLayoutResult? layoutResult;
  final List<FfiSearchResult> searchResults;
  final bool isLoading;
  final BridgeException? error;
  final bool isDirty;
  final String? lastSavedPath;
  final List<MindmapStateSnapshot> undoStack;
  final List<MindmapStateSnapshot> redoStack;

  /// Check if a mindmap is loaded
  bool get hasMindmap => mindmapData != null;

  /// Check if a node is selected
  bool get hasSelectedNode => selectedNodeId != null;

  /// Check if there are search results
  bool get hasSearchResults => searchResults.isNotEmpty;

  /// Check if undo is available
  bool get canUndo => undoStack.isNotEmpty;

  /// Check if redo is available
  bool get canRedo => redoStack.isNotEmpty;

  /// Get node count
  int get nodeCount => nodes.length;

  /// Get selected node
  FfiNodeData? get selectedNode {
    if (selectedNodeId == null) return null;
    return nodes.cast<FfiNodeData?>().firstWhere(
      (node) => node?.id == selectedNodeId,
      orElse: () => null,
    );
  }

  /// Get root node
  FfiNodeData? get rootNode {
    if (mindmapData == null) return null;
    return nodes.cast<FfiNodeData?>().firstWhere(
      (node) => node?.id == mindmapData!.rootNodeId,
      orElse: () => null,
    );
  }

  /// Get children of a node
  List<FfiNodeData> getChildren(String nodeId) {
    return nodes.where((node) => node.parentId == nodeId).toList();
  }

  /// Get descendants of a node
  List<FfiNodeData> getDescendants(String nodeId) {
    final descendants = <FfiNodeData>[];
    final children = getChildren(nodeId);

    for (final child in children) {
      descendants.add(child);
      descendants.addAll(getDescendants(child.id));
    }

    return descendants;
  }

  /// Copy with updated fields
  MindmapState copyWith({
    FfiMindmapData? mindmapData,
    List<FfiNodeData>? nodes,
    String? selectedNodeId,
    FfiLayoutResult? layoutResult,
    List<FfiSearchResult>? searchResults,
    bool? isLoading,
    BridgeException? error,
    bool? isDirty,
    String? lastSavedPath,
    List<MindmapStateSnapshot>? undoStack,
    List<MindmapStateSnapshot>? redoStack,
  }) {
    return MindmapState(
      mindmapData: mindmapData ?? this.mindmapData,
      nodes: nodes ?? this.nodes,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      layoutResult: layoutResult ?? this.layoutResult,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isDirty: isDirty ?? this.isDirty,
      lastSavedPath: lastSavedPath ?? this.lastSavedPath,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }

  /// Copy with cleared error
  MindmapState clearError() => copyWith(error: null);

  /// Copy with cleared selection
  MindmapState clearSelection() => copyWith(selectedNodeId: null);

  @override
  String toString() {
    return 'MindmapState('
        'hasData: $hasMindmap, '
        'nodeCount: $nodeCount, '
        'selectedNodeId: $selectedNodeId, '
        'isLoading: $isLoading, '
        'isDirty: $isDirty'
        ')';
  }
}

/// Snapshot of mindmap state for undo/redo functionality
@immutable
class MindmapStateSnapshot {
  const MindmapStateSnapshot({
    required this.mindmapData,
    required this.nodes,
    required this.timestamp,
    required this.operation,
  });

  final FfiMindmapData mindmapData;
  final List<FfiNodeData> nodes;
  final DateTime timestamp;
  final String operation;

  @override
  String toString() => 'MindmapStateSnapshot($operation at $timestamp)';
}

/// Mindmap state notifier for managing mindmap state
class MindmapStateNotifier extends StateNotifier<MindmapState> {
  MindmapStateNotifier(this._bridge) : super(const MindmapState()) {
    _logger = Logger();
  }

  final MindmapBridge _bridge;
  late final Logger _logger;

  static const int _maxUndoStackSize = 50;

  // Public Methods - Document Operations

  /// Create a new mindmap
  Future<void> createMindmap(String title) async {
    await _withErrorHandling(() async {
      _setLoading(true);

      final mindmapId = await _bridge.createMindmap(title);
      final rootNodeId = await _bridge.createNode(text: 'Central Idea');

      final mindmapData = FfiMindmapData(
        id: mindmapId,
        title: title,
        rootNodeId: rootNodeId,
        nodes: [],
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      await _refreshNodes();

      state = state.copyWith(
        mindmapData: mindmapData,
        isDirty: false,
        selectedNodeId: rootNodeId,
      );

      _logger.i('Created new mindmap: $title');
    });
  }

  /// Load mindmap from file
  Future<void> loadMindmap(String filePath) async {
    await _withErrorHandling(() async {
      _setLoading(true);

      final mindmapData = await _bridge.loadMindmap(filePath);
      await _refreshNodes();

      state = state.copyWith(
        mindmapData: mindmapData,
        isDirty: false,
        lastSavedPath: filePath,
        selectedNodeId: mindmapData.rootNodeId,
      );

      _logger.i('Loaded mindmap from: $filePath');
    });
  }

  /// Save mindmap to file
  Future<void> saveMindmap(String filePath, {FileOperationOptions? options}) async {
    await _withErrorHandling(() async {
      _setLoading(true);

      final result = await _bridge.saveMindmap(filePath, options: options);

      state = state.copyWith(
        isDirty: false,
        lastSavedPath: filePath,
      );

      _logger.i('Saved mindmap to: ${result.filePath}');
    });
  }

  /// Export mindmap
  Future<void> exportMindmap(String filePath, ExportFormat format) async {
    await _withErrorHandling(() async {
      _setLoading(true);

      final result = await _bridge.exportMindmap(filePath, format);

      _logger.i('Exported mindmap to: ${result.filePath} as ${format.displayName}');
    });
  }

  // Node Operations

  /// Create a new node
  Future<void> createNode({
    String? parentId,
    required String text,
    FfiPoint? position,
  }) async {
    await _withErrorHandling(() async {
      _createSnapshot('Create Node');

      final nodeId = await _bridge.createNode(
        parentId: parentId,
        text: text,
        position: position,
      );

      await _refreshNodes();

      state = state.copyWith(
        selectedNodeId: nodeId,
        isDirty: true,
      );

      _logger.d('Created node: $nodeId');
    });
  }

  /// Update a node
  Future<void> updateNode(String nodeId, FfiNodeUpdate update) async {
    await _withErrorHandling(() async {
      _createSnapshot('Update Node');

      await _bridge.updateNode(nodeId, update);
      await _refreshNodes();

      state = state.copyWith(isDirty: true);

      _logger.d('Updated node: $nodeId');
    });
  }

  /// Update node text
  Future<void> updateNodeText(String nodeId, String text) async {
    await updateNode(nodeId, FfiNodeUpdate.text(text));
  }

  /// Update node position
  Future<void> updateNodePosition(String nodeId, FfiPoint position) async {
    await updateNode(nodeId, FfiNodeUpdate.position(position));
  }

  /// Delete a node
  Future<void> deleteNode(String nodeId) async {
    await _withErrorHandling(() async {
      _createSnapshot('Delete Node');

      await _bridge.deleteNode(nodeId);
      await _refreshNodes();

      // Clear selection if deleted node was selected
      String? newSelectedId = state.selectedNodeId;
      if (state.selectedNodeId == nodeId) {
        newSelectedId = state.rootNode?.id;
      }

      state = state.copyWith(
        selectedNodeId: newSelectedId,
        isDirty: true,
      );

      _logger.d('Deleted node: $nodeId');
    });
  }

  /// Select a node
  void selectNode(String? nodeId) {
    state = state.copyWith(selectedNodeId: nodeId);
    _logger.d('Selected node: $nodeId');
  }

  /// Clear node selection
  void clearSelection() {
    state = state.clearSelection();
    _logger.d('Cleared node selection');
  }

  // Layout Operations

  /// Calculate layout
  Future<void> calculateLayout(FfiLayoutType layoutType) async {
    await _withErrorHandling(() async {
      _setLoading(true);

      final layoutResult = await _bridge.calculateLayout(layoutType);

      state = state.copyWith(layoutResult: layoutResult);

      _logger.i('Calculated ${layoutType.displayName} layout in ${layoutResult.computationTimeMs}ms');
    });
  }

  /// Apply layout
  Future<void> applyLayout() async {
    if (state.layoutResult == null) return;

    await _withErrorHandling(() async {
      _createSnapshot('Apply Layout');

      await _bridge.applyLayout(state.layoutResult!);
      await _refreshNodes();

      state = state.copyWith(isDirty: true);

      _logger.i('Applied layout with ${state.layoutResult!.nodePositions.length} positions');
    });
  }

  // Search Operations

  /// Search nodes by text
  Future<void> searchNodes(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    await _withErrorHandling(() async {
      final results = await _bridge.searchNodes(query.trim());

      state = state.copyWith(searchResults: results);

      _logger.d('Search for "$query" returned ${results.length} results');
    });
  }

  /// Search nodes by tags
  Future<void> searchByTags(List<String> tags) async {
    if (tags.isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    await _withErrorHandling(() async {
      final results = await _bridge.searchByTags(tags);

      state = state.copyWith(searchResults: results);

      _logger.d('Tag search for ${tags.join(', ')} returned ${results.length} results');
    });
  }

  /// Clear search results
  void clearSearch() {
    state = state.copyWith(searchResults: []);
    _logger.d('Cleared search results');
  }

  // Undo/Redo Operations

  /// Undo last operation
  Future<void> undo() async {
    if (!state.canUndo) return;

    final snapshot = state.undoStack.last;
    final newUndoStack = state.undoStack.sublist(0, state.undoStack.length - 1);
    final newRedoStack = [...state.redoStack, _createCurrentSnapshot('Redo Point')];

    await _restoreSnapshot(snapshot);

    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: newRedoStack,
      isDirty: true,
    );

    _logger.d('Undid operation: ${snapshot.operation}');
  }

  /// Redo last undone operation
  Future<void> redo() async {
    if (!state.canRedo) return;

    final snapshot = state.redoStack.last;
    final newRedoStack = state.redoStack.sublist(0, state.redoStack.length - 1);
    final newUndoStack = [...state.undoStack, _createCurrentSnapshot('Undo Point')];

    await _restoreSnapshot(snapshot);

    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: newRedoStack,
      isDirty: true,
    );

    _logger.d('Redid operation: ${snapshot.operation}');
  }

  // Error Handling

  /// Clear current error
  void clearError() {
    state = state.clearError();
  }

  // Utility Methods

  /// Get node by ID
  FfiNodeData? getNodeById(String nodeId) {
    return state.nodes.cast<FfiNodeData?>().firstWhere(
      (node) => node?.id == nodeId,
      orElse: () => null,
    );
  }

  /// Check if node exists
  bool nodeExists(String nodeId) {
    return getNodeById(nodeId) != null;
  }

  /// Get node children
  List<FfiNodeData> getNodeChildren(String nodeId) {
    return state.getChildren(nodeId);
  }

  /// Reset state
  void reset() {
    state = const MindmapState();
    _logger.i('Reset mindmap state');
  }

  // Private Methods

  /// Execute operation with error handling
  Future<void> _withErrorHandling(Future<void> Function() operation) async {
    try {
      state = state.clearError();
      await operation();
    } on BridgeException catch (e) {
      state = state.copyWith(error: e, isLoading: false);
      _logger.e('Bridge operation failed', error: e);
    } catch (e, stackTrace) {
      final bridgeError = BridgeOperationException.fromError(e);
      state = state.copyWith(error: bridgeError, isLoading: false);
      _logger.e('Unexpected error in bridge operation', error: e, stackTrace: stackTrace);
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Refresh nodes from bridge
  Future<void> _refreshNodes() async {
    final nodes = await _bridge.getAllNodes();
    state = state.copyWith(nodes: nodes);
  }

  /// Create snapshot for undo/redo
  void _createSnapshot(String operation) {
    if (state.mindmapData == null) return;

    final snapshot = MindmapStateSnapshot(
      mindmapData: state.mindmapData!,
      nodes: List.from(state.nodes),
      timestamp: DateTime.now(),
      operation: operation,
    );

    final newUndoStack = [...state.undoStack, snapshot];

    // Limit undo stack size
    final limitedUndoStack = newUndoStack.length > _maxUndoStackSize
        ? newUndoStack.sublist(newUndoStack.length - _maxUndoStackSize)
        : newUndoStack;

    state = state.copyWith(
      undoStack: limitedUndoStack,
      redoStack: [], // Clear redo stack when new operation is performed
    );
  }

  /// Create snapshot of current state
  MindmapStateSnapshot _createCurrentSnapshot(String operation) {
    return MindmapStateSnapshot(
      mindmapData: state.mindmapData!,
      nodes: List.from(state.nodes),
      timestamp: DateTime.now(),
      operation: operation,
    );
  }

  /// Restore from snapshot
  Future<void> _restoreSnapshot(MindmapStateSnapshot snapshot) async {
    // In a real implementation, this would restore the state through the bridge
    // For now, we'll just update the local state
    state = state.copyWith(
      mindmapData: snapshot.mindmapData,
      nodes: snapshot.nodes,
    );
  }
}