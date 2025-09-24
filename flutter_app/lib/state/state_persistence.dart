/// State persistence and restoration utilities
///
/// This file provides utilities for persisting and restoring application
/// state across app launches, including error recovery and data migration.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/bridge_types.dart';

/// State persistence manager
class StatePersistence {
  static const String _appStateKey = 'app_state_v2';
  static const String _mindmapStateKey = 'mindmap_state_v1';
  static const String _cacheDir = 'state_cache';
  static const int _maxBackups = 5;

  static final Logger _logger = Logger();

  /// Initialize state persistence system
  static Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        await _ensureStateDirectories();
        await _cleanupOldBackups();
      }
      _logger.i('State persistence system initialized');
    } catch (e) {
      _logger.e('Failed to initialize state persistence', error: e);
    }
  }

  /// Save application state with backup
  static Future<bool> saveAppState(Map<String, dynamic> state) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create backup before saving new state
      await _createStateBackup(_appStateKey, state);

      // Save to SharedPreferences
      final stateJson = jsonEncode(state);
      final success = await prefs.setString(_appStateKey, stateJson);

      if (success) {
        _logger.d('App state saved successfully');
      }

      return success;
    } catch (e) {
      _logger.e('Failed to save app state', error: e);
      return false;
    }
  }

  /// Load application state with fallback
  static Future<Map<String, dynamic>?> loadAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_appStateKey);

      if (stateJson != null) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        _logger.d('App state loaded successfully');
        return state;
      }

      // Try to restore from backup if primary state is missing
      return await _restoreStateFromBackup(_appStateKey);
    } catch (e) {
      _logger.w('Failed to load app state, trying backup', error: e);
      return await _restoreStateFromBackup(_appStateKey);
    }
  }

  /// Save mindmap state to local storage
  static Future<bool> saveMindmapState(Map<String, dynamic> state) async {
    try {
      if (kIsWeb) {
        // Use SharedPreferences on web
        final prefs = await SharedPreferences.getInstance();
        final stateJson = jsonEncode(state);
        return await prefs.setString(_mindmapStateKey, stateJson);
      }

      // Use file system on native platforms
      final file = await _getMindmapStateFile();
      await _createStateBackup('mindmap_state', state);

      await file.writeAsString(jsonEncode(state));
      _logger.d('Mindmap state saved to file: ${file.path}');

      return true;
    } catch (e) {
      _logger.e('Failed to save mindmap state', error: e);
      return false;
    }
  }

  /// Load mindmap state from local storage
  static Future<Map<String, dynamic>?> loadMindmapState() async {
    try {
      if (kIsWeb) {
        // Use SharedPreferences on web
        final prefs = await SharedPreferences.getInstance();
        final stateJson = prefs.getString(_mindmapStateKey);

        if (stateJson != null) {
          return jsonDecode(stateJson) as Map<String, dynamic>;
        }
        return null;
      }

      // Use file system on native platforms
      final file = await _getMindmapStateFile();

      if (await file.exists()) {
        final stateJson = await file.readAsString();
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        _logger.d('Mindmap state loaded from file: ${file.path}');
        return state;
      }

      return null;
    } catch (e) {
      _logger.w('Failed to load mindmap state, trying backup', error: e);
      return await _restoreStateFromBackup('mindmap_state');
    }
  }

  /// Clear all persisted state
  static Future<void> clearAllState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_appStateKey);
      await prefs.remove(_mindmapStateKey);

      if (!kIsWeb) {
        final stateDir = await _getStateDirectory();
        if (await stateDir.exists()) {
          await stateDir.delete(recursive: true);
        }
      }

      _logger.i('All persisted state cleared');
    } catch (e) {
      _logger.e('Failed to clear persisted state', error: e);
    }
  }

  /// Export state for backup or transfer
  static Future<String?> exportState() async {
    try {
      final appState = await loadAppState();
      final mindmapState = await loadMindmapState();

      final exportData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'appState': appState,
        'mindmapState': mindmapState,
      };

      return jsonEncode(exportData);
    } catch (e) {
      _logger.e('Failed to export state', error: e);
      return null;
    }
  }

  /// Import state from backup or transfer
  static Future<bool> importState(String stateData) async {
    try {
      final data = jsonDecode(stateData) as Map<String, dynamic>;
      final version = data['version'] as String?;

      if (version != '1.0') {
        _logger.w('Unsupported state version: $version');
        return false;
      }

      final appState = data['appState'] as Map<String, dynamic>?;
      final mindmapState = data['mindmapState'] as Map<String, dynamic>?;

      bool success = true;

      if (appState != null) {
        success = await saveAppState(appState) && success;
      }

      if (mindmapState != null) {
        success = await saveMindmapState(mindmapState) && success;
      }

      _logger.i('State import completed: ${success ? 'success' : 'partial failure'}');
      return success;
    } catch (e) {
      _logger.e('Failed to import state', error: e);
      return false;
    }
  }

  /// Get state storage statistics
  static Future<StateStorageStats> getStorageStats() async {
    try {
      int totalSize = 0;
      int backupCount = 0;
      DateTime? lastBackup;

      if (!kIsWeb) {
        final stateDir = await _getStateDirectory();
        if (await stateDir.exists()) {
          final files = await stateDir.list().toList();

          for (final entity in files) {
            if (entity is File) {
              final stat = await entity.stat();
              totalSize += stat.size;

              if (entity.path.contains('backup')) {
                backupCount++;
                final modified = stat.modified;
                if (lastBackup == null || modified.isAfter(lastBackup)) {
                  lastBackup = modified;
                }
              }
            }
          }
        }
      }

      return StateStorageStats(
        totalSizeBytes: totalSize,
        backupCount: backupCount,
        lastBackupTime: lastBackup,
      );
    } catch (e) {
      _logger.e('Failed to get storage stats', error: e);
      return const StateStorageStats(totalSizeBytes: 0, backupCount: 0);
    }
  }

  // Private Methods

  /// Ensure state directories exist
  static Future<void> _ensureStateDirectories() async {
    final stateDir = await _getStateDirectory();
    if (!await stateDir.exists()) {
      await stateDir.create(recursive: true);
    }

    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
  }

  /// Get state directory
  static Future<Directory> _getStateDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory(path.join(appDir.path, _cacheDir));
  }

  /// Get backup directory
  static Future<Directory> _getBackupDirectory() async {
    final stateDir = await _getStateDirectory();
    return Directory(path.join(stateDir.path, 'backups'));
  }

  /// Get mindmap state file
  static Future<File> _getMindmapStateFile() async {
    final stateDir = await _getStateDirectory();
    return File(path.join(stateDir.path, 'mindmap_state.json'));
  }

  /// Create state backup
  static Future<void> _createStateBackup(String stateType, Map<String, dynamic> state) async {
    if (kIsWeb) return; // No file backups on web

    try {
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File(path.join(backupDir.path, '${stateType}_$timestamp.json'));

      await backupFile.writeAsString(jsonEncode(state));
      _logger.v('Created backup: ${backupFile.path}');

      // Clean up old backups
      await _cleanupOldBackups();
    } catch (e) {
      _logger.w('Failed to create state backup', error: e);
    }
  }

  /// Restore state from backup
  static Future<Map<String, dynamic>?> _restoreStateFromBackup(String stateType) async {
    if (kIsWeb) return null; // No file backups on web

    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) return null;

      final backups = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.contains(stateType))
          .cast<File>()
          .toList();

      if (backups.isEmpty) return null;

      // Sort by modification time, newest first
      backups.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      for (final backup in backups) {
        try {
          final stateJson = await backup.readAsString();
          final state = jsonDecode(stateJson) as Map<String, dynamic>;
          _logger.i('Restored state from backup: ${backup.path}');
          return state;
        } catch (e) {
          _logger.w('Failed to restore from backup ${backup.path}', error: e);
          continue; // Try next backup
        }
      }

      return null;
    } catch (e) {
      _logger.e('Failed to restore from backup', error: e);
      return null;
    }
  }

  /// Clean up old backups
  static Future<void> _cleanupOldBackups() async {
    if (kIsWeb) return;

    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) return;

      final backups = await backupDir.list().cast<File>().toList();
      if (backups.length <= _maxBackups) return;

      // Sort by modification time, oldest first
      backups.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // Delete oldest backups
      final toDelete = backups.take(backups.length - _maxBackups);
      for (final backup in toDelete) {
        await backup.delete();
        _logger.v('Deleted old backup: ${backup.path}');
      }
    } catch (e) {
      _logger.w('Failed to cleanup old backups', error: e);
    }
  }
}

