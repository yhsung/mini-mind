/// Platform file service for handling cross-platform file operations
///
/// This service provides a unified interface for file operations including
/// file picker integration, native file sharing, and cross-platform file
/// path handling with proper permission management.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/platform_service.dart';
import '../utils/logger.dart';

/// File operation result containing success status and optional data
class FileOperationResult<T> {
  const FileOperationResult({
    required this.success,
    this.data,
    this.error,
    this.errorCode,
  });

  final bool success;
  final T? data;
  final String? error;
  final String? errorCode;

  /// Create a successful result with data
  factory FileOperationResult.success(T data) =>
      FileOperationResult(success: true, data: data);

  /// Create a successful result without data
  factory FileOperationResult.successEmpty() =>
      FileOperationResult(success: true);

  /// Create a failed result with error information
  factory FileOperationResult.failure(String error, [String? errorCode]) =>
      FileOperationResult(
        success: false,
        error: error,
        errorCode: errorCode,
      );
}

/// File information structure
class FileInfo {
  const FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.extension,
    required this.mimeType,
    this.lastModified,
  });

  final String name;
  final String path;
  final int size;
  final String extension;
  final String? mimeType;
  final DateTime? lastModified;

  /// Get human-readable file size
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Check if file is an image
  bool get isImage => [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
        '.svg'
      ].contains(extension.toLowerCase());

  /// Check if file is a document
  bool get isDocument => [
        '.pdf',
        '.doc',
        '.docx',
        '.txt',
        '.rtf',
        '.odt'
      ].contains(extension.toLowerCase());

  /// Check if file is an archive
  bool get isArchive =>
      ['.zip', '.rar', '.7z', '.tar', '.gz'].contains(extension.toLowerCase());
}

/// Supported file types for file picker
enum FileType {
  any,
  image,
  document,
  mindmap,
  archive,
}

