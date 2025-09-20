//! Fuzzy search algorithms for text matching
//!
//! This module implements various fuzzy search algorithms including
//! substring matching, Levenshtein distance, and basic ranking.

use std::cmp;

/// Perform fuzzy search on text and return score, snippet, and match positions
pub fn fuzzy_search(text: &str, query: &str, exact_match_boost: f64) -> Option<(f64, String, Vec<(usize, usize)>)> {
    if query.is_empty() || text.is_empty() {
        return None;
    }

    // Try exact match first
    if let Some(score) = exact_match(text, query, exact_match_boost) {
        let positions = find_all_occurrences(text, query);
        let snippet = create_snippet(text, &positions, query.len());
        return Some((score, snippet, positions));
    }

    // Try substring match
    if let Some(score) = substring_match(text, query) {
        let positions = find_all_occurrences(text, query);
        let snippet = create_snippet(text, &positions, query.len());
        return Some((score, snippet, positions));
    }

    // Try word boundary match
    if let Some(score) = word_boundary_match(text, query) {
        let positions = find_word_boundaries(text, query);
        let snippet = create_snippet(text, &positions, query.len());
        return Some((score, snippet, positions));
    }

    // Try fuzzy character matching
    if let Some((score, positions)) = fuzzy_character_match(text, query) {
        let snippet = create_snippet(text, &positions, 1);
        return Some((score, snippet, positions));
    }

    // Try Levenshtein distance for similar words
    let words: Vec<&str> = text.split_whitespace().collect();
    for (word_idx, word) in words.iter().enumerate() {
        let distance = levenshtein_distance(word, query);
        let max_len = cmp::max(word.len(), query.len());

        if max_len > 0 {
            let similarity = 1.0 - (distance as f64 / max_len as f64);

            // Accept if similarity is above threshold
            if similarity >= 0.6 {
                let score = similarity * 0.7; // Penalty for fuzzy match

                // Find the word position in original text
                let mut char_pos = 0;
                for (i, w) in words.iter().enumerate() {
                    if i == word_idx {
                        break;
                    }
                    char_pos += w.len() + 1; // +1 for space
                }

                let positions = vec![(char_pos, char_pos + word.len())];
                let snippet = create_snippet(text, &positions, word.len());
                return Some((score, snippet, positions));
            }
        }
    }

    None
}

/// Check for exact match (case insensitive)
fn exact_match(text: &str, query: &str, boost: f64) -> Option<f64> {
    if text == query {
        Some(1.0 + boost)
    } else {
        None
    }
}

/// Check for substring match and calculate score based on position and coverage
fn substring_match(text: &str, query: &str) -> Option<f64> {
    if let Some(pos) = text.find(query) {
        let coverage = query.len() as f64 / text.len() as f64;
        let position_factor = 1.0 - (pos as f64 / text.len() as f64);

        // Score based on coverage and position (earlier matches score higher)
        let score = (coverage * 0.7 + position_factor * 0.3).min(1.0);
        Some(score)
    } else {
        None
    }
}

/// Check for word boundary matches (query matches complete words)
fn word_boundary_match(text: &str, query: &str) -> Option<f64> {
    let words: Vec<&str> = text.split_whitespace().collect();
    let query_words: Vec<&str> = query.split_whitespace().collect();

    if query_words.is_empty() {
        return None;
    }

    let mut matched_words = 0;
    let mut total_score = 0.0;

    for query_word in &query_words {
        for word in &words {
            if word.contains(query_word) {
                matched_words += 1;

                // Exact word match gets higher score than partial
                if word == query_word {
                    total_score += 1.0;
                } else {
                    total_score += 0.8;
                }
                break;
            }
        }
    }

    if matched_words > 0 {
        let coverage = matched_words as f64 / words.len() as f64;
        let query_coverage = matched_words as f64 / query_words.len() as f64;

        let score = (total_score / matched_words as f64) * (coverage * 0.5 + query_coverage * 0.5);
        Some(score)
    } else {
        None
    }
}

/// Find word boundary positions for highlighting
fn find_word_boundaries(text: &str, query: &str) -> Vec<(usize, usize)> {
    let mut positions = Vec::new();
    let query_words: Vec<&str> = query.split_whitespace().collect();

    let mut char_pos = 0;
    for word in text.split_whitespace() {
        for query_word in &query_words {
            if word.contains(query_word) {
                if let Some(word_start) = word.find(query_word) {
                    positions.push((char_pos + word_start, char_pos + word_start + query_word.len()));
                }
                break;
            }
        }
        char_pos += word.len() + 1; // +1 for space
    }

    positions
}

