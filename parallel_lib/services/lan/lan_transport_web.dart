// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'lan_message.dart';
import 'lan_room_code.dart';
import 'lan_transport.dart';

class WebLanConnection implements LanConnection {
  WebLanConnection.fromWebSocket(this._socket)
      : _channel = null,
        isHostSide = false {
    _streamController = StreamController<LanMessage>.broadcast();
    final socket = _socket;
    if (socket != null) {
      _socketSub = socket.onMessage.listen((event) {
        final msg = LanMessage.tryDecode(event.data);
        if (msg != null) _streamController.add(msg);
      });
      socket.onClose.listen((_) {
        _streamController.close();
      });
      socket.onError.listen((err) {
        _streamController.addError(err);
      });
    }
  }

  WebLanConnection.fromChannel(this._channel, {this.isHostSide = false})
      : _socket = null {
    _streamController = StreamController<LanMessage>.broadcast();
    final channel = _channel;
    if (channel != null) {
      _channelSub = channel.onMessage.listen((event) {
        final data = event.data;
        if (data is Map && data['target'] == (isHostSide ? 'host' : 'client')) {
          final msg = LanMessage.tryDecode(data['msg']);
          if (msg != null) _streamController.add(msg);
        }
      });
    }
  }

  final html.WebSocket? _socket;
  final html.BroadcastChannel? _channel;
  final bool isHostSide;
  late final StreamController<LanMessage> _streamController;
  StreamSubscription? _socketSub;
  StreamSubscription? _channelSub;

  @override
  Stream<LanMessage> get messages => _streamController.stream;

  @override
  void send(LanMessage message) {
    final socket = _socket;
    final channel = _channel;
    if (socket != null && socket.readyState == html.WebSocket.OPEN) {
      socket.sendString(message.encode());
    } else if (channel != null) {
      channel.postMessage({
        'target': isHostSide ? 'client' : 'host',
        'msg': message.encode(),
      });
    }
  }

  @override
  Future<void> close() async {
    await _socketSub?.cancel();
    await _channelSub?.cancel();
    _socket?.close();
    _channel?.close();
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }

  @override
  bool get isConnected {
    final socket = _socket;
    if (socket != null) {
      return socket.readyState == html.WebSocket.OPEN;
    }
    return _channel != null;
  }
}

class WebLanServer implements LanServer {
  html.BroadcastChannel? _channel;
  final StreamController<LanConnection> _connectionController =
      StreamController<LanConnection>.broadcast();
  StreamSubscription? _sub;

  @override
  Stream<LanConnection> get clientConnections =>
      _connectionController.stream;

  @override
  Future<void> start(int port, {String? roomCode}) async {
    await stop();
    final code = (roomCode != null && roomCode.isNotEmpty)
        ? roomCode.trim().toUpperCase()
        : 'PK-DEFAULT';
    final channel = html.BroadcastChannel('pickleball_room_$code');
    _channel = channel;
    var clientRegistered = false;
    _sub = channel.onMessage.listen((event) {
      final data = event.data;
      if (data is Map && data['type'] == 'client_hello') {
        if (!clientRegistered) {
          clientRegistered = true;
          _connectionController.add(
            WebLanConnection.fromChannel(channel, isHostSide: true),
          );
          channel.postMessage({'type': 'host_hello'});
        }
      }
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _channel?.close();
    _channel = null;
  }

  @override
  Future<List<String>> getLocalAddresses() async => ['Browser Tab / Local Network'];
}

LanServer createLanServer() => WebLanServer();

Future<LanConnection> createLanClient(
  String hostOrCode,
  int port, {
  String? roomCode,
}) async {
  final clean = hostOrCode.trim();
  final targetCode = (roomCode != null && roomCode.isNotEmpty)
      ? roomCode.trim().toUpperCase()
      : clean.toUpperCase();

  // Safely parse host and port, handling ws://, ports, and Base36 IP codes
  final parsed = LanRoomCode.parseHostAndPort(clean, defaultPort: port);
  final targetHost = parsed.host;
  final targetPort = parsed.port;
  final targetWsUrl = 'ws://$targetHost:$targetPort';

  // 1. If targetHost is an external IP on the LAN (e.g. 192.0.0.4 or 192.168.1.X from Android)
  if (LanRoomCode.isValidLanIp(targetHost) && targetHost != '127.0.0.1') {
    final completer = Completer<LanConnection>();
    try {
      final ws = html.WebSocket(targetWsUrl);
      ws.onOpen.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(WebLanConnection.fromWebSocket(ws));
        }
      });
      ws.onError.listen((e) {
        if (!completer.isCompleted) {
          completer.completeError('Failed to connect to $targetWsUrl. Ensure host is running on Android and connected to the same Wi-Fi.');
        }
      });
      return await completer.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      // If WebSocket fails, continue to BroadcastChannel fallback
    }
  }

  // 2. Attempt BroadcastChannel cross-tab connection with target room code
  final channel = html.BroadcastChannel('pickleball_room_$targetCode');
  final completer = Completer<LanConnection>();
  StreamSubscription? tempSub;

  tempSub = channel.onMessage.listen((event) {
    final data = event.data;
    if (data is Map && data['type'] == 'host_hello') {
      tempSub?.cancel();
      if (!completer.isCompleted) {
        completer.complete(
          WebLanConnection.fromChannel(channel, isHostSide: false),
        );
      }
    }
  });

  channel.postMessage({'type': 'client_hello'});

  // 3. Fallback to WebSocket if no cross-tab broadcast responds in 600ms
  Future.delayed(const Duration(milliseconds: 600), () {
    if (!completer.isCompleted) {
      tempSub?.cancel();
      try {
        final ws = html.WebSocket(targetWsUrl);
        final wsCompleter = Completer<LanConnection>();
        ws.onOpen.listen((_) {
          if (!wsCompleter.isCompleted) {
            wsCompleter.complete(WebLanConnection.fromWebSocket(ws));
          }
        });
        ws.onError.listen((e) {
          if (!wsCompleter.isCompleted) {
            wsCompleter.completeError('Could not find room "$targetCode" at $targetWsUrl. For cross-device play, ensure Android creates the room.');
          }
        });
        completer.complete(wsCompleter.future);
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError('Connection to $targetWsUrl failed: $e');
        }
      }
    }
  });

  return completer.future.timeout(const Duration(seconds: 5));
}
