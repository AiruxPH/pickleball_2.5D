import '../models/pickleball.dart';
import '../models/player.dart';
import '../models/court.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// ScoreController — Official USA Pickleball Scoring
///
/// Traditional scoring implemented:
///   • Only the SERVING team can score a point
///   • Receiving team wins rally → sideout (serve passes), no point
///   • 0-0-2 game start: first serving team gets only one server
///   • Server number (1 or 2) rotates on sideout per rulebook
///   • Serve position: right on even score, left on odd score
///   • First to 11 (win by 2); configurable via RulesetConfig
///
/// Rally scoring (both teams score) can be toggled via RulesetConfig.
/// ─────────────────────────────────────────────────────────────

enum PointResult {
  none,
  playerPoint,
  aiPoint,
  netFault,
  serviceFault,
  kitchenFault,
  twoBounceFault,
  doubleBounceFault,
}

class ScoreController {
  final Player player;
  final Player ai;
  final bool isPracticeMode;
  final String? drillType;

  // ── Server tracking ─────────────────────────────────────────
  bool isPlayerServing = true;  // which team currently serves

  /// Server number within the serving team (1 or 2).
  /// Game starts 0-0-2: first team's initial turn counts as server 2,
  /// so they only get one server before the first sideout.
  int _serverNumber = 2; // game starts as "server 2" per 0-0-2 rule

  String lastFaultDetail = '';
  int practiceServeCount = 0;

  ScoreController({
    required this.player,
    required this.ai,
    required this.isPracticeMode,
    this.drillType,
  }) {
    if (isPracticeMode && drillType == 'return_drill') {
      isPlayerServing = false;
      _serverNumber = 1;
    }
  }

  /// Current server number (1 or 2) — used for score announcement.
  int get serverNumber => _serverNumber;

  /// Official rule: serve starts on the right when server's team score is
  /// even, and from the left when odd.
  bool get serverShouldBeOnRight {
    if (isPracticeMode) {
      return practiceServeCount % 2 == 0;
    }
    final serverScore = isPlayerServing ? player.score : ai.score;
    return serverScore % 2 == 0;
  }

  bool get isGameOver {
    if (isPracticeMode) return false;

    final p = player.score;
    final a = ai.score;
    if (p >= RulesetConfig.pointsToWin && p - a >= RulesetConfig.winByPoints) return true;
    if (a >= RulesetConfig.pointsToWin && a - p >= RulesetConfig.winByPoints) return true;
    return false;
  }

  // ── Detect point condition each frame ─────────────────────────
  PointResult checkPoint(Pickleball ball, Court court) {
    if (ball.state == BallState.dead || ball.state == BallState.idle) {
      return PointResult.none;
    }

    // 1. Net collision fault
    if (ball.netCollision) {
      ball.netCollision = false;
      ball.state = BallState.dead;
      lastFaultDetail = 'NET FAULT!';
      return ball.lastHitByPlayer ? PointResult.aiPoint : PointResult.playerPoint;
    }

    // 2. Service landing check (must land in correct diagonal box)
    if (ball.isServe && ball.hasBounced && ball.bounceCount == 1) {
      final isValid = court.isValidServiceBox(
        ball.position.x,
        ball.lastBounceZ,
        ball.serverOnRight,
      );

      if (!isValid) {
        ball.state = BallState.dead;
        lastFaultDetail = court.isInKitchen(ball.position.x, ball.lastBounceZ)
            ? 'SERVICE IN KITCHEN!'
            : 'SERVICE OUT OF BOX!';
        return PointResult.serviceFault;
      } else {
        // Serve landed legally — rally is now live
        ball.isServe = false;
      }
    }

    // 3. First bounce in/out detection (for regular rally shots)
    if (!ball.isServe && ball.hasBounced && ball.bounceCount == 1) {
      final inCourt = court.isInsideCourt(ball.position.x, ball.lastBounceZ);
      final onAiSide = ball.lastBounceZ < 0;
      final onPlayerSide = ball.lastBounceZ > 0;

      // Ball must cross the net to the opponent's side
      if (ball.lastHitByPlayer && !onAiSide) {
        ball.state = BallState.dead;
        lastFaultDetail = 'NET FAULT!';
        return PointResult.aiPoint;
      } else if (!ball.lastHitByPlayer && !onPlayerSide) {
        ball.state = BallState.dead;
        lastFaultDetail = 'NET FAULT!';
        return PointResult.playerPoint;
      }

      // Ball landed out of bounds on first bounce
      if (!inCourt) {
        ball.state = BallState.dead;
        lastFaultDetail = 'OUT OF BOUNDS!';
        return ball.lastHitByPlayer ? PointResult.aiPoint : PointResult.playerPoint;
      }
    }

    // 4. Double bounce (ball bounced twice without being returned)
    if (ball.hasBounced && ball.bounceCount >= 2) {
      ball.state = BallState.dead;
      lastFaultDetail = 'DOUBLE BOUNCE!';
      return ball.playerSideBounce ? PointResult.aiPoint : PointResult.playerPoint;
    }

    // 5. Ball flew far out of bounds (past court boundaries)
    final isDeepPastBaseline = ball.position.z.abs() > CourtDimensions.halfLength + 12;
    final isFarPastSideline = ball.position.x.abs() > CourtDimensions.halfWidth + 12;

    if (isDeepPastBaseline || isFarPastSideline) {
      ball.state = BallState.dead;

      if (!ball.hasBounced) {
        // Ball flew completely out without bouncing → fault on striker
        lastFaultDetail = 'OUT!';
        return ball.lastHitByPlayer ? PointResult.aiPoint : PointResult.playerPoint;
      } else {
        // Ball bounced legally and passed the defender → winner!
        lastFaultDetail = 'WINNER!';
        return ball.lastHitByPlayer ? PointResult.playerPoint : PointResult.aiPoint;
      }
    }

    return PointResult.none;
  }

