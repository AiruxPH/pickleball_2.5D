import 'package:flutter/material.dart';

import '../models/game_settings.dart';
import '../models/pickleball.dart';
import '../models/player.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';
import 'camera_controller.dart';
import 'vfx.dart';

/// One-way port used by the simulation to announce visual events.
///
/// Implementations must never feed camera or effect state back into gameplay.
abstract interface class GameEffects {
  void spawnHitSparks(
    Vec3 position,
    Color color, {
    double power = 1,
    double dirZ = -1,
  });
  void spawnBounce(Vec3 position, Color color, double intensity);
  void spawnNetPuff(Vec3 position);
  void pulseCamera({double? shake, double? zoom});
  void clear();
}

final class NoGameEffects implements GameEffects {
  const NoGameEffects();

  @override
  void clear() {}

  @override
  void pulseCamera({double? shake, double? zoom}) {}

  @override
  void spawnBounce(Vec3 position, Color color, double intensity) {}

  @override
  void spawnHitSparks(
    Vec3 position,
    Color color, {
    double power = 1,
    double dirZ = -1,
  }) {}

  @override
  void spawnNetPuff(Vec3 position) {}
}

/// Camera, viewport, and transient effects for one rendered match.
///
/// This layer observes world-space entities but cannot mutate simulation rules.
final class GamePresentation implements GameEffects {
  GamePresentation({
    required Size viewportSize,
    required Player player,
    required Pickleball ball,
    required this.settings,
  }) {
    camera = PerspectiveCamera(
      position: Vec3(
        0,
        CameraConstants.cameraHeight,
        CourtDimensions.playerStartZ + CameraConstants.cameraDistanceBehind,
      ),
      target: Vec3(0, 0, 0),
      screenSize: viewportSize,
    );
    cameraController = CameraController(
      camera: camera,
      player: player,
      ball: ball,
    );
  }

  final GameSettings settings;
  late final PerspectiveCamera camera;
  late final CameraController cameraController;
  final VfxSystem vfx = VfxSystem();

  double animTime = 0;
  double cameraZoom = 1;
  double screenShake = 0;

  void resize(Size size) {
    camera.screenSize = size;
  }

  void update(double dt, {double effectTimeScale = 1}) {
    animTime += dt;
    screenShake = (screenShake - dt * 3).clamp(0.0, 1.0).toDouble();
    cameraZoom = (cameraZoom + dt * 1.5).clamp(0.0, 1.0).toDouble();
    vfx.enabled = settings.showParticles;
    vfx.update(dt * effectTimeScale);
    cameraController.update(dt, cameraZoom);
  }

  @override
  void pulseCamera({double? shake, double? zoom}) {
    if (shake != null) {
      screenShake = shake.clamp(0.0, 1.0).toDouble();
    }
    if (zoom != null) {
      cameraZoom = zoom.clamp(0.0, 1.0).toDouble();
    }
  }

  @override
  void spawnHitSparks(
    Vec3 position,
    Color color, {
    double power = 1,
    double dirZ = -1,
  }) {
    vfx.spawnHitSparks(position, color, power: power, dirZ: dirZ);
  }

  @override
  void spawnBounce(Vec3 position, Color color, double intensity) {
    vfx.spawnBounce(position, color, intensity);
  }

  @override
  void spawnNetPuff(Vec3 position) {
    vfx.spawnNetPuff(position);
  }

  @override
  void clear() {
    vfx.clear();
    cameraZoom = 1;
    screenShake = 0;
  }
}
