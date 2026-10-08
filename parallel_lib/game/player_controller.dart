import 'dart:math' as math;
import '../models/player.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// PlayerController — updates human player movement & animations
/// ─────────────────────────────────────────────────────────────

class PlayerController {
  final Player player;

  PlayerController({required this.player});

  // ── Movement ────────────────────────────────────────────────
  void updateMovement(double dt, double jx, double jy, {double speedMultiplier = 1.0}) {
    // Target velocity from joystick
    var targetVx = jx * PhysicsConstants.playerSpeed * speedMultiplier;
    var targetVz = jy * PhysicsConstants.playerSpeed * speedMultiplier;

    // During active swing windup & contact, ground the player so feet feel planted
    if (player.isSwinging && player.swingArm < 0.70) {
      targetVx *= 0.35;
      targetVz *= 0.35;
    }

    // Dynamic acceleration: snappy athletic traction when reversing direction
    double getAccel(double currentV, double targetV, double jAxis) {
      if (jAxis.abs() < 0.05) return PhysicsConstants.playerDeceleration;
      if (currentV * targetV < -1.0) {
        // High traction turnaround cut
        return PhysicsConstants.playerAcceleration * 2.2;
      }
      return PhysicsConstants.playerAcceleration;
    }

    final accelX = getAccel(player.velocity.x, targetVx, jx);
    final accelZ = getAccel(player.velocity.z, targetVz, jy);

    player.velocity.x = _approachVelocity(
        player.velocity.x, targetVx, accelX * dt);
    player.velocity.z = _approachVelocity(
        player.velocity.z, targetVz, accelZ * dt);

    // Apply movement
    player.position.x += player.velocity.x * dt;
    player.position.z += player.velocity.z * dt;

    // Update facing angle toward movement direction
    if (player.velocity.x.abs() > 2 || player.velocity.z.abs() > 2) {
      final targetAngle = math.atan2(player.velocity.x, -player.velocity.z);
      player.facingAngle = _lerpAngle(player.facingAngle, targetAngle, dt * 10);
    }

    // Update leg cycle and smooth runBlend for walk/sprint animation
    final moving = player.isMoving;
    final targetRunBlend = moving ? 1.0 : 0.0;
    player.runBlend += (targetRunBlend - player.runBlend) * math.min(1.0, dt * 10.0);

    final speed = math.sqrt(player.velocity.x * player.velocity.x + player.velocity.z * player.velocity.z);
    if (moving) {
      player.legCycleTimer += dt * (speed * 0.10 + 6.5);
    } else {
      player.legCycleTimer += dt * 3.0 * player.runBlend;
    }

    // Smooth banking lean
    final targetLean = (player.velocity.x / 14.0).clamp(-0.20, 0.20);
    player.smoothedLean += (targetLean - player.smoothedLean) * math.min(1.0, dt * 12.0);
    player.updateFacing(dt);

    // Update animation state based on movement
    if (!player.isSwinging) {
      if (player.isMoving) {
        if (player.velocity.x < -6) {
          player.animState = PlayerAnimState.moveLeft;
        } else if (player.velocity.x > 6) {
          player.animState = PlayerAnimState.moveRight;
        } else if (player.isNearSide ? player.velocity.z < -6 : player.velocity.z > 6) {
          player.animState = PlayerAnimState.moveForward;
        } else {
          player.animState = PlayerAnimState.moveBack;
        }
      } else {
        player.animState = PlayerAnimState.idle;
      }
    }
  }

  // ── Animation update ─────────────────────────────────────────
  void updateAnimation(double dt) {
    player.animTimer += dt;
    player.swingCooldown = math.max(0, player.swingCooldown - dt);

    // Progress swing arm: dynamic pacing for athletic windup and clear follow-through
    if (player.isSwinging) {
      final swingSpeed = player.swingArm < 0.60 ? 3.6 : 2.8;
      player.swingArm = math.min(1.0, player.swingArm + dt * swingSpeed);

      // Reset swing when animation completes
      if (player.swingArm >= 1.0) {
        player.isSwinging = false;
        player.swingArm = 0;
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────
  double _approachVelocity(double current, double target, double maxStep) {
    final diff = target - current;
    if (diff.abs() < maxStep) return target;
    return current + diff.sign * maxStep;
  }

  double _lerpAngle(double a, double b, double t) {
    var diff = b - a;
    while (diff > math.pi) { diff -= 2 * math.pi; }
    while (diff < -math.pi) { diff += 2 * math.pi; }
    return a + diff * t.clamp(0, 1);
  }
}
