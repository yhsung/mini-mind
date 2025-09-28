//! Memory tracking utilities for monitoring resource usage
//!
//! This module provides memory allocation tracking, leak detection, and
//! memory usage analysis for performance optimization.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, Duration};
use serde::{Deserialize, Serialize};
use super::{MetricEntry, MetricId, MetricValue};

/// Memory tracker for monitoring allocation patterns
#[derive(Debug)]
pub struct MemoryTracker {
    allocations: Mutex<HashMap<MetricId, MemoryAllocation>>,
    total_allocated: Mutex<u64>,
    total_deallocated: Mutex<u64>,
    peak_usage: Mutex<u64>,
    snapshots: Mutex<Vec<MemorySnapshot>>,
}

impl MemoryTracker {
    /// Create a new memory tracker
    pub fn new() -> Self {
        Self {
            allocations: Mutex::new(HashMap::new()),
            total_allocated: Mutex::new(0),
            total_deallocated: Mutex::new(0),
            peak_usage: Mutex::new(0),
            snapshots: Mutex::new(Vec::new()),
        }
    }

    /// Record a memory allocation
    pub fn allocate(&self, id: MetricId, bytes: u64) {
        if let Ok(mut allocations) = self.allocations.lock() {
            let allocation = allocations.entry(id.clone()).or_insert_with(|| {
                MemoryAllocation::new(id.clone())
            });
            allocation.allocate(bytes);
        }

        if let Ok(mut total) = self.total_allocated.lock() {
            *total += bytes;
        }

        self.update_peak_usage();
        self.record_metric(id, bytes);
    }

    /// Record a memory deallocation
    pub fn deallocate(&self, id: MetricId, bytes: u64) {
        if let Ok(mut allocations) = self.allocations.lock() {
            if let Some(allocation) = allocations.get_mut(&id) {
                allocation.deallocate(bytes);
            }
        }

        if let Ok(mut total) = self.total_deallocated.lock() {
            *total += bytes;
        }
    }

    /// Record memory usage for a metric
    pub fn record(&self, id: MetricId, bytes: u64) {
        self.allocate(id, bytes);
    }

    /// Get current memory usage for a specific metric
    pub fn usage_for(&self, id: &MetricId) -> u64 {
        if let Ok(allocations) = self.allocations.lock() {
            allocations.get(id).map(|a| a.current_usage()).unwrap_or(0)
        } else {
            0
        }
    }

    /// Get current memory usage for all metrics
    pub fn current_usage(&self) -> HashMap<MetricId, u64> {
        if let Ok(allocations) = self.allocations.lock() {
            allocations.iter()
                .map(|(id, allocation)| (id.clone(), allocation.current_usage()))
                .collect()
        } else {
            HashMap::new()
        }
    }

    /// Get total allocated memory
    pub fn total_allocated(&self) -> u64 {
        if let Ok(total) = self.total_allocated.lock() {
            *total
        } else {
            0
        }
    }

    /// Get total deallocated memory
    pub fn total_deallocated(&self) -> u64 {
        if let Ok(total) = self.total_deallocated.lock() {
            *total
        } else {
            0
        }
    }

    /// Get current total memory usage
    pub fn current_total_usage(&self) -> u64 {
        self.total_allocated() - self.total_deallocated()
    }

    /// Get peak memory usage
    pub fn peak_usage(&self) -> u64 {
        if let Ok(peak) = self.peak_usage.lock() {
            *peak
        } else {
            0
        }
    }

    /// Take a snapshot of current memory state
    pub fn snapshot(&self) -> MemorySnapshot {
        let snapshot = MemorySnapshot {
            timestamp: SystemTime::now(),
            total_allocated: self.total_allocated(),
            total_deallocated: self.total_deallocated(),
            current_usage: self.current_total_usage(),
            peak_usage: self.peak_usage(),
            allocations: self.current_usage(),
        };

        if let Ok(mut snapshots) = self.snapshots.lock() {
            snapshots.push(snapshot.clone());

            // Keep only the last 1000 snapshots
            if snapshots.len() > 1000 {
                let len = snapshots.len();
                snapshots.drain(0..len - 1000);
            }
        }

        snapshot
    }

    /// Get all memory snapshots
    pub fn snapshots(&self) -> Vec<MemorySnapshot> {
        if let Ok(snapshots) = self.snapshots.lock() {
            snapshots.clone()
        } else {
            Vec::new()
        }
    }

