//! Layout algorithms for node positioning
//!
//! This module provides various layout algorithms for automatically
//! positioning nodes in a mindmap for optimal visualization.

pub mod radial;
pub mod tree;
pub mod force;

pub use radial::*;
pub use tree::*;
pub use force::*;

use crate::graph::Graph;
use crate::types::{ids::NodeId, Point, MindmapResult, MindmapError};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Layout configuration options
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LayoutConfig {
    /// Canvas width
    pub canvas_width: f64,
    /// Canvas height
    pub canvas_height: f64,
    /// Center point of the layout
    pub center: Point,
    /// Animation duration in milliseconds
    pub animation_duration: u32,
    /// Whether to respect existing node positions
    pub preserve_positions: bool,
    /// Minimum distance between nodes
    pub min_distance: f64,
    /// Layout-specific parameters
    pub parameters: HashMap<String, f64>,
}

/// Result of a layout calculation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LayoutResult {
    /// New positions for nodes
    pub positions: HashMap<NodeId, Point>,
    /// Layout bounds (min/max coordinates)
    pub bounds: LayoutBounds,
    /// Whether the layout converged (for iterative algorithms)
    pub converged: bool,
    /// Number of iterations performed
    pub iterations: u32,
    /// Total energy/cost of the layout
    pub energy: f64,
}

/// Layout bounds information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LayoutBounds {
    pub min_x: f64,
    pub min_y: f64,
    pub max_x: f64,
    pub max_y: f64,
}

/// Layout algorithm type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LayoutType {
    /// Radial layout from a center node
    Radial,
    /// Hierarchical tree layout
    Tree,
    /// Force-directed layout
    Force,
}

/// Core trait for layout algorithms
pub trait LayoutEngine {
    /// Calculate layout for the given graph
    fn calculate_layout(&self, graph: &Graph, config: &LayoutConfig) -> MindmapResult<LayoutResult>;

    /// Get the layout type
    fn layout_type(&self) -> LayoutType;

    /// Validate configuration for this layout type
    fn validate_config(&self, config: &LayoutConfig) -> MindmapResult<()> {
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

        Ok(())
    }

    /// Apply the layout result to the graph
    fn apply_layout(&self, graph: &mut Graph, result: &LayoutResult) -> MindmapResult<()> {
        for (node_id, position) in &result.positions {
            if let Some(node) = graph.get_node_mut(*node_id) {
                node.position = *position;
                node.updated_at = chrono::Utc::now();
            }
        }
        Ok(())
    }
}

impl Default for LayoutConfig {
    fn default() -> Self {
        Self {
            canvas_width: 1000.0,
            canvas_height: 800.0,
            center: Point::new(500.0, 400.0),
            animation_duration: 1000,
            preserve_positions: false,
            min_distance: 100.0,
            parameters: HashMap::new(),
        }
    }
}

impl LayoutBounds {
    /// Create new layout bounds
    pub fn new(min_x: f64, min_y: f64, max_x: f64, max_y: f64) -> Self {
        Self { min_x, min_y, max_x, max_y }
    }

    /// Create bounds from a set of points
    pub fn from_points(points: &[Point]) -> Self {
        if points.is_empty() {
            return Self::new(0.0, 0.0, 0.0, 0.0);
        }

        let mut bounds = Self::new(
            points[0].x, points[0].y,
            points[0].x, points[0].y,
        );

        for point in points.iter().skip(1) {
            bounds.extend_point(point);
        }

        bounds
    }

    /// Extend bounds to include a point
    pub fn extend_point(&mut self, point: &Point) {
        self.min_x = self.min_x.min(point.x);
        self.min_y = self.min_y.min(point.y);
        self.max_x = self.max_x.max(point.x);
        self.max_y = self.max_y.max(point.y);
    }

    /// Get the width of the bounds
    pub fn width(&self) -> f64 {
        self.max_x - self.min_x
    }

    /// Get the height of the bounds
    pub fn height(&self) -> f64 {
        self.max_y - self.min_y
    }

    /// Get the center point of the bounds
    pub fn center(&self) -> Point {
        Point::new(
            (self.min_x + self.max_x) / 2.0,
            (self.min_y + self.max_y) / 2.0,
        )
    }

    /// Check if bounds are valid (max >= min)
    pub fn is_valid(&self) -> bool {
        self.max_x >= self.min_x && self.max_y >= self.min_y
    }
}

/// Utility functions for layout calculations
pub mod utils {
    use super::*;

    /// Calculate distance between two points
    pub fn distance(p1: &Point, p2: &Point) -> f64 {
        let dx = p1.x - p2.x;
        let dy = p1.y - p2.y;
        (dx * dx + dy * dy).sqrt()
    }

