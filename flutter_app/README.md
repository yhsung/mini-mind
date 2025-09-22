# Mindmap Flutter App

Cross-platform mindmap application built with Flutter and powered by a Rust core engine.

## Features

- **Cross-Platform**: Runs on iOS, Android, macOS, Windows, Linux, and Web
- **High Performance**: Rust core engine for optimal performance and memory efficiency
- **Multiple Layout Algorithms**: Radial, tree, and force-directed layouts
- **Rich Editing**: Advanced node editing with multimedia attachments
- **Smart Search**: Fuzzy search with autocomplete and similarity matching
- **File Format Support**: Import/export OPML, Markdown, JSON, PDF, SVG, PNG
- **Real-time Collaboration**: Multi-user editing capabilities
- **Offline First**: Local-first architecture with optional cloud sync

## Architecture

### Flutter UI Layer
- **Material Design 3**: Modern, adaptive UI components
- **State Management**: Riverpod for reactive state management
- **Animation**: Smooth transitions and interactive animations
- **Responsive Design**: Adaptive layouts for all screen sizes

### Rust Core Engine
- **Graph Engine**: High-performance graph data structure
- **Layout Algorithms**: Advanced automatic layout computation
- **Search Engine**: Fast full-text and semantic search
- **File I/O**: Multi-format import/export pipeline
- **FFI Bridge**: Type-safe Flutter-Rust communication

## Getting Started

### Prerequisites

- Flutter SDK 3.13.0 or later
- Rust 1.70.0 or later
- Platform-specific toolchains (Android SDK, Xcode, etc.)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yhsung/mini-mind.git
   cd mini-mind/flutter_app
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Build Rust core** (from project root)
   ```bash
   cd rust_core
   cargo build --release
   ```

4. **Generate FFI bindings**
   ```bash
   flutter packages pub run build_runner build
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

## Development

### Project Structure

```
flutter_app/
├── lib/
│   ├── bridge/          # FFI bridge and Rust bindings
│   ├── models/          # Data models and DTOs
│   ├── services/        # Business logic and services
│   ├── state/           # State management (Riverpod providers)
│   ├── widgets/         # UI components and widgets
│   ├── utils/           # Utility functions and helpers
│   ├── app.dart         # App configuration and routing
│   └── main.dart        # Application entry point
├── assets/              # Static assets (images, fonts, etc.)
├── test/                # Unit and widget tests
├── integration_test/    # Integration tests
└── platform/            # Platform-specific configurations
```

### Key Components

#### Bridge Layer (`lib/bridge/`)
- `mindmap_bridge.dart`: Main FFI interface to Rust core
- `bridge_types.dart`: Type definitions and conversions
- `generated/`: Auto-generated Dart bindings

#### State Management (`lib/state/`)
- `mindmap_state.dart`: Core mindmap state provider
- `ui_state.dart`: UI and interaction state
- `file_state.dart`: File operations state

#### Widgets (`lib/widgets/`)
- `mindmap_canvas.dart`: Main interactive canvas
- `node_widget.dart`: Individual node rendering
- `toolbar_widget.dart`: Main application toolbar
- `search_widget.dart`: Search interface
- `layout_controls.dart`: Layout configuration

#### Services (`lib/services/`)
- `mindmap_service.dart`: Core mindmap operations
- `file_service.dart`: File I/O and platform integration
- `search_service.dart`: Search functionality
- `keyboard_service.dart`: Keyboard shortcuts

### Code Generation

The project uses several code generation tools:

```bash
# Generate FFI bindings
flutter packages pub run build_runner build

# Generate JSON serialization
flutter packages pub run build_runner build --build-filter="*.g.dart"

# Clean generated files
flutter packages pub run build_runner clean
```

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run tests with coverage
flutter test --coverage
```

### Platform Configuration

#### Android (`android/`)
- Minimum SDK: 21 (Android 5.0)
- Target SDK: Latest stable
- Kotlin support enabled

#### iOS (`ios/`)
- Minimum iOS: 11.0
- Swift support enabled
- CocoaPods for dependency management

#### Desktop (`macos/`, `windows/`, `linux/`)
- Native platform integration
- File picker and system dialogs
- Platform-specific menus and shortcuts

#### Web (`web/`)
- Progressive Web App (PWA) support
- Canvas-based rendering fallback
- File system access via Web APIs

## Build and Deployment

### Development Build
```bash
flutter run --debug
```

### Release Build
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Desktop
flutter build macos --release
flutter build windows --release
flutter build linux --release

# Web
flutter build web --release
```

### Configuration

Environment-specific configuration files:
- `.env.development`: Development settings
- `.env.production`: Production settings
- `assets/config/app_config.json`: App configuration

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` for consistent formatting
- Ensure all tests pass before submitting
- Add appropriate documentation for new features

### Architecture Guidelines

- **Separation of Concerns**: Keep UI, business logic, and data layers separate
- **Reactive Programming**: Use streams and providers for state management
- **Error Handling**: Implement comprehensive error handling and user feedback
- **Performance**: Profile and optimize performance-critical code paths
- **Accessibility**: Ensure UI components are accessible to all users

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Acknowledgments

- Flutter team for the excellent cross-platform framework
- Rust community for the high-performance core engine capabilities
- Contributors and maintainers of the open-source dependencies