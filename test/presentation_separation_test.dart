import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/camera_controller.dart';
import 'package:pickleball_3d/game/game_presentation.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/models/game_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('camera distortion cannot change simulation results', () {
    final settingsA = GameSettings();
    final settingsB = GameSettings();
    final gameA = PickleballGame(settings: settingsA);
    final gameB = PickleballGame(settings: settingsB);
    final presentation = GamePresentation(
      viewportSize: const Size(800, 600),
      player: gameA.player,
      ball: gameA.ball,
      settings: settingsA,
    );
    gameA.effects = presentation;

    gameA.setJoystick(0.7, -0.4);
    gameB.setJoystick(0.7, -0.4);
    presentation.cameraController.setView(CameraView.freeRoam);

    for (var i = 0; i < 120; i++) {
      presentation
        ..resize(Size(320 + i.toDouble(), 900 - i.toDouble()))
        ..camera.fov = 25 + (i % 90)
        ..cameraController.adjustFreeRoam(
          orbitDx: 13,
          orbitDy: -7,
          zoomFactor: 1.01,
        );
      gameA.update(1 / 120);
      gameB.update(1 / 120);
      presentation.update(1 / 60);
    }

    expect(gameA.player.position.x, closeTo(gameB.player.position.x, 1e-9));
    expect(gameA.player.position.z, closeTo(gameB.player.position.z, 1e-9));
    expect(gameA.ball.position.x, closeTo(gameB.ball.position.x, 1e-9));
    expect(gameA.ball.position.y, closeTo(gameB.ball.position.y, 1e-9));
    expect(gameA.ball.position.z, closeTo(gameB.ball.position.z, 1e-9));
    expect(gameA.state, gameB.state);
    expect(gameA.player.score, gameB.player.score);
    expect(gameA.ai.score, gameB.ai.score);
  });
}
