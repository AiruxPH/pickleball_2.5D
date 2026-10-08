import 'dart:async';
import 'lan_room_info.dart';

import 'lan_discovery_stub.dart'
    if (dart.library.io) 'lan_discovery_io.dart'
    if (dart.library.html) 'lan_discovery_web.dart' as platform;

abstract class LanDiscoveryBeacon {
  Future<void> startBroadcasting(LanRoomInfo room);
  Future<void> stopBroadcasting();
  Stream<List<LanRoomInfo>> discoverRooms();
  Future<void> dispose();
}

LanDiscoveryBeacon createDiscoveryBeacon() => platform.createDiscoveryBeacon();
