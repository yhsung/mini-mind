//! Performance monitoring and benchmarking for mindmap operations
//!
//! This module provides comprehensive performance monitoring capabilities
//! specifically tailored for mindmap operations including graph manipulation,
//! layout algorithms, and large-scale data handling.

use std::collections::HashMap;
use std::time::{Duration, Instant};
use serde::{Deserialize, Serialize};

use super::{
    MetricId, MetricCategory, MetricsRegistry, MetricEntry, MetricValue,
    timer::{Benchmark, BenchmarkResult, ScopedTimer},
    memory::MemoryGuard,
    counter::Counter,
};
use crate::types::{ids::NodeId, MindmapResult, MindmapError};
use crate::graph::Graph;
use crate::layout::{LayoutConfig, LayoutResult, RadialLayoutEngine, TreeLayoutEngine, ForceLayoutEngine};

/// Performance monitor for mindmap operations
#[derive(Debug)]
pub struct PerformanceMonitor {
    registry: &'static MetricsRegistry,
    enabled: bool,
}

impl PerformanceMonitor {
    /// Create a new performance monitor
    pub fn new() -> Self {
        Self {
            registry: super::registry(),
            enabled: true,
        }
    }

    /// Enable or disable performance monitoring
    pub fn set_enabled(&mut self, enabled: bool) {
        self.enabled = enabled;
    }

    /// Check if monitoring is enabled
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    /// Monitor graph operation performance
    pub fn monitor_graph_operation<F, R>(&self, operation_name: &str, graph: &Graph, func: F) -> (R, PerformanceResult)
    where
        F: FnOnce() -> R,
    {
        if !self.enabled {
            return (func(), PerformanceResult::empty());
        }

        let id = MetricId::graph(operation_name);
        let node_count = graph.node_count() as u64;
        let edge_count = graph.edge_count() as u64;

        // Record memory usage before operation
        let memory_before = self.estimate_graph_memory(graph);

        // Time the operation
        let start = Instant::now();
        let result = func();
        let duration = start.elapsed();

        // Record metrics
        self.registry.record(MetricEntry::new(id.clone(), MetricValue::Duration(duration)));

        let counter_id = MetricId::graph(format!("{}_operations", operation_name));
        if let Ok(counter) = self.registry.counter(counter_id) {
            counter.increment();
        }

        let memory_id = MetricId::memory(format!("{}_memory", operation_name));
        self.registry.record_memory(memory_id, memory_before);

        let perf_result = PerformanceResult {
            operation_name: operation_name.to_string(),
            duration,
            memory_used: memory_before,
            nodes_processed: node_count,
            edges_processed: edge_count,
            throughput: self.calculate_throughput(node_count + edge_count, duration),
        };

        (result, perf_result)
    }

    /// Monitor layout algorithm performance
    pub fn monitor_layout_operation<F>(&self, algorithm_name: &str, graph: &Graph, config: &LayoutConfig, func: F) -> (LayoutResult, LayoutPerformanceResult)
    where
        F: FnOnce() -> LayoutResult,
    {
        if !self.enabled {
            return (func(), LayoutPerformanceResult::empty());
        }

        let id = MetricId::layout(algorithm_name);
        let node_count = graph.node_count() as u64;

        // Estimate memory usage
        let memory_before = self.estimate_layout_memory(node_count, config);

        // Time the layout operation
        let start = Instant::now();
        let layout_result = func();
        let duration = start.elapsed();

        // Record timing metrics
        self.registry.record(MetricEntry::new(id.clone(), MetricValue::Duration(duration)));

        // Record layout-specific metrics
        let iterations_id = MetricId::layout(format!("{}_iterations", algorithm_name));
        self.registry.record(MetricEntry::new(iterations_id, MetricValue::Count(layout_result.iterations as u64)));

        let energy_id = MetricId::layout(format!("{}_energy", algorithm_name));
        self.registry.record(MetricEntry::new(energy_id, MetricValue::Float(layout_result.energy)));

        let convergence_id = MetricId::layout(format!("{}_convergence", algorithm_name));
        self.registry.record(MetricEntry::new(convergence_id, MetricValue::Boolean(layout_result.converged)));

        // Calculate performance metrics
        let nodes_per_second = if duration.as_secs_f64() > 0.0 {
            node_count as f64 / duration.as_secs_f64()
        } else {
            0.0
        };

        let perf_result = LayoutPerformanceResult {
            algorithm_name: algorithm_name.to_string(),
            duration,
            memory_used: memory_before,
            nodes_processed: node_count,
            iterations: layout_result.iterations,
            converged: layout_result.converged,
            energy: layout_result.energy,
            nodes_per_second,
            efficiency_score: self.calculate_layout_efficiency(&layout_result, duration),
        };

        (layout_result, perf_result)
    }

