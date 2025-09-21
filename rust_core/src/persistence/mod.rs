//! Database persistence layer for mindmap data
//!
//! This module provides SQLite-based storage for mindmap documents,
//! nodes, edges, and metadata with transaction support and migration capabilities.

//#[cfg(feature = "sqlite")]
//pub mod database;

#[cfg(feature = "sqlite")]
pub mod database_simple;

#[cfg(feature = "sqlite")]
pub mod manager;

//#[cfg(feature = "sqlite")]
//pub mod migrations;

//#[cfg(feature = "sqlite")]
//pub mod queries;

//#[cfg(feature = "sqlite")]
//pub use database::*;

#[cfg(feature = "sqlite")]
pub use database_simple::*;

#[cfg(feature = "sqlite")]
pub use manager::*;

//#[cfg(feature = "sqlite")]
//pub use migrations::*;

//#[cfg(feature = "sqlite")]
//pub use queries::*;

use crate::types::{ids::*, MindmapResult, MindmapError};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Database configuration options
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseConfig {
    /// Path to the SQLite database file
    pub path: String,
    /// Enable WAL mode for better concurrency
    pub wal_mode: bool,
    /// Enable foreign key constraints
    pub foreign_keys: bool,
    /// Connection pool size
    pub pool_size: u32,
    /// Connection timeout in seconds
    pub timeout: u64,
    /// Enable auto-vacuum
    pub auto_vacuum: bool,
    /// Page size in bytes
    pub page_size: u32,
    /// Cache size in pages
    pub cache_size: i32,
}

impl Default for DatabaseConfig {
    fn default() -> Self {
        Self {
            path: "mindmap.db".to_string(),
            wal_mode: true,
            foreign_keys: true,
            pool_size: 10,
            timeout: 30,
            auto_vacuum: true,
            page_size: 4096,
            cache_size: 1000,
        }
    }
}

impl DatabaseConfig {
    /// Create a new database configuration with custom path
    pub fn new(path: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            ..Default::default()
        }
    }

    /// Set WAL mode
    pub fn with_wal_mode(mut self, enabled: bool) -> Self {
        self.wal_mode = enabled;
        self
    }

    /// Set foreign key constraints
    pub fn with_foreign_keys(mut self, enabled: bool) -> Self {
        self.foreign_keys = enabled;
        self
    }

    /// Set connection pool size
    pub fn with_pool_size(mut self, size: u32) -> Self {
        self.pool_size = size;
        self
    }

    /// Set connection timeout
    pub fn with_timeout(mut self, timeout: u64) -> Self {
        self.timeout = timeout;
        self
    }

    /// Validate configuration
    pub fn validate(&self) -> MindmapResult<()> {
        if self.path.is_empty() {
            return Err(MindmapError::InvalidOperation {
                message: "Database path cannot be empty".to_string(),
            });
        }

        if self.pool_size == 0 {
            return Err(MindmapError::InvalidOperation {
                message: "Pool size must be greater than 0".to_string(),
            });
        }

        if self.page_size == 0 || (self.page_size & (self.page_size - 1)) != 0 {
            return Err(MindmapError::InvalidOperation {
                message: "Page size must be a power of 2".to_string(),
            });
        }

        Ok(())
    }

    /// Get database file directory
    pub fn get_directory(&self) -> Option<&str> {
        Path::new(&self.path).parent()?.to_str()
    }

    /// Check if database file exists
    pub fn exists(&self) -> bool {
        Path::new(&self.path).exists()
    }
}

/// Database transaction isolation levels
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IsolationLevel {
    ReadUncommitted,
    ReadCommitted,
    RepeatableRead,
    Serializable,
}

/// Database statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseStats {
    /// Total number of documents
    pub document_count: u64,
    /// Total number of nodes
    pub node_count: u64,
    /// Total number of edges
    pub edge_count: u64,
    /// Database file size in bytes
    pub file_size: u64,
    /// Page count
    pub page_count: u64,
    /// Free page count
    pub free_pages: u64,
    /// Schema version
    pub schema_version: u32,
}

/// Trait for database operations
#[cfg(feature = "sqlite")]
pub trait DatabaseOperations {
    /// Open or create database with configuration
    fn open(config: &DatabaseConfig) -> MindmapResult<Self>
    where
        Self: Sized;

    /// Close database connection
    fn close(&mut self) -> MindmapResult<()>;

    /// Check if database is connected
    fn is_connected(&self) -> bool;

    /// Get database statistics
    fn get_stats(&self) -> MindmapResult<DatabaseStats>;

    /// Run database migrations
    fn migrate(&mut self) -> MindmapResult<()>;

    /// Begin a transaction
    fn begin_transaction(&mut self) -> MindmapResult<()>;

    /// Commit current transaction
    fn commit_transaction(&mut self) -> MindmapResult<()>;

    /// Rollback current transaction
    fn rollback_transaction(&mut self) -> MindmapResult<()>;

    /// Execute with transaction (auto-commit on success, rollback on error)
    fn with_transaction<T, F>(&mut self, f: F) -> MindmapResult<T>
    where
        F: FnOnce(&mut Self) -> MindmapResult<T>;

    /// Optimize database (vacuum, analyze)
    fn optimize(&mut self) -> MindmapResult<()>;

    /// Backup database to file
    fn backup(&self, path: &str) -> MindmapResult<()>;

    /// Restore database from backup
    fn restore(&mut self, path: &str) -> MindmapResult<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_database_config_default() {
        let config = DatabaseConfig::default();
        assert_eq!(config.path, "mindmap.db");
        assert!(config.wal_mode);
        assert!(config.foreign_keys);
        assert!(config.pool_size > 0);
        assert!(config.timeout > 0);
    }

    #[test]
    fn test_database_config_builder() {
        let config = DatabaseConfig::new("test.db")
            .with_wal_mode(false)
            .with_foreign_keys(false)
            .with_pool_size(5)
            .with_timeout(60);

        assert_eq!(config.path, "test.db");
        assert!(!config.wal_mode);
        assert!(!config.foreign_keys);
        assert_eq!(config.pool_size, 5);
        assert_eq!(config.timeout, 60);
    }

    #[test]
    fn test_config_validation() {
        // Valid config
        let config = DatabaseConfig::default();
        assert!(config.validate().is_ok());

        // Empty path
        let config = DatabaseConfig {
            path: String::new(),
            ..DatabaseConfig::default()
        };
        assert!(config.validate().is_err());

        // Zero pool size
        let config = DatabaseConfig {
            pool_size: 0,
            ..DatabaseConfig::default()
        };
        assert!(config.validate().is_err());

        // Invalid page size (not power of 2)
        let config = DatabaseConfig {
            page_size: 3000,
            ..DatabaseConfig::default()
        };
        assert!(config.validate().is_err());
    }

    #[test]
    fn test_config_directory() {
        let config = DatabaseConfig::new("/path/to/database.db");
        assert_eq!(config.get_directory(), Some("/path/to"));

        let config = DatabaseConfig::new("database.db");
        assert_eq!(config.get_directory(), Some(""));
    }

    #[test]
    fn test_config_exists() {
        let config = DatabaseConfig::new("nonexistent.db");
        assert!(!config.exists());
    }
}