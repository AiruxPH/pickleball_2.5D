import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/match_command_controller.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/match_lobby.dart';
import 'package:pickleball_3d/services/lan/lan_message.dart';
import 'package:pickleball_3d/services/lan/lan_multiplayer_service.dart';
import 'package:pickleball_3d/services/lan/lan_room_code.dart';
import 'package:pickleball_3d/services/lan/lan_room_info.dart';
import 'package:pickleball_3d/services/lan/lan_state_snapshot.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'dart:ui';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatchCommand Serialization', () {
    test('serializes movement command correctly', () {
      const cmd = MatchCommand.movement(0.75, -0.5);
      final json = cmd.toJson();

      expect(json['type'], 'movement');
      expect(json['x'], 0.75);
      expect(json['y'], -0.5);

      final restored = MatchCommand.fromJson(json);
      expect(restored.type, MatchCommandType.movement);
      expect(restored.x, 0.75);
      expect(restored.y, -0.5);
    });

    test('serializes shot command correctly', () {
      const cmd = MatchCommand.shot(ShotType.power);
      final json = cmd.toJson();

      expect(json['type'], 'shot');
      expect(json['shotType'], 'power');

      final restored = MatchCommand.fromJson(json);
      expect(restored.type, MatchCommandType.shot);
      expect(restored.shotType, ShotType.power);
    });

    test('serializes serve command correctly', () {
      const cmd = MatchCommand.serve();
      final json = cmd.toJson();

      expect(json['type'], 'serve');

      final restored = MatchCommand.fromJson(json);
      expect(restored.type, MatchCommandType.serve);
    });
  });

  group('LanMessage Protocol', () {
    test('encodes and decodes lobbySync message', () {
      const msg = LanMessage(
        type: LanMessageType.lobbySync,
        payload: {'format': 'singles', 'slots': []},
      );
      final encoded = msg.encode();
      final decoded = LanMessage.tryDecode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.type, LanMessageType.lobbySync);
      expect(decoded.payload['format'], 'singles');
    });

    test('encodes and decodes stateSync message', () {
      const msg = LanMessage(
        type: LanMessageType.stateSync,
        payload: {
          'ball': {'x': 1.0, 'y': 2.0, 'z': 3.0},
          'pScore': 5,
          'aScore': 3,
        },
      );
      final encoded = msg.encode();
      final decoded = LanMessage.tryDecode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.type, LanMessageType.stateSync);
      expect(decoded.payload['pScore'], 5);
    });
  });

  group('LanStateSnapshot', () {
    test('creates and applies snapshot to game state', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        gameMode: GameMode.singles,
        settings: GameSettings(),
      );

      final snapshot = LanStateSnapshot.fromGame(game);
      expect(snapshot.playerScore, 0);
      expect(snapshot.aiScore, 0);

      // Mutate snapshot scores & position
      const modified = LanStateSnapshot(
        ball: LanEntityState(x: 5, y: 10, z: -15),
        ballState: 'inFlight',
        player1: LanEntityState(x: 2, y: 0, z: 20),
        player2: LanEntityState(x: -2, y: 0, z: -20),
        playerScore: 7,
        aiScore: 4,
        serverNumber: 1,
        isPlayerServing: true,
        servingPrimary: true,
        gameState: 'rally',
        timestamp: 123456789,
      );

      modified.applyToGame(game);

      expect(game.ball.position.x, 5);
      expect(game.ball.position.y, 10);
      expect(game.ball.position.z, -15);
      expect(game.scoreController.playerScore, 7);
      expect(game.scoreController.aiScore, 4);
      expect(game.state, GameState.rally);
    });

    test('decodes web-style numeric fields without integer cast errors', () {
      final snapshot = LanStateSnapshot.fromJson({
        'ball': {'x': 1, 'y': 2, 'z': 3},
        'p1': {'x': 0, 'y': 0, 'z': 10},
        'p2': {'x': 0, 'y': 0, 'z': -10},
        'pScore': 7.0,
        'aScore': 4.0,
        'srvNum': 2.0,
        'ts': 123456789.0,
      });

      expect(snapshot.playerScore, 7);
      expect(snapshot.aiScore, 4);
      expect(snapshot.serverNumber, 2);
      expect(snapshot.timestamp, 123456789);
    });
  });

  group('LanMultiplayerService', () {
    test('starts hosting and manages local lobby format', () async {
      final service = LanMultiplayerService.instance;
      await service.startHosting(format: LobbyFormat.doubles);

      expect(service.isHost, isTrue);
      expect(service.lobby, isNotNull);
      expect(service.lobby!.format, LobbyFormat.doubles);
      expect(service.lobby!.slots.length, 4);

      service.setFormat(LobbyFormat.singles);
      expect(service.lobby!.format, LobbyFormat.singles);
      expect(service.lobby!.slots.length, 2);

      expect(service.roomCode.startsWith('PK-'), isTrue);

      await service.disconnect();
      expect(service.isHost, isFalse);
    });

    test('LanRoomCode generates and decodes IP tokens correctly', () {
      final code = LanRoomCode.generateRandom();
      expect(code.startsWith('PK-'), isTrue);
      expect(code.length, greaterThanOrEqualTo(6));

      const testIp = '192.168.1.45';
      final encoded = LanRoomCode.encodeIp(testIp);
      expect(encoded, isNotNull);
      expect(encoded!.startsWith('PK-'), isTrue);

      final decoded = LanRoomCode.decodeIp(encoded);
      expect(decoded, testIp);

      // Direct IP decoding pass-through
      expect(LanRoomCode.decodeIp('192.168.1.100'), '192.168.1.100');

      // IP with port decoding
      expect(LanRoomCode.decodeIp('192.0.0.4:7777'), '192.0.0.4');
      expect(LanRoomCode.isValidLanIp('192.0.0.4'), isTrue);

      // parseHostAndPort prevents port duplication
      final parsed1 = LanRoomCode.parseHostAndPort('192.0.0.4:7777');
      expect(parsed1.host, '192.0.0.4');
      expect(parsed1.port, 7777);

      final parsed2 = LanRoomCode.parseHostAndPort('ws://192.0.0.4:8888');
      expect(parsed2.host, '192.0.0.4');
      expect(parsed2.port, 8888);

      final parsed3 = LanRoomCode.parseHostAndPort('localhost:7777');
      expect(parsed3.host, '127.0.0.1');
      expect(parsed3.port, 7777);
    });

    test('LanRoomInfo serializes and deserializes', () {
      const room = LanRoomInfo(
        roomCode: 'PK-4821',
        hostAddress: '192.168.1.20',
        port: 7777,
        format: LobbyFormat.doubles,
        createdAt: 100000,
      );

      final json = room.toJson();
      final restored = LanRoomInfo.fromJson(json);

      expect(restored.roomCode, 'PK-4821');
      expect(restored.hostAddress, '192.168.1.20');
      expect(restored.format, LobbyFormat.doubles);
    });
  });
}
