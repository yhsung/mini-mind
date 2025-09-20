//! Core graph data structure for mindmap representation
//!
//! This module implements the main Graph struct that manages nodes and edges
//! in a mindmap with validation and manipulation methods.

use crate::models::{Node, Edge};
use crate::types::{ids::{NodeId, EdgeId}, MindmapResult, MindmapError};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

/// Core graph structure for mindmap data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Graph {
    /// Nodes in the graph indexed by ID
    nodes: HashMap<NodeId, Node>,
    /// Edges in the graph indexed by ID
    edges: HashMap<EdgeId, Edge>,
    /// Index of outgoing edges for each node (node_id -> set of edge_ids)
    outgoing_edges: HashMap<NodeId, HashSet<EdgeId>>,
    /// Index of incoming edges for each node (node_id -> set of edge_ids)
    incoming_edges: HashMap<NodeId, HashSet<EdgeId>>,
}

impl Graph {
    /// Create a new empty graph
    pub fn new() -> Self {
        Self {
            nodes: HashMap::new(),
            edges: HashMap::new(),
            outgoing_edges: HashMap::new(),
            incoming_edges: HashMap::new(),
        }
    }

    /// Add a node to the graph
    pub fn add_node(&mut self, node: Node) -> MindmapResult<NodeId> {
        // Validate the node
        node.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // If node has a parent, validate that the parent exists
        if let Some(parent_id) = node.parent_id {
            if !self.nodes.contains_key(&parent_id) {
                return Err(MindmapError::NodeNotFound { id: parent_id.as_uuid() });
            }
        }

        let node_id = node.id;

        // Initialize edge indices for this node
        self.outgoing_edges.entry(node_id).or_insert_with(HashSet::new);
        self.incoming_edges.entry(node_id).or_insert_with(HashSet::new);

        // Insert the node
        self.nodes.insert(node_id, node);

        Ok(node_id)
    }

    /// Remove a node and all its associated edges
    pub fn remove_node(&mut self, node_id: NodeId) -> MindmapResult<Node> {
        let node = self.nodes.remove(&node_id)
            .ok_or(MindmapError::NodeNotFound { id: node_id.as_uuid() })?;

        // Remove all edges connected to this node
        let outgoing = self.outgoing_edges.remove(&node_id).unwrap_or_default();
        let incoming = self.incoming_edges.remove(&node_id).unwrap_or_default();

        for edge_id in outgoing.iter().chain(incoming.iter()) {
            self.edges.remove(edge_id);
        }

        // Update edge indices for remaining nodes
        for other_outgoing in self.outgoing_edges.values_mut() {
            for edge_id in &outgoing.union(&incoming).collect::<HashSet<_>>() {
                other_outgoing.remove(edge_id);
            }
        }

        for other_incoming in self.incoming_edges.values_mut() {
            for edge_id in &outgoing.union(&incoming).collect::<HashSet<_>>() {
                other_incoming.remove(edge_id);
            }
        }

        Ok(node)
    }

    /// Get a node by ID
    pub fn get_node(&self, node_id: NodeId) -> Option<&Node> {
        self.nodes.get(&node_id)
    }

    /// Get a mutable reference to a node by ID
    pub fn get_node_mut(&mut self, node_id: NodeId) -> Option<&mut Node> {
        self.nodes.get_mut(&node_id)
    }

    /// Update a node in the graph
    pub fn update_node(&mut self, node: Node) -> MindmapResult<()> {
        // Validate the node
        node.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // Check if node exists
        if !self.nodes.contains_key(&node.id) {
            return Err(MindmapError::NodeNotFound { id: node.id.as_uuid() });
        }

        // If node has a parent, validate that the parent exists
        if let Some(parent_id) = node.parent_id {
            if !self.nodes.contains_key(&parent_id) {
                return Err(MindmapError::NodeNotFound { id: parent_id.as_uuid() });
            }
        }

        self.nodes.insert(node.id, node);
        Ok(())
    }

