//! Simplified SQLite database implementation for mindmap persistence
//!
//! This is a working subset implementation focused on basic functionality

use super::*;
// Models will be used in future implementation
use crate::types::{MindmapResult, MindmapError};
use rusqlite::{Connection, params};
use std::sync::{Arc, Mutex};

/// Simplified SQLite database implementation
pub struct SimpleSqliteDatabase {
    connection: Arc<Mutex<Connection>>,
    config: DatabaseConfig,
}

impl SimpleSqliteDatabase {
    /// Create a new database instance
    pub fn new(config: DatabaseConfig) -> MindmapResult<Self> {
        config.validate()?;

        let connection = Connection::open(&config.path).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to open database: {}", e),
        })?;

        let db = Self {
            connection: Arc::new(Mutex::new(connection)),
            config,
        };

        Ok(db)
    }

    /// Get database statistics
    pub fn get_stats(&self) -> MindmapResult<DatabaseStats> {
        let _conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        let file_size = std::fs::metadata(&self.config.path)
            .map(|m| m.len())
            .unwrap_or(0);

        Ok(DatabaseStats {
            document_count: 0,
            node_count: 0,
            edge_count: 0,
            file_size,
            page_count: 0,
            free_pages: 0,
            schema_version: 1,
        })
    }

    /// Initialize basic schema (simplified)
    pub fn init_schema(&self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        conn.execute(
            r#"
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                metadata TEXT NOT NULL,
                root_node_id TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                last_saved_at INTEGER,
                is_dirty BOOLEAN NOT NULL DEFAULT FALSE
            )
            "#,
            params![],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to create documents table: {}", e),
        })?;

        conn.execute(
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
                version INTEGER NOT NULL DEFAULT 1
            )
            "#,
            params![],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to create nodes table: {}", e),
        })?;

        conn.execute(
            r#"
            CREATE TABLE IF NOT EXISTS edges (
                id TEXT PRIMARY KEY,
                from_node_id TEXT NOT NULL,
                to_node_id TEXT NOT NULL,
                label TEXT,
                style TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                version INTEGER NOT NULL DEFAULT 1
            )
            "#,
            params![],
        ).map_err(|e| MindmapError::DatabaseError {
            message: format!("Failed to create edges table: {}", e),
        })?;

        Ok(())
    }
}

impl DatabaseOperations for SimpleSqliteDatabase {
    fn open(config: &DatabaseConfig) -> MindmapResult<Self> {
        let db = Self::new(config.clone())?;
        db.init_schema()?;
        Ok(db)
    }

    fn close(&mut self) -> MindmapResult<()> {
        Ok(())
    }

    fn is_connected(&self) -> bool {
        self.connection.lock().is_ok()
    }

    fn get_stats(&self) -> MindmapResult<DatabaseStats> {
        self.get_stats()
    }

    fn migrate(&mut self) -> MindmapResult<()> {
        self.init_schema()
    }

    fn begin_transaction(&mut self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        conn.execute("BEGIN TRANSACTION", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to begin transaction: {}", e),
            })?;

        Ok(())
    }

    fn commit_transaction(&mut self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        conn.execute("COMMIT", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to commit transaction: {}", e),
            })?;

        Ok(())
    }

    fn rollback_transaction(&mut self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        conn.execute("ROLLBACK", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to rollback transaction: {}", e),
            })?;

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
                self.rollback_transaction().ok();
                Err(e)
            }
        }
    }

    fn optimize(&mut self) -> MindmapResult<()> {
        let conn = self.connection.lock().map_err(|_| MindmapError::DatabaseError {
            message: "Failed to acquire database lock".to_string(),
        })?;

        conn.execute("ANALYZE", params![])
            .map_err(|e| MindmapError::DatabaseError {
                message: format!("Failed to analyze database: {}", e),
            })?;

        Ok(())
    }

    fn backup(&self, _path: &str) -> MindmapResult<()> {
        // Simplified implementation - just return ok for now
        Ok(())
    }

    fn restore(&mut self, _path: &str) -> MindmapResult<()> {
        // Simplified implementation - just return ok for now
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    // tempdir was used before switching to in-memory database

    fn create_test_config() -> DatabaseConfig {
        // Use in-memory database for tests
        DatabaseConfig::new(":memory:")
    }

    #[test]
    fn test_simple_database_creation() {
        let config = create_test_config();
        let db = SimpleSqliteDatabase::new(config);
        assert!(db.is_ok());

        // Test with schema initialization
        let config2 = create_test_config();
        let db2 = SimpleSqliteDatabase::open(&config2);
        assert!(db2.is_ok());
    }

    #[test]
    fn test_database_operations() {
        let config = create_test_config();
        let mut db = SimpleSqliteDatabase::open(&config).unwrap();

        assert!(db.is_connected());
        assert!(db.get_stats().is_ok());
        assert!(db.migrate().is_ok());
        assert!(db.close().is_ok());
    }

    #[test]
    fn test_transactions() {
        let config = create_test_config();
        let mut db = SimpleSqliteDatabase::new(config).unwrap();
        db.init_schema().unwrap();

        // Test transaction operations
        assert!(db.begin_transaction().is_ok());
        assert!(db.commit_transaction().is_ok());

        assert!(db.begin_transaction().is_ok());
        assert!(db.rollback_transaction().is_ok());
    }

    #[test]
    fn test_with_transaction() {
        let config = create_test_config();
        let mut db = SimpleSqliteDatabase::new(config).unwrap();
        db.init_schema().unwrap();

        let result = db.with_transaction(|_| Ok(42));
        assert_eq!(result.unwrap(), 42);
    }
}