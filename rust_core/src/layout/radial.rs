//! Radial layout algorithm implementation
//!
//! Positions nodes in concentric circles around a root node using polar coordinates.
//! Child nodes are distributed evenly around their parent at calculated radii.

use super::*;
use crate::graph::Graph;
use crate::types::{ids::NodeId, Point, MindmapResult, MindmapError};
use std::collections::{HashMap, HashSet, VecDeque};
use std::f64::consts::PI;

/// Radial layout engine implementation
pub struct RadialLayoutEngine {
    /// Base radius for first level children
    pub base_radius: f64,
    /// Radius increment between levels
    pub radius_increment: f64,
    /// Minimum angle between siblings (in radians)
    pub min_angle: f64,
    /// Maximum depth to layout
    pub max_depth: Option<usize>,
}

impl Default for RadialLayoutEngine {
    fn default() -> Self {
        Self {
            base_radius: 150.0,
            radius_increment: 100.0,
            min_angle: PI / 12.0, // 15 degrees
            max_depth: None,
        }
    }
}

impl RadialLayoutEngine {
    /// Create a new radial layout engine with custom parameters
    pub fn new(base_radius: f64, radius_increment: f64, min_angle: f64) -> Self {
        Self {
            base_radius,
            radius_increment,
            min_angle,
            max_depth: None,
        }
    }

    /// Set maximum layout depth
    pub fn with_max_depth(mut self, max_depth: usize) -> Self {
        self.max_depth = Some(max_depth);
        self
    }

    /// Calculate optimal radius for a level with given child count
    fn calculate_level_radius(&self, level: usize, child_count: usize, node_size: f64) -> f64 {
        if child_count <= 1 {
            return self.base_radius + level as f64 * self.radius_increment;
        }

        // Calculate radius needed to maintain minimum angle between children
        let required_radius = (node_size + 20.0) / (2.0 * (self.min_angle / 2.0).sin());
        let default_radius = self.base_radius + level as f64 * self.radius_increment;

        required_radius.max(default_radius)
    }

    /// Get layout parameters from config
    fn extract_parameters(&self, config: &LayoutConfig) -> (f64, f64, f64) {
        let base_radius = config.parameters.get("base_radius")
            .copied()
            .unwrap_or(self.base_radius);

        let radius_increment = config.parameters.get("radius_increment")
            .copied()
            .unwrap_or(self.radius_increment);

        let min_angle = config.parameters.get("min_angle")
            .copied()
            .unwrap_or(self.min_angle);

        (base_radius, radius_increment, min_angle)
    }

    /// Find the best root node for radial layout
    fn find_root_node(&self, graph: &Graph) -> Option<NodeId> {
        // Prefer explicitly marked root nodes
        let roots = graph.get_root_nodes();
        if !roots.is_empty() {
            return Some(roots[0].id);
        }

        // Fall back to node with most connections
        let mut best_node = None;
        let mut max_connections = 0;

        for node in graph.nodes() {
            let children_count = graph.get_children(node.id).len();
            let parent_count = if graph.get_parent(node.id).is_some() { 1 } else { 0 };
            let connections = children_count + parent_count;

            if connections > max_connections {
                max_connections = connections;
                best_node = Some(node.id);
            }
        }

        best_node
    }

    /// Build level structure for radial layout
    fn build_levels(&self, graph: &Graph, root_id: NodeId) -> HashMap<usize, Vec<NodeId>> {
        let mut levels = HashMap::new();
        let mut visited = HashSet::new();
        let mut queue = VecDeque::new();

        // Start with root at level 0
        queue.push_back((root_id, 0));
        visited.insert(root_id);

        while let Some((node_id, level)) = queue.pop_front() {
            // Check max depth limit
            if let Some(max_depth) = self.max_depth {
                if level > max_depth {
                    continue;
                }
            }

            // Add node to its level
            levels.entry(level).or_insert_with(Vec::new).push(node_id);

            // Add children to next level
            for child in graph.get_children(node_id) {
                if !visited.contains(&child.id) {
                    visited.insert(child.id);
                    queue.push_back((child.id, level + 1));
                }
            }
        }

        levels
    }

