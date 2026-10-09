import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/tournament.dart';
import '../utils/constants.dart';
import '../services/settings_service.dart';

/// ─────────────────────────────────────────────────────────────
/// Tournament Screen — single-elimination bracket UI
/// Quarter-Final → Semi-Final → Final
/// ─────────────────────────────────────────────────────────────

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  void _onPlayNextMatch(GameSettings settings) {
    HapticFeedback.mediumImpact();
    final opp = settings.tournament.currentOpponent;
    Navigator.pushNamed(context, '/game', arguments: {
      'mode': 'singles',
      'isTournament': true,
      'difficulty': opp.difficulty,
    }).then((_) => setState(() {}));
  }

  void _onResetTournament(GameSettings settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset Tournament?',
            style: TextStyle(color: Colors.white, fontFamily: AppFonts.orbitron)),
        content: const Text('All bracket progress will be lost.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              settings.tournament.reset();
              context.read<SettingsService>().save(settings);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('RESET', style: TextStyle(color: Color(0xFFF43F5E))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Consumer<GameSettings>(
        builder: (context, settings, _) {
          final tournament = settings.tournament;

          return FadeTransition(
            opacity: _fade,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(settings),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (tournament.isComplete) ...[
                            _buildResultBanner(tournament),
                            const SizedBox(height: 24),
                          ],
                          _buildPrizeInfo(),
                          const SizedBox(height: 24),
                          _buildBracket(tournament),
                          const SizedBox(height: 28),
                          if (!tournament.isComplete)
                            _buildPlayButton(settings, tournament),
                          if (tournament.isComplete)
                            _buildPlayAgainButton(settings),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GameSettings settings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Icon(Icons.local_activity_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'PRO TOUR TOURNAMENT',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _onResetTournament(settings),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(60)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PrizeChip(label: 'QUARTER', prize: '+500', color: Color(0xFF94A3B8)),
          _PrizeChip(label: 'SEMI', prize: '+1,500', color: Color(0xFF38BDF8)),
          _PrizeChip(label: 'CHAMPION', prize: '+5,000', color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildResultBanner(TournamentState tournament) {
    final won = tournament.playerWon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (won ? const Color(0xFF34D399) : const Color(0xFFF43F5E)).withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (won ? const Color(0xFF34D399) : const Color(0xFFF43F5E)).withAlpha(100),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
            size: 44,
            color: won ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E),
          ),
          const SizedBox(height: 8),
          Text(
            won ? 'TOURNAMENT CHAMPION!' : 'ELIMINATED',
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: won ? const Color(0xFF34D399) : const Color(0xFFF43F5E),
              letterSpacing: 2,
            ),
          ),
          if (won) ...[
            const SizedBox(height: 6),
            const Text(
              '+5,000 COINS AWARDED!',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBracket(TournamentState tournament) {
    final rounds = [
      {'name': 'QF', 'fullName': 'QUARTER-FINAL', 'round': 0},
      {'name': 'SF', 'fullName': 'SEMI-FINAL', 'round': 1},
      {'name': 'F', 'fullName': 'FINAL', 'round': 2},
    ];

    return Column(
      children: rounds.map((r) {
        final idx = (r['round'] as num).toInt();
        final result = tournament.results[idx];
        final isCurrent = tournament.currentRound == idx && !tournament.isComplete;
        final opp = idx == 0
            ? kTournamentOpponents[0]
            : idx == 1
                ? kTournamentOpponents[3]
                : kTournamentOpponents[7];

        Color borderColor = const Color(0xFF334155);
        Color bgColor = const Color(0xFF1E293B);
        String statusText = 'UPCOMING';
        IconData? statusIcon;
        Color statusColor = Colors.white38;

        if (isCurrent) {
          borderColor = AppColors.primary;
          bgColor = AppColors.primary.withAlpha(15);
          statusText = 'NEXT MATCH';
          statusColor = AppColors.primary;
        } else if (result == true) {
          borderColor = const Color(0xFF34D399);
          bgColor = const Color(0xFF34D399).withAlpha(12);
          statusText = 'WON';
          statusIcon = Icons.check_circle_rounded;
          statusColor = const Color(0xFF34D399);
        } else if (result == false) {
          borderColor = const Color(0xFFF43F5E);
          bgColor = const Color(0xFFF43F5E).withAlpha(12);
          statusText = 'LOST';
          statusIcon = Icons.cancel_rounded;
          statusColor = const Color(0xFFF43F5E);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
          ),
          child: Row(
            children: [
              // Round badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: borderColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(r['name'] as String,
                      style: TextStyle(
                        fontFamily: AppFonts.orbitron,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: borderColor,
                      )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['fullName'] as String,
                        style: const TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 2),
                    Text('vs ${opp.name}  •  ${opp.title}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              // Difficulty stars
              Row(
                children: List.generate(3, (s) => Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: s < opp.difficulty ? AppColors.primary : const Color(0xFF334155),
                )),
              ),
              const SizedBox(width: 10),
              if (statusIcon != null) ...[
                Icon(statusIcon, size: 13, color: statusColor),
                const SizedBox(width: 3),
              ],
              Text(statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 1,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayButton(GameSettings settings, TournamentState tournament) {
    final opp = tournament.currentOpponent;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
        ),
        onPressed: () => _onPlayNextMatch(settings),
        child: Column(
          children: [
            Text(
              'PLAY ${tournament.currentRoundName}',
              style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'vs ${opp.name}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayAgainButton(GameSettings settings) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: () => _onResetTournament(settings),
        child: const Text(
          'PLAY NEW TOURNAMENT',
          style: TextStyle(
            fontFamily: AppFonts.orbitron,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PrizeChip extends StatelessWidget {
  final String label;
  final String prize;
  final Color color;

  const _PrizeChip({required this.label, required this.prize, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(
          fontFamily: AppFonts.orbitron,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1,
        )),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prize, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 3),
            const Icon(Icons.monetization_on_rounded, size: 13, color: Color(0xFFF59E0B)),
          ],
        ),
      ],
    );
  }
}
