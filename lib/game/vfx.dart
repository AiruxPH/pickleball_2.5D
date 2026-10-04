import 'dart:math' as math;
import 'dart:ui';
import '../utils/game_math.dart';

/// ─────────────────────────────────────────────────────────────
/// VfxSystem — lightweight world-space particles & court marks
///
///   • Paddle-contact sparks (additive streaks)
///   • Court-bounce dust puffs + fading ball skid marks
///   • Net-cord puffs
///
/// Fixed-capacity, allocation-light, simulated in world units so the
/// effects sit correctly in the 3D scene and scale with perspective.
/// ─────────────────────────────────────────────────────────────

enum ParticleKind { spark, dust }

class Particle {
  double x, y, z;
  double vx, vy, vz;
  double life;
  final double maxLife;
  double size;
  final Color color;
  final ParticleKind kind;

  Particle({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.life,
    required this.size,
    required this.color,
    required this.kind,
  }) : maxLife = life;

  /// 1.0 when freshly spawned → 0.0 when expired.
  double get remaining => (life / maxLife).clamp(0.0, 1.0);
}

class CourtMark {
  final double x, z;
  double life;
  final double maxLife;
  final double strength;

  CourtMark({
    required this.x,
    required this.z,
    required this.life,
    required this.strength,
  }) : maxLife = life;

  double get remaining => (life / maxLife).clamp(0.0, 1.0);
}

class VfxSystem {
  static const int maxParticles = 160;
  static const int maxMarks = 6;

  final List<Particle> particles = [];
  final List<CourtMark> marks = [];
  final math.Random _rng = math.Random();

  /// Mirrors GameSettings.showParticles — nothing is spawned when false.
  bool enabled = true;

  void update(double dt) {
    if (particles.isNotEmpty) {
      final sparkDrag = math.exp(-2.2 * dt);
      final dustDrag = math.exp(-4.5 * dt);
      for (int i = particles.length - 1; i >= 0; i--) {
        final p = particles[i];
        p.life -= dt;
        if (p.life <= 0) {
          // swap-remove: order is irrelevant for rendering
          particles[i] = particles.last;
          particles.removeLast();
          continue;
        }

        if (p.kind == ParticleKind.spark) {
          p.vy -= 95.0 * dt;
          p.vx *= sparkDrag;
          p.vy *= sparkDrag;
          p.vz *= sparkDrag;
        } else {
          // Dust drifts up slightly, slows fast and billows outward
          p.vy += 6.0 * dt;
          p.vx *= dustDrag;
          p.vy *= dustDrag;
          p.vz *= dustDrag;
          p.size += dt * 5.5;
        }

        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.z += p.vz * dt;

        if (p.y < 0.15) {
          p.y = 0.15;
          p.vy = -p.vy * 0.25;
          p.vx *= 0.6;
          p.vz *= 0.6;
        }
      }
    }

    for (int i = marks.length - 1; i >= 0; i--) {
      marks[i].life -= dt;
      if (marks[i].life <= 0) marks.removeAt(i);
    }
  }

  void clear() {
    particles.clear();
    marks.clear();
  }

  double _range(double a, double b) => a + _rng.nextDouble() * (b - a);

  void _add(Particle p) {
    if (particles.length >= maxParticles) {
      // Recycle the oldest-looking slot rather than growing unbounded
      particles[_rng.nextInt(particles.length)] = p;
    } else {
      particles.add(p);
    }
  }

  /// Bright contact sparks where the paddle meets the ball.
  /// [dirZ] is the outgoing ball direction along Z (-1 = toward far court).
  void spawnHitSparks(Vec3 at, Color color,
      {double power = 0.5, double dirZ = -1.0}) {
    if (!enabled) return;
    final count = (7 + power * 14).round();
    for (int i = 0; i < count; i++) {
      final ang = _range(0, math.pi * 2);
      final spread = _range(0.25, 1.0);
      final speed = _range(35, 85) * (0.6 + power * 0.8);
      _add(Particle(
        x: at.x,
        y: at.y,
        z: at.z,
        vx: math.cos(ang) * speed * spread,
        vy: math.sin(ang).abs() * speed * 0.7 + 10,
        vz: dirZ * speed * _range(0.3, 0.9) + math.sin(ang) * speed * 0.3,
        life: _range(0.18, 0.42),
        size: _range(0.5, 1.1),
        color: i.isEven ? color : const Color(0xFFFFFFFF),
        kind: ParticleKind.spark,
      ));
    }
  }

  /// Dust puff + a fading skid mark where the ball meets the court.
  void spawnBounce(Vec3 at, Color dustColor, double intensity) {
    if (!enabled) return;
    final k = intensity.clamp(0.0, 1.0);
    if (k < 0.08) return;

    marks.add(CourtMark(x: at.x, z: at.z, life: 1.6, strength: k));
    while (marks.length > maxMarks) {
      marks.removeAt(0);
    }

    final count = (3 + k * 6).round();
    for (int i = 0; i < count; i++) {
      final ang = _range(0, math.pi * 2);
      final speed = _range(6, 18) * (0.5 + k);
      _add(Particle(
        x: at.x + math.cos(ang) * 0.6,
        y: 0.4,
        z: at.z + math.sin(ang) * 0.6,
        vx: math.cos(ang) * speed,
        vy: _range(2, 7),
        vz: math.sin(ang) * speed,
        life: _range(0.35, 0.7),
        size: _range(1.2, 2.2),
        color: dustColor,
        kind: ParticleKind.dust,
      ));
    }
  }

  /// Small puff of fibres when the ball clips the net.
  void spawnNetPuff(Vec3 at) {
    if (!enabled) return;
    for (int i = 0; i < 6; i++) {
      final ang = _range(0, math.pi * 2);
      final speed = _range(5, 14);
      _add(Particle(
        x: at.x,
        y: at.y,
        z: at.z,
        vx: math.cos(ang) * speed,
        vy: math.sin(ang).abs() * speed,
        vz: _range(-4, 4),
        life: _range(0.3, 0.55),
        size: _range(0.8, 1.4),
        color: const Color(0xFFE2E8F0),
        kind: ParticleKind.dust,
      ));
    }
  }
}
