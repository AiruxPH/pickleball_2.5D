import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/camera_controller.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  group('CameraController spectator views', () {
    late PerspectiveCamera camera;
    late CameraController controller;

    setUp(() {
      camera = PerspectiveCamera(
        position: Vec3(0, 42, 130),
        target: Vec3(0, 0, 0),
        screenSize: const Size(1280, 720),
        fov: 48,
      );
      controller = CameraController(
        camera: camera,
        player: Player(startPosition: Vec3(0, 0, 60), isHuman: true),
        ball: Pickleball(),
      );
    });

    test('cycles through each spectator angle in order', () {
      controller.setView(CameraView.baseline);

      expect(controller.cycleSpectatorView(), CameraView.sideline);
      expect(controller.cycleSpectatorView(), CameraView.overhead);
      expect(controller.cycleSpectatorView(), CameraView.freeRoam);
      expect(controller.cycleSpectatorView(), CameraView.baseline);
    });

    test('sideline view moves camera laterally and adjusts its FOV', () {
      controller.setView(CameraView.sideline);
      controller.update(1, 1);

      expect(camera.position.x, greaterThan(100));
      expect(camera.fov, closeTo(54, 0.5));
    });

    test('player follow preserves viewport-selected FOV', () {
      camera.fov = 47;
      controller.update(1, 1);

      expect(camera.fov, 47);
    });

    test('free roam clamps pitch and zoom to safe stadium bounds', () {
      controller.setView(CameraView.freeRoam);
      controller.adjustFreeRoam(
        orbitDx: 40,
        orbitDy: 10000,
        zoomFactor: 100,
      );

      expect(controller.freeRoamPitch, 0.20);
      expect(controller.freeRoamDistance, 68);

      controller.adjustFreeRoam(orbitDy: -10000, zoomFactor: 0.001);
      expect(controller.freeRoamPitch, 1.22);
      expect(controller.freeRoamDistance, 210);
    });
  });
}
