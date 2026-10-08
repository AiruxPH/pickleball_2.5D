import 'pickleball_game.dart';
import '../utils/constants.dart';

/// Immutable world-space position or velocity exposed to decision systems.
final class ObservedVector {
  const ObservedVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// Read-only player facts relevant to tactical decisions.
final class PlayerObservation {
  const PlayerObservation({
    required this.position,
    required this.velocity,
    required this.canSwing,
    required this.stamina,
    required this.score,
    this.isInKitchen = false,
    this.hasEstablishedOutsideKitchen = true,
  });

  final ObservedVector position;
  final ObservedVector velocity;
  final bool canSwing;
  final double stamina;
  final int score;
  final bool isInKitchen;
  final bool hasEstablishedOutsideKitchen;
}

/// Read-only ball facts relevant to tactical decisions.
final class BallObservation {
  const BallObservation({
    required this.position,
    required this.velocity,
    required this.lastHitByNearSide,
    required this.rallyHitCount,
    required this.hasBounced,
    required this.isInPlay,
    this.mustBounceBeforeHit = false,
    this.lastBounceZ = 0,
  });

  final ObservedVector position;
  final ObservedVector velocity;
  final bool lastHitByNearSide;
  final int rallyHitCount;
  final bool hasBounced;
  final bool isInPlay;
  final bool mustBounceBeforeHit;
  final double lastBounceZ;
}

/// Immutable public state presented to players, bots, replay tools, and tests.
///
/// Every value is copied from the simulation. No mutable model or controller
/// reference crosses this boundary.
final class MatchObservation {
  const MatchObservation({
    required this.state,
    required this.nearPlayer,
    required this.farPlayer,
    required this.ball,
    required this.controlledPlayerServing,
    required this.serverShouldBeOnRight,
    this.nearPrimaryHasCoverage = true,
    this.farPrimaryHasCoverage = true,
    this.nearSuggestedTargetX,
    this.farSuggestedTargetX,
  });

  factory MatchObservation.fromGame(PickleballGame game) {
    final player = game.player;
    final opponent = game.ai;
    final ball = game.ball;
    return MatchObservation(
      state: game.state,
      nearPlayer: PlayerObservation(
        position: ObservedVector(
          player.position.x,
          player.position.y,
          player.position.z,
        ),
        velocity: ObservedVector(
          player.velocity.x,
          player.velocity.y,
          player.velocity.z,
        ),
        canSwing: player.canSwing,
        stamina: player.stamina,
        score: player.score,
        isInKitchen: player.isInKitchen(includeFootMargin: true),
        hasEstablishedOutsideKitchen: player.hasEstablishedOutsideKitchen,
      ),
      farPlayer: PlayerObservation(
        position: ObservedVector(
          opponent.position.x,
          opponent.position.y,
          opponent.position.z,
        ),
        velocity: ObservedVector(
          opponent.velocity.x,
          opponent.velocity.y,
          opponent.velocity.z,
        ),
        canSwing: opponent.canSwing,
        stamina: opponent.stamina,
        score: opponent.score,
        isInKitchen: opponent.isInKitchen(includeFootMargin: true),
        hasEstablishedOutsideKitchen: opponent.hasEstablishedOutsideKitchen,
      ),
      ball: BallObservation(
        position: ObservedVector(
          ball.position.x,
          ball.position.y,
          ball.position.z,
        ),
        velocity: ObservedVector(
          ball.velocity.x,
          ball.velocity.y,
          ball.velocity.z,
        ),
        lastHitByNearSide: ball.lastHitByPlayer,
        rallyHitCount: ball.rallyHitCount,
        hasBounced: ball.hasBounced,
        isInPlay: ball.isInPlay,
        mustBounceBeforeHit: ball.mustBounceBeforeHit,
        lastBounceZ: ball.lastBounceZ,
      ),
      controlledPlayerServing: identical(game.activeServer, game.player),
      serverShouldBeOnRight: game.scoreController.serverShouldBeOnRight,
      nearPrimaryHasCoverage: game.gameMode != GameMode.doubles ||
          identical(game.nearTeamCoverageOwner, game.player),
      farPrimaryHasCoverage: game.gameMode != GameMode.doubles ||
          identical(game.farTeamCoverageOwner, game.ai),
      nearSuggestedTargetX: game.nearTeamSuggestedTargetX,
      farSuggestedTargetX: game.farTeamSuggestedTargetX,
    );
  }

  final GameState state;
  final PlayerObservation nearPlayer;
  final PlayerObservation farPlayer;
  final BallObservation ball;
  final bool controlledPlayerServing;
  final bool serverShouldBeOnRight;
  final bool nearPrimaryHasCoverage;
  final bool farPrimaryHasCoverage;
  final double? nearSuggestedTargetX;
  final double? farSuggestedTargetX;
}

typedef MatchObserver = MatchObservation Function();
