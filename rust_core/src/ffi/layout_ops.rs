//! Layout operations for FFI interface
//!
//! This module provides specialized layout operations and utilities for the FFI bridge,
//! offering enhanced functionality beyond the basic MindmapFFI trait implementation.

use super::{BridgeError, FfiLayoutResult, FfiLayoutType, FfiPoint, MindmapBridge, utils};
use crate::{
    graph::Graph,
    layout::{LayoutConfig, LayoutEngine, LayoutEngineImpl, LayoutType},
    models::Node,
    types::{NodeId, Point},
};
use std::collections::HashMap;
use std::time::Instant;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Enhanced layout operations for advanced FFI functionality
pub struct LayoutOperations;

impl LayoutOperations {
    /// Calculate layout with advanced configuration options
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn calculate_layout_with_config(
        bridge: &MindmapBridge,
        layout_type: FfiLayoutType,
        config: FfiLayoutConfig,
    ) -> Result<FfiLayoutResult, BridgeError> {
        let start_time = Instant::now();

        // Validate configuration
        Self::validate_layout_config(&config)?;

        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        if graph.node_count() == 0 {
            return Ok(FfiLayoutResult {
                node_positions: HashMap::new(),
                layout_type,
                computation_time_ms: start_time.elapsed().as_millis() as u64,
            });
        }

        // Convert FFI config to internal config
        let internal_config = LayoutConfig {
            canvas_width: config.canvas_width,
            canvas_height: config.canvas_height,
            margin: config.margin,
            node_spacing: config.node_spacing,
            level_spacing: config.level_spacing.unwrap_or(50.0),
            preserve_aspect_ratio: config.preserve_aspect_ratio,
        };

        // Calculate layout using specified algorithm
        let layout_result = bridge.layout_engine
            .calculate_layout(&*graph, &internal_config)
            .map_err(|e| BridgeError::LayoutComputationError {
                message: format!("Layout calculation failed: {}", e),
            })?;

        // Convert result to FFI format
        let node_positions: HashMap<String, FfiPoint> = layout_result
            .node_positions
            .into_iter()
            .map(|(id, pos)| (id.to_string(), FfiPoint { x: pos.x, y: pos.y }))
            .collect();

        let result = FfiLayoutResult {
            node_positions,
            layout_type,
            computation_time_ms: layout_result.computation_time.as_millis() as u64,
        };

        bridge.record_metrics("calculate_layout_with_config", start_time, result.node_positions.len() as u32);
        Ok(result)
    }

    /// Apply layout with animation support
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn apply_layout_with_animation(
        bridge: &MindmapBridge,
        layout_result: FfiLayoutResult,
        animation_config: AnimationConfig,
    ) -> Result<Vec<AnimationFrame>, BridgeError> {
        let start_time = Instant::now();

        // Validate animation configuration
        Self::validate_animation_config(&animation_config)?;

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Get current positions
        let current_positions: HashMap<String, FfiPoint> = graph
            .get_all_nodes()
            .iter()
            .map(|(id, node)| {
                (id.to_string(), FfiPoint { x: node.position.x, y: node.position.y })
            })
            .collect();

        // Generate animation frames
        let frames = Self::generate_animation_frames(
            &current_positions,
            &layout_result.node_positions,
            &animation_config,
        )?;

        // Apply final positions
        for (node_id_str, position) in &layout_result.node_positions {
            let node_id = bridge.parse_node_id(node_id_str)?;
            if let Ok(mut node) = graph.get_node(node_id).cloned() {
                node.position = Point::new(position.x, position.y);
                node.touch();
                graph.update_node(node).map_err(|e| BridgeError::InvalidOperation {
                    message: format!("Failed to update node position: {}", e),
                })?;
            }
        }

        bridge.record_metrics("apply_layout_with_animation", start_time, layout_result.node_positions.len() as u32);
        Ok(frames)
    }

