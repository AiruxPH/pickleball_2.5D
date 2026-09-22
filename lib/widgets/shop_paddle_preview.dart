import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/shop_items.dart';

/// ─────────────────────────────────────────────────────────────
/// ShopPaddlePreview — High-detail 2D/3D Animated Paddle Preview
/// Renders authentic tournament pickleball paddle graphics
/// ─────────────────────────────────────────────────────────────

class ShopPaddlePreview extends StatefulWidget {
  final PaddleItem paddle;
  final double width;
  final double height;
  final bool isInteractive;
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
      duration: const Duration(seconds: 4),
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
        final floatY = math.sin(t * math.pi * 2) * 6.0;
        final wobbleAngle = math.sin(t * math.pi * 2) * 0.08;

        return MouseRegion(
          onHover: (event) {
            if (!widget.isInteractive) return;
            final center = Offset(widget.width / 2, widget.height / 2);
            final rel = event.localPosition - center;
            setState(() {
              _tiltX = (rel.dy / (widget.height / 2)).clamp(-0.2, 0.2);
              _tiltY = (-rel.dx / (widget.width / 2)).clamp(-0.2, 0.2);
            });
          },
          onExit: (_) {
            if (!widget.isInteractive) return;
            setState(() {
              _tiltX = 0;
              _tiltY = 0;
            });
          },
          child: Transform.translate(
            offset: Offset(0, floatY),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018) // Perspective
                ..rotateX(_tiltX)
                ..rotateY(_tiltY + wobbleAngle)
                ..rotateZ(-0.06),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: CustomPaint(
                  painter: _PaddleCanvasPainter(
                    paddle: widget.paddle,
                    animTime: t,
                    showParticles: widget.showParticles,
                  ),
                ),
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
  final double animTime;
  final bool showParticles;

  _PaddleCanvasPainter({
    required this.paddle,
    required this.animTime,
    required this.showParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Scale reference size: base design is 120w x 180h
    final scale = math.min(size.width / 130, size.height / 190);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    // ── 0. Back Glow Aura ─────────────────────────────────────
    final glowPaint = Paint()
      ..color = paddle.tier.glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawCircle(const Offset(0, -15), 48, glowPaint);

    // ── 0b. Particle sparkles around paddle ───────────────────
    if (showParticles && paddle.tier != ItemTier.common) {
      final particlePaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 7; i++) {
        final angle = (i * 0.9) + animTime * math.pi * 2;
        final radius = 55.0 + math.sin(animTime * 6.0 + i) * 12.0;
        final px = math.cos(angle) * radius;
        final py = math.sin(angle) * (radius * 0.9) - 15;
        final alpha = ((math.sin(animTime * 4.0 + i * 1.5) + 1) / 2 * 200).toInt();

        particlePaint.color = paddle.tier.color.withAlpha(alpha.clamp(20, 240));
        canvas.drawCircle(Offset(px, py), (i % 2 == 0) ? 2.5 : 1.8, particlePaint);
      }
    }

    // ── 1. Grip Handle ────────────────────────────────────────
    // Handle bounds
    const handleWidth = 14.0;
    const handleHeight = 44.0;
    const handleTop = 32.0;

    final handleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-handleWidth / 2, handleTop, handleWidth, handleHeight),
      const Radius.circular(5.0),
    );

    // Handle base fill
    canvas.drawRRect(
      handleRect,
      Paint()..color = paddle.gripTapeColor,
    );

    // Ribbed spiral wrap lines
    final gripWrapPaint = Paint()
      ..color = Colors.black.withAlpha(55)
      ..strokeWidth = 2.0;
    for (int i = 1; i < 6; i++) {
      final y = handleTop + i * 7.0;
      canvas.drawLine(
        Offset(-handleWidth / 2, y),
        Offset(handleWidth / 2, y - 2),
        gripWrapPaint,
      );
    }