    /// Benchmark graph operations with different data sizes
    pub fn benchmark_graph_operations(&self, max_nodes: usize) -> GraphBenchmarkSuite {
        let test_sizes = vec![10, 50, 100, 500, 1000, max_nodes];
        let mut results = HashMap::new();

        for &size in &test_sizes {
            let graph = self.generate_test_graph(size);
            let suite_result = self.run_graph_operation_benchmark(&graph);
            results.insert(size, suite_result);
        }

        GraphBenchmarkSuite {
            test_sizes,
            results,
            max_nodes,
        }
    }

    /// Benchmark layout algorithms with different configurations
    pub fn benchmark_layout_algorithms(&self, node_count: usize) -> LayoutBenchmarkSuite {
        let graph = self.generate_test_graph(node_count);
        let configs = self.generate_layout_configs();
        let mut results = HashMap::new();

        // Benchmark radial layout
        for (config_name, config) in &configs {
            let radial_engine = RadialLayoutEngine::default();
            let (_, perf) = self.monitor_layout_operation("radial", &graph, config, || {
                radial_engine.apply(&graph, config).unwrap_or_else(|_| LayoutResult::empty())
            });
            results.insert(format!("radial_{}", config_name), perf);

            // Benchmark tree layout
            let tree_engine = TreeLayoutEngine::default();
            let (_, perf) = self.monitor_layout_operation("tree", &graph, config, || {
                tree_engine.apply(&graph, config).unwrap_or_else(|_| LayoutResult::empty())
            });
            results.insert(format!("tree_{}", config_name), perf);

            // Benchmark force layout
            let force_engine = ForceLayoutEngine::default();
            let (_, perf) = self.monitor_layout_operation("force", &graph, config, || {
                force_engine.apply(&graph, config).unwrap_or_else(|_| LayoutResult::empty())
            });
            results.insert(format!("force_{}", config_name), perf);
        }

        LayoutBenchmarkSuite {
            node_count,
            results,
        }
    }

    /// Monitor large mindmap handling (>1000 nodes)
    pub fn monitor_large_mindmap_operations(&self, node_count: usize) -> LargeMindmapMetrics {
        if node_count <= 1000 {
            return LargeMindmapMetrics::empty();
        }

        let graph = self.generate_test_graph(node_count);
        let mut metrics = LargeMindmapMetrics::new(node_count);

        // Monitor graph creation
        let (_, creation_perf) = self.monitor_graph_operation("large_graph_creation", &graph, || {
            // Simulate heavy graph operations
            graph.validate_structure().unwrap_or(false)
        });
        metrics.creation_performance = Some(creation_perf);

        // Monitor memory usage patterns
        let memory_tracker = super::memory::MemoryTracker::new();
        let memory_id = MetricId::memory("large_mindmap");

        // Simulate memory allocation for large graph
        let estimated_memory = self.estimate_graph_memory(&graph);
        memory_tracker.allocate(memory_id.clone(), estimated_memory);

        let memory_snapshot = memory_tracker.snapshot();
        metrics.peak_memory_usage = memory_snapshot.current_usage;

        // Monitor search performance
        if graph.node_count() > 0 {
            let search_nodes = std::cmp::min(100, graph.node_count());
            let (_, search_perf) = self.monitor_graph_operation("large_graph_search", &graph, || {
                // Simulate search operations
                for _ in 0..search_nodes {
                    let _ = graph.nodes().take(10).count();
                }
            });
            metrics.search_performance = Some(search_perf);
        }

        // Monitor layout performance for large graphs
        let config = LayoutConfig::default_for_size(node_count);
        let layout_engine = RadialLayoutEngine::default();
        let (_, layout_perf) = self.monitor_layout_operation("large_graph_layout", &graph, &config, || {
            layout_engine.apply(&graph, &config).unwrap_or_else(|_| LayoutResult::empty())
        });
        metrics.layout_performance = Some(layout_perf);

        metrics
    }

