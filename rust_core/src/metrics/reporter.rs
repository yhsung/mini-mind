//! Metrics reporting utilities for output formatting and export
//!
//! This module provides various reporting formats for metrics data including
//! console output, JSON export, CSV files, and dashboard-style summaries.

use std::collections::HashMap;
use std::io::{self, Write};
use std::time::{Duration, UNIX_EPOCH};
use serde::{Deserialize, Serialize};
use crate::types::MindmapResult;
use super::{
    MetricsReport, MetricCategory, CategorySummary
};

/// Reporter for generating formatted metrics output
#[derive(Debug)]
pub struct MetricsReporter {
    config: ReporterConfig,
}

impl MetricsReporter {
    /// Create a new metrics reporter
    pub fn new(config: ReporterConfig) -> Self {
        Self { config }
    }

    /// Create a reporter with default configuration
    pub fn default() -> Self {
        Self::new(ReporterConfig::default())
    }

    /// Generate a console-friendly report
    pub fn console_report(&self, report: &MetricsReport) -> String {
        let mut output = String::new();

        // Header
        output.push_str(&format!("=== Mindmap Metrics Report ===\n"));
        output.push_str(&format!("Generated: {:?}\n", report.timestamp));
        output.push_str(&format!("Total Entries: {}\n\n", report.total_entries));

        // Summary
        output.push_str("SUMMARY:\n");
        output.push_str(&format!("  Collection Enabled: {}\n", report.summary.collection_enabled));
        output.push_str(&format!("  Categories: {}\n", report.summary.total_categories));
        output.push_str(&format!("  Metrics: {}\n", report.summary.total_metrics));
        output.push_str(&format!("  Memory Tracked: {:.2} MB\n\n", report.summary.memory_tracked_mb));

        // Most frequent operations
        if !report.summary.most_frequent_operations.is_empty() {
            output.push_str("MOST FREQUENT OPERATIONS:\n");
            for (op, count) in &report.summary.most_frequent_operations {
                output.push_str(&format!("  {} - {} times\n", op, count));
            }
            output.push('\n');
        }

        // Slowest operations
        if !report.summary.slowest_operations.is_empty() {
            output.push_str("SLOWEST OPERATIONS:\n");
            for (op, duration) in &report.summary.slowest_operations {
                output.push_str(&format!("  {} - {:.2}ms\n", op, duration.as_secs_f64() * 1000.0));
            }
            output.push('\n');
        }

        // Category details
        output.push_str("CATEGORY BREAKDOWN:\n");
        for (category, summary) in &report.categories {
            output.push_str(&self.format_category_summary(category, summary));
        }

        // Memory usage
        if !report.memory_usage.is_empty() {
            output.push_str("MEMORY USAGE:\n");
            let mut memory_items: Vec<_> = report.memory_usage.iter().collect();
            memory_items.sort_by(|a, b| b.1.cmp(a.1)); // Sort by usage descending

            for (id, bytes) in memory_items.iter().take(10) {
                let mb = **bytes as f64 / (1024.0 * 1024.0);
                output.push_str(&format!("  {} - {:.2} MB\n", id, mb));
            }
        }

        output
    }

    /// Generate a JSON report
    pub fn json_report(&self, report: &MetricsReport) -> MindmapResult<String> {
        let json_report = JsonReport::from_metrics_report(report);
        serde_json::to_string_pretty(&json_report)
            .map_err(|e| format!("Failed to serialize JSON report: {}", e).into())
    }

    /// Generate a CSV report for timing metrics
    pub fn csv_timing_report(&self, report: &MetricsReport) -> String {
        let mut output = String::new();
        output.push_str("Category,Metric,Count,Average(ms),Min(ms),Max(ms),Total(ms)\n");

        for (category, summary) in &report.categories {
            for (metric_name, timing) in &summary.timing_metrics {
                output.push_str(&format!(
                    "{:?},{},{},{:.2},{:.2},{:.2},{:.2}\n",
                    category,
                    metric_name,
                    timing.count,
                    timing.average_duration.as_secs_f64() * 1000.0,
                    timing.min_duration.as_secs_f64() * 1000.0,
                    timing.max_duration.as_secs_f64() * 1000.0,
                    timing.total_duration.as_secs_f64() * 1000.0,
                ));
            }
        }

        output
    }

