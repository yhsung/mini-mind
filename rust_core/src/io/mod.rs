//! File format handlers for mindmap documents
//!
//! This module provides import and export functionality for various file formats
//! including OPML and Markdown, with format detection and validation utilities.

pub mod opml;
pub mod markdown;

use crate::models::document::Document;
use crate::models::node::Node;
use crate::types::{MindmapResult, MindmapError};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Supported file formats for import/export
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum FileFormat {
    /// OPML (Outline Processor Markup Language) format
    Opml,
    /// Markdown outline format
    Markdown,
    /// JSON format (native mindmap format)
    Json,
    /// Plain text format
    Text,
}

impl FileFormat {
    /// Get the file extension for this format
    pub fn extension(&self) -> &'static str {
        match self {
            FileFormat::Opml => "opml",
            FileFormat::Markdown => "md",
            FileFormat::Json => "json",
            FileFormat::Text => "txt",
        }
    }

    /// Get the MIME type for this format
    pub fn mime_type(&self) -> &'static str {
        match self {
            FileFormat::Opml => "text/x-opml",
            FileFormat::Markdown => "text/markdown",
            FileFormat::Json => "application/json",
            FileFormat::Text => "text/plain",
        }
    }

    /// Get a human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            FileFormat::Opml => "OPML (Outline Processor Markup Language)",
            FileFormat::Markdown => "Markdown Outline",
            FileFormat::Json => "JSON (Native Mindmap Format)",
            FileFormat::Text => "Plain Text",
        }
    }
}

/// Import/export options for file operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportExportOptions {
    /// Whether to preserve node IDs during import (default: false - generate new IDs)
    pub preserve_ids: bool,
    /// Whether to include metadata in export (default: true)
    pub include_metadata: bool,
    /// Whether to include timestamps in export (default: true)
    pub include_timestamps: bool,
    /// Maximum depth for export (-1 for unlimited, default: -1)
    pub max_depth: i32,
    /// Whether to include empty nodes (default: false)
    pub include_empty_nodes: bool,
    /// Text encoding for export (default: UTF-8)
    pub encoding: String,
}

impl Default for ImportExportOptions {
    fn default() -> Self {
        Self {
            preserve_ids: false,
            include_metadata: true,
            include_timestamps: true,
            max_depth: -1,
            include_empty_nodes: false,
            encoding: "UTF-8".to_string(),
        }
    }
}

/// Result of an import operation
#[derive(Debug, Clone)]
pub struct ImportResult {
    /// The imported document
    pub document: Document,
    /// Number of nodes imported
    pub node_count: usize,
    /// Number of edges imported
    pub edge_count: usize,
    /// Any warnings encountered during import
    pub warnings: Vec<String>,
}

/// Result of an export operation
#[derive(Debug, Clone)]
pub struct ExportResult {
    /// The exported content as a string
    pub content: String,
    /// Number of nodes exported
    pub node_count: usize,
    /// Number of edges exported
    pub edge_count: usize,
    /// File format used for export
    pub format: FileFormat,
}

/// Trait for file format handlers
pub trait FormatHandler {
    /// Import a document from the given content
    fn import(&self, content: &str, options: &ImportExportOptions) -> MindmapResult<ImportResult>;

    /// Export a document to the format's string representation
    fn export(&self, document: &Document, nodes: &[Node], options: &ImportExportOptions) -> MindmapResult<ExportResult>;

    /// Get the file format this handler supports
    fn format(&self) -> FileFormat;

    /// Validate that the content is in the expected format
    fn validate(&self, content: &str) -> MindmapResult<bool>;
}

/// Main file format manager
pub struct FormatManager {
    handlers: std::collections::HashMap<FileFormat, Box<dyn FormatHandler>>,
}

impl FormatManager {
    /// Create a new format manager with default handlers
    pub fn new() -> Self {
        let mut manager = Self {
            handlers: std::collections::HashMap::new(),
        };

        // Register default handlers
        manager.register_handler(Box::new(opml::OpmlHandler::new()));
        manager.register_handler(Box::new(markdown::MarkdownHandler::new()));

        manager
    }

    /// Register a format handler
    pub fn register_handler(&mut self, handler: Box<dyn FormatHandler>) {
        self.handlers.insert(handler.format(), handler);
    }

    /// Import a document from file content
    pub fn import(&self, content: &str, format: FileFormat, options: &ImportExportOptions) -> MindmapResult<ImportResult> {
        let handler = self.handlers.get(&format)
            .ok_or_else(|| MindmapError::InvalidOperation {
                message: format!("No handler registered for format: {:?}", format),
            })?;

        handler.import(content, options)
    }

