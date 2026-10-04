import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'angular_frames.dart';
import 'menu_pressable.dart';

/// ─────────────────────────────────────────────────────────────
/// MenuBottomNav — Bottom Navigation Bar with Activity Badges
/// - Removed redundant Profile (available on top-left card)
/// - Angular trapezoid active indicator for a sharp athletic feel
/// ─────────────────────────────────────────────────────────────
class MenuBottomNav extends StatelessWidget {
  final double ui;
  final VoidCallback onLeaderboard;
  final VoidCallback onAchievements;
  final bool hasAchievementBadge;

  const MenuBottomNav({
    super.key,
    required this.ui,
    required this.onLeaderboard,
    required this.onAchievements,
    this.hasAchievementBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget divider() => Container(
          width: 1,
          height: 24 * ui,
          color: const Color(0xFF2B4A7A),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 180 || constraints.maxHeight < 20) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 52 * ui + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: Color(0xF20C1A33),
            border: Border(top: BorderSide(color: Color(0xFF2B4A7A), width: 1.5)),
            boxShadow: [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 720 * ui),
              child: ClipRect(
                child: Row(
                  children: [
                    Expanded(
                      child: MenuNavItem(
                        ui: ui,
                        icon: Icons.home_rounded,
                        label: 'HOME',
                        selected: true,
                        onTap: () {},
                      ),
                    ),
                    divider(),
                    Expanded(
                      child: MenuNavItem(
                        ui: ui,
                        icon: Icons.emoji_events_rounded,
                        label: 'LEADERBOARD',
                        onTap: onLeaderboard,
                      ),
                    ),
                    divider(),
                    Expanded(
                      child: MenuNavItem(
                        ui: ui,
                        icon: Icons.star_rounded,
                        label: 'ACHIEVEMENTS',
                        hasBadge: hasAchievementBadge,
                        onTap: onAchievements,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MenuNavItem extends StatelessWidget {
  final double ui;
  final IconData icon;
  final String label;
  final bool selected;
  final bool hasBadge;
  final VoidCallback onTap;

  const MenuNavItem({
    super.key,
    required this.ui,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : const Color(0xFFCBD5E1);
    final iconColor = selected ? const Color(0xFFFFC21A) : const Color(0xFF94A3B8);

    return MenuPressable(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sharp trapezoid active background indicator
          if (selected)
            Positioned.fill(
              child: ClipPath(
                clipper: TrapezoidClipper(cutWidth: 12 * ui, inverted: true),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x3DFFC21A),
                        Color(0x10FFC21A),
                        Colors.transparent,
                      ],
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0xFFFFC21A), width: 3),
                    ),
                  ),
                ),
              ),
            ),

          Container(
            height: double.infinity,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 6 * ui, vertical: 4 * ui),
            child: LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 150 * ui;

                final iconWidget = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: iconColor, size: (stacked ? 20 : 22) * ui),
                    if (hasBadge)
                      Positioned(
                        right: -3 * ui,
                        top: -2 * ui,
                        child: Container(
                          width: 8 * ui,
                          height: 8 * ui,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEF4444),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                        ),
                      ),
                  ],
                );

                final textWidget = Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: (stacked ? 9 : 12) * ui,
                    fontFamily: AppFonts.orbitron,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                );

                if (stacked) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        iconWidget,
                        SizedBox(height: 2 * ui),
                        textWidget,
                      ],
                    ),
                  );
                }

                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      SizedBox(width: 6 * ui),
                      textWidget,
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
