import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/game_settings.dart';
import '../../utils/constants.dart';
import '../menu_backdrop.dart';
import 'angular_frames.dart';

/// ─────────────────────────────────────────────────────────────
/// DailyChallengeBar — Daily Retention Task & Reward Tracker
/// Fulfills H3: High-contrast progress bar, larger reward icons,
/// and clear completion states with athletic angular frame.
/// ─────────────────────────────────────────────────────────────
class DailyChallengeBar extends StatelessWidget {
  final double ui;

  const DailyChallengeBar({super.key, required this.ui});

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
    final fraction = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
    final accent = completed ? const Color(0xFF10B981) : const Color(0xFFFFC21A);

    return Container(
      height: 48 * ui,
      padding: EdgeInsets.symmetric(horizontal: 14 * ui),
      decoration: ShapeDecoration(
        color: kMenuPanelColor,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(10 * ui),
          side: BorderSide(
            color: completed ? const Color(0xFF10B981).withAlpha(150) : kMenuPanelBorder,
            width: completed ? 1.5 : 1.0,
          ),
        ),
        shadows: completed
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withAlpha(50),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Challenge Status Icon (Angular Beveled Diamond)
          Container(
            padding: EdgeInsets.all(4 * ui),
            decoration: ShapeDecoration(
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(6 * ui),
                side: BorderSide(color: accent.withAlpha(completed ? 180 : 100), width: 1.2),
              ),
              color: accent.withAlpha(completed ? 45 : 30),
            ),
            child: Icon(
              completed ? Icons.check_circle_rounded : Icons.bolt_rounded,
              color: accent,
              size: 20 * ui,
            ),
          ),
          SizedBox(width: 10 * ui),

          // Title & Description (H3: High Contrast)
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DAILY CHALLENGE',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9.5 * ui,
                          fontFamily: AppFonts.orbitron,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (completed) ...[
                        SizedBox(width: 6 * ui),
                        ParallelogramBadge(
                          color: const Color(0xFF10B981).withAlpha(50),
                          borderColor: const Color(0xFF10B981),
                          padding: EdgeInsets.symmetric(horizontal: 6 * ui, vertical: 1.5 * ui),
                          child: Text(
                            'CLAIMED',
                            style: TextStyle(
                              color: const Color(0xFF10B981),
                              fontSize: 7.5 * ui,
                              fontFamily: AppFonts.orbitron,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2 * ui),
                  Text(
                    settings.dailyChallengeDescription,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13 * ui,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10 * ui),

          // Progress Ratio & High-Contrast Angular Progress Bar (H3)
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                Text(
                  completed ? '$target / $target' : '$progress / $target',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5 * ui,
                    fontFamily: AppFonts.orbitron,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4 * ui),
                ClipPath(
                  clipper: ShapeBorderClipper(
                    shape: BeveledRectangleBorder(
                      borderRadius: BorderRadius.circular(3 * ui),
                    ),
                  ),
                  child: SizedBox(
                    width: 90 * ui,
                    height: 7 * ui,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0xFF16253D)),
                        ),
                        FractionallySizedBox(
                          widthFactor: completed ? 1.0 : fraction,
                          heightFactor: 1.0,
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: completed
                                    ? const [Color(0xFF34D399), Color(0xFF10B981)]
                                    : const [Color(0xFFFFD54A), Color(0xFFFFB300)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
          SizedBox(width: 14 * ui),

          // Larger Reward Badges (H3)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ChallengeReward(
                ui: ui,
                amount: 500,
                icon: Icons.monetization_on_rounded,
                color: const Color(0xFFFFC21A),
              ),
              SizedBox(height: 2 * ui),
              _ChallengeReward(
                ui: ui,
                amount: 50,
                icon: Icons.diamond_rounded,
                color: const Color(0xFFC06BFF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeReward extends StatelessWidget {
  final double ui;
  final int amount;
  final IconData icon;
  final Color color;

  const _ChallengeReward({
    required this.ui,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16 * ui),
        SizedBox(width: 3 * ui),
        Text(
          '+$amount',
          style: TextStyle(
            color: color,
            fontSize: 12 * ui,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