    /// Generate a dashboard-style HTML report
    pub fn html_report(&self, report: &MetricsReport) -> String {
        let mut html = String::new();

        html.push_str("<!DOCTYPE html>\n<html>\n<head>\n");
        html.push_str("<title>Mindmap Metrics Dashboard</title>\n");
        html.push_str("<style>\n");
        html.push_str(DASHBOARD_CSS);
        html.push_str("</style>\n");
        html.push_str("</head>\n<body>\n");

        // Header
        html.push_str("<div class='header'>\n");
        html.push_str("<h1>Mindmap Metrics Dashboard</h1>\n");
        html.push_str(&format!("<p>Generated: {:?}</p>\n", report.timestamp));
        html.push_str("</div>\n");

        // Summary cards
        html.push_str("<div class='summary-cards'>\n");
        html.push_str(&format!(
            "<div class='card'><h3>Total Entries</h3><p class='metric'>{}</p></div>\n",
            report.total_entries
        ));
        html.push_str(&format!(
            "<div class='card'><h3>Categories</h3><p class='metric'>{}</p></div>\n",
            report.summary.total_categories
        ));
        html.push_str(&format!(
            "<div class='card'><h3>Memory Tracked</h3><p class='metric'>{:.2} MB</p></div>\n",
            report.summary.memory_tracked_mb
        ));
        html.push_str("</div>\n");

        // Category tables
        for (category, summary) in &report.categories {
            html.push_str(&self.format_category_html(category, summary));
        }

        html.push_str("</body>\n</html>");
        html
    }

    /// Write report to a writer
    pub fn write_console_report<W: Write>(&self, report: &MetricsReport, writer: &mut W) -> io::Result<()> {
        let content = self.console_report(report);
        writer.write_all(content.as_bytes())
    }

    /// Format category summary for console output
    fn format_category_summary(&self, category: &MetricCategory, summary: &CategorySummary) -> String {
        let mut output = String::new();

        output.push_str(&format!("{:?} ({} entries):\n", category, summary.entry_count));

        // Timing metrics
        if !summary.timing_metrics.is_empty() {
            output.push_str("  Timing:\n");
            for (name, timing) in &summary.timing_metrics {
                output.push_str(&format!(
                    "    {} - avg: {:.2}ms, count: {}, total: {:.2}ms\n",
                    name,
                    timing.average_duration.as_secs_f64() * 1000.0,
                    timing.count,
                    timing.total_duration.as_secs_f64() * 1000.0,
                ));
            }
        }

        // Counter metrics
        if !summary.counter_metrics.is_empty() {
            output.push_str("  Counters:\n");
            for (name, count) in &summary.counter_metrics {
                output.push_str(&format!("    {} - {}\n", name, count));
            }
        }

        // Memory metrics
        if !summary.memory_metrics.is_empty() {
            output.push_str("  Memory:\n");
            for (name, bytes) in &summary.memory_metrics {
                let mb = *bytes as f64 / (1024.0 * 1024.0);
                output.push_str(&format!("    {} - {:.2} MB\n", name, mb));
            }
        }

        output.push('\n');
        output
    }

    /// Format category summary for HTML output
    fn format_category_html(&self, category: &MetricCategory, summary: &CategorySummary) -> String {
        let mut html = String::new();

        html.push_str(&format!("<div class='category'>\n<h2>{:?}</h2>\n", category));
        html.push_str(&format!("<p>{} entries</p>\n", summary.entry_count));

        if !summary.timing_metrics.is_empty() {
            html.push_str("<h3>Timing Metrics</h3>\n<table>\n");
            html.push_str("<tr><th>Metric</th><th>Count</th><th>Avg (ms)</th><th>Min (ms)</th><th>Max (ms)</th></tr>\n");

            for (name, timing) in &summary.timing_metrics {
                html.push_str(&format!(
                    "<tr><td>{}</td><td>{}</td><td>{:.2}</td><td>{:.2}</td><td>{:.2}</td></tr>\n",
                    name,
                    timing.count,
                    timing.average_duration.as_secs_f64() * 1000.0,
                    timing.min_duration.as_secs_f64() * 1000.0,
                    timing.max_duration.as_secs_f64() * 1000.0,
                ));
            }
            html.push_str("</table>\n");
        }

        html.push_str("</div>\n");
        html
    }
}

impl Default for MetricsReporter {
    fn default() -> Self {
        Self::new(ReporterConfig::default())
    }
}

/// Configuration for metrics reporting
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReporterConfig {
    /// Include detailed timing breakdowns
    pub include_timing_details: bool,
    /// Include memory usage details
    pub include_memory_details: bool,
    /// Maximum number of top operations to show
    pub max_top_operations: usize,
    /// Time format for timestamps
    pub time_format: TimeFormat,
    /// Include percentile calculations
    pub include_percentiles: bool,
}

