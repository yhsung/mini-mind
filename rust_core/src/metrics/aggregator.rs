//! Metrics aggregation utilities for data analysis and reporting
//!
//! This module provides aggregation functions for collecting, processing,
//! and analyzing metric data to generate meaningful insights.

use std::collections::HashMap;
use std::time::{Duration, SystemTime};
use serde::{Deserialize, Serialize};
use super::{MetricEntry, MetricId, MetricValue, MetricCategory, TimingStats, CategorySummary};

/// Metrics aggregator for processing and analyzing metric data
#[derive(Debug)]
pub struct MetricsAggregator {
    entries: Vec<MetricEntry>,
}

impl MetricsAggregator {
    /// Create a new metrics aggregator
    pub fn new() -> Self {
        Self {
            entries: Vec::new(),
        }
    }

    /// Add entries to the aggregator
    pub fn add_entries(&mut self, entries: Vec<MetricEntry>) {
        self.entries.extend(entries);
    }

    /// Add a single entry
    pub fn add_entry(&mut self, entry: MetricEntry) {
        self.entries.push(entry);
    }

    /// Get total number of entries
    pub fn total_count(&self) -> usize {
        self.entries.len()
    }

    /// Clear all entries
    pub fn clear(&mut self) {
        self.entries.clear();
    }

    /// Group entries by category
    pub fn by_category(&self) -> HashMap<MetricCategory, CategorySummary> {
        let mut categories: HashMap<MetricCategory, Vec<&MetricEntry>> = HashMap::new();

        // Group entries by category
        for entry in &self.entries {
            categories.entry(entry.id.category)
                .or_insert_with(Vec::new)
                .push(entry);
        }

        // Create summaries for each category
        categories.into_iter()
            .map(|(category, entries)| {
                (category, self.create_category_summary(entries))
            })
            .collect()
    }

    /// Group entries by metric ID
    pub fn by_metric(&self) -> HashMap<MetricId, Vec<&MetricEntry>> {
        let mut metrics: HashMap<MetricId, Vec<&MetricEntry>> = HashMap::new();

        for entry in &self.entries {
            metrics.entry(entry.id.clone())
                .or_insert_with(Vec::new)
                .push(entry);
        }

        metrics
    }

    /// Get entries within a time range
    pub fn time_range(&self, start: SystemTime, end: SystemTime) -> Vec<&MetricEntry> {
        self.entries.iter()
            .filter(|entry| entry.timestamp >= start && entry.timestamp <= end)
            .collect()
    }

    /// Get entries for the last N seconds
    pub fn last_seconds(&self, seconds: u64) -> Vec<&MetricEntry> {
        let cutoff = SystemTime::now()
            .checked_sub(Duration::from_secs(seconds))
            .unwrap_or(SystemTime::UNIX_EPOCH);

        self.entries.iter()
            .filter(|entry| entry.timestamp >= cutoff)
            .collect()
    }

    /// Get entries for the last N minutes
    pub fn last_minutes(&self, minutes: u64) -> Vec<&MetricEntry> {
        self.last_seconds(minutes * 60)
    }

    /// Calculate timing statistics for a specific metric
    pub fn timing_stats(&self, id: &MetricId) -> Option<TimingStats> {
        let durations: Vec<Duration> = self.entries.iter()
            .filter(|entry| &entry.id == id)
            .filter_map(|entry| entry.value.as_duration())
            .collect();

        if durations.is_empty() {
            None
        } else {
            Some(TimingStats::from_durations(&durations))
        }
    }

    /// Calculate count statistics for a specific metric
    pub fn count_stats(&self, id: &MetricId) -> CountStats {
        let counts: Vec<u64> = self.entries.iter()
            .filter(|entry| &entry.id == id)
            .filter_map(|entry| entry.value.as_count())
            .collect();

        CountStats::from_counts(&counts)
    }

