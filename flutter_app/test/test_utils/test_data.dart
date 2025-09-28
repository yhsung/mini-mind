/// Test data and constants for Flutter widget tests
///
/// This file provides mock data, test constants, and sample objects
/// for use throughout the test suite.

import 'package:flutter/material.dart';

/// Test data constants and mock objects
class TestData {
  // Private constructor to prevent instantiation
  TestData._();

  /// Mock device information for Android
  static const Map<String, dynamic> mockAndroidDeviceInfo = {
    'version': {
      'securityPatch': '2023-08-01',
      'sdkInt': 33,
      'release': '13',
      'previewSdkInt': 0,
      'incremental': '1234567',
      'codename': 'REL',
      'baseOS': '',
    },
    'board': 'test_board',
    'bootloader': 'test_bootloader',
    'brand': 'Test',
    'device': 'test_device',
    'display': 'test_display',
    'fingerprint': 'test_fingerprint',
    'hardware': 'test_hardware',
    'host': 'test_host',
    'id': 'test_id',
    'manufacturer': 'Test Manufacturer',
    'model': 'Test Model',
    'product': 'test_product',
    'supported32BitAbis': <String>[],
    'supported64BitAbis': <String>['arm64-v8a'],
    'supportedAbis': <String>['arm64-v8a'],
    'tags': 'test_tags',
    'type': 'user',
    'isPhysicalDevice': true,
    'systemFeatures': <String>[],
  };

  /// Mock device information for iOS
  static const Map<String, dynamic> mockIosDeviceInfo = {
    'name': 'Test iPhone',
    'systemName': 'iOS',
    'systemVersion': '16.0',
    'model': 'iPhone',
    'localizedModel': 'iPhone',
    'identifierForVendor': 'test-identifier',
    'isPhysicalDevice': true,
    'utsname': {
      'sysname': 'Darwin',
      'nodename': 'test-node',
      'release': '22.0.0',
      'version': 'Darwin Kernel Version 22.0.0',
      'machine': 'arm64',
    },
  };

  /// Mock package information
  static const Map<String, dynamic> mockPackageInfo = {
    'appName': 'Mindmap Test',
    'packageName': 'com.example.mindmap.test',
    'version': '1.0.0',
    'buildNumber': '1',
    'buildSignature': 'test-signature',
    'installerStore': null,
  };

  /// Sample node data for testing
  static const Map<String, dynamic> sampleNodeData = {
    'id': 'test-node-1',
    'text': 'Test Node',
    'position': {'x': 100.0, 'y': 200.0},
    'parentId': null,
    'style': {
      'backgroundColor': 0xFF2196F3,
      'textColor': 0xFFFFFFFF,
      'borderColor': 0xFF1976D2,
      'fontSize': 16.0,
      'fontWeight': 'normal',
    },
    'metadata': {},
    'tags': <String>[],
    'attachments': <Map<String, dynamic>>[],
    'createdAt': '2023-01-01T00:00:00.000Z',
    'updatedAt': '2023-01-01T00:00:00.000Z',
  };

  /// Sample edge data for testing
  static const Map<String, dynamic> sampleEdgeData = {
    'id': 'test-edge-1',
    'fromNodeId': 'test-node-1',
    'toNodeId': 'test-node-2',
    'label': 'Test Connection',
    'style': {
      'color': 0xFF757575,
      'thickness': 2.0,
      'pattern': 'solid',
    },
    'createdAt': '2023-01-01T00:00:00.000Z',
    'updatedAt': '2023-01-01T00:00:00.000Z',
  };

  /// Sample document data for testing
  static const Map<String, dynamic> sampleDocumentData = {
    'id': 'test-document-1',
    'title': 'Test Mindmap',
    'description': 'A test mindmap document',
    'rootNodeId': 'test-node-1',
    'metadata': {
      'author': 'Test User',
      'version': 1,
      'lastModified': '2023-01-01T00:00:00.000Z',
    },
    'settings': {
      'autoSave': true,
      'autoLayout': false,
      'snapToGrid': true,
      'gridSize': 20.0,
    },
    'createdAt': '2023-01-01T00:00:00.000Z',
    'updatedAt': '2023-01-01T00:00:00.000Z',
    'lastSavedAt': '2023-01-01T00:00:00.000Z',
    'isDirty': false,
  };

  /// Sample user preferences for testing
  static const Map<String, dynamic> sampleUserPreferences = {
    'theme': 'system',
    'language': 'en',
    'autoSave': true,
    'autoSaveInterval': 30,
    'showGrid': true,
    'snapToGrid': true,
    'gridSize': 20.0,
    'defaultFontSize': 16.0,
    'enableAnimations': true,
    'enableSounds': false,
    'enableHapticFeedback': true,
    'maxUndoSteps': 50,
    'exportFormat': 'png',
    'exportQuality': 'high',
  };

  /// Test color schemes
  static const List<ColorScheme> testColorSchemes = [
    ColorScheme.light(),
    ColorScheme.dark(),
  ];

  /// Test screen sizes for responsive testing
  static const List<Size> testScreenSizes = [
    Size(375, 667),   // iPhone SE
    Size(390, 844),   // iPhone 12
    Size(768, 1024),  // iPad
    Size(1024, 768),  // iPad Landscape
    Size(1200, 800),  // Desktop
    Size(1920, 1080), // Full HD Desktop
  ];

