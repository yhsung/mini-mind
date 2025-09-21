//! Bridge implementation for FFI communication
//!
//! This module provides the concrete implementation of the MindmapFFI trait,
//! handling the communication between Flutter UI and Rust core engine.

use super::{
    BridgeError, ExportFormat, FfiBatchResult, FfiLayoutResult, FfiLayoutType, FfiMindmapData,
    FfiNodeData, FfiNodeUpdate, FfiPerformanceMetrics, FfiPoint, FfiResult, FfiSearchResult,
    MindmapFFI,
};
use crate::{
    graph::Graph,
    layout::{LayoutEngineImpl, LayoutType},
    models::{MindmapDocument, Node},
    search::SearchEngine,
    types::{MindmapId, NodeId},
};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use std::time::Instant;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Main bridge implementation for mindmap operations
#[derive(Debug)]
pub struct MindmapBridge {
    /// Current mindmap document
    document: Arc<RwLock<Option<MindmapDocument>>>,
    /// Graph engine for node and edge operations
    graph: Arc<RwLock<Graph>>,
    /// Layout engine for positioning algorithms
    layout_engine: Arc<LayoutEngineImpl>,
    /// Search engine for text and tag queries
    search_engine: Arc<RwLock<SearchEngine>>,
    /// Performance metrics tracking
    metrics: Arc<RwLock<Vec<FfiPerformanceMetrics>>>,
}

impl Default for MindmapBridge {
    fn default() -> Self {
        Self::new()
    }
}

impl MindmapBridge {
    /// Create a new bridge instance
    pub fn new() -> Self {
        Self {
            document: Arc::new(RwLock::new(None)),
            graph: Arc::new(RwLock::new(Graph::new())),
            layout_engine: Arc::new(LayoutEngineImpl::new()),
            search_engine: Arc::new(RwLock::new(SearchEngine::new())),
            metrics: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// Record performance metrics for an operation
    fn record_metrics(&self, operation: &str, start_time: Instant, nodes_processed: u32) {
        let duration = start_time.elapsed();
        let metrics = FfiPerformanceMetrics {
            operation: operation.to_string(),
            duration_ms: duration.as_millis() as u64,
            memory_usage: 0, // TODO: Implement memory tracking
            nodes_processed,
        };

        if let Ok(mut metrics_lock) = self.metrics.write() {
            metrics_lock.push(metrics);
            // Keep only last 100 metrics to prevent memory growth
            if metrics_lock.len() > 100 {
                metrics_lock.remove(0);
            }
        }
    }

    /// Get the current document or return error if none loaded
    fn get_document(&self) -> Result<MindmapDocument, BridgeError> {
        self.document
            .read()
            .map_err(|_| BridgeError::GenericError {
                message: "Failed to acquire document lock".to_string(),
            })?
            .clone()
            .ok_or(BridgeError::InvalidOperation {
                message: "No mindmap document loaded".to_string(),
            })
    }

    /// Update the current document
    fn set_document(&self, document: MindmapDocument) -> Result<(), BridgeError> {
        *self.document.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire document lock".to_string(),
        })? = Some(document);
        Ok(())
    }

    /// Parse string ID to UUID
    fn parse_node_id(&self, id: &str) -> Result<NodeId, BridgeError> {
        super::utils::parse_uuid(id).map(NodeId::from)
    }

    /// Convert internal node to FFI format
    fn node_to_ffi(&self, node: &Node) -> FfiNodeData {
        node.clone().into()
    }
}

