import '../../models/pickleball.dart';
import '../../models/player.dart';
import '../../utils/constants.dart';

/// Evaluates match context to adapt a player's shot into the most natural,
/// rewarding stroke without requiring fiddly button-switching.
///
/// Features:
///   1. Auto-Smash: High floaters (Y >= 28.0) hit in front of the player automatically
///      convert standard HIT or POWER into an overhead smash.
///   2. Kitchen Dink Assist: Low balls (Y <= 20.0) near the kitchen line automatically
///      soften into a controlled drop/dink over the net tape instead of blasting deep.
ShotType resolveContextualShotType({
  required ShotType requestedShot,
  required Player player,
  required Pickleball ball,
}) {
  // Never override ultimate or intentional lobs
  if (requestedShot == ShotType.ultimate || requestedShot == ShotType.lob) {
    return requestedShot;
  }

  // 1. High floater -> Overhead Smash
  final isHighFloater = ball.position.y >= 26.0 &&
      ball.position.z < player.position.z + 4.0 &&
      ball.position.z > player.position.z - 16.0;

  if (isHighFloater &&
      (requestedShot == ShotType.normal || requestedShot == ShotType.power)) {
    return ShotType.smash;
  }

  // 2. Low ball at the kitchen -> Soft arching dink (Drop)
  final isNearKitchen = player.position.z.abs() <=
      CourtDimensions.kitchenDepth + 8.0; // Near NVZ line
  final isLowBall = ball.position.y <= 20.0;

  if (isNearKitchen && isLowBall && requestedShot == ShotType.normal) {
    return ShotType.drop;
  }

  return requestedShot;
}
