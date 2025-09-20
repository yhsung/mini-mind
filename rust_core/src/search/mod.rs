//! Search functionality for node content
//!
//! This module provides fuzzy text search capabilities for finding nodes
//! in a mindmap based on their text content, with ranking and scoring.

pub mod fuzzy;
pub mod index;

pub use fuzzy::*;
pub use index::*;

use crate::graph::Graph;
use crate::models::Node;
use crate::types::ids::NodeId;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A search result containing a node reference and match score
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SearchResult {
    /// The ID of the matching node
    pub node_id: NodeId,
    /// Match score (0.0 = no match, 1.0 = perfect match)
    pub score: f64,
    /// The matched text snippet
    pub snippet: String,
    /// Positions of matched terms in the text
    pub match_positions: Vec<(usize, usize)>,
}

/// Search options for customizing search behavior
#[derive(Debug, Clone, PartialEq)]
pub struct SearchOptions {
    /// Maximum number of results to return
    pub limit: Option<usize>,
    /// Minimum score threshold (0.0 to 1.0)
    pub min_score: f64,
    /// Case sensitive search
    pub case_sensitive: bool,
    /// Search in node tags as well as text
    pub include_tags: bool,
    /// Search in metadata values
    pub include_metadata: bool,
    /// Boost score for exact matches
    pub exact_match_boost: f64,
}

/// Search context for filtering results
#[derive(Debug, Clone, PartialEq)]
pub enum SearchContext {
    /// Search all nodes
    All,
    /// Search only descendants of a specific node
    Subtree(NodeId),
    /// Search only nodes at a specific depth
    Depth(usize),
    /// Search only root nodes
    Roots,
}

impl Default for SearchOptions {
    fn default() -> Self {
        Self {
            limit: Some(50),
            min_score: 0.1,
            case_sensitive: false,
            include_tags: true,
            include_metadata: false,
            exact_match_boost: 0.5,
        }
    }
}

impl SearchResult {
    /// Create a new search result
    pub fn new(
        node_id: NodeId,
        score: f64,
        snippet: String,
        match_positions: Vec<(usize, usize)>,
    ) -> Self {
        Self {
            node_id,
            score,
            snippet,
            match_positions,
        }
    }

    /// Check if this result has a higher score than another
    pub fn is_better_than(&self, other: &SearchResult) -> bool {
        self.score > other.score
    }
}

/// Main search interface for graphs
impl Graph {
    /// Search for nodes containing the given query
    pub fn search(&self, query: &str, options: &SearchOptions) -> Vec<SearchResult> {
        self.search_with_context(query, options, &SearchContext::All)
    }

