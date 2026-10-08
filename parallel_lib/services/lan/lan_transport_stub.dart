import 'lan_message.dart';
import 'lan_transport.dart';

class StubLanConnection implements LanConnection {
  @override
  Stream<LanMessage> get messages => const Stream.empty();

  @override
  void send(LanMessage message) {}

  @override
  Future<void> close() async {}

  @override
  bool get isConnected => false;
}

class StubLanServer implements LanServer {
  @override
  Stream<LanConnection> get clientConnections => const Stream.empty();

  @override
  Future<void> start(int port, {String? roomCode}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<List<String>> getLocalAddresses() async => ['127.0.0.1'];
}

LanServer createLanServer() => StubLanServer();

Future<LanConnection> createLanClient(
  String hostOrCode,
  int port, {
  String? roomCode,
}) async =>
    StubLanConnection();
