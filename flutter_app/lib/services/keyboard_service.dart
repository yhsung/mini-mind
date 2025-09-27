/// Keyboard shortcut service for mindmap application
///
/// This service provides platform-adaptive keyboard shortcut registration
/// with comprehensive shortcuts for node creation, navigation, editing,
/// and undo/redo operations integrated with mindmap state management.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/platform_service.dart';
import '../state/mindmap_state.dart';
import '../utils/logger.dart';

/// Keyboard shortcut intent base class
abstract class KeyboardIntent extends Intent {
  const KeyboardIntent();
}

/// Node operation intents
class CreateChildNodeIntent extends KeyboardIntent {
  const CreateChildNodeIntent();
}

class CreateSiblingNodeIntent extends KeyboardIntent {
  const CreateSiblingNodeIntent();
}

class DeleteNodeIntent extends KeyboardIntent {
  const DeleteNodeIntent();
}

class EditNodeIntent extends KeyboardIntent {
  const EditNodeIntent();
}

/// Navigation intents
class SelectParentNodeIntent extends KeyboardIntent {
  const SelectParentNodeIntent();
}

class SelectChildNodeIntent extends KeyboardIntent {
  const SelectChildNodeIntent();
}

class SelectNextSiblingIntent extends KeyboardIntent {
  const SelectNextSiblingIntent();
}

class SelectPreviousSiblingIntent extends KeyboardIntent {
  const SelectPreviousSiblingIntent();
}

/// Document operation intents
class UndoIntent extends KeyboardIntent {
  const UndoIntent();
}

class RedoIntent extends KeyboardIntent {
  const RedoIntent();
}

class SaveDocumentIntent extends KeyboardIntent {
  const SaveDocumentIntent();
}

class OpenDocumentIntent extends KeyboardIntent {
  const OpenDocumentIntent();
}

class NewDocumentIntent extends KeyboardIntent {
  const NewDocumentIntent();
}

/// Search intent
class OpenSearchIntent extends KeyboardIntent {
  const OpenSearchIntent();
}

/// Focus intents
class FocusCanvasIntent extends KeyboardIntent {
  const FocusCanvasIntent();
}

class EscapeIntent extends KeyboardIntent {
  const EscapeIntent();
}

/// Keyboard shortcut definition
@immutable
class KeyboardShortcut {
  const KeyboardShortcut({
    required this.key,
    required this.intent,
    required this.description,
    this.modifiers = const <LogicalKeyboardKey>{},
    this.platforms = const <String>{},
  });

  final LogicalKeyboardKey key;
  final KeyboardIntent intent;
  final String description;
  final Set<LogicalKeyboardKey> modifiers;
  final Set<String> platforms; // Empty means all platforms

  /// Create shortcut with Command (macOS) or Control (others)
  factory KeyboardShortcut.command({
    required LogicalKeyboardKey key,
    required KeyboardIntent intent,
    required String description,
    Set<LogicalKeyboardKey> additionalModifiers = const <LogicalKeyboardKey>{},
  }) {
    final bool isMac = Platform.isMacOS;
    final LogicalKeyboardKey primaryModifier = isMac
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    return KeyboardShortcut(
      key: key,
      intent: intent,
      description: description,
      modifiers: {primaryModifier, ...additionalModifiers},
    );
  }

  /// Create platform-specific shortcut
  factory KeyboardShortcut.platform({
    required LogicalKeyboardKey key,
    required KeyboardIntent intent,
    required String description,
    required Map<String, Set<LogicalKeyboardKey>> platformModifiers,
  }) {
    final String platformName = Platform.operatingSystem;
    final Set<LogicalKeyboardKey> modifiers = platformModifiers[platformName] ?? <LogicalKeyboardKey>{};

    return KeyboardShortcut(
      key: key,
      intent: intent,
      description: description,
      modifiers: modifiers,
      platforms: platformModifiers.keys.toSet(),
    );
  }

  /// Check if shortcut applies to current platform
  bool get isApplicableToPlatform {
    if (platforms.isEmpty) return true;
    return platforms.contains(Platform.operatingSystem);
  }

