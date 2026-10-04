import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lan_discovery_service.dart';
import 'lan_room_info.dart';

class IoDiscoveryBeacon implements LanDiscoveryBeacon {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  LanRoomInfo? _currentRoom;

  final Map<String, LanRoomInfo> _discoveredRooms = {};
  final StreamController<List<LanRoomInfo>> _controller =
      StreamController<List<LanRoomInfo>>.broadcast();

  static const int beaconPort = 7778;

  @override
  Future<void> startBroadcasting(LanRoomInfo room) async {
    _currentRoom = room;
    await _ensureSocket();

    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _sendBeacon();
    });
    _sendBeacon();
  }

  void _sendBeacon() {
    if (_socket == null || _currentRoom == null) return;
    try {
      final payload = jsonEncode(_currentRoom!.toJson());
      final bytes = utf8.encode(payload);
      _socket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        beaconPort,
      );
    } catch (_) {}
  }

  @override
  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _currentRoom = null;
  }

  @override
  Stream<List<LanRoomInfo>> discoverRooms() {
    _ensureSocket();
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cleanupStaleRooms();
    });
    return _controller.stream;
  }

  Future<void> _ensureSocket() async {
    if (_socket != null) return;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });
    } catch (_) {
      // Fallback if port is in use
    }
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final jsonStr = utf8.decode(datagram.data);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final room = LanRoomInfo.fromJson(json);

      // Don't show our own broadcasted room
      if (_currentRoom?.roomCode == room.roomCode) return;

      _discoveredRooms[room.roomCode] = room;
      _controller.add(_discoveredRooms.values.toList());
    } catch (_) {}
  }

  void _cleanupStaleRooms() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _discoveredRooms.removeWhere((_, room) => now - room.createdAt > 5000);
    _controller.add(_discoveredRooms.values.toList());
  }

  @override
  Future<void> dispose() async {
    await stopBroadcasting();
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    await _controller.close();
  }
}

LanDiscoveryBeacon createDiscoveryBeacon() => IoDiscoveryBeacon();
