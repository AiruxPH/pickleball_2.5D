import 'dart:math' as math;
import 'dart:ui';

import '../models/game_settings.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';
import 'match_command_controller.dart';
import 'match_observation.dart';
import 'pickleball_game.dart';

/// Decision-only controller for the near-side player.
///
/// The agent observes public match state and emits regular [MatchCommand]s.
/// It never changes ball physics, scores, or player positions directly.
class BotAgent {
  BotAgent({
    required this.observe,
    required this.commands,
    required this.difficulty,
  });

  final MatchObserver observe;
  final MatchCommandSink commands;
  final AIDifficulty difficulty;

  double _serveTimer = 0;
  double _thinkTimer = 0;
  double _shotCooldown = 0;
  GameState? _previousState;

  double get reactionTime {
    switch (difficulty) {
      case AIDifficulty.easy:
        return 0.28;
      case AIDifficulty.medium:
        return 0.16;
      case AIDifficulty.hard:
        return 0.08;
    }
  }

  void update(double dt) {
    final observation = observe();
    if (observation.state != _previousState) {
      _previousState = observation.state;
      _serveTimer = 0;
      _thinkTimer = 0;
      _shotCooldown = 0;
      commands.clearAim();
    }

    if (observation.state == GameState.paused ||
        observation.state == GameState.gameOver ||
        observation.state == GameState.pointScored) {
      commands.stopMoving();
      return;
    }

    if (_shotCooldown > 0) _shotCooldown -= dt;

    if (observation.state == GameState.waitingForServe) {
      _updateBeforeServe(observation, dt);
      return;
    }

    _thinkTimer -= dt;
    if (_thinkTimer > 0) return;
    _thinkTimer = reactionTime;
    _updateRally(observation);
  }

  void _updateBeforeServe(MatchObservation observation, double dt) {
    final targetX = observation.serverShouldBeOnRight ? 16.0 : -16.0;
    _moveToward(
      observation,
      targetX,
      observation.nearPlayer.position.z,
    );

    if (!observation.controlledPlayerServing) return;

    _serveTimer += dt;
    final delay = 0.55 + reactionTime;
    if (_serveTimer >= delay) {
      _serveTimer = -double.infinity;
      commands.stopMoving();
      commands.serve();
    }
  }

  void _updateRally(MatchObservation observation) {
    final ball = observation.ball;
    final player = observation.nearPlayer;
    final ballIncoming =
        !ball.lastHitByNearSide && (ball.position.z > 0 || ball.velocity.z > 0);

    if (!ballIncoming) {
      final recoveryX = observation.farPlayer.position.x >= 0 ? -12.0 : 12.0;
      _moveToward(observation, recoveryX, CourtDimensions.playerStartZ);
      commands.clearAim();
      return;
    }

    final landing = _predictLanding(ball);
    final targetX = landing.dx.clamp(
      -CourtDimensions.halfWidth + 6,
      CourtDimensions.halfWidth - 6,
    );
    final targetZ = (landing.dy + 3).clamp(
      CourtDimensions.kitchenDepth + 3,
      CourtDimensions.halfLength - 6,
    );
    _moveToward(observation, targetX.toDouble(), targetZ.toDouble());

    final mustBounce = ball.rallyHitCount < 2 && !ball.hasBounced;
    final distance = dist2D(
      player.position.x,
      player.position.z,
      ball.position.x,
      ball.position.z,
    );
    if (mustBounce ||
        _shotCooldown > 0 ||
        !player.canSwing ||
        distance > 27 ||
        ball.position.y > 40 ||
        ball.position.z < -8) {
      return;
    }

    final openSide = observation.farPlayer.position.x >= 0 ? -0.68 : 0.68;
    commands.aim(Offset(openSide, -1));
    commands.shot(_chooseShot(observation));
    _shotCooldown = 0.48;
  }

  ShotType _chooseShot(MatchObservation observation) {
    if (difficulty == AIDifficulty.hard &&
        observation.ball.position.y > CourtDimensions.netHeight + 5) {
      return ShotType.smash;
    }
    if (difficulty != AIDifficulty.easy &&
        observation.farPlayer.position.z < CourtDimensions.aiStartZ - 5 &&
        observation.nearPlayer.position.z < CourtDimensions.kitchenDepth + 14) {
      return ShotType.drop;
    }
    if (difficulty != AIDifficulty.easy &&
        observation.farPlayer.position.z > -CourtDimensions.kitchenDepth - 12) {
      return ShotType.lob;
    }
    return ShotType.normal;
  }

  Offset _predictLanding(BallObservation ball) {
    var x = ball.position.x;
    var y = ball.position.y;
    var z = ball.position.z;
    var vx = ball.velocity.x;
    var vy = ball.velocity.y;
    var vz = ball.velocity.z;
    const step = 0.025;

    for (var i = 0; i < 180 && y > PhysicsConstants.ballRadius; i++) {
      x += vx * step;
      y += vy * step;
      z += vz * step;
      vy -= PhysicsConstants.gravity * step;
      vx *= 0.999;
      vz *= 0.999;
    }
    return Offset(x, z);
  }

  void _moveToward(
    MatchObservation observation,
    double targetX,
    double targetZ,
  ) {
    final dx = targetX - observation.nearPlayer.position.x;
    final dz = targetZ - observation.nearPlayer.position.z;
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance < 2) {
      commands.stopMoving();
      return;
    }
    commands.move(
      (dx / 18).clamp(-1.0, 1.0).toDouble(),
      (dz / 18).clamp(-1.0, 1.0).toDouble(),
    );
  }
}