    /// Export a document to a specific format
    pub fn export(&self, document: &Document, nodes: &[Node], format: FileFormat, options: &ImportExportOptions) -> MindmapResult<ExportResult> {
        let handler = self.handlers.get(&format)
            .ok_or_else(|| MindmapError::InvalidOperation {
                message: format!("No handler registered for format: {:?}", format),
            })?;

        handler.export(document, nodes, options)
    }

    /// Detect the file format from file extension
    pub fn detect_format_from_path(&self, path: &Path) -> Option<FileFormat> {
        let extension = path.extension()?.to_str()?.to_lowercase();

        match extension.as_str() {
            "opml" => Some(FileFormat::Opml),
            "md" | "markdown" => Some(FileFormat::Markdown),
            "json" => Some(FileFormat::Json),
            "txt" | "text" => Some(FileFormat::Text),
            _ => None,
        }
    }

    /// Detect the file format from content
    pub fn detect_format_from_content(&self, content: &str) -> Option<FileFormat> {
        // Try each handler to see which one validates the content
        for (format, handler) in &self.handlers {
            if handler.validate(content).unwrap_or(false) {
                return Some(*format);
            }
        }

        // Fallback: try to detect by content patterns
        let trimmed = content.trim();
        if trimmed.starts_with("<?xml") && trimmed.contains("<opml") {
            Some(FileFormat::Opml)
        } else if trimmed.starts_with('#') || trimmed.contains("- ") || trimmed.contains("* ") {
            Some(FileFormat::Markdown)
        } else if (trimmed.starts_with('{') && trimmed.ends_with('}')) ||
                  (trimmed.starts_with('[') && trimmed.ends_with(']')) {
            Some(FileFormat::Json)
        } else {
            Some(FileFormat::Text)
        }
    }

    /// Get list of supported formats
    pub fn supported_formats(&self) -> Vec<FileFormat> {
        self.handlers.keys().copied().collect()
    }

    /// Validate content for a specific format
    pub fn validate(&self, content: &str, format: FileFormat) -> MindmapResult<bool> {
        let handler = self.handlers.get(&format)
            .ok_or_else(|| MindmapError::InvalidOperation {
                message: format!("No handler registered for format: {:?}", format),
            })?;

        handler.validate(content)
    }
}

impl Default for FormatManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Utility functions for file operations
pub mod utils {
    use super::*;

    /// Read file content and detect encoding
    pub fn read_file_with_encoding(path: &Path) -> MindmapResult<String> {
        let bytes = std::fs::read(path).map_err(|e| MindmapError::InvalidOperation {
            message: format!("Failed to read file {}: {}", path.display(), e),
        })?;

        // Try UTF-8 first
        match String::from_utf8(bytes.clone()) {
            Ok(content) => Ok(content),
            Err(_) => {
                // Fallback to latin1 or other encodings if needed
                // For now, just try to convert with replacement
                Ok(String::from_utf8_lossy(&bytes).to_string())
            }
        }
    }

    /// Write content to file with proper encoding
    pub fn write_file_with_encoding(path: &Path, content: &str, encoding: &str) -> MindmapResult<()> {
        match encoding.to_uppercase().as_str() {
            "UTF-8" | "UTF8" => {
                std::fs::write(path, content.as_bytes()).map_err(|e| MindmapError::InvalidOperation {
                    message: format!("Failed to write file {}: {}", path.display(), e),
                })
            }
            _ => {
                // For now, default to UTF-8 for unsupported encodings
                std::fs::write(path, content.as_bytes()).map_err(|e| MindmapError::InvalidOperation {
                    message: format!("Failed to write file {}: {}", path.display(), e),
                })
            }
        }
    }

    /// Sanitize text for file output
    pub fn sanitize_text(text: &str) -> String {
        text.chars()
            .map(|c| match c {
                '\0'..='\u{1F}' | '\u{7F}'..='\u{9F}' => ' ', // Replace control characters
                _ => c,
            })
            .collect::<String>()
            .trim()
            .to_string()
    }

    /// Escape special characters for specific formats
    pub fn escape_for_format(text: &str, format: FileFormat) -> String {
        match format {
            FileFormat::Opml => escape_xml(text),
            FileFormat::Markdown => escape_markdown(text),
            FileFormat::Json => serde_json::to_string(text).unwrap_or_else(|_| format!("\"{}\"", text)),
            FileFormat::Text => text.to_string(),
        }
    }

