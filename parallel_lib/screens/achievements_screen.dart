import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/achievement.dart';
import '../services/settings_service.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/menu_ui.dart';

/// ─────────────────────────────────────────────────────────────
/// Achievements Screen — main-menu styling: category pills, glossy
/// unlocked cards, glass locked cards with progress.
/// ─────────────────────────────────────────────────────────────

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<GameSettings>();
      settings.markAchievementsSeen();
      try {
        context.read<SettingsService>().save(settings);
      } catch (_) {}
    });
  }

  static const _categories = [
    ('all', 'ALL', Icons.apps_rounded),
    ('wins', 'WINS', Icons.emoji_events_rounded),
    ('shots', 'SHOTS', Icons.sports_tennis_rounded),
    ('rallies', 'RALLIES', Icons.sync_alt_rounded),
    ('career', 'CAREER', Icons.military_tech_rounded),
    ('collection', 'COLLECTION', Icons.inventory_2_rounded),
  ];

  List<Achievement> get _filtered => _selectedCategory == 'all'
      ? kAchievements
      : kAchievements.where((a) => a.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GameSettings>();
    final ui = MenuMetrics.of(context).contentUi;
    final unlockedCount =
        kAchievements.where((a) => settings.isAchievementUnlocked(a.id)).length;
    final filtered = _filtered;

    return MenuScreen(
      title: 'ACHIEVEMENTS',
      subtitle: '$unlockedCount / ${kAchievements.length} UNLOCKED',
      actions: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * ui, vertical: 7 * ui),
          decoration: BoxDecoration(
            color: kMenuPanelColor,
            borderRadius: BorderRadius.circular(20 * ui),
            border: Border.all(color: kMenuPanelBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: kMenuGold, size: 22 * ui),
              SizedBox(width: 6 * ui),
              Text(
                '$unlockedCount/${kAchievements.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15 * ui,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
      body: Column(
        children: [
          // Overall progress
          Padding(
            padding: EdgeInsets.fromLTRB(14 * ui, 4 * ui, 14 * ui, 10 * ui),
            child: MenuProgressBar(value: unlockedCount / kAchievements.length),
          ),
          // Category pills
          SizedBox(
            height: 42 * ui,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14 * ui),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8 * ui),
              itemBuilder: (_, i) {
                final (id, label, icon) = _categories[i];
                final selected = _selectedCategory == id;
                final radius = 21 * ui;
                return MenuPressable(
                  onTap: () => setState(() => _selectedCategory = id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 16 * ui),
                    decoration: selected
                        ? menuTileDecoration(TilePalette.blue, radius)
                        : BoxDecoration(
                            color: kMenuPanelColor,
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: kMenuPanelBorder),
                          ),
                    child: Row(
                      children: [
                        Icon(icon,
                            size: 17 * ui,
                            color: selected ? Colors.white : kMenuMuted),
                        SizedBox(width: 6 * ui),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5 * ui,
                            fontWeight: FontWeight.w900,
                            color: selected ? Colors.white : kMenuMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 10 * ui),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(14 * ui, 4 * ui, 14 * ui, 20 * ui),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420 * ui,
                mainAxisExtent: 132 * ui,
                crossAxisSpacing: 12 * ui,
                mainAxisSpacing: 12 * ui,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _AchievementCard(
                achievement: filtered[i],
                unlocked: settings.isAchievementUnlocked(filtered[i].id),
                progress: settings.getAchievementProgress(filtered[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final int progress;

  const _AchievementCard({
    required this.achievement,
    required this.unlocked,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    final radius = 16 * ui;
    final a = achievement;
    final fraction = (progress / a.targetCount).clamp(0.0, 1.0);
    final showProgress = a.targetCount > 1 && !unlocked;

    return Container(
      decoration: unlocked
          ? menuTileDecoration(TilePalette.from(a.color), radius)
          : BoxDecoration(
              color: kMenuPanelColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: kMenuPanelBorder),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: Stack(
          children: [
            // Large faded emblem, like the menu tiles
            Positioned(
              right: -14 * ui,
              top: -10 * ui,
              child: Icon(a.icon,
                  size: 110 * ui,
                  color: Colors.white.withAlpha(unlocked ? 30 : 10)),
            ),
            if (unlocked) MenuGloss(radius: radius),
            Padding(
              padding: EdgeInsets.all(14 * ui),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42 * ui,
                            height: 42 * ui,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: unlocked
                                  ? Colors.white.withAlpha(50)
                                  : a.color.withAlpha(40),
                            ),
                            child: Icon(
                              a.icon,
                              size: 22 * ui,
                              color: unlocked
                                  ? Colors.white
                                  : a.color.withAlpha(150),
                            ),
                          ),
                          if (!unlocked)
                            Positioned(
                              right: -3 * ui,
                              bottom: -3 * ui,
                              child: Container(
                                padding: EdgeInsets.all(3 * ui),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0C1A33),
                                  border: Border.all(color: kMenuPanelBorder),
                                ),
                                child: Icon(Icons.lock_rounded,
                                    size: 11 * ui, color: kMenuMuted),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 12 * ui),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: menuTitleStyle(16 * ui),
                            ),
                            SizedBox(height: 3 * ui),
                            Text(
                              a.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12 * ui,
                                height: 1.25,
                                color: unlocked
                                    ? Colors.white.withAlpha(225)
                                    : kMenuMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unlocked)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8 * ui, vertical: 3 * ui),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(50),
                            borderRadius: BorderRadius.circular(10 * ui),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 13 * ui, color: Colors.white),
                              SizedBox(width: 3 * ui),
                              Text(
                                'DONE',
                                style: TextStyle(
                                  fontSize: 10.5 * ui,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (showProgress) ...[
                    Row(
                      children: [
                        Text(
                          '$progress / ${a.targetCount}',
                          style: TextStyle(
                            fontSize: 12 * ui,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(fraction * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12 * ui,
                            fontWeight: FontWeight.w900,
                            color: kMenuGold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * ui),
                    MenuProgressBar(value: fraction, height: 7),
                  ] else if (!unlocked)
                    Text(
                      'Not unlocked yet',
                      style: TextStyle(
                        fontSize: 12 * ui,
                        fontWeight: FontWeight.w700,
                        color: kMenuMuted.withAlpha(170),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
