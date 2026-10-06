import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../game/match_command_controller.dart';
import '../../models/match_lobby.dart';
import '../lan/lan_state_snapshot.dart';
import 'firebase_bootstrap.dart';
import 'webrtc_game_transport.dart';

enum OnlineRole { none, host, client }

enum OnlineStatus {
  unavailable,
  idle,
  creating,
  joining,
  connected,
  inGame,
  disconnected,
  error,
}

class OnlineMultiplayerService extends ChangeNotifier {
  OnlineMultiplayerService._();
  static final instance = OnlineMultiplayerService._();

  OnlineRole _role = OnlineRole.none;
  OnlineStatus _status = OnlineStatus.unavailable;
  String? _errorMessage;
  String _roomCode = '';
  String? _uid;
  MatchLobby? _lobby;
  DatabaseReference? _room;
  bool _snapshotWriteEnabled = true;
  int _snapshotWritesInFlight = 0;
  bool _snapshotDecodeErrorReported = false;
  int _commandWritesInFlight = 0;
  bool _commandWritesEnabled = true;
  MatchCommand? _pendingCommand;
  final List<MatchCommand> _pendingPriorityCommands = <MatchCommand>[];
  int _commandSequence = 0;
  final Map<String, int> _lastCommandSequence = <String, int>{};
  bool _hostPresent = false;
  bool _challengerPresent = false;
  WebRtcGameTransport? _webRtc;

  static const int _maxSnapshotWritesInFlight = 3;
  static const int _maxCommandWritesInFlight = 3;

  final _startController = StreamController<Map<String, dynamic>>.broadcast();
  final _commandController = StreamController<MatchCommand>.broadcast();
  final _snapshotController = StreamController<LanStateSnapshot>.broadcast();
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  OnlineRole get role => _role;
  OnlineStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get roomCode => _roomCode;
  String? get userId => _uid;
  MatchLobby? get lobby => _lobby;
  bool get isHost => _role == OnlineRole.host;
  bool get isClient => _role == OnlineRole.client;
  bool get isConnected =>
      _status == OnlineStatus.connected || _status == OnlineStatus.inGame;
  bool get hostPresent => _hostPresent;
  bool get challengerPresent => _challengerPresent;
  bool get allPlayersPresent => _hostPresent && _challengerPresent;
  bool get isPeerToPeerConnected => _webRtc?.isConnected ?? false;
  Stream<Map<String, dynamic>> get onStartMatch => _startController.stream;
  Stream<MatchCommand> get onCommandReceived => _commandController.stream;
  Stream<LanStateSnapshot> get onStateSyncReceived =>
      _snapshotController.stream;