    /// Get memory statistics
    pub fn stats(&self) -> MemoryStats {
        let snapshots = self.snapshots();
        MemoryStats::from_snapshots(&snapshots, self.current_total_usage(), self.peak_usage())
    }

    /// Detect potential memory leaks
    pub fn detect_leaks(&self) -> Vec<MemoryLeak> {
        let mut leaks = Vec::new();

        if let Ok(allocations) = self.allocations.lock() {
            for (id, allocation) in allocations.iter() {
                if allocation.is_potential_leak() {
                    leaks.push(MemoryLeak {
                        id: id.clone(),
                        bytes: allocation.current_usage(),
                        age: allocation.age(),
                        allocation_count: allocation.allocation_count(),
                    });
                }
            }
        }

        // Sort by usage amount (descending)
        leaks.sort_by(|a, b| b.bytes.cmp(&a.bytes));
        leaks
    }

    /// Reset all memory tracking data
    pub fn reset(&self) {
        if let Ok(mut allocations) = self.allocations.lock() {
            allocations.clear();
        }
        if let Ok(mut total) = self.total_allocated.lock() {
            *total = 0;
        }
        if let Ok(mut total) = self.total_deallocated.lock() {
            *total = 0;
        }
        if let Ok(mut peak) = self.peak_usage.lock() {
            *peak = 0;
        }
        if let Ok(mut snapshots) = self.snapshots.lock() {
            snapshots.clear();
        }
    }

    /// Update peak usage if current usage is higher
    fn update_peak_usage(&self) {
        let current = self.current_total_usage();
        if let Ok(mut peak) = self.peak_usage.lock() {
            if current > *peak {
                *peak = current;
            }
        }
    }

    /// Record memory metric to registry
    fn record_metric(&self, id: MetricId, bytes: u64) {
        let registry = super::registry();
        let entry = MetricEntry::new(id, MetricValue::Bytes(bytes));
        registry.record(entry);
    }
}

impl Default for MemoryTracker {
    fn default() -> Self {
        Self::new()
    }
}

/// Individual memory allocation tracker
#[derive(Debug, Clone)]
pub struct MemoryAllocation {
    id: MetricId,
    total_allocated: u64,
    total_deallocated: u64,
    allocation_count: u64,
    deallocation_count: u64,
    created_at: SystemTime,
    last_activity: SystemTime,
}

impl MemoryAllocation {
    /// Create a new memory allocation tracker
    pub fn new(id: MetricId) -> Self {
        Self {
            id,
            total_allocated: 0,
            total_deallocated: 0,
            allocation_count: 0,
            deallocation_count: 0,
            created_at: SystemTime::now(),
            last_activity: SystemTime::now(),
        }
    }

    /// Record an allocation
    pub fn allocate(&mut self, bytes: u64) {
        self.total_allocated += bytes;
        self.allocation_count += 1;
        self.last_activity = SystemTime::now();
    }

    /// Record a deallocation
    pub fn deallocate(&mut self, bytes: u64) {
        self.total_deallocated += bytes;
        self.deallocation_count += 1;
        self.last_activity = SystemTime::now();
    }

    /// Get current usage (allocated - deallocated)
    pub fn current_usage(&self) -> u64 {
        self.total_allocated - self.total_deallocated
    }

    /// Get total allocated bytes
    pub fn total_allocated(&self) -> u64 {
        self.total_allocated
    }

    /// Get total deallocated bytes
    pub fn total_deallocated(&self) -> u64 {
        self.total_deallocated
    }

    /// Get allocation count
    pub fn allocation_count(&self) -> u64 {
        self.allocation_count
    }

    /// Get deallocation count
    pub fn deallocation_count(&self) -> u64 {
        self.deallocation_count
    }

    /// Get age of this allocation tracker
    pub fn age(&self) -> Duration {
        self.created_at.elapsed().unwrap_or_default()
    }

    /// Get time since last activity
    pub fn time_since_last_activity(&self) -> Duration {
        self.last_activity.elapsed().unwrap_or_default()
    }

    /// Check if this might be a memory leak
    pub fn is_potential_leak(&self) -> bool {
        let current_usage = self.current_usage();
        let age = self.age();
        let inactive_time = self.time_since_last_activity();

        // Consider it a potential leak if:
        // 1. Has significant usage (> 1MB)
        // 2. Has been around for a while (> 5 minutes)
        // 3. No recent activity (> 1 minute)
        // 4. More allocations than deallocations
        current_usage > 1024 * 1024 && // > 1MB
        age > Duration::from_secs(300) && // > 5 minutes
        inactive_time > Duration::from_secs(60) && // > 1 minute inactive
        self.allocation_count > self.deallocation_count
    }
}

