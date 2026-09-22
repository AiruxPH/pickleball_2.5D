import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/player_profile_dialog.dart';

/// ─────────────────────────────────────────────────────────────
/// Main Menu Screen — Pickleball Stars style
/// Bright cartoon sports menu with yellow/blue palette,
/// big centered logo, PLAY button, match type sub-buttons,
/// side reward/challenge tabs, bottom collections/options.
/// ─────────────────────────────────────────────────────────────

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  // Floating logo animation
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  // Stars shimmer
  late AnimationController _shimmerController;

  // Entrance animation
  late AnimationController _enterController;
  late Animation<double> _enterFade;
  late Animation<double> _enterScale;

  // Ball spin background
  late AnimationController _ballController;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _enterFade = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _enterScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _enterController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<AudioService>().playBGM();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shimmerController.dispose();
    _ballController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  void _onPlay() => Navigator.pushNamed(context, '/mode-select');

  void _onQuickMatch() =>
      Navigator.pushNamed(context, '/game', arguments: {'mode': 'singles'});

  void _onLocalMatch() =>
      Navigator.pushNamed(context, '/game', arguments: {'mode': 'doubles'});

  void _onOptions() => Navigator.pushNamed(context, '/settings');

  void _onHowToPlay() => Navigator.pushNamed(context, '/how-to-play');

  void _onShop() => Navigator.pushNamed(context, '/shop');

  void _onTournament() => Navigator.pushNamed(context, '/tournament');

  void _onCareer() => Navigator.pushNamed(context, '/career');

  void _onLeaderboard() => Navigator.pushNamed(context, '/leaderboard');

  void _onAchievements() => Navigator.pushNamed(context, '/achievements');

  void _onTraining() => Navigator.pushNamed(context, '/training');


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      body: Stack(
        children: [
          // ── Tournament arena gradient background ───────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF070B14), Color(0xFF0B132B), Color(0xFF162544)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ── Court preview at bottom ──────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: isLandscape ? size.height * 0.42 : size.height * 0.35,
              child: CustomPaint(
                painter: _MenuCourtPainter(),
              ),
            ),
          ),

          // ── Main Content (Fully Responsive for Landscape & Portrait) ─
          Positioned.fill(
            child: FadeTransition(
              opacity: _enterFade,
              child: ScaleTransition(
                scale: _enterScale,
                child: SafeArea(
                  child: isLandscape
                      ? _buildLandscapeLayout(size)
                      : _buildPortraitLayout(size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Responsive Portrait Layout ───────────────────────────────
  Widget _buildPortraitLayout(Size size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 60) {
          return const SizedBox();
        }
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _TopBar(
                      onShopTap: _onShop,
                      onOptionsTap: _onOptions,
                    ),
                  ),

                  // Middle section
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Floating Logo
                              AnimatedBuilder(
                                animation: _floatAnim,
                                builder: (_, child) => Transform.translate(
                                  offset: Offset(0, _floatAnim.value),
                                  child: child,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _LogoSection(shimmer: _shimmerController),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Main PLAY CTA
                              _PlayButton(onTap: _onPlay),

                              const SizedBox(height: 14),

                              // Match type sub-buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _SubMatchButton(
                                      label: 'SINGLES 1v1',
                                      icon: Icons.person_rounded,
                                      onTap: _onQuickMatch,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SubMatchButton(
                                      label: 'DOUBLES 2v2',
                                      icon: Icons.group_rounded,
                                      onTap: _onLocalMatch,
                                    ),
                                  ),
                                ],
                              ),

                              // New mode buttons row
                              const SizedBox(height: 10),
                              _buildNewModeButtons(),

                              // Daily challenge card
                              const SizedBox(height: 10),
                              const _DailyChallengeCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom actions bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BottomMenuButton(
                          label: 'HOW TO PLAY',
                          icon: Icons.help_outline_rounded,
                          onTap: _onHowToPlay,
                        ),
                        _BottomMenuButton(
                          label: 'PRO SHOP',
                          icon: Icons.storefront_rounded,
                          highlightColor: const Color(0xFFFFC200),
                          onTap: _onShop,
                        ),
                        _BottomMenuButton(
                          label: 'OPTIONS',
                          icon: Icons.settings_rounded,
                          onTap: _onOptions,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewModeButtons() {
    return Row(
      children: [
        Expanded(child: _ModeButton(label: 'TOURNAMENT', icon: Icons.local_activity_rounded, color: const Color(0xFFF59E0B), onTap: _onTournament)),
        const SizedBox(width: 6),
        Expanded(child: _ModeButton(label: 'CAREER', icon: Icons.trending_up_rounded, color: const Color(0xFF34D399), onTap: _onCareer)),
        const SizedBox(width: 6),
        Expanded(child: _ModeButton(label: 'TRAINING', icon: Icons.fitness_center_rounded, color: const Color(0xFF38BDF8), onTap: _onTraining)),
        const SizedBox(width: 6),
        Expanded(child: _ModeButton(label: 'RANKS', icon: Icons.leaderboard_rounded, color: const Color(0xFF8B5CF6), onTap: _onLeaderboard)),
        const SizedBox(width: 6),
        Expanded(child: _ModeButton(label: 'TROPHIES', icon: Icons.emoji_events_rounded, color: const Color(0xFFEC4899), onTap: _onAchievements)),
      ],
    );
  }

  // ── Responsive Landscape Layout ──────────────────────────────
  Widget _buildLandscapeLayout(Size size) {
    return Column(
      children: [
        // Top bar (constrained width)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: _TopBar(
                onShopTap: _onShop,
                onOptionsTap: _onOptions,
              ),
            ),
          ),
        ),

        // 2-Column Split Content
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Logo, Daily Challenge, How to Play & Shop
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _floatAnim,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _floatAnim.value * 0.4),
                                child: child,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _LogoSection(shimmer: _shimmerController),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _DailyChallengeCard(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _BottomMenuButton(
                                  label: 'HOW TO PLAY',
                                  icon: Icons.help_outline_rounded,
                                  onTap: _onHowToPlay,
                                ),
                                const SizedBox(width: 12),
                                _BottomMenuButton(
                                  label: 'PRO SHOP',
                                  icon: Icons.storefront_rounded,
                                  highlightColor: const Color(0xFFFFC200),
                                  onTap: _onShop,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Subtle Vertical Divider
                    Container(
                      width: 1.2,
                      height: 180,
                      color: Colors.white.withAlpha(25),
                    ),

                    // Right Column: Play CTA, Quick Matches & Mode Row
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PlayButton(onTap: _onPlay),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _SubMatchButton(
                                    label: 'SINGLES 1v1',
                                    icon: Icons.person_rounded,
                                    onTap: _onQuickMatch,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SubMatchButton(
                                    label: 'DOUBLES 2v2',
                                    icon: Icons.group_rounded,
                                    onTap: _onLocalMatch,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildNewModeButtons(),
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
      ],
    );
  }
}

// ── Top bar: profile + currency + settings ─────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback? onShopTap;
  final VoidCallback? onOptionsTap;

  const _TopBar({this.onShopTap, this.onOptionsTap});

  @override
  Widget build(BuildContext context) {
    GameSettings? settings;
    try {
      settings = context.watch<GameSettings>();
    } catch (_) {}

    final coins = settings?.coins.toString() ?? '10386';
    final gems = settings?.gems.toString() ?? '8161';

    return Row(
      children: [
        // Clickable Profile pill
        const _ProfileBadge(),

        const Spacer(),

        // Currency — coins
        _CurrencyBadge(
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFFFFC200),
          value: coins,
          onTap: onShopTap,
        ),
        const SizedBox(width: 8),
        // Currency — gems
        _CurrencyBadge(
          icon: Icons.diamond_rounded,
          color: const Color(0xFFAB47BC),
          value: gems,
          onTap: onShopTap,
        ),
        if (onOptionsTap != null) ...[
          const SizedBox(width: 8),
          _OptionsIconButton(onTap: onOptionsTap!),
        ],
      ],
    );
  }
}

