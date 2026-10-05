import 'dart:math' as math;

import '../utils/constants.dart';
import '../utils/game_math.dart';

final class AIShotPlan {
  const AIShotPlan({
    required this.type,
    required this.target,
    required this.launchVelocity,
    required this.predictedNetClearance,
    required this.predictedLanding,
  });

  final ShotType type;
  final Vec3 target;
  final Vec3 launchVelocity;
  final double predictedNetClearance;
  final Vec3 predictedLanding;
}

/// Searches trajectories using the same gravity, drag, and integration order
/// as [BallController]. Only paths that clear the physical ball over the net
/// and land inside the opponent court are returned.
abstract final class AIShotPlanner {
  static const double _dt = 1 / 120;

  static AIShotPlan? plan({
    required Vec3 start,
    required Vec3 target,
    required ShotType type,
    required double preferredHorizontalSpeed,
    required double preferredVerticalSpeed,
  }) {
    final requiredClearance = switch (type) {
      ShotType.drop => 3.5,
      ShotType.lob => 8.0,
      ShotType.smash || ShotType.power => 1.5,
      _ => 2.5,
    };
    final verticalRange = switch (type) {
      ShotType.drop => (14.0, 46.0),
      ShotType.lob => (42.0, 82.0),
      ShotType.smash || ShotType.power => (-4.0, 42.0),
      _ => (20.0, 62.0),
    };
    final horizontalRange = switch (type) {
      ShotType.drop => (45.0, 115.0),
      ShotType.lob => (50.0, 135.0),
      ShotType.smash || ShotType.power => (105.0, 245.0),
      _ => (70.0, 185.0),
    };

    final dx = target.x - start.x;
    final dz = target.z - start.z;
    final horizontalDistance = math.sqrt(dx * dx + dz * dz);
    if (horizontalDistance < 0.001) return null;
    final dirX = dx / horizontalDistance;
    final dirZ = dz / horizontalDistance;

    AIShotPlan? best;
    var bestScore = double.infinity;
    for (var vertical = verticalRange.$1;
        vertical <= verticalRange.$2;
        vertical += 2.0) {
      for (var horizontal = horizontalRange.$1;
          horizontal <= horizontalRange.$2;
          horizontal += 5.0) {
        final launch = Vec3(dirX * horizontal, vertical, dirZ * horizontal);
        final result = _simulate(start, launch);
        if (!result.crossedNet ||
            result.netClearance < requiredClearance ||
            !_landsInOpponentCourt(start.z, result.landing)) {
          continue;
        }

        final landingError = dist2D(
          result.landing.x,
          result.landing.z,
          target.x,
          target.z,
        );
        final speedPenalty =
            (horizontal - preferredHorizontalSpeed).abs() * 0.025 +
                (vertical - preferredVerticalSpeed).abs() * 0.015;
        final score = landingError + speedPenalty;
        if (score < bestScore) {
          bestScore = score;
          best = AIShotPlan(
            type: type,
            target: target.copy(),
            launchVelocity: launch,
            predictedNetClearance: result.netClearance,
            predictedLanding: result.landing,
          );
        }
      }
    }
    return best;
  }

  static _TrajectoryResult _simulate(Vec3 start, Vec3 launch) {
    var x = start.x;
    var y = start.y;
    var z = start.z;
    var vx = launch.x;
    var vy = launch.y;
    var vz = launch.z;
    var crossedNet = false;
    var netClearance = -double.infinity;

    for (var step = 0; step < 600; step++) {
      final previousX = x;
      final previousY = y;
      final previousZ = z;

      vy -= PhysicsConstants.gravity * _dt;
      final speed = math.sqrt(vx * vx + vy * vy + vz * vz);
      if (speed > 0.1) {
        final drag = (1 - PhysicsConstants.ballDragCoefficient * speed * _dt)
            .clamp(0.0, 1.0);
        vx *= drag;
        vy *= drag;
        vz *= drag;
      }
      x += vx * _dt;
      y += vy * _dt;
      z += vz * _dt;

      if (!crossedNet && (previousZ > 0) != (z > 0)) {
        final t = previousZ / (previousZ - z);
        final crossX = previousX + (x - previousX) * t;
        final crossY = previousY + (y - previousY) * t;
        crossedNet = true;
        netClearance = crossY -
            PhysicsConstants.ballRadius -
            CourtDimensions.netHeightAt(crossX);
      }

      if (y <= PhysicsConstants.ballRadius && step > 1) {
        return _TrajectoryResult(
          landing: Vec3(x, PhysicsConstants.ballRadius, z),
          crossedNet: crossedNet,
          netClearance: netClearance,
        );
      }
    }
    return _TrajectoryResult(
      landing: Vec3(x, y, z),
      crossedNet: crossedNet,
      netClearance: netClearance,
    );
  }

  static bool _landsInOpponentCourt(double startZ, Vec3 landing) {
    const margin = 2.5;
    final insideWidth = landing.x.abs() <= CourtDimensions.halfWidth - margin;
    final insideLength = landing.z.abs() <= CourtDimensions.halfLength - margin;
    final crossedToOpponent = startZ < 0 ? landing.z > 0 : landing.z < 0;
    return insideWidth && insideLength && crossedToOpponent;
  }
}

final class _TrajectoryResult {
  const _TrajectoryResult({
    required this.landing,
    required this.crossedNet,
    required this.netClearance,
  });

  final Vec3 landing;
  final bool crossedNet;
  final double netClearance;
}
