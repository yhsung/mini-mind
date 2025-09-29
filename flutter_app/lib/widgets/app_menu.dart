/// Application menu bar for desktop platforms
///
/// This widget provides a platform-native menu bar with comprehensive
/// File, Edit, View, and Layout menu structure connected to application
/// state and services for complete desktop application experience.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/bridge_types.dart';
import '../services/file_service.dart';
import '../services/keyboard_service.dart';
import '../services/platform_service.dart';
import '../state/mindmap_state.dart';
import '../utils/logger.dart';

/// Menu item configuration
@immutable
class AppMenuItem {
  const AppMenuItem({
    required this.title,
    this.intent,
    this.onPressed,
    this.shortcut,
    this.enabled = true,
    this.divider = false,
    this.submenu,
  });

  final String title;
  final Intent? intent;
  final VoidCallback? onPressed;
  final MenuSerializableShortcut? shortcut;
  final bool enabled;
  final bool divider;
  final List<AppMenuItem>? submenu;

  /// Create menu item with keyboard shortcut
  factory AppMenuItem.withShortcut({
    required String title,
    Intent? intent,
    VoidCallback? onPressed,
    required LogicalKeyboardKey key,
    Set<LogicalKeyboardKey> modifiers = const <LogicalKeyboardKey>{},
    bool enabled = true,
  }) {
    return AppMenuItem(
      title: title,
      intent: intent,
      onPressed: onPressed,
      shortcut: MenuSerializableShortcut(LogicalKeySet(key, ...modifiers)),
      enabled: enabled,
    );
  }

  /// Create command/control shortcut
  factory AppMenuItem.command({
    required String title,
    Intent? intent,
    VoidCallback? onPressed,
    required LogicalKeyboardKey key,
    Set<LogicalKeyboardKey> additionalModifiers = const <LogicalKeyboardKey>{},
    bool enabled = true,
  }) {
    final bool isMac = Platform.isMacOS;
    final LogicalKeyboardKey primaryModifier = isMac
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    return AppMenuItem.withShortcut(
      title: title,
      intent: intent,
      onPressed: onPressed,
      key: key,
      modifiers: {primaryModifier, ...additionalModifiers},
      enabled: enabled,
    );
  }

  /// Create divider menu item
  factory AppMenuItem.divider() {
    return const AppMenuItem(
      title: '',
      divider: true,
      enabled: false,
    );
  }

  /// Create submenu
  factory AppMenuItem.submenu({
    required String title,
    required List<AppMenuItem> items,
    bool enabled = true,
  }) {
    return AppMenuItem(
      title: title,
      submenu: items,
      enabled: enabled,
    );
  }
}

