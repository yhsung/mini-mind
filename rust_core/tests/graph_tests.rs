//! Comprehensive unit tests for graph operations
//!
//! This module provides comprehensive testing for the core graph functionality
//! including node and edge operations, traversal algorithms, validation,
//! and property-based tests for graph invariants.

use mindmap_core::graph::{Graph, TraversalOrder};
use mindmap_core::models::{Node, Edge};
use mindmap_core::types::{
    ids::{NodeId, EdgeId},
    MindmapError, Point
};

use proptest::prelude::*;
use std::collections::HashSet;

#[cfg(test)]
mod unit_tests {
    use super::*;

    // Node Operation Tests

    #[test]
    fn test_graph_creation_and_basic_properties() {
        let graph = Graph::new();

        assert!(graph.is_empty());
        assert_eq!(graph.node_count(), 0);
        assert_eq!(graph.edge_count(), 0);
        assert!(graph.validate().is_ok());
    }

    #[test]
    fn test_single_node_operations() {
        let mut graph = Graph::new();

        // Create and add a node
        let node = Node::new("Test Node");
        let node_id = node.id;
        let node_text = node.text.clone();

        // Test node addition
        let result = graph.add_node(node);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), node_id);
        assert_eq!(graph.node_count(), 1);
        assert!(!graph.is_empty());
        assert!(graph.contains_node(node_id));

        // Test node retrieval
        let retrieved = graph.get_node(node_id);
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().text, node_text);
        assert_eq!(retrieved.unwrap().id, node_id);

        // Test node update
        let mut updated_node = retrieved.unwrap().clone();
        updated_node.text = "Updated Node".to_string();
        let update_result = graph.update_node(updated_node);
        assert!(update_result.is_ok());

        let updated_retrieved = graph.get_node(node_id);
        assert!(updated_retrieved.is_some());
        assert_eq!(updated_retrieved.unwrap().text, "Updated Node");

        // Test node removal
        let removal_result = graph.remove_node(node_id);
        assert!(removal_result.is_ok());
        assert_eq!(removal_result.unwrap().text, "Updated Node");
        assert_eq!(graph.node_count(), 0);
        assert!(graph.is_empty());
        assert!(!graph.contains_node(node_id));
    }

    #[test]
    fn test_multiple_node_operations() {
        let mut graph = Graph::new();
        let mut node_ids = Vec::new();

        // Add multiple nodes
        for i in 0..5 {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);

            assert!(graph.add_node(node).is_ok());
        }

        assert_eq!(graph.node_count(), 5);

        // Verify all nodes exist
        for (i, &node_id) in node_ids.iter().enumerate() {
            assert!(graph.contains_node(node_id));
            let node = graph.get_node(node_id).unwrap();
            assert_eq!(node.text, format!("Node {}", i));
        }

        // Remove nodes in reverse order
        for &node_id in node_ids.iter().rev() {
            assert!(graph.remove_node(node_id).is_ok());
        }

        assert!(graph.is_empty());
    }

    #[test]
    fn test_parent_child_relationships() {
        let mut graph = Graph::new();

        // Create parent node
        let parent = Node::new("Parent");
        let parent_id = parent.id;
        assert!(graph.add_node(parent).is_ok());

        // Create children
        let mut child_ids = Vec::new();
        for i in 0..3 {
            let child = Node::new_child(parent_id, &format!("Child {}", i));
            let child_id = child.id;
            child_ids.push(child_id);
            assert!(graph.add_node(child).is_ok());
        }

        // Test parent-child relationships
        let children = graph.get_children(parent_id);
        assert_eq!(children.len(), 3);

        for child in &children {
            assert!(child_ids.contains(&child.id));
            assert_eq!(child.parent_id, Some(parent_id));
        }

        // Test getting parent
        for &child_id in &child_ids {
            let parent_node = graph.get_parent(child_id);
            assert!(parent_node.is_some());
            assert_eq!(parent_node.unwrap().id, parent_id);
        }

        // Test root nodes
        let roots = graph.get_root_nodes();
        assert_eq!(roots.len(), 1);
        assert_eq!(roots[0].id, parent_id);
    }

    #[test]
    fn test_invalid_parent_reference() {
        let mut graph = Graph::new();

        // Try to add a node with non-existent parent
        let invalid_parent_id = NodeId::new();
        let child = Node::new_child(invalid_parent_id, "Orphan Child");

        let result = graph.add_node(child);
        assert!(result.is_err());

        match result.unwrap_err() {
            MindmapError::NodeNotFound { id } => assert_eq!(id, invalid_parent_id),
            _ => panic!("Expected NodeNotFound error"),
        }
    }

    // Edge Operation Tests

    #[test]
    fn test_single_edge_operations() {
        let mut graph = Graph::new();

        // Create two nodes
        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node1_id = node1.id;
        let node2_id = node2.id;

        assert!(graph.add_node(node1).is_ok());
        assert!(graph.add_node(node2).is_ok());

        // Create and add edge
        let edge = Edge::new(node1_id, node2_id);
        let edge_id = edge.id;

        let result = graph.add_edge(edge);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), edge_id);
        assert_eq!(graph.edge_count(), 1);
        assert!(graph.contains_edge(edge_id));

        // Test edge retrieval
        let retrieved = graph.get_edge(edge_id);
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().from_node, node1_id);
        assert_eq!(retrieved.unwrap().to_node, node2_id);

        // Test edge removal
        let removal_result = graph.remove_edge(edge_id);
        assert!(removal_result.is_ok());
        let removed_edge = removal_result.unwrap();
        assert_eq!(removed_edge.from_node, node1_id);
        assert_eq!(removed_edge.to_node, node2_id);
        assert_eq!(graph.edge_count(), 0);
        assert!(!graph.contains_edge(edge_id));
    }

    #[test]
    fn test_edge_indices() {
        let mut graph = Graph::new();

        // Create three nodes
        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node3 = Node::new("Node 3");
        let node1_id = node1.id;
        let node2_id = node2.id;
        let node3_id = node3.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_node(node3).unwrap();

        // Create edges: 1->2, 1->3, 2->3
        let edge1 = Edge::new(node1_id, node2_id);
        let edge2 = Edge::new(node1_id, node3_id);
        let edge3 = Edge::new(node2_id, node3_id);

        graph.add_edge(edge1).unwrap();
        graph.add_edge(edge2).unwrap();
        graph.add_edge(edge3).unwrap();

        // Test outgoing edges from node1
        let outgoing1 = graph.get_outgoing_edges(node1_id);
        assert_eq!(outgoing1.len(), 2);
        let outgoing_targets: HashSet<NodeId> = outgoing1.iter().map(|e| e.to_node).collect();
        assert!(outgoing_targets.contains(&node2_id));
        assert!(outgoing_targets.contains(&node3_id));

        // Test incoming edges to node3
        let incoming3 = graph.get_incoming_edges(node3_id);
        assert_eq!(incoming3.len(), 2);
        let incoming_sources: HashSet<NodeId> = incoming3.iter().map(|e| e.from_node).collect();
        assert!(incoming_sources.contains(&node1_id));
        assert!(incoming_sources.contains(&node2_id));

        // Test neighbors
        let neighbors1 = graph.get_neighbors(node1_id);
        assert_eq!(neighbors1.len(), 2);
        assert!(neighbors1.contains(&node2_id));
        assert!(neighbors1.contains(&node3_id));

        let neighbors2 = graph.get_neighbors(node2_id);
        assert_eq!(neighbors2.len(), 2);
        assert!(neighbors2.contains(&node1_id));
        assert!(neighbors2.contains(&node3_id));
    }

    #[test]
    fn test_edge_with_nonexistent_nodes() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node 1");
        let node1_id = node1.id;
        let nonexistent_id = NodeId::new();

        graph.add_node(node1).unwrap();

        // Try to create edge with non-existent target
        let edge = Edge::new(node1_id, nonexistent_id);
        let result = graph.add_edge(edge);
        assert!(result.is_err());

        match result.unwrap_err() {
            MindmapError::NodeNotFound { id } => assert_eq!(id, nonexistent_id),
            _ => panic!("Expected NodeNotFound error"),
        }
    }

    // Node Removal with Edge Cleanup Tests

    #[test]
    fn test_node_removal_cleans_up_edges() {
        let mut graph = Graph::new();

        // Create nodes
        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node3 = Node::new("Node 3");
        let node1_id = node1.id;
        let node2_id = node2.id;
        let node3_id = node3.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_node(node3).unwrap();

        // Create edges
        let edge1 = Edge::new(node1_id, node2_id);
        let edge2 = Edge::new(node2_id, node3_id);
        let edge3 = Edge::new(node1_id, node3_id);
        let edge1_id = edge1.id;
        let edge2_id = edge2.id;
        let edge3_id = edge3.id;

        graph.add_edge(edge1).unwrap();
        graph.add_edge(edge2).unwrap();
        graph.add_edge(edge3).unwrap();

        assert_eq!(graph.edge_count(), 3);

        // Remove node2 - should remove edges connected to it
        assert!(graph.remove_node(node2_id).is_ok());

        // Check that edges involving node2 are removed
        assert!(!graph.contains_edge(edge1_id));
        assert!(!graph.contains_edge(edge2_id));
        assert!(graph.contains_edge(edge3_id)); // This one should remain

        assert_eq!(graph.edge_count(), 1);
        assert_eq!(graph.node_count(), 2);

        // Verify remaining edge is correct
        let remaining_edge = graph.get_edge(edge3_id).unwrap();
        assert_eq!(remaining_edge.from_node, node1_id);
        assert_eq!(remaining_edge.to_node, node3_id);
    }

    // Path Finding Tests

    #[test]
    fn test_path_finding_simple() {
        let mut graph = Graph::new();

        // Create a simple path: A -> B -> C
        let node_a = Node::new("A");
        let node_b = Node::new("B");
        let node_c = Node::new("C");
        let id_a = node_a.id;
        let id_b = node_b.id;
        let id_c = node_c.id;

        graph.add_node(node_a).unwrap();
        graph.add_node(node_b).unwrap();
        graph.add_node(node_c).unwrap();

        graph.add_edge(Edge::new(id_a, id_b)).unwrap();
        graph.add_edge(Edge::new(id_b, id_c)).unwrap();

        // Test path existence (undirected)
        assert!(graph.has_path(id_a, id_c));
        assert!(graph.has_path(id_c, id_a));
        assert!(graph.has_path(id_a, id_b));
        assert!(graph.has_path(id_b, id_a));

        // Test self paths
        assert!(graph.has_path(id_a, id_a));
        assert!(graph.has_path(id_b, id_b));
        assert!(graph.has_path(id_c, id_c));
    }

    #[test]
    fn test_path_finding_disconnected() {
        let mut graph = Graph::new();

        // Create two disconnected components
        let node_a = Node::new("A");
        let node_b = Node::new("B");
        let node_c = Node::new("C");
        let node_d = Node::new("D");
        let id_a = node_a.id;
        let id_b = node_b.id;
        let id_c = node_c.id;
        let id_d = node_d.id;

        graph.add_node(node_a).unwrap();
        graph.add_node(node_b).unwrap();
        graph.add_node(node_c).unwrap();
        graph.add_node(node_d).unwrap();

        // Connect A-B and C-D
        graph.add_edge(Edge::new(id_a, id_b)).unwrap();
        graph.add_edge(Edge::new(id_c, id_d)).unwrap();

        // Test connections within components
        assert!(graph.has_path(id_a, id_b));
        assert!(graph.has_path(id_c, id_d));

        // Test no connection between components
        assert!(!graph.has_path(id_a, id_c));
        assert!(!graph.has_path(id_a, id_d));
        assert!(!graph.has_path(id_b, id_c));
        assert!(!graph.has_path(id_b, id_d));
    }

    // Graph Validation Tests

    #[test]
    fn test_graph_validation_valid() {
        let mut graph = Graph::new();

        // Create a valid graph structure
        let parent = Node::new("Parent");
        let parent_id = parent.id;
        graph.add_node(parent).unwrap();

        let child1 = Node::new_child(parent_id, "Child 1");
        let child2 = Node::new_child(parent_id, "Child 2");
        let child1_id = child1.id;
        let child2_id = child2.id;

        graph.add_node(child1).unwrap();
        graph.add_node(child2).unwrap();

        // Add edges
        graph.add_edge(Edge::new(parent_id, child1_id)).unwrap();
        graph.add_edge(Edge::new(parent_id, child2_id)).unwrap();
        graph.add_edge(Edge::new(child1_id, child2_id)).unwrap();

        // Validation should pass
        assert!(graph.validate().is_ok());
    }

    #[test]
    fn test_clear_and_empty_operations() {
        let mut graph = Graph::new();

        // Add some data
        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node1_id = node1.id;
        let node2_id = node2.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_edge(Edge::new(node1_id, node2_id)).unwrap();

        assert!(!graph.is_empty());
        assert_eq!(graph.node_count(), 2);
        assert_eq!(graph.edge_count(), 1);

        // Clear the graph
        graph.clear();

        assert!(graph.is_empty());
        assert_eq!(graph.node_count(), 0);
        assert_eq!(graph.edge_count(), 0);
        assert!(graph.validate().is_ok());
    }

    // Error Handling Tests

    #[test]
    fn test_operations_on_nonexistent_nodes() {
        let mut graph = Graph::new();
        let nonexistent_id = NodeId::new();

        // Test getting non-existent node
        assert!(graph.get_node(nonexistent_id).is_none());

        // Test removing non-existent node
        let result = graph.remove_node(nonexistent_id);
        assert!(result.is_err());
        match result.unwrap_err() {
            MindmapError::NodeNotFound { id } => assert_eq!(id, nonexistent_id),
            _ => panic!("Expected NodeNotFound error"),
        }

        // Test updating non-existent node
        let node = Node::new("Test");
        let result = graph.update_node(node);
        assert!(result.is_err());
    }

    #[test]
    fn test_operations_on_nonexistent_edges() {
        let mut graph = Graph::new();
        let nonexistent_id = EdgeId::new();

        // Test getting non-existent edge
        assert!(graph.get_edge(nonexistent_id).is_none());

        // Test removing non-existent edge
        let result = graph.remove_edge(nonexistent_id);
        assert!(result.is_err());
        match result.unwrap_err() {
            MindmapError::EdgeNotFound { id } => assert_eq!(id, nonexistent_id),
            _ => panic!("Expected EdgeNotFound error"),
        }
    }

    // Performance and Stress Tests

    #[test]
    fn test_large_graph_operations() {
        let mut graph = Graph::new();
        let node_count = 1000;
        let mut node_ids = Vec::new();

        // Add many nodes
        for i in 0..node_count {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);
            assert!(graph.add_node(node).is_ok());
        }

        assert_eq!(graph.node_count(), node_count);

        // Add edges to create a connected graph
        for i in 1..node_count {
            let edge = Edge::new(node_ids[i - 1], node_ids[i]);
            assert!(graph.add_edge(edge).is_ok());
        }

        assert_eq!(graph.edge_count(), node_count - 1);

        // Test path finding on large graph
        assert!(graph.has_path(node_ids[0], node_ids[node_count - 1]));

        // Validate the entire graph
        assert!(graph.validate().is_ok());
    }

    #[test]
    fn test_complex_hierarchy() {
        let mut graph = Graph::new();

        // Create a complex tree structure
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        let mut level1_ids = Vec::new();
        for i in 0..3 {
            let node = Node::new_child(root_id, &format!("Level1-{}", i));
            let node_id = node.id;
            level1_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        let mut level2_ids = Vec::new();
        for (i, &parent_id) in level1_ids.iter().enumerate() {
            for j in 0..2 {
                let node = Node::new_child(parent_id, &format!("Level2-{}-{}", i, j));
                let node_id = node.id;
                level2_ids.push(node_id);
                graph.add_node(node).unwrap();
            }
        }

        // Verify structure
        assert_eq!(graph.node_count(), 1 + 3 + 6); // root + level1 + level2

        // Test root identification
        let roots = graph.get_root_nodes();
        assert_eq!(roots.len(), 1);
        assert_eq!(roots[0].id, root_id);

        // Test children count at each level
        let root_children = graph.get_children(root_id);
        assert_eq!(root_children.len(), 3);

        for &level1_id in &level1_ids {
            let children = graph.get_children(level1_id);
            assert_eq!(children.len(), 2);
        }

        // Test parent relationships
        for &level1_id in &level1_ids {
            let parent = graph.get_parent(level1_id);
            assert!(parent.is_some());
            assert_eq!(parent.unwrap().id, root_id);
        }

        for &level2_id in &level2_ids {
            let parent = graph.get_parent(level2_id);
            assert!(parent.is_some());
            assert!(level1_ids.contains(&parent.unwrap().id));
        }
    }
}