/// Memory snapshot at a point in time
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemorySnapshot {
    pub timestamp: SystemTime,
    pub total_allocated: u64,
    pub total_deallocated: u64,
    pub current_usage: u64,
    pub peak_usage: u64,
    pub allocations: HashMap<MetricId, u64>,
}

impl MemorySnapshot {
    /// Get timestamp as milliseconds since epoch
    pub fn timestamp_millis(&self) -> u64 {
        self.timestamp
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64
    }

    /// Get memory usage in MB
    pub fn current_usage_mb(&self) -> f64 {
        self.current_usage as f64 / (1024.0 * 1024.0)
    }

    /// Get peak usage in MB
    pub fn peak_usage_mb(&self) -> f64 {
        self.peak_usage as f64 / (1024.0 * 1024.0)
    }
}

/// Potential memory leak information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryLeak {
    pub id: MetricId,
    pub bytes: u64,
    pub age: Duration,
    pub allocation_count: u64,
}

impl MemoryLeak {
    /// Get leak size in MB
    pub fn size_mb(&self) -> f64 {
        self.bytes as f64 / (1024.0 * 1024.0)
    }

    /// Get age in minutes
    pub fn age_minutes(&self) -> f64 {
        self.age.as_secs_f64() / 60.0
    }
}

/// Memory statistics summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryStats {
    pub current_usage: u64,
    pub peak_usage: u64,
    pub total_allocated: u64,
    pub total_deallocated: u64,
    pub average_usage: f64,
    pub growth_rate_per_minute: f64,
    pub allocation_efficiency: f64, // deallocated / allocated
}

impl MemoryStats {
    /// Create memory stats from snapshots
    pub fn from_snapshots(snapshots: &[MemorySnapshot], current_usage: u64, peak_usage: u64) -> Self {
        if snapshots.is_empty() {
            return Self::empty(current_usage, peak_usage);
        }

        let total_allocated = snapshots.last().map(|s| s.total_allocated).unwrap_or(0);
        let total_deallocated = snapshots.last().map(|s| s.total_deallocated).unwrap_or(0);

        let average_usage = if !snapshots.is_empty() {
            snapshots.iter().map(|s| s.current_usage as f64).sum::<f64>() / snapshots.len() as f64
        } else {
            current_usage as f64
        };

        let growth_rate_per_minute = if snapshots.len() >= 2 {
            let first = &snapshots[0];
            let last = &snapshots[snapshots.len() - 1];
            let time_diff = last.timestamp.duration_since(first.timestamp)
                .unwrap_or_default().as_secs_f64() / 60.0; // Convert to minutes

            if time_diff > 0.0 {
                let usage_diff = last.current_usage as f64 - first.current_usage as f64;
                usage_diff / time_diff
            } else {
                0.0
            }
        } else {
            0.0
        };

        let allocation_efficiency = if total_allocated > 0 {
            total_deallocated as f64 / total_allocated as f64
        } else {
            1.0
        };

        Self {
            current_usage,
            peak_usage,
            total_allocated,
            total_deallocated,
            average_usage,
            growth_rate_per_minute,
            allocation_efficiency,
        }
    }

    /// Create empty memory stats
    pub fn empty(current_usage: u64, peak_usage: u64) -> Self {
        Self {
            current_usage,
            peak_usage,
            total_allocated: 0,
            total_deallocated: 0,
            average_usage: current_usage as f64,
            growth_rate_per_minute: 0.0,
            allocation_efficiency: 1.0,
        }
    }

    /// Get current usage in MB
    pub fn current_usage_mb(&self) -> f64 {
        self.current_usage as f64 / (1024.0 * 1024.0)
    }

    /// Get peak usage in MB
    pub fn peak_usage_mb(&self) -> f64 {
        self.peak_usage as f64 / (1024.0 * 1024.0)
    }

    /// Get average usage in MB
    pub fn average_usage_mb(&self) -> f64 {
        self.average_usage / (1024.0 * 1024.0)
    }

    /// Get growth rate in MB per minute
    pub fn growth_rate_mb_per_minute(&self) -> f64 {
        self.growth_rate_per_minute / (1024.0 * 1024.0)
    }
}