    /// Add an edge to the graph
    pub fn add_edge(&mut self, edge: Edge) -> MindmapResult<EdgeId> {
        // Validate the edge
        edge.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

        // Check that both nodes exist
        if !self.nodes.contains_key(&edge.from_node) {
            return Err(MindmapError::NodeNotFound { id: edge.from_node.as_uuid() });
        }
        if !self.nodes.contains_key(&edge.to_node) {
            return Err(MindmapError::NodeNotFound { id: edge.to_node.as_uuid() });
        }

        let edge_id = edge.id;

        // Update edge indices
        self.outgoing_edges.entry(edge.from_node)
            .or_insert_with(HashSet::new)
            .insert(edge_id);
        self.incoming_edges.entry(edge.to_node)
            .or_insert_with(HashSet::new)
            .insert(edge_id);

        // Insert the edge
        self.edges.insert(edge_id, edge);

        Ok(edge_id)
    }

    /// Remove an edge from the graph
    pub fn remove_edge(&mut self, edge_id: EdgeId) -> MindmapResult<Edge> {
        let edge = self.edges.remove(&edge_id)
            .ok_or(MindmapError::EdgeNotFound { id: edge_id.as_uuid() })?;

        // Update edge indices
        if let Some(outgoing) = self.outgoing_edges.get_mut(&edge.from_node) {
            outgoing.remove(&edge_id);
        }
        if let Some(incoming) = self.incoming_edges.get_mut(&edge.to_node) {
            incoming.remove(&edge_id);
        }

        Ok(edge)
    }

    /// Get an edge by ID
    pub fn get_edge(&self, edge_id: EdgeId) -> Option<&Edge> {
        self.edges.get(&edge_id)
    }

    /// Get all nodes in the graph
    pub fn nodes(&self) -> impl Iterator<Item = &Node> {
        self.nodes.values()
    }

    /// Get all edges in the graph
    pub fn edges(&self) -> impl Iterator<Item = &Edge> {
        self.edges.values()
    }

    /// Get the number of nodes in the graph
    pub fn node_count(&self) -> usize {
        self.nodes.len()
    }

    /// Get the number of edges in the graph
    pub fn edge_count(&self) -> usize {
        self.edges.len()
    }

    /// Check if a node exists in the graph
    pub fn contains_node(&self, node_id: NodeId) -> bool {
        self.nodes.contains_key(&node_id)
    }

    /// Check if an edge exists in the graph
    pub fn contains_edge(&self, edge_id: EdgeId) -> bool {
        self.edges.contains_key(&edge_id)
    }

    /// Get all children of a node
    pub fn get_children(&self, node_id: NodeId) -> Vec<&Node> {
        self.nodes.values()
            .filter(|node| node.parent_id == Some(node_id))
            .collect()
    }

    /// Get the parent of a node
    pub fn get_parent(&self, node_id: NodeId) -> Option<&Node> {
        self.get_node(node_id)
            .and_then(|node| node.parent_id)
            .and_then(|parent_id| self.get_node(parent_id))
    }

    /// Get all root nodes (nodes with no parent)
    pub fn get_root_nodes(&self) -> Vec<&Node> {
        self.nodes.values()
            .filter(|node| node.parent_id.is_none())
            .collect()
    }

