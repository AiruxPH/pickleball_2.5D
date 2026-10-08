import 'dart:math' as math;
import '../utils/game_math.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Player model — holds position, velocity, state, score
/// ─────────────────────────────────────────────────────────────

enum PlayerAnimState {
  idle,
  moveLeft,
  moveRight,
  moveForward,
  moveBack,
  forehand,
  backhand,
  serve,
  victory,
  defeat,
}

class Player {
  // ── World position ─────────────────────────────────────────
  Vec3 position;
  Vec3 velocity;

  // ── State ──────────────────────────────────────────────────
  PlayerAnimState animState;
  double animTimer;       // seconds elapsed in current animation
  bool isSwinging;
  bool isServing;
  double swingCooldown;   // seconds remaining before can swing again

  // ── Score ──────────────────────────────────────────────────
  int score;

  // ── Swing detection ────────────────────────────────────────
  bool isForehand;        // true = forehand, false = backhand

  // ── Stamina & Rules ────────────────────────────────────────
  double stamina;
  final bool isPartner;
  bool assignedRightSide;
  bool isLunging = false;
  double lungeRecoveryTimer = 0.0;
  bool hasLungedThisShot = false;
  double splitStepTimer = 0.0;

  // ── Visual ─────────────────────────────────────────────────
  double facingAngle;     // radians, 0 = facing toward net
  double legCycleTimer;   // for walk animation
  double runBlend;        // 0..1 smooth blend between standing and running
  double smoothedLean;    // smoothed lateral banking angle
  double swingArm;        // 0..1, arm swing progress
  double speedMultiplier; // temporary buff/debuff (e.g. frostbite freeze)
  double facingFlip;      // -1..1 eased horizontal facing used by the renderer
  double facingFlipTarget;

  /// Kitchen momentum flag — set when player volleys outside kitchen.
  /// Cleared only when player is fully outside NVZ AND nearly stopped.
  /// Faults if player touches NVZ while this flag is active.
  bool kitchenMomentumFlag;

  /// Foot radius / stance margin for detecting contact with kitchen boundary lines.
  /// In official pickleball, the Kitchen line is part of the Kitchen.
  /// If your foot touches the line while you volley, it is considered a Kitchen violation.
  static const double footRadius = 1.2;

  /// Tracks whether the player has established both feet outside the NVZ.
  /// USA Pickleball Rule 9.D: After leaving the NVZ, both feet must be established
  /// outside the NVZ before executing a volley.
  bool hasEstablishedOutsideKitchen;
  double outsideKitchenTimer;
  static const double establishmentTimeRequired = 0.20;

  // ── Is this the human player? ──────────────────────────────
  final bool isHuman;
  final bool isNearSide;

  Player({
    required Vec3 startPosition,
    required this.isHuman,
    this.isPartner = false,
    this.assignedRightSide = true,
    bool? isNearSide,
  })  : position = startPosition,
        isNearSide = isNearSide ?? (isHuman || isPartner),
        velocity = Vec3(0, 0, 0),
        animState = PlayerAnimState.idle,
        animTimer = 0,
        isSwinging = false,
        isServing = false,
        swingCooldown = 0,
        score = 0,
        isForehand = true,
        stamina = StaminaConstants.maxStamina,
        facingAngle = (isNearSide ?? (isHuman || isPartner)) ? 0 : 3.14159,
        legCycleTimer = 0,
        runBlend = 0.0,
        smoothedLean = 0.0,
        swingArm = 0,
        speedMultiplier = 1.0,
        facingFlip = 1.0,
        facingFlipTarget = 1.0,
        kitchenMomentumFlag = false,
        hasEstablishedOutsideKitchen = true,
        outsideKitchenTimer = 1.0;

  // ── Convenience getters ────────────────────────────────────
  bool get isMoving {
    return velocity.x.abs() > 1 || velocity.z.abs() > 1;
  }

  bool get canSwing => swingCooldown <= 0 && !isSwinging;

  /// Eases the rendered facing direction toward the movement direction.
  /// Keeps the last direction while standing still (no snap back to default).
  void updateFacing(double dt) {
    final isOpponent = !isNearSide;
    if (velocity.x < -1.5) {
      facingFlipTarget = isOpponent ? 1.0 : -1.0;
    } else if (velocity.x > 1.5) {
      facingFlipTarget = isOpponent ? -1.0 : 1.0;
    }
    final k = 1.0 - math.exp(-14.0 * dt);
    facingFlip += (facingFlipTarget - facingFlip) * k;
  }

  // ── Stamina management ─────────────────────────────────────
  void regenStamina(double dt) {
    stamina = (stamina + StaminaConstants.recoveryRate * dt)
        .clamp(0.0, StaminaConstants.maxStamina);
  }

