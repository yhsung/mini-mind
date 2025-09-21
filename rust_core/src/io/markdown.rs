//! Markdown outline import/export handler
//!
//! This module provides functionality to import and export mindmap documents
//! to/from Markdown outline format, preserving the hierarchical structure using
//! headers and list items.

use super::{FormatHandler, FileFormat, ImportExportOptions, ImportResult, ExportResult};
use crate::models::document::Document;
use crate::models::node::Node;
use crate::types::{ids::NodeId, MindmapResult, Point};
use std::collections::HashMap;

/// Markdown format handler
pub struct MarkdownHandler;

impl MarkdownHandler {
    /// Create a new Markdown handler
    pub fn new() -> Self {
        Self
    }

    /// Parse Markdown content and extract outline structure
    fn parse_markdown_content(&self, content: &str) -> MindmapResult<MarkdownDocument> {
        let lines: Vec<&str> = content.lines().collect();
        let mut items: Vec<MarkdownItem> = Vec::new();
        let mut title = "Markdown Document".to_string();

        // Extract title from first header if present
        for line in &lines {
            let trimmed = line.trim();
            if trimmed.starts_with('#') {
                title = trimmed.trim_start_matches('#').trim().to_string();
                if title.is_empty() {
                    title = "Untitled".to_string();
                }
                break;
            } else if !trimmed.is_empty() {
                // If we hit non-empty content that's not a header, stop looking for title
                break;
            }
        }

        // Parse outline items
        let mut outline_items = self.parse_outline_items(&lines)?;

        // If no items found, try to parse as simple list
        if outline_items.is_empty() {
            outline_items = self.parse_simple_list(&lines)?;
        }

        Ok(MarkdownDocument {
            title,
            outline_items,
        })
    }

    /// Parse outline items from markdown lines
    fn parse_outline_items(&self, lines: &[&str]) -> MindmapResult<Vec<MarkdownItem>> {
        let mut items = Vec::new();
        let mut i = 0;

        while i < lines.len() {
            let line = lines[i].trim();

            if line.is_empty() {
                i += 1;
                continue;
            }

            // Parse headers
            if line.starts_with('#') {
                let level = line.chars().take_while(|&c| c == '#').count();
                let text = line.trim_start_matches('#').trim().to_string();

                if !text.is_empty() {
                    items.push(MarkdownItem {
                        text,
                        level,
                        item_type: MarkdownItemType::Header,
                        children: Vec::new(),
                    });
                }
            }
            // Parse list items
            else if line.starts_with('-') || line.starts_with('*') || line.starts_with('+') {
                let (level, text) = self.parse_list_item(line);
                if !text.is_empty() {
                    items.push(MarkdownItem {
                        text,
                        level,
                        item_type: MarkdownItemType::ListItem,
                        children: Vec::new(),
                    });
                }
            }
            // Parse numbered lists
            else if self.is_numbered_list_item(line) {
                let (level, text) = self.parse_numbered_list_item(line);
                if !text.is_empty() {
                    items.push(MarkdownItem {
                        text,
                        level,
                        item_type: MarkdownItemType::NumberedItem,
                        children: Vec::new(),
                    });
                }
            }

            i += 1;
        }

        // Build hierarchical structure
        self.build_hierarchy(items)
    }

    /// Parse simple list items when no headers are found
    fn parse_simple_list(&self, lines: &[&str]) -> MindmapResult<Vec<MarkdownItem>> {
        let mut items = Vec::new();

        for line in lines {
            let trimmed = line.trim();

            if trimmed.is_empty() {
                continue;
            }

            // Treat any non-empty line as a potential item
            if trimmed.starts_with('-') || trimmed.starts_with('*') || trimmed.starts_with('+') {
                let (level, text) = self.parse_list_item(trimmed);
                if !text.is_empty() {
                    items.push(MarkdownItem {
                        text,
                        level,
                        item_type: MarkdownItemType::ListItem,
                        children: Vec::new(),
                    });
                }
            } else if self.is_numbered_list_item(trimmed) {
                let (level, text) = self.parse_numbered_list_item(trimmed);
                if !text.is_empty() {
                    items.push(MarkdownItem {
                        text,
                        level,
                        item_type: MarkdownItemType::NumberedItem,
                        children: Vec::new(),
                    });
                }
            } else {
                // Treat as regular text item
                items.push(MarkdownItem {
                    text: trimmed.to_string(),
                    level: 1,
                    item_type: MarkdownItemType::Text,
                    children: Vec::new(),
                });
            }
        }

        self.build_hierarchy(items)
    }

