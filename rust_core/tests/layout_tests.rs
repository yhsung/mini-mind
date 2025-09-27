//! Comprehensive tests for layout algorithms
//!
//! This module provides extensive testing for all layout algorithms including
//! radial, tree, and force-directed layouts with performance benchmarks,
//! edge case handling, and large graph testing.

use mindmap_core::graph::Graph;
use mindmap_core::layout::{
    LayoutEngine, LayoutEngineImpl, LayoutConfig, LayoutResult, LayoutBounds, LayoutType,
    radial::RadialLayoutEngine,
    tree::{TreeLayoutEngine, TreeOrientation},
    force::{ForceLayoutEngine, ForceParameters},
    utils,
};
use mindmap_core::models::{Node, Edge};
use mindmap_core::types::{ids::NodeId, Point};

use std::collections::HashMap;
use std::time::Instant;

#[cfg(test)]
mod layout_base_tests {
    use super::*;

    #[test]
    fn test_layout_config_default() {
        let config = LayoutConfig::default();

        assert_eq!(config.canvas_width, 1000.0);
        assert_eq!(config.canvas_height, 800.0);
        assert_eq!(config.center, Point::new(500.0, 400.0));
        assert_eq!(config.animation_duration, 1000);
        assert!(!config.preserve_positions);
        assert_eq!(config.min_distance, 100.0);
        assert!(config.parameters.is_empty());
    }

    #[test]
    fn test_layout_config_validation() {
        let mut config = LayoutConfig::default();
        let engine = LayoutEngineImpl::new();

        // Valid config should pass
        assert!(engine.validate_config(&config).is_ok());

        // Invalid canvas width
        config.canvas_width = 0.0;
        assert!(engine.validate_config(&config).is_err());
        config.canvas_width = 1000.0;

        // Invalid canvas height
        config.canvas_height = -10.0;
        assert!(engine.validate_config(&config).is_err());
        config.canvas_height = 800.0;

        // Invalid min distance
        config.min_distance = -5.0;
        assert!(engine.validate_config(&config).is_err());
    }

    #[test]
    fn test_layout_bounds_creation() {
        let bounds = LayoutBounds::new(10.0, 20.0, 100.0, 80.0);

        assert_eq!(bounds.min_x, 10.0);
        assert_eq!(bounds.min_y, 20.0);
        assert_eq!(bounds.max_x, 100.0);
        assert_eq!(bounds.max_y, 80.0);
        assert_eq!(bounds.width(), 90.0);
        assert_eq!(bounds.height(), 60.0);
        assert_eq!(bounds.center(), Point::new(55.0, 50.0));
        assert!(bounds.is_valid());
    }

    #[test]
    fn test_layout_bounds_from_points() {
        let points = vec![
            Point::new(0.0, 0.0),
            Point::new(100.0, 50.0),
            Point::new(-20.0, 75.0),
            Point::new(50.0, -10.0),
        ];

        let bounds = LayoutBounds::from_points(&points);

        assert_eq!(bounds.min_x, -20.0);
        assert_eq!(bounds.min_y, -10.0);
        assert_eq!(bounds.max_x, 100.0);
        assert_eq!(bounds.max_y, 75.0);
    }

    #[test]
    fn test_layout_bounds_empty_points() {
        let bounds = LayoutBounds::from_points(&[]);

        assert_eq!(bounds.min_x, 0.0);
        assert_eq!(bounds.min_y, 0.0);
        assert_eq!(bounds.max_x, 0.0);
        assert_eq!(bounds.max_y, 0.0);
        assert!(bounds.is_valid());
    }

    #[test]
    fn test_layout_bounds_extend() {
        let mut bounds = LayoutBounds::new(10.0, 10.0, 50.0, 50.0);

        bounds.extend_point(&Point::new(100.0, 25.0));
        assert_eq!(bounds.max_x, 100.0);

        bounds.extend_point(&Point::new(25.0, 100.0));
        assert_eq!(bounds.max_y, 100.0);

        bounds.extend_point(&Point::new(-10.0, 25.0));
        assert_eq!(bounds.min_x, -10.0);

        bounds.extend_point(&Point::new(25.0, -5.0));
        assert_eq!(bounds.min_y, -5.0);
    }

    #[test]
    fn test_layout_bounds_validity() {
        assert!(LayoutBounds::new(0.0, 0.0, 100.0, 100.0).is_valid());
        assert!(LayoutBounds::new(50.0, 50.0, 50.0, 50.0).is_valid()); // Point bounds
        assert!(!LayoutBounds::new(100.0, 100.0, 0.0, 0.0).is_valid());
        assert!(!LayoutBounds::new(0.0, 100.0, 100.0, 0.0).is_valid());
    }
}

#[cfg(test)]
mod layout_utils_tests {
    use super::*;
    use std::f64::consts::PI;

    #[test]
    fn test_distance_calculation() {
        assert_eq!(utils::distance(&Point::new(0.0, 0.0), &Point::new(3.0, 4.0)), 5.0);
        assert_eq!(utils::distance(&Point::new(1.0, 1.0), &Point::new(1.0, 1.0)), 0.0);
        assert!((utils::distance(&Point::new(0.0, 0.0), &Point::new(1.0, 1.0)) - 2.0_f64.sqrt()).abs() < 1e-10);
    }

    #[test]
    fn test_angle_normalization() {
        assert!((utils::normalize_angle(0.0) - 0.0).abs() < 1e-10);
        assert!((utils::normalize_angle(PI) - PI).abs() < 1e-10);
        assert!((utils::normalize_angle(2.0 * PI) - 0.0).abs() < 1e-10);
        assert!((utils::normalize_angle(3.0 * PI) - PI).abs() < 1e-10);
        assert!((utils::normalize_angle(-PI) - PI).abs() < 1e-10);
        assert!((utils::normalize_angle(-PI / 2.0) - (3.0 * PI / 2.0)).abs() < 1e-10);
    }

