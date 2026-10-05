import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/pickleball_game.dart';
import '../game/game_presentation.dart';
import '../models/game_settings.dart';
import '../models/pickleball.dart';
import '../models/player.dart';
import '../models/ultimate_skill.dart';
import 'character_renderer.dart';
import 'sprite_character_renderer.dart';
import 'vfx.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';

/// ─────────────────────────────────────────────────────────────
/// CourtPainter — High-End Professional Tournament 3D Court Renderer
///
/// Styled after TV sports broadcasts.
/// Renders:
///   1. Arena stadium atmosphere (grandstands, realistic crowd, floodlights)
///   2. 3D perimeter digital LED barrier boards
///   3. Perspective-correct court: surface, kitchens and regulation lines are
///      drawn directly on the ground plane (true foreshortening), lit by
///      floodlight pools with a glossy acrylic sheen and distance haze
///   4. Translucent regulation mesh net with tape, center strap & metal posts
///   5. Pro athletic player characters with volumetric shading
///   6. Optic-yellow ball with 3D rotating perforations & motion blur
///   7. World-space particles (hit sparks, bounce dust, skid marks)
///   8. Camera shake, light shafts & vignette for a broadcast look
/// ─────────────────────────────────────────────────────────────

class CourtPainter extends CustomPainter {
  final PickleballGame game;
  final GamePresentation presentation;
  final double? animTimeOverride;

  double get animTime => animTimeOverride ?? presentation.animTime;

  CourtPainter({
    required this.game,
    required this.presentation,
    this.animTimeOverride,
    super.repaint,
  });

  // ── Cached screen-space atmosphere overlay (vignette, light shafts) ──
  static ui.Picture? _cachedAtmoPicture;
  static Size? _cachedAtmoSize;
  static CourtTheme? _cachedAtmoTheme;

  // ── Cached Paint objects (allocated once, reused every frame) ──
  static final Paint _railingFillPaint = Paint()
    ..color = const Color(0x660F172A);
  static final Paint _railingLinePaint = Paint()
    ..color = const Color(0x8894A3B8)
    ..strokeWidth = 1.5;

  // ── Performance Mode Cached Flat Paints (zero shader creation per frame) ──
  static final Paint _fastSideBarrierPaint = Paint()
    ..color = const Color(0xFF0F1E36);
  static final Paint _fastBackBoardPaint = Paint()
    ..color = const Color(0xFF0F172A);
  static final Paint _reusableCourtPaint = Paint();
  static final Paint _reusableStrokePaint = Paint();
  static final Paint _courtLinePaint = Paint();
  static final Paint _fastBallPaint = Paint()..color = const Color(0xFFE6F05A);
  static final Paint _fastBallGlintPaint = Paint()
    ..color = const Color(0xCCFFFFFF);
  static final Paint _fastNetPostPaint = Paint()
    ..color = const Color(0xFF475569);
  static final Paint _fastNetPostCapPaint = Paint()
    ..color = const Color(0xFF1E293B);
  static final Paint _ledTrimPaint = Paint()..strokeCap = StrokeCap.round;
  static final Paint _mountRailPaint = Paint()
    ..color = const Color(0xFF334155)
    ..strokeWidth = 1.5;
  static final Paint _stanchionPaint = Paint()
    ..color = const Color(0xFF64748B)
    ..strokeWidth = 2.0;
  static final Paint _fastFlashRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _msgBackdropPaint = Paint();
  static final Paint _msgBorderPaint = Paint()
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  static final Paint _ultimateEffectPaint = Paint();
  static final Paint _ultimateEffectStrokePaint = Paint()
    ..style = PaintingStyle.stroke;
  static final Paint _frostZonePaint = Paint();
  static final Paint _frostRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;
  static final Paint _frostSpikePaint = Paint()..strokeWidth = 0.4;
  static final Paint _ghostClonePaint = Paint();
  static final Paint _ghostRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _ultimateVignettePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;
  static final Paint _serveGuidePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _serveTargetPaint = Paint();
  UltimateType? _cachedCutInType;
  TextPainter? _cachedCutInTitle;
  TextPainter? _cachedCutInSubtitle;

  // ── Pre-compiled static net paths (computed once, reused across all frames) ──
  static final Path _staticNetBody = _buildStaticNetBody();
  static final Path _staticNetTape = _buildStaticNetTape();
  static final Path _staticNetTapeEdge = _buildStaticNetTapeEdge();
  static final Path _staticNetMeshMedium = _buildStaticNetMesh(1.8, 3);
  static final Path _staticNetMeshHigh = _buildStaticNetMesh(0.9, 6);

  static double _sagY(double x) {
    const netPostH = CourtDimensions.netHeight;
    const hw = CourtDimensions.halfWidth;
    final t = ((x + hw) / (2 * hw)).clamp(0.0, 1.0);
    return netPostH * (1.0 - math.sin(t * math.pi) * 0.056);
  }

  static List<Offset> _buildStaticNetTopEdge() {
    const netPostH = CourtDimensions.netHeight;
    const hw = CourtDimensions.halfWidth;
    const postX = hw + 2.5;
    const samples = 24;
    final topEdge = <Offset>[const Offset(-postX, netPostH)];
    for (int i = 0; i <= samples; i++) {
      final x = -hw + (i / samples) * 2 * hw;
      topEdge.add(Offset(x, _sagY(x)));
    }
    topEdge.add(const Offset(postX, netPostH));
    return topEdge;
  }

  static Path _buildStaticNetBody() {
    const hw = CourtDimensions.halfWidth;
    const postX = hw + 2.5;
    final topEdge = _buildStaticNetTopEdge();
    final body = Path()..moveTo(-postX, 0);
    for (final p in topEdge) {
      body.lineTo(p.dx, p.dy);
    }
    body
      ..lineTo(postX, 0)
      ..close();
    return body;
  }

  static Path _buildStaticNetTape() {
    final topEdge = _buildStaticNetTopEdge();
    final tape = Path()..moveTo(topEdge.first.dx, topEdge.first.dy + 0.1);
    for (final p in topEdge) {
      tape.lineTo(p.dx, p.dy + 0.1);
    }
    for (final p in topEdge.reversed) {
      tape.lineTo(p.dx, p.dy - 0.42);
    }
    tape.close();
    return tape;
  }

  static Path _buildStaticNetTapeEdge() {
    final topEdge = _buildStaticNetTopEdge();
    final tapeEdge = Path()..moveTo(topEdge.first.dx, topEdge.first.dy - 0.42);
    for (final p in topEdge) {
      tapeEdge.lineTo(p.dx, p.dy - 0.42);
    }
    return tapeEdge;
  }

  static Path _buildStaticNetMesh(double spacing, int rows) {
    const hw = CourtDimensions.halfWidth;
    const postX = hw + 2.5;
    final topEdge = _buildStaticNetTopEdge();
    final mesh = Path();
    for (double x = -postX + spacing; x < postX; x += spacing) {
      mesh
        ..moveTo(x, 0)
        ..lineTo(x, _sagY(x));
    }
    for (int j = 1; j < rows; j++) {
      final frac = j / rows;
      mesh.moveTo(topEdge.first.dx, topEdge.first.dy * frac);
      for (final p in topEdge) {
        mesh.lineTo(p.dx, p.dy * frac);
      }
    }
    return mesh;
  }

  // ── Net (drawn in net-plane world units) ──
  static final Paint _netBodyPaint = Paint()..color = const Color(0x3A0B1220);
  static final Paint _netMeshPaint = Paint()
    ..color = const Color(0x800F172A)
    ..strokeWidth = 0.12
    ..style = PaintingStyle.stroke;
  static final Paint _netTapePaint = Paint()..color = const Color(0xFFF8FAFC);
  static final Paint _netTapeEdgePaint = Paint()
    ..color = const Color(0xFF94A3B8)
    ..strokeWidth = 0.08
    ..style = PaintingStyle.stroke;
  static final Paint _netCordPaint = Paint()
    ..color = const Color(0xCC0F172A)
    ..strokeWidth = 0.14
    ..style = PaintingStyle.stroke;
  static final Paint _strapPaint = Paint()..color = const Color(0xFFF1F5F9);
  static final Paint _strapBucklePaint = Paint()
    ..color = const Color(0xFF475569);

  // ── Ball ──
  static final Paint _ballEdgePaint = Paint()
    ..color = const Color(0x44000000)
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;
  final Paint _holePaint = Paint();
  final Paint _sparkPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final Paint _dustPaint = Paint();

  /// Perforation directions on a unit sphere (flattened xyz), Fibonacci layout.
  static final List<double> _holeDirs = _buildHoleDirs();
  static List<double> _buildHoleDirs() {
    const n = 26;
    final out = <double>[];
    final golden = math.pi * (3 - math.sqrt(5));
    for (int i = 0; i < n; i++) {
      final y = 1 - (i / (n - 1)) * 2;
      final r = math.sqrt(math.max(0.0, 1 - y * y));
      final th = golden * i;
      out
        ..add(math.cos(th) * r)
        ..add(y)
        ..add(math.sin(th) * r);
    }
    return out;
  }

  // ── Cached TextPainter for static court branding (laid out once per size) ──
  TextPainter? _courtBrandingPainter;
  double _lastBoardWidth = -1;
  CourtTheme? _lastBoardTheme;

  // ── Cached TextPainter for the apron floor decal ──
  static TextPainter? _decalPainter;
  static CourtTheme? _decalTheme;
  static double _decalFontSize = -1;

  // ── Cached TextPainter for broadcast messages ──
  static TextPainter? _cachedMsgPainter;
  static String? _cachedMsgText;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = presentation.camera;
    cam.screenSize = size;
    cam.prepareFrame();

    // 1. Arena atmosphere & grandstands (distant backdrop — not shaken)
    _drawEnvironment(canvas, size, cam);

    // ── World layer (receives camera shake) ─────────────────────
    canvas.save();
    _applyCameraShake(canvas, size);

    // 2. Perspective ground pass: surface, lighting, lines, marks, shadows
    _drawCourt(canvas, size, cam);
    _drawServeGuide(canvas, cam);

    // 3. Opponent players (far side, behind net)
    _drawPlayer(canvas, cam, game.ai);
    if (game.aiPartner != null) {
      _drawPlayer(canvas, cam, game.aiPartner!);
    }

    // 5. Ball on the far side is seen *through* the translucent net
    final ballFarSide = game.ball.position.z < 0;
    if (ballFarSide) _drawBallLayer(canvas, cam);

    // 6. Regulation net with center strap & realistic sag
    _drawNet(canvas, cam);

    // 7. Near side team players (human + partner, sorted by depth)
    if (game.playerPartner != null) {
      if (game.player.position.z > game.playerPartner!.position.z) {
        _drawPlayer(canvas, cam, game.playerPartner!);
        _drawPlayer(canvas, cam, game.player);
      } else {
        _drawPlayer(canvas, cam, game.player);
        _drawPlayer(canvas, cam, game.playerPartner!);
      }
    } else {
      _drawPlayer(canvas, cam, game.player);
    }

    // 8. Ball on the near side, then airborne particles on top
    if (!ballFarSide) _drawBallLayer(canvas, cam);
    _drawParticles(canvas, cam);

    canvas.restore();

