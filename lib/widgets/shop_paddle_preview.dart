import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/shop_items.dart';

/// ─────────────────────────────────────────────────────────────
/// ShopPaddlePreview — product-shot style paddle render
///
/// Drawn like a real pickleball paddle photographed in a studio:
///   • Real proportions (elongated blade, throat, 5" handle)
///   • Visible core thickness that shifts as the paddle turns
///   • Rubber edge guard, carbon-fibre weave, printed face graphics
///   • Wrapped overgrip, throat collar and flared butt cap
///   • Soft-box reflection + contact shadow (no glow / sparkles)
/// ─────────────────────────────────────────────────────────────

class ShopPaddlePreview extends StatefulWidget {
  final PaddleItem paddle;
  final double width;
  final double height;
  final bool isInteractive;

  /// Kept for API compatibility; the realistic render has no particles.
  final bool showParticles;

  const ShopPaddlePreview({
    super.key,
    required this.paddle,
    this.width = 180,
    this.height = 240,
    this.isInteractive = true,
    this.showParticles = true,
  });

  @override
  State<ShopPaddlePreview> createState() => _ShopPaddlePreviewState();
}

class _ShopPaddlePreviewState extends State<ShopPaddlePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final t = _animCtrl.value;
        final floatY = math.sin(t * math.pi * 2) * 2.5;
        final turn = math.sin(t * math.pi * 2) * 0.16 + _tiltY;

        return MouseRegion(
          onHover: (event) {
            if (!widget.isInteractive) return;
            final center = Offset(widget.width / 2, widget.height / 2);
            final rel = event.localPosition - center;
            setState(() {
              _tiltX = (rel.dy / (widget.height / 2)).clamp(-0.18, 0.18);
              _tiltY = (-rel.dx / (widget.width / 2)).clamp(-0.25, 0.25);
            });
          },
          onExit: (_) {
            if (!widget.isInteractive) return;
            setState(() {
              _tiltX = 0;
              _tiltY = 0;
            });
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _PaddleCanvasPainter(
                paddle: widget.paddle,
                turn: turn,
                tiltX: _tiltX,
                floatY: floatY,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaddleCanvasPainter extends CustomPainter {
  final PaddleItem paddle;

  /// Rotation about the vertical axis (radians). Drives perspective,
  /// which side of the core is visible, and where the reflection sits.
  final double turn;
  final double tiltX;
  final double floatY;

  _PaddleCanvasPainter({
    required this.paddle,
    required this.turn,
    required this.tiltX,
    required this.floatY,
  });

  // ── Geometry (design units; paddle is ~16" x 7.6") ──────────
  static const double faceW = 64;
  static const double faceTop = -84;
  static const double faceBottom = 14;
  static const double throatBottom = 24;
  static const double handleW = 15.5;
  static const double handleBottom = 70;

  static Color _shade(Color c, double amount) => amount >= 0
      ? Color.lerp(c, Colors.white, amount)!
      : Color.lerp(c, Colors.black, -amount)!;

  Path _facePath() {
    const l = -faceW / 2, r = faceW / 2;
    return Path()
      ..addRRect(RRect.fromRectAndCorners(
        const Rect.fromLTRB(l, faceTop, r, faceBottom),
        topLeft: const Radius.elliptical(24, 26),
        topRight: const Radius.elliptical(24, 26),
        bottomLeft: const Radius.circular(13),
        bottomRight: const Radius.circular(13),
      ));
  }

  Path _throatPath() {
    return Path()
      ..moveTo(-15, faceBottom - 4)
      ..lineTo(15, faceBottom - 4)
      ..quadraticBezierTo(9, faceBottom + 4, handleW / 2 + 0.5, throatBottom)
      ..lineTo(-handleW / 2 - 0.5, throatBottom)
      ..quadraticBezierTo(-9, faceBottom + 4, -15, faceBottom - 4)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 92, size.height / 172);
    final detailed = s >= 0.7; // enough pixels for weave / wordmark

    // ── Contact shadow on the "table" (stays put while paddle floats) ──
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 80 * s);
    canvas.scale(s * 38 * (1 - floatY * 0.01), s * 6.5);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x66000000), Color(0x22000000), Color(0x00000000)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + floatY - 4 * s);
    // Perspective turn: apply as a real 3D transform around the paddle centre
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0022 / s)
      ..rotateX(tiltX)
      ..rotateY(turn)
      ..rotateZ(-0.08);
    canvas.transform(m.storage);
    canvas.scale(s);

    // Core thickness (16 mm) seen on the side the paddle turns away from
    final edgeDx = (-turn * 16).clamp(-3.5, 3.5);
    final coreOffset = Offset(edgeDx == 0 ? 0.001 : edgeDx, 1.2);

    _drawHandle(canvas, detailed);
    _drawBlade(canvas, coreOffset, detailed);

    canvas.restore();
  }

  // ── Handle: overgrip, collar, butt cap ─────────────────────
  void _drawHandle(Canvas canvas, bool detailed) {
    const hl = -handleW / 2, hr = handleW / 2;
    const gripTop = throatBottom - 1;
    const gripBottom = handleBottom - 6;
    final gripRect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(hl, gripTop, hr, gripBottom),
      const Radius.circular(3),
    );
    final grip = paddle.gripTapeColor;

    // Cylindrical shading of the wrapped grip
    canvas.drawRRect(
      gripRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _shade(grip, -0.45),
            _shade(grip, 0.15),
            grip,
            _shade(grip, -0.25),
            _shade(grip, -0.55),
          ],
          stops: const [0.0, 0.28, 0.5, 0.8, 1.0],
        ).createShader(gripRect.outerRect),
    );

    // Overgrip wrap: overlapping diagonal bands (seam shadow + lip highlight)
    canvas.save();
    canvas.clipRRect(gripRect);
    final seam = Paint()
      ..color = Colors.black.withAlpha(detailed ? 70 : 55)
      ..strokeWidth = detailed ? 1.1 : 1.6;
    final lip = Paint()
      ..color = Colors.white.withAlpha(detailed ? 70 : 0)
      ..strokeWidth = 0.6;
    for (double y = gripTop + 2; y < gripBottom + 6; y += detailed ? 4.2 : 6.0) {
      canvas.drawLine(Offset(hl - 1, y + 3.2), Offset(hr + 1, y - 2.2), seam);
      if (detailed) {
        canvas.drawLine(Offset(hl - 1, y + 4.0), Offset(hr + 1, y - 1.4), lip);
      }
    }
    canvas.restore();

    // Throat collar (moulded plastic sleeve)
    final collar = paddle.gripCollarColor;
    final collarRect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(hl - 1.2, throatBottom - 3, hr + 1.2, throatBottom + 3.5),
      const Radius.circular(1.6),
    );
    canvas.drawRRect(collarRect, _cylinder(collar, collarRect.outerRect));

    // Flared butt cap
    final cap = Path()
      ..moveTo(hl - 0.6, gripBottom - 1)
      ..lineTo(hr + 0.6, gripBottom - 1)
      ..quadraticBezierTo(hr + 2.6, handleBottom - 2, hr + 1.8, handleBottom)
      ..lineTo(hl - 1.8, handleBottom)
      ..quadraticBezierTo(hl - 2.6, handleBottom - 2, hl - 0.6, gripBottom - 1)
      ..close();
    canvas.drawPath(cap, _cylinder(collar, cap.getBounds()));
    // Cap end face (seen slightly from below)
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(0, handleBottom), width: handleW + 3.6, height: 2.4),
      Paint()..color = _shade(collar, -0.35),
    );
    if (detailed) {
      canvas.drawCircle(
        const Offset(0, handleBottom - 3.2),
        1.5,
        Paint()..color = paddle.rimColor.withAlpha(200),
      );
    }
  }

  Paint _cylinder(Color c, Rect bounds) => Paint()
    ..shader = LinearGradient(
      colors: [
        _shade(c, -0.5),
        _shade(c, 0.35),
        c,
        _shade(c, -0.55),
      ],
      stops: const [0.0, 0.3, 0.55, 1.0],
    ).createShader(bounds);

  // ── Blade: core edge, face, graphics, guard, reflection ───
  void _drawBlade(Canvas canvas, Offset coreOffset, bool detailed) {
    final face = _facePath();
    final throat = _throatPath();
    final bounds = face.getBounds();

    // 1. Honeycomb core side-wall (thickness), dark and slightly lit
    final side = face.shift(coreOffset);
    canvas.drawPath(side, Paint()..color = _shade(paddle.rimColor, -0.72));
    canvas.drawPath(throat.shift(coreOffset), Paint()..color = _shade(paddle.bladeColor2, -0.7));

    // 2. Throat (same laminate as the face)
    canvas.drawPath(
      throat,
      Paint()
        ..shader = LinearGradient(
          colors: [_shade(paddle.bladeColor2, -0.35), paddle.bladeColor2, _shade(paddle.bladeColor2, -0.45)],
        ).createShader(throat.getBounds()),
    );

    // 3. Face base colour
    canvas.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          colors: [paddle.bladeColor1, paddle.bladeColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(face);

    // 4. Raw carbon-fibre twill weave
    if (detailed) _drawCarbonWeave(canvas, bounds);

    // 5. Printed graphics
    _drawPrint(canvas, bounds, detailed);

    // 6. Matte falloff toward the edges (reads as a real, slightly curved surface)
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.15, -0.2),
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x55000000)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(bounds),
    );

    // 7. Soft-box studio reflection — slides across as the paddle turns
    final shift = (turn * 90).clamp(-40.0, 40.0);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x00FFFFFF),
            Color(0x2EFFFFFF),
            Color(0x10FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.18, 0.32, 0.5],
        ).createShader(bounds.shift(Offset(shift - 8, shift * 0.5 - 10))),
    );
    canvas.restore();

    // 8. Rubber edge guard: dark body, lit top lip, inner seam
    final guardColor = paddle.rimColor;
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..color = _shade(guardColor, -0.35),
    );
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_shade(guardColor, 0.45), guardColor, _shade(guardColor, -0.5)],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bounds),
    );
    // Seam where the guard meets the face
    canvas.save();
    canvas.clipPath(face);
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2
        ..color = const Color(0x40000000),
    );
    canvas.restore();
  }

  void _drawCarbonWeave(Canvas canvas, Rect b) {
    // 2x2 twill: alternating short diagonal tows
    final a = Paint()..color = Colors.white.withAlpha(14);
    final d = Paint()..color = Colors.black.withAlpha(26);
    const step = 3.0;
    int row = 0;
    for (double y = b.top; y < b.bottom; y += step, row++) {
      int col = 0;
      for (double x = b.left + (row % 2) * step; x < b.right; x += step * 2, col++) {
        canvas.drawRect(Rect.fromLTWH(x, y, step, step * 0.9), (col + row) % 2 == 0 ? a : d);
      }
    }
  }

  void _drawPrint(Canvas canvas, Rect b, bool detailed) {
    final ink = paddle.chevronColor;

    switch (paddle.patternType) {
      case 'lightning':
        // Bold diagonal slash graphic running corner to throat
        final slash = Path()
          ..moveTo(b.right + 4, b.top + 10)
          ..lineTo(b.right + 4, b.top + 30)
          ..lineTo(b.left + 22, b.bottom - 18)
          ..lineTo(b.left + 30, b.bottom - 34)
          ..lineTo(b.left - 4, b.bottom + 4)
          ..lineTo(b.left - 4, b.bottom - 14)
          ..lineTo(b.left + 14, b.bottom - 40)
          ..lineTo(b.left + 8, b.bottom - 26)
          ..close();
        canvas.drawPath(slash, Paint()..color = ink.withAlpha(215));
        canvas.drawPath(
          slash,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = Colors.white.withAlpha(110),
        );
        break;

      case 'honeycomb':
        // Hex grid that fades out toward the tip (as if printed over the core)
        for (double y = b.bottom - 8; y > b.top; y -= 9.5) {
          final fade = ((y - b.top) / b.height).clamp(0.0, 1.0);
          final p = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = ink.withAlpha((20 + 120 * fade * fade).round());
          final odd = ((b.bottom - y) / 9.5).round().isOdd;
          for (double x = b.left + (odd ? 5.5 : 0); x < b.right + 6; x += 11) {
            _hexagon(canvas, Offset(x, y), 5.4, p);
          }
        }
        break;

      case 'rings':
        // Printed sweet-spot target, offset toward the upper face
        final c = Offset(0, b.top + b.height * 0.42);
        for (final r in [30.0, 21.0, 12.0]) {
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r == 30 ? 3.2 : 1.6
              ..color = ink.withAlpha(r == 30 ? 150 : 110),
          );
        }
        canvas.drawCircle(c, 4, Paint()..color = ink.withAlpha(220));
        break;

      case 'chevrons':
      default:
        // Stacked printed chevrons rising from the throat
        final chevron = Paint()..color = ink.withAlpha(170);
        for (int i = 0; i < 3; i++) {
          final top = b.bottom - 30 - i * 15.0;
          final path = Path()
            ..moveTo(b.left + 8, top)
            ..lineTo(0, top + 11)
            ..lineTo(b.right - 8, top)
            ..lineTo(b.right - 8, top + 5)
            ..lineTo(0, top + 16)
            ..lineTo(b.left + 8, top + 5)
            ..close();
          chevron.color = ink.withAlpha(190 - i * 55);
          canvas.drawPath(path, chevron);
        }
        break;
    }

    // Accent pin-stripe following the guard
    canvas.drawPath(
      _facePath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = ink.withAlpha(120)
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = null,
    );

    // Printed wordmark near the throat + spec line
    if (detailed) {
      final brand = TextPainter(
        text: const TextSpan(
          text: 'CHAMPIONS',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xE6FFFFFF),
            fontSize: 5.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      brand.paint(canvas, Offset(-brand.width / 2, b.bottom - 15));

      final spec = TextPainter(
        text: const TextSpan(
          text: '16MM  CARBON',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0x8CFFFFFF),
            fontSize: 2.8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      spec.paint(canvas, Offset(-spec.width / 2, b.bottom - 8.5));
    }
  }

  void _hexagon(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 3 * i + math.pi / 6;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PaddleCanvasPainter old) {
    return old.paddle != paddle ||
        old.turn != turn ||
        old.tiltX != tiltX ||
        old.floatY != floatY;
  }
}