    /// Batch update node positions with validation
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn batch_update_positions(
        bridge: &MindmapBridge,
        position_updates: Vec<NodePositionUpdate>,
    ) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        // Validate all position updates first
        for update in &position_updates {
            utils::validate_position(&update.position)?;
        }

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Apply all position updates
        for update in position_updates {
            let node_id = bridge.parse_node_id(&update.node_id)?;
            let mut node = graph.get_node(node_id)
                .map_err(|_| BridgeError::NodeNotFound { id: update.node_id.clone() })?
                .clone();

            node.position = Point::new(update.position.x, update.position.y);

            // Apply relative offset if specified
            if let Some(offset) = update.relative_offset {
                node.position.x += offset.x;
                node.position.y += offset.y;
            }

            node.touch();
            graph.update_node(node).map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to update node position for {}: {}", update.node_id, e),
            })?;
        }

        bridge.record_metrics("batch_update_positions", start_time, position_updates.len() as u32);
        Ok(())
    }

    /// Get layout bounds and statistics
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn get_layout_bounds(
        bridge: &MindmapBridge,
        include_margin: bool,
    ) -> Result<LayoutBounds, BridgeError> {
        let start_time = Instant::now();

        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        if graph.node_count() == 0 {
            return Ok(LayoutBounds {
                min_x: 0.0,
                min_y: 0.0,
                max_x: 0.0,
                max_y: 0.0,
                width: 0.0,
                height: 0.0,
                center: FfiPoint { x: 0.0, y: 0.0 },
                node_count: 0,
            });
        }

        let nodes: Vec<&Node> = graph.get_all_nodes().values().collect();
        let positions: Vec<&Point> = nodes.iter().map(|n| &n.position).collect();

        let min_x = positions.iter().map(|p| p.x).fold(f64::INFINITY, f64::min);
        let max_x = positions.iter().map(|p| p.x).fold(f64::NEG_INFINITY, f64::max);
        let min_y = positions.iter().map(|p| p.y).fold(f64::INFINITY, f64::min);
        let max_y = positions.iter().map(|p| p.y).fold(f64::NEG_INFINITY, f64::max);

        let margin = if include_margin { 50.0 } else { 0.0 };

        let bounds = LayoutBounds {
            min_x: min_x - margin,
            min_y: min_y - margin,
            max_x: max_x + margin,
            max_y: max_y + margin,
            width: (max_x - min_x) + (2.0 * margin),
            height: (max_y - min_y) + (2.0 * margin),
            center: FfiPoint {
                x: (min_x + max_x) / 2.0,
                y: (min_y + max_y) / 2.0,
            },
            node_count: nodes.len() as u32,
        };

        bridge.record_metrics("get_layout_bounds", start_time, 1);
        Ok(bounds)
    }

    /// Auto-fit layout to canvas size
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn auto_fit_layout(
        bridge: &MindmapBridge,
        canvas_width: f64,
        canvas_height: f64,
        padding: f64,
    ) -> Result<FfiLayoutResult, BridgeError> {
        let start_time = Instant::now();

        if canvas_width <= 0.0 || canvas_height <= 0.0 {
            return Err(BridgeError::InvalidOperation {
                message: "Canvas dimensions must be positive".to_string(),
            });
        }

        // Get current layout bounds
        let bounds = Self::get_layout_bounds(bridge, false)?;

        if bounds.node_count == 0 {
            return Ok(FfiLayoutResult {
                node_positions: HashMap::new(),
                layout_type: FfiLayoutType::Radial,
                computation_time_ms: start_time.elapsed().as_millis() as u64,
            });
        }

        // Calculate scale factor to fit content
        let available_width = canvas_width - (2.0 * padding);
        let available_height = canvas_height - (2.0 * padding);

        let scale_x = if bounds.width > 0.0 { available_width / bounds.width } else { 1.0 };
        let scale_y = if bounds.height > 0.0 { available_height / bounds.height } else { 1.0 };
        let scale = scale_x.min(scale_y).min(1.0); // Don't scale up

        // Calculate offset to center content
        let scaled_width = bounds.width * scale;
        let scaled_height = bounds.height * scale;
        let offset_x = (canvas_width - scaled_width) / 2.0 - (bounds.min_x * scale);
        let offset_y = (canvas_height - scaled_height) / 2.0 - (bounds.min_y * scale);

        // Transform all positions
        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let node_positions: HashMap<String, FfiPoint> = graph
            .get_all_nodes()
            .iter()
            .map(|(id, node)| {
                let new_x = (node.position.x * scale) + offset_x;
                let new_y = (node.position.y * scale) + offset_y;
                (id.to_string(), FfiPoint { x: new_x, y: new_y })
            })
            .collect();

        let result = FfiLayoutResult {
            node_positions,
            layout_type: FfiLayoutType::Radial, // This is a transformation, not a specific layout
            computation_time_ms: start_time.elapsed().as_millis() as u64,
        };

        bridge.record_metrics("auto_fit_layout", start_time, result.node_positions.len() as u32);
        Ok(result)
    }

    /// Snap nodes to grid
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn snap_to_grid(
        bridge: &MindmapBridge,
        grid_size: f64,
        selected_nodes: Option<Vec<String>>,
    ) -> Result<HashMap<String, FfiPoint>, BridgeError> {
        let start_time = Instant::now();

        if grid_size <= 0.0 {
            return Err(BridgeError::InvalidOperation {
                message: "Grid size must be positive".to_string(),
            });
        }

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let mut updated_positions = HashMap::new();

        // Determine which nodes to snap
        let nodes_to_snap: Vec<NodeId> = if let Some(selected) = selected_nodes {
            selected.into_iter()
                .filter_map(|id_str| bridge.parse_node_id(&id_str).ok())
                .collect()
        } else {
            graph.get_all_nodes().keys().cloned().collect()
        };

        // Snap positions to grid
        for node_id in nodes_to_snap {
            if let Ok(mut node) = graph.get_node(node_id).cloned() {
                let snapped_x = (node.position.x / grid_size).round() * grid_size;
                let snapped_y = (node.position.y / grid_size).round() * grid_size;

                node.position = Point::new(snapped_x, snapped_y);
                node.touch();

                if graph.update_node(node).is_ok() {
                    updated_positions.insert(
                        node_id.to_string(),
                        FfiPoint { x: snapped_x, y: snapped_y }
                    );
                }
            }
        }

        bridge.record_metrics("snap_to_grid", start_time, updated_positions.len() as u32);
        Ok(updated_positions)
    }

    // Helper methods

    fn validate_layout_config(config: &FfiLayoutConfig) -> Result<(), BridgeError> {
        if config.canvas_width <= 0.0 || config.canvas_height <= 0.0 {
            return Err(BridgeError::InvalidOperation {
                message: "Canvas dimensions must be positive".to_string(),
            });
        }

        if config.node_spacing < 0.0 {
            return Err(BridgeError::InvalidOperation {
                message: "Node spacing cannot be negative".to_string(),
            });
        }

        if config.margin < 0.0 {
            return Err(BridgeError::InvalidOperation {
                message: "Margin cannot be negative".to_string(),
            });
        }

        Ok(())
    }

    fn validate_animation_config(config: &AnimationConfig) -> Result<(), BridgeError> {
        if config.duration_ms == 0 {
            return Err(BridgeError::InvalidOperation {
                message: "Animation duration must be positive".to_string(),
            });
        }

        if config.frame_count == 0 {
            return Err(BridgeError::InvalidOperation {
                message: "Animation frame count must be positive".to_string(),
            });
        }

        if config.easing_factor < 0.0 || config.easing_factor > 1.0 {
            return Err(BridgeError::InvalidOperation {
                message: "Easing factor must be between 0.0 and 1.0".to_string(),
            });
        }

        Ok(())
    }

    fn generate_animation_frames(
        start_positions: &HashMap<String, FfiPoint>,
        end_positions: &HashMap<String, FfiPoint>,
        config: &AnimationConfig,
    ) -> Result<Vec<AnimationFrame>, BridgeError> {
        let mut frames = Vec::new();
        let frame_duration = config.duration_ms / config.frame_count as u64;

        for frame_index in 0..config.frame_count {
            let progress = frame_index as f64 / (config.frame_count - 1) as f64;

            // Apply easing
            let eased_progress = match config.easing_type {
                EasingType::Linear => progress,
                EasingType::EaseInOut => {
                    if progress < 0.5 {
                        2.0 * progress * progress
                    } else {
                        1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
                    }
                },
                EasingType::EaseOut => 1.0 - (1.0 - progress).powi(2),
            };

            let mut frame_positions = HashMap::new();

            for (node_id, end_pos) in end_positions {
                let start_pos = start_positions.get(node_id)
                    .unwrap_or(&FfiPoint { x: end_pos.x, y: end_pos.y });

                let interpolated_x = start_pos.x + (end_pos.x - start_pos.x) * eased_progress;
                let interpolated_y = start_pos.y + (end_pos.y - start_pos.y) * eased_progress;

                frame_positions.insert(
                    node_id.clone(),
                    FfiPoint { x: interpolated_x, y: interpolated_y }
                );
            }

            frames.push(AnimationFrame {
                frame_index: frame_index as u32,
                timestamp_ms: frame_index as u64 * frame_duration,
                node_positions: frame_positions,
                progress: eased_progress,
            });
        }

        Ok(frames)
    }
}