    // 9. Lens / atmosphere: light shafts & vignette
    if (!game.settings.isLowEndMode) {
      _drawAtmosphere(canvas, size);
    }

    // 10. Screen effects: Ultimate vignette glow & cinematic cut-in banner
    if (game.isUltimateArmed) {
      _drawUltimateVignette(canvas, size);
    }
    if (game.ultimateCutinTimer > 0 && game.activeCutinUltimate != null) {
      _drawUltimateCutIn(canvas, size);
    }

    // 11. Broadcast on-screen messages
    _drawMessage(canvas, size);
  }

  /// Trail, ghost clones, ball and contact flash, drawn as one depth layer.
  void _drawBallLayer(Canvas canvas, PerspectiveCamera cam) {
    if (game.settings.showBallTrail) {
      _drawBallTrail(canvas, cam);
    }
    if (game.ball.isUltimate &&
        game.ball.ultimateType == UltimateType.ghostPhantom &&
        !game.settings.isLowEndMode) {
      _drawGhostClones(canvas, cam);
    }
    _drawBall(canvas, cam);
    _drawImpactFlash(canvas, cam);
  }

  void _drawServeGuide(Canvas canvas, PerspectiveCamera cam) {
    if (game.state != GameState.waitingForServe ||
        !game.isHumanServing ||
        !identical(game.activeServer, game.player)) {
      return;
    }

    final trajectory = game.getPlayerServeTrajectory(
      samples: game.settings.useReducedUltimateEffects ? 16 : 24,
    );
    final guideColor =
        trajectory.isLegal ? const Color(0xFF22D3EE) : const Color(0xFFFB7185);
    final minX = trajectory.serverOnRight ? -CourtDimensions.halfWidth : 0.0;
    final maxX = trajectory.serverOnRight ? 0.0 : CourtDimensions.halfWidth;
    const nearZ =
        -CourtDimensions.kitchenDepth - CourtDimensions.lineWidth * 0.5;
    const farZ = -CourtDimensions.halfLength;
    final corners = <Offset>[];
    for (final point in <Vec3>[
      Vec3(minX, 0.08, nearZ),
      Vec3(maxX, 0.08, nearZ),
      Vec3(maxX, 0.08, farZ),
      Vec3(minX, 0.08, farZ),
    ]) {
      final projected = cam.project(point);
      if (projected == null) return;
      corners.add(projected);
    }

    final targetPath = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (int i = 1; i < corners.length; i++) {
      targetPath.lineTo(corners[i].dx, corners[i].dy);
    }
    targetPath.close();
    canvas.drawPath(
      targetPath,
      _serveTargetPaint
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = guideColor.withAlpha(20),
    );
    canvas.drawPath(
      targetPath,
      _serveGuidePaint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = guideColor.withAlpha(150),
    );

    final projectedPoints = <Offset>[];
    for (final point in trajectory.points) {
      final projected = cam.project(point);
      if (projected != null) projectedPoints.add(projected);
    }
    if (projectedPoints.length < 2) return;

    final arc = Path()
      ..moveTo(projectedPoints.first.dx, projectedPoints.first.dy);
    for (int i = 1; i < projectedPoints.length; i++) {
      arc.lineTo(projectedPoints[i].dx, projectedPoints[i].dy);
    }
    if (!game.settings.useReducedUltimateEffects) {
      canvas.drawPath(
        arc,
        _serveGuidePaint
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = guideColor.withAlpha(34),
      );
    }
    canvas.drawPath(
      arc,
      _serveGuidePaint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = guideColor.withAlpha(220),
    );

    final beadIndex = ((animTime * 12).floor() % projectedPoints.length);
    canvas.drawCircle(
      projectedPoints[beadIndex],
      3.4,
      _serveTargetPaint
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = Colors.white,
    );
    final target = cam.project(
      Vec3(trajectory.targetX, 0.1, trajectory.targetZ),
    );
    if (target != null) {
      canvas.drawCircle(
        target,
        7,
        _serveGuidePaint
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = guideColor,
      );
      canvas.drawCircle(
        target,
        2.5,
        _serveTargetPaint
          ..shader = null
          ..style = PaintingStyle.fill
          ..color = guideColor,
      );
    }
  }

  /// Smooth multi-frequency shake (no random jitter → no strobing).
  void _applyCameraShake(Canvas canvas, Size size) {
    final s = presentation.screenShake;
    if (s <= 0.001) return;
    final amp = s * s * 10.0;
    final t = animTime;
    final dx =
        (math.sin(t * 53.0) + 0.6 * math.sin(t * 31.0 + 1.3)) / 1.6 * amp;
    final dy =
        (math.cos(t * 47.0) + 0.6 * math.sin(t * 27.0 + 0.7)) / 1.6 * amp;
    final rot = math.sin(t * 23.0) * s * s * 0.006;
    canvas.translate(size.width / 2 + dx, size.height / 2 + dy);
    canvas.rotate(rot);
    canvas.translate(-size.width / 2, -size.height / 2);
  }

  // ────────────────────────────────────────────────────────────
  // 1. Arena Atmosphere & Grandstands (Cached via ui.Picture for 60 FPS performance)
  // ────────────────────────────────────────────────────────────
  void _drawEnvironment(Canvas canvas, Size size, PerspectiveCamera cam) {
    // When using custom court background artwork, the environment is rendered
    // via high-performance hardware-accelerated Image.asset in the widget stack
    // behind the canvas, preserving 60 FPS performance without covering the art.
    if (kAlwaysFalseFallback) {
      _renderEnvironmentToCanvas(canvas, size, game.settings.courtTheme);
      _renderGymEnvironment(canvas, size, 0, game.settings.courtTheme);
      _drawPerimeterBoards(canvas, cam);
    }
  }

  static const bool kAlwaysFalseFallback = false;

  void _renderEnvironmentToCanvas(Canvas canvas, Size size, CourtTheme theme) {
    final horizon = size.height * CameraConstants.horizonFraction;

    if (theme == CourtTheme.outdoor) {
      _renderOutdoorParkEnvironment(canvas, size, horizon, theme);
    } else if (theme == CourtTheme.beach) {
      _renderBeachEnvironment(canvas, size, horizon, theme);
    } else {
      _renderStadiumEnvironment(canvas, size, horizon, theme);
    }
  }

  // ── A. Professional Tournament Stadium Environment (Center Court & Indoor Arena) ──
  void _renderStadiumEnvironment(
      Canvas canvas, Size size, double horizon, CourtTheme theme) {
    // 1. Stadium evening atmosphere gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF040711), // High arena ceiling
          theme.skyColor, // Mid arena atmosphere
          const Color(0xFF14243B), // Low horizon lighting
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon + 20));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 2. Structural Steel Roof Trusses (architectural arena gantry)
    final trussPaint = Paint()
      ..color = const Color(0x3064748B)
      ..strokeWidth = 1.6;
    final trussThinPaint = Paint()
      ..color = const Color(0x1F94A3B8)
      ..strokeWidth = 1.0;

    final gantryY1 = horizon * 0.08;
    final gantryY2 = horizon * 0.17;
    canvas.drawLine(
        Offset(0, gantryY1), Offset(size.width, gantryY1), trussPaint);
    canvas.drawLine(
        Offset(0, gantryY2), Offset(size.width, gantryY2), trussPaint);

    const trussBays = 24;
    final bayWidth = size.width / trussBays;
    for (int b = 0; b < trussBays; b++) {
      final xA = b * bayWidth;
      final xB = (b + 1) * bayWidth;
      canvas.drawLine(
          Offset(xA, gantryY1), Offset(xB, gantryY2), trussThinPaint);
      canvas.drawLine(
          Offset(xB, gantryY1), Offset(xA, gantryY2), trussThinPaint);
      canvas.drawLine(
          Offset(xA, gantryY1), Offset(xA, gantryY2), trussThinPaint);
    }

    // 3. Stadium Floodlight Banks (4 high-output LED arrays)
    _drawFloodlight(canvas, size.width * 0.08, horizon * 0.22, true);
    _drawFloodlight(canvas, size.width * 0.32, horizon * 0.19, true);
    _drawFloodlight(canvas, size.width * 0.68, horizon * 0.19, false);
    _drawFloodlight(canvas, size.width * 0.92, horizon * 0.22, false);

    // 4. Tiered Concrete Grandstand Bowl (5 architectural tiers)
    const tierCount = 5;
    final grandstandTop = horizon * 0.23;
    final grandstandHeight = horizon - grandstandTop;

    for (int tier = 0; tier < tierCount; tier++) {
      final t = tier / tierCount;
      final tierY = grandstandTop + t * grandstandHeight;
      final tierH = grandstandHeight / tierCount;

      final tierColor =
          tier.isEven ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
      canvas.drawRect(
        Rect.fromLTRB(0, tierY, size.width, tierY + tierH),
        Paint()..color = tierColor,
      );

      // Steel step ledge highlight
      canvas.drawLine(
        Offset(0, tierY + 0.8),
        Offset(size.width, tierY + 0.8),
        Paint()
          ..color = const Color(0x4094A3B8)
          ..strokeWidth = 1.0,
      );

      // Concourse Vomitories (illuminated entryway tunnels)
      if (tier == 2 || tier == 3) {
        for (int v = 1; v <= 3; v++) {
          final vx = size.width * (v * 0.25);
          final portalRect = Rect.fromCenter(
            center: Offset(vx, tierY + tierH * 0.5),
            width: 18,
            height: tierH * 0.85,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(portalRect, const Radius.circular(3)),
            Paint()..color = const Color(0xFF020617),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(portalRect.left + 2, portalRect.top + 2,
                  portalRect.width - 4, portalRect.height - 4),
              const Radius.circular(2),
            ),
            Paint()..color = const Color(0x35FBBF24),
          );
        }
      }

      // Natural clustered tournament crowd
      _drawCrowdRow(canvas, size.width, tierY + tierH * 0.42, tier);
    }

    // 5. Grandstand Lower Ribbon LED Display Board
    const ribbonH = 8.0;
    final ribbonY = horizon - ribbonH - 3;
    canvas.drawRect(
      Rect.fromLTRB(0, ribbonY, size.width, horizon - 3),
      Paint()..color = const Color(0xFF020617),
    );
    canvas.drawLine(
        Offset(0, ribbonY),
        Offset(size.width, ribbonY),
        Paint()
          ..color = theme.ledAccentColor.withAlpha(160)
          ..strokeWidth = 1.2);
    canvas.drawLine(
        Offset(0, horizon - 3),
        Offset(size.width, horizon - 3),
        Paint()
          ..color = theme.ledAccentColor.withAlpha(100)
          ..strokeWidth = 1.0);

    // 6. Lower Glass Safety Barrier Railing
    canvas.drawRect(
      Rect.fromLTRB(0, horizon - 2, size.width, horizon + 6),
      _railingFillPaint,
    );
    canvas.drawLine(
      Offset(0, horizon - 2),
      Offset(size.width, horizon - 2),
      _railingLinePaint,
    );
  }

  // ── B. Natural Daytime Outdoor Park Environment ─────────────
  void _renderOutdoorParkEnvironment(
      Canvas canvas, Size size, double horizon, CourtTheme theme) {
    // 1. Natural daylight sunny sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0284C7), // High daytime sky
          Color(0xFF38BDF8), // Mid atmosphere
          Color(0xFFBAE6FD), // Low horizon haze
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon + 10));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 2. Soft procedural cumulus clouds
    final cloudPaint = Paint()..color = const Color(0x40FFFFFF);
    void drawCloud(double cx, double cy, double scale) {
      canvas.drawCircle(Offset(cx, cy), 16 * scale, cloudPaint);
      canvas.drawCircle(
          Offset(cx - 14 * scale, cy + 3 * scale), 12 * scale, cloudPaint);
      canvas.drawCircle(
          Offset(cx + 15 * scale, cy + 2 * scale), 13 * scale, cloudPaint);
      canvas.drawCircle(
          Offset(cx + 28 * scale, cy + 5 * scale), 9 * scale, cloudPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              cx - 18 * scale, cy + 4 * scale, 52 * scale, 12 * scale),
          Radius.circular(6 * scale),
        ),
        cloudPaint,
      );
    }

    drawCloud(size.width * 0.18, horizon * 0.22, 1.2);
    drawCloud(size.width * 0.58, horizon * 0.15, 0.9);
    drawCloud(size.width * 0.85, horizon * 0.28, 1.1);

    // 3. Distant Park Tree Line & Canopy
    final treeHorizonY = horizon - 22;
    final backTreePaint = Paint()..color = const Color(0xFF14532D);
    const treeCount = 28;
    final treeSpacing = size.width / treeCount;
    for (int i = 0; i <= treeCount; i++) {
      final tx = i * treeSpacing;
      final seed = (i * 47) % 13;
      final tr = 14.0 + seed * 1.2;
      canvas.drawCircle(Offset(tx, treeHorizonY + 6), tr, backTreePaint);
    }

    final frontTreePaint = Paint()..color = const Color(0xFF166534);
    for (int i = 0; i <= treeCount + 2; i++) {
      final tx = (i - 0.5) * treeSpacing;
      final seed = (i * 31) % 11;
      final tr = 11.0 + seed * 1.0;
      canvas.drawCircle(Offset(tx, treeHorizonY + 12), tr, frontTreePaint);
    }

    // 4. Dark Green Tournament Park Windscreen Fencing
    final fenceTopY = horizon - 14;
    canvas.drawRect(
      Rect.fromLTRB(0, fenceTopY, size.width, horizon + 4),
      Paint()..color = const Color(0xFF1B4332),
    );

    // Fence top metal rail & posts
    canvas.drawLine(
      Offset(0, fenceTopY),
      Offset(size.width, fenceTopY),
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 2.0,
    );
    for (double fx = 0; fx <= size.width; fx += size.width / 12) {
      canvas.drawLine(
        Offset(fx, fenceTopY),
        Offset(fx, horizon + 4),
        Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = 1.5,
      );
    }

    // Outdoor Spectators along the park fence
    _drawCrowdRow(canvas, size.width, fenceTopY + 4, 3);
  }

  // ── C. Tropical Coastal Beach Environment ───────────────────
  void _renderBeachEnvironment(
      Canvas canvas, Size size, double horizon, CourtTheme theme) {
    // 1. Tropical coastal ocean sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0284C7),
          Color(0xFF38BDF8),
          Color(0xFFFEF08A),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon + 10));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 2. Coastal Sun Glow
    final sunCenter = Offset(size.width * 0.78, horizon * 0.35);
    canvas.drawCircle(
      sunCenter,
      48,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x70FEF08A), Color(0x20FDE047), Colors.transparent],
          stops: [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 48)),
    );

    // 3. Turquoise Ocean Horizon & Surf Lines
    final seaTopY = horizon - 26;
    final seaPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0369A1), Color(0xFF0EA5E9), Color(0xFF2DD4BF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, seaTopY, size.width, horizon));
    canvas.drawRect(Rect.fromLTRB(0, seaTopY, size.width, horizon), seaPaint);

    final surfPaint = Paint()
      ..color = const Color(0x60FFFFFF)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(0, seaTopY + 8), Offset(size.width, seaTopY + 8), surfPaint);
    canvas.drawLine(
        Offset(0, seaTopY + 16), Offset(size.width, seaTopY + 16), surfPaint);

    // 4. Palm Trees on Left and Right coastal borders
    void drawPalm(double px, double py, bool leanRight) {
      final trunkPath = Path()
        ..moveTo(px, horizon)
        ..quadraticBezierTo(
          leanRight ? px + 8 : px - 8,
          py + 25,
          leanRight ? px + 16 : px - 16,
          py,
        );
      canvas.drawPath(
        trunkPath,
        Paint()
          ..color = const Color(0xFF5C4028)
          ..strokeWidth = 5.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      final topX = leanRight ? px + 16 : px - 16;
      final frondPaint = Paint()
        ..color = const Color(0xFF15803D)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (double angle in [-0.8, -0.4, 0.0, 0.4, 0.8]) {
        final endX = topX + math.cos(angle - 1.57) * 26;
        final endY = py + math.sin(angle - 1.57) * 16;
        canvas.drawLine(Offset(topX, py), Offset(endX, endY), frondPaint);
      }
    }

    drawPalm(size.width * 0.06, horizon * 0.12, true);
    drawPalm(size.width * 0.94, horizon * 0.10, false);

    // 5. Boardwalk Pavilion Railing along horizon
    final railingY = horizon - 8;
    canvas.drawRect(
      Rect.fromLTRB(0, railingY, size.width, horizon + 4),
      Paint()..color = const Color(0xFF785938),
    );
    canvas.drawLine(
      Offset(0, railingY),
      Offset(size.width, railingY),
      Paint()
        ..color = const Color(0xFFD4A373)
        ..strokeWidth = 2.0,
    );
  }

  // ── D. Fieldhouse Gymnasium Environment ─────────────────────
  void _renderGymEnvironment(
      Canvas canvas, Size size, double horizon, CourtTheme theme) {
    // 1. Acoustic brick gymnasium back wall
    final wallPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF18181B), // Dark rafters ceiling
          Color(0xFF27272A), // Acoustic brick wall
          Color(0xFF3F3F46), // Lower wall base
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon + 10));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), wallPaint);

    // 2. High Clerestory Windows with soft daylight streaming
    const windowCount = 5;
    final winWidth = size.width / (windowCount * 2);
    final winTop = horizon * 0.12;
    final winH = horizon * 0.28;

    for (int w = 0; w < windowCount; w++) {
      final wx = (w * 2 + 0.5) * winWidth;
      final winRect = Rect.fromLTWH(wx, winTop, winWidth, winH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(winRect, const Radius.circular(4)),
        Paint()..color = const Color(0x35E0F2FE),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(winRect, const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFF52525B)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
      canvas.drawLine(
          Offset(wx + winWidth / 2, winTop),
          Offset(wx + winWidth / 2, winTop + winH),
          Paint()
            ..color = const Color(0xFF52525B)
            ..strokeWidth = 1.0);
    }

    // 3. Suspended Basketball Hoop & Backboard (Centered beyond AI baseline)
    final hoopCenterX = size.width * 0.5;
    final hoopCenterY = horizon * 0.40;
    final backboardRect = Rect.fromCenter(
        center: Offset(hoopCenterX, hoopCenterY), width: 34, height: 22);
    canvas.drawRect(backboardRect, Paint()..color = const Color(0x25FFFFFF));
    canvas.drawRect(
        backboardRect,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);
    final targetRect = Rect.fromCenter(
        center: Offset(hoopCenterX, hoopCenterY + 3), width: 12, height: 9);
    canvas.drawRect(
        targetRect,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);
    canvas.drawLine(
      Offset(hoopCenterX - 6, hoopCenterY + 7.5),
      Offset(hoopCenterX + 6, hoopCenterY + 7.5),
      Paint()
        ..color = const Color(0xFFF97316)
        ..strokeWidth = 2.2,
    );
    final netPath = Path()
      ..moveTo(hoopCenterX - 6, hoopCenterY + 7.5)
      ..lineTo(hoopCenterX - 3, hoopCenterY + 16)
      ..lineTo(hoopCenterX + 3, hoopCenterY + 16)
      ..lineTo(hoopCenterX + 6, hoopCenterY + 7.5);
    canvas.drawPath(
        netPath,
        Paint()
          ..color = const Color(0x70FFFFFF)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);

    // 4. Wooden Bleachers along the wall
    final bleacherY = horizon - 16;
    canvas.drawRect(
      Rect.fromLTRB(0, bleacherY, size.width, horizon + 4),
      Paint()..color = const Color(0xFF54341B),
    );
    _drawCrowdRow(canvas, size.width, bleacherY + 4, 2);
  }

  // ── E. Realistic Clustered Tournament Spectator Rows ─────────
  // Density scales with screen width; upper tiers sit deeper in shadow.
  void _drawCrowdRow(Canvas canvas, double width, double y, int tier) {
    final cols = (width / 10.5).round().clamp(32, 120);
    final colWidth = width / cols;
    final spectatorScale = 0.55 + tier * 0.08;
    final depthShade = (0.42 - tier * 0.08).clamp(0.0, 0.42);

    const attirePalette = [
      Color(0xFF0F172A), // Slate navy
      Color(0xFFF1F5F9), // Clean white
      Color(0xFF475569), // Heather graphite
      Color(0xFF1E3A8A), // Royal team blue
      Color(0xFF334155), // Charcoal
      Color(0xFFD97706), // Tournament amber
      Color(0xFF991B1B), // Crimson polo
      Color(0xFF0D9488), // Teal athletic
      Color(0xFFBE185D), // Berry
      Color(0xFF65A30D), // Lime
    ];
    const skinTones = [
      Color(0xFFF1C9A5),
      Color(0xFFE0AC82),
      Color(0xFFC68642),
      Color(0xFF8D5524),
      Color(0xFF5C3A21),
    ];

    final torsoPaint = Paint();
    final headPaint = Paint();
    final capPaint = Paint();
    final armPaint = Paint()
      ..strokeWidth = 1.6 * spectatorScale
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < cols; i++) {
      if (i % 9 == 0) continue; // aisle spacing
      final seed = ((tier + 3) * 7919 + i * 104729) & 0x7fffffff;
      final xJitter = ((seed % 9) - 4) * 0.35 * spectatorScale;
      final yJitter = (((seed ~/ 7) % 5) - 2) * 0.5 * spectatorScale;
      final x = (i + 0.5) * colWidth + xJitter;
      final cy = y + yJitter;

      final bodyColor = Color.lerp(attirePalette[seed % attirePalette.length],
          Colors.black, depthShade)!;
      final skin = Color.lerp(
          skinTones[(seed ~/ 3) % skinTones.length], Colors.black, depthShade)!;

      // Torso
      torsoPaint.color = bodyColor.withAlpha(225);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, cy + 2.5 * spectatorScale),
            width: 10 * spectatorScale,
            height: 9 * spectatorScale,
          ),
          Radius.circular(2.4 * spectatorScale),
        ),
        torsoPaint,
      );

      // Cheering raised arm
      if (seed % 13 == 0) {
        armPaint.color = skin;
        canvas.drawLine(
          Offset(x + 4 * spectatorScale, cy + 0.5 * spectatorScale),
          Offset(x + 6 * spectatorScale, cy - 8 * spectatorScale),
          armPaint,
        );
      }

      // Head
      headPaint.color = skin.withAlpha(235);
      canvas.drawCircle(
        Offset(x, cy - 3.5 * spectatorScale),
        3.2 * spectatorScale,
        headPaint,
      );

      // Cap / Visor
      if (seed % 3 == 0) {
        capPaint.color = bodyColor;
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(x, cy - 4.5 * spectatorScale),
            radius: 3.4 * spectatorScale,
          ),
          math.pi,
          math.pi,
          true,
          capPaint,
        );
      }
    }
  }

  void _drawFloodlight(Canvas canvas, double x, double y, bool isLeft) {
    final flarePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x35FFFFFF),
          Color(0x1538BDF8),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 55));
    canvas.drawCircle(Offset(x, y), 55, flarePaint);

    final bankRect =
        Rect.fromCenter(center: Offset(x, y), width: 22, height: 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bankRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF334155),
    );

    for (int i = 0; i < 4; i++) {
      final lx = bankRect.left + 3 + i * 5.0;
      canvas.drawCircle(
        Offset(lx, y),
        1.6,
        Paint()..color = const Color(0xFFF8FAFC),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  // 2. 3D Perimeter Digital LED Barrier Boards & Sideline Venues
  // ────────────────────────────────────────────────────────────
  void _drawPerimeterBoards(Canvas canvas, PerspectiveCamera cam) {
    final court = game.court;
    final hw = court.halfWidth;
    final theme = game.settings.courtTheme;

    // Back baseline LED barrier in 3D
    const boardH = 4.5;
    const boardZ = -88.0 - 15.0; // Behind AI baseline
    const boardLeftX = -40.0 - 16.0;
    const boardRightX = 40.0 + 16.0;

    final pBL = cam.project(Vec3(boardLeftX, 0, boardZ));
    final pBR = cam.project(Vec3(boardRightX, 0, boardZ));
    final pTL = cam.project(Vec3(boardLeftX, boardH, boardZ));
    final pTR = cam.project(Vec3(boardRightX, boardH, boardZ));

    if (pBL != null && pBR != null && pTL != null && pTR != null) {
      final boardPath = Path()
        ..moveTo(pTL.dx, pTL.dy)
        ..lineTo(pTR.dx, pTR.dy)
        ..lineTo(pBR.dx, pBR.dy)
        ..lineTo(pBL.dx, pBL.dy)
        ..close();

      // Sleek dark LED board panel
      if (game.settings.isLowEndMode) {
        canvas.drawPath(boardPath, _fastBackBoardPaint);
      } else {
        canvas.drawPath(
          boardPath,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTRB(pTL.dx, pTL.dy, pBR.dx, pBR.dy)),
        );
      }

      // Top glowing LED edge with theme color
      canvas.drawLine(
        pTL,
        pTR,
        _ledTrimPaint
          ..color = theme.ledAccentColor
          ..strokeWidth = 2.2,
      );

      // Bottom metallic floor mounting rail
      canvas.drawLine(
        pBL,
        pBR,
        _mountRailPaint,
      );

      // Tournament Branding on the back board
      final boardWidth = (pTR.dx - pTL.dx).abs();
      if ((boardWidth - _lastBoardWidth).abs() > 1.0 ||
          _courtBrandingPainter == null ||
          _lastBoardTheme != theme) {
        _lastBoardWidth = boardWidth;
        _lastBoardTheme = theme;
        _courtBrandingPainter = TextPainter(
          text: TextSpan(
            text: theme.sponsorBoardText,
            style: TextStyle(
              fontSize: (boardWidth * 0.024).clamp(7.0, 13.0),
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: const Color(0xFFF8FAFC).withAlpha(235),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }
      final tp = _courtBrandingPainter!;
      final boardMidY = (pTL.dy + pBL.dy) / 2;
      tp.paint(
          canvas,
          Offset(
              (pTL.dx + pTR.dx) / 2 - tp.width / 2, boardMidY - tp.height / 2));
    }

    // Left and Right Side Barriers extending toward player
    _drawSideBarrier(canvas, cam, -hw - 16.0, true, theme);
    _drawSideBarrier(canvas, cam, hw + 16.0, false, theme);

    // In low-end mode, skip complex 3D sidelines decor (referee chair and player bench)
    if (!game.settings.isLowEndMode) {
      // 3D Elevated Umpire / Referee Chair Stand on left sideline near net
      _drawRefereeStand(canvas, cam, -hw - 11.0);

      // 3D Player Equipment Bench on right sideline near net
      _drawPlayerBench(canvas, cam, hw + 11.0);
    }
  }

  void _drawSideBarrier(Canvas canvas, PerspectiveCamera cam, double xPos,
      bool isLeft, CourtTheme theme) {
    const boardH = 3.8;
    const zFar = -88.0 - 15.0;
    const zNear = 145.0;

    final pFarBot = cam.projectCoords(xPos, 0, zFar);
    final pFarTop = cam.projectCoords(xPos, boardH, zFar);

    double effectiveZNear = zNear;
    var pNearBot = cam.projectCoords(xPos, 0, effectiveZNear);
    var pNearTop = cam.projectCoords(xPos, boardH, effectiveZNear);
    while ((pNearBot == null || pNearTop == null) && effectiveZNear > 88.0) {
      effectiveZNear -= 10.0;
      pNearBot = cam.projectCoords(xPos, 0, effectiveZNear);
      pNearTop = cam.projectCoords(xPos, boardH, effectiveZNear);
    }

    if (pFarBot == null ||
        pFarTop == null ||
        pNearBot == null ||
        pNearTop == null) {
      return;
    }

    final path = Path()
      ..moveTo(pFarTop.dx, pFarTop.dy)
      ..lineTo(pNearTop.dx, pNearTop.dy)
      ..lineTo(pNearBot.dx, pNearBot.dy)
      ..lineTo(pFarBot.dx, pFarBot.dy)
      ..close();

    if (game.settings.isLowEndMode) {
      canvas.drawPath(path, _fastSideBarrierPaint);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: const [
              Color(0xFF0F1E36),
              Color(0xFF080D1A),
            ],
            begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          ).createShader(path.getBounds()),
      );
    }

    // Glowing top trim in theme LED accent color
    canvas.drawLine(
      pFarTop,
      pNearTop,
      _ledTrimPaint
        ..color = theme.ledAccentColor.withAlpha(200)
        ..strokeWidth = 1.8,
    );

    // Corner Stanchion Post at junction with backboard
    canvas.drawLine(
      pFarBot,
      pFarTop,
      _stanchionPaint,
    );

    // Realistic vertical barrier stanchions along the sideline for 3D depth anchoring
    for (final z in const [-60.0, -20.0, 20.0, 60.0, 100.0]) {
      if (z > effectiveZNear) continue;
      final pBot = cam.projectCoords(xPos, 0, z);
      final pTop = cam.projectCoords(xPos, boardH, z);
      if (pBot != null && pTop != null) {
        canvas.drawLine(pBot, pTop, _stanchionPaint);
      }
    }
  }

  // ── 3D Elevated Umpire / Referee Chair Stand ────────────────
  void _drawRefereeStand(Canvas canvas, PerspectiveCamera cam, double xPos) {
    final pFootA = cam.projectCoords(xPos - 1.5, 0, -2.5);
    final pFootB = cam.projectCoords(xPos + 1.5, 0, -2.5);
    final pFootC = cam.projectCoords(xPos + 1.5, 0, 2.5);
    final pFootD = cam.projectCoords(xPos - 1.5, 0, 2.5);

    const platH = 4.8;
    final pPlatA = cam.projectCoords(xPos - 1.2, platH, -2.0);
    final pPlatB = cam.projectCoords(xPos + 1.2, platH, -2.0);
    final pPlatC = cam.projectCoords(xPos + 1.2, platH, 2.0);
    final pPlatD = cam.projectCoords(xPos - 1.2, platH, 2.0);

    if (pFootA == null ||
        pFootB == null ||
        pFootC == null ||
        pFootD == null ||
        pPlatA == null ||
        pPlatB == null ||
        pPlatC == null ||
        pPlatD == null) {
      return;
    }

    final legPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 1.8;

    canvas.drawLine(pFootA, pPlatA, legPaint);
    canvas.drawLine(pFootB, pPlatB, legPaint);
    canvas.drawLine(pFootC, pPlatC, legPaint);
    canvas.drawLine(pFootD, pPlatD, legPaint);

    final platPath = Path()
      ..moveTo(pPlatA.dx, pPlatA.dy)
      ..lineTo(pPlatB.dx, pPlatB.dy)
      ..lineTo(pPlatC.dx, pPlatC.dy)
      ..lineTo(pPlatD.dx, pPlatD.dy)
      ..close();
    canvas.drawPath(platPath, Paint()..color = const Color(0xFF1E293B));
    canvas.drawPath(
        platPath,
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);

    const chairH = platH + 3.2;
    final pCanopy = cam.projectCoords(xPos, chairH + 1.2, 0);
    if (pCanopy != null) {
      final pRefHead = cam.projectCoords(xPos, platH + 2.0, 0);
      final pRefBody = cam.projectCoords(xPos, platH + 1.0, 0);
      if (pRefHead != null && pRefBody != null) {
        canvas.drawCircle(
            pRefHead, 3.2, Paint()..color = const Color(0xFFD4A373));
        canvas.drawCircle(Offset(pRefHead.dx, pRefHead.dy - 1), 3.5,
            Paint()..color = const Color(0xFF0284C7));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: pRefBody, width: 8, height: 7),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFFF8FAFC),
        );
      }
      canvas.drawCircle(
        pCanopy,
        7.5,
        Paint()..color = const Color(0xFF0284C7),
      );
      canvas.drawCircle(
        pCanopy,
        7.5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  // ── 3D Tournament Player Bench & Gear Caddy ─────────────────
  void _drawPlayerBench(Canvas canvas, PerspectiveCamera cam, double xPos) {
    const benchH = 1.8;
    final pF1 = cam.projectCoords(xPos - 1.2, 0, -3.5);
    final pF2 = cam.projectCoords(xPos + 1.2, 0, -3.5);
    final pF3 = cam.projectCoords(xPos + 1.2, 0, 3.5);
    final pF4 = cam.projectCoords(xPos - 1.2, 0, 3.5);

    final pT1 = cam.projectCoords(xPos - 1.2, benchH, -3.5);
    final pT2 = cam.projectCoords(xPos + 1.2, benchH, -3.5);
    final pT3 = cam.projectCoords(xPos + 1.2, benchH, 3.5);
    final pT4 = cam.projectCoords(xPos - 1.2, benchH, 3.5);

    if (pF1 == null ||
        pF2 == null ||
        pF3 == null ||
        pF4 == null ||
        pT1 == null ||
        pT2 == null ||
        pT3 == null ||
        pT4 == null) {
      return;
    }

    final legPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.8;
    canvas.drawLine(pF1, pT1, legPaint);
    canvas.drawLine(pF2, pT2, legPaint);
    canvas.drawLine(pF3, pT3, legPaint);
    canvas.drawLine(pF4, pT4, legPaint);

    final seatPath = Path()
      ..moveTo(pT1.dx, pT1.dy)
      ..lineTo(pT2.dx, pT2.dy)
      ..lineTo(pT3.dx, pT3.dy)
      ..lineTo(pT4.dx, pT4.dy)
      ..close();
    canvas.drawPath(seatPath, Paint()..color = const Color(0xFF0F172A));
    canvas.drawPath(
        seatPath,
        Paint()
          ..color = const Color(0xFF0284C7)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    final pTowel = cam.projectCoords(xPos, benchH + 0.5, 1.2);
    if (pTowel != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: pTowel, width: 6, height: 4),
            const Radius.circular(1.5)),
        Paint()..color = const Color(0xFFF8FAFC),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  // 3. Tournament Court Surface — perspective ground pass
  //
  // Everything here is drawn in world units on the y = 0 plane via an exact
  // perspective matrix, so paint, lines, light pools and shadows foreshorten
  // exactly like the real court.
  // ────────────────────────────────────────────────────────────
  void _drawCourt(Canvas canvas, Size sz, PerspectiveCamera cam) {
    final court = game.court;
    final hw = court.halfWidth;
    final hl = court.halfLength;
    final kd = court.kitchenDepth;
    final theme = game.settings.courtTheme;
    final lowEnd = game.settings.isLowEndMode;

    const apronPadX = 11.0;
    const apronPadZFar = 13.0;
    const apronPadZNear = 18.0;

    final apronRect = Rect.fromLTRB(
      -hw - apronPadX,
      -hl - apronPadZFar,
      hw + apronPadX,
      hl + apronPadZNear,
    );
    final courtRect = Rect.fromLTRB(-hw, -hl, hw, hl);

    canvas.save();
    canvas.transform(cam.groundMatrix());

    // ── 1. Soft Ground Contact Drop Shadow (firmly grounds the court platform) ──
    if (!lowEnd) {
      final shadowRect = Rect.fromLTRB(
        apronRect.left - 2.2,
        apronRect.top - 1.5,
        apronRect.right + 2.2,
        apronRect.bottom + 2.8,
      );
      _reusableCourtPaint
        ..shader = null
        ..color = const Color(0x66000000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(shadowRect, const Radius.circular(2.5)),
        _reusableCourtPaint,
      );
    }

    // ── 2. Tournament Platform Curb (Sleek 3D raised border) ──
    final curbRect = Rect.fromLTRB(
      apronRect.left - 0.8,
      apronRect.top - 0.8,
      apronRect.right + 0.8,
      apronRect.bottom + 0.8,
    );
    _reusableCourtPaint
      ..shader = null
      ..color = theme.apronColorDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(curbRect, const Radius.circular(1.5)),
      _reusableCourtPaint,
    );

    // ── 3. Tournament Apron (Outer Run-off Area - 100% Opaque) ──
    if (lowEnd) {
      _reusableCourtPaint
        ..shader = null
        ..color = theme.apronColor;
      canvas.drawRect(apronRect, _reusableCourtPaint);
    } else {
      _reusableCourtPaint.shader = LinearGradient(
        colors: [
          theme.apronColorDark,
          theme.apronColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 1.0],
      ).createShader(apronRect);
      canvas.drawRect(apronRect, _reusableCourtPaint);
    }

    // ── 4. Playing Court Surface (acrylic coating - 100% Opaque) ──
    if (lowEnd) {
      _reusableCourtPaint
        ..shader = null
        ..color = theme.surfaceColor;
      canvas.drawRect(courtRect, _reusableCourtPaint);
    } else {
      _reusableCourtPaint.shader = LinearGradient(
        colors: [
          theme.surfaceColorDark,
          theme.surfaceColor,
          theme.surfaceColorLight,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 1.0],
      ).createShader(courtRect);
      canvas.drawRect(courtRect, _reusableCourtPaint);
    }

    // ── 5. Non-Volley Zones (The Kitchen - 100% Opaque) ───────
    _reusableCourtPaint
      ..shader = null
      ..color = theme.kitchenColor;
    canvas.drawRect(
      Rect.fromLTRB(-hw, 0, hw, kd),
      _reusableCourtPaint,
    );
    _reusableCourtPaint.color = theme.kitchenColorDark;
    canvas.drawRect(
      Rect.fromLTRB(-hw, -kd, hw, 0),
      _reusableCourtPaint,
    );

    // Subtle surface plank/detail lines for indoor & stadium courts
    if ((theme == CourtTheme.indoor || theme == CourtTheme.tournament) &&
        !lowEnd) {
      final plankPaint = _reusableStrokePaint
        ..shader = null
        ..color = const Color(0x12000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.18;
      for (double z = apronRect.top; z <= apronRect.bottom; z += 4.0) {
        canvas.drawLine(
            Offset(apronRect.left, z), Offset(apronRect.right, z), plankPaint);
      }
    }

    // ── D. Lighting: floodlight pools / sun, glossy sheen ─────
    if (!lowEnd) {
      _drawCourtLighting(canvas, theme, hw, hl, apronRect);
    }

    // ── E. Regulation Court Markings (true painted width) ─────
    _drawCourtLines(canvas, cam, hw, hl, kd, theme);

    // ── F. Serve target / Frost zone / skid marks / shadows ───
    if (game.state == GameState.waitingForServe) {
      _drawServiceBoxHighlight(canvas, hw, hl, kd);
    }
    if (game.ball.iceZoneTimer > 0 &&
        game.ball.iceZoneCenter != null &&
        !lowEnd) {
      _drawFrostIceZone(canvas);
    }
    if (!lowEnd) {
      _drawCourtMarks(canvas);
    }
    if (game.settings.showShadows) {
      _drawNetShadow(canvas, hw);
      _drawBallShadow(canvas);
    }

    // ── G. Atmospheric distance haze over the far court ───────
    if (!lowEnd) {
      _reusableCourtPaint.shader = LinearGradient(
        colors: [
          _hazeColor(theme).withAlpha(95),
          _hazeColor(theme).withAlpha(0),
        ],
        stops: const [0.0, 0.42],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(apronRect);
      canvas.drawRect(apronRect, _reusableCourtPaint);
    }

    canvas.restore();

    // ── H. Stenciled watermark decal behind the far baseline ──
    if (!lowEnd) {
      _drawApronDecal(canvas, cam, hw, hl, theme);
    }
  }

  Color _hazeColor(CourtTheme theme) {
    switch (theme) {
      case CourtTheme.outdoor:
        return const Color(0xFFBAE6FD);
      case CourtTheme.beach:
        return const Color(0xFFFEF3C7);
      case CourtTheme.midnight:
        return const Color(0xFF1E1B4B);
      case CourtTheme.volcano:
        return const Color(0xFF7C2D12);
      case CourtTheme.canyon:
        return const Color(0xFF78350F);
      case CourtTheme.tournament:
      case CourtTheme.indoor:
        return const Color(0xFF1B2A44);
    }
  }

  /// Floodlight pools (arenas) or low sun wash (outdoors) plus the soft
  /// specular band that makes acrylic courts look glossy on broadcast.
  void _drawCourtLighting(
      Canvas canvas, CourtTheme theme, double hw, double hl, Rect apronRect) {
    if (theme.isOutdoor) {
      final sunCenter = Offset(hw * 0.9, -hl * 0.55);
      const sunR = 150.0;
      canvas.drawCircle(
        sunCenter,
        sunR,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x30FFF7D6), Color(0x10FFF7D6), Color(0x00FFF7D6)],
            stops: [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: sunCenter, radius: sunR)),
      );
    } else {
      final poolPaint = Paint();
      const poolR = 46.0;
      for (final c in [
        Offset(-hw * 0.55, -hl * 0.5),
        Offset(hw * 0.55, -hl * 0.5),
        Offset(-hw * 0.55, hl * 0.5),
        Offset(hw * 0.55, hl * 0.5),
      ]) {
        poolPaint.shader = const RadialGradient(
          colors: [Color(0x26FFFFFF), Color(0x0CFFFFFF), Color(0x00FFFFFF)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: poolR));
        canvas.drawCircle(c, poolR, poolPaint);
      }
    }

    // Glossy specular band: reflected lights glinting off the far court
    final sheenRect =
        Rect.fromLTRB(apronRect.left, -hl - 10, apronRect.right, -8);
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            Colors.white.withAlpha(theme.isOutdoor ? 22 : 30),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.45, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(sheenRect),
    );
  }

  /// Screen pixels covered by one world unit along Z at depth [z].
  double _zPixelsPerUnit(PerspectiveCamera cam, double z) {
    final a = cam.projectCoords(0, 0, z - 0.5);
    final b = cam.projectCoords(0, 0, z + 0.5);
    if (a == null || b == null) return 1.0;
    return (b.dy - a.dy).abs().clamp(0.05, 1000.0);
  }

  void _drawCourtLines(Canvas canvas, PerspectiveCamera cam, double hw,
      double hl, double kd, CourtTheme theme) {
    // Regulation 2" lines, slightly exaggerated for readability. Lines running
    // across the court get a minimum on-screen thickness so the far baseline
    // never shimmers away to a sub-pixel sliver.
    const w = 0.8;
    _courtLinePaint
      ..shader = null
      ..color = theme.lineColor;
    const half = w / 2;

    double across(double z) => math.max(w, 1.15 / _zPixelsPerUnit(cam, z));

    void crossLine(double z) {
      final t = across(z) / 2;
      canvas.drawRect(
          Rect.fromLTRB(-hw - half, z - t, hw + half, z + t), _courtLinePaint);
    }

    void lengthLine(double x, double z1, double z2) {
      canvas.drawRect(
          Rect.fromLTRB(x - half, math.min(z1, z2), x + half, math.max(z1, z2)),
          _courtLinePaint);
    }

    // Outer boundary
    crossLine(hl); // Player baseline
    crossLine(-hl); // AI baseline
    lengthLine(-hw, -hl, hl); // Left sideline
    lengthLine(hw, -hl, hl); // Right sideline

    // Kitchen (Non-Volley Zone) lines
    crossLine(kd);
    crossLine(-kd);

    // Center service lines (baseline → kitchen line)
    lengthLine(0, kd, hl);
    lengthLine(0, -hl, -kd);

    // Subtle paint edge definition (lines sit slightly proud of the acrylic)
    if (!game.settings.isLowEndMode) {
      _reusableStrokePaint
        ..shader = null
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.18;
      canvas.drawRect(
          Rect.fromLTRB(-hw - half, -hl - half, hw + half, hl + half),
          _reusableStrokePaint);
    }
  }

  // ── Serve Target Diagonal Service Box Highlight (ground space) ──
  void _drawServiceBoxHighlight(
      Canvas canvas, double hw, double hl, double kd) {
    final serverRight = game.scoreController.serverShouldBeOnRight;
    final isPlayerServing = game.scoreController.isPlayerServing;

    double x1, x2, z1, z2;
    if (isPlayerServing) {
      // Human serves to AI side (negative Z)
      z1 = -kd;
      z2 = -hl;
      if (serverRight) {
        x1 = -hw;
        x2 = 0;
      } else {
        x1 = 0;
        x2 = hw;
      }
    } else {
      // AI serves to Player side (positive Z)
      z1 = kd;
      z2 = hl;
      if (serverRight) {
        x1 = 0;
        x2 = hw;
      } else {
        x1 = -hw;
        x2 = 0;
      }
    }

    final rect = Rect.fromPoints(Offset(x1, z1), Offset(x2, z2)).deflate(0.5);
    final pulse = (math.sin(animTime * 4) + 1) / 2;

    _reusableCourtPaint
      ..shader = null
      ..color = AppColors.ballColor.withAlpha((20 + pulse * 18).toInt());
    canvas.drawRect(rect, _reusableCourtPaint);

    _reusableStrokePaint
      ..shader = null
      ..color = AppColors.ballColor.withAlpha((140 + pulse * 90).toInt())
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, _reusableStrokePaint);
  }

  // ── Bounce skid marks & expanding contact rings (ground space) ──
  void _drawCourtMarks(Canvas canvas) {
    if (game.settings.isLowEndMode) return; // skip court skid marks on low-end
    final marks = presentation.vfx.marks;
    if (marks.isEmpty) return;
    for (final m in marks) {
      final a = m.remaining * m.strength;
      if (a <= 0.01) continue;
      final c = Offset(m.x, m.z);

      // Scuff: slightly elongated along the travel direction (Z)
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1.0, 1.7);
      canvas.drawCircle(
        Offset.zero,
        1.8,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromARGB((80 * a).round(), 0, 0, 0),
              const Color(0x00000000),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.8)),
      );
      canvas.restore();

      // Expanding ring
      final grow = 1.0 - m.remaining;
      canvas.drawCircle(
        c,
        2.0 + grow * 7.0,
        Paint()
          ..color = Colors.white.withAlpha((110 * a * m.remaining).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.35,
      );
    }
  }

  /// Soft net shadow cast onto the far court by the floodlights.
  void _drawNetShadow(Canvas canvas, double hw) {
    final postX = hw + 2.5;
    const depth = 3.2;
    const skew = 1.4;
    final path = Path()
      ..moveTo(-postX, 0)
      ..lineTo(postX, 0)
      ..lineTo(postX + skew, -depth)
      ..lineTo(-postX + skew, -depth)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x48000000), Color(0x00000000)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTRB(-postX, -depth, postX + skew, 0)),
    );
  }

  /// Ball shadow on the ground plane: tight & dark near the court, broad and
  /// faint as the ball climbs — the key depth cue for judging the bounce.
  void _drawBallShadow(Canvas canvas) {
    if (!game.settings.showShadows) return;
    final ball = game.ball;
    final isVisible = ball.isInPlay || game.state == GameState.waitingForServe;
    if (!isVisible) return;

    final h = math.max(0.0, ball.position.y - PhysicsConstants.ballRadius);
    final near = 1.0 - (h / 70.0).clamp(0.0, 1.0);
    final r = PhysicsConstants.ballRadius * (0.9 + h * 0.035);
    final c = Offset(ball.position.x, ball.position.z);
    final a = (40 + 130 * near).round();

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromARGB(a, 0, 0, 0),
            Color.fromARGB(a ~/ 2, 0, 0, 0),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _drawApronDecal(Canvas canvas, PerspectiveCamera cam, double hw,
      double hl, CourtTheme theme) {
    final pDecalL = cam.projectCoords(-hw * 0.6, 0, -hl - 6.0);
    final pDecalR = cam.projectCoords(hw * 0.6, 0, -hl - 6.0);
    if (pDecalL == null || pDecalR == null) return;

    final decalWidth = (pDecalR.dx - pDecalL.dx).abs();
    final fontSize = (decalWidth * 0.038).clamp(8.0, 16.0).roundToDouble();
    if (_decalPainter == null ||
        _decalTheme != theme ||
        _decalFontSize != fontSize) {
      _decalTheme = theme;
      _decalFontSize = fontSize;
      _decalPainter = TextPainter(
        text: TextSpan(
          text: theme.displayName,
          style: TextStyle(
            fontFamily: AppFonts.orbitron,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            color: const Color(0x30FFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final tp = _decalPainter!;
    tp.paint(
      canvas,
      Offset((pDecalL.dx + pDecalR.dx) / 2 - tp.width / 2,
          (pDecalL.dy + pDecalR.dy) / 2 - tp.height / 2),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 4. Regulation Net — translucent mesh, tape, strap & metal posts
  // ────────────────────────────────────────────────────────────
  void _drawNet(Canvas canvas, PerspectiveCamera cam) {
    const netPostH = CourtDimensions.netHeight;
    const hw = CourtDimensions.halfWidth;
    const postX = hw + 2.5;
    final quality = game.settings.graphicsQuality;

    canvas.save();
    canvas.transform(cam.netPlaneMatrix());

    // Net body (dark translucent mesh fabric)
    canvas.drawPath(_staticNetBody, _netBodyPaint);

    // Woven mesh cords (omitted in low-end mode for maximum performance)
    if (quality != GraphicsQuality.low) {
      canvas.drawPath(
        quality == GraphicsQuality.high
            ? _staticNetMeshHigh
            : _staticNetMeshMedium,
        _netMeshPaint,
      );
    }

    // Bottom cord
    canvas.drawLine(
        const Offset(-postX, 0.12), const Offset(postX, 0.12), _netCordPaint);

    // Center adjustment strap + buckle
    final centerTop = _sagY(0);
    canvas.drawRect(Rect.fromLTRB(-0.45, 0, 0.45, centerTop), _strapPaint);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, centerTop - 0.9), width: 1.1, height: 0.45),
      _strapBucklePaint,
    );

    // White vinyl headband tape following the sag
    canvas.drawPath(_staticNetTape, _netTapePaint);
    canvas.drawPath(_staticNetTapeEdge, _netTapeEdgePaint);

    canvas.restore();

    // Metal posts (screen-space cylinders)
    _drawNetPost(canvas, cam, -postX, netPostH, false);
    _drawNetPost(canvas, cam, postX, netPostH, true);
  }

  void _drawNetPost(Canvas canvas, PerspectiveCamera cam, double x, double h,
      bool withCrank) {
    final bot = cam.projectCoords(x, 0, 0);
    final top = cam.projectCoords(x, h + 0.35, 0);
    final edgeA = cam.projectCoords(x - 0.8, 0, 0);
    final edgeB = cam.projectCoords(x + 0.8, 0, 0);
    if (bot == null || top == null || edgeA == null || edgeB == null) return;

    final w = (edgeB.dx - edgeA.dx).abs().clamp(2.5, 14.0);
    final hwPx = w / 2;

    if (game.settings.isLowEndMode) {
      // Ultra-efficient solid cylinder post on low-end
      final postRect =
          Rect.fromLTRB(top.dx - hwPx, top.dy, bot.dx + hwPx, bot.dy);
      canvas.drawRect(postRect, _fastNetPostPaint);
      canvas.drawOval(
        Rect.fromCenter(center: top, width: w * 1.1, height: w * 0.45),
        _fastNetPostCapPaint,
      );
      return;
    }

    // Base contact shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: bot.translate(0, 0.5), width: w * 2.4, height: w * 0.8),
      Paint()..color = const Color(0x55000000),
    );

    final path = Path()
      ..moveTo(top.dx - hwPx, top.dy)
      ..lineTo(top.dx + hwPx, top.dy)
      ..lineTo(bot.dx + hwPx, bot.dy)
      ..lineTo(bot.dx - hwPx, bot.dy)
      ..close();
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF64748B),
            Color(0xFFE2E8F0),
            Color(0xFF475569),
            Color(0xFF0F172A),
          ],
          stops: [0.0, 0.22, 0.38, 0.72, 1.0],
        ).createShader(bounds),
    );

    // Cap
    canvas.drawOval(
      Rect.fromCenter(center: top, width: w * 1.15, height: w * 0.5),
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: top.translate(-w * 0.12, -w * 0.05),
          width: w * 0.5,
          height: w * 0.18),
      Paint()..color = const Color(0x66E2E8F0),
    );

    // Tension ratchet crank handle
    if (withCrank) {
      final pivot =
          Offset(top.dx + hwPx * 0.6, top.dy + (bot.dy - top.dy) * 0.25);
      final handle = pivot.translate(w * 0.9, w * 0.2);
      canvas.drawLine(
        pivot,
        handle,
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = math.max(1.2, w * 0.25)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(handle, math.max(1.2, w * 0.2),
          Paint()..color = const Color(0xFF0F172A));
    }
  }

  void _drawPlayer(Canvas canvas, PerspectiveCamera cam, Player p) {
    // Animated sprite athletes (Character_sprite/); procedural fallback
    final drawn = SpriteCharacterRenderer.drawPlayer(
      canvas: canvas,
      player: p,
      cam: cam,
      isLowEnd: game.settings.isLowEndMode,
      showShadow: game.settings.showShadows,
    );
    if (drawn) return;
    CharacterRenderer.drawPlayer(
      canvas: canvas,
      player: p,
      cam: cam,
      isLowEnd: game.settings.isLowEndMode,
      showShadow: game.settings.showShadows,
      equippedSkin: p.isHuman ? game.currentPlayerSkin : null,
      equippedPaddle: p.isHuman ? game.currentPaddle : null,
    );
  }

  // ────────────────────────────────────────────────────────────
  // 6. Speed Trail & High-Vis Tournament Pickleball
  // ────────────────────────────────────────────────────────────
  void _drawBallTrail(Canvas canvas, PerspectiveCamera cam) {
    if (!game.settings.showBallTrail) return;
    final ball = game.ball;
    if (!ball.isInPlay || ball.trail.length < 2) return;

    // ── Ultimate Custom Trail VFX ──────────────────────────────
    if (ball.isUltimate) {
      final ultType = ball.ultimateType ?? UltimateType.thunderbolt;
      Color primaryTrailColor;
      Color secondaryTrailColor;
      double strokeMult = 1.0;

      switch (ultType) {
        case UltimateType.thunderbolt:
          primaryTrailColor = const Color(0xFF38BDF8); // lightning cyan
          secondaryTrailColor = const Color(0xFFFBBF24); // gold electricity
          strokeMult = 1.6;
          break;
        case UltimateType.ghostPhantom:
          primaryTrailColor = const Color(0xFFA855F7); // neon violet
          secondaryTrailColor = const Color(0xFFEC4899); // hot magenta
          strokeMult = 1.3;
          break;
        case UltimateType.dragonMeteor:
          primaryTrailColor = const Color(0xFFF97316); // fiery orange
          secondaryTrailColor = const Color(0xFFEF4444); // blazing crimson
          strokeMult = 1.8;
          break;
        case UltimateType.frostbite:
          primaryTrailColor = const Color(0xFF00E5FF); // cryo cyan
          secondaryTrailColor = const Color(0xFFE0F7FA); // ice crystal white
          strokeMult = 1.4;
          break;
      }

      // Medium quality keeps the bright core ribbon. High quality adds the
      // wider aura pass and denser secondary sparks.
      if (!game.settings.useReducedUltimateEffects) {
        _drawTrailRibbon(
          canvas,
          cam,
          ball.trail,
          secondaryTrailColor,
          150,
          7.0 * strokeMult,
        );
      }
      _drawTrailRibbon(
          canvas, cam, ball.trail, primaryTrailColor, 240, 3.6 * strokeMult);

      final detailStride = game.settings.useReducedUltimateEffects ? 4 : 2;
      for (int i = 1; i < ball.trail.length; i += detailStride) {
        final curr = cam.project(ball.trail[i]);
        if (curr == null) continue;
        final t = i / ball.trail.length;
        final alpha = (t * 240).toInt();

        // Thunderbolt electric spark jitter
        if (ultType == UltimateType.thunderbolt) {
          final jitterX = (math.sin(i * 9.0 + animTime * 20.0)) * 5.0;
          final jitterY = (math.cos(i * 9.0 + animTime * 20.0)) * 5.0;
          canvas.drawLine(
            curr,
            Offset(curr.dx + jitterX, curr.dy + jitterY),
            _ultimateEffectStrokePaint
              ..shader = null
              ..color = const Color(0xFFFFFFFF).withAlpha((alpha * 0.9).toInt())
              ..strokeWidth = 1.8,
          );
        }

        // Dragon Meteor ember spark specks
        if (ultType == UltimateType.dragonMeteor) {
          final emberX = (math.sin(i * 13.0 + animTime * 15.0)) * 6.0;
          final emberY = (math.cos(i * 13.0 + animTime * 15.0)) * 6.0;
          canvas.drawCircle(
            Offset(curr.dx + emberX, curr.dy + emberY),
            2.0 * t,
            _ultimateEffectPaint
              ..shader = null
              ..color = const Color(0xFFFBBF24).withAlpha(alpha),
          );
        }
      }
      return;
    }

    final isPowerShot = ball.speed > PhysicsConstants.normalHitPower * 0.8;
    _drawTrailRibbon(
      canvas,
      cam,
      ball.trail,
      isPowerShot ? AppColors.power : AppColors.ballColor,
      isPowerShot ? 200 : 120,
      isPowerShot ? 4.2 : 2.8,
    );
  }

  /// Continuous tapered ribbon (thin tail → full width at the ball) filled in a
  /// single draw with a tail-to-head alpha gradient. Unlike per-segment lines
  /// with round caps, there are no overlapping "beads" and it stays smooth.
  void _drawTrailRibbon(Canvas canvas, PerspectiveCamera cam, List<Vec3> trail,
      Color color, int maxAlpha, double maxWidth) {
    final n = trail.length;
    if (n < 2) return;

    final pts = <Offset>[];
    final widths = <double>[];
    for (int i = 0; i < n; i++) {
      final p = trail[i];
      final s = cam.projectCoords(p.x, p.y, p.z);
      if (s == null) continue;
      final t = (i + 1) / n;
      pts.add(s);
      widths.add(
          maxWidth * t * cam.depthScaleCoords(p.x, p.y, p.z).clamp(0.4, 2.5));
    }
    if (pts.length < 2 || (pts.last - pts.first).distance < 0.5) return;

    final left = <Offset>[];
    final right = <Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final a = pts[i > 0 ? i - 1 : 0];
      final b = pts[i < pts.length - 1 ? i + 1 : i];
      var dx = b.dx - a.dx;
      var dy = b.dy - a.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 0.0001) {
        dx = 0;
        dy = 1;
      } else {
        dx /= len;
        dy /= len;
      }
      final hwid = widths[i] / 2;
      final nx = -dy * hwid;
      final ny = dx * hwid;
      left.add(Offset(pts[i].dx + nx, pts[i].dy + ny));
      right.add(Offset(pts[i].dx - nx, pts[i].dy - ny));
    }

    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (int i = 1; i < left.length; i++) {
      path.lineTo(left[i].dx, left[i].dy);
    }
    for (int i = right.length - 1; i >= 0; i--) {
      path.lineTo(right[i].dx, right[i].dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          pts.first,
          pts.last,
          [color.withAlpha(0), color.withAlpha(maxAlpha)],
        ),
    );
  }

  void _drawBall(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    final isVisible = (ball.state != BallState.dead) &&
        (ball.isInPlay || game.state == GameState.waitingForServe);
    if (!isVisible) return;

    final screenPos =
        cam.projectCoords(ball.position.x, ball.position.y, ball.position.z);
    if (screenPos == null) return;

    final scale = cam.depthScale(ball.position).clamp(0.4, 2.5);
    final radius = PhysicsConstants.ballRadius * 2.3 * scale;
    final lowEnd = game.settings.isLowEndMode;

    if (lowEnd) {
      // Ultra-efficient flat optic-yellow ball with minimal glint (0 shaders, 0 loops, 0 allocations)
      canvas.drawCircle(screenPos, radius, _fastBallPaint);
      canvas.drawOval(
        Rect.fromCenter(
          center: screenPos.translate(-radius * 0.36, -radius * 0.42),
          width: radius * 0.52,
          height: radius * 0.34,
        ),
        _fastBallGlintPaint,
      );
      canvas.drawCircle(screenPos, radius, _ballEdgePaint);
      return;
    }

    // Motion blur smear: where the ball was ~1 frame ago
    if (!lowEnd && ball.isInPlay) {
      const blurTime = 0.022;
      final prev = cam.projectCoords(
        ball.position.x - ball.velocity.x * blurTime,
        ball.position.y - ball.velocity.y * blurTime,
        ball.position.z - ball.velocity.z * blurTime,
      );
      if (prev != null && (prev - screenPos).distance > radius * 0.6) {
        canvas.drawLine(
          prev,
          screenPos,
          Paint()
            ..color = const Color(0x66D4E157)
            ..strokeWidth = radius * 1.7
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Ultimate glowing energy aura corona
    if (ball.isUltimate) {
      final ultType = ball.ultimateType ?? UltimateType.thunderbolt;
      Color auraColor;
      switch (ultType) {
        case UltimateType.thunderbolt:
          auraColor = const Color(0xFF38BDF8);
          break;
        case UltimateType.ghostPhantom:
          auraColor = const Color(0xFFA855F7);
          break;
        case UltimateType.dragonMeteor:
          auraColor = const Color(0xFFF97316);
          break;
        case UltimateType.frostbite:
          auraColor = const Color(0xFF00E5FF);
          break;
      }
      if (game.settings.useReducedUltimateEffects) {
        canvas.drawCircle(
          screenPos,
          radius * 1.45,
          _ultimateEffectPaint
            ..shader = null
            ..color = auraColor.withAlpha(100),
        );
      } else {
        canvas.drawCircle(
          screenPos,
          radius * 1.85,
          _ultimateEffectPaint
            ..shader = RadialGradient(
              colors: [
                auraColor.withAlpha(210),
                auraColor.withAlpha(80),
                auraColor.withAlpha(0),
              ],
              stops: const [0.35, 0.70, 1.0],
            ).createShader(
                Rect.fromCircle(center: screenPos, radius: radius * 1.85)),
        );
      }
    }

    // Optic-yellow body: key light upper-left, soft terminator, dark rim
    final ballRect = Rect.fromCircle(center: screenPos, radius: radius);
    canvas.drawCircle(
      screenPos,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFBFDE3), // hot specular core
            Color(0xFFE6F05A), // optic yellow
            Color(0xFFB5BD2C), // turning away from light
            Color(0xFF7C8219), // occluded rim
          ],
          center: Alignment(-0.35, -0.42),
          radius: 1.15,
          stops: [0.0, 0.32, 0.78, 1.0],
        ).createShader(ballRect),
    );

    // Perforations on a rotating sphere (spin is readable, not a strobing blur)
    if (!lowEnd && radius > 3.5) {
      final theta = ball.spinAngle * math.pi / 180.0;
      final c = math.cos(theta);
      final s = math.sin(theta);
      final dirs = _holeDirs;
      final holeR = radius * 0.13;
      for (int i = 0; i < dirs.length; i += 3) {
        final hx = dirs[i];
        final hy = dirs[i + 1];
        final hz = dirs[i + 2];
        // Topspin: rotate about the horizontal screen axis
        final ry = hy * c - hz * s;
        final rz = hy * s + hz * c;
        if (rz < 0.2) continue;
        _holePaint.color =
            Color.fromARGB((40 + 90 * rz).round(), 0x5A, 0x60, 0x12);
        canvas.drawCircle(
          Offset(screenPos.dx + hx * radius * 0.86,
              screenPos.dy - ry * radius * 0.86),
          holeR * (0.45 + 0.55 * rz),
          _holePaint,
        );
      }
    }

    // Specular glint (fixed to the light, not the spin)
    canvas.drawOval(
      Rect.fromCenter(
        center: screenPos.translate(-radius * 0.36, -radius * 0.42),
        width: radius * 0.52,
        height: radius * 0.34,
      ),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    canvas.drawCircle(screenPos, radius, _ballEdgePaint);
  }

  void _drawImpactFlash(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    final f = ball.impactFlash;
    if (f <= 0) return;

    final screenPos =
        cam.projectCoords(ball.position.x, ball.position.y, ball.position.z);
    if (screenPos == null) return;

    final scale = cam.depthScale(ball.position).clamp(0.4, 2.5);
    final base = PhysicsConstants.ballRadius * 5.5 * scale;
    final grow = 1.0 - f;

    if (game.settings.isLowEndMode) {
      // Fast single shock ring
      canvas.drawCircle(
        screenPos,
        base * (0.6 + grow),
        _fastFlashRingPaint
          ..color = Colors.white.withAlpha((180 * f).round())
          ..strokeWidth = math.max(0.6, 2.0 * f * scale),
      );
      return;
    }

    // Hot core burst
    final coreR = base * (0.55 + 0.5 * grow);
    canvas.drawCircle(
      screenPos,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withAlpha((230 * f).round()),
            AppColors.ballColor.withAlpha((110 * f).round()),
            AppColors.ballColor.withAlpha(0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: screenPos, radius: coreR)),
    );

    // Expanding shock ring
    canvas.drawCircle(
      screenPos,
      base * (0.7 + 1.5 * grow),
      Paint()
        ..color = Colors.white.withAlpha((170 * f).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, 2.6 * f * scale),
    );
  }

  // ── World-space particles (sparks & dust) ────────────────────
  void _drawParticles(Canvas canvas, PerspectiveCamera cam) {
    final particles = presentation.vfx.particles;
    if (particles.isEmpty) return;

    for (final p in particles) {
      final pos = cam.projectCoords(p.x, p.y, p.z);
      if (pos == null) continue;
      final k = p.remaining;
      final scale = cam.depthScaleCoords(p.x, p.y, p.z).clamp(0.3, 2.5);

      if (p.kind == ParticleKind.spark) {
        // Short additive streak along the velocity = cheap motion blur
        const streak = 0.028;
        final tail = cam.projectCoords(
          p.x - p.vx * streak,
          p.y - p.vy * streak,
          p.z - p.vz * streak,
        );
        _sparkPaint
          ..color = p.color.withAlpha((255 * k).round())
          ..strokeWidth = math.max(0.8, p.size * 2.2 * scale * (0.4 + 0.6 * k));
        canvas.drawLine(tail ?? pos, pos, _sparkPaint);
      } else {
        _dustPaint.color = p.color.withAlpha((95 * k * k).round());
        canvas.drawCircle(pos, p.size * 2.4 * scale, _dustPaint);
      }
    }
  }

  // ── Screen-space atmosphere: light shafts / sun wash + vignette ──
  void _drawAtmosphere(Canvas canvas, Size size) {
    final theme = game.settings.courtTheme;
    if (_cachedAtmoPicture == null ||
        _cachedAtmoSize != size ||
        _cachedAtmoTheme != theme) {
      final recorder = ui.PictureRecorder();
      final rc = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
      _renderAtmosphere(rc, size, theme);
      _cachedAtmoPicture = recorder.endRecording();
      _cachedAtmoSize = size;
      _cachedAtmoTheme = theme;
    }
    canvas.drawPicture(_cachedAtmoPicture!);
  }

  void _renderAtmosphere(Canvas canvas, Size size, CourtTheme theme) {
    final w = size.width;
    final h = size.height;
    final horizon = h * CameraConstants.horizonFraction;

    if (theme == CourtTheme.tournament ||
        theme == CourtTheme.indoor ||
        theme == CourtTheme.midnight) {
      // Volumetric beams from the arena floodlight banks
      final lights = [
        Offset(w * 0.08, horizon * 0.22),
        Offset(w * 0.32, horizon * 0.19),
        Offset(w * 0.68, horizon * 0.19),
        Offset(w * 0.92, horizon * 0.22),
      ];
      for (final l in lights) {
        final bottomCenter = l.dx + (w / 2 - l.dx) * 0.55;
        final spread = w * 0.2;
        final beam = Path()
          ..moveTo(l.dx - 6, l.dy)
          ..lineTo(l.dx + 6, l.dy)
          ..lineTo(bottomCenter + spread, h)
          ..lineTo(bottomCenter - spread, h)
          ..close();
        canvas.drawPath(
          beam,
          Paint()
            ..shader = ui.Gradient.linear(
              l,
              Offset(bottomCenter, h),
              [
                theme.ledAccentColor.withAlpha(24),
                theme.ledAccentColor.withAlpha(8),
                const Color(0x00FFFFFF),
              ],
              const [0.0, 0.45, 1.0],
            ),
        );
      }
    } else {
      // Outdoor / beach / forest / volcano / canyon: warm atmospheric sun wash
      final sun = Offset(w * 0.88, -h * 0.05);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.radial(
            sun,
            w * 0.9,
            [
              theme.ledAccentColor.withAlpha(22),
              theme.ledAccentColor.withAlpha(8),
              const Color(0x00000000),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }

    // Lens vignette — pulls the eye to the court center
    final center = Offset(w / 2, h * 0.52);
    final radius = math.sqrt(w * w + h * h) * 0.62;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          const [Color(0x00000000), Color(0x00000000), Color(0x5C000000)],
          const [0.0, 0.6, 1.0],
        ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 7. Broadcast-Style In-Game Messages
  // ────────────────────────────────────────────────────────────
  void _drawMessage(Canvas canvas, Size size) {
    if (game.lastMessage.isEmpty || game.messageTimer <= 0) return;

    final alpha = (game.messageTimer / 1.5).clamp(0.0, 1.0);
    final scale = 1.0 + (1.0 - alpha) * 0.2;

    final msgText = game.lastMessage.toUpperCase();
    if (_cachedMsgText != msgText || _cachedMsgPainter == null) {
      _cachedMsgText = msgText;
      _cachedMsgPainter = TextPainter(
        text: TextSpan(
          text: msgText,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFFF8FAFC),
            letterSpacing: 4.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final tp = _cachedMsgPainter!;
    final badgeWidth = (tp.width + 48) * scale;
    final badgeHeight = (tp.height + 20) * scale;
    final badgeCenter = Offset(size.width / 2, size.height * 0.30);
    final badgeRect = Rect.fromCenter(
        center: badgeCenter, width: badgeWidth, height: badgeHeight);

    // Frosted dark pill
    _msgBackdropPaint.color =
        const Color(0xEB0B132B).withAlpha((235 * alpha).toInt());
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(24)),
      _msgBackdropPaint,
    );

    // Gold / Coral accent trim
    _msgBorderPaint.color =
        const Color(0xFFF59E0B).withAlpha((200 * alpha).toInt());
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(24)),
      _msgBorderPaint,
    );

    canvas.save();
    canvas.translate(badgeCenter.dx, badgeCenter.dy);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────
  // 8. Ultimate Skill Special VFX Renderers
  // ────────────────────────────────────────────────────────────

  /// Frost zone drawn on the ground plane (called inside the ground pass),
  /// sized to the real slow-down radius used by the gameplay code.
  void _drawFrostIceZone(Canvas canvas) {
    final center3D = game.ball.iceZoneCenter;
    if (center3D == null || game.ball.iceZoneTimer <= 0) return;

    final c = Offset(center3D.x, center3D.z);
    final radius = game.ball.iceZoneRadius + 8.0;
    final alpha = (game.ball.iceZoneTimer / 3.5).clamp(0.0, 1.0);

    // Frozen sheet. Medium quality uses a flat translucent fill to avoid
    // rebuilding a radial shader throughout the zone's lifetime.
    final reducedEffects = game.settings.useReducedUltimateEffects;
    _frostZonePaint
      ..shader = reducedEffects
          ? null
          : RadialGradient(
              colors: [
                const Color(0xFFE0F7FA).withAlpha((150 * alpha).toInt()),
                const Color(0xFF00E5FF).withAlpha((95 * alpha).toInt()),
                const Color(0xFF0284C7).withAlpha(0),
              ],
              stops: const [0.0, 0.6, 1.0],
            ).createShader(Rect.fromCircle(center: c, radius: radius))
      ..color = const Color(0xFF38BDF8).withAlpha((75 * alpha).toInt());
    canvas.drawCircle(c, radius, _frostZonePaint);

    // Frost crystal ring border
    canvas.drawCircle(
      c,
      radius * 0.92,
      _frostRingPaint
        ..color = const Color(0xFFE0F7FA).withAlpha((180 * alpha).toInt()),
    );

    // Snowflake crystal spikes around perimeter
    _frostSpikePaint.color =
        const Color(0xFFFFFFFF).withAlpha((210 * alpha).toInt());
    final spikeCount = reducedEffects ? 4 : 8;
    for (int i = 0; i < spikeCount; i++) {
      final ang = i * math.pi * 2 / spikeCount + animTime * 0.5;
      final px = c.dx + math.cos(ang) * radius * 0.92;
      final pz = c.dy + math.sin(ang) * radius * 0.92;
      canvas.drawLine(
          Offset(px - 1.4, pz), Offset(px + 1.4, pz), _frostSpikePaint);
      canvas.drawLine(
          Offset(px, pz - 1.4), Offset(px, pz + 1.4), _frostSpikePaint);
    }
  }

  void _drawGhostClones(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    if (!ball.isInPlay) return;

    _drawGhostCloneList(canvas, cam, ball.ghostClones1);
    _drawGhostCloneList(canvas, cam, ball.ghostClones2);
  }

  void _drawGhostCloneList(
      Canvas canvas, PerspectiveCamera cam, List<Vec3> clones) {
    final reducedEffects = game.settings.useReducedUltimateEffects;
    for (final clonePos in clones) {
      final screenPos = cam.project(clonePos);
      if (screenPos == null) continue;

      final scale = cam.depthScale(clonePos).clamp(0.4, 2.5);
      final radius = PhysicsConstants.ballRadius * 2.2 * scale;

      // Holographic ethereal clone
      _ghostClonePaint
        ..shader = reducedEffects
            ? null
            : const RadialGradient(
                colors: [
                  Color(0xEEF0ABFC),
                  Color(0x88A855F7),
                  Color(0x006B21A8),
                ],
                stops: [0.0, 0.6, 1.0],
              ).createShader(
                Rect.fromCircle(center: screenPos, radius: radius * 1.5),
              )
        ..color = const Color(0x99A855F7);

      canvas.drawCircle(screenPos, radius, _ghostClonePaint);

      // Neon ripple ring
      canvas.drawCircle(
        screenPos,
        radius * 1.3,
        _ghostRingPaint..color = const Color(0xAAEC4899),
      );
    }
  }

  void _drawUltimateVignette(Canvas canvas, Size size) {
    final ultSkill = game.currentUltimate;
    final pulse = 0.5 + 0.5 * math.sin(animTime * 8.0);
    final borderAlpha = (60 + 60 * pulse).toInt();

    if (game.settings.isLowEndMode) {
      _reusableStrokePaint
        ..shader = null
        ..color = ultSkill.primaryColor.withAlpha(borderAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
          const Radius.circular(16),
        ),
        _reusableStrokePaint,
      );
      return;
    }

    // Radiant outer border glow
    final borderPaint = _ultimateVignettePaint
      ..shader = LinearGradient(
        colors: [
          ultSkill.primaryColor.withAlpha(borderAlpha),
          ultSkill.accentColor.withAlpha((borderAlpha * 0.7).toInt()),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 6.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
        const Radius.circular(16),
      ),
      borderPaint,
    );
  }

  void _drawUltimateCutIn(Canvas canvas, Size size) {
    final ultType = game.activeCutinUltimate;
    if (ultType == null || game.ultimateCutinTimer <= 0) return;

    final ultSkill = getUltimateByType(ultType);
    final progress = (game.ultimateCutinTimer / 0.9).clamp(0.0, 1.0);
    final alpha = (progress > 0.8
            ? (1.0 - progress) / 0.2
            : (progress < 0.2 ? progress / 0.2 : 1.0))
        .clamp(0.0, 1.0);

    const ribbonHeight = 72.0;
    final centerY = size.height * 0.40;

    canvas.save();
    // Dynamic angled speed ribbon
    final path = Path()
      ..moveTo(0, centerY - ribbonHeight / 2 - 10)
      ..lineTo(size.width, centerY - ribbonHeight / 2 + 10)
      ..lineTo(size.width, centerY + ribbonHeight / 2 + 10)
      ..lineTo(0, centerY + ribbonHeight / 2 - 10)
      ..close();

    // Dark sleek backdrop with neon edge
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xEE0B132B).withAlpha((235 * alpha).toInt()),
    );

    // Accent energy stripe
    final stripePaint = _ultimateEffectStrokePaint
      ..shader = game.settings.useReducedUltimateEffects
          ? null
          : LinearGradient(
              colors: [
                ultSkill.primaryColor.withAlpha((255 * alpha).toInt()),
                ultSkill.accentColor.withAlpha((255 * alpha).toInt()),
                ultSkill.primaryColor.withAlpha((255 * alpha).toInt()),
              ],
            ).createShader(Rect.fromLTWH(
              0, centerY - ribbonHeight / 2, size.width, ribbonHeight))
      ..color = ultSkill.primaryColor.withAlpha((255 * alpha).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(path, stripePaint);

    // Text & Subtitle
    if (_cachedCutInType != ultType) {
      _cachedCutInType = ultType;
      _cachedCutInTitle = TextPainter(
        text: TextSpan(
          text: ultSkill.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _cachedCutInSubtitle = TextPainter(
        text: TextSpan(
          text: 'SPECIAL SHOT',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: ultSkill.accentColor,
            letterSpacing: 4.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final titlePainter = _cachedCutInTitle!;
    final subtitlePainter = _cachedCutInSubtitle!;

    final textX = size.width / 2 - titlePainter.width / 2;
    titlePainter.paint(canvas, Offset(textX, centerY - 16));
    subtitlePainter.paint(
      canvas,
      Offset(size.width / 2 - subtitlePainter.width / 2, centerY + 12),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(CourtPainter oldDelegate) {
    return oldDelegate.game != game ||
        oldDelegate.animTimeOverride != animTimeOverride;
  }
}
