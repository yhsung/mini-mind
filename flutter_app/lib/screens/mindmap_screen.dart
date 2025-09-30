/// Main mindmap screen providing the complete mindmap interface
///
/// This screen integrates the mindmap canvas with toolbars, menus, and
/// controls to provide a full-featured mindmap editing experience.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../widgets/mindmap_canvas.dart';
import '../widgets/layout_controls.dart';
import '../widgets/search_widget.dart';
import '../widgets/basic_app_menu.dart';
import '../state/mindmap_state.dart';
import '../state/app_state.dart';
import '../state/providers.dart';
import '../services/file_service.dart';
import '../services/fullscreen_service.dart';
import '../utils/platform_utils.dart';
import '../utils/error_handler.dart';
import '../bridge/bridge_types.dart';
import 'settings_screen.dart';

/// Main mindmap screen with canvas, toolbars, and controls
class MindmapScreen extends ConsumerStatefulWidget {
  const MindmapScreen({
    super.key,
    this.initialFile,
    this.enableDebugOverlay = false,
  });

  /// Optional file to load on startup
  final String? initialFile;

  /// Whether to show debug overlay
  final bool enableDebugOverlay;

  @override
  ConsumerState<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends ConsumerState<MindmapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late AnimationController _fadeController;
  late AnimationController _slideController;

  bool _showLayoutControls = true;
  bool _showSearch = false;
  bool _isFullscreen = false;
  String? _currentFilePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Initialize with fade in
    _fadeController.forward();

    // Setup fullscreen service
    _setupFullscreenService();

