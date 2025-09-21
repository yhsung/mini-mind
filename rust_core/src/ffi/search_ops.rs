//! Search operations for FFI interface
//!
//! This module provides specialized search operations and utilities for the FFI bridge,
//! offering enhanced functionality beyond the basic MindmapFFI trait implementation.

use super::{BridgeError, FfiSearchResult, MindmapBridge, utils};
use crate::{
    search::{SearchEngine, SearchResult, SearchOptions},
    types::NodeId,
};
use std::collections::HashMap;
use std::time::Instant;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Enhanced search operations for advanced FFI functionality
pub struct SearchOperations;

impl SearchOperations {
    /// Advanced search with configuration options
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn search_with_options(
        bridge: &MindmapBridge,
        query: String,
        options: SearchOptionsFFI,
    ) -> Result<SearchResultsFFI, BridgeError> {
        let start_time = Instant::now();

        // Validate search query
        if query.trim().is_empty() && options.tags.is_empty() {
            return Ok(SearchResultsFFI {
                results: Vec::new(),
                total_count: 0,
                query: query.clone(),
                search_time_ms: start_time.elapsed().as_millis() as u64,
                has_more: false,
                suggestions: Vec::new(),
            });
        }

        let search = bridge.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        // Convert FFI options to internal options
        let internal_options = SearchOptions {
            limit: options.limit.unwrap_or(50),
            min_score: options.min_score.unwrap_or(0.1),
            include_highlights: options.include_highlights,
            case_sensitive: options.case_sensitive,
            whole_words_only: options.whole_words_only,
        };

        // Perform search based on query type
        let mut results = if !query.trim().is_empty() && !options.tags.is_empty() {
            // Combined text and tag search
            Self::search_combined(&*search, &query, &options.tags, &internal_options)?
        } else if !query.trim().is_empty() {
            // Text search only
            search.search_with_options(&query, &internal_options)
                .map_err(|e| BridgeError::SearchError {
                    message: format!("Search failed: {}", e),
                })?
        } else {
            // Tag search only
            search.search_by_tags(&options.tags)
                .map_err(|e| BridgeError::SearchError {
                    message: format!("Tag search failed: {}", e),
                })?
        };

        // Apply sorting if requested
        if let Some(sort_by) = options.sort_by {
            Self::sort_results(&mut results, sort_by);
        }

        // Apply pagination
        let total_count = results.len();
        let offset = options.offset.unwrap_or(0);
        let limit = options.limit.unwrap_or(50);
        let has_more = total_count > offset + limit;

        if offset > 0 || limit < total_count {
            let end = std::cmp::min(offset + limit, total_count);
            if offset < total_count {
                results = results[offset..end].to_vec();
            } else {
                results.clear();
            }
        }

        // Convert to FFI format
        let ffi_results: Vec<FfiSearchResult> = results
            .into_iter()
            .map(|result| FfiSearchResult {
                node_id: result.node_id.to_string(),
                text: result.text,
                score: result.score,
                match_positions: result.match_positions,
            })
            .collect();

        // Generate suggestions if no results found
        let suggestions = if ffi_results.is_empty() && !query.trim().is_empty() {
            Self::generate_suggestions(&*search, &query, 5)?
        } else {
            Vec::new()
        };

        let search_results = SearchResultsFFI {
            results: ffi_results,
            total_count,
            query: query.clone(),
            search_time_ms: start_time.elapsed().as_millis() as u64,
            has_more,
            suggestions,
        };

        bridge.record_metrics("search_with_options", start_time, search_results.results.len() as u32);
        Ok(search_results)
    }

    /// Search with auto-complete suggestions
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn search_with_autocomplete(
        bridge: &MindmapBridge,
        partial_query: String,
        max_suggestions: u32,
    ) -> Result<AutocompleteResults, BridgeError> {
        let start_time = Instant::now();

        let search = bridge.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        let suggestions = if partial_query.trim().len() >= 2 {
            search.get_word_completions(&partial_query, max_suggestions as usize)
        } else {
            Vec::new()
        };

        let tag_suggestions = if partial_query.trim().len() >= 1 {
            search.get_tag_completions(&partial_query, max_suggestions as usize)
        } else {
            Vec::new()
        };

        let results = AutocompleteResults {
            word_suggestions: suggestions,
            tag_suggestions,
            query: partial_query,
            suggestion_count: suggestions.len() + tag_suggestions.len(),
        };

        bridge.record_metrics("search_with_autocomplete", start_time, results.suggestion_count as u32);
        Ok(results)
    }

