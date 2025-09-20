//! Search indexing for efficient text search
//!
//! This module provides indexing capabilities to speed up search operations
//! by pre-processing node content and creating searchable indices.

use crate::models::Node;
use crate::types::ids::NodeId;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

/// A search index for efficient text searching
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchIndex {
    /// Word to node IDs mapping
    word_index: HashMap<String, HashSet<NodeId>>,
    /// Tag to node IDs mapping
    tag_index: HashMap<String, HashSet<NodeId>>,
    /// Metadata key-value to node IDs mapping
    metadata_index: HashMap<String, HashSet<NodeId>>,
    /// Node ID to searchable content mapping
    content_cache: HashMap<NodeId, SearchableContent>,
}

/// Cached searchable content for a node
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchableContent {
    /// Processed words from node text
    words: Vec<String>,
    /// Node tags
    tags: Vec<String>,
    /// Flattened metadata key-value pairs
    metadata_pairs: Vec<String>,
    /// Full text for snippet generation
    full_text: String,
}

/// Index statistics
#[derive(Debug, Clone, PartialEq)]
pub struct IndexStatistics {
    /// Number of unique words indexed
    pub word_count: usize,
    /// Number of unique tags indexed
    pub tag_count: usize,
    /// Number of metadata entries indexed
    pub metadata_count: usize,
    /// Number of nodes indexed
    pub node_count: usize,
    /// Memory usage estimation in bytes
    pub estimated_memory_usage: usize,
}

impl SearchIndex {
    /// Create a new empty search index
    pub fn new() -> Self {
        Self {
            word_index: HashMap::new(),
            tag_index: HashMap::new(),
            metadata_index: HashMap::new(),
            content_cache: HashMap::new(),
        }
    }

    /// Add or update a node in the index
    pub fn index_node(&mut self, node: &Node) {
        // Remove existing entries for this node
        self.remove_node(node.id);

        // Process node text into words
        let words = Self::extract_words(&node.text);
        let tags = node.tags.clone();
        let metadata_pairs = Self::extract_metadata(&node.metadata);

        // Cache the searchable content
        let content = SearchableContent {
            words: words.clone(),
            tags: tags.clone(),
            metadata_pairs: metadata_pairs.clone(),
            full_text: node.text.clone(),
        };
        self.content_cache.insert(node.id, content);

        // Index words
        for word in &words {
            self.word_index
                .entry(word.clone())
                .or_insert_with(HashSet::new)
                .insert(node.id);
        }

        // Index tags
        for tag in &tags {
            let tag_lower = tag.to_lowercase();
            self.tag_index
                .entry(tag_lower)
                .or_insert_with(HashSet::new)
                .insert(node.id);
        }

        // Index metadata
        for pair in &metadata_pairs {
            self.metadata_index
                .entry(pair.clone())
                .or_insert_with(HashSet::new)
                .insert(node.id);
        }
    }

    /// Remove a node from the index
    pub fn remove_node(&mut self, node_id: NodeId) {
        if let Some(content) = self.content_cache.remove(&node_id) {
            // Remove from word index
            for word in &content.words {
                if let Some(node_set) = self.word_index.get_mut(word) {
                    node_set.remove(&node_id);
                    if node_set.is_empty() {
                        self.word_index.remove(word);
                    }
                }
            }

            // Remove from tag index
            for tag in &content.tags {
                let tag_lower = tag.to_lowercase();
                if let Some(node_set) = self.tag_index.get_mut(&tag_lower) {
                    node_set.remove(&node_id);
                    if node_set.is_empty() {
                        self.tag_index.remove(&tag_lower);
                    }
                }
            }

            // Remove from metadata index
            for pair in &content.metadata_pairs {
                if let Some(node_set) = self.metadata_index.get_mut(pair) {
                    node_set.remove(&node_id);
                    if node_set.is_empty() {
                        self.metadata_index.remove(pair);
                    }
                }
            }
        }
    }

    /// Search for nodes containing any of the query words
    pub fn search_words(&self, query: &str) -> HashSet<NodeId> {
        let query_words = Self::extract_words(query);
        let mut result = HashSet::new();

        for word in &query_words {
            if let Some(node_ids) = self.word_index.get(word) {
                result.extend(node_ids);
            }
        }

        result
    }

