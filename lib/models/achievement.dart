import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// Achievement System
/// 15 curated achievements tracking player milestones
/// ─────────────────────────────────────────────────────────────

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int targetCount; // 1 = single-event, >1 = cumulative
  final String category; // 'wins','shots','rallies','career','collection'

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetCount,
    required this.category,
  });
}

/// All achievements in the game
const List<Achievement> kAchievements = [
  // ── Wins ──────────────────────────────────────────────────────
  Achievement(
    id: 'first_win',
    title: 'First Win',
    description: 'Win your very first match.',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFF59E0B),
    targetCount: 1,
    category: 'wins',
  ),
  Achievement(
    id: 'ten_wins',
    title: '10 Match Wins',
    description: 'Win 10 matches total.',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF38BDF8),
    targetCount: 10,
    category: 'wins',
  ),
  Achievement(
    id: 'fifty_wins',
    title: 'Pickleball Legend',
    description: 'Win 50 matches total.',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFEC4899),
    targetCount: 50,
    category: 'wins',
  ),
  Achievement(
    id: 'perfect_game',
    title: 'Perfect Game',
    description: 'Win a match 11-0 without dropping a point.',
    icon: Icons.star_rounded,
    color: Color(0xFFFFD700),
    targetCount: 1,
    category: 'wins',
  ),
  Achievement(
    id: 'comeback_kid',
    title: 'Comeback Kid',
    description: 'Win a match after being down 0-9.',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF34D399),
    targetCount: 1,
    category: 'wins',
  ),
  Achievement(
    id: 'tournament_champ',
    title: 'Tournament Champion',
    description: 'Win a full tournament bracket.',
    icon: Icons.local_activity_rounded,
    color: Color(0xFFF59E0B),
    targetCount: 1,
    category: 'career',
  ),
  // ── Shots ─────────────────────────────────────────────────────
  Achievement(
    id: 'smash_master',
    title: 'Smash Master',
    description: 'Land 10 overhead smash shots.',
    icon: Icons.bolt_rounded,
    color: Color(0xFFF43F5E),
    targetCount: 10,
    category: 'shots',
  ),
  Achievement(
    id: 'ace_king',
    title: 'Ace King',
    description: 'Serve 5 unreturnable aces.',
    icon: Icons.sports_tennis_rounded,
    color: Color(0xFF8B5CF6),
    targetCount: 5,
    category: 'shots',
  ),
  Achievement(
    id: 'kitchen_dink',
    title: 'Kitchen Specialist',
    description: 'Win a match without any kitchen violations.',
    icon: Icons.restaurant_rounded,
    color: Color(0xFF06B6D4),
    targetCount: 1,
    category: 'shots',
  ),
  // ── Rallies ───────────────────────────────────────────────────
  Achievement(
    id: 'rally_king',
    title: 'Rally King',
    description: 'Sustain a 30-shot rally in a single point.',
    icon: Icons.loop_rounded,
    color: Color(0xFF10B981),
    targetCount: 30,
    category: 'rallies',
  ),
  Achievement(
    id: 'fifty_rally',
    title: '50-Rally Challenge',
    description: 'Sustain a 50-shot rally in a single point.',
    icon: Icons.autorenew_rounded,
    color: Color(0xFFEC4899),
    targetCount: 50,
    category: 'rallies',
  ),
  // ── Career ────────────────────────────────────────────────────
  Achievement(
    id: 'daily_devotee',
    title: 'Daily Devotee',
    description: 'Claim 7 daily bonus rewards.',
    icon: Icons.calendar_today_rounded,
    color: Color(0xFFFBBF24),
    targetCount: 7,
    category: 'career',
  ),
  Achievement(
    id: 'speed_demon',
    title: 'Speed Demon',
    description: 'Win a match in under 3 minutes.',
    icon: Icons.timer_rounded,
    color: Color(0xFFEF4444),
    targetCount: 1,
    category: 'career',
  ),
  // ── Collection ────────────────────────────────────────────────
  Achievement(
    id: 'big_spender',
    title: 'Big Spender',
    description: 'Spend 10,000 coins in the Pro Shop.',
    icon: Icons.monetization_on_rounded,
    color: Color(0xFFF59E0B),
    targetCount: 10000,
    category: 'collection',
  ),
  Achievement(
    id: 'collector',
    title: 'Paddle Collector',
    description: 'Unlock 5 different paddles.',
    icon: Icons.sports_tennis_rounded,
    color: Color(0xFFA855F7),
    targetCount: 5,
    category: 'collection',
  ),
];

Achievement? getAchievementById(String id) {
  try {
    return kAchievements.firstWhere((a) => a.id == id);
  } catch (_) {
    return null;
  }
}
