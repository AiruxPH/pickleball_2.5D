import 'package:flutter/material.dart';

import '../../models/match_lobby.dart';
import '../../services/lan/lan_multiplayer_service.dart';
import '../menu_ui.dart';
import 'lan_room_code_card.dart';
import 'lan_slot_tile.dart';

class LanHostView extends StatelessWidget {
  const LanHostView({
    super.key,
    required this.service,
    required this.ui,
    required this.onStartMatch,
  });

  final LanMultiplayerService service;
  final double ui;
  final VoidCallback onStartMatch;

  @override
  Widget build(BuildContext context) {
    final lobby = service.lobby;
    final hasClient = service.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room Code Card
        LanRoomCodeCard(
          roomCode: service.roomCode,
          hostAddress: service.hostAddresses.isNotEmpty
              ? service.hostAddresses.first
              : 'Local Network',
          port: service.port,
          ui: ui,
        ),
        SizedBox(height: 14 * ui),

        // Format Selector (Singles / Doubles)
        Row(
          children: LobbyFormat.values.map((format) {
            final selected = lobby?.format == format;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4 * ui),
                child: MenuPressable(
                  onTap: () => service.setFormat(format),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12 * ui),
                    decoration: BoxDecoration(
                      color: selected ? kMenuGold : const Color(0xCC172642),
                      borderRadius: BorderRadius.circular(10 * ui),
                      border: Border.all(
                        color: selected ? kMenuGold : const Color(0xFF405474),
                      ),
                    ),
                    child: Text(
                      format == LobbyFormat.singles
                          ? 'SINGLES 1v1'
                          : 'DOUBLES 2v2',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? const Color(0xFF07142B) : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12 * ui,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 14 * ui),

        // Player Slots
        MenuPanel(
          padding: EdgeInsets.all(12 * ui),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CONNECTED PLAYERS',
                    style: TextStyle(
                      color: kMenuMuted,
                      fontSize: 10 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8 * ui, vertical: 3 * ui),
                    decoration: BoxDecoration(
                      color: hasClient
                          ? const Color(0xFF139C68).withAlpha(40)
                          : const Color(0xFFE85D2A).withAlpha(40),
                      borderRadius: BorderRadius.circular(6 * ui),
                      border: Border.all(
                        color: hasClient
                            ? const Color(0xFF139C68)
                            : const Color(0xFFE85D2A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3 * ui,
                          backgroundColor: hasClient
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF97316),
                        ),
                        SizedBox(width: 5 * ui),
                        Text(
                          hasClient ? 'CLIENT CONNECTED' : 'WAITING FOR CLIENT',
                          style: TextStyle(
                            color: hasClient
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFB923C),
                            fontSize: 9 * ui,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * ui),
              if (lobby != null)
                ...lobby.slots.map((slot) {
                  final isHostSlot = slot.id == 'p1';
                  final subtitle = isHostSlot
                      ? 'Host (This Device)'
                      : (slot.type == LobbySlotType.human
                          ? (hasClient
                              ? 'Opponent (Remote Device)'
                              : 'Waiting for device on LAN...')
                          : 'CPU Partner');
                  return LanSlotTile(
                    slot: slot,
                    ui: ui,
                    isCurrentUser: isHostSlot,
                    subtitle: subtitle,
                    onToggleReady: isHostSlot
                        ? () => service.toggleReady(slot.id)
                        : null,
                  );
                }),
            ],
          ),
        ),
        SizedBox(height: 16 * ui),

        // Start Match Button
        MenuPressable(
          onTap: (hasClient && (lobby?.canStart ?? false)) ? onStartMatch : null,
          child: AnimatedOpacity(
            opacity: (hasClient && (lobby?.canStart ?? false)) ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 160),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16 * ui),
              decoration: BoxDecoration(
                color: kMenuGold,
                borderRadius: BorderRadius.circular(12 * ui),
                boxShadow: (hasClient && (lobby?.canStart ?? false))
                    ? const [
                        BoxShadow(
                          color: Color(0x66F59E0B),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: const Text(
                'START LAN MATCH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF07142B),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
