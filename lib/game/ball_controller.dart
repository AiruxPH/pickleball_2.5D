import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/pickleball.dart';
import '../models/court.dart';
import '../models/game_settings.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// BallController — Updates ball physics each frame
///
/// Handles:
///   • Gravity (correctly scaled for world units)
///   • Air drag (perforated ball Cd ≈ 0.45)
///   • Ground bounce with correct COR (0.64 from rulebook drop test)
///   • Ball state transitions: inFlight ↔ bouncing
///   • Spin animation & trail recording
/// ─────────────────────────────────────────────────────────────

class BallController {
  final Pickleball ball;
  final Court court;
  final VoidCallback? onBounce;
  final GameSettings? settings;

  BallController({
    required this.ball,
    required this.court,
    this.onBounce,
    this.settings,
  });

  void update(double dt) {
    if (ball.state == BallState.dead || ball.state == BallState.idle) return;

    // ── Record previous position for swept collision detection ──
    ball.prevPosition = ball.position.copy();

    // ── Gravity ─────────────────────────────────────────────
    ball.velocity.y -= PhysicsConstants.gravity * dt;

    // ── Air Drag ─────────────────────────────────────────────
    // F_drag ∝ v² for a perforated ball (Cd ≈ 0.45).
    // Simplified as linear drag for stability: scale velocity by (1 - Cd * |v| * dt)
    // This makes dinks die quickly and hard drives slow noticeably mid-flight.
    final speed = ball.speed;
    if (speed > 0.1) {
      final dragFactor = (1.0 - PhysicsConstants.ballDragCoefficient * speed * dt)
          .clamp(0.0, 1.0);
      ball.velocity.x *= dragFactor;
      ball.velocity.y *= dragFactor;
      ball.velocity.z *= dragFactor;
    }

    // ── Position integration ─────────────────────────────────
    ball.position.x += ball.velocity.x * dt;
    ball.position.y += ball.velocity.y * dt;
    ball.position.z += ball.velocity.z * dt;

    // ── Ground collision ─────────────────────────────────────
    if (ball.position.y <= PhysicsConstants.ballRadius) {
      ball.position.y = PhysicsConstants.ballRadius;

      // Bounce: reflect Y velocity with COR = 0.64
      final incomingVy = ball.velocity.y.abs();
      double newVy = incomingVy * PhysicsConstants.ballBounceDamping;

      // Ensure first bounce has enough arc that players can comfortably return
      if (ball.bounceCount == 0 && newVy < 18.0) {
        newVy = math.max(newVy, 18.0);
      }
      ball.velocity.y = newVy;

      // Horizontal friction on bounce (energy lost to court surface)
      ball.velocity.x *= PhysicsConstants.ballFriction;
      ball.velocity.z *= PhysicsConstants.ballFriction;

      // Trigger court bounce audio for noticeable impacts
      if (incomingVy > 5.0 && ball.bounceCount <= 2) {
        onBounce?.call();
      }

      ball.bounceCount++;
      ball.hasBounced = true;
      ball.lastBounceZ = ball.position.z;
      ball.playerSideBounce = ball.position.z > 0;

      // Transition to bouncing state on first bounce, then back to inFlight
      // so double-bounce detection works correctly across frames
      if (ball.state == BallState.inFlight) {
        ball.state = BallState.bouncing;
      }

      // Kill vertical motion after energy is spent (micro-bounce suppression)
      if (newVy < 2.5) {
        ball.velocity.y = 0;
        // After fully settling, if double-bounced, score_controller handles it
      } else {
        // Ball still has bounce arc — return to inFlight next frame
        // We do this immediately so the state is correct during score checks
        ball.state = BallState.inFlight;
      }
    } else if (ball.state == BallState.bouncing) {
      // Ball is above ground again after a bounce — back to inFlight
      ball.state = BallState.inFlight;
    }

    // ── Spin ─────────────────────────────────────────────────
    ball.spinAngle += ball.spinRate * dt;

    // ── Decay impact flash ────────────────────────────────────
    if (ball.impactFlash > 0) {
      ball.impactFlash = math.max(0, ball.impactFlash - dt * 4);
    }

    // ── Trail recording ───────────────────────────────────────
    ball.addTrailPoint(settings?.maxTrailLength ?? 12);

    // ── Clamp max horizontal speed ───────────────────────────
    final hSpeed = math.sqrt(
        ball.velocity.x * ball.velocity.x + ball.velocity.z * ball.velocity.z);
    if (hSpeed > PhysicsConstants.maxBallSpeed) {
      final scale = PhysicsConstants.maxBallSpeed / hSpeed;
      ball.velocity.x *= scale;
      ball.velocity.z *= scale;
    }
  }
}
