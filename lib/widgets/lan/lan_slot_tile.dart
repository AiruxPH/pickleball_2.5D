import 'package:flutter/material.dart';

import '../../models/match_lobby.dart';
import '../menu_ui.dart';

class LanSlotTile extends StatelessWidget {
  const LanSlotTile({
    super.key,
    required this.slot,
    required this.ui,
    required this.isCurrentUser,
    this.subtitle,
    this.onToggleReady,
  });

  final LobbyPlayerSlot slot;
  final double ui;
  final bool isCurrentUser;
  final String? subtitle;
  final VoidCallback? onToggleReady;

  @override
  Widget build(BuildContext context) {
    final human = slot.type == LobbySlotType.human;
    final teamColor = slot.team == 1 ? const Color(0xFF0284C7) : const Color(0xFFE85D2A);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4 * ui),
      padding: EdgeInsets.symmetric(horizontal: 12 * ui, vertical: 10 * ui),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0x330284C7)
            : const Color(0x22172642),
        borderRadius: BorderRadius.circular(10 * ui),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF38BDF8)
              : const Color(0xFF2E3E5C),
          width: isCurrentUser ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16 * ui,
            backgroundColor: teamColor,
            child: Text(
              '${slot.team}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14 * ui,
              ),
            ),
          ),
          SizedBox(width: 12 * ui),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      slot.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13 * ui,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 6 * ui),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6 * ui, vertical: 2 * ui),
                        decoration: BoxDecoration(
                          color: kMenuGold.withAlpha(200),
                          borderRadius: BorderRadius.circular(4 * ui),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            color: const Color(0xFF07142B),
                            fontWeight: FontWeight.w900,
                            fontSize: 9 * ui,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2 * ui),
                Text(
                  subtitle ??
                      (human
                          ? (isCurrentUser ? 'This Device' : 'Remote Device')
                          : 'CPU Partner'),
                  style: TextStyle(
                    color: kMenuMuted,
                    fontSize: 10 * ui,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          MenuPressable(
            onTap: (human && isCurrentUser) ? onToggleReady : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: 14 * ui,
                vertical: 8 * ui,
              ),
              decoration: BoxDecoration(
                color: slot.isReady
                    ? const Color(0xFF139C68)
                    : (isCurrentUser
                        ? const Color(0xFFE85D2A)
                        : const Color(0xFF34445E)),
                borderRadius: BorderRadius.circular(8 * ui),
                boxShadow: slot.isReady
                    ? const [
                        BoxShadow(
                          color: Color(0x44139C68),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                slot.isReady ? 'READY' : (isCurrentUser ? 'SET READY' : 'WAITING'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11 * ui,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
