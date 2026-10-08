import 'dart:math' as math;
import 'dart:ui';

import '../models/game_settings.dart';
import '../models/player.dart';
import '../models/shot_mechanics.dart';
import '../utils/constants.dart';
import 'match_command_controller.dart';
import 'match_observation.dart';
import 'pickleball_game.dart';

enum BotCourtSide { near, far }

/// Stable traits that make two bots at the same difficulty play differently.
final class BotPersonality {
  const BotPersonality({
    required this.name,
    required this.aggressionAdjustment,
    required this.recoveryDepth,
    required this.aimSpread,
  });

  final String name;
  final double aggressionAdjustment;
  final double recoveryDepth;
  final double aimSpread;

  static const patient = BotPersonality(
    name: 'Counterpuncher',
    aggressionAdjustment: -0.22,
    recoveryDepth: 52,
    aimSpread: 0.08,
  );

  static const balanced = BotPersonality(
    name: 'All Court',
    aggressionAdjustment: 0,
    recoveryDepth: 46,
    aimSpread: 0.06,
  );

  static const aggressive = BotPersonality(
    name: 'Attacker',
    aggressionAdjustment: 0.25,
    recoveryDepth: 35,
    aimSpread: 0.1,
  );
}

/// Decision-only controller for the near-side player.
///
/// The agent observes public match state and emits regular [MatchCommand]s.
/// It never changes ball physics, scores, or player positions directly.
class BotAgent {
  BotAgent({
    required this.observe,
    required this.commands,
    required this.difficulty,
    this.id = 'bot',
    this.side = BotCourtSide.near,
    this.personality = BotPersonality.balanced,
    int randomSeed = 0,
  }) : _random = math.Random(randomSeed);

  final MatchObserver observe;
  final MatchCommandSink commands;
  final AIDifficulty difficulty;
  final String id;
  final BotCourtSide side;
  final BotPersonality personality;
  final math.Random _random;

  double _serveTimer = 0;
  double _thinkTimer = 0;
  double _shotCooldown = 0;
  ShotType _plannedShot = ShotType.normal;
  ShotSpin _plannedSpin = ShotSpin.flat;
  Offset _plannedAim = const Offset(0, -1);
  bool _hasShotPlan = false;
  GameState? _previousState;

  ShotType get plannedShot => _plannedShot;
  ShotSpin get plannedSpin => _plannedSpin;
  Offset get plannedAim => _plannedAim;

  double get aggression {
    final base = switch (difficulty) {
      AIDifficulty.easy => 0.25,
      AIDifficulty.medium => 0.48,
      AIDifficulty.hard => 0.72,
    };
    return (base + personality.aggressionAdjustment).clamp(0.0, 1.0);
  }

  double get reactionTime {
    return 0.12;
  }

