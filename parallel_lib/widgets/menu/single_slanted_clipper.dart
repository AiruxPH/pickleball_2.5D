import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// SingleSlantedClipper & SingleSlantedFrame
/// Creates a sleek athletic tile where exactly ONE side (the right edge)
/// has a subtle angle of 6° to 8° (default 7.0°), while the left, top,
/// and bottom edges remain clean and rectangular.
/// Keeps child text and icons strictly upright with zero skew.
/// ─────────────────────────────────────────────────────────────

enum SlantDirection {
  /// Top-right extends forward, bottom-right pulls back (/)
  forward,

  /// Top-right pulls in, bottom-right extends out (\)
  backward,
}

/// CustomClipper that clips any container to a single-side slanted shape with rounded corners.
class SingleSlantedClipper extends CustomClipper<Path> {
  final double angleDegrees;
  final double radius;
  final SlantDirection direction;

  const SingleSlantedClipper({
    this.angleDegrees = 7.0,
    this.radius = 12.0,
    this.direction = SlantDirection.forward,
  });

  @override
  Path getClip(Size size) {
    return buildSingleSlantedPath(
      size: size,
      angleDegrees: angleDegrees,
      radius: radius,
      direction: direction,
    );
  }

  @override
  bool shouldReclip(covariant SingleSlantedClipper oldClipper) =>
      oldClipper.angleDegrees != angleDegrees ||
      oldClipper.radius != radius ||
      oldClipper.direction != direction;
}

/// Builds the path for a single-side slanted polygon with rounded corners.
Path buildSingleSlantedPath({
  required Size size,
  double angleDegrees = 7.0,
  double radius = 12.0,
  SlantDirection direction = SlantDirection.forward,
}) {
  final w = size.width;
  final h = size.height;

  // Clamped angle between 6.0° and 8.5°
  final clampedAngle = angleDegrees.clamp(5.0, 9.0);
  final angleRad = clampedAngle * math.pi / 180.0;
  final offset = (h * math.tan(angleRad)).clamp(4.0, w * 0.25);

  final double maxRadius = math.min(h / 3, 16.0).toDouble();
  final double r = radius.clamp(0.0, maxRadius);

  final Path path = Path();

  if (direction == SlantDirection.forward) {
    // Top-right corner is at (w, 0), Bottom-right corner is at (w - offset, h)
    // Slanted edge vector from top-right to bottom-right: (-offset, h)
    final slantLen = math.sqrt(offset * offset + h * h);
    final ux = -offset / slantLen;
    final uy = h / slantLen;

    // 1. Top-Left corner
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);

    // 2. Top Edge to Top-Right
    path.lineTo(w - r, 0);
    // Top-Right rounded corner into slanted edge
    path.quadraticBezierTo(w, 0, w + ux * r, uy * r);

    // 3. Slanted Edge down to Bottom-Right
    final brX = w - offset;
    final brY = h;
    path.lineTo(brX - ux * r, brY - uy * r);
    // Bottom-Right rounded corner into bottom edge
    path.quadraticBezierTo(brX, brY, brX - r, brY);

    // 4. Bottom Edge to Bottom-Left
    path.lineTo(r, h);
    // Bottom-Left rounded corner
    path.quadraticBezierTo(0, h, 0, h - r);

    // 5. Left Edge back to Top-Left
    path.lineTo(0, r);
    path.close();
  } else {
    // Backward slant: Top-right is at (w - offset, 0), Bottom-right is at (w, h)
    final slantLen = math.sqrt(offset * offset + h * h);
    final ux = offset / slantLen;
    final uy = h / slantLen;

    // 1. Top-Left corner
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);

    // 2. Top Edge to Top-Right
    final trX = w - offset;
    path.lineTo(trX - r, 0);
    path.quadraticBezierTo(trX, 0, trX + ux * r, uy * r);

    // 3. Slanted Edge down to Bottom-Right
    path.lineTo(w - ux * r, h - uy * r);
    path.quadraticBezierTo(w, h, w - r, h);

    // 4. Bottom Edge to Bottom-Left
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);

    // 5. Left Edge back to Top-Left
    path.lineTo(0, r);
    path.close();
  }

  return path;
}

/// CustomPainter that renders drop shadow, gradient fill, and perimeter border
/// along the single 6°–8° slanted path.
class SingleSlantedFramePainter extends CustomPainter {
  final List<Color> colors;
  final Color borderColor;
  final double borderWidth;
  final double angleDegrees;
  final double radius;
  final SlantDirection direction;
  final List<BoxShadow>? shadows;

  const SingleSlantedFramePainter({
    required this.colors,
    required this.borderColor,
    this.borderWidth = 1.8,
    this.angleDegrees = 7.0,
    this.radius = 12.0,
    this.direction = SlantDirection.forward,
    this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildSingleSlantedPath(
      size: size,
      angleDegrees: angleDegrees,
      radius: radius,
      direction: direction,
    );

    // Draw Shadows
    if (shadows != null && shadows!.isNotEmpty) {
      for (final shadow in shadows!) {
        final shadowPaint = Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
        canvas.save();
        canvas.translate(shadow.offset.dx, shadow.offset.dy);
        canvas.drawPath(path, shadowPaint);
        canvas.restore();
      }
    } else {
      // Default sleek dark shadow
      final shadowPaint = Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.save();
      canvas.translate(0, 5);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }

    // Draw Background Gradient Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw Crisp Border Stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SingleSlantedFramePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.angleDegrees != angleDegrees ||
      oldDelegate.radius != radius ||
      oldDelegate.direction != direction;
}
