# Implementation Plan

## Task Overview

This implementation plan breaks down the cross-platform mindmap application into atomic, agent-friendly tasks that follow a logical development sequence. The approach prioritizes establishing core infrastructure (Rust engine, FFI bridge) before building the Flutter UI layer, ensuring a solid foundation for the complete application.

## Steering Document Compliance

Following the established technical standards and project structure:
- **Rust Core First**: Build the graph engine and data models before UI components
- **FFI Integration**: Establish type-safe Rust-Flutter communication early
- **Testing-Driven**: Include comprehensive testing for each component
- **Cross-Platform Considerations**: Ensure platform compatibility throughout development
- **Performance Focus**: Implement performance monitoring and optimization from the start

## Atomic Task Requirements

**Each task must meet these criteria for optimal agent execution:**
- **File Scope**: Touches 1-3 related files maximum
- **Time Boxing**: Completable in 15-30 minutes
- **Single Purpose**: One testable outcome per task
- **Specific Files**: Must specify exact files to create/modify
- **Agent-Friendly**: Clear input/output with minimal context switching

## Task Format Guidelines

- Use checkbox format: `- [ ] Task number. Task description`
- **Specify files**: Always include exact file paths to create/modify
- **Include implementation details** as bullet points
- Reference requirements using: `_Requirements: REQ-MM-XXX_`
- Reference existing code to leverage using: `_Leverage: path/to/file.rs, path/to/component.dart_`
- Focus only on coding tasks (no deployment, user testing, etc.)
- **Avoid broad terms**: No "system", "integration", "complete" in task titles

## Good vs Bad Task Examples

L **Bad Examples (Too Broad)**:
- "Implement authentication system" (affects many files, multiple purposes)
- "Add user management features" (vague scope, no file specification)
- "Build complete dashboard" (too large, multiple components)

 **Good Examples (Atomic)**:
- "Create User model in models/user.py with email/password fields"
- "Add password hashing utility in utils/auth.py using bcrypt"
- "Create LoginForm component in components/LoginForm.tsx with email/password inputs"

## Tasks

### Phase 1: Project Setup and Core Infrastructure

- [ ] 1. Create Rust workspace Cargo.toml in rust_core/
  - File: rust_core/Cargo.toml
  - Initialize Cargo workspace with core dependencies (serde, uuid, chrono, rusqlite)
  - Configure target platforms for cross-compilation (macOS, Windows, iOS)
  - Set workspace metadata and edition
  - _Requirements: REQ-MM-008_

- [ ] 2. Create Rust library entry point in rust_core/src/lib.rs
  - File: rust_core/src/lib.rs
  - Set up basic module structure with pub mod declarations
  - Define public API exports for FFI interface
  - Add conditional compilation flags for different platforms
  - _Requirements: REQ-MM-008_

- [ ] 3. Create types module structure in rust_core/src/types/mod.rs
  - File: rust_core/src/types/mod.rs
  - Set up types module with public exports for ids and position
  - Add common type aliases and utility functions
  - Define module organization for data types
  - _Requirements: REQ-MM-001_

- [ ] 4. Create ID wrapper types in rust_core/src/types/ids.rs
  - File: rust_core/src/types/ids.rs
  - Define NodeId, EdgeId, MindmapId wrapper types using UUID v4
  - Implement Display, Debug, and Hash traits for ID types
  - Add Serialize/Deserialize derives for all ID types
  - _Requirements: REQ-MM-001_

- [ ] 5. Create Position type in rust_core/src/types/position.rs
  - File: rust_core/src/types/position.rs
  - Implement Position struct with f64 x, y coordinates
  - Add basic geometric operations (distance, translation, scaling)
  - Include Serialize/Deserialize and Default implementations
  - _Requirements: REQ-MM-003_

- [ ] 6. Implement Node model in rust_core/src/models/node.rs
  - File: rust_core/src/models/node.rs
  - Create Node struct with all required fields (id, parent_id, text, style, position, attachments, tags, timestamps, metadata)
  - Implement Default trait and constructor methods
  - Add validation methods for text content and parent relationships
  - _Requirements: REQ-MM-001, REQ-MM-006_

