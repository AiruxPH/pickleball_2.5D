import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_settings.dart';
import '../models/match_lobby.dart';
import '../models/match_foundation.dart';
import '../services/online/online_multiplayer_service.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/menu_ui.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _service = OnlineMultiplayerService.instance;
  final _codeController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _startSubscription;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _service.initialize();
    _startSubscription = _service.onStartMatch.listen((arguments) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/game', arguments: {
        ...arguments,
        'onlineMultiplayer': true,
        'onlineRole': _service.isHost ? 'host' : 'client',
        'localMultiplayer': true,
      });
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    _startSubscription?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return MenuScreen(
      title: 'ONLINE MULTIPLAYER',
      subtitle: 'FIREBASE HOST-AUTHORITATIVE MATCHES',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16 * ui),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _service.isConnected
                ? _buildConnected(ui)
                : _buildEntry(ui),
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(double ui) {
    final busy = _service.status == OnlineStatus.creating ||
        _service.status == OnlineStatus.joining;
    return MenuPanel(
      padding: EdgeInsets.all(18 * ui),
      child: Column(
        children: [
          const Icon(Icons.public_rounded, size: 52, color: Color(0xFF38BDF8)),
          SizedBox(height: 14 * ui),
          if (_service.errorMessage != null)
            Padding(
              padding: EdgeInsets.only(bottom: 14 * ui),
              child: Text(
                _service.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFCA5A5)),
              ),
            ),
          MenuPrimaryButton(
            label: busy ? 'CONNECTING…' : 'CREATE ONLINE ROOM',
            icon: Icons.add_circle_outline_rounded,
            palette: TilePalette.blue,
            onTap: busy ? () {} : () => _service.createRoom(),
          ),
          SizedBox(height: 18 * ui),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(color: Colors.white, letterSpacing: 4),
            decoration: const InputDecoration(
              labelText: 'ROOM CODE',
              counterText: '',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          SizedBox(height: 10 * ui),
          MenuPrimaryButton(
            label: 'JOIN ROOM',
            icon: Icons.login_rounded,
            palette: TilePalette.green,
            onTap: busy
                ? () {}
                : () => _service.joinRoom(_codeController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildConnected(double ui) {
    final lobby = _service.lobby;
    if (lobby == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final humanSlots = lobby.humanSlots.toList();
    return MenuPanel(
      padding: EdgeInsets.all(18 * ui),
      child: Column(
        children: [
          Text('ROOM ${_service.roomCode}', style: menuTitleStyle(22 * ui)),
          SizedBox(height: 6 * ui),
          SelectableText(_service.roomCode,
              style: TextStyle(
                  color: kMenuGold,
                  fontSize: 26 * ui,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5)),
          SizedBox(height: 12 * ui),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * ui,
              vertical: 8 * ui,
            ),
            decoration: BoxDecoration(
              color: (_service.allPlayersPresent
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _service.allPlayersPresent
                    ? const Color(0xFF34D399)
                    : const Color(0xFFFBBF24),
              ),
            ),
            child: Text(
              _service.allPlayersPresent
                  ? 'PHASE 2 · BOTH PLAYERS JOINED — READY UP'
                  : 'PHASE 1 · WAITING FOR CHALLENGER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12 * ui,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_service.errorMessage != null)
            Padding(
              padding: EdgeInsets.only(top: 10 * ui),
              child: Text(
                _service.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFCA5A5)),
              ),
            ),
          SizedBox(height: 18 * ui),
          if (_service.isHost)
            MenuSegmented<LobbyFormat>(
              current: lobby.format,
              segments: const [
                MenuSegment(LobbyFormat.singles, '1v1'),
                MenuSegment(LobbyFormat.doubles, '2v2'),
              ],
              onChanged: _service.setFormat,
            ),
          if (_service.isHost) ...[
            SizedBox(height: 10 * ui),
            MenuSegmented<MatchBalanceProfile>(
              current: lobby.balanceProfile,
              segments: const [
                MenuSegment(MatchBalanceProfile.standard, 'STANDARD'),
                MenuSegment(
                  MatchBalanceProfile.competitive,
                  'COMPETITIVE',
                ),
              ],
              onChanged: _service.setBalanceProfile,
            ),
          ],
          SizedBox(height: 6 * ui),
          Text(
            lobby.balanceProfile.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kMenuMuted,
              fontSize: 10 * ui,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14 * ui),
          for (var i = 0; i < humanSlots.length; i++) ...[
            Builder(builder: (context) {
              final present = i == 0
                  ? _service.hostPresent
                  : _service.challengerPresent;
              return ListTile(
                leading: Icon(
                  !present
                      ? Icons.person_off_outlined
                      : humanSlots[i].isReady
                          ? Icons.check_circle_rounded
                          : Icons.person_rounded,
                  color: !present
                      ? Colors.white38
                      : humanSlots[i].isReady
                          ? const Color(0xFF34D399)
                          : const Color(0xFF38BDF8),
                ),
                title: Text(i == 0 ? 'HOST' : 'CHALLENGER',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  present ? 'JOINED ROOM' : 'WAITING FOR PLAYER',
                  style: TextStyle(
                    color: present ? const Color(0xFF7DD3FC) : Colors.white38,
                  ),
                ),
                trailing: Text(
                  !present
                      ? 'EMPTY'
                      : humanSlots[i].isReady
                          ? 'READY'
                          : 'NOT READY',
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: present &&
                        ((_service.isHost && i == 0) ||
                            (_service.isClient && i == 1))
                    ? () => _service.toggleReady(humanSlots[i].id)
                    : null,
              );
            }),
          ],
          SizedBox(height: 14 * ui),
          if (_service.isHost)
            MenuPrimaryButton(
              label: 'START ONLINE MATCH',
              icon: Icons.play_arrow_rounded,
              palette: TilePalette.gold,
              onTap: lobby.canStart && _service.allPlayersPresent
                  ? () {
                      final settings = context.read<GameSettings>();
                      _service.startMatch({
                        'mode': lobby.format == LobbyFormat.doubles
                            ? 'doubles'
                            : 'singles',
                        'difficulty': settings.difficulty.index + 1,
                      });
                    }
                  : () {},
            ),
          SizedBox(height: 10 * ui),
          TextButton.icon(
            onPressed: _service.leaveRoom,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('LEAVE ROOM'),
          ),
        ],
      ),
    );
  }
}
