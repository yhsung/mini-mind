//! Graph operations for node and edge management
//!
//! This module provides high-level operations for manipulating graphs,
//! including relationship management, validation, and batch operations.

use crate::graph::Graph;
use crate::models::{Node, Edge};
use crate::types::{ids::{NodeId, EdgeId}, MindmapResult, MindmapError, Point};
use std::collections::{HashMap, HashSet};

/// Batch operation result
#[derive(Debug, Clone, PartialEq)]
pub struct BatchResult<T> {
    /// Successful operations
    pub successes: Vec<T>,
    /// Failed operations with error messages
    pub failures: Vec<(T, String)>,
}

/// Operations for node management
impl Graph {
    /// Add a node with position and parent validation
    pub fn add_node_with_validation(&mut self, node: Node) -> MindmapResult<NodeId> {
        // Validate node content
        node.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // If node has a parent, validate hierarchy rules
        if let Some(parent_id) = node.parent_id {
            self.validate_parent_relationship(node.id, parent_id)?;
        }

        // Check for position conflicts in same parent group
        if let Some(parent_id) = node.parent_id {
            self.validate_position_conflicts(parent_id, &node.position)?;
        }

        self.add_node(node)
    }

    /// Update a node while maintaining graph consistency
    pub fn update_node_with_validation(&mut self, mut node: Node) -> MindmapResult<()> {
        // Check if node exists
        let existing_node = self.get_node(node.id)
            .ok_or(MindmapError::NodeNotFound { id: node.id.as_uuid() })?;

        // Validate node content
        node.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // If parent is changing, validate the new relationship
        if node.parent_id != existing_node.parent_id {
            if let Some(new_parent) = node.parent_id {
                self.validate_parent_relationship(node.id, new_parent)?;
                self.validate_no_circular_dependency(node.id, new_parent)?;
            }
        }

        // Update timestamp
        node.updated_at = chrono::Utc::now();

        self.update_node(node)
    }

    /// Delete a node and handle dependent relationships
    pub fn delete_node_with_cleanup(&mut self, node_id: NodeId) -> MindmapResult<Node> {
        // Check if node exists
        if !self.contains_node(node_id) {
            return Err(MindmapError::NodeNotFound { id: node_id.as_uuid() });
        }

        // Get all children of this node
        let children: Vec<_> = self.get_children(node_id).into_iter().map(|n| n.id).collect();

        // Handle orphaned children by either removing them or reparenting
        for child_id in children {
            // Option 1: Remove child nodes (cascade delete)
            self.delete_node_with_cleanup(child_id)?;

            // Option 2: Reparent to grandparent (uncomment if preferred)
            // if let Some(grandparent_id) = self.get_parent(node_id).map(|n| n.id) {
            //     if let Some(mut child) = self.get_node_mut(child_id) {
            //         child.parent_id = Some(grandparent_id);
            //         child.updated_at = chrono::Utc::now();
            //     }
            // } else {
            //     // Make orphaned children root nodes
            //     if let Some(mut child) = self.get_node_mut(child_id) {
            //         child.parent_id = None;
            //         child.updated_at = chrono::Utc::now();
            //     }
            // }
        }

        // Remove the node (this also removes all connected edges)
        self.remove_node(node_id)
    }

    /// Move a node to a new parent
    pub fn move_node(&mut self, node_id: NodeId, new_parent_id: Option<NodeId>) -> MindmapResult<()> {
        let mut node = self.get_node(node_id)
            .ok_or(MindmapError::NodeNotFound { id: node_id.as_uuid() })?
            .clone();

        // Validate new parent relationship
        if let Some(parent_id) = new_parent_id {
            self.validate_parent_relationship(node_id, parent_id)?;
            self.validate_no_circular_dependency(node_id, parent_id)?;
        }

        // Update parent
        node.parent_id = new_parent_id;
        node.updated_at = chrono::Utc::now();

        self.update_node(node)
    }

