//! Data Transfer Objects for FFI communication
//!
//! This module contains the data structures optimized for FFI communication
//! between Rust and Flutter, ensuring efficient serialization and type safety.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Color data for FFI communication
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl From<crate::types::Color> for FfiColor {
    fn from(color: crate::types::Color) -> Self {
        let (r, g, b, a) = crate::types::utils::color_to_rgba(color);
        Self { r, g, b, a }
    }
}

impl From<FfiColor> for crate::types::Color {
    fn from(ffi_color: FfiColor) -> Self {
        crate::types::utils::rgba_to_color(ffi_color.r, ffi_color.g, ffi_color.b, ffi_color.a)
    }
}

/// Font weight for FFI communication
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum FfiFontWeight {
    Normal,
    Bold,
}

impl From<crate::models::FontWeight> for FfiFontWeight {
    fn from(weight: crate::models::FontWeight) -> Self {
        match weight {
            crate::models::FontWeight::Normal => FfiFontWeight::Normal,
            crate::models::FontWeight::Bold => FfiFontWeight::Bold,
        }
    }
}

impl From<FfiFontWeight> for crate::models::FontWeight {
    fn from(ffi_weight: FfiFontWeight) -> Self {
        match ffi_weight {
            FfiFontWeight::Normal => crate::models::FontWeight::Normal,
            FfiFontWeight::Bold => crate::models::FontWeight::Bold,
        }
    }
}

/// Text alignment for FFI communication
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum FfiTextAlign {
    Left,
    Center,
    Right,
}

impl From<crate::models::TextAlign> for FfiTextAlign {
    fn from(align: crate::models::TextAlign) -> Self {
        match align {
            crate::models::TextAlign::Left => FfiTextAlign::Left,
            crate::models::TextAlign::Center => FfiTextAlign::Center,
            crate::models::TextAlign::Right => FfiTextAlign::Right,
        }
    }
}

impl From<FfiTextAlign> for crate::models::TextAlign {
    fn from(ffi_align: FfiTextAlign) -> Self {
        match ffi_align {
            FfiTextAlign::Left => crate::models::TextAlign::Left,
            FfiTextAlign::Center => crate::models::TextAlign::Center,
            FfiTextAlign::Right => crate::models::TextAlign::Right,
        }
    }
}

/// Node shape for FFI communication
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum FfiNodeShape {
    Rectangle,
    RoundedRectangle,
    Circle,
    Ellipse,
}

impl From<crate::models::NodeShape> for FfiNodeShape {
    fn from(shape: crate::models::NodeShape) -> Self {
        match shape {
            crate::models::NodeShape::Rectangle => FfiNodeShape::Rectangle,
            crate::models::NodeShape::RoundedRectangle => FfiNodeShape::RoundedRectangle,
            crate::models::NodeShape::Circle => FfiNodeShape::Circle,
            crate::models::NodeShape::Ellipse => FfiNodeShape::Ellipse,
        }
    }
}

impl From<FfiNodeShape> for crate::models::NodeShape {
    fn from(ffi_shape: FfiNodeShape) -> Self {
        match ffi_shape {
            FfiNodeShape::Rectangle => crate::models::NodeShape::Rectangle,
            FfiNodeShape::RoundedRectangle => crate::models::NodeShape::RoundedRectangle,
            FfiNodeShape::Circle => crate::models::NodeShape::Circle,
            FfiNodeShape::Ellipse => crate::models::NodeShape::Ellipse,
        }
    }
}

/// Node style data for FFI communication
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiNodeStyle {
    pub background_color: FfiColor,
    pub text_color: FfiColor,
    pub border_color: FfiColor,
    pub border_width: f64,
    pub corner_radius: f64,
    pub font_size: f64,
    pub font_weight: FfiFontWeight,
    pub text_align: FfiTextAlign,
    pub shape: FfiNodeShape,
}

impl From<crate::models::NodeStyle> for FfiNodeStyle {
    fn from(style: crate::models::NodeStyle) -> Self {
        Self {
            background_color: style.background_color.into(),
            text_color: style.text_color.into(),
            border_color: style.border_color.into(),
            border_width: style.border_width,
            corner_radius: style.corner_radius,
            font_size: style.font_size,
            font_weight: style.font_weight.into(),
            text_align: style.text_align.into(),
            shape: style.shape.into(),
        }
    }
}

impl From<FfiNodeStyle> for crate::models::NodeStyle {
    fn from(ffi_style: FfiNodeStyle) -> Self {
        Self {
            background_color: ffi_style.background_color.into(),
            text_color: ffi_style.text_color.into(),
            border_color: ffi_style.border_color.into(),
            border_width: ffi_style.border_width,
            corner_radius: ffi_style.corner_radius,
            font_size: ffi_style.font_size,
            font_weight: ffi_style.font_weight.into(),
            text_align: ffi_style.text_align.into(),
            shape: ffi_style.shape.into(),
        }
    }
}

/// Attachment data for FFI communication
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiAttachment {
    pub id: String,
    pub filename: String,
    pub mime_type: String,
    pub size: u64,
    pub path: String,
    pub created_at: i64, // Unix timestamp
}

