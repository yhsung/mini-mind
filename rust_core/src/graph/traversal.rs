//! Graph traversal utilities and algorithms
//!
//! This module provides various graph traversal methods including
//! depth-first search, breadth-first search, and path finding.

use crate::graph::Graph;
use crate::types::ids::NodeId;
use std::collections::{HashMap, HashSet, VecDeque};

/// Result of a traversal operation
#[derive(Debug, Clone, PartialEq)]
pub struct TraversalResult {
    /// Nodes visited in order
    pub visited: Vec<NodeId>,
    /// Depth of each node from the starting point
    pub depths: HashMap<NodeId, usize>,
    /// Parent of each node in the traversal tree
    pub parents: HashMap<NodeId, NodeId>,
}

/// Traversal order options
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TraversalOrder {
    /// Depth-first search
    DepthFirst,
    /// Breadth-first search
    BreadthFirst,
}

impl Graph {
    /// Perform a traversal starting from a given node
    pub fn traverse(&self, start: NodeId, order: TraversalOrder) -> Option<TraversalResult> {
        if !self.contains_node(start) {
            return None;
        }

        match order {
            TraversalOrder::DepthFirst => Some(self.depth_first_search(start)),
            TraversalOrder::BreadthFirst => Some(self.breadth_first_search(start)),
        }
    }

    /// Perform depth-first search starting from a node
    pub fn depth_first_search(&self, start: NodeId) -> TraversalResult {
        let mut visited = Vec::new();
        let mut visited_set = HashSet::new();
        let mut depths = HashMap::new();
        let mut parents = HashMap::new();
        let mut stack = vec![(start, 0, None)];

        while let Some((node_id, depth, parent)) = stack.pop() {
            if visited_set.contains(&node_id) {
                continue;
            }

            visited.push(node_id);
            visited_set.insert(node_id);
            depths.insert(node_id, depth);

            if let Some(parent_id) = parent {
                parents.insert(node_id, parent_id);
            }

            // Add neighbors to stack (reverse order for consistent left-to-right traversal)
            let mut neighbors: Vec<_> = self.get_neighbors(node_id);
            neighbors.reverse();
            for neighbor in neighbors {
                if !visited_set.contains(&neighbor) {
                    stack.push((neighbor, depth + 1, Some(node_id)));
                }
            }
        }

        TraversalResult {
            visited,
            depths,
            parents,
        }
    }

    /// Perform breadth-first search starting from a node
    pub fn breadth_first_search(&self, start: NodeId) -> TraversalResult {
        let mut visited = Vec::new();
        let mut visited_set = HashSet::new();
        let mut depths = HashMap::new();
        let mut parents = HashMap::new();
        let mut queue = VecDeque::new();

        queue.push_back((start, 0, None));

        while let Some((node_id, depth, parent)) = queue.pop_front() {
            if visited_set.contains(&node_id) {
                continue;
            }

            visited.push(node_id);
            visited_set.insert(node_id);
            depths.insert(node_id, depth);

            if let Some(parent_id) = parent {
                parents.insert(node_id, parent_id);
            }

            // Add neighbors to queue
            for neighbor in self.get_neighbors(node_id) {
                if !visited_set.contains(&neighbor) {
                    queue.push_back((neighbor, depth + 1, Some(node_id)));
                }
            }
        }

        TraversalResult {
            visited,
            depths,
            parents,
        }
    }

    /// Find a path between two nodes using BFS
    pub fn find_path(&self, from: NodeId, to: NodeId) -> Option<Vec<NodeId>> {
        if from == to {
            return Some(vec![from]);
        }

        if !self.contains_node(from) || !self.contains_node(to) {
            return None;
        }

        let mut visited = HashSet::new();
        let mut parents = HashMap::new();
        let mut queue = VecDeque::new();

        queue.push_back(from);
        visited.insert(from);

        while let Some(current) = queue.pop_front() {
            for neighbor in self.get_neighbors(current) {
                if !visited.contains(&neighbor) {
                    visited.insert(neighbor);
                    parents.insert(neighbor, current);
                    queue.push_back(neighbor);

                    if neighbor == to {
                        // Reconstruct path
                        let mut path = Vec::new();
                        let mut node = to;

                        while let Some(&parent) = parents.get(&node) {
                            path.push(node);
                            node = parent;
                        }
                        path.push(from);
                        path.reverse();

                        return Some(path);
                    }
                }
            }
        }

        None
    }

