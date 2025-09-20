//! Mindmap Core Engine
//!
//! Cross-platform mindmap application core engine providing graph data structures,
//! layout algorithms, persistence, and FFI interfaces for Flutter integration.

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Initialize the mindmap core engine
pub fn init() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    log::info!("Mindmap Core Engine v{} initialized", VERSION);
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
    }
}