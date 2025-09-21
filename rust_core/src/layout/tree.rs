//! Tree layout algorithm implementation
//!
//! Arranges nodes in a hierarchical tree structure with configurable orientation
//! and spacing. Supports horizontal and vertical layouts with automatic sizing.

use super::*;
use crate::graph::Graph;
use crate::types::{ids::NodeId, Point, MindmapResult, MindmapError};
use std::collections::{HashMap, HashSet};

/// Tree layout orientation
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TreeOrientation {
    /// Top to bottom layout
    TopDown,
    /// Bottom to top layout
    BottomUp,
    /// Left to right layout
    LeftRight,
    /// Right to left layout
    RightLeft,
}

/// Tree layout engine implementation
pub struct TreeLayoutEngine {
    /// Layout orientation
    pub orientation: TreeOrientation,
    /// Horizontal spacing between sibling nodes
    pub horizontal_spacing: f64,
    /// Vertical spacing between levels
    pub vertical_spacing: f64,
    /// Minimum node size for calculations
    pub node_size: f64,
    /// Whether to balance subtrees
    pub balance_subtrees: bool,
}

/// Internal structure for tree node layout calculations
#[derive(Debug, Clone)]
struct TreeNode {
    id: NodeId,
    children: Vec<TreeNode>,
    width: f64,
    height: f64,
    x_offset: f64,
    y_offset: f64,
    subtree_width: f64,
}

impl Default for TreeLayoutEngine {
    fn default() -> Self {
        Self {
            orientation: TreeOrientation::TopDown,
            horizontal_spacing: 80.0,
            vertical_spacing: 120.0,
            node_size: 60.0,
            balance_subtrees: true,
        }
    }
}

impl TreeLayoutEngine {
    /// Create a new tree layout engine with custom parameters
    pub fn new(
        orientation: TreeOrientation,
        horizontal_spacing: f64,
        vertical_spacing: f64,
    ) -> Self {
        Self {
            orientation,
            horizontal_spacing,
            vertical_spacing,
            node_size: 60.0,
            balance_subtrees: true,
        }
    }

    /// Set node size for layout calculations
    pub fn with_node_size(mut self, node_size: f64) -> Self {
        self.node_size = node_size;
        self
    }

    /// Enable or disable subtree balancing
    pub fn with_balance_subtrees(mut self, balance: bool) -> Self {
        self.balance_subtrees = balance;
        self
    }

    /// Extract parameters from layout configuration
    fn extract_parameters(&self, config: &LayoutConfig) -> (TreeOrientation, f64, f64, f64) {
        let orientation = config.parameters.get("orientation")
            .and_then(|&val| match val as u32 {
                0 => Some(TreeOrientation::TopDown),
                1 => Some(TreeOrientation::BottomUp),
                2 => Some(TreeOrientation::LeftRight),
                3 => Some(TreeOrientation::RightLeft),
                _ => None,
            })
            .unwrap_or(self.orientation);

        let horizontal_spacing = config.parameters.get("horizontal_spacing")
            .copied()
            .unwrap_or(self.horizontal_spacing);

        let vertical_spacing = config.parameters.get("vertical_spacing")
            .copied()
            .unwrap_or(self.vertical_spacing);

        let node_size = config.parameters.get("node_size")
            .copied()
            .unwrap_or(self.node_size);

        (orientation, horizontal_spacing, vertical_spacing, node_size)
    }

    /// Find the best root node for tree layout
    fn find_root_node(&self, graph: &Graph) -> Option<NodeId> {
        // Prefer explicitly marked root nodes
        let roots = graph.get_root_nodes();
        if !roots.is_empty() {
            return Some(roots[0].id);
        }

        // Fall back to node with most children and no parents
        let mut best_node = None;
        let mut max_children = 0;

        for node in graph.nodes() {
            if graph.get_parent(node.id).is_none() {
                let child_count = graph.get_children(node.id).len();
                if child_count > max_children {
                    max_children = child_count;
                    best_node = Some(node.id);
                }
            }
        }

        // If no parentless nodes found, find node with most children
        if best_node.is_none() {
            for node in graph.nodes() {
                let child_count = graph.get_children(node.id).len();
                if child_count > max_children {
                    max_children = child_count;
                    best_node = Some(node.id);
                }
            }
        }

        best_node
    }