    /// Calculate positions for nodes at a specific level
    fn position_level(
        &self,
        graph: &Graph,
        level: usize,
        nodes: &[NodeId],
        positions: &mut HashMap<NodeId, Point>,
        center: &Point,
        config: &LayoutConfig,
    ) -> MindmapResult<()> {
        if nodes.is_empty() {
            return Ok(());
        }

        let (_base_radius, _radius_increment, _min_angle) = self.extract_parameters(config);

        // Root node goes at center
        if level == 0 {
            if let Some(&root_id) = nodes.first() {
                positions.insert(root_id, *center);
            }
            return Ok(());
        }

        // Group nodes by their parent
        let mut parent_groups: HashMap<NodeId, Vec<NodeId>> = HashMap::new();
        for &node_id in nodes {
            if let Some(parent) = graph.get_parent(node_id) {
                parent_groups.entry(parent.id).or_insert_with(Vec::new).push(node_id);
            }
        }

        // Position each group around its parent
        for (parent_id, children) in parent_groups {
            let parent_pos = positions.get(&parent_id)
                .copied()
                .unwrap_or(*center);

            let child_count = children.len();
            if child_count == 0 {
                continue;
            }

            // Calculate radius for this level
            let node_size = config.parameters.get("node_size").copied().unwrap_or(40.0);
            let radius = self.calculate_level_radius(level, child_count, node_size);

            // Distribute children evenly around the circle
            let start_angle = config.parameters.get("start_angle").copied().unwrap_or(0.0);
            let angles = utils::distribute_angles(child_count, start_angle);

            for (i, &child_id) in children.iter().enumerate() {
                let angle = angles[i];
                let position = utils::polar_to_cartesian(radius, angle, &parent_pos);
                positions.insert(child_id, position);
            }
        }

        Ok(())
    }

    /// Apply collision detection and resolution
    fn resolve_collisions(
        &self,
        positions: &mut HashMap<NodeId, Point>,
        config: &LayoutConfig,
    ) {
        let min_distance = config.min_distance;
        let node_size = config.parameters.get("node_size").copied().unwrap_or(40.0);
        let min_separation = (min_distance + node_size).max(50.0);

        let nodes: Vec<NodeId> = positions.keys().copied().collect();
        let mut moved_any = true;
        let mut iterations = 0;
        const MAX_ITERATIONS: usize = 50;

        while moved_any && iterations < MAX_ITERATIONS {
            moved_any = false;
            iterations += 1;

            for i in 0..nodes.len() {
                for j in i + 1..nodes.len() {
                    let node1 = nodes[i];
                    let node2 = nodes[j];

                    if let (Some(&pos1), Some(&pos2)) = (positions.get(&node1), positions.get(&node2)) {
                        let distance = utils::distance(&pos1, &pos2);

                        if distance < min_separation && distance > 0.0 {
                            // Calculate repulsion vector
                            let dx = pos2.x - pos1.x;
                            let dy = pos2.y - pos1.y;
                            let repulsion_strength = (min_separation - distance) / 2.0;

                            let norm = (dx * dx + dy * dy).sqrt();
                            if norm > 0.0 {
                                let unit_x = dx / norm;
                                let unit_y = dy / norm;

                                // Move both nodes apart
                                if let Some(p1) = positions.get_mut(&node1) {
                                    p1.x -= unit_x * repulsion_strength;
                                    p1.y -= unit_y * repulsion_strength;
                                }
                                if let Some(p2) = positions.get_mut(&node2) {
                                    p2.x += unit_x * repulsion_strength;
                                    p2.y += unit_y * repulsion_strength;
                                }

                                moved_any = true;
                            }
                        }
                    }
                }
            }
        }
    }

