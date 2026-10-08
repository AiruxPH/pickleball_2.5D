import 'dart:math' as math;
import '../models/player.dart';
import '../models/pickleball.dart';
import '../models/court.dart';
import '../models/game_settings.dart';
import '../models/shot_mechanics.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';
import 'ai_shot_planner.dart';
import 'shot_targeting.dart';

/// ─────────────────────────────────────────────────────────────
/// AIController — State-machine based AI opponent
///
/// States: IDLE → POSITION → APPROACH → SWING → RECOVER
///
/// Difficulty affects: speed, reaction time, accuracy, error rate,
/// and tactical shot selection (smashes, dinks, drives).
///
/// In Training / Practice Mode:
///   AI is locked to an ultra-hard preset with:
///   • 145 court speed
///   • 0.02s reaction time
///   • 0.0 unforced error rate
///   • Ballistic trajectory anticipation
///   • Drill-specific tactical placement
/// ─────────────────────────────────────────────────────────────

enum AIState { idle, positioning, approach, swing, recover }

class AIController {
  final Player ai;
  final Pickleball ball;
  final Court court;
  final GameSettings settings;
  final AIDifficulty? difficultyOverride;
  final bool isPracticeMode;
  final String? drillType;
  final Player? humanPlayer;
  final Player? teammate;
  final bool Function(Player player)? hasCoverageClaim;
  final double? Function()? preferredTargetX;
  final void Function(bool isPower)? onHit;
  final double paddleSpin;

  AIState _state = AIState.idle;
  double _reactionTimer = 0;
  Vec3 _targetPosition = Vec3(0, 0, CourtDimensions.aiStartZ);
  bool _hasPredictedTarget = false;
  int _observedBounceCount = 0;
  bool _ballBouncedThisTick = false;
  double _teamSideTravelTimer = 0;
  AIShotPlan? lastShotPlan;

  static const double contactRadiusX = 10.0;
  static const double contactReachForward = 10.0;
  static const double contactReachBack = 5.0;
  static const double maximumContactHeight = CourtDimensions.playerHeight + 8.0;
  static const double minimumTeamSideTravelTime = 0.12;

  final math.Random _rng = math.Random();

  AIController({
    required this.ai,
    required this.ball,
    required this.court,
    required this.settings,
    this.difficultyOverride,
    this.isPracticeMode = false,
    this.drillType,
    this.humanPlayer,
    this.teammate,
    this.hasCoverageClaim,
    this.preferredTargetX,
    this.onHit,
    this.paddleSpin = 0.5,
  });

  /// Active difficulty for this AI instance (respects match override)
  AIDifficulty get difficulty => difficultyOverride ?? settings.difficulty;

  // Dynamic difficulty getters:
  double get effectiveSpeed {
    if (isPracticeMode) return 145.0;
    switch (difficulty) {
      case AIDifficulty.easy:
        return 90.0;
      case AIDifficulty.medium:
        return 100.0;
      case AIDifficulty.hard:
        return 130.0;
    }
  }

  double get effectiveReactionTime {
    return 0.12;
  }

  double get effectiveAccuracy {
    if (isPracticeMode) return 0.98;
    switch (difficulty) {
      case AIDifficulty.easy:
        return 0.65;
      case AIDifficulty.medium:
        return 0.82;
      case AIDifficulty.hard:
        return 0.95;
    }
  }

  double get effectiveErrorChance {
    if (isPracticeMode) return 0.0;
    switch (difficulty) {
      case AIDifficulty.easy:
        return 0.15;
      case AIDifficulty.medium:
        return 0.07;
      case AIDifficulty.hard:
        return 0.02;
    }
  }

  /// Max lateral error in world units when targeting a shot (lower = more accurate).
  double get _shotAimError {
    return (1.0 - effectiveAccuracy) * 35.0;
  }