    // Rubber grip collar ring at throat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-handleWidth / 2 - 1.5, handleTop - 2, handleWidth + 3, 5),
        const Radius.circular(2),
      ),
      Paint()..color = paddle.gripCollarColor,
    );

    // Butt cap at bottom
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-handleWidth / 2 - 2, handleTop + handleHeight - 4, handleWidth + 4, 6),
        const Radius.circular(3),
      ),
      Paint()..color = paddle.gripCollarColor,
    );

    // Butt cap emblem logo
    canvas.drawCircle(
      const Offset(0, 75.0),
      2.5,
      Paint()..color = paddle.rimColor,
    );

    // ── 2. Paddle Face (Modern Elongated Blade) ────────────────
    const faceWidth = 76.0;
    const faceHeight = 98.0;
    const faceTop = -66.0;

    final faceRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-faceWidth / 2, faceTop, faceWidth, faceHeight),
      const Radius.circular(22.0),
    );

    // Subtle drop shadow under blade
    canvas.drawRRect(
      faceRect.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Blade Gradient Base
    canvas.drawRRect(
      faceRect,
      Paint()
        ..shader = LinearGradient(
          colors: [paddle.bladeColor1, paddle.bladeColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(faceRect.outerRect),
    );

    // ── 3. Pattern / Texture Overlay ──────────────────────────
    _drawPaddlePattern(canvas, faceRect);

    // ── 4. Edge Guard (Rim) with Tier Sheen ────────────────────
    final rimPaint = Paint()
      ..color = paddle.rimColor
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(faceRect, rimPaint);

    // Inner bevel highlight
    final innerRimPaint = Paint()
      ..color = Colors.white.withAlpha(45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(faceRect.deflate(2.2), innerRimPaint);

    // ── 5. Dynamic Light Shimmer Sweep ────────────────────────
    final shimmerOffset = (animTime * 2.2 - 0.6) * faceWidth * 2;
    canvas.save();
    canvas.clipRRect(faceRect);

    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(60),
          Colors.white.withAlpha(0),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromLTWH(
          -faceWidth + shimmerOffset,
          faceTop - 20,
          45,
          faceHeight + 40,
        ),
      );

    canvas.drawRect(faceRect.outerRect, sweepPaint);
    canvas.restore();

    canvas.restore();
  }

  void _drawPaddlePattern(Canvas canvas, RRect faceRect) {
    canvas.save();
    canvas.clipRRect(faceRect);

    final patternColor = paddle.chevronColor;

    switch (paddle.patternType) {
      case 'lightning':
        final p = Path();
        p.moveTo(-10, -50);
        p.lineTo(6, -20);
        p.lineTo(-4, -18);
        p.lineTo(12, 18);
        p.lineTo(-2, -8);
        p.lineTo(4, -10);
        p.close();

        canvas.drawPath(
          p,
          Paint()
            ..color = patternColor.withAlpha(160)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
        );
        canvas.drawPath(
          p,
          Paint()
            ..color = Colors.white.withAlpha(200)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
        break;

      case 'honeycomb':
        final hexPaint = Paint()
          ..color = patternColor.withAlpha(65)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        const size = 11.0;
        for (double y = -50; y <= 20; y += 16) {
          for (double x = -26; x <= 26; x += 18) {
            final yOffset = ((x.toInt() ~/ 18) % 2 == 0) ? 8.0 : 0.0;
            _drawHexagon(canvas, Offset(x, y + yOffset), size, hexPaint);
          }
        }
        break;

      case 'rings':
        final ringPaint = Paint()
          ..color = patternColor.withAlpha(80)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(const Offset(0, -18), 16, ringPaint);
        canvas.drawCircle(const Offset(0, -18), 28, ringPaint);
        canvas.drawCircle(const Offset(0, -18), 40, ringPaint);

        // Center sweet spot dot
        canvas.drawCircle(
          const Offset(0, -18),
          4.5,
          Paint()..color = patternColor,
        );
        break;

      case 'chevrons':
      default:
        final chevronPaint = Paint()
          ..color = patternColor.withAlpha(140)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < 3; i++) {
          final dy = -34.0 + i * 18.0;
          canvas.drawLine(Offset(-22, dy), Offset(0, dy + 14), chevronPaint);
          canvas.drawLine(Offset(22, dy), Offset(0, dy + 14), chevronPaint);
        }
        break;
    }

    // Tournament brand typography emblem on face
    const textStyle = TextStyle(
      color: Colors.white60,
      fontSize: 6.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
      fontFamily: 'monospace',
    );
    const textSpan = TextSpan(text: 'PRO TOUR 2026', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 18));

    canvas.restore();
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PaddleCanvasPainter oldDelegate) {
    return oldDelegate.paddle != paddle ||
        oldDelegate.animTime != animTime ||
        oldDelegate.showParticles != showParticles;
  }
}
