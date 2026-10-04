import '../utils/game_math.dart';
import '../utils/constants.dart';
import 'ultimate_skill.dart';

/// ─────────────────────────────────────────────────────────────
/// Pickleball model — physics state of the ball
/// ─────────────────────────────────────────────────────────────

enum BallState {
  idle,       // not in play (waiting for serve)
  inFlight,   // travelling through air
  bouncing,   // has hit the ground
  dead,       // out of bounds / hit net — point scored
}

class Pickleball {
  // ── World position and velocity ────────────────────────────
  Vec3 position;
  Vec3 velocity;   // world units per second

  /// Previous frame position — used for swept net-collision detection
  Vec3 prevPosition;

  // ── State ──────────────────────────────────────────────────
  BallState state;
  int bounceCount;       // how many times ball has bounced this rally
  bool lastHitByPlayer;  // true = human hit it last, false = AI
  bool netCollision;     // did ball just hit the net?
  bool outOfBounds;      // did ball land out?

  // ── Rules & Mechanics ──────────────────────────────────────
  /// Count of legal hits in the current rally.
  /// 0 = serve not yet hit, incremented when each player/AI hits.
  /// Two-Bounce Rule: hits 0 (serve) and 1 (return) must bounce before being struck.
  int rallyHitCount;
  bool isServe;          // currently executing the serve
  bool serverOnRight;    // true if serve originates from the right service box
  ShotType shotType;     // normal, power, lob, drop, smash, ultimate

  // ── Ultimate Special Skill State ───────────────────────────
  bool isUltimate;
  UltimateType? ultimateType;
  double ultimateAnimTimer;
  final List<Vec3> ghostClones1;
  final List<Vec3> ghostClones2;
  Vec3? iceZoneCenter;
  double iceZoneRadius;
  double iceZoneTimer;
  double lightningFlash;
  double shockwaveRadius;

  // ── Visual effects ─────────────────────────────────────────
  double impactFlash;    // 0..1, fades after paddle hit
  List<Vec3> trail;      // recent positions for ball trail
  double spinRate;       // degrees per second (visual spin)
  double spinAngle;      // current spin display angle

  // ── Bounce detection ───────────────────────────────────────
  bool hasBounced;       // has ball bounced on the CURRENT side since last hit
  double lastBounceZ;    // Z position of last bounce (to check service box)
  bool playerSideBounce; // bounced on player's side?

  Pickleball()
      : position = Vec3(0, PhysicsConstants.serveBallHeight, 
                        CourtDimensions.playerStartZ),
        velocity = Vec3(0, 0, 0),
        prevPosition = Vec3(0, PhysicsConstants.serveBallHeight,
                            CourtDimensions.playerStartZ),
        state = BallState.idle,
        bounceCount = 0,
        lastHitByPlayer = true,
        netCollision = false,
        outOfBounds = false,
        rallyHitCount = 0,
        isServe = true,
        serverOnRight = true,
        shotType = ShotType.normal,
        isUltimate = false,
        ultimateType = null,
        ultimateAnimTimer = 0,
        ghostClones1 = [],
        ghostClones2 = [],
        iceZoneCenter = null,
        iceZoneRadius = 0,
        iceZoneTimer = 0,
        lightningFlash = 0,
        shockwaveRadius = 0,
        impactFlash = 0,
        trail = [],
        spinRate = 0,
        spinAngle = 0,
        hasBounced = false,
        lastBounceZ = 0,
        playerSideBounce = false;

  // ── Convenience getters ────────────────────────────────────
  bool get isInPlay => state == BallState.inFlight || state == BallState.bouncing;

  double get speed => velocity.length;

  /// Is the ball currently on the player's side of the net?
  bool get isOnPlayerSide => position.z > 0;

  /// Is the ball currently on the AI's side of the net?
  bool get isOnAISide => position.z < 0;

  /// Two-Bounce Rule:
  /// The serve (hit 0→1) and the return of serve (hit 1→2) must bounce before
  /// being struck. After rallyHitCount >= 2, players may volley freely
  /// (outside the kitchen). The flag is checked BEFORE the hit increments.
  bool get canVolley => rallyHitCount >= 2;

  /// True when the ball MUST bounce before it can legally be struck.
  /// Applies to: serve return (rallyHitCount == 0 after serve) and
  /// the third shot (rallyHitCount == 1 after return).
  bool get mustBounceBeforeHit => rallyHitCount < 2;

  // ── Trail management ──────────────────────────────────────
  void addTrailPoint([int maxPoints = 12]) {
    if (maxPoints <= 0) {
      if (trail.isNotEmpty) trail.clear();
      return;
    }
    trail.add(position.copy());
    while (trail.length > maxPoints) {
      trail.removeAt(0);
    }
  }

  // ── Reset helpers ──────────────────────────────────────────
  /// Reuses the two Ghost Phantom positions instead of allocating new lists
  /// and vectors on every simulation tick.
  void updateGhostClones(double wave) {
    if (ghostClones1.isEmpty) {
      ghostClones1.add(Vec3(0, 0, 0));
    }
    if (ghostClones2.isEmpty) {
      ghostClones2.add(Vec3(0, 0, 0));
    }

    final first = ghostClones1.first;
    first
      ..x = position.x + wave
      ..y = position.y + 1.2
      ..z = position.z;

    final second = ghostClones2.first;
    second
      ..x = position.x - wave
      ..y = position.y - 1.2
      ..z = position.z;
  }

  void _resetCommon() {
    velocity = Vec3(0, 0, 0);
    prevPosition = position.copy();
    state = BallState.idle;
    bounceCount = 0;
    netCollision = false;
    outOfBounds = false;
    rallyHitCount = 0;
    isServe = true;
    shotType = ShotType.normal;
    impactFlash = 0;
    trail.clear();
    hasBounced = false;
    playerSideBounce = false;
    isUltimate = false;
    ultimateType = null;
    ghostClones1.clear();
    ghostClones2.clear();
    iceZoneCenter = null;
    iceZoneTimer = 0;
    lightningFlash = 0;
    shockwaveRadius = 0;
  }

  void resetForPlayerServe({bool fromRight = true}) {
    serverOnRight = fromRight;
    final startX = fromRight ? 16.0 : -16.0;
    position = Vec3(
      startX,
      PhysicsConstants.serveBallHeight,
      CourtDimensions.halfLength + CourtDimensions.serveBaselineOffset,
    );
    lastHitByPlayer = true;
    _resetCommon();
  }

  void resetForAIServe({bool fromRight = true}) {
    serverOnRight = fromRight;
    final startX = fromRight ? -16.0 : 16.0;
    position = Vec3(
      startX,
      PhysicsConstants.serveBallHeight,
      -CourtDimensions.halfLength - CourtDimensions.serveBaselineOffset,
    );
    lastHitByPlayer = false;
    _resetCommon();
  }

  // ── Bounds check ─────────────────────────────────────────
  bool isOutOfBounds() {
    return position.x.abs() > CourtDimensions.halfWidth + 2 ||
           position.z.abs() > CourtDimensions.halfLength + 2;
  }
}
