//! Counter utilities for tracking operation counts and rates
//!
//! This module provides counters for tracking the frequency of operations,
//! rates of events, and cumulative metrics over time.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
//
use std::time::{SystemTime, Duration, Instant};
use serde::{Deserialize, Serialize};
use super::{MetricEntry, MetricId, MetricValue};

/// Thread-safe counter for tracking operation counts
#[derive(Debug)]
pub struct Counter {
    id: MetricId,
    value: AtomicU64,
    created_at: SystemTime,
}

impl Counter {
    /// Create a new counter
    pub fn new(id: MetricId) -> Self {
        Self {
            id,
            value: AtomicU64::new(0),
            created_at: SystemTime::now(),
        }
    }

    /// Increment the counter by 1
    pub fn increment(&self) {
        self.add(1);
    }

    /// Decrement the counter by 1
    pub fn decrement(&self) {
        self.subtract(1);
    }

    /// Add a value to the counter
    pub fn add(&self, value: u64) {
        let old_value = self.value.fetch_add(value, Ordering::Relaxed);

        // Record the metric
        let registry = super::registry();
        let entry = MetricEntry::new(self.id.clone(), MetricValue::Count(old_value + value));
        registry.record(entry);
    }

    /// Subtract a value from the counter
    pub fn subtract(&self, value: u64) {
        let old_value = self.value.fetch_sub(value, Ordering::Relaxed);

        // Record the metric (ensure we don't go below 0)
        let new_value = if old_value >= value { old_value - value } else { 0 };
        let registry = super::registry();
        let entry = MetricEntry::new(self.id.clone(), MetricValue::Count(new_value));
        registry.record(entry);
    }

    /// Set the counter to a specific value
    pub fn set(&self, value: u64) {
        self.value.store(value, Ordering::Relaxed);

        // Record the metric
        let registry = super::registry();
        let entry = MetricEntry::new(self.id.clone(), MetricValue::Count(value));
        registry.record(entry);
    }

    /// Get the current value
    pub fn get(&self) -> u64 {
        self.value.load(Ordering::Relaxed)
    }

    /// Reset the counter to 0
    pub fn reset(&self) {
        self.set(0);
    }

    /// Get the counter ID
    pub fn id(&self) -> &MetricId {
        &self.id
    }

    /// Get the time when this counter was created
    pub fn created_at(&self) -> SystemTime {
        self.created_at
    }

    /// Get the rate of change per second since creation
    pub fn rate_per_second(&self) -> f64 {
        let elapsed = self.created_at.elapsed().unwrap_or_default();
        if elapsed.as_secs() > 0 {
            self.get() as f64 / elapsed.as_secs_f64()
        } else {
            0.0
        }
    }
}

/// Registry for managing multiple counters for the same metric
#[derive(Debug)]
pub struct CounterRegistry {
    id: MetricId,
    counter: Arc<Counter>,
    snapshots: Arc<Mutex<Vec<CounterSnapshot>>>,
}

