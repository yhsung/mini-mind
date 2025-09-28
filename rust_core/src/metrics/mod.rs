//! Performance metrics and monitoring framework
//!
//! This module provides comprehensive performance monitoring capabilities for the
//! mindmap core engine, including timing utilities, memory tracking, operation
//! counting, and aggregated reporting functionality.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, RwLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use serde::{Deserialize, Serialize};
use crate::types::{MindmapResult, MindmapError};

// Sub-modules
pub mod timer;
pub mod counter;
pub mod memory;
pub mod aggregator;
pub mod reporter;

// Re-exports
pub use timer::*;
pub use counter::*;
pub use memory::*;
pub use aggregator::*;
pub use reporter::*;

/// Global metrics registry instance
static METRICS_REGISTRY: std::sync::OnceLock<MetricsRegistry> = std::sync::OnceLock::new();

/// Get the global metrics registry
pub fn registry() -> &'static MetricsRegistry {
    METRICS_REGISTRY.get_or_init(|| MetricsRegistry::new())
}

/// Initialize the metrics system
pub fn init() -> MindmapResult<()> {
    let registry = registry();
    registry.reset();
    log::info!("Metrics system initialized");
    Ok(())
}

/// Metric types that can be collected
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum MetricType {
    /// Timing measurements
    Timer,
    /// Count-based metrics
    Counter,
    /// Memory usage metrics
    Memory,
    /// Distribution/histogram metrics
    Distribution,
    /// Custom application metrics
    Custom,
}

/// Metric categories for organization
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum MetricCategory {
    /// Graph operations (node/edge manipulation)
    Graph,
    /// Layout algorithm performance
    Layout,
    /// Search and indexing operations
    Search,
    /// File I/O and persistence operations
    IO,
    /// Memory allocation and management
    Memory,
    /// FFI bridge operations
    FFI,
    /// General application performance
    Application,
}

/// Unique identifier for metrics
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MetricId {
    pub category: MetricCategory,
    pub name: String,
}

impl MetricId {
    pub fn new(category: MetricCategory, name: impl Into<String>) -> Self {
        Self {
            category,
            name: name.into(),
        }
    }

    pub fn graph(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::Graph, name)
    }

    pub fn layout(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::Layout, name)
    }

    pub fn search(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::Search, name)
    }

    pub fn io(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::IO, name)
    }

    pub fn memory(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::Memory, name)
    }

    pub fn ffi(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::FFI, name)
    }

    pub fn application(name: impl Into<String>) -> Self {
        Self::new(MetricCategory::Application, name)
    }
}

impl std::fmt::Display for MetricId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}.{}", self.category, self.name)
    }
}

/// Raw metric value that can be collected
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MetricValue {
    /// Duration measurement
    Duration(Duration),
    /// Integer count
    Count(u64),
    /// Floating point value
    Float(f64),
    /// Memory size in bytes
    Bytes(u64),
    /// Boolean flag
    Boolean(bool),
    /// String value
    String(String),
}

impl MetricValue {
    /// Convert to duration if possible
    pub fn as_duration(&self) -> Option<Duration> {
        match self {
            MetricValue::Duration(d) => Some(*d),
            _ => None,
        }
    }

    /// Convert to count if possible
    pub fn as_count(&self) -> Option<u64> {
        match self {
            MetricValue::Count(c) => Some(*c),
            MetricValue::Bytes(b) => Some(*b),
            _ => None,
        }
    }

    /// Convert to float if possible
    pub fn as_float(&self) -> Option<f64> {
        match self {
            MetricValue::Float(f) => Some(*f),
            MetricValue::Duration(d) => Some(d.as_secs_f64()),
            MetricValue::Count(c) => Some(*c as f64),
            MetricValue::Bytes(b) => Some(*b as f64),
            _ => None,
        }
    }
}

/// A single metric data point
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricEntry {
    pub id: MetricId,
    pub value: MetricValue,
    pub timestamp: SystemTime,
    pub tags: HashMap<String, String>,
}

impl MetricEntry {
    pub fn new(id: MetricId, value: MetricValue) -> Self {
        Self {
            id,
            value,
            timestamp: SystemTime::now(),
            tags: HashMap::new(),
        }
    }

    pub fn with_tags(mut self, tags: HashMap<String, String>) -> Self {
        self.tags = tags;
        self
    }

    pub fn with_tag(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.tags.insert(key.into(), value.into());
        self
    }

    /// Get timestamp as milliseconds since epoch
    pub fn timestamp_millis(&self) -> u64 {
        self.timestamp
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64
    }
}