  void update(double dt) {
    _ballBouncedThisTick = ball.bounceCount != _observedBounceCount;
    _observedBounceCount = ball.bounceCount;
    // In practice mode, AI has infinite stamina and never tires
    if (isPracticeMode && !ai.isPartner) {
      ai.stamina = StaminaConstants.maxStamina;
    }

    // Only act when ball is on this player's side or coming toward it
    final isPartner = ai.isPartner;
    final opponentHitBall =
        isPartner ? !ball.lastHitByPlayer : ball.lastHitByPlayer;
    final movingTowardTeam =
        isPartner ? ball.velocity.z > 2.0 : ball.velocity.z < -2.0;
    final arrivingOnTeamSide = opponentHitBall && movingTowardTeam;
    final ballComing = arrivingOnTeamSide && shouldCoverIncomingBall();
    final ballOnOwnHalf = isPartner ? ball.position.z > 0 : ball.position.z < 0;
    if (ballComing && ballOnOwnHalf) {
      _teamSideTravelTimer += dt;
    } else {
      _teamSideTravelTimer = 0;
    }

    // Release a teammate-owned ball immediately instead of crossing lanes.
    if (arrivingOnTeamSide && !ballComing && _state != AIState.idle) {
      _state = AIState.idle;
      _hasPredictedTarget = false;
      _reactionTimer = 0;
    }

    switch (_state) {
      case AIState.idle:
        _updateIdle(dt, ballComing);
        break;
      case AIState.positioning:
        _updatePositioning(dt, ballComing);
        break;
      case AIState.approach:
        _updateApproach(dt);
        break;
      case AIState.swing:
        _updateSwing(dt);
        break;
      case AIState.recover:
        _updateRecover(dt);
        break;
    }

    // Apply velocity and clamp
    ai.position.x += ai.velocity.x * dt;
    ai.position.z += ai.velocity.z * dt;
    ai.clampToCourt();

    // Regenerate stamina
    ai.regenStamina(dt);

    // Update AI animation
    _updateAnimation(dt);
  }

  /// Keeps doubles players in their assigned lane, with a limited poach when
  /// they are clearly closer than their teammate. Singles always owns the ball.
  bool shouldCoverIncomingBall() {
    final partner = teammate;
    if (partner == null) return true;
    final claim = hasCoverageClaim;
    if (claim != null) return claim(ai);

    final homeX = ai.assignedRightSide
        ? (ai.isPartner ? 16.0 : -16.0)
        : (ai.isPartner ? -16.0 : 16.0);
    final ballX = ball.position.x;
    final assignedLane = ballX * homeX >= 0;

    // The serve must be returned by the designated diagonal receiver. Normal
    // rally poaching is allowed only after that required return.
    if (ball.isServe || ball.rallyHitCount == 0) {
      return assignedLane;
    }

    final ownDistance = dist2D(
      ai.position.x,
      ai.position.z,
      ball.position.x,
      ball.position.z,
    );
    final teammateDistance = dist2D(
      partner.position.x,
      partner.position.z,
      ball.position.x,
      ball.position.z,
    );

    if (ballX.abs() < 4.0) {
      return ownDistance <= teammateDistance;
    }

    if (assignedLane) {
      return ownDistance <= teammateDistance + 12.0;
    }
    return ownDistance + 12.0 < teammateDistance;
  }

  /// Clears rally-specific intent so an approach from the previous point does
  /// not carry into the next serve formation.
  void resetForRally() {
    _state = AIState.idle;
    _reactionTimer = 0;
    _hasPredictedTarget = false;
    _observedBounceCount = ball.bounceCount;
    _ballBouncedThisTick = false;
    _teamSideTravelTimer = 0;
    lastShotPlan = null;
    ai.velocity
      ..x = 0
      ..y = 0
      ..z = 0;
  }

  // ── Idle: wait for reaction time ───────────────────────────────
  void _updateIdle(double dt, bool ballComing) {
    final defaultZ = ai.isPartner
        ? CourtDimensions.playerStartZ * 0.7
        : CourtDimensions.aiStartZ * 0.7;
    final defaultX = ai.assignedRightSide
        ? (ai.isPartner ? 16.0 : -16.0)
        : (ai.isPartner ? -16.0 : 16.0);

    if (!ballComing) {
      // Ball on other side — recover to default position
      _moveToward(Vec3(defaultX, 0, defaultZ), dt, effectiveSpeed * 0.65);
      return;
    }

    _reactionTimer += dt;
    final reactionDelay =
        effectiveReactionTime / (ai.speedMultiplier.clamp(0.2, 1.0));
    if (_reactionTimer >= reactionDelay) {
      _reactionTimer = 0;
      _hasPredictedTarget = false;
      _state = AIState.positioning;
    }
  }

