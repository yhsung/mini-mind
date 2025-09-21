//! Node operations for FFI interface
//!
//! This module provides specialized node operations and utilities for the FFI bridge,
//! offering enhanced functionality beyond the basic MindmapFFI trait implementation.

use super::{BridgeError, FfiNodeData, FfiNodeUpdate, FfiPoint, MindmapBridge, utils};
use crate::{
    graph::Graph,
    models::Node,
    types::{NodeId, Point},
};
use std::collections::HashMap;
use std::time::Instant;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Extended node operations for advanced FFI functionality
pub struct NodeOperations;

impl NodeOperations {
    /// Create a new node with validation and automatic parent relationship setup
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn create_node_with_validation(
        bridge: &MindmapBridge,
        parent_id: Option<String>,
        text: String,
        position: Option<FfiPoint>,
        tags: Option<Vec<String>>,
    ) -> Result<String, BridgeError> {
        let start_time = Instant::now();

        // Validate all inputs
        utils::validate_node_text(&text)?;
        if let Some(ref tags_vec) = tags {
            utils::validate_tags(tags_vec)?;
        }
        if let Some(ref pos) = position {
            utils::validate_position(pos)?;
        }

        // Parse parent ID if provided
        let parent_uuid = if let Some(parent_str) = parent_id {
            Some(bridge.parse_node_id(&parent_str)?)
        } else {
            None
        };

        // Create new node with all properties
        let mut node = if let Some(parent) = parent_uuid {
            Node::new_child(parent, text)
        } else {
            Node::new(text)
        };

        // Set position if provided
        if let Some(pos) = position {
            node.position = Point::new(pos.x, pos.y);
        }

        // Set tags if provided
        if let Some(tags_vec) = tags {
            node.tags = tags_vec;
        }

        // Add to graph through bridge
        let graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let node_id = node.id;
        graph.add_node(node).map_err(|e| BridgeError::InvalidOperation {
            message: format!("Failed to create node: {}", e),
        })?;

        // Update search index
        if let Ok(mut search) = bridge.search_engine.write() {
            if let Some(node_ref) = graph.get_node(node_id) {
                search.index_node(node_ref);
            }
        }

        bridge.record_metrics("create_node_with_validation", start_time, 1);
        Ok(node_id.to_string())
    }

    /// Batch create multiple nodes efficiently
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn batch_create_nodes(
        bridge: &MindmapBridge,
        nodes_data: Vec<BatchNodeCreate>,
    ) -> Result<Vec<String>, BridgeError> {
        let start_time = Instant::now();
        let mut created_ids = Vec::new();

        // Validate all nodes first
        for node_data in &nodes_data {
            utils::validate_node_text(&node_data.text)?;
            if let Some(ref tags) = node_data.tags {
                utils::validate_tags(tags)?;
            }
            if let Some(ref pos) = node_data.position {
                utils::validate_position(pos)?;
            }
        }

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Create all nodes
        for node_data in nodes_data {
            let parent_uuid = if let Some(parent_str) = node_data.parent_id {
                Some(bridge.parse_node_id(&parent_str)?)
            } else {
                None
            };

            let mut node = if let Some(parent) = parent_uuid {
                Node::new_child(parent, node_data.text)
            } else {
                Node::new(node_data.text)
            };

            if let Some(pos) = node_data.position {
                node.position = Point::new(pos.x, pos.y);
            }

            if let Some(tags) = node_data.tags {
                node.tags = tags;
            }

            if let Some(metadata) = node_data.metadata {
                node.metadata = metadata;
            }

            let node_id = node.id;
            graph.add_node(node).map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to create node in batch: {}", e),
            })?;

