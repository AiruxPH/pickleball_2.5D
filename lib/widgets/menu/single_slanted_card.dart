import 'package:flutter/material.dart';
import 'single_slanted_clipper.dart';
import 'shine_sweep.dart';
import 'menu_pressable.dart';

/// ─────────────────────────────────────────────────────────────
/// SingleSlantedCard — Cohesive Athletic Frame for Game UIs
///
/// Matches the Main Menu tiles:
/// - 7.0° subtle athletic angle on the right edge only
/// - Left, top, and bottom edges remain rectangular
/// - Child content (text, icons) kept strictly upright with zero skew
/// - Light shine sweep on hover/focus & periodic pulse
/// - Snappy scale-up micro-animation on press (1.03)
/// - Metallic / glass top gloss highlight
/// ─────────────────────────────────────────────────────────────

class SingleSlantedCard extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final Color? borderColor;
  final double borderWidth;
  final double angleDegrees;
  final double radius;
  final SlantDirection direction;
  final VoidCallback? onTap;
  final bool enableShine;
  final bool enableGloss;
  final double pressedScale;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  const SingleSlantedCard({
    super.key,
    required this.child,
    this.colors,
    this.borderColor,
    this.borderWidth = 1.8,
    this.angleDegrees = 7.0,
    this.radius = 12.0,
    this.direction = SlantDirection.forward,
    this.onTap,
    this.enableShine = true,
    this.enableGloss = true,
    this.pressedScale = 1.03,
    this.padding,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColors = colors ??
        const [
          Color(0xE60E1E38),
          Color(0xD90A172D),
          Color(0xCC061022),
        ];
    final effectiveBorder = borderColor ?? const Color(0xFF1E3A66);

    Widget cardContent = CustomPaint(
      painter: SingleSlantedFramePainter(
        colors: effectiveColors,
        borderColor: effectiveBorder,
        borderWidth: borderWidth,
        angleDegrees: angleDegrees,
        radius: radius,
        direction: direction,
        shadows: shadows,
      ),
      child: ClipPath(
        clipper: SingleSlantedClipper(
          angleDegrees: angleDegrees,
          radius: radius,
          direction: direction,
        ),
        child: Stack(
          children: [
            if (enableGloss)
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x33FFFFFF),
                          Color(0x00FFFFFF),
                          Color(0x00000000),
                          Color(0x22000000),
                        ],
                        stops: [0.0, 0.45, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding ?? const EdgeInsets.all(12.0),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (enableShine) {
      cardContent = ShineSweep(child: cardContent);
    }

    if (onTap != null) {
      return MenuPressable(
        onTap: onTap!,
        pressedScale: pressedScale,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