    /// Search for nodes with specific context filtering
    pub fn search_with_context(
        &self,
        query: &str,
        options: &SearchOptions,
        context: &SearchContext,
    ) -> Vec<SearchResult> {
        if query.trim().is_empty() {
            return Vec::new();
        }

        let mut results = Vec::new();
        let search_query = if options.case_sensitive {
            query.to_string()
        } else {
            query.to_lowercase()
        };

        // Get nodes to search based on context
        let nodes_to_search = self.get_search_candidates(context);

        for node in nodes_to_search {
            if let Some(result) = self.search_node(node, &search_query, options) {
                if result.score >= options.min_score {
                    results.push(result);
                }
            }
        }

        // Sort by score (highest first)
        results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));

        // Apply limit
        if let Some(limit) = options.limit {
            results.truncate(limit);
        }

        results
    }

    /// Search a single node for matches
    fn search_node(&self, node: &Node, query: &str, options: &SearchOptions) -> Option<SearchResult> {
        let mut best_score = 0.0;
        let mut best_snippet = String::new();
        let mut best_positions = Vec::new();

        // Search in node text
        let node_text = if options.case_sensitive {
            node.text.clone()
        } else {
            node.text.to_lowercase()
        };

        if let Some((score, snippet, positions)) = fuzzy_search(&node_text, query, options.exact_match_boost) {
            if score > best_score {
                best_score = score;
                best_snippet = snippet;
                best_positions = positions;
            }
        }

        // Search in tags if enabled
        if options.include_tags {
            for tag in &node.tags {
                let tag_text = if options.case_sensitive {
                    tag.clone()
                } else {
                    tag.to_lowercase()
                };

                if let Some((score, snippet, positions)) = fuzzy_search(&tag_text, query, options.exact_match_boost) {
                    // Apply a slight penalty for tag matches vs text matches
                    let adjusted_score = score * 0.8;
                    if adjusted_score > best_score {
                        best_score = adjusted_score;
                        best_snippet = format!("Tag: {}", snippet);
                        best_positions = positions;
                    }
                }
            }
        }

        // Search in metadata if enabled
        if options.include_metadata {
            for (key, value) in &node.metadata {
                let metadata_text = if options.case_sensitive {
                    format!("{}: {}", key, value)
                } else {
                    format!("{}: {}", key, value).to_lowercase()
                };

                if let Some((score, snippet, positions)) = fuzzy_search(&metadata_text, query, options.exact_match_boost) {
                    // Apply a penalty for metadata matches
                    let adjusted_score = score * 0.6;
                    if adjusted_score > best_score {
                        best_score = adjusted_score;
                        best_snippet = format!("Metadata: {}", snippet);
                        best_positions = positions;
                    }
                }
            }
        }

        if best_score > 0.0 {
            Some(SearchResult::new(
                node.id,
                best_score,
                best_snippet,
                best_positions,
            ))
        } else {
            None
        }
    }

    /// Get candidate nodes based on search context
    fn get_search_candidates(&self, context: &SearchContext) -> Vec<&Node> {
        match context {
            SearchContext::All => self.nodes().collect(),
            SearchContext::Subtree(root_id) => {
                let mut candidates = Vec::new();
                if let Some(root) = self.get_node(*root_id) {
                    candidates.push(root);
                    for descendant_id in self.get_descendants(*root_id) {
                        if let Some(node) = self.get_node(descendant_id) {
                            candidates.push(node);
                        }
                    }
                }
                candidates
            }
            SearchContext::Depth(depth) => {
                self.get_nodes_at_depth(*depth)
                    .into_iter()
                    .filter_map(|id| self.get_node(id))
                    .collect()
            }
            SearchContext::Roots => self.get_root_nodes(),
        }
    }

    /// Find similar nodes based on text content
    pub fn find_similar_nodes(&self, node_id: NodeId, options: &SearchOptions) -> Vec<SearchResult> {
        let node = match self.get_node(node_id) {
            Some(n) => n,
            None => return Vec::new(),
        };

        // Use the node's text as the search query
        let query = &node.text;
        let mut results = self.search(query, options);

        // Remove the original node from results
        results.retain(|result| result.node_id != node_id);

        results
    }

    /// Get search suggestions based on partial query
    pub fn get_search_suggestions(&self, partial_query: &str, max_suggestions: usize) -> Vec<String> {
        if partial_query.trim().is_empty() {
            return Vec::new();
        }

        let mut suggestions = HashMap::new();
        let query_lower = partial_query.to_lowercase();

        // Collect words from all nodes
        for node in self.nodes() {
            let words = node.text.split_whitespace();
            for word in words {
                let word_lower = word.to_lowercase();
                if word_lower.starts_with(&query_lower) && word_lower != query_lower {
                    *suggestions.entry(word.to_string()).or_insert(0) += 1;
                }
            }

            // Also check tags
            for tag in &node.tags {
                let tag_lower = tag.to_lowercase();
                if tag_lower.starts_with(&query_lower) && tag_lower != query_lower {
                    *suggestions.entry(tag.clone()).or_insert(0) += 1;
                }
            }
        }

        // Sort by frequency and take top suggestions
        let mut sorted_suggestions: Vec<_> = suggestions.into_iter().collect();
        sorted_suggestions.sort_by(|a, b| b.1.cmp(&a.1));

        sorted_suggestions
            .into_iter()
            .take(max_suggestions)
            .map(|(word, _)| word)
            .collect()
    }

    /// Search and highlight matches in the original text
    pub fn search_with_highlights(
        &self,
        query: &str,
        options: &SearchOptions,
    ) -> Vec<(SearchResult, String)> {
        let results = self.search(query, options);
        let mut highlighted_results = Vec::new();

        for result in results {
            if let Some(node) = self.get_node(result.node_id) {
                let highlighted_text = highlight_matches(&node.text, &result.match_positions);
                highlighted_results.push((result, highlighted_text));
            }
        }

        highlighted_results
    }
}

