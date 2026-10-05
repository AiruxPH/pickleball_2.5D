import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../game/match_command_controller.dart';
import '../../models/match_lobby.dart';
import '../lan/lan_state_snapshot.dart';
import 'firebase_bootstrap.dart';

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
  bool _snapshotWriteInFlight = false;

  final _startController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _commandController = StreamController<MatchCommand>.broadcast();
  final _snapshotController =
      StreamController<LanStateSnapshot>.broadcast();
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
    _snapshotWriteInFlight = false;
    _status = OnlineStatus.creating;
    _roomCode = _generateRoomCode();
    _lobby = MatchLobby.online(_roomCode, format: format);
    _lobby!.addListener(_writeLobby);
    _room = FirebaseDatabase.instance.ref('onlineRooms/$_roomCode');
    try {
      await _room!.child('meta').set({
        'hostUid': _uid,
        'status': 'lobby',
        'format': format.name,
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
      await _room!.update({
        'lobby': _lobby!.toJson(),
        'members/$_uid': {
          'role': 'host',
          'online': true,
          'joinedAt': ServerValue.timestamp,
        },
      });
      await _room!.child('members/$_uid').onDisconnect().remove();
      await _room!.child('meta/status').onDisconnect().set('closed');
      _listenToRoom();
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
        'online': true,
        'joinedAt': ServerValue.timestamp,
      });
      await _room!.child('members/$_uid').onDisconnect().remove();
      _listenToRoom();
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
    if (isHost) {
      _subscriptions.add(room.child('actions').onChildAdded.listen((event) {
        final raw = event.snapshot.value;
        if (raw is Map && raw['type'] == 'toggleReady') {
          final slotId = raw['slotId'] as String?;
          if (slotId != null) _lobby?.toggleReady(slotId);
        }
        event.snapshot.ref.remove();
      }));
      _subscriptions.add(room.child('commands').onChildAdded.listen((event) {
        final raw = event.snapshot.value;
        if (raw is Map && raw['cmd'] is Map) {
          _commandController.add(MatchCommand.fromJson(
              Map<String, dynamic>.from(raw['cmd'] as Map)));
        }
        event.snapshot.ref.remove();
      }));
    } else {
      _subscriptions.add(room.child('snapshot').onValue.listen((event) {
        if (event.snapshot.value is Map) {
          _snapshotController.add(LanStateSnapshot.fromJson(
              Map<String, dynamic>.from(event.snapshot.value as Map)));
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
    final action = _room?.child('actions').push();
    await action?.set({
      'type': 'toggleReady',
      'slotId': slotId,
      'uid': _uid,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> startMatch(Map<String, dynamic> arguments) async {
    if (!isHost || _room == null) return;
    final payload = Map<String, dynamic>.from(arguments)
      ..['startedAt'] = ServerValue.timestamp;
    await _room!.update({'start': payload, 'meta/status': 'inGame'});
  }

  Future<void> sendMatchCommand(MatchCommand command) async {
    if (!isClient || _room == null) return;
    await _room!.child('commands').push().set({
      'uid': _uid,
      'cmd': command.toJson(),
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> sendStateSync(LanStateSnapshot snapshot) async {
    if (!isHost ||
        _room == null ||
        !_snapshotWriteEnabled ||
        _snapshotWriteInFlight) {
      return;
    }
    _snapshotWriteInFlight = true;
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
      _snapshotWriteInFlight = false;
    }
  }

  Future<void> leaveRoom() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _lobby?.removeListener(_writeLobby);
    if (_room != null && _uid != null) {
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
    _snapshotWriteInFlight = false;
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
