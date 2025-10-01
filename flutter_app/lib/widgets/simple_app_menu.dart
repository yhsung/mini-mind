/// Simple application menu for desktop platforms
///
/// A streamlined menu bar implementation focusing on essential functionality
/// without the complexity of the full app menu system.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mindmap_state.dart';
import '../services/platform_service.dart';
import '../screens/settings_screen.dart';

/// Simple menu bar wrapper for desktop platforms
class SimpleAppMenuBar extends ConsumerWidget {
  const SimpleAppMenuBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show menu bar on desktop platforms
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return child;
    }

    final mindmapState = ref.watch(mindmapStateProvider);

    return Column(
      children: [
        MenuBar(
          children: [
            _buildFileMenu(context, ref, mindmapState),
            _buildEditMenu(context, ref, mindmapState),
            _buildViewMenu(context, ref, mindmapState),
            _buildHelpMenu(context),
          ],
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildFileMenu(BuildContext context, WidgetRef ref, MindmapState state) {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: () => _handleNew(context, ref),
          child: const Text('New'),
        ),
        MenuItemButton(
          onPressed: () => _handleOpen(context, ref),
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyO,
          ),
          child: const Text('Open...'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: state.hasMindmap && state.isDirty ? () => _handleSave(context, ref) : null,
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyS,
          ),
          child: const Text('Save'),
        ),
        MenuItemButton(
          onPressed: state.hasMindmap ? () => _handleSaveAs(context, ref) : null,
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.shiftLeft,
            LogicalKeyboardKey.keyS,
          ),
          child: const Text('Save As...'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: () => _handleSettings(context),
          child: const Text('Settings...'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: () => _handleQuit(context),
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyQ,
          ),
          child: const Text('Quit'),
        ),
      ],
      child: const Text('File'),
    );
  }

  Widget _buildEditMenu(BuildContext context, WidgetRef ref, MindmapState state) {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: state.canUndo ? () => _handleUndo(context, ref) : null,
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyZ,
          ),
          child: const Text('Undo'),
        ),
        MenuItemButton(
          onPressed: state.canRedo ? () => _handleRedo(context, ref) : null,
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyY,
          ),
          child: const Text('Redo'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: state.hasSelectedNode ? () => _handleCut(context, ref) : null,
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyX,
          ),
          child: const Text('Cut'),
        ),
        MenuItemButton(
          onPressed: state.hasSelectedNode ? () => _handleCopy(context, ref) : null,
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyC,
          ),
          child: const Text('Copy'),
        ),
        MenuItemButton(
          onPressed: () => _handlePaste(context, ref),
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyV,
          ),
          child: const Text('Paste'),
        ),
      ],
      child: const Text('Edit'),
    );
  }

  Widget _buildViewMenu(BuildContext context, WidgetRef ref, MindmapState state) {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: () => _handleZoomIn(context, ref),
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.equal,
          ),
          child: const Text('Zoom In'),
        ),
        MenuItemButton(
          onPressed: () => _handleZoomOut(context, ref),
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.minus,
          ),
          child: const Text('Zoom Out'),
        ),
        MenuItemButton(
          onPressed: () => _handleZoomToFit(context, ref),
          shortcut: LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.digit0,
          ),
          child: const Text('Zoom to Fit'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: () => _handleToggleFullScreen(context),
          shortcut: LogicalKeySet(LogicalKeyboardKey.f11),
          child: const Text('Full Screen'),
        ),
      ],
      child: const Text('View'),
    );
  }

  Widget _buildHelpMenu(BuildContext context) {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: () => _handleAbout(context),
          child: const Text('About'),
        ),
        MenuItemButton(
          onPressed: () => _handleKeyboardShortcuts(context),
          child: const Text('Keyboard Shortcuts'),
        ),
      ],
      child: const Text('Help'),
    );
  }

  // Menu action handlers
  void _handleNew(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.createNewMindmap();
  }

  void _handleOpen(BuildContext context, WidgetRef ref) {
    // Placeholder for file open dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open file functionality would be implemented here')),
    );
  }

  void _handleSave(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    final state = ref.read(mindmapStateProvider);
    if (state.lastSavedPath != null) {
      notifier.saveMindmap(state.lastSavedPath!);
    } else {
      _handleSaveAs(context, ref);
    }
  }

  void _handleSaveAs(BuildContext context, WidgetRef ref) {
    // Placeholder for save as dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save As functionality would be implemented here')),
    );
  }

  void _handleSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _handleQuit(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _handleUndo(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.undo();
  }

  void _handleRedo(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.redo();
  }

  void _handleCut(BuildContext context, WidgetRef ref) {
    // Placeholder for cut functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cut functionality would be implemented here')),
    );
  }

  void _handleCopy(BuildContext context, WidgetRef ref) {
    // Placeholder for copy functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copy functionality would be implemented here')),
    );
  }

  void _handlePaste(BuildContext context, WidgetRef ref) {
    // Placeholder for paste functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paste functionality would be implemented here')),
    );
  }

  void _handleZoomIn(BuildContext context, WidgetRef ref) {
    // Placeholder for zoom in functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zoom In functionality would be implemented here')),
    );
  }

  void _handleZoomOut(BuildContext context, WidgetRef ref) {
    // Placeholder for zoom out functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zoom Out functionality would be implemented here')),
    );
  }

  void _handleZoomToFit(BuildContext context, WidgetRef ref) {
    // Placeholder for zoom to fit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zoom to Fit functionality would be implemented here')),
    );
  }

  void _handleToggleFullScreen(BuildContext context) {
    // Placeholder for full screen toggle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full screen toggle would be implemented here')),
    );
  }

  void _handleAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Mindmap',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Mindmap Application',
      children: [
        const Text('A cross-platform mindmap application with Rust core engine and Flutter UI.'),
      ],
    );
  }

  void _handleKeyboardShortcuts(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ctrl/Cmd + N: New mindmap'),
            Text('Ctrl/Cmd + O: Open mindmap'),
            Text('Ctrl/Cmd + S: Save mindmap'),
            Text('Ctrl/Cmd + Z: Undo'),
            Text('Ctrl/Cmd + Y: Redo'),
            Text('F11: Toggle fullscreen'),
            Text('Ctrl/Cmd + F: Search'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}