import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../game/match_command_controller.dart';
import '../../models/match_lobby.dart';
import '../../models/match_foundation.dart';
import 'lan_discovery_service.dart';
import 'lan_message.dart';
import 'lan_room_code.dart';
import 'lan_room_info.dart';
import 'lan_state_snapshot.dart';
import 'lan_transport.dart';

enum LanRole { none, host, client }

enum LanStatus { idle, hosting, connecting, reconnecting, connected, inGame, error }

class LanMultiplayerService extends ChangeNotifier {
  LanMultiplayerService._() {
    _beacon = createDiscoveryBeacon();
  }
  static final LanMultiplayerService instance = LanMultiplayerService._();

  LanRole _role = LanRole.none;
  LanStatus _status = LanStatus.idle;
  String? _errorMessage;
  List<String> _hostAddresses = [];
  int _port = 7777;
  String? _lastJoinTarget;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;
  Timer? _heartbeat;
  int? _lastPingSentAt;
  int? _latencyMs;
  String _roomCode = LanRoomCode.generateRandom();

  LanServer? _server;
  LanConnection? _connection;
  StreamSubscription? _connectionSub;
  StreamSubscription? _serverSub;
  late final LanDiscoveryBeacon _beacon;

  MatchLobby? _lobby;

  // Event streams for in-game synchronization
  final StreamController<Map<String, dynamic>> _startMatchController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<MatchCommand> _commandController =
      StreamController<MatchCommand>.broadcast();
  final StreamController<LanStateSnapshot> _stateSyncController =
      StreamController<LanStateSnapshot>.broadcast();

  LanRole get role => _role;
  LanStatus get status => _status;
  bool get isHost => _role == LanRole.host;
  bool get isClient => _role == LanRole.client;
  bool get isConnected =>
      _status == LanStatus.connected || _status == LanStatus.inGame;
  String? get errorMessage => _errorMessage;
  List<String> get hostAddresses => List.unmodifiable(_hostAddresses);
  int get port => _port;
  int? get latencyMs => _latencyMs;
  String get roomCode => _roomCode;
  MatchLobby? get lobby => _lobby;

  Stream<Map<String, dynamic>> get onStartMatch =>
      _startMatchController.stream;
  Stream<MatchCommand> get onCommandReceived => _commandController.stream;
  Stream<LanStateSnapshot> get onStateSyncReceived =>
      _stateSyncController.stream;
  Stream<List<LanRoomInfo>> get nearbyRooms => _beacon.discoverRooms();

  void setRoomCode(String code) {
    _roomCode = LanRoomCode.normalize(code);
    notifyListeners();
  }

  void generateNewRoomCode() {
    _roomCode = LanRoomCode.generateRandom();
    notifyListeners();
  }

