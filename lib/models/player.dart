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

  // ── Visual ─────────────────────────────────────────────────
  double facingAngle;     // radians, 0 = facing toward net
  double legCycleTimer;   // for walk animation
  double swingArm;        // 0..1, arm swing progress
  double speedMultiplier; // temporary buff/debuff (e.g. frostbite freeze)

  /// Kitchen momentum flag — set when player volleys outside kitchen.
  /// Cleared only when player is fully outside NVZ AND nearly stopped.
  /// Faults if player touches NVZ while this flag is active.
  bool kitchenMomentumFlag;

  // ── Is this the human player? ──────────────────────────────
  final bool isHuman;

  Player({
    required Vec3 startPosition,
    required this.isHuman,
    this.isPartner = false,
    this.assignedRightSide = true,
  })  : position = startPosition,
        velocity = Vec3(0, 0, 0),
        animState = PlayerAnimState.idle,
        animTimer = 0,
        isSwinging = false,
        isServing = false,
        swingCooldown = 0,
        score = 0,
        isForehand = true,
        stamina = StaminaConstants.maxStamina,
        facingAngle = (isHuman || isPartner) ? 0 : 3.14159,
        legCycleTimer = 0,
        swingArm = 0,
        speedMultiplier = 1.0,
        kitchenMomentumFlag = false;

  // ── Convenience getters ────────────────────────────────────
  bool get isMoving {
    return velocity.x.abs() > 1 || velocity.z.abs() > 1;
  }

  bool get canSwing => swingCooldown <= 0 && !isSwinging;

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

  // ── Kitchen Rule Check ─────────────────────────────────────
  /// Returns true if the player is currently standing inside the Non-Volley Zone (Kitchen)
  bool isInKitchen() {
    if (isHuman || (isPartner && position.z > 0)) {
      return position.z >= 0 &&
          position.z <= CourtDimensions.kitchenDepth &&
          position.x.abs() <= CourtDimensions.halfWidth;
    } else {
      return position.z <= 0 &&
          position.z >= -CourtDimensions.kitchenDepth &&
          position.x.abs() <= CourtDimensions.halfWidth;
    }
  }

  /// Returns true if player is in kitchen OR has the momentum flag set.
  /// A player who volleys and then enters the NVZ due to their own momentum
  /// is also faulting per USA Pickleball rules.
  bool isInKitchenOrMomentum() {
    return isInKitchen() || kitchenMomentumFlag;
  }

  /// Clears momentum flag once player is fully outside NVZ and has stopped
  void clearKitchenMomentumIfStopped() {
    if (kitchenMomentumFlag && !isInKitchen()) {
      final speed = velocity.x.abs() + velocity.z.abs();
      if (speed < 8.0) {
        kitchenMomentumFlag = false;
      }
    }
  }

  // ── Bounds ─────────────────────────────────────────────────
  void clampToCourt() {
    if (isHuman || (isPartner && position.z > 0)) {
      // Human / partner stays on near half (positive Z)
      position.x = position.x.clamp(
          -CourtDimensions.halfWidth + 5, CourtDimensions.halfWidth - 5);
      position.z = position.z.clamp(2.0, CourtDimensions.halfLength - 5);
    } else {
      // AI opponent stays on far half (negative Z)
      position.x = position.x.clamp(
          -CourtDimensions.halfWidth + 5, CourtDimensions.halfWidth - 5);
      position.z = position.z.clamp(
          -CourtDimensions.halfLength + 5, -2.0);
    }
  }

  // ── Reset ──────────────────────────────────────────────────
  void resetPosition({double? customX, double? customZ}) {
    if (customX != null && customZ != null) {
      position = Vec3(customX, 0, customZ);
    } else if (isHuman) {
      position = Vec3(assignedRightSide ? 16.0 : -16.0, 0, CourtDimensions.playerStartZ);
    } else if (isPartner) {
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
  }
}