impl From<crate::models::Attachment> for FfiAttachment {
    fn from(attachment: crate::models::Attachment) -> Self {
        Self {
            id: attachment.id,
            filename: attachment.filename,
            mime_type: attachment.mime_type,
            size: attachment.size,
            path: attachment.path,
            created_at: attachment.created_at.timestamp(),
        }
    }
}

impl From<FfiAttachment> for crate::models::Attachment {
    fn from(ffi_attachment: FfiAttachment) -> Self {
        use chrono::{DateTime, TimeZone, Utc};

        Self {
            id: ffi_attachment.id,
            filename: ffi_attachment.filename,
            mime_type: ffi_attachment.mime_type,
            size: ffi_attachment.size,
            path: ffi_attachment.path,
            created_at: Utc.timestamp_opt(ffi_attachment.created_at, 0).unwrap(),
        }
    }
}

/// Complete node data with style and attachments for FFI communication
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiCompleteNodeData {
    pub id: String,
    pub parent_id: Option<String>,
    pub text: String,
    pub style: FfiNodeStyle,
    pub position: super::FfiPoint,
    pub attachments: Vec<FfiAttachment>,
    pub tags: Vec<String>,
    pub created_at: i64, // Unix timestamp
    pub updated_at: i64, // Unix timestamp
    pub metadata: HashMap<String, String>,
}

impl From<crate::models::Node> for FfiCompleteNodeData {
    fn from(node: crate::models::Node) -> Self {
        Self {
            id: node.id.to_string(),
            parent_id: node.parent_id.map(|id| id.to_string()),
            text: node.text,
            style: node.style.into(),
            position: node.position.into(),
            attachments: node.attachments.into_iter().map(Into::into).collect(),
            tags: node.tags,
            created_at: node.created_at.timestamp(),
            updated_at: node.updated_at.timestamp(),
            metadata: node.metadata,
        }
    }
}

/// Layout configuration for FFI communication
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiLayoutConfig {
    /// Center point for the layout
    pub center: super::FfiPoint,
    /// Spacing between nodes
    pub node_spacing: f64,
    /// Layer spacing for hierarchical layouts
    pub layer_spacing: f64,
    /// Minimum distance between nodes
    pub min_distance: f64,
    /// Maximum iterations for force-directed layouts
    pub max_iterations: Option<u32>,
    /// Force strength for force-directed layouts
    pub force_strength: Option<f64>,
}

impl Default for FfiLayoutConfig {
    fn default() -> Self {
        Self {
            center: super::FfiPoint { x: 0.0, y: 0.0 },
            node_spacing: 150.0,
            layer_spacing: 100.0,
            min_distance: 50.0,
            max_iterations: Some(100),
            force_strength: Some(0.1),
        }
    }
}

/// Batch operation result for FFI communication
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiBatchResult {
    /// Number of successful operations
    pub success_count: u32,
    /// Number of failed operations
    pub failure_count: u32,
    /// Error messages for failed operations
    pub errors: Vec<String>,
}

/// Performance metrics for FFI communication
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FfiPerformanceMetrics {
    /// Operation name
    pub operation: String,
    /// Duration in milliseconds
    pub duration_ms: u64,
    /// Memory usage in bytes
    pub memory_usage: u64,
    /// Number of nodes processed
    pub nodes_processed: u32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_color_conversion() {
        let original_color = crate::types::utils::rgba_to_color(255, 128, 64, 32);
        let ffi_color: FfiColor = original_color.into();
        let converted_back: crate::types::Color = ffi_color.into();

        assert_eq!(original_color, converted_back);
        assert_eq!(ffi_color.r, 255);
        assert_eq!(ffi_color.g, 128);
        assert_eq!(ffi_color.b, 64);
        assert_eq!(ffi_color.a, 32);
    }

    #[test]
    fn test_font_weight_conversion() {
        let bold = crate::models::FontWeight::Bold;
        let ffi_bold: FfiFontWeight = bold.into();
        let converted_back: crate::models::FontWeight = ffi_bold.into();

        assert_eq!(bold, converted_back);
        assert_eq!(ffi_bold, FfiFontWeight::Bold);
    }

    #[test]
    fn test_text_align_conversion() {
        let center = crate::models::TextAlign::Center;
        let ffi_center: FfiTextAlign = center.into();
        let converted_back: crate::models::TextAlign = ffi_center.into();

        assert_eq!(center, converted_back);
        assert_eq!(ffi_center, FfiTextAlign::Center);
    }

    #[test]
    fn test_node_shape_conversion() {
        let circle = crate::models::NodeShape::Circle;
        let ffi_circle: FfiNodeShape = circle.into();
        let converted_back: crate::models::NodeShape = ffi_circle.into();

        assert_eq!(circle, converted_back);
        assert_eq!(ffi_circle, FfiNodeShape::Circle);
    }

    #[test]
    fn test_layout_config_default() {
        let config = FfiLayoutConfig::default();
        assert_eq!(config.center.x, 0.0);
        assert_eq!(config.center.y, 0.0);
        assert_eq!(config.node_spacing, 150.0);
        assert_eq!(config.layer_spacing, 100.0);
        assert_eq!(config.min_distance, 50.0);
        assert_eq!(config.max_iterations, Some(100));
        assert_eq!(config.force_strength, Some(0.1));
    }
}