- [ ] 7. Implement Edge model in rust_core/src/models/edge.rs
  - File: rust_core/src/models/edge.rs
  - Create Edge struct with id, from_node, to_node, edge_type, label, style, timestamps
  - Define EdgeType enum (ParentChild, CrossLink, etc.)
  - Implement validation for edge relationships and cycles
  - _Requirements: REQ-MM-001_

- [ ] 8. Create NodeStyle and EdgeStyle models in rust_core/src/models/style.rs
  - File: rust_core/src/models/style.rs
  - Implement NodeStyle struct with color, font, shape, padding properties
  - Create EdgeStyle struct with line style, arrow, and color properties
  - Define enums for FontWeight, NodeShape, etc.
  - _Requirements: REQ-MM-001_

### Phase 2: Graph Engine and Core Operations

- [ ] 9. Create graph data structure in rust_core/src/graph/mod.rs
  - Files: rust_core/src/graph/mod.rs, rust_core/src/graph/graph.rs
  - Implement Graph struct using HashMap<NodeId, Node> and HashMap<EdgeId, Edge>
  - Add methods for node/edge insertion, removal, and validation
  - Implement graph traversal utilities (children, ancestors, paths)
  - _Requirements: REQ-MM-001_
  - _Leverage: rust_core/src/models/node.rs, rust_core/src/models/edge.rs_

- [ ] 7. Add graph operations in rust_core/src/graph/operations.rs
  - File: rust_core/src/graph/operations.rs
  - Implement add_node, update_node, delete_node methods with relationship management
  - Add edge creation and validation with cycle detection
  - Implement node hierarchy validation and parent-child consistency
  - _Requirements: REQ-MM-001, REQ-MM-003_
  - _Leverage: rust_core/src/graph/graph.rs_

- [ ] 8. Create search functionality in rust_core/src/search/mod.rs
  - Files: rust_core/src/search/mod.rs, rust_core/src/search/fuzzy.rs
  - Implement fuzzy text search using simple string matching algorithms
  - Create SearchResult struct with node reference and match score
  - Add search indexing for node text content with ranking
  - _Requirements: REQ-MM-004_
  - _Leverage: rust_core/src/graph/graph.rs_

- [ ] 9. Implement radial layout algorithm in rust_core/src/layout/radial.rs
  - Files: rust_core/src/layout/mod.rs, rust_core/src/layout/radial.rs
  - Create LayoutEngine trait with calculate_layout method
  - Implement radial layout using polar coordinates from root node
  - Add angle distribution and radius calculation for child nodes
  - _Requirements: REQ-MM-002_
  - _Leverage: rust_core/src/types/position.rs, rust_core/src/graph/graph.rs_

- [ ] 10. Implement tree layout algorithm in rust_core/src/layout/tree.rs
  - File: rust_core/src/layout/tree.rs
  - Create hierarchical tree layout with level-based positioning
  - Implement node spacing calculation to avoid overlaps
  - Add support for left-to-right and top-to-bottom orientations
  - _Requirements: REQ-MM-002_
  - _Leverage: rust_core/src/layout/radial.rs_

- [ ] 11. Implement force-directed layout in rust_core/src/layout/force.rs
  - File: rust_core/src/layout/force.rs
  - Create basic force-directed algorithm with spring forces
  - Implement iterative position updates with configurable parameters
  - Add collision detection and boundary constraints
  - _Requirements: REQ-MM-002_
  - _Leverage: rust_core/src/layout/radial.rs_

### Phase 3: Data Persistence and Storage

- [ ] 12. Create persistence module in rust_core/src/persistence/mod.rs
  - Files: rust_core/src/persistence/mod.rs, rust_core/src/persistence/sqlite.rs
  - Set up SQLite database schema for nodes, edges, and mindmaps
  - Implement database connection management and migration support
  - Create basic CRUD operations for database entities
  - _Requirements: REQ-MM-007_

- [ ] 13. Implement MindmapDocument model in rust_core/src/models/document.rs
  - File: rust_core/src/models/document.rs
  - Create MindmapDocument struct with id, title, root_node, nodes, edges, view_state, settings
  - Implement serialization/deserialization for complete documents
  - Add document validation and consistency checking methods
  - _Requirements: REQ-MM-007_
  - _Leverage: rust_core/src/models/node.rs, rust_core/src/models/edge.rs_

