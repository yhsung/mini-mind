/// Exception classes for Flutter-Rust bridge error handling
///
/// This file defines custom exception classes that map to Rust errors
/// and provide user-friendly error messages for the Flutter UI layer.

import 'bridge_types.dart';

/// Base class for all bridge-related exceptions
abstract class BridgeException implements Exception {
  const BridgeException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'BridgeException: $message';
}

/// Exception thrown when the bridge is not initialized
class BridgeNotInitializedException extends BridgeException {
  const BridgeNotInitializedException()
      : super('MindmapBridge must be initialized before use. Call initialize() first.');
}

/// Exception thrown when a bridge operation fails
class BridgeOperationException extends BridgeException {
  const BridgeOperationException(super.message, {super.cause});

  /// Create from a generic error
  factory BridgeOperationException.fromError(Object error) {
    return BridgeOperationException(
      'Bridge operation failed: ${error.toString()}',
      cause: error,
    );
  }
}

/// Exception thrown when a node is not found
class NodeNotFoundException extends BridgeException {
  const NodeNotFoundException(this.nodeId)
      : super('Node with ID "$nodeId" was not found');

  final String nodeId;

  @override
  String toString() => 'NodeNotFoundException: Node "$nodeId" not found';
}

/// Exception thrown when an edge is not found
class EdgeNotFoundException extends BridgeException {
  const EdgeNotFoundException(this.edgeId)
      : super('Edge with ID "$edgeId" was not found');

  final String edgeId;

  @override
  String toString() => 'EdgeNotFoundException: Edge "$edgeId" not found';
}

/// Exception thrown when a document is not found
class DocumentNotFoundException extends BridgeException {
  const DocumentNotFoundException(this.documentId)
      : super('Document with ID "$documentId" was not found');

  final String documentId;

  @override
  String toString() => 'DocumentNotFoundException: Document "$documentId" not found';
}

/// Exception thrown when an invalid operation is attempted
class InvalidOperationException extends BridgeException {
  const InvalidOperationException(super.message);

  /// Create for circular dependency attempts
  factory InvalidOperationException.circularDependency(String parentId, String childId) {
    return InvalidOperationException(
      'Cannot create circular dependency: node "$childId" cannot be a parent of "$parentId"',
    );
  }

  /// Create for invalid node text
  factory InvalidOperationException.invalidNodeText(String reason) {
    return InvalidOperationException('Invalid node text: $reason');
  }

  /// Create for invalid position
  factory InvalidOperationException.invalidPosition(String reason) {
    return InvalidOperationException('Invalid position: $reason');
  }

  /// Create for exceeding limits
  factory InvalidOperationException.limitExceeded(String limitType, int limit) {
    return InvalidOperationException('$limitType limit exceeded: maximum $limit');
  }
}

/// Exception thrown when file system operations fail
class FileSystemException extends BridgeException {
  const FileSystemException(super.message, {super.cause, this.filePath});

  final String? filePath;

  /// Create for file not found
  factory FileSystemException.fileNotFound(String filePath) {
    return FileSystemException(
      'File not found: $filePath',
      filePath: filePath,
    );
  }

  /// Create for file access denied
  factory FileSystemException.accessDenied(String filePath) {
    return FileSystemException(
      'Access denied: $filePath',
      filePath: filePath,
    );
  }

  /// Create for file write failure
  factory FileSystemException.writeFailed(String filePath, Object cause) {
    return FileSystemException(
      'Failed to write file: $filePath',
      filePath: filePath,
      cause: cause,
    );
  }

  /// Create for file read failure
  factory FileSystemException.readFailed(String filePath, Object cause) {
    return FileSystemException(
      'Failed to read file: $filePath',
      filePath: filePath,
      cause: cause,
    );
  }

  @override
  String toString() {
    final path = filePath != null ? ' ($filePath)' : '';
    return 'FileSystemException: $message$path';
  }
}

/// Exception thrown when serialization/deserialization fails
class SerializationException extends BridgeException {
  const SerializationException(super.message, {super.cause, this.dataType});

  final String? dataType;

  /// Create for JSON serialization failure
  factory SerializationException.jsonSerializationFailed(String dataType, Object cause) {
    return SerializationException(
      'Failed to serialize $dataType to JSON',
      cause: cause,
      dataType: dataType,
    );
  }

