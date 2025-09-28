/// Mock services for testing
///
/// This file provides mock implementations of application services
/// for use in widget tests and unit tests.

import 'dart:async';

import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Mock implementation of ErrorService for testing
class MockErrorService {
  static bool _isInitialized = false;
  static final List<_ErrorReport> _reports = [];

  static void setup() {
    _isInitialized = false;
    _reports.clear();
  }

  static void cleanup() {
    _isInitialized = false;
    _reports.clear();
  }

  static Future<void> initialize() async {
    _isInitialized = true;
  }

  static bool get isInitialized => _isInitialized;

  static void reportError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) {
    _reports.add(_ErrorReport(
      error: error,
      stackTrace: stackTrace,
      fatal: fatal,
      timestamp: DateTime.now(),
    ));
  }

  static List<_ErrorReport> get reports => List.unmodifiable(_reports);
  static int get reportCount => _reports.length;
  static void clearReports() => _reports.clear();
}

/// Mock implementation of LoggingService for testing
class MockLoggingService {
  static bool _isInitialized = false;
  static final List<_LogEntry> _logs = [];
  static Level? _currentLevel;

  static void setup() {
    _isInitialized = false;
    _logs.clear();
    _currentLevel = null;
  }

  static void cleanup() {
    _isInitialized = false;
    _logs.clear();
    _currentLevel = null;
  }

  static Future<void> initialize({
    Level logLevel = Level.info,
    bool enableFileLogging = false,
    int maxLogFiles = 5,
  }) async {
    _isInitialized = true;
    _currentLevel = logLevel;
  }

  static bool get isInitialized => _isInitialized;
  static Level? get currentLevel => _currentLevel;

  static void log(Level level, String message, {Object? error, StackTrace? stackTrace}) {
    _logs.add(_LogEntry(
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    ));
  }

  static List<_LogEntry> get logs => List.unmodifiable(_logs);
  static int get logCount => _logs.length;
  static void clearLogs() => _logs.clear();

  static List<_LogEntry> getLogsByLevel(Level level) {
    return _logs.where((log) => log.level == level).toList();
  }
}

/// Mock implementation of PlatformService for testing
class MockPlatformService {
  static bool _isInitialized = false;
  static MockDeviceInfo? _deviceInfo;
  static MockPackageInfo? _packageInfo;

  static void setup() {
    _isInitialized = false;
    _deviceInfo = null;
    _packageInfo = null;
  }

  static void cleanup() {
    _isInitialized = false;
    _deviceInfo = null;
    _packageInfo = null;
  }

  static Future<void> initialize({
    DeviceInfoPlugin? deviceInfo,
    PackageInfo? packageInfo,
  }) async {
    _isInitialized = true;
    _deviceInfo = MockDeviceInfo();
    _packageInfo = MockPackageInfo();
  }

  static bool get isInitialized => _isInitialized;
  static MockDeviceInfo? get deviceInfo => _deviceInfo;
  static MockPackageInfo? get packageInfo => _packageInfo;
}

/// Mock device information
class MockDeviceInfo {
  final String model = 'Test Device';
  final String platform = 'test';
  final String version = '1.0.0';
  final String identifier = 'test-device-id';

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'platform': platform,
      'version': version,
      'identifier': identifier,
    };
  }
}

/// Mock package information
class MockPackageInfo {
  final String appName = 'Mindmap Test';
  final String packageName = 'com.example.mindmap.test';
  final String version = '1.0.0+1';
  final String buildNumber = '1';
  final String buildSignature = 'test-signature';

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'packageName': packageName,
      'version': version,
      'buildNumber': buildNumber,
      'buildSignature': buildSignature,
    };
  }
}

/// Mock file system service for testing
class MockFileSystemService {
  static final Map<String, String> _files = {};
  static final Set<String> _directories = {};

  static void setup() {
    _files.clear();
    _directories.clear();

    // Set up default directories
    _directories.addAll([
      '/tmp',
      '/tmp/documents',
      '/tmp/support',
    ]);
  }

  static void cleanup() {
    _files.clear();
    _directories.clear();
  }

  static void createFile(String path, String content) {
    _files[path] = content;
  }

  static void createDirectory(String path) {
    _directories.add(path);
  }

  static String? readFile(String path) {
    return _files[path];
  }

  static bool fileExists(String path) {
    return _files.containsKey(path);
  }

  static bool directoryExists(String path) {
    return _directories.contains(path);
  }

  static List<String> listFiles(String directory) {
    return _files.keys
        .where((path) => path.startsWith(directory))
        .toList();
  }

  static void deleteFile(String path) {
    _files.remove(path);
  }

  static void deleteDirectory(String path) {
    _directories.remove(path);
    _files.removeWhere((key, value) => key.startsWith(path));
  }
}