impl CounterRegistry {
    /// Create a new counter registry
    pub fn new(id: MetricId) -> Self {
        Self {
            counter: Arc::new(Counter::new(id.clone())),
            id,
            snapshots: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Get the main counter
    pub fn get_counter(&self) -> Arc<Counter> {
        self.counter.clone()
    }

    /// Take a snapshot of the current counter value
    pub fn snapshot(&self) -> CounterSnapshot {
        let snapshot = CounterSnapshot {
            timestamp: SystemTime::now(),
            value: self.counter.get(),
        };

        if let Ok(mut snapshots) = self.snapshots.lock() {
            snapshots.push(snapshot.clone());

            // Keep only the last 1000 snapshots to prevent memory leaks
            if snapshots.len() > 1000 {
                let len = snapshots.len();
                snapshots.drain(0..len - 1000);
            }
        }

        snapshot
    }

    /// Get all snapshots
    pub fn snapshots(&self) -> Vec<CounterSnapshot> {
        if let Ok(snapshots) = self.snapshots.lock() {
            snapshots.clone()
        } else {
            Vec::new()
        }
    }

    /// Get the rate of change between two snapshots
    pub fn rate_between_snapshots(&self, from: &CounterSnapshot, to: &CounterSnapshot) -> f64 {
        let time_diff = to.timestamp.duration_since(from.timestamp)
            .unwrap_or_default();

        if time_diff.as_secs_f64() > 0.0 {
            let value_diff = if to.value >= from.value {
                to.value - from.value
            } else {
                0 // Handle counter resets
            };
            value_diff as f64 / time_diff.as_secs_f64()
        } else {
            0.0
        }
    }

    /// Get statistics for the counter
    pub fn stats(&self) -> CounterStats {
        let snapshots = self.snapshots();
        CounterStats::from_snapshots(&snapshots, self.counter.get())
    }
}

/// A snapshot of a counter at a specific point in time
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CounterSnapshot {
    pub timestamp: SystemTime,
    pub value: u64,
}

impl CounterSnapshot {
    /// Get timestamp as milliseconds since epoch
    pub fn timestamp_millis(&self) -> u64 {
        self.timestamp
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64
    }
}

/// Statistical summary of counter measurements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CounterStats {
    pub current_value: u64,
    pub total_snapshots: usize,
    pub min_value: u64,
    pub max_value: u64,
    pub average_value: f64,
    pub rate_per_second: f64,
    pub peak_rate_per_second: f64,
}

impl CounterStats {
    /// Create counter stats from snapshots
    pub fn from_snapshots(snapshots: &[CounterSnapshot], current_value: u64) -> Self {
        if snapshots.is_empty() {
            return Self::empty(current_value);
        }

        let values: Vec<u64> = snapshots.iter().map(|s| s.value).collect();
        let min_value = values.iter().min().copied().unwrap_or(0);
        let max_value = values.iter().max().copied().unwrap_or(0);
        let average_value = if !values.is_empty() {
            values.iter().sum::<u64>() as f64 / values.len() as f64
        } else {
            0.0
        };

        // Calculate overall rate
        let rate_per_second = if snapshots.len() >= 2 {
            let first = &snapshots[0];
            let last = &snapshots[snapshots.len() - 1];
            let time_diff = last.timestamp.duration_since(first.timestamp)
                .unwrap_or_default();

            if time_diff.as_secs_f64() > 0.0 {
                let value_diff = if last.value >= first.value {
                    last.value - first.value
                } else {
                    0
                };
                value_diff as f64 / time_diff.as_secs_f64()
            } else {
                0.0
            }
        } else {
            0.0
        };

        // Calculate peak rate (maximum rate between consecutive snapshots)
        let peak_rate_per_second = if snapshots.len() >= 2 {
            let mut max_rate: f64 = 0.0;
            for i in 1..snapshots.len() {
                let prev = &snapshots[i - 1];
                let curr = &snapshots[i];
                let time_diff = curr.timestamp.duration_since(prev.timestamp)
                    .unwrap_or_default();

                if time_diff.as_secs_f64() > 0.0 {
                    let value_diff = if curr.value >= prev.value {
                        curr.value - prev.value
                    } else {
                        0
                    };
                    let rate = value_diff as f64 / time_diff.as_secs_f64();
                    max_rate = max_rate.max(rate);
                }
            }
            max_rate
        } else {
            0.0
        };

        Self {
            current_value,
            total_snapshots: snapshots.len(),
            min_value,
            max_value,
            average_value,
            rate_per_second,
            peak_rate_per_second,
        }
    }

    /// Create empty counter stats
    pub fn empty(current_value: u64) -> Self {
        Self {
            current_value,
            total_snapshots: 0,
            min_value: current_value,
            max_value: current_value,
            average_value: current_value as f64,
            rate_per_second: 0.0,
            peak_rate_per_second: 0.0,
        }
    }
}

/// Rate limiter using token bucket algorithm
#[derive(Debug)]
pub struct RateLimiter {
    tokens: AtomicU64,
    max_tokens: u64,
    refill_rate: u64, // tokens per second
    last_refill: Mutex<Instant>,
}

impl RateLimiter {
    /// Create a new rate limiter
    pub fn new(max_tokens: u64, refill_rate: u64) -> Self {
        Self {
            tokens: AtomicU64::new(max_tokens),
            max_tokens,
            refill_rate,
            last_refill: Mutex::new(Instant::now()),
        }
    }

    /// Try to consume tokens
    pub fn try_consume(&self, tokens: u64) -> bool {
        self.refill();

        let current_tokens = self.tokens.load(Ordering::Relaxed);
        if current_tokens >= tokens {
            self.tokens.fetch_sub(tokens, Ordering::Relaxed);
            true
        } else {
            false
        }
    }

    /// Wait until tokens are available (blocking)
    pub fn consume(&self, tokens: u64) {
        while !self.try_consume(tokens) {
            std::thread::sleep(Duration::from_millis(10));
        }
    }

    /// Refill tokens based on elapsed time
    fn refill(&self) {
        if let Ok(mut last_refill) = self.last_refill.lock() {
            let now = Instant::now();
            let elapsed = now.duration_since(*last_refill);
            *last_refill = now;

            let tokens_to_add = (elapsed.as_secs_f64() * self.refill_rate as f64) as u64;
            if tokens_to_add > 0 {
                let current = self.tokens.load(Ordering::Relaxed);
                let new_value = (current + tokens_to_add).min(self.max_tokens);
                self.tokens.store(new_value, Ordering::Relaxed);
            }
        }
    }

