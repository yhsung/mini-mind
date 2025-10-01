/// Clipboard service for mindmap node operations
///
/// Provides cut, copy, and paste functionality for mindmap nodes
/// with support for both single nodes and node trees.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../bridge/bridge_types.dart';

/// Clipboard data structure for mindmap nodes
class ClipboardData {
  const ClipboardData({
    required this.nodes,
    required this.operation,
    required this.timestamp,
    this.text,
  });

  final List<FfiNodeData> nodes;
  final ClipboardOperation operation;
  final DateTime timestamp;
  final String? text;

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((node) => {
      'id': node.id,
      'text': node.text,
      'position': {'x': node.position.x, 'y': node.position.y},
      'parentId': node.parentId,
      'metadata': node.metadata,
    }).toList(),
    'operation': operation.toString(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory ClipboardData.fromJson(Map<String, dynamic> json) {
    return ClipboardData(
      nodes: (json['nodes'] as List).map((nodeJson) => FfiNodeData(
        id: nodeJson['id'],
        text: nodeJson['text'],
        position: FfiPoint(
          x: nodeJson['position']['x'],
          y: nodeJson['position']['y'],
        ),
        size: const FfiSize(width: 100, height: 40),
        parentId: nodeJson['parentId'],
        metadata: Map<String, String>.from(nodeJson['metadata'] ?? {}),
      )).toList(),
      operation: ClipboardOperation.values.firstWhere(
        (op) => op.toString() == json['operation'],
        orElse: () => ClipboardOperation.copy,
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

enum ClipboardOperation { cut, copy }

/// Service for handling clipboard operations
class ClipboardService {
  static ClipboardService? _instance;
  static final Logger _logger = Logger();

  ClipboardService._();

  static ClipboardService get instance {
    _instance ??= ClipboardService._();
    return _instance!;
  }

  static const String _clipboardMimeType = 'application/x-mindmap-nodes';
  ClipboardData? _internalClipboard;

  /// Copy nodes to clipboard
  Future<void> copyNodes(List<FfiNodeData> nodes) async {
    try {
      final clipboardData = ClipboardData(
        nodes: nodes,
        operation: ClipboardOperation.copy,
        timestamp: DateTime.now(),
      );

      await _setClipboardData(clipboardData);
      _internalClipboard = clipboardData;

      _logger.d('Copied ${nodes.length} nodes to clipboard');
    } catch (e) {
      _logger.e('Failed to copy nodes to clipboard', error: e);
      rethrow;
    }
  }

  /// Cut nodes to clipboard
  Future<void> cutNodes(List<FfiNodeData> nodes) async {
    try {
      final clipboardData = ClipboardData(
        nodes: nodes,
        operation: ClipboardOperation.cut,
        timestamp: DateTime.now(),
      );

      await _setClipboardData(clipboardData);
      _internalClipboard = clipboardData;

      _logger.d('Cut ${nodes.length} nodes to clipboard');
    } catch (e) {
      _logger.e('Failed to cut nodes to clipboard', error: e);
      rethrow;
    }
  }

  /// Get clipboard data
  Future<ClipboardData?> getClipboardData() async {
    try {
      // Try to get from system clipboard first
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        try {
          final json = jsonDecode(clipboardData!.text!);
          if (json['nodes'] != null && json['operation'] != null) {
            return ClipboardData.fromJson(json);
          }
        } catch (e) {
          // Not mindmap data, use internal clipboard
        }
      }

      // Fallback to internal clipboard
      return _internalClipboard;
    } catch (e) {
      _logger.e('Failed to get clipboard data', error: e);
      return _internalClipboard;
    }
  }

  /// Check if clipboard contains mindmap data
  Future<bool> hasClipboardData() async {
    final data = await getClipboardData();
    return data != null && data.nodes.isNotEmpty;
  }

  /// Check if clipboard contains cut data (nodes should be moved, not copied)
  Future<bool> hasCutData() async {
    final data = await getClipboardData();
    return data != null && data.operation == ClipboardOperation.cut;
  }

  /// Clear clipboard
  Future<void> clearClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(
        nodes: const [],
        operation: ClipboardOperation.cut,
        timestamp: DateTime.now(),
        text: '',
      ));
      _internalClipboard = null;
      _logger.d('Clipboard cleared');
    } catch (e) {
      _logger.e('Failed to clear clipboard', error: e);
    }
  }

  /// Set clipboard data (internal helper)
  Future<void> _setClipboardData(ClipboardData data) async {
    try {
      final jsonString = jsonEncode(data.toJson());
      await Clipboard.setData(ClipboardData(
        nodes: data.nodes,
        operation: data.operation,
        timestamp: data.timestamp,
        text: jsonString,
      ));
    } catch (e) {
      // If system clipboard fails, at least keep internal clipboard
      _logger.w('Failed to set system clipboard, using internal only', error: e);
    }
  }

  /// Generate new IDs for pasted nodes to avoid conflicts
  List<FfiNodeData> generateNewNodeIds(List<FfiNodeData> nodes) {
    final idMapping = <String, String>{};
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Generate new IDs for all nodes
    for (int i = 0; i < nodes.length; i++) {
      final oldId = nodes[i].id;
      final newId = 'node_${timestamp}_$i';
      idMapping[oldId] = newId;
    }

    // Update nodes with new IDs and parent references
    return nodes.map((node) {
      final newId = idMapping[node.id]!;
      final newParentId = node.parentId != null ? idMapping[node.parentId] : null;

      return FfiNodeData(
        id: newId,
        text: node.text,
        position: node.position,
        size: node.size,
        parentId: newParentId,
        metadata: node.metadata,
      );
    }).toList();
  }
}