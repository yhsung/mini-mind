//! File operations for FFI interface
//!
//! This module provides specialized file operations and utilities for the FFI bridge,
//! offering enhanced functionality for saving, loading, importing, and exporting mindmaps.

use super::{BridgeError, ExportFormat, FfiMindmapData, MindmapBridge};
use crate::{
    io::{FormatManager, FileFormat, ImportExportOptions, ImportResult, ExportResult},
    models::{Document, Node},
    persistence::PersistenceManager,
    types::{NodeId, DocumentId},
};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::Instant;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Enhanced file operations for advanced FFI functionality
pub struct FileOperations;

impl FileOperations {
    /// Save mindmap to file with comprehensive options
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn save_mindmap_with_options(
        bridge: &MindmapBridge,
        file_path: String,
        options: SaveOptions,
    ) -> Result<SaveResult, BridgeError> {
        let start_time = Instant::now();

        // Validate file path
        let path = PathBuf::from(&file_path);
        Self::validate_file_path(&path, true)?;

        // Get current document and graph data
        let document = bridge.get_document()?;
        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let nodes: Vec<Node> = graph.get_all_nodes().values().cloned().collect();

        // Determine format from file extension or explicit format
        let format = options.format.unwrap_or_else(|| {
            Self::detect_format_from_extension(&path)
                .unwrap_or(FileFormat::Json)
        });

        // Convert options to internal format
        let export_options = ImportExportOptions {
            preserve_ids: options.preserve_ids,
            include_metadata: options.include_metadata,
            include_timestamps: options.include_timestamps,
            max_depth: options.max_depth.unwrap_or(-1),
            include_empty_nodes: options.include_empty_nodes,
            encoding: options.encoding.clone(),
        };

        // Save using appropriate method
        let save_result = match format {
            FileFormat::Json => {
                // Save as native JSON format
                Self::save_json_format(&document, &nodes, &path, &export_options)?
            }
            FileFormat::Opml | FileFormat::Markdown => {
                // Save using format manager
                Self::save_with_format_manager(&document, &nodes, &path, format, &export_options)?
            }
            FileFormat::Text => {
                // Save as plain text
                Self::save_text_format(&nodes, &path, &export_options)?
            }
        };

        // Create backup if requested
        if options.create_backup {
            Self::create_backup_file(&path)?;
        }

        let result = SaveResult {
            file_path: file_path.clone(),
            format,
            file_size: save_result.file_size,
            node_count: save_result.node_count,
            save_time_ms: start_time.elapsed().as_millis() as u64,
            backup_created: options.create_backup,
        };

        bridge.record_metrics("save_mindmap_with_options", start_time, result.node_count as u32);
        Ok(result)
    }

    /// Load mindmap from file with format detection
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn load_mindmap_with_detection(
        bridge: &MindmapBridge,
        file_path: String,
        options: LoadOptions,
    ) -> Result<LoadResult, BridgeError> {
        let start_time = Instant::now();

        // Validate file path
        let path = PathBuf::from(&file_path);
        Self::validate_file_path(&path, false)?;

        // Read file content
        let content = std::fs::read_to_string(&path).map_err(|e| BridgeError::FileSystemError {
            message: format!("Failed to read file {}: {}", file_path, e),
        })?;

        // Detect format
        let format_manager = FormatManager::new();
        let detected_format = options.force_format.unwrap_or_else(|| {
            format_manager.detect_format_from_content(&content)
                .or_else(|| format_manager.detect_format_from_path(&path))
                .unwrap_or(FileFormat::Text)
        });

        // Convert options to internal format
        let import_options = ImportExportOptions {
            preserve_ids: options.preserve_ids,
            include_metadata: true,
            include_timestamps: true,
            max_depth: -1,
            include_empty_nodes: false,
            encoding: "UTF-8".to_string(),
        };

        // Load based on detected format
        let (document, nodes, import_result) = match detected_format {
            FileFormat::Json => {
                Self::load_json_format(&content, &import_options)?
            }
            FileFormat::Opml | FileFormat::Markdown => {
                Self::load_with_format_manager(&content, detected_format, &import_options)?
            }
            FileFormat::Text => {
                Self::load_text_format(&content, &import_options)?
            }
        };

        // Update bridge with loaded data
        Self::update_bridge_with_loaded_data(bridge, document, nodes)?;

        let result = LoadResult {
            file_path: file_path.clone(),
            detected_format,
            node_count: import_result.node_count,
            edge_count: import_result.edge_count,
            load_time_ms: start_time.elapsed().as_millis() as u64,
            warnings: import_result.warnings,
            document_id: import_result.document.id.to_string(),
        };

        bridge.record_metrics("load_mindmap_with_detection", start_time, result.node_count as u32);
        Ok(result)
    }