    #[test]
    fn test_polar_cartesian_conversion() {
        let center = Point::new(100.0, 100.0);
        let test_cases = vec![
            (0.0, 0.0),           // Origin
            (50.0, 0.0),          // Along positive X
            (50.0, PI / 2.0),     // Along positive Y
            (50.0, PI),           // Along negative X
            (50.0, 3.0 * PI / 2.0), // Along negative Y
            (25.0, PI / 4.0),     // 45 degrees
        ];

        for (radius, angle) in test_cases {
            let cartesian = utils::polar_to_cartesian(radius, angle, &center);
            let (back_radius, back_angle) = utils::cartesian_to_polar(&cartesian, &center);

            assert!((back_radius - radius).abs() < 1e-10,
                   "Radius mismatch: expected {}, got {}", radius, back_radius);

            // Handle angle wrapping for comparison
            let normalized_original = utils::normalize_angle(angle);
            let normalized_back = utils::normalize_angle(back_angle);
            assert!((normalized_back - normalized_original).abs() < 1e-10,
                   "Angle mismatch: expected {}, got {}", normalized_original, normalized_back);
        }
    }

    #[test]
    fn test_distribute_angles() {
        // Test various counts
        for count in 1..=8 {
            let angles = utils::distribute_angles(count, 0.0);
            assert_eq!(angles.len(), count);

            if count > 1 {
                let expected_step = 2.0 * PI / count as f64;
                for (i, &angle) in angles.iter().enumerate() {
                    let expected = i as f64 * expected_step;
                    assert!((angle - expected).abs() < 1e-10,
                           "Angle {} mismatch: expected {}, got {}", i, expected, angle);
                }
            }
        }

        // Test with start angle offset
        let angles = utils::distribute_angles(4, PI / 4.0);
        let expected_first = PI / 4.0;
        assert!((angles[0] - expected_first).abs() < 1e-10);
    }

    #[test]
    fn test_distribute_angles_edge_cases() {
        // Empty case
        let angles = utils::distribute_angles(0, 0.0);
        assert!(angles.is_empty());

        // Single angle
        let angles = utils::distribute_angles(1, PI / 3.0);
        assert_eq!(angles.len(), 1);
        assert!((angles[0] - PI / 3.0).abs() < 1e-10);
    }

    #[test]
    fn test_calculate_radius() {
        // Test minimum constraints
        let radius = utils::calculate_radius(1, 50.0, 20.0);
        assert_eq!(radius, 50.0); // Should return min_distance for single child

        // Test multiple children
        let radius = utils::calculate_radius(4, 50.0, 20.0);
        assert!(radius >= 50.0); // At least min_distance
        assert!(radius >= 40.0); // At least 2 * node_size

        // Test that radius increases with more children
        let radius_4 = utils::calculate_radius(4, 50.0, 20.0);
        let radius_8 = utils::calculate_radius(8, 50.0, 20.0);
        assert!(radius_8 >= radius_4);

        // Test edge case
        let radius_0 = utils::calculate_radius(0, 50.0, 20.0);
        assert_eq!(radius_0, 50.0);
    }

    #[test]
    fn test_scale_to_fit() {
        let mut points = HashMap::new();
        let node1 = NodeId::new();
        let node2 = NodeId::new();
        let node3 = NodeId::new();

        points.insert(node1, Point::new(0.0, 0.0));
        points.insert(node2, Point::new(200.0, 100.0));
        points.insert(node3, Point::new(100.0, 200.0));

        let target_bounds = LayoutBounds::new(0.0, 0.0, 100.0, 100.0);
        utils::scale_to_fit(&mut points, &target_bounds);

        // Verify points are scaled to fit
        let scaled_points: Vec<Point> = points.values().cloned().collect();
        let result_bounds = LayoutBounds::from_points(&scaled_points);

        assert!(result_bounds.width() <= target_bounds.width() * 1.01); // Small tolerance
        assert!(result_bounds.height() <= target_bounds.height() * 1.01);

        // Verify aspect ratio is preserved (approximately)
        let original_aspect = 200.0 / 200.0; // 1.0
        let scaled_aspect = result_bounds.width() / result_bounds.height();
        assert!((scaled_aspect - original_aspect).abs() < 0.1);
    }

    #[test]
    fn test_scale_to_fit_edge_cases() {
        // Empty points
        let mut empty_points = HashMap::new();
        let target_bounds = LayoutBounds::new(0.0, 0.0, 100.0, 100.0);
        utils::scale_to_fit(&mut empty_points, &target_bounds);
        assert!(empty_points.is_empty());

        // Single point
        let mut single_point = HashMap::new();
        single_point.insert(NodeId::new(), Point::new(50.0, 50.0));
        utils::scale_to_fit(&mut single_point, &target_bounds);
        // Should not crash and point should remain
        assert_eq!(single_point.len(), 1);

        // All points at same location
        let mut same_points = HashMap::new();
        same_points.insert(NodeId::new(), Point::new(50.0, 50.0));
        same_points.insert(NodeId::new(), Point::new(50.0, 50.0));
        utils::scale_to_fit(&mut same_points, &target_bounds);
        // Should not crash
        assert_eq!(same_points.len(), 2);
    }
}

#[cfg(test)]
mod radial_layout_tests {
    use super::*;

    fn create_simple_tree() -> (Graph, NodeId) {
        let mut graph = Graph::new();

        // Create root
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        // Create children
        let mut child_ids = Vec::new();
        for i in 0..4 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            let child_id = child.id;
            child_ids.push(child_id);
            graph.add_node(child).unwrap();
        }

        // Create grandchildren for first child
        for i in 0..3 {
            let grandchild = Node::new_child(child_ids[0], &format!("Grandchild {}", i));
            graph.add_node(grandchild).unwrap();
        }

