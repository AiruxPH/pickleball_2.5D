import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/character_sprite_manager.dart';
import '../utils/game_math.dart';
import 'character_renderer.dart';

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
    final scale = cam.depthScale(player.position).clamp(0.28, 2.2);

    final pose = nearTeam ? _backViewPose(player) : _frontViewPose(player);
    final src = atlas.frameRect(pose.anim, pose.frame);
    if (src == null) return false;

    canvas.save();
    canvas.translate(screenPos.dx, screenPos.dy);
    canvas.scale(scale);

    // Ground shadows stay on the court (no lean / flip)
    final runWeight = player.runBlend.clamp(0.0, 1.0);
    final bob = runWeight * (math.sin(player.legCycleTimer * 2.0) * 0.5 + 0.5) * 1.6;
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
    canvas.drawImageRect(atlas.image, src, dst, isLowEnd ? _spritePaintLowEnd : _spritePaint);

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
  static _Pose _backViewPose(Player p) {
    if (p.isSwinging) return _swingPose(p);
    if (p.runBlend > 0.3) {
      return _Pose('backpedal', _strideFrame(p), 1.0, 0);
    }
    return const _Pose('idle', 1, 1.0, 0); // "Up" (back) idle
  }

  // ── Far team: front view ─────────────────────────────────────
  static _Pose _frontViewPose(Player p) {
    // The girl's action frames face screen-right; mirror when heading left.
    final flip = p.facingFlip >= 0 ? -1.0 : 1.0;

    if (p.isSwinging) return _swingPose(p);

    final vx = p.velocity.x, vz = p.velocity.z;
    final speed = math.sqrt(vx * vx + vz * vz);
    if (p.runBlend > 0.3 && speed > 4) {
      // Opponents stand at negative z: moving further away is a backpedal
      final anim = vz < -8 && vz.abs() > vx.abs()
          ? 'backpedal'
          : speed > 60
              ? 'run'
              : speed > 28
                  ? 'jog'
                  : 'walk';
      return _Pose(anim, _strideFrame(p), flip, 0);
    }

    // Idle loop at ~5 fps
    return _Pose('idle', (p.animTimer * 5).floor(), flip, 0);
  }
}

class _Pose {
  final String anim;
  final int frame;
  final double flip;
  final double twist;
  const _Pose(this.anim, this.frame, this.flip, this.twist);
}