// ── Options Gear Icon Button for Top Bar ───────────────────────
class _OptionsIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OptionsIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          try {
            Provider.of<AudioService>(context, listen: false).playButtonClick();
          } catch (_) {}
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(7.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF082B6B),
                blurRadius: 0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Color(0xFFFFC200),
            size: 16,
          ),
        ),
      ),
    );
  }
}

// ── Interactive Profile Badge (pill) ───────────────────────────
class _ProfileBadge extends StatefulWidget {
  const _ProfileBadge();

  @override
  State<_ProfileBadge> createState() => _ProfileBadgeState();
}

class _ProfileBadgeState extends State<_ProfileBadge>
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

  void _onTap() {
    PlayerProfileDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    GameSettings? settings;
    try {
      settings = context.watch<GameSettings>();
    } catch (_) {}

    final playerName = settings?.playerName ?? 'John Doe';
    final playerLvl = settings?.playerLevel ?? 5;
    final xp = settings?.playerXp ?? 580;
    final maxXp = settings?.playerMaxXp ?? 750;
    final avatarIndex = settings?.avatarIndex ?? 0;
    final avatarIcon = getProfileAvatarIcon(avatarIndex);
    final xpRatio = (xp / maxXp).clamp(0.0, 1.0);

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
          _onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final pressed = _ctrl.value > 0.5;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: pressed
                        ? const [Color(0xFF1976D2), Color(0xFF1565C0)]
                        : const [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: pressed ? const Color(0xFFFFC200) : const Color(0xFF42A5F5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF082B6B),
                      blurRadius: 0,
                      offset: pressed ? const Offset(0, 1) : const Offset(0, 3),
                    ),
                    if (pressed)
                      const BoxShadow(
                        color: Color(0x44FFC200),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4488FF),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(avatarIcon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFC200),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LVL $playerLvl',
                          style: const TextStyle(
                            color: Color(0xFFFFC200),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    // XP bar
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 60,
                        height: 4,
                        child: LinearProgressIndicator(
                          value: xpRatio,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC200)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final VoidCallback? onTap;

  const _CurrencyBadge({
    required this.icon,
    required this.color,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFF082B6B), blurRadius: 0, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 5),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(200),
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 10),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            try {
              Provider.of<AudioService>(context, listen: false).playButtonClick();
            } catch (_) {}
            onTap!();
          },
          child: badge,
        ),
      );
    }
    return badge;
  }
}

