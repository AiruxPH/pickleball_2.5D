import 'dart:math' as math;
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

    test('sideline view is a true lateral broadcast angle', () {
      controller.setView(CameraView.sideline);
      controller.update(1, 1);

      expect(camera.position.x, greaterThan(115));
      expect(camera.position.z.abs(), lessThan(2));
      expect(camera.fov, closeTo(60, 0.5));
    });

    test('player follow preserves viewport-selected FOV', () {
      camera.fov = 47;
      controller.update(1, 1);

      expect(camera.fov, 47);
    });

    test('free roam wraps through 360 degrees while clamping pitch and zoom',
        () {
      controller.setView(CameraView.freeRoam);
      controller.adjustFreeRoam(
        orbitDx: -(math.pi / 0.008),
        orbitDy: 10000,
        zoomFactor: 100,
      );

      expect(controller.freeRoamYaw.abs(), closeTo(math.pi, 1e-6));
      expect(controller.freeRoamPitch, 0.26);
      expect(controller.freeRoamDistance, 110);

      controller.adjustFreeRoam(
        orbitDx: -(math.pi / 0.008),
        orbitDy: -10000,
        zoomFactor: 0.001,
      );
      expect(controller.freeRoamYaw, closeTo(0, 1e-6));
      expect(controller.freeRoamPitch, 1.12);
      expect(controller.freeRoamDistance, 260);
    });

    test('baseline and overhead presets keep the full court farther away', () {
      controller.setView(CameraView.baseline);
      controller.update(1, 1);
      expect(camera.position.z, greaterThan(150));

      controller.setView(CameraView.overhead);
      controller.update(1, 1);
      expect(camera.position.y, greaterThan(210));
      expect(camera.position.z.abs(), lessThan(2));
      camera.prepareFrame();
      expect(camera.projectCoords(0, 0, -80), isNotNull);
      expect(camera.projectCoords(0, 0, 80), isNotNull);
    });
  });
}