impl Default for ReporterConfig {
    fn default() -> Self {
        Self {
            include_timing_details: true,
            include_memory_details: true,
            max_top_operations: 10,
            time_format: TimeFormat::RFC3339,
            include_percentiles: false,
        }
    }
}

/// Time format options for reports
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum TimeFormat {
    RFC3339,
    Unix,
    Relative,
}

/// JSON-serializable metrics report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonReport {
    pub timestamp: u64,
    pub total_entries: usize,
    pub summary: JsonSummary,
    pub categories: HashMap<String, JsonCategorySummary>,
    pub memory_usage: HashMap<String, u64>,
}

impl JsonReport {
    /// Convert from MetricsReport
    pub fn from_metrics_report(report: &MetricsReport) -> Self {
        let timestamp = report.timestamp
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        let categories = report.categories.iter()
            .map(|(category, summary)| {
                (format!("{:?}", category), JsonCategorySummary::from_category_summary(summary))
            })
            .collect();

        let memory_usage = report.memory_usage.iter()
            .map(|(id, bytes)| (id.to_string(), *bytes))
            .collect();

        Self {
            timestamp,
            total_entries: report.total_entries,
            summary: JsonSummary::from_metrics_summary(&report.summary),
            categories,
            memory_usage,
        }
    }
}

/// JSON-serializable summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonSummary {
    pub collection_enabled: bool,
    pub total_categories: usize,
    pub total_metrics: usize,
    pub memory_tracked_mb: f64,
    pub most_frequent_operations: Vec<(String, usize)>,
    pub slowest_operations: Vec<(String, f64)>, // Duration in milliseconds
}

impl JsonSummary {
    fn from_metrics_summary(summary: &super::MetricsSummary) -> Self {
        let slowest_operations = summary.slowest_operations.iter()
            .map(|(name, duration)| (name.clone(), duration.as_secs_f64() * 1000.0))
            .collect();

        Self {
            collection_enabled: summary.collection_enabled,
            total_categories: summary.total_categories,
            total_metrics: summary.total_metrics,
            memory_tracked_mb: summary.memory_tracked_mb,
            most_frequent_operations: summary.most_frequent_operations.clone(),
            slowest_operations,
        }
    }
}

/// JSON-serializable category summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonCategorySummary {
    pub entry_count: usize,
    pub timing_metrics: HashMap<String, JsonTimingStats>,
    pub counter_metrics: HashMap<String, u64>,
    pub memory_metrics: HashMap<String, u64>,
}

impl JsonCategorySummary {
    fn from_category_summary(summary: &CategorySummary) -> Self {
        let timing_metrics = summary.timing_metrics.iter()
            .map(|(name, timing)| (name.clone(), JsonTimingStats::from_timing_summary(timing)))
            .collect();

        Self {
            entry_count: summary.entry_count,
            timing_metrics,
            counter_metrics: summary.counter_metrics.clone(),
            memory_metrics: summary.memory_metrics.clone(),
        }
    }
}

/// JSON-serializable timing statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonTimingStats {
    pub count: usize,
    pub total_ms: f64,
    pub average_ms: f64,
    pub min_ms: f64,
    pub max_ms: f64,
    pub median_ms: f64,
    pub percentile_95_ms: f64,
    pub percentile_99_ms: f64,
}

impl JsonTimingStats {
    fn from_timing_summary(timing: &super::TimingSummary) -> Self {
        Self {
            count: timing.count,
            total_ms: timing.total_duration.as_secs_f64() * 1000.0,
            average_ms: timing.average_duration.as_secs_f64() * 1000.0,
            min_ms: timing.min_duration.as_secs_f64() * 1000.0,
            max_ms: timing.max_duration.as_secs_f64() * 1000.0,
            median_ms: timing.average_duration.as_secs_f64() * 1000.0, // Use average as proxy for median
            percentile_95_ms: timing.max_duration.as_secs_f64() * 1000.0, // Use max as proxy
            percentile_99_ms: timing.max_duration.as_secs_f64() * 1000.0, // Use max as proxy
        }
    }
}

/// Live metrics dashboard for real-time monitoring
pub struct LiveDashboard {
    config: DashboardConfig,
    last_report: Option<MetricsReport>,
}

impl LiveDashboard {
    /// Create a new live dashboard
    pub fn new(config: DashboardConfig) -> Self {
        Self {
            config,
            last_report: None,
        }
    }