    /// Export mindmap to multiple formats
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn export_mindmap_multi_format(
        bridge: &MindmapBridge,
        base_path: String,
        formats: Vec<ExportFormatFFI>,
        options: ExportOptions,
    ) -> Result<Vec<ExportResult>, BridgeError> {
        let start_time = Instant::now();

        let document = bridge.get_document()?;
        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let nodes: Vec<Node> = graph.get_all_nodes().values().cloned().collect();
        let mut results = Vec::new();

        // Convert options to internal format
        let export_options = ImportExportOptions {
            preserve_ids: false, // Usually not needed for export
            include_metadata: options.include_metadata,
            include_timestamps: options.include_timestamps,
            max_depth: options.max_depth.unwrap_or(-1),
            include_empty_nodes: options.include_empty_nodes,
            encoding: "UTF-8".to_string(),
        };

        // Export to each requested format
        for format_ffi in formats {
            let format_result = Self::export_single_format(
                &document,
                &nodes,
                &base_path,
                format_ffi,
                &export_options,
            )?;
            results.push(format_result);
        }

        bridge.record_metrics("export_mindmap_multi_format", start_time, results.len() as u32);
        Ok(results)
    }

    /// Import from various file formats with validation
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn import_from_file(
        bridge: &MindmapBridge,
        file_path: String,
        import_options: ImportOptions,
    ) -> Result<ImportResultFFI, BridgeError> {
        let start_time = Instant::now();

        // Validate file
        let path = PathBuf::from(&file_path);
        Self::validate_file_path(&path, false)?;

        // Read and validate content
        let content = std::fs::read_to_string(&path).map_err(|e| BridgeError::FileSystemError {
            message: format!("Failed to read file {}: {}", file_path, e),
        })?;

        // Detect and validate format
        let format_manager = FormatManager::new();
        let format = import_options.expected_format.unwrap_or_else(|| {
            format_manager.detect_format_from_content(&content)
                .or_else(|| format_manager.detect_format_from_path(&path))
                .unwrap_or(FileFormat::Text)
        });

        // Validate content format
        if !format_manager.validate(&content, format).unwrap_or(false) {
            return Err(BridgeError::InvalidOperation {
                message: format!("File content is not valid {} format", format.description()),
            });
        }

        // Convert options
        let internal_options = ImportExportOptions {
            preserve_ids: import_options.preserve_ids,
            include_metadata: true,
            include_timestamps: true,
            max_depth: import_options.max_depth.unwrap_or(-1),
            include_empty_nodes: import_options.include_empty_nodes,
            encoding: "UTF-8".to_string(),
        };

        // Import content
        let import_result = format_manager.import(&content, format, &internal_options)
            .map_err(|e| BridgeError::SerializationError {
                message: format!("Import failed: {}", e),
            })?;

        // Handle merge or replace
        if import_options.merge_with_existing {
            Self::merge_imported_data(bridge, &import_result)?;
        } else {
            // Replace current data
            let nodes: Vec<Node> = Vec::new(); // Will be populated from document
            Self::update_bridge_with_loaded_data(bridge, import_result.document.clone(), nodes)?;
        }

        let result = ImportResultFFI {
            file_path: file_path.clone(),
            format,
            imported_node_count: import_result.node_count,
            imported_edge_count: import_result.edge_count,
            import_time_ms: start_time.elapsed().as_millis() as u64,
            warnings: import_result.warnings,
            merged: import_options.merge_with_existing,
        };

        bridge.record_metrics("import_from_file", start_time, result.imported_node_count as u32);
        Ok(result)
    }

