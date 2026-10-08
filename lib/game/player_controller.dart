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
    final totalMultiplier = speedMultiplier * player.speedMultiplier;
    final targetVx = jx * PhysicsConstants.playerSpeed * totalMultiplier;
    final targetVz = jy * PhysicsConstants.playerSpeed * totalMultiplier;

    // Smooth acceleration/deceleration
    final baseAccel = jx.abs() < 0.05 && jy.abs() < 0.05
        ? PhysicsConstants.playerDeceleration
        : PhysicsConstants.playerAcceleration;
    
    // Apply split-step buff
    final accel = player.splitStepTimer > 0 ? baseAccel * 1.12 : baseAccel;

    player.velocity.x = _approachVelocity(
        player.velocity.x, targetVx, accel * dt);
    player.velocity.z = _approachVelocity(
        player.velocity.z, targetVz, accel * dt);

    // Apply movement
    player.position.x += player.velocity.x * dt;
    player.position.z += player.velocity.z * dt;

    // Update facing angle toward movement direction
    if (player.velocity.x.abs() > 2 || player.velocity.z.abs() > 2) {
      final targetAngle = math.atan2(player.velocity.x, -player.velocity.z);
      player.facingAngle = _lerpAngle(player.facingAngle, targetAngle, dt * 8);
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
        if (player.velocity.x < -5) {
          player.animState = PlayerAnimState.moveLeft;
        } else if (player.velocity.x > 5) {
          player.animState = PlayerAnimState.moveRight;
        } else if (player.velocity.z < -5) {
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
    
    if (player.splitStepTimer > 0) {
      player.splitStepTimer = math.max(0, player.splitStepTimer - dt);
    }
    
    if (player.lungeRecoveryTimer > 0) {
      player.lungeRecoveryTimer -= dt;
      if (player.lungeRecoveryTimer <= 0) {
        player.isLunging = false;
        player.lungeRecoveryTimer = 0;
      }
    }

    // Progress swing arm
    if (player.isSwinging) {
      player.swingArm = math.min(1.0, player.swingArm + dt * 5);

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