    /// Get current token count
    pub fn available_tokens(&self) -> u64 {
        self.refill();
        self.tokens.load(Ordering::Relaxed)
    }
}

/// Moving average calculator for smoothing counter values
#[derive(Debug)]
pub struct MovingAverage {
    window_size: usize,
    values: Mutex<Vec<f64>>,
    sum: AtomicU64, // Using atomic for thread safety, storing as u64 bits
}

impl MovingAverage {
    /// Create a new moving average calculator
    pub fn new(window_size: usize) -> Self {
        Self {
            window_size,
            values: Mutex::new(Vec::new()),
            sum: AtomicU64::new(0),
        }
    }

    /// Add a new value and get the updated average
    pub fn add(&self, value: f64) -> f64 {
        if let Ok(mut values) = self.values.lock() {
            values.push(value);

            if values.len() > self.window_size {
                values.remove(0);
            }

            let sum: f64 = values.iter().sum();
            let avg = sum / values.len() as f64;

            // Store sum as bits in atomic
            self.sum.store(sum.to_bits(), Ordering::Relaxed);

            avg
        } else {
            value
        }
    }

    /// Get the current average
    pub fn average(&self) -> f64 {
        if let Ok(values) = self.values.lock() {
            if values.is_empty() {
                0.0
            } else {
                values.iter().sum::<f64>() / values.len() as f64
            }
        } else {
            0.0
        }
    }

    /// Get the number of values in the window
    pub fn count(&self) -> usize {
        if let Ok(values) = self.values.lock() {
            values.len()
        } else {
            0
        }
    }

    /// Clear all values
    pub fn clear(&self) {
        if let Ok(mut values) = self.values.lock() {
            values.clear();
            self.sum.store(0, Ordering::Relaxed);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::metrics::MetricCategory;
    use std::thread;

    #[test]
    fn test_counter_basic_operations() {
        let id = MetricId::new(MetricCategory::Graph, "test_counter");
        let counter = Counter::new(id);

        assert_eq!(counter.get(), 0);

        counter.increment();
        assert_eq!(counter.get(), 1);

        counter.add(5);
        assert_eq!(counter.get(), 6);

        counter.decrement();
        assert_eq!(counter.get(), 5);

        counter.set(10);
        assert_eq!(counter.get(), 10);

        counter.reset();
        assert_eq!(counter.get(), 0);
    }

    #[test]
    fn test_counter_thread_safety() {
        let id = MetricId::new(MetricCategory::Application, "thread_test");
        let counter = Arc::new(Counter::new(id));

        let handles: Vec<_> = (0..10)
            .map(|_| {
                let counter = counter.clone();
                thread::spawn(move || {
                    for _ in 0..100 {
                        counter.increment();
                    }
                })
            })
            .collect();

        for handle in handles {
            handle.join().unwrap();
        }

        assert_eq!(counter.get(), 1000);
    }

    #[test]
    fn test_counter_registry() {
        let id = MetricId::new(MetricCategory::Graph, "registry_test");
        let registry = CounterRegistry::new(id);

        let counter = registry.get_counter();
        counter.increment();

        let snapshot = registry.snapshot();
        assert_eq!(snapshot.value, 1);

        counter.add(5);
        let snapshot2 = registry.snapshot();
        assert_eq!(snapshot2.value, 6);

        let snapshots = registry.snapshots();
        assert_eq!(snapshots.len(), 2);
    }

    #[test]
    fn test_rate_limiter() {
        let limiter = RateLimiter::new(10, 5); // 10 tokens, refill 5 per second

        // Should be able to consume initial tokens
        assert!(limiter.try_consume(5));
        assert_eq!(limiter.available_tokens(), 5);

        // Should be able to consume remaining tokens
        assert!(limiter.try_consume(5));
        assert_eq!(limiter.available_tokens(), 0);

        // Should not be able to consume more tokens immediately
        assert!(!limiter.try_consume(1));
    }

    #[test]
    fn test_moving_average() {
        let avg = MovingAverage::new(3);

        assert_eq!(avg.add(1.0), 1.0);
        assert_eq!(avg.add(2.0), 1.5);
        assert_eq!(avg.add(3.0), 2.0);
        assert_eq!(avg.add(4.0), 3.0); // Window slides: [2, 3, 4]

        assert_eq!(avg.count(), 3);
        assert_eq!(avg.average(), 3.0);
    }

    #[test]
    fn test_counter_stats() {
        let snapshots = vec![
            CounterSnapshot {
                timestamp: SystemTime::UNIX_EPOCH,
                value: 0,
            },
            CounterSnapshot {
                timestamp: SystemTime::UNIX_EPOCH + Duration::from_secs(1),
                value: 10,
            },
            CounterSnapshot {
                timestamp: SystemTime::UNIX_EPOCH + Duration::from_secs(2),
                value: 15,
            },
        ];

        let stats = CounterStats::from_snapshots(&snapshots, 15);
        assert_eq!(stats.current_value, 15);
        assert_eq!(stats.total_snapshots, 3);
        assert_eq!(stats.min_value, 0);
        assert_eq!(stats.max_value, 15);
        assert_eq!(stats.rate_per_second, 7.5); // 15 over 2 seconds
    }
}