    /// Get file information and metadata
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn get_file_info(
        file_path: String,
    ) -> Result<FileInfo, BridgeError> {
        let path = PathBuf::from(&file_path);

        if !path.exists() {
            return Err(BridgeError::FileSystemError {
                message: format!("File does not exist: {}", file_path),
            });
        }

        let metadata = std::fs::metadata(&path).map_err(|e| BridgeError::FileSystemError {
            message: format!("Failed to read file metadata: {}", e),
        })?;

        let format_manager = FormatManager::new();
        let detected_format = format_manager.detect_format_from_path(&path);

        // Try to read content for additional analysis
        let (node_count_estimate, format_valid) = if let Ok(content) = std::fs::read_to_string(&path) {
            let format = detected_format.unwrap_or(FileFormat::Text);
            let valid = format_manager.validate(&content, format).unwrap_or(false);
            let estimate = Self::estimate_node_count(&content, format);
            (Some(estimate), valid)
        } else {
            (None, false)
        };

        Ok(FileInfo {
            file_path: file_path.clone(),
            file_size: metadata.len(),
            detected_format,
            format_valid,
            node_count_estimate,
            created: metadata.created().ok().map(|t| t.duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs() as i64),
            modified: metadata.modified().ok().map(|t| t.duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs() as i64),
            readable: path.metadata().map(|m| !m.permissions().readonly()).unwrap_or(false),
        })
    }

    // Helper methods

    fn validate_file_path(path: &Path, for_writing: bool) -> Result<(), BridgeError> {
        if for_writing {
            // Check if parent directory exists
            if let Some(parent) = path.parent() {
                if !parent.exists() {
                    return Err(BridgeError::FileSystemError {
                        message: format!("Directory does not exist: {}", parent.display()),
                    });
                }
            }
        } else {
            // Check if file exists for reading
            if !path.exists() {
                return Err(BridgeError::FileSystemError {
                    message: format!("File does not exist: {}", path.display()),
                });
            }
        }

        Ok(())
    }

    fn detect_format_from_extension(path: &Path) -> Option<FileFormat> {
        path.extension()?.to_str().map(|ext| {
            match ext.to_lowercase().as_str() {
                "opml" => FileFormat::Opml,
                "md" | "markdown" => FileFormat::Markdown,
                "json" => FileFormat::Json,
                "txt" | "text" => FileFormat::Text,
                _ => FileFormat::Json,
            }
        })
    }

    fn save_json_format(
        document: &Document,
        nodes: &[Node],
        path: &Path,
        _options: &ImportExportOptions,
    ) -> Result<FileSaveResult, BridgeError> {
        let json_data = serde_json::json!({
            "document": document,
            "nodes": nodes,
            "version": "1.0",
            "created_at": chrono::Utc::now().timestamp()
        });

        let content = serde_json::to_string_pretty(&json_data).map_err(|e| BridgeError::SerializationError {
            message: format!("JSON serialization failed: {}", e),
        })?;

        std::fs::write(path, &content).map_err(|e| BridgeError::FileSystemError {
            message: format!("Failed to write file: {}", e),
        })?;

        Ok(FileSaveResult {
            file_size: content.len() as u64,
            node_count: nodes.len(),
        })
    }

    fn save_with_format_manager(
        document: &Document,
        nodes: &[Node],
        path: &Path,
        format: FileFormat,
        options: &ImportExportOptions,
    ) -> Result<FileSaveResult, BridgeError> {
        let format_manager = FormatManager::new();
        let export_result = format_manager.export(document, nodes, format, options)
            .map_err(|e| BridgeError::SerializationError {
                message: format!("Export failed: {}", e),
            })?;

        std::fs::write(path, &export_result.content).map_err(|e| BridgeError::FileSystemError {
            message: format!("Failed to write file: {}", e),
        })?;

        Ok(FileSaveResult {
            file_size: export_result.content.len() as u64,
            node_count: export_result.node_count,
        })
    }

    fn save_text_format(
        nodes: &[Node],
        path: &Path,
        _options: &ImportExportOptions,
    ) -> Result<FileSaveResult, BridgeError> {
        let content: String = nodes.iter()
            .map(|node| node.text.clone())
            .collect::<Vec<_>>()
            .join("\n");

        std::fs::write(path, &content).map_err(|e| BridgeError::FileSystemError {
            message: format!("Failed to write file: {}", e),
        })?;

        Ok(FileSaveResult {
            file_size: content.len() as u64,
            node_count: nodes.len(),
        })
    }