  // ── Positioning: predict where ball will land ──────────────────
  void _updatePositioning(double dt, bool ballComing) {
    if (!ballComing) {
      _state = AIState.idle;
      return;
    }

    if (!_hasPredictedTarget) {
      _predictBallLanding();
      _hasPredictedTarget = true;
    }

    final distToTarget = dist2D(
      ai.position.x,
      ai.position.z,
      _targetPosition.x,
      _targetPosition.z,
    );

    if (distToTarget < 18) {
      _state = AIState.approach;
    } else {
      _moveToward(_targetPosition, dt, effectiveSpeed);
    }
  }

  // ── Approach: close in on ball ─────────────────────────────────
  void _updateApproach(double dt) {
    // The receiving side must let the serve bounce, and the serving side must
    // also let the return bounce. Normal rally balls may be volleyed.
    final mustWaitBounce = ball.mustBounceBeforeHit && !ball.hasBounced;
    final mayEnterKitchen = _ballBouncedInOwnKitchen;

    // Movement target during approach:
    // Head toward predicted landing spot while ball is in flight, then track bounced ball directly
    final targetX = ball.hasBounced
        ? ball.position.x
        : lerp(_targetPosition.x, ball.position.x, 0.35);

    final targetZ = ball.hasBounced
        ? (ai.isPartner ? ball.position.z + 3.0 : ball.position.z - 3.0)
        : _targetPosition.z;

    // Keep the bot clear of the NVZ unless this ball bounced in its own NVZ.
    // A bounce elsewhere still permits a groundstroke, but not an unnecessary
    // step onto the kitchen or its boundary line.
    const kitchenMargin = Player.footRadius + 1.0;
    final clampedZ = mayEnterKitchen
        ? targetZ
        : (ai.isPartner
            ? math.max(
                targetZ,
                CourtDimensions.kitchenDepth + kitchenMargin,
              )
            : math.min(
                targetZ,
                -CourtDimensions.kitchenDepth - kitchenMargin,
              ));

    final approachSpeed = isPracticeMode ? 165.0 : effectiveSpeed * 1.15;
    _moveToward(Vec3(targetX, 0, clampedZ), dt, approachSpeed);

    // Two-bounce rule check
    if (mustWaitBounce) return;
    if (_ballBouncedThisTick) return;
    if (!ball.canBeHitAfterBounce) return;
    if (!_openingBounceHasTravelled) return;
    if (_teamSideTravelTimer < minimumTeamSideTravelTime) return;

    // Never strike while touching the NVZ unless the current ball bounced
    // there. For a volley, both feet must additionally be established outside.
    if (ai.isInKitchen(includeFootMargin: true) && !mayEnterKitchen) {
      return;
    }
    if (!ball.hasBounced && !ai.hasEstablishedOutsideKitchen) {
      return;
    }

    if (canContactBall() && ai.canSwing) {
      _state = AIState.swing;
    }

    // Ball went past AI
    final passedBaseline = ai.isPartner
        ? ball.position.z > CourtDimensions.halfLength + 5
        : ball.position.z < -CourtDimensions.halfLength - 5;
    if (passedBaseline) {
      _state = AIState.recover;
    }
  }

  bool canContactBall() {
    final lateral = (ball.position.x - ai.position.x).abs();
    final forward = ai.isPartner
        ? ai.position.z - ball.position.z
        : ball.position.z - ai.position.z;
    final movingTowardPlayer =
        ai.isPartner ? ball.velocity.z > 0 : ball.velocity.z < 0;
    return movingTowardPlayer &&
        lateral <= contactRadiusX &&
        forward >= -contactReachBack &&
        forward <= contactReachForward &&
        ball.position.y >= PhysicsConstants.ballRadius &&
        ball.position.y <= maximumContactHeight;
  }

