import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/career.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';
import '../widgets/menu/single_slanted_card.dart';
import '../widgets/menu/angular_frames.dart';

/// ─────────────────────────────────────────────────────────────
/// Game Over / Victory Screen
/// Shows final score + animated win/lose presentation
/// ─────────────────────────────────────────────────────────────

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  // Main entrance animation
  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Score count-up animation
  late AnimationController _scoreCtrl;
  late Animation<int> _playerScoreAnim;
  late Animation<int> _aiScoreAnim;

  // Confetti / particles
  late AnimationController _confettiCtrl;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  late bool _playerWon;
  late int _playerScore;
  late int _aiScore;
  Map<String, dynamic> _rematchArguments = <String, dynamic>{};

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.elasticOut),
    );

    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _playerScore = ((args?['playerScore'] as num?)?.toInt()) ?? 0;
    _aiScore = ((args?['aiScore'] as num?)?.toInt()) ?? 0;
    _playerWon = (args?['playerWon'] as bool?) ?? false;
    final rematchArguments = args?['rematchArguments'];
    _rematchArguments = rematchArguments is Map
        ? Map<String, dynamic>.from(rematchArguments)
        : <String, dynamic>{};

    // Setup score animations
    _playerScoreAnim = IntTween(begin: 0, end: _playerScore).animate(
      CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut),
    );
    _aiScoreAnim = IntTween(begin: 0, end: _aiScore).animate(
      CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut),
    );

    // Generate particles
    if (_playerWon) {
      _particles.clear();
      for (int i = 0; i < 60; i++) {
        _particles.add(_Particle(rng: _rng));
      }
    }

    // Record match stats AFTER the current build frame to avoid calling
    // GameSettings.notifyListeners() during build (setState during build error).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recordMatchStats(args);
    });

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _enterCtrl.forward();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _scoreCtrl.forward();
            if (_playerWon) _confettiCtrl.repeat();
          }
        });
      }
    });
  }

  bool _statsRecorded = false;
  void _recordMatchStats(Map? args) {
    if (_statsRecorded) return;
    _statsRecorded = true;

    final settings = context.read<GameSettings>();
    final smashes = ((args?['smashes'] as num?)?.toInt()) ?? 0;
    final longestRally = ((args?['longestRally'] as num?)?.toInt()) ?? 0;
    final isTournament = (args?['isTournament'] as bool?) ?? false;
    final isCareer = (args?['isCareer'] as bool?) ?? false;
    final matchDuration = (args?['matchDuration'] as double?) ?? 0.0;

    final isPerfect = _playerWon && _aiScore == 0;
    final isComeback = _playerWon && (args?['wasDown09'] as bool? ?? false);

    settings.recordMatchResult(
      won: _playerWon,
      playerScore: _playerScore,
      aiScore: _aiScore,
      smashesThisMatch: smashes,
      longestRallyThisMatch: longestRally,
      isPerfect: isPerfect,
      isComeback: isComeback,
      isTournament: isTournament,
      matchDurationSeconds: matchDuration,
    );

    // Daily challenge
    if (_playerWon) settings.addDailyChallengeProgress('win_match', 1);
    if (smashes > 0) settings.addDailyChallengeProgress('smash', smashes);
    if (longestRally > 0) settings.addDailyChallengeProgress('rally', longestRally);

    // Career mode result
    if (isCareer) {
      final xp = _playerWon ? 100 + _playerScore * 5 : 20 + _playerScore * 2;
      final coins = _playerWon ? 300 + _playerScore * 10 : 50;
      settings.career.addResult(CareerMatchResult(
        opponentName: (args?['opponentName'] as String?) ?? 'CPU',
        playerScore: _playerScore,
        opponentScore: _aiScore,
        won: _playerWon,
        xpEarned: xp,
        coinsEarned: coins,
      ));
      settings.coins = settings.coins + coins;
    }

    // Tournament result
    if (isTournament) {
      final completedRound = settings.tournament.currentRound;
      settings.tournament.recordResult(_playerWon);
      if (_playerWon) {
        final prizeCoins = completedRound == 0
            ? 500
            : completedRound == 1
                ? 1500
                : 5000;
        settings.coins = settings.coins + prizeCoins;
      }
    }

    // Coin reward for regular wins
    if (!isCareer && !isTournament && _playerWon) {
      settings.coins = settings.coins + 200 + _playerScore * 15;
    }

    // Save
    context.read<SettingsService>().save(settings);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _scoreCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070B14), Color(0xFF0B132B), Color(0xFF162544)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // ── Confetti (only on win) ─────────────────────
            if (_playerWon)
              AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiCtrl.value,
                    size: size,
                  ),
                  size: Size.infinite,
                ),
              ),

            // ── Main content (Fully Responsive) ───────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 860 : 440,
                      ),
                      child: isLandscape
                          ? _buildLandscapeContent(context)
                          : _buildPortraitContent(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        // ── Result banner ─────────────────────
        ScaleTransition(
          scale: _scaleAnim,
          child: _buildResultBanner(),
        ),
        const SizedBox(height: 24),

        // ── Score display ─────────────────────
        _buildScoreDisplay(),
        const SizedBox(height: 24),

        // ── Divider ───────────────────────────
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 20),

        // ── Stats ─────────────────────────────
        _buildMatchSummary(),
        const SizedBox(height: 28),

        // ── Action buttons ─────────────────────
        _buildButtons(context),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLandscapeContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Result & Score
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: _buildResultBanner(),
                ),
                const SizedBox(height: 16),
                _buildScoreDisplay(),
              ],
            ),
          ),
        ),

        // Vertical divider
        Container(
          width: 1.2,
          height: 240,
          color: Colors.white.withAlpha(25),
        ),

        // Right Column: Summary Stats & Buttons
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMatchSummary(),
                const SizedBox(height: 20),
                _buildButtons(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentBadge({required bool isVictory}) {
    final glowColor = isVictory ? const Color(0xFFF59E0B) : const Color(0xFF64748B);
    final rimColor = isVictory ? const Color(0xFFFDE68A) : const Color(0xFF94A3B8);
    final iconData = isVictory ? Icons.workspace_premium_rounded : Icons.sports_tennis_rounded;

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isVictory
              ? const [Color(0xFF2E2005), Color(0xFF181206), Color(0xFF0F172A)]
              : const [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF070B14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: rimColor.withAlpha(isVictory ? 230 : 130),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withAlpha(isVictory ? 60 : 25),
            blurRadius: 12,
          ),
          const BoxShadow(
            color: Color(0x80000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner decorative ring
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isVictory
                    ? const Color(0x44F59E0B)
                    : const Color(0x22FFFFFF),
                width: 1.0,
              ),
            ),
          ),
          Icon(
            iconData,
            size: 46,
            color: isVictory ? const Color(0xFFFFD700) : const Color(0xFFCBD5E1),
            shadows: [
              Shadow(
                color: glowColor.withAlpha(180),
                blurRadius: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    if (_playerWon) {
      return Column(
        children: [
          _buildTournamentBadge(isVictory: true),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFEF08A), Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(b),
            child: const Text(
              'VICTORY',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33F59E0B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x66F59E0B)),
            ),
            child: const Text(
              'CHAMPIONS TOUR • MATCH WINNER',
              style: TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Great match — you won!',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildTournamentBadge(isVictory: false),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(b),
            child: const Text(
              'MATCH OVER',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: const Text(
              'CHAMPIONS TOUR • FINAL RESULT',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hard-fought battle across all sets',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildScoreDisplay() {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final scoreFontSize = isLandscape ? 44.0 : 60.0;

    return AnimatedBuilder(
      animation: _scoreCtrl,
      builder: (context, _) {
        return SingleSlantedCard(
          angleDegrees: 7.0,
          borderWidth: 1.8,
          borderColor: const Color(0xFF1E3A66),
          colors: const [
            Color(0xE60E1E38),
            Color(0xD90A172D),
            Color(0xCC061022),
          ],
          padding: EdgeInsets.symmetric(
            vertical: isLandscape ? 14 : 24,
            horizontal: 20,
          ),
          child: Row(
            children: [
              // Player
              Expanded(
                child: Column(
                  children: [
                    const Text('YOU',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      '${_playerScoreAnim.value}',
                      style: TextStyle(
                        fontFamily: AppFonts.orbitron,
                        fontSize: scoreFontSize,
                        fontWeight: FontWeight.w800,
                        color: _playerWon
                            ? AppColors.scorePlayer
                            : AppColors.textSecondary,
                        shadows: [
                          Shadow(
                            color: (_playerWon
                                    ? AppColors.scorePlayer
                                    : AppColors.textSecondary)
                                .withAlpha(60),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    if (_playerWon)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ParallelogramBadge(
                          color: AppColors.scorePlayer.withAlpha(45),
                          borderColor: AppColors.scorePlayer.withAlpha(160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          child: const Text(
                            'WINNER',
                            style: TextStyle(
                              fontFamily: AppFonts.orbitron,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.scorePlayer,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Divider
              Container(
                width: 1,
                height: 80,
                color: Colors.white12,
              ),

              // AI
              Expanded(
                child: Column(
                  children: [
                    const Text('AI',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      '${_aiScoreAnim.value}',
                      style: TextStyle(
                        fontFamily: AppFonts.orbitron,
                        fontSize: scoreFontSize,
                        fontWeight: FontWeight.w800,
                        color: !_playerWon
                            ? AppColors.scoreAI
                            : AppColors.textSecondary,
                        shadows: [
                          Shadow(
                            color: (!_playerWon
                                    ? AppColors.scoreAI
                                    : AppColors.textSecondary)
                                .withAlpha(60),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    if (!_playerWon)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ParallelogramBadge(
                          color: AppColors.scoreAI.withAlpha(45),
                          borderColor: AppColors.scoreAI.withAlpha(160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          child: const Text(
                            'WINNER',
                            style: TextStyle(
                              fontFamily: AppFonts.orbitron,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.scoreAI,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchSummary() {
    final diff = (_playerScore - _aiScore).abs();
    String summary;
    if (_playerWon) {
      if (diff >= 5) {
        summary = 'Dominant performance — complete court control.';
      } else if (diff >= 3) {
        summary = 'Decisive victory — clinical shot execution.';
      } else {
        summary = 'Hard-fought battle — contested to the final point.';
      }
    } else {
      if (diff >= 5) {
        summary = 'Tough defeat — sharpen your dinks and kitchen defense.';
      } else {
        summary = 'Narrow margin — exceptional effort against top competition.';
      }
    }

    return Text(
      summary,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        MenuButton(
          label: _playerWon ? 'PLAY AGAIN' : 'TRY AGAIN',
          onTap: () => Navigator.pushReplacementNamed(
            context,
            '/game',
            arguments: _rematchArguments,
          ),
          isPrimary: true,
        ),
        const SizedBox(height: 14),
        MenuButton(
          label: 'MAIN MENU',
          onTap: () => Navigator.pushReplacementNamed(context, '/menu'),
        ),
      ],
    );
  }
}

// ── Confetti particle ─────────────────────────────────────────
class _Particle {
  final double x;         // 0..1 initial X position
  final double speed;     // fall speed multiplier
  final double size;      // particle size
  final Color color;
  final double rotSpeed;  // rotation speed

  _Particle({required math.Random rng})
      : x = rng.nextDouble(),
        speed = 0.3 + rng.nextDouble() * 0.7,
        size = 5 + rng.nextDouble() * 8,
        color = _confettiColors[rng.nextInt(_confettiColors.length)],
        rotSpeed = (rng.nextDouble() - 0.5) * 5;

  static const _confettiColors = [
    Color(0xFFFFCC00),
    Color(0xFF00C2FF),
    Color(0xFF00FF87),
    Color(0xFFFF6B00),
    Color(0xFFFF4466),
    Color(0xFFCC44FF),
  ];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Size size;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final p in particles) {
      final x = p.x * canvasSize.width;
      final y = (progress * p.speed * canvasSize.height * 1.3) % canvasSize.height;
      final rot = progress * p.rotSpeed * math.pi * 4;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        Paint()..color = p.color.withAlpha(200),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