/// State storage statistics
@immutable
class StateStorageStats {
  const StateStorageStats({
    required this.totalSizeBytes,
    required this.backupCount,
    this.lastBackupTime,
  });

  final int totalSizeBytes;
  final int backupCount;
  final DateTime? lastBackupTime;

  /// Get formatted total size
  String get formattedSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get last backup time description
  String get lastBackupDescription {
    if (lastBackupTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastBackupTime!);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  String toString() {
    return 'StateStorageStats(size: $formattedSize, backups: $backupCount, lastBackup: $lastBackupDescription)';
  }
}

/// State migration utilities for handling version upgrades
class StateMigration {
  static final Logger _logger = Logger();

  /// Migrate state from old version to new version
  static Map<String, dynamic>? migrateAppState(
    Map<String, dynamic> oldState,
    String fromVersion,
    String toVersion,
  ) {
    try {
      if (fromVersion == toVersion) return oldState;

      _logger.i('Migrating app state from $fromVersion to $toVersion');

      // Add migration logic here as needed
      switch (fromVersion) {
        case '1.0':
          return _migrateFromV1ToV2(oldState);
        default:
          _logger.w('Unknown state version: $fromVersion');
          return oldState;
      }
    } catch (e) {
      _logger.e('State migration failed', error: e);
      return null;
    }
  }

  /// Migration from version 1.0 to 2.0
  static Map<String, dynamic> _migrateFromV1ToV2(Map<String, dynamic> state) {
    // Example migration: add new fields with defaults
    final migratedState = Map<String, dynamic>.from(state);

    // Add new settings if they don't exist
    if (!migratedState.containsKey('uiPreferences')) {
      migratedState['uiPreferences'] = {
        'showToolbar': true,
        'showStatusBar': true,
        'enableGridSnap': true,
        'gridSize': 20.0,
      };
    }

    // Update version
    migratedState['version'] = '2.0';

    return migratedState;
  }
}