import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/shop_items.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CharacterRenderer
///
/// High-fidelity articulated 3D-stylized athlete renderer for Pickleball 3D.
/// Faithfully reproduces the visual designs of:
///   1. Player Pro (player_pro.png): Blonde hair, white visor, teal & white geometric jersey, orange court sneakers.
///   2. AI Rival (ai_rival.png): Dark hair, navy/coral visor, polarized sunglasses, navy & coral polo, Champion crest.
///   3. Partner Pro (partner_pro.png): Dirty blonde hair, two-tone cap, royal blue & neon lime burst jersey, orange sneakers.
///
/// Features silky-smooth kinematic athletic locomotion:
///   - Dual-segmented articulated legs with knee flexion & foot-plant angles.
///   - Kinetic banking lean & forward acceleration tilt.
///   - Organic step cadence & rhythmic vertical breathing / ready-stance sway.
///   - Directional facing orientation (smooth horizontal flip).
///   - Multi-phase dynamic paddle swings with luminous speed arc blur.
///   - Dynamic soft ground shadow reactive to foot elevation.
/// ─────────────────────────────────────────────────────────────────────────────
class CharacterRenderer {
  // Pre-cached paints for performance.
  // Soft shadows use a unit-circle radial gradient that is scaled into an
  // ellipse at draw time — much cheaper than MaskFilter.blur (esp. on web).
  static final Paint _contactShadowPaint = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0x8A02060E), Color(0x4002060E), Color(0x0002060E)],
      stops: [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.0));
  static final Paint _castShadowPaint = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0x3802060E), Color(0x1A02060E), Color(0x0002060E)],
      stops: [0.0, 0.6, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.0));

  static final Paint _sockPaint = Paint()..color = const Color(0xFFF8FAFC);
  static final Paint _shoeMidsolePaint = Paint()
    ..color = const Color(0xFFFFFFFF);
  static final Paint _shoeOutsolePaint = Paint()
    ..color = const Color(0xFF334155);

  // ── Lighting state for the character currently being drawn ──────────────
  // +1 → key light hits the local left side (screen upper-left floodlights).
  static double _lightSide = 1.0;
  static bool _shade = true;

  /// Cylindrical form shading: highlight on the lit edge, core shadow on the
  /// far edge. Falls back to a flat fill in low-end mode.
  static Paint _shaded(Color base, Rect bounds,
      {double highlight = 0.22, double shadow = 0.34}) {
    if (!_shade) return Paint()..color = base;
    final lit = Color.lerp(base, Colors.white, highlight)!;
    final dark = Color.lerp(base, Colors.black, shadow)!;
    final fromLeft = _lightSide > 0;
    return Paint()
      ..shader = LinearGradient(
        colors: [lit, base, dark],
        stops: const [0.0, 0.42, 1.0],
        begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
      ).createShader(bounds);
  }

  /// Main render call for in-game court players
  static void drawPlayer({
    required Canvas canvas,
    required Player player,
    required PerspectiveCamera? cam,
    required bool isLowEnd,
    required bool showShadow,
    PlayerSkinItem? equippedSkin,
    PaddleItem? equippedPaddle,
    double manualScale = 1.0,
  }) {
    double scale = manualScale;
    if (cam != null) {
      final screenPos = cam.project(player.position);
      if (screenPos == null) return;
      final headPos = cam.projectCoords(
        player.position.x,
        player.position.y + CourtDimensions.playerHeight,
        player.position.z,
      );
      if (headPos == null) return;
      scale =
          ((headPos - screenPos).distance / CourtDimensions.characterArtHeight)
              .clamp(0.05, 5.0);

      canvas.save();
      canvas.translate(screenPos.dx, screenPos.dy);
    } else {
      canvas.save();
    }

    canvas.scale(scale);

    final isPartner = player.isPartner;
    final isAI = !player.isHuman && !player.isPartner;
    final runWeight = player.runBlend.clamp(0.0, 1.0);

    // ── 1. Silky Smooth Bodily Locomotion Transforms ──────────────────────────
    // Organic vertical bounce & breathing sway
    final bouncePhase = math.sin(player.legCycleTimer * 2.0);
    final idleSway = math.sin(player.animTimer * 2.5);
    final stepBob = runWeight * (bouncePhase * 0.5 + 0.5) * 3.0 +
        (1.0 - runWeight) * (idleSway * 0.7);

    // ── 2. Ground Shadows (drawn in ground space: unaffected by bob/lean) ─────
    if (showShadow) {
      drawGroundShadows(canvas, isAI, stepBob, isLowEnd);
    }

    canvas.translate(0, -stepBob);

    // Lateral banking lean
    canvas.rotate(player.smoothedLean);

    // Directional orientation — eased turn instead of an instant mirror snap.
    // A small minimum width keeps the body readable mid-turn.
    final f = player.facingFlip;
    final flip = f.abs() < 0.16 ? (f >= 0 ? 0.16 : -0.16) : f;
    canvas.scale(flip, 1.0);

    _lightSide = flip >= 0 ? 1.0 : -1.0;
    _shade = !isLowEnd;

    // ── 3. Color & Aesthetic Palette Configuration ───────────────────────────
    final CharacterPalette pal = _resolvePalette(
      isAI: isAI,
      isPartner: isPartner,
      equippedSkin: equippedSkin,
    );

    // ── 4. Articulated Legs (Back Leg first, then Front Leg) ───────────────────
    final legCycle = player.legCycleTimer;
    final leftLegAngle = math.sin(legCycle) * 0.50 * runWeight;
    final rightLegAngle = -math.sin(legCycle) * 0.50 * runWeight;

    // Draw far leg
    _drawArticulatedLeg(
      canvas: canvas,
      xOffset: -7.5,
      angle: leftLegAngle,
      pal: pal,
      isAI: isAI,
      isLowEnd: isLowEnd,
    );

    // ── 5. Non-Dominant Balance Arm (Counter-Balancing Stride) ────────────────
    final balanceAngle = runWeight > 0.05
        ? -math.sin(legCycle) * 0.40 * runWeight
        : (isAI ? 0.12 : -0.12);
    _drawBalanceArm(
      canvas: canvas,
      xOffset: isAI ? 10.0 : -10.0,
      pal: pal,
      isAI: isAI,
      armAngle: balanceAngle,
    );

    // ── 6. Athletic V-Taper Torso & Signature Jersey ─────────────────────────
    _drawTorso(
      canvas: canvas,
      pal: pal,
      isAI: isAI,
      isPartner: isPartner,
      isLowEnd: isLowEnd,
    );

    // ── 7. Near Articulated Leg (Foreground) ──────────────────────────────────
    _drawArticulatedLeg(
      canvas: canvas,
      xOffset: 7.5,
      angle: rightLegAngle,
      pal: pal,
      isAI: isAI,
      isLowEnd: isLowEnd,
    );

    // ── 8. Head, Hair, Eyewear & Visor / Cap ──────────────────────────────────
    _drawHeadgear(
      canvas: canvas,
      pal: pal,
      isAI: isAI,
      isPartner: isPartner,
      isLowEnd: isLowEnd,
    );

    // ── 9. Dominant Paddle Arm & Dynamic Multi-Phase Swing ────────────────────
    _drawDominantPaddleArm(
      canvas: canvas,
      player: player,
      pal: pal,
      isAI: isAI,
      isPartner: isPartner,
      paddle: equippedPaddle,
      isLowEnd: isLowEnd,
    );

    // ── 10. Luminous Speed Arc Trail on Swing ─────────────────────────────────
    if (player.isSwinging && !isLowEnd) {
      drawSwingSpeedArc(
        canvas: canvas,
        isAI: isAI,
        isPartner: isPartner,
        isForehand: player.isForehand,
        progress: player.swingArm,
      );
    }

    canvas.restore();
  }

  /// Soft contact shadow under the feet plus a faint long shadow cast away
  /// from the arena floodlights. Shrinks/lightens as the body lifts.
  static void drawGroundShadows(
      Canvas canvas, bool isAI, double stepBob, bool isLowEnd) {
    final lift = (stepBob.abs() * 0.035).clamp(0.0, 0.3);
    final w = (isAI ? 21.0 : 19.0) * (1.0 - lift);
    final h = (isAI ? 6.2 : 5.6) * (1.0 - lift);

    // Long directional floodlight shadow (up-right on screen = away from light)
    if (!isLowEnd) {
      canvas.save();
      canvas.translate(15.0, 29.0);
      canvas.rotate(-0.22);
      canvas.scale(30.0, 6.5);
      canvas.drawCircle(Offset.zero, 1.0, _castShadowPaint);
      canvas.restore();
    }

    // Ambient-occlusion contact shadow
    canvas.save();
    canvas.translate(0, 33.0);
    canvas.scale(w, h);
    canvas.drawCircle(Offset.zero, 1.0, _contactShadowPaint);
    canvas.restore();
  }

  /// Draw articulated multi-segment leg with knee flex and court sneaker
  static void _drawArticulatedLeg({
    required Canvas canvas,
    required double xOffset,
    required double angle,
    required CharacterPalette pal,
    required bool isAI,
    required bool isLowEnd,
  }) {
    canvas.save();
    canvas.translate(xOffset, 2);
    canvas.rotate(angle);

    // Athletic performance shorts with notched outer seam
    const shortsBounds = Rect.fromLTWH(-4.8, 0, 9.6, 13.0);
    final shortsRect = RRect.fromRectAndRadius(
      shortsBounds,
      const Radius.circular(2.5),
    );
    canvas.drawRRect(shortsRect, _shaded(pal.shortsColor, shortsBounds));

    // Subtle outer seam notch
    canvas.drawLine(
      Offset(xOffset < 0 ? -4.8 : 4.8, 10.5),
      Offset(xOffset < 0 ? -2.8 : 2.8, 13.0),
      Paint()
        ..color = Colors.white.withAlpha(45)
        ..strokeWidth = 1.0,
    );

    // Upper thigh (skin tone with subtle muscular shading)
    const thighBounds = Rect.fromLTWH(-3.6, 10.5, 7.2, 4.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(thighBounds, const Radius.circular(1.6)),
      _shaded(pal.skinColor, thighBounds),
    );

    // Knee joint & flex on backswing
    final kneeBend = (angle < 0) ? -angle * 0.78 : 0.0;
    canvas.translate(0, 12.5);
    canvas.rotate(kneeBend);

    // Muscular sculpted athletic calf
    const calfBounds = Rect.fromLTWH(-3.5, 0, 7.0, 11.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(calfBounds, const Radius.circular(2.5)),
      _shaded(pal.skinColor, calfBounds),
    );

    // White crew compression sock
    canvas.drawRect(
      const Rect.fromLTWH(-3.3, 7.5, 6.6, 4.8),
      _sockPaint,
    );
    // Colored sports stripe on sock
    canvas.drawRect(
      const Rect.fromLTWH(-3.3, 8.2, 6.6, 1.2),
      Paint()..color = pal.shoeAccent,
    );

    // Pro Court Sneaker (matching reference sneakers)
    canvas.translate(0, 11.5);
    canvas.rotate(-angle * 0.28); // Foot-plant angle

    // Sneaker Upper
    const shoeBounds = Rect.fromLTWH(-5.8, 0, 13.0, 7.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shoeBounds, const Radius.circular(3.2)),
      _shaded(pal.shoeUpper, shoeBounds, highlight: 0.28),
    );

    // Side speed stripe / lace collar
    canvas.drawRect(
      const Rect.fromLTWH(-5.0, 1.5, 11.0, 1.8),
      Paint()..color = pal.shoeAccent,
    );

    // White EVA Cushioning Midsole
    canvas.drawRect(
      const Rect.fromLTWH(-5.8, 4.8, 13.0, 2.4),
      _shoeMidsolePaint,
    );

    // Dark Rubber Grip Outsole
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5.8, 6.2, 13.0, 1.8),
        const Radius.circular(1.0),
      ),
      _shoeOutsolePaint,
    );

    canvas.restore();
  }

  /// Athletic V-taper torso with accurate reference jersey graphic patterns
  static void _drawTorso({
    required Canvas canvas,
    required CharacterPalette pal,
    required bool isAI,
    required bool isPartner,
    required bool isLowEnd,
  }) {
    final torsoPath = Path()
      ..moveTo(-12.5, -25.5)
      ..lineTo(12.5, -25.5)
      ..lineTo(10.8, 2.5)
      ..lineTo(-10.8, 2.5)
      ..close();

    // 1. Base Gradient Jersey
    if (isLowEnd) {
      canvas.drawPath(torsoPath, Paint()..color = pal.jerseyMain);
    } else {
      canvas.drawPath(
        torsoPath,
        Paint()
          ..shader = LinearGradient(
            colors: [pal.jerseyLight, pal.jerseyMain],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(const Rect.fromLTWH(-12.5, -25.5, 25, 28)),
      );
    }

    // 2. Character-Specific Signature Graphic Texture
    if (!isLowEnd) {
      canvas.save();
      canvas.clipPath(torsoPath);

      if (isAI) {
        // AI Rival: Aggressive fiery coral diagonal speed lines & geometric lattice
        final coralLinePaint = Paint()
          ..color = pal.jerseyAccent.withAlpha(160)
          ..strokeWidth = 1.4;
        for (double lx = -22; lx <= 22; lx += 6) {
          canvas.drawLine(Offset(lx, -26), Offset(lx + 16, 4), coralLinePaint);
        }
        final subtleLinePaint = Paint()
          ..color = pal.jerseyAccent.withAlpha(70)
          ..strokeWidth = 0.9;
        for (double lx = -20; lx <= 20; lx += 8) {
          canvas.drawLine(
              Offset(lx + 10, -26), Offset(lx - 6, 4), subtleLinePaint);
        }
      } else if (isPartner) {
        // Partner Pro: Royal blue with neon lime-green criss-cross burst grid
        final limeBurstPaint = Paint()
          ..color = pal.jerseyAccent.withAlpha(150)
          ..strokeWidth = 1.3;
        for (double lx = -24; lx <= 24; lx += 5.5) {
          canvas.drawLine(Offset(lx, -26), Offset(lx + 14, 4), limeBurstPaint);
          canvas.drawLine(Offset(lx + 14, -26), Offset(lx, 4), limeBurstPaint);
        }
      } else {
        // Player Pro: Turquoise & white intricate diamond-geometric lattice pattern
        final whiteLatticePaint = Paint()
          ..color = Colors.white.withAlpha(90)
          ..strokeWidth = 1.2;
        for (double lx = -24; lx <= 24; lx += 5.2) {
          canvas.drawLine(
              Offset(lx, -26), Offset(lx + 13, 4), whiteLatticePaint);
          canvas.drawLine(
              Offset(lx + 13, -26), Offset(lx, 4), whiteLatticePaint);
        }
      }
      canvas.restore();
    }

    // 3. Contrast Breathability Side Panels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12.0, -23.5, 2.6, 23.0),
        const Radius.circular(1.2),
      ),
      Paint()..color = pal.jerseyAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9.4, -23.5, 2.6, 23.0),
        const Radius.circular(1.2),
      ),
      Paint()..color = pal.jerseyAccent,
    );

    // 3b. Volumetric form shading over the jersey (lit edge → core shadow),
    //     plus waist ambient occlusion where the shirt meets the shorts.
    if (!isLowEnd) {
      const torsoBounds = Rect.fromLTWH(-12.5, -25.5, 25.0, 28.0);
      final fromLeft = _lightSide > 0;
      canvas.drawPath(
        torsoPath,
        Paint()
          ..shader = LinearGradient(
            colors: const [
              Color(0x38FFFFFF),
              Color(0x00FFFFFF),
              Color(0x00000000),
              Color(0x66000000),
            ],
            stops: const [0.0, 0.3, 0.55, 1.0],
            begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          ).createShader(torsoBounds),
      );
      canvas.drawPath(
        torsoPath,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00000000), Color(0x00000000), Color(0x55000000)],
            stops: [0.0, 0.78, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(torsoBounds),
      );
    }

    // 4. Performance Collar / Neckline
    if (isAI) {
      // Pro Polo collar with buttons (as in ai_rival.png)
      final collarPath = Path()
        ..moveTo(-7, -25.5)
        ..lineTo(-2, -18)
        ..lineTo(0, -18)
        ..lineTo(2, -18)
        ..lineTo(7, -25.5);
      canvas.drawPath(
        collarPath,
        Paint()
          ..color = pal.jerseyAccent
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // Button placket
      canvas.drawLine(
        const Offset(0, -18),
        const Offset(0, -14),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.2,
      );
      // "CHAMPION" Team Logo Crest
      canvas.drawCircle(
        const Offset(5, -12),
        3.2,
        Paint()..color = Colors.white.withAlpha(200),
      );
    } else {
      // V-Neck Performance Collar (as in player_pro.png & partner_pro.png)
      final collarPath = Path()
        ..moveTo(-6.5, -25.5)
        ..lineTo(0, -18.5)
        ..lineTo(6.5, -25.5);
      canvas.drawPath(
        collarPath,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // Chest Crest Emblem
      canvas.drawCircle(
        const Offset(0, -12),
        3.8,
        Paint()..color = Colors.white.withAlpha(65),
      );
    }
  }

  /// Head, hair, visor/cap, eyewear & facial details
  static void _drawHeadgear({
    required Canvas canvas,
    required CharacterPalette pal,
    required bool isAI,
    required bool isPartner,
    required bool isLowEnd,
  }) {
    // Tapered Muscular Neck
    canvas.drawRect(
      const Rect.fromLTWH(-4.2, -28.5, 8.4, 5.2),
      Paint()..color = Color.lerp(pal.skinColor, Colors.black, 0.12)!,
    );

    // Head Volume — spherical shading with the key light up-left
    const headCenter = Offset(0, -34.0);
    const headRadius = 11.2;
    if (isLowEnd) {
      canvas.drawCircle(headCenter, headRadius, Paint()..color = pal.skinColor);
    } else {
      canvas.drawCircle(
        headCenter,
        headRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(pal.skinColor, Colors.white, 0.20)!,
              pal.skinColor,
              Color.lerp(pal.skinColor, Colors.black, 0.35)!,
            ],
            stops: const [0.0, 0.55, 1.0],
            center: Alignment(_lightSide > 0 ? -0.4 : 0.4, -0.45),
            radius: 0.95,
          ).createShader(
              Rect.fromCircle(center: headCenter, radius: headRadius)),
      );
    }

    if (isAI) {
      // ── AI Rival: Front View with Sunglasses, Visor & Styled Dark Hair ────
      // Styled Dark Hair top volume
      canvas.drawCircle(
          const Offset(-4, -42), 6.0, Paint()..color = pal.hairDark);
      canvas.drawCircle(
          const Offset(4, -42), 6.0, Paint()..color = pal.hairDark);
      canvas.drawCircle(
          const Offset(0, -44), 6.8, Paint()..color = pal.hairMid);

      // Polarized Wraparound Sports Sunglasses
      final glassesRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9.0, -37.0, 18.0, 6.2),
        const Radius.circular(2.8),
      );
      canvas.drawRRect(glassesRect, Paint()..color = const Color(0xFF0F172A));

      // Specular glare reflection on polarized lenses
      canvas.drawLine(
        const Offset(-7.0, -34.8),
        const Offset(-2.0, -34.8),
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        const Offset(2.0, -34.8),
        const Offset(7.0, -34.8),
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );

      // Pro Sports Visor Crown (Midnight Navy)
      canvas.drawArc(
        const Rect.fromLTWH(-11.5, -44.5, 23.0, 14.5),
        math.pi,
        math.pi,
        true,
        Paint()..color = pal.jerseyMain,
      );
      // Curved Fiery Coral Visor Brim
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-13.0, -39.2, 26.0, 4.0),
          const Radius.circular(2.0),
        ),
        Paint()..color = pal.jerseyAccent,
      );
      // Wave emblem on visor
      canvas.drawLine(
        const Offset(-3, -41),
        const Offset(3, -41),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.2,
      );
    } else if (isPartner) {
      // ── Partner Pro: 3/4 Back View with Teal/White Baseball Cap & Blonde Hair ──
      // Dirty blonde wavy hair locks spilling under cap
      canvas.drawCircle(
          const Offset(0, -30.0), 8.5, Paint()..color = pal.hairDark);
      canvas.drawCircle(
          const Offset(-8.5, -34.0), 5.0, Paint()..color = pal.hairMid);
      canvas.drawCircle(
          const Offset(8.5, -34.0), 5.0, Paint()..color = pal.hairMid);

      // Cap White Back Crown Panel
      canvas.drawArc(
        const Rect.fromLTWH(-11.2, -43.0, 22.4, 15.0),
        math.pi,
        math.pi,
        true,
        Paint()..color = Colors.white,
      );
      // Turquoise Cap Brim & Crown Front
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12.5, -39.0, 25.0, 4.2),
          const Radius.circular(2.0),
        ),
        Paint()..color = const Color(0xFF00A896),
      );
      // Cap Button on top
      canvas.drawCircle(const Offset(0, -43.0), 2.0,
          Paint()..color = const Color(0xFF00A896));
    } else {
      // ── Player Pro: 3/4 Back View with White Visor & Layered Blonde Hair ──
      // Layered Blonde Hair Locks (matching player_pro.png)
      canvas.drawCircle(
          const Offset(0, -30.0), 8.5, Paint()..color = pal.hairDark);
      canvas.drawCircle(
          const Offset(-8.5, -34.0), 5.2, Paint()..color = pal.hairMid);
      canvas.drawCircle(
          const Offset(8.5, -34.0), 5.2, Paint()..color = pal.hairMid);
      canvas.drawCircle(
          const Offset(-6.2, -38.5), 4.4, Paint()..color = pal.hairLight);
      canvas.drawCircle(
          const Offset(6.2, -38.5), 4.4, Paint()..color = pal.hairLight);
      canvas.drawCircle(
          const Offset(0, -41.5), 6.0, Paint()..color = pal.hairMid);

      // 3D White Performance Visor Crown
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11.5, -42.5, 23.0, 7.8),
          const Radius.circular(3.6),
        ),
        Paint()..color = Colors.white,
      );
      // Curved Visor Brim
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12.5, -38.5, 25.0, 3.8),
          const Radius.circular(2.0),
        ),
        Paint()..color = const Color(0xFFF1F5F9),
      );
      // Visor Rear Elastic Adjustment Band
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4.5, -37.0, 9.0, 2.6),
          const Radius.circular(1.2),
        ),
        Paint()..color = const Color(0xFF334155),
      );
    }
  }

  /// Balance arm (non-dominant arm counter-balancing strides)
  static void _drawBalanceArm({
    required Canvas canvas,
    required double xOffset,
    required CharacterPalette pal,
    required bool isAI,
    required double armAngle,
  }) {
    canvas.save();
    canvas.translate(xOffset, -18.5);
    canvas.rotate(armAngle);

    // Sleeve
    canvas.drawCircle(Offset.zero, 4.8, Paint()..color = pal.jerseyMain);

    // Upper & Forearm
    final armBounds = Rect.fromLTWH(isAI ? 0 : -5.0, 0, 5.0, 14.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(armBounds, const Radius.circular(2.6)),
      _shaded(pal.skinColor, armBounds),
    );

    // White Terrycloth Wristband
    canvas.drawRect(
      Rect.fromLTWH(isAI ? 0 : -5.0, 11.5, 5.0, 3.4),
      _sockPaint,
    );

    canvas.restore();
  }

  /// Dominant paddle arm with articulated swing phases
  static void _drawDominantPaddleArm({
    required Canvas canvas,
    required Player player,
    required CharacterPalette pal,
    required bool isAI,
    required bool isPartner,
    required PaddleItem? paddle,
    required bool isLowEnd,
  }) {
    double armAngle = isAI ? -0.26 : 0.26;

    if (player.isSwinging) {
      final t = player.swingArm;
      // Multi-phase dynamic swing arc: windup -> strike -> follow-through
      if (player.isForehand) {
        armAngle = isAI ? -0.35 + t * 2.4 : 0.35 - t * 2.4;
      } else {
        armAngle = isAI ? -0.35 - t * 2.4 : 0.35 + t * 2.4;
      }
    } else if (player.runBlend > 0.05) {
      // Dynamic ready arm bounce synced to stride
      armAngle += math.sin(player.legCycleTimer) * 0.15 * player.runBlend;
    } else {
      // Idle ready stance ready-waggle
      armAngle += math.sin(player.animTimer * 2.5) * 0.05;
    }

    canvas.save();
    canvas.translate(isAI ? -10.0 : 10.0, -18.5);
    canvas.rotate(armAngle);

    // Sleeve
    canvas.drawCircle(Offset.zero, 5.0, Paint()..color = pal.jerseyMain);

    // Muscular Upper Arm
    const upperArmBounds = Rect.fromLTWH(-3.2, 0, 6.4, 13.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(upperArmBounds, const Radius.circular(3.0)),
      _shaded(pal.skinColor, upperArmBounds),
    );

    // Forearm
    canvas.translate(0, 13.0);
    canvas.rotate(armAngle * 0.36);
    const forearmBounds = Rect.fromLTWH(-2.8, 0, 5.6, 12.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(forearmBounds, const Radius.circular(2.8)),
      _shaded(pal.skinColor, forearmBounds),
    );

    // White Compression Wristband
    canvas.drawRect(
      const Rect.fromLTWH(-3.3, 8.5, 6.6, 3.5),
      _sockPaint,
    );

    // ── Pickleball Paddle ─────────────────────────────────────────────────────
    canvas.translate(0, 12.0);
    _drawPaddle(
      canvas: canvas,
      isAI: isAI,
      isPartner: isPartner,
      paddle: paddle,
    );

    canvas.restore();
  }

  /// Character-specific or custom equipped pickleball paddle
  static void _drawPaddle({
    required Canvas canvas,
    required bool isAI,
    required bool isPartner,
    required PaddleItem? paddle,
  }) {
    // Grip tape & collar
    final gripTape = isAI
        ? const Color(0xFFF8FAFC)
        : (paddle?.gripTapeColor ?? const Color(0xFFF8FAFC));
    final gripCollar = isAI
        ? const Color(0xFF0F172A)
        : (paddle?.gripCollarColor ?? const Color(0xFF0F172A));

    // Handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2.2, 0, 4.4, 12.5),
        const Radius.circular(1.2),
      ),
      Paint()..color = gripTape,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-2.4, 0, 4.8, 2.2),
      Paint()..color = gripCollar,
    );

    // Paddle Blade
    canvas.translate(0, 12.0);
    final bladeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-8.0, 0, 16.0, 22.0),
      const Radius.circular(5.0),
    );

    if (isAI) {
      // AI Rival: Aggressive black carbon paddle with fiery coral & gold graphic
      canvas.drawRRect(
        bladeRect,
        Paint()..color = const Color(0xFF0F172A),
      );
      // Fiery coral aerodynamic blade graphic
      final aiGraphic = Path()
        ..moveTo(-6, 3)
        ..lineTo(0, 18)
        ..lineTo(6, 3)
        ..close();
      canvas.drawPath(
        aiGraphic,
        Paint()..color = const Color(0xFFFF5722),
      );
      canvas.drawLine(
        const Offset(0, 2),
        const Offset(0, 19),
        Paint()
          ..color = const Color(0xFFFFD700)
          ..strokeWidth = 1.4,
      );
    } else if (isPartner) {
      // Partner Pro: Cyan, neon lime, and purple geometric paddle (as in partner_pro.png)
      canvas.drawRRect(
        bladeRect,
        Paint()..color = const Color(0xFF0284C7),
      );
      // Neon Lime cross pattern
      final pGraphic = Path()
        ..moveTo(-7, 4)
        ..lineTo(7, 18)
        ..lineTo(4, 19)
        ..lineTo(-7, 8)
        ..close();
      canvas.drawPath(
        pGraphic,
        Paint()..color = const Color(0xFFD4E157),
      );
    } else if (paddle != null) {
      // Equipped Custom Shop Paddle
      canvas.drawRRect(
        bladeRect,
        Paint()
          ..shader = LinearGradient(
            colors: [paddle.bladeColor1, paddle.bladeColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(const Rect.fromLTWH(-8.0, 0, 16.0, 22.0)),
      );
      // Honeycomb center texture
      canvas.drawCircle(
        const Offset(0, 11),
        4.0,
        Paint()..color = paddle.chevronColor.withAlpha(120),
      );
    } else {
      // Player Pro: Default vibrant swirl paddle (orange, teal, yellow)
      canvas.drawRRect(
        bladeRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFF6D00), Color(0xFF00A896)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(const Rect.fromLTWH(-8.0, 0, 16.0, 22.0)),
      );
      canvas.drawCircle(
        const Offset(0, 11),
        4.2,
        Paint()..color = const Color(0xFFFFD54F).withAlpha(180),
      );
    }

    // Glossy face sheen (carbon / fibreglass clear-coat catching the lights)
    if (_shade) {
      canvas.drawRRect(
        bladeRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x55FFFFFF),
              Color(0x00FFFFFF),
              Color(0x00000000),
              Color(0x40000000),
            ],
            stops: [0.0, 0.35, 0.6, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(const Rect.fromLTWH(-8.0, 0, 16.0, 22.0)),
      );
    }

    // Outer Edge Guard
    canvas.drawRRect(
      bladeRect,
      Paint()
        ..color = isAI
            ? const Color(0xFFEA580C)
            : (paddle?.rimColor ?? const Color(0xFF1E293B))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  /// Dynamic speed arc trail on swing
  static void drawSwingSpeedArc({
    required Canvas canvas,
    required bool isAI,
    required bool isPartner,
    required bool isForehand,
    required double progress,
  }) {
    final arcColor = isAI
        ? const Color(0xFFFF5722) // Coral
        : isPartner
            ? const Color(0xFFD4E157) // Lime
            : const Color(0xFF00E5FF); // Cyan

    // The arc "draws on" with the swing and fades out on the follow-through,
    // reading as motion blur of the paddle rather than a static decal.
    final p = progress.clamp(0.0, 1.0);
    final sweep = 1.85 * math.min(1.0, 0.15 + p * 1.6);
    final fade = p < 0.6 ? 1.0 : (1.0 - (p - 0.6) / 0.4).clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    final sweepX = isForehand ? 18.0 : -18.0;
    final arcRect = Rect.fromCenter(
      center: Offset(sweepX, -8),
      width: 46,
      height: 40,
    );
    final start = isForehand ? -0.8 : math.pi - 0.8;

    // Wide soft glow pass + narrow bright core (no blur filter needed)
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = arcColor.withAlpha((70 * fade).round())
        ..strokeWidth = 9.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = arcColor.withAlpha((190 * fade).round())
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      arcRect,
      start + sweep * 0.55,
      sweep * 0.45,
      false,
      Paint()
        ..color = Colors.white.withAlpha((150 * fade).round())
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Resolve color palette based on character role or equipped shop skin
  static CharacterPalette _resolvePalette({
    required bool isAI,
    required bool isPartner,
    required PlayerSkinItem? equippedSkin,
  }) {
    if (isAI) {
      // AI Rival Palette (ai_rival.png)
      return const CharacterPalette(
        jerseyMain: Color(0xFF0F172A), // Midnight Navy
        jerseyLight: Color(0xFF1E293B),
        jerseyAccent: Color(0xFFFF5722), // Fiery Coral
        shortsColor: Color(0xFF090D16), // Deep Midnight
        skinColor: Color(0xFFC67D52), // Tanned
        hairDark: Color(0xFF0F172A), // Dark Hair
        hairMid: Color(0xFF1E293B),
        hairLight: Color(0xFF334155),
        shoeUpper: Color(0xFF0F172A), // Navy Sneaker
        shoeAccent: Color(0xFFFF5722), // Coral Accent
      );
    }

    if (isPartner) {
      // Partner Pro Palette (partner_pro.png)
      return const CharacterPalette(
        jerseyMain: Color(0xFF0284C7), // Royal Blue
        jerseyLight: Color(0xFF0369A1),
        jerseyAccent: Color(0xFFD4E157), // Neon Lime Green
        shortsColor: Color(0xFF1E293B), // Charcoal
        skinColor: Color(0xFFDE9B6D), // Tan
        hairDark: Color(0xFFB45309), // Dirty Blonde / Brown
        hairMid: Color(0xFFD97706),
        hairLight: Color(0xFFFBBF24),
        shoeUpper: Color(0xFFFF6D00), // Orange Sneaker
        shoeAccent: Color(0xFFF8FAFC), // White Accent
      );
    }

    if (equippedSkin != null) {
      // Custom Equipped Shop Skin
      return CharacterPalette(
        jerseyMain: equippedSkin.jerseyMain,
        jerseyLight: equippedSkin.jerseyLight,
        jerseyAccent: equippedSkin.jerseyAccent,
        shortsColor: equippedSkin.shortsColor,
        skinColor: equippedSkin.skinColor,
        hairDark: const Color(0xFFB45309),
        hairMid: const Color(0xFFEAB308),
        hairLight: const Color(0xFFFDE68A),
        shoeUpper: const Color(0xFFFF6D00),
        shoeAccent: equippedSkin.shoeAccent,
      );
    }

    // Default Player Pro (player_pro.png)
    return const CharacterPalette(
      jerseyMain: Color(0xFF00A896), // Turquoise / Teal
      jerseyLight: Color(0xFF14B8A6), // Light Teal
      jerseyAccent: Color(0xFFFFFFFF), // Crisp White
      shortsColor: Color(0xFF0D9488), // Teal Shorts
      skinColor: Color(0xFFE0AC82), // Warm Sun-Kissed Tan
      hairDark: Color(0xFFB47F28), // Golden Blonde
      hairMid: Color(0xFFEAB308),
      hairLight: Color(0xFFFDE68A),
      shoeUpper: Color(0xFFFF6D00), // Vibrant Orange Court Sneaker
      shoeAccent: Color(0xFFFFFFFF), // White Accent
    );
  }
}

/// Character color and styling tokens
class CharacterPalette {
  final Color jerseyMain;
  final Color jerseyLight;
  final Color jerseyAccent;
  final Color shortsColor;
  final Color skinColor;
  final Color hairDark;
  final Color hairMid;
  final Color hairLight;
  final Color shoeUpper;
  final Color shoeAccent;

  const CharacterPalette({
    required this.jerseyMain,
    required this.jerseyLight,
    required this.jerseyAccent,
    required this.shortsColor,
    required this.skinColor,
    required this.hairDark,
    required this.hairMid,
    required this.hairLight,
    required this.shoeUpper,
    required this.shoeAccent,
  });
}
