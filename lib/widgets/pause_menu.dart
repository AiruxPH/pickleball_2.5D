import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import 'game_button.dart';

/// ─────────────────────────────────────────────────────────────
/// PauseMenu — in-match pause dialog
/// Bright blue panel with yellow primary action button
/// ─────────────────────────────────────────────────────────────

class PauseMenu extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onCustomizeControls;
  final VoidCallback onMainMenu;

  const PauseMenu({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onCustomizeControls,
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
                MenuButton(label: 'CUSTOMIZE CONTROLS', onTap: widget.onCustomizeControls),
                const SizedBox(height: 12),
                MenuButton(label: 'KITCHEN (NVZ) RULES', onTap: () => _showKitchenRules(context)),
                const SizedBox(height: 12),
                MenuButton(label: 'MAIN MENU', onTap: widget.onMainMenu, color: AppColors.scoreAI),
                const SizedBox(height: 14),
                _buildQuickGraphicsToggle(context),
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

            // Right: 2×2 button grid + Quick Performance Toggle
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
                          label: 'CONTROLS',
                          onTap: widget.onCustomizeControls,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactPauseButton(
                          label: 'NVZ RULES',
                          onTap: () => _showKitchenRules(context),
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
                  const SizedBox(height: 10),
                  _buildQuickGraphicsToggle(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGraphicsToggle(BuildContext context) {
    final settings = context.watch<GameSettings>();
    final isLow = settings.graphicsQuality == GraphicsQuality.low;
    final isMed = settings.graphicsQuality == GraphicsQuality.medium;
    final qualityLabel = isLow
        ? 'LOW (FASTEST)'
        : (isMed ? 'MEDIUM (BALANCED)' : 'HIGH (MAX QUALITY)');
    final qualityColor = isLow
        ? const Color(0xFF10B981)
        : (isMed ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B));

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        final next = isLow
            ? GraphicsQuality.medium
            : (isMed ? GraphicsQuality.high : GraphicsQuality.low);
        settings.graphicsQuality = next;
        try {
          context.read<SettingsService>().save(settings);
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: qualityColor.withAlpha(140), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLow ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
              size: 14,
              color: qualityColor,
            ),
            const SizedBox(width: 7),
            Text(
              'GRAPHICS: $qualityLabel',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: qualityColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.touch_app_rounded,
              size: 11,
              color: qualityColor.withAlpha(180),
            ),
          ],
        ),
      ),
    );
  }

  void _showKitchenRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 580),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xF80F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF38BDF8).withAlpha(140), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 28, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0369A1).withAlpha(70),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 1.0),
                      ),
                      child: const Icon(Icons.sports_tennis_rounded, color: Color(0xFF38BDF8), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NON-VOLLEY ZONE (THE KITCHEN)',
                            style: TextStyle(
                              fontFamily: AppFonts.orbitron,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF8FAFC),
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'Official USA Pickleball Rules & Mechanics',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x330369A1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The Kitchen is the area 7 feet from the net on each side, making a 14-foot area around the net.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildRuleItem(
                          title: 'NO VOLLEYS INSIDE THE KITCHEN',
                          description:
                              'A volley means hitting the ball before it bounces. If you are standing inside the Kitchen or touching the Kitchen line and hit a volley, it is a FAULT.',
                          icon: Icons.block_rounded,
                          color: const Color(0xFFEF4444),
                        ),
                        _buildRuleItem(
                          title: 'THE KITCHEN LINE IS PART OF THE KITCHEN',
                          description:
                              'If your foot touches the line while you volley, it is considered a Kitchen violation.',
                          icon: Icons.straighten_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                        _buildRuleItem(
                          title: 'ENTER FREELY IF THE BALL BOUNCES FIRST',
                          description:
                              'If your opponent hits a short ball that lands inside the Kitchen, you may step inside and hit it after the bounce. Being inside the Kitchen itself is NOT a fault.',
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF10B981),
                        ),
                        _buildRuleItem(
                          title: 'MOMENTUM CANNOT CARRY YOU INTO KITCHEN',
                          description:
                              'Even if you hit the ball while standing outside, it is still a fault if your momentum makes you step into or touch the Kitchen afterward. This applies even if the rally has already ended.',
                          icon: Icons.directions_run_rounded,
                          color: const Color(0xFFF97316),
                        ),
                        _buildRuleItem(
                          title: 'BOTH FEET MUST BE ESTABLISHED OUTSIDE',
                          description:
                              'After leaving the Kitchen, both feet must be established outside before you volley. You cannot stand inside, jump to hit the ball in the air, and land outside.',
                          icon: Icons.airline_seat_legroom_extra_rounded,
                          color: const Color(0xFFA855F7),
                        ),
                        _buildRuleItem(
                          title: 'THE SERVE MUST CLEAR THE KITCHEN',
                          description:
                              'A serve must land diagonally in the opponent\'s service court. If the serve touches the Kitchen line, it is considered short and is a fault.',
                          icon: Icons.sports_tennis_rounded,
                          color: const Color(0xFF38BDF8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Center(
                    child: Text(
                      'Golden Rule: You can go inside the Kitchen, but you cannot volley while touching or standing inside it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.orbitron,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleItem({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFCBD5E1),
                      height: 1.3,
                    ),
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