// ── Logo section ───────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  final AnimationController shimmer;
  const _LogoSection({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "PICKLEBALL" text
          const _StrokedText(
            text: 'PICKLEBALL',
            fontSize: 34,
            strokeColor: Color(0xFF0F172A),
            fillColor: Color(0xFFF8FAFC),
            letterSpacing: 4,
          ),
          // "PRO TOUR" text
          const _StrokedText(
            text: 'PRO TOUR',
            fontSize: 48,
            strokeColor: Color(0xFF0F172A),
            fillColor: Color(0xFFF59E0B),
            letterSpacing: 6,
            height: 0.90,
          ),
          const SizedBox(height: 8),
          // 3 gold tournament stars
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) {
                final t = ((shimmer.value - i * 0.25) % 1.0);
                final bright = t < 0.3
                    ? (t / 0.3)
                    : (t < 0.6 ? (1.0 - ((t - 0.3) / 0.3)) : 0.0);
                final alpha = (180 + bright * 75).toInt().clamp(0, 255);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.star_rounded,
                    color: Color.lerp(
                      const Color(0xFFF59E0B),
                      Colors.white,
                      bright * 0.6,
                    ),
                    size: 28,
                    shadows: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withAlpha(alpha),
                        blurRadius: 8 + bright * 10,
                      ),
                    ],
                  ),
                );
              },
            )),
          ),
        ],
      ),
    );
  }
}

// ── Stroked text widget for cartoon logo effect ─────────────────
class _StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color strokeColor;
  final Color fillColor;
  final double letterSpacing;
  final double height;

  const _StrokedText({
    required this.text,
    required this.fontSize,
    required this.strokeColor,
    required this.fillColor,
    this.letterSpacing = 2,
    this.height = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.orbitron,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: height,
    );
    return Stack(
      children: [
        // Stroke layer
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = strokeColor,
          ),
        ),
        // Fill layer
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(color: fillColor),
        ),
      ],
    );
  }
}

// ── PLAY button — big yellow CTA ──────────────────────────────
class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          HapticFeedback.mediumImpact();
          try {
            Provider.of<AudioService>(context, listen: false).playButtonClick();
          } catch (_) {}
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
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFEF62), Color(0xFFFFC200), Color(0xFFE5A800)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: const Color(0xFFB37800), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A5200),
                    blurRadius: 0,
                    offset: pressed ? const Offset(0, 2) : const Offset(0, 6),
                  ),
                  const BoxShadow(
                    color: Color(0x44FFC200),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Color(0xFF0D47A1), size: 32,
                  shadows: [Shadow(color: Colors.white38, blurRadius: 4)]),
              SizedBox(width: 8),
              Text(
                'PLAY',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D47A1),
                  letterSpacing: 6,
                  shadows: [
                    Shadow(color: Colors.white38, blurRadius: 4)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

// ── Sub-match button (Quick Match / Local Match) ───────────────
class _SubMatchButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SubMatchButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SubMatchButton> createState() => _SubMatchButtonState();
}

class _SubMatchButtonState extends State<_SubMatchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
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
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final pressed = _ctrl.value > 0.5;
            return Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2), Color(0xFF0D47A1)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: const Color(0xFF082B6B), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF082B6B),
                    blurRadius: 0,
                    offset: pressed ? const Offset(0, 2) : const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: const Color(0xFFFFC200), size: 18),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1))
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}



// ── Bottom menu button ─────────────────────────────────────────
class _BottomMenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? highlightColor;

  const _BottomMenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlightColor,
  });

  @override
  State<_BottomMenuButton> createState() => _BottomMenuButtonState();
}

