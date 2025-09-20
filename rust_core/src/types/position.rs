//! Position and geometry types for mindmap visualization
//!
//! This module provides types for representing positions, sizes, bounds,
//! and other geometric concepts used in mindmap layouts.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Type alias for coordinate values
pub type Coordinate = f64;

/// 2D point with x and y coordinates
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point {
    pub x: Coordinate,
    pub y: Coordinate,
}

/// Size with width and height dimensions
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Size {
    pub width: Coordinate,
    pub height: Coordinate,
}

/// Rectangle defined by position and size
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Rect {
    pub position: Point,
    pub size: Size,
}

/// Bounding box with min/max coordinates
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Bounds {
    pub min_x: Coordinate,
    pub min_y: Coordinate,
    pub max_x: Coordinate,
    pub max_y: Coordinate,
}

/// Vector representing direction and magnitude
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Vector {
    pub x: Coordinate,
    pub y: Coordinate,
}

/// Polar coordinates (radius and angle)
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Polar {
    pub radius: Coordinate,
    pub angle: Coordinate, // in radians
}

impl Point {
    /// Create a new point
    pub fn new(x: Coordinate, y: Coordinate) -> Self {
        Self { x, y }
    }

    /// Origin point (0, 0)
    pub fn origin() -> Self {
        Self::new(0.0, 0.0)
    }

    /// Calculate distance to another point
    pub fn distance_to(&self, other: &Point) -> Coordinate {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }

    /// Calculate midpoint with another point
    pub fn midpoint(&self, other: &Point) -> Point {
        Point::new((self.x + other.x) / 2.0, (self.y + other.y) / 2.0)
    }

    /// Translate point by a vector
    pub fn translate(&self, vector: &Vector) -> Point {
        Point::new(self.x + vector.x, self.y + vector.y)
    }

    /// Convert to polar coordinates relative to origin
    pub fn to_polar(&self) -> Polar {
        let radius = (self.x * self.x + self.y * self.y).sqrt();
        let angle = self.y.atan2(self.x);
        Polar { radius, angle }
    }

    /// Create point from polar coordinates
    pub fn from_polar(polar: &Polar) -> Self {
        Point::new(
            polar.radius * polar.angle.cos(),
            polar.radius * polar.angle.sin(),
        )
    }
}

impl Size {
    /// Create a new size
    pub fn new(width: Coordinate, height: Coordinate) -> Self {
        Self { width, height }
    }

    /// Zero size
    pub fn zero() -> Self {
        Self::new(0.0, 0.0)
    }

    /// Square size with equal width and height
    pub fn square(size: Coordinate) -> Self {
        Self::new(size, size)
    }

    /// Calculate area
    pub fn area(&self) -> Coordinate {
        self.width * self.height
    }

    /// Check if size is valid (positive dimensions)
    pub fn is_valid(&self) -> bool {
        self.width >= 0.0 && self.height >= 0.0
    }

    /// Scale size by a factor
    pub fn scale(&self, factor: Coordinate) -> Size {
        Size::new(self.width * factor, self.height * factor)
    }
}

impl Rect {
    /// Create a new rectangle
    pub fn new(x: Coordinate, y: Coordinate, width: Coordinate, height: Coordinate) -> Self {
        Self {
            position: Point::new(x, y),
            size: Size::new(width, height),
        }
    }

    /// Create rectangle from position and size
    pub fn from_pos_size(position: Point, size: Size) -> Self {
        Self { position, size }
    }

    /// Get the left edge x-coordinate
    pub fn left(&self) -> Coordinate {
        self.position.x
    }

    /// Get the right edge x-coordinate
    pub fn right(&self) -> Coordinate {
        self.position.x + self.size.width
    }

    /// Get the top edge y-coordinate
    pub fn top(&self) -> Coordinate {
        self.position.y
    }

    /// Get the bottom edge y-coordinate
    pub fn bottom(&self) -> Coordinate {
        self.position.y + self.size.height
    }

    /// Get the center point
    pub fn center(&self) -> Point {
        Point::new(
            self.position.x + self.size.width / 2.0,
            self.position.y + self.size.height / 2.0,
        )
    }

    /// Check if point is inside rectangle
    pub fn contains_point(&self, point: &Point) -> bool {
        point.x >= self.left()
            && point.x <= self.right()
            && point.y >= self.top()
            && point.y <= self.bottom()
    }

    /// Check if rectangle intersects with another rectangle
    pub fn intersects(&self, other: &Rect) -> bool {
        self.left() <= other.right()
            && self.right() >= other.left()
            && self.top() <= other.bottom()
            && self.bottom() >= other.top()
    }

    /// Convert to bounds
    pub fn to_bounds(&self) -> Bounds {
        Bounds {
            min_x: self.left(),
            min_y: self.top(),
            max_x: self.right(),
            max_y: self.bottom(),
        }
    }
}

impl Bounds {
    /// Create new bounds
    pub fn new(min_x: Coordinate, min_y: Coordinate, max_x: Coordinate, max_y: Coordinate) -> Self {
        Self {
            min_x,
            min_y,
            max_x,
            max_y,
        }
    }

    /// Empty bounds (invalid bounds where min > max)
    pub fn empty() -> Self {
        Self::new(
            Coordinate::INFINITY,
            Coordinate::INFINITY,
            Coordinate::NEG_INFINITY,
            Coordinate::NEG_INFINITY,
        )
    }