  bool useStamina(double amount) {
    if (stamina >= amount) {
      stamina = (stamina - amount).clamp(0.0, StaminaConstants.maxStamina);
      return true;
    }
    return false;
  }

  // ── Kitchen Rule Checks ────────────────────────────────────
  /// Returns true if the player is currently standing inside the Non-Volley Zone (Kitchen)
  /// or touching the Kitchen line.
  /// If [includeFootMargin] is true (default), accounts for foot footprint touching the line.
  bool isInKitchen({bool includeFootMargin = true}) {
    final margin = includeFootMargin ? footRadius : 0.0;
    if (isNearSide) {
      return position.z >= -margin &&
          position.z <= (CourtDimensions.kitchenDepth + margin) &&
          position.x.abs() <= (CourtDimensions.halfWidth + margin);
    } else {
      return position.z <= margin &&
          position.z >= (-CourtDimensions.kitchenDepth - margin) &&
          position.x.abs() <= (CourtDimensions.halfWidth + margin);
    }
  }

  /// Returns true if the player's foot is directly touching or on the Kitchen line.
  bool isTouchingKitchenLine({double margin = footRadius}) {
    final targetLineZ = isNearSide
        ? CourtDimensions.kitchenDepth
        : -CourtDimensions.kitchenDepth;
    return (position.z - targetLineZ).abs() <= margin &&
        position.x.abs() <= CourtDimensions.halfWidth + margin;
  }

  /// Returns true if player is legally permitted to volley right now.
  /// Volleys are forbidden if player is in the Kitchen, touching the Kitchen line,
  /// or has not established both feet outside the Kitchen.
  bool canVolley() {
    return !isInKitchen(includeFootMargin: true) && hasEstablishedOutsideKitchen;
  }

  /// Returns true if player is in kitchen OR has the momentum flag set.
  /// A player who volleys and then enters the NVZ due to their own momentum
  /// is also faulting per USA Pickleball rules.
  bool isInKitchenOrMomentum() {
    return isInKitchen(includeFootMargin: true) || kitchenMomentumFlag;
  }

  /// Updates kitchen foot establishment state and checks momentum stop condition.
  void updateKitchenStatus(double dt) {
    if (isInKitchen(includeFootMargin: true)) {
      hasEstablishedOutsideKitchen = false;
      outsideKitchenTimer = 0.0;
    } else {
      outsideKitchenTimer += dt;
      if (outsideKitchenTimer >= establishmentTimeRequired) {
        hasEstablishedOutsideKitchen = true;
      }
    }
    clearKitchenMomentumIfStopped();
  }

  /// Clears momentum flag once player is fully outside NVZ and has stopped
  void clearKitchenMomentumIfStopped() {
    if (kitchenMomentumFlag && !isInKitchen(includeFootMargin: true)) {
      final speed = velocity.x.abs() + velocity.z.abs();
      if (speed < 8.0) {
        kitchenMomentumFlag = false;
      }
    }
  }

  // ── Bounds ─────────────────────────────────────────────────
  void clampToCourt() {
    if (isNearSide) {
      // Human / partner stays on near half (positive Z)
      position.x = position.x.clamp(
          -CourtDimensions.halfWidth - 40, CourtDimensions.halfWidth + 40);
      position.z = position.z.clamp(2.0, CourtDimensions.halfLength + 60);
    } else {
      // AI opponent stays on far half (negative Z)
      position.x = position.x.clamp(
          -CourtDimensions.halfWidth - 40, CourtDimensions.halfWidth + 40);
      position.z = position.z.clamp(
          -CourtDimensions.halfLength - 60, -2.0);
    }
  }

  // ── Reset ──────────────────────────────────────────────────
  void resetPosition({double? customX, double? customZ}) {
    if (customX != null && customZ != null) {
      position = Vec3(customX, 0, customZ);
    } else if (isNearSide && isHuman) {
      position = Vec3(assignedRightSide ? 16.0 : -16.0, 0, CourtDimensions.playerStartZ);
    } else if (isNearSide) {
      position = Vec3(assignedRightSide ? 16.0 : -16.0, 0, CourtDimensions.playerStartZ);
    } else {
      position = Vec3(assignedRightSide ? -16.0 : 16.0, 0, CourtDimensions.aiStartZ);
    }
    velocity = Vec3(0, 0, 0);
    animState = PlayerAnimState.idle;
    isSwinging = false;
    swingCooldown = 0;
    swingArm = 0;
    stamina = StaminaConstants.maxStamina;
    kitchenMomentumFlag = false;
    hasEstablishedOutsideKitchen = true;
    outsideKitchenTimer = 1.0;
  }
}
