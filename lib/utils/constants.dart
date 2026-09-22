import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// App-wide constants for colors, sizes, and game parameters
/// Styled to match Pickleball Stars (Zudo Labs) — bright cartoon
/// sports aesthetic with yellow/blue/teal palette.
/// ─────────────────────────────────────────────────────────────

// ── Professional Sports Tournament Color Palette ────────────────
class AppColors {
  AppColors._();

  // Arena & Atmosphere (Deep modern tournament stadium)
  static const Color darkBg = Color(0xFF0B132B);
  static const Color darkBgSecondary = Color(0xFF1C2541);
  static const Color darkCard = Color(0xFF1E293B);

  // Arena sky / upper stadium lighting
  static const Color skyTop = Color(0xFF0F1E36);
  static const Color skyMid = Color(0xFF1B2F4E);
  static const Color skyBottom = Color(0xFF243B5E);

  // Primary accent — Championship Gold
  static const Color primary = Color(0xFFF59E0B);
  static const Color primaryDark = Color(0xFFD97706);
  static const Color primaryShadow = Color(0xFF92400E);
  static const Color primaryGlow = Color(0x55F59E0B);

  // Secondary — Tournament Electric Coral
  static const Color secondary = Color(0xFFFB923C);
  static const Color secondaryDark = Color(0xFFEA580C);

  // Power shot accent
  static const Color power = Color(0xFFF43F5E);
  static const Color powerGlow = Color(0x66F43F5E);

  // Broadcast HUD panels — sleek frosted dark slate
  static const Color panelBlue = Color(0xFF1E293B);
  static const Color panelBlueDark = Color(0xFF0F172A);
  static const Color panelBlueBorder = Color(0xFF334155);
  static const Color glassPanel = Color(0xD90F172A); // 85% opacity
  static const Color glassBorder = Color(0x33FFFFFF); // subtle rim highlight

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDark = Color(0xFF0F172A);

  // Official Tournament Court Colors (PPA Tour style)
  static const Color courtApron = Color(0xFF162544);       // Deep tournament slate outer run-off
  static const Color courtSurface = Color(0xFF0284C7);     // Pacific Blue main playing area
  static const Color courtSurfaceLight = Color(0xFF0EA5E9);// Highlight / sun side
  static const Color courtKitchen = Color(0xFF0369A1);     // Precision Kitchen Teal
  static const Color courtLines = Color(0xFFFFFFFF);       // Crisp regulation white
  static const Color netColor = Color(0xFFF8FAFC);
  static const Color floorShadow = Color(0x55000000);

  // Official Pickleball — High-Vis Tournament Chartreuse
  static const Color ballColor = Color(0xFFD4E157);
  static const Color ballHighlight = Color(0xFFF0F4C3);
  static const Color ballShadow = Color(0xFFAFB42B);

  // Score / HUD Broadcast
  static const Color hudBg = Color(0xD90B132B);
  static const Color scorePlayer = Color(0xFF34D399); // Crisp Emerald
  static const Color scoreAI = Color(0xFFF87171);     // Crisp Coral Red

