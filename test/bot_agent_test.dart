import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/bot_agent.dart';
import 'package:pickleball_3d/game/match_command_controller.dart';
import 'package:pickleball_3d/game/match_observation.dart';
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
        observe: () => MatchObservation.fromGame(game),
        commands: MatchCommandController(game: game),
        difficulty: AIDifficulty.hard,
      );
    });

    test('serves through the shared command gateway after its delay', () {
      agent.update(0.7);

      expect(game.servePressed, isTrue);
    });

    test('moves toward an incoming ball without mutating position directly',
        () {
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

    test('decides from a standalone observation with command-only output', () {
      final commands = _RecordingCommandSink();
      const observation = MatchObservation(
        state: GameState.rally,
        nearPlayer: PlayerObservation(
          position: ObservedVector(0, 0, 60),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        farPlayer: PlayerObservation(
          position: ObservedVector(16, 0, -60),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        ball: BallObservation(
          position: ObservedVector(0, 22, 60),
          velocity: ObservedVector(0, -4, 20),
          lastHitByNearSide: false,
          rallyHitCount: 2,
          hasBounced: true,
          isInPlay: true,
        ),
        controlledPlayerServing: false,
        serverShouldBeOnRight: true,
      );
      final isolatedAgent = BotAgent(
        observe: () => observation,
        commands: commands,
        difficulty: AIDifficulty.hard,
      );

      isolatedAgent.update(0.1);

      expect(commands.lastShot, ShotType.power);
      expect(commands.aimDirection, isNotNull);
    });
  });
}

final class _RecordingCommandSink implements MatchCommandSink {
  Offset? aimDirection;
  ShotType? lastShot;

  @override
  void aim(Offset direction) => aimDirection = direction;

  @override
  void clearAim() => aimDirection = null;

  @override
  void move(double x, double y) {}

  @override
  void serve() {}

  @override
  void shot(ShotType type) => lastShot = type;

  @override
  void stopMoving() {}

  @override
  void toggleUltimate() {}
}
