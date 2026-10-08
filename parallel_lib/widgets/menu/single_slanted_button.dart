import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'single_slanted_clipper.dart';
import 'shine_sweep.dart';
import 'menu_pressable.dart';

/// ─────────────────────────────────────────────────────────────
/// SingleSlantedButton — High-Impact Athletic CTA Button
///
/// Matches the Main Menu PLAY Tile:
/// - Single-side 7.0° angle on the right edge
/// - Upright Orbitron typography
/// - Light shine sweep on hover/focus & periodic pulse
/// - Snappy scale-up micro-animation on press (1.035)
/// - Top glass gloss reflection
/// ─────────────────────────────────────────────────────────────

class SingleSlantedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final List<Color>? colors;
  final Color? borderColor;
  final Color textColor;
  final double height;
  final double radius;
  final double angleDegrees;
  final double fontSize;
  final Color? shineColor;
  final bool autoPeriodic;

  const SingleSlantedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.colors,
    this.borderColor,
    this.textColor = const Color(0xFF200F00),
    this.height = 54.0,
    this.radius = 12.0,
    this.angleDegrees = 7.0,
    this.fontSize = 20.0,
    this.shineColor,
    this.autoPeriodic = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColors = colors ??
        const [
          Color(0xFFFFD23F),
          Color(0xFFFFB300),
          Color(0xFFF08C00),
        ];
    final effectiveBorder = borderColor ?? const Color(0xFFFFE48A);

    return MenuPressable(
      onTap: onTap,
      pressedScale: 1.035, // Quick scale-up feedback matching PlayTile
      child: ShineSweep(
        autoPeriodic: autoPeriodic,
        periodicInterval: const Duration(seconds: 5),
        shineColor: shineColor ?? const Color(0xFFFFF7D6),
        clipper: SingleSlantedClipper(
          angleDegrees: angleDegrees,
          radius: radius,
          direction: SlantDirection.forward,
        ),
        child: SizedBox(
          height: height,
          child: CustomPaint(
            painter: SingleSlantedFramePainter(
              colors: effectiveColors,
              borderColor: effectiveBorder,
              borderWidth: 2.0,
              angleDegrees: angleDegrees,
              radius: radius,
              direction: SlantDirection.forward,
            ),
            child: ClipPath(
              clipper: SingleSlantedClipper(
                angleDegrees: angleDegrees,
                radius: radius,
                direction: SlantDirection.forward,
              ),
              child: Stack(
                children: [
                  // Top gloss highlight
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x40FFFFFF),
                              Color(0x05FFFFFF),
                              Color(0x00000000),
                              Color(0x28000000),
                            ],
                            stops: [0.0, 0.45, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: textColor, size: fontSize * 1.2),
                              const SizedBox(width: 8.0),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: AppFonts.orbitron,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(45),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