    /// Batch add multiple nodes
    pub fn add_nodes_batch(&mut self, nodes: Vec<Node>) -> BatchResult<NodeId> {
        let mut successes = Vec::new();
        let mut failures = Vec::new();

        for node in nodes {
            let node_id = node.id;
            match self.add_node_with_validation(node) {
                Ok(id) => successes.push(id),
                Err(e) => failures.push((node_id, e.to_string())),
            }
        }

        BatchResult { successes, failures }
    }

    /// Batch update multiple nodes
    pub fn update_nodes_batch(&mut self, nodes: Vec<Node>) -> BatchResult<NodeId> {
        let mut successes = Vec::new();
        let mut failures = Vec::new();

        for node in nodes {
            let node_id = node.id;
            match self.update_node_with_validation(node) {
                Ok(_) => successes.push(node_id),
                Err(e) => failures.push((node_id, e.to_string())),
            }
        }

        BatchResult { successes, failures }
    }

    /// Validate parent-child relationship rules
    fn validate_parent_relationship(&self, child_id: NodeId, parent_id: NodeId) -> MindmapResult<()> {
        // Parent must exist
        if !self.contains_node(parent_id) {
            return Err(MindmapError::NodeNotFound { id: parent_id.as_uuid() });
        }

        // Child cannot be its own parent
        if child_id == parent_id {
            return Err(MindmapError::InvalidOperation {
                message: "Node cannot be its own parent".to_string()
            });
        }

        Ok(())
    }

    /// Validate that no circular dependencies would be created
    fn validate_no_circular_dependency(&self, child_id: NodeId, parent_id: NodeId) -> MindmapResult<()> {
        // Check if parent_id is a descendant of child_id
        if self.is_descendant(parent_id, child_id) {
            return Err(MindmapError::InvalidOperation {
                message: "Cannot create circular dependency in parent-child relationships".to_string()
            });
        }

        Ok(())
    }

    /// Validate position conflicts within same parent group
    fn validate_position_conflicts(&self, parent_id: NodeId, position: &Point) -> MindmapResult<()> {
        let children = self.get_children(parent_id);
        let min_distance = 50.0; // Minimum distance between sibling nodes

        for child in children {
            let distance = child.position.distance_to(position);
            if distance < min_distance {
                return Err(MindmapError::InvalidOperation {
                    message: format!("Position too close to existing node (minimum distance: {})", min_distance)
                });
            }
        }

        Ok(())
    }
}

/// Operations for edge management
impl Graph {
    /// Add an edge with comprehensive validation
    pub fn add_edge_with_validation(&mut self, edge: Edge) -> MindmapResult<EdgeId> {
        // Basic edge validation
        edge.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // Check that both nodes exist
        if !self.contains_node(edge.from_node) {
            return Err(MindmapError::NodeNotFound { id: edge.from_node.as_uuid() });
        }
        if !self.contains_node(edge.to_node) {
            return Err(MindmapError::NodeNotFound { id: edge.to_node.as_uuid() });
        }

        // Check for duplicate edges
        if self.has_edge_between(edge.from_node, edge.to_node) {
            return Err(MindmapError::InvalidOperation {
                message: "Edge already exists between these nodes".to_string()
            });
        }

        // Optionally prevent cycles (uncomment if strict DAG is required)
        // if self.would_create_cycle(edge.from_node, edge.to_node) {
        //     return Err(MindmapError::InvalidOperation {
        //         message: "Edge would create a cycle".to_string()
        //     });
        // }

        self.add_edge(edge)
    }

    /// Update an edge while maintaining consistency
    pub fn update_edge_with_validation(&mut self, mut edge: Edge) -> MindmapResult<()> {
        // Check if edge exists
        if !self.contains_edge(edge.id) {
            return Err(MindmapError::EdgeNotFound { id: edge.id.as_uuid() });
        }

        // Validate edge content
        edge.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // Update timestamp
        edge.updated_at = chrono::Utc::now();

        // Remove old edge and add updated one
        self.remove_edge(edge.id)?;
        self.add_edge(edge)?;

        Ok(())
    }

    /// Check if an edge exists between two nodes
    pub fn has_edge_between(&self, from: NodeId, to: NodeId) -> bool {
        self.get_outgoing_edges(from)
            .iter()
            .any(|edge| edge.to_node == to)
    }

