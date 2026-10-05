import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/render_metrics.dart';
import 'package:pickleball_3d/game/sprite_character_renderer.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  test('overhead projection keeps physical scale and readable athletes', () {
    final camera = PerspectiveCamera(
      position: Vec3(0, 230, 0),
      target: Vec3(0, 0, 0),
      up: Vec3(0, 0, -1),
      screenSize: const Size(1280, 720),
      fov: 60,
    )..prepareFrame();
    final feet = Vec3(0, 0, 60);

    expect(camera.pixelsPerWorldUnit(feet), greaterThan(0));
    final renderedHeight = RenderMetrics.characterScale(camera, feet) *
        CourtDimensions.characterArtHeight;
    expect(renderedHeight, greaterThanOrEqualTo(720 * 0.035));
  });

  test('ball body never drops below the readable radius', () {
    final camera = PerspectiveCamera(
      position: Vec3(0, 230, 0),
      target: Vec3(0, 0, 0),
      up: Vec3(0, 0, -1),
      screenSize: const Size(1280, 720),
      fov: 60,
    )..prepareFrame();

    expect(
      RenderMetrics.ballRadius(camera, Vec3(0, 1, -80)),
      greaterThanOrEqualTo(RenderMetrics.minimumBallRadius),
    );
  });

  test('sprite facing responds to camera-relative movement', () {
    final camera = PerspectiveCamera(
      position: Vec3(120, 69, 0),
      target: Vec3(0, 7, 0),
      screenSize: const Size(1280, 720),
      fov: 60,
    )..prepareFrame();
    final player = Player(
      startPosition: Vec3(0, 0, 60),
      isHuman: true,
    )..velocity = Vec3(0, 0, -40);

    expect(
      SpriteCharacterRenderer.facingForCamera(player, camera),
      anyOf(SpriteFacing.left, SpriteFacing.right),
    );
  });
}