  /// Get shortcut display string
  String get displayString {
    final List<String> parts = [];

    if (modifiers.contains(LogicalKeyboardKey.controlLeft) ||
        modifiers.contains(LogicalKeyboardKey.controlRight)) {
      parts.add(Platform.isMacOS ? '⌃' : 'Ctrl');
    }

    if (modifiers.contains(LogicalKeyboardKey.altLeft) ||
        modifiers.contains(LogicalKeyboardKey.altRight)) {
      parts.add(Platform.isMacOS ? '⌥' : 'Alt');
    }

    if (modifiers.contains(LogicalKeyboardKey.shiftLeft) ||
        modifiers.contains(LogicalKeyboardKey.shiftRight)) {
      parts.add(Platform.isMacOS ? '⇧' : 'Shift');
    }

    if (modifiers.contains(LogicalKeyboardKey.metaLeft) ||
        modifiers.contains(LogicalKeyboardKey.metaRight)) {
      parts.add(Platform.isMacOS ? '⌘' : 'Win');
    }

    parts.add(_getKeyDisplayName(key));

    return parts.join(Platform.isMacOS ? '' : '+');
  }

  /// Get human-readable key name
  String _getKeyDisplayName(LogicalKeyboardKey key) {
    final Map<LogicalKeyboardKey, String> keyNames = {
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.escape: 'Esc',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.arrowUp: '↑',
      LogicalKeyboardKey.arrowDown: '↓',
      LogicalKeyboardKey.arrowLeft: '←',
      LogicalKeyboardKey.arrowRight: '→',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'PgUp',
      LogicalKeyboardKey.pageDown: 'PgDn',
    };

    return keyNames[key] ?? key.keyLabel.toUpperCase();
  }

  @override
  String toString() => '$displayString: $description';
}

/// Keyboard service for managing shortcuts and handling keyboard input
class KeyboardService {
  static final KeyboardService _instance = KeyboardService._internal();
  factory KeyboardService() => _instance;
  KeyboardService._internal();

  static KeyboardService get instance => _instance;

  final PlatformService _platformService = PlatformService.instance;
  final Logger _logger = Logger.instance;

  late Map<LogicalKeySet, KeyboardIntent> _shortcuts;
  late Map<Type, KeyboardShortcut> _intentToShortcut;
  late List<KeyboardShortcut> _allShortcuts;

  ProviderRef? _ref;
  bool _isInitialized = false;

  /// Initialize keyboard service with provider reference
  void initialize(ProviderRef ref) {
    if (_isInitialized) return;

    _ref = ref;
    _setupShortcuts();
    _isInitialized = true;

    _logger.info('KeyboardService: Initialized with ${_allShortcuts.length} shortcuts');
  }

  /// Get all available shortcuts
  List<KeyboardShortcut> get shortcuts => List.unmodifiable(_allShortcuts);

  /// Get shortcuts by category
  List<KeyboardShortcut> getShortcutsByCategory(String category) {
    switch (category.toLowerCase()) {
      case 'node':
        return _allShortcuts.where((s) =>
          s.intent is CreateChildNodeIntent ||
          s.intent is CreateSiblingNodeIntent ||
          s.intent is DeleteNodeIntent ||
          s.intent is EditNodeIntent
        ).toList();

      case 'navigation':
        return _allShortcuts.where((s) =>
          s.intent is SelectParentNodeIntent ||
          s.intent is SelectChildNodeIntent ||
          s.intent is SelectNextSiblingIntent ||
          s.intent is SelectPreviousSiblingIntent
        ).toList();

      case 'document':
        return _allShortcuts.where((s) =>
          s.intent is UndoIntent ||
          s.intent is RedoIntent ||
          s.intent is SaveDocumentIntent ||
          s.intent is OpenDocumentIntent ||
          s.intent is NewDocumentIntent
        ).toList();

      case 'search':
        return _allShortcuts.where((s) =>
          s.intent is OpenSearchIntent
        ).toList();

      default:
        return _allShortcuts;
    }
  }

