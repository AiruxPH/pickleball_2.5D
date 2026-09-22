import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/pickleball_game.dart';
import '../models/pickleball.dart';
import '../models/player.dart';
import '../models/shop_items.dart';
import '../models/ultimate_skill.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';

/// ─────────────────────────────────────────────────────────────
/// CourtPainter — High-End Professional Tournament 3D Court Renderer
///
/// Inspired by official PPA Tour championships and broadcast graphics.
/// Renders:
///   1. Arena stadium atmosphere (grandstands, realistic crowd, floodlights)
///   2. 3D perimeter digital LED barrier boards
///   3. Dual-tone tournament court (apron, Pacific Blue surface, Teal kitchen)
///   4. Regulation net with authentic center strap and 34" droop
///   5. Pro athletic player characters with realistic sportswear & paddles
///   6. Tournament optic yellow ball with dynamic lighting & speed trail
///   7. Broadcast-style in-game notification banners
/// ─────────────────────────────────────────────────────────────

class CourtPainter extends CustomPainter {
  final PickleballGame game;
  final double animTime;

  CourtPainter({required this.game, required this.animTime});

  // ── High-performance cached Picture for static stadium crowd & background ──
  static ui.Picture? _cachedEnvPicture;
  static Size? _cachedEnvSize;
  static CourtTheme? _cachedEnvTheme;

  // ── Cached Paint objects (allocated once, reused every frame) ──
  static final Paint _railingFillPaint = Paint()..color = const Color(0x660F172A);
  static final Paint _railingLinePaint = Paint()
    ..color = const Color(0x8894A3B8)
    ..strokeWidth = 1.5;
  static final Paint _meshPaint = Paint()
    ..color = const Color(0x77FFFFFF)
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;
  static final Paint _topCableBackPaint = Paint()
    ..color = const Color(0x40000000)
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;
  static final Paint _topCablePaint = Paint()
    ..color = const Color(0xFFF8FAFC)
    ..strokeWidth = 2.8
    ..style = PaintingStyle.stroke;
  static final Paint _strapPaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.square;
  static final Paint _strapBucklePaint = Paint()..color = const Color(0xFF475569);
  static final Paint _postShadowPaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..strokeWidth = 5.0
    ..strokeCap = StrokeCap.round;
  static final Paint _postBodyPaint = Paint()
    ..color = const Color(0xFF334155)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round;
  static final Paint _postHighlightPaint = Paint()
    ..color = const Color(0xFF94A3B8)
    ..strokeWidth = 1.0;
  static final Paint _postCapPaint = Paint()..color = const Color(0xFF1E293B);
  static final Paint _linePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 2.0
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint _ballEdgePaint = Paint()
    ..color = const Color(0x55000000)
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;
  static final Paint _holePaint = Paint()..color = const Color(0x99556B2F);
  static final Paint _wrapPaint = Paint()
    ..color = const Color(0x33000000)
    ..strokeWidth = 1.0;

  // ── Cached TextPainter for static court branding (laid out once per size) ──
  TextPainter? _courtBrandingPainter;
  double _lastBoardWidth = -1;

  // ── Shadow oval paint (reused with updated alpha each frame) ──
  final Paint _ballShadowPaint = Paint();
  final Paint _playerShadowPaint = Paint()..color = const Color(0x4A000000);
  final Paint _netShadowPaint = Paint()..color = const Color(0x3C000000);

  @override
  void paint(Canvas canvas, Size size) {
    final cam = game.camera;
    cam.screenSize = size;

    // 1. Arena atmosphere & grandstands
    _drawEnvironment(canvas, size, cam);

    // 2. 3D Court perimeter LED barrier boards
    _drawPerimeterBoards(canvas, cam);

    // 3. Dual-tone tournament court surface with regulation lines
    _drawCourt(canvas, size, cam);

    // 3b. Serve target box visual guide
    if (game.state == GameState.waitingForServe) {
      _drawServiceBoxHighlight(canvas, cam);
    }

    // 3c. Frostbite ice freeze zone on court
    if (game.ball.iceZoneTimer > 0 && game.ball.iceZoneCenter != null) {
      _drawFrostIceZone(canvas, cam);
    }

    // 4. Opponent players (far side, behind net)
    _drawPlayer(canvas, cam, game.ai);
    if (game.aiPartner != null) {
      _drawPlayer(canvas, cam, game.aiPartner!);
    }

    // 5. Regulation net with center strap & realistic sag
    _drawNet(canvas, cam);

    // 6. Near side team players (human + partner, sorted by depth)
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

    // 7. Ball shadow, speed trail, ball & impact effect
    _drawBallShadow(canvas, cam);
    _drawBallTrail(canvas, cam);
    if (game.ball.isUltimate &&
        game.ball.ultimateType == UltimateType.ghostPhantom) {
      _drawGhostClones(canvas, cam);
    }
    _drawBall(canvas, cam);
    _drawImpactFlash(canvas, cam);

    // 8. Screen effects: Ultimate vignette glow & cinematic cut-in banner
    if (game.isUltimateArmed) {
      _drawUltimateVignette(canvas, size);
    }
    if (game.ultimateCutinTimer > 0 && game.activeCutinUltimate != null) {
      _drawUltimateCutIn(canvas, size);
    }

    // 9. Broadcast on-screen messages
    _drawMessage(canvas, size);
  }

  // ────────────────────────────────────────────────────────────
  // 1. Arena Atmosphere & Grandstands (Cached via ui.Picture for 60 FPS performance)
  // ────────────────────────────────────────────────────────────
  void _drawEnvironment(Canvas canvas, Size size, PerspectiveCamera cam) {
    final theme = game.settings.courtTheme;
    if (_cachedEnvPicture != null &&
        _cachedEnvSize == size &&
        _cachedEnvTheme == theme) {
      canvas.drawPicture(_cachedEnvPicture!);
      return;
    }

    final recorder = ui.PictureRecorder();
    final recCanvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    _renderEnvironmentToCanvas(recCanvas, size);
    _cachedEnvPicture = recorder.endRecording();
    _cachedEnvSize = size;
    _cachedEnvTheme = theme;

    canvas.drawPicture(_cachedEnvPicture!);
  }

