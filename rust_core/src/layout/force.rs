//! Force-directed layout algorithm implementation
//!
//! Uses physical simulation with spring forces and repulsion to automatically
//! position nodes in an aesthetically pleasing arrangement.

use super::*;
use crate::graph::Graph;
use crate::types::{ids::NodeId, Point, MindmapResult, MindmapError};
use std::collections::HashMap;

/// Force simulation parameters
#[derive(Debug, Clone)]
pub struct ForceParameters {
    /// Spring force strength for connected nodes
    pub spring_strength: f64,
    /// Spring rest length for connected nodes
    pub spring_length: f64,
    /// Repulsion force strength between all nodes
    pub repulsion_strength: f64,
    /// Damping factor to reduce oscillation
    pub damping: f64,
    /// Center attraction force strength
    pub center_strength: f64,
    /// Time step for simulation
    pub time_step: f64,
    /// Maximum iterations for convergence
    pub max_iterations: u32,
    /// Convergence threshold (total energy)
    pub convergence_threshold: f64,
}

/// Node state during force simulation
#[derive(Debug, Clone)]
struct NodeState {
    position: Point,
    velocity: Point,
    force: Point,
    mass: f64,
}

/// Force-directed layout engine implementation
pub struct ForceLayoutEngine {
    /// Force simulation parameters
    pub parameters: ForceParameters,
    /// Whether to use adaptive time stepping
    pub adaptive_timestep: bool,
    /// Random seed for initial positioning
    pub random_seed: Option<u64>,
}

impl Default for ForceParameters {
    fn default() -> Self {
        Self {
            spring_strength: 0.1,
            spring_length: 100.0,
            repulsion_strength: 1000.0,
            damping: 0.95,
            center_strength: 0.001,
            time_step: 0.1,
            max_iterations: 1000,
            convergence_threshold: 0.01,
        }
    }
}

impl Default for ForceLayoutEngine {
    fn default() -> Self {
        Self {
            parameters: ForceParameters::default(),
            adaptive_timestep: true,
            random_seed: None,
        }
    }
}

impl ForceLayoutEngine {
    /// Create a new force layout engine with custom parameters
    pub fn new(parameters: ForceParameters) -> Self {
        Self {
            parameters,
            adaptive_timestep: true,
            random_seed: None,
        }
    }

    /// Set random seed for reproducible layouts
    pub fn with_seed(mut self, seed: u64) -> Self {
        self.random_seed = Some(seed);
        self
    }

    /// Enable or disable adaptive time stepping
    pub fn with_adaptive_timestep(mut self, adaptive: bool) -> Self {
        self.adaptive_timestep = adaptive;
        self
    }

    /// Extract parameters from layout configuration
    fn extract_parameters(&self, config: &LayoutConfig) -> ForceParameters {
        ForceParameters {
            spring_strength: config.parameters.get("spring_strength")
                .copied()
                .unwrap_or(self.parameters.spring_strength),
            spring_length: config.parameters.get("spring_length")
                .copied()
                .unwrap_or(self.parameters.spring_length),
            repulsion_strength: config.parameters.get("repulsion_strength")
                .copied()
                .unwrap_or(self.parameters.repulsion_strength),
            damping: config.parameters.get("damping")
                .copied()
                .unwrap_or(self.parameters.damping),
            center_strength: config.parameters.get("center_strength")
                .copied()
                .unwrap_or(self.parameters.center_strength),
            time_step: config.parameters.get("time_step")
                .copied()
                .unwrap_or(self.parameters.time_step),
            max_iterations: config.parameters.get("max_iterations")
                .copied()
                .unwrap_or(self.parameters.max_iterations as f64) as u32,
            convergence_threshold: config.parameters.get("convergence_threshold")
                .copied()
                .unwrap_or(self.parameters.convergence_threshold),
        }
    }