    /// Find the shortest path between two nodes
    pub fn shortest_path(&self, from: NodeId, to: NodeId) -> Option<Vec<NodeId>> {
        // For unweighted graphs, BFS gives the shortest path
        self.find_path(from, to)
    }

    /// Get all ancestors of a node (following parent relationships)
    pub fn get_ancestors(&self, node_id: NodeId) -> Vec<NodeId> {
        let mut ancestors = Vec::new();
        let mut current = node_id;

        while let Some(parent) = self.get_parent(current) {
            ancestors.push(parent.id);
            current = parent.id;
        }

        ancestors
    }

    /// Get all descendants of a node (following child relationships)
    pub fn get_descendants(&self, node_id: NodeId) -> Vec<NodeId> {
        let mut descendants = Vec::new();
        let mut stack = vec![node_id];
        let mut visited = HashSet::new();

        while let Some(current) = stack.pop() {
            if visited.contains(&current) {
                continue;
            }
            visited.insert(current);

            for child in self.get_children(current) {
                descendants.push(child.id);
                stack.push(child.id);
            }
        }

        descendants
    }

    /// Check if one node is an ancestor of another
    pub fn is_ancestor(&self, ancestor_id: NodeId, descendant_id: NodeId) -> bool {
        let ancestors = self.get_ancestors(descendant_id);
        ancestors.contains(&ancestor_id)
    }

    /// Check if one node is a descendant of another
    pub fn is_descendant(&self, descendant_id: NodeId, ancestor_id: NodeId) -> bool {
        self.is_ancestor(ancestor_id, descendant_id)
    }

    /// Get the lowest common ancestor of two nodes
    pub fn lowest_common_ancestor(&self, node1: NodeId, node2: NodeId) -> Option<NodeId> {
        if node1 == node2 {
            return Some(node1);
        }

        let ancestors1: HashSet<_> = self.get_ancestors(node1).into_iter().collect();
        let ancestors2 = self.get_ancestors(node2);

        // Also include the nodes themselves as potential ancestors
        let mut extended_ancestors1 = ancestors1.clone();
        extended_ancestors1.insert(node1);

        // Find the first common ancestor in node2's ancestor chain (from immediate parent to root)
        // Check node2 itself first
        if extended_ancestors1.contains(&node2) {
            return Some(node2);
        }

        // Then check ancestors of node2
        for ancestor in ancestors2 {
            if extended_ancestors1.contains(&ancestor) {
                return Some(ancestor);
            }
        }

        None
    }

    /// Get the depth of a node in the tree (distance from root)
    pub fn get_node_depth(&self, node_id: NodeId) -> Option<usize> {
        if !self.contains_node(node_id) {
            return None;
        }

        Some(self.get_ancestors(node_id).len())
    }

    /// Get all nodes at a specific depth level
    pub fn get_nodes_at_depth(&self, depth: usize) -> Vec<NodeId> {
        self.nodes()
            .filter_map(|node| {
                let node_depth = self.get_node_depth(node.id)?;
                if node_depth == depth {
                    Some(node.id)
                } else {
                    None
                }
            })
            .collect()
    }

    /// Get the maximum depth in the graph
    pub fn max_depth(&self) -> usize {
        self.nodes()
            .filter_map(|node| self.get_node_depth(node.id))
            .max()
            .unwrap_or(0)
    }