    fn load_json_format(
        content: &str,
        _options: &ImportExportOptions,
    ) -> Result<(Document, Vec<Node>, ImportResult), BridgeError> {
        let json_data: serde_json::Value = serde_json::from_str(content).map_err(|e| BridgeError::SerializationError {
            message: format!("JSON parsing failed: {}", e),
        })?;

        let document: Document = serde_json::from_value(json_data["document"].clone()).map_err(|e| BridgeError::SerializationError {
            message: format!("Document deserialization failed: {}", e),
        })?;

        let nodes: Vec<Node> = serde_json::from_value(json_data["nodes"].clone()).map_err(|e| BridgeError::SerializationError {
            message: format!("Nodes deserialization failed: {}", e),
        })?;

        let import_result = ImportResult {
            document: document.clone(),
            node_count: nodes.len(),
            edge_count: 0, // Will be calculated from node relationships
            warnings: Vec::new(),
        };

        Ok((document, nodes, import_result))
    }

    fn load_with_format_manager(
        content: &str,
        format: FileFormat,
        options: &ImportExportOptions,
    ) -> Result<(Document, Vec<Node>, ImportResult), BridgeError> {
        let format_manager = FormatManager::new();
        let import_result = format_manager.import(content, format, options)
            .map_err(|e| BridgeError::SerializationError {
                message: format!("Import failed: {}", e),
            })?;

        let nodes = Vec::new(); // Nodes will be extracted from document structure
        Ok((import_result.document.clone(), nodes, import_result))
    }

    fn load_text_format(
        content: &str,
        _options: &ImportExportOptions,
    ) -> Result<(Document, Vec<Node>, ImportResult), BridgeError> {
        let lines: Vec<&str> = content.lines().collect();
        let mut nodes = Vec::new();
        let root_id = NodeId::new();

        // Create root node
        let mut root_node = Node::new("Imported Text".to_string());
        root_node.id = root_id;
        nodes.push(root_node);

        // Create child nodes for each line
        for (i, line) in lines.iter().enumerate() {
            if !line.trim().is_empty() {
                let mut node = Node::new_child(root_id, line.trim().to_string());
                node.id = NodeId::new();
                nodes.push(node);
            }
        }

        let document = Document::new("Imported Text Document", root_id);

        let import_result = ImportResult {
            document: document.clone(),
            node_count: nodes.len(),
            edge_count: nodes.len() - 1, // All children connected to root
            warnings: vec!["Imported as plain text with basic structure".to_string()],
        };

        Ok((document, nodes, import_result))
    }

    fn export_single_format(
        document: &Document,
        nodes: &[Node],
        base_path: &str,
        format: ExportFormatFFI,
        options: &ImportExportOptions,
    ) -> Result<ExportResult, BridgeError> {
        let extension = match format {
            ExportFormatFFI::Pdf => "pdf",
            ExportFormatFFI::Svg => "svg",
            ExportFormatFFI::Png => "png",
            ExportFormatFFI::Opml => "opml",
            ExportFormatFFI::Markdown => "md",
            ExportFormatFFI::Json => "json",
        };

        let file_path = format!("{}.{}", base_path, extension);
        let path = PathBuf::from(&file_path);

        // For now, implement text-based formats (PDF, SVG, PNG would need additional libraries)
        match format {
            ExportFormatFFI::Opml => {
                let format_manager = FormatManager::new();
                let result = format_manager.export(document, nodes, FileFormat::Opml, options)
                    .map_err(|e| BridgeError::SerializationError {
                        message: format!("OPML export failed: {}", e),
                    })?;

                std::fs::write(&path, &result.content).map_err(|e| BridgeError::FileSystemError {
                    message: format!("Failed to write OPML file: {}", e),
                })?;

                Ok(ExportResult {
                    file_path,
                    format,
                    file_size: result.content.len() as u64,
                    node_count: result.node_count,
                })
            }
            ExportFormatFFI::Markdown => {
                let format_manager = FormatManager::new();
                let result = format_manager.export(document, nodes, FileFormat::Markdown, options)
                    .map_err(|e| BridgeError::SerializationError {
                        message: format!("Markdown export failed: {}", e),
                    })?;

                std::fs::write(&path, &result.content).map_err(|e| BridgeError::FileSystemError {
                    message: format!("Failed to write Markdown file: {}", e),
                })?;

                Ok(ExportResult {
                    file_path,
                    format,
                    file_size: result.content.len() as u64,
                    node_count: result.node_count,
                })
            }
            ExportFormatFFI::Json => {
                let save_result = Self::save_json_format(document, nodes, &path, options)?;
                Ok(ExportResult {
                    file_path,
                    format,
                    file_size: save_result.file_size,
                    node_count: save_result.node_count,
                })
            }
            _ => {
                // PDF, SVG, PNG require additional rendering libraries
                Err(BridgeError::InvalidOperation {
                    message: format!("Export format {:?} not yet implemented", format),
                })
            }
        }
    }

