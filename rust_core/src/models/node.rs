//! Node model for mindmap nodes
//!
//! This module defines the Node struct which represents individual nodes
//! in a mindmap with their content, styling, position, and metadata.

use crate::types::{ids::NodeId, Point, Color, Timestamp};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Style configuration for a node
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NodeStyle {
    /// Background color
    pub background_color: Color,
    /// Text color
    pub text_color: Color,
    /// Border color
    pub border_color: Color,
    /// Border width in pixels
    pub border_width: f64,
    /// Corner radius for rounded borders
    pub corner_radius: f64,
    /// Font size
    pub font_size: f64,
    /// Font weight (normal, bold)
    pub font_weight: FontWeight,
    /// Text alignment
    pub text_align: TextAlign,
    /// Node shape
    pub shape: NodeShape,
}

/// Font weight options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FontWeight {
    Normal,
    Bold,
}

/// Text alignment options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TextAlign {
    Left,
    Center,
    Right,
}

/// Node shape options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum NodeShape {
    Rectangle,
    RoundedRectangle,
    Circle,
    Ellipse,
}

/// File attachment for a node
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Attachment {
    /// Unique identifier for the attachment
    pub id: String,
    /// Original filename
    pub filename: String,
    /// MIME type
    pub mime_type: String,
    /// File size in bytes
    pub size: u64,
    /// Path to the attached file (relative to document)
    pub path: String,
    /// When the attachment was added
    pub created_at: Timestamp,
}

/// A node in the mindmap
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Node {
    /// Unique identifier for this node
    pub id: NodeId,

    /// ID of parent node (None for root nodes)
    pub parent_id: Option<NodeId>,

    /// Text content of the node
    pub text: String,

    /// Visual styling for the node
    pub style: NodeStyle,

    /// Position in 2D space
    pub position: Point,

    /// File attachments
    pub attachments: Vec<Attachment>,

    /// Tags for categorization
    pub tags: Vec<String>,

    /// When this node was created
    pub created_at: Timestamp,

    /// When this node was last modified
    pub updated_at: Timestamp,

    /// Custom metadata as key-value pairs
    pub metadata: HashMap<String, String>,
}

impl Node {
    /// Create a new node with the given text content
    pub fn new(text: impl Into<String>) -> Self {
        let now = chrono::Utc::now();

        Self {
            id: NodeId::new(),
            parent_id: None,
            text: text.into(),
            style: NodeStyle::default(),
            position: Point::origin(),
            attachments: Vec::new(),
            tags: Vec::new(),
            created_at: now,
            updated_at: now,
            metadata: HashMap::new(),
        }
    }

    /// Create a new child node with the given parent and text
    pub fn new_child(parent_id: NodeId, text: impl Into<String>) -> Self {
        let mut node = Self::new(text);
        node.parent_id = Some(parent_id);
        node
    }

    /// Update the text content and mark as modified
    pub fn set_text(&mut self, text: impl Into<String>) {
        self.text = text.into();
        self.updated_at = chrono::Utc::now();
    }

    /// Update the position and mark as modified
    pub fn set_position(&mut self, position: Point) {
        self.position = position;
        self.updated_at = chrono::Utc::now();
    }

    /// Add a tag to this node
    pub fn add_tag(&mut self, tag: impl Into<String>) {
        let tag = tag.into();
        if !self.tags.contains(&tag) {
            self.tags.push(tag);
            self.updated_at = chrono::Utc::now();
        }
    }

    /// Remove a tag from this node
    pub fn remove_tag(&mut self, tag: &str) -> bool {
        if let Some(pos) = self.tags.iter().position(|t| t == tag) {
            self.tags.remove(pos);
            self.updated_at = chrono::Utc::now();
            true
        } else {
            false
        }
    }

    /// Add an attachment to this node
    pub fn add_attachment(&mut self, attachment: Attachment) {
        self.attachments.push(attachment);
        self.updated_at = chrono::Utc::now();
    }

    /// Remove an attachment by ID
    pub fn remove_attachment(&mut self, attachment_id: &str) -> bool {
        if let Some(pos) = self.attachments.iter().position(|a| a.id == attachment_id) {
            self.attachments.remove(pos);
            self.updated_at = chrono::Utc::now();
            true
        } else {
            false
        }
    }

    /// Set a metadata value
    pub fn set_metadata(&mut self, key: impl Into<String>, value: impl Into<String>) {
        self.metadata.insert(key.into(), value.into());
        self.updated_at = chrono::Utc::now();
    }

    /// Get a metadata value
    pub fn get_metadata(&self, key: &str) -> Option<&String> {
        self.metadata.get(key)
    }

    /// Remove a metadata key
    pub fn remove_metadata(&mut self, key: &str) -> Option<String> {
        let result = self.metadata.remove(key);
        if result.is_some() {
            self.updated_at = chrono::Utc::now();
        }
        result
    }

    /// Check if this node is a root node (has no parent)
    pub fn is_root(&self) -> bool {
        self.parent_id.is_none()
    }

    /// Check if this node is a child of the given parent
    pub fn is_child_of(&self, parent_id: NodeId) -> bool {
        self.parent_id == Some(parent_id)
    }

    /// Validate that the text content is not empty
    pub fn validate_text(&self) -> Result<(), String> {
        if self.text.trim().is_empty() {
            Err("Node text cannot be empty".to_string())
        } else if self.text.len() > 10000 {
            Err("Node text cannot exceed 10000 characters".to_string())
        } else {
            Ok(())
        }
    }

