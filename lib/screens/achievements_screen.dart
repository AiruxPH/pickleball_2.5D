import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/achievement.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Achievements Screen — premium grid with progress tracking
/// ─────────────────────────────────────────────────────────────

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  String _selectedCategory = 'all';

  final List<String> _categories = ['all', 'wins', 'shots', 'rallies', 'career', 'collection'];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  List<Achievement> _filteredAchievements(GameSettings settings) {
    if (_selectedCategory == 'all') return kAchievements;
    return kAchievements.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final crossAxisCount = isLandscape ? 3 : 2;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Consumer<GameSettings>(
        builder: (context, settings, _) {
          final filtered = _filteredAchievements(settings);
          final unlockedCount = kAchievements.where((a) => settings.isAchievementUnlocked(a.id)).length;

          return SafeArea(
            child: Column(
              children: [
                _buildHeader(unlockedCount),
                _buildCategoryBar(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isLandscape ? 1.3 : 0.9,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildAchievementCard(filtered[i], settings),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(int unlockedCount) {
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
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACHIEVEMENTS',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '$unlockedCount / ${kAchievements.length} UNLOCKED',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Trophy icon with count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 6),
                Text(
                  '$unlockedCount',
                  style: const TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: _categories.map((cat) {
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withAlpha(25) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFF334155),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                cat.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : Colors.white54,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, GameSettings settings) {
    final unlocked = settings.isAchievementUnlocked(achievement.id);
    final progress = settings.getAchievementProgress(achievement.id);
    final progressFraction = (progress / achievement.targetCount).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: unlocked
                ? achievement.color.withAlpha(18)
                : const Color(0xFF1E293B),
            border: Border.all(
              color: unlocked
                  ? achievement.color.withAlpha(120)
                  : const Color(0xFF334155),
              width: unlocked ? 1.5 : 1,
            ),
            boxShadow: unlocked
                ? [BoxShadow(color: achievement.color.withAlpha(50), blurRadius: 16)]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon container
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? achievement.color.withAlpha(35)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        unlocked ? achievement.icon : Icons.lock_rounded,
                        color: unlocked ? achievement.color : Colors.white24,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: achievement.color.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DONE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: achievement.color,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: unlocked ? Colors.white : Colors.white60,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (achievement.targetCount > 1 && !unlocked) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$progress/${achievement.targetCount}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: achievement.color.withAlpha(180),
                        ),
                      ),
                      Text(
                        '${(progressFraction * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: achievement.color.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      backgroundColor: const Color(0xFF0F172A),
                      valueColor: AlwaysStoppedAnimation<Color>(achievement.color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
