import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/shop_items.dart';

/// ─────────────────────────────────────────────────────────────
/// ShopPlayerPreview — High-detail Animated Athlete Preview
/// Renders tournament player character skins on Canvas
/// ─────────────────────────────────────────────────────────────

class ShopPlayerPreview extends StatefulWidget {
  final PlayerSkinItem playerSkin;
  final double width;
  final double height;
  final bool isInteractive;

  const ShopPlayerPreview({
    super.key,
    required this.playerSkin,
    this.width = 180,
    this.height = 240,
    this.isInteractive = true,
  });

  @override
  State<ShopPlayerPreview> createState() => _ShopPlayerPreviewState();
}

class _ShopPlayerPreviewState extends State<ShopPlayerPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
        final bounce = math.sin(t * math.pi * 2) * 4.0;

        return Transform.translate(
          offset: Offset(0, bounce),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _PlayerCanvasPainter(
                skin: widget.playerSkin,
                animTime: t,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerCanvasPainter extends CustomPainter {
  final PlayerSkinItem skin;
  final double animTime;

  _PlayerCanvasPainter({
    required this.skin,
    required this.animTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    final scale = math.min(size.width / 140, size.height / 190) * 1.65;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    // ── 0. Back Glow & Contact Shadow ─────────────────────────
    final auraPaint = Paint()
      ..color = skin.tier.glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(const Offset(0, -10), 38, auraPaint);

    // Court shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 36), width: 44, height: 12),
      Paint()
        ..color = Colors.black.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── 1. Athletic Legs & Shoes ──────────────────────────────
    _drawLeg(canvas, -8, 0.0);
    _drawLeg(canvas, 8, 0.0);

    // ── 2. Torso / Sports Jersey ──────────────────────────────
    final torsoRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-13, -26, 26, 28),
      const Radius.circular(5.5),
    );

    // Performance jersey gradient
    canvas.drawRRect(
      torsoRect,
      Paint()
        ..shader = LinearGradient(
          colors: [skin.jerseyLight, skin.jerseyMain],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(-13, -26, 26, 28)),
    );

    // Athletic side speed stripes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -24, 3, 24),
        const Radius.circular(1.5),
      ),
      Paint()..color = skin.jerseyAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, -24, 3, 24),
        const Radius.circular(1.5),
      ),
      Paint()..color = skin.jerseyAccent,
    );

    // V-neck sports collar
    final collarPath = Path()
      ..moveTo(-6, -26)
      ..lineTo(0, -18)
      ..lineTo(6, -26);
    canvas.drawPath(
      collarPath,
      Paint()
        ..color = skin.jerseyAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // Chest number / star emblem
    canvas.drawCircle(
      const Offset(0, -12),
      4.5,
      Paint()..color = Colors.white.withAlpha(70),
    );

    // ── 3. Arms ───────────────────────────────────────────────
    _drawArm(canvas, -13, true);
    _drawArm(canvas, 13, false);

    // ── 4. Neck & Head ────────────────────────────────────────
    // Neck
    canvas.drawRect(
      const Rect.fromLTWH(-4.5, -31, 9, 6),
      Paint()..color = skin.skinColor,
    );

    // Head
    canvas.drawCircle(
      const Offset(0, -38),
      12.0,
      Paint()..color = skin.skinColor,
    );

    // Headwear / Accessories
    if (skin.hasSunglasses) {
      // Sunglasses
      final glassRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -42, 20, 6),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(glassRect, Paint()..color = const Color(0xFF0F172A));
      // Lens shine
      canvas.drawLine(
        const Offset(-7, -40),
        const Offset(-2, -40),
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 1.4,
      );
      canvas.drawLine(
        const Offset(3, -40),
        const Offset(8, -40),
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 1.4,
      );
    }

    if (skin.hasVisor) {
      // Visor crown
      canvas.drawArc(
        const Rect.fromLTWH(-12, -50, 24, 16),
        math.pi,
        math.pi,
        true,
        Paint()..color = skin.jerseyMain,
      );
      // Visor brim
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-14, -45, 28, 4),
          const Radius.circular(2),
        ),
        Paint()..color = skin.jerseyAccent,
      );
    } else {
      // Athletic Cap
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -50, 24, 15),
          const Radius.circular(7),
        ),
        Paint()..color = skin.jerseyMain,
      );
      // Cap button
      canvas.drawCircle(
        const Offset(0, -50),
        1.8,
        Paint()..color = skin.jerseyAccent,
      );
    }

    canvas.restore();
  }

  void _drawLeg(Canvas canvas, double xOffset, double angle) {
    canvas.save();
    canvas.translate(xOffset, 2);

    // Performance shorts
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5.5, 0, 11, 14),
        const Radius.circular(2.5),
      ),
      Paint()..color = skin.shortsColor,
    );

    // Athletic leg / calf
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.0, 13, 8, 14),
        const Radius.circular(2.5),
      ),
      Paint()..color = skin.skinColor,
    );

    // Pro tennis shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6.5, 26, 13, 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFF8FAFC),
    );
    // Colored sports stripe
    canvas.drawRect(
      const Rect.fromLTWH(-5.5, 28, 11, 2.5),
      Paint()..color = skin.shoeAccent,
    );
    // Rubber outsole grip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6.5, 32, 13, 3),
        const Radius.circular(1.2),
      ),
      Paint()..color = const Color(0xFF334155),
    );

    canvas.restore();
  }

  void _drawArm(Canvas canvas, double xOffset, bool isLeft) {
    canvas.save();
    canvas.translate(xOffset, -20);

    // Sleeve
    canvas.drawCircle(Offset.zero, 5.0, Paint()..color = skin.jerseyMain);

    // Upper arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(isLeft ? -4.5 : 0, 0, 4.5, 16),
        const Radius.circular(2.5),
      ),
      Paint()..color = skin.skinColor,
    );

    // Wristband
    canvas.drawRect(
      Rect.fromLTWH(isLeft ? -4.8 : -0.2, 12, 5.0, 3.2),
      Paint()..color = skin.jerseyAccent,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlayerCanvasPainter oldDelegate) {
    return oldDelegate.skin != skin || oldDelegate.animTime != animTime;
  }
}