#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
impl MindmapFFI for MindmapBridge {
    fn create_node(
        &self,
        parent_id: Option<String>,
        text: String,
    ) -> Result<String, BridgeError> {
        let start_time = Instant::now();

        // Validate input
        super::utils::validate_node_text(&text)?;

        let parent_uuid = if let Some(parent_str) = parent_id {
            Some(self.parse_node_id(&parent_str)?)
        } else {
            None
        };

        // Create new node
        let mut node = if let Some(parent) = parent_uuid {
            Node::new_child(parent, text)
        } else {
            Node::new(text)
        };

        let node_id = node.id;

        // Add node to graph
        let mut graph = self.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        graph
            .add_node(node)
            .map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to add node: {}", e),
            })?;

        // Update search index
        if let Ok(mut search) = self.search_engine.write() {
            if let Ok(updated_node) = graph.get_node(node_id) {
                search.index_node(&updated_node);
            }
        }

        self.record_metrics("create_node", start_time, 1);
        Ok(node_id.to_string())
    }

    fn update_node(
        &self,
        node_id: String,
        update: FfiNodeUpdate,
    ) -> Result<(), BridgeError> {
        let start_time = Instant::now();
        let id = self.parse_node_id(&node_id)?;

        let mut graph = self.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let mut node = graph.get_node(id).map_err(|_| BridgeError::NodeNotFound {
            id: node_id.clone(),
        })?;

        // Apply updates
        if let Some(text) = update.text {
            super::utils::validate_node_text(&text)?;
            node.set_text(text);
        }

        if let Some(position) = update.position {
            super::utils::validate_position(&position)?;
            node.set_position(position.into());
        }

        if let Some(tags) = update.tags {
            super::utils::validate_tags(&tags)?;
            node.tags = tags;
            node.updated_at = chrono::Utc::now();
        }

        if let Some(metadata) = update.metadata {
            node.metadata = metadata;
            node.updated_at = chrono::Utc::now();
        }

        // Update node in graph
        graph
            .update_node(id, node.clone())
            .map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to update node: {}", e),
            })?;

        // Update search index
        if let Ok(mut search) = self.search_engine.write() {
            search.index_node(&node);
        }

        self.record_metrics("update_node", start_time, 1);
        Ok(())
    }

    fn update_node_text(
        &self,
        node_id: String,
        text: String,
    ) -> Result<(), BridgeError> {
        let update = FfiNodeUpdate {
            text: Some(text),
            position: None,
            tags: None,
            metadata: None,
        };
        self.update_node(node_id, update)
    }

    fn update_node_position(
        &self,
        node_id: String,
        position: FfiPoint,
    ) -> Result<(), BridgeError> {
        let update = FfiNodeUpdate {
            text: None,
            position: Some(position),
            tags: None,
            metadata: None,
        };
        self.update_node(node_id, update)
    }

    fn delete_node(&self, node_id: String) -> Result<(), BridgeError> {
        let start_time = Instant::now();
        let id = self.parse_node_id(&node_id)?;

        let mut graph = self.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Get children count for metrics
        let children = graph.get_children(id).unwrap_or_default();
        let nodes_affected = 1 + children.len() as u32;

        // Remove node and all children
        graph
            .remove_node(id)
            .map_err(|_| BridgeError::NodeNotFound {
                id: node_id.clone(),
            })?;

        // Update search index
        if let Ok(mut search) = self.search_engine.write() {
            search.remove_node(id);
            for child in children {
                search.remove_node(child.id);
            }
        }

        self.record_metrics("delete_node", start_time, nodes_affected);
        Ok(())
    }

    fn get_node(&self, node_id: String) -> Result<FfiNodeData, BridgeError> {
        let start_time = Instant::now();
        let id = self.parse_node_id(&node_id)?;

        let graph = self.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let node = graph.get_node(id).map_err(|_| BridgeError::NodeNotFound {
            id: node_id,
        })?;

        self.record_metrics("get_node", start_time, 1);
        Ok(self.node_to_ffi(&node))
    }

    fn get_node_children(&self, node_id: String) -> Result<Vec<FfiNodeData>, BridgeError> {
        let start_time = Instant::now();
        let id = self.parse_node_id(&node_id)?;

        let graph = self.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let children = graph.get_children(id).map_err(|_| BridgeError::NodeNotFound {
            id: node_id,
        })?;

        let result: Vec<FfiNodeData> = children.iter().map(|node| self.node_to_ffi(node)).collect();

        self.record_metrics("get_node_children", start_time, result.len() as u32);
        Ok(result)
    }

    fn get_all_nodes(&self) -> Result<Vec<FfiNodeData>, BridgeError> {
        let start_time = Instant::now();

        let graph = self.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let nodes = graph.get_all_nodes();
        let result: Vec<FfiNodeData> = nodes.iter().map(|node| self.node_to_ffi(node)).collect();

        self.record_metrics("get_all_nodes", start_time, result.len() as u32);
        Ok(result)
    }

    fn calculate_layout(&self, layout_type: FfiLayoutType) -> Result<FfiLayoutResult, BridgeError> {
        let start_time = Instant::now();

        let graph = self.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let layout_result = self
            .layout_engine
            .calculate_layout(&*graph, layout_type.into())
            .map_err(|e| BridgeError::LayoutComputationError {
                message: format!("Layout calculation failed: {}", e),
            })?;

        let node_positions: HashMap<String, FfiPoint> = layout_result
            .positions
            .into_iter()
            .map(|(id, pos)| (id.to_string(), pos.into()))
            .collect();

        let result = FfiLayoutResult {
            node_positions,
            layout_type,
            computation_time_ms: layout_result.computation_time.as_millis() as u64,
        };

        self.record_metrics("calculate_layout", start_time, result.node_positions.len() as u32);
        Ok(result)
    }

    fn apply_layout(&self, layout_result: FfiLayoutResult) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        let mut graph = self.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let mut updates_count = 0;
        for (node_id_str, position) in layout_result.node_positions {
            let node_id = self.parse_node_id(&node_id_str)?;

            if let Ok(mut node) = graph.get_node(node_id) {
                node.set_position(position.into());
                if graph.update_node(node_id, node).is_ok() {
                    updates_count += 1;
                }
            }
        }

        self.record_metrics("apply_layout", start_time, updates_count);
        Ok(())
    }

    fn search_nodes(&self, query: String) -> Result<Vec<FfiSearchResult>, BridgeError> {
        let start_time = Instant::now();

        if query.trim().is_empty() {
            return Ok(Vec::new());
        }

        let search = self.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        let results = search
            .search(&query)
            .map_err(|e| BridgeError::SearchError {
                message: format!("Search failed: {}", e),
            })?;

        let ffi_results: Vec<FfiSearchResult> = results
            .into_iter()
            .map(|result| FfiSearchResult {
                node_id: result.node_id.to_string(),
                text: result.text,
                score: result.score,
                match_positions: result.match_positions,
            })
            .collect();

        self.record_metrics("search_nodes", start_time, ffi_results.len() as u32);
        Ok(ffi_results)
    }

    fn search_by_tags(&self, tags: Vec<String>) -> Result<Vec<FfiSearchResult>, BridgeError> {
        let start_time = Instant::now();

        if tags.is_empty() {
            return Ok(Vec::new());
        }

        let search = self.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        let results = search
            .search_by_tags(&tags)
            .map_err(|e| BridgeError::SearchError {
                message: format!("Tag search failed: {}", e),
            })?;

        let ffi_results: Vec<FfiSearchResult> = results
            .into_iter()
            .map(|result| FfiSearchResult {
                node_id: result.node_id.to_string(),
                text: result.text,
                score: result.score,
                match_positions: vec![], // Tag searches don't have text match positions
            })
            .collect();

        self.record_metrics("search_by_tags", start_time, ffi_results.len() as u32);
        Ok(ffi_results)
    }

    fn create_mindmap(&self, title: String) -> Result<String, BridgeError> {
        let start_time = Instant::now();

        if title.trim().is_empty() {
            return Err(BridgeError::InvalidOperation {
                message: "Mindmap title cannot be empty".to_string(),
            });
        }

        // Create new document with root node
        let root_node = Node::new(&title);
        let root_id = root_node.id;

        let document = MindmapDocument::new(title, root_id);
        let document_id = document.id;

        // Initialize graph with root node
        let mut graph = self.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        *graph = Graph::new();
        graph
            .add_node(root_node.clone())
            .map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to add root node: {}", e),
            })?;

        // Set the document
        self.set_document(document)?;

        // Initialize search index
        if let Ok(mut search) = self.search_engine.write() {
            *search = SearchEngine::new();
            search.index_node(&root_node);
        }

        self.record_metrics("create_mindmap", start_time, 1);
        Ok(document_id.to_string())
    }

    fn load_mindmap(&self, path: String) -> Result<FfiMindmapData, BridgeError> {
        let start_time = Instant::now();

        // TODO: Implement actual file loading
        // For now, return an error indicating not implemented
        Err(BridgeError::GenericError {
            message: "File loading not yet implemented".to_string(),
        })
    }

    fn save_mindmap(&self, path: String) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        // TODO: Implement actual file saving
        // For now, return an error indicating not implemented
        Err(BridgeError::GenericError {
            message: "File saving not yet implemented".to_string(),
        })
    }

    fn export_mindmap(&self, path: String, format: ExportFormat) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        // TODO: Implement actual export functionality
        // For now, return an error indicating not implemented
        Err(BridgeError::GenericError {
            message: "Export functionality not yet implemented".to_string(),
        })
    }

    fn get_mindmap_data(&self) -> Result<FfiMindmapData, BridgeError> {
        let start_time = Instant::now();

        let document = self.get_document()?;
        let graph = self.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let nodes = graph.get_all_nodes();
        let ffi_nodes: Vec<FfiNodeData> = nodes.iter().map(|node| self.node_to_ffi(node)).collect();

        let mindmap_data = FfiMindmapData {
            id: document.id.to_string(),
            title: document.title,
            root_node_id: document.root_node.to_string(),
            nodes: ffi_nodes,
            created_at: document.created_at.timestamp(),
            updated_at: document.updated_at.timestamp(),
        };

        self.record_metrics("get_mindmap_data", start_time, mindmap_data.nodes.len() as u32);
        Ok(mindmap_data)
    }

    fn validate_mindmap(&self) -> Result<bool, BridgeError> {
        let start_time = Instant::now();

        let graph = self.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Validate all nodes
        let nodes = graph.get_all_nodes();
        for node in &nodes {
            if let Err(e) = node.validate() {
                return Err(BridgeError::InvalidOperation { message: e });
            }
        }

        // TODO: Add more validation rules (e.g., graph connectivity, cycles)

        self.record_metrics("validate_mindmap", start_time, nodes.len() as u32);
        Ok(true)
    }

    fn get_engine_info(&self) -> Result<String, BridgeError> {
        let info = crate::info();
        let engine_info = format!(
            "Mindmap Core Engine v{} on {} with features: {:?}",
            info.version, info.platform, info.features
        );
        Ok(engine_info)
    }

    fn initialize(&self) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        crate::init().map_err(|e| BridgeError::GenericError {
            message: format!("Failed to initialize engine: {}", e),
        })?;

        self.record_metrics("initialize", start_time, 0);
        Ok(())
    }

    fn cleanup(&self) -> Result<(), BridgeError> {
        let start_time = Instant::now();

        // Clear all data structures
        if let Ok(mut graph) = self.graph.write() {
            *graph = Graph::new();
        }

        if let Ok(mut document) = self.document.write() {
            *document = None;
        }

        if let Ok(mut search) = self.search_engine.write() {
            *search = SearchEngine::new();
        }

        if let Ok(mut metrics) = self.metrics.write() {
            metrics.clear();
        }

        self.record_metrics("cleanup", start_time, 0);
        Ok(())
    }
}

