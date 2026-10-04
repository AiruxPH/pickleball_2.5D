import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/bot_agent.dart';
import 'package:pickleball_3d/game/match_command_controller.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BotAgent', () {
    late PickleballGame game;
    late BotAgent agent;

    setUp(() {
      game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        difficultyOverride: AIDifficulty.hard,
      );
      agent = BotAgent(
        game: game,
        commands: MatchCommandController(game: game),
        difficulty: AIDifficulty.hard,
      );
    });

    test('serves through the shared command gateway after its delay', () {
      agent.update(0.7);

      expect(game.servePressed, isTrue);
    });

    test('moves toward an incoming ball without mutating position directly', () {
      game.state = GameState.rally;
      game.ball
        ..state = BallState.inFlight
        ..lastHitByPlayer = false
        ..position = Vec3(-20, 12, 30)
        ..velocity = Vec3(0, -4, 45);
      final originalPosition = game.player.position.copy();

      agent.update(0.1);

      expect(game.joystickX, isNot(0));
      expect(game.player.position.x, originalPosition.x);
      expect(game.player.position.z, originalPosition.z);
    });

    test('selects a power return for a reachable high ball on hard', () {
      game.state = GameState.rally;
      game.ball
        ..state = BallState.inFlight
        ..lastHitByPlayer = false
        ..rallyHitCount = 2
        ..hasBounced = true
        ..position = Vec3(
          game.player.position.x,
          22,
          game.player.position.z,
        )
        ..velocity = Vec3(0, -4, 20);

      agent.update(0.1);

      expect(game.powerPressed, isTrue);
      expect(game.bufferedShot, ShotType.power);
    });
  });
}
