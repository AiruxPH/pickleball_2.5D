import 'package:flutter/material.dart';

import '../models/match_lobby.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/menu_ui.dart';

class LocalLobbyScreen extends StatefulWidget {
  const LocalLobbyScreen({super.key});

  @override
  State<LocalLobbyScreen> createState() => _LocalLobbyScreenState();
}

class _LocalLobbyScreenState extends State<LocalLobbyScreen> {
  late final MatchLobby _lobby;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(_lobbyInitialized)) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _lobby = MatchLobby.local(
        format: args?['format'] == 'doubles'
            ? LobbyFormat.doubles
            : LobbyFormat.singles,
      );
      _lobby.addListener(_refresh);
      _lobbyInitialized = true;
    }
  }

  bool _lobbyInitialized = false;

  void _refresh() => setState(() {});

  @override
  void dispose() {
    if (_lobbyInitialized) {
      _lobby.removeListener(_refresh);
      _lobby.dispose();
    }
    super.dispose();
  }

  void _startMatch() {
    if (!_lobby.canStart) return;
    Navigator.pushReplacementNamed(context, '/game', arguments: {
      'mode': _lobby.format.name,
      'localMultiplayer': true,
      'lobby': _lobby.toJson(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return MenuScreen(
      title: 'LOCAL LOBBY',
      subtitle: 'Shared screen • Online-ready room format',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(18 * ui),
            child: Column(
              children: [
                _formatSelector(ui),
                SizedBox(height: 16 * ui),
                MenuPanel(
                  padding: EdgeInsets.all(14 * ui),
                  child: Column(
                    children: _lobby.slots
                        .map((slot) => _slotTile(slot, ui))
                        .toList(),
                  ),
                ),
                SizedBox(height: 14 * ui),
                Text(
                  'P1: WASD + J/K/L/U  •  P2: ARROWS + M/N/B/V',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kMenuMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * ui,
                  ),
                ),
                SizedBox(height: 14 * ui),
                SizedBox(
                  width: double.infinity,
                  child: MenuPressable(
                    onTap: _lobby.canStart ? _startMatch : null,
                    child: AnimatedOpacity(
                      opacity: _lobby.canStart ? 1 : 0.45,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16 * ui),
                        decoration: BoxDecoration(
                          color: kMenuGold,
                          borderRadius: BorderRadius.circular(14 * ui),
                        ),
                        child: const Text(
                          'START MATCH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF07142B),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formatSelector(double ui) {
    return Row(
      children: LobbyFormat.values.map((format) {
        final selected = _lobby.format == format;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5 * ui),
            child: MenuPressable(
              onTap: () => _lobby.setFormat(format),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 13 * ui),
                decoration: BoxDecoration(
                  color: selected ? kMenuGold : const Color(0xCC172642),
                  borderRadius: BorderRadius.circular(12 * ui),
                  border: Border.all(
                    color: selected ? kMenuGold : const Color(0xFF405474),
                  ),
                ),
                child: Text(
                  format == LobbyFormat.singles ? 'SINGLES 1v1' : 'DOUBLES 2v2',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? const Color(0xFF07142B) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _slotTile(LobbyPlayerSlot slot, double ui) {
    final human = slot.type == LobbySlotType.human;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5 * ui),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: slot.team == 1
                ? const Color(0xFF0284C7)
                : const Color(0xFFE85D2A),
            child: Text('${slot.team}'),
          ),
          SizedBox(width: 12 * ui),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                Text(human ? 'LOCAL PLAYER' : 'CPU PARTNER',
                    style: TextStyle(color: kMenuMuted, fontSize: 11 * ui)),
              ],
            ),
          ),
          MenuPressable(
            onTap: human ? () => _lobby.toggleReady(slot.id) : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 13 * ui, vertical: 8 * ui),
              decoration: BoxDecoration(
                color: slot.isReady
                    ? const Color(0xFF139C68)
                    : const Color(0xFF34445E),
                borderRadius: BorderRadius.circular(10 * ui),
              ),
              child: Text(slot.isReady ? 'READY' : 'NOT READY',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
