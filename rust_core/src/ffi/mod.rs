//! Foreign Function Interface for Flutter integration
//!
//! This module provides the FFI bridge between Rust core engine and Flutter UI,
//! enabling cross-platform mindmap functionality with type-safe interfaces
//! and efficient error handling.

use crate::models::{Node, Edge, MindmapDocument, NodeStyle, Attachment};
use crate::types::{NodeId, EdgeId, MindmapId, Point, Color, MindmapError, MindmapResult};
use crate::layout::LayoutType;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

// FFI-specific data transfer objects
pub mod dto;
pub mod bridge;
pub mod errors;

pub use dto::*;
pub use bridge::*;
pub use errors::*;

/// FFI-compatible error type for bridge communication
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum BridgeError {
    /// Node with specified ID was not found
    NodeNotFound { id: String },
    /// Edge with specified ID was not found
    EdgeNotFound { id: String },
    /// Document with specified ID was not found
    DocumentNotFound { id: String },
    /// Invalid operation attempted
    InvalidOperation { message: String },
    /// File system operation failed
    FileSystemError { message: String },
    /// Data serialization/deserialization failed
    SerializationError { message: String },
    /// Layout computation failed
    LayoutComputationError { message: String },
    /// Search operation failed
    SearchError { message: String },
    /// Generic error with message
    GenericError { message: String },
}

/// Convert internal MindmapError to FFI-compatible BridgeError
impl From<MindmapError> for BridgeError {
    fn from(error: MindmapError) -> Self {
        match error {
            MindmapError::NodeNotFound { id } => BridgeError::NodeNotFound {
                id: id.to_string()
            },
            MindmapError::EdgeNotFound { id } => BridgeError::EdgeNotFound {
                id: id.to_string()
            },
            MindmapError::DocumentNotFound { id } => BridgeError::DocumentNotFound {
                id: id.to_string()
            },
            MindmapError::InvalidOperation { message } => BridgeError::InvalidOperation { message },
            MindmapError::IoError { message } => BridgeError::FileSystemError { message },
            MindmapError::ParseError { message } => BridgeError::SerializationError { message },
            MindmapError::DatabaseError { message } => BridgeError::GenericError { message },
        }
    }
}

/// FFI-compatible layout types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum FfiLayoutType {
    /// Radial layout with nodes arranged in circles
    Radial,
    /// Hierarchical tree layout
    Tree,
    /// Force-directed layout with physics simulation
    ForceDirected,
}

impl From<FfiLayoutType> for LayoutType {
    fn from(ffi_type: FfiLayoutType) -> Self {
        match ffi_type {
            FfiLayoutType::Radial => LayoutType::Radial,
            FfiLayoutType::Tree => LayoutType::Tree,
            FfiLayoutType::ForceDirected => LayoutType::Force,
        }
    }
}

/// FFI-compatible export format types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum ExportFormat {
    /// Portable Document Format
    Pdf,
    /// Scalable Vector Graphics
    Svg,
    /// Portable Network Graphics
    Png,
    /// Outline Processor Markup Language
    Opml,
    /// Markdown outline format
    Markdown,
}

/// FFI-compatible position data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiPoint {
    pub x: f64,
    pub y: f64,
}

impl From<Point> for FfiPoint {
    fn from(point: Point) -> Self {
        Self { x: point.x, y: point.y }
    }
}

impl From<FfiPoint> for Point {
    fn from(ffi_point: FfiPoint) -> Self {
        Self { x: ffi_point.x, y: ffi_point.y }
    }
}

/// FFI-compatible node data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiNodeData {
    pub id: String,
    pub parent_id: Option<String>,
    pub text: String,
    pub position: FfiPoint,
    pub tags: Vec<String>,
    pub created_at: i64, // Unix timestamp
    pub updated_at: i64, // Unix timestamp
    pub metadata: HashMap<String, String>,
}

impl From<Node> for FfiNodeData {
    fn from(node: Node) -> Self {
        Self {
            id: node.id.to_string(),
            parent_id: node.parent_id.map(|id| id.to_string()),
            text: node.text,
            position: node.position.into(),
            tags: node.tags,
            created_at: node.created_at.timestamp(),
            updated_at: node.updated_at.timestamp(),
            metadata: node.metadata,
        }
    }
}

/// FFI-compatible layout result data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiLayoutResult {
    pub node_positions: HashMap<String, FfiPoint>,
    pub layout_type: FfiLayoutType,
    pub computation_time_ms: u64,
}

/// FFI-compatible search result data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiSearchResult {
    pub node_id: String,
    pub text: String,
    pub score: f64,
    pub match_positions: Vec<(usize, usize)>, // (start, end) positions of matches
}