    /// Parse list item and determine indentation level
    fn parse_list_item(&self, line: &str) -> (usize, String) {
        let indent_count = line.len() - line.trim_start().len();
        let level = (indent_count / 2).max(1); // Assume 2 spaces per level

        let text = line.trim()
            .trim_start_matches('-')
            .trim_start_matches('*')
            .trim_start_matches('+')
            .trim()
            .to_string();

        (level, text)
    }

    /// Check if line is a numbered list item
    fn is_numbered_list_item(&self, line: &str) -> bool {
        let trimmed = line.trim();
        if let Some(dot_pos) = trimmed.find('.') {
            if dot_pos > 0 && dot_pos < trimmed.len() - 1 {
                let number_part = &trimmed[..dot_pos];
                return number_part.chars().all(|c| c.is_ascii_digit());
            }
        }
        false
    }

    /// Parse numbered list item
    fn parse_numbered_list_item(&self, line: &str) -> (usize, String) {
        let indent_count = line.len() - line.trim_start().len();
        let level = (indent_count / 2).max(1);

        let trimmed = line.trim();
        if let Some(dot_pos) = trimmed.find('.') {
            let text = trimmed[dot_pos + 1..].trim().to_string();
            (level, text)
        } else {
            (level, trimmed.to_string())
        }
    }

    /// Build hierarchical structure from flat list
    fn build_hierarchy(&self, items: Vec<MarkdownItem>) -> MindmapResult<Vec<MarkdownItem>> {
        if items.is_empty() {
            return Ok(items);
        }

        let mut result = Vec::new();
        let mut stack: Vec<(usize, usize)> = Vec::new(); // (level, index in result)

        for item in items {
            // Find the appropriate parent level
            while let Some(&(parent_level, _)) = stack.last() {
                if parent_level < item.level {
                    break;
                }
                stack.pop();
            }

            if let Some(&(_, parent_index)) = stack.last() {
                // Add as child to parent
                self.add_child_to_item(&mut result, parent_index, item.clone());
            } else {
                // Add as root item
                let index = result.len();
                result.push(item);
                stack.push((result[index].level, index));
            }
        }

        Ok(result)
    }

    /// Add child item to parent (recursive helper)
    fn add_child_to_item(&self, items: &mut Vec<MarkdownItem>, parent_index: usize, child: MarkdownItem) {
        if parent_index < items.len() {
            items[parent_index].children.push(child);
        }
    }

    /// Convert markdown items to mindmap nodes
    fn markdown_items_to_nodes(&self, items: &[MarkdownItem], parent_id: Option<NodeId>, x_offset: f64, y_offset: &mut f64) -> Vec<Node> {
        let mut nodes = Vec::new();

        for item in items {
            let node_id = NodeId::new();
            let mut node = Node::new(&item.text);
            node.id = node_id;
            node.parent_id = parent_id;
            node.position = Point::new(x_offset, *y_offset);

            // Add item type as metadata
            match item.item_type {
                MarkdownItemType::Header => {
                    node.set_metadata("type", "header");
                    node.set_metadata("level", &item.level.to_string());
                }
                MarkdownItemType::ListItem => {
                    node.set_metadata("type", "list_item");
                }
                MarkdownItemType::NumberedItem => {
                    node.set_metadata("type", "numbered_item");
                }
                MarkdownItemType::Text => {
                    node.set_metadata("type", "text");
                }
            }

            *y_offset += 80.0; // Space nodes vertically
            nodes.push(node);

            // Process children
            if !item.children.is_empty() {
                let mut child_nodes = self.markdown_items_to_nodes(
                    &item.children,
                    Some(node_id),
                    x_offset + 200.0, // Indent children
                    y_offset
                );
                nodes.append(&mut child_nodes);
            }
        }

        nodes
    }

    /// Convert nodes to markdown items
    fn nodes_to_markdown_items(&self, nodes: &[Node], root_node_id: NodeId, options: &ImportExportOptions) -> Vec<MarkdownItem> {
        let mut items = Vec::new();

        // Build parent-child relationships
        let mut children_map: HashMap<NodeId, Vec<&Node>> = HashMap::new();
        for node in nodes {
            if let Some(parent_id) = node.parent_id {
                children_map.entry(parent_id).or_default().push(node);
            }
        }

        // Start from root and build items recursively
        if let Some(_root_node) = nodes.iter().find(|n| n.id == root_node_id) {
            if let Some(child_nodes) = children_map.get(&root_node_id) {
                for child_node in child_nodes {
                    let item = self.node_to_markdown_item(child_node, &children_map, options, 1);
                    items.push(item);
                }
            }
        }

        items
    }