/// Mock network service for testing
class MockNetworkService {
  static bool _isConnected = true;
  static String _connectionType = 'wifi';
  static final List<_NetworkRequest> _requests = [];

  static void setup({bool isConnected = true, String connectionType = 'wifi'}) {
    _isConnected = isConnected;
    _connectionType = connectionType;
    _requests.clear();
  }

  static void cleanup() {
    _isConnected = true;
    _connectionType = 'wifi';
    _requests.clear();
  }

  static bool get isConnected => _isConnected;
  static String get connectionType => _connectionType;

  static void setConnected(bool connected) {
    _isConnected = connected;
  }

  static void setConnectionType(String type) {
    _connectionType = type;
  }

  static Future<Map<String, dynamic>> makeRequest({
    required String url,
    required String method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    _requests.add(_NetworkRequest(
      url: url,
      method: method,
      headers: headers ?? {},
      body: body,
      timestamp: DateTime.now(),
    ));

    if (!_isConnected) {
      throw Exception('No internet connection');
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Return mock response
    return {
      'status': 200,
      'data': {'message': 'Mock response'},
    };
  }

  static List<_NetworkRequest> get requests => List.unmodifiable(_requests);
  static int get requestCount => _requests.length;
  static void clearRequests() => _requests.clear();
}

/// Mock database service for testing
class MockDatabaseService {
  static final Map<String, Map<String, dynamic>> _data = {};
  static bool _isInitialized = false;

  static void setup() {
    _data.clear();
    _isInitialized = false;
  }

  static void cleanup() {
    _data.clear();
    _isInitialized = false;
  }

  static Future<void> initialize() async {
    _isInitialized = true;
  }

  static bool get isInitialized => _isInitialized;

  static Future<void> insert(String table, Map<String, dynamic> data) async {
    _data[table] ??= {};
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _data[table]![id] = {...data, 'id': id};
  }

  static Future<Map<String, dynamic>?> findById(String table, String id) async {
    return _data[table]?[id];
  }

  static Future<List<Map<String, dynamic>>> findAll(String table) async {
    return _data[table]?.values.cast<Map<String, dynamic>>().toList() ?? [];
  }

  static Future<void> update(String table, String id, Map<String, dynamic> data) async {
    if (_data[table]?.containsKey(id) == true) {
      _data[table]![id] = {..._data[table]![id]!, ...data};
    }
  }

  static Future<void> delete(String table, String id) async {
    _data[table]?.remove(id);
  }

  static Future<void> clear(String table) async {
    _data[table]?.clear();
  }

  static int getCount(String table) {
    return _data[table]?.length ?? 0;
  }
}

/// Mock preferences service for testing
class MockPreferencesService {
  static final Map<String, dynamic> _preferences = {};

  static void setup() {
    _preferences.clear();
  }

  static void cleanup() {
    _preferences.clear();
  }

  static Future<void> setString(String key, String value) async {
    _preferences[key] = value;
  }

  static Future<void> setInt(String key, int value) async {
    _preferences[key] = value;
  }

  static Future<void> setBool(String key, bool value) async {
    _preferences[key] = value;
  }

  static Future<void> setDouble(String key, double value) async {
    _preferences[key] = value;
  }

  static Future<void> setStringList(String key, List<String> value) async {
    _preferences[key] = value;
  }

  static String? getString(String key) {
    return _preferences[key] as String?;
  }

  static int? getInt(String key) {
    return _preferences[key] as int?;
  }

  static bool? getBool(String key) {
    return _preferences[key] as bool?;
  }

  static double? getDouble(String key) {
    return _preferences[key] as double?;
  }

  static List<String>? getStringList(String key) {
    return _preferences[key] as List<String>?;
  }

  static Future<void> remove(String key) async {
    _preferences.remove(key);
  }

  static Future<void> clear() async {
    _preferences.clear();
  }

  static Set<String> getKeys() {
    return _preferences.keys.toSet();
  }
}

// Private classes for tracking service calls

class _ErrorReport {
  final Object error;
  final StackTrace? stackTrace;
  final bool fatal;
  final DateTime timestamp;

  _ErrorReport({
    required this.error,
    this.stackTrace,
    required this.fatal,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ErrorReport(error: $error, fatal: $fatal, timestamp: $timestamp)';
  }
}

class _LogEntry {
  final Level level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  _LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'LogEntry(level: $level, message: $message, timestamp: $timestamp)';
  }
}

class _NetworkRequest {
  final String url;
  final String method;
  final Map<String, String> headers;
  final Map<String, dynamic>? body;
  final DateTime timestamp;

  _NetworkRequest({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NetworkRequest(method: $method, url: $url, timestamp: $timestamp)';
  }
}