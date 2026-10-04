import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/vfx.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  PerspectiveCamera makeCam() {
    final cam = PerspectiveCamera(
      position: Vec3(6, 92, 170),
      target: Vec3(0, 6, -12),
      screenSize: const Size(390, 844),
    );
    cam.prepareFrame();
    return cam;
  }

  Offset applyMatrix(List<double> m, double u, double v) {
    final x = m[0] * u + m[4] * v + m[12];
    final y = m[1] * u + m[5] * v + m[13];
    final w = m[3] * u + m[7] * v + m[15];
    return Offset(x / w, y / w);
  }

  group('Perspective plane matrices', () {
    test('groundMatrix maps world (x, z) exactly like projectCoords', () {
      final cam = makeCam();
      final m = cam.groundMatrix();
      for (final p in const [
        [0.0, 0.0],
        [-40.0, -88.0],
        [40.0, 88.0],
        [12.5, -30.0],
        [-54.0, 109.0],
      ]) {
        final got = applyMatrix(m, p[0], p[1]);
        final expected = cam.projectCoords(p[0], 0, p[1])!;
        expect(got.dx, closeTo(expected.dx, 1e-6));
        expect(got.dy, closeTo(expected.dy, 1e-6));
      }
    });

    test('netPlaneMatrix maps world (x, y) on z = 0 like projectCoords', () {
      final cam = makeCam();
      final m = cam.netPlaneMatrix();
      for (final p in const [
        [0.0, 0.0],
        [-42.5, 3.0],
        [42.5, 0.0],
        [10.0, 2.83],
      ]) {
        final got = applyMatrix(m, p[0], p[1]);
        final expected = cam.projectCoords(p[0], p[1], 0)!;
        expect(got.dx, closeTo(expected.dx, 1e-6));
        expect(got.dy, closeTo(expected.dy, 1e-6));
      }
    });
  });

  group('VfxSystem', () {
    test('particles and marks spawn, age and expire', () {
      final vfx = VfxSystem();
      vfx.spawnHitSparks(Vec3(0, 10, 40), Colors.yellow, power: 1.0);
      vfx.spawnBounce(Vec3(5, 3, -30), Colors.white, 0.8);
      expect(vfx.particles, isNotEmpty);
      expect(vfx.marks, hasLength(1));

      for (int i = 0; i < 180; i++) {
        vfx.update(1 / 60);
      }
      expect(vfx.particles, isEmpty);
      expect(vfx.marks, isEmpty);
    });

    test('respects the particle cap and the disabled flag', () {
      final vfx = VfxSystem();
      for (int i = 0; i < 50; i++) {
        vfx.spawnHitSparks(Vec3(0, 10, 0), Colors.red, power: 1.0);
      }
      expect(vfx.particles.length, lessThanOrEqualTo(VfxSystem.maxParticles));

      vfx
        ..clear()
        ..enabled = false;
      vfx.spawnHitSparks(Vec3(0, 10, 0), Colors.red);
      expect(vfx.particles, isEmpty);
    });
  });

  group('Player facing', () {
    test('eases toward movement direction instead of snapping', () {
      final p = Player(startPosition: Vec3(0, 0, 60), isHuman: true);
      expect(p.facingFlip, 1.0);

      p.velocity.x = -40;
      p.updateFacing(1 / 60);
      expect(p.facingFlip, lessThan(1.0));
      expect(p.facingFlip, greaterThan(-1.0));

      for (int i = 0; i < 60; i++) {
        p.updateFacing(1 / 60);
      }
      expect(p.facingFlip, closeTo(-1.0, 0.01));

      // Standing still keeps the last facing (no pop back to default)
      p.velocity.x = 0;
      for (int i = 0; i < 30; i++) {
        p.updateFacing(1 / 60);
      }
      expect(p.facingFlip, closeTo(-1.0, 0.01));
    });
  });
}
