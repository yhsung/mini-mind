//! Timer utilities for performance measurement
//!
//! This module provides high-precision timing functionality for measuring
//! operation durations and performance profiling.

use std::time::{Duration, Instant};
use std::sync::{Arc, Mutex};
use serde::{Deserialize, Serialize};
use super::{MetricEntry, MetricId, MetricValue, MetricsRegistry};

/// High-precision timer handle for measuring operation duration
#[derive(Debug)]
pub struct TimerHandle {
    id: MetricId,
    start_time: Instant,
    registry: Option<*const MetricsRegistry>,
    finished: Arc<Mutex<bool>>,
}

// TimerHandle is Send because we control access to the registry pointer
unsafe impl Send for TimerHandle {}

impl TimerHandle {
    /// Create a new timer handle
    pub fn new(id: MetricId, registry: Option<*const MetricsRegistry>) -> Self {
        Self {
            id,
            start_time: Instant::now(),
            registry,
            finished: Arc::new(Mutex::new(false)),
        }
    }

    /// Get the elapsed duration without finishing the timer
    pub fn elapsed(&self) -> Duration {
        self.start_time.elapsed()
    }

    /// Finish timing and record the result
    pub fn finish(self) -> Duration {
        let duration = self.elapsed();

        // Mark as finished
        if let Ok(mut finished) = self.finished.lock() {
            *finished = true;
        }

        // Record the metric if registry is available
        if let Some(registry_ptr) = self.registry {
            unsafe {
                let registry = &*registry_ptr;
                let entry = MetricEntry::new(self.id.clone(), MetricValue::Duration(duration));
                registry.record(entry);
            }
        }

        duration
    }

    /// Check if the timer has been finished
    pub fn is_finished(&self) -> bool {
        if let Ok(finished) = self.finished.lock() {
            *finished
        } else {
            false
        }
    }
}

impl Drop for TimerHandle {
    fn drop(&mut self) {
        // Auto-finish if not already finished
        if !self.is_finished() {
            let duration = self.elapsed();

            if let Ok(mut finished) = self.finished.lock() {
                *finished = true;
            }

            if let Some(registry_ptr) = self.registry {
                unsafe {
                    let registry = &*registry_ptr;
                    let entry = MetricEntry::new(self.id.clone(), MetricValue::Duration(duration));
                    registry.record(entry);
                }
            }
        }
    }
}

/// Registry for managing multiple timers for the same metric
#[derive(Debug)]
pub struct TimerRegistry {
    id: MetricId,
    active_timers: Arc<Mutex<Vec<TimerHandle>>>,
    completed_timings: Arc<Mutex<Vec<Duration>>>,
}

impl TimerRegistry {
    /// Create a new timer registry
    pub fn new(id: MetricId) -> Self {
        Self {
            id,
            active_timers: Arc::new(Mutex::new(Vec::new())),
            completed_timings: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Start a new timer
    pub fn start(&mut self) -> TimerHandle {
        let handle = TimerHandle::new(self.id.clone(), None);

        if let Ok(mut timers) = self.active_timers.lock() {
            timers.push(TimerHandle::new(self.id.clone(), None));
        }

        handle
    }

    /// Get statistics for completed timings
    pub fn stats(&self) -> TimingStats {
        if let Ok(timings) = self.completed_timings.lock() {
            TimingStats::from_durations(&timings)
        } else {
            TimingStats::empty()
        }
    }

    /// Get the number of active timers
    pub fn active_count(&self) -> usize {
        if let Ok(timers) = self.active_timers.lock() {
            timers.len()
        } else {
            0
        }
    }

    /// Get the number of completed timings
    pub fn completed_count(&self) -> usize {
        if let Ok(timings) = self.completed_timings.lock() {
            timings.len()
        } else {
            0
        }
    }

    /// Clear all timing data
    pub fn clear(&mut self) {
        if let Ok(mut timers) = self.active_timers.lock() {
            timers.clear();
        }
        if let Ok(mut timings) = self.completed_timings.lock() {
            timings.clear();
        }
    }
}

/// Statistical summary of timing measurements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimingStats {
    pub count: usize,
    pub total: Duration,
    pub average: Duration,
    pub min: Duration,
    pub max: Duration,
    pub median: Duration,
    pub percentile_95: Duration,
    pub percentile_99: Duration,
}

impl TimingStats {
    /// Create timing stats from a collection of durations
    pub fn from_durations(durations: &[Duration]) -> Self {
        if durations.is_empty() {
            return Self::empty();
        }

        let mut sorted_durations = durations.to_vec();
        sorted_durations.sort();

        let count = durations.len();
        let total = durations.iter().sum();
        let average = total / count as u32;
        let min = sorted_durations[0];
        let max = sorted_durations[count - 1];

        let median = if count % 2 == 0 {
            let mid = count / 2;
            (sorted_durations[mid - 1] + sorted_durations[mid]) / 2
        } else {
            sorted_durations[count / 2]
        };

        let percentile_95 = sorted_durations[((count as f64) * 0.95) as usize];
        let percentile_99 = sorted_durations[((count as f64) * 0.99) as usize];

        Self {
            count,
            total,
            average,
            min,
            max,
            median,
            percentile_95,
            percentile_99,
        }
    }

