//! Error handling for FFI operations
//!
//! This module provides comprehensive error handling and conversion utilities
//! for the Flutter-Rust bridge, ensuring proper error propagation and user-friendly
//! error messages across the FFI boundary.

use serde::{Deserialize, Serialize};
use std::fmt;

#[cfg(feature = "flutter_rust_bridge_feature")]
use flutter_rust_bridge::frb;

/// Detailed error information for FFI communication
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct ErrorDetails {
    /// Error code for programmatic handling
    pub code: String,
    /// Human-readable error message
    pub message: String,
    /// Additional context information
    pub context: Option<String>,
    /// Timestamp when error occurred
    pub timestamp: i64,
    /// Stack trace or debug information
    pub debug_info: Option<String>,
}

impl ErrorDetails {
    /// Create new error details
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            context: None,
            timestamp: chrono::Utc::now().timestamp(),
            debug_info: None,
        }
    }

    /// Add context information
    pub fn with_context(mut self, context: impl Into<String>) -> Self {
        self.context = Some(context.into());
        self
    }

    /// Add debug information
    pub fn with_debug_info(mut self, debug_info: impl Into<String>) -> Self {
        self.debug_info = Some(debug_info.into());
        self
    }
}

/// Error severity levels for FFI errors
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub enum ErrorSeverity {
    /// Critical error that prevents operation
    Critical,
    /// Error that affects functionality
    Error,
    /// Warning that doesn't prevent operation
    Warning,
    /// Informational message
    Info,
}

/// Enhanced bridge error with additional metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "flutter_rust_bridge_feature", frb)]
pub struct EnhancedBridgeError {
    /// Core error information
    pub details: ErrorDetails,
    /// Error severity level
    pub severity: ErrorSeverity,
    /// Suggested recovery actions
    pub recovery_suggestions: Vec<String>,
    /// Related entity IDs (node, edge, document)
    pub entity_ids: Vec<String>,
}

impl EnhancedBridgeError {
    /// Create a new enhanced error
    pub fn new(
        code: impl Into<String>,
        message: impl Into<String>,
        severity: ErrorSeverity,
    ) -> Self {
        Self {
            details: ErrorDetails::new(code, message),
            severity,
            recovery_suggestions: Vec::new(),
            entity_ids: Vec::new(),
        }
    }

    /// Add recovery suggestion
    pub fn with_recovery(mut self, suggestion: impl Into<String>) -> Self {
        self.recovery_suggestions.push(suggestion.into());
        self
    }

    /// Add entity ID
    pub fn with_entity_id(mut self, entity_id: impl Into<String>) -> Self {
        self.entity_ids.push(entity_id.into());
        self
    }

    /// Add context information
    pub fn with_context(mut self, context: impl Into<String>) -> Self {
        self.details = self.details.with_context(context);
        self
    }
}

impl fmt::Display for EnhancedBridgeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}] {}", self.details.code, self.details.message)?;

        if let Some(context) = &self.details.context {
            write!(f, " (Context: {})", context)?;
        }

        if !self.entity_ids.is_empty() {
            write!(f, " [Entities: {}]", self.entity_ids.join(", "))?;
        }

        Ok(())
    }
}

impl std::error::Error for EnhancedBridgeError {}