    /// Calculate float statistics for a specific metric
    pub fn float_stats(&self, id: &MetricId) -> FloatStats {
        let values: Vec<f64> = self.entries.iter()
            .filter(|entry| &entry.id == id)
            .filter_map(|entry| entry.value.as_float())
            .collect();

        FloatStats::from_values(&values)
    }

    /// Get top metrics by count
    pub fn top_by_count(&self, limit: usize) -> Vec<(MetricId, usize)> {
        let mut metric_counts: HashMap<MetricId, usize> = HashMap::new();

        for entry in &self.entries {
            *metric_counts.entry(entry.id.clone()).or_insert(0) += 1;
        }

        let mut sorted: Vec<_> = metric_counts.into_iter().collect();
        sorted.sort_by(|a, b| b.1.cmp(&a.1));
        sorted.truncate(limit);
        sorted
    }

    /// Get slowest operations by average duration
    pub fn slowest_operations(&self, limit: usize) -> Vec<(MetricId, Duration)> {
        let mut operation_durations: HashMap<MetricId, Vec<Duration>> = HashMap::new();

        for entry in &self.entries {
            if let Some(duration) = entry.value.as_duration() {
                operation_durations.entry(entry.id.clone())
                    .or_insert_with(Vec::new)
                    .push(duration);
            }
        }

        let mut averages: Vec<_> = operation_durations.into_iter()
            .map(|(id, durations)| {
                let avg = durations.iter().sum::<Duration>() / durations.len() as u32;
                (id, avg)
            })
            .collect();

        averages.sort_by(|a, b| b.1.cmp(&a.1));
        averages.truncate(limit);
        averages
    }

    /// Get memory usage trends
    pub fn memory_trends(&self) -> Vec<MemoryTrend> {
        let mut memory_entries: Vec<&MetricEntry> = self.entries.iter()
            .filter(|entry| matches!(entry.value, MetricValue::Bytes(_)))
            .collect();

        memory_entries.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));

        memory_entries.windows(2)
            .map(|window| {
                let prev = window[0];
                let curr = window[1];
                let time_diff = curr.timestamp.duration_since(prev.timestamp)
                    .unwrap_or_default();

                let prev_bytes = prev.value.as_count().unwrap_or(0);
                let curr_bytes = curr.value.as_count().unwrap_or(0);

                MemoryTrend {
                    timestamp: curr.timestamp,
                    bytes: curr_bytes,
                    change: curr_bytes as i64 - prev_bytes as i64,
                    rate_per_second: if time_diff.as_secs_f64() > 0.0 {
                        (curr_bytes as i64 - prev_bytes as i64) as f64 / time_diff.as_secs_f64()
                    } else {
                        0.0
                    },
                }
            })
            .collect()
    }

    /// Calculate percentiles for numeric metrics
    pub fn percentiles(&self, id: &MetricId, percentiles: &[f64]) -> HashMap<String, f64> {
        let mut values: Vec<f64> = self.entries.iter()
            .filter(|entry| &entry.id == id)
            .filter_map(|entry| entry.value.as_float())
            .collect();

        if values.is_empty() {
            return HashMap::new();
        }

        values.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        percentiles.iter()
            .map(|&p| {
                let index = ((values.len() as f64 - 1.0) * p / 100.0) as usize;
                let key = format!("p{}", p as u32);
                (key, values[index])
            })
            .collect()
    }

    /// Generate an overall summary
    pub fn summary(&self) -> super::MetricsSummary {
        let categories = self.by_category();
        let top_operations = self.top_by_count(10);
        let slowest_ops = self.slowest_operations(10);

        let most_frequent_operations = top_operations.into_iter()
            .map(|(id, count)| (id.to_string(), count))
            .collect();

        let slowest_operations = slowest_ops.into_iter()
            .map(|(id, duration)| (id.to_string(), duration))
            .collect();

        let total_memory = self.entries.iter()
            .filter_map(|entry| match &entry.value {
                MetricValue::Bytes(b) => Some(*b),
                _ => None,
            })
            .sum::<u64>() as f64 / (1024.0 * 1024.0); // Convert to MB

        super::MetricsSummary {
            collection_enabled: true,
            total_categories: categories.len(),
            total_metrics: self.by_metric().len(),
            memory_tracked_mb: total_memory,
            most_frequent_operations,
            slowest_operations,
        }
    }

    /// Create a category summary from entries
    fn create_category_summary(&self, entries: Vec<&MetricEntry>) -> CategorySummary {
        let mut timing_metrics: HashMap<String, Vec<Duration>> = HashMap::new();
        let mut counter_metrics: HashMap<String, u64> = HashMap::new();
        let mut memory_metrics: HashMap<String, u64> = HashMap::new();

        for entry in &entries {
            let metric_name = entry.id.name.clone();

            match &entry.value {
                MetricValue::Duration(d) => {
                    timing_metrics.entry(metric_name)
                        .or_insert_with(Vec::new)
                        .push(*d);
                }
                MetricValue::Count(c) => {
                    let current = counter_metrics.entry(metric_name).or_insert(0);
                    *current = (*current).max(*c);
                }
                MetricValue::Bytes(b) => {
                    let current = memory_metrics.entry(metric_name).or_insert(0);
                    *current = (*current).max(*b);
                }
                _ => {}
            }
        }

        let timing_summaries = timing_metrics.into_iter()
            .map(|(name, durations)| (name, super::TimingSummary {
                count: durations.len(),
                total_duration: durations.iter().sum(),
                average_duration: if durations.is_empty() { Duration::ZERO } else { durations.iter().sum::<Duration>() / durations.len() as u32 },
                min_duration: durations.iter().min().copied().unwrap_or(Duration::ZERO),
                max_duration: durations.iter().max().copied().unwrap_or(Duration::ZERO),
            }))
            .collect();

        CategorySummary {
            entry_count: entries.len(),
            timing_metrics: timing_summaries,
            counter_metrics,
            memory_metrics,
        }
    }
}

