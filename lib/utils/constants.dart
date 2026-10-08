import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// App-wide constants for colors, sizes, and game parameters
/// Pickleball Champions — bright cartoon
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

  // Tournament court colors
  static const Color courtApron =
      Color(0xFF162544); // Deep tournament slate outer run-off
  static const Color courtSurface =
      Color(0xFF0284C7); // Pacific Blue main playing area
  static const Color courtSurfaceLight =
      Color(0xFF0EA5E9); // Highlight / sun side
  static const Color courtKitchen = Color(0xFF0369A1); // Precision Kitchen Teal
  static const Color courtLines = Color(0xFFFFFFFF); // Crisp regulation white
  static const Color netColor = Color(0xFFF8FAFC);
  static const Color floorShadow = Color(0x55000000);

  // Official Pickleball — High-Vis Tournament Chartreuse
  static const Color ballColor = Color(0xFFD4E157);
  static const Color ballHighlight = Color(0xFFF0F4C3);
  static const Color ballShadow = Color(0xFFAFB42B);

  // Score / HUD Broadcast
  static const Color hudBg = Color(0xD90B132B);
  static const Color scorePlayer = Color(0xFF34D399); // Crisp Emerald
  static const Color scoreAI = Color(0xFFF87171); // Crisp Coral Red

  // Stadium Architecture
  static const Color stadiumGreen =
      Color(0xFF1E293B); // Grandstand shadow slate
  static const Color stadiumGreenLight =
      Color(0xFF334155); // Tier ledge highlight
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

  // One foot is four world units (one unit is three inches).
  static const double unitsPerFoot = 4.0;

  // Official pickleball court: 20ft wide × 44ft long
  // We scale to game units where 1 unit ≈ 0.25ft
  static const double width = 80.0; // 20ft * 4
  static const double length = 176.0; // 44ft * 4
  static const double halfWidth = width / 2;
  static const double halfLength = length / 2;

  // Net is at center (z = 0 in our coordinate system)
  static const double netZ = 0.0;
  // Regulation net: 36 inches at the posts and 34 inches at center.
  static const double netHeight = 12.0;
  static const double netCenterHeight = 34.0 / 3.0;
  static const double netPostOffset = 4.0;

  static double netHeightAt(double x) {
    final normalizedX = (x / halfWidth).clamp(-1.0, 1.0).toDouble();
    return netCenterHeight +
        (netHeight - netCenterHeight) * normalizedX * normalizedX;
  }

  // Kitchen (Non-Volley Zone) extends 7ft from net = 28 units
  static const double kitchenDepth = 28.0;

  // Regulation line width: 2 inches (5.08 cm) -> ~0.67 units (1 unit = 3 inches = 0.25ft)
  static const double lineWidth = 0.67;

  // Service areas
  static const double serviceLineZ = kitchenDepth;

  // Player starting positions (z is depth, negative = player side)
  static const double playerStartZ = 60.0; // behind kitchen
  static const double aiStartZ = -60.0; // opponent side
  // Regulation serve contact occurs completely outside the baseline. The
  // six-unit margin also keeps the player's rendered feet clear of the line.
  static const double serveBaselineOffset = 6.0;

  // Player movement bounds
  static const double playerMinZ = halfLength * 0.05;
  static const double playerMaxZ = halfLength * 0.95;
  static const double playerMinX = -halfWidth * 0.9;
  static const double playerMaxX = halfWidth * 0.9;

  // A six-foot athlete is 24 world units tall. Character artwork is authored
  // at roughly 84 local units, so it must be converted into court scale.
  static const double playerHeight = 6.0 * unitsPerFoot;
  static const double characterArtHeight = 84.0;
  static const double playerRenderScale = playerHeight / characterArtHeight;
}

// ── Game Modes, Shot Types & Court Themes ─────────────────────
enum GameMode { singles, doubles }

enum ShotType { normal, power, lob, drop, smash, ultimate }

enum CourtTheme {
  tournament,
  beach,
  indoor,
  outdoor,
  midnight,
  volcano,
  canyon
}