    /// Validate parent relationship (prevent self-reference)
    pub fn validate_parent(&self) -> Result<(), String> {
        if let Some(parent_id) = self.parent_id {
            if parent_id == self.id {
                Err("Node cannot be its own parent".to_string())
            } else {
                Ok(())
            }
        } else {
            Ok(())
        }
    }

    /// Validate the entire node
    pub fn validate(&self) -> Result<(), String> {
        self.validate_text()?;
        self.validate_parent()?;
        Ok(())
    }
}

impl Default for NodeStyle {
    fn default() -> Self {
        Self {
            background_color: crate::types::utils::rgb_to_color(255, 255, 255), // White
            text_color: crate::types::utils::rgb_to_color(0, 0, 0), // Black
            border_color: crate::types::utils::rgb_to_color(128, 128, 128), // Gray
            border_width: 1.0,
            corner_radius: 4.0,
            font_size: 14.0,
            font_weight: FontWeight::Normal,
            text_align: TextAlign::Center,
            shape: NodeShape::RoundedRectangle,
        }
    }
}

impl Default for FontWeight {
    fn default() -> Self {
        FontWeight::Normal
    }
}

impl Default for TextAlign {
    fn default() -> Self {
        TextAlign::Center
    }
}

impl Default for NodeShape {
    fn default() -> Self {
        NodeShape::RoundedRectangle
    }
}

impl Attachment {
    /// Create a new attachment
    pub fn new(
        filename: impl Into<String>,
        mime_type: impl Into<String>,
        size: u64,
        path: impl Into<String>,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            filename: filename.into(),
            mime_type: mime_type.into(),
            size,
            path: path.into(),
            created_at: chrono::Utc::now(),
        }
    }

    /// Check if this is an image attachment
    pub fn is_image(&self) -> bool {
        self.mime_type.starts_with("image/")
    }

    /// Check if this is a document attachment
    pub fn is_document(&self) -> bool {
        matches!(
            self.mime_type.as_str(),
            "application/pdf" | "text/plain" | "application/msword" |
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_node_creation() {
        let node = Node::new("Test Node");
        assert_eq!(node.text, "Test Node");
        assert!(node.is_root());
        assert!(node.tags.is_empty());
        assert!(node.attachments.is_empty());
    }

    #[test]
    fn test_child_node_creation() {
        let parent_id = NodeId::new();
        let child = Node::new_child(parent_id, "Child Node");

        assert_eq!(child.text, "Child Node");
        assert!(!child.is_root());
        assert!(child.is_child_of(parent_id));
    }

    #[test]
    fn test_text_validation() {
        let mut node = Node::new("Valid text");
        assert!(node.validate_text().is_ok());

        node.text = "".to_string();
        assert!(node.validate_text().is_err());

        node.text = "a".repeat(20000);
        assert!(node.validate_text().is_err());
    }

    #[test]
    fn test_parent_validation() {
        let mut node = Node::new("Test");
        assert!(node.validate_parent().is_ok());

        // Self-reference should fail
        node.parent_id = Some(node.id);
        assert!(node.validate_parent().is_err());
    }

    #[test]
    fn test_tag_management() {
        let mut node = Node::new("Test");

        node.add_tag("important");
        node.add_tag("urgent");
        assert_eq!(node.tags.len(), 2);

        // Adding duplicate tag shouldn't increase count
        node.add_tag("important");
        assert_eq!(node.tags.len(), 2);

        assert!(node.remove_tag("urgent"));
        assert_eq!(node.tags.len(), 1);

        assert!(!node.remove_tag("nonexistent"));
    }

    #[test]
    fn test_metadata_management() {
        let mut node = Node::new("Test");

        node.set_metadata("key1", "value1");
        assert_eq!(node.get_metadata("key1"), Some(&"value1".to_string()));

        assert_eq!(node.remove_metadata("key1"), Some("value1".to_string()));
        assert_eq!(node.get_metadata("key1"), None);
    }

    #[test]
    fn test_attachment_creation() {
        let attachment = Attachment::new("test.pdf", "application/pdf", 1024, "files/test.pdf");

        assert_eq!(attachment.filename, "test.pdf");
        assert_eq!(attachment.size, 1024);
        assert!(attachment.is_document());
        assert!(!attachment.is_image());

        let image = Attachment::new("test.png", "image/png", 2048, "images/test.png");
        assert!(image.is_image());
        assert!(!image.is_document());
    }

    #[test]
    fn test_attachment_management() {
        let mut node = Node::new("Test");
        let attachment = Attachment::new("test.txt", "text/plain", 100, "test.txt");
        let attachment_id = attachment.id.clone();

        node.add_attachment(attachment);
        assert_eq!(node.attachments.len(), 1);

        assert!(node.remove_attachment(&attachment_id));
        assert_eq!(node.attachments.len(), 0);

        assert!(!node.remove_attachment("nonexistent"));
    }

    #[test]
    fn test_node_style_default() {
        let style = NodeStyle::default();
        assert_eq!(style.font_weight, FontWeight::Normal);
        assert_eq!(style.text_align, TextAlign::Center);
        assert_eq!(style.shape, NodeShape::RoundedRectangle);
    }
}