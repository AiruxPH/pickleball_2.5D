import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/character_sprite_manager.dart';
import '../utils/game_math.dart';
import 'character_renderer.dart';
import '../models/shop_items.dart';
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
  static const double _feetY = 0.0;

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
    PlayerSkinItem? equippedSkin,
  }) {
    final nearTeam = player.isNearSide;
    final manager = CharacterSpriteManager.instance;

    // Equipped shop character (all unlocked skins; starter boy & girl use their full animated atlases)
    final skinKey = equippedSkin?.spriteKey;
    if (skinKey != null &&
        ((nearTeam && skinKey != 'sporty_boy') ||
            (!nearTeam && skinKey != 'sporty_girl'))) {
      final views = manager.shopViews(skinKey);
      if (views != null) {
        return _drawShopSkin(
            canvas, player, cam, views, isLowEnd, showShadow, skinKey);
      }
      // Still loading: fall through to the default atlas for a moment.
    }

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
    final idleWeight = 1.0 - runWeight;
    final runBob =
        runWeight * (math.sin(player.legCycleTimer * 2.0) * 0.5 + 0.5) * 1.8;
    // Rhythmic athletic ready-stance breathing & toe bounce
    final idleBob =
        idleWeight * (math.sin(player.animTimer * 3.2) * 0.5 + 0.5) * 1.4;
    final bob = runBob + idleBob;
    final idleSway = idleWeight * math.sin(player.animTimer * 1.8) * 0.02;

    if (showShadow) {
      CharacterRenderer.drawGroundShadows(canvas, !nearTeam, bob, isLowEnd);
    }

    canvas.translate(0, -bob);
    canvas.rotate(player.smoothedLean * 0.6 + pose.twist + idleSway);
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

  /// Draws a shop character from its static front/right/back/left views,
  /// with dedicated 5-frame hit animations from skill.png during swings.
  static bool _drawShopSkin(
    Canvas canvas,
    Player player,
    PerspectiveCamera cam,
    List<ui.Image> views,
    bool isLowEnd,
    bool showShadow,
    String skinKey,
  ) {
    final screenPos = cam.project(player.position);
    if (screenPos == null) return true;
    final scale = RenderMetrics.characterScale(cam, player.position);

    final runWeight = player.runBlend.clamp(0.0, 1.0);
    final idleWeight = 1.0 - runWeight;
    final stride = math.sin(player.legCycleTimer * 2.0);
    final runBob = runWeight * (stride * 0.5 + 0.5) * 3.2;
    final idleBob =
        idleWeight * (math.sin(player.animTimer * 3.2) * 0.5 + 0.5) * 2.0;
    final bob = runBob + idleBob;
    final sway =
        runWeight * stride * 0.05 + idleWeight * math.sin(player.animTimer * 1.8) * 0.025;

    // When swinging, render the character's dedicated 5-frame hit animation from skill.png
    if (player.isSwinging) {
      final hitAtlas = CharacterSpriteManager.instance.getHitAtlas(skinKey);
      if (hitAtlas != null) {
        final f = (player.swingArm.clamp(0.0, 0.999) * 5).floor();
        final anim = player.isForehand ? 'hit_right' : 'hit_left';
        final src = hitAtlas.frameRect(anim, f);
        if (src != null) {
          canvas.save();
          canvas.translate(screenPos.dx, screenPos.dy);
          canvas.scale(scale);

          if (showShadow) {
            CharacterRenderer.drawGroundShadows(
              canvas,
              !player.isNearSide,
              bob,
              isLowEnd,
            );
          }

          canvas.translate(0, -bob);
          canvas.rotate(player.smoothedLean * 0.6);

          final k = _bodyUnits / hitAtlas.bodyHeight;
          final dst = Rect.fromLTWH(
            -hitAtlas.anchorX * k,
            _feetY - hitAtlas.anchorY * k,
            hitAtlas.cellWidth * k,
            hitAtlas.cellHeight * k,
          );
          canvas.drawImageRect(
            hitAtlas.image,
            src,
            dst,
            isLowEnd ? _spritePaintLowEnd : _spritePaint,
          );

          canvas.restore();
          return true;
        }
      }
    }

    final facing = facingForCamera(player, cam);
    // views order: front, right, back, left
    final img = switch (facing) {
      SpriteFacing.front => views[0],
      SpriteFacing.right => views[1],
      SpriteFacing.back => views[2],
      SpriteFacing.left => views[3],
    };

    var swingTilt = 0.0;
    var swingStretch = 0.0;
    if (player.isSwinging) {
      final s = math.sin(player.swingArm.clamp(0.0, 1.0) * math.pi);
      swingTilt = s * 0.28 * (player.isForehand ? 1.0 : -1.0);
      swingStretch = s * 0.06;
    }

    canvas.save();
    canvas.translate(screenPos.dx, screenPos.dy);
    canvas.scale(scale);

    if (showShadow) {
      CharacterRenderer.drawGroundShadows(canvas, !player.isNearSide, bob, isLowEnd);
    }

    canvas.translate(0, -bob);
    canvas.rotate(player.smoothedLean * 0.6 + sway + swingTilt);

    // Scale image based on actual image height so all characters normalize to _bodyUnits
    final k = _bodyUnits / math.max(1, img.height) * (1.0 + swingStretch);
    final w = img.width * k, h = img.height * k;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-w / 2, _feetY - h, w, h),
      isLowEnd ? _spritePaintLowEnd : _spritePaint,
    );

    canvas.restore();
    return true;
  }

  /// Frame index for a 4-frame locomotion cycle driven by the stride timer.
  static int _strideFrame(Player p) =>
      ((p.legCycleTimer / (math.pi / 2)).floor()) % 4;

  /// 5-frame swing (Ready → Backswing → Swing → Contact → Follow Through).
  /// "hit_right" swings to the right and "hit_left" swings to the left as drawn in skill.png.
  static _Pose _swingPose(Player p) {
    final f = (p.swingArm.clamp(0.0, 0.999) * 5).floor();
    return p.isForehand
        ? _Pose('hit_right', f, 1.0, 0)
        : _Pose('hit_left', f, 1.0, 0);
  }

  // ── Near team: back view (swings use the sheet's swing animation) ─────
  // ── Far team: front view ─────────────────────────────────────
  static SpriteFacing facingForCamera(Player player, PerspectiveCamera cam) {
    var dx = player.velocity.x;
    var dz = player.velocity.z;
    final speed = math.sqrt(dx * dx + dz * dz);
    if (speed < 6) {
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
    if (screenDelta.dx.abs() > screenDelta.dy.abs() * 1.25) {
      return screenDelta.dx < 0 ? SpriteFacing.left : SpriteFacing.right;
    }
    return screenDelta.dy < 0 ? SpriteFacing.back : SpriteFacing.front;
  }

  static _Pose _poseFor(Player p, bool boyAtlas, SpriteFacing facing) {
    final horizontalFlip = facing == SpriteFacing.left ? -1.0 : 1.0;
    if (p.isSwinging) {
      final swing = _swingPose(p);
      return _Pose(swing.anim, swing.frame, swing.flip, 0);
    }

    final speed = math.sqrt(
      p.velocity.x * p.velocity.x + p.velocity.z * p.velocity.z,
    );
    if (p.runBlend > 0.25 && speed > 5) {
      final isBackpedal = p.isNearSide ? p.velocity.z > 8 : p.velocity.z < -8;
      final anim = isBackpedal
          ? 'backpedal'
          : speed > 65
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

    // girlAtlas: row 1 is 'idle' (4 animated frames)
    final idleFrame = ((p.animTimer * 4.0).floor()) % 4;
    return _Pose('idle', idleFrame, 1, 0);
  }
}

class _Pose {
  final String anim;
  final int frame;
  final double flip;
  final double twist;
  const _Pose(this.anim, this.frame, this.flip, this.twist);
}