  /// Create for JSON deserialization failure
  factory SerializationException.jsonDeserializationFailed(String dataType, Object cause) {
    return SerializationException(
      'Failed to deserialize $dataType from JSON',
      cause: cause,
      dataType: dataType,
    );
  }

  /// Create for unknown format
  factory SerializationException.unknownFormat(String format) {
    return SerializationException('Unknown serialization format: $format');
  }

  @override
  String toString() {
    final type = dataType != null ? ' ($dataType)' : '';
    return 'SerializationException: $message$type';
  }
}

/// Exception thrown when layout computation fails
class LayoutComputationException extends BridgeException {
  const LayoutComputationException(super.message, {super.cause, this.layoutType});

  final FfiLayoutType? layoutType;

  /// Create for layout algorithm failure
  factory LayoutComputationException.algorithmFailed(FfiLayoutType layoutType, Object cause) {
    return LayoutComputationException(
      'Layout algorithm failed for ${layoutType.displayName}',
      cause: cause,
      layoutType: layoutType,
    );
  }

  /// Create for insufficient nodes
  factory LayoutComputationException.insufficientNodes(FfiLayoutType layoutType) {
    return LayoutComputationException(
      '${layoutType.displayName} layout requires at least one node',
      layoutType: layoutType,
    );
  }

  /// Create for layout timeout
  factory LayoutComputationException.timeout(FfiLayoutType layoutType, Duration timeout) {
    return LayoutComputationException(
      '${layoutType.displayName} layout computation timed out after ${timeout.inSeconds}s',
      layoutType: layoutType,
    );
  }

  @override
  String toString() {
    final type = layoutType != null ? ' (${layoutType!.displayName})' : '';
    return 'LayoutComputationException: $message$type';
  }
}

/// Exception thrown when search operations fail
class SearchException extends BridgeException {
  const SearchException(super.message, {super.cause, this.query});

  final String? query;

  /// Create for empty query
  factory SearchException.emptyQuery() {
    return const SearchException('Search query cannot be empty');
  }

  /// Create for invalid query
  factory SearchException.invalidQuery(String query, String reason) {
    return SearchException(
      'Invalid search query: $reason',
      query: query,
    );
  }

  /// Create for search timeout
  factory SearchException.timeout(String query, Duration timeout) {
    return SearchException(
      'Search timed out after ${timeout.inSeconds}s',
      query: query,
    );
  }

  /// Create for index corruption
  factory SearchException.indexCorrupted() {
    return const SearchException('Search index is corrupted and needs to be rebuilt');
  }

  @override
  String toString() {
    final queryText = query != null ? ' (query: "$query")' : '';
    return 'SearchException: $message$queryText';
  }
}

/// Exception thrown for network-related errors
class NetworkException extends BridgeException {
  const NetworkException(super.message, {super.cause, this.statusCode});

  final int? statusCode;

  /// Create for connection timeout
  factory NetworkException.timeout() {
    return const NetworkException('Network request timed out');
  }

  /// Create for no internet connection
  factory NetworkException.noConnection() {
    return const NetworkException('No internet connection available');
  }

  /// Create for server error
  factory NetworkException.serverError(int statusCode) {
    return NetworkException(
      'Server error: HTTP $statusCode',
      statusCode: statusCode,
    );
  }

  /// Create for client error
  factory NetworkException.clientError(int statusCode) {
    return NetworkException(
      'Client error: HTTP $statusCode',
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    final code = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'NetworkException: $message$code';
  }
}

/// Exception thrown when platform-specific operations fail
class PlatformException extends BridgeException {
  const PlatformException(super.message, {super.cause, this.platform});

  final String? platform;

  /// Create for unsupported platform
  factory PlatformException.unsupportedPlatform(String operation, String platform) {
    return PlatformException(
      'Operation "$operation" is not supported on $platform',
      platform: platform,
    );
  }

  /// Create for platform-specific feature unavailable
  factory PlatformException.featureUnavailable(String feature, String platform) {
    return PlatformException(
      'Feature "$feature" is not available on $platform',
      platform: platform,
    );
  }

