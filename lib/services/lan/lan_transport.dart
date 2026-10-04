import 'lan_message.dart';
import 'lan_transport_stub.dart'
    if (dart.library.io) 'lan_transport_io.dart'
    if (dart.library.html) 'lan_transport_web.dart' as platform;

abstract class LanConnection {
  Stream<LanMessage> get messages;
  void send(LanMessage message);
  Future<void> close();
  bool get isConnected;
}

abstract class LanServer {
  Stream<LanConnection> get clientConnections;
  Future<void> start(int port, {String? roomCode});
  Future<void> stop();
  Future<List<String>> getLocalAddresses();
}

LanServer createLanServer() => platform.createLanServer();

Future<LanConnection> createLanClient(
  String hostOrCode,
  int port, {
  String? roomCode,
}) =>
    platform.createLanClient(hostOrCode, port, roomCode: roomCode);