/// Platform file service for cross-platform file operations
class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  static FileService get instance => _instance;

  final PlatformService _platformService = PlatformService.instance;
  final Logger _logger = Logger.instance;

  /// Platform channel for native file operations
  static const MethodChannel _channel = MethodChannel('com.minimind.app/file_service');

  /// Initialize the file service
  Future<void> initialize() async {
    _logger.info('FileService: Initializing file service');

    // Initialize platform-specific features
    if (_platformService.isDesktop) {
      await _initializeDesktopFeatures();
    } else if (_platformService.isMobile) {
      await _initializeMobileFeatures();
    }
  }

  /// Initialize desktop-specific file handling features
  Future<void> _initializeDesktopFeatures() async {
    try {
      // Register file associations and drag-drop handlers
      if (_platformService.platformName == 'Windows') {
        await _registerWindowsFileAssociations();
      } else if (_platformService.platformName == 'macOS') {
        await _registerMacOSFileAssociations();
      } else if (_platformService.platformName == 'Linux') {
        await _registerLinuxFileAssociations();
      }
    } catch (e) {
      _logger.warning('FileService: Could not initialize desktop features: $e');
    }
  }

  /// Initialize mobile-specific file handling features
  Future<void> _initializeMobileFeatures() async {
    try {
      // Request storage permissions if needed
      await _requestStoragePermissions();
    } catch (e) {
      _logger.warning('FileService: Could not initialize mobile features: $e');
    }
  }

  /// Register Windows file associations
  Future<void> _registerWindowsFileAssociations() async {
    try {
      await _channel.invokeMethod('registerFileAssociations', {
        'extensions': ['.mm', '.xmind', '.json'],
        'appName': 'MindMap',
        'appId': 'com.minimind.app',
      });
    } catch (e) {
      _logger.debug('FileService: Windows file association registration failed: $e');
    }
  }

  /// Register macOS file associations
  Future<void> _registerMacOSFileAssociations() async {
    try {
      await _channel.invokeMethod('registerFileAssociations', {
        'extensions': ['.mm', '.xmind', '.json'],
        'appName': 'MindMap',
        'bundleId': 'com.minimind.app',
      });
    } catch (e) {
      _logger.debug('FileService: macOS file association registration failed: $e');
    }
  }

  /// Register Linux file associations
  Future<void> _registerLinuxFileAssociations() async {
    try {
      await _channel.invokeMethod('registerFileAssociations', {
        'extensions': ['.mm', '.xmind', '.json'],
        'appName': 'MindMap',
        'desktopFile': 'com.minimind.app.desktop',
      });
    } catch (e) {
      _logger.debug('FileService: Linux file association registration failed: $e');
    }
  }

  /// Request storage permissions on mobile platforms
  Future<void> _requestStoragePermissions() async {
    try {
      final bool granted = await _channel.invokeMethod('requestStoragePermissions');
      if (granted) {
        _logger.info('FileService: Storage permissions granted');
      } else {
        _logger.warning('FileService: Storage permissions denied');
      }
    } catch (e) {
      _logger.debug('FileService: Storage permission request failed: $e');
    }
  }

  /// Pick a single file using native file picker
  Future<FileOperationResult<FileInfo?>> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      if (!_platformService.supportsFileAccess) {
        return FileOperationResult.failure(
          'File access not supported on this platform',
          'PLATFORM_NOT_SUPPORTED',
        );
      }

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: _mapFileType(type),
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle ?? 'Select File',
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return FileOperationResult.success(null);
      }

      final PlatformFile platformFile = result.files.first;
      if (platformFile.path == null) {
        return FileOperationResult.failure(
          'File path is not available',
          'NO_FILE_PATH',
        );
      }

      final File file = File(platformFile.path!);
      final FileStat stat = await file.stat();

      final FileInfo fileInfo = FileInfo(
        name: platformFile.name,
        path: platformFile.path!,
        size: platformFile.size,
        extension: path.extension(platformFile.name),
        mimeType: _guessMimeType(platformFile.name),
        lastModified: stat.modified,
      );

      _logger.info('FileService: File picked successfully: ${fileInfo.name}');
      return FileOperationResult.success(fileInfo);
    } catch (e) {
      _logger.error('FileService: Error picking file: $e');
      return FileOperationResult.failure(
        'Failed to pick file: ${e.toString()}',
        'PICK_FILE_ERROR',
      );
    }
  }

  /// Pick multiple files using native file picker
  Future<FileOperationResult<List<FileInfo>>> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    String? dialogTitle,
    int? maxFiles,
  }) async {
    try {
      if (!_platformService.supportsFileAccess) {
        return FileOperationResult.failure(
          'File access not supported on this platform',
          'PLATFORM_NOT_SUPPORTED',
        );
      }

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: _mapFileType(type),
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle ?? 'Select Files',
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return FileOperationResult.success(<FileInfo>[]);
      }

      List<PlatformFile> files = result.files;
      if (maxFiles != null && files.length > maxFiles) {
        files = files.take(maxFiles).toList();
      }

      final List<FileInfo> fileInfos = [];
      for (final PlatformFile platformFile in files) {
        if (platformFile.path == null) continue;

        final File file = File(platformFile.path!);
        final FileStat stat = await file.stat();

        fileInfos.add(FileInfo(
          name: platformFile.name,
          path: platformFile.path!,
          size: platformFile.size,
          extension: path.extension(platformFile.name),
          mimeType: _guessMimeType(platformFile.name),
          lastModified: stat.modified,
        ));
      }

      _logger.info(
          'FileService: ${fileInfos.length} files picked successfully');
      return FileOperationResult.success(fileInfos);
    } catch (e) {
      _logger.error('FileService: Error picking files: $e');
      return FileOperationResult.failure(
        'Failed to pick files: ${e.toString()}',
        'PICK_FILES_ERROR',
      );
    }
  }

  /// Save file using native save dialog
  Future<FileOperationResult<String?>> saveFile({
    required Uint8List data,
    String? fileName,
    String? dialogTitle,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    try {
      if (!_platformService.supportsFileAccess) {
        return FileOperationResult.failure(
          'File save not supported on this platform',
          'PLATFORM_NOT_SUPPORTED',
        );
      }

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Save File',
        fileName: fileName,
        type: _mapFileType(type),
        allowedExtensions: allowedExtensions,
      );

      if (outputPath == null) {
        return FileOperationResult.success(null);
      }

      final File file = File(outputPath);
      await file.writeAsBytes(data);

      _logger.info('FileService: File saved successfully: $outputPath');
      return FileOperationResult.success(outputPath);
    } catch (e) {
      _logger.error('FileService: Error saving file: $e');
      return FileOperationResult.failure(
        'Failed to save file: ${e.toString()}',
        'SAVE_FILE_ERROR',
      );
    }
  }

  /// Read file contents as bytes
  Future<FileOperationResult<Uint8List>> readFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        return FileOperationResult.failure(
          'File does not exist: $filePath',
          'FILE_NOT_FOUND',
        );
      }

      final Uint8List data = await file.readAsBytes();
      _logger.info('FileService: File read successfully: $filePath');
      return FileOperationResult.success(data);
    } catch (e) {
      _logger.error('FileService: Error reading file: $e');
      return FileOperationResult.failure(
        'Failed to read file: ${e.toString()}',
        'READ_FILE_ERROR',
      );
    }
  }

  /// Write data to file
  Future<FileOperationResult<void>> writeFile(
    String filePath,
    Uint8List data,
  ) async {
    try {
      final File file = File(filePath);

      // Create parent directories if they don't exist
      final Directory parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      await file.writeAsBytes(data);
      _logger.info('FileService: File written successfully: $filePath');
      return FileOperationResult.successEmpty();
    } catch (e) {
      _logger.error('FileService: Error writing file: $e');
      return FileOperationResult.failure(
        'Failed to write file: ${e.toString()}',
        'WRITE_FILE_ERROR',
      );
    }
  }

  /// Share file using platform sharing
  Future<FileOperationResult<void>> shareFile({
    required String filePath,
    String? subject,
    String? text,
    String? mimeType,
  }) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        return FileOperationResult.failure(
          'File does not exist: $filePath',
          'FILE_NOT_FOUND',
        );
      }

      final ShareResult result = await Share.shareXFiles(
        [XFile(filePath, mimeType: mimeType)],
        subject: subject,
        text: text,
      );

      if (result.status == ShareResultStatus.success) {
        _logger.info('FileService: File shared successfully: $filePath');
        return FileOperationResult.successEmpty();
      } else {
        return FileOperationResult.failure(
          'Failed to share file: ${result.status}',
          'SHARE_FAILED',
        );
      }
    } catch (e) {
      _logger.error('FileService: Error sharing file: $e');
      return FileOperationResult.failure(
        'Failed to share file: ${e.toString()}',
        'SHARE_FILE_ERROR',
      );
    }
  }

  /// Get application documents directory
  Future<FileOperationResult<String>> getDocumentsDirectory() async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      return FileOperationResult.success(directory.path);
    } catch (e) {
      _logger.error('FileService: Error getting documents directory: $e');
      return FileOperationResult.failure(
        'Failed to get documents directory: ${e.toString()}',
        'DOCUMENTS_DIR_ERROR',
      );
    }
  }

  /// Get application cache directory
  Future<FileOperationResult<String>> getCacheDirectory() async {
    try {
      final Directory directory = await getTemporaryDirectory();
      return FileOperationResult.success(directory.path);
    } catch (e) {
      _logger.error('FileService: Error getting cache directory: $e');
      return FileOperationResult.failure(
        'Failed to get cache directory: ${e.toString()}',
        'CACHE_DIR_ERROR',
      );
    }
  }

  /// Create application-specific subdirectory
  Future<FileOperationResult<String>> createAppDirectory(
    String dirName, {
    bool inDocuments = true,
  }) async {
    try {
      final FileOperationResult<String> baseDirResult = inDocuments
          ? await getDocumentsDirectory()
          : await getCacheDirectory();

      if (!baseDirResult.success) {
        return FileOperationResult.failure(
          baseDirResult.error!,
          baseDirResult.errorCode,
        );
      }

      final String appDirPath = path.join(baseDirResult.data!, dirName);
      final Directory appDir = Directory(appDirPath);

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      _logger.info('FileService: App directory created: $appDirPath');
      return FileOperationResult.success(appDirPath);
    } catch (e) {
      _logger.error('FileService: Error creating app directory: $e');
      return FileOperationResult.failure(
        'Failed to create app directory: ${e.toString()}',
        'CREATE_DIR_ERROR',
      );
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      _logger.error('FileService: Error checking file existence: $e');
      return false;
    }
  }

  /// Get file information
  Future<FileOperationResult<FileInfo>> getFileInfo(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        return FileOperationResult.failure(
          'File does not exist: $filePath',
          'FILE_NOT_FOUND',
        );
      }

      final FileStat stat = await file.stat();
      final String fileName = path.basename(filePath);
      final String extension = path.extension(fileName);

      final FileInfo fileInfo = FileInfo(
        name: fileName,
        path: filePath,
        size: stat.size,
        extension: extension,
        mimeType: _guessMimeType(fileName),
        lastModified: stat.modified,
      );

      return FileOperationResult.success(fileInfo);
    } catch (e) {
      _logger.error('FileService: Error getting file info: $e');
      return FileOperationResult.failure(
        'Failed to get file info: ${e.toString()}',
        'FILE_INFO_ERROR',
      );
    }
  }

  /// Delete file
  Future<FileOperationResult<void>> deleteFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _logger.info('FileService: File deleted successfully: $filePath');
      }
      return FileOperationResult.successEmpty();
    } catch (e) {
      _logger.error('FileService: Error deleting file: $e');
      return FileOperationResult.failure(
        'Failed to delete file: ${e.toString()}',
        'DELETE_FILE_ERROR',
      );
    }
  }

  /// Open file with system default application
  Future<FileOperationResult<void>> openFileWithSystem(String filePath) async {
    try {
      if (!await fileExists(filePath)) {
        return FileOperationResult.failure(
          'File does not exist: $filePath',
          'FILE_NOT_FOUND',
        );
      }

      final bool success = await _channel.invokeMethod('openFileWithSystem', {
        'filePath': filePath,
      });

      if (success) {
        _logger.info('FileService: File opened with system app: $filePath');
        return FileOperationResult.successEmpty();
      } else {
        return FileOperationResult.failure(
          'Failed to open file with system application',
          'OPEN_SYSTEM_FAILED',
        );
      }
    } catch (e) {
      _logger.error('FileService: Error opening file with system: $e');
      return FileOperationResult.failure(
        'Failed to open file: ${e.toString()}',
        'OPEN_FILE_ERROR',
      );
    }
  }

  /// Show file in system file manager
  Future<FileOperationResult<void>> showInFileManager(String filePath) async {
    try {
      if (!await fileExists(filePath)) {
        return FileOperationResult.failure(
          'File does not exist: $filePath',
          'FILE_NOT_FOUND',
        );
      }

      final bool success = await _channel.invokeMethod('showInFileManager', {
        'filePath': filePath,
      });

      if (success) {
        _logger.info('FileService: File shown in file manager: $filePath');
        return FileOperationResult.successEmpty();
      } else {
        return FileOperationResult.failure(
          'Failed to show file in file manager',
          'SHOW_FILE_FAILED',
        );
      }
    } catch (e) {
      _logger.error('FileService: Error showing file in manager: $e');
      return FileOperationResult.failure(
        'Failed to show file: ${e.toString()}',
        'SHOW_FILE_ERROR',
      );
    }
  }

  /// Get recent files from platform file history
  Future<FileOperationResult<List<FileInfo>>> getRecentFiles({
    int maxFiles = 10,
    List<String>? extensions,
  }) async {
    try {
      final List<dynamic> recentFiles = await _channel.invokeMethod('getRecentFiles', {
        'maxFiles': maxFiles,
        'extensions': extensions,
      });

      final List<FileInfo> fileInfos = [];
      for (final dynamic fileData in recentFiles) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(fileData);
        final String filePath = data['path'] as String;

        if (await fileExists(filePath)) {
          final FileOperationResult<FileInfo> result = await getFileInfo(filePath);
          if (result.success && result.data != null) {
            fileInfos.add(result.data!);
          }
        }
      }

      _logger.info('FileService: Retrieved ${fileInfos.length} recent files');
      return FileOperationResult.success(fileInfos);
    } catch (e) {
      _logger.error('FileService: Error getting recent files: $e');
      return FileOperationResult.failure(
        'Failed to get recent files: ${e.toString()}',
        'RECENT_FILES_ERROR',
      );
    }
  }

  /// Add file to platform recent files list
  Future<void> addToRecentFiles(String filePath) async {
    try {
      if (await fileExists(filePath)) {
        await _channel.invokeMethod('addToRecentFiles', {
          'filePath': filePath,
        });
        _logger.debug('FileService: Added to recent files: $filePath');
      }
    } catch (e) {
      _logger.debug('FileService: Could not add to recent files: $e');
    }
  }

  /// Get platform-specific file associations
  Future<FileOperationResult<List<String>>> getFileAssociations(
    String extension,
  ) async {
    try {
      final List<dynamic> associations = await _channel.invokeMethod('getFileAssociations', {
        'extension': extension,
      });

      final List<String> apps = associations.cast<String>();
      return FileOperationResult.success(apps);
    } catch (e) {
      _logger.error('FileService: Error getting file associations: $e');
      return FileOperationResult.failure(
        'Failed to get file associations: ${e.toString()}',
        'ASSOCIATIONS_ERROR',
      );
    }
  }

  /// Map FileType to FilePicker FileType
  FilePickerType _mapFileType(FileType type) {
    switch (type) {
      case FileType.any:
        return FilePickerType.any;
      case FileType.image:
        return FilePickerType.image;
      case FileType.document:
        return FilePickerType.any; // FilePicker doesn't have document type
      case FileType.mindmap:
        return FilePickerType.custom;
      case FileType.archive:
        return FilePickerType.custom;
    }
  }

  /// Guess MIME type based on file extension
  String? _guessMimeType(String fileName) {
    final String extension = path.extension(fileName).toLowerCase();

    const Map<String, String> mimeTypes = {
      // Images
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',

      // Documents
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.txt': 'text/plain',
      '.rtf': 'application/rtf',
      '.odt': 'application/vnd.oasis.opendocument.text',

      // Archives
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',

      // Mindmap formats
      '.mm': 'application/x-freemind',
      '.xmind': 'application/vnd.xmind.workbook',
      '.json': 'application/json',
      '.xml': 'application/xml',
    };

    return mimeTypes[extension];
  }
}