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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE60F172A), // 90% opacity deep slate glass
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPractice
              ? const Color(0xFF34D399).withAlpha(60)
              : Colors.white.withAlpha(35),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tournament / Training header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPractice ? const Color(0xFF34D399) : AppColors.primary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isPractice
                    ? 'TRAINING MODE  •  NO SCORING'
                    : (modeName != null
                        ? 'PPA TOUR  •  ${modeName!.toUpperCase()}'
                        : 'PPA TOUR  •  MATCH POINT'),
                style: TextStyle(
                  color: isPractice ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Player & Opponent Rows
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player Side
              _PlayerCard(
                name: 'PLAYER',
                score: playerScore,
                isServing: isServing,
                serverNumber: serverNumber,
                isPlayer: true,
                animate: playerScoreAnim,
              ),

              // Subtle divider
              Container(
                width: 1.2,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0x3394A3B8),
              ),

              // AI Opponent Side
              _PlayerCard(
                name: 'LORINE',
                score: aiScore,
                isServing: !isServing,
                serverNumber: serverNumber,
                isPlayer: false,
                animate: aiScoreAnim,
              ),
            ],
          ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seed badge or avatar indicator
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isPlayer
                ? const Color(0xFF0284C7).withAlpha(180)
                : const Color(0xFFEA580C).withAlpha(180),
            border: Border.all(color: Colors.white.withAlpha(50), width: 1.0),
          ),
          child: Center(
            child: Text(
              widget.isPlayer ? '1' : '4',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Name & Serve Indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                if (widget.isServing) ...[
                  const SizedBox(width: 5),
                  // Glowing tournament chartreuse serve pip with server number
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.ballColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ballColor.withAlpha(180),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Text(
                      'S${widget.serverNumber ?? 1}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              widget.isPlayer ? 'USA' : 'ESP',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),

        // Score display
        ScaleTransition(
          scale: _scaleAnim,
          child: Text(
            '$_displayScore',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
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