        (graph, root_id)
    }

    #[test]
    fn test_radial_layout_engine_creation() {
        let engine = RadialLayoutEngine::default();
        assert_eq!(engine.base_radius, 150.0);
        assert_eq!(engine.radius_increment, 100.0);
        assert_eq!(engine.max_depth, None);

        let custom_engine = RadialLayoutEngine::new(200.0, 150.0, std::f64::consts::PI / 6.0);
        assert_eq!(custom_engine.base_radius, 200.0);
        assert_eq!(custom_engine.radius_increment, 150.0);

        let limited_engine = custom_engine.with_max_depth(3);
        assert_eq!(limited_engine.max_depth, Some(3));
    }

    #[test]
    fn test_radial_layout_simple_tree() {
        let (graph, root_id) = create_simple_tree();
        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // Should have positions for all nodes
        assert_eq!(layout.positions.len(), graph.node_count());

        // Root should be at center
        let root_pos = layout.positions.get(&root_id).unwrap();
        let center_distance = utils::distance(root_pos, &config.center);
        assert!(center_distance < 1.0, "Root should be near center, distance: {}", center_distance);

        // Check that layout bounds are reasonable
        assert!(layout.bounds.is_valid());
        assert!(layout.bounds.width() > 0.0);
        assert!(layout.bounds.height() > 0.0);
    }

    #[test]
    fn test_radial_layout_children_distribution() {
        let mut graph = Graph::new();

        // Create root with exactly 4 children for predictable angle distribution
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        let mut child_ids = Vec::new();
        for i in 0..4 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            let child_id = child.id;
            child_ids.push(child_id);
            graph.add_node(child).unwrap();
        }

        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        // Check that children are distributed around the root
        let root_pos = *layout.positions.get(&root_id).unwrap();

        let mut angles = Vec::new();
        for &child_id in &child_ids {
            let child_pos = *layout.positions.get(&child_id).unwrap();
            let (radius, angle) = utils::cartesian_to_polar(&child_pos, &root_pos);

            // Check radius is reasonable
            assert!(radius > engine.base_radius * 0.8, "Child radius too small: {}", radius);
            assert!(radius < engine.base_radius * 1.2, "Child radius too large: {}", radius);

            angles.push(angle);
        }

        // Check that angles are roughly evenly distributed
        angles.sort_by(|a, b| a.partial_cmp(b).unwrap());
        for i in 1..angles.len() {
            let angle_diff = angles[i] - angles[i-1];
            let expected_diff = 2.0 * std::f64::consts::PI / 4.0; // 90 degrees
            assert!((angle_diff - expected_diff).abs() < 0.5,
                   "Angles not evenly distributed: {} vs expected {}", angle_diff, expected_diff);
        }
    }

    #[test]
    fn test_radial_layout_depth_levels() {
        let (graph, root_id) = create_simple_tree();
        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        let root_pos = *layout.positions.get(&root_id).unwrap();

        // Find children and grandchildren
        let children = graph.get_children(root_id);
        let first_child = &children[0]; // Has grandchildren
        let grandchildren = graph.get_children(first_child.id);

        // Check that children are at base radius
        for child in &children {
            let child_pos = *layout.positions.get(&child.id).unwrap();
            let (radius, _) = utils::cartesian_to_polar(&child_pos, &root_pos);
            assert!((radius - engine.base_radius).abs() < 20.0,
                   "Child radius {} not close to base radius {}", radius, engine.base_radius);
        }

        // Check that grandchildren are at increased radius
        let first_child_pos = *layout.positions.get(&first_child.id).unwrap();
        for grandchild in &grandchildren {
            let grandchild_pos = *layout.positions.get(&grandchild.id).unwrap();
            let (radius, _) = utils::cartesian_to_polar(&grandchild_pos, &first_child_pos);
            let expected_radius = engine.base_radius;
            assert!((radius - expected_radius).abs() < 50.0,
                   "Grandchild radius {} not at expected level", radius);
        }
    }

    #[test]
    fn test_radial_layout_max_depth() {
        let (graph, _) = create_simple_tree();
        let engine = RadialLayoutEngine::default().with_max_depth(1);
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        // With max depth 1, only root and direct children should be positioned
        // Grandchildren should either not be positioned or be at same level as children
        assert!(layout.positions.len() >= 5); // Root + 4 children minimum
    }

    #[test]
    fn test_radial_layout_empty_graph() {
        let graph = Graph::new();
        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert!(layout.positions.is_empty());
        assert_eq!(layout.bounds.width(), 0.0);
        assert_eq!(layout.bounds.height(), 0.0);
    }

    #[test]
    fn test_radial_layout_single_node() {
        let mut graph = Graph::new();
        let node = Node::new("Single Node");
        let node_id = node.id;
        graph.add_node(node).unwrap();

        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        assert_eq!(layout.positions.len(), 1);
        let pos = layout.positions.get(&node_id).unwrap();

        // Single node should be at center
        let distance = utils::distance(pos, &config.center);
        assert!(distance < 1.0, "Single node should be at center");
    }
}

#[cfg(test)]
mod tree_layout_tests {
    use super::*;

    fn create_balanced_tree() -> (Graph, NodeId) {
        let mut graph = Graph::new();

        // Create root
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        // Create two main branches
        let mut level1_ids = Vec::new();
        for i in 0..2 {
            let child = Node::new_child(root_id, &format!("L1-{}", i));
            let child_id = child.id;
            level1_ids.push(child_id);
            graph.add_node(child).unwrap();
        }

        // Create level 2 nodes
        for (i, &parent_id) in level1_ids.iter().enumerate() {
            for j in 0..3 {
                let child = Node::new_child(parent_id, &format!("L2-{}-{}", i, j));
                graph.add_node(child).unwrap();
            }
        }

        (graph, root_id)
    }

    #[test]
    fn test_tree_layout_engine_creation() {
        let engine = TreeLayoutEngine::default();
        assert_eq!(engine.orientation, TreeOrientation::TopDown);
        assert_eq!(engine.horizontal_spacing, 80.0);
        assert_eq!(engine.vertical_spacing, 120.0);
        assert!(engine.balance_subtrees);

        let custom_engine = TreeLayoutEngine::new(
            TreeOrientation::LeftRight, 150.0, 200.0
        );
        assert_eq!(custom_engine.orientation, TreeOrientation::LeftRight);
        assert_eq!(custom_engine.horizontal_spacing, 150.0);
    }

