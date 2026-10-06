import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/game_math.dart';

/// Converts viewport-space gestures into the player-relative command axes used
/// by the simulation, using the same perspective camera as the renderer.
final class CourtInputMapper {
  const CourtInputMapper(this.camera);

  final PerspectiveCamera camera;

  Offset? commandAxesFromScreenDrag({
    required Offset origin,
    required Offset current,
    required bool farSide,
    double magnitude = 1,
  }) {
    final worldOrigin = camera.screenToGround(origin);
    final worldCurrent = camera.screenToGround(current);
    if (worldOrigin == null || worldCurrent == null) return null;

    final dx = worldCurrent.x - worldOrigin.x;
    final dz = worldCurrent.z - worldOrigin.z;
    final length = math.sqrt(dx * dx + dz * dz);
    if (!length.isFinite || length < 0.0001) return Offset.zero;

    final strength = magnitude.clamp(0.0, 1.0).toDouble();
    return Offset(
      dx / length * strength,
      (farSide ? -dz : dz) / length * strength,
    );
  }

  Offset? commandAxesFromNormalizedScreenVector(
    Offset vector, {
    required bool farSide,
    Offset? anchor,
    double sampleDistance = 80,
  }) {
    final magnitude = vector.distance.clamp(0.0, 1.0).toDouble();
    if (magnitude < 0.0001) return Offset.zero;
    final origin = anchor ??
        Offset(camera.screenSize.width / 2, camera.screenSize.height / 2);
    final direction = vector / vector.distance;
    return commandAxesFromScreenDrag(
      origin: origin,
      current: origin + direction * sampleDistance,
      farSide: farSide,
      magnitude: magnitude,
    );
  }
}
