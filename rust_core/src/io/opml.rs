//! OPML (Outline Processor Markup Language) import/export handler
//!
//! This module provides functionality to import and export mindmap documents
//! to/from OPML format, preserving the hierarchical structure of nodes.

use super::{FormatHandler, FileFormat, ImportExportOptions, ImportResult, ExportResult};
use crate::models::document::Document;
use crate::models::node::Node;
use crate::types::{ids::NodeId, MindmapResult, MindmapError, Point};
use std::collections::HashMap;

/// OPML format handler
pub struct OpmlHandler;

impl OpmlHandler {
    /// Create a new OPML handler
    pub fn new() -> Self {
        Self
    }

    /// Parse OPML content and extract outline items
    fn parse_opml_content(&self, content: &str) -> MindmapResult<OpmlDocument> {
        let content = content.trim();

        // Basic XML validation
        if !content.starts_with("<?xml") && !content.contains("<opml") {
            return Err(MindmapError::InvalidOperation {
                message: "Content does not appear to be valid OPML".to_string(),
            });
        }

        // Extract head information
        let title = self.extract_xml_content(content, "title").unwrap_or("Untitled OPML Document".to_string());
        let date_created = self.extract_xml_content(content, "dateCreated");
        let date_modified = self.extract_xml_content(content, "dateModified");

        // Extract body content and parse outline items
        let body_content = self.extract_xml_content(content, "body")
            .unwrap_or_else(|| {
                // If no body tag found, try to extract outline items directly
                content.to_string()
            });

        let outline_items = self.parse_outline_items(&body_content)?;

        Ok(OpmlDocument {
            title,
            date_created,
            date_modified,
            outline_items,
        })
    }

    /// Extract content between XML tags
    fn extract_xml_content(&self, content: &str, tag: &str) -> Option<String> {
        let start_tag = format!("<{}>", tag);
        let end_tag = format!("</{}>", tag);

        let start_pos = content.find(&start_tag)? + start_tag.len();
        let end_pos = content[start_pos..].find(&end_tag)? + start_pos;

        Some(self.unescape_xml(&content[start_pos..end_pos]))
    }

    /// Parse outline items from OPML body content
    fn parse_outline_items(&self, content: &str) -> MindmapResult<Vec<OutlineItem>> {
        let mut items = Vec::new();
        let depth = 0;
        let mut current_pos = 0;

        while let Some(outline_start) = content[current_pos..].find("<outline") {
            let absolute_pos = current_pos + outline_start;

            // Find the end of this outline tag
            let tag_end = content[absolute_pos..].find('>')
                .ok_or_else(|| MindmapError::InvalidOperation {
                    message: "Malformed outline tag".to_string(),
                })?;

            let tag_content = &content[absolute_pos..absolute_pos + tag_end + 1];

            // Check if it's a self-closing tag
            let is_self_closing = tag_content.ends_with("/>");

            // Extract attributes
            let text = self.extract_outline_attribute(tag_content, "text")
                .unwrap_or_else(|| self.extract_outline_attribute(tag_content, "_note").unwrap_or("".to_string()));

            let note = self.extract_outline_attribute(tag_content, "_note");

            let item = OutlineItem {
                text,
                note,
                depth,
                children: Vec::new(),
            };

            // If not self-closing, we need to handle nested items
            if !is_self_closing {
                // Find matching closing tag and parse children
                let children_start = absolute_pos + tag_end + 1;
                let closing_tag = "</outline>";

                if let Some(closing_pos) = content[children_start..].find(closing_tag) {
                    let children_content = &content[children_start..children_start + closing_pos];

                    // Parse children recursively (simplified for now)
                    let child_items = self.parse_outline_items_simple(children_content, depth + 1)?;

                    let mut item_with_children = item;
                    item_with_children.children = child_items;
                    items.push(item_with_children);

                    current_pos = children_start + closing_pos + closing_tag.len();
                } else {
                    items.push(item);
                    current_pos = absolute_pos + tag_end + 1;
                }
            } else {
                items.push(item);
                current_pos = absolute_pos + tag_end + 1;
            }
        }

        Ok(items)
    }