    #[test]
    fn test_tree_layout_orientations() {
        let (graph, root_id) = create_balanced_tree();
        let config = LayoutConfig::default();

        for orientation in [
            TreeOrientation::TopDown,
            TreeOrientation::BottomUp,
            TreeOrientation::LeftRight,
            TreeOrientation::RightLeft,
        ] {
            let engine = TreeLayoutEngine::new(orientation, 100.0, 150.0);
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok(), "Layout failed for orientation {:?}", orientation);

            let layout = result.unwrap();
            assert_eq!(layout.positions.len(), graph.node_count());
            assert!(layout.bounds.is_valid());
        }
    }

    #[test]
    fn test_tree_layout_hierarchy() {
        let (graph, root_id) = create_balanced_tree();
        let engine = TreeLayoutEngine::default(); // TopDown
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        let root_pos = *layout.positions.get(&root_id).unwrap();
        let children = graph.get_children(root_id);

        // In top-down layout, children should be below root (higher Y)
        for child in &children {
            let child_pos = *layout.positions.get(&child.id).unwrap();
            assert!(child_pos.y > root_pos.y,
                   "Child should be below root: child.y={}, root.y={}", child_pos.y, root_pos.y);

            // Check vertical spacing
            let vertical_distance = child_pos.y - root_pos.y;
            assert!(vertical_distance >= engine.vertical_spacing * 0.8,
                   "Vertical spacing too small: {}", vertical_distance);

            // Check grandchildren
            let grandchildren = graph.get_children(child.id);
            for grandchild in &grandchildren {
                let grandchild_pos = *layout.positions.get(&grandchild.id).unwrap();
                assert!(grandchild_pos.y > child_pos.y,
                       "Grandchild should be below child");
            }
        }
    }

    #[test]
    fn test_tree_layout_sibling_spacing() {
        let mut graph = Graph::new();

        // Create root with multiple children
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        let mut child_ids = Vec::new();
        for i in 0..5 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            let child_id = child.id;
            child_ids.push(child_id);
            graph.add_node(child).unwrap();
        }

        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        // Check horizontal spacing between siblings
        let mut child_positions: Vec<(NodeId, Point)> = child_ids.iter()
            .map(|&id| (id, *layout.positions.get(&id).unwrap()))
            .collect();

        // Sort by X position
        child_positions.sort_by(|a, b| a.1.x.partial_cmp(&b.1.x).unwrap());

        for i in 1..child_positions.len() {
            let distance = child_positions[i].1.x - child_positions[i-1].1.x;
            assert!(distance >= engine.horizontal_spacing * 0.8,
                   "Horizontal spacing too small between siblings: {}", distance);
        }
    }

    #[test]
    fn test_tree_layout_bottom_up() {
        let (graph, root_id) = create_balanced_tree();
        let engine = TreeLayoutEngine::new(
            TreeOrientation::BottomUp, 100.0, 150.0
        );
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        let root_pos = *layout.positions.get(&root_id).unwrap();
        let children = graph.get_children(root_id);

        // In bottom-up layout, children should be above root (lower Y)
        for child in &children {
            let child_pos = *layout.positions.get(&child.id).unwrap();
            assert!(child_pos.y < root_pos.y,
                   "Child should be above root in bottom-up layout");
        }
    }

    #[test]
    fn test_tree_layout_left_right() {
        let (graph, root_id) = create_balanced_tree();
        let engine = TreeLayoutEngine::new(
            TreeOrientation::LeftRight, 100.0, 150.0
        );
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        let root_pos = *layout.positions.get(&root_id).unwrap();
        let children = graph.get_children(root_id);

        // In left-right layout, children should be to the right of root (higher X)
        for child in &children {
            let child_pos = *layout.positions.get(&child.id).unwrap();
            assert!(child_pos.x > root_pos.x,
                   "Child should be to the right of root in left-right layout");
        }
    }

    #[test]
    fn test_tree_layout_empty_and_single_node() {
        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();

        // Empty graph
        let empty_graph = Graph::new();
        let result = engine.calculate_layout(&empty_graph, &config);
        assert!(result.is_ok());
        let layout = result.unwrap();
        assert!(layout.positions.is_empty());

        // Single node
        let mut single_graph = Graph::new();
        let node = Node::new("Single");
        let node_id = node.id;
        single_graph.add_node(node).unwrap();

        let result = engine.calculate_layout(&single_graph, &config);
        assert!(result.is_ok());
        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), 1);

        // Single node should be near center
        let pos = layout.positions.get(&node_id).unwrap();
        let distance = utils::distance(pos, &config.center);
        assert!(distance < 200.0, "Single node should be near center");
    }
}

#[cfg(test)]
mod force_layout_tests {
    use super::*;