    /// Normalize an angle to [0, 2π] range
    pub fn normalize_angle(angle: f64) -> f64 {
        let two_pi = 2.0 * std::f64::consts::PI;
        ((angle % two_pi) + two_pi) % two_pi
    }

    /// Convert polar coordinates to cartesian
    pub fn polar_to_cartesian(radius: f64, angle: f64, center: &Point) -> Point {
        Point::new(
            center.x + radius * angle.cos(),
            center.y + radius * angle.sin(),
        )
    }

    /// Convert cartesian coordinates to polar (relative to center)
    pub fn cartesian_to_polar(point: &Point, center: &Point) -> (f64, f64) {
        let dx = point.x - center.x;
        let dy = point.y - center.y;
        let radius = (dx * dx + dy * dy).sqrt();
        let angle = dy.atan2(dx);
        (radius, normalize_angle(angle))
    }

    /// Distribute angles evenly around a circle
    pub fn distribute_angles(count: usize, start_angle: f64) -> Vec<f64> {
        if count == 0 {
            return Vec::new();
        }

        let angle_step = 2.0 * std::f64::consts::PI / count as f64;
        (0..count)
            .map(|i| normalize_angle(start_angle + i as f64 * angle_step))
            .collect()
    }

    /// Calculate optimal radius based on number of children and their sizes
    pub fn calculate_radius(child_count: usize, min_distance: f64, node_size: f64) -> f64 {
        if child_count <= 1 {
            return min_distance.max(node_size * 2.0);
        }

        // Calculate radius needed to maintain minimum distance between children
        let angle_step = 2.0 * std::f64::consts::PI / child_count as f64;
        let chord_length = min_distance + node_size;
        let radius = chord_length / (2.0 * (angle_step / 2.0).sin());

        radius.max(min_distance).max(node_size * 2.0)
    }

    /// Scale points to fit within bounds
    pub fn scale_to_fit(points: &mut HashMap<NodeId, Point>, target_bounds: &LayoutBounds) {
        if points.is_empty() {
            return;
        }

        let current_points: Vec<Point> = points.values().cloned().collect();
        let current_bounds = LayoutBounds::from_points(&current_points);

        if !current_bounds.is_valid() || current_bounds.width() == 0.0 || current_bounds.height() == 0.0 {
            return;
        }

        let scale_x = target_bounds.width() / current_bounds.width();
        let scale_y = target_bounds.height() / current_bounds.height();
        let scale = scale_x.min(scale_y) * 0.9; // Leave 10% margin

        let current_center = current_bounds.center();
        let target_center = target_bounds.center();

        for position in points.values_mut() {
            // Translate to origin
            position.x -= current_center.x;
            position.y -= current_center.y;

            // Scale
            position.x *= scale;
            position.y *= scale;

            // Translate to target center
            position.x += target_center.x;
            position.y += target_center.y;
        }
    }
}

/// Concrete layout engine that can handle multiple layout algorithms
pub struct LayoutEngineImpl {
    current_layout: LayoutType,
}

impl LayoutEngineImpl {
    /// Create a new layout engine with default layout type
    pub fn new() -> Self {
        Self {
            current_layout: LayoutType::Radial,
        }
    }

    /// Create a layout engine with specific layout type
    pub fn with_layout_type(layout_type: LayoutType) -> Self {
        Self {
            current_layout: layout_type,
        }
    }

    /// Set the layout type
    pub fn set_layout_type(&mut self, layout_type: LayoutType) {
        self.current_layout = layout_type;
    }

    /// Calculate layout for a graph using the specified layout type
    pub fn calculate_layout(&self, graph: &Graph, layout_type: LayoutType) -> MindmapResult<LayoutResult> {
        let config = LayoutConfig::default();

        match layout_type {
            LayoutType::Radial => {
                let radial_engine = radial::RadialLayoutEngine::default();
                radial_engine.calculate_layout(graph, &config)
            }
            LayoutType::Tree => {
                let tree_engine = tree::TreeLayoutEngine::default();
                tree_engine.calculate_layout(graph, &config)
            }
            LayoutType::Force => {
                let force_engine = force::ForceLayoutEngine::default();
                force_engine.calculate_layout(graph, &config)
            }
        }
    }
}

impl Default for LayoutEngineImpl {
    fn default() -> Self {
        Self::new()
    }
}

impl LayoutEngine for LayoutEngineImpl {
    fn calculate_layout(&self, graph: &Graph, config: &LayoutConfig) -> MindmapResult<LayoutResult> {
        match self.current_layout {
            LayoutType::Radial => {
                let radial_engine = radial::RadialLayoutEngine::default();
                radial_engine.calculate_layout(graph, config)
            }
            LayoutType::Tree => {
                let tree_engine = tree::TreeLayoutEngine::default();
                tree_engine.calculate_layout(graph, config)
            }
            LayoutType::Force => {
                let force_engine = force::ForceLayoutEngine::default();
                force_engine.calculate_layout(graph, config)
            }
        }
    }

