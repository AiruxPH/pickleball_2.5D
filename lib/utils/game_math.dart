import 'dart:math' as math;
import 'dart:typed_data';
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

  /// Preferred screen-up direction in world space.
  ///
  /// Normal gameplay uses world height. A vertical overhead camera instead
  /// uses court depth so its basis remains well-defined while looking down.
  Vec3 up;

  // Cached frame basis vectors and perspective coefficients
  // to avoid recalculating basis and allocating Vec3s hundreds of times per frame
  double _fwdX = 0, _fwdY = 0, _fwdZ = -1;
  double _rightX = 1, _rightY = 0, _rightZ = 0;
  double _upX = 0, _upY = 1, _upZ = 0;
  double _invHalfW = 1.0;
  double _invHalfH = 1.0;
  double _halfScreenWidth = 0;
  double _halfScreenHeight = 0;
  bool _framePrepared = false;

  PerspectiveCamera({
    required this.position,
    required this.target,
    required this.screenSize,
    this.fov = CameraConstants.defaultFOV,
    Vec3? up,
  }) : up = up?.copy() ?? Vec3(0, 1, 0) {
    prepareFrame();
  }

  /// Call once per frame before projection passes to cache basis vectors & projection factors
  void prepareFrame() {
    final tpx = target.x - position.x;
    final tpy = target.y - position.y;
    final tpz = target.z - position.z;
    final fwdLen = math.sqrt(tpx * tpx + tpy * tpy + tpz * tpz);
    if (fwdLen > 0.0001) {
      _fwdX = tpx / fwdLen;
      _fwdY = tpy / fwdLen;
      _fwdZ = tpz / fwdLen;
    } else {
      _fwdX = 0;
      _fwdY = 0;
      _fwdZ = -1;
    }

    // right = forward x preferredUp. The configurable up vector lets a true
    // vertical overhead camera avoid the world-up singularity.
    var rx = _fwdY * up.z - _fwdZ * up.y;
    var ry = _fwdZ * up.x - _fwdX * up.z;
    var rz = _fwdX * up.y - _fwdY * up.x;
    var rLen = math.sqrt(rx * rx + ry * ry + rz * rz);
    if (rLen <= 0.0001) {
      final fallbackUp = _fwdY.abs() > 0.9 ? Vec3(0, 0, -1) : Vec3(0, 1, 0);
      rx = _fwdY * fallbackUp.z - _fwdZ * fallbackUp.y;
      ry = _fwdZ * fallbackUp.x - _fwdX * fallbackUp.z;
      rz = _fwdX * fallbackUp.y - _fwdY * fallbackUp.x;
      rLen = math.sqrt(rx * rx + ry * ry + rz * rz);
    }
    if (rLen > 0.0001) {
      _rightX = rx / rLen;
      _rightY = ry;
      _rightZ = rz / rLen;
    } else {
      _rightX = 1;
      _rightY = 0;
      _rightZ = 0;
    }

    // up = right x fwd
    final ux = _rightY * _fwdZ - _rightZ * _fwdY;
    final uy = _rightZ * _fwdX - _rightX * _fwdZ;
    final uz = _rightX * _fwdY - _rightY * _fwdX;
    final uLen = math.sqrt(ux * ux + uy * uy + uz * uz);
    if (uLen > 0.0001) {
      _upX = ux / uLen;
      _upY = uy / uLen;
      _upZ = uz / uLen;
    } else {
      _upX = 0;
      _upY = 1;
      _upZ = 0;
    }

    final halfH = math.tan(fov * math.pi / 360.0);
    final h = screenSize.height > 0 ? screenSize.height : 1.0;
    final aspect = screenSize.width / h;
    final halfW = halfH * aspect;

    _invHalfH = halfH > 0 ? 1.0 / halfH : 1.0;
    _invHalfW = halfW > 0 ? 1.0 / halfW : 1.0;
    _halfScreenWidth = screenSize.width * 0.5;
    _halfScreenHeight = screenSize.height * 0.5;
    _framePrepared = true;
  }

  /// Project a world point to screen coordinates.
  /// Returns null if the point is behind the camera.
  Offset? project(Vec3 worldPoint) {
    return projectCoords(worldPoint.x, worldPoint.y, worldPoint.z);
  }

  /// Fast coordinate projection without allocating any Vec3 objects
  Offset? projectCoords(double wx, double wy, double wz) {
    if (!_framePrepared) prepareFrame();

    final dx = wx - position.x;
    final dy = wy - position.y;
    final dz = wz - position.z;

    // Forward distance along camera look axis
    final cz = dx * _fwdX + dy * _fwdY + dz * _fwdZ;
    if (cz <= 0.1) return null;

    final cx = dx * _rightX + dy * _rightY + dz * _rightZ;
    final cy = dx * _upX + dy * _upY + dz * _upZ;

    final invCz = 1.0 / cz;
    final ndcX = cx * invCz * _invHalfW;
    final ndcY = cy * invCz * _invHalfH;

    final sx = (ndcX + 1.0) * _halfScreenWidth;
    final sy = (1.0 - ndcY) * _halfScreenHeight;

    return Offset(sx, sy);
  }

  /// Builds a column-major 4x4 matrix (for [Canvas.transform]) that maps 2D
  /// canvas coordinates (u, v) lying on the world plane
  /// `origin + u * axisU + v * axisV` to screen space with exact perspective.
  ///
  /// This lets planar content (court paint, lines, net mesh) be drawn directly
  /// in world units, so line widths and textures foreshorten correctly.
  /// Only valid while the whole drawn region is in front of the camera.
  Float64List planeToScreenMatrix(
    double ox,
    double oy,
    double oz,
    double ux,
    double uy,
    double uz,
    double vx,
    double vy,
    double vz,
  ) {
    if (!_framePrepared) prepareFrame();

    final dx = ox - position.x;
    final dy = oy - position.y;
    final dz = oz - position.z;

    // Camera-space coefficients: c = c0 + u * cU + v * cV
    final cx0 = dx * _rightX + dy * _rightY + dz * _rightZ;
    final cy0 = dx * _upX + dy * _upY + dz * _upZ;
    final cz0 = dx * _fwdX + dy * _fwdY + dz * _fwdZ;
    final cxU = ux * _rightX + uy * _rightY + uz * _rightZ;
    final cyU = ux * _upX + uy * _upY + uz * _upZ;
    final czU = ux * _fwdX + uy * _fwdY + uz * _fwdZ;
    final cxV = vx * _rightX + vy * _rightY + vz * _rightZ;
    final cyV = vx * _upX + vy * _upY + vz * _upZ;
    final czV = vx * _fwdX + vy * _fwdY + vz * _fwdZ;

    // screenX * w = hsw * invHalfW * cx + hsw * cz
    // screenY * w = hsh * cz - hsh * invHalfH * cy
    // w           = cz
    final ax = _halfScreenWidth * _invHalfW;
    final ay = _halfScreenHeight * _invHalfH;
    final hsw = _halfScreenWidth;
    final hsh = _halfScreenHeight;

    final m = Float64List(16);
    // column 0 (u)
    m[0] = ax * cxU + hsw * czU;
    m[1] = hsh * czU - ay * cyU;
    m[3] = czU;
    // column 1 (v)
    m[4] = ax * cxV + hsw * czV;
    m[5] = hsh * czV - ay * cyV;
    m[7] = czV;
    // column 2 (z passthrough)
    m[10] = 1.0;
    // column 3 (translation)
    m[12] = ax * cx0 + hsw * cz0;
    m[13] = hsh * cz0 - ay * cy0;
    m[15] = cz0;
    return m;
  }

  /// Ground plane (y = 0) mapping: canvas (u, v) = world (x, z).
  Float64List groundMatrix() => planeToScreenMatrix(0, 0, 0, 1, 0, 0, 0, 0, 1);

  /// Net plane (z = 0) mapping: canvas (u, v) = world (x, y).
  Float64List netPlaneMatrix() =>
      planeToScreenMatrix(0, 0, 0, 1, 0, 0, 0, 1, 0);

  /// Returns a scale factor for objects at this world point (for depth sizing)
  double depthScale(Vec3 worldPoint) {
    return depthScaleCoords(worldPoint.x, worldPoint.y, worldPoint.z);
  }

  /// Fast depth scale calculation without allocating any Vec3 objects
  double depthScaleCoords(double wx, double wy, double wz) {
    if (!_framePrepared) prepareFrame();
    final dz = (wx - position.x) * _fwdX +
        (wy - position.y) * _fwdY +
        (wz - position.z) * _fwdZ;
    if (dz <= 0) return 0;
    const refDist = 100.0;
    return (refDist / dz).clamp(0.2, 3.0);
  }

  /// Perspective scale at [worldPoint], expressed as screen pixels per world
  /// unit. Unlike projecting a vertical segment, this does not collapse when
  /// the camera looks straight down.
  double pixelsPerWorldUnit(Vec3 worldPoint) => pixelsPerWorldUnitCoords(
        worldPoint.x,
        worldPoint.y,
        worldPoint.z,
      );

  double pixelsPerWorldUnitCoords(double wx, double wy, double wz) {
    if (!_framePrepared) prepareFrame();
    final depth = (wx - position.x) * _fwdX +
        (wy - position.y) * _fwdY +
        (wz - position.z) * _fwdZ;
    if (depth <= 0.1) return 0;
    return _halfScreenHeight * _invHalfH / depth;
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