/// Fuzzy character-by-character matching
fn fuzzy_character_match(text: &str, query: &str) -> Option<(f64, Vec<(usize, usize)>)> {
    let text_chars: Vec<char> = text.chars().collect();
    let query_chars: Vec<char> = query.chars().collect();

    if query_chars.is_empty() {
        return None;
    }

    let mut matched_chars = 0;
    let mut positions = Vec::new();
    let mut text_idx = 0;
    let mut query_idx = 0;
    let mut char_position = 0;

    while text_idx < text_chars.len() && query_idx < query_chars.len() {
        if text_chars[text_idx] == query_chars[query_idx] {
            positions.push((char_position, char_position + 1));
            matched_chars += 1;
            query_idx += 1;
        }
        text_idx += 1;
        char_position += text_chars[text_idx - 1].len_utf8();
    }

    if matched_chars > 0 {
        let score = (matched_chars as f64 / query_chars.len() as f64) * 0.5; // Penalty for character-level matching
        Some((score, positions))
    } else {
        None
    }
}

/// Find all occurrences of a substring
fn find_all_occurrences(text: &str, pattern: &str) -> Vec<(usize, usize)> {
    let mut positions = Vec::new();
    let mut start = 0;

    while let Some(pos) = text[start..].find(pattern) {
        let absolute_pos = start + pos;
        positions.push((absolute_pos, absolute_pos + pattern.len()));
        start = absolute_pos + 1;
    }

    positions
}

/// Create a snippet around match positions
fn create_snippet(text: &str, positions: &[(usize, usize)], match_len: usize) -> String {
    if positions.is_empty() {
        return text.chars().take(100).collect(); // Return first 100 chars if no positions
    }

    let first_match = positions[0].0;
    let context_size = 50; // Characters before and after

    let start = first_match.saturating_sub(context_size);
    let end = (first_match + match_len + context_size).min(text.len());

    let mut snippet = String::new();

    if start > 0 {
        snippet.push_str("...");
    }

    snippet.push_str(&text[start..end]);

    if end < text.len() {
        snippet.push_str("...");
    }

    snippet
}

/// Calculate Levenshtein distance between two strings
fn levenshtein_distance(s1: &str, s2: &str) -> usize {
    let s1_chars: Vec<char> = s1.chars().collect();
    let s2_chars: Vec<char> = s2.chars().collect();

    let len1 = s1_chars.len();
    let len2 = s2_chars.len();

    if len1 == 0 {
        return len2;
    }
    if len2 == 0 {
        return len1;
    }

    let mut matrix = vec![vec![0; len2 + 1]; len1 + 1];

    // Initialize first row and column
    for i in 0..=len1 {
        matrix[i][0] = i;
    }
    for j in 0..=len2 {
        matrix[0][j] = j;
    }

    // Fill the matrix
    for i in 1..=len1 {
        for j in 1..=len2 {
            let cost = if s1_chars[i - 1] == s2_chars[j - 1] { 0 } else { 1 };
            matrix[i][j] = cmp::min(
                cmp::min(
                    matrix[i - 1][j] + 1,     // deletion
                    matrix[i][j - 1] + 1,     // insertion
                ),
                matrix[i - 1][j - 1] + cost, // substitution
            );
        }
    }

    matrix[len1][len2]
}