    fn layout_type(&self) -> LayoutType {
        self.current_layout
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_layout_config_default() {
        let config = LayoutConfig::default();
        assert_eq!(config.canvas_width, 1000.0);
        assert_eq!(config.canvas_height, 800.0);
        assert_eq!(config.center, Point::new(500.0, 400.0));
        assert!(!config.preserve_positions);
    }

    #[test]
    fn test_layout_bounds() {
        let points = vec![
            Point::new(0.0, 0.0),
            Point::new(100.0, 50.0),
            Point::new(-50.0, 75.0),
        ];

        let bounds = LayoutBounds::from_points(&points);
        assert_eq!(bounds.min_x, -50.0);
        assert_eq!(bounds.min_y, 0.0);
        assert_eq!(bounds.max_x, 100.0);
        assert_eq!(bounds.max_y, 75.0);
        assert_eq!(bounds.width(), 150.0);
        assert_eq!(bounds.height(), 75.0);
    }

    #[test]
    fn test_bounds_center() {
        let bounds = LayoutBounds::new(0.0, 0.0, 100.0, 50.0);
        let center = bounds.center();
        assert_eq!(center, Point::new(50.0, 25.0));
    }

    #[test]
    fn test_distance() {
        let p1 = Point::new(0.0, 0.0);
        let p2 = Point::new(3.0, 4.0);
        assert_eq!(utils::distance(&p1, &p2), 5.0);
    }

    #[test]
    fn test_normalize_angle() {
        use std::f64::consts::PI;

        assert!((utils::normalize_angle(0.0) - 0.0).abs() < 1e-10);
        assert!((utils::normalize_angle(PI) - PI).abs() < 1e-10);
        assert!((utils::normalize_angle(3.0 * PI) - PI).abs() < 1e-10);
        assert!((utils::normalize_angle(-PI) - PI).abs() < 1e-10);
    }

    #[test]
    fn test_polar_cartesian_conversion() {
        let center = Point::new(100.0, 100.0);
        let radius = 50.0;
        let angle = std::f64::consts::PI / 4.0; // 45 degrees

        let cartesian = utils::polar_to_cartesian(radius, angle, &center);
        let (back_radius, back_angle) = utils::cartesian_to_polar(&cartesian, &center);

        assert!((back_radius - radius).abs() < 1e-10);
        assert!((back_angle - angle).abs() < 1e-10);
    }

    #[test]
    fn test_distribute_angles() {
        let angles = utils::distribute_angles(4, 0.0);
        assert_eq!(angles.len(), 4);

        // Should be evenly distributed around the circle
        let expected_step = std::f64::consts::PI / 2.0;
        for (i, &angle) in angles.iter().enumerate() {
            let expected = i as f64 * expected_step;
            assert!((angle - expected).abs() < 1e-10);
        }
    }

    #[test]
    fn test_calculate_radius() {
        let radius = utils::calculate_radius(4, 50.0, 20.0);
        assert!(radius >= 50.0); // At least min_distance
        assert!(radius >= 40.0); // At least 2 * node_size

        // Single child should return minimum values
        let radius_single = utils::calculate_radius(1, 50.0, 20.0);
        assert_eq!(radius_single, 50.0);
    }

    #[test]
    fn test_empty_distribute_angles() {
        let angles = utils::distribute_angles(0, 0.0);
        assert!(angles.is_empty());
    }

    #[test]
    fn test_bounds_validity() {
        let valid_bounds = LayoutBounds::new(0.0, 0.0, 100.0, 100.0);
        assert!(valid_bounds.is_valid());

        let invalid_bounds = LayoutBounds::new(100.0, 100.0, 0.0, 0.0);
        assert!(!invalid_bounds.is_valid());
    }

    #[test]
    fn test_scale_to_fit() {
        let mut points = HashMap::new();
        points.insert(NodeId::new(), Point::new(0.0, 0.0));
        points.insert(NodeId::new(), Point::new(200.0, 100.0));

        let target_bounds = LayoutBounds::new(0.0, 0.0, 100.0, 50.0);
        utils::scale_to_fit(&mut points, &target_bounds);

        // Points should be scaled to fit within target bounds
        let scaled_points: Vec<Point> = points.values().cloned().collect();
        let result_bounds = LayoutBounds::from_points(&scaled_points);

        assert!(result_bounds.width() <= target_bounds.width());
        assert!(result_bounds.height() <= target_bounds.height());
    }
}