- [ ] 14. Add persistence manager in rust_core/src/persistence/manager.rs
  - File: rust_core/src/persistence/manager.rs
  - Implement PersistenceManager struct with save/load methods
  - Add auto-save functionality with configurable intervals
  - Create backup and recovery mechanisms for data safety
  - _Requirements: REQ-MM-007_
  - _Leverage: rust_core/src/persistence/sqlite.rs, rust_core/src/models/document.rs_

- [ ] 15. Create file format handlers in rust_core/src/io/mod.rs
  - Files: rust_core/src/io/mod.rs, rust_core/src/io/opml.rs, rust_core/src/io/markdown.rs
  - Implement OPML import/export with node hierarchy preservation
  - Add Markdown outline import/export functionality
  - Create format detection and validation utilities
  - _Requirements: REQ-MM-005_
  - _Leverage: rust_core/src/models/document.rs_

### Phase 4: FFI Bridge and Flutter Integration

- [ ] 16. Set up Flutter-Rust bridge in rust_core/src/ffi/mod.rs
  - Files: rust_core/src/ffi/mod.rs, rust_core/Cargo.toml (add flutter_rust_bridge)
  - Configure flutter_rust_bridge dependencies and build setup
  - Define bridge error types and conversion utilities
  - Create basic FFI interface structure and exports
  - _Requirements: REQ-MM-008_

- [ ] 17. Implement FFI node operations in rust_core/src/ffi/node_ops.rs
  - File: rust_core/src/ffi/node_ops.rs
  - Create FFI functions for create_node, update_node_text, delete_node
  - Implement get_node_children and node hierarchy operations
  - Add proper error handling and type conversion for FFI boundary
  - _Requirements: REQ-MM-001_
  - _Leverage: rust_core/src/graph/operations.rs, rust_core/src/ffi/mod.rs_

- [ ] 18. Add FFI layout operations in rust_core/src/ffi/layout_ops.rs
  - File: rust_core/src/ffi/layout_ops.rs
  - Implement calculate_layout FFI function with LayoutType parameter
  - Create update_node_position for manual positioning
  - Add layout result serialization for Flutter consumption
  - _Requirements: REQ-MM-002, REQ-MM-003_
  - _Leverage: rust_core/src/layout/mod.rs, rust_core/src/ffi/mod.rs_

- [ ] 19. Implement FFI search operations in rust_core/src/ffi/search_ops.rs
  - File: rust_core/src/ffi/search_ops.rs
  - Create search_nodes FFI function with query string input
  - Implement search result serialization with match scores
  - Add search result navigation and highlighting support
  - _Requirements: REQ-MM-004_
  - _Leverage: rust_core/src/search/mod.rs, rust_core/src/ffi/mod.rs_

- [ ] 20. Create FFI file operations in rust_core/src/ffi/file_ops.rs
  - File: rust_core/src/ffi/file_ops.rs
  - Implement save_mindmap and load_mindmap FFI functions
  - Add export_mindmap with format selection (PDF, SVG, PNG, OPML, Markdown)
  - Create import functionality for supported file formats
  - _Requirements: REQ-MM-005, REQ-MM-007_
  - _Leverage: rust_core/src/persistence/manager.rs, rust_core/src/io/mod.rs_

### Phase 5: Flutter Application Setup

- [ ] 21. Create Flutter pubspec.yaml configuration
  - File: flutter_app/pubspec.yaml
  - Initialize Flutter project with required dependencies (flutter_rust_bridge, provider, material design)
  - Configure platform-specific dependencies and build settings
  - Set app metadata and version information
  - _Requirements: REQ-MM-008_

- [ ] 22. Create Flutter main.dart entry point
  - File: flutter_app/lib/main.dart
  - Set up main() function with runApp() and basic error handling
  - Initialize platform-specific configurations and services
  - Configure app-level settings and theme mode
  - _Requirements: REQ-MM-008_

