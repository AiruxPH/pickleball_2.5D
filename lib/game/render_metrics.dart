import 'dart:math' as math;

import '../utils/constants.dart';
import '../utils/game_math.dart';

/// Presentation-only sizing derived from the camera's perspective.
///
/// Readability clamps never feed back into simulation or collision state.
abstract final class RenderMetrics {
  static const double minimumBallRadius = 4.0;

  static double ballRadius(PerspectiveCamera camera, Vec3 position) {
    final physical =
        PhysicsConstants.ballRadius * camera.pixelsPerWorldUnit(position);
    return math.max(minimumBallRadius, physical);
  }

  static double characterScale(PerspectiveCamera camera, Vec3 feetPosition) {
    final projectedHeight =
        CourtDimensions.playerHeight * camera.pixelsPerWorldUnit(feetPosition);
    final viewport = camera.screenSize;
    final shortestSide = math.min(viewport.width, viewport.height);
    final readableHeight = projectedHeight.clamp(
      shortestSide * 0.035,
      viewport.height * 0.18,
    );
    return readableHeight / CourtDimensions.characterArtHeight;
  }
}