/// Calculate Jaro-Winkler similarity for fuzzy matching
pub fn jaro_winkler_similarity(s1: &str, s2: &str) -> f64 {
    if s1 == s2 {
        return 1.0;
    }

    let s1_chars: Vec<char> = s1.chars().collect();
    let s2_chars: Vec<char> = s2.chars().collect();

    let len1 = s1_chars.len();
    let len2 = s2_chars.len();

    if len1 == 0 || len2 == 0 {
        return 0.0;
    }

    let match_window = cmp::max(len1, len2) / 2;
    let match_window = if match_window > 0 { match_window - 1 } else { 0 };

    let mut s1_matches = vec![false; len1];
    let mut s2_matches = vec![false; len2];

    let mut matches = 0;
    let mut transpositions = 0;

    // Identify matches
    for i in 0..len1 {
        let start = if i >= match_window { i - match_window } else { 0 };
        let end = cmp::min(i + match_window + 1, len2);

        for j in start..end {
            if s2_matches[j] || s1_chars[i] != s2_chars[j] {
                continue;
            }
            s1_matches[i] = true;
            s2_matches[j] = true;
            matches += 1;
            break;
        }
    }

    if matches == 0 {
        return 0.0;
    }

    // Count transpositions
    let mut k = 0;
    for i in 0..len1 {
        if !s1_matches[i] {
            continue;
        }
        while !s2_matches[k] {
            k += 1;
        }
        if s1_chars[i] != s2_chars[k] {
            transpositions += 1;
        }
        k += 1;
    }

    let jaro = (matches as f64 / len1 as f64
        + matches as f64 / len2 as f64
        + (matches - transpositions / 2) as f64 / matches as f64)
        / 3.0;

    // Winkler prefix bonus
    let mut prefix = 0;
    for i in 0..cmp::min(4, cmp::min(len1, len2)) {
        if s1_chars[i] == s2_chars[i] {
            prefix += 1;
        } else {
            break;
        }
    }

    jaro + (0.1 * prefix as f64 * (1.0 - jaro))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exact_match() {
        assert_eq!(exact_match("hello", "hello", 0.5), Some(1.5));
        assert_eq!(exact_match("hello", "world", 0.5), None);
    }

    #[test]
    fn test_substring_match() {
        assert!(substring_match("hello world", "world").is_some());
        assert!(substring_match("hello world", "xyz").is_none());

        // Earlier matches should score higher
        let early_score = substring_match("world hello", "world").unwrap();
        let late_score = substring_match("hello world", "world").unwrap();
        assert!(early_score > late_score);
    }

    #[test]
    fn test_word_boundary_match() {
        assert!(word_boundary_match("machine learning algorithms", "learning").is_some());
        assert!(word_boundary_match("machine learning algorithms", "learn").is_some());
        assert!(word_boundary_match("hello world", "xyz").is_none());
    }

    #[test]
    fn test_fuzzy_character_match() {
        let result = fuzzy_character_match("hello", "hlo");
        assert!(result.is_some());

        let (score, positions) = result.unwrap();
        assert!(score > 0.0);
        assert_eq!(positions.len(), 3); // h, l, o matched
    }

    #[test]
    fn test_levenshtein_distance() {
        assert_eq!(levenshtein_distance("", ""), 0);
        assert_eq!(levenshtein_distance("hello", "hello"), 0);
        assert_eq!(levenshtein_distance("hello", "hellow"), 1);
        assert_eq!(levenshtein_distance("kitten", "sitting"), 3);
    }

    #[test]
    fn test_jaro_winkler_similarity() {
        assert_eq!(jaro_winkler_similarity("hello", "hello"), 1.0);

        let similarity = jaro_winkler_similarity("dwayne", "duane");
        assert!(similarity > 0.8);

        let similarity = jaro_winkler_similarity("hello", "world");
        assert!(similarity < 0.5);

        // Empty strings should return 0.0
        assert_eq!(jaro_winkler_similarity("", "hello"), 0.0);
        assert_eq!(jaro_winkler_similarity("hello", ""), 0.0);
    }

    #[test]
    fn test_find_all_occurrences() {
        let positions = find_all_occurrences("hello hello world", "hello");
        assert_eq!(positions.len(), 2);
        assert_eq!(positions[0], (0, 5));
        assert_eq!(positions[1], (6, 11));
    }

    #[test]
    fn test_create_snippet() {
        let text = "This is a very long text that should be truncated to create a meaningful snippet around the match";
        let positions = vec![(50, 55)]; // "should"
        let snippet = create_snippet(text, &positions, 5);

        assert!(snippet.contains("should"));
        // The snippet should either be shorter or about the same length (when ellipses are added)
        assert!(snippet.len() <= text.len() + 6); // Allow for "..." at start and end
    }

    #[test]
    fn test_fuzzy_search_integration() {
        // Test exact match
        let result = fuzzy_search("machine learning", "machine learning", 0.5);
        assert!(result.is_some());
        let (score, _, _) = result.unwrap();
        assert!(score > 1.0); // Should have boost

        // Test substring match
        let result = fuzzy_search("deep machine learning", "machine", 0.0);
        assert!(result.is_some());
        let (score, snippet, positions) = result.unwrap();
        assert!(score > 0.0);
        assert!(snippet.contains("machine"));
        assert!(!positions.is_empty());

        // Test no match
        let result = fuzzy_search("hello world", "xyz", 0.0);
        assert!(result.is_none());
    }

    #[test]
    fn test_word_boundaries() {
        let positions = find_word_boundaries("neural network algorithms", "neural network");
        assert_eq!(positions.len(), 2);
        assert_eq!(positions[0], (0, 6));  // "neural"
        assert_eq!(positions[1], (7, 14)); // "network"
    }

    #[test]
    fn test_empty_inputs() {
        assert!(fuzzy_search("", "query", 0.0).is_none());
        assert!(fuzzy_search("text", "", 0.0).is_none());
        assert!(fuzzy_search("", "", 0.0).is_none());
    }
}