  // Stadium Architecture
  static const Color stadiumGreen = Color(0xFF1E293B);      // Grandstand shadow slate
  static const Color stadiumGreenLight = Color(0xFF334155); // Tier ledge highlight
  static const Color arenaWall = Color(0xFF0F172A);
  static const Color arenaRailing = Color(0xFF475569);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient panelGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient powerGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Sleek modern button decoration
  static BoxDecoration yellowButtonDecoration({double radius = 14}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x33F59E0B),
          blurRadius: 16,
        ),
      ],
    );
  }

  // Sleek modern blue/slate button decoration
  static BoxDecoration blueButtonDecoration({double radius = 14}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        colors: [Color(0xFF334155), Color(0xFF1E293B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border.all(color: const Color(0xFF475569), width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x50000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}

// ── Typography ─────────────────────────────────────────────────
class AppFonts {
  AppFonts._();
  // Standard clean system athletic sans-serif
  static const String? proFont = null;
  static const String orbitron = 'Orbitron';
}

// ── Court Dimensions (in 3D world units) ───────────────────────
class CourtDimensions {
  CourtDimensions._();

  // Official pickleball court: 20ft wide × 44ft long
  // We scale to game units where 1 unit ≈ 0.25ft
  static const double width = 80.0;      // 20ft * 4
  static const double length = 176.0;    // 44ft * 4
  static const double halfWidth = width / 2;
  static const double halfLength = length / 2;

  // Net is at center (z = 0 in our coordinate system)
  static const double netZ = 0.0;
  static const double netHeight = 3.0;   // net height in world units

  // Kitchen (Non-Volley Zone) extends 7ft from net = 28 units
  static const double kitchenDepth = 28.0;

  // Service areas
  static const double serviceLineZ = kitchenDepth;

  // Player starting positions (z is depth, negative = player side)
  static const double playerStartZ = 60.0;   // behind kitchen
  static const double aiStartZ = -60.0;      // opponent side

  // Player movement bounds
  static const double playerMinZ = halfLength * 0.05;
  static const double playerMaxZ = halfLength * 0.95;
  static const double playerMinX = -halfWidth * 0.9;
  static const double playerMaxX = halfWidth * 0.9;
}

// ── Game Modes, Shot Types & Court Themes ─────────────────────
enum GameMode { singles, doubles }

enum ShotType { normal, power, lob, drop, smash, ultimate }

enum CourtTheme { tournament, indoor, outdoor, beach, gym }

extension CourtThemeExtension on CourtTheme {
  String get displayName {
    switch (this) {
      case CourtTheme.tournament: return 'CENTER COURT';
      case CourtTheme.indoor:     return 'INDOOR ARENA';
      case CourtTheme.outdoor:    return 'OUTDOOR PARK';
      case CourtTheme.beach:      return 'BEACH COURT';
      case CourtTheme.gym:        return 'SCHOOL GYM';
    }
  }

  String get emoji {
    switch (this) {
      case CourtTheme.tournament: return '🏆';
      case CourtTheme.indoor:     return '🏟️';
      case CourtTheme.outdoor:    return '🌳';
      case CourtTheme.beach:      return '🏖️';
      case CourtTheme.gym:        return '🏫';
    }
  }

  // Court surface color
  Color get surfaceColor {
    switch (this) {
      case CourtTheme.tournament: return const Color(0xFF0284C7);
      case CourtTheme.indoor:     return const Color(0xFF1565C0);
      case CourtTheme.outdoor:    return const Color(0xFF2E7D32);
      case CourtTheme.beach:      return const Color(0xFFC4A35A);
      case CourtTheme.gym:        return const Color(0xFFBF8040);
    }
  }

  Color get kitchenColor {
    switch (this) {
      case CourtTheme.tournament: return const Color(0xFF0369A1);
      case CourtTheme.indoor:     return const Color(0xFF0D47A1);
      case CourtTheme.outdoor:    return const Color(0xFF1B5E20);
      case CourtTheme.beach:      return const Color(0xFFB8943F);
      case CourtTheme.gym:        return const Color(0xFFA0692E);
    }
  }

  Color get apronColor {
    switch (this) {
      case CourtTheme.tournament: return const Color(0xFF162544);
      case CourtTheme.indoor:     return const Color(0xFF0A1929);
      case CourtTheme.outdoor:    return const Color(0xFF33691E);
      case CourtTheme.beach:      return const Color(0xFFD4A96A);
      case CourtTheme.gym:        return const Color(0xFF6D4C26);
    }
  }

  Color get skyColor {
    switch (this) {
      case CourtTheme.tournament: return const Color(0xFF0B132B);
      case CourtTheme.indoor:     return const Color(0xFF0D1B2A);
      case CourtTheme.outdoor:    return const Color(0xFF1565C0);
      case CourtTheme.beach:      return const Color(0xFF0277BD);
      case CourtTheme.gym:        return const Color(0xFF263238);
    }
  }
}

// ── Stamina Constants ──────────────────────────────────────────
class StaminaConstants {
  StaminaConstants._();

  static const double maxStamina = 1.0;
  static const double powerShotCost = 0.35;
  static const double lobShotCost = 0.15;
  static const double dropShotCost = 0.10;
  static const double recoveryRate = 0.22; // per second
}

// ── Physics Constants ──────────────────────────────────────────
class PhysicsConstants {
  PhysicsConstants._();

  // Gravity: 9.81 m/s² × world scale (1 unit ≈ 0.076 m) ≈ 129 units/s²
  // Tuned to 120 for slightly more playable arc while staying realistic
  static const double gravity = 120.0;

  static const double ballRadius = 3.0;          // world units

  // COR from drop test: rebounds 30–34" from 78" → COR ≈ 0.64
  static const double ballBounceDamping = 0.64;

  // Horizontal friction on bounce (energy lost to court)
  static const double ballFriction = 0.88;

  // Air drag coefficient: perforated ball Cd ≈ 0.45
  // Applied as: velocity *= (1 - dragScale * speed * dt)
  // dragScale tuned so ball loses ~35% speed over full-court flight
  static const double ballDragCoefficient = 0.0018;

  static const double maxBallSpeed = 300.0;      // max horizontal speed
  static const double serveBallHeight = 20.0;    // height to toss for serve
  static const double normalHitPower = 120.0;
  static const double powerHitPower = 195.0;
  static const double lobHitPower = 92.0;
  static const double lobUpPower = 56.0;
  static const double dropHitPower = 62.0;
  static const double dropUpPower = 20.0;
  static const double playerSpeed = 80.0;        // world units/s
  static const double playerAcceleration = 400.0;
  static const double playerDeceleration = 600.0;
}

// ── Ruleset Configuration ──────────────────────────────────────
/// Configurable ruleset — change these to adjust game rules without
/// touching game logic. Matches the USA Pickleball rulebook defaults.
class RulesetConfig {
  RulesetConfig._();

  /// Score needed to win (standard = 11, variants 15 or 21)
  static const int pointsToWin = 11;

  /// Must win by this many points
  static const int winByPoints = 2;

  /// Traditional scoring: only serving team scores a point.
  /// Receiving team wins rally → sideout only (serve changes, no point).
  /// Set false for rally scoring (every rally awards a point).
  static const bool traditionalScoring = true;

  /// If true, a serve that clips the net and lands legally is replayed (let).
  /// If false, it is treated as a fault. Configurable per rulebook version.
  static const bool letServeReplay = false;

  /// Maximum serves allowed per server turn (always 1 in pickleball)
  static const int maxServesPerTurn = 1;
}

// ── Camera Constants ───────────────────────────────────────────
class CameraConstants {
  CameraConstants._();

  static const double defaultFOV = 58.0;         // degrees
  static const double cameraHeight = 92.0;       // above court
  static const double cameraDistanceBehind = 104.0;
  static const double cameraLerpSpeed = 5.0;     // smoothing factor
  static const double horizonFraction = 0.32;    // horizon position on screen
}

// ── Scoring (kept for compatibility — use RulesetConfig for game logic) ──
class ScoringConstants {
  ScoringConstants._();

  static const int pointsToWin = RulesetConfig.pointsToWin;
  static const int winByPoints = RulesetConfig.winByPoints;
}

// ── UI Sizes ───────────────────────────────────────────────────
class UISizes {
  UISizes._();

  static const double joystickSize = 120.0;
  static const double joystickKnobSize = 50.0;
  static const double hitButtonSize = 68.0;
  static const double powerButtonSize = 56.0;
  static const double lobButtonSize = 52.0;
  static const double dropButtonSize = 52.0;
  static const double serveButtonSize = 56.0;
  static const double ultimateButtonSize = 62.0;
  static const double hudPadding = 16.0;
  static const double borderRadius = 16.0;
}