/// Central registry for all metrics
#[derive(Debug)]
pub struct MetricsRegistry {
    entries: Arc<RwLock<Vec<MetricEntry>>>,
    timers: Arc<Mutex<HashMap<MetricId, TimerRegistry>>>,
    counters: Arc<Mutex<HashMap<MetricId, CounterRegistry>>>,
    memory_tracker: Arc<Mutex<MemoryTracker>>,
    config: Arc<RwLock<MetricsConfig>>,
}

impl MetricsRegistry {
    pub fn new() -> Self {
        Self {
            entries: Arc::new(RwLock::new(Vec::new())),
            timers: Arc::new(Mutex::new(HashMap::new())),
            counters: Arc::new(Mutex::new(HashMap::new())),
            memory_tracker: Arc::new(Mutex::new(MemoryTracker::new())),
            config: Arc::new(RwLock::new(MetricsConfig::default())),
        }
    }

    /// Record a metric entry
    pub fn record(&self, entry: MetricEntry) {
        if let Ok(config) = self.config.read() {
            if !config.enabled {
                return;
            }

            // Check if category is enabled
            if !config.enabled_categories.contains(&entry.id.category) {
                return;
            }
        }

        if let Ok(mut entries) = self.entries.write() {
            entries.push(entry);

            // Maintain maximum entries limit
            if let Ok(config) = self.config.read() {
                if entries.len() > config.max_entries {
                    let remove_count = entries.len() - config.max_entries;
                    entries.drain(0..remove_count);
                }
            }
        }
    }

    /// Get timer registry for a metric
    pub fn timer(&self, id: MetricId) -> MindmapResult<TimerHandle> {
        let mut timers = self.timers.lock()
            .map_err(|_| MindmapError::MetricsError("Failed to acquire timer lock".to_string()))?;

        let timer_registry = timers.entry(id.clone()).or_insert_with(|| TimerRegistry::new(id.clone()));
        Ok(timer_registry.start())
    }

    /// Get counter for a metric
    pub fn counter(&self, id: MetricId) -> MindmapResult<Arc<Counter>> {
        let mut counters = self.counters.lock()
            .map_err(|_| MindmapError::MetricsError("Failed to acquire counter lock".to_string()))?;

        let counter_registry = counters.entry(id.clone()).or_insert_with(|| CounterRegistry::new(id.clone()));
        Ok(counter_registry.get_counter())
    }

    /// Record memory usage
    pub fn record_memory(&self, id: MetricId, bytes: u64) {
        if let Ok(tracker) = self.memory_tracker.lock() {
            tracker.record(id, bytes);
        }
    }

    /// Get current memory usage
    pub fn memory_usage(&self) -> HashMap<MetricId, u64> {
        if let Ok(tracker) = self.memory_tracker.lock() {
            tracker.current_usage()
        } else {
            HashMap::new()
        }
    }

    /// Get all recorded entries
    pub fn entries(&self) -> Vec<MetricEntry> {
        if let Ok(entries) = self.entries.read() {
            entries.clone()
        } else {
            Vec::new()
        }
    }

    /// Get entries for a specific category
    pub fn entries_for_category(&self, category: MetricCategory) -> Vec<MetricEntry> {
        if let Ok(entries) = self.entries.read() {
            entries.iter()
                .filter(|entry| entry.id.category == category)
                .cloned()
                .collect()
        } else {
            Vec::new()
        }
    }

    /// Get entries for a specific metric ID
    pub fn entries_for_metric(&self, id: &MetricId) -> Vec<MetricEntry> {
        if let Ok(entries) = self.entries.read() {
            entries.iter()
                .filter(|entry| &entry.id == id)
                .cloned()
                .collect()
        } else {
            Vec::new()
        }
    }

    /// Reset all metrics
    pub fn reset(&self) {
        if let Ok(mut entries) = self.entries.write() {
            entries.clear();
        }
        if let Ok(mut timers) = self.timers.lock() {
            timers.clear();
        }
        if let Ok(mut counters) = self.counters.lock() {
            counters.clear();
        }
        if let Ok(tracker) = self.memory_tracker.lock() {
            tracker.reset();
        }
    }

    /// Update configuration
    pub fn configure(&self, config: MetricsConfig) {
        if let Ok(mut current_config) = self.config.write() {
            *current_config = config;
        }
    }

    /// Get current configuration
    pub fn config(&self) -> MetricsConfig {
        if let Ok(config) = self.config.read() {
            config.clone()
        } else {
            MetricsConfig::default()
        }
    }

    /// Generate a comprehensive metrics report
    pub fn report(&self) -> MetricsReport {
        let entries = self.entries();
        let memory_usage = self.memory_usage();

        let mut aggregator = MetricsAggregator::new();
        aggregator.add_entries(entries);

        MetricsReport {
            timestamp: SystemTime::now(),
            total_entries: aggregator.total_count(),
            categories: aggregator.by_category(),
            memory_usage,
            summary: aggregator.summary(),
        }
    }
}