    fn create_connected_graph() -> Graph {
        let mut graph = Graph::new();

        // Create nodes
        let mut node_ids = Vec::new();
        for i in 0..6 {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Create edges to form a connected graph
        // 0-1-2-3 chain plus 1-4 and 2-5 branches
        let edges = vec![
            (0, 1), (1, 2), (2, 3), (1, 4), (2, 5)
        ];

        for (i, j) in edges {
            let edge = Edge::new(node_ids[i], node_ids[j]);
            graph.add_edge(edge).unwrap();
        }

        graph
    }

    #[test]
    fn test_force_parameters_default() {
        let params = ForceParameters::default();
        assert!(params.spring_strength > 0.0);
        assert!(params.spring_length > 0.0);
        assert!(params.repulsion_strength > 0.0);
        assert!(params.damping > 0.0 && params.damping < 1.0);
        assert!(params.time_step > 0.0);
        assert!(params.max_iterations > 0);
        assert!(params.convergence_threshold > 0.0);
    }

    #[test]
    fn test_force_layout_engine_creation() {
        let engine = ForceLayoutEngine::default();
        assert!(engine.adaptive_timestep); // Default should be true
        assert_eq!(engine.random_seed, None);

        let custom_params = ForceParameters {
            spring_strength: 0.5,
            spring_length: 100.0,
            repulsion_strength: 1000.0,
            damping: 0.8,
            center_strength: 0.1,
            time_step: 0.1,
            max_iterations: 500,
            convergence_threshold: 0.01,
        };

        let custom_engine = ForceLayoutEngine::new(custom_params)
            .with_adaptive_timestep(true)
            .with_seed(42);
        assert_eq!(custom_engine.parameters.spring_strength, 0.5);
        assert!(custom_engine.adaptive_timestep);
        assert_eq!(custom_engine.random_seed, Some(42));
    }

    #[test]
    fn test_force_layout_connected_graph() {
        let graph = create_connected_graph();
        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // Should have positions for all nodes
        assert_eq!(layout.positions.len(), graph.node_count());

        // Layout should have valid bounds
        assert!(layout.bounds.is_valid());
        assert!(layout.bounds.width() > 0.0);
        assert!(layout.bounds.height() > 0.0);

        // Check if layout converged or reached max iterations
        assert!(layout.iterations > 0);
        assert!(layout.iterations <= engine.parameters.max_iterations);
    }

    #[test]
    fn test_force_layout_node_separation() {
        let graph = create_connected_graph();
        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        // Check that no two nodes are too close (repulsion working)
        let positions: Vec<Point> = layout.positions.values().cloned().collect();
        let min_distance = 20.0; // Reasonable minimum distance

        for i in 0..positions.len() {
            for j in i+1..positions.len() {
                let distance = utils::distance(&positions[i], &positions[j]);
                assert!(distance >= min_distance,
                       "Nodes too close: distance {} < {}", distance, min_distance);
            }
        }
    }

    #[test]
    fn test_force_layout_connected_nodes_closer() {
        let mut graph = Graph::new();

        // Create a simple connected pair and an isolated node
        let node1 = Node::new("Connected 1");
        let node2 = Node::new("Connected 2");
        let node3 = Node::new("Isolated");
        let id1 = node1.id;
        let id2 = node2.id;
        let id3 = node3.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();
        graph.add_node(node3).unwrap();

        // Connect node1 and node2
        graph.add_edge(Edge::new(id1, id2)).unwrap();

        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        let pos1 = *layout.positions.get(&id1).unwrap();
        let pos2 = *layout.positions.get(&id2).unwrap();
        let pos3 = *layout.positions.get(&id3).unwrap();

        let connected_distance = utils::distance(&pos1, &pos2);
        let isolated_distance1 = utils::distance(&pos1, &pos3);
        let isolated_distance2 = utils::distance(&pos2, &pos3);

        // Connected nodes should be closer together than to isolated node
        assert!(connected_distance < isolated_distance1,
               "Connected nodes should be closer: {} vs {}", connected_distance, isolated_distance1);
        assert!(connected_distance < isolated_distance2,
               "Connected nodes should be closer: {} vs {}", connected_distance, isolated_distance2);
    }

    #[test]
    fn test_force_layout_deterministic_with_seed() {
        let graph = create_connected_graph();
        let engine1 = ForceLayoutEngine::default().with_seed(42);
        let engine2 = ForceLayoutEngine::default().with_seed(42);
        let config = LayoutConfig::default();

        let layout1 = engine1.calculate_layout(&graph, &config).unwrap();
        let layout2 = engine2.calculate_layout(&graph, &config).unwrap();

        // With same seed, layouts should be identical
        for (node_id, pos1) in &layout1.positions {
            let pos2 = layout2.positions.get(node_id).unwrap();
            assert!((pos1.x - pos2.x).abs() < 1e-6, "X positions should be identical");
            assert!((pos1.y - pos2.y).abs() < 1e-6, "Y positions should be identical");
        }
    }

    #[test]
    fn test_force_layout_convergence() {
        let graph = create_connected_graph();

        // Use tight convergence threshold
        let mut params = ForceParameters::default();
        params.convergence_threshold = 0.001;
        params.max_iterations = 1000;

        let engine = ForceLayoutEngine::new(params).with_seed(42);
        let config = LayoutConfig::default();
        let layout = engine.calculate_layout(&graph, &config).unwrap();

        // If converged, energy should be low
        if layout.converged {
            assert!(layout.energy < engine.parameters.convergence_threshold * 2.0,
                   "Energy too high for converged layout: {}", layout.energy);
        }

        // Should not exceed max iterations
        assert!(layout.iterations <= engine.parameters.max_iterations);
    }

    #[test]
    fn test_force_layout_empty_and_single_node() {
        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();

        // Empty graph
        let empty_graph = Graph::new();
        let result = engine.calculate_layout(&empty_graph, &config);
        assert!(result.is_ok());
        let layout = result.unwrap();
        assert!(layout.positions.is_empty());
        assert!(layout.converged); // Empty graph should converge immediately

        // Single node
        let mut single_graph = Graph::new();
        let node = Node::new("Single");
        let node_id = node.id;
        single_graph.add_node(node).unwrap();

        let result = engine.calculate_layout(&single_graph, &config);
        assert!(result.is_ok());
        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), 1);

        // Single node should be at or near center due to center attraction
        let pos = layout.positions.get(&node_id).unwrap();
        let distance = utils::distance(pos, &config.center);
        assert!(distance < 200.0, "Single node should be near center");
    }
}

#[cfg(test)]
mod layout_engine_integration_tests {
    use super::*;

    #[test]
    fn test_layout_engine_impl_creation() {
        let engine = LayoutEngineImpl::new();
        assert_eq!(engine.layout_type(), LayoutType::Radial);

        let tree_engine = LayoutEngineImpl::with_layout_type(LayoutType::Tree);
        assert_eq!(tree_engine.layout_type(), LayoutType::Tree);

        let force_engine = LayoutEngineImpl::with_layout_type(LayoutType::Force);
        assert_eq!(force_engine.layout_type(), LayoutType::Force);
    }

