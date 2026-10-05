import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/ai_controller.dart';
import 'package:pickleball_3d/game/ai_shot_planner.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AIShotPlanner', () {
    final cases = <(ShotType, double, double, double)>[
      (ShotType.drop, 8, 16, 3.5),
      (ShotType.normal, 10, 55, 2.5),
      (ShotType.lob, 9, 70, 8.0),
      (ShotType.smash, 24, 58, 1.5),
    ];

    for (final shotCase in cases) {
      test('${shotCase.$1.name} clears the net and lands in bounds', () {
        final plan = AIShotPlanner.plan(
          start: Vec3(0, shotCase.$2, -38),
          target: Vec3(10, PhysicsConstants.ballRadius, shotCase.$3),
          type: shotCase.$1,
          preferredHorizontalSpeed: switch (shotCase.$1) {
            ShotType.drop => 62,
            ShotType.lob => 92,
            ShotType.smash => 195,
            _ => 120,
          },
          preferredVerticalSpeed: switch (shotCase.$1) {
            ShotType.drop => 28,
            ShotType.lob => 56,
            ShotType.smash => 28,
            _ => 42,
          },
        );

        expect(plan, isNotNull);
        expect(plan!.predictedNetClearance, greaterThanOrEqualTo(shotCase.$4));
        expect(
            plan.predictedLanding.x.abs(), lessThan(CourtDimensions.halfWidth));
        expect(plan.predictedLanding.z,
            inInclusiveRange(0, CourtDimensions.halfLength));
      });
    }
  });

  test('far-side bot waits until the incoming ball reaches paddle range', () {
    final ai = Player(
      startPosition: Vec3(0, 0, -40),
      isHuman: false,
      isNearSide: false,
    );
    final ball = Pickleball()
      ..position = Vec3(0, 12, -20)
      ..velocity = Vec3(0, -3, -40)
      ..hasBounced = true
      ..rallyHitCount = 3
      ..state = BallState.inFlight;
    final controller = AIController(
      ai: ai,
      ball: ball,
      court: Court(),
      settings: GameSettings(),
    );

    expect(controller.canContactBall(), isFalse);
    ball.position.z = -31;
    expect(controller.canContactBall(), isTrue);
    ball.position.z = -47;
    expect(controller.canContactBall(), isFalse);
  });
}
