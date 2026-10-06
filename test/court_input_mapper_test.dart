import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/court_input_mapper.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  PerspectiveCamera camera(Vec3 position, Vec3 target) => PerspectiveCamera(
        position: position,
        target: target,
        screenSize: const Size(1280, 720),
        fov: 55,
      )..prepareFrame();

  test('screen-right maps naturally for each baseline camera', () {
    final nearMapper = CourtInputMapper(
      camera(Vec3(0, 68, 160), Vec3(0, 6, -6)),
    );
    final farMapper = CourtInputMapper(
      camera(Vec3(0, 68, -160), Vec3(0, 6, 6)),
    );
    const center = Offset(640, 360);
    const right = Offset(720, 360);

    final near = nearMapper.commandAxesFromScreenDrag(
      origin: center,
      current: right,
      farSide: false,
    )!;
    final far = farMapper.commandAxesFromScreenDrag(
      origin: center,
      current: right,
      farSide: true,
    )!;

    expect(near.dx, greaterThan(0.99));
    expect(far.dx, lessThan(-0.99));
  });

  test('screen-up maps toward the net for both player command spaces', () {
    final nearMapper = CourtInputMapper(
      camera(Vec3(0, 68, 160), Vec3(0, 6, -6)),
    );
    final farMapper = CourtInputMapper(
      camera(Vec3(0, 68, -160), Vec3(0, 6, 6)),
    );
    const center = Offset(640, 360);
    const up = Offset(640, 280);

    final near = nearMapper.commandAxesFromScreenDrag(
      origin: center,
      current: up,
      farSide: false,
    )!;
    final far = farMapper.commandAxesFromScreenDrag(
      origin: center,
      current: up,
      farSide: true,
    )!;

    expect(near.dy, lessThan(-0.99));
    expect(far.dy, lessThan(-0.99));
  });

  test('normalized input preserves analog magnitude', () {
    final mapper = CourtInputMapper(
      camera(Vec3(0, 68, 160), Vec3(0, 6, -6)),
    );
    final axes = mapper.commandAxesFromNormalizedScreenVector(
      const Offset(0.3, 0),
      farSide: false,
    )!;
    expect(axes.distance, closeTo(0.3, 1e-6));
  });
}
