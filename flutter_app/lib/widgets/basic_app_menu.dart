/// Basic application menu for desktop platforms
///
/// A simple menu bar implementation focusing on essential functionality
/// without keyboard shortcuts for now.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mindmap_state.dart';
import '../screens/settings_screen.dart';

/// Basic menu bar wrapper for desktop platforms
class BasicAppMenuBar extends ConsumerWidget {
  const BasicAppMenuBar({
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
          child: const Text('Open...'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: state.hasMindmap && state.isDirty ? () => _handleSave(context, ref) : null,
          child: const Text('Save'),
        ),
        MenuItemButton(
          onPressed: state.hasMindmap ? () => _handleSaveAs(context, ref) : null,
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
      ],
      child: const Text('File'),
    );
  }

  Widget _buildEditMenu(BuildContext context, WidgetRef ref, MindmapState state) {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: state.canUndo ? () => _handleUndo(context, ref) : null,
          child: const Text('Undo'),
        ),
        MenuItemButton(
          onPressed: state.canRedo ? () => _handleRedo(context, ref) : null,
          child: const Text('Redo'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: state.hasSelectedNode ? () => _handleCut(context, ref) : null,
          child: const Text('Cut'),
        ),
        MenuItemButton(
          onPressed: state.hasSelectedNode ? () => _handleCopy(context, ref) : null,
          child: const Text('Copy'),
        ),
        MenuItemButton(
          onPressed: () => _handlePaste(context, ref),
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
          child: const Text('Zoom In'),
        ),
        MenuItemButton(
          onPressed: () => _handleZoomOut(context, ref),
          child: const Text('Zoom Out'),
        ),
        MenuItemButton(
          onPressed: () => _handleZoomToFit(context, ref),
          child: const Text('Zoom to Fit'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: () => _handleToggleFullScreen(context),
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
    notifier.createMindmap('New Mindmap');
  }

  void _handleOpen(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open file functionality will be implemented')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save As functionality will be implemented')),
    );
  }

  void _handleSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(),
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cut functionality will be implemented')),
    );
  }

  void _handleCopy(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copy functionality will be implemented')),
    );
  }

  void _handlePaste(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paste functionality will be implemented')),
    );
  }

  void _handleZoomIn(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zoom In functionality will be implemented')),
    );
  }

  void _handleZoomOut(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zoom Out functionality will be implemented')),
    );
  }

  void _handleZoomToFit(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zoom to Fit functionality will be implemented')),
    );
  }

  void _handleToggleFullScreen(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full screen toggle will be implemented')),
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