extension CourtThemeExtension on CourtTheme {
  String get displayName {
    switch (this) {
      case CourtTheme.tournament:
        return 'CENTER COURT';
      case CourtTheme.beach:
        return 'TROPICAL BEACH';
      case CourtTheme.indoor:
        return 'SKY ARENA';
      case CourtTheme.outdoor:
        return 'FOREST PARK';
      case CourtTheme.midnight:
        return 'MIDNIGHT DOME';
      case CourtTheme.volcano:
        return 'SUNSET CALDERA';
      case CourtTheme.canyon:
        return 'DESERT CANYON';
    }
  }

  IconData get icon {
    switch (this) {
      case CourtTheme.tournament:
        return Icons.emoji_events_rounded;
      case CourtTheme.beach:
        return Icons.beach_access_rounded;
      case CourtTheme.indoor:
        return Icons.location_city_rounded;
      case CourtTheme.outdoor:
        return Icons.park_rounded;
      case CourtTheme.midnight:
        return Icons.nightlife_rounded;
      case CourtTheme.volcano:
        return Icons.local_fire_department_rounded;
      case CourtTheme.canyon:
        return Icons.landscape_rounded;
    }
  }

  String get assetPath {
    switch (this) {
      case CourtTheme.tournament:
        return 'assets/images/courts/court_7.png';
      case CourtTheme.beach:
        return 'assets/images/courts/court_1.jpg';
      case CourtTheme.indoor:
        return 'assets/images/courts/court_2.png';
      case CourtTheme.outdoor:
        return 'assets/images/courts/court_3.png';
      case CourtTheme.midnight:
        return 'assets/images/courts/court_4.png';
      case CourtTheme.volcano:
        return 'assets/images/courts/court_5.png';
      case CourtTheme.canyon:
        return 'assets/images/courts/court_6.png';
    }
  }

  String get overheadAssetPath {
    switch (this) {
      case CourtTheme.tournament:
        return 'assets/images/courts/court_7_overhead.jpg';
      case CourtTheme.beach:
        return 'assets/images/courts/court_1_overhead.jpg';
      case CourtTheme.indoor:
        return 'assets/images/courts/court_2_overhead.jpg';
      case CourtTheme.outdoor:
        return assetPath; // Uses court_3.png as fallback
      case CourtTheme.midnight:
        return 'assets/images/courts/court_4_overhead.jpg';
      case CourtTheme.volcano:
        return 'assets/images/courts/court_5_overhead.jpg';
      case CourtTheme.canyon:
        return 'assets/images/courts/court_6_overhead.jpg';
    }
  }

  /// Optional 360-degree equirectangular panorama backdrop for dynamic camera rendering
  String? get panoramaAssetPath {
    return null;
  }

