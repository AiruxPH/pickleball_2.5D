import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_settings.dart';
import '../models/career.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Career Screen — season-based progression
/// Shows rank, XP bar, match schedule, and history
/// ─────────────────────────────────────────────────────────────

class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories_rounded,
                            size: 72, color: Color(0xFF34D399)),
                        SizedBox(height: 20),
                        Text('STORY MODE', style: TextStyle(
                          fontFamily: AppFonts.orbitron, fontSize: 24,
                          fontWeight: FontWeight.w900, color: Colors.white,
                          letterSpacing: 2)),
                        SizedBox(height: 10),
                        Text('COMING SOON', style: TextStyle(
                          fontFamily: AppFonts.orbitron, fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF34D399), letterSpacing: 2)),
                        SizedBox(height: 14),
                        Text('Your journey from local courts to the pro tour is being built.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          const Icon(Icons.trending_up_rounded, color: Color(0xFF34D399), size: 22),
          const SizedBox(width: 8),
          const Text(
            'CAREER MODE',
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRankCard(CareerState career) {
    final rank = career.rank;
    final progress = career.rankProgress;

    // Rank colors
    final rankColors = {
      CareerRank.beginner:   const Color(0xFF94A3B8),
      CareerRank.amateur:    const Color(0xFF34D399),
      CareerRank.clubPlayer: const Color(0xFF38BDF8),
      CareerRank.pro:        const Color(0xFF8B5CF6),
      CareerRank.elite:      const Color(0xFFF59E0B),
      CareerRank.champion:   const Color(0xFFF43F5E),
      CareerRank.legend:     const Color(0xFFEC4899),
    };
    final color = rankColors[rank] ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  rank.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${career.totalXp} XP',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!rank.isMax) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PROGRESS TO NEXT RANK', style: TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1)),
                Text('${career.xpToNextRank} XP needed', style: TextStyle(fontSize: 10, color: color.withAlpha(180))),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withAlpha(20),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ] else
            Text('Top rank reached!', style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatPill('Season', '${career.currentSeason}', color),
              const SizedBox(width: 10),
              _StatPill('Matches', '${career.matchHistory.length}', color),
              const SizedBox(width: 10),
              _StatPill('Wins', '${career.matchHistory.where((r) => r.won).length}', color),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSeasonCard(CareerState career) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('SEASON ', style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
              Text('${career.currentSeason}', style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              )),
              const Spacer(),
              Text('${career.matchesInSeason}/8 MATCHES',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(8, (i) {
              final played = i < career.matchesInSeason;
              Color dotColor = const Color(0xFF334155);
              if (played) {
                final historyIdx = career.matchHistory.length - career.matchesInSeason + i;
                if (historyIdx >= 0 && historyIdx < career.matchHistory.length) {
                  dotColor = career.matchHistory[historyIdx].won
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF43F5E);
                }
              }
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 7 ? 4 : 0),
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'NEXT OPPONENT: ${career.nextOpponentName}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPlayNextButton(GameSettings settings, CareerState career) {
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
        onPressed: () {
          HapticFeedback.mediumImpact();
          // Set difficulty based on career progress
          final diffLevel = career.nextMatchDifficulty;
          Navigator.pushNamed(context, '/game', arguments: {
            'mode': 'singles',
            'isCareer': true,
            'difficulty': diffLevel,
          }).then((_) => setState(() {}));
        },
        child: Column(
          children: [
            const Text(
              'PLAY NEXT MATCH',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'vs ${career.nextOpponentName}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHistoryRow(CareerMatchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: result.won
            ? const Color(0xFF34D399).withAlpha(12)
            : const Color(0xFFF43F5E).withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.won
              ? const Color(0xFF34D399).withAlpha(50)
              : const Color(0xFFF43F5E).withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.won ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: result.won ? const Color(0xFF34D399) : const Color(0xFFF43F5E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.opponentName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('${result.playerScore} - ${result.opponentScore}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${result.xpEarned} XP',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF34D399), fontWeight: FontWeight.w700)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+${result.coinsEarned} ',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                  const Icon(Icons.monetization_on_rounded, size: 12, color: Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(
            fontFamily: AppFonts.orbitron,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          )),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