impl Default for MetricsAggregator {
    fn default() -> Self {
        Self::new()
    }
}

/// Statistics for count-based metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CountStats {
    pub count: usize,
    pub sum: u64,
    pub average: f64,
    pub min: u64,
    pub max: u64,
    pub median: u64,
}

impl CountStats {
    /// Create count stats from a collection of counts
    pub fn from_counts(counts: &[u64]) -> Self {
        if counts.is_empty() {
            return Self::empty();
        }

        let mut sorted_counts = counts.to_vec();
        sorted_counts.sort();

        let count = counts.len();
        let sum = counts.iter().sum();
        let average = sum as f64 / count as f64;
        let min = sorted_counts[0];
        let max = sorted_counts[count - 1];

        let median = if count % 2 == 0 {
            let mid = count / 2;
            (sorted_counts[mid - 1] + sorted_counts[mid]) / 2
        } else {
            sorted_counts[count / 2]
        };

        Self {
            count,
            sum,
            average,
            min,
            max,
            median,
        }
    }

    /// Create empty count stats
    pub fn empty() -> Self {
        Self {
            count: 0,
            sum: 0,
            average: 0.0,
            min: 0,
            max: 0,
            median: 0,
        }
    }
}

/// Statistics for float-based metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FloatStats {
    pub count: usize,
    pub sum: f64,
    pub average: f64,
    pub min: f64,
    pub max: f64,
    pub median: f64,
    pub std_dev: f64,
}

