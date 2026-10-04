import 'package:flutter/material.dart';

import '../../models/match_lobby.dart';
import '../../services/lan/lan_room_info.dart';
import 'lan_action_button.dart';

class LanNearbyRoomsView extends StatelessWidget {
  const LanNearbyRoomsView({
    super.key,
    required this.rooms,
    required this.ui,
    required this.onJoinRoom,
  });

  final List<LanRoomInfo> rooms;
  final double ui;
  final ValueChanged<LanRoomInfo> onJoinRoom;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 18 * ui, horizontal: 16 * ui),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E36).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12 * ui),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1 * ui,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14 * ui,
              height: 14 * ui,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF00E5FF)),
              ),
            ),
            SizedBox(width: 12 * ui),
            Text(
              'Scanning for active rooms on local network...',
              style: TextStyle(
                fontSize: 12 * ui,
                color: Colors.white54,
                letterSpacing: 0.5 * ui,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.radar,
              size: 14 * ui,
              color: const Color(0xFF00E5FF),
            ),
            SizedBox(width: 6 * ui),
            Text(
              'NEARBY ROOMS DETECTED (${rooms.length})',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 10 * ui,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5 * ui,
                color: const Color(0xFF81D4FA),
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * ui),
        ...rooms.map((room) {
          final isDoubles = room.format == LobbyFormat.doubles;
          return Container(
            margin: EdgeInsets.only(bottom: 8 * ui),
            padding: EdgeInsets.symmetric(
              horizontal: 16 * ui,
              vertical: 10 * ui,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0E223D).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10 * ui),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                width: 1.2 * ui,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * ui,
                    vertical: 5 * ui,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6 * ui),
                  ),
                  child: Text(
                    room.roomCode,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 13 * ui,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF00E5FF),
                      letterSpacing: 1.2 * ui,
                    ),
                  ),
                ),
                SizedBox(width: 14 * ui),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDoubles ? 'DOUBLES 2v2 MATCH' : 'SINGLES 1v1 MATCH',
                        style: TextStyle(
                          fontSize: 12 * ui,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Ready to join',
                        style: TextStyle(
                          fontSize: 10 * ui,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                LanActionButton(
                  label: 'JOIN',
                  icon: Icons.login,
                  ui: ui * 0.85,
                  color: const Color(0xFFFFB300),
                  onTap: () => onJoinRoom(room),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
