//! Database migration system for mindmap SQLite database
//!
//! This module handles database schema creation and evolution,
//! ensuring backward compatibility and data integrity.

use super::*;
use crate::types::{MindmapResult, MindmapError};
use rusqlite::{Connection, params};

/// Database schema version
pub const CURRENT_SCHEMA_VERSION: u32 = 1;

/// Migration definition
#[derive(Debug)]
pub struct Migration {
    /// Version number
    pub version: u32,
    /// Description of the migration
    pub description: String,
    /// SQL statements to execute
    pub up_sql: Vec<String>,
    /// SQL statements to rollback (optional)
    pub down_sql: Vec<String>,
}

impl Migration {
    /// Create a new migration
    pub fn new(version: u32, description: impl Into<String>) -> Self {
        Self {
            version,
            description: description.into(),
            up_sql: Vec::new(),
            down_sql: Vec::new(),
        }
    }

    /// Add an up SQL statement
    pub fn up(mut self, sql: impl Into<String>) -> Self {
        self.up_sql.push(sql.into());
        self
    }

    /// Add a down SQL statement
    pub fn down(mut self, sql: impl Into<String>) -> Self {
        self.down_sql.push(sql.into());
        self
    }

    /// Add multiple up SQL statements
    pub fn up_multi(mut self, sql_statements: Vec<String>) -> Self {
        self.up_sql.extend(sql_statements);
        self
    }
}

/// Get all available migrations
pub fn get_migrations() -> Vec<Migration> {
    vec![
        create_initial_schema(),
    ]
}