/// Convert basic BridgeError to enhanced version
impl From<super::BridgeError> for EnhancedBridgeError {
    fn from(error: super::BridgeError) -> Self {
        match error {
            super::BridgeError::NodeNotFound { id } => EnhancedBridgeError::new(
                "NODE_NOT_FOUND",
                format!("Node with ID '{}' was not found", id),
                ErrorSeverity::Error,
            )
            .with_entity_id(id)
            .with_recovery("Verify the node ID exists in the current mindmap")
            .with_recovery("Refresh the node list to get current valid IDs"),

            super::BridgeError::EdgeNotFound { id } => EnhancedBridgeError::new(
                "EDGE_NOT_FOUND",
                format!("Edge with ID '{}' was not found", id),
                ErrorSeverity::Error,
            )
            .with_entity_id(id)
            .with_recovery("Verify the edge ID exists in the current mindmap"),

            super::BridgeError::DocumentNotFound { id } => EnhancedBridgeError::new(
                "DOCUMENT_NOT_FOUND",
                format!("Document with ID '{}' was not found", id),
                ErrorSeverity::Critical,
            )
            .with_entity_id(id)
            .with_recovery("Load a valid mindmap document")
            .with_recovery("Create a new mindmap if none exists"),

            super::BridgeError::InvalidOperation { message } => EnhancedBridgeError::new(
                "INVALID_OPERATION",
                message,
                ErrorSeverity::Error,
            )
            .with_recovery("Check the operation parameters")
            .with_recovery("Ensure the mindmap is in a valid state"),

            super::BridgeError::FileSystemError { message } => EnhancedBridgeError::new(
                "FILE_SYSTEM_ERROR",
                format!("File system operation failed: {}", message),
                ErrorSeverity::Error,
            )
            .with_recovery("Check file permissions")
            .with_recovery("Verify the file path exists and is accessible")
            .with_recovery("Ensure sufficient disk space is available"),

            super::BridgeError::SerializationError { message } => EnhancedBridgeError::new(
                "SERIALIZATION_ERROR",
                format!("Data serialization failed: {}", message),
                ErrorSeverity::Error,
            )
            .with_recovery("Validate the data format")
            .with_recovery("Try exporting to a different format"),

            super::BridgeError::LayoutComputationError { message } => {
                EnhancedBridgeError::new(
                    "LAYOUT_COMPUTATION_ERROR",
                    format!("Layout calculation failed: {}", message),
                    ErrorSeverity::Warning,
                )
                .with_recovery("Try a different layout algorithm")
                .with_recovery("Reduce the number of nodes")
                .with_recovery("Check for circular dependencies in the graph")
            }

            super::BridgeError::SearchError { message } => EnhancedBridgeError::new(
                "SEARCH_ERROR",
                format!("Search operation failed: {}", message),
                ErrorSeverity::Warning,
            )
            .with_recovery("Try a simpler search query")
            .with_recovery("Rebuild the search index"),

            super::BridgeError::GenericError { message } => EnhancedBridgeError::new(
                "GENERIC_ERROR",
                message,
                ErrorSeverity::Error,
            )
            .with_recovery("Retry the operation")
            .with_recovery("Restart the application if the problem persists"),
        }
    }
}

/// Error recovery strategies
pub mod recovery {
    use super::*;

    /// Attempt to recover from a node operation error
    pub fn recover_node_operation(
        error: &EnhancedBridgeError,
        bridge: &super::super::MindmapBridge,
    ) -> Result<Vec<String>, EnhancedBridgeError> {
        let mut suggestions = Vec::new();

        match error.details.code.as_str() {
            "NODE_NOT_FOUND" => {
                // Try to find similar nodes
                if let Ok(all_nodes) = bridge.get_all_nodes() {
                    suggestions.push(format!("Found {} existing nodes", all_nodes.len()));
                    if !all_nodes.is_empty() {
                        let sample_ids: Vec<String> = all_nodes
                            .iter()
                            .take(3)
                            .map(|n| n.id.clone())
                            .collect();
                        suggestions.push(format!("Sample valid IDs: {}", sample_ids.join(", ")));
                    }
                }
            }
            "INVALID_OPERATION" => {
                suggestions.push("Validate mindmap state".to_string());
                if let Ok(is_valid) = bridge.validate_mindmap() {
                    suggestions.push(format!("Mindmap validation result: {}", is_valid));
                }
            }
            _ => {
                suggestions.push("General recovery suggestions available".to_string());
            }
        }

        Ok(suggestions)
    }

    /// Get user-friendly error message
    pub fn get_user_friendly_message(error: &EnhancedBridgeError) -> String {
        match error.details.code.as_str() {
            "NODE_NOT_FOUND" => {
                "The selected node could not be found. It may have been deleted or the mindmap may have been reloaded.".to_string()
            }
            "EDGE_NOT_FOUND" => {
                "The connection between nodes could not be found. The relationship may have been removed.".to_string()
            }
            "DOCUMENT_NOT_FOUND" => {
                "The mindmap document could not be found. Please load or create a mindmap first.".to_string()
            }
            "INVALID_OPERATION" => {
                "This operation is not allowed in the current state. Please check your inputs and try again.".to_string()
            }
            "FILE_SYSTEM_ERROR" => {
                "There was a problem accessing the file system. Please check permissions and available space.".to_string()
            }
            "SERIALIZATION_ERROR" => {
                "There was a problem saving or loading data. The file format may be corrupted.".to_string()
            }
            "LAYOUT_COMPUTATION_ERROR" => {
                "The layout calculation encountered an issue. Try using a different layout algorithm.".to_string()
            }
            "SEARCH_ERROR" => {
                "The search operation failed. Please try a different search term or rebuild the search index.".to_string()
            }
            _ => {
                "An unexpected error occurred. Please try again or contact support if the problem persists.".to_string()
            }
        }
    }
}

/// Error reporting and analytics
pub mod reporting {
    use super::*;
    use std::collections::HashMap;