/// FFI-compatible mindmap data structure
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiMindmapData {
    pub id: String,
    pub title: String,
    pub root_node_id: String,
    pub nodes: Vec<FfiNodeData>,
    pub created_at: i64, // Unix timestamp
    pub updated_at: i64, // Unix timestamp
}

/// FFI-compatible update data for nodes
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiNodeUpdate {
    pub text: Option<String>,
    pub position: Option<FfiPoint>,
    pub tags: Option<Vec<String>>,
    pub metadata: Option<HashMap<String, String>>,
}

/// Main FFI interface for mindmap operations
///
/// This trait defines all the operations that can be called from Flutter
/// to interact with the Rust core engine. All methods return Results
/// for proper error handling across the FFI boundary.
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub trait MindmapFFI {
    // Node Operations

    /// Create a new node with optional parent
    fn create_node(
        &self,
        parent_id: Option<String>,
        text: String,
    ) -> Result<String, BridgeError>;

    /// Update an existing node's properties
    fn update_node(
        &self,
        node_id: String,
        update: FfiNodeUpdate,
    ) -> Result<(), BridgeError>;

    /// Update node text content
    fn update_node_text(
        &self,
        node_id: String,
        text: String,
    ) -> Result<(), BridgeError>;

    /// Update node position
    fn update_node_position(
        &self,
        node_id: String,
        position: FfiPoint,
    ) -> Result<(), BridgeError>;

    /// Delete a node and all its children
    fn delete_node(
        &self,
        node_id: String,
    ) -> Result<(), BridgeError>;

    /// Get node data by ID
    fn get_node(
        &self,
        node_id: String,
    ) -> Result<FfiNodeData, BridgeError>;

    /// Get all children of a node
    fn get_node_children(
        &self,
        node_id: String,
    ) -> Result<Vec<FfiNodeData>, BridgeError>;

    /// Get all nodes in the mindmap
    fn get_all_nodes(&self) -> Result<Vec<FfiNodeData>, BridgeError>;

    // Layout Operations

    /// Calculate layout for all nodes using specified algorithm
    fn calculate_layout(
        &self,
        layout_type: FfiLayoutType,
    ) -> Result<FfiLayoutResult, BridgeError>;

    /// Apply layout result to update node positions
    fn apply_layout(
        &self,
        layout_result: FfiLayoutResult,
    ) -> Result<(), BridgeError>;

    // Search Operations

    /// Search nodes by text content with fuzzy matching
    fn search_nodes(
        &self,
        query: String,
    ) -> Result<Vec<FfiSearchResult>, BridgeError>;

    /// Search nodes by tags
    fn search_by_tags(
        &self,
        tags: Vec<String>,
    ) -> Result<Vec<FfiSearchResult>, BridgeError>;

    // File Operations

    /// Create a new mindmap document
    fn create_mindmap(
        &self,
        title: String,
    ) -> Result<String, BridgeError>;

    /// Load mindmap from file path
    fn load_mindmap(
        &self,
        path: String,
    ) -> Result<FfiMindmapData, BridgeError>;

    /// Save current mindmap to file path
    fn save_mindmap(
        &self,
        path: String,
    ) -> Result<(), BridgeError>;

    /// Export mindmap to specified format and path
    fn export_mindmap(
        &self,
        path: String,
        format: ExportFormat,
    ) -> Result<(), BridgeError>;

    /// Get current mindmap data
    fn get_mindmap_data(&self) -> Result<FfiMindmapData, BridgeError>;

    // Utility Operations

    /// Validate mindmap data integrity
    fn validate_mindmap(&self) -> Result<bool, BridgeError>;

    /// Get engine version and platform information
    fn get_engine_info(&self) -> Result<String, BridgeError>;

    /// Initialize the engine with configuration
    fn initialize(&self) -> Result<(), BridgeError>;

    /// Cleanup resources and save state
    fn cleanup(&self) -> Result<(), BridgeError>;
}

/// Type alias for FFI result
pub type FfiResult<T> = Result<T, BridgeError>;

/// Constants for FFI interface
pub mod constants {
    /// Maximum allowed text length for nodes
    pub const MAX_NODE_TEXT_LENGTH: usize = 10000;

    /// Maximum number of nodes in a single mindmap
    pub const MAX_NODES_PER_MINDMAP: usize = 10000;

    /// Maximum number of tags per node
    pub const MAX_TAGS_PER_NODE: usize = 50;

    /// Maximum length for tag names
    pub const MAX_TAG_LENGTH: usize = 100;

    /// Maximum file size for attachments (100MB)
    pub const MAX_ATTACHMENT_SIZE: u64 = 100 * 1024 * 1024;
}

/// Utility functions for FFI operations
pub mod utils {
    use super::*;
    use uuid::Uuid;