/// Create the initial database schema (version 1)
fn create_initial_schema() -> Migration {
    Migration::new(1, "Initial database schema")
        .up_multi(vec![
            // Create schema_info table for tracking migrations
            r#"
            CREATE TABLE IF NOT EXISTS schema_info (
                version INTEGER PRIMARY KEY,
                applied_at INTEGER NOT NULL,
                description TEXT NOT NULL
            )
            "#.to_string(),

            // Create documents table
            r#"
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT,
                root_node_id TEXT,
                metadata TEXT NOT NULL DEFAULT '{}',
                tags TEXT NOT NULL DEFAULT '[]',
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                version INTEGER NOT NULL DEFAULT 1,
                is_dirty BOOLEAN NOT NULL DEFAULT FALSE,
                FOREIGN KEY (root_node_id) REFERENCES nodes(id) ON DELETE SET NULL
            )
            "#.to_string(),

            // Create nodes table
            r#"
            CREATE TABLE IF NOT EXISTS nodes (
                id TEXT PRIMARY KEY,
                parent_id TEXT,
                text TEXT NOT NULL,
                position_x REAL NOT NULL DEFAULT 0.0,
                position_y REAL NOT NULL DEFAULT 0.0,
                metadata TEXT NOT NULL DEFAULT '{}',
                tags TEXT NOT NULL DEFAULT '[]',
                attachments TEXT NOT NULL DEFAULT '[]',
                style TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                version INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY (parent_id) REFERENCES nodes(id) ON DELETE SET NULL
            )
            "#.to_string(),

            // Create edges table
            r#"
            CREATE TABLE IF NOT EXISTS edges (
                id TEXT PRIMARY KEY,
                from_node_id TEXT NOT NULL,
                to_node_id TEXT NOT NULL,
                label TEXT,
                style TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                version INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY (from_node_id) REFERENCES nodes(id) ON DELETE CASCADE,
                FOREIGN KEY (to_node_id) REFERENCES nodes(id) ON DELETE CASCADE,
                UNIQUE(from_node_id, to_node_id)
            )
            "#.to_string(),

            // Create document_nodes association table
            r#"
            CREATE TABLE IF NOT EXISTS document_nodes (
                document_id TEXT NOT NULL,
                node_id TEXT NOT NULL,
                PRIMARY KEY (document_id, node_id),
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
                FOREIGN KEY (node_id) REFERENCES nodes(id) ON DELETE CASCADE
            )
            "#.to_string(),

            // Create document_edges association table
            r#"
            CREATE TABLE IF NOT EXISTS document_edges (
                document_id TEXT NOT NULL,
                edge_id TEXT NOT NULL,
                PRIMARY KEY (document_id, edge_id),
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
                FOREIGN KEY (edge_id) REFERENCES edges(id) ON DELETE CASCADE
            )
            "#.to_string(),

            // Create indexes for performance
            "CREATE INDEX IF NOT EXISTS idx_documents_updated_at ON documents(updated_at)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_documents_title ON documents(title)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_nodes_parent_id ON nodes(parent_id)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_nodes_text ON nodes(text)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_nodes_position ON nodes(position_x, position_y)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_edges_from_node ON edges(from_node_id)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_edges_to_node ON edges(to_node_id)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_document_nodes_document ON document_nodes(document_id)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_document_nodes_node ON document_nodes(node_id)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_document_edges_document ON document_edges(document_id)".to_string(),
            "CREATE INDEX IF NOT EXISTS idx_document_edges_edge ON document_edges(edge_id)".to_string(),

            // Create full-text search tables for nodes
            r#"
            CREATE VIRTUAL TABLE IF NOT EXISTS nodes_fts USING fts5(
                id UNINDEXED,
                text,
                tags,
                metadata,
                content='nodes',
                content_rowid='rowid'
            )
            "#.to_string(),

            // Create triggers to maintain FTS index
            r#"
            CREATE TRIGGER IF NOT EXISTS nodes_fts_insert AFTER INSERT ON nodes BEGIN
                INSERT INTO nodes_fts(id, text, tags, metadata)
                VALUES (new.id, new.text, new.tags, new.metadata);
            END
            "#.to_string(),

            r#"
            CREATE TRIGGER IF NOT EXISTS nodes_fts_update AFTER UPDATE ON nodes BEGIN
                UPDATE nodes_fts SET text = new.text, tags = new.tags, metadata = new.metadata
                WHERE id = new.id;
            END
            "#.to_string(),

            r#"
            CREATE TRIGGER IF NOT EXISTS nodes_fts_delete AFTER DELETE ON nodes BEGIN
                DELETE FROM nodes_fts WHERE id = old.id;
            END
            "#.to_string(),
        ])
        .down_multi(vec![
            "DROP TRIGGER IF EXISTS nodes_fts_delete".to_string(),
            "DROP TRIGGER IF EXISTS nodes_fts_update".to_string(),
            "DROP TRIGGER IF EXISTS nodes_fts_insert".to_string(),
            "DROP TABLE IF EXISTS nodes_fts".to_string(),
            "DROP INDEX IF EXISTS idx_document_edges_edge".to_string(),
            "DROP INDEX IF EXISTS idx_document_edges_document".to_string(),
            "DROP INDEX IF EXISTS idx_document_nodes_node".to_string(),
            "DROP INDEX IF EXISTS idx_document_nodes_document".to_string(),
            "DROP INDEX IF EXISTS idx_edges_to_node".to_string(),
            "DROP INDEX IF EXISTS idx_edges_from_node".to_string(),
            "DROP INDEX IF EXISTS idx_nodes_position".to_string(),
            "DROP INDEX IF EXISTS idx_nodes_text".to_string(),
            "DROP INDEX IF EXISTS idx_nodes_parent_id".to_string(),
            "DROP INDEX IF EXISTS idx_documents_title".to_string(),
            "DROP INDEX IF EXISTS idx_documents_updated_at".to_string(),
            "DROP TABLE IF EXISTS document_edges".to_string(),
            "DROP TABLE IF EXISTS document_nodes".to_string(),
            "DROP TABLE IF EXISTS edges".to_string(),
            "DROP TABLE IF EXISTS nodes".to_string(),
            "DROP TABLE IF EXISTS documents".to_string(),
            "DROP TABLE IF EXISTS schema_info".to_string(),
        ])
}

/// Run all pending migrations
pub fn run_migrations(db: &mut super::database::SqliteDatabase) -> MindmapResult<()> {
    let current_version = get_current_schema_version(db)?;
    let migrations = get_migrations();

    // Find migrations to apply
    let pending_migrations: Vec<&Migration> = migrations
        .iter()
        .filter(|m| m.version > current_version)
        .collect();

    if pending_migrations.is_empty() {
        return Ok(());
    }

    log::info!("Running {} pending migrations", pending_migrations.len());

    for migration in pending_migrations {
        log::info!("Applying migration {}: {}", migration.version, migration.description);
        apply_migration(db, migration)?;
    }

    Ok(())
}