    #[test]
    fn test_layout_engine_impl_switching() {
        let mut engine = LayoutEngineImpl::new();

        // Start with radial
        assert_eq!(engine.layout_type(), LayoutType::Radial);

        // Switch to tree
        engine.set_layout_type(LayoutType::Tree);
        assert_eq!(engine.layout_type(), LayoutType::Tree);

        // Switch to force
        engine.set_layout_type(LayoutType::Force);
        assert_eq!(engine.layout_type(), LayoutType::Force);
    }

    #[test]
    fn test_layout_engine_impl_calculate_all_types() {
        let mut graph = Graph::new();

        // Create a simple tree
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        for i in 0..3 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            graph.add_node(child).unwrap();
        }

        let engine = LayoutEngineImpl::new();
        let config = LayoutConfig::default();

        // Test all layout types through the unified interface
        for layout_type in [LayoutType::Radial, LayoutType::Tree, LayoutType::Force] {
            let result = engine.calculate_layout(&graph, layout_type);
            assert!(result.is_ok(), "Layout type {:?} failed", layout_type);

            let layout = result.unwrap();
            assert_eq!(layout.positions.len(), graph.node_count());
            assert!(layout.bounds.is_valid());
        }
    }

    #[test]
    fn test_layout_engine_impl_trait_implementation() {
        let mut engine = LayoutEngineImpl::new();
        let mut graph = Graph::new();

        // Create test graph
        let node = Node::new("Test Node");
        graph.add_node(node).unwrap();

        let config = LayoutConfig::default();

        // Test radial layout through trait
        engine.set_layout_type(LayoutType::Radial);
        let result = LayoutEngine::calculate_layout(&engine, &graph, &config);
        assert!(result.is_ok());

        // Test tree layout through trait
        engine.set_layout_type(LayoutType::Tree);
        let result = LayoutEngine::calculate_layout(&engine, &graph, &config);
        assert!(result.is_ok());

        // Test force layout through trait
        engine.set_layout_type(LayoutType::Force);
        let result = LayoutEngine::calculate_layout(&engine, &graph, &config);
        assert!(result.is_ok());
    }

    #[test]
    fn test_apply_layout_to_graph() {
        let mut graph = Graph::new();

        // Create nodes
        let mut node_ids = Vec::new();
        for i in 0..3 {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Calculate layout
        let engine = LayoutEngineImpl::with_layout_type(LayoutType::Radial);
        let config = LayoutConfig::default();
        let layout_result = LayoutEngine::calculate_layout(&engine, &graph, &config).unwrap();

        // Store original positions
        let original_positions: HashMap<NodeId, Point> = node_ids.iter()
            .map(|&id| (id, graph.get_node(id).unwrap().position))
            .collect();

        // Apply layout
        let apply_result = engine.apply_layout(&mut graph, &layout_result);
        assert!(apply_result.is_ok());

        // Check that positions were updated
        for &node_id in &node_ids {
            let node = graph.get_node(node_id).unwrap();
            let original_pos = original_positions.get(&node_id).unwrap();
            if let Some(layout_pos) = layout_result.positions.get(&node_id) {

                // Node position should match layout result
                assert!((node.position.x - layout_pos.x).abs() < 1e-10);
                assert!((node.position.y - layout_pos.y).abs() < 1e-10);

                // Position should likely have changed (unless coincidentally same)
                if utils::distance(&original_pos, &layout_pos) > 1.0 {
                    assert!((node.position.x - original_pos.x).abs() > 1e-10 ||
                           (node.position.y - original_pos.y).abs() > 1e-10,
                           "Position should have been updated");
                }
            } else {
                panic!("Layout result should contain position for node {:?}", node_id);
            }
        }
    }
}

#[cfg(test)]
mod performance_tests {
    use super::*;

