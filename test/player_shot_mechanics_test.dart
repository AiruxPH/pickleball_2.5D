import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/models/shop_items.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';
import 'package:pickleball_3d/game/shot/contextual_shot_type.dart';
import 'package:pickleball_3d/game/shot/contact_timing_offset.dart';
import 'package:pickleball_3d/game/shot/shot_quality.dart';
import 'package:pickleball_3d/game/shot/player_aim_calculator.dart';
import 'package:pickleball_3d/game/shot/player_shot_trajectory_solver.dart';

void main() {
  group('Contextual Shot Type Adaptation', () {
    test('High floater adapts normal and power hits to smash', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      );
      final ball = Pickleball()
        ..position = Vec3(0, 32, 42); // High floater in front of player

      final adaptedNormal = resolveContextualShotType(
        requestedShot: ShotType.normal,
        player: player,
        ball: ball,
      );
      final adaptedPower = resolveContextualShotType(
        requestedShot: ShotType.power,
        player: player,
        ball: ball,
      );

      expect(adaptedNormal, equals(ShotType.smash));
      expect(adaptedPower, equals(ShotType.smash));
    });

    test('Low ball near the kitchen adapts normal hit to drop/dink', () {
      final player = Player(
        startPosition: Vec3(0, 0, 30), // Near NVZ line (depth is 28)
        isHuman: true,
        isNearSide: true,
      );
      final ball = Pickleball()
        ..position = Vec3(0, 14, 29); // Low ball

      final adapted = resolveContextualShotType(
        requestedShot: ShotType.normal,
        player: player,
        ball: ball,
      );

      expect(adapted, equals(ShotType.drop));
    });

    test('Intentional lob and ultimate are preserved without override', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      );
      final ball = Pickleball()..position = Vec3(0, 32, 42);

      final lob = resolveContextualShotType(
        requestedShot: ShotType.lob,
        player: player,
        ball: ball,
      );
      final ultimate = resolveContextualShotType(
        requestedShot: ShotType.ultimate,
        player: player,
        ball: ball,
      );

      expect(lob, equals(ShotType.lob));
      expect(ultimate, equals(ShotType.ultimate));
    });
  });

  group('Contact Timing Offset', () {
    test('Forehand early contact deflects cross-court (negative dx)', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      )..isForehand = true;

      // Early contact: ball is further forward toward net than ideal
      final ball = Pickleball()..position = Vec3(4, 18, 40);

      final offsetDx = calculateContactTimingOffset(
        player: player,
        ball: ball,
        isNearSide: true,
      );

      expect(offsetDx, lessThan(0.0)); // Pulls cross-court to the left
    });

    test('Forehand late contact deflects down-the-line (positive dx)', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      )..isForehand = true;

      // Late contact: ball is deeper/behind ideal contact
      final ball = Pickleball()..position = Vec3(4, 18, 48);

      final offsetDx = calculateContactTimingOffset(
        player: player,
        ball: ball,
        isNearSide: true,
      );

      expect(offsetDx, greaterThan(0.0)); // Pushes down-the-line to the right
    });
  });

  group('Player Aim Calculator', () {
    test('Synthesizes joystick steering with timing offset', () {
      final aim = calculatePlayerAimDirection(
        swipeDirection: null,
        joystickX: 0.5,
        joystickY: 0.0,
        timingOffsetDx: 0.1,
        contactX: 0.0,
        isNearSide: true,
      );

      expect(aim.dx, greaterThan(0.0));
      expect(aim.dy, lessThan(0.0)); // Near side returns forward toward -Z
    });

    test('Safeguards wide returns near sideline toward court center', () {
      final wideAim = calculatePlayerAimDirection(
        swipeDirection: null,
        joystickX: 0.8, // Holding right while struck near right sideline
        joystickY: 0.0,
        timingOffsetDx: 0.0,
        contactX: CourtDimensions.halfWidth * 0.7,
        isNearSide: true,
      );

      // Must be constrained inward (negative dx)
      expect(wideAim.dx, lessThan(0.0));
    });
  });

  group('Shot Quality and Proximity', () {
    test('Sweet spot contact awards high quality and sweet-spot flag', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      );
      final ball = Pickleball()..position = Vec3(2, 18, 48);

      final result = calculateShotQuality(
        player: player,
        ball: ball,
        hitRadius: 30.0,
      );

      expect(result.quality, greaterThanOrEqualTo(0.85));
      expect(result.isSweetSpot, isTrue);
      expect(result.speedMultiplier, greaterThan(1.0));
    });

    test('Stretched reach contact softens speed and adds safety lift', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      );
      // Stretched contact near the edge of reach (dist = 28)
      final ball = Pickleball()..position = Vec3(20, 18, 68);

      final result = calculateShotQuality(
        player: player,
        ball: ball,
        hitRadius: 30.0,
      );

      expect(result.quality, lessThan(0.80));
      expect(result.isSweetSpot, isFalse);
      expect(result.speedMultiplier, lessThan(1.0));
      expect(result.liftAssist, greaterThan(0.0));
    });
  });

  group('Player Shot Trajectory Solver', () {
    test('Guarantees upward lift to safely clear net tape on low contact', () {
      final player = Player(
        startPosition: Vec3(0, 0, 48),
        isHuman: true,
        isNearSide: true,
      );
      final ball = Pickleball()..position = Vec3(0, 6, 44); // Very low ball
      final paddle = getPaddleById('classic_wood');
      const quality = ShotQualityResult(
        quality: 0.9,
        isSweetSpot: true,
        speedMultiplier: 1.0,
        liftAssist: 0.0,
      );

      final solution = solvePlayerShotTrajectory(
        shotType: ShotType.normal,
        player: player,
        ball: ball,
        aimDirection: const Offset(0, -1),
        quality: quality,
        paddle: paddle,
        joystickY: 0.0,
        isNearSide: true,
      );

      // Must have positive vertical velocity well above baseline to clear the net
      expect(solution.launchVelocity.y, greaterThan(25.0));
      expect(solution.launchVelocity.z, lessThan(0.0)); // Traveling toward opponent
    });
  });
}
