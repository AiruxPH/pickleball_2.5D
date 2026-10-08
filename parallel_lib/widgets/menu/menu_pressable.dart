import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/audio_service.dart';

/// ─────────────────────────────────────────────────────────────
/// MenuPressable — Shared interactive press feedback
/// Provides tactile scale-down, haptic feedback, and button audio.
/// ─────────────────────────────────────────────────────────────
class MenuPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  const MenuPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 1.03,
  });

  @override
  State<MenuPressable> createState() => _MenuPressableState();
}

class _MenuPressableState extends State<MenuPressable> {
  bool _down = false;

  void _fire() {
    HapticFeedback.lightImpact();
    try {
      Provider.of<AudioService>(context, listen: false).playButtonClick();
    } catch (_) {}
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          _fire();
        },
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1.0,
          duration: Duration(milliseconds: _down ? 65 : 160),
          curve: _down ? Curves.easeOutQuad : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}