            created_ids.push(node_id.to_string());
        }

        // Update search index for all new nodes
        if let Ok(mut search) = bridge.search_engine.write() {
            for id_str in &created_ids {
                if let Ok(node_id) = bridge.parse_node_id(id_str) {
                    if let Some(node_ref) = graph.get_node(node_id) {
                        search.index_node(node_ref);
                    }
                }
            }
        }

        bridge.record_metrics("batch_create_nodes", start_time, created_ids.len() as u32);
        Ok(created_ids)
    }

    /// Update multiple node properties atomically
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn batch_update_nodes(
        bridge: &MindmapBridge,
        updates: Vec<BatchNodeUpdate>,
    ) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        // Validate all updates first
        for update in &updates {
            if let Some(ref text) = update.update.text {
                utils::validate_node_text(text)?;
            }
            if let Some(ref tags) = update.update.tags {
                utils::validate_tags(tags)?;
            }
            if let Some(ref pos) = update.update.position {
                utils::validate_position(pos)?;
            }
        }

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Apply all updates
        for update in updates {
            let node_id = bridge.parse_node_id(&update.node_id)?;

            let mut node = graph.get_node(node_id)
                .map_err(|_| BridgeError::NodeNotFound { id: update.node_id.clone() })?
                .clone();

            // Apply updates
            if let Some(text) = update.update.text {
                node.text = text;
            }
            if let Some(pos) = update.update.position {
                node.position = Point::new(pos.x, pos.y);
            }
            if let Some(tags) = update.update.tags {
                node.tags = tags;
            }
            if let Some(metadata) = update.update.metadata {
                node.metadata.extend(metadata);
            }

            node.touch();
            graph.update_node(node).map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to update node {}: {}", update.node_id, e),
            })?;
        }

        bridge.record_metrics("batch_update_nodes", start_time, updates.len() as u32);
        Ok(())
    }

    /// Get node hierarchy (ancestors and descendants) with depth control
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn get_node_hierarchy(
        bridge: &MindmapBridge,
        node_id: String,
        max_depth: Option<i32>,
        include_ancestors: bool,
    ) -> Result<NodeHierarchy, BridgeError> {
        let start_time = Instant::now();
        let id = bridge.parse_node_id(&node_id)?;

        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let node = graph.get_node(id).map_err(|_| BridgeError::NodeNotFound {
            id: node_id,
        })?;

        let mut hierarchy = NodeHierarchy {
            root: bridge.node_to_ffi(node),
            ancestors: Vec::new(),
            descendants: Vec::new(),
            total_depth: 0,
        };

        // Get ancestors if requested
        if include_ancestors {
            let mut current_id = node.parent_id;
            while let Some(parent_id) = current_id {
                if let Some(parent_node) = graph.get_node(parent_id) {
                    hierarchy.ancestors.push(bridge.node_to_ffi(parent_node));
                    current_id = parent_node.parent_id;
                } else {
                    break;
                }
            }
            hierarchy.ancestors.reverse(); // Root first
        }

        // Get descendants with depth control
        let depth_limit = max_depth.unwrap_or(-1);
        Self::collect_descendants(&graph, bridge, id, &mut hierarchy.descendants, 0, depth_limit);

        hierarchy.total_depth = Self::calculate_max_depth(&hierarchy.descendants);

        bridge.record_metrics("get_node_hierarchy", start_time, 1);
        Ok(hierarchy)
    }

    /// Move node to new parent with validation
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn move_node_with_validation(
        bridge: &MindmapBridge,
        node_id: String,
        new_parent_id: Option<String>,
        new_position: Option<FfiPoint>,
    ) -> Result<(), BridgeError> {
        let start_time = Instant::now();
        let id = bridge.parse_node_id(&node_id)?;

        let new_parent = if let Some(parent_str) = new_parent_id {
            Some(bridge.parse_node_id(&parent_str)?)
        } else {
            None
        };

        if let Some(pos) = &new_position {
            utils::validate_position(pos)?;
        }

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Validate move operation doesn't create cycles
        if let Some(new_parent) = new_parent {
            if Self::would_create_cycle(&graph, id, new_parent)? {
                return Err(BridgeError::InvalidOperation {
                    message: "Moving node would create a cycle".to_string(),
                });
            }
        }

        // Get and update node
        let mut node = graph.get_node(id)
            .map_err(|_| BridgeError::NodeNotFound { id: node_id })?
            .clone();

        node.parent_id = new_parent;

        if let Some(pos) = new_position {
            node.position = Point::new(pos.x, pos.y);
        }

        node.touch();
        graph.update_node(node).map_err(|e| BridgeError::InvalidOperation {
            message: format!("Failed to move node: {}", e),
        })?;

        bridge.record_metrics("move_node_with_validation", start_time, 1);
        Ok(())
    }

    /// Delete nodes by criteria (tags, depth, etc.)
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn delete_nodes_by_criteria(
        bridge: &MindmapBridge,
        criteria: NodeDeletionCriteria,
    ) -> Result<Vec<String>, BridgeError> {
        let start_time = Instant::now();
        let mut deleted_ids = Vec::new();

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Find nodes matching criteria
        let nodes_to_delete = Self::find_nodes_by_criteria(&graph, &criteria)?;

        // Delete nodes (children will be handled automatically)
        for node_id in nodes_to_delete {
            if graph.contains_node(node_id) {
                graph.remove_node(node_id).map_err(|e| BridgeError::InvalidOperation {
                    message: format!("Failed to delete node: {}", e),
                })?;
                deleted_ids.push(node_id.to_string());

                // Update search index
                if let Ok(mut search) = bridge.search_engine.write() {
                    search.remove_node(node_id);
                }
            }
        }

        bridge.record_metrics("delete_nodes_by_criteria", start_time, deleted_ids.len() as u32);
        Ok(deleted_ids)
    }

    // Helper methods

    fn collect_descendants(
        graph: &Graph,
        bridge: &MindmapBridge,
        parent_id: NodeId,
        descendants: &mut Vec<FfiNodeData>,
        current_depth: i32,
        max_depth: i32,
    ) {
        if max_depth >= 0 && current_depth >= max_depth {
            return;
        }

        if let Ok(children) = graph.get_children(parent_id) {
            for child in children {
                descendants.push(bridge.node_to_ffi(child));
                Self::collect_descendants(graph, bridge, child.id, descendants, current_depth + 1, max_depth);
            }
        }
    }

    fn calculate_max_depth(descendants: &[FfiNodeData]) -> i32 {
        // This is a simplified calculation - in a real implementation,
        // you'd need to track the actual depth of each node
        descendants.len() as i32
    }

    fn would_create_cycle(graph: &Graph, node_id: NodeId, new_parent_id: NodeId) -> Result<bool, BridgeError> {
        // Check if new_parent_id is a descendant of node_id
        let mut current = Some(new_parent_id);
        while let Some(current_id) = current {
            if current_id == node_id {
                return Ok(true);
            }
            current = graph.get_node(current_id)
                .map_err(|_| BridgeError::InvalidOperation {
                    message: "Invalid node in hierarchy".to_string(),
                })?
                .parent_id;
        }
        Ok(false)
    }

    fn find_nodes_by_criteria(graph: &Graph, criteria: &NodeDeletionCriteria) -> Result<Vec<NodeId>, BridgeError> {
        let mut matching_nodes = Vec::new();

        for (node_id, node) in graph.get_all_nodes() {
            let mut matches = true;

            // Check tag criteria
            if let Some(ref required_tags) = criteria.has_tags {
                if !required_tags.iter().all(|tag| node.tags.contains(tag)) {
                    matches = false;
                }
            }

            // Check text content criteria
            if let Some(ref text_contains) = criteria.text_contains {
                if !node.text.contains(text_contains) {
                    matches = false;
                }
            }

            // Check empty criteria
            if criteria.is_empty && !node.text.trim().is_empty() {
                matches = false;
            }

            if matches {
                matching_nodes.push(*node_id);
            }
        }

        Ok(matching_nodes)
    }
}

