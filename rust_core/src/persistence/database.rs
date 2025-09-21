//! SQLite database implementation for mindmap persistence
//!
//! This module provides the main SQLiteDatabase implementation with
//! connection management, transactions, and core database operations.

use super::*;
use crate::models::{Document, Node, Edge};
use crate::graph::Graph;
use crate::types::{ids::*, MindmapResult, MindmapError, Point, Timestamp};
use rusqlite::{Connection, params, OptionalExtension};
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::fs;
use std::str::FromStr;

/// SQLite database implementation
pub struct SqliteDatabase {
    /// Database connection
    connection: Arc<Mutex<Connection>>,
    /// Database configuration
    config: DatabaseConfig,
    /// Current transaction depth
    transaction_depth: u32,
}

impl SqliteDatabase {
    /// Create a new database instance
    pub fn new(config: DatabaseConfig) -> MindmapResult<Self> {
        config.validate()?;

        // Create directory if it doesn't exist
        if let Some(dir) = config.get_directory() {
            if !dir.is_empty() && !Path::new(dir).exists() {
                fs::create_dir_all(dir).map_err(|e| MindmapError::DatabaseError {
                    message: format!("Failed to create database directory: {}", e),
                })?;
            }
        }

        // Open database connection
        let connection = Connection::open(&config.path).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to open database: {}", e),
        })?;

        let mut db = Self {
            connection: Arc::new(Mutex::new(connection)),
            config,
            transaction_depth: 0,
        };

        // Configure database
        db.configure_connection()?;

        Ok(db)
    }

    /// Configure database connection settings
    fn configure_connection(&mut self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        // Enable WAL mode if configured
        if self.config.wal_mode {
            conn.execute("PRAGMA journal_mode = WAL", params![])
                .map_err(|e| MindmapError::DatabaseError {
                    message: format!("Failed to enable WAL mode: {}", e),
                })?;
        }

        // Enable foreign key constraints if configured
        if self.config.foreign_keys {
            conn.execute("PRAGMA foreign_keys = ON", params![])
                .map_err(|e| MindmapError::DatabaseError {
                    message: format!("Failed to enable foreign keys: {}", e),
                })?;
        }

        // Set cache size
        conn.execute(&format!("PRAGMA cache_size = {}", self.config.cache_size), params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to set cache size: {}", e),
            })?;

        // Set page size (only effective before first write)
        conn.execute(&format!("PRAGMA page_size = {}", self.config.page_size), params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to set page size: {}", e),
            })?;

        // Enable auto-vacuum if configured
        if self.config.auto_vacuum {
            conn.execute("PRAGMA auto_vacuum = INCREMENTAL", params![])
                .map_err(|e| MindmapError::DatabaseError {
                    message: format!("Failed to enable auto-vacuum: {}", e),
                })?;
        }

        drop(conn);
        Ok(())
    }

    /// Save a document to the database
    pub fn save_document(&mut self, document: &Document) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let metadata_json = serde_json::to_string(&document.metadata)
            .map_err(|e| MindmapError::InvalidOperation {
                message: format!("Failed to serialize document metadata: {}", e),
            })?;

        conn.execute(
            "INSERT OR REPLACE INTO documents (
                id, metadata, root_node_id,
                created_at, updated_at, last_saved_at, is_dirty
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                document.id.to_string(),
                metadata_json,
                document.root_node_id.map(|id| id.to_string()),
                document.created_at.timestamp(),
                document.updated_at.timestamp(),
                document.last_saved_at.map(|ts| ts.timestamp()),
                document.is_dirty
            ],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to save document: {}", e),
        })?;

        Ok(())
    }

    /// Load a document from the database
    pub fn load_document(&self, id: DocumentId) -> MindmapResult<Option<Document>> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare(
            "SELECT id, metadata, root_node_id,
                    created_at, updated_at, last_saved_at, is_dirty
             FROM documents WHERE id = ?1"
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

        let document = stmt.query_row(
            params![id.to_string()],
            |row| {
                let metadata_json: String = row.get(1)?;
                let root_node_id: Option<String> = row.get(2)?;

                let metadata = serde_json::from_str(&metadata_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(1, "metadata".to_string(), rusqlite::types::Type::Text))?;

                Ok(Document {
                    id: DocumentId::from_str(&row.get::<_, String>(0)?)
                        .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                    metadata,
                    root_node_id: root_node_id
                        .map(|s| NodeId::from_str(&s))
                        .transpose()
                        .map_err(|_| rusqlite::Error::InvalidColumnType(2, "root_node_id".to_string(), rusqlite::types::Type::Text))?,
                    created_at: Timestamp::from_timestamp(row.get(3)?, 0).unwrap(),
                    updated_at: Timestamp::from_timestamp(row.get(4)?, 0).unwrap(),
                    last_saved_at: row.get::<_, Option<i64>>(5)?
                        .map(|ts| Timestamp::from_timestamp(ts, 0).unwrap()),
                    is_dirty: row.get(6)?,
                })
            }
        ).optional().map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to load document: {}", e),
        })?;

        Ok(document)
    }

    /// Save a node to the database
    pub fn save_node(&mut self, node: &Node) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let metadata_json = serde_json::to_string(&node.metadata)
            .map_err(|e| MindmapError::InvalidOperation {
                message: format!("Failed to serialize node metadata: {}", e),
            })?;

        let tags_json = serde_json::to_string(&node.tags)
            .map_err(|e| MindmapError::InvalidOperation {
                message: format!("Failed to serialize node tags: {}", e),
            })?;

        let attachments_json = serde_json::to_string(&node.attachments)
            .map_err(|e| MindmapError::InvalidOperation {
                message: format!("Failed to serialize node attachments: {}", e),
            })?;

        let style_json = serde_json::to_string(&node.style)
            .map_err(|e| MindmapError::InvalidOperation {
                message: format!("Failed to serialize node style: {}", e),
            })?;

        conn.execute(
            "INSERT OR REPLACE INTO nodes (
                id, parent_id, text, position_x, position_y, metadata, tags, attachments,
                style, created_at, updated_at
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
            params![
                node.id.to_string(),
                node.parent_id.map(|id| id.to_string()),
                node.text,
                node.position.x,
                node.position.y,
                metadata_json,
                tags_json,
                attachments_json,
                style_json,
                node.created_at.timestamp(),
                node.updated_at.timestamp()
            ],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to save node: {}", e),
        })?;

        Ok(())
    }

    /// Load a node from the database
    pub fn load_node(&self, id: NodeId) -> MindmapResult<Option<Node>> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare(
            "SELECT id, parent_id, text, position_x, position_y, metadata, tags, attachments,
                    style, created_at, updated_at
             FROM nodes WHERE id = ?1"
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

        let node = stmt.query_row(
            params![id.to_string()],
            |row| {
                let metadata_json: String = row.get(5)?;
                let tags_json: String = row.get(6)?;
                let attachments_json: String = row.get(7)?;
                let style_json: String = row.get(8)?;
                let parent_id: Option<String> = row.get(1)?;

                let metadata = serde_json::from_str(&metadata_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(5, "metadata".to_string(), rusqlite::types::Type::Text))?;

                let tags = serde_json::from_str(&tags_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(6, "tags".to_string(), rusqlite::types::Type::Text))?;

                let attachments = serde_json::from_str(&attachments_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(7, "attachments".to_string(), rusqlite::types::Type::Text))?;

                let style = serde_json::from_str(&style_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(8, "style".to_string(), rusqlite::types::Type::Text))?;

                Ok(Node {
                    id: NodeId::from_str(&row.get::<_, String>(0)?)
                        .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                    parent_id: parent_id
                        .map(|s| NodeId::from_str(&s))
                        .transpose()
                        .map_err(|_| rusqlite::Error::InvalidColumnType(1, "parent_id".to_string(), rusqlite::types::Type::Text))?,
                    text: row.get(2)?,
                    position: Point::new(row.get(3)?, row.get(4)?),
                    metadata,
                    tags,
                    attachments,
                    style,
                    created_at: Timestamp::from_timestamp(row.get(9)?, 0).unwrap(),
                    updated_at: Timestamp::from_timestamp(row.get(10)?, 0).unwrap(),
                })
            }
        ).optional().map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to load node: {}", e),
        })?;

        Ok(node)
    }

    /// Save an edge to the database
    pub fn save_edge(&mut self, edge: &Edge) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let style_json = serde_json::to_string(&edge.style)
            .map_err(|e| MindmapError::InvalidOperation {
                message: format!("Failed to serialize edge style: {}", e),
            })?;

        conn.execute(
            "INSERT OR REPLACE INTO edges (
                id, from_node_id, to_node_id, label, style,
                created_at, updated_at
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                edge.id.to_string(),
                edge.from_node.to_string(),
                edge.to_node.to_string(),
                edge.label,
                style_json,
                edge.created_at.timestamp(),
                edge.updated_at.timestamp()
            ],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to save edge: {}", e),
        })?;

        Ok(())
    }

    /// Load an edge from the database
    pub fn load_edge(&self, id: EdgeId) -> MindmapResult<Option<Edge>> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare(
            "SELECT id, from_node_id, to_node_id, label, style,
                    created_at, updated_at
             FROM edges WHERE id = ?1"
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

        let edge = stmt.query_row(
            params![id.to_string()],
            |row| {
                let style_json: String = row.get(4)?;

                let style = serde_json::from_str(&style_json)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(4, "style".to_string(), rusqlite::types::Type::Text))?;

                Ok(Edge {
                    id: EdgeId::from_str(&row.get::<_, String>(0)?)
                        .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                    from_node: NodeId::from_str(&row.get::<_, String>(1)?)
                        .map_err(|_| rusqlite::Error::InvalidColumnType(1, "from_node_id".to_string(), rusqlite::types::Type::Text))?,
                    to_node: NodeId::from_str(&row.get::<_, String>(2)?)
                        .map_err(|_| rusqlite::Error::InvalidColumnType(2, "to_node_id".to_string(), rusqlite::types::Type::Text))?,
                    label: row.get(3)?,
                    style,
                    created_at: Timestamp::from_timestamp(row.get(5)?, 0).unwrap(),
                    updated_at: Timestamp::from_timestamp(row.get(6)?, 0).unwrap(),
                })
            }
        ).optional().map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to load edge: {}", e),
        })?;

        Ok(edge)
    }

    /// Save a complete graph to the database
    pub fn save_graph(&mut self, document_id: DocumentId, graph: &Graph) -> MindmapResult<()> {
        self.with_transaction(|db| {
            // Save all nodes
            for node in graph.nodes() {
                db.save_node(node)?;
            }

            // Save all edges
            for edge in graph.edges() {
                db.save_edge(edge)?;
            }

            // Update document associations
            db.associate_graph_with_document(document_id, graph)?;

            Ok(())
        })
    }

    /// Load a complete graph from the database
    pub fn load_graph(&self, document_id: DocumentId) -> MindmapResult<Graph> {
        let mut graph = Graph::new();

        // Load all nodes for this document
        let nodes = self.load_document_nodes(document_id)?;
        for node in nodes {
            graph.add_node(node)?;
        }

        // Load all edges for this document
        let edges = self.load_document_edges(document_id)?;
        for edge in edges {
            graph.add_edge(edge)?;
        }

        Ok(graph)
    }

    /// Load all nodes for a document
    fn load_document_nodes(&self, document_id: DocumentId) -> MindmapResult<Vec<Node>> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare(
            "SELECT n.id, n.parent_id, n.text, n.position_x, n.position_y, n.metadata, n.tags, n.attachments,
                    n.style, n.created_at, n.updated_at
             FROM nodes n
             INNER JOIN document_nodes dn ON n.id = dn.node_id
             WHERE dn.document_id = ?1"
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

        let rows = stmt.query_map(params![document_id.to_string()], |row| {
            let metadata_json: String = row.get(5)?;
            let tags_json: String = row.get(6)?;
            let attachments_json: String = row.get(7)?;
            let style_json: String = row.get(8)?;
            let parent_id: Option<String> = row.get(1)?;

            let metadata = serde_json::from_str(&metadata_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(5, "metadata".to_string(), rusqlite::types::Type::Text))?;

            let tags = serde_json::from_str(&tags_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(6, "tags".to_string(), rusqlite::types::Type::Text))?;

            let attachments = serde_json::from_str(&attachments_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(7, "attachments".to_string(), rusqlite::types::Type::Text))?;

            let style = serde_json::from_str(&style_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(8, "style".to_string(), rusqlite::types::Type::Text))?;

            Ok(Node {
                id: NodeId::from_str(&row.get::<_, String>(0)?)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                parent_id: parent_id
                    .map(|s| NodeId::from_str(&s))
                    .transpose()
                    .map_err(|_| rusqlite::Error::InvalidColumnType(1, "parent_id".to_string(), rusqlite::types::Type::Text))?,
                text: row.get(2)?,
                position: Point::new(row.get(3)?, row.get(4)?),
                metadata,
                tags,
                attachments,
                style,
                created_at: Timestamp::from_timestamp(row.get(9)?, 0).unwrap(),
                updated_at: Timestamp::from_timestamp(row.get(10)?, 0).unwrap(),
            })
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to query nodes: {}", e),
        })?;

        let mut nodes = Vec::new();
        for row in rows {
            nodes.push(row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse node row: {}", e),
            })?);
        }

        Ok(nodes)
    }

    /// Load all edges for a document
    fn load_document_edges(&self, document_id: DocumentId) -> MindmapResult<Vec<Edge>> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare(
            "SELECT e.id, e.from_node_id, e.to_node_id, e.label, e.style,
                    e.created_at, e.updated_at
             FROM edges e
             INNER JOIN document_edges de ON e.id = de.edge_id
             WHERE de.document_id = ?1"
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

        let rows = stmt.query_map(params![document_id.to_string()], |row| {
            let style_json: String = row.get(4)?;

            let style = serde_json::from_str(&style_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(4, "style".to_string(), rusqlite::types::Type::Text))?;

            Ok(Edge {
                id: EdgeId::from_str(&row.get::<_, String>(0)?)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                from_node: NodeId::from_str(&row.get::<_, String>(1)?)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(1, "from_node_id".to_string(), rusqlite::types::Type::Text))?,
                to_node: NodeId::from_str(&row.get::<_, String>(2)?)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(2, "to_node_id".to_string(), rusqlite::types::Type::Text))?,
                label: row.get(3)?,
                style,
                created_at: Timestamp::from_timestamp(row.get(5)?, 0).unwrap(),
                updated_at: Timestamp::from_timestamp(row.get(6)?, 0).unwrap(),
            })
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to query edges: {}", e),
        })?;

        let mut edges = Vec::new();
        for row in rows {
            edges.push(row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse edge row: {}", e),
            })?);
        }

        Ok(edges)
    }

    /// Associate graph elements with a document
    fn associate_graph_with_document(&mut self, document_id: DocumentId, graph: &Graph) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        // Clear existing associations
        conn.execute(
            "DELETE FROM document_nodes WHERE document_id = ?1",
            params![document_id.to_string()],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to clear document nodes: {}", e),
        })?;

        conn.execute(
            "DELETE FROM document_edges WHERE document_id = ?1",
            params![document_id.to_string()],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to clear document edges: {}", e),
        })?;

        // Associate nodes
        for node in graph.nodes() {
            conn.execute(
                "INSERT INTO document_nodes (document_id, node_id) VALUES (?1, ?2)",
                params![document_id.to_string(), node.id.to_string()],
            ).map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to associate node with document: {}", e),
            })?;
        }

        // Associate edges
        for edge in graph.edges() {
            conn.execute(
                "INSERT INTO document_edges (document_id, edge_id) VALUES (?1, ?2)",
                params![document_id.to_string(), edge.id.to_string()],
            ).map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to associate edge with document: {}", e),
            })?;
        }

        Ok(())
    }

    /// Delete a document and all associated data
    pub fn delete_document(&mut self, id: DocumentId) -> MindmapResult<()> {
        self.with_transaction(|db| {
            let conn = db.connection.lock().map_err(|_| MindmapError::DatabaseError {
                message: "Failed to acquire database lock".to_string(),
            })?;

            // Delete document (cascading deletes will handle associations)
            conn.execute(
                "DELETE FROM documents WHERE id = ?1",
                params![id.to_string()],
            ).map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to delete document: {}", e),
            })?;

            Ok(())
        })
    }

    /// List all documents
    pub fn list_documents(&self) -> MindmapResult<Vec<Document>> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare(
            "SELECT id, metadata, root_node_id,
                    created_at, updated_at, last_saved_at, is_dirty
             FROM documents ORDER BY updated_at DESC"
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare statement: {}", e),
        })?;

        let rows = stmt.query_map(params![], |row| {
            let metadata_json: String = row.get(1)?;
            let root_node_id: Option<String> = row.get(2)?;

            let metadata = serde_json::from_str(&metadata_json)
                .map_err(|_| rusqlite::Error::InvalidColumnType(1, "metadata".to_string(), rusqlite::types::Type::Text))?;

            Ok(Document {
                id: DocumentId::from_str(&row.get::<_, String>(0)?)
                    .map_err(|_| rusqlite::Error::InvalidColumnType(0, "id".to_string(), rusqlite::types::Type::Text))?,
                metadata,
                root_node_id: root_node_id
                    .map(|s| NodeId::from_str(&s))
                    .transpose()
                    .map_err(|_| rusqlite::Error::InvalidColumnType(2, "root_node_id".to_string(), rusqlite::types::Type::Text))?,
                created_at: Timestamp::from_timestamp(row.get(3)?, 0).unwrap(),
                updated_at: Timestamp::from_timestamp(row.get(4)?, 0).unwrap(),
                last_saved_at: row.get::<_, Option<i64>>(5)?
                    .map(|ts| Timestamp::from_timestamp(ts, 0).unwrap()),
                is_dirty: row.get(6)?,
            })
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to query documents: {}", e),
        })?;

        let mut documents = Vec::new();
        for row in rows {
            documents.push(row.map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to parse document row: {}", e),
            })?);
        }

        Ok(documents)
    }
}

