import 'dart:async';
import 'lan_discovery_service.dart';
import 'lan_room_info.dart';

class StubDiscoveryBeacon implements LanDiscoveryBeacon {
  @override
  Future<void> startBroadcasting(LanRoomInfo room) async {}

  @override
  Future<void> stopBroadcasting() async {}

  @override
  Stream<List<LanRoomInfo>> discoverRooms() => Stream.value([]);

  @override
  Future<void> dispose() async {}
}

LanDiscoveryBeacon createDiscoveryBeacon() => StubDiscoveryBeacon();