    /// Convert string ID to UUID, returning error if invalid
    pub fn parse_uuid(id: &str) -> Result<Uuid, BridgeError> {
        Uuid::parse_str(id).map_err(|_| BridgeError::InvalidOperation {
            message: format!("Invalid UUID format: {}", id),
        })
    }

    /// Validate node text length
    pub fn validate_node_text(text: &str) -> Result<(), BridgeError> {
        if text.is_empty() {
            return Err(BridgeError::InvalidOperation {
                message: "Node text cannot be empty".to_string(),
            });
        }

        if text.len() > constants::MAX_NODE_TEXT_LENGTH {
            return Err(BridgeError::InvalidOperation {
                message: format!(
                    "Node text exceeds maximum length of {} characters",
                    constants::MAX_NODE_TEXT_LENGTH
                ),
            });
        }

        Ok(())
    }

    /// Validate tag list
    pub fn validate_tags(tags: &[String]) -> Result<(), BridgeError> {
        if tags.len() > constants::MAX_TAGS_PER_NODE {
            return Err(BridgeError::InvalidOperation {
                message: format!(
                    "Too many tags: {} (maximum: {})",
                    tags.len(),
                    constants::MAX_TAGS_PER_NODE
                ),
            });
        }

        for tag in tags {
            if tag.is_empty() {
                return Err(BridgeError::InvalidOperation {
                    message: "Tag cannot be empty".to_string(),
                });
            }

            if tag.len() > constants::MAX_TAG_LENGTH {
                return Err(BridgeError::InvalidOperation {
                    message: format!(
                        "Tag '{}' exceeds maximum length of {} characters",
                        tag,
                        constants::MAX_TAG_LENGTH
                    ),
                });
            }
        }

        Ok(())
    }

    /// Validate coordinate values
    pub fn validate_position(position: &FfiPoint) -> Result<(), BridgeError> {
        if !position.x.is_finite() || !position.y.is_finite() {
            return Err(BridgeError::InvalidOperation {
                message: "Position coordinates must be finite numbers".to_string(),
            });
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::utils::*;

    #[test]
    fn test_bridge_error_conversion() {
        let node_id = uuid::Uuid::new_v4();
        let mindmap_error = MindmapError::NodeNotFound { id: node_id };
        let bridge_error: BridgeError = mindmap_error.into();

        match bridge_error {
            BridgeError::NodeNotFound { id } => {
                assert_eq!(id, node_id.to_string());
            }
            _ => panic!("Expected NodeNotFound error"),
        }
    }

    #[test]
    fn test_ffi_layout_type_conversion() {
        let ffi_type = FfiLayoutType::Radial;
        let layout_type: LayoutType = ffi_type.into();
        assert_eq!(layout_type, LayoutType::Radial);
    }

    #[test]
    fn test_ffi_point_conversion() {
        let point = Point::new(10.5, 20.3);
        let ffi_point: FfiPoint = point.into();
        let back_to_point: Point = ffi_point.into();

        assert_eq!(point.x, back_to_point.x);
        assert_eq!(point.y, back_to_point.y);
    }

    #[test]
    fn test_uuid_parsing() {
        let valid_uuid = "550e8400-e29b-41d4-a716-446655440000";
        assert!(parse_uuid(valid_uuid).is_ok());

        let invalid_uuid = "not-a-uuid";
        assert!(parse_uuid(invalid_uuid).is_err());
    }

    #[test]
    fn test_node_text_validation() {
        assert!(validate_node_text("Valid text").is_ok());
        assert!(validate_node_text("").is_err());

        let long_text = "a".repeat(constants::MAX_NODE_TEXT_LENGTH + 1);
        assert!(validate_node_text(&long_text).is_err());
    }

    #[test]
    fn test_tags_validation() {
        let valid_tags = vec!["tag1".to_string(), "tag2".to_string()];
        assert!(validate_tags(&valid_tags).is_ok());

        let empty_tag = vec!["".to_string()];
        assert!(validate_tags(&empty_tag).is_err());

        let too_many_tags: Vec<String> = (0..constants::MAX_TAGS_PER_NODE + 1)
            .map(|i| format!("tag{}", i))
            .collect();
        assert!(validate_tags(&too_many_tags).is_err());
    }

    #[test]
    fn test_position_validation() {
        let valid_position = FfiPoint { x: 10.0, y: 20.0 };
        assert!(validate_position(&valid_position).is_ok());

        let invalid_position = FfiPoint { x: f64::NAN, y: 20.0 };
        assert!(validate_position(&invalid_position).is_err());

        let infinite_position = FfiPoint { x: f64::INFINITY, y: 20.0 };
        assert!(validate_position(&infinite_position).is_err());
    }
}