impl DatabaseOperations for SqliteDatabase {
    fn open(config: &DatabaseConfig) -> MindmapResult<Self> {
        Self::new(config.clone())
    }

    fn close(&mut self) -> MindmapResult<()> {
        // SQLite connections are automatically closed when dropped
        Ok(())
    }

    fn is_connected(&self) -> bool {
        self.connection.lock().is_ok()
    }

    fn get_stats(&self) -> MindmapResult<DatabaseStats> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let mut stmt = conn.prepare("SELECT
            (SELECT COUNT(*) FROM documents) as document_count,
            (SELECT COUNT(*) FROM nodes) as node_count,
            (SELECT COUNT(*) FROM edges) as edge_count
        ").map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to prepare stats query: {}", e),
        })?;

        let (document_count, node_count, edge_count) = stmt.query_row(params![], |row| {
            Ok((row.get::<_, i64>(0)? as u64, row.get::<_, i64>(1)? as u64, row.get::<_, i64>(2)? as u64))
        }).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to get counts: {}", e),
        })?;

        // Get file size
        let file_size = std::fs::metadata(&self.config.path)
            .map(|m| m.len())
            .unwrap_or(0);

        // Get page info
        let page_count: u64 = conn.query_row("PRAGMA page_count", params![], |row| row.get(0))
            .unwrap_or(0);

        let free_pages: u64 = conn.query_row("PRAGMA freelist_count", params![], |row| row.get(0))
            .unwrap_or(0);

        Ok(DatabaseStats {
            document_count,
            node_count,
            edge_count,
            file_size,
            page_count,
            free_pages,
            schema_version: 1, // Will be managed by migrations
        })
    }

    fn migrate(&mut self) -> MindmapResult<()> {
        // Implementation will be in migrations.rs
        super::migrations::run_migrations(self)
    }

    fn begin_transaction(&mut self) -> MindmapResult<()> {
        if self.transaction_depth == 0 {
            let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
                message: "Failed to acquire database lock".to_string(),
            })?;

            conn.execute("BEGIN TRANSACTION", params![])
                .map_err(|e| MindmapError::DatabaseError {
                    message: format!("Failed to begin transaction: {}", e),
                })?;
        }
        self.transaction_depth += 1;
        Ok(())
    }

    fn commit_transaction(&mut self) -> MindmapResult<()> {
        if self.transaction_depth == 0 {
            return Err(MindmapError::InvalidOperation {
                message: "No transaction to commit".to_string(),
            });
        }

        self.transaction_depth -= 1;
        if self.transaction_depth == 0 {
            let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
                message: "Failed to acquire database lock".to_string(),
            })?;

            conn.execute("COMMIT", params![])
                .map_err(|e| MindmapError::DatabaseError {
                    message: format!("Failed to commit transaction: {}", e),
                })?;
        }
        Ok(())
    }

    fn rollback_transaction(&mut self) -> MindmapResult<()> {
        if self.transaction_depth == 0 {
            return Err(MindmapError::InvalidOperation {
                message: "No transaction to rollback".to_string(),
            });
        }

        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        conn.execute("ROLLBACK", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to rollback transaction: {}", e),
            })?;

        self.transaction_depth = 0;
        Ok(())
    }

    fn with_transaction<T, F>(&mut self, f: F) -> MindmapResult<T>
    where
        F: FnOnce(&mut Self) -> MindmapResult<T>,
    {
        self.begin_transaction()?;

        match f(self) {
            Ok(result) => {
                self.commit_transaction()?;
                Ok(result)
            }
            Err(e) => {
                self.rollback_transaction().ok(); // Ignore rollback errors
                Err(e)
            }
        }
    }

    fn optimize(&mut self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        // Run incremental vacuum
        conn.execute("PRAGMA incremental_vacuum", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to run incremental vacuum: {}", e),
            })?;

        // Analyze tables for query optimization
        conn.execute("ANALYZE", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to analyze database: {}", e),
            })?;

        Ok(())
    }

    fn backup(&self, path: &str) -> MindmapResult<()> {
        let source_conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let backup_conn = Connection::open(path).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to open backup database: {}", e),
        })?;

        let backup = rusqlite::backup::Backup::new(&source_conn, &backup_conn)
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to create backup: {}", e),
            })?;

        backup.run_to_completion(5, std::time::Duration::from_millis(100), None)
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to complete backup: {}", e),
            })?;

        Ok(())
    }

    fn restore(&mut self, path: &str) -> MindmapResult<()> {
        let source_conn = Connection::open(path).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to open backup database: {}", e),
        })?;

        let target_conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let backup = rusqlite::backup::Backup::new(&source_conn, &target_conn)
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to create restore backup: {}", e),
            })?;

        backup.run_to_completion(5, std::time::Duration::from_millis(100), None)
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to complete restore: {}", e),
            })?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn create_test_config() -> DatabaseConfig {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db");
        DatabaseConfig::new(db_path.to_string_lossy().to_string())
    }

    #[test]
    fn test_database_creation() {
        let config = create_test_config();
        let db = SqliteDatabase::new(config);
        assert!(db.is_ok());
    }

    #[test]
    fn test_database_operations_trait() {
        let config = create_test_config();
        let mut db = SqliteDatabase::open(&config).unwrap();

        assert!(db.is_connected());
        assert!(db.close().is_ok());
    }

    #[test]
    fn test_transaction_operations() {
        let config = create_test_config();
        let mut db = SqliteDatabase::new(config).unwrap();

        // Test begin/commit
        assert!(db.begin_transaction().is_ok());
        assert!(db.commit_transaction().is_ok());

        // Test begin/rollback
        assert!(db.begin_transaction().is_ok());
        assert!(db.rollback_transaction().is_ok());

        // Test with_transaction success
        let result = db.with_transaction(|_| Ok(42));
        assert_eq!(result.unwrap(), 42);

        // Test with_transaction error
        let result: MindmapResult<()> = db.with_transaction(|_| {
            Err(MindmapError::InvalidOperation {
                message: "Test error".to_string(),
            })
        });
        assert!(result.is_err());
    }

    #[test]
    fn test_document_save_load() {
        let config = create_test_config();
        let mut db = SqliteDatabase::new(config).unwrap();
        db.migrate().unwrap();

        let document = Document::new("Test Document");
        let doc_id = document.id;

        // Save document
        assert!(db.save_document(&document).is_ok());

        // Load document
        let loaded = db.load_document(doc_id).unwrap();
        assert!(loaded.is_some());
        let loaded = loaded.unwrap();
        assert_eq!(loaded.metadata.title, "Test Document");
        assert_eq!(loaded.id, doc_id);
    }

    #[test]
    fn test_node_save_load() {
        let config = create_test_config();
        let mut db = SqliteDatabase::new(config).unwrap();
        db.migrate().unwrap();

        let node = Node::new("Test Node");
        let node_id = node.id;

        // Save node
        assert!(db.save_node(&node).is_ok());

        // Load node
        let loaded = db.load_node(node_id).unwrap();
        assert!(loaded.is_some());
        let loaded = loaded.unwrap();
        assert_eq!(loaded.text, "Test Node");
        assert_eq!(loaded.id, node_id);
    }

    #[test]
    fn test_edge_save_load() {
        let config = create_test_config();
        let mut db = SqliteDatabase::new(config).unwrap();
        db.migrate().unwrap();

        let node1 = Node::new("Node 1");
        let node2 = Node::new("Node 2");
        let edge = Edge::new(node1.id, node2.id);
        let edge_id = edge.id;

        // Save nodes first
        db.save_node(&node1).unwrap();
        db.save_node(&node2).unwrap();

        // Save edge
        assert!(db.save_edge(&edge).is_ok());

        // Load edge
        let loaded = db.load_edge(edge_id).unwrap();
        assert!(loaded.is_some());
        let loaded = loaded.unwrap();
        assert_eq!(loaded.id, edge_id);
        assert_eq!(loaded.from_node, node1.id);
        assert_eq!(loaded.to_node, node2.id);
    }
}