- [ ] 23. Create Flutter app.dart structure
  - File: flutter_app/lib/app.dart
  - Implement MaterialApp with theme configuration and routing
  - Set up basic navigation structure and home page
  - Configure platform-adaptive design settings
  - _Requirements: REQ-MM-008_

- [ ] 24. Set up Flutter-Rust bridge client in flutter_app/lib/bridge/
  - Files: flutter_app/lib/bridge/mindmap_bridge.dart, flutter_app/lib/bridge/bridge_types.dart
  - Generate Dart bindings from Rust FFI interface
  - Create type conversion utilities for Dart-Rust communication
  - Implement error handling and exception mapping
  - _Requirements: REQ-MM-008_
  - _Leverage: rust_core/src/ffi/mod.rs_

- [ ] 25. Create state management in flutter_app/lib/state/
  - Files: flutter_app/lib/state/mindmap_state.dart, flutter_app/lib/state/app_state.dart
  - Implement MindmapState using ChangeNotifier for document management
  - Create AppState for global application settings and preferences
  - Add state persistence and restoration capabilities
  - _Requirements: REQ-MM-007, REQ-MM-008_

- [ ] 24. Implement node data models in flutter_app/lib/models/
  - Files: flutter_app/lib/models/node.dart, flutter_app/lib/models/edge.dart, flutter_app/lib/models/document.dart
  - Create Dart equivalents of Rust data models for UI layer
  - Implement JSON serialization for state management
  - Add conversion utilities between Dart and FFI types
  - _Requirements: REQ-MM-001_
  - _Leverage: rust_core/src/models/node.rs, flutter_app/lib/bridge/bridge_types.dart_

### Phase 6: Core UI Components

- [ ] 25. Create base mindmap canvas in flutter_app/lib/widgets/mindmap_canvas.dart
  - File: flutter_app/lib/widgets/mindmap_canvas.dart
  - Implement CustomPainter for mindmap rendering
  - Add basic zoom, pan, and viewport management
  - Create coordinate transformation utilities for screen-to-canvas mapping
  - _Requirements: REQ-MM-001, REQ-MM-003_
  - _Leverage: flutter_app/lib/models/node.dart_

- [ ] 26. Implement node widget in flutter_app/lib/widgets/node_widget.dart
  - File: flutter_app/lib/widgets/node_widget.dart
  - Create NodeWidget with text display and editing capabilities
  - Implement node selection, focus, and visual states
  - Add rich text formatting support (bold, italic, code)
  - _Requirements: REQ-MM-001_
  - _Leverage: flutter_app/lib/models/node.dart_

- [ ] 27. Add gesture handling in flutter_app/lib/widgets/gesture_handler.dart
  - File: flutter_app/lib/widgets/gesture_handler.dart
  - Implement drag and drop functionality for node repositioning
  - Add tap, double-tap, and long-press gesture recognition
  - Create gesture-to-action mapping with proper event handling
  - _Requirements: REQ-MM-003_
  - _Leverage: flutter_app/lib/widgets/mindmap_canvas.dart_

- [ ] 28. Create search interface in flutter_app/lib/widgets/search_widget.dart
  - File: flutter_app/lib/widgets/search_widget.dart
  - Implement search input field with real-time query updates
  - Add search results dropdown with node navigation
  - Create keyboard shortcuts for search result cycling
  - _Requirements: REQ-MM-004_
  - _Leverage: flutter_app/lib/bridge/mindmap_bridge.dart_

- [ ] 29. Implement layout controls in flutter_app/lib/widgets/layout_controls.dart
  - File: flutter_app/lib/widgets/layout_controls.dart
  - Create layout selection buttons (radial, tree, force-directed)
  - Add animation controls for smooth layout transitions
  - Implement layout-specific configuration options
  - _Requirements: REQ-MM-002_
  - _Leverage: flutter_app/lib/bridge/mindmap_bridge.dart_

### Phase 7: Advanced Features and Platform Integration

- [ ] 30. Add attachment support in flutter_app/lib/widgets/attachment_widget.dart
  - File: flutter_app/lib/widgets/attachment_widget.dart
  - Implement file attachment display with thumbnail previews
  - Add link attachment with URL validation and click handling
  - Create attachment management UI (add, remove, edit)
  - _Requirements: REQ-MM-006_
  - _Leverage: flutter_app/lib/widgets/node_widget.dart_

