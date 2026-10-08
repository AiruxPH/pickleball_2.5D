import 'dart:math' as math;
import 'dart:ui';
import '../../models/pickleball.dart';
import '../../models/player.dart';
import '../../models/shop_items.dart';
import '../../models/ultimate_skill.dart';
import '../../models/shot_mechanics.dart';
import '../../utils/constants.dart';
import '../../utils/game_math.dart';
import 'shot_quality.dart';

final class TrajectorySolution {
  const TrajectorySolution({
    required this.launchVelocity,
    required this.forwardSpeed,
    required this.upSpeed,
    required this.isPowerHit,
  });

  final Vec3 launchVelocity;
  final double forwardSpeed;
  final double upSpeed;
  final bool isPowerHit;
}

/// Solves 3D launch velocity with smart net clearance, court boundary limits,
/// and forgiving arc mechanics so players never suffer cheap unforced errors.
TrajectorySolution solvePlayerShotTrajectory({
  required ShotType shotType,
  required Player player,
  required Pickleball ball,
  required Offset aimDirection,
  required ShotQualityResult quality,
  required PaddleItem paddle,
  required double joystickY,
  required bool isNearSide,
  SwingTimingGrade timingGrade = SwingTimingGrade.good,
}) {
  double forwardSpeed;
  double upSpeed;

  switch (shotType) {
    case ShotType.ultimate:
      final ultType = ball.ultimateType;
      switch (ultType) {
        case UltimateType.thunderbolt:
          forwardSpeed = 245.0;
          upSpeed = 26.0;
          break;
        case UltimateType.ghostPhantom:
          forwardSpeed = 155.0;
          upSpeed = 40.0;
          break;
        case UltimateType.dragonMeteor:
          forwardSpeed = 135.0;
          upSpeed = 55.0;
          break;
        case UltimateType.frostbite:
          forwardSpeed = 175.0;
          upSpeed = 34.0;
          break;
        default:
          forwardSpeed = 185.0;
          upSpeed = 35.0;
          break;
      }
      break;

    case ShotType.power:
      forwardSpeed = 165.0;
      upSpeed = 38.0;
      break;

    case ShotType.lob:
      forwardSpeed = 95.0;
      upSpeed = 68.0;
      break;

    case ShotType.drop:
      forwardSpeed = 82.0;
      upSpeed = 36.0;
      break;

    case ShotType.smash:
      // Overhead smash: fast drive with controlled downward elevation
      forwardSpeed = 210.0;
      upSpeed = 12.0;
      break;

    case ShotType.normal:
      forwardSpeed = 130.0;
      upSpeed = 40.0;
      break;
  }

  // 1. Paddle power attribute (+0% to +12% speed)
  final powerBonus = 1.0 + (paddle.power - 0.50) * 0.25;
  forwardSpeed *= powerBonus;

  // 2. Shot quality scaling (rewards sweet spot, softens stretched reach)
  forwardSpeed *= quality.speedMultiplier;
  upSpeed += quality.liftAssist;

  final timing = timingModifiersFor(timingGrade);
  forwardSpeed *= timing.speedMultiplier;
  upSpeed += timing.liftAssist;

  // 3. Joystick Y depth steering
  if (joystickY < -0.2) {
    // Pushing forward -> drive deeper and flatter
    final forwardPace = (-joystickY).clamp(0.0, 1.0);
    forwardSpeed *= 1.0 + forwardPace * 0.10;
  } else if (joystickY > 0.2) {
    // Pulling back -> higher safety arc, shorter depth
    final pullBack = joystickY.clamp(0.0, 1.0);
    upSpeed += pullBack * 7.0;
    forwardSpeed *= 1.0 - pullBack * 0.12;
  }

  // 4. Deep recovery assistance near the back baseline
  final forwardSign = isNearSide ? -1.0 : 1.0;
  final startZ = isNearSide ? CourtDimensions.playerStartZ : CourtDimensions.aiStartZ;
  final maxZ = isNearSide ? CourtDimensions.playerMaxZ : -CourtDimensions.playerMaxZ;
  final deepRecoveryFactor = isNearSide
      ? ((ball.position.z - startZ) / (maxZ - startZ)).clamp(0.0, 1.0).toDouble()
      : ((startZ - ball.position.z) / (startZ - maxZ)).clamp(0.0, 1.0).toDouble();

  if (deepRecoveryFactor > 0 &&
      shotType != ShotType.smash &&
      shotType != ShotType.ultimate) {
    final forwardBoost = shotType == ShotType.lob
        ? 0.24
        : (shotType == ShotType.power ? 0.18 : 0.15);
    forwardSpeed *= 1.0 + forwardBoost * deepRecoveryFactor;
    final liftBoost = shotType == ShotType.lob
        ? 8.0
        : (shotType == ShotType.power ? 18.0 : 15.0);
    upSpeed += liftBoost * deepRecoveryFactor;
  }

  // 5. Directional unit vectors
  final aimDirX = aimDirection.dx.clamp(-0.85, 0.85);
  final aimDirZ = forwardSign * math.sqrt(math.max(0.05, 1.0 - aimDirX * aimDirX));

  // 6. Net Clearance Guarantee & Court In-Bounds Safety
  final isHeadingToNet = isNearSide ? (ball.position.z > 0 && aimDirZ < 0) : (ball.position.z < 0 && aimDirZ > 0);
  if (isHeadingToNet) {
    final conservativeForwardZ = math.max(1.0, aimDirZ.abs() * forwardSpeed * 0.82);
    final timeToNet = ball.position.z.abs() / conservativeForwardZ;
    final targetNetHeight = CourtDimensions.netHeightAt(ball.position.x) +
        PhysicsConstants.ballRadius +
        4.0;
    final minimumUpSpeed = (targetNetHeight -
                ball.position.y +
                0.5 * PhysicsConstants.gravity * timeToNet * timeToNet) /
            timeToNet +
        2.0;
    upSpeed = math.max(upSpeed, minimumUpSpeed.clamp(0.0, 82.0).toDouble());

    // In-bounds guard: cap forward pace so non-smash returns land legally inside the court
    if (shotType != ShotType.smash && shotType != ShotType.ultimate) {
      final heightAboveGround = math.max(0.0, ball.position.y - PhysicsConstants.ballRadius);
      final discriminant = upSpeed * upSpeed + 2 * PhysicsConstants.gravity * heightAboveGround;
      final flightTime = (upSpeed + math.sqrt(discriminant)) / PhysicsConstants.gravity;
      final targetZ = shotType == ShotType.drop
          ? (forwardSign * 16.0)
          : (forwardSign * 55.0);
      final requiredForward = (ball.position.z - targetZ).abs() / flightTime * 1.12;
      if (deepRecoveryFactor == 0) {
        forwardSpeed = math.min(forwardSpeed, requiredForward);
      }
    }
  }

  final isPowerHit = shotType == ShotType.power ||
      shotType == ShotType.smash ||
      shotType == ShotType.ultimate;

  return TrajectorySolution(
    launchVelocity: Vec3(
      aimDirX * forwardSpeed,
      upSpeed,
      aimDirZ * forwardSpeed,
    ),
    forwardSpeed: forwardSpeed,
    upSpeed: upSpeed,
    isPowerHit: isPowerHit,
  );
}