    /// Create a performance report for the current session
    pub fn generate_performance_report(&self) -> PerformanceReport {
        let report = self.registry.report();
        let graph_metrics = self.extract_graph_metrics(&report);
        let layout_metrics = self.extract_layout_metrics(&report);
        let memory_metrics = self.extract_memory_metrics(&report);

        PerformanceReport {
            timestamp: std::time::SystemTime::now(),
            graph_metrics,
            layout_metrics,
            memory_metrics,
            overall_performance: self.calculate_overall_performance_score(&report),
        }
    }

    // Helper methods

    /// Generate a test graph with specified number of nodes
    fn generate_test_graph(&self, node_count: usize) -> Graph {
        // This would normally create a proper test graph
        // For now, return an empty graph as a placeholder
        Graph::new()
    }

    /// Estimate memory usage for a graph
    fn estimate_graph_memory(&self, graph: &Graph) -> u64 {
        let node_size = 64; // Estimated bytes per node
        let edge_size = 32; // Estimated bytes per edge

        (graph.node_count() * node_size + graph.edge_count() * edge_size) as u64
    }

    /// Estimate memory usage for layout operations
    fn estimate_layout_memory(&self, node_count: u64, _config: &LayoutConfig) -> u64 {
        // Estimate memory for layout calculations
        let position_size = 16; // x,y coordinates
        let temp_data_size = 32; // Temporary calculation data per node

        node_count * (position_size + temp_data_size)
    }

    /// Calculate throughput in operations per second
    fn calculate_throughput(&self, operations: u64, duration: Duration) -> f64 {
        if duration.as_secs_f64() > 0.0 {
            operations as f64 / duration.as_secs_f64()
        } else {
            0.0
        }
    }

    /// Calculate layout efficiency score
    fn calculate_layout_efficiency(&self, result: &LayoutResult, duration: Duration) -> f64 {
        let time_factor = if duration.as_millis() > 0 { 1000.0 / duration.as_millis() as f64 } else { 0.0 };
        let convergence_factor = if result.converged { 1.0 } else { 0.5 };
        let iteration_factor = if result.iterations > 0 { 100.0 / result.iterations as f64 } else { 0.0 };

        (time_factor * convergence_factor * iteration_factor).min(100.0)
    }

    /// Generate test layout configurations
    fn generate_layout_configs(&self) -> HashMap<String, LayoutConfig> {
        let mut configs = HashMap::new();

        configs.insert("small".to_string(), LayoutConfig::default_for_size(100));
        configs.insert("medium".to_string(), LayoutConfig::default_for_size(500));
        configs.insert("large".to_string(), LayoutConfig::default_for_size(1000));

        configs
    }