    /// Find similar nodes based on content
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn find_similar_nodes(
        bridge: &MindmapBridge,
        node_id: String,
        max_results: u32,
        min_similarity: f64,
    ) -> Result<Vec<SimilarNodeResult>, BridgeError> {
        let start_time = Instant::now();

        let id = bridge.parse_node_id(&node_id)?;

        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let source_node = graph.get_node(id).map_err(|_| BridgeError::NodeNotFound {
            id: node_id.clone(),
        })?;

        let search = bridge.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        let similar_results = search.find_similar_nodes(id, max_results as usize, min_similarity)
            .map_err(|e| BridgeError::SearchError {
                message: format!("Similar node search failed: {}", e),
            })?;

        let results: Vec<SimilarNodeResult> = similar_results
            .into_iter()
            .map(|result| SimilarNodeResult {
                node_id: result.node_id.to_string(),
                text: result.text,
                similarity_score: result.score,
                common_words: result.match_positions.len(),
                relationship: Self::determine_relationship(&*graph, id, result.node_id),
            })
            .collect();

        bridge.record_metrics("find_similar_nodes", start_time, results.len() as u32);
        Ok(results)
    }

    /// Advanced search with filters
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn search_with_filters(
        bridge: &MindmapBridge,
        filters: SearchFilters,
    ) -> Result<Vec<FfiSearchResult>, BridgeError> {
        let start_time = Instant::now();

        let graph = bridge.graph.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire graph lock".to_string(),
        })?;

        let search = bridge.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        let mut candidate_nodes: Vec<NodeId> = graph.get_all_nodes().keys().cloned().collect();

        // Apply text filter
        if let Some(text_query) = filters.text_contains {
            if !text_query.trim().is_empty() {
                let text_results = search.search(&text_query)
                    .map_err(|e| BridgeError::SearchError {
                        message: format!("Text search failed: {}", e),
                    })?;
                let text_node_ids: Vec<NodeId> = text_results.into_iter()
                    .map(|r| r.node_id)
                    .collect();
                candidate_nodes.retain(|id| text_node_ids.contains(id));
            }
        }

        // Apply tag filters
        if !filters.has_tags.is_empty() {
            candidate_nodes.retain(|&id| {
                if let Some(node) = graph.get_node(id) {
                    filters.has_tags.iter().all(|tag| node.tags.contains(tag))
                } else {
                    false
                }
            });
        }

        if !filters.not_has_tags.is_empty() {
            candidate_nodes.retain(|&id| {
                if let Some(node) = graph.get_node(id) {
                    !filters.not_has_tags.iter().any(|tag| node.tags.contains(tag))
                } else {
                    false
                }
            });
        }

        // Apply date filters
        if let Some(created_after) = filters.created_after {
            candidate_nodes.retain(|&id| {
                if let Some(node) = graph.get_node(id) {
                    node.created_at.timestamp() >= created_after
                } else {
                    false
                }
            });
        }

        if let Some(updated_after) = filters.updated_after {
            candidate_nodes.retain(|&id| {
                if let Some(node) = graph.get_node(id) {
                    node.updated_at.timestamp() >= updated_after
                } else {
                    false
                }
            });
        }

        // Apply metadata filters
        for (key, value) in filters.metadata_contains {
            candidate_nodes.retain(|&id| {
                if let Some(node) = graph.get_node(id) {
                    node.metadata.get(&key).map_or(false, |v| v.contains(&value))
                } else {
                    false
                }
            });
        }

        // Convert to search results format
        let mut results: Vec<FfiSearchResult> = candidate_nodes
            .into_iter()
            .filter_map(|id| {
                graph.get_node(id).map(|node| FfiSearchResult {
                    node_id: id.to_string(),
                    text: node.text.clone(),
                    score: 1.0, // All filtered results have equal score
                    match_positions: vec![],
                })
            })
            .collect();

        // Apply sorting and limits
        if let Some(sort_by) = filters.sort_by {
            let sort_results: Vec<SearchResult> = results.iter()
                .map(|r| SearchResult {
                    node_id: bridge.parse_node_id(&r.node_id).unwrap_or_default(),
                    text: r.text.clone(),
                    score: r.score,
                    match_positions: r.match_positions.clone(),
                })
                .collect();
            let mut sort_results = sort_results;
            Self::sort_results(&mut sort_results, sort_by);
            results = sort_results.into_iter()
                .map(|r| FfiSearchResult {
                    node_id: r.node_id.to_string(),
                    text: r.text,
                    score: r.score,
                    match_positions: r.match_positions,
                })
                .collect();
        }

        if let Some(limit) = filters.limit {
            results.truncate(limit);
        }

        bridge.record_metrics("search_with_filters", start_time, results.len() as u32);
        Ok(results)
    }

    /// Get search statistics and analytics
    #[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
    pub fn get_search_stats(
        bridge: &MindmapBridge,
    ) -> Result<SearchStats, BridgeError> {
        let start_time = Instant::now();

        let search = bridge.search_engine.read().map_err(|_| BridgeError::GenericError {
            message: "Failed to acquire search lock".to_string(),
        })?;

        let stats = search.get_statistics();

        let search_stats = SearchStats {
            total_indexed_nodes: stats.total_nodes,
            total_words: stats.total_words,
            unique_words: stats.unique_words,
            total_tags: stats.total_tags,
            unique_tags: stats.unique_tags,
            average_words_per_node: if stats.total_nodes > 0 {
                stats.total_words as f64 / stats.total_nodes as f64
            } else {
                0.0
            },
            most_common_words: stats.most_common_words.into_iter().take(10).collect(),
            most_common_tags: stats.most_common_tags.into_iter().take(10).collect(),
        };

        bridge.record_metrics("get_search_stats", start_time, 1);
        Ok(search_stats)
    }

    // Helper methods

    fn search_combined(
        search: &SearchEngine,
        query: &str,
        tags: &[String],
        options: &SearchOptions,
    ) -> Result<Vec<SearchResult>, BridgeError> {
        // First get text search results
        let text_results = search.search_with_options(query, options)
            .map_err(|e| BridgeError::SearchError {
                message: format!("Text search failed: {}", e),
            })?;

        // Then get tag search results
        let tag_results = search.search_by_tags(tags)
            .map_err(|e| BridgeError::SearchError {
                message: format!("Tag search failed: {}", e),
            })?;

        // Find intersection (nodes that match both text and tags)
        let text_node_ids: std::collections::HashSet<NodeId> = text_results.iter()
            .map(|r| r.node_id)
            .collect();

        let combined_results: Vec<SearchResult> = tag_results.into_iter()
            .filter(|r| text_node_ids.contains(&r.node_id))
            .map(|mut r| {
                // Use text search score for combined results
                if let Some(text_result) = text_results.iter().find(|tr| tr.node_id == r.node_id) {
                    r.score = text_result.score;
                    r.match_positions = text_result.match_positions.clone();
                }
                r
            })
            .collect();

        Ok(combined_results)
    }

    fn sort_results(results: &mut Vec<SearchResult>, sort_by: SortBy) {
        match sort_by {
            SortBy::Score => {
                results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
            }
            SortBy::Alphabetical => {
                results.sort_by(|a, b| a.text.cmp(&b.text));
            }
            SortBy::Length => {
                results.sort_by(|a, b| a.text.len().cmp(&b.text.len()));
            }
        }
    }

    fn generate_suggestions(
        search: &SearchEngine,
        query: &str,
        max_suggestions: usize,
    ) -> Result<Vec<String>, BridgeError> {
        let words: Vec<&str> = query.split_whitespace().collect();
        if let Some(last_word) = words.last() {
            Ok(search.get_word_completions(last_word, max_suggestions))
        } else {
            Ok(Vec::new())
        }
    }

    fn determine_relationship(graph: &crate::graph::Graph, source_id: NodeId, target_id: NodeId) -> NodeRelationship {
        if let (Some(source), Some(target)) = (graph.get_node(source_id), graph.get_node(target_id)) {
            if source.parent_id == Some(target_id) {
                NodeRelationship::Child
            } else if target.parent_id == Some(source_id) {
                NodeRelationship::Parent
            } else if source.parent_id == target.parent_id && source.parent_id.is_some() {
                NodeRelationship::Sibling
            } else {
                NodeRelationship::Unrelated
            }
        } else {
            NodeRelationship::Unrelated
        }
    }
}