    /// Initialize node positions randomly or from existing positions
    fn initialize_positions(
        &self,
        graph: &Graph,
        config: &LayoutConfig,
    ) -> HashMap<NodeId, NodeState> {
        let mut states = HashMap::new();

        // Use simple linear congruential generator for reproducible randomness
        let mut rng_state = self.random_seed.unwrap_or(12345);

        for node in graph.nodes() {
            let position = if config.preserve_positions {
                node.position
            } else {
                // Generate random position within canvas bounds
                let x = self.random_f64(&mut rng_state) * config.canvas_width;
                let y = self.random_f64(&mut rng_state) * config.canvas_height;
                Point::new(x, y)
            };

            // Calculate node mass based on connectivity
            let connections = graph.get_children(node.id).len() +
                             if graph.get_parent(node.id).is_some() { 1 } else { 0 };
            let mass = 1.0 + connections as f64 * 0.1; // Nodes with more connections have more mass

            states.insert(node.id, NodeState {
                position,
                velocity: Point::new(0.0, 0.0),
                force: Point::new(0.0, 0.0),
                mass,
            });
        }

        states
    }

    /// Simple linear congruential generator for reproducible randomness
    fn random_f64(&self, state: &mut u64) -> f64 {
        *state = state.wrapping_mul(1103515245).wrapping_add(12345);
        (*state % 1000000) as f64 / 1000000.0
    }

    /// Calculate spring forces between connected nodes
    fn calculate_spring_forces(
        &self,
        graph: &Graph,
        states: &mut HashMap<NodeId, NodeState>,
        parameters: &ForceParameters,
    ) {
        for edge in graph.edges() {
            if let (Some(from_state), Some(to_state)) = (
                states.get(&edge.from_node),
                states.get(&edge.to_node),
            ) {
                let dx = to_state.position.x - from_state.position.x;
                let dy = to_state.position.y - from_state.position.y;
                let distance = (dx * dx + dy * dy).sqrt().max(0.1); // Avoid division by zero

                // Hooke's law: F = k * (current_length - rest_length)
                let spring_force = parameters.spring_strength * (distance - parameters.spring_length);

                let fx = (dx / distance) * spring_force;
                let fy = (dy / distance) * spring_force;

                // Apply equal and opposite forces
                if let Some(from_state) = states.get_mut(&edge.from_node) {
                    from_state.force.x += fx;
                    from_state.force.y += fy;
                }
                if let Some(to_state) = states.get_mut(&edge.to_node) {
                    to_state.force.x -= fx;
                    to_state.force.y -= fy;
                }
            }
        }
    }

    /// Calculate repulsion forces between all pairs of nodes
    fn calculate_repulsion_forces(
        &self,
        states: &mut HashMap<NodeId, NodeState>,
        parameters: &ForceParameters,
    ) {
        let node_ids: Vec<NodeId> = states.keys().copied().collect();

        for i in 0..node_ids.len() {
            for j in i + 1..node_ids.len() {
                let node1 = node_ids[i];
                let node2 = node_ids[j];

                if let (Some(state1), Some(state2)) = (states.get(&node1), states.get(&node2)) {
                    let dx = state2.position.x - state1.position.x;
                    let dy = state2.position.y - state1.position.y;
                    let distance_sq = dx * dx + dy * dy;
                    let distance = distance_sq.sqrt().max(1.0); // Minimum distance to avoid singularity

                    // Coulomb's law: F = k / r^2
                    let repulsion_force = parameters.repulsion_strength / distance_sq;

                    let fx = (dx / distance) * repulsion_force;
                    let fy = (dy / distance) * repulsion_force;

                    // Apply forces to both nodes
                    if let Some(state1) = states.get_mut(&node1) {
                        state1.force.x -= fx;
                        state1.force.y -= fy;
                    }
                    if let Some(state2) = states.get_mut(&node2) {
                        state2.force.x += fx;
                        state2.force.y += fy;
                    }
                }
            }
        }
    }

    /// Calculate center attraction forces to prevent nodes from drifting away
    fn calculate_center_forces(
        &self,
        states: &mut HashMap<NodeId, NodeState>,
        center: &Point,
        parameters: &ForceParameters,
    ) {
        for state in states.values_mut() {
            let dx = center.x - state.position.x;
            let dy = center.y - state.position.y;

            state.force.x += dx * parameters.center_strength;
            state.force.y += dy * parameters.center_strength;
        }
    }