    /// Error statistics for monitoring
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct ErrorStats {
        pub total_errors: u64,
        pub errors_by_code: HashMap<String, u64>,
        pub errors_by_severity: HashMap<ErrorSeverity, u64>,
        pub recent_errors: Vec<ErrorDetails>,
    }

    impl Default for ErrorStats {
        fn default() -> Self {
            Self {
                total_errors: 0,
                errors_by_code: HashMap::new(),
                errors_by_severity: HashMap::new(),
                recent_errors: Vec::new(),
            }
        }
    }

    impl ErrorStats {
        /// Record a new error
        pub fn record_error(&mut self, error: &EnhancedBridgeError) {
            self.total_errors += 1;

            // Count by error code
            *self.errors_by_code.entry(error.details.code.clone()).or_insert(0) += 1;

            // Count by severity
            *self.errors_by_severity.entry(error.severity).or_insert(0) += 1;

            // Keep recent errors (last 50)
            self.recent_errors.push(error.details.clone());
            if self.recent_errors.len() > 50 {
                self.recent_errors.remove(0);
            }
        }

        /// Get most frequent error codes
        pub fn get_top_error_codes(&self, limit: usize) -> Vec<(String, u64)> {
            let mut sorted_errors: Vec<_> = self.errors_by_code.iter().collect();
            sorted_errors.sort_by(|a, b| b.1.cmp(a.1));
            sorted_errors
                .into_iter()
                .take(limit)
                .map(|(code, count)| (code.clone(), *count))
                .collect()
        }

        /// Check if error rate is concerning
        pub fn is_error_rate_high(&self) -> bool {
            // Simple heuristic: more than 10% of operations result in critical errors
            let critical_count = self.errors_by_severity.get(&ErrorSeverity::Critical).unwrap_or(&0);
            let error_count = self.errors_by_severity.get(&ErrorSeverity::Error).unwrap_or(&0);

            (critical_count + error_count) > (self.total_errors / 10)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_details_creation() {
        let details = ErrorDetails::new("TEST_ERROR", "Test error message")
            .with_context("Test context")
            .with_debug_info("Debug information");

        assert_eq!(details.code, "TEST_ERROR");
        assert_eq!(details.message, "Test error message");
        assert_eq!(details.context, Some("Test context".to_string()));
        assert_eq!(details.debug_info, Some("Debug information".to_string()));
    }

    #[test]
    fn test_enhanced_error_creation() {
        let error = EnhancedBridgeError::new("TEST_ERROR", "Test message", ErrorSeverity::Error)
            .with_recovery("Try again")
            .with_entity_id("node-123")
            .with_context("Test context");

        assert_eq!(error.details.code, "TEST_ERROR");
        assert_eq!(error.severity, ErrorSeverity::Error);
        assert_eq!(error.recovery_suggestions, vec!["Try again".to_string()]);
        assert_eq!(error.entity_ids, vec!["node-123".to_string()]);
    }

    #[test]
    fn test_bridge_error_conversion() {
        let bridge_error = super::super::BridgeError::NodeNotFound {
            id: "node-123".to_string(),
        };

        let enhanced_error: EnhancedBridgeError = bridge_error.into();

        assert_eq!(enhanced_error.details.code, "NODE_NOT_FOUND");
        assert_eq!(enhanced_error.severity, ErrorSeverity::Error);
        assert!(enhanced_error.entity_ids.contains(&"node-123".to_string()));
        assert!(!enhanced_error.recovery_suggestions.is_empty());
    }

    #[test]
    fn test_user_friendly_messages() {
        let error = EnhancedBridgeError::new("NODE_NOT_FOUND", "Test", ErrorSeverity::Error);
        let message = recovery::get_user_friendly_message(&error);

        assert!(message.contains("node could not be found"));
        assert!(message.len() > 20); // Should be a meaningful message
    }

    #[test]
    fn test_error_stats() {
        let mut stats = reporting::ErrorStats::default();

        let error1 = EnhancedBridgeError::new("ERROR_A", "Test", ErrorSeverity::Error);
        let error2 = EnhancedBridgeError::new("ERROR_A", "Test", ErrorSeverity::Critical);
        let error3 = EnhancedBridgeError::new("ERROR_B", "Test", ErrorSeverity::Warning);

        stats.record_error(&error1);
        stats.record_error(&error2);
        stats.record_error(&error3);

        assert_eq!(stats.total_errors, 3);
        assert_eq!(stats.errors_by_code.get("ERROR_A"), Some(&2));
        assert_eq!(stats.errors_by_code.get("ERROR_B"), Some(&1));

        let top_errors = stats.get_top_error_codes(1);
        assert_eq!(top_errors[0].0, "ERROR_A");
        assert_eq!(top_errors[0].1, 2);
    }
}