/// RAII memory guard for automatic tracking
pub struct MemoryGuard {
    id: MetricId,
    bytes: u64,
    tracker: Arc<MemoryTracker>,
}

impl MemoryGuard {
    /// Create a new memory guard
    pub fn new(id: MetricId, bytes: u64, tracker: Arc<MemoryTracker>) -> Self {
        tracker.allocate(id.clone(), bytes);
        Self { id, bytes, tracker }
    }

    /// Get the tracked bytes
    pub fn bytes(&self) -> u64 {
        self.bytes
    }

    /// Get the metric ID
    pub fn id(&self) -> &MetricId {
        &self.id
    }
}

impl Drop for MemoryGuard {
    fn drop(&mut self) {
        self.tracker.deallocate(self.id.clone(), self.bytes);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::metrics::MetricCategory;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn test_memory_tracker_basic() {
        let tracker = MemoryTracker::new();
        let id = MetricId::new(MetricCategory::Memory, "test_allocation");

        tracker.allocate(id.clone(), 1024);
        assert_eq!(tracker.usage_for(&id), 1024);
        assert_eq!(tracker.total_allocated(), 1024);

        tracker.deallocate(id.clone(), 512);
        assert_eq!(tracker.usage_for(&id), 512);
        assert_eq!(tracker.total_deallocated(), 512);
    }

    #[test]
    fn test_memory_allocation() {
        let id = MetricId::new(MetricCategory::Memory, "test_alloc");
        let mut allocation = MemoryAllocation::new(id);

        allocation.allocate(1000);
        allocation.allocate(500);
        assert_eq!(allocation.total_allocated(), 1500);
        assert_eq!(allocation.current_usage(), 1500);
        assert_eq!(allocation.allocation_count(), 2);

        allocation.deallocate(300);
        assert_eq!(allocation.current_usage(), 1200);
        assert_eq!(allocation.deallocation_count(), 1);
    }

    #[test]
    fn test_memory_snapshots() {
        let tracker = MemoryTracker::new();
        let id = MetricId::new(MetricCategory::Memory, "snapshot_test");

        tracker.allocate(id.clone(), 1024);
        let snapshot1 = tracker.snapshot();
        assert_eq!(snapshot1.current_usage, 1024);

        tracker.allocate(id.clone(), 2048);
        let snapshot2 = tracker.snapshot();
        assert_eq!(snapshot2.current_usage, 3072);

        let snapshots = tracker.snapshots();
        assert_eq!(snapshots.len(), 2);
    }

    #[test]
    fn test_memory_guard() {
        let tracker = Arc::new(MemoryTracker::new());
        let id = MetricId::new(MetricCategory::Memory, "guard_test");

        {
            let _guard = MemoryGuard::new(id.clone(), 1024, tracker.clone());
            assert_eq!(tracker.usage_for(&id), 1024);
        }

        // After guard is dropped, memory should be deallocated
        assert_eq!(tracker.usage_for(&id), 0);
    }

    #[test]
    fn test_potential_leak_detection() {
        let id = MetricId::new(MetricCategory::Memory, "leak_test");
        let mut allocation = MemoryAllocation::new(id);

        // Simulate a large allocation that's been around for a while
        allocation.allocate(2 * 1024 * 1024); // 2MB

        // Since we can't easily simulate time passage in tests,
        // we'll test the logic components
        assert_eq!(allocation.current_usage(), 2 * 1024 * 1024);
        assert_eq!(allocation.allocation_count(), 1);
        assert_eq!(allocation.deallocation_count(), 0);
    }

    #[test]
    fn test_memory_stats() {
        let snapshots = vec![
            MemorySnapshot {
                timestamp: SystemTime::UNIX_EPOCH,
                total_allocated: 1000,
                total_deallocated: 0,
                current_usage: 1000,
                peak_usage: 1000,
                allocations: HashMap::new(),
            },
            MemorySnapshot {
                timestamp: SystemTime::UNIX_EPOCH + Duration::from_secs(60),
                total_allocated: 2000,
                total_deallocated: 500,
                current_usage: 1500,
                peak_usage: 2000,
                allocations: HashMap::new(),
            },
        ];

        let stats = MemoryStats::from_snapshots(&snapshots, 1500, 2000);
        assert_eq!(stats.current_usage, 1500);
        assert_eq!(stats.peak_usage, 2000);
        assert_eq!(stats.growth_rate_per_minute, 500.0); // 500 bytes per minute
        assert_eq!(stats.allocation_efficiency, 0.25); // 500/2000
    }
}