/// Get current schema version from database
fn get_current_schema_version(db: &super::database::SqliteDatabase) -> MindmapResult<u32> {
    let conn = db.connection.lock().map_err(|_| MindmapError::DatabaseError {
        message: "Failed to acquire database lock".to_string(),
    })?;

    // Check if schema_info table exists
    let table_exists: bool = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='schema_info'",
        params![],
        |row| Ok(row.get::<_, i64>(0)? > 0)
    ).unwrap_or(false);

    if !table_exists {
        return Ok(0);
    }

    // Get the highest version number
    let version: u32 = conn.query_row(
        "SELECT COALESCE(MAX(version), 0) FROM schema_info",
        params![],
        |row| Ok(row.get::<_, i64>(0)? as u32)
    ).unwrap_or(0);

    Ok(version)
}

/// Apply a single migration
fn apply_migration(db: &mut super::database::SqliteDatabase, migration: &Migration) -> MindmapResult<()> {
    db.with_transaction(|db| {
        let conn = db.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        // Execute all up SQL statements
        for sql in &migration.up_sql {
            conn.execute(sql, params![]).map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to execute migration SQL: {} - {}", sql, e),
            })?;
        }

        // Record migration in schema_info
        conn.execute(
            "INSERT INTO schema_info (version, applied_at, description) VALUES (?1, ?2, ?3)",
            params![
                migration.version,
                chrono::Utc::now().timestamp(),
                migration.description
            ],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to record migration: {}", e),
        })?;

        Ok(())
    })
}

/// Rollback to a specific version (for development/testing)
#[allow(dead_code)]
pub fn rollback_to_version(db: &mut super::database::SqliteDatabase, target_version: u32) -> MindmapResult<()> {
    let current_version = get_current_schema_version(db)?;

    if target_version >= current_version {
        return Ok(());
    }

    let migrations = get_migrations();

    // Find migrations to rollback (in reverse order)
    let mut rollback_migrations: Vec<&Migration> = migrations
        .iter()
        .filter(|m| m.version > target_version && m.version <= current_version)
        .collect();

    rollback_migrations.sort_by(|a, b| b.version.cmp(&a.version));

    for migration in rollback_migrations {
        log::info!("Rolling back migration {}: {}", migration.version, migration.description);
        rollback_migration(db, migration)?;
    }

    Ok(())
}

/// Rollback a single migration
fn rollback_migration(db: &mut super::database::SqliteDatabase, migration: &Migration) -> MindmapResult<()> {
    db.with_transaction(|db| {
        let conn = db.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        // Execute all down SQL statements
        for sql in &migration.down_sql {
            conn.execute(sql, params![]).map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to execute rollback SQL: {} - {}", sql, e),
            })?;
        }

        // Remove migration record from schema_info
        conn.execute(
            "DELETE FROM schema_info WHERE version = ?1",
            params![migration.version],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to remove migration record: {}", e),
        })?;

        Ok(())
    })
}

/// Validate database schema integrity
pub fn validate_schema(db: &super::database::SqliteDatabase) -> MindmapResult<()> {
    let conn = db.connection.lock().map_err(|_| MindmapError::DatabaseError {
        message: "Failed to acquire database lock".to_string(),
    })?;

    // Check foreign key constraints
    conn.execute("PRAGMA foreign_key_check", params![])
        .map_err(|e| MindmapError::DatabaseError {
            message: format!("Foreign key constraint violation: {}", e),
        })?;

    // Check database integrity
    let integrity_check: String = conn.query_row(
        "PRAGMA integrity_check",
        params![],
        |row| row.get(0)
    ).map_err(|e| MindmapError::DatabaseError {
        message: format!("Failed to check database integrity: {}", e),
    })?;

    if integrity_check != "ok" {
        return Err(MindmapError::DatabaseError {
            message: format!("Database integrity check failed: {}", integrity_check),
        });
    }

    Ok(())
}

