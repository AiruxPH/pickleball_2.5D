import '../models/match_foundation.dart';
import '../models/pickleball.dart';
import '../models/player.dart';
import '../utils/constants.dart';

class RallyPhaseClassifier {
  const RallyPhaseClassifier._();

  static RallyPhase classify({
    required Pickleball ball,
    required Iterable<Player> nearTeam,
    required Iterable<Player> farTeam,
  }) {
    if (!ball.isInPlay || ball.isServe || ball.rallyHitCount < 2) {
      return RallyPhase.opening;
    }

    final receiverNear = !ball.lastHitByPlayer;
    final approachingReceiver = receiverNear
        ? ball.velocity.z > 0
        : ball.velocity.z < 0;
    final attackableHeight = ball.position.y >= CourtDimensions.netHeight + 5 &&
        ball.position.y <= 42;
    if (approachingReceiver && !ball.hasBounced && attackableHeight) {
      return RallyPhase.attackable;
    }

    const kitchenStagingMargin = 14.0;
    bool establishedNearKitchen(Iterable<Player> team) => team.any(
          (player) =>
              player.position.z.abs() <=
                  CourtDimensions.kitchenDepth + kitchenStagingMargin &&
              player.position.z.abs() >= CourtDimensions.kitchenDepth - 8.0,
        );
    if (establishedNearKitchen(nearTeam) &&
        establishedNearKitchen(farTeam) &&
        ball.speed <= 155) {
      return RallyPhase.kitchen;
    }

    return RallyPhase.baseline;
  }
}
