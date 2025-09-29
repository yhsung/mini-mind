/// Welcome screen that provides an entry point to the mindmap application
///
/// This screen offers options to create new mindmaps, open existing ones,
/// and access settings. It serves as a landing page before entering the
/// main mindmap interface.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/platform_utils.dart';
import 'mindmap_screen.dart';
import 'settings_screen.dart';

/// Welcome screen with create/open options
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = AppConfig.instance.config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mindmap'),
        actions: [
          if (PlatformUtils.supportsKeyboardShortcuts)
            IconButton(
              icon: const Icon(Icons.keyboard),
              onPressed: () => _showKeyboardShortcuts(context),
              tooltip: 'Keyboard Shortcuts',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: PlatformUtils.defaultPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_tree,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: PlatformUtils.defaultSpacing * 2),
              Text(
                'Welcome to Mindmap',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: PlatformUtils.defaultSpacing),
              Text(
                'A cross-platform mindmap application with Rust core engine and Flutter UI.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: PlatformUtils.defaultSpacing * 3),
              Wrap(
                spacing: PlatformUtils.defaultSpacing,
                runSpacing: PlatformUtils.defaultSpacing,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _createNewMindmap(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New Mindmap'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openMindmap(context),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open Mindmap'),
                  ),
                ],
              ),
              SizedBox(height: PlatformUtils.defaultSpacing * 2),
              _buildPlatformInfo(context),
            ],
          ),
        ),
      ),
      floatingActionButton: PlatformUtils.isMobile
          ? FloatingActionButton(
              onPressed: () => _createNewMindmap(context),
              tooltip: 'Create New Mindmap',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildPlatformInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(PlatformUtils.defaultSpacing),
        child: Column(
          children: [
            Text(
              'Platform Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: PlatformUtils.defaultSpacing / 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Platform:', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  PlatformUtils.platformName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Touch Primary:', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  PlatformUtils.isTouchPrimary ? 'Yes' : 'No',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('File System:', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  PlatformUtils.supportsFileSystem ? 'Supported' : 'Not Supported',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createNewMindmap(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const MindmapScreen(),
      ),
    );
  }

  void _openMindmap(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const MindmapScreen(),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showKeyboardShortcuts(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${PlatformUtils.modifierKey} + N: New mindmap'),
            Text('${PlatformUtils.modifierKey} + O: Open mindmap'),
            Text('${PlatformUtils.modifierKey} + S: Save mindmap'),
            Text('${PlatformUtils.modifierKey} + Z: Undo'),
            Text('${PlatformUtils.modifierKey} + Y: Redo'),
            Text('F11: Toggle fullscreen'),
            Text('${PlatformUtils.modifierKey} + F: Search'),
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