# Mini Mind

A cross-platform mindmap application built with Flutter UI and Rust core engine, designed for seamless mind mapping across desktop and mobile platforms.

## 🚀 Features

### Core Functionality
- **Interactive Mindmap Canvas**: Custom-painted mindmap rendering with zoom, pan, and viewport management
- **Rich Node Management**: Create, edit, delete, and style mindmap nodes with text formatting
- **Multiple Layout Algorithms**: Radial, tree, and force-directed layout engines
- **Cross-Platform Compatibility**: Native support for macOS, Windows, Linux, iOS, and Android

### Desktop Experience
- **Native Menu Integration**: Complete File/Edit/View menu structure with platform-native styling
- **Comprehensive Keyboard Shortcuts**:
  - File: `Cmd/Ctrl+N` (New), `Cmd/Ctrl+O` (Open), `Cmd/Ctrl+S` (Save), `Cmd/Ctrl+Shift+S` (Save As)
  - Edit: `Cmd/Ctrl+Z` (Undo), `Cmd/Ctrl+Y` (Redo), `Cmd/Ctrl+X` (Cut), `Cmd/Ctrl+C` (Copy), `Cmd/Ctrl+V` (Paste)
  - View: `Cmd/Ctrl+=` (Zoom In), `Cmd/Ctrl+-` (Zoom Out), `Cmd/Ctrl+0` (Zoom to Fit), `F11` (Fullscreen)
- **Advanced Clipboard Operations**: Cut, copy, and paste nodes with hierarchy preservation
- **Fullscreen Mode**: Distraction-free editing experience

### File Support
- **Multiple Export Formats**: JSON, XML, HTML, Plain Text
- **Import/Export Capabilities**: OPML and Markdown support
- **Auto-save & Backup**: Automatic document persistence with recovery mechanisms

## 🏗️ Architecture

### Technology Stack
- **Frontend**: Flutter 3.13+ with Material Design 3
- **Backend**: Rust core engine with high-performance graph operations
- **FFI Bridge**: Flutter-Rust Bridge for type-safe communication
- **State Management**: Riverpod with ChangeNotifier pattern
- **Storage**: SQLite with cross-platform file system integration

### Service-Oriented Design
```
Menu System → Service Layer → UI Components
     ↓             ↓              ↓
Keyboard     Callback      Widget
Shortcuts    Registry      Updates
```

**Core Services:**
- **CanvasController**: Zoom/pan operations and viewport management
- **FullscreenController**: Application fullscreen state coordination
- **ClipboardService**: Node cut/copy/paste with conflict prevention
- **FileService**: Cross-platform file operations and format handling

## 🔧 Development Setup

### Prerequisites
- **Flutter 3.13+**: `flutter --version`
- **Rust 1.70+**: `rustc --version`
- **Platform Tools**:
  - macOS: Xcode Command Line Tools
  - Windows: Visual Studio Build Tools
  - Linux: build-essential

### Installation
```bash
# Clone repository
git clone https://github.com/yhsung/mini-mind.git
cd mini-mind

# Setup Rust core
cd rust_core
cargo build --release

# Setup Flutter app
cd ../flutter_app
flutter pub get
flutter run -d [platform]
```

### Platform-Specific Setup
```bash
# Enable desktop platforms
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop

# Add platform support
flutter create --platforms=macos,windows,linux .
```

## 📱 Platform Support

| Platform | Status | Features |
|----------|--------|----------|
| **macOS** | ✅ Complete | Native menus, keyboard shortcuts, file dialogs |
| **Windows** | ✅ Complete | Native menus, keyboard shortcuts, file dialogs |
| **Linux** | ✅ Complete | Native menus, keyboard shortcuts, file dialogs |
| **iOS** | 🚧 In Progress | Touch gestures, mobile-optimized UI |
| **Android** | 🚧 In Progress | Touch gestures, mobile-optimized UI |

## 🧪 Testing

### Test Structure
```
tests/
├── rust_core/tests/          # Rust unit tests
├── flutter_app/test/         # Flutter widget tests
└── integration_test/         # End-to-end tests
```

### Running Tests
```bash
# Rust core tests
cd rust_core && cargo test

# Flutter tests
cd flutter_app && flutter test

# Integration tests
flutter test integration_test/
```

## 📂 Project Structure

```
mini-mind/
├── rust_core/                # Rust engine
│   ├── src/
│   │   ├── graph/            # Graph data structures
│   │   ├── layout/           # Layout algorithms
│   │   ├── persistence/      # Data storage
│   │   ├── search/           # Search functionality
│   │   └── ffi/              # Flutter-Rust bridge
│   └── tests/
├── flutter_app/              # Flutter UI
│   ├── lib/
│   │   ├── bridge/           # FFI bindings
│   │   ├── models/           # Data models
│   │   ├── services/         # Business logic
│   │   ├── state/            # State management
│   │   ├── widgets/          # UI components
│   │   └── screens/          # Application screens
│   ├── test/                 # Unit tests
│   └── integration_test/     # E2E tests
└── .claude/specs/            # Project specifications
```

## 🤝 Contributing

### Development Workflow
1. **Fork & Clone**: Create your development environment
2. **Branch**: Create feature branches from `main`
3. **Test**: Ensure all tests pass before submitting
4. **PR**: Submit pull requests with clear descriptions

### Code Standards
- **Rust**: Follow `rustfmt` and `clippy` recommendations
- **Flutter**: Adhere to `flutter analyze` guidelines
- **Commits**: Use conventional commit messages
- **Documentation**: Update README and inline docs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Roadmap

### Phase 1: Core Foundation ✅
- [x] Rust graph engine
- [x] FFI bridge setup
- [x] Basic Flutter UI

### Phase 2: Desktop Features ✅
- [x] Menu system integration
- [x] Keyboard shortcuts
- [x] Service architecture
- [x] File operations

### Phase 3: Advanced Features 🚧
- [ ] Real-time collaboration
- [ ] Plugin system
- [ ] Advanced styling
- [ ] Mobile optimizations

### Phase 4: Polish & Performance 📋
- [ ] Performance optimization
- [ ] Accessibility features
- [ ] Documentation
- [ ] Distribution packages

---

**Built with ❤️ using Flutter and Rust**