  // Court surface color (primary tone)
  Color get surfaceColor {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF1783B9); // Tour Pro Blue
      case CourtTheme.beach:
        return const Color(0xFF0E7DB9); // Pacific Aqua
      case CourtTheme.indoor:
        return const Color(0xFF0E92D7); // Championship Cobalt
      case CourtTheme.outdoor:
        return const Color(0xFF0C93D6); // Alpine Glacial Blue
      case CourtTheme.midnight:
        return const Color(0xFF0C92E4); // Electric Neon Blue
      case CourtTheme.volcano:
        return const Color(0xFF0A7ABC); // Caldera Contrast Blue
      case CourtTheme.canyon:
        return const Color(0xFF307BA0); // Desert Oasis Turquoise
    }
  }

  // Far court surface tone (depth shading)
  Color get surfaceColorDark {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF0F5A82);
      case CourtTheme.beach:
        return const Color(0xFF0A5C88);
      case CourtTheme.indoor:
        return const Color(0xFF096AA0);
      case CourtTheme.outdoor:
        return const Color(0xFF086899);
      case CourtTheme.midnight:
        return const Color(0xFF085B93);
      case CourtTheme.volcano:
        return const Color(0xFF065180);
      case CourtTheme.canyon:
        return const Color(0xFF215B77);
    }
  }

  // Near court surface tone (sun / floodlight sheen)
  Color get surfaceColorLight {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF38BDF8);
      case CourtTheme.beach:
        return const Color(0xFF38BDF8);
      case CourtTheme.indoor:
        return const Color(0xFF60A5FA);
      case CourtTheme.outdoor:
        return const Color(0xFF38BDF8);
      case CourtTheme.midnight:
        return const Color(0xFF67E8F9);
      case CourtTheme.volcano:
        return const Color(0xFF38BDF8);
      case CourtTheme.canyon:
        return const Color(0xFF67E8F9);
    }
  }

  // Non-Volley Zone (The Kitchen)
  Color get kitchenColor {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF0D9488); // Precision Teal
      case CourtTheme.beach:
        return const Color(0xFF14B8A6); // Ocean Turquoise
      case CourtTheme.indoor:
        return const Color(0xFF0284C7); // High-Vis Cyan
      case CourtTheme.outdoor:
        return const Color(0xFF16A34A); // Contrast Emerald
      case CourtTheme.midnight:
        return const Color(0xFF6366F1); // Cyber Indigo
      case CourtTheme.volcano:
        return const Color(0xFFEA580C); // Ember Orange
      case CourtTheme.canyon:
        return const Color(0xFFB45309); // Red Rock Amber
    }
  }

  Color get kitchenColorDark {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF0F766E);
      case CourtTheme.beach:
        return const Color(0xFF0D9488);
      case CourtTheme.indoor:
        return const Color(0xFF0369A1);
      case CourtTheme.outdoor:
        return const Color(0xFF15803D);
      case CourtTheme.midnight:
        return const Color(0xFF4F46E5);
      case CourtTheme.volcano:
        return const Color(0xFFC2410C);
      case CourtTheme.canyon:
        return const Color(0xFF92400E);
    }
  }

  // Outer Apron Run-Off
  Color get apronColor {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF162544); // Deep Navy Slate
      case CourtTheme.beach:
        return const Color(0xFF142944); // Deep Coastal Tournament Navy
      case CourtTheme.indoor:
        return const Color(0xFF3B4861); // Stadium Slate
      case CourtTheme.outdoor:
        return const Color(0xFF243B14); // Deep Alpine Pine
      case CourtTheme.midnight:
        return const Color(0xFF1B2342); // Deep Twilight Slate
      case CourtTheme.volcano:
        return const Color(0xFF3B231D); // Volcanic Rock
      case CourtTheme.canyon:
        return const Color(0xFF4A3836); // Red Rock Earth
    }
  }

  Color get apronColorDark {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF0F172A);
      case CourtTheme.beach:
        return const Color(0xFF0C1D33);
      case CourtTheme.indoor:
        return const Color(0xFF222B3D);
      case CourtTheme.outdoor:
        return const Color(0xFF17260C);
      case CourtTheme.midnight:
        return const Color(0xFF10162B);
      case CourtTheme.volcano:
        return const Color(0xFF26140E);
      case CourtTheme.canyon:
        return const Color(0xFF312423);
    }
  }

  Color get skyColor {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF1C2532);
      case CourtTheme.beach:
        return const Color(0xFF1D98CF);
      case CourtTheme.indoor:
        return const Color(0xFF72ABDC);
      case CourtTheme.outdoor:
        return const Color(0xFF5E7F45);
      case CourtTheme.midnight:
        return const Color(0xFF203D80);
      case CourtTheme.volcano:
        return const Color(0xFFCF5029);
      case CourtTheme.canyon:
        return const Color(0xFFCD7450);
    }
  }

  Color get lineColor {
    switch (this) {
      case CourtTheme.volcano:
      case CourtTheme.canyon:
        return const Color(0xFFFFFBEB); // Warm regulation court white
      default:
        return const Color(0xFFF8FAFC); // Crisp regulation white
    }
  }

  Color get ledAccentColor {
    switch (this) {
      case CourtTheme.tournament:
        return const Color(0xFF38BDF8); // Cyan
      case CourtTheme.beach:
        return const Color(0xFFFBBF24); // Warm Gold
      case CourtTheme.indoor:
        return const Color(0xFF818CF8); // Electric Indigo
      case CourtTheme.outdoor:
        return const Color(0xFF4ADE80); // Spring Mint
      case CourtTheme.midnight:
        return const Color(0xFFA855F7); // Neon Purple
      case CourtTheme.volcano:
        return const Color(0xFFF97316); // High-Vis Orange
      case CourtTheme.canyon:
        return const Color(0xFFFBBF24); // Desert Gold
    }
  }

  String get venueSubtitle {
    switch (this) {
      case CourtTheme.tournament:
        return 'Grand Slam Center Stadium';
      case CourtTheme.beach:
        return 'Azure Coast Beach Club';
      case CourtTheme.indoor:
        return 'Skyline Dome Sportsplex';
      case CourtTheme.outdoor:
        return 'Pine Valley Mountain Sanctuary';
      case CourtTheme.midnight:
        return 'Neon Cyber Grand Slam';
      case CourtTheme.volcano:
        return 'Magma Peak Arena';
      case CourtTheme.canyon:
        return 'Red Rock Sun Valley';
    }
  }

  String get badgeLabel {
    switch (this) {
      case CourtTheme.tournament:
        return 'PRO TOUR';
      case CourtTheme.beach:
        return 'RESORT';
      case CourtTheme.indoor:
        return 'CHAMPIONSHIP';
      case CourtTheme.outdoor:
        return 'ALPINE';
      case CourtTheme.midnight:
        return 'NIGHT TOUR';
      case CourtTheme.volcano:
        return 'VOLCANIC';
      case CourtTheme.canyon:
        return 'CANYON';
    }
  }

  String get sponsorBoardText {
    switch (this) {
      case CourtTheme.tournament:
        return 'WORLD TOUR FINALS  \u2022  CENTER COURT  \u2022  SWEETSPOT  \u2022  RALLY FUEL';
      case CourtTheme.beach:
        return 'COASTAL CLASSIC  \u2022  PALM COVE  \u2022  SUNCOURT  \u2022  SANDBAR';
      case CourtTheme.indoor:
        return 'METRO MASTERS  \u2022  SKYLINE DOME  \u2022  RALLY FUEL';
      case CourtTheme.outdoor:
        return 'ALPINE OPEN  \u2022  PINE VALLEY  \u2022  SWEETSPOT PADDLES';
      case CourtTheme.midnight:
        return 'NEON NIGHTS  \u2022  CYBER SLAM  \u2022  POWER PADDLE  \u2022  PULSE';
      case CourtTheme.volcano:
        return 'CALDERA CLASH  \u2022  EMBER PEAK  \u2022  FIRE VOLLEY';
      case CourtTheme.canyon:
        return 'DESERT CLASSIC  \u2022  RED ROCK  \u2022  SUNCOURT  \u2022  OASIS';
    }
  }

  bool get isOutdoor =>
      this == CourtTheme.outdoor ||
      this == CourtTheme.beach ||
      this == CourtTheme.volcano ||
      this == CourtTheme.canyon;
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

  // Regulation diameter is approximately 2.9 inches.
  static const double ballRadius = 0.49;

  // COR from drop test: rebounds 30–34" from 78" → COR ≈ 0.64
  static const double ballBounceDamping = 0.64;

  // Horizontal friction on bounce (energy lost to court)
  static const double ballFriction = 0.88;

  /// Minimum time after a court bounce before paddle contact is accepted.
  /// This keeps the bounce visually readable and prevents a same-tick hit from
  /// making the required opening bounces appear to have been skipped.
  static const double postBounceHitDelay = 0.08;
  static const double minimumOpeningBounceTravel = 3.0;

  // Air drag coefficient: perforated ball Cd ≈ 0.45
  // Applied as: velocity *= (1 - dragScale * speed * dt)
  // dragScale tuned so ball loses ~35% speed over full-court flight
  static const double ballDragCoefficient = 0.0025;

  static const double maxBallSpeed = 300.0; // max horizontal speed
  static const double serveBallHeight = 20.0; // height to toss for serve
  static const double normalHitPower = 120.0;
  static const double powerHitPower = 195.0;
  static const double lobHitPower = 92.0;
  static const double lobUpPower = 56.0;
  static const double dropHitPower = 62.0;
  static const double dropUpPower = 20.0;
  static const double playerSpeed = 100.0; // world units/s
  static const double playerAcceleration = 520.0;
  static const double playerDeceleration = 680.0;
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

  static const double defaultFOV = 58.0; // degrees
  static const double cameraHeight = 92.0; // above court
  static const double cameraDistanceBehind = 104.0;
  static const double cameraLerpSpeed = 5.0; // smoothing factor
  static const double horizonFraction = 0.32; // horizon position on screen
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
