import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import 'menu/single_slanted_clipper.dart';
import 'menu/shine_sweep.dart';

/// ─────────────────────────────────────────────────────────────
/// GameButton — High-End Tactile Action Controls (HIT, POWER, SERVE)
///
/// Designed with sleek sports console aesthetic:
///   • Dual-ring metallic rim with radiant glow
///   • Smooth spring scale physics on tap & hold
///   • Crisp athletic iconography & typography
/// ─────────────────────────────────────────────────────────────

class GameButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final Color color;
  final Color glowColor;
  final double size;
  final bool isCircle;

  const GameButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.color = AppColors.primary,
    this.glowColor = AppColors.primaryGlow,
    this.size = UISizes.hitButtonSize,
    this.isCircle = true,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _press() {
    if (!_isPressed) {
      _isPressed = true;
      _ctrl.forward();
      HapticFeedback.lightImpact();
      try {
        Provider.of<AudioService>(context, listen: false).playButtonClick();
      } catch (_) {}
    }
  }

  void _release() {
    if (_isPressed) {
      _isPressed = false;
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isYellow = widget.color == AppColors.primary;
    final isPower = widget.color == AppColors.power;

    // Gradient colors based on button role
    final gradientColors = isYellow
        ? const [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)]
        : isPower
            ? const [Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFFBE123C)]
            : const [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0369A1)];

    final rimColor = isYellow
        ? const Color(0xFFFEF08A)
        : isPower
            ? const Color(0xFFFECDD3)
            : const Color(0xFFBAE6FD);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          _press();
        },
      onTapUp: (_) {
        _release();
        widget.onTap?.call();
      },
      onTapCancel: () {
        _release();
      },
      onLongPressStart: (_) {
        _press();
        widget.onLongPressStart?.call();
      },
      onLongPressEnd: (_) {
        _release();
        widget.onLongPressEnd?.call();
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final pressed = _ctrl.value > 0.5;
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: widget.isCircle
                    ? null
                    : BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: pressed ? rimColor : rimColor.withAlpha(190),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x60000000),
                    blurRadius: pressed ? 4 : 10,
                    offset: pressed ? const Offset(0, 2) : const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: widget.glowColor.withAlpha(pressed ? 180 : 100),
                    blurRadius: pressed ? 20 : 12,
                    spreadRadius: pressed ? 2 : 0,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: widget.size * 0.38,
                  shadows: const [
                    Shadow(
                      color: Color(0x60000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.size * 0.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(
                      color: Color(0x60000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

/// ─────────────────────────────────────────────────────────────
/// MenuButton — Athletic Single-Slanted Menu Action Button
/// Matches the main menu tiles with 7.0° angle, shine sweep, and glossy finish.
/// ─────────────────────────────────────────────────────────────
class MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;

  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.color,
  });

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = widget.color == AppColors.scoreAI ||
        widget.color == AppColors.power;
    final isYellow = widget.isPrimary && widget.color == null;

    final gradientColors = isYellow
        ? const [Color(0xFFFFD23F), Color(0xFFFFB300), Color(0xFFF08C00)]
        : isDanger
            ? const [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFBE123C)]
            : widget.color != null
                ? [
                    widget.color!,
                    Color.lerp(widget.color!, Colors.black, 0.25)!,
                  ]
                : const [
                    Color(0xFF334155),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ];

    final borderColor = isYellow
        ? const Color(0xFFFFE48A)
        : isDanger
            ? const Color(0xFFFECDD3)
            : widget.color != null
                ? Color.lerp(widget.color!, Colors.white, 0.4)!
                : const Color(0xFF64748B);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          HapticFeedback.lightImpact();
          try {
            Provider.of<AudioService>(context, listen: false).playButtonClick();
          } catch (_) {}
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: ShineSweep(
            autoPeriodic: isYellow,
            periodicInterval: const Duration(seconds: 5),
            shineColor: isYellow
                ? const Color(0xFFFFF7D6)
                : const Color(0x40FFFFFF),
            clipper: const SingleSlantedClipper(
              angleDegrees: 7.0,
              radius: 12.0,
              direction: SlantDirection.forward,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: CustomPaint(
                painter: SingleSlantedFramePainter(
                  colors: gradientColors,
                  borderColor: borderColor,
                  borderWidth: 2.0,
                  angleDegrees: 7.0, // 7° angle on right edge
                  radius: 12.0,
                  direction: SlantDirection.forward,
                ),
                child: ClipPath(
                  clipper: const SingleSlantedClipper(
                    angleDegrees: 7.0,
                    radius: 12.0,
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
                                  Color(0x38FFFFFF),
                                  Color(0x05FFFFFF),
                                  Color(0x00000000),
                                  Color(0x22000000),
                                ],
                                stops: [0.0, 0.45, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isYellow
                                ? const Color(0xFF200F00)
                                : Colors.white,
                            letterSpacing: 1.8,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha(40),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