    /// Convert a single node to markdown item
    fn node_to_markdown_item(&self, node: &Node, children_map: &HashMap<NodeId, Vec<&Node>>, options: &ImportExportOptions, level: usize) -> MarkdownItem {
        let text = if options.include_empty_nodes || !node.text.trim().is_empty() {
            node.text.clone()
        } else {
            "Empty Node".to_string()
        };

        // Determine item type from metadata
        let item_type = if let Some(type_str) = node.get_metadata("type") {
            match type_str.as_str() {
                "header" => MarkdownItemType::Header,
                "numbered_item" => MarkdownItemType::NumberedItem,
                "text" => MarkdownItemType::Text,
                _ => MarkdownItemType::ListItem,
            }
        } else {
            MarkdownItemType::ListItem
        };

        let mut children = Vec::new();
        if let Some(child_nodes) = children_map.get(&node.id) {
            for child_node in child_nodes {
                if options.max_depth < 0 || level < options.max_depth as usize {
                    children.push(self.node_to_markdown_item(child_node, children_map, options, level + 1));
                }
            }
        }

        MarkdownItem {
            text,
            level,
            item_type,
            children,
        }
    }

    /// Generate markdown text from items
    fn generate_markdown(&self, doc: &MarkdownDocument) -> String {
        let mut markdown = String::new();

        // Add title as main header
        markdown.push_str(&format!("# {}\n\n", doc.title));

        // Add outline items
        for item in &doc.outline_items {
            markdown.push_str(&self.markdown_item_to_text(item, 0));
        }

        markdown
    }

    /// Convert markdown item to text representation
    fn markdown_item_to_text(&self, item: &MarkdownItem, base_level: usize) -> String {
        let mut text = String::new();
        let indent = "  ".repeat(base_level);

        match item.item_type {
            MarkdownItemType::Header => {
                let level = (item.level + base_level).min(6); // Markdown supports up to 6 header levels
                text.push_str(&format!("{} {}\n", "#".repeat(level), item.text));
            }
            MarkdownItemType::ListItem => {
                text.push_str(&format!("{}* {}\n", indent, item.text));
            }
            MarkdownItemType::NumberedItem => {
                text.push_str(&format!("{}1. {}\n", indent, item.text));
            }
            MarkdownItemType::Text => {
                if base_level == 0 {
                    text.push_str(&format!("{}\n", item.text));
                } else {
                    text.push_str(&format!("{}* {}\n", indent, item.text));
                }
            }
        }

        // Add children
        for child in &item.children {
            text.push_str(&self.markdown_item_to_text(child, base_level + 1));
        }

        text
    }