/// FFI-compatible layout configuration
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiLayoutConfig {
    pub canvas_width: f64,
    pub canvas_height: f64,
    pub margin: f64,
    pub node_spacing: f64,
    pub level_spacing: Option<f64>,
    pub preserve_aspect_ratio: bool,
}

impl Default for FfiLayoutConfig {
    fn default() -> Self {
        Self {
            canvas_width: 800.0,
            canvas_height: 600.0,
            margin: 50.0,
            node_spacing: 20.0,
            level_spacing: Some(50.0),
            preserve_aspect_ratio: true,
        }
    }
}

/// Configuration for layout animations
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct AnimationConfig {
    pub duration_ms: u64,
    pub frame_count: u32,
    pub easing_type: EasingType,
    pub easing_factor: f64,
}

/// Easing types for animations
#[derive(Debug, Clone, Copy)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum EasingType {
    Linear,
    EaseInOut,
    EaseOut,
}

/// Single animation frame
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct AnimationFrame {
    pub frame_index: u32,
    pub timestamp_ms: u64,
    pub node_positions: HashMap<String, FfiPoint>,
    pub progress: f64,
}

/// Node position update data
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct NodePositionUpdate {
    pub node_id: String,
    pub position: FfiPoint,
    pub relative_offset: Option<FfiPoint>,
}

