import '../models/pickleball.dart';
import '../models/player.dart';
import '../models/court.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// PhysicsController — Collision detection
///
/// Checks:
///   • Ball vs net  (swept segment detection — no tunneling)
///   • Ball vs player paddle
///   • Ball vs AI paddle
/// ─────────────────────────────────────────────────────────────

class CollisionResult {
  final bool playerHit;
  final bool aiHit;
  final bool netHit;
  final bool powerHit;

  const CollisionResult({
    this.playerHit = false,
    this.aiHit = false,
    this.netHit = false,
    this.powerHit = false,
  });
}

class PhysicsController {
  final Pickleball ball;
  final Player player;
  final Player? playerPartner;
  final Player ai;
  final Player? aiPartner;
  final Court court;

  PhysicsController({
    required this.ball,
    required this.player,
    this.playerPartner,
    required this.ai,
    this.aiPartner,
    required this.court,
  });

  CollisionResult update(double dt) {
    if (ball.state == BallState.dead || ball.state == BallState.idle) {
      return const CollisionResult();
    }

    bool netHit = false;

    // ── Net collision (swept segment, no tunneling) ───────────
    if (_checkNetCollisionSwept()) {
      netHit = true;
      // Reflect Z velocity (ball hit the net face) with high energy loss
      ball.velocity.z = -ball.velocity.z * 0.25;
      ball.velocity.x *= 0.45;
      ball.velocity.y *= 0.20;
      ball.netCollision = true;
    }

    return CollisionResult(
      netHit: netHit,
    );
  }

  // ── Swept net detection (prevents tunneling) ──────────────────
  // The net is at Z = 0. We check whether the ball's path from prevPosition
  // to position crosses Z = 0, then interpolate the Y at that crossing to
  // determine if the ball was at or below net height at that point.
  bool _checkNetCollisionSwept() {
    final prevZ = ball.prevPosition.z;
    final currZ = ball.position.z;

    // Did the ball cross Z = 0 this frame?
    if (prevZ == currZ) return false;
    if ((prevZ > 0) == (currZ > 0)) return false; // same side, no crossing

    // Parametric t at crossing: prevZ + t*(currZ - prevZ) = 0
    final t = prevZ / (prevZ - currZ); // 0..1
    final crossY = ball.prevPosition.y + t * (ball.position.y - ball.prevPosition.y);
    final crossX = ball.prevPosition.x + t * (ball.position.x - ball.prevPosition.x);

    // Check X is within net posts (net spans full court width)
    if (crossX.abs() > CourtDimensions.halfWidth + 2) return false;

    // Net height sags slightly at center: 36" at posts → 34" at center
    // Modeled as a parabolic droop: netHeight * (1 - 0.06 * (1 - (x/halfW)²))
    final normalizedX = (crossX / CourtDimensions.halfWidth).clamp(-1.0, 1.0);
    final netH = CourtDimensions.netHeight * (1.0 - 0.06 * (1.0 - normalizedX * normalizedX));

    // Ball hits net if crossing Y is at or below net height (with small tape clip threshold)
    return crossY <= netH + 0.3;
  }
}
