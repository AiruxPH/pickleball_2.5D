import 'package:flutter/material.dart';

import '../../models/match_lobby.dart';
import '../../services/lan/lan_multiplayer_service.dart';
import '../../services/lan/lan_room_info.dart';
import '../menu_ui.dart';
import 'lan_action_button.dart';
import 'lan_nearby_rooms_view.dart';
import 'lan_slot_tile.dart';

class LanJoinView extends StatefulWidget {
  const LanJoinView({
    super.key,
    required this.service,
    required this.ui,
  });

  final LanMultiplayerService service;
  final double ui;

  @override
  State<LanJoinView> createState() => _LanJoinViewState();
}

class _LanJoinViewState extends State<LanJoinView> {
  final TextEditingController _codeController = TextEditingController();
  bool _showDirectIp = false;
  final TextEditingController _directIpController =
      TextEditingController(text: '127.0.0.1');

  @override
  void dispose() {
    _codeController.dispose();
    _directIpController.dispose();
    super.dispose();
  }

  void _onJoinWithCode([String? codeOverride]) {
    final code = (codeOverride ?? _codeController.text).trim();
    if (code.isNotEmpty) {
      widget.service.joinRoom(code);
    }
  }

  void _onJoinDirectIp() {
    final ip = _directIpController.text.trim();
    if (ip.isNotEmpty) {
      widget.service.joinRoom(ip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final service = widget.service;
    final isConnected = service.isConnected;
    final isConnecting = service.status == LanStatus.connecting;
    final lobby = service.lobby;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isConnected) ...[
          // Room Code Input Card
          Container(
            padding: EdgeInsets.all(16 * ui),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E36).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14 * ui),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                width: 1.5 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  blurRadius: 14 * ui,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'JOIN WITH ROOM CODE',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: const Color(0xFF81D4FA),
                        fontSize: 10 * ui,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5 * ui,
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          setState(() => _showDirectIp = !_showDirectIp),
                      child: Text(
                        _showDirectIp ? 'Standard Code' : 'Direct IP Fallback',
                        style: TextStyle(
                          fontSize: 10 * ui,
                          color: Colors.white54,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10 * ui),
                if (!_showDirectIp) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14 * ui),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1629),
                            borderRadius: BorderRadius.circular(10 * ui),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            ),
                          ),
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white,
                              fontSize: 16 * ui,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0 * ui,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. PK-4821',
                              hintStyle: TextStyle(
                                fontFamily: 'Orbitron',
                                color: Colors.white30,
                                fontSize: 13 * ui,
                                letterSpacing: 1.5 * ui,
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _onJoinWithCode(),
                          ),
                        ),
                      ),
                      SizedBox(width: 10 * ui),
                      LanActionButton(
                        label: isConnecting ? 'CONNECTING...' : 'JOIN ROOM',
                        icon: isConnecting ? Icons.sync : Icons.login,
                        ui: ui * 0.95,
                        color: const Color(0xFF00E5FF),
                        onTap: isConnecting ? null : () => _onJoinWithCode(),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14 * ui),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1629),
                            borderRadius: BorderRadius.circular(10 * ui),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            ),
                          ),
                          child: TextField(
                            controller: _directIpController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13 * ui,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 192.168.1.15',
                              hintStyle: TextStyle(
                                color: Colors.white30,
                                fontSize: 12 * ui,
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _onJoinDirectIp(),
                          ),
                        ),
                      ),
                      SizedBox(width: 10 * ui),
                      LanActionButton(
                        label: 'CONNECT IP',
                        icon: Icons.lan,
                        ui: ui * 0.95,
                        color: const Color(0xFF00E5FF),
                        onTap: isConnecting ? null : _onJoinDirectIp,
                      ),
                    ],
                  ),
                ],
                if (service.errorMessage != null) ...[
                  SizedBox(height: 10 * ui),
                  Text(
                    service.errorMessage!,
                    style: TextStyle(
                      color: const Color(0xFFFF5252),
                      fontSize: 11 * ui,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 14 * ui),

          // Nearby Discovered Rooms
          StreamBuilder<List<LanRoomInfo>>(
            stream: service.nearbyRooms,
            builder: (context, snapshot) {
              final rooms = snapshot.data ?? [];
              return LanNearbyRoomsView(
                rooms: rooms,
                ui: ui,
                onJoinRoom: (room) {
                  _codeController.text = room.roomCode;
                  _onJoinWithCode(room.roomCode);
                },
              );
            },
          ),
          SizedBox(height: 14 * ui),
        ] else ...[
          // Connected Banner
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * ui,
              vertical: 12 * ui,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10 * ui),
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.6),
                width: 1.2 * ui,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: const Color(0xFF00E676),
                  size: 20 * ui,
                ),
                SizedBox(width: 12 * ui),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONNECTED TO ROOM: ${service.roomCode}',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: const Color(0xFF00E676),
                          fontWeight: FontWeight.w800,
                          fontSize: 12 * ui,
                          letterSpacing: 1.0 * ui,
                        ),
                      ),
                      Text(
                        'Synchronized with host. Waiting for match to start...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10 * ui,
                        ),
                      ),
                    ],
                  ),
                ),
                LanActionButton(
                  label: 'LEAVE',
                  icon: Icons.exit_to_app,
                  ui: ui * 0.82,
                  color: const Color(0xFFFF5252),
                  onTap: () => service.disconnect(),
                ),
              ],
            ),
          ),
          SizedBox(height: 14 * ui),

          // Synchronized Player Slots
          MenuPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PLAYERS (${lobby?.playerCount ?? 0}/${lobby?.maxPlayers ?? 2})',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: kMenuMuted,
                        fontSize: 11 * ui,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      lobby?.format == LobbyFormat.doubles
                          ? 'DOUBLES 2v2'
                          : 'SINGLES 1v1',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: const Color(0xFF38BDF8),
                        fontSize: 11 * ui,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10 * ui),
                if (lobby != null)
                  ...lobby.slots.map(
                    (slot) => LanSlotTile(
                      slot: slot,
                      ui: ui,
                      isCurrentUser: slot.id == 'p2',
                      subtitle: slot.id == 'p2' ? 'You' : null,
                      onToggleReady: slot.id == 'p2'
                          ? () => service.toggleReady(slot.id)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