    /// Create empty timing stats
    pub fn empty() -> Self {
        Self {
            count: 0,
            total: Duration::ZERO,
            average: Duration::ZERO,
            min: Duration::ZERO,
            max: Duration::ZERO,
            median: Duration::ZERO,
            percentile_95: Duration::ZERO,
            percentile_99: Duration::ZERO,
        }
    }

    /// Check if this represents empty stats
    pub fn is_empty(&self) -> bool {
        self.count == 0
    }

    /// Get the average duration in milliseconds
    pub fn average_millis(&self) -> f64 {
        self.average.as_secs_f64() * 1000.0
    }

    /// Get the total duration in milliseconds
    pub fn total_millis(&self) -> f64 {
        self.total.as_secs_f64() * 1000.0
    }
}

/// Scoped timer that automatically records timing when dropped
pub struct ScopedTimer {
    handle: Option<TimerHandle>,
}

impl ScopedTimer {
    /// Create a new scoped timer
    pub fn new(id: MetricId) -> Self {
        let registry = super::registry();
        let handle = TimerHandle::new(id, Some(registry as *const MetricsRegistry));
        Self {
            handle: Some(handle),
        }
    }

    /// Get the elapsed time without finishing
    pub fn elapsed(&self) -> Duration {
        if let Some(handle) = &self.handle {
            handle.elapsed()
        } else {
            Duration::ZERO
        }
    }

    /// Manually finish the timer early
    pub fn finish(&mut self) -> Option<Duration> {
        if let Some(handle) = self.handle.take() {
            Some(handle.finish())
        } else {
            None
        }
    }
}

impl Drop for ScopedTimer {
    fn drop(&mut self) {
        if let Some(handle) = self.handle.take() {
            handle.finish();
        }
    }
}

/// Utility for measuring function execution time
pub fn time_function<F, R>(id: MetricId, func: F) -> (R, Duration)
where
    F: FnOnce() -> R,
{
    let timer = ScopedTimer::new(id);
    let result = func();
    let duration = timer.elapsed();
    (result, duration)
}

/// Utility for measuring async function execution time
pub async fn time_async_function<F, Fut, R>(id: MetricId, func: F) -> (R, Duration)
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = R>,
{
    let start = Instant::now();
    let result = func().await;
    let duration = start.elapsed();

    // Record the timing
    let registry = super::registry();
    let entry = MetricEntry::new(id, MetricValue::Duration(duration));
    registry.record(entry);

    (result, duration)
}

/// Benchmark runner for performance testing
pub struct Benchmark {
    id: MetricId,
    iterations: usize,
    warmup_iterations: usize,
}

impl Benchmark {
    /// Create a new benchmark
    pub fn new(id: MetricId) -> Self {
        Self {
            id,
            iterations: 1000,
            warmup_iterations: 100,
        }
    }

    /// Set the number of iterations
    pub fn iterations(mut self, count: usize) -> Self {
        self.iterations = count;
        self
    }