    /// Search for nodes with specific tags
    pub fn search_tags(&self, query: &str) -> HashSet<NodeId> {
        let query_lower = query.to_lowercase();
        self.tag_index.get(&query_lower).cloned().unwrap_or_default()
    }

    /// Search for nodes with metadata containing the query
    pub fn search_metadata(&self, query: &str) -> HashSet<NodeId> {
        let query_lower = query.to_lowercase();
        let mut result = HashSet::new();

        for (metadata_pair, node_ids) in &self.metadata_index {
            if metadata_pair.contains(&query_lower) {
                result.extend(node_ids);
            }
        }

        result
    }

    /// Get all nodes that match any search criteria
    pub fn search_all(&self, query: &str) -> HashSet<NodeId> {
        let mut result = HashSet::new();

        result.extend(self.search_words(query));
        result.extend(self.search_tags(query));
        result.extend(self.search_metadata(query));

        result
    }

    /// Get searchable content for a node
    pub fn get_content(&self, node_id: NodeId) -> Option<&SearchableContent> {
        self.content_cache.get(&node_id)
    }

    /// Get all words that start with a prefix (for autocomplete)
    pub fn get_word_completions(&self, prefix: &str, limit: usize) -> Vec<String> {
        let prefix_lower = prefix.to_lowercase();
        let mut completions: Vec<_> = self.word_index
            .keys()
            .filter(|word| word.starts_with(&prefix_lower) && *word != &prefix_lower)
            .cloned()
            .collect();

        // Sort by frequency (number of nodes containing the word)
        completions.sort_by(|a, b| {
            let a_count = self.word_index.get(a).map_or(0, |set| set.len());
            let b_count = self.word_index.get(b).map_or(0, |set| set.len());
            b_count.cmp(&a_count)
        });

        completions.truncate(limit);
        completions
    }

    /// Get all tags that start with a prefix
    pub fn get_tag_completions(&self, prefix: &str, limit: usize) -> Vec<String> {
        let prefix_lower = prefix.to_lowercase();
        let mut completions: Vec<_> = self.tag_index
            .keys()
            .filter(|tag| tag.starts_with(&prefix_lower) && *tag != &prefix_lower)
            .cloned()
            .collect();

        completions.sort_by(|a, b| {
            let a_count = self.tag_index.get(a).map_or(0, |set| set.len());
            let b_count = self.tag_index.get(b).map_or(0, |set| set.len());
            b_count.cmp(&a_count)
        });

        completions.truncate(limit);
        completions
    }

    /// Clear the entire index
    pub fn clear(&mut self) {
        self.word_index.clear();
        self.tag_index.clear();
        self.metadata_index.clear();
        self.content_cache.clear();
    }

    /// Get index statistics
    pub fn get_statistics(&self) -> IndexStatistics {
        let word_count = self.word_index.len();
        let tag_count = self.tag_index.len();
        let metadata_count = self.metadata_index.len();
        let node_count = self.content_cache.len();

        // Rough memory usage estimation
        let mut memory_usage = 0;
        memory_usage += word_count * 50; // Average word length + overhead
        memory_usage += tag_count * 30; // Average tag length + overhead
        memory_usage += metadata_count * 80; // Average metadata pair length + overhead
        memory_usage += node_count * 200; // Average node content size

        IndexStatistics {
            word_count,
            tag_count,
            metadata_count,
            node_count,
            estimated_memory_usage: memory_usage,
        }
    }

    /// Extract words from text, normalized and filtered
    fn extract_words(text: &str) -> Vec<String> {
        text.to_lowercase()
            .split_whitespace()
            .map(|word| {
                // Remove punctuation and normalize
                word.chars()
                    .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
                    .collect::<String>()
            })
            .filter(|word| word.len() > 1) // Skip single character words
            .collect()
    }

    /// Extract metadata key-value pairs for indexing
    fn extract_metadata(metadata: &HashMap<String, String>) -> Vec<String> {
        let mut pairs = Vec::new();
        for (key, value) in metadata {
            let pair = format!("{}:{}", key.to_lowercase(), value.to_lowercase());
            pairs.push(pair);
            // Also index just the values
            pairs.push(value.to_lowercase());
        }
        pairs
    }

    /// Rebuild the entire index from a collection of nodes
    pub fn rebuild_from_nodes<'a, I>(&mut self, nodes: I)
    where
        I: Iterator<Item = &'a Node>,
    {
        self.clear();
        for node in nodes {
            self.index_node(node);
        }
    }

