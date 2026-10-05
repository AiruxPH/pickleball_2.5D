import 'dart:math' as math;
import '../../models/pickleball.dart';
import '../../models/player.dart';

final class ShotQualityResult {
  const ShotQualityResult({
    required this.quality,
    required this.isSweetSpot,
    required this.speedMultiplier,
    required this.liftAssist,
  });

  /// Quality score between 0.0 (maximum stretch/edge reach) and 1.0 (dead-center sweet spot).
  final double quality;

  /// True when hit is within the optimal paddle sweet spot zone.
  final bool isSweetSpot;

  /// Speed scaling factor (0.88 to 1.05). Off-center hits yield safer, softer floaters
  /// rather than fatal unforced net errors.
  final double speedMultiplier;

  /// Additional vertical lift for off-center/low contacts to guarantee net clearance.
  final double liftAssist;
}

/// Evaluates contact proximity and quality.
///
/// Punishes off-center timing tactically (producing a floatier ball the opponent can attack)
/// rather than with an instant unforced net fault.
ShotQualityResult calculateShotQuality({
  required Player player,
  required Pickleball ball,
  required double hitRadius,
}) {
  final dx = ball.position.x - player.position.x;
  final dz = ball.position.z - player.position.z;
  final dist = math.sqrt(dx * dx + dz * dz);

  // Sweet spot radius is roughly 40% of the maximum reach radius
  final sweetSpotRadius = hitRadius * 0.40;

  double rawQuality;
  if (dist <= sweetSpotRadius) {
    rawQuality = 1.0;
  } else {
    final falloff = (dist - sweetSpotRadius) / (hitRadius - sweetSpotRadius);
    rawQuality = (1.0 - falloff * 0.65).clamp(0.35, 1.0);
  }

  final isSweet = rawQuality >= 0.82;
  final speedMultiplier = 0.88 + 0.17 * rawQuality; // 0.88 to 1.05
  final liftAssist = (1.0 - rawQuality) * 4.0; // Up to +4.0 safety lift on stretched hits

  return ShotQualityResult(
    quality: rawQuality,
    isSweetSpot: isSweet,
    speedMultiplier: speedMultiplier,
    liftAssist: liftAssist,
  );
}