impl FloatStats {
    /// Create float stats from a collection of values
    pub fn from_values(values: &[f64]) -> Self {
        if values.is_empty() {
            return Self::empty();
        }

        let mut sorted_values = values.to_vec();
        sorted_values.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        let count = values.len();
        let sum = values.iter().sum();
        let average = sum / count as f64;
        let min = sorted_values[0];
        let max = sorted_values[count - 1];

        let median = if count % 2 == 0 {
            let mid = count / 2;
            (sorted_values[mid - 1] + sorted_values[mid]) / 2.0
        } else {
            sorted_values[count / 2]
        };

        // Calculate standard deviation
        let variance: f64 = values.iter()
            .map(|&x| {
                let diff: f64 = x - average;
                diff.powi(2)
            })
            .sum::<f64>() / count as f64;
        let std_dev = variance.sqrt();

        Self {
            count,
            sum,
            average,
            min,
            max,
            median,
            std_dev,
        }
    }

    /// Create empty float stats
    pub fn empty() -> Self {
        Self {
            count: 0,
            sum: 0.0,
            average: 0.0,
            min: 0.0,
            max: 0.0,
            median: 0.0,
            std_dev: 0.0,
        }
    }
}

/// Memory usage trend data point
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryTrend {
    pub timestamp: SystemTime,
    pub bytes: u64,
    pub change: i64, // Bytes changed since previous measurement
    pub rate_per_second: f64, // Rate of change in bytes per second
}

impl MemoryTrend {
    /// Get memory usage in MB
    pub fn usage_mb(&self) -> f64 {
        self.bytes as f64 / (1024.0 * 1024.0)
    }

    /// Get change in MB
    pub fn change_mb(&self) -> f64 {
        self.change as f64 / (1024.0 * 1024.0)
    }

    /// Get rate in MB per second
    pub fn rate_mb_per_second(&self) -> f64 {
        self.rate_per_second / (1024.0 * 1024.0)
    }
}

/// Time-series data aggregator for trend analysis
#[derive(Debug)]
pub struct TimeSeriesAggregator {
    window_size: Duration,
    buckets: HashMap<u64, Vec<MetricEntry>>,
}

impl TimeSeriesAggregator {
    /// Create a new time series aggregator with the specified window size
    pub fn new(window_size: Duration) -> Self {
        Self {
            window_size,
            buckets: HashMap::new(),
        }
    }

    /// Add entries to the time series
    pub fn add_entries(&mut self, entries: Vec<MetricEntry>) {
        for entry in entries {
            let bucket_key = self.time_to_bucket(entry.timestamp);
            self.buckets.entry(bucket_key)
                .or_insert_with(Vec::new)
                .push(entry);
        }
    }

    /// Get aggregated data for each time bucket
    pub fn buckets(&self) -> Vec<TimeBucket> {
        let mut buckets: Vec<_> = self.buckets.iter()
            .map(|(&bucket_key, entries)| {
                let timestamp = self.bucket_to_time(bucket_key);
                let aggregator = {
                    let mut agg = MetricsAggregator::new();
                    agg.add_entries(entries.clone());
                    agg
                };

                TimeBucket {
                    timestamp,
                    entry_count: entries.len(),
                    categories: aggregator.by_category(),
                }
            })
            .collect();

        buckets.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
        buckets
    }

    /// Convert timestamp to bucket key
    fn time_to_bucket(&self, timestamp: SystemTime) -> u64 {
        let epoch_duration = timestamp.duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default();
        epoch_duration.as_secs() / self.window_size.as_secs()
    }

    /// Convert bucket key back to timestamp
    fn bucket_to_time(&self, bucket_key: u64) -> SystemTime {
        let seconds = bucket_key * self.window_size.as_secs();
        SystemTime::UNIX_EPOCH + Duration::from_secs(seconds)
    }
}

/// Time bucket containing aggregated metrics for a time window
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeBucket {
    pub timestamp: SystemTime,
    pub entry_count: usize,
    pub categories: HashMap<MetricCategory, CategorySummary>,
}