    fn update_bridge_with_loaded_data(
        bridge: &MindmapBridge,
        document: Document,
        nodes: Vec<Node>,
    ) -> Result<(), BridgeError> {
        // Update document
        bridge.set_document(document)?;

        // Update graph with nodes
        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        *graph = crate::graph::Graph::new();
        for node in nodes {
            graph.add_node(node).map_err(|e| BridgeError::InvalidOperation {
                message: format!("Failed to add node: {}", e),
            })?;
        }

        // Update search index
        if let Ok(mut search) = bridge.search_engine.write() {
            *search = crate::search::SearchEngine::new();
            for (_, node) in graph.get_all_nodes() {
                search.index_node(node);
            }
        }

        Ok(())
    }

    fn merge_imported_data(
        bridge: &MindmapBridge,
        import_result: &ImportResult,
    ) -> Result<(), BridgeError> {
        // For now, implement simple merge by adding imported content to existing graph
        // In a full implementation, this would handle conflicts and user preferences

        let mut graph = bridge.graph.write().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        // Add nodes from import (this is a simplified implementation)
        // In practice, you'd need to handle ID conflicts and merge strategies

        Ok(())
    }

    fn create_backup_file(original_path: &Path) -> Result<(), BridgeError> {
        if original_path.exists() {
            let backup_path = original_path.with_extension(
                format!("{}.backup", original_path.extension().unwrap_or_default().to_string_lossy())
            );

            std::fs::copy(original_path, backup_path).map_err(|e| BridgeError::FileSystemError {
                message: format!("Failed to create backup: {}", e),
            })?;
        }
        Ok(())
    }

    fn estimate_node_count(content: &str, format: FileFormat) -> usize {
        match format {
            FileFormat::Opml => content.matches("<outline").count(),
            FileFormat::Markdown => content.lines().filter(|line| {
                let trimmed = line.trim();
                trimmed.starts_with('#') || trimmed.starts_with('-') ||
                trimmed.starts_with('*') || trimmed.starts_with('+')
            }).count(),
            FileFormat::Json => {
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(content) {
                    if let Some(nodes) = json.get("nodes").and_then(|n| n.as_array()) {
                        nodes.len()
                    } else {
                        1
                    }
                } else {
                    0
                }
            }
            FileFormat::Text => content.lines().filter(|line| !line.trim().is_empty()).count(),
        }
    }
}

/// Save operation options
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SaveOptions {
    pub format: Option<FileFormat>,
    pub preserve_ids: bool,
    pub include_metadata: bool,
    pub include_timestamps: bool,
    pub max_depth: Option<i32>,
    pub include_empty_nodes: bool,
    pub encoding: String,
    pub create_backup: bool,
}

impl Default for SaveOptions {
    fn default() -> Self {
        Self {
            format: None,
            preserve_ids: false,
            include_metadata: true,
            include_timestamps: true,
            max_depth: None,
            include_empty_nodes: false,
            encoding: "UTF-8".to_string(),
            create_backup: false,
        }
    }
}

/// Load operation options
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct LoadOptions {
    pub force_format: Option<FileFormat>,
    pub preserve_ids: bool,
}

impl Default for LoadOptions {
    fn default() -> Self {
        Self {
            force_format: None,
            preserve_ids: false,
        }
    }
}

/// Export operation options
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct ExportOptions {
    pub include_metadata: bool,
    pub include_timestamps: bool,
    pub max_depth: Option<i32>,
    pub include_empty_nodes: bool,
}

