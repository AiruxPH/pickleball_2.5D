import '../../models/pickleball.dart';
import '../../models/player.dart';

/// Calculates the natural lateral deflection (dx offset) resulting from
/// contact timing and paddle position relative to the player's body.
///
/// Principles:
///   - Early contact (striking out in front of the body): naturally pulls cross-court.
///   - Late contact (striking level or behind the body): pushes down-the-line / inside-out.
///   - Centered contact: zero extra deflection, drives clean on targeted line.
double calculateContactTimingOffset({
  required Player player,
  required Pickleball ball,
  required bool isNearSide,
}) {
  // Ideal contact point is slightly out in front of the player toward the net
  final forwardSign = isNearSide ? -1.0 : 1.0;
  final idealContactZ = player.position.z + forwardSign * 3.5;

  // Positive = early hit (further forward toward net), Negative = late hit (deeper toward baseline)
  final deltaForward = isNearSide
      ? (idealContactZ - ball.position.z)
      : (ball.position.z - idealContactZ);

  // Clamp normalized timing factor into [-1.0, 1.0]
  final timingFactor = (deltaForward / 6.0).clamp(-1.0, 1.0);

  // Determine if striking on the forehand or backhand side
  // Default to player's tracked isForehand flag or derive from lateral offset
  final isForehand = player.isForehand;

  // Angle deflection magnitude: up to ~0.22 radians / lateral deflection
  const maxDeflection = 0.22;

  if (isNearSide) {
    if (isForehand) {
      // Early pulls cross-court (left / negative X), Late pushes down-the-line (right / positive X)
      return -timingFactor * maxDeflection;
    } else {
      // Backhand: Early pulls cross-court (right / positive X), Late pushes down-the-line (left / negative X)
      return timingFactor * maxDeflection;
    }
  } else {
    // Mirrored for far side
    if (isForehand) {
      return timingFactor * maxDeflection;
    } else {
      return -timingFactor * maxDeflection;
    }
  }
}