    /// Build tree structure from graph
    fn build_tree(&self, graph: &Graph, root_id: NodeId) -> MindmapResult<TreeNode> {
        let mut visited = HashSet::new();
        self.build_tree_recursive(graph, root_id, &mut visited)
    }

    /// Recursively build tree structure
    fn build_tree_recursive(
        &self,
        graph: &Graph,
        node_id: NodeId,
        visited: &mut HashSet<NodeId>,
    ) -> MindmapResult<TreeNode> {
        if visited.contains(&node_id) {
            return Err(MindmapError::InvalidOperation {
                message: "Circular dependency detected in tree layout".to_string(),
            });
        }

        visited.insert(node_id);

        let mut children = Vec::new();
        for child in graph.get_children(node_id) {
            let child_tree = self.build_tree_recursive(graph, child.id, visited)?;
            children.push(child_tree);
        }

        visited.remove(&node_id);

        Ok(TreeNode {
            id: node_id,
            children,
            width: self.node_size,
            height: self.node_size, // Currently used for node spacing calculations
            x_offset: 0.0,
            y_offset: 0.0,
            subtree_width: 0.0,
        })
    }

    /// Calculate subtree dimensions and positions
    fn calculate_tree_layout(
        &self,
        tree: &mut TreeNode,
        horizontal_spacing: f64,
        vertical_spacing: f64,
    ) {
        // Calculate layout for all children first (post-order traversal)
        for child in &mut tree.children {
            self.calculate_tree_layout(child, horizontal_spacing, vertical_spacing);
        }

        if tree.children.is_empty() {
            // Leaf node
            tree.subtree_width = tree.width;
            return;
        }

        // Calculate total width needed for all children
        let mut total_children_width = 0.0;
        for (i, child) in tree.children.iter().enumerate() {
            total_children_width += child.subtree_width;
            if i > 0 {
                total_children_width += horizontal_spacing;
            }
        }

        // Set subtree width to maximum of node width and children width
        tree.subtree_width = tree.width.max(total_children_width);

        // Position children horizontally
        let mut current_x = -(tree.subtree_width / 2.0);

        // If children are narrower than parent, center them
        if total_children_width < tree.subtree_width {
            current_x += (tree.subtree_width - total_children_width) / 2.0;
        }

        for child in &mut tree.children {
            child.x_offset = current_x + child.subtree_width / 2.0;
            child.y_offset = vertical_spacing;
            current_x += child.subtree_width + horizontal_spacing;
        }

        // Balance subtrees if enabled
        if self.balance_subtrees && tree.children.len() > 1 {
            self.balance_tree_positions(tree);
        }
    }

    /// Balance positions of child subtrees for better visual distribution
    fn balance_tree_positions(&self, tree: &mut TreeNode) {
        if tree.children.len() <= 1 {
            return;
        }

        // Calculate the center of mass for better distribution
        let mut total_weight = 0.0;
        let mut weighted_position = 0.0;

        for child in &tree.children {
            let weight = self.calculate_subtree_weight(child);
            total_weight += weight;
            weighted_position += child.x_offset * weight;
        }

        if total_weight > 0.0 {
            let center_of_mass = weighted_position / total_weight;

            // Adjust positions to center the subtree
            let adjustment = -center_of_mass;
            for child in &mut tree.children {
                child.x_offset += adjustment;
            }
        }
    }

    /// Calculate weight of a subtree for balancing
    fn calculate_subtree_weight(&self, tree: &TreeNode) -> f64 {
        let mut weight = 1.0; // Weight of the node itself

        for child in &tree.children {
            weight += self.calculate_subtree_weight(child);
        }

        weight
    }

    /// Convert tree positions to absolute coordinates
    fn tree_to_positions(
        &self,
        tree: &TreeNode,
        positions: &mut HashMap<NodeId, Point>,
        base_x: f64,
        base_y: f64,
        orientation: TreeOrientation,
    ) {
        // Calculate absolute position for this node
        let (x, y) = self.transform_coordinates(
            base_x + tree.x_offset,
            base_y + tree.y_offset,
            orientation,
        );

        positions.insert(tree.id, Point::new(x, y));

        // Process children
        for child in &tree.children {
            self.tree_to_positions(
                child,
                positions,
                base_x + tree.x_offset,
                base_y + tree.y_offset,
                orientation,
            );
        }
    }

    /// Transform coordinates based on orientation
    fn transform_coordinates(&self, x: f64, y: f64, orientation: TreeOrientation) -> (f64, f64) {
        match orientation {
            TreeOrientation::TopDown => (x, y),
            TreeOrientation::BottomUp => (x, -y),
            TreeOrientation::LeftRight => (y, x),
            TreeOrientation::RightLeft => (-y, x),
        }
    }

