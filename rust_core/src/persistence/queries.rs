//! Database query helpers and search functionality
//!
//! This module provides optimized queries for searching and filtering
//! mindmap data with full-text search capabilities.

use super::*;
use crate::search::SearchResult;
use crate::types::{ids::*, MindmapResult, MindmapError};
use rusqlite::{Connection, params, OptionalExtension};
use std::collections::HashMap;

/// Search options for database queries
#[derive(Debug, Clone)]
pub struct DatabaseSearchOptions {
    /// Maximum number of results to return
    pub limit: Option<usize>,
    /// Minimum relevance score (0.0 to 1.0)
    pub min_score: f64,
    /// Case sensitive search
    pub case_sensitive: bool,
    /// Include tag search
    pub include_tags: bool,
    /// Include metadata search
    pub include_metadata: bool,
    /// Document filter (search within specific documents)
    pub document_filter: Option<Vec<DocumentId>>,
}

impl Default for DatabaseSearchOptions {
    fn default() -> Self {
        Self {
            limit: Some(50),
            min_score: 0.1,
            case_sensitive: false,
            include_tags: true,
            include_metadata: false,
            document_filter: None,
        }
    }
}

/// Database query executor
pub struct QueryExecutor<'a> {
    connection: &'a Connection,
}

impl<'a> QueryExecutor<'a> {
    /// Create a new query executor
    pub fn new(connection: &'a Connection) -> Self {
        Self { connection }
    }