- [ ] 31. Create platform file service in flutter_app/lib/services/file_service.dart
  - File: flutter_app/lib/services/file_service.dart
  - Implement platform channels for native file picker integration
  - Add file sharing and export functionality using platform APIs
  - Create cross-platform file path and permission handling
  - _Requirements: REQ-MM-005, REQ-MM-008_

- [ ] 32. Implement keyboard shortcuts in flutter_app/lib/services/keyboard_service.dart
  - File: flutter_app/lib/services/keyboard_service.dart
  - Create platform-adaptive keyboard shortcut registration
  - Implement shortcuts for node creation (Enter, Tab), navigation, and editing
  - Add undo/redo keyboard support with state management integration
  - _Requirements: REQ-MM-001, REQ-MM-008_
  - _Leverage: flutter_app/lib/state/mindmap_state.dart_

- [ ] 33. Add application menu in flutter_app/lib/widgets/app_menu.dart
  - File: flutter_app/lib/widgets/app_menu.dart
  - Create platform-native menu bar for desktop platforms
  - Implement File, Edit, View, Layout menu structure
  - Add menu item actions connected to application state
  - _Requirements: REQ-MM-005, REQ-MM-008_
  - _Leverage: flutter_app/lib/services/file_service.dart_

### Phase 8: Testing and Quality Assurance

- [ ] 34. Create graph operations unit tests in rust_core/tests/graph_tests.rs
  - File: rust_core/tests/graph_tests.rs
  - Implement comprehensive unit tests for node and edge operations
  - Add tests for graph traversal and validation functions
  - Create property-based tests for graph invariants using PropTest
  - _Requirements: REQ-MM-001_
  - _Leverage: rust_core/src/graph/mod.rs_

- [ ] 35. Create layout algorithm tests in rust_core/tests/layout_tests.rs
  - File: rust_core/tests/layout_tests.rs
  - Add unit tests for radial, tree, and force-directed layouts
  - Implement performance benchmarks for layout algorithms
  - Create tests for layout edge cases and large graphs
  - _Requirements: REQ-MM-002_
  - _Leverage: rust_core/src/layout/mod.rs_

- [ ] 36. Create persistence tests in rust_core/tests/persistence_tests.rs
  - File: rust_core/tests/persistence_tests.rs
  - Implement persistence round-trip tests for data integrity
  - Add tests for auto-save and backup functionality
  - Create tests for database migration and error recovery
  - _Requirements: REQ-MM-007_
  - _Leverage: rust_core/src/persistence/mod.rs_

- [ ] 37. Create Flutter widget tests in flutter_app/test/widget_test.dart
  - File: flutter_app/test/widget_test.dart
  - Implement basic widget testing framework setup
  - Add tests for app initialization and routing
  - Create utility functions for test data and mocking
  - _Requirements: REQ-MM-008_
  - _Leverage: flutter_app/lib/main.dart_

- [ ] 38. Add NodeWidget tests in flutter_app/test/node_widget_test.dart
  - File: flutter_app/test/node_widget_test.dart
  - Create widget tests for NodeWidget with various states
  - Test text editing, selection, and styling functionality
  - Add golden file tests for visual regression detection
  - _Requirements: REQ-MM-001_
  - _Leverage: flutter_app/lib/widgets/node_widget.dart_

- [ ] 39. Add MindmapCanvas tests in flutter_app/test/canvas_test.dart
  - File: flutter_app/test/canvas_test.dart
  - Implement MindmapCanvas testing with gesture simulation
  - Test zoom, pan, and viewport management functionality
  - Create tests for node rendering and coordinate transformation
  - _Requirements: REQ-MM-003_
  - _Leverage: flutter_app/lib/widgets/mindmap_canvas.dart_

- [ ] 40. Create app integration tests in flutter_app/integration_test/app_test.dart
  - File: flutter_app/integration_test/app_test.dart
  - Set up integration testing framework and basic app flow tests
  - Test application startup and basic navigation
  - Add tests for cross-platform functionality
  - _Requirements: REQ-MM-008_
  - _Leverage: flutter_app/lib/main.dart_