  // ── Swing: hit the ball with tactical shot selection ────────────
  void _updateSwing(double dt) {
    if (!ai.canSwing) {
      return; // wait until swing cooldown finishes, do not abort
    }

    if (_ballBouncedThisTick ||
        !ball.canBeHitAfterBounce ||
        !_openingBounceHasTravelled ||
        _teamSideTravelTimer < minimumTeamSideTravelTime ||
        !canContactBall()) {
      _state = AIState.approach;
      return;
    }

    final mayEnterKitchen = _ballBouncedInOwnKitchen;

    // The bot may only strike from the NVZ when this ball bounced in the NVZ.
    if (ai.isInKitchen(includeFootMargin: true) && !mayEnterKitchen) {
      _state = AIState.approach;
      return;
    }

    // Kitchen check: Cannot volley before establishing both feet outside.
    if (!ball.hasBounced) {
      if (!ai.hasEstablishedOutsideKitchen) {
        _state = AIState.approach;
        return;
      }
      // Arm AI kitchen momentum flag on legal volley
      ai.kitchenMomentumFlag = true;
    }

    // Two-bounce rule check: must not hit before bounce on serve / return
    if (ball.mustBounceBeforeHit && !ball.hasBounced) {
      _state = AIState.approach;
      return;
    }

    final isPartner = ai.isPartner;

    ShotType chosenShot = ShotType.normal;
    double forwardPower = PhysicsConstants.normalHitPower;
    double upPower = 40.0;
    double targetZ = isPartner ? -52.0 : 52.0;
    double aimX = 0;

    final isUnforcedError = _rng.nextDouble() < effectiveErrorChance;
    final isServeReturn = ball.rallyHitCount < 2;
    final opponentAtKitchen = humanPlayer != null &&
        humanPlayer!.position.z <= CourtDimensions.kitchenDepth + 12.0;
    final opponentPinnedDeep = humanPlayer != null &&
        humanPlayer!.position.z >= CourtDimensions.playerStartZ + 6.0;
    final aiAtKitchenLine = ai.isPartner
        ? ai.position.z <= CourtDimensions.kitchenDepth + 12.0
        : ai.position.z >= -CourtDimensions.kitchenDepth - 12.0;

    if (isPracticeMode && !isPartner) {
      // ── ULTRA-HARD TRAINING AI TACTICS ──────────────────────────
      if (drillType == 'smash_drill') {
        chosenShot = ShotType.lob;
        forwardPower = PhysicsConstants.lobHitPower * 0.92;
        upPower = 52.0;
        aimX = (_rng.nextDouble() - 0.5) * CourtDimensions.width * 0.6;
        targetZ = 50.0;
      } else if (drillType == 'dink_drill') {
        chosenShot = ShotType.drop;
        forwardPower =
            PhysicsConstants.dropHitPower * (0.95 + _rng.nextDouble() * 0.10);
        upPower = 36.0;
        aimX = (_rng.nextDouble() - 0.5) * CourtDimensions.width * 0.7;
        targetZ = 16.0;
      } else if (drillType == 'footwork_drill') {
        final playerOnLeft =
            humanPlayer != null ? humanPlayer!.position.x < 0 : false;
        aimX = playerOnLeft
            ? (CourtDimensions.halfWidth * 0.85)
            : (-CourtDimensions.halfWidth * 0.85);
        chosenShot = ShotType.normal;
        forwardPower = PhysicsConstants.normalHitPower * 1.18;
        upPower = 40.0;
        targetZ = 55.0;
      } else {
        if (ball.position.y > 18 && ai.position.z > -48.0) {
          chosenShot = ShotType.smash;
          forwardPower = PhysicsConstants.powerHitPower * 1.15;
          upPower = 28.0;
          targetZ = 48.0;
          if (humanPlayer != null && humanPlayer!.position.x < 0) {
            aimX = CourtDimensions.halfWidth * 0.82;
          } else {
            aimX = -CourtDimensions.halfWidth * 0.82;
          }
        } else if (humanPlayer != null &&
            humanPlayer!.position.z > CourtDimensions.playerStartZ + 6 &&
            ai.position.z > -38.0) {
          chosenShot = ShotType.drop;
          forwardPower = PhysicsConstants.dropHitPower * 1.05;
          upPower = 36.0;
          aimX = (humanPlayer!.position.x < 0) ? 14.0 : -14.0;
          targetZ = 16.0;
        } else {
          chosenShot = ShotType.normal;
          forwardPower = PhysicsConstants.normalHitPower * 1.16;
          upPower = 40.0;
          targetZ = 55.0;
          if (humanPlayer != null) {
            final oppX = humanPlayer!.position.x <= 0
                ? CourtDimensions.halfWidth * 0.82
                : -CourtDimensions.halfWidth * 0.82;
            aimX = oppX + (_rng.nextDouble() - 0.5) * 4.0;
          } else {
            aimX =
                (_rng.nextBool() ? 1 : -1) * CourtDimensions.halfWidth * 0.80;
          }
        }
      }
    } else if (difficulty == AIDifficulty.hard) {
      // ── HARD: TOURNAMENT PRO TACTICS ─────────────────────────────
      if (isServeReturn) {
        // Return of serve: deep aggressive drive to baseline
        chosenShot = ShotType.normal;
        forwardPower = PhysicsConstants.normalHitPower * 1.15;
        upPower = 40.0;
        targetZ = 55.0;
        aimX = (humanPlayer != null && humanPlayer!.position.x <= 0)
            ? CourtDimensions.halfWidth * 0.80
            : -CourtDimensions.halfWidth * 0.80;
        aimX += (_rng.nextDouble() - 0.5) * 3.0;
      } else if (ball.position.y > 17.0) {
        // Overhead Smash on high ball
        chosenShot = ShotType.smash;
        forwardPower = PhysicsConstants.powerHitPower * 1.15;
        upPower = 28.0;
        targetZ = 46.0;
        aimX = (humanPlayer != null && humanPlayer!.position.x < 0)
            ? CourtDimensions.halfWidth * 0.82
            : -CourtDimensions.halfWidth * 0.82;
        ai.useStamina(StaminaConstants.powerShotCost * 0.5);
      } else if (opponentAtKitchen && aiAtKitchenLine) {
        chosenShot = ShotType.lob;
        forwardPower = PhysicsConstants.lobHitPower;
        upPower = PhysicsConstants.lobUpPower;
        targetZ = CourtDimensions.halfLength - 8.0;
        aimX = humanPlayer!.position.x < 0 ? 18.0 : -18.0;
        ai.useStamina(StaminaConstants.lobShotCost * 0.5);
      } else if (opponentPinnedDeep && aiAtKitchenLine) {
        // Human is pinned deep: punish with kitchen drop shot (only from near kitchen)
        chosenShot = ShotType.drop;
        forwardPower = PhysicsConstants.dropHitPower * 1.05;
        upPower = 36.0;
        aimX = (humanPlayer!.position.x < 0) ? 14.0 : -14.0;
        targetZ = 16.0;
        ai.useStamina(StaminaConstants.dropShotCost * 0.5);
      } else if (isUnforcedError) {
        // Authentic unforced error on baseline exchange
        chosenShot = ShotType.normal;
        if (_rng.nextBool()) {
          forwardPower = PhysicsConstants.normalHitPower * 1.35;
          upPower = 44.0;
          targetZ = isPartner ? -75.0 : 75.0;
          aimX = (_rng.nextDouble() - 0.5) * CourtDimensions.halfWidth * 0.6;
        } else {
          forwardPower = PhysicsConstants.normalHitPower * 1.05;
          upPower = 40.0;
          targetZ = isPartner ? -50.0 : 50.0;
          aimX = (_rng.nextBool() ? 1 : -1) * (CourtDimensions.halfWidth + 4.0);
        }
      } else {
        // Fast flat drive targeting deep corners
        chosenShot = ShotType.normal;
        forwardPower = PhysicsConstants.normalHitPower * 1.12;
        upPower = 39.0;
        targetZ = 54.0;
        if (humanPlayer != null) {
          final oppSideX = humanPlayer!.position.x <= 0
              ? CourtDimensions.halfWidth * 0.80
              : -CourtDimensions.halfWidth * 0.80;
          aimX = oppSideX + (_rng.nextDouble() - 0.5) * 4.0;
        } else {
          aimX = (_rng.nextBool() ? 1 : -1) * CourtDimensions.halfWidth * 0.78;
        }
      }
    } else if (difficulty == AIDifficulty.medium) {
      // ── MEDIUM: BALANCED CLUB PLAYER ─────────────────────────────
      if (isServeReturn) {
        chosenShot = ShotType.normal;
        forwardPower = PhysicsConstants.normalHitPower * 1.05;
        upPower = 41.0;
        targetZ = 52.0;
        aimX = (humanPlayer != null && humanPlayer!.position.x <= 0)
            ? CourtDimensions.halfWidth * 0.60
            : -CourtDimensions.halfWidth * 0.60;
      } else {
        final roll = _rng.nextDouble();
        if (ball.position.y > 19.0 &&
            roll < 0.35 &&
            ai.stamina >= StaminaConstants.powerShotCost) {
          chosenShot = ShotType.smash;
          ai.useStamina(StaminaConstants.powerShotCost);
          forwardPower = PhysicsConstants.powerHitPower;
          upPower = 38.0;
          targetZ = 50.0;
          aimX = (humanPlayer != null && humanPlayer!.position.x < 0)
              ? CourtDimensions.halfWidth * 0.65
              : -CourtDimensions.halfWidth * 0.65;
        } else if (opponentAtKitchen && aiAtKitchenLine && roll < 0.35) {
          chosenShot = ShotType.lob;
          ai.useStamina(StaminaConstants.lobShotCost);
          forwardPower = PhysicsConstants.lobHitPower;
          upPower = PhysicsConstants.lobUpPower;
          targetZ = CourtDimensions.halfLength - 10.0;
          aimX = humanPlayer!.position.x < 0 ? 14.0 : -14.0;
        } else if (opponentPinnedDeep &&
            aiAtKitchenLine &&
            roll < 0.35 &&
            ai.stamina >= StaminaConstants.dropShotCost) {
          chosenShot = ShotType.drop;
          ai.useStamina(StaminaConstants.dropShotCost);
          forwardPower = PhysicsConstants.dropHitPower * 1.05;
          upPower = 36.0;
          targetZ = 16.0;
          aimX = (_rng.nextDouble() - 0.5) * 16.0;
        } else if (isUnforcedError) {
          chosenShot = ShotType.normal;
          forwardPower = PhysicsConstants.normalHitPower * 1.25;
          upPower = 43.0;
          targetZ = isPartner ? -75.0 : 75.0;
          aimX = (_rng.nextDouble() - 0.5) * CourtDimensions.halfWidth * 0.8;
        } else {
          chosenShot = ShotType.normal;
          forwardPower = PhysicsConstants.normalHitPower;
          upPower = 40.0;
          targetZ = 52.0;
          final targetSide =
              (humanPlayer != null && humanPlayer!.position.x <= 0) ? 1 : -1;
          aimX = targetSide * CourtDimensions.halfWidth * 0.60 +
              (_rng.nextDouble() - 0.5) * 8.0;
        }
      }
    } else {
      // ── EASY: FORGIVING RALLIES (CENTERED & PREDICTABLE) ──────────
      if (isUnforcedError) {
        chosenShot = ShotType.normal;
        forwardPower = 115.0;
        upPower = 41.0;
        targetZ = isPartner ? -50.0 : 50.0;
        aimX = (_rng.nextBool() ? 1 : -1) * (CourtDimensions.halfWidth + 3.0);
      } else {
        chosenShot = ShotType.normal;
        forwardPower = 125.0;
        upPower = 43.0; // High, comfortable arc clearing the net easily
        targetZ = isPartner ? -50.0 : 50.0;
        aimX = (_rng.nextDouble() - 0.5) *
            12.0; // Centered directly into player's court
      }
    }

    // In doubles, deliberately change the receiving lane between exchanges.
    // This keeps both defenders involved while the coverage coordinator still
    // decides whether an emergency poach is necessary.
    final coordinatedTargetX = preferredTargetX?.call();
    if (coordinatedTargetX != null && !isUnforcedError) {
      final spread = (1.0 - effectiveAccuracy) * 5.0;
      aimX = coordinatedTargetX + (_rng.nextDouble() - 0.5) * 2 * spread;
    }

    // Errors reduce tactical quality but never deliberately target outside.
    aimX = ShotTargeting.constrainReturnTargetX(aimX, ball.position.x);
    aimX = aimX.clamp(
      -CourtDimensions.halfWidth + 2.5,
      CourtDimensions.halfWidth - 2.5,
    );
    targetZ = targetZ.abs().clamp(4.0, CourtDimensions.halfLength - 4.0);

    // Tactical branches describe depth as a positive distance. Convert that
    // depth to the opponent's half for the team actually making the shot.
    targetZ = isPartner ? -targetZ.abs() : targetZ.abs();

    final target = Vec3(aimX, PhysicsConstants.ballRadius, targetZ);
    var shotPlan = AIShotPlanner.plan(
      start: ball.position,
      target: target,
      type: chosenShot,
      preferredHorizontalSpeed: forwardPower,
      preferredVerticalSpeed: upPower,
    );
    if (shotPlan == null) {
      chosenShot = ShotType.normal;
      final safeTarget = Vec3(
        0,
        PhysicsConstants.ballRadius,
        isPartner ? -52.0 : 52.0,
      );
      shotPlan = AIShotPlanner.plan(
        start: ball.position,
        target: safeTarget,
        type: chosenShot,
        preferredHorizontalSpeed: PhysicsConstants.normalHitPower,
        preferredVerticalSpeed: 44.0,
      );
    }
    if (shotPlan == null) {
      _state = AIState.approach;
      return;
    }
    lastShotPlan = shotPlan;

    final selectedSpin = _chooseSpin(chosenShot);
    final spinStrength = selectedSpin == ShotSpin.flat
        ? 0.0
        : (0.75 + paddleSpin * 0.50).clamp(0.0, 1.25).toDouble();

    // Launch the exact trajectory that was validated against drag and net sag.
    ball.velocity = shotPlan.launchVelocity.copy();
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = isPartner;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.isServe = false;
    ball.impactFlash =
        chosenShot == ShotType.power || chosenShot == ShotType.smash
            ? 1.0
            : 0.7;
    ball.shotSpin = selectedSpin;
    ball.spinStrength = spinStrength;
    ball.spinRate = switch (selectedSpin) {
      ShotSpin.topspin => 720.0 * spinStrength,
      ShotSpin.slice => -540.0 * spinStrength,
      ShotSpin.flat => chosenShot == ShotType.drop ? -400 : 400,
    };
    ball.shotType = chosenShot;
    ball.rallyHitCount++;

    onHit?.call(chosenShot == ShotType.power || chosenShot == ShotType.smash);

    ai.isSwinging = true;
    ai.swingCooldown = 0.5;
    ai.isForehand = ball.position.x > ai.position.x;
    ai.animState =
        ai.isForehand ? PlayerAnimState.forehand : PlayerAnimState.backhand;
    ai.animTimer = 0;
    ai.swingArm = 0.60; // Start at contact frame on strike

    _state = AIState.recover;
  }