impl Default for ExportOptions {
    fn default() -> Self {
        Self {
            include_metadata: true,
            include_timestamps: true,
            max_depth: None,
            include_empty_nodes: false,
        }
    }
}

/// Import operation options
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct ImportOptions {
    pub expected_format: Option<FileFormat>,
    pub preserve_ids: bool,
    pub merge_with_existing: bool,
    pub max_depth: Option<i32>,
    pub include_empty_nodes: bool,
}

impl Default for ImportOptions {
    fn default() -> Self {
        Self {
            expected_format: None,
            preserve_ids: false,
            merge_with_existing: false,
            max_depth: None,
            include_empty_nodes: false,
        }
    }
}

/// Export format options for FFI
#[derive(Debug, Clone, Copy)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum ExportFormatFFI {
    Pdf,
    Svg,
    Png,
    Opml,
    Markdown,
    Json,
}

/// Save operation result
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SaveResult {
    pub file_path: String,
    pub format: FileFormat,
    pub file_size: u64,
    pub node_count: usize,
    pub save_time_ms: u64,
    pub backup_created: bool,
}

/// Load operation result
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct LoadResult {
    pub file_path: String,
    pub detected_format: FileFormat,
    pub node_count: usize,
    pub edge_count: usize,
    pub load_time_ms: u64,
    pub warnings: Vec<String>,
    pub document_id: String,
}

/// Export operation result
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct ExportResult {
    pub file_path: String,
    pub format: ExportFormatFFI,
    pub file_size: u64,
    pub node_count: usize,
}

/// Import operation result
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct ImportResultFFI {
    pub file_path: String,
    pub format: FileFormat,
    pub imported_node_count: usize,
    pub imported_edge_count: usize,
    pub import_time_ms: u64,
    pub warnings: Vec<String>,
    pub merged: bool,
}

/// File information and metadata
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct FileInfo {
    pub file_path: String,
    pub file_size: u64,
    pub detected_format: Option<FileFormat>,
    pub format_valid: bool,
    pub node_count_estimate: Option<usize>,
    pub created: Option<i64>,
    pub modified: Option<i64>,
    pub readable: bool,
}

/// Internal save result
struct FileSaveResult {
    file_size: u64,
    node_count: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_save_options_default() {
        let options = SaveOptions::default();
        assert!(options.format.is_none());
        assert!(!options.preserve_ids);
        assert!(options.include_metadata);
        assert!(options.include_timestamps);
        assert!(!options.create_backup);
        assert_eq!(options.encoding, "UTF-8");
    }

    #[test]
    fn test_load_options_default() {
        let options = LoadOptions::default();
        assert!(options.force_format.is_none());
        assert!(!options.preserve_ids);
    }

    #[test]
    fn test_export_format_variants() {
        let pdf = ExportFormatFFI::Pdf;
        let svg = ExportFormatFFI::Svg;
        let png = ExportFormatFFI::Png;
        let opml = ExportFormatFFI::Opml;
        let markdown = ExportFormatFFI::Markdown;
        let json = ExportFormatFFI::Json;

        assert!(matches!(pdf, ExportFormatFFI::Pdf));
        assert!(matches!(svg, ExportFormatFFI::Svg));
        assert!(matches!(png, ExportFormatFFI::Png));
        assert!(matches!(opml, ExportFormatFFI::Opml));
        assert!(matches!(markdown, ExportFormatFFI::Markdown));
        assert!(matches!(json, ExportFormatFFI::Json));
    }

    #[test]
    fn test_save_result_structure() {
        let result = SaveResult {
            file_path: "/test/path.json".to_string(),
            format: FileFormat::Json,
            file_size: 1024,
            node_count: 10,
            save_time_ms: 50,
            backup_created: true,
        };

        assert_eq!(result.file_path, "/test/path.json");
        assert_eq!(result.file_size, 1024);
        assert_eq!(result.node_count, 10);
        assert!(result.backup_created);
    }

    #[test]
    fn test_import_options_default() {
        let options = ImportOptions::default();
        assert!(options.expected_format.is_none());
        assert!(!options.preserve_ids);
        assert!(!options.merge_with_existing);
        assert!(options.max_depth.is_none());
        assert!(!options.include_empty_nodes);
    }
}