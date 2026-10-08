import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// ParallaxBall — Interactive Tilt & Parallax Ball Art
/// Reacts to mouse cursor hover position with 3D perspective tilt
/// and parallax displacement, combined with smooth idle floating.
/// ─────────────────────────────────────────────────────────────

class ParallaxBall extends StatelessWidget {
  final double size;
  final Animation<double> idle;
  final Offset hoverNormalized; // dx: -1.0..1.0, dy: -1.0..1.0
  final bool isHovered;

  const ParallaxBall({
    super.key,
    required this.size,
    required this.idle,
    required this.hoverNormalized,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: idle,
      builder: (context, child) {
        // Idle breathing & gentle roll
        final idleRoll = math.sin(idle.value * math.pi * 2) * 0.18;
        final idleBob = math.cos(idle.value * math.pi * 2) * (size * 0.025);

        // Parallax offset
        final targetPx = hoverNormalized.dx * (size * 0.08);
        final targetPy = hoverNormalized.dy * (size * 0.06) + idleBob;

        // 3D Perspective Tilt angles (radians)
        final tiltX = -hoverNormalized.dy * 0.15; // pitch
        final tiltY = hoverNormalized.dx * 0.18;  // yaw
        final tiltZ = idleRoll + hoverNormalized.dx * 0.08; // roll

        final transformMatrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0018) // perspective factor
          ..rotateX(tiltX)
          ..rotateY(tiltY)
          ..rotateZ(tiltZ);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Dynamic Contact Shadow
              Positioned(
                bottom: size * 0.04 - targetPy * 0.35,
                left: size * 0.15 - targetPx * 0.35,
                right: size * 0.15 + targetPx * 0.35,
                height: size * 0.16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(size * 0.4, size * 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x55000000),
                        blurRadius: isHovered ? 14 : 9,
                        spreadRadius: isHovered ? 1 : 0,
                      ),
                    ],
                  ),
                ),
              ),

              // 3D Tilted and Parallaxed Ball
              Transform.translate(
                offset: Offset(targetPx, targetPy),
                child: Transform(
                  alignment: Alignment.center,
                  transform: transformMatrix,
                  child: Image.asset(
                    'assets/images/menu/play_ball.png',
                    width: size,
                    height: size,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
