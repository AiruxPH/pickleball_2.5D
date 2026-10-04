import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pickleball_3d/utils/game_math.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/game/ball_controller.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';

void main() {
  group('Low-End Device Optimizations & Math Pipeline', () {
    test('PerspectiveCamera prepareFrame and projectCoords match Vec3 projection', () {
      final camera = PerspectiveCamera(
        position: Vec3(0, 3.2, -8.5),
        target: Vec3(0, 0.9, 0),
        fov: 60,
        screenSize: const Size(800, 600),
      );

      camera.prepareFrame();

      final testPoints = [
        Vec3(0, 0, 0),
        Vec3(-3.0, 0.8, 4.0),
        Vec3(2.5, 1.5, -2.0),
        Vec3(0, 0.914, 0), // center net cord
      ];

      for (final p in testPoints) {
        final screenViaVec3 = camera.project(p);
        final screenViaCoords = camera.projectCoords(p.x, p.y, p.z);

        expect(screenViaVec3, isNotNull);
        expect(screenViaCoords, isNotNull);
        expect(screenViaCoords!.dx, closeTo(screenViaVec3!.dx, 1e-4));
        expect(screenViaCoords.dy, closeTo(screenViaVec3.dy, 1e-4));

        final scaleViaVec3 = camera.depthScale(p);
        final scaleViaCoords = camera.depthScaleCoords(p.x, p.y, p.z);
        expect(scaleViaCoords, closeTo(scaleViaVec3, 1e-4));
      }
    });

    test('GameSettings targetFps & low-end mode heuristics', () {
      final settings = GameSettings();
      settings.graphicsQuality = GraphicsQuality.high;
      settings.targetFps = 60;
      expect(settings.isLowEndMode, isFalse);
      expect(settings.maxTrailLength, equals(12));

      settings.graphicsQuality = GraphicsQuality.low;
      expect(settings.isLowEndMode, isTrue);
      expect(settings.maxTrailLength, equals(3));

      settings.graphicsQuality = GraphicsQuality.medium;
      settings.targetFps = 30;
      expect(settings.maxTrailLength, equals(6));

      // Serialization & Deserialization
      final json = settings.toJson();
      expect(json['targetFps'], equals(30));
      expect(json['graphicsQuality'], equals(GraphicsQuality.medium.index));

      final restored = GameSettings();
      restored.fromJson(json);
      expect(restored.targetFps, equals(30));
      expect(restored.graphicsQuality, equals(GraphicsQuality.medium));
    });

    test('Pickleball trail dynamically adapts to maxTrailLength', () {
      final ball = Pickleball();
      expect(ball.trail.length, equals(0));

      // Add 20 points with maxTrailLength = 3 (Low graphics)
      for (int i = 0; i < 20; i++) {
        ball.position = Vec3(0, 1.0, i * 0.5);
        ball.addTrailPoint(3);
      }
      expect(ball.trail.length, equals(3));

      // Add points with maxTrailLength = 6 (Medium graphics)
      for (int i = 0; i < 20; i++) {
        ball.position = Vec3(0, 1.0, i * 0.5);
        ball.addTrailPoint(6);
      }
      expect(ball.trail.length, equals(6));
    });

    test('Ghost Phantom reuses clone storage between simulation ticks', () {
      final ball = Pickleball()..position = Vec3(4, 6, 8);

      ball.updateGhostClones(3);
      final firstList = ball.ghostClones1;
      final secondList = ball.ghostClones2;
      final firstClone = firstList.first;
      final secondClone = secondList.first;

      ball.position = Vec3(10, 12, 14);
      ball.updateGhostClones(2);

      expect(identical(ball.ghostClones1, firstList), isTrue);
      expect(identical(ball.ghostClones2, secondList), isTrue);
      expect(identical(ball.ghostClones1.first, firstClone), isTrue);
      expect(identical(ball.ghostClones2.first, secondClone), isTrue);
      expect(firstClone.x, equals(12));
      expect(firstClone.y, equals(13.2));
      expect(firstClone.z, equals(14));
      expect(secondClone.x, equals(8));
      expect(secondClone.y, equals(10.8));
      expect(secondClone.z, equals(14));
    });

    test('BallController trims trail according to settings', () {
      final lowSettings = GameSettings();
      lowSettings.graphicsQuality = GraphicsQuality.low;

      final ball = Pickleball();
      final court = Court();
      final controller = BallController(
        ball: ball,
        court: court,
        settings: lowSettings,
      );

      controller.ball.state = BallState.inFlight;
      controller.ball.velocity = Vec3(0, 2, 8);

      for (int i = 0; i < 30; i++) {
        controller.update(0.016);
      }

      expect(controller.ball.trail.length, lessThanOrEqualTo(lowSettings.maxTrailLength));
    });

    test('PickleballGame passes settings to ball controller correctly', () {
      final settings = GameSettings();
      settings.graphicsQuality = GraphicsQuality.low;
      settings.targetFps = 30;

      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
      );

      expect(game.ballController.settings?.isLowEndMode, isTrue);
      expect(game.ballController.settings?.targetFps, equals(30));
    });
  });
}