    /// Run comprehensive graph operation benchmarks
    fn run_graph_operation_benchmark(&self, graph: &Graph) -> GraphOperationBenchmark {
        let mut results = HashMap::new();

        // Benchmark node operations
        if graph.node_count() > 0 {
            let (_, add_perf) = self.monitor_graph_operation("add_node", graph, || {
                // Simulate adding nodes
                for _ in 0..10 {
                    let _ = std::hint::black_box(graph.node_count());
                }
            });
            results.insert("add_node".to_string(), add_perf);

            let (_, search_perf) = self.monitor_graph_operation("search_node", graph, || {
                // Simulate node search
                let _ = graph.nodes().take(5).count();
            });
            results.insert("search_node".to_string(), search_perf);
        }

        // Benchmark edge operations
        if graph.edge_count() > 0 {
            let (_, edge_perf) = self.monitor_graph_operation("traverse_edges", graph, || {
                // Simulate edge traversal
                let _ = graph.edges().take(10).count();
            });
            results.insert("traverse_edges".to_string(), edge_perf);
        }

        GraphOperationBenchmark {
            node_count: graph.node_count(),
            edge_count: graph.edge_count(),
            operation_results: results,
        }
    }

    /// Extract graph-related metrics from report
    fn extract_graph_metrics(&self, report: &super::MetricsReport) -> GraphPerformanceMetrics {
        let graph_category = report.categories.get(&MetricCategory::Graph);

        GraphPerformanceMetrics {
            total_operations: graph_category.map(|c| c.entry_count).unwrap_or(0),
            average_operation_time: graph_category
                .and_then(|c| c.timing_metrics.values().next())
                .map(|t| t.average_duration)
                .unwrap_or(Duration::ZERO),
            memory_usage: report.memory_usage.values().sum(),
        }
    }

    /// Extract layout-related metrics from report
    fn extract_layout_metrics(&self, report: &super::MetricsReport) -> LayoutPerformanceMetrics {
        let layout_category = report.categories.get(&MetricCategory::Layout);

        LayoutPerformanceMetrics {
            total_layouts: layout_category.map(|c| c.entry_count).unwrap_or(0),
            average_layout_time: layout_category
                .and_then(|c| c.timing_metrics.values().next())
                .map(|t| t.average_duration)
                .unwrap_or(Duration::ZERO),
            average_iterations: 0, // Would be calculated from actual data
            convergence_rate: 0.0, // Would be calculated from actual data
        }
    }

    /// Extract memory-related metrics from report
    fn extract_memory_metrics(&self, report: &super::MetricsReport) -> MemoryPerformanceMetrics {
        MemoryPerformanceMetrics {
            peak_usage: report.memory_usage.values().max().copied().unwrap_or(0),
            total_allocated: report.memory_usage.values().sum(),
            efficiency: 0.85, // Would be calculated from actual allocation/deallocation ratios
        }
    }

    /// Calculate overall performance score
    fn calculate_overall_performance_score(&self, _report: &super::MetricsReport) -> f64 {
        // This would implement a comprehensive scoring algorithm
        85.0 // Placeholder score
    }
}

impl Default for PerformanceMonitor {
    fn default() -> Self {
        Self::new()
    }
}

/// Result of a single performance measurement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceResult {
    pub operation_name: String,
    pub duration: Duration,
    pub memory_used: u64,
    pub nodes_processed: u64,
    pub edges_processed: u64,
    pub throughput: f64, // operations per second
}

impl PerformanceResult {
    pub fn empty() -> Self {
        Self {
            operation_name: "empty".to_string(),
            duration: Duration::ZERO,
            memory_used: 0,
            nodes_processed: 0,
            edges_processed: 0,
            throughput: 0.0,
        }
    }

    pub fn duration_millis(&self) -> f64 {
        self.duration.as_secs_f64() * 1000.0
    }

    pub fn memory_mb(&self) -> f64 {
        self.memory_used as f64 / (1024.0 * 1024.0)
    }
}

/// Performance result specific to layout operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayoutPerformanceResult {
    pub algorithm_name: String,
    pub duration: Duration,
    pub memory_used: u64,
    pub nodes_processed: u64,
    pub iterations: u32,
    pub converged: bool,
    pub energy: f64,
    pub nodes_per_second: f64,
    pub efficiency_score: f64,
}