/// Get migration history
pub fn get_migration_history(db: &super::database::SqliteDatabase) -> MindmapResult<Vec<(u32, i64, String)>> {
    let conn = db.connection.lock().map_err(|_| MindmapError::DatabaseError {
        message: "Failed to acquire database lock".to_string(),
    })?;

    let mut stmt = conn.prepare(
        "SELECT version, applied_at, description FROM schema_info ORDER BY version"
    ).map_err(|e| MindmapError::DatabaseError {
        message: format!("Failed to prepare migration history query: {}", e),
    })?;

    let rows = stmt.query_map(params![], |row| {
        Ok((
            row.get::<_, i64>(0)? as u32,
            row.get::<_, i64>(1)?,
            row.get::<_, String>(2)?,
        ))
    }).map_err(|e| MindmapError::DatabaseError {
        message: format!("Failed to query migration history: {}", e),
    })?;

    let mut history = Vec::new();
    for row in rows {
        history.push(row.map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to parse migration history row: {}", e),
        })?);
    }

    Ok(history)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn create_test_db() -> super::database::SqliteDatabase {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db");
        let config = super::DatabaseConfig::new(db_path.to_string_lossy().to_string());
        super::database::SqliteDatabase::new(config).unwrap()
    }

    #[test]
    fn test_migration_creation() {
        let migration = Migration::new(1, "Test migration")
            .up("CREATE TABLE test (id INTEGER)")
            .down("DROP TABLE test");

        assert_eq!(migration.version, 1);
        assert_eq!(migration.description, "Test migration");
        assert_eq!(migration.up_sql.len(), 1);
        assert_eq!(migration.down_sql.len(), 1);
    }

    #[test]
    fn test_initial_schema_version() {
        let mut db = create_test_db();
        let version = get_current_schema_version(&db).unwrap();
        assert_eq!(version, 0);
    }

    #[test]
    fn test_run_migrations() {
        let mut db = create_test_db();

        // Run migrations
        assert!(run_migrations(&mut db).is_ok());

        // Check that schema version is updated
        let version = get_current_schema_version(&db).unwrap();
        assert_eq!(version, CURRENT_SCHEMA_VERSION);

        // Running migrations again should be a no-op
        assert!(run_migrations(&mut db).is_ok());
        let version = get_current_schema_version(&db).unwrap();
        assert_eq!(version, CURRENT_SCHEMA_VERSION);
    }

    #[test]
    fn test_schema_validation() {
        let mut db = create_test_db();
        run_migrations(&mut db).unwrap();

        // Validate schema should pass
        assert!(validate_schema(&db).is_ok());
    }

    #[test]
    fn test_migration_history() {
        let mut db = create_test_db();
        run_migrations(&mut db).unwrap();

        let history = get_migration_history(&db).unwrap();
        assert!(!history.is_empty());
        assert_eq!(history[0].0, 1); // First migration should be version 1
    }

    #[test]
    fn test_get_migrations() {
        let migrations = get_migrations();
        assert!(!migrations.is_empty());
        assert_eq!(migrations[0].version, 1);
    }

    #[test]
    fn test_schema_tables_creation() {
        let mut db = create_test_db();
        run_migrations(&mut db).unwrap();

        let conn = db.connection.lock().unwrap();

        // Check that all expected tables exist
        let tables = ["documents", "nodes", "edges", "document_nodes", "document_edges", "schema_info", "nodes_fts"];

        for table in &tables {
            let exists: bool = conn.query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?1",
                params![table],
                |row| Ok(row.get::<_, i64>(0)? > 0)
            ).unwrap_or(false);

            assert!(exists, "Table {} should exist", table);
        }
    }

    #[test]
    fn test_rollback_migration() {
        let mut db = create_test_db();
        run_migrations(&mut db).unwrap();

        let version_before = get_current_schema_version(&db).unwrap();
        assert!(version_before > 0);

        // Rollback to version 0
        rollback_to_version(&mut db, 0).unwrap();

        let version_after = get_current_schema_version(&db).unwrap();
        assert_eq!(version_after, 0);
    }
}