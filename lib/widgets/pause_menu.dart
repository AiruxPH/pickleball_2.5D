import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import 'game_button.dart';

/// ─────────────────────────────────────────────────────────────
/// PauseMenu — Cartoon dialog matching Pickleball Stars style
/// Bright blue panel with yellow primary action button
/// ─────────────────────────────────────────────────────────────

class PauseMenu extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onMainMenu;

  const PauseMenu({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onMainMenu,
  });

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withAlpha(180),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: isLandscape
                ? _buildLandscapeMenu()
                : _buildPortraitMenu(),
          ),
        ),
      ),
    );
  }

  // ── Portrait: full-width vertical stack (original style) ─────
  Widget _buildPortraitMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 36),
      decoration: _menuDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(fontSize: 20, topPad: 22, bottomPad: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            child: Column(
              children: [
                MenuButton(label: 'RESUME MATCH', onTap: widget.onResume, isPrimary: true),
                const SizedBox(height: 12),
                MenuButton(label: 'RESTART MATCH', onTap: widget.onRestart),
                const SizedBox(height: 12),
                MenuButton(label: 'SETTINGS', onTap: widget.onSettings),
                const SizedBox(height: 12),
                MenuButton(label: 'MAIN MENU', onTap: widget.onMainMenu, color: AppColors.scoreAI),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Landscape: compact 2-column grid, smaller buttons ────────
  Widget _buildLandscapeMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: _menuDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: title
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitle(fontSize: 16, topPad: 0, bottomPad: 0),
              ],
            ),

            const SizedBox(width: 20),

            // Vertical divider
            Container(
              width: 1,
              height: 100,
              color: Colors.white.withAlpha(25),
            ),

            const SizedBox(width: 20),

            // Right: 2×2 button grid
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CompactPauseButton(
                          label: 'RESUME',
                          isPrimary: true,
                          onTap: widget.onResume,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactPauseButton(
                          label: 'RESTART',
                          onTap: widget.onRestart,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactPauseButton(
                          label: 'SETTINGS',
                          onTap: widget.onSettings,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactPauseButton(
                          label: 'MAIN MENU',
                          isDanger: true,
                          onTap: widget.onMainMenu,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _menuDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: const Color(0xF20F172A),
      border: Border.all(color: Colors.white.withAlpha(35), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildTitle({required double fontSize, required double topPad, required double bottomPad}) {
    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PAUSED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF8FAFC),
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 2.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact landscape-only button ─────────────────────────────
class _CompactPauseButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDanger;

  const _CompactPauseButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isDanger = false,
  });

  @override
  State<_CompactPauseButton> createState() => _CompactPauseButtonState();
}

class _CompactPauseButtonState extends State<_CompactPauseButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
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
    final List<Color> gradientColors = widget.isPrimary
        ? const [Color(0xFFFBBF24), Color(0xFFF59E0B)]
        : widget.isDanger
            ? const [Color(0xFFF43F5E), Color(0xFFE11D48)]
            : const [Color(0xFF334155), Color(0xFF1E293B)];

    final borderColor = widget.isPrimary
        ? const Color(0xFFFEF08A)
        : widget.isDanger
            ? const Color(0xFFFECDD3)
            : const Color(0xFF64748B);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: borderColor.withAlpha(180), width: 1.5),
            boxShadow: [
              const BoxShadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
              if (widget.isPrimary)
                const BoxShadow(
                  color: Color(0x30F59E0B),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: widget.isPrimary ? const Color(0xFF0F172A) : Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