    fn create_large_tree(depth: usize, branching_factor: usize) -> (Graph, NodeId) {
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
                    next_level.push(child_id);
                }
            }

            current_level = next_level;
        }

        (graph, root_id)
    }

    fn create_dense_graph(node_count: usize) -> Graph {
        let mut graph = Graph::new();
        let mut node_ids = Vec::new();

        // Create nodes
        for i in 0..node_count {
            let node = Node::new(&format!("Node {}", i));
            let node_id = node.id;
            node_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Create edges (not fully connected to avoid O(n²) edges)
        for i in 0..node_count {
            let connections = (node_count / 4).min(5).max(1); // Each node connects to ~25% of others, max 5
            for j in 1..=connections {
                let target = (i + j) % node_count;
                if target != i {
                    let edge = Edge::new(node_ids[i], node_ids[target]);
                    graph.add_edge(edge).unwrap();
                }
            }
        }

        graph
    }

    #[test]
    fn test_radial_layout_performance_medium_tree() {
        let (graph, _) = create_large_tree(4, 3); // 3^4 = 81 nodes + root = ~120 nodes

        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();

        let start = Instant::now();
        let result = engine.calculate_layout(&graph, &config);
        let duration = start.elapsed();

        assert!(result.is_ok());
        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        // Should complete within reasonable time (adjust based on performance requirements)
        assert!(duration.as_millis() < 1000, "Radial layout too slow: {}ms", duration.as_millis());

        println!("Radial layout for {} nodes: {}ms", graph.node_count(), duration.as_millis());
    }

    #[test]
    fn test_tree_layout_performance_medium_tree() {
        let (graph, _) = create_large_tree(4, 3);

        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();

        let start = Instant::now();
        let result = engine.calculate_layout(&graph, &config);
        let duration = start.elapsed();

        assert!(result.is_ok());
        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        assert!(duration.as_millis() < 1000, "Tree layout too slow: {}ms", duration.as_millis());

        println!("Tree layout for {} nodes: {}ms", graph.node_count(), duration.as_millis());
    }

    #[test]
    fn test_force_layout_performance_medium_graph() {
        let graph = create_dense_graph(50); // 50 nodes with multiple connections

        let mut params = ForceParameters::default();
        params.max_iterations = 200; // Limit iterations for test performance

        let engine = ForceLayoutEngine::new(params).with_seed(42);
        let config = LayoutConfig::default();

        let start = Instant::now();
        let result = engine.calculate_layout(&graph, &config);
        let duration = start.elapsed();

        assert!(result.is_ok());
        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        // Force layout is more computationally intensive
        assert!(duration.as_millis() < 5000, "Force layout too slow: {}ms", duration.as_millis());

        println!("Force layout for {} nodes: {}ms (converged: {}, iterations: {})",
                graph.node_count(), duration.as_millis(), layout.converged, layout.iterations);
    }

    #[test]
    fn test_layout_scaling_characteristics() {
        let sizes = vec![10, 25, 50];

        for &size in &sizes {
            let graph = create_dense_graph(size);
            let config = LayoutConfig::default();

            // Test radial layout scaling
            let radial_engine = RadialLayoutEngine::default();
            let start = Instant::now();
            let result = radial_engine.calculate_layout(&graph, &config);
            let radial_duration = start.elapsed();
            assert!(result.is_ok());

            // Test tree layout scaling
            let tree_engine = TreeLayoutEngine::default();
            let start = Instant::now();
            let result = tree_engine.calculate_layout(&graph, &config);
            let tree_duration = start.elapsed();
            assert!(result.is_ok());

            // Test force layout scaling (with limited iterations)
            let mut force_params = ForceParameters::default();
            force_params.max_iterations = 100;
            let force_engine = ForceLayoutEngine::new(force_params).with_seed(42);
            let start = Instant::now();
            let result = force_engine.calculate_layout(&graph, &config);
            let force_duration = start.elapsed();
            assert!(result.is_ok());

            println!("Size {}: Radial {}ms, Tree {}ms, Force {}ms",
                    size, radial_duration.as_millis(), tree_duration.as_millis(), force_duration.as_millis());

            // Sanity check - layouts shouldn't take too long for these sizes
            assert!(radial_duration.as_millis() < 500);
            assert!(tree_duration.as_millis() < 500);
            assert!(force_duration.as_millis() < 2000);
        }
    }

    #[test]
    fn test_layout_memory_efficiency() {
        let (graph, _) = create_large_tree(3, 4); // Reasonable size for memory test
        let config = LayoutConfig::default();

        // Test that layouts don't allocate excessive memory
        // This is more of a smoke test - in real scenarios you'd use a profiler

        let engines: Vec<Box<dyn LayoutEngine>> = vec![
            Box::new(RadialLayoutEngine::default()),
            Box::new(TreeLayoutEngine::default()),
            Box::new(ForceLayoutEngine::default()),
        ];

        for engine in engines {
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok());

            let layout = result.unwrap();

            // Layout should include all nodes
            assert_eq!(layout.positions.len(), graph.node_count());

            // Bounds should be reasonable (not infinite or NaN)
            assert!(layout.bounds.is_valid());
            assert!(layout.bounds.width().is_finite());
            assert!(layout.bounds.height().is_finite());
            assert!(layout.bounds.width() >= 0.0);
            assert!(layout.bounds.height() >= 0.0);
        }
    }
}

#[cfg(test)]
mod edge_case_tests {
    use super::*;

    #[test]
    fn test_disconnected_components() {
        let mut graph = Graph::new();

        // Create two disconnected components
        let mut component1_ids = Vec::new();
        let mut component2_ids = Vec::new();

        // Component 1: Triangle
        for i in 0..3 {
            let node = Node::new(&format!("C1-{}", i));
            let node_id = node.id;
            component1_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Component 2: Chain
        for i in 0..3 {
            let node = Node::new(&format!("C2-{}", i));
            let node_id = node.id;
            component2_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        // Add edges within components
        for i in 0..3 {
            let edge1 = Edge::new(component1_ids[i], component1_ids[(i+1) % 3]);
            graph.add_edge(edge1).unwrap();
        }

        for i in 0..2 {
            let edge2 = Edge::new(component2_ids[i], component2_ids[i+1]);
            graph.add_edge(edge2).unwrap();
        }

        let config = LayoutConfig::default();

        // Test all layout types handle disconnected components
        let engines: Vec<Box<dyn LayoutEngine>> = vec![
            Box::new(RadialLayoutEngine::default()),
            Box::new(TreeLayoutEngine::default()),
            Box::new(ForceLayoutEngine::default()),
        ];

        for engine in engines {
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok(), "Layout failed for disconnected components");

            let layout = result.unwrap();
            assert_eq!(layout.positions.len(), graph.node_count());

            // All positions should be valid (finite numbers)
            for position in layout.positions.values() {
                assert!(position.x.is_finite(), "Invalid X coordinate: {}", position.x);
                assert!(position.y.is_finite(), "Invalid Y coordinate: {}", position.y);
            }
        }
    }

    #[test]
    fn test_self_loops() {
        let mut graph = Graph::new();

        let node = Node::new("Self Loop Node");
        let node_id = node.id;
        graph.add_node(node).unwrap();

        // Add self loop (skip if not supported)
        let self_edge = Edge::new(node_id, node_id);
        if graph.add_edge(self_edge).is_err() {
            // Self-loops not supported, skip this test
            return;
        }

        let config = LayoutConfig::default();

        // All layouts should handle self loops gracefully
        let engines: Vec<Box<dyn LayoutEngine>> = vec![
            Box::new(RadialLayoutEngine::default()),
            Box::new(TreeLayoutEngine::default()),
            Box::new(ForceLayoutEngine::default()),
        ];

        for engine in engines {
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok(), "Layout failed with self loop");

            let layout = result.unwrap();
            assert_eq!(layout.positions.len(), 1);

            let position = layout.positions.get(&node_id).unwrap();
            assert!(position.x.is_finite());
            assert!(position.y.is_finite());
        }
    }