- [ ] 41. Add mindmap workflow tests in flutter_app/integration_test/mindmap_workflow_test.dart
  - File: flutter_app/integration_test/mindmap_workflow_test.dart
  - Create end-to-end tests for complete mindmap creation workflow
  - Add tests for file import/export functionality
  - Test search, navigation, and layout switching features
  - _Requirements: REQ-MM-001, REQ-MM-004, REQ-MM-005_
  - _Leverage: flutter_app/lib/services/file_service.dart_

### Phase 9: Performance Optimization and Polish

- [ ] 42. Create metrics module in rust_core/src/metrics/mod.rs
  - File: rust_core/src/metrics/mod.rs
  - Set up metrics collection framework and data structures
  - Define performance measurement interfaces and timing utilities
  - Create metrics aggregation and reporting functionality
  - _Requirements: REQ-MM-002 (Performance)_

- [ ] 43. Add performance monitoring in rust_core/src/metrics/performance.rs
  - File: rust_core/src/metrics/performance.rs
  - Implement operation timing and memory usage tracking
  - Create performance benchmarks for layout algorithms
  - Add metrics collection for large mindmap handling (>1000 nodes)
  - _Requirements: REQ-MM-002 (Performance)_
  - _Leverage: rust_core/src/layout/mod.rs, rust_core/src/graph/mod.rs_

- [ ] 44. Create viewport manager in flutter_app/lib/rendering/viewport_manager.dart
  - File: flutter_app/lib/rendering/viewport_manager.dart
  - Implement viewport-based node rendering with culling
  - Add zoom level and coordinate transformation management
  - Create viewport bounds calculation and optimization
  - _Requirements: REQ-MM-002 (Performance)_
  - _Leverage: flutter_app/lib/widgets/mindmap_canvas.dart_

- [ ] 45. Add node virtualization in flutter_app/lib/rendering/node_virtualization.dart
  - File: flutter_app/lib/rendering/node_virtualization.dart
  - Implement level-of-detail rendering for distant nodes
  - Add smart caching and memory management for large mindmaps
  - Create progressive loading and background prefetching
  - _Requirements: REQ-MM-002 (Performance)_
  - _Leverage: flutter_app/lib/rendering/viewport_manager.dart_

- [ ] 46. Create screen reader support in flutter_app/lib/accessibility/screen_reader.dart
  - File: flutter_app/lib/accessibility/screen_reader.dart
  - Implement screen reader compatibility with semantic labels
  - Add ARIA-like descriptions for complex UI elements
  - Create voice navigation assistance for mindmap structures
  - _Requirements: REQ-MM-008 (Accessibility)_
  - _Leverage: flutter_app/lib/widgets/node_widget.dart_

- [ ] 47. Add keyboard navigation in flutter_app/lib/accessibility/keyboard_navigation.dart
  - File: flutter_app/lib/accessibility/keyboard_navigation.dart
  - Implement keyboard-only navigation for all UI elements
  - Add focus management and tab order optimization
  - Create keyboard shortcuts for accessibility features
  - _Requirements: REQ-MM-008 (Accessibility)_
  - _Leverage: flutter_app/lib/services/keyboard_service.dart_

- [ ] 48. Create app configuration in flutter_app/lib/config/app_config.dart
  - File: flutter_app/lib/config/app_config.dart
  - Implement application settings and preferences management
  - Add theme configuration and platform-specific settings
  - Create configuration persistence and validation
  - _Requirements: REQ-MM-008_
  - _Leverage: flutter_app/lib/state/app_state.dart_

- [ ] 49. Add final error handling in flutter_app/lib/utils/error_handler.dart
  - File: flutter_app/lib/utils/error_handler.dart
  - Implement global error handling and user feedback systems
  - Add crash reporting and recovery mechanisms
  - Create user-friendly error messages and fallback behaviors
  - _Requirements: REQ-MM-007, REQ-MM-008_
  - _Leverage: flutter_app/lib/bridge/mindmap_bridge.dart_