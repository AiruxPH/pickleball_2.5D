import 'dart:math' as math;
import 'dart:ui';

import '../utils/constants.dart';

/// Shared safeguards that keep returns directed back into the playable court.
class ShotTargeting {
  static const double _sidelineThresholdRatio = 0.55;
  static const double _minimumInwardDirection = 0.25;

  static bool _isNearSideline(double contactX) {
    return contactX.abs() >=
        CourtDimensions.halfWidth * _sidelineThresholdRatio;
  }

  /// From a wide contact point, force a return toward center or the opposite
  /// half instead of allowing it to continue toward the nearby sideline.
  static Offset constrainReturnDirection(
    Offset proposedDirection,
    double contactX,
  ) {
    if (!_isNearSideline(contactX)) return _normalized(proposedDirection);

    var dx = proposedDirection.dx;
    if (contactX > 0 && dx > -0.12) {
      dx = -_minimumInwardDirection;
    } else if (contactX < 0 && dx < 0.12) {
      dx = _minimumInwardDirection;
    }
    return _normalized(Offset(dx, proposedDirection.dy));
  }

  /// Applies the same rule to AI world-space targets.
  static double constrainReturnTargetX(double proposedTargetX, double contactX) {
    if (!_isNearSideline(contactX)) return proposedTargetX;
    return contactX > 0
        ? math.min(proposedTargetX, 0.0)
        : math.max(proposedTargetX, 0.0);
  }

  static Offset _normalized(Offset value) {
    final length = math.sqrt(value.dx * value.dx + value.dy * value.dy);
    if (length <= 0.0001) return const Offset(0, -1);
    return Offset(value.dx / length, value.dy / length);
  }
}
