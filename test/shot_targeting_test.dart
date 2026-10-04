import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/ai_controller.dart';
import 'package:pickleball_3d/game/shot_targeting.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  group('Sideline return targeting', () {
    test('right-side contact is redirected toward center or left', () {
      final direction = ShotTargeting.constrainReturnDirection(
        const Offset(0.7, -1),
        18,
      );

      expect(direction.dx, lessThan(0));
      expect(ShotTargeting.constrainReturnTargetX(14, 18), equals(0));
      expect(ShotTargeting.constrainReturnTargetX(-12, 18), equals(-12));
    });

    test('left-side contact is redirected toward center or right', () {
      final direction = ShotTargeting.constrainReturnDirection(
        const Offset(-0.7, -1),
        -18,
      );

      expect(direction.dx, greaterThan(0));
      expect(ShotTargeting.constrainReturnTargetX(-14, -18), equals(0));
      expect(ShotTargeting.constrainReturnTargetX(12, -18), equals(12));
    });
  });

  group('Doubles coverage ownership', () {
    test('near-side ally holds its lane instead of chasing the human lane', () {
      final ball = Pickleball()..position = Vec3(16, 8, 45);
      final human = Player(
        startPosition: Vec3(15, 0, 50),
        isHuman: true,
        assignedRightSide: true,
      );
      final ally = Player(
        startPosition: Vec3(-16, 0, 50),
        isHuman: false,
        isPartner: true,
        assignedRightSide: false,
      );
      final controller = AIController(
        ai: ally,
        ball: ball,
        court: Court(),
        settings: GameSettings(),
        teammate: human,
      );

      expect(controller.shouldCoverIncomingBall(), isFalse);

      ball.position.x = -16;
      expect(controller.shouldCoverIncomingBall(), isTrue);
    });

    test('ally may poach only when clearly closer than its teammate', () {
      final ball = Pickleball()
        ..position = Vec3(15, 8, 35)
        ..isServe = false
        ..rallyHitCount = 1;
      final human = Player(
        startPosition: Vec3(16, 0, 70),
        isHuman: true,
        assignedRightSide: true,
      );
      final ally = Player(
        startPosition: Vec3(5, 0, 35),
        isHuman: false,
        isPartner: true,
        assignedRightSide: false,
      );
      final controller = AIController(
        ai: ally,
        ball: ball,
        court: Court(),
        settings: GameSettings(),
        teammate: human,
      );

      expect(controller.shouldCoverIncomingBall(), isTrue);
    });

    test('ally cannot poach a serve assigned to the diagonal receiver', () {
      final ball = Pickleball()
        ..position = Vec3(15, 8, 35)
        ..isServe = true
        ..rallyHitCount = 0;
      final human = Player(
        startPosition: Vec3(16, 0, 70),
        isHuman: true,
        assignedRightSide: true,
      );
      final ally = Player(
        startPosition: Vec3(5, 0, 35),
        isHuman: false,
        isPartner: true,
        assignedRightSide: false,
      );
      final controller = AIController(
        ai: ally,
        ball: ball,
        court: Court(),
        settings: GameSettings(),
        teammate: human,
      );

      expect(controller.shouldCoverIncomingBall(), isFalse);
    });

    test('near-side ally returns the ball toward the far court', () {
      final settings = GameSettings()..difficulty = AIDifficulty.hard;
      final ball = Pickleball()
        ..position = Vec3(-14, 8, 45)
        ..velocity = Vec3(0, -4, 20)
        ..state = BallState.inFlight
        ..hasBounced = true
        ..rallyHitCount = 3
        ..lastHitByPlayer = false;
      final human = Player(
        startPosition: Vec3(16, 0, 60),
        isHuman: true,
        assignedRightSide: true,
      );
      final ally = Player(
        startPosition: Vec3(-14, 0, 45),
        isHuman: false,
        isPartner: true,
        assignedRightSide: false,
      );
      final controller = AIController(
        ai: ally,
        ball: ball,
        court: Court(),
        settings: settings,
        teammate: human,
      );

      for (var i = 0; i < 20 && ball.velocity.z > 0; i++) {
        controller.update(0.05);
      }

      expect(ball.lastHitByPlayer, isTrue);
      expect(ball.velocity.z, lessThan(0));
    });
  });
}