    /// Check if the index contains a specific node
    pub fn contains_node(&self, node_id: NodeId) -> bool {
        self.content_cache.contains_key(&node_id)
    }

    /// Get the number of nodes that contain a specific word
    pub fn get_word_frequency(&self, word: &str) -> usize {
        let word_lower = word.to_lowercase();
        self.word_index.get(&word_lower).map_or(0, |set| set.len())
    }

    /// Get the most common words in the index
    pub fn get_common_words(&self, limit: usize) -> Vec<(String, usize)> {
        let mut word_counts: Vec<_> = self.word_index
            .iter()
            .map(|(word, node_set)| (word.clone(), node_set.len()))
            .collect();

        word_counts.sort_by(|a, b| b.1.cmp(&a.1));
        word_counts.truncate(limit);
        word_counts
    }

    /// Get the most common tags in the index
    pub fn get_common_tags(&self, limit: usize) -> Vec<(String, usize)> {
        let mut tag_counts: Vec<_> = self.tag_index
            .iter()
            .map(|(tag, node_set)| (tag.clone(), node_set.len()))
            .collect();

        tag_counts.sort_by(|a, b| b.1.cmp(&a.1));
        tag_counts.truncate(limit);
        tag_counts
    }
}

impl Default for SearchIndex {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Node;
    use std::collections::HashMap;

    fn create_test_node(text: &str, tags: Vec<&str>) -> Node {
        let mut node = Node::new(text);
        node.tags = tags.into_iter().map(|s| s.to_string()).collect();
        node.metadata.insert("category".to_string(), "test".to_string());
        node
    }

    #[test]
    fn test_index_creation() {
        let index = SearchIndex::new();
        assert_eq!(index.word_index.len(), 0);
        assert_eq!(index.tag_index.len(), 0);
        assert_eq!(index.content_cache.len(), 0);
    }

    #[test]
    fn test_node_indexing() {
        let mut index = SearchIndex::new();
        let node = create_test_node("Machine Learning Algorithms", vec!["AI", "Education"]);
        let node_id = node.id;

        index.index_node(&node);

        // Check that words are indexed
        assert!(index.word_index.contains_key("machine"));
        assert!(index.word_index.contains_key("learning"));
        assert!(index.word_index.contains_key("algorithms"));

        // Check that tags are indexed
        assert!(index.tag_index.contains_key("ai"));
        assert!(index.tag_index.contains_key("education"));

        // Check that content is cached
        assert!(index.content_cache.contains_key(&node_id));
    }

    #[test]
    fn test_node_removal() {
        let mut index = SearchIndex::new();
        let node = create_test_node("Test Content", vec!["tag1"]);
        let node_id = node.id;

        index.index_node(&node);
        assert!(index.contains_node(node_id));

        index.remove_node(node_id);
        assert!(!index.contains_node(node_id));
        assert!(index.word_index.get("test").is_none() || index.word_index.get("test").unwrap().is_empty());
    }

    #[test]
    fn test_word_search() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("Machine Learning", vec![]);
        let node2 = create_test_node("Deep Learning Networks", vec![]);

        index.index_node(&node1);
        index.index_node(&node2);

        let results = index.search_words("learning");
        assert_eq!(results.len(), 2);
        assert!(results.contains(&node1.id));
        assert!(results.contains(&node2.id));