    /// Check if the graph contains cycles (ignoring parent-child relationships)
    pub fn has_cycles(&self) -> bool {
        let mut visited = HashSet::new();
        let mut recursion_stack = HashSet::new();

        for node in self.nodes() {
            if !visited.contains(&node.id) {
                if self.has_cycle_dfs(node.id, &mut visited, &mut recursion_stack) {
                    return true;
                }
            }
        }

        false
    }

    /// Helper function for cycle detection using DFS
    fn has_cycle_dfs(
        &self,
        node_id: NodeId,
        visited: &mut HashSet<NodeId>,
        recursion_stack: &mut HashSet<NodeId>,
    ) -> bool {
        visited.insert(node_id);
        recursion_stack.insert(node_id);

        for edge in self.get_outgoing_edges(node_id) {
            let neighbor = edge.to_node;

            if !visited.contains(&neighbor) {
                if self.has_cycle_dfs(neighbor, visited, recursion_stack) {
                    return true;
                }
            } else if recursion_stack.contains(&neighbor) {
                return true;
            }
        }

        recursion_stack.remove(&node_id);
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Node, Edge};

    fn create_test_graph() -> (Graph, NodeId, NodeId, NodeId, NodeId) {
        let mut graph = Graph::new();

        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node3 = Node::new("Node 3");
        let node4 = Node::new("Node 4");

        let id1 = node1.id;
        let id2 = node2.id;
        let id3 = node3.id;
        let id4 = node4.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_node(node3).unwrap();
        graph.add_node(node4).unwrap();

        // Create connections: 1 -> 2 -> 3, 1 -> 4
        graph.add_edge(Edge::new(id1, id2)).unwrap();
        graph.add_edge(Edge::new(id2, id3)).unwrap();
        graph.add_edge(Edge::new(id1, id4)).unwrap();

        (graph, id1, id2, id3, id4)
    }

    #[test]
    fn test_depth_first_search() {
        let (graph, id1, _id2, _id3, _id4) = create_test_graph();

        let result = graph.depth_first_search(id1);
        assert_eq!(result.visited.len(), 4);
        assert_eq!(result.visited[0], id1);
        assert_eq!(result.depths[&id1], 0);
    }

    #[test]
    fn test_breadth_first_search() {
        let (graph, id1, id2, _id3, id4) = create_test_graph();

        let result = graph.breadth_first_search(id1);
        assert_eq!(result.visited.len(), 4);
        assert_eq!(result.visited[0], id1);
        assert_eq!(result.depths[&id1], 0);
        assert_eq!(result.depths[&id2], 1);
        assert_eq!(result.depths[&id4], 1);
    }

    #[test]
    fn test_traverse() {
        let (graph, id1, _id2, _id3, _id4) = create_test_graph();

        let dfs_result = graph.traverse(id1, TraversalOrder::DepthFirst);
        assert!(dfs_result.is_some());
        assert_eq!(dfs_result.unwrap().visited.len(), 4);

        let bfs_result = graph.traverse(id1, TraversalOrder::BreadthFirst);
        assert!(bfs_result.is_some());
        assert_eq!(bfs_result.unwrap().visited.len(), 4);

        // Test invalid start node
        let invalid_result = graph.traverse(NodeId::new(), TraversalOrder::DepthFirst);
        assert!(invalid_result.is_none());
    }

    #[test]
    fn test_find_path() {
        let (graph, id1, _id2, id3, id4) = create_test_graph();

        // Path from 1 to 3
        let path = graph.find_path(id1, id3);
        assert!(path.is_some());
        let path = path.unwrap();
        assert_eq!(path[0], id1);
        assert_eq!(path[path.len() - 1], id3);

        // Path from 1 to 4
        let path = graph.find_path(id1, id4);
        assert!(path.is_some());
        let path = path.unwrap();
        assert_eq!(path.len(), 2);
        assert_eq!(path[0], id1);
        assert_eq!(path[1], id4);

        // Path to same node
        let path = graph.find_path(id1, id1);
        assert_eq!(path, Some(vec![id1]));

        // Path to non-existent node
        let path = graph.find_path(id1, NodeId::new());
        assert!(path.is_none());
    }