    /// Escape text for XML/OPML
    pub fn escape_xml(text: &str) -> String {
        text.replace('&', "&amp;")
            .replace('<', "&lt;")
            .replace('>', "&gt;")
            .replace('"', "&quot;")
            .replace('\'', "&apos;")
    }

    /// Escape text for Markdown
    pub fn escape_markdown(text: &str) -> String {
        text.replace('\\', "\\\\")
            .replace('*', "\\*")
            .replace('_', "\\_")
            .replace('`', "\\`")
            .replace('[', "\\[")
            .replace(']', "\\]")
            .replace('(', "\\(")
            .replace(')', "\\)")
            .replace('#', "\\#")
            .replace('-', "\\-")
            .replace('+', "\\+")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_file_format_properties() {
        assert_eq!(FileFormat::Opml.extension(), "opml");
        assert_eq!(FileFormat::Markdown.extension(), "md");
        assert_eq!(FileFormat::Json.extension(), "json");
        assert_eq!(FileFormat::Text.extension(), "txt");

        assert_eq!(FileFormat::Opml.mime_type(), "text/x-opml");
        assert_eq!(FileFormat::Markdown.mime_type(), "text/markdown");
    }

    #[test]
    fn test_import_export_options_default() {
        let options = ImportExportOptions::default();
        assert!(!options.preserve_ids);
        assert!(options.include_metadata);
        assert!(options.include_timestamps);
        assert_eq!(options.max_depth, -1);
        assert!(!options.include_empty_nodes);
        assert_eq!(options.encoding, "UTF-8");
    }

    #[test]
    fn test_format_manager_creation() {
        let manager = FormatManager::new();
        let formats = manager.supported_formats();

        assert!(formats.contains(&FileFormat::Opml));
        assert!(formats.contains(&FileFormat::Markdown));
        assert_eq!(formats.len(), 2);
    }

    #[test]
    fn test_format_detection_from_path() {
        let manager = FormatManager::new();

        assert_eq!(manager.detect_format_from_path(Path::new("test.opml")), Some(FileFormat::Opml));
        assert_eq!(manager.detect_format_from_path(Path::new("test.md")), Some(FileFormat::Markdown));
        assert_eq!(manager.detect_format_from_path(Path::new("test.markdown")), Some(FileFormat::Markdown));
        assert_eq!(manager.detect_format_from_path(Path::new("test.json")), Some(FileFormat::Json));
        assert_eq!(manager.detect_format_from_path(Path::new("test.txt")), Some(FileFormat::Text));
        assert_eq!(manager.detect_format_from_path(Path::new("test.unknown")), None);
    }

    #[test]
    fn test_format_detection_from_content() {
        let manager = FormatManager::new();

        // OPML content
        let opml_content = r#"<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Test</title></head>
<body></body>
</opml>"#;
        assert_eq!(manager.detect_format_from_content(opml_content), Some(FileFormat::Opml));

        // Markdown content
        assert_eq!(manager.detect_format_from_content("# Title\n- Item 1"), Some(FileFormat::Markdown));
        assert_eq!(manager.detect_format_from_content("* Item 1\n* Item 2"), Some(FileFormat::Markdown));

        // JSON content
        assert_eq!(manager.detect_format_from_content("{}"), Some(FileFormat::Json));
        assert_eq!(manager.detect_format_from_content("[]"), Some(FileFormat::Json));

        // Text content (fallback)
        assert_eq!(manager.detect_format_from_content("plain text"), Some(FileFormat::Text));
    }

    #[test]
    fn test_utils_sanitize_text() {
        assert_eq!(utils::sanitize_text("Hello\x00World\x1F"), "Hello World");
        assert_eq!(utils::sanitize_text("  spaced  "), "spaced");
        assert_eq!(utils::sanitize_text("normal text"), "normal text");
    }

    #[test]
    fn test_utils_escape_xml() {
        assert_eq!(utils::escape_xml("Hello & <world>"), "Hello &amp; &lt;world&gt;");
        assert_eq!(utils::escape_xml("Quote \"test\""), "Quote &quot;test&quot;");
    }

    #[test]
    fn test_utils_escape_markdown() {
        assert_eq!(utils::escape_markdown("*bold* text"), "\\*bold\\* text");
        assert_eq!(utils::escape_markdown("[link](url)"), "\\[link\\]\\(url\\)");
        assert_eq!(utils::escape_markdown("# Header"), "\\# Header");
    }
}