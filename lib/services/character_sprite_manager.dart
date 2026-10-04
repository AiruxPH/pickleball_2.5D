import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/character_renderer.dart';
import '../models/player.dart';

/// ─────────────────────────────────────────────────────────────
/// CharacterSpriteManager
///
/// Pre-loads, decodes, and manages high-definition 3D-stylized
/// sprites for the Human Player, AI Competitor, and Doubles Partner.
/// Provides articulated character rendering and movement on Canvas.
/// ─────────────────────────────────────────────────────────────
/// One packed animation atlas made by tool/extract_sprites.dart.
/// Rows are named animations with up to 4 frames each; every frame is
/// anchored at the feet (anchorX, anchorY) inside a fixed-size cell.
class SpriteAtlas {
  final ui.Image image;
  final double cellWidth;
  final double cellHeight;
  final double anchorX;
  final double anchorY;
  final double bodyHeight;
  final Map<String, ({int row, int frames})> rows;

  const SpriteAtlas({
    required this.image,
    required this.cellWidth,
    required this.cellHeight,
    required this.anchorX,
    required this.anchorY,
    required this.bodyHeight,
    required this.rows,
  });

  /// Source rect for [frame] of animation [name] (wraps around).
  Rect? frameRect(String name, int frame) {
    final r = rows[name];
    if (r == null || r.frames == 0) return null;
    final f = frame % r.frames;
    return Rect.fromLTWH(f * cellWidth, r.row * cellHeight, cellWidth, cellHeight);
  }

  static SpriteAtlas fromJson(ui.Image image, Map<String, dynamic> j) {
    final rows = <String, ({int row, int frames})>{};
    (j['rows'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      rows[k] = (row: m['row'] as int, frames: m['frames'] as int);
    });
    return SpriteAtlas(
      image: image,
      cellWidth: (j['cellWidth'] as num).toDouble(),
      cellHeight: (j['cellHeight'] as num).toDouble(),
      anchorX: (j['anchorX'] as num).toDouble(),
      anchorY: (j['anchorY'] as num).toDouble(),
      bodyHeight: (j['bodyHeight'] as num).toDouble(),
      rows: rows,
    );
  }
}

class CharacterSpriteManager {
  static final CharacterSpriteManager instance = CharacterSpriteManager._internal();

  CharacterSpriteManager._internal();

  ui.Image? _playerSprite;
  ui.Image? _aiRivalSprite;
  ui.Image? _partnerSprite;
  bool _isInitialized = false;

  // Animated court characters (from Character_sprite/)
  SpriteAtlas? _boyAtlas;
  SpriteAtlas? _girlAtlas;

  /// Your player (and doubles partner): the boy, seen from behind.
  SpriteAtlas? get boyAtlas => _boyAtlas;

  /// The opponent team: the girl, facing the camera.
  SpriteAtlas? get girlAtlas => _girlAtlas;

  Future<SpriteAtlas?> _loadAtlas(String base) async {
    try {
      final image = await _loadUiImage('$base.png');
      if (image == null) return null;
      final meta = jsonDecode(await rootBundle.loadString('$base.json'))
          as Map<String, dynamic>;
      return SpriteAtlas.fromJson(image, meta);
    } catch (e) {
      debugPrint('[CharacterSpriteManager] Error loading atlas $base: $e');
      return null;
    }
  }

  bool get isLoaded => _isInitialized && _playerSprite != null;
  ui.Image? get playerSprite => _playerSprite;
  ui.Image? get aiRivalSprite => _aiRivalSprite;
  ui.Image? get partnerSprite => _partnerSprite;

  /// Decode image asset into a hardware-backed ui.Image
  Future<ui.Image?> _loadUiImage(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('[CharacterSpriteManager] Error loading $assetPath: $e');
      return null;
    }
  }

  /// Initialize and decode all character sprites into GPU memory
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final results = await Future.wait([
        _loadUiImage('assets/images/characters/player_pro.png'),
        _loadUiImage('assets/images/characters/ai_rival.png'),
        _loadUiImage('assets/images/characters/partner_pro.png'),
      ]);

      _playerSprite = results[0];
      _aiRivalSprite = results[1];
      _partnerSprite = results[2];

      final atlases = await Future.wait([
        _loadAtlas('assets/images/characters/boy_atlas'),
        _loadAtlas('assets/images/characters/girl_atlas'),
      ]);
      _boyAtlas = atlases[0];
      _girlAtlas = atlases[1];

      _isInitialized = true;
      debugPrint('[CharacterSpriteManager] Successfully loaded character sprites.');
    } catch (e) {
      debugPrint('[CharacterSpriteManager] Initialization error: $e');
    }
  }

  /// Retrieve appropriate sprite based on player role
  ui.Image? getSpriteForPlayer(Player p) {
    if (p.isPartner) {
      return _partnerSprite ?? _playerSprite;
    }
    if (!p.isHuman) {
      return _aiRivalSprite ?? _playerSprite;
    }
    return _playerSprite;
  }

  /// Render stylized character with kinematic athletic locomotion and swing dynamics
  bool drawPlayerSprite({
    required Canvas canvas,
    required Player player,
    required double scale,
    required bool isLowEnd,
    required bool showShadow,
  }) {
    CharacterRenderer.drawPlayer(
      canvas: canvas,
      player: player,
      cam: null,
      isLowEnd: isLowEnd,
      showShadow: showShadow,
      manualScale: scale,
    );
    return true;
  }

  /// Dynamic swing speed arc effect
  static void drawSwingEffect(Canvas canvas, bool isAI, bool isForehand) {
    final arcPaint = Paint()
      ..color = isAI
          ? const Color(0x99FF5722)
          : const Color(0x9900E5FF)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final sweepX = isForehand ? 18.0 : -18.0;
    final arcRect = Rect.fromCenter(
      center: Offset(sweepX, -8),
      width: 44,
      height: 38,
    );

    canvas.drawArc(
      arcRect,
      isForehand ? -0.8 : math.pi - 0.8,
      1.8,
      false,
      arcPaint,
    );
  }
}