    /// Ensure all positions are within canvas bounds
    fn constrain_to_canvas(
        &self,
        positions: &mut HashMap<NodeId, Point>,
        config: &LayoutConfig,
    ) {
        let margin = 50.0;
        let min_x = margin;
        let min_y = margin;
        let max_x = config.canvas_width - margin;
        let max_y = config.canvas_height - margin;

        for position in positions.values_mut() {
            position.x = position.x.clamp(min_x, max_x);
            position.y = position.y.clamp(min_y, max_y);
        }
    }
}

impl LayoutEngine for RadialLayoutEngine {
    fn calculate_layout(&self, graph: &Graph, config: &LayoutConfig) -> MindmapResult<LayoutResult> {
        self.validate_config(config)?;

        if graph.node_count() == 0 {
            return Ok(LayoutResult {
                positions: HashMap::new(),
                bounds: LayoutBounds::new(0.0, 0.0, 0.0, 0.0),
                converged: true,
                iterations: 0,
                energy: 0.0,
            });
        }

        // Find root node
        let root_id = self.find_root_node(graph)
            .ok_or_else(|| MindmapError::InvalidOperation {
                message: "No suitable root node found for radial layout".to_string(),
            })?;

        // Build level structure
        let levels = self.build_levels(graph, root_id);
        let mut positions = HashMap::new();

        // Position nodes level by level
        let max_level = levels.keys().copied().max().unwrap_or(0);
        for level in 0..=max_level {
            if let Some(nodes) = levels.get(&level) {
                self.position_level(graph, level, nodes, &mut positions, &config.center, config)?;
            }
        }

        // Apply collision detection if requested
        if config.parameters.get("resolve_collisions").copied().unwrap_or(1.0) > 0.0 {
            self.resolve_collisions(&mut positions, config);
        }

        // Constrain to canvas bounds
        self.constrain_to_canvas(&mut positions, config);

        // Calculate final bounds and energy
        let all_points: Vec<Point> = positions.values().copied().collect();
        let bounds = LayoutBounds::from_points(&all_points);

        // Calculate energy as sum of edge lengths (lower is better)
        let mut total_energy = 0.0;
        for edge in graph.edges() {
            if let (Some(&pos1), Some(&pos2)) = (positions.get(&edge.from_node), positions.get(&edge.to_node)) {
                total_energy += utils::distance(&pos1, &pos2);
            }
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
        LayoutType::Radial
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

        // Validate radial-specific parameters
        if let Some(&base_radius) = config.parameters.get("base_radius") {
            if base_radius <= 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Base radius must be positive".to_string(),
                });
            }
        }

        if let Some(&radius_increment) = config.parameters.get("radius_increment") {
            if radius_increment <= 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Radius increment must be positive".to_string(),
                });
            }
        }

        if let Some(&min_angle) = config.parameters.get("min_angle") {
            if min_angle <= 0.0 || min_angle >= PI {
                return Err(MindmapError::InvalidOperation {
                    message: "Minimum angle must be between 0 and π radians".to_string(),
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

    fn create_test_graph() -> Graph {
        let mut graph = Graph::new();

        // Create root node
        let root = Node::new("Root");
        let root_id = root.id;
        graph.add_node(root).unwrap();

        // Create first level children
        for i in 1..=4 {
            let child = Node::new_child(root_id, &format!("Child {}", i));
            let child_id = child.id;
            graph.add_node(child).unwrap();

            // Add some second level children
            if i <= 2 {
                for j in 1..=3 {
                    let grandchild = Node::new_child(child_id, &format!("Grandchild {}-{}", i, j));
                    graph.add_node(grandchild).unwrap();
                }
            }
        }

        graph
    }

    #[test]
    fn test_radial_layout_basic() {
        let graph = create_test_graph();
        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());
        assert!(layout.converged);
        assert!(layout.bounds.is_valid());
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
    }

    #[test]
    fn test_radial_layout_single_node() {
        let mut graph = Graph::new();
        let node = Node::new("Single");
        graph.add_node(node).unwrap();

        let engine = RadialLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), 1);

        // Single node should be at center
        let position = layout.positions.values().next().unwrap();
        assert!((position.x - config.center.x).abs() < 1.0);
        assert!((position.y - config.center.y).abs() < 1.0);
    }

    #[test]
    fn test_radial_layout_custom_parameters() {
        let graph = create_test_graph();
        let engine = RadialLayoutEngine::new(200.0, 80.0, PI / 8.0);

        let mut config = LayoutConfig::default();
        config.parameters.insert("base_radius".to_string(), 200.0);
        config.parameters.insert("radius_increment".to_string(), 80.0);
        config.parameters.insert("min_angle".to_string(), PI / 8.0);

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());

        // Check that children are positioned away from root
        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;
        let root_pos = layout.positions[&root_id];

        for child in graph.get_children(root_id) {
            let child_pos = layout.positions[&child.id];
            let distance = utils::distance(&root_pos, &child_pos);
            assert!(distance > 0.0); // Children should not be at the same position as root
        }
    }

    #[test]
    fn test_radial_layout_with_max_depth() {
        let graph = create_test_graph();
        let engine = RadialLayoutEngine::default().with_max_depth(1);
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // Should only position root and first level children (not grandchildren)
        assert!(layout.positions.len() <= 5); // 1 root + 4 children max
    }

    #[test]
    fn test_radial_layout_collision_resolution() {
        let graph = create_test_graph();
        let engine = RadialLayoutEngine::default();

        let mut config = LayoutConfig::default();
        config.min_distance = 60.0;
        config.parameters.insert("resolve_collisions".to_string(), 1.0);
        config.parameters.insert("node_size".to_string(), 30.0);

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // Check that no two nodes are too close
        let positions: Vec<Point> = layout.positions.values().copied().collect();
        for i in 0..positions.len() {
            for j in i + 1..positions.len() {
                let distance = utils::distance(&positions[i], &positions[j]);
                // Allow some tolerance for collision resolution
                assert!(distance >= 50.0, "Nodes too close: {} pixels", distance);
            }
        }
    }

    #[test]
    fn test_layout_type() {
        let engine = RadialLayoutEngine::default();
        assert_eq!(engine.layout_type(), LayoutType::Radial);
    }

    #[test]
    fn test_config_validation() {
        let engine = RadialLayoutEngine::default();

        // Valid config should pass
        let config = LayoutConfig::default();
        assert!(engine.validate_config(&config).is_ok());

        // Invalid base radius
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("base_radius".to_string(), -10.0);
        assert!(engine.validate_config(&invalid_config).is_err());

        // Invalid min angle
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("min_angle".to_string(), PI + 1.0);
        assert!(engine.validate_config(&invalid_config).is_err());
    }

    #[test]
    fn test_level_building() {
        let graph = create_test_graph();
        let engine = RadialLayoutEngine::default();

        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;

        let levels = engine.build_levels(&graph, root_id);

        // Should have 3 levels: root, children, grandchildren
        assert_eq!(levels.len(), 3);
        assert_eq!(levels[&0].len(), 1); // 1 root
        assert_eq!(levels[&1].len(), 4); // 4 children
        assert_eq!(levels[&2].len(), 6); // 6 grandchildren (3 each for first 2 children)
    }

    #[test]
    fn test_radius_calculation() {
        let engine = RadialLayoutEngine::default();

        // Single child should use base radius
        let radius1 = engine.calculate_level_radius(1, 1, 40.0);
        assert!((radius1 - (engine.base_radius + engine.radius_increment)).abs() < 1.0);

        // Multiple children should use larger radius if needed
        let radius4 = engine.calculate_level_radius(1, 8, 40.0);
        assert!(radius4 >= engine.base_radius + engine.radius_increment);
    }

    #[test]
    fn test_canvas_constraints() {
        let graph = create_test_graph();
        let engine = RadialLayoutEngine::default();

        let mut config = LayoutConfig::default();
        config.canvas_width = 400.0;
        config.canvas_height = 300.0;

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // All positions should be within canvas bounds (with margin)
        for position in layout.positions.values() {
            assert!(position.x >= 50.0);
            assert!(position.x <= 350.0);
            assert!(position.y >= 50.0);
            assert!(position.y <= 250.0);
        }
    }
}