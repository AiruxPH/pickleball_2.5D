import 'dart:math' as math;
import 'dart:ui';

import '../models/game_settings.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';
import 'match_command_controller.dart';
import 'pickleball_game.dart';

/// Decision-only controller for the near-side player.
///
/// The agent observes public match state and emits regular [MatchCommand]s.
/// It never changes ball physics, scores, or player positions directly.
class BotAgent {
  BotAgent({
    required this.game,
    required this.commands,
    required this.difficulty,
  });

  final PickleballGame game;
  final MatchCommandController commands;
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
    if (game.state != _previousState) {
      _previousState = game.state;
      _serveTimer = 0;
      _thinkTimer = 0;
      _shotCooldown = 0;
      commands.clearAim();
    }

    if (game.state == GameState.paused ||
        game.state == GameState.gameOver ||
        game.state == GameState.pointScored) {
      commands.stopMoving();
      return;
    }

    if (_shotCooldown > 0) _shotCooldown -= dt;

    if (game.state == GameState.waitingForServe) {
      _updateBeforeServe(dt);
      return;
    }

    _thinkTimer -= dt;
    if (_thinkTimer > 0) return;
    _thinkTimer = reactionTime;
    _updateRally();
  }

  void _updateBeforeServe(double dt) {
    final serverOnRight = game.scoreController.serverShouldBeOnRight;
    final targetX = serverOnRight ? 16.0 : -16.0;
    _moveToward(targetX, game.player.position.z);

    if (!game.isHumanServing) return;

    _serveTimer += dt;
    final delay = 0.55 + reactionTime;
    if (_serveTimer >= delay) {
      _serveTimer = -double.infinity;
      commands.stopMoving();
      commands.serve();
    }
  }

  void _updateRally() {
    final ball = game.ball;
    final player = game.player;
    final ballIncoming = !ball.lastHitByPlayer &&
        (ball.position.z > 0 || ball.velocity.z > 0);

    if (!ballIncoming) {
      final recoveryX = game.ai.position.x >= 0 ? -12.0 : 12.0;
      _moveToward(recoveryX, CourtDimensions.playerStartZ);
      commands.clearAim();
      return;
    }

    final landing = _predictLanding();
    final targetX = landing.dx.clamp(
      -CourtDimensions.halfWidth + 6,
      CourtDimensions.halfWidth - 6,
    );
    final targetZ = (landing.dy + 3).clamp(
      CourtDimensions.kitchenDepth + 3,
      CourtDimensions.halfLength - 6,
    );
    _moveToward(targetX.toDouble(), targetZ.toDouble());

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

    final openSide = game.ai.position.x >= 0 ? -0.68 : 0.68;
    commands.aim(Offset(openSide, -1));
    commands.shot(_chooseShot());
    _shotCooldown = 0.48;
  }

  ShotType _chooseShot() {
    if (difficulty == AIDifficulty.hard && game.ball.position.y > 18) {
      return ShotType.power;
    }
    if (difficulty != AIDifficulty.easy &&
        game.ai.position.z < CourtDimensions.aiStartZ - 5 &&
        game.player.position.z < CourtDimensions.playerStartZ) {
      return ShotType.drop;
    }
    if (difficulty == AIDifficulty.hard && game.ai.position.z > -38) {
      return ShotType.lob;
    }
    return ShotType.normal;
  }

  Offset _predictLanding() {
    final ball = game.ball;
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

  void _moveToward(double targetX, double targetZ) {
    final dx = targetX - game.player.position.x;
    final dz = targetZ - game.player.position.z;
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
