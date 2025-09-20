//! Edge model for mindmap connections
//!
//! This module defines the Edge struct which represents connections
//! between nodes in a mindmap.

use crate::types::{ids::{EdgeId, NodeId}, Color, Timestamp};
use serde::{Deserialize, Serialize};

/// Style configuration for an edge
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EdgeStyle {
    /// Line color
    pub color: Color,
    /// Line width in pixels
    pub width: f64,
    /// Line style (solid, dashed, dotted)
    pub style: LineStyle,
    /// Arrow type at the end of the edge
    pub arrow_type: ArrowType,
}

/// Line style options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LineStyle {
    Solid,
    Dashed,
    Dotted,
}

/// Arrow type options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ArrowType {
    None,
    Simple,
    Filled,
    Open,
}

/// An edge connecting two nodes in the mindmap
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Edge {
    /// Unique identifier for this edge
    pub id: EdgeId,

    /// Source node ID
    pub from_node: NodeId,

    /// Target node ID
    pub to_node: NodeId,

    /// Optional label text
    pub label: Option<String>,

    /// Visual styling for the edge
    pub style: EdgeStyle,

    /// When this edge was created
    pub created_at: Timestamp,

    /// When this edge was last modified
    pub updated_at: Timestamp,
}

impl Edge {
    /// Create a new edge between two nodes
    pub fn new(from_node: NodeId, to_node: NodeId) -> Self {
        let now = chrono::Utc::now();

        Self {
            id: EdgeId::new(),
            from_node,
            to_node,
            label: None,
            style: EdgeStyle::default(),
            created_at: now,
            updated_at: now,
        }
    }

    /// Create a new edge with a label
    pub fn new_with_label(from_node: NodeId, to_node: NodeId, label: impl Into<String>) -> Self {
        let mut edge = Self::new(from_node, to_node);
        edge.label = Some(label.into());
        edge
    }

    /// Set the edge label
    pub fn set_label(&mut self, label: Option<String>) {
        self.label = label;
        self.updated_at = chrono::Utc::now();
    }

    /// Clear the edge label
    pub fn clear_label(&mut self) {
        self.label = None;
        self.updated_at = chrono::Utc::now();
    }

    /// Check if this edge connects the given nodes (in either direction)
    pub fn connects(&self, node1: NodeId, node2: NodeId) -> bool {
        (self.from_node == node1 && self.to_node == node2) ||
        (self.from_node == node2 && self.to_node == node1)
    }

    /// Check if this edge has a label
    pub fn has_label(&self) -> bool {
        self.label.is_some()
    }

    /// Validate that the edge doesn't connect a node to itself
    pub fn validate(&self) -> Result<(), String> {
        if self.from_node == self.to_node {
            Err("Edge cannot connect a node to itself".to_string())
        } else {
            Ok(())
        }
    }
}

impl Default for EdgeStyle {
    fn default() -> Self {
        Self {
            color: crate::types::utils::rgb_to_color(128, 128, 128), // Gray
            width: 2.0,
            style: LineStyle::Solid,
            arrow_type: ArrowType::Simple,
        }
    }
}

impl Default for LineStyle {
    fn default() -> Self {
        LineStyle::Solid
    }
}

impl Default for ArrowType {
    fn default() -> Self {
        ArrowType::Simple
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::ids::NodeId;

    #[test]
    fn test_edge_creation() {
        let node1 = NodeId::new();
        let node2 = NodeId::new();
        let edge = Edge::new(node1, node2);

        assert_eq!(edge.from_node, node1);
        assert_eq!(edge.to_node, node2);
        assert_eq!(edge.label, None);
        assert!(!edge.has_label());
    }

    #[test]
    fn test_edge_with_label() {
        let node1 = NodeId::new();
        let node2 = NodeId::new();
        let edge = Edge::new_with_label(node1, node2, "connects to");

        assert_eq!(edge.label, Some("connects to".to_string()));
        assert!(edge.has_label());
    }

    #[test]
    fn test_edge_connects() {
        let node1 = NodeId::new();
        let node2 = NodeId::new();
        let node3 = NodeId::new();
        let edge = Edge::new(node1, node2);

        assert!(edge.connects(node1, node2));
        assert!(edge.connects(node2, node1)); // Should work in both directions
        assert!(!edge.connects(node1, node3));
    }

    #[test]
    fn test_edge_validation() {
        let node1 = NodeId::new();
        let node2 = NodeId::new();

        let valid_edge = Edge::new(node1, node2);
        assert!(valid_edge.validate().is_ok());

        let invalid_edge = Edge::new(node1, node1);
        assert!(invalid_edge.validate().is_err());
    }

    #[test]
    fn test_label_management() {
        let node1 = NodeId::new();
        let node2 = NodeId::new();
        let mut edge = Edge::new(node1, node2);

        edge.set_label(Some("test label".to_string()));
        assert_eq!(edge.label, Some("test label".to_string()));

        edge.clear_label();
        assert_eq!(edge.label, None);
    }

    #[test]
    fn test_edge_style_default() {
        let style = EdgeStyle::default();
        assert_eq!(style.style, LineStyle::Solid);
        assert_eq!(style.arrow_type, ArrowType::Simple);
        assert_eq!(style.width, 2.0);
    }
}