    /// Simplified parsing for child outline items
    fn parse_outline_items_simple(&self, content: &str, depth: usize) -> MindmapResult<Vec<OutlineItem>> {
        let mut items = Vec::new();
        let mut current_pos = 0;

        while let Some(outline_start) = content[current_pos..].find("<outline") {
            let absolute_pos = current_pos + outline_start;

            if let Some(tag_end) = content[absolute_pos..].find('>') {
                let tag_content = &content[absolute_pos..absolute_pos + tag_end + 1];

                let text = self.extract_outline_attribute(tag_content, "text")
                    .unwrap_or_else(|| self.extract_outline_attribute(tag_content, "_note").unwrap_or("".to_string()));

                let note = self.extract_outline_attribute(tag_content, "_note");

                items.push(OutlineItem {
                    text,
                    note,
                    depth,
                    children: Vec::new(),
                });

                current_pos = absolute_pos + tag_end + 1;
            } else {
                break;
            }
        }

        Ok(items)
    }

    /// Extract attribute value from outline tag
    fn extract_outline_attribute(&self, tag_content: &str, attr_name: &str) -> Option<String> {
        let attr_pattern = format!("{}=\"", attr_name);
        let start_pos = tag_content.find(&attr_pattern)? + attr_pattern.len();
        let end_pos = tag_content[start_pos..].find('"')? + start_pos;

        Some(self.unescape_xml(&tag_content[start_pos..end_pos]))
    }

    /// Convert outline items to mindmap nodes
    fn outline_items_to_nodes(&self, items: &[OutlineItem], parent_id: Option<NodeId>, options: &ImportExportOptions) -> Vec<Node> {
        let mut nodes = Vec::new();
        let mut y_offset = 0.0;

        for item in items {
            let node_id = if options.preserve_ids {
                // For now, generate new IDs since OPML doesn't typically have node IDs
                NodeId::new()
            } else {
                NodeId::new()
            };

            let mut node = Node::new(&item.text);
            node.id = node_id;
            node.parent_id = parent_id;
            node.position = Point::new(
                (item.depth as f64) * 200.0, // Spread nodes horizontally by depth
                y_offset
            );

            // Add note as metadata if present
            if let Some(ref note) = item.note {
                if !note.is_empty() {
                    node.set_metadata("note", note);
                }
            }

            y_offset += 100.0; // Space nodes vertically

            nodes.push(node);

            // Process children recursively
            if !item.children.is_empty() {
                let mut child_nodes = self.outline_items_to_nodes(&item.children, Some(node_id), options);
                nodes.append(&mut child_nodes);
            }
        }

        nodes
    }

    /// Convert nodes to OPML outline items
    fn nodes_to_outline_items(&self, nodes: &[Node], root_node_id: NodeId, options: &ImportExportOptions) -> Vec<OutlineItem> {
        let mut items = Vec::new();

        // Build parent-child relationships
        let mut children_map: HashMap<NodeId, Vec<&Node>> = HashMap::new();
        for node in nodes {
            if let Some(parent_id) = node.parent_id {
                children_map.entry(parent_id).or_default().push(node);
            }
        }

        // Find root node
        if let Some(root_node) = nodes.iter().find(|n| n.id == root_node_id) {
            let root_item = self.node_to_outline_item(root_node, &children_map, options, 0);
            items.push(root_item);
        }

        items
    }

    /// Convert a single node to an outline item
    fn node_to_outline_item(&self, node: &Node, children_map: &HashMap<NodeId, Vec<&Node>>, options: &ImportExportOptions, depth: usize) -> OutlineItem {
        let text = if options.include_empty_nodes || !node.text.trim().is_empty() {
            node.text.clone()
        } else {
            "Empty Node".to_string()
        };

        let note = if options.include_metadata {
            node.get_metadata("note").cloned()
        } else {
            None
        };

        let mut children = Vec::new();
        if let Some(child_nodes) = children_map.get(&node.id) {
            for child_node in child_nodes {
                if options.max_depth < 0 || depth < options.max_depth as usize {
                    children.push(self.node_to_outline_item(child_node, children_map, options, depth + 1));
                }
            }
        }

        OutlineItem {
            text,
            note,
            depth,
            children,
        }
    }