    #[test]
    fn test_ancestor_descendant_relationships() {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let child = Node::new_child(root.id, "Child");
        let grandchild = Node::new_child(child.id, "Grandchild");

        let root_id = root.id;
        let child_id = child.id;
        let grandchild_id = grandchild.id;

        graph.add_node(root).unwrap();
        graph.add_node(child).unwrap();
        graph.add_node(grandchild).unwrap();

        // Test ancestors
        let ancestors = graph.get_ancestors(grandchild_id);
        assert_eq!(ancestors.len(), 2);
        assert!(ancestors.contains(&child_id));
        assert!(ancestors.contains(&root_id));

        // Test descendants
        let descendants = graph.get_descendants(root_id);
        assert_eq!(descendants.len(), 2);
        assert!(descendants.contains(&child_id));
        assert!(descendants.contains(&grandchild_id));

        // Test relationships
        assert!(graph.is_ancestor(root_id, grandchild_id));
        assert!(graph.is_descendant(grandchild_id, root_id));
        assert!(!graph.is_ancestor(grandchild_id, root_id));
    }

    #[test]
    fn test_node_depth() {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let child = Node::new_child(root.id, "Child");
        let grandchild = Node::new_child(child.id, "Grandchild");

        let root_id = root.id;
        let child_id = child.id;
        let grandchild_id = grandchild.id;

        graph.add_node(root).unwrap();
        graph.add_node(child).unwrap();
        graph.add_node(grandchild).unwrap();

        assert_eq!(graph.get_node_depth(root_id), Some(0));
        assert_eq!(graph.get_node_depth(child_id), Some(1));
        assert_eq!(graph.get_node_depth(grandchild_id), Some(2));
        assert_eq!(graph.max_depth(), 2);

        let depth_0_nodes = graph.get_nodes_at_depth(0);
        assert_eq!(depth_0_nodes.len(), 1);
        assert!(depth_0_nodes.contains(&root_id));
    }

    #[test]
    fn test_lowest_common_ancestor() {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let child1 = Node::new_child(root.id, "Child1");
        let child2 = Node::new_child(root.id, "Child2");
        let grandchild1 = Node::new_child(child1.id, "Grandchild1");
        let grandchild2 = Node::new_child(child2.id, "Grandchild2");

        let root_id = root.id;
        let child1_id = child1.id;
        let _child2_id = child2.id;
        let grandchild1_id = grandchild1.id;
        let grandchild2_id = grandchild2.id;

        graph.add_node(root).unwrap();
        graph.add_node(child1).unwrap();
        graph.add_node(child2).unwrap();
        graph.add_node(grandchild1).unwrap();
        graph.add_node(grandchild2).unwrap();

        // LCA of grandchildren should be root
        let lca = graph.lowest_common_ancestor(grandchild1_id, grandchild2_id);
        assert_eq!(lca, Some(root_id));

        // LCA of child and grandchild in same branch should be child
        let lca = graph.lowest_common_ancestor(child1_id, grandchild1_id);
        assert_eq!(lca, Some(child1_id));
    }

    #[test]
    fn test_cycle_detection() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node3 = Node::new("Node 3");

        let id1 = node1.id;
        let id2 = node2.id;
        let id3 = node3.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_node(node3).unwrap();

        // No cycles initially
        assert!(!graph.has_cycles());

        // Add edges: 1 -> 2 -> 3
        graph.add_edge(Edge::new(id1, id2)).unwrap();
        graph.add_edge(Edge::new(id2, id3)).unwrap();
        assert!(!graph.has_cycles());

        // Add cycle: 3 -> 1
        graph.add_edge(Edge::new(id3, id1)).unwrap();
        assert!(graph.has_cycles());
    }
}