    /// Update the dashboard with new metrics
    pub fn update(&mut self, report: MetricsReport) {
        self.last_report = Some(report);
        if self.config.auto_display {
            self.display();
        }
    }

    /// Display the current dashboard
    pub fn display(&self) {
        if let Some(report) = &self.last_report {
            let reporter = MetricsReporter::new(ReporterConfig::default());

            match self.config.format {
                DashboardFormat::Console => {
                    println!("{}", reporter.console_report(report));
                }
                DashboardFormat::Json => {
                    if let Ok(json) = reporter.json_report(report) {
                        println!("{}", json);
                    }
                }
            }
        }
    }

    /// Get the current report
    pub fn current_report(&self) -> Option<&MetricsReport> {
        self.last_report.as_ref()
    }
}

/// Configuration for live dashboard
#[derive(Debug, Clone)]
pub struct DashboardConfig {
    pub format: DashboardFormat,
    pub auto_display: bool,
    pub refresh_interval: Duration,
}

impl Default for DashboardConfig {
    fn default() -> Self {
        Self {
            format: DashboardFormat::Console,
            auto_display: false,
            refresh_interval: Duration::from_secs(5),
        }
    }
}

/// Dashboard display format
#[derive(Debug, Clone, Copy)]
pub enum DashboardFormat {
    Console,
    Json,
}

// CSS styles for HTML dashboard (inline for simplicity)
const DASHBOARD_CSS: &str = r#"
body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #f5f5f5;
}

.header {
    background-color: #2c3e50;
    color: white;
    padding: 20px;
    border-radius: 8px;
    margin-bottom: 20px;
}

.summary-cards {
    display: flex;
    gap: 20px;
    margin-bottom: 30px;
    flex-wrap: wrap;
}

.card {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    min-width: 200px;
}

.card h3 {
    margin: 0 0 10px 0;
    color: #333;
}

.metric {
    font-size: 24px;
    font-weight: bold;
    color: #2c3e50;
    margin: 0;
}

.category {
    background: white;
    margin-bottom: 20px;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
}

th, td {
    text-align: left;
    padding: 8px 12px;
    border-bottom: 1px solid #ddd;
}

th {
    background-color: #f8f9fa;
    font-weight: 600;
}

tr:hover {
    background-color: #f8f9fa;
}
"#;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::metrics::{MetricCategory, MetricsRegistry};
    use std::time::Duration;

    fn create_test_report() -> MetricsReport {
        let registry = MetricsRegistry::new();
        registry.report()
    }

    #[test]
    fn test_console_report() {
        let report = create_test_report();
        let reporter = MetricsReporter::default();
        let output = reporter.console_report(&report);

        assert!(output.contains("Mindmap Metrics Report"));
        assert!(output.contains("Total Entries"));
    }

    #[test]
    fn test_json_report() {
        let report = create_test_report();
        let reporter = MetricsReporter::default();
        let json_result = reporter.json_report(&report);

        assert!(json_result.is_ok());
        let json = json_result.unwrap();
        assert!(json.contains("timestamp"));
        assert!(json.contains("total_entries"));
    }

    #[test]
    fn test_csv_timing_report() {
        let report = create_test_report();
        let reporter = MetricsReporter::default();
        let csv = reporter.csv_timing_report(&report);

        assert!(csv.contains("Category,Metric,Count"));
    }

    #[test]
    fn test_html_report() {
        let report = create_test_report();
        let reporter = MetricsReporter::default();
        let html = reporter.html_report(&report);

        assert!(html.contains("<!DOCTYPE html>"));
        assert!(html.contains("Mindmap Metrics Dashboard"));
        assert!(html.contains("</html>"));
    }

    #[test]
    fn test_json_report_conversion() {
        let report = create_test_report();
        let json_report = JsonReport::from_metrics_report(&report);

        assert_eq!(json_report.total_entries, report.total_entries);
    }

    #[test]
    fn test_live_dashboard() {
        let mut dashboard = LiveDashboard::new(DashboardConfig::default());
        let report = create_test_report();

        dashboard.update(report);
        assert!(dashboard.current_report().is_some());
    }

    #[test]
    fn test_reporter_config() {
        let config = ReporterConfig {
            include_timing_details: false,
            include_memory_details: true,
            max_top_operations: 5,
            time_format: TimeFormat::Unix,
            include_percentiles: true,
        };

        let reporter = MetricsReporter::new(config);
        // Test that config is properly set
        assert!(!reporter.config.include_timing_details);
        assert!(reporter.config.include_memory_details);
        assert_eq!(reporter.config.max_top_operations, 5);
    }
}