impl Default for MetricsRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// Configuration for the metrics system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsConfig {
    /// Whether metrics collection is enabled
    pub enabled: bool,
    /// Maximum number of entries to keep in memory
    pub max_entries: usize,
    /// Enabled metric categories
    pub enabled_categories: Vec<MetricCategory>,
    /// Sample rate (0.0 to 1.0)
    pub sample_rate: f64,
    /// Whether to include stack traces for timing metrics
    pub include_stack_traces: bool,
}

impl Default for MetricsConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            max_entries: 10000,
            enabled_categories: vec![
                MetricCategory::Graph,
                MetricCategory::Layout,
                MetricCategory::Search,
                MetricCategory::IO,
                MetricCategory::Memory,
                MetricCategory::FFI,
                MetricCategory::Application,
            ],
            sample_rate: 1.0,
            include_stack_traces: false,
        }
    }
}

/// Comprehensive metrics report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsReport {
    pub timestamp: SystemTime,
    pub total_entries: usize,
    pub categories: HashMap<MetricCategory, CategorySummary>,
    pub memory_usage: HashMap<MetricId, u64>,
    pub summary: MetricsSummary,
}

/// Summary for a metric category
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySummary {
    pub entry_count: usize,
    pub timing_metrics: HashMap<String, TimingSummary>,
    pub counter_metrics: HashMap<String, u64>,
    pub memory_metrics: HashMap<String, u64>,
}

/// Summary of timing metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimingSummary {
    pub count: usize,
    pub total_duration: Duration,
    pub average_duration: Duration,
    pub min_duration: Duration,
    pub max_duration: Duration,
}

/// Overall metrics summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsSummary {
    pub collection_enabled: bool,
    pub total_categories: usize,
    pub total_metrics: usize,
    pub memory_tracked_mb: f64,
    pub most_frequent_operations: Vec<(String, usize)>,
    pub slowest_operations: Vec<(String, Duration)>,
}

// Convenience macros for common metric operations
#[macro_export]
macro_rules! time_operation {
    ($category:expr, $name:expr, $operation:expr) => {{
        let id = MetricId::new($category, $name);
        let timer = $crate::metrics::registry().timer(id);
        let result = $operation;
        if let Ok(timer_handle) = timer {
            timer_handle.finish();
        }
        result
    }};
}

#[macro_export]
macro_rules! count_operation {
    ($category:expr, $name:expr) => {{
        let id = MetricId::new($category, $name);
        if let Ok(counter) = $crate::metrics::registry().counter(id) {
            counter.increment();
        }
    }};
}

#[macro_export]
macro_rules! record_memory {
    ($category:expr, $name:expr, $bytes:expr) => {{
        let id = MetricId::new($category, $name);
        $crate::metrics::registry().record_memory(id, $bytes);
    }};
}

// Update the error type to include metrics errors
impl From<String> for MindmapError {
    fn from(msg: String) -> Self {
        MindmapError::MetricsError(msg)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metric_id_creation() {
        let id = MetricId::graph("node_creation");
        assert_eq!(id.category, MetricCategory::Graph);
        assert_eq!(id.name, "node_creation");
        assert_eq!(id.to_string(), "Graph.node_creation");
    }

    #[test]
    fn test_metric_value_conversions() {
        let duration_value = MetricValue::Duration(Duration::from_millis(100));
        assert_eq!(duration_value.as_duration(), Some(Duration::from_millis(100)));
        assert_eq!(duration_value.as_float(), Some(0.1));

        let count_value = MetricValue::Count(42);
        assert_eq!(count_value.as_count(), Some(42));
        assert_eq!(count_value.as_float(), Some(42.0));
    }

    #[test]
    fn test_metrics_registry() {
        let registry = MetricsRegistry::new();

        // Test recording an entry
        let id = MetricId::graph("test_metric");
        let entry = MetricEntry::new(id.clone(), MetricValue::Count(1));
        registry.record(entry);

        let entries = registry.entries_for_metric(&id);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].value.as_count(), Some(1));
    }

    #[test]
    fn test_metrics_config() {
        let config = MetricsConfig::default();
        assert!(config.enabled);
        assert_eq!(config.max_entries, 10000);
        assert_eq!(config.sample_rate, 1.0);
        assert!(!config.include_stack_traces);
    }

    #[test]
    fn test_metrics_reset() {
        let registry = MetricsRegistry::new();

        let id = MetricId::graph("test_reset");
        let entry = MetricEntry::new(id.clone(), MetricValue::Count(1));
        registry.record(entry);

        assert_eq!(registry.entries().len(), 1);

        registry.reset();
        assert_eq!(registry.entries().len(), 0);
    }
}