impl TimeBucket {
    /// Get timestamp as milliseconds since epoch
    pub fn timestamp_millis(&self) -> u64 {
        self.timestamp
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::metrics::MetricCategory;
    use std::time::Duration;

    fn create_test_entries() -> Vec<MetricEntry> {
        vec![
            MetricEntry::new(
                MetricId::new(MetricCategory::Graph, "node_creation"),
                MetricValue::Duration(Duration::from_millis(100)),
            ),
            MetricEntry::new(
                MetricId::new(MetricCategory::Graph, "node_creation"),
                MetricValue::Duration(Duration::from_millis(150)),
            ),
            MetricEntry::new(
                MetricId::new(MetricCategory::Layout, "radial_layout"),
                MetricValue::Duration(Duration::from_millis(500)),
            ),
            MetricEntry::new(
                MetricId::new(MetricCategory::Memory, "allocation"),
                MetricValue::Bytes(1024),
            ),
        ]
    }

    #[test]
    fn test_aggregator_basic() {
        let mut aggregator = MetricsAggregator::new();
        let entries = create_test_entries();

        aggregator.add_entries(entries);
        assert_eq!(aggregator.total_count(), 4);

        let by_category = aggregator.by_category();
        assert_eq!(by_category.len(), 3); // Graph, Layout, Memory
    }

    #[test]
    fn test_timing_stats() {
        let mut aggregator = MetricsAggregator::new();
        aggregator.add_entries(create_test_entries());

        let id = MetricId::new(MetricCategory::Graph, "node_creation");
        let stats = aggregator.timing_stats(&id).unwrap();

        assert_eq!(stats.count, 2);
        assert_eq!(stats.min, Duration::from_millis(100));
        assert_eq!(stats.max, Duration::from_millis(150));
    }

    #[test]
    fn test_count_stats() {
        let counts = vec![1, 2, 3, 4, 5];
        let stats = CountStats::from_counts(&counts);

        assert_eq!(stats.count, 5);
        assert_eq!(stats.sum, 15);
        assert_eq!(stats.average, 3.0);
        assert_eq!(stats.min, 1);
        assert_eq!(stats.max, 5);
        assert_eq!(stats.median, 3);
    }

    #[test]
    fn test_float_stats() {
        let values = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let stats = FloatStats::from_values(&values);

        assert_eq!(stats.count, 5);
        assert_eq!(stats.sum, 15.0);
        assert_eq!(stats.average, 3.0);
        assert_eq!(stats.min, 1.0);
        assert_eq!(stats.max, 5.0);
        assert_eq!(stats.median, 3.0);
        assert!(stats.std_dev > 0.0);
    }

    #[test]
    fn test_top_by_count() {
        let mut aggregator = MetricsAggregator::new();
        aggregator.add_entries(create_test_entries());

        let top = aggregator.top_by_count(5);
        assert!(!top.is_empty());

        // The "node_creation" metric appears twice, so it should be first
        assert_eq!(top[0].1, 2);
    }

    #[test]
    fn test_time_series_aggregator() {
        let mut ts_aggregator = TimeSeriesAggregator::new(Duration::from_secs(60));
        ts_aggregator.add_entries(create_test_entries());

        let buckets = ts_aggregator.buckets();
        assert!(!buckets.is_empty());
    }

    #[test]
    fn test_percentiles() {
        let mut aggregator = MetricsAggregator::new();
        let entries = (1..=100).map(|i| {
            MetricEntry::new(
                MetricId::new(MetricCategory::Application, "test_metric"),
                MetricValue::Float(i as f64),
            )
        }).collect();

        aggregator.add_entries(entries);

        let id = MetricId::new(MetricCategory::Application, "test_metric");
        let percentiles = aggregator.percentiles(&id, &[50.0, 90.0, 95.0, 99.0]);

        assert!(percentiles.contains_key("p50"));
        assert!(percentiles.contains_key("p90"));
        assert!(percentiles.contains_key("p95"));
        assert!(percentiles.contains_key("p99"));
    }
}