/// FFI-compatible search options
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SearchOptionsFFI {
    pub tags: Vec<String>,
    pub limit: Option<usize>,
    pub offset: Option<usize>,
    pub min_score: Option<f64>,
    pub include_highlights: bool,
    pub case_sensitive: bool,
    pub whole_words_only: bool,
    pub sort_by: Option<SortBy>,
}

impl Default for SearchOptionsFFI {
    fn default() -> Self {
        Self {
            tags: Vec::new(),
            limit: Some(50),
            offset: Some(0),
            min_score: Some(0.1),
            include_highlights: true,
            case_sensitive: false,
            whole_words_only: false,
            sort_by: Some(SortBy::Score),
        }
    }
}

/// Search results with metadata
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SearchResultsFFI {
    pub results: Vec<FfiSearchResult>,
    pub total_count: usize,
    pub query: String,
    pub search_time_ms: u64,
    pub has_more: bool,
    pub suggestions: Vec<String>,
}

/// Autocomplete results
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct AutocompleteResults {
    pub word_suggestions: Vec<String>,
    pub tag_suggestions: Vec<String>,
    pub query: String,
    pub suggestion_count: usize,
}

/// Similar node search result
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SimilarNodeResult {
    pub node_id: String,
    pub text: String,
    pub similarity_score: f64,
    pub common_words: usize,
    pub relationship: NodeRelationship,
}