    /// Check if bounds are valid
    pub fn is_valid(&self) -> bool {
        self.min_x <= self.max_x && self.min_y <= self.max_y
    }

    /// Get width of bounds
    pub fn width(&self) -> Coordinate {
        self.max_x - self.min_x
    }

    /// Get height of bounds
    pub fn height(&self) -> Coordinate {
        self.max_y - self.min_y
    }

    /// Get center point
    pub fn center(&self) -> Point {
        Point::new(
            (self.min_x + self.max_x) / 2.0,
            (self.min_y + self.max_y) / 2.0,
        )
    }

    /// Expand bounds to include a point
    pub fn include_point(&mut self, point: &Point) {
        if !self.is_valid() {
            self.min_x = point.x;
            self.min_y = point.y;
            self.max_x = point.x;
            self.max_y = point.y;
        } else {
            self.min_x = self.min_x.min(point.x);
            self.min_y = self.min_y.min(point.y);
            self.max_x = self.max_x.max(point.x);
            self.max_y = self.max_y.max(point.y);
        }
    }

    /// Expand bounds to include another bounds
    pub fn include_bounds(&mut self, other: &Bounds) {
        if other.is_valid() {
            self.include_point(&Point::new(other.min_x, other.min_y));
            self.include_point(&Point::new(other.max_x, other.max_y));
        }
    }

    /// Convert to rectangle
    pub fn to_rect(&self) -> Rect {
        Rect::new(self.min_x, self.min_y, self.width(), self.height())
    }
}

impl Vector {
    /// Create a new vector
    pub fn new(x: Coordinate, y: Coordinate) -> Self {
        Self { x, y }
    }

    /// Zero vector
    pub fn zero() -> Self {
        Self::new(0.0, 0.0)
    }

    /// Calculate magnitude (length) of vector
    pub fn magnitude(&self) -> Coordinate {
        (self.x * self.x + self.y * self.y).sqrt()
    }

    /// Normalize vector to unit length
    pub fn normalize(&self) -> Vector {
        let mag = self.magnitude();
        if mag > 0.0 {
            Vector::new(self.x / mag, self.y / mag)
        } else {
            Vector::zero()
        }
    }

    /// Scale vector by a factor
    pub fn scale(&self, factor: Coordinate) -> Vector {
        Vector::new(self.x * factor, self.y * factor)
    }

    /// Add two vectors
    pub fn add(&self, other: &Vector) -> Vector {
        Vector::new(self.x + other.x, self.y + other.y)
    }

    /// Subtract two vectors
    pub fn subtract(&self, other: &Vector) -> Vector {
        Vector::new(self.x - other.x, self.y - other.y)
    }

    /// Dot product with another vector
    pub fn dot(&self, other: &Vector) -> Coordinate {
        self.x * other.x + self.y * other.y
    }
}

// Default implementations
impl Default for Point {
    fn default() -> Self {
        Self::origin()
    }
}

impl Default for Size {
    fn default() -> Self {
        Self::zero()
    }
}

impl Default for Vector {
    fn default() -> Self {
        Self::zero()
    }
}

// Display implementations
impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({:.2}, {:.2})", self.x, self.y)
    }
}

impl fmt::Display for Size {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}x{}", self.width, self.height)
    }
}

impl fmt::Display for Rect {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{} {}]", self.position, self.size)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_point_distance() {
        let p1 = Point::new(0.0, 0.0);
        let p2 = Point::new(3.0, 4.0);
        assert_eq!(p1.distance_to(&p2), 5.0);
    }

    #[test]
    fn test_point_midpoint() {
        let p1 = Point::new(0.0, 0.0);
        let p2 = Point::new(4.0, 6.0);
        let mid = p1.midpoint(&p2);
        assert_eq!(mid, Point::new(2.0, 3.0));
    }

    #[test]
    fn test_rect_contains() {
        let rect = Rect::new(10.0, 10.0, 20.0, 20.0);
        assert!(rect.contains_point(&Point::new(15.0, 15.0)));
        assert!(!rect.contains_point(&Point::new(5.0, 5.0)));
    }

    #[test]
    fn test_bounds_include() {
        let mut bounds = Bounds::empty();
        bounds.include_point(&Point::new(10.0, 20.0));
        bounds.include_point(&Point::new(30.0, 5.0));

        assert_eq!(bounds.min_x, 10.0);
        assert_eq!(bounds.min_y, 5.0);
        assert_eq!(bounds.max_x, 30.0);
        assert_eq!(bounds.max_y, 20.0);
    }

    #[test]
    fn test_vector_operations() {
        let v1 = Vector::new(3.0, 4.0);
        let v2 = Vector::new(1.0, 2.0);

        assert_eq!(v1.magnitude(), 5.0);
        assert_eq!(v1.add(&v2), Vector::new(4.0, 6.0));
        assert_eq!(v1.subtract(&v2), Vector::new(2.0, 2.0));
        assert_eq!(v1.dot(&v2), 11.0);
    }

    #[test]
    fn test_polar_conversion() {
        let point = Point::new(1.0, 1.0);
        let polar = point.to_polar();
        let back = Point::from_polar(&polar);

        assert!((back.x - point.x).abs() < 1e-10);
        assert!((back.y - point.y).abs() < 1e-10);
    }
}