  Future<bool> initialize() async {
    if (!await FirebaseBootstrap.initialize()) {
      _status = OnlineStatus.unavailable;
      _errorMessage =
          'Firebase is not configured. Run flutterfire configure first.';
      notifyListeners();
      return false;
    }
    try {
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
      if (_uid == null) throw StateError('Anonymous sign-in returned no user.');
      _status = OnlineStatus.idle;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (error) {
      _status = OnlineStatus.error;
      _errorMessage = error.code == 'operation-not-allowed'
          ? 'Enable Anonymous sign-in in Firebase Authentication.'
          : error.message ?? error.code;
      notifyListeners();
      return false;
    } catch (error) {
      _status = OnlineStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> createRoom({LobbyFormat format = LobbyFormat.singles}) async {
    await leaveRoom();
    if (!await initialize()) return;
    _role = OnlineRole.host;
    _snapshotWriteEnabled = true;
    _snapshotWritesInFlight = 0;
    _status = OnlineStatus.creating;
    _roomCode = _generateRoomCode();
    _lobby = MatchLobby.online(_roomCode, format: format);
    _lobby!.addListener(_writeLobby);
    _room = FirebaseDatabase.instance.ref('onlineRooms/$_roomCode');
    try {
      await _room!.child('meta').set({
        'hostUid': _uid,
        'status': 'lobby',
        'sessionId': _roomCode,
        'format': format.name,
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
      await _room!.update({
        'lobby': _lobby!.toJson(),
        'members/$_uid': {
          'role': 'host',
          'slot': 0,
          'online': true,
          'joinedAt': ServerValue.timestamp,
        },
      });
      await _room!.child('members/$_uid').onDisconnect().remove();
      await _room!.child('meta/status').onDisconnect().set('closed');
      _listenToRoom();
      unawaited(_startWebRtc());
      _status = OnlineStatus.connected;
      notifyListeners();
    } catch (error) {
      _fail('Could not create online room', error);
    }
  }

  Future<void> joinRoom(String code) async {
    await leaveRoom();
    if (!await initialize()) return;
    _role = OnlineRole.client;
    _status = OnlineStatus.joining;
    _roomCode = code.trim().toUpperCase();
    _room = FirebaseDatabase.instance.ref('onlineRooms/$_roomCode');
    notifyListeners();
    try {
      final snapshot = await _room!.get();
      if (!snapshot.exists) throw StateError('Room not found.');
      final raw = snapshot.value;
      if (raw is! Map) throw StateError('Room data is invalid.');
      final data = Map<String, dynamic>.from(raw);
      final meta = Map<String, dynamic>.from(data['meta'] as Map? ?? {});
      if (meta['status'] == 'closed') throw StateError('Room is closed.');
      final lobbyRaw = data['lobby'];
      if (lobbyRaw is Map) {
        _replaceLobby(MatchLobby.fromJson(Map<String, dynamic>.from(lobbyRaw)));
      }
      await _room!.child('members/$_uid').set({
        'role': 'client',
        'slot': 1,
        'online': true,
        'joinedAt': ServerValue.timestamp,
      });
      await _room!.child('members/$_uid').onDisconnect().remove();
      await _room!.child('ready/$_uid').set(false);
      await _room!.child('ready/$_uid').onDisconnect().set(false);
      _listenToRoom();
      unawaited(_startWebRtc());
      _status = OnlineStatus.connected;
      notifyListeners();
    } catch (error) {
      _fail('Could not join room', error);
    }
  }

  void _listenToRoom() {
    final room = _room!;
    _subscriptions.add(room.child('lobby').onValue.listen((event) {
      if (!isClient || event.snapshot.value is! Map) return;
      _replaceLobby(MatchLobby.fromJson(
          Map<String, dynamic>.from(event.snapshot.value as Map)));
      notifyListeners();
    }));
    _subscriptions.add(room.child('start').onValue.listen((event) {
      if (event.snapshot.value is! Map) return;
      final payload = Map<String, dynamic>.from(event.snapshot.value as Map);
      _status = OnlineStatus.inGame;
      _startController.add(payload);
      notifyListeners();
    }));
    _subscriptions.add(room.child('members').onValue.listen((event) {
      var hostPresent = false;
      var challengerPresent = false;
      final raw = event.snapshot.value;
      if (raw is Map) {
        for (final value in raw.values) {
          if (value is! Map || value['online'] != true) continue;
          hostPresent |= value['role'] == 'host';
          challengerPresent |= value['role'] == 'client';
        }
      }
      final challengerLeft = _challengerPresent && !challengerPresent;
      _hostPresent = hostPresent;
      _challengerPresent = challengerPresent;
      if (challengerLeft && isHost) {
        _lobby?.setReady('p2', false);
      }
      notifyListeners();
    }));
    if (isHost) {
      _subscriptions.add(room.child('ready').onValue.listen((event) {
        var challengerReady = false;
        final raw = event.snapshot.value;
        if (raw is Map) {
          challengerReady = raw.values.any((value) => value == true);
        }
        _lobby?.setReady('p2', challengerReady);
      }));
      _subscriptions.add(room.child('commands').onValue.listen((event) {
        final rawCommands = event.snapshot.value;
        if (rawCommands is! Map) return;
        for (final entry in rawCommands.entries) {
          final uid = entry.key.toString();
          final raw = entry.value;
          if (raw is! Map || raw['cmd'] is! Map) continue;
          final sequence = (raw['seq'] as num?)?.toInt() ?? 0;
          if (sequence <= (_lastCommandSequence[uid] ?? 0)) continue;
          _lastCommandSequence[uid] = sequence;
          _commandController.add(MatchCommand.fromJson(
              Map<String, dynamic>.from(raw['cmd'] as Map)));
        }
      }));
    } else {
      _subscriptions.add(room.child('snapshot').onValue.listen((event) {
        final raw = event.snapshot.value;
        if (raw is! Map) return;
        try {
          _snapshotController.add(
            LanStateSnapshot.fromJson(Map<String, dynamic>.from(raw)),
          );
          _snapshotDecodeErrorReported = false;
        } catch (error, stackTrace) {
          if (_snapshotDecodeErrorReported) return;
          _snapshotDecodeErrorReported = true;
          debugPrint('[OnlineMultiplayer] Invalid state snapshot: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }));
      _subscriptions.add(room.child('meta/status').onValue.listen((event) {
        if (event.snapshot.value == 'closed') {
          _status = OnlineStatus.disconnected;
          _errorMessage = 'The host closed the room.';
          notifyListeners();
        }
      }));
    }
  }

  void _replaceLobby(MatchLobby next) {
    _lobby?.removeListener(_writeLobby);
    _lobby = next;
    if (isHost) _lobby!.addListener(_writeLobby);
  }

  Future<void> _writeLobby() async {
    if (isHost && _lobby != null) {
      await _room?.child('lobby').set(_lobby!.toJson());
      notifyListeners();
    }
  }

  void setFormat(LobbyFormat format) {
    if (!isHost) return;
    _lobby?.setFormat(format);
  }

  Future<void> toggleReady(String slotId) async {
    if (isHost) {
      _lobby?.toggleReady(slotId);
      return;
    }
    if (!_challengerPresent) return;
    try {
      await _ensureClientMembership();
      final slot =
          _lobby?.humanSlots.where((player) => player.id == slotId).firstOrNull;
      if (slot == null) return;
      await _room?.child('ready/$_uid').set(!slot.isReady);
    } catch (error) {
      _errorMessage = 'Could not update ready state: $error';
      debugPrint('[OnlineMultiplayer] $_errorMessage');
      notifyListeners();
    }
  }

  Future<void> _ensureClientMembership() async {
    if (!isClient || _room == null || _uid == null) return;
    await _room!.child('members/$_uid').set({
      'role': 'client',
      'slot': 1,
      'online': true,
      'joinedAt': ServerValue.timestamp,
    });
    await _room!.child('members/$_uid').onDisconnect().remove();
  }

  Future<void> startMatch(Map<String, dynamic> arguments) async {
    if (!isHost || _room == null || !allPlayersPresent) return;
    final payload = Map<String, dynamic>.from(arguments)
      ..['startedAt'] = ServerValue.timestamp
      ..['sessionId'] = _roomCode;
    await _room!.update({'start': payload, 'meta/status': 'inGame'});
  }

  Future<void> _startWebRtc() async {
    final room = _room;
    final uid = _uid;
    if (room == null || uid == null || _role == OnlineRole.none) return;
    try {
      await _webRtc?.close();
      final transport = WebRtcGameTransport(
        room: room,
        uid: uid,
        isHost: isHost,
        onCommand: _commandController.add,
        onSnapshot: _snapshotController.add,
        onConnectionChanged: notifyListeners,
      );
      _webRtc = transport;
      await transport.start();
    } catch (error, stackTrace) {
      debugPrint(
          '[OnlineMultiplayer] WebRTC unavailable; using Firebase: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _webRtc?.close();
      _webRtc = null;
      notifyListeners();
    }
  }

  Future<void> sendMatchCommand(MatchCommand command) async {
    if (!isClient || _room == null || !_commandWritesEnabled) return;
    if (_webRtc?.sendCommand(command) ?? false) return;
    if (command.type == MatchCommandType.movement) {
      _pendingCommand = command;
    } else {
      if (_pendingPriorityCommands.length >= 8) {
        _pendingPriorityCommands.removeAt(0);
      }
      _pendingPriorityCommands.add(command);
    }
    _flushPendingCommands();
  }

  void _flushPendingCommands() {
    final room = _room;
    if (!isClient ||
        room == null ||
        !_commandWritesEnabled ||
        _commandWritesInFlight >= _maxCommandWritesInFlight) {
      return;
    }
    final MatchCommand? next = _pendingPriorityCommands.isNotEmpty
        ? _pendingPriorityCommands.removeAt(0)
        : _pendingCommand;
    if (next == null) return;
    if (identical(next, _pendingCommand)) _pendingCommand = null;

    _commandWritesInFlight++;
    room.child('commands/$_uid').set({
      'uid': _uid,
      'slot': 1,
      'seq': ++_commandSequence,
      'cmd': next.toJson(),
      'createdAt': ServerValue.timestamp,
    }).catchError((Object error) {
      _pendingCommand = null;
      _pendingPriorityCommands.clear();
      _commandWritesEnabled = false;
      _status = OnlineStatus.error;
      _errorMessage = 'Challenger input was rejected: $error';
      debugPrint('[OnlineMultiplayer] $_errorMessage');
      notifyListeners();
    }).whenComplete(() {
      _commandWritesInFlight = max(0, _commandWritesInFlight - 1);
      _flushPendingCommands();
    });

    _flushPendingCommands();
  }

  Future<void> sendStateSync(LanStateSnapshot snapshot) async {
    if (_webRtc?.sendSnapshot(snapshot) ?? false) return;
    if (!isHost ||
        _room == null ||
        !_snapshotWriteEnabled ||
        _snapshotWritesInFlight >= _maxSnapshotWritesInFlight) {
      return;
    }
    _snapshotWritesInFlight++;
    try {
      await _room!.child('snapshot').set(snapshot.toJson());
    } catch (error) {
      // A frame-driven caller must never create an unbounded stream of
      // rejected futures. Disable sync until the next room connection.
      _snapshotWriteEnabled = false;
      _status = OnlineStatus.error;
      _errorMessage = 'Online state sync failed: $error';
      debugPrint('[OnlineMultiplayer] $_errorMessage');
      notifyListeners();
    } finally {
      _snapshotWritesInFlight = max(0, _snapshotWritesInFlight - 1);
    }
  }

  Future<void> leaveRoom() async {
    await _webRtc?.close();
    _webRtc = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _lobby?.removeListener(_writeLobby);
    if (_room != null && _uid != null) {
      if (isClient) {
        await _room!.child('ready/$_uid').set(false);
      }
      await _room!.child('members/$_uid').remove();
      if (isHost) {
        await _room!.child('meta/status').set('closed');
      }
    }
    _room = null;
    _lobby = null;
    _roomCode = '';
    _role = OnlineRole.none;
    _snapshotWriteEnabled = true;
    _snapshotWritesInFlight = 0;
    _snapshotDecodeErrorReported = false;
    _commandWritesInFlight = 0;
    _commandWritesEnabled = true;
    _pendingCommand = null;
    _pendingPriorityCommands.clear();
    _commandSequence = 0;
    _lastCommandSequence.clear();
    _hostPresent = false;
    _challengerPresent = false;
    _status = FirebaseBootstrap.isReady
        ? OnlineStatus.idle
        : OnlineStatus.unavailable;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(String prefix, Object error) {
    _status = OnlineStatus.error;
    _errorMessage = '$prefix: $error';
    notifyListeners();
  }

  static String _generateRoomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => alphabet[random.nextInt(alphabet.length)])
        .join();
  }
}