    /// Generate OPML XML from outline items
    fn generate_opml_xml(&self, doc: &OpmlDocument) -> String {
        let mut xml = String::new();

        // XML declaration
        xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        xml.push_str("<opml version=\"2.0\">\n");

        // Head section
        xml.push_str("  <head>\n");
        xml.push_str(&format!("    <title>{}</title>\n", self.escape_xml(&doc.title)));

        if let Some(ref date_created) = doc.date_created {
            xml.push_str(&format!("    <dateCreated>{}</dateCreated>\n", self.escape_xml(date_created)));
        }

        if let Some(ref date_modified) = doc.date_modified {
            xml.push_str(&format!("    <dateModified>{}</dateModified>\n", self.escape_xml(date_modified)));
        }

        xml.push_str("  </head>\n");

        // Body section
        xml.push_str("  <body>\n");

        for item in &doc.outline_items {
            xml.push_str(&self.outline_item_to_xml(item, 2));
        }

        xml.push_str("  </body>\n");
        xml.push_str("</opml>\n");

        xml
    }

    /// Convert outline item to XML
    fn outline_item_to_xml(&self, item: &OutlineItem, indent_level: usize) -> String {
        let indent = "  ".repeat(indent_level);
        let mut xml = String::new();

        if item.children.is_empty() {
            // Self-closing tag
            xml.push_str(&format!("{}< outline text=\"{}\"", indent, self.escape_xml(&item.text)));

            if let Some(ref note) = item.note {
                xml.push_str(&format!(" _note=\"{}\"", self.escape_xml(note)));
            }

            xml.push_str(" />\n");
        } else {
            // Opening tag
            xml.push_str(&format!("{}< outline text=\"{}\"", indent, self.escape_xml(&item.text)));

            if let Some(ref note) = item.note {
                xml.push_str(&format!(" _note=\"{}\"", self.escape_xml(note)));
            }

            xml.push_str(">\n");

            // Children
            for child in &item.children {
                xml.push_str(&self.outline_item_to_xml(child, indent_level + 1));
            }

            // Closing tag
            xml.push_str(&format!("{}</outline>\n", indent));
        }

        xml
    }

    /// Escape XML special characters
    fn escape_xml(&self, text: &str) -> String {
        text.replace('&', "&amp;")
            .replace('<', "&lt;")
            .replace('>', "&gt;")
            .replace('"', "&quot;")
            .replace('\'', "&apos;")
    }

    /// Unescape XML special characters
    fn unescape_xml(&self, text: &str) -> String {
        text.replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&apos;", "'")
    }
}

impl FormatHandler for OpmlHandler {
    fn import(&self, content: &str, options: &ImportExportOptions) -> MindmapResult<ImportResult> {
        let opml_doc = self.parse_opml_content(content)?;

        // Create root node
        let root_node_id = NodeId::new();
        let mut root_node = Node::new(&opml_doc.title);
        root_node.id = root_node_id;
        root_node.position = Point::new(0.0, 0.0);

        // Convert outline items to nodes
        let mut nodes = vec![root_node];
        let mut outline_nodes = self.outline_items_to_nodes(&opml_doc.outline_items, Some(root_node_id), options);
        nodes.append(&mut outline_nodes);

        // Create document
        let mut document = Document::new(&opml_doc.title, root_node_id);

        // Set metadata if available
        if let Some(ref date_created) = opml_doc.date_created {
            document.set_custom_metadata("opml_date_created", date_created);
        }

        if let Some(ref date_modified) = opml_doc.date_modified {
            document.set_custom_metadata("opml_date_modified", date_modified);
        }

        Ok(ImportResult {
            document,
            node_count: nodes.len(),
            edge_count: nodes.len().saturating_sub(1), // Parent-child edges
            warnings: Vec::new(),
        })
    }

