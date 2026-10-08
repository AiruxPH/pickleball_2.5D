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
    final key = widget.playerSkin.spriteKey;
    if (key != null) {
      return AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          // Gentle idle bob
          final bob = math.sin(_animCtrl.value * math.pi * 2) * 2.5;
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.width * 0.55,
                  height: widget.height * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.playerSkin.tier.glowColor,
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, bob),
                  child: Image.asset(
                    'assets/images/characters/shop/${key}_main.png',
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
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

/// Front / Right / Back / Left views of a shop character.
class ShopCharacterViews extends StatelessWidget {
  final PlayerSkinItem skin;
  final double height;

  const ShopCharacterViews({super.key, required this.skin, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final key = skin.spriteKey;
    if (key == null) return const SizedBox.shrink();
    const views = ['front', 'right', 'back', 'left'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final v in views)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/characters/shop/${key}_$v.png',
                height: height,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 2),
              Text(
                v[0].toUpperCase() + v.substring(1),
                style: const TextStyle(fontSize: 8, color: Colors.white54),
              ),
            ],
          ),
      ],
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
