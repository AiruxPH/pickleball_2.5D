import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../services/settings_service.dart';
import 'menu_backdrop.dart';
import 'menu_ui.dart';

/// Available avatar icons
const List<IconData> kProfileAvatars = [
  Icons.person_rounded,
  Icons.sports_tennis_rounded,
  Icons.workspace_premium_rounded,
  Icons.bolt_rounded,
  Icons.local_fire_department_rounded,
  Icons.star_rounded,
];

IconData getProfileAvatarIcon(int index) {
  if (index >= 0 && index < kProfileAvatars.length) {
    return kProfileAvatars[index];
  }
  return Icons.person_rounded;
}

/// ─────────────────────────────────────────────────────────────
/// PlayerProfileDialog — player profile popup in the main-menu style
/// ─────────────────────────────────────────────────────────────
class PlayerProfileDialog extends StatefulWidget {
  const PlayerProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Profile',
      barrierColor: Colors.black.withAlpha(160),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim, secondaryAnim) =>
          const PlayerProfileDialog(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PlayerProfileDialog> createState() => _PlayerProfileDialogState();
}

class _PlayerProfileDialogState extends State<PlayerProfileDialog> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<GameSettings>();
    _nameController = TextEditingController(text: settings.playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName(GameSettings settings) {
    final trimmed = _nameController.text.trim();
    if (trimmed.isNotEmpty) {
      settings.playerName = trimmed;
      context.read<SettingsService>().save(settings);
    }
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GameSettings>();
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.shortestSide < 600;
    final ui = MenuMetrics.of(context).contentUi * (isMobile ? 0.9 : 1.0);
    final xpProgress = settings.playerMaxXp > 0
        ? (settings.playerXp / settings.playerMaxXp).clamp(0.0, 1.0)
        : 0.0;
    final winRate = settings.matchesPlayed > 0
        ? (settings.matchesWon * 100 / settings.matchesPlayed).round()
        : 0;
    final screenHeight = screenSize.height;
    final avatarSize = 78.0 * ui;
    // Landscape screens: two columns so nothing needs scrolling
    final screenWidth = screenSize.width;
    final wide = screenWidth > screenHeight && screenWidth > 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: (wide ? 760 : 380) * ui,
              maxHeight: screenHeight * 0.92),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF5142B52), Color(0xF50C1A33)],
              ),
              borderRadius: BorderRadius.circular(22 * ui),
              border: Border.all(color: const Color(0xFF3E6DB5), width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 24,
                    offset: Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21 * ui),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ─────────────────────────────────────
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(16 * ui, 12 * ui, 12 * ui, 4 * ui),
                    child: Row(
                      children: [
                        Icon(Icons.badge_rounded,
                            color: kMenuGold, size: 22 * ui),
                        SizedBox(width: 8 * ui),
                        Expanded(
                          child: Text('PLAYER PROFILE',
                              style: menuTitleStyle(18 * ui)),
                        ),
                        MenuIconButton(
                          icon: Icons.close_rounded,
                          size: 34,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          16 * ui, 8 * ui, 16 * ui, 16 * ui),
                      child: _ProfileBody(
                        wide: wide,
                        identity: [
                          // ── Portrait + level badge ─────────────────
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1B4E9B),
                                  border: Border.all(
                                      color: const Color(0xFF6FA8FF),
                                      width: 3 * ui),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3)),
                                  ],
                                ),
                                child: ClipOval(
                                  child: settings.avatarIndex == 0
                                      ? Image.asset(
                                          'assets/images/menu/avatar_boy.png',
                                          fit: BoxFit.cover)
                                      : Icon(
                                          getProfileAvatarIcon(
                                              settings.avatarIndex),
                                          color: Colors.white,
                                          size: avatarSize * 0.55),
                                ),
                              ),
                              Positioned(
                                bottom: -8 * ui,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10 * ui, vertical: 3 * ui),
                                  decoration: menuTileDecoration(
                                      TilePalette.gold, 12 * ui),
                                  child: Text(
                                    'Lv. ${settings.playerLevel}',
                                    style: menuTitleStyle(12 * ui),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16 * ui),

                          // ── Avatar picker ──────────────────────────
                          Text(
                            'CHOOSE AVATAR',
                            style: TextStyle(
                              fontSize: 10.5 * ui,
                              fontWeight: FontWeight.w900,
                              color: kMenuMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 8 * ui),
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(kProfileAvatars.length,
                                    (idx) {
                                  final isSelected =
                                      settings.avatarIndex == idx;
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 3.5 * ui),
                                    child: MenuPressable(
                                      onTap: () {
                                        settings.avatarIndex = idx;
                                        context
                                            .read<SettingsService>()
                                            .save(settings);
                                      },
                                      child: Container(
                                        width: 36 * ui,
                                        height: 36 * ui,
                                        decoration: isSelected
                                            ? menuTileDecoration(
                                                TilePalette.gold, 18 * ui)
                                            : BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: kMenuPanelColor,
                                                border: Border.all(
                                                    color: kMenuPanelBorder),
                                              ),
                                        child: Icon(
                                          kProfileAvatars[idx],
                                          size: 19 * ui,
                                          color: isSelected
                                              ? Colors.white
                                              : kMenuMuted,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              )),
                          SizedBox(height: 12 * ui),

                          // ── Name (tap the pencil to edit) ──────────
                          if (_isEditingName)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 180 * ui,
                                  height: 40 * ui,
                                  child: TextField(
                                    controller: _nameController,
                                    autofocus: true,
                                    maxLength: 16,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15 * ui,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10 * ui,
                                          vertical: 8 * ui),
                                      filled: true,
                                      fillColor: kMenuPanelColor,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10 * ui),
                                        borderSide: const BorderSide(
                                            color: kMenuGold, width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10 * ui),
                                        borderSide: const BorderSide(
                                            color: kMenuGold, width: 1.5),
                                      ),
                                    ),
                                    onSubmitted: (_) => _saveName(settings),
                                  ),
                                ),
                                SizedBox(width: 8 * ui),
                                MenuPressable(
                                  onTap: () => _saveName(settings),
                                  child: Container(
                                    width: 38 * ui,
                                    height: 38 * ui,
                                    decoration: menuTileDecoration(
                                        TilePalette.green, 12 * ui),
                                    child: Icon(Icons.check_rounded,
                                        color: Colors.white, size: 22 * ui),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    settings.playerName,
                                    overflow: TextOverflow.ellipsis,
                                    style: menuTitleStyle(22 * ui),
                                  ),
                                ),
                                SizedBox(width: 8 * ui),
                                MenuIconButton(
                                  icon: Icons.edit_rounded,
                                  size: 30,
                                  onTap: () {
                                    _nameController.text = settings.playerName;
                                    setState(() => _isEditingName = true);
                                  },
                                ),
                              ],
                            ),
                          SizedBox(height: 6 * ui),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10 * ui, vertical: 3 * ui),
                            decoration: BoxDecoration(
                              color: kMenuPanelColor,
                              borderRadius: BorderRadius.circular(12 * ui),
                              border: Border.all(color: kMenuPanelBorder),
                            ),
                            child: Text(
                              'NEW PLAYER',
                              style: TextStyle(
                                color: kMenuMuted,
                                fontSize: 10.5 * ui,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          SizedBox(height: 14 * ui),
                        ],
                        details: [
                          // ── Level progress ─────────────────────────
                          MenuPanel(
                            padding: EdgeInsets.all(12 * ui),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'LEVEL PROGRESS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12 * ui,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${settings.playerXp} / ${settings.playerMaxXp} XP',
                                      style: TextStyle(
                                        color: kMenuGold,
                                        fontSize: 12 * ui,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8 * ui),
                                MenuProgressBar(value: xpProgress, height: 9),
                                SizedBox(height: 8 * ui),
                                Row(
                                  children: [
                                    Icon(Icons.card_giftcard_rounded,
                                        color: kMenuGold, size: 15 * ui),
                                    SizedBox(width: 6 * ui),
                                    Expanded(
                                      child: Text(
                                        'Next: +250 Coins & Pro Paddle Unlock',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: kMenuMuted,
                                          fontSize: 11.5 * ui,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10 * ui),

                          // ── Stats ──────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'MATCHES',
                                  value: '${settings.matchesPlayed}',
                                  icon: Icons.sports_tennis_rounded,
                                  color: const Color(0xFF4DA3FF),
                                ),
                              ),
                              SizedBox(width: 8 * ui),
                              Expanded(
                                child: _StatTile(
                                  label: 'WINS',
                                  value: '${settings.matchesWon} ($winRate%)',
                                  icon: Icons.workspace_premium_rounded,
                                  color: kMenuGold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8 * ui),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'WIN STREAK',
                                  value: '${settings.winStreak} Matches',
                                  icon: Icons.local_fire_department_rounded,
                                  color: const Color(0xFFFF7A45),
                                ),
                              ),
                              SizedBox(width: 8 * ui),
                              Expanded(
                                child: _StatTile(
                                  label: 'TOTAL ACES',
                                  value: '${settings.aces}',
                                  icon: Icons.bolt_rounded,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10 * ui),

                          // ── Wallet ─────────────────────────────────
                          MenuPanel(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12 * ui, vertical: 9 * ui),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _WalletItem(
                                    icon: Icons.monetization_on_rounded,
                                    color: kMenuGold,
                                    value: settings.coins),
                                Container(
                                    width: 1,
                                    height: 18 * ui,
                                    color: kMenuPanelBorder),
                                _WalletItem(
                                    icon: Icons.diamond_rounded,
                                    color: const Color(0xFFC06BFF),
                                    value: settings.gems),
                              ],
                            ),
                          ),
                          SizedBox(height: 14 * ui),

                          // ── Actions ────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: MenuPrimaryButton(
                                  label: 'GO TO SHOP',
                                  icon: Icons.shopping_cart_rounded,
                                  palette: TilePalette.purple,
                                  height: 48,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pushNamed('/shop');
                                  },
                                ),
                              ),
                              SizedBox(width: 10 * ui),
                              Expanded(
                                flex: 5,
                                child: MenuPrimaryButton(
                                  label: 'AWESOME!',
                                  height: 48,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
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
    );
  }
}