    /// Get all outgoing edges from a node
    pub fn get_outgoing_edges(&self, node_id: NodeId) -> Vec<&Edge> {
        self.outgoing_edges.get(&node_id)
            .map(|edge_ids| {
                edge_ids.iter()
                    .filter_map(|edge_id| self.edges.get(edge_id))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Get all incoming edges to a node
    pub fn get_incoming_edges(&self, node_id: NodeId) -> Vec<&Edge> {
        self.incoming_edges.get(&node_id)
            .map(|edge_ids| {
                edge_ids.iter()
                    .filter_map(|edge_id| self.edges.get(edge_id))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Get all neighbors of a node (connected by edges)
    pub fn get_neighbors(&self, node_id: NodeId) -> Vec<NodeId> {
        let mut neighbors = HashSet::new();

        // Add nodes connected by outgoing edges
        for edge in self.get_outgoing_edges(node_id) {
            neighbors.insert(edge.to_node);
        }

        // Add nodes connected by incoming edges
        for edge in self.get_incoming_edges(node_id) {
            neighbors.insert(edge.from_node);
        }

        neighbors.into_iter().collect()
    }

    /// Check if there's a path between two nodes
    pub fn has_path(&self, from: NodeId, to: NodeId) -> bool {
        if from == to {
            return true;
        }

        let mut visited = HashSet::new();
        let mut stack = vec![from];

        while let Some(current) = stack.pop() {
            if visited.contains(&current) {
                continue;
            }
            visited.insert(current);

            for neighbor in self.get_neighbors(current) {
                if neighbor == to {
                    return true;
                }
                if !visited.contains(&neighbor) {
                    stack.push(neighbor);
                }
            }
        }

        false
    }

    /// Validate the entire graph for consistency
    pub fn validate(&self) -> MindmapResult<()> {
        // Validate all nodes
        for node in self.nodes.values() {
            node.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

            // Check parent exists if specified
            if let Some(parent_id) = node.parent_id {
                if !self.nodes.contains_key(&parent_id) {
                    return Err(MindmapError::NodeNotFound { id: parent_id.as_uuid() });
                }
            }
        }

        // Validate all edges
        for edge in self.edges.values() {
            edge.validate().map_err(|msg| MindmapError::InvalidOperation { message: msg })?;

            // Check that both endpoint nodes exist
            if !self.nodes.contains_key(&edge.from_node) {
                return Err(MindmapError::NodeNotFound { id: edge.from_node.as_uuid() });
            }
            if !self.nodes.contains_key(&edge.to_node) {
                return Err(MindmapError::NodeNotFound { id: edge.to_node.as_uuid() });
            }
        }

        // Validate edge indices consistency
        for (node_id, edge_ids) in &self.outgoing_edges {
            for edge_id in edge_ids {
                if let Some(edge) = self.edges.get(edge_id) {
                    if edge.from_node != *node_id {
                        return Err(MindmapError::InvalidOperation {
                            message: "Outgoing edge index inconsistency".to_string()
                        });
                    }
                }
            }
        }

        for (node_id, edge_ids) in &self.incoming_edges {
            for edge_id in edge_ids {
                if let Some(edge) = self.edges.get(edge_id) {
                    if edge.to_node != *node_id {
                        return Err(MindmapError::InvalidOperation {
                            message: "Incoming edge index inconsistency".to_string()
                        });
                    }
                }
            }
        }

        Ok(())
    }

    /// Clear all nodes and edges from the graph
    pub fn clear(&mut self) {
        self.nodes.clear();
        self.edges.clear();
        self.outgoing_edges.clear();
        self.incoming_edges.clear();
    }

    /// Check if the graph is empty
    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty() && self.edges.is_empty()
    }
}

impl Default for Graph {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Node, Edge};

    #[test]
    fn test_graph_creation() {
        let graph = Graph::new();
        assert!(graph.is_empty());
        assert_eq!(graph.node_count(), 0);
        assert_eq!(graph.edge_count(), 0);
    }

    #[test]
    fn test_node_operations() {
        let mut graph = Graph::new();

        // Add a node
        let node = Node::new("Root Node");
        let node_id = node.id;
        assert!(graph.add_node(node).is_ok());
        assert_eq!(graph.node_count(), 1);
        assert!(graph.contains_node(node_id));

        // Get the node
        let retrieved = graph.get_node(node_id);
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().text, "Root Node");

        // Remove the node
        let removed = graph.remove_node(node_id);
        assert!(removed.is_ok());
        assert_eq!(graph.node_count(), 0);
        assert!(!graph.contains_node(node_id));
    }

    #[test]
    fn test_edge_operations() {
        let mut graph = Graph::new();

        // Add two nodes
        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node1_id = node1.id;
        let node2_id = node2.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();

        // Add an edge
        let edge = Edge::new(node1_id, node2_id);
        let edge_id = edge.id;
        assert!(graph.add_edge(edge).is_ok());
        assert_eq!(graph.edge_count(), 1);
        assert!(graph.contains_edge(edge_id));

        // Get the edge
        let retrieved = graph.get_edge(edge_id);
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().from_node, node1_id);
        assert_eq!(retrieved.unwrap().to_node, node2_id);

        // Remove the edge
        let removed = graph.remove_edge(edge_id);
        assert!(removed.is_ok());
        assert_eq!(graph.edge_count(), 0);
        assert!(!graph.contains_edge(edge_id));
    }

    #[test]
    fn test_parent_child_relationships() {
        let mut graph = Graph::new();

        let parent = Node::new("Parent");
        let parent_id = parent.id;
        graph.add_node(parent).unwrap();

        let child = Node::new_child(parent_id, "Child");
        let child_id = child.id;
        graph.add_node(child).unwrap();

        // Test parent-child relationships
        let children = graph.get_children(parent_id);
        assert_eq!(children.len(), 1);
        assert_eq!(children[0].id, child_id);

        let parent_node = graph.get_parent(child_id);
        assert!(parent_node.is_some());
        assert_eq!(parent_node.unwrap().id, parent_id);

        // Test root nodes
        let roots = graph.get_root_nodes();
        assert_eq!(roots.len(), 1);
        assert_eq!(roots[0].id, parent_id);
    }

    #[test]
    fn test_edge_indices() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node1_id = node1.id;
        let node2_id = node2.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();

        let edge = Edge::new(node1_id, node2_id);
        graph.add_edge(edge).unwrap();

        // Test outgoing edges
        let outgoing = graph.get_outgoing_edges(node1_id);
        assert_eq!(outgoing.len(), 1);
        assert_eq!(outgoing[0].to_node, node2_id);

        // Test incoming edges
        let incoming = graph.get_incoming_edges(node2_id);
        assert_eq!(incoming.len(), 1);
        assert_eq!(incoming[0].from_node, node1_id);

        // Test neighbors
        let neighbors1 = graph.get_neighbors(node1_id);
        assert_eq!(neighbors1.len(), 1);
        assert!(neighbors1.contains(&node2_id));

        let neighbors2 = graph.get_neighbors(node2_id);
        assert_eq!(neighbors2.len(), 1);
        assert!(neighbors2.contains(&node1_id));
    }

    #[test]
    fn test_path_finding() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node3 = Node::new("Node 3");
        let node1_id = node1.id;
        let node2_id = node2.id;
        let node3_id = node3.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_node(node3).unwrap();

        // Connect 1 -> 2 -> 3
        graph.add_edge(Edge::new(node1_id, node2_id)).unwrap();
        graph.add_edge(Edge::new(node2_id, node3_id)).unwrap();

        // Test path existence
        assert!(graph.has_path(node1_id, node3_id));
        assert!(graph.has_path(node3_id, node1_id)); // Undirected path
        assert!(graph.has_path(node1_id, node1_id)); // Self path
    }

    #[test]
    fn test_validation() {
        let mut graph = Graph::new();

        let node = Node::new("Valid Node");
        graph.add_node(node).unwrap();

        // Valid graph should pass validation
        assert!(graph.validate().is_ok());

        // Test invalid parent reference
        let invalid_node = Node::new_child(NodeId::new(), "Invalid Child");
        assert!(graph.add_node(invalid_node).is_err());
    }

    #[test]
    fn test_clear() {
        let mut graph = Graph::new();

        let node = Node::new("Test Node");
        graph.add_node(node).unwrap();

        assert!(!graph.is_empty());
        graph.clear();
        assert!(graph.is_empty());
    }
}