    /// Check if adding an edge would create a cycle
    pub fn would_create_cycle(&self, from: NodeId, to: NodeId) -> bool {
        // If there's already a path from `to` to `from`, adding `from` -> `to` would create a cycle
        self.has_path(to, from)
    }

    /// Batch add multiple edges
    pub fn add_edges_batch(&mut self, edges: Vec<Edge>) -> BatchResult<EdgeId> {
        let mut successes = Vec::new();
        let mut failures = Vec::new();

        for edge in edges {
            let edge_id = edge.id;
            match self.add_edge_with_validation(edge) {
                Ok(id) => successes.push(id),
                Err(e) => failures.push((edge_id, e.to_string())),
            }
        }

        BatchResult { successes, failures }
    }

    /// Remove all edges between two nodes
    pub fn remove_edges_between(&mut self, node1: NodeId, node2: NodeId) -> MindmapResult<Vec<Edge>> {
        let mut removed_edges = Vec::new();

        // Find all edges between the nodes (in both directions)
        let edges_to_remove: Vec<_> = self.edges()
            .filter(|edge| edge.connects(node1, node2))
            .map(|edge| edge.id)
            .collect();

        for edge_id in edges_to_remove {
            match self.remove_edge(edge_id) {
                Ok(edge) => removed_edges.push(edge),
                Err(e) => return Err(e),
            }
        }

        Ok(removed_edges)
    }
}

/// Advanced graph operations
impl Graph {
    /// Clone a subgraph starting from a node
    pub fn clone_subgraph(&self, root_id: NodeId, max_depth: Option<usize>) -> MindmapResult<Graph> {
        let mut new_graph = Graph::new();
        let mut visited = HashSet::new();
        let mut id_mapping = HashMap::new(); // old_id -> new_id

        self.clone_subgraph_recursive(
            root_id,
            &mut new_graph,
            &mut visited,
            &mut id_mapping,
            0,
            max_depth,
        )?;

        // Add edges between cloned nodes
        for edge in self.edges() {
            if let (Some(&new_from), Some(&new_to)) = (
                id_mapping.get(&edge.from_node),
                id_mapping.get(&edge.to_node),
            ) {
                let mut new_edge = edge.clone();
                new_edge.id = EdgeId::new();
                new_edge.from_node = new_from;
                new_edge.to_node = new_to;
                new_graph.add_edge(new_edge)?;
            }
        }

        Ok(new_graph)
    }

    /// Helper for recursive subgraph cloning
    fn clone_subgraph_recursive(
        &self,
        node_id: NodeId,
        new_graph: &mut Graph,
        visited: &mut HashSet<NodeId>,
        id_mapping: &mut HashMap<NodeId, NodeId>,
        current_depth: usize,
        max_depth: Option<usize>,
    ) -> MindmapResult<()> {
        if visited.contains(&node_id) {
            return Ok(());
        }

        if let Some(max) = max_depth {
            if current_depth > max {
                return Ok(());
            }
        }

        visited.insert(node_id);

        // Clone the node
        if let Some(node) = self.get_node(node_id) {
            let mut new_node = node.clone();
            let new_id = NodeId::new();
            new_node.id = new_id;

            // Update parent reference if parent was already cloned
            if let Some(parent_id) = new_node.parent_id {
                new_node.parent_id = id_mapping.get(&parent_id).copied();
            }

            id_mapping.insert(node_id, new_id);
            new_graph.add_node(new_node)?;

            // Recursively clone children
            for child in self.get_children(node_id) {
                self.clone_subgraph_recursive(
                    child.id,
                    new_graph,
                    visited,
                    id_mapping,
                    current_depth + 1,
                    max_depth,
                )?;
            }
        }

        Ok(())
    }

