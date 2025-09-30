/// Basic application menu for desktop platforms
///
/// A simple menu bar implementation focusing on essential functionality
/// without keyboard shortcuts for now.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mindmap_state.dart';
import '../screens/settings_screen.dart';
import '../services/file_service.dart';
import '../services/clipboard_service.dart';
import '../services/canvas_service.dart';
import '../services/fullscreen_service.dart';
import '../bridge/bridge_types.dart';

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
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyN,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('New'),
        ),
        MenuItemButton(
          onPressed: () => _handleOpen(context, ref),
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyO,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Open...'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: state.hasMindmap && state.isDirty ? () => _handleSave(context, ref) : null,
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyS,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Save'),
        ),
        MenuItemButton(
          onPressed: state.hasMindmap ? () => _handleSaveAs(context, ref) : null,
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyS,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
            shift: true,
          ),
          child: const Text('Save As...'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: state.hasMindmap ? () => _handleExportJSON(context, ref) : null,
              child: const Text('JSON'),
            ),
            MenuItemButton(
              onPressed: state.hasMindmap ? () => _handleExportXML(context, ref) : null,
              child: const Text('XML'),
            ),
            MenuItemButton(
              onPressed: state.hasMindmap ? () => _handleExportTXT(context, ref) : null,
              child: const Text('Plain Text'),
            ),
            MenuItemButton(
              onPressed: state.hasMindmap ? () => _handleExportHTML(context, ref) : null,
              child: const Text('HTML'),
            ),
          ],
          child: Text(
            'Export',
            style: TextStyle(
              color: state.hasMindmap ? null : Theme.of(context).disabledColor,
            ),
          ),
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
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Undo'),
        ),
        MenuItemButton(
          onPressed: state.canRedo ? () => _handleRedo(context, ref) : null,
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyY,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Redo'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: state.hasSelectedNode ? () => _handleCut(context, ref) : null,
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyX,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Cut'),
        ),
        MenuItemButton(
          onPressed: state.hasSelectedNode ? () => _handleCopy(context, ref) : null,
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyC,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Copy'),
        ),
        MenuItemButton(
          onPressed: () => _handlePaste(context, ref),
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyV,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
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
          shortcut: SingleActivator(
            LogicalKeyboardKey.equal,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Zoom In'),
        ),
        MenuItemButton(
          onPressed: () => _handleZoomOut(context, ref),
          shortcut: SingleActivator(
            LogicalKeyboardKey.minus,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Zoom Out'),
        ),
        MenuItemButton(
          onPressed: () => _handleZoomToFit(context, ref),
          shortcut: SingleActivator(
            LogicalKeyboardKey.digit0,
            meta: Platform.isMacOS,
            control: !Platform.isMacOS,
          ),
          child: const Text('Zoom to Fit'),
        ),
        const MenuItemButton(
          onPressed: null,
          child: Divider(),
        ),
        MenuItemButton(
          onPressed: () => _handleToggleFullScreen(context, ref),
          shortcut: const SingleActivator(LogicalKeyboardKey.f11),
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

  void _handleOpen(BuildContext context, WidgetRef ref) async {
    try {
      final fileService = FileService.instance;

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening file dialog...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final result = await fileService.pickFile(
        type: FileType.mindmap,
        allowedExtensions: ['json', 'mm'],
        dialogTitle: 'Open Mindmap',
      );

      if (!result.success) {
        if (result.error?.isNotEmpty == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open file: ${result.error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _handleOpen(context, ref),
              ),
            ),
          );
        }
        return;
      }

      if (result.data?.path != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading mindmap...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        final notifier = ref.read(mindmapStateProvider.notifier);
        await notifier.loadMindmap(result.data!.path);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully opened: ${result.data!.name}'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Report',
              onPressed: () => _showErrorDialog(context, 'Open File Error', e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _handleSave(BuildContext context, WidgetRef ref) async {
    try {
      final notifier = ref.read(mindmapStateProvider.notifier);
      final state = ref.read(mindmapStateProvider);

      if (state.lastSavedPath != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saving mindmap...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        await notifier.saveMindmap(state.lastSavedPath!);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mindmap saved successfully to ${state.lastSavedPath!.split('/').last}'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        _handleSaveAs(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleSave(context, ref),
            ),
          ),
        );
      }
    }
  }

  void _handleSaveAs(BuildContext context, WidgetRef ref) async {
    try {
      final state = ref.read(mindmapStateProvider);
      if (!state.hasMindmap) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No mindmap to save')),
          );
        }
        return;
      }

      final fileService = FileService.instance;

      // Create mindmap data as JSON
      final mindmapData = {
        'title': state.mindmapData?.title ?? 'Untitled Mindmap',
        'nodes': state.nodes.map((node) => {
          'id': node.id,
          'text': node.text,
          'position': {
            'x': node.position.x,
            'y': node.position.y,
          },
        }).toList(),
        'created': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      final jsonString = json.encode(mindmapData);
      final data = Uint8List.fromList(utf8.encode(jsonString));

      final result = await fileService.saveFile(
        data: data,
        fileName: '${state.mindmapData?.title ?? 'mindmap'}.json',
        dialogTitle: 'Save Mindmap As',
        type: FileType.mindmap,
        allowedExtensions: ['json'],
      );

      if (!result.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving file: ${result.error}')),
          );
        }
        return;
      }

      if (result.data != null) {
        final notifier = ref.read(mindmapStateProvider.notifier);
        await notifier.saveMindmap(result.data!);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved as: ${result.data!.split('/').last}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
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

  void _handleCut(BuildContext context, WidgetRef ref) async {
    try {
      final state = ref.read(mindmapStateProvider);
      final selectedNode = state.selectedNode;

      if (selectedNode == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No node selected to cut')),
          );
        }
        return;
      }

      // Get all descendants of the selected node
      final descendants = state.getDescendants(selectedNode.id);
      final nodesToCut = [selectedNode, ...descendants];

      // Cut to clipboard
      final clipboardService = ClipboardService.instance;
      await clipboardService.cutNodes(nodesToCut);

      if (context.mounted) {
        _showSuccessMessage(
          context,
          'Cut ${nodesToCut.length} node${nodesToCut.length == 1 ? '' : 's'}',
          details: 'Use Paste to move to a new location',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Cut Error', e.toString());
      }
    }
  }

  void _handleCopy(BuildContext context, WidgetRef ref) async {
    try {
      final state = ref.read(mindmapStateProvider);
      final selectedNode = state.selectedNode;

      if (selectedNode == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No node selected to copy')),
          );
        }
        return;
      }

      // Get all descendants of the selected node
      final descendants = state.getDescendants(selectedNode.id);
      final nodesToCopy = [selectedNode, ...descendants];

      // Copy to clipboard
      final clipboardService = ClipboardService.instance;
      await clipboardService.copyNodes(nodesToCopy);

      if (context.mounted) {
        _showSuccessMessage(
          context,
          'Copied ${nodesToCopy.length} node${nodesToCopy.length == 1 ? '' : 's'}',
          details: 'Use Paste to duplicate at a new location',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Copy Error', e.toString());
      }
    }
  }

  void _handlePaste(BuildContext context, WidgetRef ref) async {
    try {
      final clipboardService = ClipboardService.instance;
      final clipboardData = await clipboardService.getClipboardData();

      if (clipboardData == null || clipboardData.nodes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to paste')),
          );
        }
        return;
      }

      final state = ref.read(mindmapStateProvider);
      final notifier = ref.read(mindmapStateProvider.notifier);

      // Determine paste location
      final selectedNode = state.selectedNode;
      final pasteLocation = selectedNode?.position ?? const FfiPoint(x: 100, y: 100);

      // Generate new IDs for nodes to avoid conflicts
      final nodesToPaste = clipboardService.generateNewNodeIds(clipboardData.nodes);

      // Create the nodes through the bridge
      final bridge = ref.read(mindmapBridgeProvider);

      for (final node in nodesToPaste) {
        // Offset position to avoid overlap
        final offsetPosition = FfiPoint(
          x: pasteLocation.x + 50,
          y: pasteLocation.y + (nodesToPaste.indexOf(node) * 80),
        );

        await bridge.createNode(
          text: node.text,
          position: offsetPosition,
        );
      }

      // If this was a cut operation, we should delete the original nodes
      if (clipboardData.operation == ClipboardOperation.cut) {
        for (final originalNode in clipboardData.nodes) {
          try {
            await bridge.deleteNode(originalNode.id);
          } catch (e) {
            // Node might already be deleted, continue
          }
        }
        await clipboardService.clearClipboard();
      }

      // Refresh the mindmap state
      // Note: This would typically be handled by the state notifier
      // For now, we'll show a success message

      if (context.mounted) {
        final operation = clipboardData.operation == ClipboardOperation.cut ? 'Moved' : 'Pasted';
        _showSuccessMessage(
          context,
          '$operation ${nodesToPaste.length} node${nodesToPaste.length == 1 ? '' : 's'}',
          details: 'Nodes added to the mindmap',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Paste Error', e.toString());
      }
    }
  }

  void _handleZoomIn(BuildContext context, WidgetRef ref) {
    try {
      final canvasController = ref.read(canvasControllerProvider);
      canvasController.zoomIn();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoomed in to ${canvasController.zoomPercentage}%'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Zoom Error', e.toString());
      }
    }
  }

  void _handleZoomOut(BuildContext context, WidgetRef ref) {
    try {
      final canvasController = ref.read(canvasControllerProvider);
      canvasController.zoomOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoomed out to ${canvasController.zoomPercentage}%'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Zoom Error', e.toString());
      }
    }
  }

  void _handleZoomToFit(BuildContext context, WidgetRef ref) {
    try {
      final canvasController = ref.read(canvasControllerProvider);
      canvasController.zoomToFit();

      if (context.mounted) {
        _showSuccessMessage(
          context,
          'Zoomed to fit all content',
          details: 'Canvas adjusted to show entire mindmap',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Zoom Error', e.toString());
      }
    }
  }

  void _handleToggleFullScreen(BuildContext context, WidgetRef ref) {
    try {
      final fullscreenController = ref.read(fullscreenControllerProvider);
      fullscreenController.toggleFullscreen();

      if (context.mounted) {
        final isFullscreen = fullscreenController.isFullscreen;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFullscreen ? 'Entered fullscreen mode' : 'Exited fullscreen mode'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Fullscreen Error', e.toString());
      }
    }
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
            Text('File Operations:'),
            Text('  Ctrl/Cmd + N: New mindmap'),
            Text('  Ctrl/Cmd + O: Open mindmap'),
            Text('  Ctrl/Cmd + S: Save mindmap'),
            Text('  Ctrl/Cmd + Shift + S: Save As'),
            Text(''),
            Text('Edit Operations:'),
            Text('  Ctrl/Cmd + Z: Undo'),
            Text('  Ctrl/Cmd + Y: Redo'),
            Text('  Ctrl/Cmd + X: Cut'),
            Text('  Ctrl/Cmd + C: Copy'),
            Text('  Ctrl/Cmd + V: Paste'),
            Text(''),
            Text('View Operations:'),
            Text('  Ctrl/Cmd + +: Zoom In'),
            Text('  Ctrl/Cmd + -: Zoom Out'),
            Text('  Ctrl/Cmd + 0: Zoom to Fit'),
            Text('  F11: Toggle fullscreen'),
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

  // Export handlers
  void _handleExportJSON(BuildContext context, WidgetRef ref) async {
    await _exportAs(context, ref, 'json', _generateJSONExport);
  }

  void _handleExportXML(BuildContext context, WidgetRef ref) async {
    await _exportAs(context, ref, 'xml', _generateXMLExport);
  }

  void _handleExportTXT(BuildContext context, WidgetRef ref) async {
    await _exportAs(context, ref, 'txt', _generateTXTExport);
  }

  void _handleExportHTML(BuildContext context, WidgetRef ref) async {
    await _exportAs(context, ref, 'html', _generateHTMLExport);
  }

  Future<void> _exportAs(
    BuildContext context,
    WidgetRef ref,
    String extension,
    String Function(MindmapState) generator,
  ) async {
    try {
      final state = ref.read(mindmapStateProvider);
      if (!state.hasMindmap) return;

      final content = generator(state);
      final data = Uint8List.fromList(utf8.encode(content));

      final fileService = FileService.instance;
      final result = await fileService.saveFile(
        data: data,
        fileName: '${state.mindmapData?.title ?? 'mindmap'}.$extension',
        dialogTitle: 'Export Mindmap',
        type: FileType.any,
        allowedExtensions: [extension],
      );

      if (result.success && context.mounted) {
        _showSuccessMessage(
          context,
          'Export completed successfully',
          details: 'Exported as ${extension.toUpperCase()} format',
        );
      } else if (!result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${result.error ?? 'Unknown error'}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _exportAs(context, ref, extension, generator),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Export Error', e.toString());
      }
    }
  }

  String _generateJSONExport(MindmapState state) {
    final mindmapData = {
      'title': state.mindmapData?.title ?? 'Untitled Mindmap',
      'nodes': state.nodes.map((node) => {
        'id': node.id,
        'text': node.text,
        'position': {
          'x': node.position.x,
          'y': node.position.y,
        },
      }).toList(),
      'exported': DateTime.now().toIso8601String(),
      'version': '1.0',
      'format': 'JSON Export',
    };
    return const JsonEncoder.withIndent('  ').convert(mindmapData);
  }

  String _generateXMLExport(MindmapState state) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<mindmap title="${_escapeXml(state.mindmapData?.title ?? 'Untitled Mindmap')}" version="1.0" exported="${DateTime.now().toIso8601String()}">');
    buffer.writeln('  <nodes>');

    for (final node in state.nodes) {
      buffer.writeln('    <node id="${node.id}">');
      buffer.writeln('      <text>${_escapeXml(node.text)}</text>');
      buffer.writeln('      <position x="${node.position.x}" y="${node.position.y}" />');
      buffer.writeln('    </node>');
    }

    buffer.writeln('  </nodes>');
    buffer.writeln('</mindmap>');
    return buffer.toString();
  }

  String _generateTXTExport(MindmapState state) {
    final buffer = StringBuffer();
    buffer.writeln('MINDMAP: ${state.mindmapData?.title ?? 'Untitled Mindmap'}');
    buffer.writeln('Exported: ${DateTime.now().toString()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final node in state.nodes) {
      buffer.writeln('• ${node.text}');
      buffer.writeln('  Position: (${node.position.x.toStringAsFixed(1)}, ${node.position.y.toStringAsFixed(1)})');
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _generateHTMLExport(MindmapState state) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>${_escapeHtml(state.mindmapData?.title ?? 'Untitled Mindmap')}</title>');
    buffer.writeln('  <style>');
    buffer.writeln('    body { font-family: Arial, sans-serif; margin: 20px; }');
    buffer.writeln('    h1 { color: #333; border-bottom: 2px solid #ddd; }');
    buffer.writeln('    .node { margin: 10px 0; padding: 10px; border-left: 4px solid #007acc; background: #f9f9f9; }');
    buffer.writeln('    .node-id { font-size: 0.8em; color: #666; }');
    buffer.writeln('    .node-position { font-size: 0.8em; color: #999; }');
    buffer.writeln('    .export-info { margin-top: 30px; padding: 10px; background: #e9e9e9; font-size: 0.9em; }');
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <h1>${_escapeHtml(state.mindmapData?.title ?? 'Untitled Mindmap')}</h1>');

    for (final node in state.nodes) {
      buffer.writeln('  <div class="node">');
      buffer.writeln('    <strong>${_escapeHtml(node.text)}</strong>');
      buffer.writeln('    <div class="node-id">ID: ${node.id}</div>');
      buffer.writeln('    <div class="node-position">Position: (${node.position.x.toStringAsFixed(1)}, ${node.position.y.toStringAsFixed(1)})</div>');
      buffer.writeln('  </div>');
    }

    buffer.writeln('  <div class="export-info">');
    buffer.writeln('    <strong>Export Information:</strong><br>');
    buffer.writeln('    Generated: ${DateTime.now().toString()}<br>');
    buffer.writeln('    Total Nodes: ${state.nodes.length}<br>');
    buffer.writeln('    Format: HTML Export v1.0');
    buffer.writeln('  </div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    return buffer.toString();
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An error occurred while performing this operation:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please try again or contact support if the problem persists.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Could implement feedback/bug report feature here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error reporting feature would be implemented here'),
                ),
              );
            },
            child: const Text('Report Issue'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message, {String? details}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            if (details != null) ...[
              const SizedBox(height: 4),
              Text(
                details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}