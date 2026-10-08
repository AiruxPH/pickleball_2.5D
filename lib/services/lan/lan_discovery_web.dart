// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'lan_discovery_service.dart';
import 'lan_room_info.dart';

class WebDiscoveryBeacon implements LanDiscoveryBeacon {
  Timer? _broadcastTimer;
  Timer? _scanTimer;
  LanRoomInfo? _currentRoom;
  final StreamController<List<LanRoomInfo>> _controller =
      StreamController<List<LanRoomInfo>>.broadcast();

  @override
  Future<void> startBroadcasting(LanRoomInfo room) async {
    _currentRoom = room;
    _updateLocalStorage();
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateLocalStorage();
    });
  }

  void _updateLocalStorage() {
    if (_currentRoom == null) return;
    try {
      final updated = LanRoomInfo(
        roomCode: _currentRoom!.roomCode,
        hostAddress: _currentRoom!.hostAddress,
        port: _currentRoom!.port,
        format: _currentRoom!.format,
        balanceProfile: _currentRoom!.balanceProfile,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        name: _currentRoom!.name,
      );
      final jsonStr = jsonEncode(updated.toJson());
      html.window.localStorage['pkl_room_${_currentRoom!.roomCode}'] = jsonStr;
    } catch (_) {}
  }

  @override
  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    if (_currentRoom != null) {
      try {
        html.window.localStorage.remove('pkl_room_${_currentRoom!.roomCode}');
      } catch (_) {}
      _currentRoom = null;
    }
  }

  @override
  Stream<List<LanRoomInfo>> discoverRooms() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _scanActiveRooms();
    });
    // Initial immediate scan
    _scanActiveRooms();
    return _controller.stream;
  }

  void _scanActiveRooms() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rooms = <LanRoomInfo>[];
    final keysToRemove = <String>[];

    try {
      final storage = html.window.localStorage;
      for (final key in storage.keys) {
        if (key.startsWith('pkl_room_')) {
          final val = storage[key];
          if (val != null) {
            try {
              final json = jsonDecode(val) as Map<String, dynamic>;
              final room = LanRoomInfo.fromJson(json);
              // Rooms active within the last 4 seconds
              if (now - room.createdAt < 4000) {
                // If broadcasting our own room, don't show it in join list
                if (_currentRoom?.roomCode != room.roomCode) {
                  rooms.add(room);
                }
              } else {
                keysToRemove.add(key);
              }
            } catch (_) {
              keysToRemove.add(key);
            }
          }
        }
      }

      for (final k in keysToRemove) {
        storage.remove(k);
      }
    } catch (_) {}

    _controller.add(rooms);
  }

  @override
  Future<void> dispose() async {
    await stopBroadcasting();
    _scanTimer?.cancel();
    _scanTimer = null;
    await _controller.close();
  }
}

LanDiscoveryBeacon createDiscoveryBeacon() => WebDiscoveryBeacon();