/// Create a new bridge instance for FFI use
pub fn create_bridge() -> MindmapBridge {
    MindmapBridge::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bridge_creation() {
        let bridge = MindmapBridge::new();
        assert!(bridge.get_all_nodes().unwrap().is_empty());
    }

    #[test]
    fn test_create_and_get_node() {
        let bridge = MindmapBridge::new();

        let node_id = bridge.create_node(None, "Test Node".to_string()).unwrap();
        let node = bridge.get_node(node_id).unwrap();

        assert_eq!(node.text, "Test Node");
        assert!(node.parent_id.is_none());
    }

    #[test]
    fn test_node_text_validation() {
        let bridge = MindmapBridge::new();

        // Empty text should fail
        let result = bridge.create_node(None, "".to_string());
        assert!(result.is_err());

        // Valid text should succeed
        let result = bridge.create_node(None, "Valid text".to_string());
        assert!(result.is_ok());
    }

    #[test]
    fn test_update_node() {
        let bridge = MindmapBridge::new();

        let node_id = bridge.create_node(None, "Original".to_string()).unwrap();

        let update = FfiNodeUpdate {
            text: Some("Updated".to_string()),
            position: Some(FfiPoint { x: 10.0, y: 20.0 }),
            tags: Some(vec!["tag1".to_string()]),
            metadata: None,
        };

        assert!(bridge.update_node(node_id.clone(), update).is_ok());

        let updated_node = bridge.get_node(node_id).unwrap();
        assert_eq!(updated_node.text, "Updated");
        assert_eq!(updated_node.position.x, 10.0);
        assert_eq!(updated_node.position.y, 20.0);
        assert_eq!(updated_node.tags, vec!["tag1".to_string()]);
    }

    #[test]
    fn test_create_mindmap() {
        let bridge = MindmapBridge::new();

        let doc_id = bridge.create_mindmap("Test Mindmap".to_string()).unwrap();
        let mindmap_data = bridge.get_mindmap_data().unwrap();

        assert_eq!(mindmap_data.id, doc_id);
        assert_eq!(mindmap_data.title, "Test Mindmap");
        assert_eq!(mindmap_data.nodes.len(), 1); // Should have root node
    }

    #[test]
    fn test_engine_info() {
        let bridge = MindmapBridge::new();
        let info = bridge.get_engine_info().unwrap();
        assert!(info.contains("Mindmap Core Engine"));
    }
}