    /// Escape markdown special characters
    fn escape_markdown(&self, text: &str) -> String {
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

impl FormatHandler for MarkdownHandler {
    fn import(&self, content: &str, _options: &ImportExportOptions) -> MindmapResult<ImportResult> {
        let markdown_doc = self.parse_markdown_content(content)?;

        // Create root node
        let root_node_id = NodeId::new();
        let mut root_node = Node::new(&markdown_doc.title);
        root_node.id = root_node_id;
        root_node.position = Point::new(0.0, 0.0);

        // Convert markdown items to nodes
        let mut y_offset = 100.0;
        let mut nodes = vec![root_node];
        let mut markdown_nodes = self.markdown_items_to_nodes(&markdown_doc.outline_items, Some(root_node_id), 200.0, &mut y_offset);
        nodes.append(&mut markdown_nodes);

        // Create document
        let document = Document::new(&markdown_doc.title, root_node_id);

        Ok(ImportResult {
            document,
            node_count: nodes.len(),
            edge_count: nodes.len().saturating_sub(1),
            warnings: Vec::new(),
        })
    }

    fn export(&self, document: &Document, nodes: &[Node], options: &ImportExportOptions) -> MindmapResult<ExportResult> {
        let markdown_items = self.nodes_to_markdown_items(nodes, document.get_root_node(), options);

        let markdown_doc = MarkdownDocument {
            title: document.title.clone(),
            outline_items: markdown_items,
        };

        let content = self.generate_markdown(&markdown_doc);

        Ok(ExportResult {
            content,
            node_count: nodes.len(),
            edge_count: nodes.len().saturating_sub(1),
            format: FileFormat::Markdown,
        })
    }

    fn format(&self) -> FileFormat {
        FileFormat::Markdown
    }

    fn validate(&self, content: &str) -> MindmapResult<bool> {
        let lines: Vec<&str> = content.lines().collect();

        // Check for markdown patterns
        let has_headers = lines.iter().any(|line| line.trim().starts_with('#'));
        let has_lists = lines.iter().any(|line| {
            let trimmed = line.trim();
            trimmed.starts_with('-') || trimmed.starts_with('*') || trimmed.starts_with('+') || self.is_numbered_list_item(trimmed)
        });

        // Consider it markdown if it has headers or lists
        // Don't default to markdown for any non-empty content
        Ok(has_headers || has_lists)
    }
}

impl Default for MarkdownHandler {
    fn default() -> Self {
        Self::new()
    }
}

/// Represents a Markdown document structure
#[derive(Debug, Clone)]
struct MarkdownDocument {
    title: String,
    outline_items: Vec<MarkdownItem>,
}

/// Represents an item in markdown outline
#[derive(Debug, Clone)]
struct MarkdownItem {
    text: String,
    level: usize,
    item_type: MarkdownItemType,
    children: Vec<MarkdownItem>,
}

/// Types of markdown items
#[derive(Debug, Clone, PartialEq)]
enum MarkdownItemType {
    Header,      // # Header
    ListItem,    // - Item
    NumberedItem, // 1. Item
    Text,        // Plain text
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_markdown() -> String {
        r#"# Test Mindmap

## Main Topic
- Subtopic 1
- Subtopic 2
  - Sub-subtopic 1
  - Sub-subtopic 2

## Another Topic
1. First item
2. Second item

Some plain text content"#.to_string()
    }

    #[test]
    fn test_markdown_validation() {
        let handler = MarkdownHandler::new();

        let valid_markdown = create_test_markdown();
        assert!(handler.validate(&valid_markdown).unwrap());

        let list_markdown = "- Item 1\n- Item 2";
        assert!(handler.validate(list_markdown).unwrap());

        let plain_text = "Just some text";
        assert!(!handler.validate(plain_text).unwrap()); // Plain text without markdown structure should not validate

        let empty_content = "";
        assert!(!handler.validate(empty_content).unwrap());
    }

    #[test]
    fn test_markdown_import() {
        let handler = MarkdownHandler::new();
        let options = ImportExportOptions::default();

        let markdown_content = create_test_markdown();
        let result = handler.import(&markdown_content, &options).unwrap();

        assert_eq!(result.document.title, "Test Mindmap");
        assert!(result.node_count > 0);
        assert!(result.warnings.is_empty());
    }

    #[test]
    fn test_list_item_parsing() {
        let handler = MarkdownHandler::new();

        let (level, text) = handler.parse_list_item("- Simple item");
        assert_eq!(level, 1);
        assert_eq!(text, "Simple item");

        let (level, text) = handler.parse_list_item("  - Indented item");
        assert_eq!(level, 1);
        assert_eq!(text, "Indented item");

        let (level, text) = handler.parse_list_item("    - Double indented");
        assert_eq!(level, 2);
        assert_eq!(text, "Double indented");
    }

    #[test]
    fn test_numbered_list_detection() {
        let handler = MarkdownHandler::new();

        assert!(handler.is_numbered_list_item("1. First item"));
        assert!(handler.is_numbered_list_item("123. Item"));
        assert!(!handler.is_numbered_list_item("- Not numbered"));
        assert!(!handler.is_numbered_list_item("1 No dot"));
    }

    #[test]
    fn test_numbered_list_parsing() {
        let handler = MarkdownHandler::new();

        let (level, text) = handler.parse_numbered_list_item("1. First item");
        assert_eq!(level, 1);
        assert_eq!(text, "First item");

        let (level, text) = handler.parse_numbered_list_item("  42. Indented numbered item");
        assert_eq!(level, 1);
        assert_eq!(text, "Indented numbered item");
    }

    #[test]
    fn test_markdown_escaping() {
        let handler = MarkdownHandler::new();

        let original = "Text with *bold* and [link](url)";
        let escaped = handler.escape_markdown(original);
        assert_eq!(escaped, "Text with \\*bold\\* and \\[link\\]\\(url\\)");
    }

    #[test]
    fn test_simple_markdown_parsing() {
        let handler = MarkdownHandler::new();

        let simple_content = "- Item 1\n- Item 2\n  - Sub item";
        let doc = handler.parse_markdown_content(simple_content).unwrap();

        assert_eq!(doc.title, "Markdown Document");
        assert!(!doc.outline_items.is_empty());
    }
}