        let results = index.search_words("machine");
        assert_eq!(results.len(), 1);
        assert!(results.contains(&node1.id));
    }

    #[test]
    fn test_tag_search() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("Content 1", vec!["AI", "Machine Learning"]);
        let node2 = create_test_node("Content 2", vec!["AI", "Deep Learning"]);

        index.index_node(&node1);
        index.index_node(&node2);

        let results = index.search_tags("AI");
        assert_eq!(results.len(), 2);

        let results = index.search_tags("Machine Learning");
        assert_eq!(results.len(), 1);
        assert!(results.contains(&node1.id));
    }

    #[test]
    fn test_metadata_search() {
        let mut index = SearchIndex::new();
        let mut node = create_test_node("Test Content", vec![]);
        node.metadata.insert("category".to_string(), "technology".to_string());
        node.metadata.insert("difficulty".to_string(), "advanced".to_string());

        index.index_node(&node);

        let results = index.search_metadata("technology");
        assert_eq!(results.len(), 1);
        assert!(results.contains(&node.id));

        let results = index.search_metadata("advanced");
        assert_eq!(results.len(), 1);
        assert!(results.contains(&node.id));
    }

    #[test]
    fn test_word_completions() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("Machine Learning", vec![]);
        let node2 = create_test_node("Machine Vision", vec![]);

        index.index_node(&node1);
        index.index_node(&node2);

        let completions = index.get_word_completions("mach", 10);
        assert!(completions.contains(&"machine".to_string()));

        let completions = index.get_word_completions("learn", 10);
        assert!(completions.contains(&"learning".to_string()));
    }

    #[test]
    fn test_tag_completions() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("Content", vec!["Artificial Intelligence"]);
        let node2 = create_test_node("Content", vec!["Art History"]);

        index.index_node(&node1);
        index.index_node(&node2);

        let completions = index.get_tag_completions("art", 10);
        assert_eq!(completions.len(), 2);
        assert!(completions.contains(&"artificial intelligence".to_string()));
        assert!(completions.contains(&"art history".to_string()));
    }

    #[test]
    fn test_statistics() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("Machine Learning", vec!["AI"]);
        let node2 = create_test_node("Deep Learning", vec!["AI", "Neural"]);

        index.index_node(&node1);
        index.index_node(&node2);

        let stats = index.get_statistics();
        assert!(stats.word_count > 0);
        assert!(stats.tag_count > 0);
        assert_eq!(stats.node_count, 2);
        assert!(stats.estimated_memory_usage > 0);
    }

    #[test]
    fn test_word_frequency() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("Learning is important", vec![]);
        let node2 = create_test_node("Machine Learning algorithms", vec![]);

        index.index_node(&node1);
        index.index_node(&node2);

        assert_eq!(index.get_word_frequency("learning"), 2);
        assert_eq!(index.get_word_frequency("machine"), 1);
        assert_eq!(index.get_word_frequency("nonexistent"), 0);
    }

    #[test]
    fn test_common_words() {
        let mut index = SearchIndex::new();
        let node1 = create_test_node("machine learning", vec![]);
        let node2 = create_test_node("learning algorithms", vec![]);
        let node3 = create_test_node("deep learning", vec![]);

        index.index_node(&node1);
        index.index_node(&node2);
        index.index_node(&node3);

        let common = index.get_common_words(5);
        assert!(!common.is_empty());

        // "learning" should be the most common word (appears 3 times)
        assert_eq!(common[0].0, "learning");
        assert_eq!(common[0].1, 3);
    }

    #[test]
    fn test_extract_words() {
        let words = SearchIndex::extract_words("Hello, World! This is a test.");
        assert!(words.contains(&"hello".to_string()));
        assert!(words.contains(&"world".to_string()));
        assert!(words.contains(&"test".to_string()));
        assert!(!words.contains(&"a".to_string())); // Single character words filtered out
    }

    #[test]
    fn test_extract_metadata() {
        let mut metadata = HashMap::new();
        metadata.insert("Category".to_string(), "Technology".to_string());
        metadata.insert("Level".to_string(), "Advanced".to_string());

        let pairs = SearchIndex::extract_metadata(&metadata);
        assert!(pairs.contains(&"category:technology".to_string()));
        assert!(pairs.contains(&"level:advanced".to_string()));
        assert!(pairs.contains(&"technology".to_string()));
        assert!(pairs.contains(&"advanced".to_string()));
    }

    #[test]
    fn test_rebuild_from_nodes() {
        let mut index = SearchIndex::new();
        let nodes = vec![
            create_test_node("First node", vec!["tag1"]),
            create_test_node("Second node", vec!["tag2"]),
        ];

        index.rebuild_from_nodes(nodes.iter());

        let stats = index.get_statistics();
        assert_eq!(stats.node_count, 2);
        assert!(stats.word_count > 0);
        assert!(stats.tag_count > 0);
    }

    #[test]
    fn test_clear_index() {
        let mut index = SearchIndex::new();
        let node = create_test_node("Test content", vec!["tag"]);

        index.index_node(&node);
        assert!(!index.word_index.is_empty());

        index.clear();
        assert!(index.word_index.is_empty());
        assert!(index.tag_index.is_empty());
        assert!(index.content_cache.is_empty());
    }
}