    // Load initial file if provided
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMindmapFile(widget.initialFile!);
      });
    } else {
      // Create a new mindmap by default
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _createNewMindmap();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _slideController.dispose();

    // Cleanup fullscreen service
    final fullscreenController = ref.read(fullscreenControllerProvider);
    fullscreenController.unregisterCallback();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Auto-save when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _autoSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mindmapState = ref.watch(mindmapStateProvider);
    final appState = ref.watch(appStateProvider);
    final config = AppConfig.instance.config;

    return BasicAppMenuBar(
      child: FadeTransition(
        opacity: _fadeController,
        child: Scaffold(
        backgroundColor: config.theme.themeMode == ThemeMode.dark
            ? Colors.grey[900]
            : Colors.grey[50],
        body: Stack(
          children: [
            // Main mindmap canvas
            _buildMainCanvas(context, mindmapState, config),

            // Top toolbar
            if (!_isFullscreen) _buildTopToolbar(context, mindmapState, config),

            // Side panels
            if (_showLayoutControls && !_isFullscreen)
              _buildLayoutControlsPanel(context, config),

            // Search overlay
            if (_showSearch) _buildSearchOverlay(context, config),

            // Status bar
            if (!_isFullscreen) _buildStatusBar(context, mindmapState, config),

            // Debug overlay
            if (widget.enableDebugOverlay && config.app.enableDebugMode)
              _buildDebugOverlay(context, mindmapState),

            // Loading overlay
            if (mindmapState.isLoading) _buildLoadingOverlay(context),
          ],
        ),
          floatingActionButton: _buildFloatingActionButton(context, config),
        ),
      ),
    );
  }

  Widget _buildMainCanvas(BuildContext context, MindmapState state, AppConfigData config) {
    return Positioned.fill(
      top: _isFullscreen ? 0 : 56, // Account for toolbar
      bottom: _isFullscreen ? 0 : 24, // Account for status bar
      child: Container(
        decoration: BoxDecoration(
          color: config.theme.themeMode == ThemeMode.dark
              ? Colors.grey[850]
              : Colors.white,
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
        child: MindmapCanvas(
          backgroundColor: config.theme.themeMode == ThemeMode.dark
              ? Colors.grey[850]!
              : Colors.white,
          showGrid: config.ui.enableGridSnap,
          gridColor: Theme.of(context).dividerColor.withOpacity(0.1),
          enableZoom: true,
          enablePan: true,
          minZoom: 0.1,
          maxZoom: 5.0,
          onNodeTapped: _onNodeTapped,
          onCanvasTapped: _onCanvasTapped,
          onNodeDragStart: _onNodeDragStart,
          onNodeDragUpdate: _onNodeDragUpdate,
          onNodeDragEnd: _onNodeDragEnd,
        ),
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, MindmapState state, AppConfigData config) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeInOut,
        )),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              // Menu button
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _showAppMenu(context),
                tooltip: 'Menu',
              ),

              // File operations
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createNewMindmap,
                tooltip: 'New Mindmap (${PlatformUtils.modifierKey}+N)',
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _openMindmap,
                tooltip: 'Open (${PlatformUtils.modifierKey}+O)',
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveMindmap,
                tooltip: 'Save (${PlatformUtils.modifierKey}+S)',
              ),

              const VerticalDivider(),

              // Edit operations
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: state.canUndo ? _undo : null,
                tooltip: 'Undo (${PlatformUtils.modifierKey}+Z)',
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: state.canRedo ? _redo : null,
                tooltip: 'Redo (${PlatformUtils.modifierKey}+Y)',
              ),

              const VerticalDivider(),

              // Layout controls
              IconButton(
                icon: Icon(_showLayoutControls ? Icons.close_fullscreen : Icons.tune),
                onPressed: () => setState(() => _showLayoutControls = !_showLayoutControls),
                tooltip: 'Layout Controls',
              ),

              // Search
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _showSearch = !_showSearch),
                tooltip: 'Search (${PlatformUtils.modifierKey}+F)',
              ),

              const Spacer(),

              // View controls
              IconButton(
                icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                onPressed: _toggleFullscreen,
                tooltip: 'Toggle Fullscreen (F11)',
              ),

              // Settings
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutControlsPanel(BuildContext context, AppConfigData config) {
    return Positioned(
      top: 56,
      right: 0,
      width: 280,
      height: MediaQuery.of(context).size.height - 80,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeInOut,
        )),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              left: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(-2, 0),
                blurRadius: 4,
              ),
            ],
          ),
          child: const MindmapLayoutControls()
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context, AppConfigData config) {
    return Positioned(
      top: 56,
      left: 0,
      right: _showLayoutControls ? 280 : 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: MindmapSearchWidget(
          onSearchClosed: () => setState(() => _showSearch = false),
          onSearchResult: _onSearchResult,
        )
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, MindmapState state, AppConfigData config) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          children: [
            // Node count
            Text(
              '${state.nodes.length} nodes',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(width: 16),

            // Selected node info
            if (state.selectedNodeId != null)
              Text(
                'Selected: ${state.selectedNodeId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),

            const Spacer(),

            // File status
            if (_currentFilePath != null)
              Text(
                'File: ${_currentFilePath!.split('/').last}',
                style: Theme.of(context).textTheme.bodySmall,
              ),

            // Modified indicator
            if (state.isDirty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugOverlay(BuildContext context, MindmapState state) {
    return Positioned(
      top: 80,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Info',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Nodes: ${state.nodes.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
            ),
            Text(
              'Selected: ${state.selectedNodeId ?? 'None'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
            ),
            Text(
              'Layout: Active',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading mindmap...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, AppConfigData config) {
    if (!PlatformUtils.isMobile || _isFullscreen) return null;

    return FloatingActionButton(
      onPressed: _addNewNode,
      tooltip: 'Add Node',
      child: const Icon(Icons.add),
    );
  }

  // Event handlers
  void _onNodeTapped(dynamic node) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.selectNode(node.id as String);
  }

  void _onCanvasTapped(Offset position) {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.clearSelection();
  }

  void _onNodeDragStart(dynamic node, Offset position) {
    // Handle node drag start
  }

  void _onNodeDragUpdate(dynamic node, Offset position) {
    // Handle node drag update
  }

  void _onNodeDragEnd(dynamic node, Offset position) {
    // Handle node drag end
    final notifier = ref.read(mindmapStateProvider.notifier);
    final ffiPosition = FfiPoint(x: position.dx, y: position.dy);
    notifier.updateNodePosition(node.id as String, ffiPosition);
  }

  void _onSearchResult(List<dynamic> searchResults) {
    // Handle search result selection - for now just select the first result
    if (searchResults.isNotEmpty) {
      final notifier = ref.read(mindmapStateProvider.notifier);
      final firstResult = searchResults.first;
      if (firstResult.node?.id != null) {
        notifier.selectNode(firstResult.node.id as String);
      }
    }
  }

  // Actions
  Future<void> _createNewMindmap() async {
    try {
      final notifier = ref.read(mindmapStateProvider.notifier);
      await notifier.createMindmap('New Mindmap');
      setState(() {
        _currentFilePath = null;
      });
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'create_new_mindmap'},
      );
    }
  }

  Future<void> _openMindmap() async {
    try {
      final fileService = FileService();
      final result = await fileService.pickFile(
        allowedExtensions: ['json', 'mm', 'opml'],
        dialogTitle: 'Open Mindmap',
      );

      if (result.success && result.data != null) {
        await _loadMindmapFile(result.data!.path);
      }
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'open_mindmap'},
      );
    }
  }

  Future<void> _loadMindmapFile(String filePath) async {
    try {
      final notifier = ref.read(mindmapStateProvider.notifier);
      await notifier.loadMindmap(filePath);
      setState(() {
        _currentFilePath = filePath;
      });
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {
          'operation': 'load_mindmap_file',
          'file_path': filePath,
        },
      );
    }
  }

  Future<void> _saveMindmap() async {
    try {
      final notifier = ref.read(mindmapStateProvider.notifier);

      if (_currentFilePath != null) {
        await notifier.saveMindmap(_currentFilePath!);
      } else {
        await _saveAsMindmap();
      }
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'save_mindmap'},
      );
    }
  }

  Future<void> _saveAsMindmap() async {
    try {
      final fileService = FileService();
      final result = await fileService.saveFile(
        fileName: 'mindmap.json',
        data: Uint8List(0), // Empty data for now
        dialogTitle: 'Save Mindmap',
      );

      if (result.success && result.data != null) {
        final notifier = ref.read(mindmapStateProvider.notifier);
        await notifier.saveMindmap(result.data!);
        setState(() {
          _currentFilePath = result.data!;
        });
      }
    } catch (e, stackTrace) {
      await GlobalErrorHandler.instance.handleError(
        e,
        stackTrace,
        context: context,
        additionalContext: {'operation': 'save_as_mindmap'},
      );
    }
  }

  Future<void> _autoSave() async {
    final config = AppConfig.instance.config;
    if (!config.app.autoSave || _currentFilePath == null) return;

    try {
      final notifier = ref.read(mindmapStateProvider.notifier);
      await notifier.saveMindmap(_currentFilePath!);
    } catch (e) {
      // Silent auto-save failure - don't disrupt user
    }
  }

  void _undo() {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.undo();
  }

  void _redo() {
    final notifier = ref.read(mindmapStateProvider.notifier);
    notifier.redo();
  }

  void _addNewNode() {
    final notifier = ref.read(mindmapStateProvider.notifier);
    // Use the FfiPoint type from bridge_types.dart
    final position = FfiPoint(x: 100.0, y: 100.0);
    notifier.createNode(text: 'New Node', position: position);
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      _slideController.reverse();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _slideController.forward();
    }

    // Update fullscreen service state
    final fullscreenController = ref.read(fullscreenControllerProvider);
    fullscreenController.updateState(_isFullscreen);
  }

  void _showAppMenu(BuildContext context) {
    // App menu is now integrated via AppMenuBar wrapper
    // This method can be used for mobile context menu if needed
    if (PlatformUtils.isMobile) {
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSettings(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _setupFullscreenService() {
    final fullscreenController = ref.read(fullscreenControllerProvider);
    fullscreenController.registerToggleCallback(_toggleFullscreen);
  }
}