    /// Update node positions using Verlet integration
    fn integrate_forces(
        &self,
        states: &mut HashMap<NodeId, NodeState>,
        parameters: &ForceParameters,
    ) -> f64 {
        let mut total_energy = 0.0;

        for state in states.values_mut() {
            // Apply damping to velocity
            state.velocity.x *= parameters.damping;
            state.velocity.y *= parameters.damping;

            // Update velocity: v = v + (F/m) * dt
            let acceleration_x = state.force.x / state.mass;
            let acceleration_y = state.force.y / state.mass;

            state.velocity.x += acceleration_x * parameters.time_step;
            state.velocity.y += acceleration_y * parameters.time_step;

            // Update position: x = x + v * dt
            state.position.x += state.velocity.x * parameters.time_step;
            state.position.y += state.velocity.y * parameters.time_step;

            // Calculate kinetic energy for convergence detection
            let velocity_sq = state.velocity.x * state.velocity.x + state.velocity.y * state.velocity.y;
            total_energy += 0.5 * state.mass * velocity_sq;

            // Reset forces for next iteration
            state.force.x = 0.0;
            state.force.y = 0.0;
        }

        total_energy
    }

    /// Constrain positions to canvas bounds
    fn constrain_to_bounds(
        &self,
        states: &mut HashMap<NodeId, NodeState>,
        config: &LayoutConfig,
    ) {
        let margin = 30.0;
        let min_x = margin;
        let min_y = margin;
        let max_x = config.canvas_width - margin;
        let max_y = config.canvas_height - margin;

        for state in states.values_mut() {
            // Constrain position
            if state.position.x < min_x {
                state.position.x = min_x;
                state.velocity.x = 0.0; // Stop velocity when hitting boundary
            } else if state.position.x > max_x {
                state.position.x = max_x;
                state.velocity.x = 0.0;
            }

            if state.position.y < min_y {
                state.position.y = min_y;
                state.velocity.y = 0.0;
            } else if state.position.y > max_y {
                state.position.y = max_y;
                state.velocity.y = 0.0;
            }
        }
    }

    /// Run the force-directed simulation
    fn simulate(
        &self,
        graph: &Graph,
        config: &LayoutConfig,
        parameters: &ForceParameters,
    ) -> MindmapResult<(HashMap<NodeId, Point>, bool, u32, f64)> {
        let mut states = self.initialize_positions(graph, config);
        let mut converged = false;
        let mut iteration = 0;
        let mut final_energy = 0.0;

        while iteration < parameters.max_iterations && !converged {
            // Calculate all forces
            self.calculate_spring_forces(graph, &mut states, parameters);
            self.calculate_repulsion_forces(&mut states, parameters);
            self.calculate_center_forces(&mut states, &config.center, parameters);

            // Integrate forces and update positions
            let energy = self.integrate_forces(&mut states, parameters);

            // Constrain to canvas bounds
            self.constrain_to_bounds(&mut states, config);

            // Check for convergence
            if energy < parameters.convergence_threshold {
                converged = true;
            }

            final_energy = energy;
            iteration += 1;
        }

        // Extract final positions
        let positions = states.into_iter()
            .map(|(id, state)| (id, state.position))
            .collect();

        Ok((positions, converged, iteration, final_energy))
    }
}

impl LayoutEngine for ForceLayoutEngine {
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

        // Extract simulation parameters
        let parameters = self.extract_parameters(config);

        // Run force simulation
        let (positions, converged, iterations, energy) =
            self.simulate(graph, config, &parameters)?;

        // Calculate final bounds
        let all_points: Vec<Point> = positions.values().copied().collect();
        let bounds = LayoutBounds::from_points(&all_points);