  /// Test text scale factors
  static const List<double> testTextScaleFactors = [
    0.8,  // Small
    1.0,  // Normal
    1.3,  // Large
    1.7,  // Extra Large
    2.0,  // Accessibility
  ];

  /// Test locales
  static const List<Locale> testLocales = [
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
    Locale('de', 'DE'),
    Locale('ja', 'JP'),
    Locale('zh', 'CN'),
  ];

  /// Sample error messages for testing
  static const List<String> sampleErrorMessages = [
    'Network connection failed',
    'File not found',
    'Invalid input data',
    'Permission denied',
    'Timeout occurred',
    'Unknown error',
  ];

  /// Sample success messages for testing
  static const List<String> sampleSuccessMessages = [
    'Document saved successfully',
    'Export completed',
    'Settings updated',
    'Connection established',
    'Operation completed',
  ];

  /// Test keyboard shortcuts
  static const Map<String, String> testKeyboardShortcuts = {
    'new': 'Ctrl+N',
    'open': 'Ctrl+O',
    'save': 'Ctrl+S',
    'undo': 'Ctrl+Z',
    'redo': 'Ctrl+Y',
    'copy': 'Ctrl+C',
    'paste': 'Ctrl+V',
    'cut': 'Ctrl+X',
    'selectAll': 'Ctrl+A',
    'find': 'Ctrl+F',
  };

  /// Test file paths
  static const Map<String, String> testFilePaths = {
    'documents': '/documents',
    'exports': '/exports',
    'temp': '/tmp',
    'cache': '/cache',
    'logs': '/logs',
  };

  /// Test URLs for network testing
  static const Map<String, String> testUrls = {
    'api': 'https://api.example.com',
    'auth': 'https://auth.example.com',
    'storage': 'https://storage.example.com',
    'cdn': 'https://cdn.example.com',
  };

  /// Test animation durations
  static const Map<String, Duration> testAnimationDurations = {
    'fast': Duration(milliseconds: 150),
    'normal': Duration(milliseconds: 300),
    'slow': Duration(milliseconds: 500),
    'veryFast': Duration(milliseconds: 100),
    'verySlow': Duration(milliseconds: 1000),
  };

  /// Test layout configurations
  static const Map<String, Map<String, dynamic>> testLayoutConfigs = {
    'radial': {
      'type': 'radial',
      'centerRadius': 50.0,
      'ringSpacing': 100.0,
      'nodeSpacing': 80.0,
      'startAngle': 0.0,
    },
    'tree': {
      'type': 'tree',
      'orientation': 'topDown',
      'horizontalSpacing': 80.0,
      'verticalSpacing': 120.0,
      'balanceSubtrees': true,
    },
    'force': {
      'type': 'force',
      'springStrength': 0.1,
      'springLength': 100.0,
      'repulsionStrength': 1000.0,
      'damping': 0.95,
      'maxIterations': 1000,
    },
  };

  /// Helper methods for creating test data

  /// Creates a list of sample nodes
  static List<Map<String, dynamic>> createSampleNodes(int count) {
    return List.generate(count, (index) => {
      ...sampleNodeData,
      'id': 'test-node-$index',
      'text': 'Test Node $index',
      'position': {
        'x': (index % 5) * 100.0,
        'y': (index ~/ 5) * 100.0,
      },
    });
  }

  /// Creates a list of sample edges
  static List<Map<String, dynamic>> createSampleEdges(int count) {
    return List.generate(count, (index) => {
      ...sampleEdgeData,
      'id': 'test-edge-$index',
      'fromNodeId': 'test-node-$index',
      'toNodeId': 'test-node-${index + 1}',
      'label': 'Connection $index',
    });
  }

  /// Creates a sample mindmap with nodes and edges
  static Map<String, dynamic> createSampleMindmap({
    int nodeCount = 5,
    int edgeCount = 4,
  }) {
    return {
      ...sampleDocumentData,
      'nodes': createSampleNodes(nodeCount),
      'edges': createSampleEdges(edgeCount),
    };
  }

  /// Creates test theme data with custom colors
  static ThemeData createTestTheme({
    Brightness brightness = Brightness.light,
    Color? primaryColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor ?? Colors.blue,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
    );
  }

  /// Creates test media query data
  static MediaQueryData createTestMediaQuery({
    Size size = const Size(400, 800),
    double textScaleFactor = 1.0,
    Brightness platformBrightness = Brightness.light,
  }) {
    return MediaQueryData(
      size: size,
      textScaleFactor: textScaleFactor,
      platformBrightness: platformBrightness,
    );
  }

  /// Gets a random test color
  static Color getRandomTestColor() {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[DateTime.now().millisecond % colors.length];
  }

  /// Gets a random test text
  static String getRandomTestText({int wordCount = 3}) {
    const words = [
      'test', 'sample', 'example', 'demo', 'mock', 'data',
      'widget', 'flutter', 'dart', 'app', 'component', 'element',
      'node', 'edge', 'mindmap', 'document', 'file', 'content',
    ];

    final result = List.generate(wordCount, (index) =>
        words[DateTime.now().microsecond % words.length]);

    return result.join(' ');
  }

  /// Validates test data integrity
  static bool validateTestData() {
    // Basic validation of test data structure
    return sampleNodeData.containsKey('id') &&
           sampleEdgeData.containsKey('id') &&
           sampleDocumentData.containsKey('id') &&
           testScreenSizes.isNotEmpty &&
           testColorSchemes.isNotEmpty;
  }
}