//! ID types and utilities for mindmap entities
//!
//! This module provides type-safe wrappers around UUIDs for different
//! entity types in the mindmap system.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;
use uuid::Uuid;

/// Strongly-typed wrapper for node identifiers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct NodeId(pub Uuid);

/// Strongly-typed wrapper for edge identifiers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EdgeId(pub Uuid);

/// Strongly-typed wrapper for document identifiers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct DocumentId(pub Uuid);

/// Strongly-typed wrapper for mindmap identifiers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MindmapId(pub Uuid);

impl NodeId {
    /// Create a new random node ID
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// Create a node ID from an existing UUID
    pub fn from_uuid(uuid: Uuid) -> Self {
        Self(uuid)
    }

    /// Get the inner UUID
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

impl EdgeId {
    /// Create a new random edge ID
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// Create an edge ID from an existing UUID
    pub fn from_uuid(uuid: Uuid) -> Self {
        Self(uuid)
    }

    /// Get the inner UUID
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

impl DocumentId {
    /// Create a new random document ID
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// Create a document ID from an existing UUID
    pub fn from_uuid(uuid: Uuid) -> Self {
        Self(uuid)
    }

    /// Get the inner UUID
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

impl MindmapId {
    /// Create a new random mindmap ID
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// Create a mindmap ID from an existing UUID
    pub fn from_uuid(uuid: Uuid) -> Self {
        Self(uuid)
    }

    /// Get the inner UUID
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

// Display implementations
impl fmt::Display for NodeId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "node:{}", self.0)
    }
}

impl fmt::Display for EdgeId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "edge:{}", self.0)
    }
}

impl fmt::Display for DocumentId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "doc:{}", self.0)
    }
}

impl fmt::Display for MindmapId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "mindmap:{}", self.0)
    }
}

// FromStr implementations for parsing from strings
impl FromStr for NodeId {
    type Err = uuid::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let uuid_str = s.strip_prefix("node:").unwrap_or(s);
        Ok(Self(Uuid::from_str(uuid_str)?))
    }
}

impl FromStr for EdgeId {
    type Err = uuid::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let uuid_str = s.strip_prefix("edge:").unwrap_or(s);
        Ok(Self(Uuid::from_str(uuid_str)?))
    }
}

impl FromStr for DocumentId {
    type Err = uuid::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let uuid_str = s.strip_prefix("doc:").unwrap_or(s);
        Ok(Self(Uuid::from_str(uuid_str)?))
    }
}

impl FromStr for MindmapId {
    type Err = uuid::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let uuid_str = s.strip_prefix("mindmap:").unwrap_or(s);
        Ok(Self(Uuid::from_str(uuid_str)?))
    }
}

// Default implementations
impl Default for NodeId {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for EdgeId {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for DocumentId {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for MindmapId {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_node_id_creation() {
        let id1 = NodeId::new();
        let id2 = NodeId::new();
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_edge_id_creation() {
        let id1 = EdgeId::new();
        let id2 = EdgeId::new();
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_document_id_creation() {
        let id1 = DocumentId::new();
        let id2 = DocumentId::new();
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_mindmap_id_creation() {
        let id1 = MindmapId::new();
        let id2 = MindmapId::new();
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_id_display() {
        let node_id = NodeId::new();
        let edge_id = EdgeId::new();
        let doc_id = DocumentId::new();
        let mindmap_id = MindmapId::new();

        assert!(node_id.to_string().starts_with("node:"));
        assert!(edge_id.to_string().starts_with("edge:"));
        assert!(doc_id.to_string().starts_with("doc:"));
        assert!(mindmap_id.to_string().starts_with("mindmap:"));
    }

    #[test]
    fn test_id_parsing() {
        let node_id = NodeId::new();
        let node_str = node_id.to_string();
        let parsed = NodeId::from_str(&node_str).unwrap();
        assert_eq!(node_id, parsed);

        // Test parsing without prefix
        let uuid_str = node_id.as_uuid().to_string();
        let parsed = NodeId::from_str(&uuid_str).unwrap();
        assert_eq!(node_id, parsed);
    }

    #[test]
    fn test_serialization() {
        let node_id = NodeId::new();
        let json = serde_json::to_string(&node_id).unwrap();
        let deserialized: NodeId = serde_json::from_str(&json).unwrap();
        assert_eq!(node_id, deserialized);
    }
}