/// Highlight matched positions in text with markers
fn highlight_matches(text: &str, positions: &[(usize, usize)]) -> String {
    if positions.is_empty() {
        return text.to_string();
    }

    let mut result = String::new();
    let mut last_end = 0;

    for &(start, end) in positions {
        // Add text before the match
        if start > last_end {
            result.push_str(&text[last_end..start]);
        }

        // Add highlighted match
        result.push_str("**");
        if end <= text.len() {
            result.push_str(&text[start..end]);
        }
        result.push_str("**");

        last_end = end;
    }

    // Add remaining text
    if last_end < text.len() {
        result.push_str(&text[last_end..]);
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Node;

    fn create_test_graph() -> Graph {
        let mut graph = Graph::new();

        let mut root = Node::new("Machine Learning Fundamentals");
        root.tags.push("AI".to_string());
        root.tags.push("Education".to_string());
        let root_id = root.id;

        let mut child1 = Node::new_child(root_id, "Neural Networks and Deep Learning");
        child1.tags.push("AI".to_string());
        child1.tags.push("Deep Learning".to_string());

        let mut child2 = Node::new_child(root_id, "Supervised Learning Algorithms");
        child2.tags.push("AI".to_string());
        child2.tags.push("Algorithms".to_string());

        let mut grandchild = Node::new_child(child1.id, "Convolutional Neural Networks");
        grandchild.tags.push("CNN".to_string());
        grandchild.metadata.insert("complexity".to_string(), "advanced".to_string());

        graph.add_node(root).unwrap();
        graph.add_node(child1).unwrap();
        graph.add_node(child2).unwrap();
        graph.add_node(grandchild).unwrap();

        graph
    }

    #[test]
    fn test_basic_search() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        let results = graph.search("learning", &options);
        assert!(results.len() >= 2); // Should find "Machine Learning" and "Deep Learning"

        // Check that results are sorted by score
        for i in 1..results.len() {
            assert!(results[i - 1].score >= results[i].score);
        }
    }

    #[test]
    fn test_case_sensitivity() {
        let graph = create_test_graph();

        let case_insensitive = SearchOptions {
            case_sensitive: false,
            ..SearchOptions::default()
        };

        let case_sensitive = SearchOptions {
            case_sensitive: true,
            ..SearchOptions::default()
        };

        let results_insensitive = graph.search("LEARNING", &case_insensitive);
        let results_sensitive = graph.search("LEARNING", &case_sensitive);

        assert!(!results_insensitive.is_empty());
        assert!(results_sensitive.is_empty()); // No exact case match
    }

    #[test]
    fn test_tag_search() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        let results = graph.search("AI", &options);
        assert!(results.len() >= 3); // Should find nodes with "AI" tag

        // Test with tags disabled
        let no_tags_options = SearchOptions {
            include_tags: false,
            ..SearchOptions::default()
        };

        let results_no_tags = graph.search("AI", &no_tags_options);
        assert!(results_no_tags.len() <= results.len()); // Should be less or equal (in case AI appears in text too)
    }

    #[test]
    fn test_metadata_search() {
        let graph = create_test_graph();
        let options = SearchOptions {
            include_metadata: true,
            ..SearchOptions::default()
        };

        let results = graph.search("advanced", &options);
        assert!(!results.is_empty()); // Should find node with "advanced" in metadata
    }

    #[test]
    fn test_search_with_context() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        // Get root node ID for subtree search
        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;

        let all_results = graph.search_with_context("Convolutional", &options, &SearchContext::All);
        let subtree_results = graph.search_with_context("Convolutional", &options, &SearchContext::Subtree(root_id));
        let root_results = graph.search_with_context("Convolutional", &options, &SearchContext::Roots);

        assert!(!all_results.is_empty());
        assert_eq!(all_results.len(), subtree_results.len()); // All nodes are in the subtree
        assert!(root_results.is_empty()); // "Convolutional" not in root node
    }

    #[test]
    fn test_min_score_threshold() {
        let graph = create_test_graph();
        let high_threshold_options = SearchOptions {
            min_score: 0.8,
            ..SearchOptions::default()
        };

        let low_threshold_options = SearchOptions {
            min_score: 0.1,
            ..SearchOptions::default()
        };

        let high_results = graph.search("learning", &high_threshold_options);
        let low_results = graph.search("learning", &low_threshold_options);

        assert!(high_results.len() <= low_results.len());
    }

    #[test]
    fn test_result_limit() {
        let graph = create_test_graph();
        let limited_options = SearchOptions {
            limit: Some(2),
            ..SearchOptions::default()
        };

        let results = graph.search("a", &limited_options); // Should match many nodes
        assert!(results.len() <= 2);
    }

    #[test]
    fn test_find_similar_nodes() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        let root_nodes = graph.get_root_nodes();
        let root_id = root_nodes[0].id;

        let similar = graph.find_similar_nodes(root_id, &options);
        // Should find nodes with similar content, excluding the original node
        assert!(!similar.iter().any(|result| result.node_id == root_id));
    }

    #[test]
    fn test_search_suggestions() {
        let graph = create_test_graph();

        let suggestions = graph.get_search_suggestions("Lear", 5);
        assert!(suggestions.contains(&"Learning".to_string()));

        let suggestions = graph.get_search_suggestions("Ne", 5);
        assert!(suggestions.iter().any(|s| s.contains("Neural")));
    }

    #[test]
    fn test_search_with_highlights() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        let highlighted_results = graph.search_with_highlights("Learning", &options);
        assert!(!highlighted_results.is_empty());

        // Check that highlights are properly formatted
        for (_, highlighted_text) in &highlighted_results {
            assert!(highlighted_text.contains("**"));
        }
    }

    #[test]
    fn test_empty_query() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        let results = graph.search("", &options);
        assert!(results.is_empty());

        let results = graph.search("   ", &options);
        assert!(results.is_empty());
    }

    #[test]
    fn test_search_result_ordering() {
        let graph = create_test_graph();
        let options = SearchOptions::default();

        let results = graph.search("Neural Networks", &options);
        assert!(!results.is_empty());

        // Results should be ordered by score (highest first)
        for i in 1..results.len() {
            assert!(results[i - 1].score >= results[i].score);
        }
    }
}