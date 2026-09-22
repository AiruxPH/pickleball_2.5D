import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Math helpers: perspective projection, lerp, vector operations
/// ─────────────────────────────────────────────────────────────

// ── Simple 3D Vector ──────────────────────────────────────────
class Vec3 {
  double x, y, z;

  Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final len = length;
    if (len == 0) return Vec3(0, 0, 0);
    return Vec3(x / len, y / len, z / len);
  }

  Vec3 copy() => Vec3(x, y, z);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

// ── Perspective Projection Camera ─────────────────────────────
/// Projects a 3D world point to a 2D screen position.
///
/// Coordinate system:
///   X = left/right across court
///   Y = height above court surface
///   Z = depth along court (positive = toward player/camera, negative = toward AI)
///
/// The camera sits behind the player, slightly above,
/// looking toward the net (toward negative Z).
class PerspectiveCamera {
  /// Where the camera is positioned in world space
  Vec3 position;

  /// Where the camera is looking (target point)
  Vec3 target;

  /// Screen size for projection
  Size screenSize;

  /// Vertical field of view in degrees
  double fov;

  PerspectiveCamera({
    required this.position,
    required this.target,
    required this.screenSize,
    this.fov = CameraConstants.defaultFOV,
  });

  /// Project a world point to screen coordinates.
  /// Returns null if the point is behind the camera.
  Offset? project(Vec3 worldPoint) {
    // Translate so camera is at origin
    final dx = worldPoint.x - position.x;
    final dy = worldPoint.y - position.y;
    final dz = worldPoint.z - position.z;

    // Simple forward-facing camera: camera looks toward -Z direction in world
    // We rotate so "forward" aligns with camera → target direction
    final fwd = (target - position).normalized();
    final right = Vec3(-fwd.z, 0, fwd.x).normalized(); // right = fwd x worldUp (0, 1, 0)
    final up = Vec3(
      right.y * fwd.z - right.z * fwd.y,
      right.z * fwd.x - right.x * fwd.z,
      right.x * fwd.y - right.y * fwd.x,
    ).normalized(); // up = right x fwd

    // Camera-space coordinates
    final cx = dx * right.x + dy * right.y + dz * right.z;
    final cy = dx * up.x + dy * up.y + dz * up.z;
    final cz = dx * fwd.x + dy * fwd.y + dz * fwd.z;

    // Behind camera
    if (cz <= 0.1) return null;

    // Perspective divide
    final halfH = math.tan(fov * math.pi / 360.0);
    final aspect = screenSize.width / screenSize.height;
    final halfW = halfH * aspect;

    final ndcX = cx / (cz * halfW);
    final ndcY = cy / (cz * halfH);

    // Convert to screen coordinates (Y flipped: up in 3D = 0 at screen top)
    final sx = (ndcX + 1.0) * 0.5 * screenSize.width;
    final sy = (1.0 - ndcY) * 0.5 * screenSize.height;

    return Offset(sx, sy);
  }

  /// Returns a scale factor for objects at this world point (for depth sizing)
  double depthScale(Vec3 worldPoint) {
    final dz = (worldPoint - position).dot(
      (target - position).normalized(),
    );
    if (dz <= 0) return 0;
    // Reference distance at which scale = 1.0
    const refDist = 100.0;
    return (refDist / dz).clamp(0.2, 3.0);
  }
}

// ── Math Helpers ───────────────────────────────────────────────

/// Linear interpolation between a and b by t (0..1)
double lerp(double a, double b, double t) => a + (b - a) * t;

/// Clamp x between lo and hi
double clamp(double x, double lo, double hi) => x < lo ? lo : (x > hi ? hi : x);

/// Smooth step (ease in-out) between 0 and 1
double smoothStep(double t) {
  t = clamp(t, 0, 1);
  return t * t * (3.0 - 2.0 * t);
}

/// Distance between two 2D points
double dist2D(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return math.sqrt(dx * dx + dy * dy);
}

/// Angle between two 2D vectors, in radians
double angle2D(double dx, double dy) => math.atan2(dy, dx);

/// Random double between min and max
double randomRange(double min, double max) {
  return min + math.Random().nextDouble() * (max - min);
}

/// Vec3 linear interpolation
Vec3 lerpVec3(Vec3 a, Vec3 b, double t) {
  return Vec3(
    lerp(a.x, b.x, t),
    lerp(a.y, b.y, t),
    lerp(a.z, b.z, t),
  );
}

/// Degrees to radians
double deg2rad(double degrees) => degrees * math.pi / 180.0;

/// Radians to degrees
double rad2deg(double radians) => radians * 180.0 / math.pi;