    /// Scale and center the layout within canvas bounds
    fn scale_and_center_layout(
        &self,
        positions: &mut HashMap<NodeId, Point>,
        config: &LayoutConfig,
    ) {
        if positions.is_empty() {
            return;
        }

        // Calculate current bounds
        let all_points: Vec<Point> = positions.values().copied().collect();
        let current_bounds = LayoutBounds::from_points(&all_points);

        if !current_bounds.is_valid() {
            return;
        }

        // Calculate target bounds with margins
        let margin = 50.0;
        let target_bounds = LayoutBounds::new(
            margin,
            margin,
            config.canvas_width - margin,
            config.canvas_height - margin,
        );

        // Scale if necessary
        if !config.preserve_positions {
            utils::scale_to_fit(positions, &target_bounds);
        } else {
            // Just center without scaling
            let current_center = current_bounds.center();
            let target_center = config.center;
            let offset_x = target_center.x - current_center.x;
            let offset_y = target_center.y - current_center.y;

            for position in positions.values_mut() {
                position.x += offset_x;
                position.y += offset_y;
            }
        }
    }

    /// Apply minimum distance constraints
    fn apply_distance_constraints(
        &self,
        positions: &mut HashMap<NodeId, Point>,
        min_distance: f64,
    ) {
        let nodes: Vec<NodeId> = positions.keys().copied().collect();
        let mut adjusted = true;
        let mut iterations = 0;
        const MAX_ITERATIONS: usize = 20;

        while adjusted && iterations < MAX_ITERATIONS {
            adjusted = false;
            iterations += 1;

            for i in 0..nodes.len() {
                for j in i + 1..nodes.len() {
                    let node1 = nodes[i];
                    let node2 = nodes[j];

                    if let (Some(&pos1), Some(&pos2)) = (positions.get(&node1), positions.get(&node2)) {
                        let distance = utils::distance(&pos1, &pos2);

                        if distance < min_distance && distance > 0.0 {
                            let adjustment = (min_distance - distance) / 2.0;
                            let dx = pos2.x - pos1.x;
                            let dy = pos2.y - pos1.y;
                            let norm = distance;

                            if norm > 0.0 {
                                let unit_x = dx / norm;
                                let unit_y = dy / norm;

                                if let Some(p1) = positions.get_mut(&node1) {
                                    p1.x -= unit_x * adjustment;
                                    p1.y -= unit_y * adjustment;
                                }
                                if let Some(p2) = positions.get_mut(&node2) {
                                    p2.x += unit_x * adjustment;
                                    p2.y += unit_y * adjustment;
                                }

                                adjusted = true;
                            }
                        }
                    }
                }
            }
        }
    }
}

impl LayoutEngine for TreeLayoutEngine {
    fn calculate_layout(&self, graph: &Graph, config: &LayoutConfig) -> MindmapResult<LayoutResult> {
        self.validate_config(config)?;

        if graph.node_count() == 0 {
            return Ok(LayoutResult {
                positions: HashMap::new(),
                bounds: LayoutBounds::new(0.0, 0.0, 0.0, 0.0),
                converged: true,
                iterations: 1,
                energy: 0.0,
            });
        }

        // Find root node
        let root_id = self.find_root_node(graph)
            .ok_or_else(|| MindmapError::InvalidOperation {
                message: "No suitable root node found for tree layout".to_string(),
            })?;

        // Extract parameters
        let (orientation, horizontal_spacing, vertical_spacing, _node_size) =
            self.extract_parameters(config);

        // Build tree structure
        let mut tree = self.build_tree(graph, root_id)?;

        // Calculate tree layout
        self.calculate_tree_layout(&mut tree, horizontal_spacing, vertical_spacing);

        // Convert to absolute positions
        let mut positions = HashMap::new();
        self.tree_to_positions(&mut tree, &mut positions, 0.0, 0.0, orientation);

        // Apply distance constraints if needed
        if config.min_distance > 0.0 {
            self.apply_distance_constraints(&mut positions, config.min_distance);
        }

        // Scale and center within canvas
        self.scale_and_center_layout(&mut positions, config);

        // Calculate final bounds and energy
        let all_points: Vec<Point> = positions.values().copied().collect();
        let bounds = LayoutBounds::from_points(&all_points);

        // Calculate energy as total layout compactness (lower is better)
        let mut total_energy = 0.0;
        if bounds.is_valid() {
            total_energy = bounds.width() * bounds.height();
        }

        Ok(LayoutResult {
            positions,
            bounds,
            converged: true,
            iterations: 1,
            energy: total_energy,
        })
    }