/// One column normally; identity | details side by side when [wide].
class _ProfileBody extends StatelessWidget {
  final bool wide;
  final List<Widget> identity;
  final List<Widget> details;

  const _ProfileBody(
      {required this.wide, required this.identity, required this.details});

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
          mainAxisSize: MainAxisSize.min, children: [...identity, ...details]);
    }
    final ui = MenuMetrics.of(context).contentUi;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Column(mainAxisSize: MainAxisSize.min, children: identity),
        ),
        SizedBox(width: 16 * ui),
        Expanded(
          flex: 6,
          child: Column(mainAxisSize: MainAxisSize.min, children: details),
        ),
      ],
    );
  }
}

// ── Stat tile ──────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return MenuPanel(
      radius: 14,
      padding: EdgeInsets.symmetric(horizontal: 10 * ui, vertical: 9 * ui),
      child: Row(
        children: [
          Container(
            width: 32 * ui,
            height: 32 * ui,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withAlpha(45)),
            child: Icon(icon, color: color, size: 18 * ui),
          ),
          SizedBox(width: 8 * ui),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: kMenuMuted,
                    fontSize: 9.5 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5 * ui,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  const _WalletItem(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Row(
      children: [
        Icon(icon, color: color, size: 20 * ui),
        SizedBox(width: 6 * ui),
        Text(
          '$value',
          style: TextStyle(
              color: Colors.white,
              fontSize: 15 * ui,
              fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
