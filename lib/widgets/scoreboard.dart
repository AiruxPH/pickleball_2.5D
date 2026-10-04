import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Scoreboard — Professional Broadcast HUD (ESPN / Apple Sports style)
///
/// Sleek frosted glass capsule featuring:
///   • Pro tournament branding & seed badges
///   • Crisp typography with uppercase player names
///   • Glowing optic-yellow serve indicator pips
///   • Smooth elastic score counter animations
/// ─────────────────────────────────────────────────────────────

class Scoreboard extends StatelessWidget {
  final int playerScore;
  final int aiScore;
  final bool playerScoreAnim;
  final bool aiScoreAnim;
  final VoidCallback? onPause;
  final bool isServing; // true = player is serving
  final int? serverNumber;
  final String? modeName;
  final bool isPractice;
  final Widget? footer;

  const Scoreboard({
    super.key,
    required this.playerScore,
    required this.aiScore,
    this.onPause,
    this.playerScoreAnim = false,
    this.aiScoreAnim = false,
    this.isServing = true,
    this.serverNumber,
    this.modeName,
    this.isPractice = false,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xD90F172A), // 85% opacity deep slate glass
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPractice
              ? const Color(0xFF34D399).withAlpha(60)
              : Colors.white.withAlpha(30),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tournament / Training header
          Row(
            children: [
              Container(
                width: 4.5,
                height: 4.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPractice ? const Color(0xFF34D399) : AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isPractice
                    ? 'TRAINING MODE'
                    : (modeName != null
                        ? 'TOUR  •  ${modeName!.toUpperCase()}'
                        : 'CHAMPIONS TOUR'),
                style: TextStyle(
                  color: isPractice ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                  fontSize: 7.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          // Player & Opponent Rows
          Row(
            children: [
              // Player Side
              Expanded(
                child: _PlayerCard(
                  name: 'PLAYER',
                  score: playerScore,
                  isServing: isServing,
                  serverNumber: serverNumber,
                  isPlayer: true,
                  animate: playerScoreAnim,
                ),
              ),

              // Subtle divider
              Container(
                width: 0.8,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                color: const Color(0x3394A3B8),
              ),

              // AI Opponent Side
              Expanded(
                child: _PlayerCard(
                  name: 'LORINE',
                  score: aiScore,
                  isServing: !isServing,
                  serverNumber: serverNumber,
                  isPlayer: false,
                  animate: aiScoreAnim,
                ),
              ),
            ],
          ),

          // Integrated Status Footer (SP / Stamina)
          if (footer != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 3.5, bottom: 2.5),
              height: 0.6,
              color: Colors.white.withAlpha(20),
            ),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _PlayerCard extends StatefulWidget {
  final String name;
  final int score;
  final bool isServing;
  final int? serverNumber;
  final bool isPlayer;
  final bool animate;

  const _PlayerCard({
    required this.name,
    required this.score,
    required this.isServing,
    this.serverNumber,
    required this.isPlayer,
    required this.animate,
  });

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  int _displayScore = 0;

  @override
  void initState() {
    super.initState();
    _displayScore = widget.score;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_PlayerCard old) {
    super.didUpdateWidget(old);
    if (widget.score != _displayScore && widget.animate) {
      _displayScore = widget.score;
      _ctrl.forward(from: 0);
    } else {
      _displayScore = widget.score;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Seed badge
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isPlayer
                ? const Color(0xFF0284C7).withAlpha(190)
                : const Color(0xFFEA580C).withAlpha(190),
            border: Border.all(color: Colors.white.withAlpha(50), width: 0.8),
          ),
          child: Center(
            child: Text(
              widget.isPlayer ? '1' : '4',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Name & Serve Indicator
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 9.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (widget.isServing) ...[
                const SizedBox(width: 2.5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: AppColors.ballColor,
                    borderRadius: BorderRadius.circular(2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ballColor.withAlpha(160),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Text(
                    'S${widget.serverNumber ?? 1}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 6.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),

        // Score display
        ScaleTransition(
          scale: _scaleAnim,
          child: Text(
            '$_displayScore',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}


/// ─────────────────────────────────────────────────────────────
/// PauseButton — Modern Frosted Glass HUD Pause Button
/// ─────────────────────────────────────────────────────────────
class PauseButton extends StatefulWidget {
  final VoidCallback onTap;

  const PauseButton({super.key, required this.onTap});

  @override
  State<PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<PauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
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
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xE60F172A),
              border: Border.all(color: Colors.white.withAlpha(35), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.pause_rounded,
              color: Color(0xFFF8FAFC),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