impl LayoutPerformanceResult {
    pub fn empty() -> Self {
        Self {
            algorithm_name: "empty".to_string(),
            duration: Duration::ZERO,
            memory_used: 0,
            nodes_processed: 0,
            iterations: 0,
            converged: false,
            energy: 0.0,
            nodes_per_second: 0.0,
            efficiency_score: 0.0,
        }
    }
}

/// Suite of graph operation benchmarks
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphBenchmarkSuite {
    pub test_sizes: Vec<usize>,
    pub results: HashMap<usize, GraphOperationBenchmark>,
    pub max_nodes: usize,
}

/// Individual graph operation benchmark result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphOperationBenchmark {
    pub node_count: usize,
    pub edge_count: usize,
    pub operation_results: HashMap<String, PerformanceResult>,
}

/// Suite of layout algorithm benchmarks
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayoutBenchmarkSuite {
    pub node_count: usize,
    pub results: HashMap<String, LayoutPerformanceResult>,
}

/// Metrics for large mindmap handling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LargeMindmapMetrics {
    pub node_count: usize,
    pub creation_performance: Option<PerformanceResult>,
    pub search_performance: Option<PerformanceResult>,
    pub layout_performance: Option<LayoutPerformanceResult>,
    pub peak_memory_usage: u64,
}

impl LargeMindmapMetrics {
    pub fn new(node_count: usize) -> Self {
        Self {
            node_count,
            creation_performance: None,
            search_performance: None,
            layout_performance: None,
            peak_memory_usage: 0,
        }
    }

    pub fn empty() -> Self {
        Self::new(0)
    }

    pub fn peak_memory_mb(&self) -> f64 {
        self.peak_memory_usage as f64 / (1024.0 * 1024.0)
    }
}

/// Comprehensive performance report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceReport {
    pub timestamp: std::time::SystemTime,
    pub graph_metrics: GraphPerformanceMetrics,
    pub layout_metrics: LayoutPerformanceMetrics,
    pub memory_metrics: MemoryPerformanceMetrics,
    pub overall_performance: f64,
}

/// Graph-specific performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphPerformanceMetrics {
    pub total_operations: usize,
    pub average_operation_time: Duration,
    pub memory_usage: u64,
}

/// Layout-specific performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayoutPerformanceMetrics {
    pub total_layouts: usize,
    pub average_layout_time: Duration,
    pub average_iterations: u32,
    pub convergence_rate: f64,
}

/// Memory-specific performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryPerformanceMetrics {
    pub peak_usage: u64,
    pub total_allocated: u64,
    pub efficiency: f64,
}

// Extension trait for LayoutConfig to create size-appropriate configurations
pub trait LayoutConfigExt {
    fn default_for_size(node_count: usize) -> LayoutConfig;
}

impl LayoutConfigExt for LayoutConfig {
    fn default_for_size(node_count: usize) -> LayoutConfig {
        let canvas_size = match node_count {
            0..=50 => (800.0, 600.0),
            51..=200 => (1200.0, 900.0),
            201..=500 => (1600.0, 1200.0),
            _ => (2400.0, 1800.0),
        };

        let mut params = HashMap::new();
        params.insert("node_count".to_string(), node_count as f64);

        LayoutConfig {
            canvas_width: canvas_size.0,
            canvas_height: canvas_size.1,
            center: crate::types::Point { x: canvas_size.0 / 2.0, y: canvas_size.1 / 2.0 },
            animation_duration: 300,
            preserve_positions: false,
            min_distance: if node_count > 500 { 30.0 } else { 50.0 },
            parameters: params,
        }
    }
}

// Extension trait for LayoutResult to create empty results
pub trait LayoutResultExt {
    fn empty() -> LayoutResult;
}