  void update(double dt) {
    final observation = observe();
    if (observation.state != _previousState) {
      _previousState = observation.state;
      _serveTimer = 0;
      _thinkTimer = 0;
      _shotCooldown = 0;
      _hasShotPlan = false;
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

    // Paddle contact is a reflex, not a tactical decision. Check it at the
    // fixed simulation rate so a fast ball cannot cross the reachable window
    // between difficulty-dependent thinking ticks.
    _tryReturnBall(observation);

    _thinkTimer -= dt;
    if (_thinkTimer > 0) return;
    _thinkTimer = reactionTime;
    _updateRally(observation);
  }

  void _updateBeforeServe(MatchObservation observation, double dt) {
    final targetX = side == BotCourtSide.near
        ? (observation.serverShouldBeOnRight ? 16.0 : -16.0)
        : (observation.serverShouldBeOnRight ? -16.0 : 16.0);
    final player = _controlledPlayer(observation);
    _moveToward(
      observation,
      targetX,
      _localZ(player.position.z),
    );

    if (!_controlledPlayerServing(observation)) return;

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
    final opponent = _opponentPlayer(observation);
    final ballIncoming = _isBallIncoming(observation);

    if (!ballIncoming) {
      final recoveryX = opponent.position.x >= 0 ? -12.0 : 12.0;
      _moveToward(observation, recoveryX, personality.recoveryDepth);
      _hasShotPlan = false;
      commands.clearAim();
      return;
    }

    final landing = _predictLanding(ball);
    final targetX = landing.dx.clamp(
      -CourtDimensions.halfWidth + 6,
      CourtDimensions.halfWidth - 6,
    );
    final bouncedInOwnKitchen = ball.hasBounced &&
        ball.lastBounceZ >= 0 &&
        ball.lastBounceZ <= CourtDimensions.kitchenDepth;
    const kitchenSafety = Player.footRadius + 1.0;
    final targetZ = (landing.dy + 3).clamp(
      bouncedInOwnKitchen ? 0.0 : CourtDimensions.kitchenDepth + kitchenSafety,
      CourtDimensions.halfLength - 6,
    );
    _moveToward(observation, targetX.toDouble(), targetZ.toDouble());
    _planReturn(observation);

    if (_shotCooldown <= 0) {
      commands.clearAim();
    }
  }

  bool _tryReturnBall(MatchObservation observation) {
    final ball = observation.ball;
    final player = _controlledPlayer(observation);
    final ballIncoming = _isBallIncoming(observation);
    if (!ballIncoming) return false;

    final localBallZ = _localZ(ball.position.z);
    final localPlayerZ = _localZ(player.position.z);
    final localBounceZ = _localZ(ball.lastBounceZ);
    final bouncedInOwnKitchen = ball.hasBounced &&
        localBounceZ >= 0 &&
        localBounceZ <= CourtDimensions.kitchenDepth;
    final mustBounce = ball.mustBounceBeforeHit && !ball.hasBounced;
    final lateral = (ball.position.x - player.position.x).abs();
    final forward = localPlayerZ - localBallZ;
    final insideContactEnvelope = lateral <= 10 &&
        forward >= -5 &&
        forward <= 10 &&
        ball.position.y >= PhysicsConstants.ballRadius &&
        ball.position.y <= CourtDimensions.playerHeight + 8;
    final legalKitchenContact = !player.isInKitchen || bouncedInOwnKitchen;
    final legalVolleyStance =
        ball.hasBounced || player.hasEstablishedOutsideKitchen;
    if (mustBounce ||
        _shotCooldown > 0 ||
        !player.canSwing ||
        !insideContactEnvelope ||
        !legalKitchenContact ||
        !legalVolleyStance) {
      return false;
    }

    if (!_hasShotPlan) _planReturn(observation);
    commands.aim(_plannedAim);
    commands.shot(_plannedShot, spin: _plannedSpin);
    _shotCooldown = 0.48;
    _hasShotPlan = false;
    return true;
  }

  void _planReturn(MatchObservation observation) {
    final opponent = _opponentPlayer(observation);
    _plannedShot = _chooseShot(observation);
    _plannedSpin = _chooseSpin(observation, _plannedShot);
    final coordinatedTargetX = side == BotCourtSide.near
        ? observation.nearSuggestedTargetX
        : observation.farSuggestedTargetX;
    final openDirection = opponent.position.x >= 0 ? -1.0 : 1.0;
    final width = coordinatedTargetX == null
        ? 0.38 + aggression * 0.36
        : coordinatedTargetX / (CourtDimensions.halfWidth * 0.88);
    final difficultySpread = switch (difficulty) {
      AIDifficulty.easy => 1.35,
      AIDifficulty.medium => 0.8,
      AIDifficulty.hard => 0.4,
    };
    final variation = (_random.nextDouble() - 0.5) *
        2 *
        personality.aimSpread *
        difficultySpread;
    final aimX =
        ((coordinatedTargetX == null ? openDirection : 1.0) * width + variation)
            .clamp(-0.82, 0.82);
    _plannedAim = Offset(aimX.toDouble(), -1);
    _hasShotPlan = true;
  }

  ShotType _chooseShot(MatchObservation observation) {
    final player = _controlledPlayer(observation);
    final opponent = _opponentPlayer(observation);
    final playerZ = _localZ(player.position.z);
    final opponentZ = _localZ(opponent.position.z);

    if (aggression >= 0.55 &&
        observation.ball.position.y > CourtDimensions.netHeight + 5) {
      return ShotType.smash;
    }
    if (difficulty != AIDifficulty.easy &&
        opponentZ < CourtDimensions.aiStartZ - 5 &&
        playerZ < CourtDimensions.kitchenDepth + 14) {
      return ShotType.drop;
    }
    if (difficulty != AIDifficulty.easy &&
        opponentZ > -CourtDimensions.kitchenDepth - 12 &&
        aggression < 0.68) {
      return ShotType.lob;
    }
    if (aggression >= 0.68 &&
        observation.ball.position.y > CourtDimensions.netHeight - 4) {
      return ShotType.power;
    }
    return ShotType.normal;
  }

  ShotSpin _chooseSpin(MatchObservation observation, ShotType shot) {
    if (shot != ShotType.normal && shot != ShotType.power) {
      return ShotSpin.flat;
    }
    return switch (difficulty) {
      AIDifficulty.easy => _random.nextDouble() < 0.12
          ? ShotSpin.topspin
          : ShotSpin.flat,
      AIDifficulty.medium => shot == ShotType.power
          ? ShotSpin.topspin
          : (_random.nextDouble() < 0.22
              ? ShotSpin.slice
              : ShotSpin.topspin),
      AIDifficulty.hard => shot == ShotType.power ||
              observation.ball.position.y > CourtDimensions.netHeight + 2
          ? ShotSpin.topspin
          : ShotSpin.slice,
    };
  }

  Offset _predictLanding(BallObservation ball) {
    var x = ball.position.x;
    var y = ball.position.y;
    var z = ball.position.z;
    var vx = ball.velocity.x;
    var vy = ball.velocity.y;
    var vz = ball.velocity.z;
    const step = 1 / 120;

    for (var i = 0; i < 600 && y > PhysicsConstants.ballRadius; i++) {
      vy -= PhysicsConstants.gravity * step;
      final speed = math.sqrt(vx * vx + vy * vy + vz * vz);
      if (speed > 0.1) {
        final drag = (1 - PhysicsConstants.ballDragCoefficient * speed * step)
            .clamp(0.0, 1.0);
        vx *= drag;
        vy *= drag;
        vz *= drag;
      }
      x += vx * step;
      y += vy * step;
      z += vz * step;
    }
    return Offset(x, _localZ(z));
  }

  void _moveToward(
    MatchObservation observation,
    double targetX,
    double targetZ,
  ) {
    final player = _controlledPlayer(observation);
    final dx = targetX - player.position.x;
    final dz = targetZ - _localZ(player.position.z);
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

  PlayerObservation _controlledPlayer(MatchObservation observation) =>
      side == BotCourtSide.near
          ? observation.nearPlayer
          : observation.farPlayer;

  PlayerObservation _opponentPlayer(MatchObservation observation) =>
      side == BotCourtSide.near
          ? observation.farPlayer
          : observation.nearPlayer;

  bool _controlledPlayerServing(MatchObservation observation) =>
      side == BotCourtSide.near
          ? observation.controlledPlayerServing
          : !observation.controlledPlayerServing;

  bool _isBallIncoming(MatchObservation observation) {
    final ball = observation.ball;
    final ownsCoverage = side == BotCourtSide.near
        ? observation.nearPrimaryHasCoverage
        : observation.farPrimaryHasCoverage;
    if (!ownsCoverage) return false;
    final lastHitByControlled = side == BotCourtSide.near
        ? ball.lastHitByNearSide
        : !ball.lastHitByNearSide;
    final vz = _localZ(ball.velocity.z);
    return !lastHitByControlled && vz > 2.0;
  }

  double _localZ(double worldZ) => side == BotCourtSide.near ? worldZ : -worldZ;
}