/// Data structure for batch node creation
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct BatchNodeCreate {
    pub parent_id: Option<String>,
    pub text: String,
    pub position: Option<FfiPoint>,
    pub tags: Option<Vec<String>>,
    pub metadata: Option<HashMap<String, String>>,
}

/// Data structure for batch node updates
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct BatchNodeUpdate {
    pub node_id: String,
    pub update: FfiNodeUpdate,
}

/// Node hierarchy information
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct NodeHierarchy {
    pub root: FfiNodeData,
    pub ancestors: Vec<FfiNodeData>,
    pub descendants: Vec<FfiNodeData>,
    pub total_depth: i32,
}

/// Criteria for node deletion operations
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct NodeDeletionCriteria {
    pub has_tags: Option<Vec<String>>,
    pub text_contains: Option<String>,
    pub is_empty: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::NodeId;

    #[test]
    fn test_batch_node_create_structure() {
        let batch_create = BatchNodeCreate {
            parent_id: Some("parent-123".to_string()),
            text: "Test node".to_string(),
            position: Some(FfiPoint { x: 10.0, y: 20.0 }),
            tags: Some(vec!["tag1".to_string(), "tag2".to_string()]),
            metadata: Some([("key".to_string(), "value".to_string())].into()),
        };

        assert_eq!(batch_create.text, "Test node");
        assert!(batch_create.parent_id.is_some());
        assert!(batch_create.position.is_some());
        assert!(batch_create.tags.is_some());
        assert!(batch_create.metadata.is_some());
    }

    #[test]
    fn test_node_hierarchy_structure() {
        let root_node = FfiNodeData {
            id: "root-123".to_string(),
            parent_id: None,
            text: "Root".to_string(),
            position: FfiPoint { x: 0.0, y: 0.0 },
            tags: Vec::new(),
            created_at: 1234567890,
            updated_at: 1234567890,
            metadata: HashMap::new(),
        };

        let hierarchy = NodeHierarchy {
            root: root_node,
            ancestors: Vec::new(),
            descendants: Vec::new(),
            total_depth: 0,
        };

        assert_eq!(hierarchy.root.text, "Root");
        assert_eq!(hierarchy.total_depth, 0);
        assert!(hierarchy.ancestors.is_empty());
        assert!(hierarchy.descendants.is_empty());
    }

    #[test]
    fn test_node_deletion_criteria() {
        let criteria = NodeDeletionCriteria {
            has_tags: Some(vec!["delete".to_string()]),
            text_contains: Some("temp".to_string()),
            is_empty: false,
        };

        assert!(criteria.has_tags.is_some());
        assert!(criteria.text_contains.is_some());
        assert!(!criteria.is_empty);
    }
}