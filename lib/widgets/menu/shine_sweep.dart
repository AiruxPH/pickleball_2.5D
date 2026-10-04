import 'dart:async';
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// ShineSweep — Dynamic Light Sheen Micro-Animation
/// Renders a luminous diagonal light beam that sweeps across the tile
/// on hover, focus, or periodic ambient pulse.
/// Delivers high-energy motion without cluttering shapes.
/// ─────────────────────────────────────────────────────────────

class ShineSweep extends StatefulWidget {
  final Widget child;
  final bool autoPeriodic;
  final Duration periodicInterval;
  final Duration sweepDuration;
  final double angleDegrees;
  final double shineWidth;
  final Color shineColor;

  const ShineSweep({
    super.key,
    required this.child,
    this.autoPeriodic = false,
    this.periodicInterval = const Duration(seconds: 6),
    this.sweepDuration = const Duration(milliseconds: 700),
    this.angleDegrees = -22.0,
    this.shineWidth = 70.0,
    this.shineColor = Colors.white,
  });

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.sweepDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    if (widget.autoPeriodic) {
      _startPeriodicTimer();
    }
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(widget.periodicInterval, (_) {
      if (mounted && !_controller.isAnimating) {
        _controller.forward(from: 0.0);
      }
    });
  }

  void triggerSweep() {
    if (mounted && !_controller.isAnimating) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (focused) {
        if (focused) triggerSweep();
      },
      child: MouseRegion(
        onEnter: (_) => triggerSweep(),
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    if (_animation.value <= 0.0 || _animation.value >= 1.0) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: _ShineSweepPainter(
                        progress: _animation.value,
                        angleDegrees: widget.angleDegrees,
                        shineWidth: widget.shineWidth,
                        shineColor: widget.shineColor,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShineSweepPainter extends CustomPainter {
  final double progress;
  final double angleDegrees;
  final double shineWidth;
  final Color shineColor;

  _ShineSweepPainter({
    required this.progress,
    required this.angleDegrees,
    required this.shineWidth,
    required this.shineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Total sweep travel from beyond left to beyond right
    final startX = -shineWidth * 1.5;
    final endX = size.width + shineWidth * 1.5;
    final currentX = startX + (endX - startX) * progress;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Diagonal skew / rotation around the shine center
    canvas.translate(currentX, size.height * 0.5);
    canvas.rotate(angleDegrees * 3.14159265 / 180.0);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: shineWidth,
      height: size.height * 3.0,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          shineColor.withAlpha(0),
          shineColor.withAlpha(30),
          shineColor.withAlpha(140),
          shineColor.withAlpha(30),
          shineColor.withAlpha(0),
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShineSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
