import 'dart:math' as math;
import '../models/player.dart';
import '../models/pickleball.dart';
import '../models/court.dart';
import '../models/game_settings.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';

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
  final void Function(bool isPower)? onHit;

  AIState _state = AIState.idle;
  double _reactionTimer = 0;
  Vec3 _targetPosition = Vec3(0, 0, CourtDimensions.aiStartZ);
  bool _hasPredictedTarget = false;

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
    this.onHit,
  });

  /// Active difficulty for this AI instance (respects match override)
  AIDifficulty get difficulty => difficultyOverride ?? settings.difficulty;

  // Dynamic difficulty getters:
  double get effectiveSpeed {
    if (isPracticeMode) return 145.0;
    switch (difficulty) {
      case AIDifficulty.easy:   return 75.0;
      case AIDifficulty.medium: return 100.0;
      case AIDifficulty.hard:   return 130.0;
    }
  }

  double get effectiveReactionTime {
    if (isPracticeMode) return 0.02;
    switch (difficulty) {
      case AIDifficulty.easy:   return 0.32;
      case AIDifficulty.medium: return 0.18;
      case AIDifficulty.hard:   return 0.08;
    }
  }

  double get effectiveAccuracy {
    if (isPracticeMode) return 0.98;
    switch (difficulty) {
      case AIDifficulty.easy:   return 0.65;
      case AIDifficulty.medium: return 0.82;
      case AIDifficulty.hard:   return 0.95;
    }
  }

  double get effectiveErrorChance {
    if (isPracticeMode) return 0.0;
    switch (difficulty) {
      case AIDifficulty.easy:   return 0.15;
      case AIDifficulty.medium: return 0.07;
      case AIDifficulty.hard:   return 0.02;
    }
  }

  /// Max lateral error in world units when targeting a shot (lower = more accurate).
  double get _shotAimError {
    return (1.0 - effectiveAccuracy) * 35.0;
  }

  void update(double dt) {
    // In practice mode, AI has infinite stamina and never tires
    if (isPracticeMode && !ai.isPartner) {
      ai.stamina = StaminaConstants.maxStamina;
    }

    // Only act when ball is on this player's side or coming toward it
    final isPartner = ai.isPartner;
    final ballComing = isPartner
        ? (ball.position.z > 0 || ball.velocity.z > 2.0)
        : (ball.position.z < 0 || ball.velocity.z < -2.0);

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
    final reactionDelay = effectiveReactionTime / (ai.speedMultiplier.clamp(0.2, 1.0));
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
      ai.position.x, ai.position.z,
      _targetPosition.x, _targetPosition.z,
    );

    if (distToTarget < 18) {
      _state = AIState.approach;
    } else {
      _moveToward(_targetPosition, dt, effectiveSpeed);
    }
  }

  // ── Approach: close in on ball ─────────────────────────────────
  void _updateApproach(double dt) {
    // Two-bounce rule: If rallyHitCount < 2, must let ball bounce before striking!
    final mustWaitBounce = ball.rallyHitCount < 2 && !ball.hasBounced;

    // Movement target during approach:
    // Head toward predicted landing spot while ball is in flight, then track bounced ball directly
    final targetX = ball.hasBounced
        ? ball.position.x
        : (isPracticeMode || difficulty == AIDifficulty.hard
            ? ball.position.x
            : lerp(_targetPosition.x, ball.position.x, 0.85));

    final targetZ = ball.hasBounced
        ? (ai.isPartner ? ball.position.z + 3.0 : ball.position.z - 3.0)
        : _targetPosition.z;

    // Non-volley zone rule: If ball hasn't bounced yet, stay outside kitchen!
    // Once ball bounces, player can legally step into kitchen to return.
    final clampedZ = ball.hasBounced
        ? targetZ
        : (ai.isPartner
            ? math.max(targetZ, CourtDimensions.kitchenDepth + 2.5)
            : math.min(targetZ, -CourtDimensions.kitchenDepth - 2.5));

    final approachSpeed = isPracticeMode ? 165.0 : effectiveSpeed * 1.15;
    _moveToward(Vec3(targetX, 0, clampedZ), dt, approachSpeed);

    // Check if close enough to swing
    final distToBall = dist2D(
      ai.position.x, ai.position.z,
      ball.position.x, ball.position.z,
    );

    // Two-bounce rule check
    if (mustWaitBounce) return;

    // Kitchen rule: cannot volley from inside kitchen or touching line before bounce
    if (!ball.hasBounced) {
      if (ai.isInKitchen(includeFootMargin: true) || !ai.hasEstablishedOutsideKitchen) {
        return;
      }
    }

    final canHitZ = ai.isPartner ? ball.position.z > -8 : ball.position.z < 8;
    final reach = isPracticeMode ? 34.0 : 32.0;
    final maxHitY = isPracticeMode ? 44.0 : 40.0;
    if (distToBall < reach && ball.position.y < maxHitY && canHitZ && ai.canSwing) {
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

  // ── Swing: hit the ball with tactical shot selection ────────────
  void _updateSwing(double dt) {
    if (!ai.canSwing) {
      return; // wait until swing cooldown finishes, do not abort
    }

    // Kitchen check: Cannot volley from inside kitchen or touching line, or before establishing feet!
    if (!ball.hasBounced) {
      if (ai.isInKitchen(includeFootMargin: true) || !ai.hasEstablishedOutsideKitchen) {
        _state = AIState.approach;
        return;
      }
      // Arm AI kitchen momentum flag on legal volley
      ai.kitchenMomentumFlag = true;
    }

    // Two-bounce rule check: must not hit before bounce on serve / return
    if (ball.rallyHitCount < 2 && !ball.hasBounced) {
      _state = AIState.approach;
      return;
    }

    final isPartner = ai.isPartner;
    final zDirection = isPartner ? -1.0 : 1.0;

    ShotType chosenShot = ShotType.normal;
    double forwardPower = PhysicsConstants.normalHitPower;
    double upPower = 40.0;
    double targetZ = isPartner ? -52.0 : 52.0;
    double aimX = 0;

    final isUnforcedError = _rng.nextDouble() < effectiveErrorChance;
    final isServeReturn = ball.rallyHitCount < 2;

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
        forwardPower = PhysicsConstants.dropHitPower * (0.95 + _rng.nextDouble() * 0.10);
        upPower = 36.0;
        aimX = (_rng.nextDouble() - 0.5) * CourtDimensions.width * 0.7;
        targetZ = 16.0;
      } else if (drillType == 'footwork_drill') {
        final playerOnLeft = humanPlayer != null ? humanPlayer!.position.x < 0 : false;
        aimX = playerOnLeft
            ? (CourtDimensions.halfWidth * 0.85)
            : (-CourtDimensions.halfWidth * 0.85);
        chosenShot = ShotType.normal;
        forwardPower = PhysicsConstants.normalHitPower * 1.18;
        upPower = 40.0;
        targetZ = 55.0;
      } else {
        if (ball.position.y > 18 && ai.position.z > -48.0) {
          chosenShot = ShotType.power;
          forwardPower = PhysicsConstants.powerHitPower * 1.15;
          upPower = 28.0;
          targetZ = 48.0;
          if (humanPlayer != null && humanPlayer!.position.x < 0) {
            aimX = CourtDimensions.halfWidth * 0.82;
          } else {
            aimX = -CourtDimensions.halfWidth * 0.82;
          }
        } else if (humanPlayer != null && humanPlayer!.position.z > CourtDimensions.playerStartZ + 6 && ai.position.z > -38.0) {
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
            aimX = (_rng.nextBool() ? 1 : -1) * CourtDimensions.halfWidth * 0.80;
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
        chosenShot = ShotType.power;
        forwardPower = PhysicsConstants.powerHitPower * 1.15;
        upPower = 28.0;
        targetZ = 46.0;
        aimX = (humanPlayer != null && humanPlayer!.position.x < 0)
            ? CourtDimensions.halfWidth * 0.82
            : -CourtDimensions.halfWidth * 0.82;
        ai.useStamina(StaminaConstants.powerShotCost * 0.5);
      } else if (humanPlayer != null && humanPlayer!.position.z > CourtDimensions.playerStartZ + 6.0 && ai.position.z > -38.0) {
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
        if (ball.position.y > 19.0 && roll < 0.35 && ai.stamina >= StaminaConstants.powerShotCost) {
          chosenShot = ShotType.power;
          ai.useStamina(StaminaConstants.powerShotCost);
          forwardPower = PhysicsConstants.powerHitPower;
          upPower = 38.0;
          targetZ = 50.0;
          aimX = (humanPlayer != null && humanPlayer!.position.x < 0)
              ? CourtDimensions.halfWidth * 0.65
              : -CourtDimensions.halfWidth * 0.65;
        } else if (roll < 0.15 && ai.position.z > -38.0 && ai.stamina >= StaminaConstants.dropShotCost) {
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
          final targetSide = (humanPlayer != null && humanPlayer!.position.x <= 0) ? 1 : -1;
          aimX = targetSide * CourtDimensions.halfWidth * 0.60 + (_rng.nextDouble() - 0.5) * 8.0;
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
        aimX = (_rng.nextDouble() - 0.5) * 12.0; // Centered directly into player's court
      }
    }

    // Clamp aimX safely within legal court sidelines (unless deliberate wide unforced error)
    if (!isUnforcedError) {
      aimX = aimX.clamp(-CourtDimensions.halfWidth + 2.5, CourtDimensions.halfWidth - 2.5);
    }

    // Accurate directional velocity computation toward (aimX, targetZ)
    final deltaX = aimX - ball.position.x;
    final deltaZ = targetZ - ball.position.z;
    final horizDist = math.sqrt(deltaX * deltaX + deltaZ * deltaZ);
    final dirX = horizDist > 0.001 ? deltaX / horizDist : 0.0;
    final dirZ = horizDist > 0.001 ? deltaZ / horizDist : zDirection;

    // Launch ball cleanly
    ball.velocity = Vec3(
      dirX * forwardPower,
      upPower,
      dirZ * forwardPower,
    );
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = isPartner;
    ball.bounceCount = 0;
    ball.hasBounced = false;
    ball.isServe = false;
    ball.impactFlash = chosenShot == ShotType.power ? 1.0 : 0.7;
    ball.spinRate = chosenShot == ShotType.drop ? -400 : 400;
    ball.shotType = chosenShot;
    ball.rallyHitCount++;

    onHit?.call(chosenShot == ShotType.power);

    ai.isSwinging = true;
    ai.swingCooldown = 0.5;
    ai.isForehand = ball.position.x > ai.position.x;
    ai.animState = ai.isForehand
        ? PlayerAnimState.forehand
        : PlayerAnimState.backhand;
    ai.animTimer = 0;
    ai.swingArm = 0;

    _state = AIState.recover;
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

    final dist = dist2D(
        ai.position.x, ai.position.z, defaultPos.x, defaultPos.z);
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
        final drag = (1.0 - PhysicsConstants.ballDragCoefficient * spd * simDt).clamp(0.0, 1.0);
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
    ai.velocity.x = lerp(ai.velocity.x, dirX * effectiveSpeedWithMultiplier, dt * 6);
    ai.velocity.z = lerp(ai.velocity.z, dirZ * effectiveSpeedWithMultiplier, dt * 6);
  }

  void _updateAnimation(double dt) {
    ai.animTimer += dt;
    ai.swingCooldown = math.max(0, ai.swingCooldown - dt);

    if (ai.isSwinging) {
      ai.swingArm = math.min(1.0, ai.swingArm + dt * 5);
      if (ai.swingArm >= 1.0) {
        ai.isSwinging = false;
        ai.swingArm = 0;
      }
    }

    final moving = ai.isMoving;
    final targetRunBlend = moving ? 1.0 : 0.0;
    ai.runBlend += (targetRunBlend - ai.runBlend) * math.min(1.0, dt * 10.0);

    final speed = math.sqrt(ai.velocity.x * ai.velocity.x + ai.velocity.z * ai.velocity.z);
    if (moving) {
      ai.legCycleTimer += dt * (speed * 0.10 + 6.5);
      ai.animState = PlayerAnimState.moveForward;
    } else {
      ai.legCycleTimer += dt * 3.0 * ai.runBlend;
      ai.animState = PlayerAnimState.idle;
    }

    final targetLean = (ai.velocity.x / 14.0).clamp(-0.20, 0.20);
    ai.smoothedLean += (targetLean - ai.smoothedLean) * math.min(1.0, dt * 12.0);
    ai.updateFacing(dt);
  }
}
