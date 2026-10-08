import 'dart:async';
import 'package:flutter/material.dart';

import '../models/match_lobby.dart';
import '../services/lan/lan_multiplayer_service.dart';
import '../widgets/lan/lan_host_view.dart';
import '../widgets/lan/lan_join_view.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/menu_ui.dart';

class LocalLobbyScreen extends StatefulWidget {
  const LocalLobbyScreen({super.key});

  @override
  State<LocalLobbyScreen> createState() => _LocalLobbyScreenState();
}

class _LocalLobbyScreenState extends State<LocalLobbyScreen> {
  final LanMultiplayerService _lanService = LanMultiplayerService.instance;
  bool _isHostTab = true;
  StreamSubscription? _startMatchSub;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _lanService.addListener(_onServiceChanged);

      _startMatchSub = _lanService.onStartMatch.listen((matchArgs) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/game',
          arguments: {
            ...matchArgs,
            'lanMultiplayer': true,
            'lanRole': _lanService.isHost ? 'host' : 'client',
          },
        );
      });

      // Start hosting by default on initial entry
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final format = args?['format'] == 'doubles'
          ? LobbyFormat.doubles
          : LobbyFormat.singles;
      _lanService.startHosting(format: format);
    }
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _startMatchSub?.cancel();
    _lanService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _switchTab(bool isHost) {
    if (_isHostTab == isHost) return;
    setState(() => _isHostTab = isHost);
    if (isHost) {
      _lanService.startHosting();
    } else {
      _lanService.disconnect();
    }
  }

  void _startHostMatch() {
    final lobby = _lanService.lobby;
    if (lobby == null || !lobby.canStart) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _lanService.startMatch(matchArgs: {
      'mode': lobby.format.name,
      'lobby': lobby.toJson(),
      'court': args?['court'] ?? 'classic',
      'balanceProfile': lobby.balanceProfile.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;

    return MenuScreen(
      title: 'LAN MULTIPLAYER',
      subtitle: 'Device vs Device • Room Code Pairing • Wi-Fi & Local Network',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(18 * ui),
            child: Column(
              children: [
                // Host / Join Tab Switcher
                Container(
                  padding: EdgeInsets.all(4 * ui),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0F1E38),
                    borderRadius: BorderRadius.circular(12 * ui),
                    border: Border.all(color: const Color(0xFF2E3E5C)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MenuPressable(
                          onTap: () => _switchTab(true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12 * ui),
                            decoration: BoxDecoration(
                              color: _isHostTab
                                  ? const Color(0xFF0284C7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9 * ui),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.meeting_room_rounded,
                                    size: 16 * ui,
                                    color: _isHostTab
                                        ? Colors.white
                                        : kMenuMuted),
                                SizedBox(width: 8 * ui),
                                Text(
                                  'CREATE ROOM',
                                  style: TextStyle(
                                    color: _isHostTab
                                        ? Colors.white
                                        : kMenuMuted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12 * ui,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: MenuPressable(
                          onTap: () => _switchTab(false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12 * ui),
                            decoration: BoxDecoration(
                              color: !_isHostTab
                                  ? const Color(0xFF0284C7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9 * ui),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded,
                                    size: 16 * ui,
                                    color: !_isHostTab
                                        ? Colors.white
                                        : kMenuMuted),
                                SizedBox(width: 8 * ui),
                                Text(
                                  'JOIN ROOM',
                                  style: TextStyle(
                                    color: !_isHostTab
                                        ? Colors.white
                                        : kMenuMuted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12 * ui,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16 * ui),

                // Active View: Host or Join
                if (_isHostTab)
                  LanHostView(
                    service: _lanService,
                    ui: ui,
                    onStartMatch: _startHostMatch,
                  )
                else
                  LanJoinView(
                    service: _lanService,
                    ui: ui,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