    fn export(&self, document: &Document, nodes: &[Node], options: &ImportExportOptions) -> MindmapResult<ExportResult> {
        let outline_items = self.nodes_to_outline_items(nodes, document.get_root_node(), options);

        let opml_doc = OpmlDocument {
            title: document.title.clone(),
            date_created: document.get_custom_metadata("opml_date_created").cloned(),
            date_modified: if options.include_timestamps {
                Some(document.updated_at.format("%a, %d %b %Y %H:%M:%S GMT").to_string())
            } else {
                None
            },
            outline_items,
        };

        let content = self.generate_opml_xml(&opml_doc);

        Ok(ExportResult {
            content,
            node_count: nodes.len(),
            edge_count: nodes.len().saturating_sub(1),
            format: FileFormat::Opml,
        })
    }

    fn format(&self) -> FileFormat {
        FileFormat::Opml
    }

    fn validate(&self, content: &str) -> MindmapResult<bool> {
        let trimmed = content.trim();

        // Check for OPML structure (XML declaration is optional)
        let has_opml_tag = trimmed.contains("<opml");
        let has_head_tag = trimmed.contains("<head");
        let has_body_tag = trimmed.contains("<body");

        // Must have opml tag and either head or body
        Ok(has_opml_tag && (has_head_tag || has_body_tag))
    }
}

impl Default for OpmlHandler {
    fn default() -> Self {
        Self::new()
    }
}

/// Represents an OPML document structure
#[derive(Debug, Clone)]
struct OpmlDocument {
    title: String,
    date_created: Option<String>,
    date_modified: Option<String>,
    outline_items: Vec<OutlineItem>,
}

/// Represents an outline item in OPML
#[derive(Debug, Clone)]
struct OutlineItem {
    text: String,
    note: Option<String>,
    depth: usize,
    children: Vec<OutlineItem>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_opml() -> String {
        r#"<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>Test Mindmap</title>
    <dateCreated>Mon, 01 Jan 2024 00:00:00 GMT</dateCreated>
  </head>
  <body>
    <outline text="Main Topic">
      <outline text="Subtopic 1" _note="This is a note" />
      <outline text="Subtopic 2">
        <outline text="Sub-subtopic 1" />
      </outline>
    </outline>
    <outline text="Another Topic" />
  </body>
</opml>"#.to_string()
    }

    #[test]
    fn test_opml_validation() {
        let handler = OpmlHandler::new();

        let valid_opml = create_test_opml();
        assert!(handler.validate(&valid_opml).unwrap());

        let invalid_content = "This is not OPML";
        assert!(!handler.validate(invalid_content).unwrap());

        let partial_opml = r#"<opml><head><title>Test</title></head></opml>"#;
        assert!(handler.validate(partial_opml).unwrap());
    }

    #[test]
    fn test_opml_import() {
        let handler = OpmlHandler::new();
        let options = ImportExportOptions::default();

        let opml_content = create_test_opml();
        let result = handler.import(&opml_content, &options).unwrap();

        assert_eq!(result.document.title, "Test Mindmap");
        assert!(result.node_count > 0);
        assert!(result.warnings.is_empty());
    }

    #[test]
    fn test_xml_escape_unescape() {
        let handler = OpmlHandler::new();

        let original = "Hello & <world> \"test\"";
        let escaped = handler.escape_xml(original);
        let unescaped = handler.unescape_xml(&escaped);

        assert_eq!(escaped, "Hello &amp; &lt;world&gt; &quot;test&quot;");
        assert_eq!(unescaped, original);
    }

    #[test]
    fn test_extract_xml_content() {
        let handler = OpmlHandler::new();

        let xml = "<title>Test Title</title>";
        let content = handler.extract_xml_content(xml, "title");
        assert_eq!(content, Some("Test Title".to_string()));

        let no_content = handler.extract_xml_content(xml, "missing");
        assert_eq!(no_content, None);
    }

    #[test]
    fn test_outline_attribute_extraction() {
        let handler = OpmlHandler::new();

        let tag = r#"<outline text="Sample Text" _note="Sample Note" />"#;
        let text = handler.extract_outline_attribute(tag, "text");
        let note = handler.extract_outline_attribute(tag, "_note");

        assert_eq!(text, Some("Sample Text".to_string()));
        assert_eq!(note, Some("Sample Note".to_string()));
    }
}