//! Document model for mindmap documents
//!
//! This module defines the Document struct which represents a complete
//! mindmap document containing nodes and edges.

use crate::types::{ids::{DocumentId, NodeId}, Timestamp};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Metadata for a mindmap document
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DocumentMetadata {
    /// Document title
    pub title: String,
    /// Document description
    pub description: Option<String>,
    /// Author name
    pub author: Option<String>,
    /// Document version
    pub version: String,
    /// Tags for categorization
    pub tags: Vec<String>,
    /// Custom metadata as key-value pairs
    pub custom: HashMap<String, String>,
}

/// A complete mindmap document
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Document {
    /// Unique identifier for this document
    pub id: DocumentId,

    /// Document title
    pub title: String,

    /// ID of the root node (entry point of the mindmap)
    pub root_node: NodeId,

    /// Document metadata
    pub metadata: DocumentMetadata,

    /// When this document was created
    pub created_at: Timestamp,

    /// When this document was last modified
    pub updated_at: Timestamp,

    /// When this document was last saved
    pub last_saved_at: Option<Timestamp>,

    /// Whether the document has unsaved changes
    pub is_dirty: bool,
}

impl Document {
    /// Create a new document with title and root node ID
    pub fn new(title: impl Into<String>, root_node: NodeId) -> Self {
        let now = chrono::Utc::now();
        let title_str = title.into();

        Self {
            id: DocumentId::new(),
            title: title_str.clone(),
            root_node,
            metadata: DocumentMetadata {
                title: title_str,
                description: None,
                author: None,
                version: "1.0".to_string(),
                tags: Vec::new(),
                custom: HashMap::new(),
            },
            created_at: now,
            updated_at: now,
            last_saved_at: None,
            is_dirty: false,
        }
    }

    /// Set the root node for this document
    pub fn set_root_node(&mut self, node_id: NodeId) {
        self.root_node = node_id;
        self.mark_dirty();
    }

    /// Update the document title
    pub fn set_title(&mut self, title: impl Into<String>) {
        let title_str = title.into();
        self.title = title_str.clone();
        self.metadata.title = title_str;
        self.mark_dirty();
    }

    /// Update the document description
    pub fn set_description(&mut self, description: Option<String>) {
        self.metadata.description = description;
        self.mark_dirty();
    }

    /// Update the document author
    pub fn set_author(&mut self, author: Option<String>) {
        self.metadata.author = author;
        self.mark_dirty();
    }

    /// Add a tag to the document
    pub fn add_tag(&mut self, tag: impl Into<String>) {
        let tag = tag.into();
        if !self.metadata.tags.contains(&tag) {
            self.metadata.tags.push(tag);
            self.mark_dirty();
        }
    }

    /// Remove a tag from the document
    pub fn remove_tag(&mut self, tag: &str) -> bool {
        if let Some(pos) = self.metadata.tags.iter().position(|t| t == tag) {
            self.metadata.tags.remove(pos);
            self.mark_dirty();
            true
        } else {
            false
        }
    }

    /// Set a custom metadata value
    pub fn set_custom_metadata(&mut self, key: impl Into<String>, value: impl Into<String>) {
        self.metadata.custom.insert(key.into(), value.into());
        self.mark_dirty();
    }

    /// Get a custom metadata value
    pub fn get_custom_metadata(&self, key: &str) -> Option<&String> {
        self.metadata.custom.get(key)
    }

    /// Remove a custom metadata key
    pub fn remove_custom_metadata(&mut self, key: &str) -> Option<String> {
        let result = self.metadata.custom.remove(key);
        if result.is_some() {
            self.mark_dirty();
        }
        result
    }

    /// Mark the document as having unsaved changes
    pub fn mark_dirty(&mut self) {
        self.is_dirty = true;
        self.updated_at = chrono::Utc::now();
    }

    /// Mark the document as saved
    pub fn mark_saved(&mut self) {
        self.is_dirty = false;
        self.last_saved_at = Some(chrono::Utc::now());
    }

