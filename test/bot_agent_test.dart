import 'dart:math' as math;
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

    test('selects a smash for a reachable high ball on hard', () {
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

      expect(game.bufferedShot, ShotType.smash);
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

      expect(commands.lastShot, ShotType.smash);
      expect(commands.aimDirection, isNotNull);
    });

    test('ignores an outgoing ball that its own team just hit', () {
      final commands = _RecordingCommandSink();
      const observation = MatchObservation(
        state: GameState.rally,
        nearPlayer: PlayerObservation(
          position: ObservedVector(0, 0, 50),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        farPlayer: PlayerObservation(
          position: ObservedVector(0, 0, -50),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        ball: BallObservation(
          position: ObservedVector(0, 12, 35),
          velocity: ObservedVector(0, -2, -30),
          lastHitByNearSide: true,
          rallyHitCount: 3,
          hasBounced: false,
          isInPlay: true,
        ),
        controlledPlayerServing: false,
        serverShouldBeOnRight: true,
      );
      final nearAgent = BotAgent(
        observe: () => observation,
        commands: commands,
        difficulty: AIDifficulty.easy,
      );

      nearAgent.update(0.2);

      expect(commands.lastShot, isNull);
      expect(commands.aimDirection, isNull);
    });

    test('holds position when its doubles teammate owns coverage', () {
      final commands = _RecordingCommandSink();
      const observation = MatchObservation(
        state: GameState.rally,
        nearPlayer: PlayerObservation(
          position: ObservedVector(0, 0, 50),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        farPlayer: PlayerObservation(
          position: ObservedVector(0, 0, -50),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        ball: BallObservation(
          position: ObservedVector(0, 12, 35),
          velocity: ObservedVector(0, -2, 30),
          lastHitByNearSide: false,
          rallyHitCount: 3,
          hasBounced: false,
          isInPlay: true,
        ),
        controlledPlayerServing: false,
        serverShouldBeOnRight: true,
        nearPrimaryHasCoverage: false,
      );
      final nearAgent = BotAgent(
        observe: () => observation,
        commands: commands,
        difficulty: AIDifficulty.easy,
      );

      nearAgent.update(0.2);

      expect(commands.lastShot, isNull);
      expect(commands.aimDirection, isNull);
    });

    test('returns an AI serve at the production 120 Hz step', () {
      final returnGame = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: true,
        drillType: 'return_drill',
        difficultyOverride: AIDifficulty.easy,
      );
      final returnAgent = BotAgent(
        observe: () => MatchObservation.fromGame(returnGame),
        commands: MatchCommandController(game: returnGame),
        difficulty: AIDifficulty.easy,
      );

      var returnedServe = false;
      for (var i = 0; i < 960; i++) {
        returnAgent.update(1 / 120);
        returnGame.update(1 / 120);
        if (returnGame.ball.lastHitByPlayer &&
            returnGame.ball.rallyHitCount >= 1) {
          returnedServe = true;
          break;
        }
      }

      expect(returnedServe, isTrue,
          reason: 'The near-side bot must not miss a served ball between '
              'reaction ticks');
    });

    test('far-side bot owns an independent mirrored decision path', () {
      final versusGame = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isLocalMultiplayer: true,
      );
      final farAgent = BotAgent(
        observe: () => MatchObservation.fromGame(versusGame),
        commands: MatchCommandController(game: versusGame, playerSlot: 1),
        difficulty: AIDifficulty.hard,
        id: 'far-bot',
        side: BotCourtSide.far,
        personality: BotPersonality.aggressive,
        randomSeed: 22,
      );
      versusGame.state = GameState.rally;
      versusGame.ball
        ..state = BallState.inFlight
        ..lastHitByPlayer = true
        ..rallyHitCount = 2
        ..hasBounced = true
        ..position = Vec3(
          versusGame.ai.position.x,
          18,
          versusGame.ai.position.z,
        )
        ..velocity = Vec3(0, -3, -20);

      farAgent.update(1 / 120);

      expect(versusGame.opponentBufferedShot, isNotNull);
      expect(versusGame.bufferedShot, isNull,
          reason: 'The far bot must command only its own player slot');
    });

    test('personalities produce individual shot decisions', () {
      const observation = MatchObservation(
        state: GameState.rally,
        nearPlayer: PlayerObservation(
          position: ObservedVector(0, 0, 50),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        farPlayer: PlayerObservation(
          position: ObservedVector(16, 0, -55),
          velocity: ObservedVector(0, 0, 0),
          canSwing: true,
          stamina: 1,
          score: 0,
        ),
        ball: BallObservation(
          position: ObservedVector(0, 22, 50),
          velocity: ObservedVector(0, -4, 20),
          lastHitByNearSide: false,
          rallyHitCount: 2,
          hasBounced: true,
          isInPlay: true,
        ),
        controlledPlayerServing: false,
        serverShouldBeOnRight: true,
      );
      final patientCommands = _RecordingCommandSink();
      final aggressiveCommands = _RecordingCommandSink();
      final patient = BotAgent(
        observe: () => observation,
        commands: patientCommands,
        difficulty: AIDifficulty.medium,
        personality: BotPersonality.patient,
        randomSeed: 1,
      );
      final aggressive = BotAgent(
        observe: () => observation,
        commands: aggressiveCommands,
        difficulty: AIDifficulty.medium,
        personality: BotPersonality.aggressive,
        randomSeed: 2,
      );

      patient.update(1 / 120);
      aggressive.update(1 / 120);

      expect(patientCommands.lastShot, ShotType.normal);
      expect(aggressiveCommands.lastShot, ShotType.smash);
      expect(patient.plannedAim, isNot(aggressive.plannedAim));
    });

    test('two side-aware agents complete the opening three shots', () {
      final versusGame = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isLocalMultiplayer: true,
        difficultyOverride: AIDifficulty.medium,
      );
      final nearAgent = BotAgent(
        observe: () => MatchObservation.fromGame(versusGame),
        commands: MatchCommandController(game: versusGame),
        difficulty: AIDifficulty.medium,
        id: 'near-counterpuncher',
        personality: BotPersonality.patient,
        randomSeed: 1103,
      );
      final farAgent = BotAgent(
        observe: () => MatchObservation.fromGame(versusGame),
        commands: MatchCommandController(game: versusGame, playerSlot: 1),
        difficulty: AIDifficulty.medium,
        id: 'far-attacker',
        side: BotCourtSide.far,
        personality: BotPersonality.aggressive,
        randomSeed: 2909,
      );

      var longestRally = 0;
      for (var i = 0; i < 2400 && longestRally < 2; i++) {
        nearAgent.update(1 / 120);
        farAgent.update(1 / 120);
        versusGame.update(1 / 120);
        longestRally = math.max(longestRally, versusGame.ball.rallyHitCount);
      }

      expect(longestRally, greaterThanOrEqualTo(2),
          reason: 'Both independent agents must serve and legally return the '
              'first two-bounce exchanges; state=${versusGame.state}, '
              'message=${versusGame.lastMessage}, '
              'fault=${versusGame.scoreController.lastFaultDetail}, '
              'ball=${versusGame.ball.position}, '
              'near=${versusGame.player.position}, '
              'far=${versusGame.ai.position}');
    });

    test('easy doubles bots coordinate without wrong-receiver conflicts', () {
      final doublesGame = PickleballGame(
        settings: GameSettings(),
        gameMode: GameMode.doubles,
        isLocalMultiplayer: true,
        difficultyOverride: AIDifficulty.easy,
      );
      final nearAgent = BotAgent(
        observe: () => MatchObservation.fromGame(doublesGame),
        commands: MatchCommandController(game: doublesGame),
        difficulty: AIDifficulty.easy,
        randomSeed: 31,
      );
      final farAgent = BotAgent(
        observe: () => MatchObservation.fromGame(doublesGame),
        commands: MatchCommandController(game: doublesGame, playerSlot: 1),
        difficulty: AIDifficulty.easy,
        side: BotCourtSide.far,
        randomSeed: 47,
      );

      var longestRally = 0;
      var wrongReceiverFault = false;
      for (var i = 0; i < 3600 && longestRally < 2; i++) {
        nearAgent.update(1 / 120);
        farAgent.update(1 / 120);
        doublesGame.update(1 / 120);
        longestRally = math.max(longestRally, doublesGame.ball.rallyHitCount);
        wrongReceiverFault = wrongReceiverFault ||
            doublesGame.scoreController.lastFaultDetail
                .contains('WRONG RECEIVER');
        if (wrongReceiverFault) break;
      }

      expect(wrongReceiverFault, isFalse);
      expect(longestRally, greaterThanOrEqualTo(2),
          reason: 'The designated receiver and its teammate must coordinate '
              'the opening two-bounce exchange on Easy.');
      doublesGame.dispose();
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