    /// Merge another graph into this one
    pub fn merge_graph(&mut self, other: &Graph) -> MindmapResult<HashMap<NodeId, NodeId>> {
        let mut id_mapping = HashMap::new();

        // First pass: add all nodes with new IDs
        for node in other.nodes() {
            let mut new_node = node.clone();
            let new_id = NodeId::new();
            new_node.id = new_id;
            new_node.parent_id = None; // Will be fixed in second pass

            id_mapping.insert(node.id, new_id);
            self.add_node(new_node)?;
        }

        // Second pass: fix parent relationships
        for node in other.nodes() {
            if let Some(parent_id) = node.parent_id {
                if let Some(&new_parent_id) = id_mapping.get(&parent_id) {
                    if let Some(&new_node_id) = id_mapping.get(&node.id) {
                        self.move_node(new_node_id, Some(new_parent_id))?;
                    }
                }
            }
        }

        // Third pass: add all edges with new IDs
        for edge in other.edges() {
            if let (Some(&new_from), Some(&new_to)) = (
                id_mapping.get(&edge.from_node),
                id_mapping.get(&edge.to_node),
            ) {
                let mut new_edge = edge.clone();
                new_edge.id = EdgeId::new();
                new_edge.from_node = new_from;
                new_edge.to_node = new_to;
                self.add_edge(new_edge)?;
            }
        }

        Ok(id_mapping)
    }

    /// Get graph statistics
    pub fn get_statistics(&self) -> GraphStatistics {
        let node_count = self.node_count();
        let edge_count = self.edge_count();
        let root_count = self.get_root_nodes().len();
        let max_depth = self.max_depth();
        let has_cycles = self.has_cycles();

        // Calculate average degree
        let total_degree: usize = self.nodes()
            .map(|node| self.get_neighbors(node.id).len())
            .sum();
        let avg_degree = if node_count > 0 {
            total_degree as f64 / node_count as f64
        } else {
            0.0
        };

        GraphStatistics {
            node_count,
            edge_count,
            root_count,
            max_depth,
            avg_degree,
            has_cycles,
        }
    }
}