/// Layout bounds information
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct LayoutBounds {
    pub min_x: f64,
    pub min_y: f64,
    pub max_x: f64,
    pub max_y: f64,
    pub width: f64,
    pub height: f64,
    pub center: FfiPoint,
    pub node_count: u32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffi_layout_config_default() {
        let config = FfiLayoutConfig::default();
        assert_eq!(config.canvas_width, 800.0);
        assert_eq!(config.canvas_height, 600.0);
        assert_eq!(config.margin, 50.0);
        assert_eq!(config.node_spacing, 20.0);
        assert_eq!(config.level_spacing, Some(50.0));
        assert!(config.preserve_aspect_ratio);
    }

    #[test]
    fn test_animation_config_validation() {
        let valid_config = AnimationConfig {
            duration_ms: 1000,
            frame_count: 30,
            easing_type: EasingType::Linear,
            easing_factor: 0.5,
        };

        assert!(LayoutOperations::validate_animation_config(&valid_config).is_ok());

        let invalid_config = AnimationConfig {
            duration_ms: 0,
            frame_count: 30,
            easing_type: EasingType::Linear,
            easing_factor: 0.5,
        };

        assert!(LayoutOperations::validate_animation_config(&invalid_config).is_err());
    }

    #[test]
    fn test_layout_bounds_structure() {
        let bounds = LayoutBounds {
            min_x: 0.0,
            min_y: 0.0,
            max_x: 100.0,
            max_y: 100.0,
            width: 100.0,
            height: 100.0,
            center: FfiPoint { x: 50.0, y: 50.0 },
            node_count: 5,
        };

        assert_eq!(bounds.width, 100.0);
        assert_eq!(bounds.height, 100.0);
        assert_eq!(bounds.center.x, 50.0);
        assert_eq!(bounds.center.y, 50.0);
        assert_eq!(bounds.node_count, 5);
    }

    #[test]
    fn test_node_position_update() {
        let update = NodePositionUpdate {
            node_id: "test-123".to_string(),
            position: FfiPoint { x: 10.0, y: 20.0 },
            relative_offset: Some(FfiPoint { x: 5.0, y: -5.0 }),
        };

        assert_eq!(update.node_id, "test-123");
        assert_eq!(update.position.x, 10.0);
        assert_eq!(update.position.y, 20.0);
        assert!(update.relative_offset.is_some());
    }

    #[test]
    fn test_easing_types() {
        let linear = EasingType::Linear;
        let ease_in_out = EasingType::EaseInOut;
        let ease_out = EasingType::EaseOut;

        // Just test that variants exist
        assert_eq!(format!("{:?}", linear), "Linear");
        assert_eq!(format!("{:?}", ease_in_out), "EaseInOut");
        assert_eq!(format!("{:?}", ease_out), "EaseOut");
    }
}