#[cfg(test)]
mod traversal_tests {
    use super::*;

    fn create_test_tree() -> (Graph, Vec<NodeId>) {
        let mut graph = Graph::new();
        let mut node_ids = Vec::new();

        // Create tree structure:
        //       0
        //     /   \
        //    1     2
        //   / \   /
        //  3   4 5

        for i in 0..6 {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Add parent-child relationships and edges
        let mut update_node_with_parent = |child_idx: usize, parent_idx: usize| {
            let mut child = graph.get_node(node_ids[child_idx]).unwrap().clone();
            child.parent_id = Some(node_ids[parent_idx]);
            graph.update_node(child).unwrap();
            graph.add_edge(Edge::new(node_ids[parent_idx], node_ids[child_idx])).unwrap();
        };

        update_node_with_parent(1, 0); // 1 -> 0
        update_node_with_parent(2, 0); // 2 -> 0
        update_node_with_parent(3, 1); // 3 -> 1
        update_node_with_parent(4, 1); // 4 -> 1
        update_node_with_parent(5, 2); // 5 -> 2

        (graph, node_ids)
    }

    #[test]
    fn test_depth_first_traversal() {
        let (graph, node_ids) = create_test_tree();

        let result = graph.traverse(node_ids[0], TraversalOrder::DepthFirst);
        assert!(result.is_some());

        let traversal = result.unwrap();

        // Should visit all nodes
        assert_eq!(traversal.visited.len(), 6);
        assert!(traversal.visited.contains(&node_ids[0]));

        // Root should be at depth 0
        assert_eq!(traversal.depths[&node_ids[0]], 0);

        // Level 1 nodes should be at depth 1
        assert_eq!(traversal.depths[&node_ids[1]], 1);
        assert_eq!(traversal.depths[&node_ids[2]], 1);

        // Level 2 nodes should be at depth 2
        assert_eq!(traversal.depths[&node_ids[3]], 2);
        assert_eq!(traversal.depths[&node_ids[4]], 2);
        assert_eq!(traversal.depths[&node_ids[5]], 2);
    }

    #[test]
    fn test_breadth_first_traversal() {
        let (graph, node_ids) = create_test_tree();

        let result = graph.traverse(node_ids[0], TraversalOrder::BreadthFirst);
        assert!(result.is_some());

        let traversal = result.unwrap();

        // Should visit all nodes
        assert_eq!(traversal.visited.len(), 6);

        // Should visit nodes in breadth-first order
        // Root first
        assert_eq!(traversal.visited[0], node_ids[0]);

        // Then level 1 nodes (order may vary)
        let level1_positions: Vec<usize> = traversal.visited.iter()
            .enumerate()
            .filter_map(|(i, &id)| {
                if id == node_ids[1] || id == node_ids[2] { Some(i) } else { None }
            })
            .collect();
        assert_eq!(level1_positions.len(), 2);
        assert!(level1_positions[0] < level1_positions[1]);
        assert!(level1_positions[1] <= 2); // Should be visited by position 2

        // Verify depths
        assert_eq!(traversal.depths[&node_ids[0]], 0);
        assert_eq!(traversal.depths[&node_ids[1]], 1);
        assert_eq!(traversal.depths[&node_ids[2]], 1);
        assert_eq!(traversal.depths[&node_ids[3]], 2);
        assert_eq!(traversal.depths[&node_ids[4]], 2);
        assert_eq!(traversal.depths[&node_ids[5]], 2);
    }

    #[test]
    fn test_traversal_from_nonexistent_node() {
        let graph = Graph::new();
        let nonexistent_id = NodeId::new();

        let result = graph.traverse(nonexistent_id, TraversalOrder::DepthFirst);
        assert!(result.is_none());

        let result = graph.traverse(nonexistent_id, TraversalOrder::BreadthFirst);
        assert!(result.is_none());
    }

    #[test]
    fn test_traversal_single_node() {
        let mut graph = Graph::new();
        let node = Node::new("Single Node");
        let node_id = node.id;
        graph.add_node(node).unwrap();

        let result = graph.traverse(node_id, TraversalOrder::DepthFirst);
        assert!(result.is_some());

        let traversal = result.unwrap();
        assert_eq!(traversal.visited.len(), 1);
        assert_eq!(traversal.visited[0], node_id);
        assert_eq!(traversal.depths[&node_id], 0);
        assert!(traversal.parents.is_empty());
    }

    #[test]
    fn test_traversal_disconnected_components() {
        let mut graph = Graph::new();

        // Create two disconnected nodes
        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let node1_id = node1.id;
        let node2_id = node2.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();

        // Traverse from node1 - should only visit node1
        let result = graph.traverse(node1_id, TraversalOrder::DepthFirst);
        assert!(result.is_some());

        let traversal = result.unwrap();
        assert_eq!(traversal.visited.len(), 1);
        assert_eq!(traversal.visited[0], node1_id);
        assert!(!traversal.visited.contains(&node2_id));
    }
}

#[cfg(test)]
mod property_tests {
    use super::*;
    use proptest::collection::vec;

