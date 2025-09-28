//! Core data types for mindmap operations
//!
//! This module provides common data types, type aliases, and utility functions
//! used throughout the mindmap application.

use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Public exports for sub-modules
pub mod ids;
pub mod position;

// Re-export commonly used types
pub use ids::*;
pub use position::*;

// ID types are now defined in the ids module as proper structs

/// Type alias for coordinate values (floating point)
pub type Coordinate = f64;

/// Type alias for size dimensions
pub type Size = f64;

/// Type alias for angle values in radians
pub type Angle = f64;

/// Type alias for color values (RGBA)
pub type Color = u32;

/// Type alias for timestamp values
pub type Timestamp = chrono::DateTime<chrono::Utc>;

/// Result type for mindmap operations
pub type MindmapResult<T> = Result<T, MindmapError>;

/// Common error types for mindmap operations
#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum MindmapError {
    #[error("Node not found: {id}")]
    NodeNotFound { id: NodeId },

    #[error("Edge not found: {id}")]
    EdgeNotFound { id: EdgeId },

    #[error("Document not found: {id}")]
    DocumentNotFound { id: DocumentId },

    #[error("Invalid operation: {message}")]
    InvalidOperation { message: String },

    #[error("IO error: {message}")]
    IoError { message: String },

    #[error("Metrics error: {0}")]
    MetricsError(String),

    #[error("Parse error: {message}")]
    ParseError { message: String },

    #[error("Database error: {message}")]
    DatabaseError { message: String },
}

/// Utility functions for type conversions and validation
pub mod utils {
    use super::*;

    /// Generate a new NodeId
    pub fn new_node_id() -> NodeId {
        NodeId::new()
    }

    /// Generate a new EdgeId
    pub fn new_edge_id() -> EdgeId {
        EdgeId::new()
    }

    /// Generate a new DocumentId
    pub fn new_document_id() -> DocumentId {
        DocumentId::new()
    }

    /// Generate a new MindmapId
    pub fn new_mindmap_id() -> MindmapId {
        MindmapId::new()
    }

    /// Convert RGB values to RGBA color
    pub fn rgb_to_color(r: u8, g: u8, b: u8) -> Color {
        rgba_to_color(r, g, b, 255)
    }

    /// Convert RGBA values to color
    pub fn rgba_to_color(r: u8, g: u8, b: u8, a: u8) -> Color {
        ((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
    }

    /// Extract RGBA components from color
    pub fn color_to_rgba(color: Color) -> (u8, u8, u8, u8) {
        let a = ((color >> 24) & 0xFF) as u8;
        let r = ((color >> 16) & 0xFF) as u8;
        let g = ((color >> 8) & 0xFF) as u8;
        let b = (color & 0xFF) as u8;
        (r, g, b, a)
    }

    /// Get current timestamp
    pub fn now() -> Timestamp {
        chrono::Utc::now()
    }

    /// Validate coordinate values (check for NaN and infinity)
    pub fn validate_coordinate(coord: Coordinate) -> bool {
        coord.is_finite()
    }

    /// Clamp coordinate to valid range
    pub fn clamp_coordinate(coord: Coordinate, min: Coordinate, max: Coordinate) -> Coordinate {
        coord.max(min).min(max)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::utils::*;

    #[test]
    fn test_id_generation() {
        let node_id = new_node_id();
        let edge_id = new_edge_id();
        let doc_id = new_document_id();

        // Test that IDs are unique by converting to strings
        assert_ne!(node_id.to_string(), edge_id.to_string());
        assert_ne!(edge_id.to_string(), doc_id.to_string());
        assert_ne!(node_id.to_string(), doc_id.to_string());
    }

    #[test]
    fn test_color_conversion() {
        let color = rgb_to_color(255, 128, 64);
        let (r, g, b, a) = color_to_rgba(color);

        assert_eq!(r, 255);
        assert_eq!(g, 128);
        assert_eq!(b, 64);
        assert_eq!(a, 255);
    }

    #[test]
    fn test_rgba_color_conversion() {
        let color = rgba_to_color(255, 128, 64, 32);
        let (r, g, b, a) = color_to_rgba(color);

        assert_eq!(r, 255);
        assert_eq!(g, 128);
        assert_eq!(b, 64);
        assert_eq!(a, 32);
    }

    #[test]
    fn test_coordinate_validation() {
        assert!(validate_coordinate(42.0));
        assert!(validate_coordinate(-100.5));
        assert!(!validate_coordinate(f64::NAN));
        assert!(!validate_coordinate(f64::INFINITY));
        assert!(!validate_coordinate(f64::NEG_INFINITY));
    }

    #[test]
    fn test_coordinate_clamping() {
        assert_eq!(clamp_coordinate(50.0, 0.0, 100.0), 50.0);
        assert_eq!(clamp_coordinate(-10.0, 0.0, 100.0), 0.0);
        assert_eq!(clamp_coordinate(150.0, 0.0, 100.0), 100.0);
    }

    #[test]
    fn test_timestamp() {
        let ts1 = now();
        std::thread::sleep(std::time::Duration::from_millis(10));
        let ts2 = now();

        assert!(ts2 > ts1);
    }
}