/// Search filters for advanced filtering
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SearchFilters {
    pub text_contains: Option<String>,
    pub has_tags: Vec<String>,
    pub not_has_tags: Vec<String>,
    pub created_after: Option<i64>,
    pub updated_after: Option<i64>,
    pub metadata_contains: HashMap<String, String>,
    pub sort_by: Option<SortBy>,
    pub limit: Option<usize>,
}

/// Search statistics
#[derive(Debug, Clone)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct SearchStats {
    pub total_indexed_nodes: usize,
    pub total_words: usize,
    pub unique_words: usize,
    pub total_tags: usize,
    pub unique_tags: usize,
    pub average_words_per_node: f64,
    pub most_common_words: Vec<(String, usize)>,
    pub most_common_tags: Vec<(String, usize)>,
}

/// Sorting options for search results
#[derive(Debug, Clone, Copy)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum SortBy {
    Score,
    Alphabetical,
    Length,
}

/// Node relationship types
#[derive(Debug, Clone, Copy)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum NodeRelationship {
    Parent,
    Child,
    Sibling,
    Unrelated,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_options_default() {
        let options = SearchOptionsFFI::default();
        assert_eq!(options.limit, Some(50));
        assert_eq!(options.offset, Some(0));
        assert_eq!(options.min_score, Some(0.1));
        assert!(options.include_highlights);
        assert!(!options.case_sensitive);
        assert!(!options.whole_words_only);
    }

    #[test]
    fn test_search_results_structure() {
        let results = SearchResultsFFI {
            results: Vec::new(),
            total_count: 0,
            query: "test".to_string(),
            search_time_ms: 10,
            has_more: false,
            suggestions: Vec::new(),
        };

        assert_eq!(results.query, "test");
        assert_eq!(results.total_count, 0);
        assert_eq!(results.search_time_ms, 10);
        assert!(!results.has_more);
    }

    #[test]
    fn test_autocomplete_results() {
        let results = AutocompleteResults {
            word_suggestions: vec!["hello".to_string(), "help".to_string()],
            tag_suggestions: vec!["tag1".to_string()],
            query: "he".to_string(),
            suggestion_count: 3,
        };

        assert_eq!(results.word_suggestions.len(), 2);
        assert_eq!(results.tag_suggestions.len(), 1);
        assert_eq!(results.suggestion_count, 3);
    }

    #[test]
    fn test_similar_node_result() {
        let result = SimilarNodeResult {
            node_id: "node-123".to_string(),
            text: "Similar content".to_string(),
            similarity_score: 0.8,
            common_words: 5,
            relationship: NodeRelationship::Sibling,
        };

        assert_eq!(result.similarity_score, 0.8);
        assert_eq!(result.common_words, 5);
        assert!(matches!(result.relationship, NodeRelationship::Sibling));
    }

    #[test]
    fn test_search_filters() {
        let mut metadata = HashMap::new();
        metadata.insert("category".to_string(), "important".to_string());

        let filters = SearchFilters {
            text_contains: Some("example".to_string()),
            has_tags: vec!["urgent".to_string()],
            not_has_tags: vec!["archived".to_string()],
            created_after: Some(1640995200), // 2022-01-01
            updated_after: None,
            metadata_contains: metadata,
            sort_by: Some(SortBy::Score),
            limit: Some(20),
        };

        assert!(filters.text_contains.is_some());
        assert_eq!(filters.has_tags.len(), 1);
        assert_eq!(filters.not_has_tags.len(), 1);
        assert!(filters.created_after.is_some());
        assert_eq!(filters.limit, Some(20));
    }

    #[test]
    fn test_sort_by_variants() {
        let score = SortBy::Score;
        let alphabetical = SortBy::Alphabetical;
        let length = SortBy::Length;

        assert!(matches!(score, SortBy::Score));
        assert!(matches!(alphabetical, SortBy::Alphabetical));
        assert!(matches!(length, SortBy::Length));
    }

    #[test]
    fn test_node_relationship_variants() {
        let parent = NodeRelationship::Parent;
        let child = NodeRelationship::Child;
        let sibling = NodeRelationship::Sibling;
        let unrelated = NodeRelationship::Unrelated;

        assert!(matches!(parent, NodeRelationship::Parent));
        assert!(matches!(child, NodeRelationship::Child));
        assert!(matches!(sibling, NodeRelationship::Sibling));
        assert!(matches!(unrelated, NodeRelationship::Unrelated));
    }
}