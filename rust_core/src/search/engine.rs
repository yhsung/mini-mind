//! Search engine implementation
//!
//! This module provides text search functionality for mindmap nodes
//! with fuzzy matching and ranking capabilities.

use crate::models::Node;
use crate::types::{NodeId, MindmapResult, MindmapError};
use std::collections::HashMap;
use serde::{Deserialize, Serialize};

/// Search result with ranking information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SearchResult {
    /// ID of the matching node
    pub node_id: NodeId,
    /// Full text content of the node
    pub text: String,
    /// Relevance score (0.0 to 1.0)
    pub score: f64,
    /// Positions of matches in the text (start, end)
    pub match_positions: Vec<(usize, usize)>,
}

/// Search engine for mindmap nodes
#[derive(Debug, Clone)]
pub struct SearchEngine {
    /// Index of node text content
    text_index: HashMap<NodeId, String>,
    /// Index of node tags
    tag_index: HashMap<NodeId, Vec<String>>,
    /// Cached search results
    result_cache: HashMap<String, Vec<SearchResult>>,
}

impl SearchEngine {
    /// Create a new search engine
    pub fn new() -> Self {
        Self {
            text_index: HashMap::new(),
            tag_index: HashMap::new(),
            result_cache: HashMap::new(),
        }
    }

    /// Index a node for searching
    pub fn index_node(&mut self, node: &Node) {
        self.text_index.insert(node.id, node.text.clone());
        self.tag_index.insert(node.id, node.tags.clone());

        // Clear cache when index changes
        self.result_cache.clear();
    }

    /// Remove a node from the search index
    pub fn remove_node(&mut self, node_id: NodeId) {
        self.text_index.remove(&node_id);
        self.tag_index.remove(&node_id);

        // Clear cache when index changes
        self.result_cache.clear();
    }

    /// Search nodes by text content with fuzzy matching
    pub fn search(&self, query: &str) -> MindmapResult<Vec<SearchResult>> {
        if query.trim().is_empty() {
            return Ok(Vec::new());
        }

        // Check cache first
        if let Some(cached_results) = self.result_cache.get(query) {
            return Ok(cached_results.clone());
        }

        let query_lower = query.to_lowercase();
        let mut results = Vec::new();

        for (node_id, text) in &self.text_index {
            if let Some(result) = self.match_text(*node_id, text, &query_lower) {
                results.push(result);
            }
        }

        // Sort by score (highest first)
        results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));

        // Note: Caching is skipped in this implementation to avoid unsafe code
        // In a production version, this would use interior mutability (RefCell/RwLock)

        Ok(results)
    }

    /// Search nodes by tags
    pub fn search_by_tags(&self, tags: &[String]) -> MindmapResult<Vec<SearchResult>> {
        if tags.is_empty() {
            return Ok(Vec::new());
        }

        let mut results = Vec::new();

        for (node_id, node_tags) in &self.tag_index {
            let mut matching_tags = 0;

            for search_tag in tags {
                if node_tags.iter().any(|tag| tag.to_lowercase().contains(&search_tag.to_lowercase())) {
                    matching_tags += 1;
                }
            }

            if matching_tags > 0 {
                // Calculate score based on tag matches
                let score = matching_tags as f64 / tags.len() as f64;

                if let Some(text) = self.text_index.get(node_id) {
                    results.push(SearchResult {
                        node_id: *node_id,
                        text: text.clone(),
                        score,
                        match_positions: Vec::new(), // No text positions for tag searches
                    });
                }
            }
        }

        // Sort by score (highest first)
        results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));

        Ok(results)
    }

    /// Match text against query and return result if relevant
    fn match_text(&self, node_id: NodeId, text: &str, query: &str) -> Option<SearchResult> {
        let text_lower = text.to_lowercase();

        // Exact match gets highest score
        if text_lower.contains(query) {
            let score = if text_lower == query {
                1.0
            } else if text_lower.starts_with(query) {
                0.9
            } else {
                0.8 - (query.len() as f64 / text.len() as f64) * 0.3
            };

            let match_positions = self.find_match_positions(&text_lower, query);

            return Some(SearchResult {
                node_id,
                text: text.to_string(),
                score: score.max(0.1),
                match_positions,
            });
        }

        // Fuzzy matching for partial matches
        if self.fuzzy_match(&text_lower, query) {
            let score = self.calculate_fuzzy_score(&text_lower, query);

            if score > 0.3 {
                return Some(SearchResult {
                    node_id,
                    text: text.to_string(),
                    score,
                    match_positions: Vec::new(), // Fuzzy matches don't have exact positions
                });
            }
        }

        None
    }

    /// Find exact match positions in text
    fn find_match_positions(&self, text: &str, query: &str) -> Vec<(usize, usize)> {
        let mut positions = Vec::new();
        let mut start = 0;

        while let Some(pos) = text[start..].find(query) {
            let absolute_pos = start + pos;
            positions.push((absolute_pos, absolute_pos + query.len()));
            start = absolute_pos + 1;
        }

        positions
    }

    /// Simple fuzzy matching algorithm
    fn fuzzy_match(&self, text: &str, query: &str) -> bool {
        let mut text_chars: Vec<char> = text.chars().collect();
        let query_chars: Vec<char> = query.chars().collect();

        let mut text_idx = 0;
        let mut query_idx = 0;

        while text_idx < text_chars.len() && query_idx < query_chars.len() {
            if text_chars[text_idx] == query_chars[query_idx] {
                query_idx += 1;
            }
            text_idx += 1;
        }

        query_idx == query_chars.len()
    }

    /// Calculate fuzzy match score
    fn calculate_fuzzy_score(&self, text: &str, query: &str) -> f64 {
        let text_len = text.len() as f64;
        let query_len = query.len() as f64;

        // Simple scoring based on length ratio and character overlap
        let length_ratio = (query_len / text_len).min(1.0);
        let char_overlap = self.character_overlap(text, query);

        (length_ratio * 0.3 + char_overlap * 0.7).max(0.0).min(1.0)
    }

    /// Calculate character overlap between text and query
    fn character_overlap(&self, text: &str, query: &str) -> f64 {
        let text_chars: std::collections::HashSet<char> = text.chars().collect();
        let query_chars: std::collections::HashSet<char> = query.chars().collect();

        let intersection = text_chars.intersection(&query_chars).count();
        let union = text_chars.union(&query_chars).count();

        if union == 0 {
            0.0
        } else {
            intersection as f64 / union as f64
        }
    }

    /// Clear the search index
    pub fn clear(&mut self) {
        self.text_index.clear();
        self.tag_index.clear();
        self.result_cache.clear();
    }

    /// Get statistics about the search index
    pub fn get_stats(&self) -> SearchStats {
        SearchStats {
            indexed_nodes: self.text_index.len(),
            indexed_tags: self.tag_index.values().map(|tags| tags.len()).sum(),
            cached_queries: self.result_cache.len(),
        }
    }
}