    /// Set the number of warmup iterations
    pub fn warmup(mut self, count: usize) -> Self {
        self.warmup_iterations = count;
        self
    }

    /// Run the benchmark
    pub fn run<F, R>(&self, func: F) -> BenchmarkResult
    where
        F: Fn() -> R,
    {
        // Warmup phase
        for _ in 0..self.warmup_iterations {
            let _ = func();
        }

        // Actual benchmark
        let mut timings = Vec::with_capacity(self.iterations);
        for _ in 0..self.iterations {
            let start = Instant::now();
            let _ = func();
            timings.push(start.elapsed());
        }

        // Record individual timings
        let registry = super::registry();
        for timing in &timings {
            let entry = MetricEntry::new(self.id.clone(), MetricValue::Duration(*timing));
            registry.record(entry);
        }

        BenchmarkResult {
            id: self.id.clone(),
            iterations: self.iterations,
            stats: TimingStats::from_durations(&timings),
        }
    }
}

/// Result of a benchmark run
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BenchmarkResult {
    pub id: MetricId,
    pub iterations: usize,
    pub stats: TimingStats,
}

impl BenchmarkResult {
    /// Get operations per second
    pub fn ops_per_second(&self) -> f64 {
        if self.stats.average.as_secs_f64() > 0.0 {
            1.0 / self.stats.average.as_secs_f64()
        } else {
            0.0
        }
    }
}

// Convenience macros for timing operations
#[macro_export]
macro_rules! time_scope {
    ($id:expr) => {
        let _timer = $crate::metrics::timer::ScopedTimer::new($id);
    };
}

#[macro_export]
macro_rules! time_block {
    ($id:expr, $block:block) => {{
        let timer = $crate::metrics::timer::ScopedTimer::new($id);
        let result = $block;
        (result, timer.elapsed())
    }};
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::metrics::MetricCategory;
    use std::thread;

    #[test]
    fn test_timer_handle() {
        let id = MetricId::new(MetricCategory::Graph, "test_timer");
        let timer = TimerHandle::new(id, None);

        thread::sleep(Duration::from_millis(10));
        let duration = timer.finish();

        assert!(duration >= Duration::from_millis(10));
    }

    #[test]
    fn test_scoped_timer() {
        let id = MetricId::new(MetricCategory::Graph, "test_scoped");

        let duration = {
            let timer = ScopedTimer::new(id);
            thread::sleep(Duration::from_millis(5));
            timer.elapsed()
        };

        assert!(duration >= Duration::from_millis(5));
    }

    #[test]
    fn test_timing_stats() {
        let durations = vec![
            Duration::from_millis(10),
            Duration::from_millis(20),
            Duration::from_millis(30),
            Duration::from_millis(40),
            Duration::from_millis(50),
        ];

        let stats = TimingStats::from_durations(&durations);
        assert_eq!(stats.count, 5);
        assert_eq!(stats.min, Duration::from_millis(10));
        assert_eq!(stats.max, Duration::from_millis(50));
        assert_eq!(stats.median, Duration::from_millis(30));
    }

    #[test]
    fn test_empty_timing_stats() {
        let stats = TimingStats::from_durations(&[]);
        assert!(stats.is_empty());
        assert_eq!(stats.count, 0);
    }

    #[test]
    fn test_time_function() {
        let id = MetricId::new(MetricCategory::Application, "test_function");
        let (result, duration) = time_function(id, || {
            thread::sleep(Duration::from_millis(5));
            42
        });

        assert_eq!(result, 42);
        assert!(duration >= Duration::from_millis(5));
    }

    #[test]
    fn test_benchmark() {
        let id = MetricId::new(MetricCategory::Application, "test_benchmark");
        let benchmark = Benchmark::new(id)
            .iterations(10)
            .warmup(5);

        let result = benchmark.run(|| {
            // Simple operation
            let mut sum = 0;
            for i in 0..100 {
                sum += i;
            }
            sum
        });

        assert_eq!(result.iterations, 10);
        assert!(result.stats.count == 10);
        assert!(result.ops_per_second() > 0.0);
    }
}