    /// Get the root node ID
    pub fn get_root_node(&self) -> NodeId {
        self.root_node
    }

    /// Validate the document
    pub fn validate(&self) -> Result<(), String> {
        if self.metadata.title.trim().is_empty() {
            Err("Document title cannot be empty".to_string())
        } else if self.metadata.title.len() > 255 {
            Err("Document title cannot exceed 255 characters".to_string())
        } else {
            Ok(())
        }
    }
}

impl Default for DocumentMetadata {
    fn default() -> Self {
        Self {
            title: "Untitled Document".to_string(),
            description: None,
            author: None,
            version: "1.0".to_string(),
            tags: Vec::new(),
            custom: HashMap::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::ids::NodeId;

    #[test]
    fn test_document_creation() {
        let root_node = NodeId::new();
        let doc = Document::new("Test Document", root_node);

        assert_eq!(doc.metadata.title, "Test Document");
        assert_eq!(doc.get_root_node(), root_node);
        assert!(!doc.is_dirty);
        assert!(doc.last_saved_at.is_none());
    }

    #[test]
    fn test_root_node_management() {
        let initial_node = NodeId::new();
        let mut doc = Document::new("Test", initial_node);
        let new_node_id = NodeId::new();

        doc.set_root_node(new_node_id);
        assert_eq!(doc.get_root_node(), new_node_id);
        assert!(doc.is_dirty);
    }

    #[test]
    fn test_metadata_updates() {
        let root_node = NodeId::new();
        let mut doc = Document::new("Original Title", root_node);

        doc.set_title("New Title");
        assert_eq!(doc.metadata.title, "New Title");
        assert!(doc.is_dirty);

        doc.set_description(Some("Test description".to_string()));
        assert_eq!(doc.metadata.description, Some("Test description".to_string()));

        doc.set_author(Some("Test Author".to_string()));
        assert_eq!(doc.metadata.author, Some("Test Author".to_string()));
    }

    #[test]
    fn test_tag_management() {
        let root_node = NodeId::new();
        let mut doc = Document::new("Test", root_node);

        doc.add_tag("important");
        doc.add_tag("urgent");
        assert_eq!(doc.metadata.tags.len(), 2);

        // Adding duplicate tag shouldn't increase count
        doc.add_tag("important");
        assert_eq!(doc.metadata.tags.len(), 2);

        assert!(doc.remove_tag("urgent"));
        assert_eq!(doc.metadata.tags.len(), 1);

        assert!(!doc.remove_tag("nonexistent"));
    }

    #[test]
    fn test_custom_metadata() {
        let root_node = NodeId::new();
        let mut doc = Document::new("Test", root_node);

        doc.set_custom_metadata("key1", "value1");
        assert_eq!(doc.get_custom_metadata("key1"), Some(&"value1".to_string()));

        assert_eq!(doc.remove_custom_metadata("key1"), Some("value1".to_string()));
        assert_eq!(doc.get_custom_metadata("key1"), None);
    }

    #[test]
    fn test_dirty_tracking() {
        let root_node = NodeId::new();
        let mut doc = Document::new("Test", root_node);
        assert!(!doc.is_dirty);

        doc.mark_dirty();
        assert!(doc.is_dirty);

        doc.mark_saved();
        assert!(!doc.is_dirty);
        assert!(doc.last_saved_at.is_some());
    }

    #[test]
    fn test_document_validation() {
        let root_node = NodeId::new();
        let mut doc = Document::new("Valid Title", root_node);
        assert!(doc.validate().is_ok());

        doc.metadata.title = "".to_string();
        assert!(doc.validate().is_err());

        doc.metadata.title = "a".repeat(300);
        assert!(doc.validate().is_err());
    }

    #[test]
    fn test_metadata_default() {
        let metadata = DocumentMetadata::default();
        assert_eq!(metadata.title, "Untitled Document");
        assert_eq!(metadata.version, "1.0");
        assert!(metadata.tags.is_empty());
    }
}