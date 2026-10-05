import 'dart:ui';
import '../shot_targeting.dart';

/// Calculates the final aim vector by synthesizing joystick steering,
/// contact timing deflection, and court sideline safety constraints.
Offset calculatePlayerAimDirection({
  required Offset? swipeDirection,
  required double joystickX,
  required double joystickY,
  required double timingOffsetDx,
  required double contactX,
  required bool isNearSide,
}) {
  final forwardZ = isNearSide ? -1.0 : 1.0;

  // 1. Base lateral intent: swipe gesture overrides joystick if active
  double baseDx;
  if (swipeDirection != null) {
    baseDx = swipeDirection.dx;
  } else {
    // Joystick steering: +/-0.65 max lateral influence
    baseDx = (joystickX * 0.65).clamp(-0.65, 0.65);
  }

  // 2. Synthesize with natural timing angle
  final combinedDx = (baseDx + timingOffsetDx).clamp(-0.85, 0.85);

  // 3. Construct proposed 2D direction (X, Z)
  final proposed = Offset(combinedDx, forwardZ);

  // 4. Run through sideline safety constraints so balls struck out wide
  // naturally hook back into the playable court rather than flying wide.
  if (isNearSide) {
    return ShotTargeting.constrainReturnDirection(proposed, contactX);
  } else {
    final constrained = ShotTargeting.constrainReturnDirection(
      Offset(proposed.dx, -1),
      contactX,
    );
    return Offset(constrained.dx, 1);
  }
}