    /// Search nodes using full-text search
    pub fn search_nodes(&self, query: &str, options: &DatabaseSearchOptions) -> MindmapResult<Vec<SearchResult>> {
        if query.trim().is_empty() {
            return Ok(Vec::new());
        }

        let fts_query = self.prepare_fts_query(query, options)?;
        let mut results = Vec::new();

        // Build the SQL query
        let mut sql = String::from(
            r#"
            SELECT
                n.id,
                n.text,
                n.tags,
                n.metadata,
                fts.rank,
                snippet(nodes_fts, 1, '<mark>', '</mark>', '...', 50) as snippet
            FROM nodes_fts fts
            INNER JOIN nodes n ON n.id = fts.id
            "#
        );

        // Add document filter if specified
        if options.document_filter.is_some() {
            sql.push_str(
                r#"
                INNER JOIN document_nodes dn ON n.id = dn.node_id
                "#
            );
        }

        sql.push_str(&format!("WHERE nodes_fts MATCH '{}'", fts_query));

        // Add document filter condition
        if let Some(ref doc_ids) = options.document_filter {
            if !doc_ids.is_empty() {
                let placeholders: Vec<String> = doc_ids.iter().map(|_| "?".to_string()).collect();
                sql.push_str(&format!(" AND dn.document_id IN ({})", placeholders.join(",")));
            }
        }

        sql.push_str(" ORDER BY rank DESC");

        // Add limit
        if let Some(limit) = options.limit {
            sql.push_str(&format!(" LIMIT {}", limit));
        }

        // Prepare parameters
        let mut params: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();

        if let Some(ref doc_ids) = options.document_filter {
            for doc_id in doc_ids {
                params.push(Box::new(doc_id.as_uuid().to_string()));
            }
        }

        // Execute query
        let mut stmt = self.connection.prepare(&sql).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare search query: {}", e),
        })?;

        let param_refs: Vec<&dyn rusqlite::ToSql> = params.iter().map(|p| p.as_ref()).collect();

        let rows = stmt.query_map(&param_refs[..], |row| {
            let node_id = NodeId::parse(&row.get::<_, String>(0)?)
                .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?;

            let text: String = row.get(1)?;
            let tags_json: String = row.get(2)?;
            let metadata_json: String = row.get(3)?;
            let rank: f64 = row.get(4)?;
            let snippet: String = row.get(5)?;

            // Calculate score from rank (FTS5 rank is negative, lower = better)
            let score = self.calculate_score_from_rank(rank, &text, query, options);

            // Find match positions (simplified for now)
            let match_positions = self.find_match_positions(&text, query, options);

            Ok(SearchResult::new(node_id, score, snippet, match_positions))
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to execute search query: {}", e),
        })?;

        for row in rows {
            let result = row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse search result: {}", e),
            })?;

            if result.score >= options.min_score {
                results.push(result);
            }
        }

        Ok(results)
    }

    /// Search documents by title and description
    pub fn search_documents(&self, query: &str, limit: Option<usize>) -> MindmapResult<Vec<crate::models::Document>> {
        if query.trim().is_empty() {
            return Ok(Vec::new());
        }

        let search_pattern = format!("%{}%", query.to_lowercase());

        let mut sql = String::from(
            r#"
            SELECT id, title, description, root_node_id, metadata, tags,
                   created_at, updated_at, version, is_dirty
            FROM documents
            WHERE LOWER(title) LIKE ?1 OR LOWER(description) LIKE ?1
            ORDER BY
                CASE
                    WHEN LOWER(title) = LOWER(?2) THEN 1
                    WHEN LOWER(title) LIKE ?3 THEN 2
                    WHEN LOWER(description) LIKE ?3 THEN 3
                    ELSE 4
                END,
                updated_at DESC
            "#
        );

        if let Some(limit) = limit {
            sql.push_str(&format!(" LIMIT {}", limit));
        }

        let mut stmt = self.connection.prepare(&sql).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare document search query: {}", e),
        })?;

        let title_exact = query.to_lowercase();
        let title_pattern = format!("%{}%", query.to_lowercase());

        let rows = stmt.query_map(
            params![search_pattern, title_exact, title_pattern],
            |row| {
                let metadata_json: String = row.get(4)?;
                let tags_json: String = row.get(5)?;
                let root_node_id: Option<String> = row.get(3)?;

                let metadata = serde_json::from_str(&metadata_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(4, "metadata".to_string(), rusqlite::types::Type::Text))?;

                let tags = serde_json::from_str(&tags_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(5, "tags".to_string(), rusqlite::types::Type::Text))?;

                Ok(crate::models::Document {
                    id: DocumentId::parse(&row.get::<_, String>(0)?)
                        .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                    title: row.get(1)?,
                    description: row.get(2)?,
                    root_node_id: root_node_id
                        .map(|s| NodeId::parse(&s))
                        .transpose()
                        .map_err(|_| rusqlite::Error::InvalidColumnType(3, "root_node_id".to_string(), rusqlite::types::Type::Text))?,
                    metadata,
                    tags,
                    created_at: crate::types::Timestamp::from_timestamp(row.get(6)?),
                    updated_at: crate::types::Timestamp::from_timestamp(row.get(7)?),
                    version: row.get(8)?,
                    is_dirty: row.get(9)?,
                })
            }
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to execute document search: {}", e),
        })?;

        let mut documents = Vec::new();
        for row in rows {
            documents.push(row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse document row: {}", e),
            })?);
        }

        Ok(documents)
    }

    /// Get nodes by tag
    pub fn get_nodes_by_tag(&self, tag: &str, limit: Option<usize>) -> MindmapResult<Vec<NodeId>> {
        let mut sql = String::from(
            r#"
            SELECT id FROM nodes
            WHERE tags LIKE ?1
            ORDER BY updated_at DESC
            "#
        );

        if let Some(limit) = limit {
            sql.push_str(&format!(" LIMIT {}", limit));
        }

        let tag_pattern = format!("%\"{}%", tag);

        let mut stmt = self.connection.prepare(&sql).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare tag query: {}", e),
        })?;

        let rows = stmt.query_map(params![tag_pattern], |row| {
            NodeId::parse(&row.get::<_, String>(0)?)
                .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to execute tag query: {}", e),
        })?;

        let mut node_ids = Vec::new();
        for row in rows {
            node_ids.push(row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse node ID: {}", e),
            })?);
        }

        Ok(node_ids)
    }

    /// Get recent documents
    pub fn get_recent_documents(&self, limit: usize) -> MindmapResult<Vec<crate::models::Document>> {
        let mut stmt = self.connection.prepare(
            r#"
            SELECT id, title, description, root_node_id, metadata, tags,
                   created_at, updated_at, version, is_dirty
            FROM documents
            ORDER BY updated_at DESC
            LIMIT ?1
            "#
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare recent documents query: {}", e),
        })?;

        let rows = stmt.query_map(params![limit], |row| {
            let metadata_json: String = row.get(4)?;
            let tags_json: String = row.get(5)?;
            let root_node_id: Option<String> = row.get(3)?;

            let metadata = serde_json::from_str(&metadata_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(4, "metadata".to_string(), rusqlite::types::Type::Text))?;

            let tags = serde_json::from_str(&tags_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(5, "tags".to_string(), rusqlite::types::Type::Text))?;

            Ok(crate::models::Document {
                id: DocumentId::parse(&row.get::<_, String>(0)?)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                title: row.get(1)?,
                description: row.get(2)?,
                root_node_id: root_node_id
                    .map(|s| NodeId::parse(&s))
                    .transpose()
                    .map_err(|_| rusqlite::Error::InvalidColumnType(3, "root_node_id".to_string(), rusqlite::types::Type::Text))?,
                metadata,
                tags,
                created_at: crate::types::Timestamp::from_timestamp(row.get(6)?),
                updated_at: crate::types::Timestamp::from_timestamp(row.get(7)?),
                version: row.get(8)?,
                is_dirty: row.get(9)?,
            })
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to execute recent documents query: {}", e),
        })?;

        let mut documents = Vec::new();
        for row in rows {
            documents.push(row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse document row: {}", e),
            })?);
        }

        Ok(documents)
    }

    /// Get document statistics
    pub fn get_document_stats(&self, document_id: DocumentId) -> MindmapResult<HashMap<String, i64>> {
        let mut stats = HashMap::new();

        // Count nodes
        let node_count: i64 = self.connection.query_row(
            "SELECT COUNT(*) FROM document_nodes WHERE document_id = ?1",
            params![document_id.as_uuid().to_string()],
            |row| row.get(0)
        ).unwrap_or(0);
        stats.insert("node_count".to_string(), node_count);

        // Count edges
        let edge_count: i64 = self.connection.query_row(
            "SELECT COUNT(*) FROM document_edges WHERE document_id = ?1",
            params![document_id.as_uuid().to_string()],
            |row| row.get(0)
        ).unwrap_or(0);
        stats.insert("edge_count".to_string(), edge_count);

        // Count depth levels
        let max_depth: i64 = self.connection.query_row(
            r#"
            WITH RECURSIVE node_depth AS (
                SELECT n.id, 0 as depth
                FROM nodes n
                INNER JOIN document_nodes dn ON n.id = dn.node_id
                WHERE dn.document_id = ?1 AND n.parent_id IS NULL

                UNION ALL

                SELECT n.id, nd.depth + 1
                FROM nodes n
                INNER JOIN document_nodes dn ON n.id = dn.node_id
                INNER JOIN node_depth nd ON n.parent_id = nd.id
                WHERE dn.document_id = ?1
            )
            SELECT COALESCE(MAX(depth), 0) FROM node_depth
            "#,
            params![document_id.as_uuid().to_string()],
            |row| row.get(0)
        ).unwrap_or(0);
        stats.insert("max_depth".to_string(), max_depth);

        // Count root nodes
        let root_count: i64 = self.connection.query_row(
            r#"
            SELECT COUNT(*)
            FROM nodes n
            INNER JOIN document_nodes dn ON n.id = dn.node_id
            WHERE dn.document_id = ?1 AND n.parent_id IS NULL
            "#,
            params![document_id.as_uuid().to_string()],
            |row| row.get(0)
        ).unwrap_or(0);
        stats.insert("root_count".to_string(), root_count);

        Ok(stats)
    }

    /// Get popular tags across all documents
    pub fn get_popular_tags(&self, limit: usize) -> MindmapResult<Vec<(String, i64)>> {
        // This is a simplified implementation
        // In a real application, you might want to parse JSON arrays properly
        let mut stmt = self.connection.prepare(
            r#"
            SELECT tags, COUNT(*) as frequency
            FROM (
                SELECT DISTINCT tags
                FROM nodes
                WHERE tags != '[]' AND tags IS NOT NULL
                UNION ALL
                SELECT DISTINCT tags
                FROM documents
                WHERE tags != '[]' AND tags IS NOT NULL
            )
            GROUP BY tags
            ORDER BY frequency DESC
            LIMIT ?1
            "#
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare popular tags query: {}", e),
        })?;

        let rows = stmt.query_map(params![limit], |row| {
            let tags_json: String = row.get(0)?;
            let frequency: i64 = row.get(1)?;

            // Parse tags JSON and extract individual tags
            let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();

            Ok((tags, frequency))
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to execute popular tags query: {}", e),
        })?;

        let mut tag_counts: HashMap<String, i64> = HashMap::new();

        for row in rows {
            let (tags, frequency) = row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse tag row: {}", e),
            })?;

            for tag in tags {
                *tag_counts.entry(tag).or_insert(0) += frequency;
            }
        }

        let mut result: Vec<(String, i64)> = tag_counts.into_iter().collect();
        result.sort_by(|a, b| b.1.cmp(&a.1));
        result.truncate(limit);

        Ok(result)
    }

    /// Prepare FTS query with proper escaping and operators
    fn prepare_fts_query(&self, query: &str, options: &DatabaseSearchOptions) -> MindmapResult<String> {
        let mut fts_query = String::new();

        // Split query into terms
        let terms: Vec<&str> = query.split_whitespace().collect();

        if terms.is_empty() {
            return Err(MindmapError::InvalidOperation {
                message: "Query cannot be empty".to_string(),
            });
        }

        // Escape special FTS characters
        let escaped_terms: Vec<String> = terms
            .iter()
            .map(|term| self.escape_fts_term(term))
            .collect();

        // Build FTS query
        if escaped_terms.len() == 1 {
            fts_query = escaped_terms[0].clone();
        } else {
            // Use AND operator by default for multiple terms
            fts_query = escaped_terms.join(" AND ");
        }

        // Add field restrictions if needed
        if !options.include_tags && !options.include_metadata {
            fts_query = format!("text:{}", fts_query);
        }

        Ok(fts_query)
    }

    /// Escape FTS special characters
    fn escape_fts_term(&self, term: &str) -> String {
        // FTS5 special characters that need escaping
        let escaped = term
            .replace('"', "\"\"")
            .replace('*', "")
            .replace('(', "")
            .replace(')', "");

        // Quote the term if it contains spaces or special characters
        if escaped.contains(' ') || escaped != term {
            format!("\"{}\"", escaped)
        } else {
            escaped
        }
    }

    /// Calculate relevance score from FTS rank
    fn calculate_score_from_rank(&self, rank: f64, text: &str, query: &str, _options: &DatabaseSearchOptions) -> f64 {
        // FTS5 rank is negative, convert to positive score
        let base_score = 1.0 / (1.0 + (-rank));

        // Apply additional scoring factors
        let query_lower = query.to_lowercase();
        let text_lower = text.to_lowercase();

        let mut score_multiplier = 1.0;

        // Boost for exact phrase match
        if text_lower.contains(&query_lower) {
            score_multiplier *= 1.5;
        }

        // Boost for matches at the beginning
        if text_lower.starts_with(&query_lower) {
            score_multiplier *= 1.3;
        }

        // Boost for shorter text (more focused content)
        if text.len() < 100 {
            score_multiplier *= 1.2;
        }

        (base_score * score_multiplier).min(1.0)
    }

    /// Find match positions in text (simplified implementation)
    fn find_match_positions(&self, text: &str, query: &str, options: &DatabaseSearchOptions) -> Vec<(usize, usize)> {
        let mut positions = Vec::new();

        let search_text = if options.case_sensitive { text } else { &text.to_lowercase() };
        let search_query = if options.case_sensitive { query } else { &query.to_lowercase() };

        let mut start = 0;
        while let Some(pos) = search_text[start..].find(search_query) {
            let absolute_pos = start + pos;
            positions.push((absolute_pos, absolute_pos + search_query.len()));
            start = absolute_pos + 1;
        }

        positions
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn create_test_db() -> super::database::SqliteDatabase {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db");
        let config = super::DatabaseConfig::new(db_path.to_string_lossy().to_string());
        let mut db = super::database::SqliteDatabase::new(config).unwrap();
        db.migrate().unwrap();
        db
    }

    #[test]
    fn test_search_options_default() {
        let options = DatabaseSearchOptions::default();
        assert_eq!(options.limit, Some(50));
        assert_eq!(options.min_score, 0.1);
        assert!(!options.case_sensitive);
        assert!(options.include_tags);
        assert!(!options.include_metadata);
    }

    #[test]
    fn test_query_executor_creation() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);

        // Just test that we can create an executor
        assert!(true);
    }

    #[test]
    fn test_fts_query_preparation() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);
        let options = DatabaseSearchOptions::default();

        // Test single term
        let query = executor.prepare_fts_query("hello", &options).unwrap();
        assert_eq!(query, "hello");

        // Test multiple terms
        let query = executor.prepare_fts_query("hello world", &options).unwrap();
        assert_eq!(query, "hello AND world");

        // Test empty query
        let result = executor.prepare_fts_query("", &options);
        assert!(result.is_err());
    }

    #[test]
    fn test_fts_term_escaping() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);

        // Test normal term
        assert_eq!(executor.escape_fts_term("hello"), "hello");

        // Test term with quotes
        assert_eq!(executor.escape_fts_term("hello\"world"), "\"hello\"\"world\"");

        // Test term with spaces
        assert_eq!(executor.escape_fts_term("hello world"), "\"hello world\"");
    }

    #[test]
    fn test_score_calculation() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);
        let options = DatabaseSearchOptions::default();

        // Test basic scoring
        let score = executor.calculate_score_from_rank(-1.0, "hello world", "hello", &options);
        assert!(score > 0.0 && score <= 1.0);

        // Test exact match boost
        let score_exact = executor.calculate_score_from_rank(-1.0, "hello", "hello", &options);
        let score_partial = executor.calculate_score_from_rank(-1.0, "hello world", "hello", &options);
        assert!(score_exact > score_partial);
    }

    #[test]
    fn test_match_positions() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);
        let options = DatabaseSearchOptions::default();

        let positions = executor.find_match_positions("hello world hello", "hello", &options);
        assert_eq!(positions.len(), 2);
        assert_eq!(positions[0], (0, 5));
        assert_eq!(positions[1], (12, 17));
    }

    #[test]
    fn test_empty_search() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);
        let options = DatabaseSearchOptions::default();

        let results = executor.search_nodes("", &options).unwrap();
        assert!(results.is_empty());

        let results = executor.search_nodes("   ", &options).unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_document_search_empty() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);

        let results = executor.search_documents("nonexistent", Some(10)).unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_get_nodes_by_tag_empty() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);

        let results = executor.get_nodes_by_tag("nonexistent", Some(10)).unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_get_recent_documents_empty() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);

        let results = executor.get_recent_documents(10).unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_get_popular_tags_empty() {
        let db = create_test_db();
        let conn = db.connection.lock().unwrap();
        let executor = QueryExecutor::new(&conn);

        let results = executor.get_popular_tags(10).unwrap();
        assert!(results.is_empty());
    }
}