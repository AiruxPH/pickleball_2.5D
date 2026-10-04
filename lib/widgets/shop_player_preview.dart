import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/character_renderer.dart';
import '../models/player.dart';
import '../models/shop_items.dart';
import '../utils/game_math.dart';

/// ─────────────────────────────────────────────────────────────
/// ShopPlayerPreview — High-detail Animated Athlete Preview
/// Renders tournament player character skins on Canvas with dynamic
/// idle breathing sway, ready-stance bounce, and authentic gear.
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

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: _PlayerCanvasPainter(
              skin: widget.playerSkin,
              animTime: t,
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

    // Tier Aura Glow
    final auraPaint = Paint()
      ..color = skin.tier.glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(const Offset(0, -10), 38, auraPaint);

    // High-fidelity Articulated Athlete with dynamic idle breathing & ready bounce
    final dummyPlayer = Player(
      startPosition: Vec3(0, 0, 0),
      isHuman: true,
    )
      ..animTimer = animTime * math.pi * 2
      ..runBlend = 0.0
      ..legCycleTimer = 0.0
      ..smoothedLean = math.sin(animTime * math.pi * 2) * 0.04;

    CharacterRenderer.drawPlayer(
      canvas: canvas,
      player: dummyPlayer,
      cam: null,
      isLowEnd: false,
      showShadow: true,
      equippedSkin: skin,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlayerCanvasPainter oldDelegate) {
    return oldDelegate.skin != skin || oldDelegate.animTime != animTime;
  }
}