  void _renderEnvironmentToCanvas(Canvas canvas, Size size) {
    final horizon = size.height * CameraConstants.horizonFraction;

    // Arena ceiling / evening sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF070B14), // Top: deep stadium arena night
          Color(0xFF0F1E36), // Mid: floodlight atmospheric haze
          Color(0xFF1B2F4E), // Horizon: arena court lighting
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon + 20));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Stadium Floodlights (left & right high stanchions)
    _drawFloodlight(canvas, size.width * 0.10, horizon * 0.28, true);
    _drawFloodlight(canvas, size.width * 0.90, horizon * 0.28, false);

    // Grandstand Seating Architecture (tiered concrete seating behind court)
    const tierCount = 5;
    final grandstandTop = horizon * 0.22;
    final grandstandHeight = horizon - grandstandTop;

    for (int tier = 0; tier < tierCount; tier++) {
      final t = tier / tierCount;
      final tierY = grandstandTop + t * grandstandHeight;
      final tierH = grandstandHeight / tierCount;

      // Tier shadow & seat ledge
      final tierColor = tier.isEven
          ? const Color(0xFF162032)
          : const Color(0xFF1E293B);
      canvas.drawRect(
        Rect.fromLTRB(0, tierY, size.width, tierY + tierH),
        Paint()..color = tierColor,
      );

      // Subtle metallic safety railing line
      canvas.drawLine(
        Offset(0, tierY + 1),
        Offset(size.width, tierY + 1),
        Paint()
          ..color = const Color(0x33475569)
          ..strokeWidth = 1.0,
      );

      // Realistic Spectator Crowd Silhouettes (natural tournament crowd attire)
      // Clustered spectators with varied clothing colors and natural spacing
      final crowdY = tierY + tierH * 0.45;
      const spectatorCols = 36;
      final colWidth = size.width / spectatorCols;

      for (int i = 0; i < spectatorCols; i++) {
        // Natural clustering: leave occasional aisle gaps
        if (i % 9 == 0) continue;

        // Pseudo-random deterministic jitter based on tier and col
        final seed = (tier * 73 + i * 37);
        final xJitter = ((seed % 11) - 5) * 0.8;
        final x = (i + 0.5) * colWidth + xJitter;

        // Spectator clothing palette (collegiate navy, white, heather gray, slate, subtle gold)
        final attirePalette = [
          const Color(0xFF0F172A), // Slate navy
          const Color(0xFFE2E8F0), // Clean white t-shirt
          const Color(0xFF475569), // Heather graphite
          const Color(0xFF1E3A5F), // Deep team navy
          const Color(0xFF334155), // Charcoal
          const Color(0xFFD97706), // Subtle tournament amber cap
          const Color(0xFFCBD5E1), // Light gray polo
          const Color(0xFF0369A1), // Pro blue shirt
        ];
        final bodyColor = attirePalette[seed % attirePalette.length];
        const headColor = Color(0xFFD4A373); // Neutral warm skin silhouette

        final spectatorScale = (0.55 + tier * 0.10); // Farther rows are smaller

        // Spectator Torso
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, crowdY + 2 * spectatorScale),
              width: 10 * spectatorScale,
              height: 9 * spectatorScale,
            ),
            Radius.circular(2 * spectatorScale),
          ),
          Paint()..color = bodyColor.withAlpha(210),
        );

        // Spectator Head
        canvas.drawCircle(
          Offset(x, crowdY - 4 * spectatorScale),
          3.2 * spectatorScale,
          Paint()..color = headColor.withAlpha(190),
        );

        // Occasional spectator cap
        if (seed % 3 == 0) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(x, crowdY - 5 * spectatorScale),
              radius: 3.4 * spectatorScale,
            ),
            math.pi,
            math.pi,
            true,
            Paint()..color = bodyColor,
          );
        }
      }
    }

    // Grandstand Glass Railing Barrier at bottom of stands
    final railingY = horizon - 2;
    canvas.drawRect(
      Rect.fromLTRB(0, railingY, size.width, horizon + 6),
      _railingFillPaint,
    );
    canvas.drawLine(
      Offset(0, railingY),
      Offset(size.width, railingY),
      _railingLinePaint,
    );
  }

  void _drawFloodlight(Canvas canvas, double x, double y, bool isLeft) {
    // Soft radial light flare
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

    // Floodlight lamp bank housing
    final bankRect = Rect.fromCenter(center: Offset(x, y), width: 22, height: 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bankRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF334155),
    );

    // Glowing LED emitters
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
  // 2. 3D Perimeter Digital LED Barrier Boards
  // ────────────────────────────────────────────────────────────
  void _drawPerimeterBoards(Canvas canvas, PerspectiveCamera cam) {
    final court = game.court;
    final hw = court.halfWidth;

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
      canvas.drawPath(
        boardPath,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF030712)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTRB(pTL.dx, pTL.dy, pBR.dx, pBR.dy)),
      );

      // Top glowing cyan LED edge
      canvas.drawLine(
        pTL,
        pTR,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 2.0,
      );

      // Tournament Branding on the back board — cached TextPainter
      final boardWidth = (pTR.dx - pTL.dx).abs();
      if ((boardWidth - _lastBoardWidth).abs() > 1.0 || _courtBrandingPainter == null) {
        _lastBoardWidth = boardWidth;
        _courtBrandingPainter = TextPainter(
          text: TextSpan(
            text: '\u2605  PRO PICKLEBALL TOUR  \u2605  CENTER COURT  \u2605',
            style: TextStyle(
              fontSize: (boardWidth * 0.024).clamp(7.0, 13.0),
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: const Color(0xFFF8FAFC).withAlpha(220),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }
      final tp = _courtBrandingPainter!;
      final boardMidY = (pTL.dy + pBL.dy) / 2;
      tp.paint(canvas, Offset((pTL.dx + pTR.dx) / 2 - tp.width / 2, boardMidY - tp.height / 2));
    }

    // Left and Right Side Barriers extending toward player
    _drawSideBarrier(canvas, cam, -hw - 16.0, true);
    _drawSideBarrier(canvas, cam, hw + 16.0, false);
  }

  void _drawSideBarrier(Canvas canvas, PerspectiveCamera cam, double xPos, bool isLeft) {
    const boardH = 3.8;
    const zFar = -88.0 - 15.0;
    const zNear = 88.0 + 18.0;

    final pFarBot = cam.project(Vec3(xPos, 0, zFar));
    final pFarTop = cam.project(Vec3(xPos, boardH, zFar));
    final pNearBot = cam.project(Vec3(xPos, 0, zNear));
    final pNearTop = cam.project(Vec3(xPos, boardH, zNear));

    if (pFarBot == null || pFarTop == null || pNearBot == null || pNearTop == null) return;

    final path = Path()
      ..moveTo(pFarTop.dx, pFarTop.dy)
      ..lineTo(pNearTop.dx, pNearTop.dy)
      ..lineTo(pNearBot.dx, pNearBot.dy)
      ..lineTo(pFarBot.dx, pFarBot.dy)
      ..close();

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

    // Glowing top trim
    canvas.drawLine(
      pFarTop,
      pNearTop,
      Paint()
        ..color = const Color(0xFF0284C7).withAlpha(180)
        ..strokeWidth = 1.5,
    );
  }

  // ────────────────────────────────────────────────────────────
  // 3. Tournament Court Surface & Regulation Markings
  // ────────────────────────────────────────────────────────────
  void _drawCourt(Canvas canvas, Size sz, PerspectiveCamera cam) {
    final court = game.court;
    final hw = court.halfWidth;
    final hl = court.halfLength;

    // ── A. Tournament Apron (Outer Run-off Area) ──────────────
    // Extends past playing court boundary
    const apronPadX = 14.0;
    const apronPadZ = 15.0;
    final apron3D = [
      Vec3(-hw - apronPadX, 0, -hl - apronPadZ),
      Vec3(hw + apronPadX, 0, -hl - apronPadZ),
      Vec3(hw + apronPadX, 0, hl + apronPadZ + 6),
      Vec3(-hw - apronPadX, 0, hl + apronPadZ + 6),
    ];
    final apron2D = apron3D.map((v) => cam.project(v)).toList();

    if (!apron2D.any((p) => p == null)) {
      final apronPath = Path()
        ..moveTo(apron2D[0]!.dx, apron2D[0]!.dy)
        ..lineTo(apron2D[1]!.dx, apron2D[1]!.dy)
        ..lineTo(apron2D[2]!.dx, apron2D[2]!.dy)
        ..lineTo(apron2D[3]!.dx, apron2D[3]!.dy)
        ..close();

      // Deep tournament slate apron with subtle light gradient
      canvas.drawPath(
        apronPath,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFF0F1D33), // Far apron
              Color(0xFF162544), // Near apron
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(apronPath.getBounds()),
      );
    }

    // ── B. Playing Court Surface (Pacific Blue) ───────────────
    final court3D = [
      Vec3(-hw, 0, -hl),
      Vec3(hw, 0, -hl),
      Vec3(hw, 0, hl),
      Vec3(-hw, 0, hl),
    ];
    final court2D = court3D.map((v) => cam.project(v)).toList();
    if (court2D.any((p) => p == null)) return;

    final courtPath = Path()
      ..moveTo(court2D[0]!.dx, court2D[0]!.dy)
      ..lineTo(court2D[1]!.dx, court2D[1]!.dy)
      ..lineTo(court2D[2]!.dx, court2D[2]!.dy)
      ..lineTo(court2D[3]!.dx, court2D[3]!.dy)
      ..close();

    // Tournament Pacific Blue dual-tone surface
    canvas.drawPath(
      courtPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0369A1), // Far court
            Color(0xFF0284C7), // Center court
            Color(0xFF0EA5E9), // Near court
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.45, 1.0],
        ).createShader(courtPath.getBounds()),
    );

    // ── C. Non-Volley Zone (The Kitchen - Precision Teal) ─────
    _drawZone(canvas, cam, hw, court.playerKitchenNear, court.playerKitchenFar,
        const Color(0xFF007799));
    _drawZone(canvas, cam, hw, court.aiKitchenFar, court.aiKitchenNear,
        const Color(0xFF006B8A));

    // ── D. Regulation Court Markings ──────────────────────────
    _drawCourtLines(canvas, cam, hw, hl, court.playerKitchenFar, court.aiKitchenFar);
  }

  void _drawZone(Canvas canvas, PerspectiveCamera cam, double halfW,
      double zNear, double zFar, Color color) {
    final pts = [
      cam.project(Vec3(-halfW, 0, zNear)),
      cam.project(Vec3(halfW, 0, zNear)),
      cam.project(Vec3(halfW, 0, zFar)),
      cam.project(Vec3(-halfW, 0, zFar)),
    ];
    if (pts.any((p) => p == null)) return;

    final path = Path()
      ..moveTo(pts[0]!.dx, pts[0]!.dy)
      ..lineTo(pts[1]!.dx, pts[1]!.dy)
      ..lineTo(pts[2]!.dx, pts[2]!.dy)
      ..lineTo(pts[3]!.dx, pts[3]!.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _drawCourtLines(Canvas canvas, PerspectiveCamera cam, double hw,
      double hl, double kitchenZ, double aiKitchenZ) {
    void line3D(Vec3 a, Vec3 b) {
      final pa = cam.project(a);
      final pb = cam.project(b);
      if (pa != null && pb != null) {
        canvas.drawLine(pa, pb, _linePaint);
      }
    }

    // Outer boundary lines
    line3D(Vec3(-hw, 0, hl), Vec3(hw, 0, hl));   // Player baseline
    line3D(Vec3(-hw, 0, -hl), Vec3(hw, 0, -hl)); // AI baseline
    line3D(Vec3(-hw, 0, -hl), Vec3(-hw, 0, hl)); // Left sideline
    line3D(Vec3(hw, 0, -hl), Vec3(hw, 0, hl));   // Right sideline

    // Center service lines (extends from baseline to kitchen line)
    line3D(Vec3(0, 0, hl), Vec3(0, 0, kitchenZ));
    line3D(Vec3(0, 0, -hl), Vec3(0, 0, aiKitchenZ));

    // Kitchen (Non-Volley Zone) lines
    line3D(Vec3(-hw, 0, kitchenZ), Vec3(hw, 0, kitchenZ));
    line3D(Vec3(-hw, 0, aiKitchenZ), Vec3(hw, 0, aiKitchenZ));
  }

  // ── Serve Target Diagonal Service Box Highlight ─────────────
  void _drawServiceBoxHighlight(Canvas canvas, PerspectiveCamera cam) {
    final court = game.court;
    final hw = court.halfWidth;
    final hl = court.halfLength;
    final kitchenZ = court.kitchenDepth;
    final serverRight = game.scoreController.serverShouldBeOnRight;
    final isPlayerServing = game.scoreController.isPlayerServing;

    // Determine target service box coordinates:
    double x1, x2, z1, z2;
    if (isPlayerServing) {
      // Human serves to AI side (negative Z)
      z1 = -kitchenZ;
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
      z1 = kitchenZ;
      z2 = hl;
      if (serverRight) {
        x1 = 0;
        x2 = hw;
      } else {
        x1 = -hw;
        x2 = 0;
      }
    }

    final p1 = cam.project(Vec3(x1, 0, z1));
    final p2 = cam.project(Vec3(x2, 0, z1));
    final p3 = cam.project(Vec3(x2, 0, z2));
    final p4 = cam.project(Vec3(x1, 0, z2));
    if (p1 == null || p2 == null || p3 == null || p4 == null) return;

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    final pulse = (math.sin(animTime * 4) + 1) / 2;

    // Translucent tournament green highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ballColor.withAlpha((22 + pulse * 18).toInt())
        ..style = PaintingStyle.fill,
    );

    // Glowing border outline
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ballColor.withAlpha((140 + pulse * 90).toInt())
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
  }

  // ────────────────────────────────────────────────────────────
  // 4. Regulation Net with Center Strap & Realistic Sag
  // ────────────────────────────────────────────────────────────
  void _drawNet(Canvas canvas, PerspectiveCamera cam) {
    const netPostH = CourtDimensions.netHeight; // 3.0 units (36 inches)
    const netCenterH = netPostH * 0.944;        // 2.83 units (34 inches at center!)
    const hw = CourtDimensions.halfWidth;
    const postX = hw + 2.5;

    // Posts in 3D
    final postLeftTop = cam.project(Vec3(-postX, netPostH, 0));
    final postLeftBot = cam.project(Vec3(-postX, 0, 0));
    final postRightTop = cam.project(Vec3(postX, netPostH, 0));
    final postRightBot = cam.project(Vec3(postX, 0, 0));

    // Center point in 3D
    final centerTop = cam.project(Vec3(0, netCenterH, 0));
    final centerBot = cam.project(Vec3(0, 0, 0));

    if (postLeftTop == null || postLeftBot == null ||
        postRightTop == null || postRightBot == null ||
        centerTop == null || centerBot == null) {
      return;
    }

    // ── Net Ground Shadow — cheap oval, no blur ───────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset((postLeftBot.dx + postRightBot.dx) / 2, (postLeftBot.dy + postRightBot.dy) / 2 + 1),
        width: (postRightBot.dx - postLeftBot.dx).abs() * 0.96,
        height: 6,
      ),
      _netShadowPaint,
    );

    // ── Net Mesh (reduced to 8 segments — same visual quality) ────
    const segments = 8;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final x3d = -hw + t * (hw * 2);
      // Realistic catenary curve drop toward center
      final sagFactor = 1.0 - math.sin(t * math.pi) * 0.056;
      final y3d = netPostH * sagFactor;

      final pTop = cam.project(Vec3(x3d, y3d, 0));
      final pBot = cam.project(Vec3(x3d, 0, 0));
      if (pTop != null && pBot != null) {
        canvas.drawLine(pTop, pBot, _meshPaint);
      }
    }

    // Horizontal mesh cords (4 cords instead of 7)
    const horizCords = 4;
    for (int j = 1; j <= horizCords; j++) {
      final frac = j / (horizCords + 1);
      final meshPath = Path();
      bool started = false;
      for (int i = 0; i <= segments; i++) {
        final t = i / segments;
        final x3d = -hw + t * (hw * 2);
        final sagFactor = 1.0 - math.sin(t * math.pi) * 0.056;
        final y3d = netPostH * sagFactor * frac;
        final pt = cam.project(Vec3(x3d, y3d, 0));
        if (pt != null) {
          if (!started) {
            meshPath.moveTo(pt.dx, pt.dy);
            started = true;
          } else {
            meshPath.lineTo(pt.dx, pt.dy);
          }
        }
      }
      canvas.drawPath(meshPath, _meshPaint);
    }

    // ── Top White Vinyl Headband (Regulation Top Cable) ─────────
    final topCablePath = Path();
    topCablePath.moveTo(postLeftTop.dx, postLeftTop.dy);
    topCablePath.quadraticBezierTo(centerTop.dx, centerTop.dy, postRightTop.dx, postRightTop.dy);

    // Cable shadow/backing
    canvas.drawPath(
      topCablePath,
      _topCableBackPaint,
    );
    // Crisp white vinyl tape
    canvas.drawPath(
      topCablePath,
      _topCablePaint,
    );

    // ── Center Strap (Vertical White Strap pulling to 34") ──────
    canvas.drawLine(centerTop, centerBot, _strapPaint);
    // Center strap buckle detail
    canvas.drawCircle(
      Offset(centerTop.dx, (centerTop.dy + centerBot.dy) / 2),
      2.0,
      _strapBucklePaint,
    );

    // ── Powder-Coated Metal Posts ──────────────────────────────
    _drawNetPost(canvas, postLeftBot, postLeftTop);
    _drawNetPost(canvas, postRightBot, postRightTop);
  }

  void _drawNetPost(Canvas canvas, Offset bot, Offset top) {
    // Post shadow
    canvas.drawLine(bot, top, _postShadowPaint);
    // Metallic dark titanium cylinder
    canvas.drawLine(
      bot,
      top,
      _postBodyPaint,
    );
    // Specular highlight stripe
    canvas.drawLine(
      Offset(bot.dx - 0.8, bot.dy),
      Offset(top.dx - 0.8, top.dy),
      _postHighlightPaint,
    );
    // Post cap
    canvas.drawCircle(top, 3.2, _postCapPaint);
  }

  // ────────────────────────────────────────────────────────────
  // 5. Pro Athletic Player Models
  // ────────────────────────────────────────────────────────────
  void _drawPlayer(Canvas canvas, PerspectiveCamera cam, Player p) {
    final screenPos = cam.project(p.position);
    if (screenPos == null) return;

    final scale = cam.depthScale(p.position).clamp(0.3, 2.0);
    final isPartner = p.isPartner;
    final isAI = !p.isHuman && !p.isPartner;

    canvas.save();
    canvas.translate(screenPos.dx, screenPos.dy);
    canvas.scale(scale);

    // ── Smooth Contact Shadow on Court Floor — cheap oval, no blur ───
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 32), width: 34, height: 10),
      _playerShadowPaint,
    );

    // Tournament Athletic Sportswear Palette
    // Human: Equipped Player Skin Palette
    // Human Partner: Team Precision Teal & Chartreuse
    // AI: Pro Tournament Coral & Midnight Navy
    final Color jerseyMain;
    final Color jerseyLight;
    final Color jerseyAccent;
    final Color shortsColor;
    final Color skinColor;
    final Color shoeAccent;

    if (isPartner) {
      jerseyMain = const Color(0xFF0369A1); // Team Teal
      jerseyLight = const Color(0xFF0284C7);
      jerseyAccent = const Color(0xFFD4E157); // Chartreuse trim
      shortsColor = const Color(0xFF1E293B);
      skinColor = const Color(0xFFE0AC82);
      shoeAccent = const Color(0xFF38BDF8);
    } else if (isAI) {
      jerseyMain = const Color(0xFFEA580C); // Pro Coral
      jerseyLight = const Color(0xFFF97316);
      jerseyAccent = const Color(0xFFFFFFFF);
      shortsColor = const Color(0xFF0F172A);
      skinColor = const Color(0xFFE0AC82);
      shoeAccent = const Color(0xFFEA580C);
    } else {
      final equippedSkin = game.currentPlayerSkin;
      jerseyMain = equippedSkin.jerseyMain;
      jerseyLight = equippedSkin.jerseyLight;
      jerseyAccent = equippedSkin.jerseyAccent;
      shortsColor = equippedSkin.shortsColor;
      skinColor = equippedSkin.skinColor;
      shoeAccent = equippedSkin.shoeAccent;
    }

    const shoeMain = Color(0xFFF8FAFC);

    // ── Legs & Pro Court Shoes ─────────────────────────────────
    final legAngle = math.sin(p.legCycleTimer) * 0.35;
    _drawProLeg(canvas, -7, legAngle, shortsColor, skinColor, shoeMain, shoeAccent);
    _drawProLeg(canvas, 7, -legAngle, shortsColor, skinColor, shoeMain, shoeAccent);

    // ── Athletic Torso / Jersey ────────────────────────────────
    final torsoRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -24, 22, 26),
      const Radius.circular(5),
    );
    // Performance jersey with athletic gradient
    canvas.drawRRect(
      torsoRect,
      Paint()
        ..shader = LinearGradient(
          colors: [jerseyLight, jerseyMain],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(-11, -24, 22, 26)),
    );

    // Athletic side accent stripes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -22, 2.5, 22),
        const Radius.circular(1),
      ),
      Paint()..color = jerseyAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8.5, -22, 2.5, 22),
        const Radius.circular(1),
      ),
      Paint()..color = jerseyAccent,
    );

    // Jersey back number / logo emblem
    if (!isAI) {
      canvas.drawCircle(
        const Offset(0, -12),
        4.5,
        Paint()..color = Colors.white.withAlpha(40),
      );
    } else {
      // Pro tournament polo collar V-neck
      final collarPath = Path()
        ..moveTo(-5, -24)
        ..lineTo(0, -17)
        ..lineTo(5, -24);
      canvas.drawPath(
        collarPath,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Athletic Head & Visor/Cap ───────────────────────────────
    // Neck
    canvas.drawRect(
      const Rect.fromLTWH(-4, -28, 8, 5),
      Paint()..color = const Color(0xFFC6956D),
    );

    // Head
    canvas.drawCircle(
      const Offset(0, -32),
      10.5,
      Paint()..color = skinColor,
    );

    if (isAI) {
      // Pro Competitor facing forward: athletic sports visor & sunglasses silhouette
      // Sunglasses
      final glassesRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -35, 16, 5),
        const Radius.circular(2),
      );
      canvas.drawRRect(glassesRect, Paint()..color = const Color(0xFF0F172A));
      // Subtle polarized lens glare
      canvas.drawLine(
        const Offset(-6, -33),
        const Offset(-2, -33),
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 1.2,
      );
      // Performance Visor
      canvas.drawArc(
        const Rect.fromLTWH(-10.5, -42, 21, 14),
        math.pi,
        math.pi,
        true,
        Paint()..color = jerseyMain,
      );
      // Visor brim
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -37, 24, 3.5),
          const Radius.circular(1.5),
        ),
        Paint()..color = jerseyMain,
      );
    } else {
      // Human Player seen from behind: performance athletic cap & neck taper
      // Hair at nape
      canvas.drawCircle(
        const Offset(0, -28),
        7.5,
        Paint()..color = const Color(0xFF2C1810),
      );
      // Athletic Cap crown
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10.5, -43, 21, 13),
          const Radius.circular(6),
        ),
        Paint()..color = jerseyMain,
      );
      // Adjustment strap / ponytail slot
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.5, -34, 7, 3),
          const Radius.circular(1.5),
        ),
        Paint()..color = skinColor,
      );
      // Accent cap button
      canvas.drawCircle(const Offset(0, -43), 1.5, Paint()..color = jerseyAccent);
    }

    // ── Non-Dominant Arm (Natural Balance Posture) ──────────────
    _drawBalanceArm(canvas, isAI ? 9 : -9, skinColor, jerseyMain, isAI);

    // ── Dominant Paddle Arm & Carbon-Fiber Paddle ──────────────
    _drawProPaddleArm(canvas, p, skinColor, jerseyMain, isAI);

    canvas.restore();
  }

  void _drawProLeg(Canvas canvas, double xOffset, double angle,
      Color shortsColor, Color skinColor, Color shoeMain, Color shoeAccent) {
    canvas.save();
    canvas.translate(xOffset, 2);
    canvas.rotate(angle);

    // Performance athletic shorts
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.5, 0, 9, 12),
        const Radius.circular(2),
      ),
      Paint()..color = shortsColor,
    );

    // Athletic leg / calf
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.5, 11, 7, 13),
        const Radius.circular(2),
      ),
      Paint()..color = skinColor,
    );

    // Pro Tennis Shoe
    // Shoe body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5.5, 23, 12, 7),
        const Radius.circular(3),
      ),
      Paint()..color = shoeMain,
    );
    // Colored sports stripe
    canvas.drawRect(
      const Rect.fromLTWH(-4.5, 25, 10, 2),
      Paint()..color = shoeAccent,
    );
    // Rubber outsole grip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5.5, 28, 12, 2.5),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFF334155),
    );

    canvas.restore();
  }

  void _drawBalanceArm(Canvas canvas, double xOffset, Color skinColor,
      Color jerseyColor, bool isAI) {
    canvas.save();
    canvas.translate(xOffset, -18);

    // Sleeve
    canvas.drawCircle(Offset.zero, 4, Paint()..color = jerseyColor);
    // Arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(isAI ? 0 : -5, 0, 5, 15),
        const Radius.circular(2.5),
      ),
      Paint()..color = skinColor,
    );

    canvas.restore();
  }

  void _drawProPaddleArm(Canvas canvas, Player p, Color skinColor,
      Color jerseyColor, bool isAI) {
    double armAngle = isAI ? -0.25 : 0.25;

    if (p.isSwinging) {
      final swingT = p.swingArm;
      if (p.isForehand) {
        armAngle = isAI ? -0.25 + swingT * 1.7 : 0.25 - swingT * 1.7;
      } else {
        armAngle = isAI ? -0.25 - swingT * 1.7 : 0.25 + swingT * 1.7;
      }
    }

    canvas.save();
    canvas.translate(isAI ? -9 : 9, -18);
    canvas.rotate(armAngle);

    // Sleeve
    canvas.drawCircle(Offset.zero, 4.5, Paint()..color = jerseyColor);

    // Upper arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, 0, 6, 14),
        const Radius.circular(3),
      ),
      Paint()..color = skinColor,
    );

    // Forearm
    canvas.translate(0, 13);
    canvas.rotate(armAngle * 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2.8, 0, 5.6, 12),
        const Radius.circular(2.8),
      ),
      Paint()..color = skinColor,
    );

    // Wristband
    canvas.drawRect(
      const Rect.fromLTWH(-3.2, 9, 6.4, 3),
      Paint()..color = const Color(0xFFF8FAFC),
    );

    // ── Carbon-Fiber Pickleball Paddle ────────────────────────
    canvas.translate(0, 12);
    _drawCarbonPaddle(canvas, isAI, isAI ? null : game.currentPaddle);

    canvas.restore();
  }

  void _drawCarbonPaddle(Canvas canvas, bool isAI, [PaddleItem? paddle]) {
    final gripTape = isAI
        ? const Color(0xFFF8FAFC)
        : (paddle?.gripTapeColor ?? const Color(0xFFF8FAFC));
    final gripCollar = isAI
        ? const Color(0xFF0F172A)
        : (paddle?.gripCollarColor ?? const Color(0xFF0F172A));
    final blade1 = isAI
        ? const Color(0xFF1E293B)
        : (paddle?.bladeColor1 ?? const Color(0xFF1E293B));
    final blade2 = isAI
        ? const Color(0xFF0F172A)
        : (paddle?.bladeColor2 ?? const Color(0xFF0F172A));
    final rimColor = isAI
        ? const Color(0xFFEA580C)
        : (paddle?.rimColor ?? const Color(0xFF0284C7));
    final chevronColor = isAI
        ? const Color(0xFFF97316).withAlpha(120)
        : (paddle?.chevronColor.withAlpha(160) ??
            const Color(0xFF38BDF8).withAlpha(120));

    // 1. Cushioned Ergonomic Grip Handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2.5, 0, 5, 13),
        const Radius.circular(2.5),
      ),
      Paint()..color = gripTape,
    );
    // Spiral wrap grip lines
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(-2.5, i * 3.2), Offset(2.5, i * 3.2), _wrapPaint);
    }
    // Rubber grip collar ring
    canvas.drawRect(
      const Rect.fromLTWH(-3, 0, 6, 2),
      Paint()..color = gripCollar,
    );

    // 2. Modern Elongated Carbon-Fiber Paddle Face
    canvas.translate(0, 13);
    final paddleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, 0, 20, 26),
      const Radius.circular(6),
    );

    // Matte Carbon-Fiber Face with texture
    canvas.drawRRect(
      paddleRect,
      Paint()
        ..shader = LinearGradient(
          colors: [blade1, blade2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(-10, 0, 20, 26)),
    );

    // Protective Edge Guard (Rim)
    canvas.drawRRect(
      paddleRect,
      Paint()
        ..color = rimColor
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // Custom Face Graphics
    final pattern = paddle?.patternType ?? 'chevrons';
    if (pattern == 'rings') {
      canvas.drawCircle(
        const Offset(0, 13),
        5,
        Paint()
          ..color = chevronColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        const Offset(0, 13),
        2,
        Paint()..color = chevronColor,
      );
    } else if (pattern == 'lightning') {
      final p = Path()
        ..moveTo(-3, 6)
        ..lineTo(2, 12)
        ..lineTo(-1, 13)
        ..lineTo(3, 20);
      canvas.drawPath(
        p,
        Paint()
          ..color = chevronColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    } else if (pattern == 'honeycomb') {
      for (double y = 6; y <= 20; y += 5) {
        canvas.drawLine(
          Offset(-5, y),
          Offset(5, y),
          Paint()
            ..color = chevronColor
            ..strokeWidth = 0.8,
        );
      }
    } else {
      // Tour Honeycomb Core Graphics / Graphic Chevron
      final chevronPaint = Paint()
        ..color = chevronColor
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(-6, 8), const Offset(0, 14), chevronPaint);
      canvas.drawLine(const Offset(6, 8), const Offset(0, 14), chevronPaint);
      canvas.drawLine(const Offset(-6, 13), const Offset(0, 19), chevronPaint);
      canvas.drawLine(const Offset(6, 13), const Offset(0, 19), chevronPaint);
    }
  }

  // ────────────────────────────────────────────────────────────
  // 6. Ball Shadow, Speed Trail & High-Vis Tournament Pickleball
  // ────────────────────────────────────────────────────────────
  void _drawBallShadow(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    final isVisible = ball.isInPlay || game.state == GameState.waitingForServe;
    if (!isVisible) return;

    final shadowPos = cam.project(Vec3(ball.position.x, 0.05, ball.position.z));
    if (shadowPos == null) return;

    final heightFactor = (1.0 - (ball.position.y / 55).clamp(0.0, 1.0));
    final shadowScale = cam.depthScale(Vec3(ball.position.x, 0, ball.position.z));

    // Cheap oval shadow — no MaskFilter.blur (saved ~2ms/frame on web)
    _ballShadowPaint.color = Color.fromARGB(
      (110 * heightFactor).toInt(),
      0, 0, 0,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: shadowPos,
        width: 14 * shadowScale * (0.6 + 0.4 * heightFactor),
        height: 6 * shadowScale * (0.6 + 0.4 * heightFactor),
      ),
      _ballShadowPaint,
    );
  }

  void _drawBallTrail(Canvas canvas, PerspectiveCamera cam) {
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

      for (int i = 1; i < ball.trail.length; i++) {
        final prev = cam.project(ball.trail[i - 1]);
        final curr = cam.project(ball.trail[i]);
        if (prev == null || curr == null) continue;

        final t = i / ball.trail.length;
        final alpha = (t * 240).toInt();

        // Primary core beam
        canvas.drawLine(
          prev,
          curr,
          Paint()
            ..color = primaryTrailColor.withAlpha(alpha)
            ..strokeWidth = 4.2 * t * strokeMult
            ..strokeCap = StrokeCap.round,
        );

        // Outer neon aura ribbon
        canvas.drawLine(
          prev,
          curr,
          Paint()
            ..color = secondaryTrailColor.withAlpha((alpha * 0.7).toInt())
            ..strokeWidth = 6.8 * t * strokeMult
            ..strokeCap = StrokeCap.round,
        );

        // Thunderbolt electric spark jitter
        if (ultType == UltimateType.thunderbolt && i % 2 == 0) {
          final jitterX = (math.sin(i * 9.0 + animTime * 20.0)) * 5.0;
          final jitterY = (math.cos(i * 9.0 + animTime * 20.0)) * 5.0;
          canvas.drawLine(
            curr,
            Offset(curr.dx + jitterX, curr.dy + jitterY),
            Paint()
              ..color = const Color(0xFFFFFFFF).withAlpha((alpha * 0.9).toInt())
              ..strokeWidth = 1.8,
          );
        }

        // Dragon Meteor ember spark specks
        if (ultType == UltimateType.dragonMeteor && i % 2 == 1) {
          final emberX = (math.sin(i * 13.0 + animTime * 15.0)) * 6.0;
          final emberY = (math.cos(i * 13.0 + animTime * 15.0)) * 6.0;
          canvas.drawCircle(
            Offset(curr.dx + emberX, curr.dy + emberY),
            2.0 * t,
            Paint()..color = const Color(0xFFFBBF24).withAlpha(alpha),
          );
        }
      }
      return;
    }

    final isPowerShot = ball.speed > PhysicsConstants.normalHitPower * 0.8;

    for (int i = 1; i < ball.trail.length; i++) {
      final prev = cam.project(ball.trail[i - 1]);
      final curr = cam.project(ball.trail[i]);
      if (prev == null || curr == null) continue;

      final t = i / ball.trail.length;
      final alpha = (t * (isPowerShot ? 220 : 130)).toInt();
      final color = isPowerShot
          ? AppColors.power.withAlpha(alpha)
          : AppColors.ballColor.withAlpha(alpha);

      canvas.drawLine(
        prev,
        curr,
        Paint()
          ..color = color
          ..strokeWidth = isPowerShot ? (3.5 * t) : (2.2 * t)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawBall(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    final isVisible = (ball.state != BallState.dead) &&
        (ball.isInPlay || game.state == GameState.waitingForServe);
    if (!isVisible) return;

    final screenPos = cam.project(ball.position);
    if (screenPos == null) return;

    final scale = cam.depthScale(ball.position).clamp(0.4, 2.5);
    final radius = PhysicsConstants.ballRadius * 2.3 * scale;

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
      canvas.drawCircle(
        screenPos,
        radius * 1.85,
        Paint()
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

    // High-Vis Tournament Optic Yellow Ball Body
    final ballPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFF9FBE7), // Bright specular highlight
          Color(0xFFD4E157), // Tournament chartreuse yellow
          Color(0xFFAFB42B), // Ambient shadow side
        ],
        center: Alignment(-0.35, -0.40),
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: screenPos, radius: radius));
    canvas.drawCircle(screenPos, radius, ballPaint);

    // Subtle edge rim for crisp visibility
    canvas.drawCircle(
      screenPos,
      radius,
      _ballEdgePaint,
    );

    // Aerodynamic Perforated Holes (Official 26-40 hole pattern)
    for (final angle in const [0.0, 1.05, 2.09, 3.14, 4.19, 5.24]) {
      final hx =
          screenPos.dx + math.cos(angle + ball.spinAngle) * radius * 0.52;
      final hy =
          screenPos.dy + math.sin(angle + ball.spinAngle) * radius * 0.52;
      canvas.drawCircle(Offset(hx, hy), radius * 0.16, _holePaint);
    }
    // Center hole
    canvas.drawCircle(screenPos, radius * 0.14, _holePaint);
  }

  void _drawImpactFlash(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    if (ball.impactFlash <= 0) return;

    final screenPos = cam.project(ball.position);
    if (screenPos == null) return;

    final scale = cam.depthScale(ball.position).clamp(0.4, 2.5);
    final r = PhysicsConstants.ballRadius * 5.5 * scale * ball.impactFlash;

    // Clean radial impact burst — cheap, no blur
    final flashPaint = Paint()
      ..color = Colors.white.withAlpha((180 * ball.impactFlash).toInt());
    canvas.drawCircle(screenPos, r, flashPaint);
  }

  // ────────────────────────────────────────────────────────────
  // 7. Broadcast-Style In-Game Messages
  // ────────────────────────────────────────────────────────────
  void _drawMessage(Canvas canvas, Size size) {
    if (game.lastMessage.isEmpty || game.messageTimer <= 0) return;

    final alpha = (game.messageTimer / 1.5).clamp(0.0, 1.0);
    final scale = 1.0 + (1.0 - alpha) * 0.2;

    // Clean broadcast banner capsule
    final tp = TextPainter(
      text: TextSpan(
        text: game.lastMessage.toUpperCase(),
        style: TextStyle(
          fontSize: 26 * scale,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFF8FAFC).withAlpha((255 * alpha).toInt()),
          letterSpacing: 4.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = tp.width + 48;
    final badgeHeight = tp.height + 20;
    final badgeCenter = Offset(size.width / 2, size.height * 0.30);
    final badgeRect = Rect.fromCenter(center: badgeCenter, width: badgeWidth, height: badgeHeight);

    // Frosted dark pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(24)),
      Paint()..color = const Color(0xEB0B132B).withAlpha((235 * alpha).toInt()),
    );

    // Gold / Coral accent trim
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(24)),
      Paint()
        ..color = const Color(0xFFF59E0B).withAlpha((200 * alpha).toInt())
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  // ────────────────────────────────────────────────────────────
  // 8. Ultimate Skill Special VFX Renderers
  // ────────────────────────────────────────────────────────────
  void _drawFrostIceZone(Canvas canvas, PerspectiveCamera cam) {
    final center3D = game.ball.iceZoneCenter;
    if (center3D == null || game.ball.iceZoneTimer <= 0) return;

    final center2D = cam.project(Vec3(center3D.x, 0.08, center3D.z));
    if (center2D == null) return;

    final scale = cam.depthScale(center3D);
    final radius = game.ball.iceZoneRadius * scale * 2.2;
    final alpha = (game.ball.iceZoneTimer / 3.5).clamp(0.0, 1.0);

    // Ice ground oval
    final icePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xAA00E5FF).withAlpha((140 * alpha).toInt()),
          const Color(0x6600B0FF).withAlpha((90 * alpha).toInt()),
          const Color(0x000284C7),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center2D, radius: radius));

    canvas.drawOval(
      Rect.fromCenter(center: center2D, width: radius * 2, height: radius * 0.9),
      icePaint,
    );

    // Frost crystal ring border
    final ringPaint = Paint()
      ..color = const Color(0xFFE0F7FA).withAlpha((180 * alpha).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawOval(
      Rect.fromCenter(
          center: center2D, width: radius * 1.9, height: radius * 0.85),
      ringPaint,
    );

    // Snowflake crystal spikes around perimeter
    final spikePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withAlpha((210 * alpha).toInt())
      ..strokeWidth = 1.6;
    for (int i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 + animTime * 0.5;
      final px = center2D.dx + math.cos(ang) * radius * 0.95;
      final py = center2D.dy + math.sin(ang) * radius * 0.42;
      canvas.drawLine(Offset(px - 3, py), Offset(px + 3, py), spikePaint);
      canvas.drawLine(Offset(px, py - 3), Offset(px, py + 3), spikePaint);
    }
  }

  void _drawGhostClones(Canvas canvas, PerspectiveCamera cam) {
    final ball = game.ball;
    if (!ball.isInPlay) return;

    final allClones = [...ball.ghostClones1, ...ball.ghostClones2];
    for (int i = 0; i < allClones.length; i++) {
      final clonePos = allClones[i];
      final screenPos = cam.project(clonePos);
      if (screenPos == null) continue;

      final scale = cam.depthScale(clonePos).clamp(0.4, 2.5);
      final radius = PhysicsConstants.ballRadius * 2.2 * scale;

      // Holographic ethereal clone
      final clonePaint = Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xEEF0ABFC),
            Color(0x88A855F7),
            Color(0x006B21A8),
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(
            Rect.fromCircle(center: screenPos, radius: radius * 1.5));

      canvas.drawCircle(screenPos, radius, clonePaint);

      // Neon ripple ring
      canvas.drawCircle(
        screenPos,
        radius * 1.3,
        Paint()
          ..color = const Color(0xAAEC4899)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawUltimateVignette(Canvas canvas, Size size) {
    final ultSkill = game.currentUltimate;
    final pulse = 0.5 + 0.5 * math.sin(animTime * 8.0);
    final borderAlpha = (60 + 60 * pulse).toInt();

    // Radiant outer border glow
    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          ultSkill.primaryColor.withAlpha(borderAlpha),
          ultSkill.accentColor.withAlpha((borderAlpha * 0.7).toInt()),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
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
    final progress = (game.ultimateCutinTimer / 1.4).clamp(0.0, 1.0);
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
      Paint()
        ..color =
            const Color(0xEE0B132B).withAlpha((235 * alpha).toInt()),
    );

    // Accent energy stripe
    final stripePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          ultSkill.primaryColor.withAlpha((255 * alpha).toInt()),
          ultSkill.accentColor.withAlpha((255 * alpha).toInt()),
          ultSkill.primaryColor.withAlpha((255 * alpha).toInt()),
        ],
      ).createShader(Rect.fromLTWH(
          0, centerY - ribbonHeight / 2, size.width, ribbonHeight))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(path, stripePaint);

    // Text & Subtitle
    final titlePainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${ultSkill.name}  ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white.withAlpha((255 * alpha).toInt()),
              letterSpacing: 3.5,
              shadows: [
                Shadow(
                  color: ultSkill.primaryColor
                      .withAlpha((240 * alpha).toInt()),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          TextSpan(
            text: '[${ultSkill.japaneseName}]',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ultSkill.primaryColor
                  .withAlpha((245 * alpha).toInt()),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final subtitlePainter = TextPainter(
      text: TextSpan(
        text: '★ SUPER ULTIMATE ACTIVATED ★',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: ultSkill.accentColor.withAlpha((230 * alpha).toInt()),
          letterSpacing: 4.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

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
    // Only repaint when game state or animation time has meaningfully changed
    final b = game.ball;
    final ob = oldDelegate.game.ball;
    if ((animTime - oldDelegate.animTime).abs() < 0.004) return false;
    if (b.position.x != ob.position.x ||
        b.position.y != ob.position.y ||
        b.position.z != ob.position.z) {
      return true;
    }
    if (game.player.position.x != oldDelegate.game.player.position.x ||
        game.player.position.z != oldDelegate.game.player.position.z) {
      return true;
    }
    if (game.ai.position.x != oldDelegate.game.ai.position.x ||
        game.ai.position.z != oldDelegate.game.ai.position.z) {
      return true;
    }
    if (game.state != oldDelegate.game.state) return true;
    if (game.lastMessage != oldDelegate.game.lastMessage) return true;
    if (game.player.animState != oldDelegate.game.player.animState) return true;
    if (b.impactFlash > 0 || ob.impactFlash > 0) return true;
    if (b.spinAngle != ob.spinAngle) return true;
    return animTime != oldDelegate.animTime;
  }
}
