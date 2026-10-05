import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/character_sprite_manager.dart';
import '../utils/game_math.dart';
import 'character_renderer.dart';
import 'render_metrics.dart';

enum SpriteFacing { front, back, left, right }

/// ─────────────────────────────────────────────────────────────
/// SpriteCharacterRenderer
///
/// Draws the court athletes from the animated sprite atlases in
/// assets/images/characters/ (built from Character_sprite/):
///
///   • Your team (near side)  → the boy, seen from behind.
///     Back-view idle + backpedal cycle.
///   • Opponents (far side)    → the girl, facing the camera, with the
///     full idle / walk / jog / run / backpedal set.
///   • Both swing with the 5-frame Hit Left / Hit Right animations
///     (Ready, Backswing, Swing, Contact, Follow Through).
///
/// Returns false when the atlases are not loaded yet so the caller can
/// fall back to the procedural CharacterRenderer.
/// ─────────────────────────────────────────────────────────────
class SpriteCharacterRenderer {
  /// Sprite height in the same local units the procedural athlete uses
  /// (head top ≈ -48, feet ≈ +34 at depth scale 1).
  static const double _bodyUnits = 84.0;
  static const double _feetY = 34.0;

  static final Paint _spritePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  static final Paint _spritePaintLowEnd = Paint()
    ..filterQuality = FilterQuality.low
    ..isAntiAlias = false;

  static bool drawPlayer({
    required Canvas canvas,
    required Player player,
    required PerspectiveCamera cam,
    required bool isLowEnd,
    required bool showShadow,
  }) {
    final nearTeam = player.isNearSide;
    final manager = CharacterSpriteManager.instance;
    final atlas = nearTeam ? manager.boyAtlas : manager.girlAtlas;
    if (atlas == null) return false;

    final screenPos = cam.project(player.position);
    if (screenPos == null) return true; // behind camera: nothing to draw
    final scale = RenderMetrics.characterScale(cam, player.position);

    final facing = facingForCamera(player, cam);
    final pose = _poseFor(player, nearTeam, facing);
    final src = atlas.frameRect(pose.anim, pose.frame);
    if (src == null) return false;

    canvas.save();
    canvas.translate(screenPos.dx, screenPos.dy);
    canvas.scale(scale);

    // Ground shadows stay on the court (no lean / flip)
    final runWeight = player.runBlend.clamp(0.0, 1.0);
    final bob =
        runWeight * (math.sin(player.legCycleTimer * 2.0) * 0.5 + 0.5) * 1.6;
    if (showShadow) {
      CharacterRenderer.drawGroundShadows(canvas, !nearTeam, bob, isLowEnd);
    }

    canvas.translate(0, -bob);
    canvas.rotate(player.smoothedLean * 0.6 + pose.twist);
    canvas.scale(pose.flip, 1.0);

    final k = _bodyUnits / atlas.bodyHeight;
    final dst = Rect.fromLTWH(
      -atlas.anchorX * k,
      _feetY - atlas.anchorY * k,
      atlas.cellWidth * k,
      atlas.cellHeight * k,
    );
    canvas.drawImageRect(
        atlas.image, src, dst, isLowEnd ? _spritePaintLowEnd : _spritePaint);

    canvas.restore();
    return true;
  }

  /// Frame index for a 4-frame locomotion cycle driven by the stride timer.
  static int _strideFrame(Player p) =>
      ((p.legCycleTimer / (math.pi / 2)).floor()) % 4;

  /// 5-frame swing (Ready → Backswing → Swing → Contact → Follow Through).
  /// Both sheet sequences make contact on the screen-right side, so a hit on
  /// the right plays "hit_right" as drawn and a hit on the left plays
  /// "hit_left" mirrored.
  static _Pose _swingPose(Player p) {
    final f = (p.swingArm.clamp(0.0, 0.999) * 5).floor();
    return p.isForehand
        ? _Pose('hit_right', f, 1.0, 0)
        : _Pose('hit_left', f, -1.0, 0);
  }

  // ── Near team: back view (swings use the sheet's swing animation) ─────
  // ── Far team: front view ─────────────────────────────────────
  static SpriteFacing facingForCamera(Player player, PerspectiveCamera cam) {
    var dx = player.velocity.x;
    var dz = player.velocity.z;
    if (math.sqrt(dx * dx + dz * dz) < 4) {
      dx = 0;
      dz = player.isNearSide ? -1 : 1;
    }

    final feet = cam.project(player.position);
    final ahead = cam.projectCoords(
      player.position.x + dx,
      player.position.y,
      player.position.z + dz,
    );
    if (feet == null || ahead == null) {
      return player.isNearSide ? SpriteFacing.back : SpriteFacing.front;
    }
    final screenDelta = ahead - feet;
    if (screenDelta.dx.abs() > screenDelta.dy.abs()) {
      return screenDelta.dx < 0 ? SpriteFacing.left : SpriteFacing.right;
    }
    return screenDelta.dy < 0 ? SpriteFacing.back : SpriteFacing.front;
  }

  static _Pose _poseFor(Player p, bool boyAtlas, SpriteFacing facing) {
    final horizontalFlip = facing == SpriteFacing.left ? -1.0 : 1.0;
    if (p.isSwinging) {
      final swing = _swingPose(p);
      return _Pose(swing.anim, swing.frame, swing.flip * horizontalFlip, 0);
    }

    final speed = math.sqrt(
      p.velocity.x * p.velocity.x + p.velocity.z * p.velocity.z,
    );
    if (p.runBlend > 0.3 && speed > 4) {
      final anim = speed > 60
          ? 'run'
          : speed > 28
              ? 'jog'
              : 'walk';
      return _Pose(anim, _strideFrame(p), horizontalFlip, 0);
    }

    if (boyAtlas) {
      final frame = switch (facing) {
        SpriteFacing.front => 0,
        SpriteFacing.back => 1,
        SpriteFacing.left => 2,
        SpriteFacing.right => 3,
      };
      return _Pose('idle', frame, 1, 0);
    }

    final frame = switch (facing) {
      SpriteFacing.front => 0,
      SpriteFacing.right => 1,
      SpriteFacing.back => 2,
      SpriteFacing.left => 3,
    };
    return _Pose('turnaround', frame, 1, 0);
  }
}

class _Pose {
  final String anim;
  final int frame;
  final double flip;
  final double twist;
  const _Pose(this.anim, this.frame, this.flip, this.twist);
}