  Future<void> startHosting({
    int port = 7777,
    LobbyFormat format = LobbyFormat.singles,
    MatchBalanceProfile balanceProfile = MatchBalanceProfile.standard,
    String? customRoomCode,
  }) async {
    await disconnect();
    _manualDisconnect = false;
    _port = port;
    _role = LanRole.host;
    _status = LanStatus.hosting;
    _errorMessage = null;

    if (customRoomCode != null && customRoomCode.trim().isNotEmpty) {
      _roomCode = LanRoomCode.normalize(customRoomCode);
    } else if (_roomCode.isEmpty) {
      _roomCode = LanRoomCode.generateRandom();
    }

    _lobby = MatchLobby.local(
      format: format,
      balanceProfile: balanceProfile,
    );
    _lobby!.addListener(_onLocalLobbyChanged);

    try {
      _server = createLanServer();
      await _server!.start(port, roomCode: _roomCode);
      _hostAddresses = await _server!.getLocalAddresses();

      // On native platforms with a LAN IP, encode IP into the room code for easy pairing
      if (_hostAddresses.isNotEmpty && _hostAddresses.first != '127.0.0.1') {
        final encoded = LanRoomCode.encodeIp(_hostAddresses.first);
        if (encoded != null) {
          _roomCode = encoded;
        }
      }

      // Broadcast room beacon for nearby discovery
      final roomInfo = LanRoomInfo(
        roomCode: _roomCode,
        hostAddress: _hostAddresses.isNotEmpty ? _hostAddresses.first : '127.0.0.1',
        port: port,
        format: format,
        balanceProfile: balanceProfile,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _beacon.startBroadcasting(roomInfo);

      _serverSub = _server!.clientConnections.listen((clientConn) {
        _onClientConnected(clientConn);
      });

      _startHeartbeat();

      notifyListeners();
    } catch (e) {
      _status = LanStatus.error;
      _errorMessage = 'Failed to start room: $e';
      notifyListeners();
    }
  }

  void _onClientConnected(LanConnection clientConn) {
    _connection?.close();
    _connectionSub?.cancel();

    _connection = clientConn;
    _status = LanStatus.connected;

    // Send initial lobby state to client
    _sendLobbySync();

    _connectionSub = _connection!.messages.listen(
      _handleIncomingMessage,
      onError: (err) {
        _errorMessage = 'Client disconnected: $err';
        _status = LanStatus.hosting;
        notifyListeners();
      },
      onDone: () {
        _status = LanStatus.hosting;
        notifyListeners();
      },
    );

    notifyListeners();
  }

  Future<void> joinRoom(String roomCodeOrIp, {int port = 7777}) async {
    await disconnect();
    _manualDisconnect = false;
    _lastJoinTarget = roomCodeOrIp;
    _reconnectAttempt = 0;
    await _connectClient(roomCodeOrIp, port);
  }

  Future<void> _connectClient(String roomCodeOrIp, int port) async {
    _port = port;
    _role = LanRole.client;
    _status = LanStatus.connecting;
    _errorMessage = null;
    _roomCode = roomCodeOrIp.trim();
    notifyListeners();

    try {
      _connection = await createLanClient(
        _roomCode,
        port,
        roomCode: _roomCode,
      );
      _status = LanStatus.connected;

      _connectionSub = _connection!.messages.listen(
        _handleIncomingMessage,
        onError: (err) {
          _errorMessage = 'Connection error: $err';
          if (!_manualDisconnect) _scheduleReconnect();
        },
        onDone: () {
          if (!_manualDisconnect) _scheduleReconnect();
        },
      );

      _reconnectAttempt = 0;
      _startHeartbeat();

      // Request current lobby state from host
      _connection!.send(const LanMessage(
        type: LanMessageType.lobbyAction,
        payload: {'action': 'get_lobby'},
      ));

      notifyListeners();
    } catch (e) {
      if (!_manualDisconnect && _reconnectAttempt < 3) {
        _scheduleReconnect();
      } else {
        _status = LanStatus.error;
        _errorMessage = 'Could not join room "$_roomCode": $e';
        notifyListeners();
      }
    }
  }

  void _scheduleReconnect() {
    final target = _lastJoinTarget;
    if (!isClient || target == null || _manualDisconnect) return;
    _reconnectAttempt++;
    if (_reconnectAttempt > 3) {
      _status = LanStatus.error;
      _errorMessage = 'Connection lost after 3 reconnect attempts.';
      notifyListeners();
      return;
    }
    _status = LanStatus.reconnecting;
    _errorMessage = 'Reconnecting ($_reconnectAttempt/3)…';
    notifyListeners();
    Future<void>.delayed(Duration(milliseconds: 500 * _reconnectAttempt), () {
      if (!_manualDisconnect) _connectClient(target, _port);
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      final connection = _connection;
      if (connection == null || !connection.isConnected) return;
      final sentAt = DateTime.now().millisecondsSinceEpoch;
      _lastPingSentAt = sentAt;
      connection.send(LanMessage(
        type: LanMessageType.ping,
        payload: {'sentAt': sentAt},
      ));
    });
  }

  void _onLocalLobbyChanged() {
    if (isHost && isConnected) {
      _sendLobbySync();
    }
    notifyListeners();
  }

  void _sendLobbySync() {
    if (_lobby != null && _connection != null && _connection!.isConnected) {
      _connection!.send(LanMessage(
        type: LanMessageType.lobbySync,
        payload: _lobby!.toJson(),
      ));
    }
  }

  void setFormat(LobbyFormat format) {
    if (!isHost) return;
    _lobby?.setFormat(format);
    _sendLobbySync();
    notifyListeners();
  }

  void setBalanceProfile(MatchBalanceProfile profile) {
    if (!isHost) return;
    _lobby?.setBalanceProfile(profile);
    _sendLobbySync();
    notifyListeners();
  }

  void toggleReady(String slotId) {
    if (isHost) {
      _lobby?.toggleReady(slotId);
      _sendLobbySync();
      notifyListeners();
    } else if (isClient && _connection != null) {
      _connection!.send(LanMessage(
        type: LanMessageType.lobbyAction,
        payload: {'action': 'toggle_ready', 'slotId': slotId},
      ));
    }
  }

  void _handleIncomingMessage(LanMessage message) {
    switch (message.type) {
      case LanMessageType.lobbySync:
        if (isClient) {
          _lobby?.removeListener(_onLocalLobbyChanged);
          _lobby = MatchLobby.fromJson(message.payload);
          _lobby!.addListener(_onLocalLobbyChanged);
          notifyListeners();
        }
        break;

      case LanMessageType.lobbyAction:
        if (isHost) {
          final action = message.payload['action'];
          if (action == 'get_lobby') {
            _sendLobbySync();
          } else if (action == 'toggle_ready') {
            final slotId = message.payload['slotId'] as String?;
            if (slotId != null) {
              _lobby?.toggleReady(slotId);
              _sendLobbySync();
              notifyListeners();
            }
          }
        }
        break;

      case LanMessageType.startMatch:
        _status = LanStatus.inGame;
        _startMatchController.add(message.payload);
        notifyListeners();
        break;

      case LanMessageType.matchCommand:
        final cmdJson = message.payload['cmd'];
        if (cmdJson is Map) {
          final cmd = MatchCommand.fromJson(Map<String, dynamic>.from(cmdJson));
          _commandController.add(cmd);
        }
        break;

      case LanMessageType.stateSync:
        final snapshot = LanStateSnapshot.fromJson(message.payload);
        _stateSyncController.add(snapshot);
        break;

      case LanMessageType.ping:
        _connection?.send(LanMessage(
          type: LanMessageType.pong,
          payload: message.payload,
        ));
        break;

      case LanMessageType.pong:
        final sentAt = (message.payload['sentAt'] as num?)?.toInt() ?? _lastPingSentAt;
        if (sentAt != null) {
          _latencyMs = DateTime.now().millisecondsSinceEpoch - sentAt;
          notifyListeners();
        }
        break;
    }
  }

  void startMatch({required Map<String, dynamic> matchArgs}) {
    if (!isHost) return;
    _status = LanStatus.inGame;
    final payload = Map<String, dynamic>.from(matchArgs);
    _connection?.send(LanMessage(
      type: LanMessageType.startMatch,
      payload: payload,
    ));
    _startMatchController.add(payload);
    notifyListeners();
  }

  void sendMatchCommand(MatchCommand command) {
    if (_connection != null && _connection!.isConnected) {
      _connection!.send(LanMessage(
        type: LanMessageType.matchCommand,
        payload: {'cmd': command.toJson()},
      ));
    }
  }

  void sendStateSync(LanStateSnapshot snapshot) {
    if (isHost && _connection != null && _connection!.isConnected) {
      _connection!.send(LanMessage(
        type: LanMessageType.stateSync,
        payload: snapshot.toJson(),
      ));
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _beacon.stopBroadcasting();

    await _connectionSub?.cancel();
    _connectionSub = null;
    await _serverSub?.cancel();
    _serverSub = null;

    await _connection?.close();
    _connection = null;

    await _server?.stop();
    _server = null;

    _lobby?.removeListener(_onLocalLobbyChanged);
    _lobby = null;

    _role = LanRole.none;
    _status = LanStatus.idle;
    _errorMessage = null;
    _hostAddresses = [];
    _latencyMs = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _beacon.dispose();
    disconnect();
    _startMatchController.close();
    _commandController.close();
    _stateSyncController.close();
    super.dispose();
  }
}