class _BottomMenuButtonState extends State<_BottomMenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    final isHighlighted = widget.highlightColor != null;

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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHighlighted
                    ? [const Color(0xFFD97706), const Color(0xFF78350F)]
                    : const [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.highlightColor ?? const Color(0xFF42A5F5),
                width: isHighlighted ? 2.4 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted ? const Color(0x66D97706) : const Color(0xFF082B6B),
                  blurRadius: isHighlighted ? 10 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: isHighlighted ? const Color(0xFFFEF08A) : const Color(0xFFFFC200),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Menu court preview painter ─────────────────────────────────
class _MenuCourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Stadium background
    final stadPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0B132B), Color(0xFF1E293B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.6), stadPaint);

    // Court apron
    final apronPath = Path()
      ..moveTo(w * 0.02, h * 0.32)
      ..lineTo(w * 0.98, h * 0.32)
      ..lineTo(w * 1.15, h)
      ..lineTo(w * -0.15, h)
      ..close();
    canvas.drawPath(apronPath, Paint()..color = const Color(0xFF162544));

    // Court surface
    final courtPath = Path()
      ..moveTo(w * 0.07, h * 0.35)
      ..lineTo(w * 0.93, h * 0.35)
      ..lineTo(w * 1.08, h)
      ..lineTo(w * -0.08, h)
      ..close();
    canvas.drawPath(
      courtPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, h * 0.3, w, h * 0.7)),
    );

    // Kitchen zone
    final kitchenPath = Path()
      ..moveTo(w * 0.07, h * 0.35)
      ..lineTo(w * 0.93, h * 0.35)
      ..lineTo(w * 0.98, h * 0.58)
      ..lineTo(w * 0.02, h * 0.58)
      ..close();
    canvas.drawPath(kitchenPath, Paint()..color = const Color(0xFF007799));

    // Court lines
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Sidelines
    canvas.drawLine(Offset(w * 0.07, h * 0.35), Offset(w * -0.08, h), linePaint);
    canvas.drawLine(Offset(w * 0.93, h * 0.35), Offset(w * 1.08, h), linePaint);

    // Kitchen line
    canvas.drawLine(Offset(w * 0.02, h * 0.58), Offset(w * 0.98, h * 0.58), linePaint);

    // Center line
    canvas.drawLine(Offset(w * 0.5, h * 0.58), Offset(w * 0.5, h), linePaint);

    // Net
    final netPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.06, h * 0.44), Offset(w * 0.94, h * 0.44), netPaint);

    // Net posts
    final postPaint = Paint()..color = const Color(0xFF334155)..strokeWidth = 4;
    canvas.drawLine(Offset(w * 0.06, h * 0.36), Offset(w * 0.06, h * 0.45), postPaint);
    canvas.drawLine(Offset(w * 0.94, h * 0.36), Offset(w * 0.94, h * 0.45), postPaint);

    // Subtle spectator silhouettes
    final crowdPaint = Paint()..color = const Color(0x33475569);
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 18; col++) {
        canvas.drawCircle(
          Offset(w * 0.05 + col * w * 0.055, h * 0.10 + row * h * 0.10),
          w * 0.012,
          crowdPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}


// ── Compact mode button for the new features row ───────────────
class _ModeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapCancel: () => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.reverse();
          HapticFeedback.selectionClick();
          try {
            Provider.of<AudioService>(context, listen: false).playButtonClick();
          } catch (_) {}
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: widget.color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.color.withAlpha(80), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: widget.color, size: 18),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Daily Challenge card shown on main menu ────────────────────
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context) {
    GameSettings? settings;
    try {
      settings = context.watch<GameSettings>();
    } catch (_) {}

    if (settings == null) return const SizedBox.shrink();

    final completed = settings.dailyChallengeCompleted;
    final progress = settings.dailyChallengeProgress;
    final target = settings.dailyChallengeTarget;
    final desc = settings.dailyChallengeDescription;
    final fraction = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFF34D399).withAlpha(18)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed
              ? const Color(0xFF34D399).withAlpha(100)
              : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (completed ? const Color(0xFF34D399) : AppColors.primary).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              completed ? Icons.check_circle_rounded : Icons.today_rounded,
              color: completed ? const Color(0xFF34D399) : AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'DAILY CHALLENGE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    if (completed) ...[
                      const SizedBox(width: 6),
                      const Text('✓ DONE', style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF34D399),
                      )),
                    ],
                  ],
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!completed && target > 1) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: const Color(0xFF0F172A),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+500 🪙', style: TextStyle(fontSize: 10, color: Color(0xFFFFC200), fontWeight: FontWeight.w700)),
              Text('+50 💎', style: TextStyle(fontSize: 10, color: Color(0xFFAB47BC))),
            ],
          ),
        ],
      ),
    );
  }
}