  /// Get shortcut for intent type
  KeyboardShortcut? getShortcutForIntent<T extends KeyboardIntent>() {
    return _intentToShortcut[T];
  }

  /// Get shortcuts map for Shortcuts widget
  Map<LogicalKeySet, Intent> getShortcutsMap() {
    return Map.unmodifiable(_shortcuts);
  }

  /// Get actions map for Actions widget
  Map<Type, Action<Intent>> getActionsMap() {
    return {
      // Node operations
      CreateChildNodeIntent: CallbackAction<CreateChildNodeIntent>(
        onInvoke: _handleCreateChildNode,
      ),
      CreateSiblingNodeIntent: CallbackAction<CreateSiblingNodeIntent>(
        onInvoke: _handleCreateSiblingNode,
      ),
      DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
        onInvoke: _handleDeleteNode,
      ),
      EditNodeIntent: CallbackAction<EditNodeIntent>(
        onInvoke: _handleEditNode,
      ),

      // Navigation
      SelectParentNodeIntent: CallbackAction<SelectParentNodeIntent>(
        onInvoke: _handleSelectParentNode,
      ),
      SelectChildNodeIntent: CallbackAction<SelectChildNodeIntent>(
        onInvoke: _handleSelectChildNode,
      ),
      SelectNextSiblingIntent: CallbackAction<SelectNextSiblingIntent>(
        onInvoke: _handleSelectNextSibling,
      ),
      SelectPreviousSiblingIntent: CallbackAction<SelectPreviousSiblingIntent>(
        onInvoke: _handleSelectPreviousSibling,
      ),

      // Document operations
      UndoIntent: CallbackAction<UndoIntent>(
        onInvoke: _handleUndo,
      ),
      RedoIntent: CallbackAction<RedoIntent>(
        onInvoke: _handleRedo,
      ),
      SaveDocumentIntent: CallbackAction<SaveDocumentIntent>(
        onInvoke: _handleSaveDocument,
      ),
      OpenDocumentIntent: CallbackAction<OpenDocumentIntent>(
        onInvoke: _handleOpenDocument,
      ),
      NewDocumentIntent: CallbackAction<NewDocumentIntent>(
        onInvoke: _handleNewDocument,
      ),

      // Search
      OpenSearchIntent: CallbackAction<OpenSearchIntent>(
        onInvoke: _handleOpenSearch,
      ),

      // Focus
      FocusCanvasIntent: CallbackAction<FocusCanvasIntent>(
        onInvoke: _handleFocusCanvas,
      ),
      EscapeIntent: CallbackAction<EscapeIntent>(
        onInvoke: _handleEscape,
      ),
    };
  }

  /// Setup keyboard shortcuts
  void _setupShortcuts() {
    _allShortcuts = [
      // Node creation and editing
      KeyboardShortcut(
        key: LogicalKeyboardKey.enter,
        intent: const CreateChildNodeIntent(),
        description: 'Create child node',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.tab,
        intent: const CreateSiblingNodeIntent(),
        description: 'Create sibling node',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.delete,
        intent: const DeleteNodeIntent(),
        description: 'Delete selected node',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.f2,
        intent: const EditNodeIntent(),
        description: 'Edit selected node',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.space,
        intent: const EditNodeIntent(),
        description: 'Edit selected node',
      ),

      // Navigation
      KeyboardShortcut(
        key: LogicalKeyboardKey.arrowUp,
        intent: const SelectParentNodeIntent(),
        description: 'Select parent node',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.arrowDown,
        intent: const SelectChildNodeIntent(),
        description: 'Select first child node',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.arrowRight,
        intent: const SelectNextSiblingIntent(),
        description: 'Select next sibling',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.arrowLeft,
        intent: const SelectPreviousSiblingIntent(),
        description: 'Select previous sibling',
      ),

      // Document operations
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyZ,
        intent: const UndoIntent(),
        description: 'Undo last action',
      ),
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyY,
        intent: const RedoIntent(),
        description: 'Redo last undone action',
      ),
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyZ,
        intent: const RedoIntent(),
        description: 'Redo last undone action',
        additionalModifiers: {LogicalKeyboardKey.shiftLeft},
      ),
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyS,
        intent: const SaveDocumentIntent(),
        description: 'Save document',
      ),
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyO,
        intent: const OpenDocumentIntent(),
        description: 'Open document',
      ),
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyN,
        intent: const NewDocumentIntent(),
        description: 'Create new document',
      ),

      // Search
      KeyboardShortcut.command(
        key: LogicalKeyboardKey.keyF,
        intent: const OpenSearchIntent(),
        description: 'Open search',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.f3,
        intent: const OpenSearchIntent(),
        description: 'Open search',
      ),

      // Focus and escape
      KeyboardShortcut(
        key: LogicalKeyboardKey.escape,
        intent: const EscapeIntent(),
        description: 'Cancel current operation',
      ),
      KeyboardShortcut(
        key: LogicalKeyboardKey.f6,
        intent: const FocusCanvasIntent(),
        description: 'Focus on canvas',
      ),
    ];

    // Filter shortcuts for current platform
    _allShortcuts = _allShortcuts.where((s) => s.isApplicableToPlatform).toList();

    // Build shortcuts map
    _shortcuts = {};
    _intentToShortcut = {};

    for (final shortcut in _allShortcuts) {
      final keySet = LogicalKeySet(shortcut.key, ...shortcut.modifiers);
      _shortcuts[keySet] = shortcut.intent;
      _intentToShortcut[shortcut.intent.runtimeType] = shortcut;
    }

    _logger.debug('KeyboardService: Setup ${_shortcuts.length} shortcuts');
  }

  /// Handle create child node
  void _handleCreateChildNode(CreateChildNodeIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap) return;

    final selectedNode = state.selectedNode;
    if (selectedNode != null) {
      notifier.createNode(
        parentId: selectedNode.id,
        text: 'New Node',
      );
      _logger.debug('Created child node via keyboard shortcut');
    }
  }

  /// Handle create sibling node
  void _handleCreateSiblingNode(CreateSiblingNodeIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap) return;

    final selectedNode = state.selectedNode;
    if (selectedNode != null && selectedNode.parentId != null) {
      notifier.createNode(
        parentId: selectedNode.parentId,
        text: 'New Node',
      );
      _logger.debug('Created sibling node via keyboard shortcut');
    }
  }

  /// Handle delete node
  void _handleDeleteNode(DeleteNodeIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap || !state.hasSelectedNode) return;

    final selectedNode = state.selectedNode;
    if (selectedNode != null && selectedNode.id != state.rootNode?.id) {
      notifier.deleteNode(selectedNode.id);
      _logger.debug('Deleted node via keyboard shortcut');
    }
  }

  /// Handle edit node
  void _handleEditNode(EditNodeIntent intent) {
    if (_ref == null) return;

    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap || !state.hasSelectedNode) return;

    // This would trigger edit mode in the UI
    // The actual implementation would depend on the widget architecture
    _logger.debug('Edit node triggered via keyboard shortcut');
  }

  /// Handle select parent node
  void _handleSelectParentNode(SelectParentNodeIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap || !state.hasSelectedNode) return;

    final selectedNode = state.selectedNode;
    if (selectedNode?.parentId != null) {
      notifier.selectNode(selectedNode!.parentId);
      _logger.debug('Selected parent node via keyboard shortcut');
    }
  }

  /// Handle select child node
  void _handleSelectChildNode(SelectChildNodeIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap || !state.hasSelectedNode) return;

    final selectedNode = state.selectedNode;
    if (selectedNode != null) {
      final children = state.getChildren(selectedNode.id);
      if (children.isNotEmpty) {
        notifier.selectNode(children.first.id);
        _logger.debug('Selected child node via keyboard shortcut');
      }
    }
  }

  /// Handle select next sibling
  void _handleSelectNextSibling(SelectNextSiblingIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap || !state.hasSelectedNode) return;

    final selectedNode = state.selectedNode;
    if (selectedNode?.parentId != null) {
      final siblings = state.getChildren(selectedNode!.parentId!);
      final currentIndex = siblings.indexWhere((n) => n.id == selectedNode.id);

      if (currentIndex >= 0 && currentIndex < siblings.length - 1) {
        notifier.selectNode(siblings[currentIndex + 1].id);
        _logger.debug('Selected next sibling via keyboard shortcut');
      }
    }
  }

  /// Handle select previous sibling
  void _handleSelectPreviousSibling(SelectPreviousSiblingIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (!state.hasMindmap || !state.hasSelectedNode) return;

    final selectedNode = state.selectedNode;
    if (selectedNode?.parentId != null) {
      final siblings = state.getChildren(selectedNode!.parentId!);
      final currentIndex = siblings.indexWhere((n) => n.id == selectedNode.id);

      if (currentIndex > 0) {
        notifier.selectNode(siblings[currentIndex - 1].id);
        _logger.debug('Selected previous sibling via keyboard shortcut');
      }
    }
  }

  /// Handle undo
  void _handleUndo(UndoIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (state.canUndo) {
      notifier.undo();
      _logger.debug('Undo triggered via keyboard shortcut');
    }
  }

  /// Handle redo
  void _handleRedo(RedoIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);
    final state = _ref!.read(mindmapStateProvider);

    if (state.canRedo) {
      notifier.redo();
      _logger.debug('Redo triggered via keyboard shortcut');
    }
  }

  /// Handle save document
  void _handleSaveDocument(SaveDocumentIntent intent) {
    if (_ref == null) return;

    final state = _ref!.read(mindmapStateProvider);

    if (state.hasMindmap && state.isDirty) {
      // This would trigger save dialog in the UI
      // The actual implementation would depend on the file service integration
      _logger.debug('Save document triggered via keyboard shortcut');
    }
  }

  /// Handle open document
  void _handleOpenDocument(OpenDocumentIntent intent) {
    if (_ref == null) return;

    // This would trigger open dialog in the UI
    _logger.debug('Open document triggered via keyboard shortcut');
  }

  /// Handle new document
  void _handleNewDocument(NewDocumentIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);

    // This would trigger new document creation
    notifier.createMindmap('New Mindmap');
    _logger.debug('New document triggered via keyboard shortcut');
  }

  /// Handle open search
  void _handleOpenSearch(OpenSearchIntent intent) {
    if (_ref == null) return;

    final state = _ref!.read(mindmapStateProvider);

    if (state.hasMindmap) {
      // This would trigger search interface in the UI
      _logger.debug('Open search triggered via keyboard shortcut');
    }
  }

  /// Handle focus canvas
  void _handleFocusCanvas(FocusCanvasIntent intent) {
    if (_ref == null) return;

    // This would focus the canvas widget
    _logger.debug('Focus canvas triggered via keyboard shortcut');
  }

  /// Handle escape
  void _handleEscape(EscapeIntent intent) {
    if (_ref == null) return;

    final notifier = _ref!.read(mindmapStateProvider.notifier);

    // Clear selection and search results
    notifier.clearSelection();
    notifier.clearSearch();
    _logger.debug('Escape triggered via keyboard shortcut');
  }
}

/// Provider for keyboard service
final keyboardServiceProvider = Provider<KeyboardService>((ref) {
  final service = KeyboardService.instance;
  service.initialize(ref);
  return service;
});

/// Provider for keyboard shortcuts map
final keyboardShortcutsProvider = Provider<Map<LogicalKeySet, Intent>>((ref) {
  final service = ref.watch(keyboardServiceProvider);
  return service.getShortcutsMap();
});

/// Provider for keyboard actions map
final keyboardActionsProvider = Provider<Map<Type, Action<Intent>>>((ref) {
  final service = ref.watch(keyboardServiceProvider);
  return service.getActionsMap();
});