    fn layout_type(&self) -> LayoutType {
        LayoutType::Tree
    }

    fn validate_config(&self, config: &LayoutConfig) -> MindmapResult<()> {
        // Call base validation
        if config.canvas_width <= 0.0 || config.canvas_height <= 0.0 {
            return Err(MindmapError::InvalidOperation {
                message: "Canvas dimensions must be positive".to_string(),
            });
        }

        if config.min_distance < 0.0 {
            return Err(MindmapError::InvalidOperation {
                message: "Minimum distance cannot be negative".to_string(),
            });
        }

        // Validate tree-specific parameters
        if let Some(&horizontal_spacing) = config.parameters.get("horizontal_spacing") {
            if horizontal_spacing < 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Horizontal spacing must be non-negative".to_string(),
                });
            }
        }

        if let Some(&vertical_spacing) = config.parameters.get("vertical_spacing") {
            if vertical_spacing <= 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Vertical spacing must be positive".to_string(),
                });
            }
        }

        if let Some(&node_size) = config.parameters.get("node_size") {
            if node_size <= 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Node size must be positive".to_string(),
                });
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Node;

    fn create_test_tree() -> Graph {
        let mut graph = Graph::new();

        // Create root node
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        // Create first level children
        let mut child_ids = Vec::new();
        for i in 1..=3 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            let child_id = child.id;
            child_ids.push(child_id);
            graph.add_node(child).unwrap();
        }

        // Create second level children
        for (i, &child_id) in child_ids.iter().enumerate() {
            for j in 1..=2 {
                let grandchild = Node::new_child(child_id, &format!("Grandchild {}-{}", i + 1, j));
                graph.add_node(grandchild).unwrap();
            }
        }

        graph
    }

    #[test]
    fn test_tree_layout_basic() {
        let graph = create_test_tree();
        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());
        assert!(layout.converged);
        assert!(layout.bounds.is_valid());
    }

    #[test]
    fn test_tree_layout_empty_graph() {
        let graph = Graph::new();
        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert!(layout.positions.is_empty());
    }

    #[test]
    fn test_tree_layout_single_node() {
        let mut graph = Graph::new();
        let node = Node::new("Single");
        graph.add_node(node).unwrap();

        let engine = TreeLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), 1);
    }

    #[test]
    fn test_tree_orientations() {
        let graph = create_test_tree();
        let config = LayoutConfig::default();

        let orientations = [
            TreeOrientation::TopDown,
            TreeOrientation::BottomUp,
            TreeOrientation::LeftRight,
            TreeOrientation::RightLeft,
        ];

        for orientation in &orientations {
            let engine = TreeLayoutEngine::new(*orientation, 80.0, 120.0);
            let result = engine.calculate_layout(&graph, &config);
            assert!(result.is_ok(), "Failed for orientation {:?}", orientation);

            let layout = result.unwrap();
            assert_eq!(layout.positions.len(), graph.node_count());
        }
    }

    #[test]
    fn test_tree_custom_spacing() {
        let graph = create_test_tree();
        let engine = TreeLayoutEngine::new(TreeOrientation::TopDown, 100.0, 150.0);

        let mut config = LayoutConfig::default();
        config.parameters.insert("horizontal_spacing".to_string(), 100.0);
        config.parameters.insert("vertical_spacing".to_string(), 150.0);

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        // Check that children are appropriately spaced
        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;
        let root_pos = layout.positions[&root_id];

        let children: Vec<_> = graph.get_children(root_id);
        if children.len() >= 2 {
            let pos1 = layout.positions[&children[0].id];
            let pos2 = layout.positions[&children[1].id];
            let distance = utils::distance(&pos1, &pos2);
            assert!(distance >= 80.0); // Should respect minimum spacing
        }

        // Check vertical spacing
        if !children.is_empty() {
            let child_pos = layout.positions[&children[0].id];
            let vertical_distance = (child_pos.y - root_pos.y).abs();
            assert!(vertical_distance >= 100.0); // Should respect vertical spacing
        }
    }

    #[test]
    fn test_tree_balancing() {
        let graph = create_test_tree();
        let engine_balanced = TreeLayoutEngine::default().with_balance_subtrees(true);
        let engine_unbalanced = TreeLayoutEngine::default().with_balance_subtrees(false);
        let config = LayoutConfig::default();

        let result_balanced = engine_balanced.calculate_layout(&graph, &config);
        let result_unbalanced = engine_unbalanced.calculate_layout(&graph, &config);

        assert!(result_balanced.is_ok());
        assert!(result_unbalanced.is_ok());

        // Both should produce valid layouts
        let layout_balanced = result_balanced.unwrap();
        let layout_unbalanced = result_unbalanced.unwrap();

        assert_eq!(layout_balanced.positions.len(), graph.node_count());
        assert_eq!(layout_unbalanced.positions.len(), graph.node_count());
    }

    #[test]
    fn test_layout_type() {
        let engine = TreeLayoutEngine::default();
        assert_eq!(engine.layout_type(), LayoutType::Tree);
    }

    #[test]
    fn test_config_validation() {
        let engine = TreeLayoutEngine::default();

        // Valid config should pass
        let config = LayoutConfig::default();
        assert!(engine.validate_config(&config).is_ok());

        // Invalid horizontal spacing
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("horizontal_spacing".to_string(), -10.0);
        assert!(engine.validate_config(&invalid_config).is_err());

        // Invalid vertical spacing
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("vertical_spacing".to_string(), 0.0);
        assert!(engine.validate_config(&invalid_config).is_err());

        // Invalid node size
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("node_size".to_string(), -5.0);
        assert!(engine.validate_config(&invalid_config).is_err());
    }

    #[test]
    fn test_coordinate_transformation() {
        let engine = TreeLayoutEngine::default();

        let (x, y) = engine.transform_coordinates(10.0, 20.0, TreeOrientation::TopDown);
        assert_eq!((x, y), (10.0, 20.0));

        let (x, y) = engine.transform_coordinates(10.0, 20.0, TreeOrientation::BottomUp);
        assert_eq!((x, y), (10.0, -20.0));

        let (x, y) = engine.transform_coordinates(10.0, 20.0, TreeOrientation::LeftRight);
        assert_eq!((x, y), (20.0, 10.0));

        let (x, y) = engine.transform_coordinates(10.0, 20.0, TreeOrientation::RightLeft);
        assert_eq!((x, y), (-20.0, 10.0));
    }

    #[test]
    fn test_tree_building() {
        let graph = create_test_tree();
        let engine = TreeLayoutEngine::default();

        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;

        let result = engine.build_tree(&graph, root_id);
        assert!(result.is_ok());

        let tree = result.unwrap();
        assert_eq!(tree.id, root_id);
        assert_eq!(tree.children.len(), 3); // 3 children

        // Each child should have 2 grandchildren
        for child in &tree.children {
            assert_eq!(child.children.len(), 2);
        }
    }

    #[test]
    fn test_subtree_weight_calculation() {
        let graph = create_test_tree();
        let engine = TreeLayoutEngine::default();

        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;

        let tree = engine.build_tree(&graph, root_id).unwrap();
        let weight = engine.calculate_subtree_weight(&tree);

        // Total nodes: 1 root + 3 children + 6 grandchildren = 10
        assert_eq!(weight, 10.0);
    }

    #[test]
    fn test_distance_constraints() {
        let graph = create_test_tree();
        let engine = TreeLayoutEngine::default();

        let mut config = LayoutConfig::default();
        config.min_distance = 100.0;

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // Check that distance constraints are respected (approximately)
        let positions: Vec<Point> = layout.positions.values().copied().collect();
        for i in 0..positions.len() {
            for j in i + 1..positions.len() {
                let distance = utils::distance(&positions[i], &positions[j]);
                // Allow some tolerance due to constraint solving
                assert!(distance >= 80.0, "Nodes too close: {} pixels", distance);
            }
        }
    }

    #[test]
    fn test_canvas_bounds() {
        let graph = create_test_tree();
        let engine = TreeLayoutEngine::default();

        let mut config = LayoutConfig::default();
        config.canvas_width = 500.0;
        config.canvas_height = 400.0;

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // All positions should be within canvas bounds (with margin)
        for position in layout.positions.values() {
            assert!(position.x >= 0.0);
            assert!(position.x <= 500.0);
            assert!(position.y >= 0.0);
            assert!(position.y <= 400.0);
        }
    }
}