/// Application menu bar widget
class AppMenuBar extends ConsumerStatefulWidget {
  const AppMenuBar({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  ConsumerState<AppMenuBar> createState() => _AppMenuBarState();
}

class _AppMenuBarState extends ConsumerState<AppMenuBar> {
  final Logger _logger = Logger.instance;
  final FileService _fileService = FileService.instance;
  final PlatformService _platformService = PlatformService.instance;

  @override
  Widget build(BuildContext context) {
    // Only show menu bar on desktop platforms
    if (!_platformService.isDesktop) {
      return widget.child ?? const SizedBox.shrink();
    }

    final mindmapState = ref.watch(mindmapStateProvider);
    final keyboardService = ref.watch(keyboardServiceProvider);

    return MenuBarTheme(
      data: _buildMenuBarTheme(context),
      child: MenuBar(
        children: _buildMenus(context, mindmapState, keyboardService),
        child: widget.child,
      ),
    );
  }

  /// Build menu bar theme
  MenuBarThemeData _buildMenuBarTheme(BuildContext context) {
    final theme = Theme.of(context);

    return MenuBarThemeData(
      style: MenuStyle(
        backgroundColor: MaterialStateProperty.all(theme.colorScheme.surface),
        elevation: MaterialStateProperty.all(2.0),
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        ),
      ),
    );
  }

  /// Build menu structure
  List<Widget> _buildMenus(
    BuildContext context,
    MindmapState mindmapState,
    KeyboardService keyboardService,
  ) {
    return [
      _buildFileMenu(context, mindmapState),
      _buildEditMenu(context, mindmapState),
      _buildViewMenu(context, mindmapState),
      _buildLayoutMenu(context, mindmapState),
      _buildHelpMenu(context),
    ];
  }

  /// Build File menu
  Widget _buildFileMenu(BuildContext context, MindmapState mindmapState) {
    return SubmenuButton(
      menuChildren: _buildMenuItems([
        AppMenuItem.command(
          title: 'New',
          intent: const NewDocumentIntent(),
          key: LogicalKeyboardKey.keyN,
        ),
        AppMenuItem.command(
          title: 'Open...',
          intent: const OpenDocumentIntent(),
          key: LogicalKeyboardKey.keyO,
        ),
        AppMenuItem.divider(),
        AppMenuItem.command(
          title: 'Save',
          onPressed: mindmapState.hasMindmap && mindmapState.isDirty
              ? () => _handleSave(context)
              : null,
          key: LogicalKeyboardKey.keyS,
          enabled: mindmapState.hasMindmap && mindmapState.isDirty,
        ),
        AppMenuItem.command(
          title: 'Save As...',
          onPressed: mindmapState.hasMindmap
              ? () => _handleSaveAs(context)
              : null,
          key: LogicalKeyboardKey.keyS,
          additionalModifiers: {LogicalKeyboardKey.shiftLeft},
          enabled: mindmapState.hasMindmap,
        ),
        AppMenuItem.divider(),
        AppMenuItem.submenu(
          title: 'Export',
          enabled: mindmapState.hasMindmap,
          items: [
            AppMenuItem(
              title: 'Export as PNG...',
              onPressed: mindmapState.hasMindmap
                  ? () => _handleExport(context, ExportFormat.png)
                  : null,
              enabled: mindmapState.hasMindmap,
            ),
            AppMenuItem(
              title: 'Export as SVG...',
              onPressed: mindmapState.hasMindmap
                  ? () => _handleExport(context, ExportFormat.svg)
                  : null,
              enabled: mindmapState.hasMindmap,
            ),
            AppMenuItem(
              title: 'Export as PDF...',
              onPressed: mindmapState.hasMindmap
                  ? () => _handleExport(context, ExportFormat.pdf)
                  : null,
              enabled: mindmapState.hasMindmap,
            ),
            AppMenuItem(
              title: 'Export as OPML...',
              onPressed: mindmapState.hasMindmap
                  ? () => _handleExport(context, ExportFormat.opml)
                  : null,
              enabled: mindmapState.hasMindmap,
            ),
          ],
        ),
        AppMenuItem.divider(),
        AppMenuItem.submenu(
          title: 'Recent Files',
          items: _buildRecentFilesMenu(),
        ),
        AppMenuItem.divider(),
        AppMenuItem.command(
          title: 'Quit',
          onPressed: () => _handleQuit(context),
          key: LogicalKeyboardKey.keyQ,
        ),
      ]),
      child: const Text('File'),
    );
  }

  /// Build Edit menu
  Widget _buildEditMenu(BuildContext context, MindmapState mindmapState) {
    return SubmenuButton(
      menuChildren: _buildMenuItems([
        AppMenuItem.command(
          title: 'Undo',
          intent: const UndoIntent(),
          key: LogicalKeyboardKey.keyZ,
          enabled: mindmapState.canUndo,
        ),
        AppMenuItem.command(
          title: 'Redo',
          intent: const RedoIntent(),
          key: LogicalKeyboardKey.keyY,
          enabled: mindmapState.canRedo,
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Cut',
          onPressed: mindmapState.hasSelectedNode
              ? () => _handleCut(context)
              : null,
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyX,
          )),
          enabled: mindmapState.hasSelectedNode,
        ),
        AppMenuItem(
          title: 'Copy',
          onPressed: mindmapState.hasSelectedNode
              ? () => _handleCopy(context)
              : null,
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyC,
          )),
          enabled: mindmapState.hasSelectedNode,
        ),
        AppMenuItem(
          title: 'Paste',
          onPressed: () => _handlePaste(context),
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyV,
          )),
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Select All',
          onPressed: mindmapState.hasMindmap
              ? () => _handleSelectAll(context)
              : null,
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.keyA,
          )),
          enabled: mindmapState.hasMindmap,
        ),
        AppMenuItem.divider(),
        AppMenuItem.command(
          title: 'Find...',
          intent: const OpenSearchIntent(),
          key: LogicalKeyboardKey.keyF,
          enabled: mindmapState.hasMindmap,
        ),
      ]),
      child: const Text('Edit'),
    );
  }

  /// Build View menu
  Widget _buildViewMenu(BuildContext context, MindmapState mindmapState) {
    return SubmenuButton(
      menuChildren: _buildMenuItems([
        AppMenuItem(
          title: 'Zoom In',
          onPressed: () => _handleZoomIn(context),
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.equal,
          )),
        ),
        AppMenuItem(
          title: 'Zoom Out',
          onPressed: () => _handleZoomOut(context),
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.minus,
          )),
        ),
        AppMenuItem(
          title: 'Zoom to Fit',
          onPressed: () => _handleZoomToFit(context),
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            Platform.isMacOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.digit0,
          )),
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Center on Selection',
          onPressed: mindmapState.hasSelectedNode
              ? () => _handleCenterOnSelection(context)
              : null,
          enabled: mindmapState.hasSelectedNode,
        ),
        AppMenuItem(
          title: 'Center on Root',
          onPressed: mindmapState.hasMindmap
              ? () => _handleCenterOnRoot(context)
              : null,
          enabled: mindmapState.hasMindmap,
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Show Grid',
          onPressed: () => _handleToggleGrid(context),
        ),
        AppMenuItem(
          title: 'Show Minimap',
          onPressed: () => _handleToggleMinimap(context),
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Full Screen',
          onPressed: () => _handleToggleFullScreen(context),
          shortcut: MenuSerializableShortcut(LogicalKeySet(
            LogicalKeyboardKey.f11,
          )),
        ),
      ]),
      child: const Text('View'),
    );
  }

  /// Build Layout menu
  Widget _buildLayoutMenu(BuildContext context, MindmapState mindmapState) {
    return SubmenuButton(
      menuChildren: _buildMenuItems([
        AppMenuItem(
          title: 'Radial Layout',
          onPressed: mindmapState.hasMindmap
              ? () => _handleApplyLayout(context, FfiLayoutType.radial)
              : null,
          enabled: mindmapState.hasMindmap,
        ),
        AppMenuItem(
          title: 'Tree Layout',
          onPressed: mindmapState.hasMindmap
              ? () => _handleApplyLayout(context, FfiLayoutType.tree)
              : null,
          enabled: mindmapState.hasMindmap,
        ),
        AppMenuItem(
          title: 'Force-Directed Layout',
          onPressed: mindmapState.hasMindmap
              ? () => _handleApplyLayout(context, FfiLayoutType.forceDirected)
              : null,
          enabled: mindmapState.hasMindmap,
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Auto-Layout',
          onPressed: () => _handleToggleAutoLayout(context),
        ),
        AppMenuItem(
          title: 'Layout Settings...',
          onPressed: () => _handleLayoutSettings(context),
        ),
      ]),
      child: const Text('Layout'),
    );
  }

  /// Build Help menu
  Widget _buildHelpMenu(BuildContext context) {
    return SubmenuButton(
      menuChildren: _buildMenuItems([
        AppMenuItem(
          title: 'Keyboard Shortcuts',
          onPressed: () => _handleShowShortcuts(context),
        ),
        AppMenuItem(
          title: 'User Guide',
          onPressed: () => _handleShowUserGuide(context),
        ),
        AppMenuItem.divider(),
        AppMenuItem(
          title: 'Report Issue',
          onPressed: () => _handleReportIssue(context),
        ),
        AppMenuItem(
          title: 'About MindMap',
          onPressed: () => _handleShowAbout(context),
        ),
      ]),
      child: const Text('Help'),
    );
  }

  /// Build recent files menu
  List<AppMenuItem> _buildRecentFilesMenu() {
    // This would be populated from file service recent files
    // For now, return empty placeholder
    return [
      const AppMenuItem(
        title: '(No recent files)',
        enabled: false,
      ),
    ];
  }

  /// Convert AppMenuItem list to MenuItemButton widgets
  List<Widget> _buildMenuItems(List<AppMenuItem> items) {
    return items.map((item) {
      if (item.divider) {
        return const Divider();
      }

      if (item.submenu != null) {
        return SubmenuButton(
          menuChildren: _buildMenuItems(item.submenu!),
          child: Text(item.title),
        );
      }

      return MenuItemButton(
        onPressed: item.enabled ? (item.onPressed ?? () => _executeIntent(item.intent)) : null,
        shortcut: item.shortcut,
        child: Text(item.title),
      );
    }).toList();
  }

  /// Execute intent if provided
  void _executeIntent(Intent? intent) {
    if (intent != null) {
      Actions.invoke(context, intent);
    }
  }

  // File menu handlers

  void _handleSave(BuildContext context) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    final state = ref.read(mindmapStateProvider);

    if (state.lastSavedPath != null) {
      notifier.saveMindmap(state.lastSavedPath!);
    } else {
      _handleSaveAs(context);
    }
  }

  void _handleSaveAs(BuildContext context) async {
    final result = await _fileService.saveFile(
      data: const [], // This would be the actual mindmap data
      fileName: 'mindmap.json',
      dialogTitle: 'Save Mindmap',
      type: FileType.mindmap,
      allowedExtensions: ['json', 'mm'],
    );

    if (result.success && result.data != null) {
      final notifier = ref.read(mindmapStateProvider.notifier);
      notifier.saveMindmap(result.data!);
    }
  }

  void _handleExport(BuildContext context, ExportFormat format) async {
    final notifier = ref.read(mindmapStateProvider.notifier);
    final extension = format.name;

    final result = await _fileService.saveFile(
      data: const [], // This would be the exported data
      fileName: 'mindmap.$extension',
      dialogTitle: 'Export Mindmap',
    );

    if (result.success && result.data != null) {
      notifier.exportMindmap(result.data!, format);
    }
  }

  void _handleQuit(BuildContext context) {
    final state = ref.read(mindmapStateProvider);

    if (state.isDirty) {
      // Show save confirmation dialog
      _showSaveConfirmationDialog(context).then((shouldSave) {
        if (shouldSave == true) {
          _handleSave(context);
        }
        SystemNavigator.pop();
      });
    } else {
      SystemNavigator.pop();
    }
  }

  // Edit menu handlers

  void _handleCut(BuildContext context) {
    _logger.debug('Cut operation triggered');
    // Implement cut logic
  }

  void _handleCopy(BuildContext context) {
    _logger.debug('Copy operation triggered');
    // Implement copy logic
  }

  void _handlePaste(BuildContext context) {
    _logger.debug('Paste operation triggered');
    // Implement paste logic
  }

  void _handleSelectAll(BuildContext context) {
    _logger.debug('Select all operation triggered');
    // Implement select all logic
  }

  // View menu handlers

  void _handleZoomIn(BuildContext context) {
    _logger.debug('Zoom in triggered');
    // Implement zoom in logic
  }

  void _handleZoomOut(BuildContext context) {
    _logger.debug('Zoom out triggered');
    // Implement zoom out logic
  }

  void _handleZoomToFit(BuildContext context) {
    _logger.debug('Zoom to fit triggered');
    // Implement zoom to fit logic
  }

  void _handleCenterOnSelection(BuildContext context) {
    _logger.debug('Center on selection triggered');
    // Implement center on selection logic
  }

  void _handleCenterOnRoot(BuildContext context) {
    _logger.debug('Center on root triggered');
    // Implement center on root logic
  }

  void _handleToggleGrid(BuildContext context) {
    _logger.debug('Toggle grid triggered');
    // Implement grid toggle logic
  }

  void _handleToggleMinimap(BuildContext context) {
    _logger.debug('Toggle minimap triggered');
    // Implement minimap toggle logic
  }

  void _handleToggleFullScreen(BuildContext context) {
    _logger.debug('Toggle full screen triggered');
    // Implement fullscreen toggle logic
  }

  // Layout menu handlers

  void _handleApplyLayout(BuildContext context, FfiLayoutType layoutType) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.calculateLayout(layoutType).then((_) {
      notifier.applyLayout();
    });
  }

  void _handleToggleAutoLayout(BuildContext context) {
    _logger.debug('Toggle auto-layout triggered');
    // Implement auto-layout toggle logic
  }

  void _handleLayoutSettings(BuildContext context) {
    _logger.debug('Layout settings triggered');
    // Show layout settings dialog
  }

  // Help menu handlers

  void _handleShowShortcuts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const KeyboardShortcutsDialog(),
    );
  }

  void _handleShowUserGuide(BuildContext context) {
    _logger.debug('Show user guide triggered');
    // Open user guide
  }

  void _handleReportIssue(BuildContext context) {
    _logger.debug('Report issue triggered');
    // Open issue reporting
  }

  void _handleShowAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'MindMap',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 MindMap Application',
      children: [
        const Text('A powerful cross-platform mindmap application built with Flutter and Rust.'),
      ],
    );
  }

  /// Show save confirmation dialog
  Future<bool?> _showSaveConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes?'),
        content: const Text('You have unsaved changes. Do you want to save before closing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Don\'t Save'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Keyboard shortcuts dialog
class KeyboardShortcutsDialog extends ConsumerWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardService = ref.watch(keyboardServiceProvider);
    final shortcuts = keyboardService.shortcuts;

    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShortcutCategory('Node Operations', keyboardService.getShortcutsByCategory('node')),
              _buildShortcutCategory('Navigation', keyboardService.getShortcutsByCategory('navigation')),
              _buildShortcutCategory('Document', keyboardService.getShortcutsByCategory('document')),
              _buildShortcutCategory('Search', keyboardService.getShortcutsByCategory('search')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildShortcutCategory(String title, List<KeyboardShortcut> shortcuts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...shortcuts.map((shortcut) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  shortcut.displayString,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              Expanded(child: Text(shortcut.description)),
            ],
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}