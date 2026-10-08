import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/game_settings.dart';
import '../../utils/constants.dart';
import '../menu_backdrop.dart';
import '../player_profile_dialog.dart';
import 'angular_frames.dart';
import 'menu_pressable.dart';

/// ─────────────────────────────────────────────────────────────
/// MenuTopBar — Profile Card, Currency Counters & Action Controls
/// Implements H6 (XP display & contrast), H7 (>=44px hit targets)
/// with sharp angular frames & athletic parallelogram badges.
/// ─────────────────────────────────────────────────────────────
class MenuTopBar extends StatelessWidget {
  final double ui;
  final bool compact;
  final VoidCallback onProfile;
  final VoidCallback onShop;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  const MenuTopBar({
    super.key,
    required this.ui,
    this.compact = false,
    required this.onProfile,
    required this.onShop,
    required this.onSettings,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    GameSettings? settings;
    try {
      settings = context.watch<GameSettings>();
    } catch (_) {}

    final coins = MenuCurrencyPill(
      ui: ui,
      icon: Icons.monetization_on_rounded,
      color: const Color(0xFFFFC21A),
      value: settings?.coins ?? 10386,
      onTap: onShop,
    );
    final gems = MenuCurrencyPill(
      ui: ui,
      icon: Icons.diamond_rounded,
      color: const Color(0xFFC06BFF),
      value: settings?.gems ?? 8161,
      onTap: onShop,
    );
    final gap = SizedBox(width: 8 * ui);
    final help = MenuRoundIconButton(
      ui: ui,
      icon: Icons.help_outline_rounded,
      tooltip: 'How to Play & Rules',
      onTap: onHelp,
    );
    final settingsBtn = MenuRoundIconButton(
      ui: ui,
      icon: Icons.settings_rounded,
      tooltip: 'Game Settings & Audio',
      onTap: onSettings,
    );

    // Narrow portrait screens: currencies get their own row under the bar
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MenuProfileBadge(ui: ui, onTap: onProfile),
                ),
              ),
              gap,
              settingsBtn,
              gap,
              help,
            ],
          ),
          SizedBox(height: 8 * ui),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [coins, gap, gems],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        MenuProfileBadge(ui: ui, onTap: onProfile),
        const Spacer(),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                coins,
                gap,
                gems,
                gap,
                settingsBtn,
                gap,
                help,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// MenuProfileBadge — Displays Player Avatar, Name, Level & XP
/// Fulfills H6: Shows numerical XP and high-contrast level bar.
/// ─────────────────────────────────────────────────────────────
class MenuProfileBadge extends StatelessWidget {
  final double ui;
  final VoidCallback onTap;

  const MenuProfileBadge({
    super.key,
    required this.ui,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    GameSettings? settings;
    try {
      settings = context.watch<GameSettings>();
    } catch (_) {}

    final name = settings?.playerName ?? 'John Doe';
    final level = settings?.playerLevel ?? 5;
    final xp = settings?.playerXp ?? 580;
    final maxXp = settings?.playerMaxXp ?? 750;
    final avatarIndex = settings?.avatarIndex ?? 0;
    final ratio = maxXp > 0 ? (xp / maxXp).clamp(0.0, 1.0) : 0.0;
    final avatar = 48.0 * ui;

    final portrait = Container(
      width: avatar,
      height: avatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1B4E9B),
        border: Border.all(color: const Color(0xFF6FA8FF), width: 2.2 * ui),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarIndex == 0
            ? Image.asset(
                'assets/images/menu/avatar_boy.png',
                fit: BoxFit.cover,
              )
            : Icon(
                getProfileAvatarIcon(avatarIndex),
                color: Colors.white,
                size: 26 * ui,
              ),
      ),
    );

    // Name panel with numerical XP and vibrant level progress in athletic angular cut frame
    final panel = Container(
      margin: EdgeInsets.only(left: avatar * 0.5),
      padding: EdgeInsets.fromLTRB(avatar * 0.5 + 10 * ui, 5 * ui, 16 * ui, 6 * ui),
      decoration: ShapeDecoration(
        color: kMenuPanelColor,
        shape: BeveledRectangleBorder(
          side: const BorderSide(color: kMenuPanelBorder),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(14 * ui),
            bottomRight: Radius.circular(14 * ui),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5 * ui,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              SizedBox(width: 8 * ui),
              ParallelogramBadge(
                color: const Color(0xFFFFC21A).withAlpha(45),
                borderColor: const Color(0xFFFFC21A),
                padding: EdgeInsets.symmetric(horizontal: 6 * ui, vertical: 1.5 * ui),
                child: Text(
                  'Lv. $level',
                  style: TextStyle(
                    color: const Color(0xFFFFC21A),
                    fontSize: 9.5 * ui,
                    fontFamily: AppFonts.orbitron,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3 * ui),
          // XP Bar and Numerical Progress (H6)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipPath(
                clipper: ShapeBorderClipper(
                  shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.circular(3 * ui),
                  ),
                ),
                child: SizedBox(
                  width: 95 * ui,
                  height: 6.5 * ui,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xFF16253D)),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        heightFactor: 1.0,
                        alignment: Alignment.centerLeft,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD54A), Color(0xFF38BDF8)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6 * ui),
              Text(
                '$xp / $maxXp XP',
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: 9.5 * ui,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Tooltip(
      message: 'View & Edit Player Profile',
      child: MenuPressable(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [panel, portrait],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// MenuCurrencyPill — Coin / Diamond Currency Counter
/// Fulfills H7: >=44px touch target with clear '+' affordance.
/// ─────────────────────────────────────────────────────────────
class MenuCurrencyPill extends StatelessWidget {
  final double ui;
  final IconData icon;
  final Color color;
  final int value;
  final VoidCallback onTap;

  const MenuCurrencyPill({
    super.key,
    required this.ui,
    required this.icon,
    required this.color,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open Shop to Acquire More',
      child: MenuPressable(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: 44 * ui,
            minWidth: 44 * ui,
          ),
          padding: EdgeInsets.symmetric(horizontal: 8 * ui, vertical: 4 * ui),
          decoration: ShapeDecoration(
            color: kMenuPanelColor,
            shape: BeveledRectangleBorder(
              side: const BorderSide(color: kMenuPanelBorder),
              borderRadius: BorderRadius.circular(10 * ui),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26 * ui),
              SizedBox(width: 6 * ui),
              Text(
                '$value',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5 * ui,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 8 * ui),
              // Prominent + Action Affordance (H7) with Angular Frame
              Container(
                width: 24 * ui,
                height: 24 * ui,
                decoration: ShapeDecoration(
                  shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.circular(6 * ui),
                    side: BorderSide(color: color.withAlpha(200), width: 1.3),
                  ),
                  color: color.withAlpha(50),
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 16 * ui),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// MenuRoundIconButton — Angular Chamfered Utility Action Button
/// Fulfills H7: >=44px minimum tap target with tooltip clarity.
/// ─────────────────────────────────────────────────────────────
class MenuRoundIconButton extends StatelessWidget {
  final double ui;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const MenuRoundIconButton({
    super.key,
    required this.ui,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MenuPressable(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minWidth: 44 * ui,
            minHeight: 44 * ui,
          ),
          padding: EdgeInsets.all(8 * ui),
          decoration: ShapeDecoration(
            color: kMenuPanelColor,
            shape: BeveledRectangleBorder(
              side: const BorderSide(color: kMenuPanelBorder),
              borderRadius: BorderRadius.circular(9 * ui),
            ),
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 22 * ui),
          ),
        ),
      ),
    );
  }
}