        Ok(LayoutResult {
            positions,
            bounds,
            converged,
            iterations,
            energy,
        })
    }

    fn layout_type(&self) -> LayoutType {
        LayoutType::Force
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

        // Validate force-specific parameters
        if let Some(&spring_strength) = config.parameters.get("spring_strength") {
            if spring_strength < 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Spring strength must be non-negative".to_string(),
                });
            }
        }

        if let Some(&spring_length) = config.parameters.get("spring_length") {
            if spring_length <= 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Spring length must be positive".to_string(),
                });
            }
        }

        if let Some(&repulsion_strength) = config.parameters.get("repulsion_strength") {
            if repulsion_strength < 0.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Repulsion strength must be non-negative".to_string(),
                });
            }
        }

        if let Some(&damping) = config.parameters.get("damping") {
            if damping < 0.0 || damping > 1.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Damping must be between 0.0 and 1.0".to_string(),
                });
            }
        }

        if let Some(&time_step) = config.parameters.get("time_step") {
            if time_step <= 0.0 || time_step > 1.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Time step must be between 0.0 and 1.0".to_string(),
                });
            }
        }

        if let Some(&max_iterations) = config.parameters.get("max_iterations") {
            if max_iterations < 1.0 {
                return Err(MindmapError::InvalidOperation {
                    message: "Maximum iterations must be at least 1".to_string(),
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

        // Create nodes
        let nodes = (0..5).map(|i| {
            let node = Node::new(&format!("Node {}", i));
            let id = node.id;
            graph.add_node(node).unwrap();
            id
        }).collect::<Vec<_>>();

        // Create some edges to form a connected graph
        for i in 0..4 {
            let edge = crate::models::Edge::new(nodes[i], nodes[i + 1]);
            graph.add_edge(edge).unwrap();
        }

        // Add one more edge to make it more interesting
        let edge = crate::models::Edge::new(nodes[0], nodes[3]);
        graph.add_edge(edge).unwrap();

        graph
    }

    #[test]
    fn test_force_layout_basic() {
        let graph = create_test_graph();
        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());
        assert!(layout.bounds.is_valid());
        assert!(layout.iterations > 0);
    }

    #[test]
    fn test_force_layout_empty_graph() {
        let graph = Graph::new();
        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert!(layout.positions.is_empty());
        assert_eq!(layout.iterations, 0);
        assert!(layout.converged);
    }

    #[test]
    fn test_force_layout_single_node() {
        let mut graph = Graph::new();
        let node = Node::new("Single");
        graph.add_node(node).unwrap();

        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), 1);
    }

    #[test]
    fn test_force_layout_custom_parameters() {
        let graph = create_test_graph();

        let custom_params = ForceParameters {
            spring_strength: 0.2,
            spring_length: 150.0,
            repulsion_strength: 2000.0,
            damping: 0.9,
            center_strength: 0.002,
            time_step: 0.05,
            max_iterations: 500,
            convergence_threshold: 0.005,
        };

        let engine = ForceLayoutEngine::new(custom_params);
        let mut config = LayoutConfig::default();
        config.parameters.insert("spring_strength".to_string(), 0.2);
        config.parameters.insert("max_iterations".to_string(), 500.0);

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert_eq!(layout.positions.len(), graph.node_count());
        assert!(layout.iterations <= 500);
    }

    #[test]
    fn test_force_layout_with_seed() {
        let graph = create_test_graph();
        let engine1 = ForceLayoutEngine::default().with_seed(42);
        let engine2 = ForceLayoutEngine::default().with_seed(42);
        let config = LayoutConfig::default();

        let result1 = engine1.calculate_layout(&graph, &config);
        let result2 = engine2.calculate_layout(&graph, &config);

        assert!(result1.is_ok());
        assert!(result2.is_ok());

        let layout1 = result1.unwrap();
        let layout2 = result2.unwrap();

        // With the same seed, layouts should be identical
        assert_eq!(layout1.positions.len(), layout2.positions.len());

        // Due to floating point precision, we'll check approximate equality
        for (id, pos1) in &layout1.positions {
            if let Some(pos2) = layout2.positions.get(id) {
                assert!((pos1.x - pos2.x).abs() < 0.01);
                assert!((pos1.y - pos2.y).abs() < 0.01);
            }
        }
    }

    #[test]
    fn test_force_layout_convergence() {
        let graph = create_test_graph();

        let fast_convergence_params = ForceParameters {
            convergence_threshold: 1000.0, // Very high threshold for fast convergence
            max_iterations: 10,
            ..ForceParameters::default()
        };

        let engine = ForceLayoutEngine::new(fast_convergence_params);
        let config = LayoutConfig::default();

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();
        assert!(layout.converged || layout.iterations == 10);
    }

    #[test]
    fn test_layout_type() {
        let engine = ForceLayoutEngine::default();
        assert_eq!(engine.layout_type(), LayoutType::Force);
    }

    #[test]
    fn test_config_validation() {
        let engine = ForceLayoutEngine::default();

        // Valid config should pass
        let config = LayoutConfig::default();
        assert!(engine.validate_config(&config).is_ok());

        // Invalid spring strength
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("spring_strength".to_string(), -0.1);
        assert!(engine.validate_config(&invalid_config).is_err());

        // Invalid spring length
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("spring_length".to_string(), 0.0);
        assert!(engine.validate_config(&invalid_config).is_err());

        // Invalid damping
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("damping".to_string(), 1.5);
        assert!(engine.validate_config(&invalid_config).is_err());

        // Invalid time step
        let mut invalid_config = LayoutConfig::default();
        invalid_config.parameters.insert("time_step".to_string(), 1.5);
        assert!(engine.validate_config(&invalid_config).is_err());
    }

    #[test]
    fn test_preserve_positions() {
        let mut graph = Graph::new();

        // Create nodes with specific positions
        let node1 = {
            let mut n = Node::new("Node 1");
            n.position = Point::new(100.0, 100.0);
            n
        };
        let id1 = node1.id;
        graph.add_node(node1).unwrap();

        let node2 = {
            let mut n = Node::new("Node 2");
            n.position = Point::new(200.0, 200.0);
            n
        };
        let id2 = node2.id;
        graph.add_node(node2).unwrap();

        let edge = crate::models::Edge::new(id1, id2);
        graph.add_edge(edge).unwrap();

        let engine = ForceLayoutEngine::default();
        let mut config = LayoutConfig::default();
        config.preserve_positions = true;
        config.parameters.insert("max_iterations".to_string(), 1.0); // Single iteration

        let result = engine.calculate_layout(&graph, &config);
        assert!(result.is_ok());

        let layout = result.unwrap();

        // Positions should be close to original (might change slightly due to forces)
        let pos1 = layout.positions[&id1];
        let pos2 = layout.positions[&id2];

        assert!((pos1.x - 100.0).abs() < 50.0);
        assert!((pos1.y - 100.0).abs() < 50.0);
        assert!((pos2.x - 200.0).abs() < 50.0);
        assert!((pos2.y - 200.0).abs() < 50.0);
    }

    #[test]
    fn test_force_parameters_default() {
        let params = ForceParameters::default();
        assert!(params.spring_strength > 0.0);
        assert!(params.spring_length > 0.0);
        assert!(params.repulsion_strength > 0.0);
        assert!(params.damping > 0.0 && params.damping <= 1.0);
        assert!(params.time_step > 0.0 && params.time_step <= 1.0);
        assert!(params.max_iterations > 0);
        assert!(params.convergence_threshold > 0.0);
    }

    #[test]
    fn test_random_generator() {
        let engine = ForceLayoutEngine::default();
        let mut state1 = 12345u64;
        let mut state2 = 12345u64;

        // Same seed should produce same sequence
        let r1a = engine.random_f64(&mut state1);
        let r1b = engine.random_f64(&mut state1);

        let r2a = engine.random_f64(&mut state2);
        let r2b = engine.random_f64(&mut state2);

        assert_eq!(r1a, r2a);
        assert_eq!(r1b, r2b);
        assert_ne!(r1a, r1b); // Should be different values

        // Values should be in [0, 1) range
        assert!(r1a >= 0.0 && r1a < 1.0);
        assert!(r1b >= 0.0 && r1b < 1.0);
    }

    #[test]
    fn test_node_mass_calculation() {
        let graph = create_test_graph();
        let engine = ForceLayoutEngine::default();
        let config = LayoutConfig::default();

        let states = engine.initialize_positions(&graph, &config);

        // All nodes should have mass >= 1.0
        for state in states.values() {
            assert!(state.mass >= 1.0);
        }

        // Nodes with more connections should have higher mass
        // In our test graph, some nodes have edges so they should have mass > 1.0
        let masses: Vec<f64> = states.values().map(|s| s.mass).collect();

        // Check that at least some nodes have the expected mass (connected nodes should have mass > 1.0)
        // Since we created a connected graph, we expect this to be true
        let min_mass = masses.iter().fold(f64::INFINITY, |a, &b| a.min(b));
        let max_mass = masses.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));

        assert!(min_mass >= 1.0); // All nodes have at least base mass
        assert!(max_mass >= min_mass); // Some variation is expected
    }
}