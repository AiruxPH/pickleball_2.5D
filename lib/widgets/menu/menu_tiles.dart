import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'angular_frames.dart';
import 'menu_pressable.dart';
import 'parallax_ball.dart';

/// ─────────────────────────────────────────────────────────────
/// MenuTiles — Interactive Navigation Grid for Home Screen
/// Implements:
/// - Single-edge 6°–8° subtle athletic slant on one side only
/// - Text kept strictly upright with high-contrast typography
/// - Motion: Light shine sweep on hover or focus
/// - Motion: Quick snappy scale-up on press
/// - Motion: 3D perspective tilt & mouse parallax on the ball art
/// - Athletic forward-leaning activity & context badges
/// ─────────────────────────────────────────────────────────────

TextStyle _tileTitle(double size, {Color color = Colors.white}) => TextStyle(
      color: color,
      fontSize: size,
      fontFamily: AppFonts.orbitron,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
      height: 1.0,
      shadows: const [
        Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 3),
      ],
    );

TextStyle _tileSubtitle(double size, {Color color = const Color(0xE6FFFFFF)}) => TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );

/// Left-aligned text block that scales down as a whole if vertical space is constrained.
class FitColumn extends StatelessWidget {
  final List<Widget> children;
  const FitColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        width: c.maxWidth,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Glossy top highlight clipped to the single-slanted frame.
class TileGloss extends StatelessWidget {
  const TileGloss({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x38FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00000000),
                Color(0x26000000),
              ],
              stops: [0.0, 0.45, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// PlayTile — Primary Hero Action
/// Features:
/// - Single-side 7° subtle slant on right edge only (text strictly upright)
/// - Light shine sweep on hover/focus & periodic pulse
/// - Quick scale-up feedback on press
/// - 3D perspective tilt & mouse parallax on the ball art
/// ─────────────────────────────────────────────────────────────
class PlayTile extends StatefulWidget {
  final double ui;
  final Animation<double> idle;
  final VoidCallback onTap;

  const PlayTile({
    super.key,
    required this.ui,
    required this.idle,
    required this.onTap,
  });

  @override
  State<PlayTile> createState() => _PlayTileState();
}

class _PlayTileState extends State<PlayTile> {
  Offset _hoverNormalized = Offset.zero;
  bool _isHovered = false;

  void _onHover(Offset localPos, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final normX = ((localPos.dx / size.width) - 0.5) * 2.0;
    final normY = ((localPos.dy / size.height) - 0.5) * 2.0;
    setState(() {
      _hoverNormalized = Offset(normX.clamp(-1.0, 1.0), normY.clamp(-1.0, 1.0));
      _isHovered = true;
    });
  }

  void _onExit() {
    setState(() {
      _hoverNormalized = Offset.zero;
      _isHovered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = 16 * widget.ui;

    return MenuPressable(
      onTap: widget.onTap,
      pressedScale: 1.035, // Quick scale-up on press
      child: LayoutBuilder(
        builder: (context, c) {
          final ballSize = c.maxHeight * 0.82;

          return MouseRegion(
            onHover: (e) => _onHover(e.localPosition, Size(c.maxWidth, c.maxHeight)),
            onExit: (_) => _onExit(),
            child: ShineSweep(
              autoPeriodic: true,
              periodicInterval: const Duration(seconds: 6),
              shineColor: const Color(0xFFFFF7D6),
              child: CustomPaint(
                painter: SingleSlantedFramePainter(
                  colors: const [
                    Color(0xFFFFD23F),
                    Color(0xFFFFB300),
                    Color(0xFFF08C00),
                  ],
                  borderColor: const Color(0xFFFFE48A),
                  borderWidth: 2.2,
                  angleDegrees: 7.0, // 6° to 8° angle on right edge only
                  radius: radius,
                  direction: SlantDirection.forward,
                ),
                child: ClipPath(
                  clipper: SingleSlantedClipper(
                    angleDegrees: 7.0,
                    radius: radius,
                    direction: SlantDirection.forward,
                  ),
                  child: Stack(
                    children: [
                      // Net texture across the right half
                      Positioned.fill(
                        child: CustomPaint(painter: _NetTexturePainter()),
                      ),

                      // Motion: Interactive Parallax & 3D Tilt on the Ball Art
                      Positioned(
                        right: c.maxWidth * 0.08,
                        top: (c.maxHeight - ballSize) / 2 + 2 * widget.ui,
                        child: ParallaxBall(
                          size: ballSize,
                          idle: widget.idle,
                          hoverNormalized: _hoverNormalized,
                          isHovered: _isHovered,
                        ),
                      ),

                      // Soft dark vignette behind the text for perfect readability (H1)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: c.maxWidth * 0.65,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0x38000000),
                                Color(0x15000000),
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),

                      const TileGloss(),

                      // Text & Icon content: Kept strictly upright
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16 * widget.ui,
                          vertical: 10 * widget.ui,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8 * widget.ui),
                              decoration: ShapeDecoration(
                                shape: BeveledRectangleBorder(
                                  borderRadius: BorderRadius.circular(8 * widget.ui),
                                  side: BorderSide(
                                    color: const Color(0xFF1E1000).withAlpha(60),
                                    width: 1.5,
                                  ),
                                ),
                                color: const Color(0xFF1E1000).withAlpha(35),
                              ),
                              child: Icon(
                                Icons.sports_tennis_rounded,
                                color: const Color(0xFF261300),
                                size: math.min(42 * widget.ui, c.maxHeight * 0.45),
                              ),
                            ),
                            SizedBox(width: 14 * widget.ui),
                            Expanded(
                              child: FitColumn(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'PLAY',
                                        style: TextStyle(
                                          fontFamily: AppFonts.orbitron,
                                          fontSize: 38 * widget.ui,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF200F00),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      SizedBox(width: 8 * widget.ui),
                                      // Context Badge with Athletic Parallelogram Frame
                                      ParallelogramBadge(
                                        color: const Color(0xFF200F00),
                                        borderColor: const Color(0xFFFFD23F).withAlpha(140),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8 * widget.ui,
                                          vertical: 2.5 * widget.ui,
                                        ),
                                        child: Text(
                                          'QUICK MATCH',
                                          style: TextStyle(
                                            fontFamily: AppFonts.orbitron,
                                            fontSize: 8.5 * widget.ui,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFFFD23F),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (c.maxHeight > 80 * widget.ui) ...[
                                    SizedBox(height: 4 * widget.ui),
                                    Text(
                                      'Jump into a fast court rally and test your skills!',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5 * widget.ui,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF381D00),
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(6 * widget.ui),
                              decoration: ShapeDecoration(
                                shape: BeveledRectangleBorder(
                                  borderRadius: BorderRadius.circular(6 * widget.ui),
                                ),
                                color: const Color(0xFF200F00).withAlpha(40),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: const Color(0xFF200F00),
                                size: 26 * widget.ui,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Standard Menu Tile
/// Features:
/// - Single-side 7° subtle slant on right edge only (text strictly upright)
/// - Light shine sweep on hover or focus
/// - Quick scale-up feedback on press
/// - Clean watermark icon, high-contrast typography, and context badges
/// ─────────────────────────────────────────────────────────────
class MenuTile extends StatelessWidget {
  final double ui;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color border;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  const MenuTile({
    super.key,
    required this.ui,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.border,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 14 * ui;

    return MenuPressable(
      onTap: onTap,
      pressedScale: 1.03, // Quick scale-up on press
      child: LayoutBuilder(
        builder: (context, c) {
          final roomy = c.maxHeight > 74 * ui && c.maxWidth > 190 * ui;

          return ShineSweep(
            child: CustomPaint(
              painter: SingleSlantedFramePainter(
                colors: colors,
                borderColor: border,
                borderWidth: 1.8,
                angleDegrees: 7.0, // 6° to 8° angle on right edge only
                radius: radius,
                direction: SlantDirection.forward,
              ),
              child: ClipPath(
                clipper: SingleSlantedClipper(
                  angleDegrees: 7.0,
                  radius: radius,
                  direction: SlantDirection.forward,
                ),
                child: Stack(
                  children: [
                    // Decorative watermark shifted right & faint to avoid control collisions
                    Positioned(
                      right: -c.maxHeight * 0.2,
                      top: -c.maxHeight * 0.1,
                      child: Icon(
                        icon,
                        size: c.maxHeight * 1.15,
                        color: Colors.white.withAlpha(14),
                      ),
                    ),

                    // Dark text protection gradient (H1)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0x30000000),
                              Color(0x10000000),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    const TileGloss(),

                    // Content: Text and icons are strictly upright with no skew
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * ui,
                        vertical: 8 * ui,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: Colors.white,
                            size: math.min(36 * ui, c.maxHeight * 0.48),
                          ),
                          SizedBox(width: 10 * ui),
                          Expanded(
                            child: FitColumn(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          title,
                                          style: _tileTitle(19 * ui),
                                        ),
                                      ),
                                    ),
                                    if (badgeText != null) ...[
                                      SizedBox(width: 6 * ui),
                                      // Notification/Activity Badge with Athletic Parallelogram Frame
                                      ParallelogramBadge(
                                        color: badgeColor ?? const Color(0xFFFFC21A),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6 * ui,
                                          vertical: 2 * ui,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (badgeColor ?? const Color(0xFFFFC21A)).withAlpha(100),
                                            blurRadius: 4,
                                          ),
                                        ],
                                        child: Text(
                                          badgeText!,
                                          style: TextStyle(
                                            fontFamily: AppFonts.orbitron,
                                            fontSize: 7.5 * ui,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (roomy) ...[
                                  SizedBox(height: 3 * ui),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _tileSubtitle(11 * ui),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 26 * ui,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Perspective net texture on PLAY tile
class _NetTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * 0.5;
    final paint = Paint()
      ..color = const Color(0x1F7A3E00)
      ..strokeWidth = 1;

    canvas.saveLayer(Offset.zero & size, Paint());
    for (double x = left; x < size.width + size.height; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height * 0.35, size.height),
        paint,
      );
    }
    for (double y = 0; y < size.height; y += 9) {
      canvas.drawLine(Offset(left - 20, y), Offset(size.width, y - 6), paint);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          colors: [Color(0x00000000), Color(0xFF000000)],
          stops: [0.42, 0.75],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.93, 0, size.width * 0.018, size.height),
      Paint()..color = const Color(0x2E7A3E00),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
