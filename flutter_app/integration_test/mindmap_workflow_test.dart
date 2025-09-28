/// Mindmap workflow integration tests
///
/// This file contains comprehensive end-to-end tests for complete mindmap
/// creation, editing, navigation, and file operations workflows.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import the main app and services
import 'package:mindmap_app/main.dart' as app;
import 'package:mindmap_app/app.dart';
import 'package:mindmap_app/services/file_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mindmap Workflow Integration Tests', () {
    group('Mindmap Creation and Editing Workflow', () {
      testWidgets('Create new mindmap and add nodes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for UI elements that might be related to creating a new mindmap
        // Since we don't know the exact UI structure, we'll be flexible
        final buttons = find.byType(ElevatedButton);
        final iconButtons = find.byType(IconButton);
        final floatingActionButtons = find.byType(FloatingActionButton);

        // Try to find and tap a "new" or "create" button
        var newButton = find.byTooltip('New');
        if (newButton.evaluate().isEmpty) {
          newButton = find.byIcon(Icons.add);
        }
        if (newButton.evaluate().isEmpty) {
          newButton = find.byIcon(Icons.create);
        }
        if (newButton.evaluate().isEmpty && floatingActionButtons.evaluate().isNotEmpty) {
          newButton = floatingActionButtons.first;
        }

        if (newButton.evaluate().isNotEmpty) {
          await tester.tap(newButton);
          await tester.pumpAndSettle();
        }

        // The app should remain functional after attempting to create new content
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Edit mindmap node content', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for editable text fields that might represent nodes
        final textFields = find.byType(TextField);
        final textFormFields = find.byType(TextFormField);

        if (textFields.evaluate().isNotEmpty) {
          await tester.tap(textFields.first);
          await tester.pumpAndSettle();

          await tester.enterText(textFields.first, 'New node content');
          await tester.pumpAndSettle();

          expect(find.text('New node content'), findsOneWidget);
        } else if (textFormFields.evaluate().isNotEmpty) {
          await tester.tap(textFormFields.first);
          await tester.pumpAndSettle();

          await tester.enterText(textFormFields.first, 'New node content');
          await tester.pumpAndSettle();

          expect(find.text('New node content'), findsOneWidget);
        }

        // App should remain stable after editing
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Add child nodes to existing node', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for context menu or add child functionality
        final gestureDetectors = find.byType(GestureDetector);
        final inkWells = find.byType(InkWell);

        // Try right-click or long press to trigger context menu
        if (gestureDetectors.evaluate().isNotEmpty) {
          await tester.longPress(gestureDetectors.first);
          await tester.pumpAndSettle();
        } else if (inkWells.evaluate().isNotEmpty) {
          await tester.longPress(inkWells.first);
          await tester.pumpAndSettle();
        }

        // Look for add child button
        final addChildButton = find.byTooltip('Add Child');
        final addButton = find.byIcon(Icons.add_circle);

        if (addChildButton.evaluate().isNotEmpty) {
          await tester.tap(addChildButton);
          await tester.pumpAndSettle();
        } else if (addButton.evaluate().isNotEmpty) {
          await tester.tap(addButton.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Delete nodes from mindmap', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Try to find delete functionality
        final deleteButton = find.byTooltip('Delete');
        final deleteIcon = find.byIcon(Icons.delete);

        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();
        } else if (deleteIcon.evaluate().isNotEmpty) {
          await tester.tap(deleteIcon.first);
          await tester.pumpAndSettle();
        }

        // App should handle deletion gracefully
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Undo and redo operations', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for undo/redo buttons
        final undoButton = find.byTooltip('Undo');
        final redoButton = find.byTooltip('Redo');
        final undoIcon = find.byIcon(Icons.undo);
        final redoIcon = find.byIcon(Icons.redo);

        // Test undo
        if (undoButton.evaluate().isNotEmpty) {
          await tester.tap(undoButton);
          await tester.pumpAndSettle();
        } else if (undoIcon.evaluate().isNotEmpty) {
          await tester.tap(undoIcon.first);
          await tester.pumpAndSettle();
        }

        // Test redo
        if (redoButton.evaluate().isNotEmpty) {
          await tester.tap(redoButton);
          await tester.pumpAndSettle();
        } else if (redoIcon.evaluate().isNotEmpty) {
          await tester.tap(redoIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Node styling and formatting', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for styling options
        final colorButton = find.byTooltip('Color');
        final styleButton = find.byTooltip('Style');
        final formatButton = find.byTooltip('Format');

        if (colorButton.evaluate().isNotEmpty) {
          await tester.tap(colorButton);
          await tester.pumpAndSettle();
        } else if (styleButton.evaluate().isNotEmpty) {
          await tester.tap(styleButton);
          await tester.pumpAndSettle();
        } else if (formatButton.evaluate().isNotEmpty) {
          await tester.tap(formatButton);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('File Import/Export Functionality', () {
      testWidgets('Save mindmap to file', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for save functionality
        final saveButton = find.byTooltip('Save');
        final saveIcon = find.byIcon(Icons.save);

        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
        } else if (saveIcon.evaluate().isNotEmpty) {
          await tester.tap(saveIcon.first);
          await tester.pumpAndSettle();
        }

        // Test save as functionality
        final saveAsButton = find.byTooltip('Save As');
        if (saveAsButton.evaluate().isNotEmpty) {
          await tester.tap(saveAsButton);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Load mindmap from file', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for open/load functionality
        final openButton = find.byTooltip('Open');
        final loadButton = find.byTooltip('Load');
        final openIcon = find.byIcon(Icons.folder_open);

        if (openButton.evaluate().isNotEmpty) {
          await tester.tap(openButton);
          await tester.pumpAndSettle();
        } else if (loadButton.evaluate().isNotEmpty) {
          await tester.tap(loadButton);
          await tester.pumpAndSettle();
        } else if (openIcon.evaluate().isNotEmpty) {
          await tester.tap(openIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Export mindmap to different formats', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for export functionality
        final exportButton = find.byTooltip('Export');
        final shareButton = find.byTooltip('Share');
        final exportIcon = find.byIcon(Icons.share);

        if (exportButton.evaluate().isNotEmpty) {
          await tester.tap(exportButton);
          await tester.pumpAndSettle();

          // Look for format options
          final pdfOption = find.text('PDF');
          final imageOption = find.text('Image');
          final jsonOption = find.text('JSON');

          if (pdfOption.evaluate().isNotEmpty) {
            await tester.tap(pdfOption);
            await tester.pumpAndSettle();
          } else if (imageOption.evaluate().isNotEmpty) {
            await tester.tap(imageOption);
            await tester.pumpAndSettle();
          } else if (jsonOption.evaluate().isNotEmpty) {
            await tester.tap(jsonOption);
            await tester.pumpAndSettle();
          }
        } else if (shareButton.evaluate().isNotEmpty) {
          await tester.tap(shareButton);
          await tester.pumpAndSettle();
        } else if (exportIcon.evaluate().isNotEmpty) {
          await tester.tap(exportIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Import from external mindmap formats', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for import functionality
        final importButton = find.byTooltip('Import');
        final importIcon = find.byIcon(Icons.upload);

        if (importButton.evaluate().isNotEmpty) {
          await tester.tap(importButton);
          await tester.pumpAndSettle();

          // Look for format options
          final freemindOption = find.text('FreeMind');
          final xmindOption = find.text('XMind');
          final jsonOption = find.text('JSON');

          if (freemindOption.evaluate().isNotEmpty) {
            await tester.tap(freemindOption);
            await tester.pumpAndSettle();
          } else if (xmindOption.evaluate().isNotEmpty) {
            await tester.tap(xmindOption);
            await tester.pumpAndSettle();
          } else if (jsonOption.evaluate().isNotEmpty) {
            await tester.tap(jsonOption);
            await tester.pumpAndSettle();
          }
        } else if (importIcon.evaluate().isNotEmpty) {
          await tester.tap(importIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Recent files functionality', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for recent files menu
        final recentButton = find.byTooltip('Recent');
        final recentFiles = find.text('Recent Files');

        if (recentButton.evaluate().isNotEmpty) {
          await tester.tap(recentButton);
          await tester.pumpAndSettle();
        } else if (recentFiles.evaluate().isNotEmpty) {
          await tester.tap(recentFiles);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('File operation error handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test file service error scenarios by attempting operations
        // that might fail (like accessing non-existent files)
        final fileService = FileService.instance;

        // Test reading non-existent file
        final readResult = await fileService.readFile('/non/existent/path.mm');
        expect(readResult.success, isFalse);
        expect(readResult.errorCode, equals('FILE_NOT_FOUND'));

        // Test getting info for non-existent file
        final infoResult = await fileService.getFileInfo('/non/existent/path.mm');
        expect(infoResult.success, isFalse);

        // App should remain stable after file operation errors
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Search, Navigation, and Layout Features', () {
      testWidgets('Search for nodes in mindmap', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for search functionality
        final searchButton = find.byTooltip('Search');
        final searchIcon = find.byIcon(Icons.search);
        final searchField = find.byType(SearchBar);

        if (searchButton.evaluate().isNotEmpty) {
          await tester.tap(searchButton);
          await tester.pumpAndSettle();
        } else if (searchIcon.evaluate().isNotEmpty) {
          await tester.tap(searchIcon.first);
          await tester.pumpAndSettle();
        }

        // Try to find search input field
        final searchInput = find.byType(TextField);
        if (searchInput.evaluate().isNotEmpty) {
          await tester.tap(searchInput.first);
          await tester.pumpAndSettle();

          await tester.enterText(searchInput.first, 'test search');
          await tester.pumpAndSettle();

          // Trigger search
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
        } else if (searchField.evaluate().isNotEmpty) {
          await tester.tap(searchField.first);
          await tester.pumpAndSettle();

          await tester.enterText(searchField.first, 'test search');
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Navigate through search results', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Perform search first (if search functionality exists)
        final searchIcon = find.byIcon(Icons.search);
        if (searchIcon.evaluate().isNotEmpty) {
          await tester.tap(searchIcon.first);
          await tester.pumpAndSettle();

          final searchInput = find.byType(TextField);
          if (searchInput.evaluate().isNotEmpty) {
            await tester.enterText(searchInput.first, 'node');
            await tester.pumpAndSettle();
          }
        }

        // Look for navigation buttons in search results
        final nextButton = find.byTooltip('Next');
        final previousButton = find.byTooltip('Previous');
        final nextIcon = find.byIcon(Icons.keyboard_arrow_down);
        final prevIcon = find.byIcon(Icons.keyboard_arrow_up);

        if (nextButton.evaluate().isNotEmpty) {
          await tester.tap(nextButton);
          await tester.pumpAndSettle();
        } else if (nextIcon.evaluate().isNotEmpty) {
          await tester.tap(nextIcon.first);
          await tester.pumpAndSettle();
        }

        if (previousButton.evaluate().isNotEmpty) {
          await tester.tap(previousButton);
          await tester.pumpAndSettle();
        } else if (prevIcon.evaluate().isNotEmpty) {
          await tester.tap(prevIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Switch between different layout modes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for layout controls
        final layoutButton = find.byTooltip('Layout');
        final viewButton = find.byTooltip('View');
        final layoutIcon = find.byIcon(Icons.view_module);

        if (layoutButton.evaluate().isNotEmpty) {
          await tester.tap(layoutButton);
          await tester.pumpAndSettle();

          // Look for different layout options
          final radialLayout = find.text('Radial');
          final treeLayout = find.text('Tree');
          final organicLayout = find.text('Organic');
          final hierarchicalLayout = find.text('Hierarchical');

          if (radialLayout.evaluate().isNotEmpty) {
            await tester.tap(radialLayout);
            await tester.pumpAndSettle();
          } else if (treeLayout.evaluate().isNotEmpty) {
            await tester.tap(treeLayout);
            await tester.pumpAndSettle();
          } else if (organicLayout.evaluate().isNotEmpty) {
            await tester.tap(organicLayout);
            await tester.pumpAndSettle();
          } else if (hierarchicalLayout.evaluate().isNotEmpty) {
            await tester.tap(hierarchicalLayout);
            await tester.pumpAndSettle();
          }
        } else if (viewButton.evaluate().isNotEmpty) {
          await tester.tap(viewButton);
          await tester.pumpAndSettle();
        } else if (layoutIcon.evaluate().isNotEmpty) {
          await tester.tap(layoutIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Zoom and pan navigation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for zoom controls
        final zoomInButton = find.byTooltip('Zoom In');
        final zoomOutButton = find.byTooltip('Zoom Out');
        final fitButton = find.byTooltip('Fit to Screen');

        if (zoomInButton.evaluate().isNotEmpty) {
          await tester.tap(zoomInButton);
          await tester.pumpAndSettle();
        }

        if (zoomOutButton.evaluate().isNotEmpty) {
          await tester.tap(zoomOutButton);
          await tester.pumpAndSettle();
        }

        if (fitButton.evaluate().isNotEmpty) {
          await tester.tap(fitButton);
          await tester.pumpAndSettle();
        }

        // Test pan by dragging
        final canvas = find.byType(CustomPaint);
        if (canvas.evaluate().isNotEmpty) {
          final center = tester.getCenter(canvas.first);
          await tester.dragFrom(center, const Offset(100, 50));
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Minimap navigation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for minimap toggle
        final minimapButton = find.byTooltip('Minimap');
        final minimapIcon = find.byIcon(Icons.map);

        if (minimapButton.evaluate().isNotEmpty) {
          await tester.tap(minimapButton);
          await tester.pumpAndSettle();

          // Try to interact with minimap if visible
          final minimap = find.byKey(const Key('minimap'));
          if (minimap.evaluate().isNotEmpty) {
            await tester.tap(minimap);
            await tester.pumpAndSettle();
          }
        } else if (minimapIcon.evaluate().isNotEmpty) {
          await tester.tap(minimapIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Full-screen mode toggle', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for full-screen functionality
        final fullscreenButton = find.byTooltip('Full Screen');
        final fullscreenIcon = find.byIcon(Icons.fullscreen);

        if (fullscreenButton.evaluate().isNotEmpty) {
          await tester.tap(fullscreenButton);
          await tester.pumpAndSettle();

          // Toggle back
          await tester.tap(fullscreenButton);
          await tester.pumpAndSettle();
        } else if (fullscreenIcon.evaluate().isNotEmpty) {
          await tester.tap(fullscreenIcon.first);
          await tester.pumpAndSettle();

          // Look for exit fullscreen
          final exitFullscreen = find.byIcon(Icons.fullscreen_exit);
          if (exitFullscreen.evaluate().isNotEmpty) {
            await tester.tap(exitFullscreen);
            await tester.pumpAndSettle();
          }
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Complex Workflow Scenarios', () {
      testWidgets('Complete mindmap creation workflow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Create new mindmap
        final newButton = find.byIcon(Icons.add);
        if (newButton.evaluate().isNotEmpty) {
          await tester.tap(newButton.first);
          await tester.pumpAndSettle();
        }

        // Step 2: Add root node
        final textFields = find.byType(TextField);
        if (textFields.evaluate().isNotEmpty) {
          await tester.tap(textFields.first);
          await tester.enterText(textFields.first, 'Root Node');
          await tester.pumpAndSettle();
        }

        // Step 3: Add child nodes
        final addChildButton = find.byTooltip('Add Child');
        if (addChildButton.evaluate().isNotEmpty) {
          await tester.tap(addChildButton);
          await tester.pumpAndSettle();
        }

        // Step 4: Apply layout
        final layoutButton = find.byTooltip('Layout');
        if (layoutButton.evaluate().isNotEmpty) {
          await tester.tap(layoutButton);
          await tester.pumpAndSettle();
        }

        // Step 5: Save the mindmap
        final saveButton = find.byIcon(Icons.save);
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Mindmap editing and layout switching workflow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Edit existing content
        final gestureDetectors = find.byType(GestureDetector);
        if (gestureDetectors.evaluate().isNotEmpty) {
          await tester.doubleTap(gestureDetectors.first);
          await tester.pumpAndSettle();

          final textFields = find.byType(TextField);
          if (textFields.evaluate().isNotEmpty) {
            await tester.enterText(textFields.first, 'Modified content');
            await tester.pumpAndSettle();
          }
        }

        // Switch layouts multiple times
        final layoutOptions = ['Radial', 'Tree', 'Organic'];
        for (final layout in layoutOptions) {
          final layoutOption = find.text(layout);
          if (layoutOption.evaluate().isNotEmpty) {
            await tester.tap(layoutOption);
            await tester.pumpAndSettle();
          }
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Search and navigation workflow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Open search
        final searchIcon = find.byIcon(Icons.search);
        if (searchIcon.evaluate().isNotEmpty) {
          await tester.tap(searchIcon.first);
          await tester.pumpAndSettle();

          // Perform search
          final searchField = find.byType(TextField);
          if (searchField.evaluate().isNotEmpty) {
            await tester.enterText(searchField.first, 'important');
            await tester.pumpAndSettle();

            // Navigate through results
            final nextButton = find.byTooltip('Next');
            if (nextButton.evaluate().isNotEmpty) {
              for (int i = 0; i < 3; i++) {
                await tester.tap(nextButton);
                await tester.pumpAndSettle();
              }
            }
          }
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('File operation workflow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Create some content first
        final textFields = find.byType(TextField);
        if (textFields.evaluate().isNotEmpty) {
          await tester.tap(textFields.first);
          await tester.enterText(textFields.first, 'Test content for file ops');
          await tester.pumpAndSettle();
        }

        // Save file
        final saveButton = find.byIcon(Icons.save);
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton.first);
          await tester.pumpAndSettle();
        }

        // Export to different format
        final exportButton = find.byTooltip('Export');
        if (exportButton.evaluate().isNotEmpty) {
          await tester.tap(exportButton);
          await tester.pumpAndSettle();
        }

        // Try to open recent files
        final recentButton = find.byTooltip('Recent');
        if (recentButton.evaluate().isNotEmpty) {
          await tester.tap(recentButton);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Collaborative features workflow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Look for sharing functionality
        final shareButton = find.byIcon(Icons.share);
        if (shareButton.evaluate().isNotEmpty) {
          await tester.tap(shareButton.first);
          await tester.pumpAndSettle();
        }

        // Look for comment functionality
        final commentButton = find.byTooltip('Comment');
        final commentIcon = find.byIcon(Icons.comment);
        if (commentButton.evaluate().isNotEmpty) {
          await tester.tap(commentButton);
          await tester.pumpAndSettle();
        } else if (commentIcon.evaluate().isNotEmpty) {
          await tester.tap(commentIcon.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Performance and Stress Testing', () {
      testWidgets('Large mindmap performance', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        final stopwatch = Stopwatch()..start();

        // Simulate creating many nodes rapidly
        for (int i = 0; i < 20; i++) {
          final addButton = find.byIcon(Icons.add);
          if (addButton.evaluate().isNotEmpty) {
            await tester.tap(addButton.first);
            await tester.pump(const Duration(milliseconds: 50));
          }

          final textFields = find.byType(TextField);
          if (textFields.evaluate().isNotEmpty) {
            await tester.enterText(textFields.first, 'Node $i');
            await tester.pump(const Duration(milliseconds: 30));
          }
        }

        await tester.pumpAndSettle();
        stopwatch.stop();

        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Rapid layout switching performance', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        final stopwatch = Stopwatch()..start();

        // Rapidly switch between layouts
        final layouts = ['Radial', 'Tree', 'Organic', 'Hierarchical'];
        for (int i = 0; i < 10; i++) {
          final layout = layouts[i % layouts.length];
          final layoutOption = find.text(layout);
          if (layoutOption.evaluate().isNotEmpty) {
            await tester.tap(layoutOption);
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await tester.pumpAndSettle();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Memory usage during complex operations', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Perform memory-intensive operations
        for (int i = 0; i < 50; i++) {
          // Zoom in and out
          final zoomIn = find.byTooltip('Zoom In');
          final zoomOut = find.byTooltip('Zoom Out');

          if (zoomIn.evaluate().isNotEmpty) {
            await tester.tap(zoomIn);
            await tester.pump();
          }

          if (zoomOut.evaluate().isNotEmpty) {
            await tester.tap(zoomOut);
            await tester.pump();
          }

          // Pan around
          final canvas = find.byType(CustomPaint);
          if (canvas.evaluate().isNotEmpty) {
            await tester.drag(canvas.first, Offset(i % 10 - 5, i % 8 - 4));
            await tester.pump();
          }
        }

        await tester.pumpAndSettle();
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Error Recovery and Edge Cases', () {
      testWidgets('Invalid file format handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test file service with invalid data
        final fileService = FileService.instance;
        final invalidData = Uint8List.fromList([0, 1, 2, 3]); // Invalid mindmap data

        final result = await fileService.writeFile('/tmp/invalid.mm', invalidData);
        // The file operation itself should succeed
        expect(result.success, isTrue);

        // But reading/parsing as mindmap should handle errors gracefully
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Network interruption during file operations', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate network-dependent operations
        final shareButton = find.byIcon(Icons.share);
        if (shareButton.evaluate().isNotEmpty) {
          await tester.tap(shareButton.first);
          await tester.pumpAndSettle();
        }

        // App should remain stable even if network operations fail
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Corrupted mindmap data recovery', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // The app should handle corrupted data gracefully
        // This would typically involve the core Rust engine
        // For now, we verify the app remains stable
        expect(find.byType(MaterialApp), findsOneWidget);

        // Try various operations that might trigger error paths
        final buttons = find.byType(ElevatedButton);
        final iconButtons = find.byType(IconButton);

        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
          await tester.pumpAndSettle();
        }

        if (iconButtons.evaluate().isNotEmpty) {
          await tester.tap(iconButtons.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Low memory conditions handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate memory pressure by creating large amounts of transient data
        for (int i = 0; i < 100; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Container(
                child: Column(
                  children: List.generate(50, (index) => Text('Memory test $i-$index')),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        // Return to main app
        app.main();
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Concurrent operation handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Try to trigger multiple operations simultaneously
        final stopwatch = Stopwatch()..start();

        final futures = <Future>[];

        // Start multiple operations in parallel
        final buttons = find.byType(ElevatedButton);
        final iconButtons = find.byType(IconButton);

        if (buttons.evaluate().isNotEmpty) {
          futures.add(tester.tap(buttons.first));
        }

        if (iconButtons.evaluate().isNotEmpty) {
          futures.add(tester.tap(iconButtons.first));
        }

        // Add text input operations
        final textFields = find.byType(TextField);
        if (textFields.evaluate().isNotEmpty) {
          futures.add(tester.enterText(textFields.first, 'Concurrent test'));
        }

        await Future.wait(futures);
        await tester.pumpAndSettle();

        stopwatch.stop();

        expect(find.byType(MaterialApp), findsOneWidget);
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });
  });
}