import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/ai_controller.dart';
import 'package:pickleball_3d/game/ball_controller.dart';
import 'package:pickleball_3d/game/physics_controller.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Regulation world scale', () {
    test('court, athlete, ball, and net share one unit conversion', () {
      expect(CourtDimensions.width / CourtDimensions.unitsPerFoot, 20);
      expect(CourtDimensions.length / CourtDimensions.unitsPerFoot, 44);
      expect(CourtDimensions.playerHeight / CourtDimensions.unitsPerFoot, 6);
      expect(CourtDimensions.width / CourtDimensions.playerHeight,
          closeTo(20 / 6, 1e-9));
      expect(PhysicsConstants.ballRadius * 2 * 3, closeTo(2.94, 0.01));
      expect(CourtDimensions.netHeight, 12);
      expect(CourtDimensions.netHeightAt(0), closeTo(34 / 3, 1e-9));
      expect(
        CourtDimensions.netHeightAt(CourtDimensions.halfWidth),
        CourtDimensions.netHeight,
      );
    });

    test('net collision follows the rendered sag and ball radius', () {
      final ball = Pickleball();
      final physics = PhysicsController(
        ball: ball,
        player: Player(startPosition: Vec3(0, 0, 60), isHuman: true),
        ai: Player(startPosition: Vec3(0, 0, -60), isHuman: false),
        court: Court(),
      );
      final centerNet = CourtDimensions.netHeightAt(0);

      ball
        ..prevPosition = Vec3(0, centerNet + PhysicsConstants.ballRadius, 2)
        ..position = Vec3(0, centerNet + PhysicsConstants.ballRadius, -2)
        ..velocity = Vec3(0, 0, -100)
        ..state = BallState.inFlight;
      expect(physics.update(1 / 120).netHit, isTrue);

      ball
        ..netCollision = false
        ..prevPosition =
            Vec3(0, centerNet + PhysicsConstants.ballRadius + 0.1, 2)
        ..position = Vec3(0, centerNet + PhysicsConstants.ballRadius + 0.1, -2)
        ..velocity = Vec3(0, 0, -100);
      expect(physics.update(1 / 120).netHit, isFalse);
    });
  });

  group('Context-aware far-side bot', () {
    test('lobs over an opponent crowding the kitchen and lands in bounds', () {
      final scenario = _Scenario(
        aiPosition: Vec3(0, 0, -34),
        playerPosition: Vec3(-10, 0, 22),
        ballHeight: 10,
      );

      scenario.runUntilHit();

      expect(scenario.ball.shotType, ShotType.lob);
      final landing = scenario.runUntilBounce();
      expect(landing.z, inInclusiveRange(0, CourtDimensions.halfLength));
      expect(landing.x.abs(), lessThan(CourtDimensions.halfWidth));
    });

    test('dinks when the opponent is pinned deep', () {
      final scenario = _Scenario(
        aiPosition: Vec3(0, 0, -34),
        playerPosition: Vec3(16, 0, 74),
        ballHeight: 10,
      );

      scenario.runUntilHit();

      expect(scenario.ball.shotType, ShotType.drop);
      final landing = scenario.runUntilBounce();
      expect(landing.z, inInclusiveRange(0, CourtDimensions.kitchenDepth));
      expect(landing.x.abs(), lessThan(CourtDimensions.halfWidth));
    });

    test('smashes a high attackable ball into the opponent court', () {
      final scenario = _Scenario(
        aiPosition: Vec3(0, 0, -45),
        playerPosition: Vec3(-15, 0, 65),
        ballHeight: 22,
      );

      scenario.runUntilHit();

      expect(scenario.ball.shotType, ShotType.smash);
      final landing = scenario.runUntilBounce();
      expect(landing.z, inInclusiveRange(0, CourtDimensions.halfLength));
      expect(landing.x.abs(), lessThan(CourtDimensions.halfWidth));
    });

    test('never volleys while its feet are touching the kitchen', () {
      final settings = GameSettings()..difficulty = AIDifficulty.hard;
      final ai = Player(
        startPosition: Vec3(0, 0, -14),
        isHuman: false,
        isNearSide: false,
      );
      final ball = Pickleball()
        ..position = Vec3(0, 14, -12)
        ..velocity = Vec3(0, -2, -4)
        ..lastHitByPlayer = true
        ..rallyHitCount = 3
        ..hasBounced = false
        ..state = BallState.inFlight;
      final controller = AIController(
        ai: ai,
        ball: ball,
        court: Court(),
        settings: settings,
      );

      double? contactZ;
      for (var i = 0; i < 180; i++) {
        controller.update(1 / 120);
        if (!ball.lastHitByPlayer) {
          contactZ = ai.position.z;
          break;
        }
      }

      if (contactZ != null) {
        expect(
          contactZ,
          lessThan(-CourtDimensions.kitchenDepth - Player.footRadius),
        );
      }
    });
  });
}

final class _Scenario {
  _Scenario({
    required Vec3 aiPosition,
    required Vec3 playerPosition,
    required double ballHeight,
  })  : settings = GameSettings()..difficulty = AIDifficulty.hard,
        ai = Player(
          startPosition: aiPosition,
          isHuman: false,
          isNearSide: false,
        ),
        player = Player(
          startPosition: playerPosition,
          isHuman: true,
          isNearSide: true,
        ),
        ball = Pickleball() {
    ball
      ..position = Vec3(aiPosition.x, ballHeight, aiPosition.z)
      ..velocity = Vec3(0, -5, -20)
      ..lastHitByPlayer = true
      ..hasBounced = true
      ..lastBounceZ = aiPosition.z - 8
      ..rallyHitCount = 3
      ..state = BallState.inFlight;
    aiController = AIController(
      ai: ai,
      ball: ball,
      court: court,
      settings: settings,
      humanPlayer: player,
    );
  }

  final GameSettings settings;
  final Court court = Court();
  final Player ai;
  final Player player;
  final Pickleball ball;
  late final AIController aiController;

  void runUntilHit() {
    for (var i = 0; i < 120 && ball.lastHitByPlayer; i++) {
      aiController.update(1 / 120);
    }
    expect(ball.lastHitByPlayer, isFalse, reason: 'AI should reach the ball');
  }

  Vec3 runUntilBounce() {
    final ballController = BallController(ball: ball, court: court);
    final physics = PhysicsController(
      ball: ball,
      player: player,
      ai: ai,
      court: court,
    );
    for (var i = 0; i < 480; i++) {
      ballController.update(1 / 240);
      physics.update(1 / 240);
      if (ball.hasBounced) return ball.position.copy();
    }
    fail('Shot did not bounce');
  }
}