  bool get _openingBounceHasTravelled =>
      ball.rallyHitCount >= 2 ||
      (ball.hasBounced &&
          (ball.position.z - ball.lastBounceZ).abs() >=
              PhysicsConstants.minimumOpeningBounceTravel);

  bool get _ballBouncedInOwnKitchen {
    if (!ball.hasBounced) return false;

    final bounceZ = ball.lastBounceZ;
    return ai.isPartner
        ? bounceZ >= 0 && bounceZ <= CourtDimensions.kitchenDepth
        : bounceZ <= 0 && bounceZ >= -CourtDimensions.kitchenDepth;
  }

  // ── Recover: return to court position ─────────────────────────
  void _updateRecover(double dt) {
    final defaultZ = ai.isPartner
        ? CourtDimensions.playerStartZ * 0.6
        : CourtDimensions.aiStartZ * 0.6;
    final defaultX = ai.assignedRightSide
        ? (ai.isPartner ? 16.0 : -16.0)
        : (ai.isPartner ? -16.0 : 16.0);
    final defaultPos = Vec3(defaultX, 0, defaultZ);
    final recoverSpeed = isPracticeMode ? 140.0 : effectiveSpeed * 0.6;
    _moveToward(defaultPos, dt, recoverSpeed);

    final dist =
        dist2D(ai.position.x, ai.position.z, defaultPos.x, defaultPos.z);
    if (dist < 12) {
      _state = AIState.idle;
      _hasPredictedTarget = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  void _predictBallLanding() {
    double bx = ball.position.x;
    double by = ball.position.y;
    double bz = ball.position.z;
    double vx = ball.velocity.x;
    double vy = ball.velocity.y;
    double vz = ball.velocity.z;
    const simDt = 0.025;
    bool foundLanding = false;

    for (int i = 0; i < 160; i++) {
      vy -= PhysicsConstants.gravity * simDt;

      // Air drag integration matching BallController
      final spd = math.sqrt(vx * vx + vy * vy + vz * vz);
      if (spd > 0.1) {
        final drag = (1.0 - PhysicsConstants.ballDragCoefficient * spd * simDt)
            .clamp(0.0, 1.0);
        vx *= drag;
        vy *= drag;
        vz *= drag;
      }

      bx += vx * simDt;
      by += vy * simDt;
      bz += vz * simDt;

      // Ground bounce
      if (by <= PhysicsConstants.ballRadius && !foundLanding) {
        by = PhysicsConstants.ballRadius;
        vy = vy.abs() * PhysicsConstants.ballBounceDamping;
        vx *= PhysicsConstants.ballFriction;
        vz *= PhysicsConstants.ballFriction;
        foundLanding = true;

        final onThisSide = ai.isPartner ? (bz > 0) : (bz < 0);
        if (onThisSide) {
          final errX = isPracticeMode
              ? 0.0
              : (_rng.nextDouble() - 0.5) * _shotAimError * 0.6;
          // Offset behind the bounce in direction of ball movement
          final offsetZ = ai.isPartner ? 4.0 : -4.0;
          _targetPosition = Vec3(bx + errX, 0, bz + offsetZ);
          return;
        }
      }
    }

    // Default to appropriate side of court
    final defaultZ = ai.isPartner
        ? CourtDimensions.playerStartZ * 0.7
        : CourtDimensions.aiStartZ * 0.7;
    _targetPosition = Vec3(ball.position.x * 0.5, 0, defaultZ);
  }

  void _moveToward(Vec3 target, double dt, double speed) {
    final dx = target.x - ai.position.x;
    final dz = target.z - ai.position.z;
    final dist = math.sqrt(dx * dx + dz * dz);

    if (dist < 0.5) {
      ai.velocity.x = lerp(ai.velocity.x, 0, dt * 8);
      ai.velocity.z = lerp(ai.velocity.z, 0, dt * 8);
      return;
    }

    final dirX = dx / dist;
    final dirZ = dz / dist;
    final effectiveSpeedWithMultiplier = speed * ai.speedMultiplier;
    ai.velocity.x =
        lerp(ai.velocity.x, dirX * effectiveSpeedWithMultiplier, dt * 6);
    ai.velocity.z =
        lerp(ai.velocity.z, dirZ * effectiveSpeedWithMultiplier, dt * 6);
  }

  ShotSpin _chooseSpin(ShotType shot) {
    if (shot != ShotType.normal && shot != ShotType.power) {
      return ShotSpin.flat;
    }
    if (isPracticeMode) return ShotSpin.topspin;
    return switch (difficulty) {
      AIDifficulty.easy => _rng.nextDouble() < 0.12
          ? ShotSpin.topspin
          : ShotSpin.flat,
      AIDifficulty.medium => shot == ShotType.power
          ? ShotSpin.topspin
          : (_rng.nextDouble() < 0.22
              ? ShotSpin.slice
              : ShotSpin.topspin),
      AIDifficulty.hard => shot == ShotType.power || ball.position.y > 15
          ? ShotSpin.topspin
          : ShotSpin.slice,
    };
  }

  void _updateAnimation(double dt) {
    ai.animTimer += dt;
    ai.swingCooldown = math.max(0, ai.swingCooldown - dt);

    if (ai.isSwinging) {
      final swingSpeed = ai.swingArm < 0.60 ? 3.6 : 2.8;
      ai.swingArm = math.min(1.0, ai.swingArm + dt * swingSpeed);
      if (ai.swingArm >= 1.0) {
        ai.isSwinging = false;
        ai.swingArm = 0;
      }
    }

    final moving = ai.isMoving;
    final targetRunBlend = moving ? 1.0 : 0.0;
    ai.runBlend += (targetRunBlend - ai.runBlend) * math.min(1.0, dt * 10.0);

    final speed = math
        .sqrt(ai.velocity.x * ai.velocity.x + ai.velocity.z * ai.velocity.z);
    if (moving) {
      ai.legCycleTimer += dt * (speed * 0.10 + 6.5);
      ai.animState = PlayerAnimState.moveForward;
    } else {
      ai.legCycleTimer += dt * 3.0 * ai.runBlend;
      ai.animState = PlayerAnimState.idle;
    }

    final targetLean = (ai.velocity.x / 14.0).clamp(-0.20, 0.20);
    ai.smoothedLean +=
        (targetLean - ai.smoothedLean) * math.min(1.0, dt * 12.0);
    ai.updateFacing(dt);
  }
}