impl LayoutResultExt for LayoutResult {
    fn empty() -> LayoutResult {
        LayoutResult {
            positions: HashMap::new(),
            bounds: crate::layout::LayoutBounds {
                min_x: 0.0,
                min_y: 0.0,
                max_x: 0.0,
                max_y: 0.0,
            },
            converged: false,
            iterations: 0,
            energy: 0.0,
        }
    }
}

/// Convenience macros for performance monitoring
#[macro_export]
macro_rules! monitor_graph_op {
    ($monitor:expr, $op_name:expr, $graph:expr, $operation:expr) => {{
        $monitor.monitor_graph_operation($op_name, $graph, || $operation)
    }};
}

#[macro_export]
macro_rules! monitor_layout_op {
    ($monitor:expr, $algorithm:expr, $graph:expr, $config:expr, $operation:expr) => {{
        $monitor.monitor_layout_operation($algorithm, $graph, $config, || $operation)
    }};
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::graph::Graph;

    #[test]
    fn test_performance_monitor_creation() {
        let monitor = PerformanceMonitor::new();
        assert!(monitor.is_enabled());
    }

    #[test]
    fn test_monitor_graph_operation() {
        let monitor = PerformanceMonitor::new();
        let graph = Graph::new();

        let (result, perf) = monitor.monitor_graph_operation("test_op", &graph, || {
            42
        });

        assert_eq!(result, 42);
        assert_eq!(perf.operation_name, "test_op");
        assert_eq!(perf.nodes_processed, 0);
        assert_eq!(perf.edges_processed, 0);
    }

    #[test]
    fn test_performance_result() {
        let result = PerformanceResult {
            operation_name: "test".to_string(),
            duration: Duration::from_millis(100),
            memory_used: 1024 * 1024, // 1MB
            nodes_processed: 50,
            edges_processed: 25,
            throughput: 750.0,
        };

        assert_eq!(result.duration_millis(), 100.0);
        assert_eq!(result.memory_mb(), 1.0);
    }

    #[test]
    fn test_layout_config_for_size() {
        let small_config = LayoutConfig::default_for_size(10);
        let large_config = LayoutConfig::default_for_size(1000);

        assert!(large_config.canvas_width > small_config.canvas_width);
        assert!(large_config.canvas_height > small_config.canvas_height);
        assert!(large_config.min_distance < small_config.min_distance);
    }

    #[test]
    fn test_large_mindmap_metrics() {
        let metrics = LargeMindmapMetrics::new(1500);
        assert_eq!(metrics.node_count, 1500);
        assert!(metrics.creation_performance.is_none());

        let empty_metrics = LargeMindmapMetrics::empty();
        assert_eq!(empty_metrics.node_count, 0);
    }

    #[test]
    fn test_monitor_disabled() {
        let mut monitor = PerformanceMonitor::new();
        monitor.set_enabled(false);

        let graph = Graph::new();
        let (result, perf) = monitor.monitor_graph_operation("test", &graph, || 42);

        assert_eq!(result, 42);
        assert_eq!(perf.operation_name, "empty");
    }

    #[test]
    fn test_benchmark_graph_operations() {
        let monitor = PerformanceMonitor::new();
        let benchmark = monitor.benchmark_graph_operations(100);

        assert_eq!(benchmark.max_nodes, 100);
        assert!(!benchmark.test_sizes.is_empty());
    }

    #[test]
    fn test_layout_performance_result() {
        let result = LayoutPerformanceResult {
            algorithm_name: "radial".to_string(),
            duration: Duration::from_millis(50),
            memory_used: 512 * 1024,
            nodes_processed: 100,
            iterations: 25,
            converged: true,
            energy: 0.5,
            nodes_per_second: 2000.0,
            efficiency_score: 85.0,
        };

        assert!(result.efficiency_score > 80.0);
        assert!(result.converged);
        assert_eq!(result.nodes_processed, 100);
    }
}