    #[test]
    fn test_parallel_edges() {
        let mut graph = Graph::new();

        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let id1 = node1.id;
        let id2 = node2.id;

        graph.add_node(node1).unwrap();
        graph.add_node(node2).unwrap();

        // Add multiple edges between same nodes
        for _ in 0..3 {
            let edge = Edge::new(id1, id2);
            graph.add_edge(edge).unwrap();
        }

        let config = LayoutConfig::default();

        // Layouts should handle parallel edges
        let engines: Vec<Box<dyn LayoutEngine>> = vec![
            Box::new(RadialLayoutEngine::default()),
            Box::new(TreeLayoutEngine::default()),
            Box::new(ForceLayoutEngine::default()),
        ];

        for engine in engines {
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok(), "Layout failed with parallel edges");

            let layout = result.unwrap();
            assert_eq!(layout.positions.len(), 2);
        }
    }

    #[test]
    fn test_very_large_coordinates() {
        let mut graph = Graph::new();

        // Create nodes with extreme initial positions
        let mut extreme_node = Node::new("Extreme Node");
        extreme_node.position = Point::new(1e6, -1e6);
        let extreme_id = extreme_node.id;
        graph.add_node(extreme_node).unwrap();

        let normal_node = Node::new("Normal Node");
        let normal_id = normal_node.id;
        graph.add_node(normal_node).unwrap();

        // Connect them
        let edge = Edge::new(extreme_id, normal_id);
        graph.add_edge(edge).unwrap();

        let config = LayoutConfig::default();

        // Layouts should normalize extreme coordinates
        let engines: Vec<Box<dyn LayoutEngine>> = vec![
            Box::new(RadialLayoutEngine::default()),
            Box::new(TreeLayoutEngine::default()),
            Box::new(ForceLayoutEngine::default()),
        ];

        for engine in engines {
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok(), "Layout failed with extreme coordinates");

            let layout = result.unwrap();

            // Result positions should be reasonable
            for position in layout.positions.values() {
                assert!(position.x.is_finite());
                assert!(position.y.is_finite());
                assert!(position.x.abs() < 1e5, "X coordinate too extreme: {}", position.x);
                assert!(position.y.abs() < 1e5, "Y coordinate too extreme: {}", position.y);
            }
        }
    }

    #[test]
    fn test_degenerate_tree_structures() {
        let mut graph = Graph::new();

        // Create a completely linear tree (chain)
        let mut node_ids = Vec::new();
        for i in 0..10 {
            let node = if i == 0 {
                Node::new("Root")
            } else {
                Node::new_child(node_ids[i-1], &format!("Node {}", i))
            };
            let node_id = node.id;
            node_ids.push(node_id);
            graph.add_node(node).unwrap();
        }

        let config = LayoutConfig::default();

        // All layouts should handle linear trees
        let tree_engine = TreeLayoutEngine::default();
        let result = tree_engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        // Verify the linear structure is laid out reasonably
        let positions: Vec<Point> = node_ids.iter()
            .map(|&id| *layout.positions.get(&id).unwrap())
            .collect();

        // In a top-down tree layout, Y should increase down the chain
        for i in 1..positions.len() {
            assert!(positions[i].y > positions[i-1].y,
                   "Linear tree not laid out properly: node {} Y={}, previous Y={}",
                   i, positions[i].y, positions[i-1].y);
        }
    }

    #[test]
    fn test_very_unbalanced_tree() {
        let mut graph = Graph::new();

        // Create root
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        // Create one branch with many children
        let heavy_branch = Node::new_child(root_id, "Heavy Branch");
        let heavy_id = heavy_branch.id;
        graph.add_node(heavy_branch).unwrap();

        // Add many children to heavy branch
        for i in 0..20 {
            let child = Node::new_child(heavy_id, &format!("Heavy Child {}", i));
            graph.add_node(child).unwrap();
        }

        // Create one light branch
        let light_branch = Node::new_child(root_id, "Light Branch");
        let light_id = light_branch.id;
        graph.add_node(light_branch).unwrap();

        let light_child = Node::new_child(light_id, "Light Child");
        graph.add_node(light_child).unwrap();

        let config = LayoutConfig::default();

        // Test tree layout with unbalanced structure
        let tree_engine = TreeLayoutEngine::default();
        let result = tree_engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        // Heavy and light branches should be positioned reasonably
        let heavy_pos = layout.positions.get(&heavy_id).unwrap();
        let light_pos = layout.positions.get(&light_id).unwrap();

        // They should be separated horizontally
        let horizontal_distance = (heavy_pos.x - light_pos.x).abs();
        assert!(horizontal_distance > 50.0, "Branches not separated enough: {}", horizontal_distance);
    }
}

// Benchmark functions for future criterion integration
#[cfg(test)]
mod benchmark_functions {
    use super::*;

    pub fn benchmark_radial_layout(graph: &Graph) -> LayoutResult {
        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();
        engine.calculate_layout(graph, &config).unwrap()
    }

    pub fn benchmark_tree_layout(graph: &Graph) -> LayoutResult {
        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();
        engine.calculate_layout(graph, &config).unwrap()
    }

    pub fn benchmark_force_layout(graph: &Graph) -> LayoutResult {
        let mut params = ForceParameters::default();
        params.max_iterations = 100; // Limit for benchmarking
        let engine = ForceLayoutEngine::new(params).with_seed(42);
        let config = LayoutConfig::default();
        engine.calculate_layout(graph, &config).unwrap()
    }

    #[test]
    fn test_benchmark_functions() {
        let mut graph = Graph::new();

        // Create small test graph
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        for i in 0..3 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            graph.add_node(child).unwrap();
        }

        // Test that benchmark functions work
        let radial_result = benchmark_radial_layout(&graph);
        assert_eq!(radial_result.positions.len(), graph.node_count());

        let tree_result = benchmark_tree_layout(&graph);
        assert_eq!(tree_result.positions.len(), graph.node_count());

        let force_result = benchmark_force_layout(&graph);
        assert_eq!(force_result.positions.len(), graph.node_count());
    }
}