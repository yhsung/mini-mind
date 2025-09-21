//! Data models for nodes, edges, and documents
//!
//! This module contains the core data structures representing mindmap entities.

pub mod node;
pub mod edge;
pub mod document;

pub use node::*;
pub use edge::*;
pub use document::*;

// Alias for FFI compatibility
pub type MindmapDocument = Document;