    // Property-based test strategies

    prop_compose! {
        fn arb_node_text()(text in "[a-zA-Z0-9 ]{1,20}") -> String {
            text
        }
    }

    prop_compose! {
        fn arb_position()(x in -1000.0..1000.0, y in -1000.0..1000.0) -> Point {
            Point { x, y }
        }
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn prop_graph_node_count_consistency(
            node_texts in vec(arb_node_text(), 0..20)
        ) {
            let mut graph = Graph::new();
            let mut expected_count = 0;

            for text in node_texts {
                let node = Node::new(&text);
                if graph.add_node(node).is_ok() {
                    expected_count += 1;
                }
            }

            prop_assert_eq!(graph.node_count(), expected_count);
            prop_assert_eq!(graph.is_empty(), expected_count == 0);
        }

        #[test]
        fn prop_graph_add_remove_node_invariant(
            text in arb_node_text()
        ) {
            let mut graph = Graph::new();
            let initial_count = graph.node_count();

            let node = Node::new(&text);
            let node_id = node.id;

            // Add node
            prop_assert!(graph.add_node(node).is_ok());
            prop_assert_eq!(graph.node_count(), initial_count + 1);
            prop_assert!(graph.contains_node(node_id));

            // Remove node
            prop_assert!(graph.remove_node(node_id).is_ok());
            prop_assert_eq!(graph.node_count(), initial_count);
            prop_assert!(!graph.contains_node(node_id));
        }

        #[test]
        fn prop_graph_validation_always_succeeds_on_valid_operations(
            node_texts in vec(arb_node_text(), 1..10)
        ) {
            let mut graph = Graph::new();

            // Add nodes sequentially
            for text in node_texts {
                let node = Node::new(&text);
                if graph.add_node(node).is_ok() {
                    // Graph should always be valid after successful operations
                    prop_assert!(graph.validate().is_ok());
                }
            }
        }

        #[test]
        fn prop_edge_count_consistency_with_node_removal(
            node_count in 2..10usize
        ) {
            let mut graph = Graph::new();
            let mut node_ids = Vec::new();

            // Create nodes
            for i in 0..node_count {
                let node = Node::new(&format!("Node {}", i));
                let node_id = node.id;
                node_ids.push(node_id);
                graph.add_node(node).unwrap();
            }

            // Create edges between consecutive nodes
            let mut edge_count = 0;
            for i in 1..node_count {
                let edge = Edge::new(node_ids[i-1], node_ids[i]);
                if graph.add_edge(edge).is_ok() {
                    edge_count += 1;
                }
            }

            prop_assert_eq!(graph.edge_count(), edge_count);

            // Remove first node - should remove one edge
            if node_count > 1 {
                graph.remove_node(node_ids[0]).unwrap();
                prop_assert_eq!(graph.edge_count(), edge_count - 1);
            }
        }

        #[test]
        fn prop_parent_child_relationship_consistency(
            child_count in 1..10usize
        ) {
            let mut graph = Graph::new();

            // Create parent
            let parent = Node::new("Parent");
            let parent_id = parent.id;
            graph.add_node(parent).unwrap();

            let mut child_ids = Vec::new();

            // Create children
            for i in 0..child_count {
                let child = Node::new_child(parent_id, &format!("Child {}", i));
                let child_id = child.id;
                child_ids.push(child_id);
                graph.add_node(child).unwrap();
            }

            // Verify parent-child relationships
            let children = graph.get_children(parent_id);
            prop_assert_eq!(children.len(), child_count);

            for &child_id in &child_ids {
                let parent_node = graph.get_parent(child_id);
                prop_assert!(parent_node.is_some());
                prop_assert_eq!(parent_node.unwrap().id, parent_id);
            }

            // Verify all children are in the children list
            let child_ids_from_graph: HashSet<NodeId> = children.iter().map(|n| n.id).collect();
            let expected_child_ids: HashSet<NodeId> = child_ids.into_iter().collect();
            prop_assert_eq!(child_ids_from_graph, expected_child_ids);
        }

        #[test]
        fn prop_path_finding_reflexivity_and_symmetry(
            node_count in 2..8usize
        ) {
            let mut graph = Graph::new();
            let mut node_ids = Vec::new();

            // Create nodes
            for i in 0..node_count {
                let node = Node::new(&format!("Node {}", i));
                let node_id = node.id;
                node_ids.push(node_id);
                graph.add_node(node).unwrap();
            }

            // Create a connected graph (cycle)
            for i in 0..node_count {
                let from = node_ids[i];
                let to = node_ids[(i + 1) % node_count];
                graph.add_edge(Edge::new(from, to)).unwrap();
            }

            // Test reflexivity: every node has a path to itself
            for &node_id in &node_ids {
                prop_assert!(graph.has_path(node_id, node_id));
            }

            // Test symmetry: if A has path to B, then B has path to A (undirected)
            for &from in &node_ids {
                for &to in &node_ids {
                    if graph.has_path(from, to) {
                        prop_assert!(graph.has_path(to, from));
                    }
                }
            }

            // In a connected graph, all nodes should have paths to all other nodes
            for &from in &node_ids {
                for &to in &node_ids {
                    prop_assert!(graph.has_path(from, to));
                }
            }
        }

        #[test]
        fn prop_traversal_visits_all_reachable_nodes(
            tree_depth in 1..5usize
        ) {
            let mut graph = Graph::new();
            let mut all_nodes = Vec::new();

            // Create a binary tree
            let root = Node::new("Root");
            let root_id = root.id;
            all_nodes.push(root_id);
            graph.add_node(root).unwrap();

            let mut current_level = vec![root_id];

            for depth in 1..=tree_depth {
                let mut next_level = Vec::new();

                for &parent_id in &current_level {
                    // Add two children for each node in current level
                    for i in 0..2 {
                        let child = Node::new_child(parent_id, &format!("D{}-{}", depth, i));
                        let child_id = child.id;
                        all_nodes.push(child_id);
                        graph.add_node(child).unwrap();

                        // Add edge
                        graph.add_edge(Edge::new(parent_id, child_id)).unwrap();
                        next_level.push(child_id);
                    }
                }

                current_level = next_level;
            }

            // Test both traversal orders
            for order in [TraversalOrder::DepthFirst, TraversalOrder::BreadthFirst] {
                let result = graph.traverse(root_id, order);
                prop_assert!(result.is_some());

                let traversal = result.unwrap();

                // Should visit all nodes
                prop_assert_eq!(traversal.visited.len(), all_nodes.len());

                // All nodes should be reachable
                for &node_id in &all_nodes {
                    prop_assert!(traversal.visited.contains(&node_id));
                    prop_assert!(traversal.depths.contains_key(&node_id));
                }

                // Root should be at depth 0
                prop_assert_eq!(traversal.depths[&root_id], 0);
            }
        }
    }
}

// Benchmark helper functions for future performance testing
#[cfg(test)]
mod benchmark_helpers {
    use super::*;

