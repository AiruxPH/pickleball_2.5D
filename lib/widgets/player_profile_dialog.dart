import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';

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
/// PlayerProfileDialog — Cartoon sports player profile modal
/// Styled to match Pickleball Stars theme
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
      pageBuilder: (context, anim, secondaryAnim) => const PlayerProfileDialog(),
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
    final avatarIcon = getProfileAvatarIcon(settings.avatarIndex);
    final xpProgress = (settings.playerXp / settings.playerMaxXp).clamp(0.0, 1.0);
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 340,
            maxHeight: screenHeight * 0.9,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1976D2),
                  Color(0xFF0D47A1),
                  Color(0xFF082B6B),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF42A5F5), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF061A40),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header Banner ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF082B6B)],
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: Color(0xFFFFC200), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'PLAYER PROFILE',
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        // Close button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1565C0),
                              border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Avatar & Level Badge ─────────────────────
                          Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4488FF), Color(0xFF1E88E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(avatarIcon, color: Colors.white, size: 36),
                                ),
                                Positioned(
                                  bottom: -5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFFEF62), Color(0xFFFFC200)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFB37800), width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Color(0xFF7A5200), size: 11),
                                        const SizedBox(width: 2),
                                        Text(
                                          'LVL ${settings.playerLevel}',
                                          style: const TextStyle(
                                            fontFamily: AppFonts.orbitron,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF082B6B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── Avatar selector row ──────────────────────
                          Text(
                            'CHOOSE AVATAR',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withAlpha(180),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(kProfileAvatars.length, (idx) {
                              final isSelected = settings.avatarIndex == idx;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  settings.avatarIndex = idx;
                                  context.read<SettingsService>().save(settings);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFFFFC200)
                                        : const Color(0xFF0D47A1),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : const Color(0xFF42A5F5),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    kProfileAvatars[idx],
                                    size: 16,
                                    color: isSelected ? const Color(0xFF082B6B) : Colors.white,
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 10),

                          // ── Player Name with Edit ────────────────────
                          if (_isEditingName)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 160,
                                  height: 34,
                                  child: TextField(
                                    controller: _nameController,
                                    autofocus: true,
                                    maxLength: 16,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      filled: true,
                                      fillColor: const Color(0xFF082B6B),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFFFC200), width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFFFC200), width: 1.5),
                                      ),
                                    ),
                                    onSubmitted: (_) => _saveName(settings),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _saveName(settings),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  settings.playerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _nameController.text = settings.playerName;
                                    setState(() => _isEditingName = true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF42A5F5), width: 1),
                                    ),
                                    child: const Icon(Icons.edit_rounded, color: Color(0xFFFFC200), size: 13),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 3),

                          // Subtitle badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF082B6B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1565C0), width: 1),
                            ),
                            child: const Text(
                              '⭐ RISING STAR • AMATEUR PRO',
                              style: TextStyle(
                                color: Color(0xFFBBDEFB),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── XP & Level Progress Card ─────────────────
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'LEVEL PROGRESS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '${settings.playerXp} / ${settings.playerMaxXp} XP',
                                      style: const TextStyle(
                                        color: Color(0xFFFFC200),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        color: const Color(0xFF082B6B),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: xpProgress,
                                        child: Container(
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Color(0xFFFFEE66), Color(0xFFFFC200)],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC200), size: 12),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Next: +250 Coins & Pro Paddle Unlock',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(200),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── Career Statistics Grid ───────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'MATCHES',
                                  value: '${settings.matchesPlayed}',
                                  icon: Icons.sports_tennis_rounded,
                                  iconColor: const Color(0xFF42A5F5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StatTile(
                                  label: 'WINS',
                                  value: '${settings.matchesWon} (81%)',
                                  icon: Icons.workspace_premium_rounded,
                                  iconColor: const Color(0xFFFFC200),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'WIN STREAK',
                                  value: '${settings.winStreak} Matches',
                                  icon: Icons.local_fire_department_rounded,
                                  iconColor: const Color(0xFFFF7043),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StatTile(
                                  label: 'TOTAL ACES',
                                  value: '${settings.aces}',
                                  icon: Icons.bolt_rounded,
                                  iconColor: const Color(0xFFFFEE58),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ── Wallet / Balance Summary ─────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF082B6B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1565C0), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC200), size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${settings.coins}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 14, color: Colors.white24),
                                Row(
                                  children: [
                                    const Icon(Icons.diamond_rounded, color: Color(0xFFAB47BC), size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${settings.gems}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Action Buttons ───────────────────────────
                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _DialogActionButton(
                                  label: 'VISIT PRO SHOP',
                                  gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                                  borderColor: const Color(0xFFFFC200),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pushNamed('/shop');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: _DialogActionButton(
                                  label: 'AWESOME!',
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).pop();
                                  },
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

// ── Stat Tile Widget ───────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1565C0), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(160),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3D Yellow Cartoon Dialog Action Button ──────────────────────
class _DialogActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color>? gradient;
  final Color? borderColor;

  const _DialogActionButton({
    required this.label,
    required this.onTap,
    this.gradient,
    this.borderColor,
  });

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final pressed = _ctrl.value > 0.5;
            return Container(
              width: double.infinity,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: widget.gradient ??
                      const [Color(0xFFFFEF62), Color(0xFFFFC200), Color(0xFFE5A800)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: widget.borderColor ?? const Color(0xFFB37800),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A5200),
                    blurRadius: 0,
                    offset: pressed ? const Offset(0, 1.5) : const Offset(0, 3.5),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0D47A1),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