impl Default for SearchEngine {
    fn default() -> Self {
        Self::new()
    }
}

/// Search engine statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchStats {
    /// Number of indexed nodes
    pub indexed_nodes: usize,
    /// Total number of indexed tags
    pub indexed_tags: usize,
    /// Number of cached search queries
    pub cached_queries: usize,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Node;

    fn create_test_node(text: &str, tags: Vec<&str>) -> Node {
        let mut node = Node::new(text);
        for tag in tags {
            node.add_tag(tag);
        }
        node
    }

    #[test]
    fn test_search_engine_creation() {
        let engine = SearchEngine::new();
        assert_eq!(engine.text_index.len(), 0);
        assert_eq!(engine.tag_index.len(), 0);
    }

    #[test]
    fn test_node_indexing() {
        let mut engine = SearchEngine::new();
        let node = create_test_node("Test node", vec!["important", "work"]);

        engine.index_node(&node);

        assert_eq!(engine.text_index.len(), 1);
        assert_eq!(engine.tag_index.len(), 1);
        assert_eq!(engine.text_index.get(&node.id), Some(&"Test node".to_string()));
    }

    #[test]
    fn test_exact_text_search() {
        let mut engine = SearchEngine::new();
        let node = create_test_node("Hello world", vec![]);

        engine.index_node(&node);

        let results = engine.search("hello").unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].node_id, node.id);
        assert!(results[0].score > 0.5);
    }

    #[test]
    fn test_fuzzy_search() {
        let mut engine = SearchEngine::new();
        let node = create_test_node("Important information", vec![]);

        engine.index_node(&node);

        let results = engine.search("imprtnt").unwrap();
        assert_eq!(results.len(), 1);
        assert!(results[0].score > 0.3);
    }

    #[test]
    fn test_tag_search() {
        let mut engine = SearchEngine::new();
        let node1 = create_test_node("Node 1", vec!["important", "work"]);
        let node2 = create_test_node("Node 2", vec!["personal", "hobby"]);

        engine.index_node(&node1);
        engine.index_node(&node2);

        let results = engine.search_by_tags(&["important".to_string()]).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].node_id, node1.id);
    }

    #[test]
    fn test_node_removal() {
        let mut engine = SearchEngine::new();
        let node = create_test_node("Test node", vec!["tag"]);

        engine.index_node(&node);
        assert_eq!(engine.text_index.len(), 1);

        engine.remove_node(node.id);
        assert_eq!(engine.text_index.len(), 0);
        assert_eq!(engine.tag_index.len(), 0);
    }

    #[test]
    fn test_empty_query() {
        let engine = SearchEngine::new();
        let results = engine.search("").unwrap();
        assert!(results.is_empty());

        let results = engine.search("   ").unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_search_ranking() {
        let mut engine = SearchEngine::new();
        let node1 = create_test_node("test", vec![]);
        let node2 = create_test_node("testing something", vec![]);
        let node3 = create_test_node("this has test in middle", vec![]);

        engine.index_node(&node1);
        engine.index_node(&node2);
        engine.index_node(&node3);

        let results = engine.search("test").unwrap();
        assert_eq!(results.len(), 3);

        // Exact match should have highest score
        assert_eq!(results[0].node_id, node1.id);
        assert!(results[0].score > results[1].score);
        assert!(results[1].score > results[2].score);
    }

    #[test]
    fn test_match_positions() {
        let mut engine = SearchEngine::new();
        let node = create_test_node("hello world hello", vec![]);

        engine.index_node(&node);

        let results = engine.search("hello").unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].match_positions.len(), 2);
        assert_eq!(results[0].match_positions[0], (0, 5));
        assert_eq!(results[0].match_positions[1], (12, 17));
    }
}