    pub fn create_large_tree(depth: usize, branching_factor: usize) -> (Graph, NodeId) {
        let mut graph = Graph::new();

        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        let mut current_level = vec![root_id];

        for d in 1..=depth {
            let mut next_level = Vec::new();

            for &parent_id in &current_level {
                for i in 0..branching_factor {
                    let child = Node::new_child(parent_id, &format!("D{}-{}", d, i));
                    let child_id = child.id;
                    graph.add_node(child).unwrap();
                    graph.add_edge(Edge::new(parent_id, child_id)).unwrap();
                    next_level.push(child_id);
                }
            }

            current_level = next_level;
        }

        (graph, root_id)
    }

    pub fn create_dense_graph(node_count: usize) -> Graph {
        let mut graph = Graph::new();
        let mut node_ids = Vec::new();

        // Create nodes
        for i in 0..node_count {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Create edges between all pairs of nodes
        for i in 0..node_count {
            for j in i+1..node_count {
                let edge = Edge::new(node_ids[i], node_ids[j]);
                graph.add_edge(edge).unwrap();
            }
        }

        graph
    }

    #[test]
    fn test_benchmark_helpers() {
        let (graph, root_id) = create_large_tree(3, 2);

        // Tree with depth 3 and branching factor 2 should have:
        // 1 (root) + 2 (level 1) + 4 (level 2) + 8 (level 3) = 15 nodes
        assert_eq!(graph.node_count(), 15);

        // Should have 14 edges (each non-root node has one parent edge)
        assert_eq!(graph.edge_count(), 14);

        // Root should have 2 children
        let children = graph.get_children(root_id);
        assert_eq!(children.len(), 2);
    }
}