import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// VirtualJoystick — Precision Translucent HUD Movement Controller
///
/// Designed with sleek minimal glassmorphism:
///   • Frosted etched guide ring with fine crosshair ticks
///   • Precision thumb nub with subtle tactile rim & haptic glow
///   • Outputs normalized (x, y) with smooth return-to-center physics
///   • Wrapped in RepaintBoundary to isolate drag repaints from game tree
/// ─────────────────────────────────────────────────────────────

class VirtualJoystick extends StatefulWidget {
  /// Called every frame with (x, y) in range [-1, 1]
  final void Function(double x, double y) onMove;

  /// Called when joystick is released (returns to center)
  final VoidCallback? onRelease;

  final double size;
  final double sensitivity;

  const VirtualJoystick({
    super.key,
    required this.onMove,
    this.onRelease,
    this.size = UISizes.joystickSize,
    this.sensitivity = 1.0,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

/// A floating joystick that appears wherever the player first touches its
/// control zone, then disappears on release.
class DynamicJoystick extends StatefulWidget {
  const DynamicJoystick({
    super.key,
    this.onMove,
    this.onDrag,
    required this.onRelease,
    this.size = 116,
    this.sensitivity = 1,
  }) : assert(onMove != null || onDrag != null);

  final void Function(double x, double y)? onMove;
  final ValueChanged<JoystickDrag>? onDrag;
  final VoidCallback onRelease;
  final double size;
  final double sensitivity;

  @override
  State<DynamicJoystick> createState() => _DynamicJoystickState();
}

class _DynamicJoystickState extends State<DynamicJoystick> {
  Offset? _origin;
  Offset? _screenOrigin;
  Offset _delta = Offset.zero;

  void _update(Offset point, Offset screenPoint) {
    final origin = _origin;
    final screenOrigin = _screenOrigin;
    if (origin == null || screenOrigin == null) return;
    final radius = widget.size * 0.36;
    final raw = point - origin;
    final distance = raw.distance;
    _delta = distance > radius ? raw / distance * radius : raw;
    final normalized = Offset(
      (_delta.dx / radius * widget.sensitivity).clamp(-1.0, 1.0),
      (_delta.dy / radius * widget.sensitivity).clamp(-1.0, 1.0),
    );
    widget.onMove?.call(normalized.dx, normalized.dy);
    widget.onDrag?.call(JoystickDrag(
      origin: screenOrigin,
      current: screenPoint,
      normalized: normalized,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        _origin = details.localPosition;
        _screenOrigin = details.globalPosition;
        _delta = Offset.zero;
        setState(() {});
      },
      onPanUpdate: (details) =>
          _update(details.localPosition, details.globalPosition),
      onPanEnd: (_) {
        _origin = null;
        _screenOrigin = null;
        _delta = Offset.zero;
        widget.onRelease();
        setState(() {});
      },
      onPanCancel: () {
        _origin = null;
        _screenOrigin = null;
        _delta = Offset.zero;
        widget.onRelease();
        setState(() {});
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_origin case final origin?)
            Positioned(
              left: origin.dx - widget.size / 2,
              top: origin.dy - widget.size / 2,
              child: IgnorePointer(
                child: Transform.translate(
                  offset: _delta,
                  child: VirtualJoystick(
                    size: widget.size,
                    sensitivity: widget.sensitivity,
                    onMove: (_, __) {},
                    onRelease: () {},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class JoystickDrag {
  const JoystickDrag({
    required this.origin,
    required this.current,
    required this.normalized,
  });

  final Offset origin;
  final Offset current;
  final Offset normalized;
}

class _VirtualJoystickState extends State<VirtualJoystick>
    with SingleTickerProviderStateMixin {
  Offset _knobPos = Offset.zero;
  bool _isDragging = false;

  late AnimationController _returnController;
  late Animation<Offset> _returnAnim;
  Offset _knobAtRelease = Offset.zero;

  @override
  void initState() {
    super.initState();
    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _returnAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _returnController, curve: Curves.easeOutCubic),
    );
    _returnController.addListener(() {
      if (!_isDragging) {
        setState(() => _knobPos = _returnAnim.value);
      }
    });
  }

  @override
  void dispose() {
    _returnController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _returnController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final maxRadius = widget.size / 2 - UISizes.joystickKnobSize / 2;
    var newPos = _knobPos + details.delta;

    // Clamp to circular bounds
    final dist = math.sqrt(newPos.dx * newPos.dx + newPos.dy * newPos.dy);
    if (dist > maxRadius) {
      newPos = newPos / dist * maxRadius;
    }

    setState(() => _knobPos = newPos);

    // Dead zone handling & normalized output
    const deadZone = 0.08;
    double nx = (newPos.dx / maxRadius).clamp(-1.0, 1.0);
    double ny = (newPos.dy / maxRadius).clamp(-1.0, 1.0);

    if (nx.abs() < deadZone) nx = 0;
    if (ny.abs() < deadZone) ny = 0;

    widget.onMove(nx * widget.sensitivity, ny * widget.sensitivity);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _knobAtRelease = _knobPos;

    _returnAnim = Tween<Offset>(
      begin: _knobAtRelease,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _returnController, curve: Curves.easeOutCubic),
    );
    _returnController.forward(from: 0);

    widget.onMove(0, 0);
    widget.onRelease?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    const knobSize = UISizes.joystickKnobSize;

    // RepaintBoundary isolates this widget's drag repaints from the parent game tree
    return RepaintBoundary(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Frosted Glass Base Ring ─────────────────────────
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x330B132B),
                  border: Border.all(
                    color: Colors.white.withAlpha(_isDragging ? 70 : 35),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),

              // Inner concentric reticle ring
              Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(20),
                    width: 1.0,
                  ),
                ),
              ),

              // Subtle Crosshair Ticks — single CustomPaint draw call
              _CrosshairTicks(size: size),

              // ── Precision Thumb Knob ────────────────────────────
              Transform.translate(
                offset: _knobPos,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isDragging
                          ? const [Color(0xFF38BDF8), Color(0xFF0284C7)]
                          : const [Color(0xFF475569), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _isDragging
                          ? const Color(0xFFBAE6FD)
                          : Colors.white.withAlpha(60),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isDragging
                            ? const Color(0x660284C7)
                            : const Color(0x60000000),
                        blurRadius: _isDragging ? 16 : 8,
                        spreadRadius: _isDragging ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: knobSize * 0.40,
                      height: knobSize * 0.40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(_isDragging ? 60 : 25),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crosshair tick marks rendered in a single CustomPaint draw call
/// (replaces 4-widget Stack of Containers — eliminates 4 separate paint layers)
class _CrosshairTicks extends StatelessWidget {
  final double size;
  const _CrosshairTicks({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CrosshairPainter(),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  static final Paint _tickPaint = Paint()
    ..color = const Color(0x55FFFFFF)
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;
  static const double _tickLen = 5.0;
  static const double _tickOffset = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Top
    canvas.drawLine(Offset(cx, _tickOffset), Offset(cx, _tickOffset + _tickLen),
        _tickPaint);
    // Bottom
    canvas.drawLine(Offset(cx, size.height - _tickOffset),
        Offset(cx, size.height - _tickOffset - _tickLen), _tickPaint);
    // Left
    canvas.drawLine(Offset(_tickOffset, cy), Offset(_tickOffset + _tickLen, cy),
        _tickPaint);
    // Right
    canvas.drawLine(Offset(size.width - _tickOffset, cy),
        Offset(size.width - _tickOffset - _tickLen, cy), _tickPaint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => false; // Static — never repaints
}
