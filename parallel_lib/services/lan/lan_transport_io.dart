import 'dart:async';
import 'dart:io';

import 'lan_message.dart';
import 'lan_room_code.dart';
import 'lan_transport.dart';

class IoLanConnection implements LanConnection {
  IoLanConnection(this._socket) {
    _streamController = StreamController<LanMessage>.broadcast();
    _subscription = _socket.listen(
      (data) {
        final msg = LanMessage.tryDecode(data);
        if (msg != null) {
          _streamController.add(msg);
        }
      },
      onError: (err) {
        _streamController.addError(err);
      },
      onDone: () {
        _streamController.close();
      },
    );
  }

  final WebSocket _socket;
  late final StreamController<LanMessage> _streamController;
  StreamSubscription? _subscription;

  @override
  Stream<LanMessage> get messages => _streamController.stream;

  @override
  void send(LanMessage message) {
    if (isConnected) {
      try {
        _socket.add(message.encode());
      } catch (_) {}
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _socket.close();
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }

  @override
  bool get isConnected => _socket.readyState == WebSocket.open;
}

class IoLanServer implements LanServer {
  HttpServer? _server;
  final StreamController<LanConnection> _connectionController =
      StreamController<LanConnection>.broadcast();

  @override
  Stream<LanConnection> get clientConnections =>
      _connectionController.stream;

  @override
  Future<void> start(int port, {String? roomCode}) async {
    await stop();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          final connection = IoLanConnection(socket);
          _connectionController.add(connection);
        } catch (_) {}
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      }
    });
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  @override
  Future<List<String>> getLocalAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }
    return ips;
  }
}

LanServer createLanServer() => IoLanServer();

Future<LanConnection> createLanClient(
  String hostOrCode,
  int port, {
  String? roomCode,
}) async {
  final clean = hostOrCode.trim();
  final parsed = LanRoomCode.parseHostAndPort(clean, defaultPort: port);
  final socket = await WebSocket.connect('ws://${parsed.host}:${parsed.port}')
      .timeout(const Duration(seconds: 4));
  return IoLanConnection(socket);
}
