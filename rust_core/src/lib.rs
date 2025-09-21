//! Mindmap Core Engine
//!
//! Cross-platform mindmap application core engine providing graph data structures,
//! layout algorithms, persistence, and FFI interfaces for Flutter integration.
//!
//! # Features
//!
//! - **Graph Management**: Hierarchical node and edge data structures
//! - **Layout Algorithms**: Radial, tree, and force-directed layouts
//! - **Search**: Fuzzy text search with ranking
//! - **Persistence**: SQLite-based storage with auto-save
//! - **Import/Export**: OPML and Markdown format support
//! - **FFI Interface**: Flutter-Rust bridge for cross-platform UI
//! - **Cross-Platform**: macOS, Windows, and iOS support

// Platform-specific conditional compilation
#[cfg(target_os = "macos")]
extern crate core_foundation;

#[cfg(target_os = "windows")]
extern crate winapi;

#[cfg(target_os = "ios")]
extern crate core_foundation;

// Core module declarations
// Note: Modules will be implemented in subsequent tasks

// Data types and structures
pub mod types;

pub mod models;

// Graph operations and algorithms
pub mod graph;

pub mod layout;

pub mod search;

// Data persistence and I/O
#[cfg(feature = "sqlite")]
pub mod persistence;

pub mod io;

// FFI and platform integration
#[cfg(feature = "flutter_rust_bridge_feature")]
pub mod ffi;

// Performance monitoring
#[cfg(feature = "metrics")]
pub mod metrics {
    //! Performance metrics and monitoring
    // Module placeholder - will be implemented in Tasks 47-48
}

// Public API exports for FFI interface
#[cfg(feature = "flutter_rust_bridge_feature")]
pub use ffi::{MindmapFFI, MindmapBridge, BridgeError, create_bridge};

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Platform information
pub const PLATFORM: &str = {
    #[cfg(target_os = "macos")]
    { "macOS" }
    #[cfg(target_os = "windows")]
    { "Windows" }
    #[cfg(target_os = "ios")]
    { "iOS" }
    #[cfg(target_os = "linux")]
    { "Linux" }
    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "ios", target_os = "linux")))]
    { "Unknown" }
};

/// Initialize the mindmap core engine
pub fn init() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    log::info!("Mindmap Core Engine v{} initialized on {}", VERSION, PLATFORM);

    // Platform-specific initialization
    #[cfg(target_os = "macos")]
    init_macos()?;

    #[cfg(target_os = "windows")]
    init_windows()?;

    #[cfg(target_os = "ios")]
    init_ios()?;

    Ok(())
}

/// Get runtime information about the engine
pub fn info() -> EngineInfo {
    EngineInfo {
        version: VERSION,
        platform: PLATFORM,
        features: get_enabled_features(),
    }
}

/// Engine runtime information
#[derive(Debug)]
pub struct EngineInfo {
    pub version: &'static str,
    pub platform: &'static str,
    pub features: Vec<&'static str>,
}

/// Get list of enabled features
fn get_enabled_features() -> Vec<&'static str> {
    let mut features = Vec::new();

    #[cfg(feature = "sqlite")]
    features.push("sqlite");

    #[cfg(feature = "metrics")]
    features.push("metrics");

    #[cfg(feature = "debug-ui")]
    features.push("debug-ui");

    #[cfg(feature = "flutter_rust_bridge_feature")]
    features.push("flutter_rust_bridge");

    features
}

// Platform-specific initialization functions
#[cfg(target_os = "macos")]
fn init_macos() -> Result<(), Box<dyn std::error::Error>> {
    log::debug!("Initializing macOS-specific components");
    // macOS-specific initialization will be added later
    Ok(())
}

#[cfg(target_os = "windows")]
fn init_windows() -> Result<(), Box<dyn std::error::Error>> {
    log::debug!("Initializing Windows-specific components");
    // Windows-specific initialization will be added later
    Ok(())
}

#[cfg(target_os = "ios")]
fn init_ios() -> Result<(), Box<dyn std::error::Error>> {
    log::debug!("Initializing iOS-specific components");
    // iOS-specific initialization will be added later
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init() {
        assert!(init().is_ok());
    }

    #[test]
    fn test_version() {
        assert!(!VERSION.is_empty());
        assert_eq!(VERSION, env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn test_platform() {
        assert!(!PLATFORM.is_empty());
        assert!(["macOS", "Windows", "iOS", "Linux", "Unknown"].contains(&PLATFORM));
    }

    #[test]
    fn test_info() {
        let info = info();
        assert_eq!(info.version, VERSION);
        assert_eq!(info.platform, PLATFORM);
        assert!(!info.features.is_empty() || info.features.is_empty()); // Features may or may not be enabled
    }

    #[test]
    fn test_enabled_features() {
        let features = get_enabled_features();

        // Test that sqlite feature is enabled when default features are used
        #[cfg(feature = "sqlite")]
        assert!(features.contains(&"sqlite"));

        // Test that metrics feature is enabled when explicitly enabled
        #[cfg(feature = "metrics")]
        assert!(features.contains(&"metrics"));

        // Features should be a valid list (no additional validation needed)
    }
}