  /// Create for permission denied
  factory PlatformException.permissionDenied(String permission) {
    return PlatformException('Permission denied: $permission');
  }

  @override
  String toString() {
    final platformText = platform != null ? ' ($platform)' : '';
    return 'PlatformException: $message$platformText';
  }
}

/// Exception thrown when memory limits are exceeded
class MemoryException extends BridgeException {
  const MemoryException(super.message, {super.cause, this.memoryUsage});

  final int? memoryUsage; // Memory usage in bytes

  /// Create for out of memory
  factory MemoryException.outOfMemory() {
    return const MemoryException('Out of memory');
  }

  /// Create for memory limit exceeded
  factory MemoryException.limitExceeded(int currentUsage, int limit) {
    return MemoryException(
      'Memory limit exceeded: ${_formatBytes(currentUsage)} > ${_formatBytes(limit)}',
      memoryUsage: currentUsage,
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  String toString() {
    final usage = memoryUsage != null ? ' (${_formatBytes(memoryUsage!)})' : '';
    return 'MemoryException: $message$usage';
  }
}

/// Utility functions for exception handling
class BridgeExceptionUtils {
  BridgeExceptionUtils._(); // Private constructor

  /// Convert a BridgeError to the appropriate exception
  static BridgeException fromBridgeError(BridgeError error) {
    switch (error.type) {
      case BridgeErrorType.nodeNotFound:
        return NodeNotFoundException(error.id ?? 'unknown');
      case BridgeErrorType.edgeNotFound:
        return EdgeNotFoundException(error.id ?? 'unknown');
      case BridgeErrorType.documentNotFound:
        return DocumentNotFoundException(error.id ?? 'unknown');
      case BridgeErrorType.invalidOperation:
        return InvalidOperationException(error.message);
      case BridgeErrorType.fileSystemError:
        return FileSystemException(error.message);
      case BridgeErrorType.serializationError:
        return SerializationException(error.message);
      case BridgeErrorType.layoutComputationError:
        return LayoutComputationException(error.message);
      case BridgeErrorType.searchError:
        return SearchException(error.message);
      case BridgeErrorType.genericError:
        return BridgeOperationException(error.message);
    }
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage(BridgeException exception) {
    switch (exception.runtimeType) {
      case NodeNotFoundException:
        return 'The selected node could not be found. It may have been deleted.';
      case DocumentNotFoundException:
        return 'The mindmap document could not be found. It may have been moved or deleted.';
      case FileSystemException:
        final fileException = exception as FileSystemException;
        if (fileException.message.contains('not found')) {
          return 'The file could not be found. Please check the file path.';
        } else if (fileException.message.contains('denied')) {
          return 'Permission denied. Please check file permissions.';
        }
        return 'A file operation failed. Please try again.';
      case NetworkException:
        final networkException = exception as NetworkException;
        if (networkException.message.contains('timeout')) {
          return 'The request timed out. Please check your internet connection.';
        } else if (networkException.message.contains('connection')) {
          return 'No internet connection. Please check your network settings.';
        }
        return 'A network error occurred. Please try again.';
      case SearchException:
        return 'Search failed. Please try a different search term.';
      case LayoutComputationException:
        return 'Layout calculation failed. Please try a different layout type.';
      case MemoryException:
        return 'Not enough memory available. Please close other applications and try again.';
      case PlatformException:
        return 'This feature is not available on your platform.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if an exception is recoverable (user can retry)
  static bool isRecoverable(BridgeException exception) {
    switch (exception.runtimeType) {
      case NetworkException:
      case FileSystemException:
      case SearchException:
      case LayoutComputationException:
        return true;
      case NodeNotFoundException:
      case DocumentNotFoundException:
      case PlatformException:
      case MemoryException:
        return false;
      default:
        return true; // Assume recoverable by default
    }
  }

  /// Check if an exception requires user action
  static bool requiresUserAction(BridgeException exception) {
    switch (exception.runtimeType) {
      case FileSystemException:
        final fileException = exception as FileSystemException;
        return fileException.message.contains('denied') ||
               fileException.message.contains('not found');
      case NetworkException:
        final networkException = exception as NetworkException;
        return networkException.message.contains('connection');
      case PlatformException:
        return true;
      default:
        return false;
    }
  }
}