/// Graph statistics
#[derive(Debug, Clone, PartialEq)]
pub struct GraphStatistics {
    pub node_count: usize,
    pub edge_count: usize,
    pub root_count: usize,
    pub max_depth: usize,
    pub avg_degree: f64,
    pub has_cycles: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Node, Edge};
    use crate::types::Point;

    #[test]
    fn test_add_node_with_validation() {
        let mut graph = Graph::new();

        // Add root node
        let root = Node::new("Root");
        let root_id = root.id;
        assert!(graph.add_node_with_validation(root).is_ok());

        // Add child node
        let child = Node::new_child(root_id, "Child");
        assert!(graph.add_node_with_validation(child).is_ok());

        // Try to add node with non-existent parent
        let invalid_child = Node::new_child(NodeId::new(), "Invalid");
        assert!(graph.add_node_with_validation(invalid_child).is_err());
    }

    #[test]
    fn test_update_node_with_validation() {
        let mut graph = Graph::new();

        let mut node = Node::new("Original");
        let node_id = node.id;
        graph.add_node_with_validation(node.clone()).unwrap();

        // Update node text
        node.text = "Updated".to_string();
        assert!(graph.update_node_with_validation(node).is_ok());

        // Verify update
        let updated = graph.get_node(node_id).unwrap();
        assert_eq!(updated.text, "Updated");
    }

    #[test]
    fn test_delete_node_with_cleanup() {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let child = Node::new_child(root.id, "Child");
        let grandchild = Node::new_child(child.id, "Grandchild");

        let root_id = root.id;
        let child_id = child.id;

        graph.add_node_with_validation(root).unwrap();
        graph.add_node_with_validation(child).unwrap();
        graph.add_node_with_validation(grandchild).unwrap();

        // Delete child node (should cascade to grandchild)
        assert!(graph.delete_node_with_cleanup(child_id).is_ok());

        // Root should still exist, others should be gone
        assert!(graph.contains_node(root_id));
        assert!(!graph.contains_node(child_id));
    }

    #[test]
    fn test_move_node() {
        let mut graph = Graph::new();

        let root1 = Node::new("Root1");
        let root2 = Node::new("Root2");
        let child = Node::new_child(root1.id, "Child");

        let _root1_id = root1.id;
        let root2_id = root2.id;
        let child_id = child.id;

        graph.add_node_with_validation(root1).unwrap();
        graph.add_node_with_validation(root2).unwrap();
        graph.add_node_with_validation(child).unwrap();

        // Move child from root1 to root2
        assert!(graph.move_node(child_id, Some(root2_id)).is_ok());

        // Verify new parent
        let moved_child = graph.get_node(child_id).unwrap();
        assert_eq!(moved_child.parent_id, Some(root2_id));
    }

    #[test]
    fn test_circular_dependency_prevention() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node1");
        let node2 = Node::new_child(node1.id, "Node2");

        let node1_id = node1.id;
        let node2_id = node2.id;

        graph.add_node_with_validation(node1).unwrap();
        graph.add_node_with_validation(node2).unwrap();

        // Try to make node1 a child of node2 (would create cycle)
        assert!(graph.move_node(node1_id, Some(node2_id)).is_err());
    }

    #[test]
    fn test_batch_operations() {
        let mut graph = Graph::new();

        let nodes = vec![
            Node::new("Node1"),
            Node::new("Node2"),
            Node::new("Node3"),
        ];

        let result = graph.add_nodes_batch(nodes);
        assert_eq!(result.successes.len(), 3);
        assert_eq!(result.failures.len(), 0);
    }

    #[test]
    fn test_edge_validation() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node1");
        let node2 = Node::new("Node2");
        let node1_id = node1.id;
        let node2_id = node2.id;

        graph.add_node_with_validation(node1).unwrap();
        graph.add_node_with_validation(node2).unwrap();

        // Add valid edge
        let edge = Edge::new(node1_id, node2_id);
        assert!(graph.add_edge_with_validation(edge).is_ok());

        // Try to add duplicate edge
        let duplicate_edge = Edge::new(node1_id, node2_id);
        assert!(graph.add_edge_with_validation(duplicate_edge).is_err());
    }

    #[test]
    fn test_clone_subgraph() {
        let mut graph = Graph::new();

        let mut root = Node::new("Root");
        root.position = Point::new(0.0, 0.0);

        let mut child1 = Node::new_child(root.id, "Child1");
        child1.position = Point::new(100.0, 0.0);

        let mut child2 = Node::new_child(root.id, "Child2");
        child2.position = Point::new(200.0, 0.0);

        let mut grandchild = Node::new_child(child1.id, "Grandchild");
        grandchild.position = Point::new(100.0, 100.0);

        let root_id = root.id;

        graph.add_node_with_validation(root).unwrap();
        graph.add_node_with_validation(child1).unwrap();
        graph.add_node_with_validation(child2).unwrap();
        graph.add_node_with_validation(grandchild).unwrap();

        // Clone subgraph with depth limit
        let cloned = graph.clone_subgraph(root_id, Some(1)).unwrap();
        assert_eq!(cloned.node_count(), 3); // root + 2 children, no grandchild
    }

    #[test]
    fn test_graph_statistics() {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let child = Node::new_child(root.id, "Child");

        graph.add_node_with_validation(root).unwrap();
        graph.add_node_with_validation(child).unwrap();

        let stats = graph.get_statistics();
        assert_eq!(stats.node_count, 2);
        assert_eq!(stats.root_count, 1);
        assert_eq!(stats.max_depth, 1);
        assert!(!stats.has_cycles);
    }

    #[test]
    fn test_position_validation() {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node_with_validation(root).unwrap();

        // Add first child at (100, 100)
        let mut child1 = Node::new_child(root_id, "Child1");
        child1.position = Point::new(100.0, 100.0);
        graph.add_node_with_validation(child1).unwrap();

        // Try to add second child too close (should fail)
        let mut child2 = Node::new_child(root_id, "Child2");
        child2.position = Point::new(110.0, 110.0); // Too close (distance < 50)
        assert!(graph.add_node_with_validation(child2).is_err());

        // Add second child at safe distance (should succeed)
        let mut child3 = Node::new_child(root_id, "Child3");
        child3.position = Point::new(200.0, 200.0); // Safe distance
        assert!(graph.add_node_with_validation(child3).is_ok());
    }
}