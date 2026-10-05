import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/career.dart';
import '../services/audio_service.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/player_profile_dialog.dart';
import '../widgets/menu/menu_top_bar.dart';
import '../widgets/menu/menu_tiles.dart';
import '../widgets/menu/daily_challenge_bar.dart';
import '../widgets/menu/menu_bottom_nav.dart';

/// ─────────────────────────────────────────────────────────────
/// Main Menu Screen
///
/// Scene art from assets/images/menu/ with interactive HUD on top:
/// - MenuTopBar: Profile badge with XP & level, currency pills (>=44px hit targets),
///   Settings and Help icons with accessible tooltips.
/// - MenuTiles: High-contrast Play, Career, Tournament, Shop, and Training tiles.
/// - DailyChallengeBar: Vibrant progress bar, clear completion states, larger rewards.
/// - MenuBottomNav: Contrast-enhanced navigation with active indicators and badges.
/// ─────────────────────────────────────────────────────────────

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _enter.forward();

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
    _enter.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _go(String route) => Navigator.pushNamed(context, route);
  void _onPlay() => _go('/mode-select');
  void _onCareer() => _go('/career');
  void _onTournament() => _go('/tournament');
  void _onShop() => _go('/shop');
  void _onTraining() => _go('/training');
  void _onSettings() => _go('/settings');
  void _onHowToPlay() => _go('/how-to-play');
  void _onLeaderboard() => _go('/leaderboard');
  void _onAchievements() => _go('/achievements');
  void _onProfile() => PlayerProfileDialog.show(context);

  /// Staggered slide + fade for entrance.
  Widget _reveal(Widget child, double start,
      {Offset from = const Offset(0.12, 0)}) {
    final curve = CurvedAnimation(
      parent: _enter,
      curve: Interval(start, math.min(1.0, start + 0.5),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: from, end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width < 100 || size.height < 100) {
      return const Scaffold(backgroundColor: kMenuCourtBlue);
    }
    final landscape = size.width >= size.height;
    final m = MenuMetrics.of(context);
    final ui = m.ui;

    GameSettings? settings;
    try {
      settings = context.watch<GameSettings>();
    } catch (_) {}

    return Scaffold(
      backgroundColor: kMenuCourtBlue,
      body: Stack(
        children: [
          // ── Scene art (shared with the splash screen) ─────────
          const Positioned.fill(child: MenuBackdrop()),

          SafeArea(
            bottom: false,
            child: ClipRect(
              child: Column(
                children: [
                  _reveal(
                    Padding(
                      padding: EdgeInsets.fromLTRB(14 * ui, 8 * ui, 14 * ui, 0),
                      child: MenuTopBar(
                        ui: ui,
                        compact: !landscape,
                        onProfile: _onProfile,
                        onShop: _onShop,
                        onSettings: _onSettings,
                        onHelp: _onHowToPlay,
                      ),
                    ),
                    0.0,
                    from: const Offset(0, -0.4),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(14 * ui, 10 * ui, 14 * ui, 10 * ui),
                      child: landscape
                          ? _landscapeBody(size, ui, settings)
                          : _portraitBody(ui, settings),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom navigation ─────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _reveal(
              MenuBottomNav(
                ui: ui,
                hasAchievementBadge: settings?.hasUnseenAchievements ?? false,
                onLeaderboard: _onLeaderboard,
                onAchievements: _onAchievements,
              ),
              0.35,
              from: const Offset(0, 0.6),
            ),
          ),
        ],
      ),
    );
  }

  double _navHeight(double ui) => MenuMetrics.of(context).navHeight;

  Widget _tiles(double ui, GameSettings? settings) {
    final gap = 10 * ui;

    // Dynamic career subtitle & badge
    final career = settings?.career;
    final careerSubtitle = career != null
        ? 'Season ${career.currentSeason} · Match ${career.matchesInSeason + 1}/8 · ${career.rank.displayName}'
        : 'Climb the ranks, season by season.';

    // Dynamic tournament subtitle & badge
    final tournament = settings?.tournament;
    final tournamentSubtitle = tournament != null
        ? (tournament.isComplete && tournament.playerWon
            ? 'CHAMPION · Defend your title!'
            : '${tournament.currentRoundName} · vs ${tournament.currentOpponent.name}')
        : 'Compete in brackets and earn trophies.';
    final tournamentBadge = (tournament != null && tournament.isComplete && tournament.playerWon)
        ? 'CHAMPION'
        : 'BRACKET';

    return LayoutBuilder(
      builder: (context, constraints) {
        final column = Column(
          children: [
            Expanded(
              flex: 11,
              child: _reveal(
                PlayTile(ui: ui, idle: _idle, onTap: _onPlay),
                0.1,
              ),
            ),
            SizedBox(height: gap),
            Expanded(
              flex: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _reveal(
                      MenuTile(
                        ui: ui,
                        title: 'CAREER',
                        subtitle: careerSubtitle,
                        badgeText: 'SEASON ${career?.currentSeason ?? 1}',
                        badgeColor: const Color(0xFF38BDF8),
                        icon: Icons.military_tech_rounded,
                        colors: const [
                          Color(0xFF3B8BFF),
                          Color(0xFF1B5FD9),
                          Color(0xFF1449B5),
                        ],
                        border: const Color(0xFF7DB2FF),
                        onTap: _onCareer,
                      ),
                      0.18,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _reveal(
                      MenuTile(
                        ui: ui,
                        title: 'TOURNAMENT',
                        subtitle: tournamentSubtitle,
                        badgeText: tournamentBadge,
                        badgeColor: const Color(0xFF34D399),
                        icon: Icons.emoji_events_rounded,
                        colors: const [
                          Color(0xFF2ED18A),
                          Color(0xFF14A866),
                          Color(0xFF0B8A52),
                        ],
                        border: const Color(0xFF7EEDB9),
                        onTap: _onTournament,
                      ),
                      0.24,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: gap),
            Expanded(
              flex: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _reveal(
                      MenuTile(
                        ui: ui,
                        title: 'SHOP',
                        subtitle: 'Equipment, paddles & athlete skins.',
                        badgeText: (settings?.canClaimDailyBonus ?? false)
                            ? 'BONUS'
                            : null,
                        badgeColor: const Color(0xFFFFC21A),
                        icon: Icons.shopping_cart_rounded,
                        colors: const [
                          Color(0xFF8B5CFF),
                          Color(0xFF6A3BE6),
                          Color(0xFF5227C4),
                        ],
                        border: const Color(0xFFBFA6FF),
                        onTap: _onShop,
                      ),
                      0.30,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _reveal(
                      MenuTile(
                        ui: ui,
                        title: 'TRAINING',
                        subtitle: 'Target practice, ball machine & drills.',
                        badgeText: 'DRILLS',
                        badgeColor: const Color(0xFFFB923C),
                        icon: Icons.track_changes_rounded,
                        colors: const [
                          Color(0xFFEA580C),
                          Color(0xFFC2410C),
                          Color(0xFF9A3412),
                        ],
                        border: const Color(0xFFFB923C),
                        onTap: _onTraining,
                      ),
                      0.36,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final targetH = 270.0 * ui;
        if (constraints.maxHeight > 0 && constraints.maxHeight < targetH) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth > 0 ? constraints.maxWidth : 380 * ui,
              height: targetH,
              child: column,
            ),
          );
        }
        return column;
      },
    );
  }

  Widget _landscapeBody(Size size, double ui, GameSettings? settings) {
    final tilesWidth = MenuMetrics.of(context).tilesWidth;
    return Padding(
      padding: EdgeInsets.only(bottom: _navHeight(ui)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: the art shows through; daily challenge sits at the bottom
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 440 * ui),
                child: _reveal(
                  DailyChallengeBar(ui: ui),
                  0.4,
                  from: const Offset(-0.2, 0),
                ),
              ),
            ),
          ),
          SizedBox(width: 12 * ui),
          SizedBox(width: tilesWidth, child: _tiles(ui, settings)),
        ],
      ),
    );
  }

  Widget _portraitBody(double ui, GameSettings? settings) {
    return Padding(
      padding: EdgeInsets.only(bottom: _navHeight(ui)),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _reveal(
            DailyChallengeBar(ui: ui),
            0.4,
            from: const Offset(0, 0.3),
          ),
          SizedBox(height: 10 * ui),
          Expanded(flex: 18, child: _tiles(ui, settings)),
        ],
      ),
    );
  }
}
