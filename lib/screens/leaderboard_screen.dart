import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Leaderboard Screen — local rankings table
/// ─────────────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildLeaderboard(GameSettings settings) {
    // Start with saved entries
    final entries = List<Map<String, dynamic>>.from(settings.leaderboard);

    // Always include the player
    final playerEntry = {
      'name': settings.playerName.toUpperCase(),
      'wins': settings.matchesWon,
      'winPct': settings.winPercentage,
      'isPlayer': true,
    };
    // Remove any existing player entry then re-add
    entries.removeWhere((e) => e['isPlayer'] == true);
    entries.add(playerEntry);

    // Fill with AI bots if fewer than 10
    final bots = [
      {'name': 'LORINE D.',  'wins': 142, 'winPct': 88.5, 'isPlayer': false},
      {'name': 'SAM V.',     'wins': 117, 'winPct': 81.2, 'isPlayer': false},
      {'name': 'RILEY C.',   'wins': 98,  'winPct': 76.0, 'isPlayer': false},
      {'name': 'CASEY F.',   'wins': 85,  'winPct': 72.4, 'isPlayer': false},
      {'name': 'TAYLOR N.',  'wins': 71,  'winPct': 68.3, 'isPlayer': false},
      {'name': 'MORGAN L.',  'wins': 54,  'winPct': 61.0, 'isPlayer': false},
      {'name': 'ALEX B.',    'wins': 43,  'winPct': 55.7, 'isPlayer': false},
      {'name': 'JAMIE S.',   'wins': 29,  'winPct': 48.2, 'isPlayer': false},
      {'name': 'JORDAN P.',  'wins': 18,  'winPct': 42.5, 'isPlayer': false},
    ];
    for (final bot in bots) {
      if (entries.length < 15) entries.add(bot);
    }

    entries.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Consumer<GameSettings>(
        builder: (context, settings, _) {
          final entries = _buildLeaderboard(settings);

          return FadeTransition(
            opacity: _fade,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      _buildHeader(compact: isLandscape),
                      _buildTableHeader(),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isLandscape ? 4 : 8,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (_, i) =>
                              _buildRow(i + 1, entries[i], compact: isLandscape),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader({bool compact = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 16, 16, compact ? 8 : 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Icon(Icons.leaderboard_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          const Text(
            'LEADERBOARD',
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFF0F172A),
      child: const Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1))),
          Expanded(child: Text('PLAYER', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1))),
          SizedBox(width: 50, child: Text('WINS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1))),
          SizedBox(width: 55, child: Text('WIN %', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildRow(int rank, Map<String, dynamic> entry, {bool compact = false}) {
    final isPlayer = entry['isPlayer'] == true;
    final wins = entry['wins'] as int;
    final winPct = (entry['winPct'] as num).toDouble();
    final name = entry['name'] as String;

    Color rankColor = Colors.white54;
    Widget rankWidget;
    if (rank <= 3) {
      const medalColors = [Color(0xFFF5B301), Color(0xFFB8C2CC), Color(0xFFCD7F32)];
      rankWidget = Icon(
        Icons.emoji_events_rounded,
        size: compact ? 15 : 19,
        color: medalColors[rank - 1],
      );
    } else {
      rankWidget = Text(
        '$rank',
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w800,
          color: rankColor,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: compact ? 4 : 6),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 7 : 12,
      ),
      decoration: BoxDecoration(
        color: isPlayer
            ? AppColors.primary.withAlpha(18)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlayer ? AppColors.primary.withAlpha(100) : Colors.transparent,
          width: isPlayer ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: rankWidget),
          Expanded(
            child: Row(
              children: [
                if (isPlayer) ...[
                  const Icon(Icons.person_rounded, color: AppColors.primary, size: 14),
                  const SizedBox(width: 6),
                ],
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isPlayer ? AppColors.primary : Colors.white,
                    fontSize: 13,
                  ),
                ),
                if (isPlayer) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('YOU', style: TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '$wins',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              '${winPct.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: winPct >= 70 ? const Color(0xFF34D399) : winPct >= 50 ? AppColors.primary : Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