  // ── Award points with official sideout scoring ──────────────────
  //
  // Traditional scoring (RulesetConfig.traditionalScoring = true):
  //   • Serving team wins rally  → point + keep serve
  //   • Receiving team wins rally → sideout, serve passes (no point)
  //
  // Rally scoring (traditionalScoring = false):
  //   • Either team scores on every rally win
  // ──────────────────────────────────────────────────────────────────
  void awardPlayerPoint() {
    if (isPracticeMode) {
      practiceServeCount++;
      if (drillType == 'return_drill') {
        isPlayerServing = false;
        _serverNumber = 1;
      } else {
        isPlayerServing = true;
        _serverNumber = 1;
      }
      return;
    }

    if (RulesetConfig.traditionalScoring) {
      if (isPlayerServing) {
        // Serving team (player) wins rally → score point, keep serve
        player.score++;
        // Server stays the same (server number doesn't change on point won)
      } else {
        // Receiving team (player) wins rally → sideout, player gets serve
        // No point scored for player
        isPlayerServing = true;
        _serverNumber = 1; // receiving team always starts with server 1
      }
    } else {
      // Rally scoring: player always gets a point
      player.score++;
      isPlayerServing = true;
      _serverNumber = 1;
    }
  }

  void awardAIPoint() {
    if (isPracticeMode) {
      practiceServeCount++;
      if (drillType == 'serve_drill') {
        isPlayerServing = true;
        _serverNumber = 1;
      } else {
        isPlayerServing = false;
        _serverNumber = 1;
      }
      return;
    }

    if (RulesetConfig.traditionalScoring) {
      if (!isPlayerServing) {
        // Serving team (AI) wins rally → score point, keep serve
        ai.score++;
      } else {
        // Receiving team (AI) wins rally → sideout, AI gets serve
        // No point scored for AI
        isPlayerServing = false;
        _serverNumber = 1;
      }
    } else {
      // Rally scoring: AI always gets a point
      ai.score++;
      isPlayerServing = false;
      _serverNumber = 1;
    }
  }

  /// Called when a service fault occurs (server loses the rally).
  /// In traditional scoring this is a sideout or server rotation.
  void handleServiceFault() {
    if (isPlayerServing) {
      if (_serverNumber == 1) {
        // Server 1 faults → server 2 takes over (still player's serve)
        _serverNumber = 2;
      } else {
        // Server 2 faults → sideout, AI serves
        isPlayerServing = false;
        _serverNumber = 1;
      }
    } else {
      if (_serverNumber == 1) {
        _serverNumber = 2;
      } else {
        isPlayerServing = true;
        _serverNumber = 1;
      }
    }
  }

  // ── Reset ────────────────────────────────────────────────────────
  void reset() {
    player.score = 0;
    ai.score = 0;
    practiceServeCount = 0;
    isPlayerServing = (isPracticeMode && drillType == 'return_drill') ? false : true;
    // 0-0-2 start rule: game starts with server number 2
    _serverNumber = 2;
    lastFaultDetail = '';
  }
}
