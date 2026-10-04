import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../game/match_command_controller.dart';
import '../../models/match_lobby.dart';
import 'lan_discovery_service.dart';
import 'lan_message.dart';
import 'lan_room_code.dart';
import 'lan_room_info.dart';
import 'lan_state_snapshot.dart';
import 'lan_transport.dart';

enum LanRole { none, host, client }

enum LanStatus { idle, hosting, connecting, connected, inGame, error }

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
    String? customRoomCode,
  }) async {
    await disconnect();
    _port = port;
    _role = LanRole.host;
    _status = LanStatus.hosting;
    _errorMessage = null;

    if (customRoomCode != null && customRoomCode.trim().isNotEmpty) {
      _roomCode = LanRoomCode.normalize(customRoomCode);
    } else if (_roomCode.isEmpty) {
      _roomCode = LanRoomCode.generateRandom();
    }

    _lobby = MatchLobby.local(format: format);
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
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _beacon.startBroadcasting(roomInfo);

      _serverSub = _server!.clientConnections.listen((clientConn) {
        _onClientConnected(clientConn);
      });

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
          _status = LanStatus.error;
          _errorMessage = 'Connection error: $err';
          notifyListeners();
        },
        onDone: () {
          _status = LanStatus.idle;
          _errorMessage = 'Host closed connection.';
          notifyListeners();
        },
      );

      // Request current lobby state from host
      _connection!.send(const LanMessage(
        type: LanMessageType.lobbyAction,
        payload: {'action': 'get_lobby'},
      ));

      notifyListeners();
    } catch (e) {
      _status = LanStatus.error;
      _errorMessage = 'Could not join room "$_roomCode": $e';
      notifyListeners();
    }
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
