import '../models/court.dart';
import '../models/pickleball.dart';
import '../models/player.dart';
import '../utils/constants.dart';

enum PointResult {
  none,
  playerPoint,
  aiPoint,
  netFault,
  serviceFault,
  kitchenFault,
  twoBounceFault,
  doubleBounceFault,
  wrongReceiverFault,
}

/// Official side-out scoring and rally adjudication state.
class ScoreController {
  ScoreController({
    required this.player,
    required this.ai,
    required this.isPracticeMode,
    this.drillType,
    this.gameMode = GameMode.singles,
  }) {
    if (isPracticeMode && drillType == 'return_drill') {
      isPlayerServing = false;
      _serverNumber = 1;
    } else {
      // The 0-0-2 opening exception applies only to doubles.
      _serverNumber = gameMode == GameMode.doubles ? 2 : 1;
    }
  }

  final Player player;
  final Player ai;
  final bool isPracticeMode;
  final String? drillType;
  final GameMode gameMode;

  bool isPlayerServing = true;
  int _serverNumber = 1;
  bool _servingPrimary = true;
  bool _playerPrimaryOnRight = true;
  bool _aiPrimaryOnRight = true;
  String lastFaultDetail = '';
  int practiceServeCount = 0;
  _ScoringSnapshot? _lastRallySnapshot;

  int get serverNumber => _serverNumber;
  bool get servingPrimary => _servingPrimary;
  bool get playerPrimaryOnRight => _playerPrimaryOnRight;
  bool get aiPrimaryOnRight => _aiPrimaryOnRight;

  bool get serverShouldBeOnRight {
    if (isPracticeMode) return practiceServeCount % 2 == 0;
    if (gameMode != GameMode.doubles) {
      final serverScore = isPlayerServing ? player.score : ai.score;
      return serverScore.isEven;
    }
    final primaryOnRight =
        isPlayerServing ? _playerPrimaryOnRight : _aiPrimaryOnRight;
    return _servingPrimary ? primaryOnRight : !primaryOnRight;
  }

  bool get isGameOver {
    if (isPracticeMode) return false;
    final playerLead = player.score - ai.score;
    final aiLead = ai.score - player.score;
    return (player.score >= RulesetConfig.pointsToWin &&
            playerLead >= RulesetConfig.winByPoints) ||
        (ai.score >= RulesetConfig.pointsToWin &&
            aiLead >= RulesetConfig.winByPoints);
  }

  PointResult checkPoint(Pickleball ball, Court court) {
    if (ball.state == BallState.dead || ball.state == BallState.idle) {
      return PointResult.none;
    }

    if (ball.netCollision) {
      ball.netCollision = false;
      ball.state = BallState.dead;
      lastFaultDetail = 'NET FAULT!';
      return ball.lastHitByPlayer
          ? PointResult.aiPoint
          : PointResult.playerPoint;
    }

    if (ball.isServe && ball.hasBounced && ball.bounceCount == 1) {
      final isValid = court.isValidServiceBox(
        ball.position.x,
        ball.lastBounceZ,
        ball.serverOnRight,
      );
      if (!isValid) {
        ball.state = BallState.dead;
        lastFaultDetail = court.isInKitchen(
          ball.position.x,
          ball.lastBounceZ,
        )
            ? 'SERVICE IN KITCHEN (SHORT)!'
            : 'SERVICE OUT OF BOX!';
        return PointResult.serviceFault;
      }
      ball.isServe = false;
    }

    if (!ball.isServe && ball.hasBounced && ball.bounceCount == 1) {
      final inCourt = court.isInsideCourt(
        ball.position.x,
        ball.lastBounceZ,
      );
      final onAiSide = ball.lastBounceZ < 0;
      final onPlayerSide = ball.lastBounceZ > 0;

      if (ball.lastHitByPlayer && !onAiSide) {
        ball.state = BallState.dead;
        lastFaultDetail = 'NET FAULT!';
        return PointResult.aiPoint;
      }
      if (!ball.lastHitByPlayer && !onPlayerSide) {
        ball.state = BallState.dead;
        lastFaultDetail = 'NET FAULT!';
        return PointResult.playerPoint;
      }
      if (!inCourt) {
        ball.state = BallState.dead;
        lastFaultDetail = 'OUT OF BOUNDS!';
        return ball.lastHitByPlayer
            ? PointResult.aiPoint
            : PointResult.playerPoint;
      }
    }

    if (ball.hasBounced &&
        ball.bounceCount >= 2 &&
        ball.secondBounceGraceTimer <= 0) {
      ball.state = BallState.dead;
      lastFaultDetail = 'DOUBLE BOUNCE!';
      return ball.playerSideBounce
          ? PointResult.aiPoint
          : PointResult.playerPoint;
    }

    final deepOut =
        ball.position.z.abs() > CourtDimensions.halfLength + 12;
    final wideOut = ball.position.x.abs() > CourtDimensions.halfWidth + 12;
    if (deepOut || wideOut) {
      ball.state = BallState.dead;
      if (!ball.hasBounced) {
        lastFaultDetail = 'OUT!';
        return ball.lastHitByPlayer
            ? PointResult.aiPoint
            : PointResult.playerPoint;
      }
      lastFaultDetail = 'WINNER!';
      return ball.lastHitByPlayer
          ? PointResult.playerPoint
          : PointResult.aiPoint;
    }

    return PointResult.none;
  }

  /// Resolves a rally won by the player team.
  /// Returns true only when the scoreboard actually increases.
  bool awardPlayerPoint() {
    _captureScoringState();
    if (isPracticeMode) {
      practiceServeCount++;
      isPlayerServing = drillType != 'return_drill';
      _serverNumber = 1;
      return false;
    }

    if (!RulesetConfig.traditionalScoring) {
      player.score++;
      isPlayerServing = true;
      _serverNumber = 1;
      _rotatePlayerTeamAfterScore();
      return true;
    }

    if (isPlayerServing) {
      player.score++;
      _rotatePlayerTeamAfterScore();
      return true;
    }
    _advanceAfterServingTeamLoses();
    return false;
  }

  /// Resolves a rally won by the opponent team.
  /// Returns true only when the scoreboard actually increases.
  bool awardAIPoint() {
    _captureScoringState();
    if (isPracticeMode) {
      practiceServeCount++;
      isPlayerServing = drillType == 'serve_drill';
      _serverNumber = 1;
      return false;
    }

    if (!RulesetConfig.traditionalScoring) {
      ai.score++;
      isPlayerServing = false;
      _serverNumber = 1;
      _rotateAITeamAfterScore();
      return true;
    }

    if (!isPlayerServing) {
      ai.score++;
      _rotateAITeamAfterScore();
      return true;
    }
    _advanceAfterServingTeamLoses();
    return false;
  }

  void _advanceAfterServingTeamLoses() {
    if (gameMode == GameMode.doubles && _serverNumber == 1) {
      _serverNumber = 2;
      _servingPrimary = !_servingPrimary;
      return;
    }
    isPlayerServing = !isPlayerServing;
    _serverNumber = 1;
    _selectFirstServerForCurrentTeam();
  }

  void _rotatePlayerTeamAfterScore() {
    if (gameMode == GameMode.doubles) {
      _playerPrimaryOnRight = !_playerPrimaryOnRight;
    }
  }

  void _rotateAITeamAfterScore() {
    if (gameMode == GameMode.doubles) {
      _aiPrimaryOnRight = !_aiPrimaryOnRight;
    }
  }

  void _selectFirstServerForCurrentTeam() {
    if (gameMode != GameMode.doubles) {
      _servingPrimary = true;
      return;
    }
    final score = isPlayerServing ? player.score : ai.score;
    final primaryOnRight =
        isPlayerServing ? _playerPrimaryOnRight : _aiPrimaryOnRight;
    final firstServerShouldBeOnRight = score.isEven;
    _servingPrimary = primaryOnRight == firstServerShouldBeOnRight;
  }

  void handleServiceFault() {
    _advanceAfterServingTeamLoses();
  }

  /// Restores the exact state from before the last rally, then resolves the
  /// rally for the opponent of the player who committed the late NVZ fault.
  void overturnPointForKitchenFault({required bool playerFaulted}) {
    if (isPracticeMode) {
      lastFaultDetail = playerFaulted
          ? 'NVZ MOMENTUM FAULT!'
          : 'OPPONENT NVZ MOMENTUM FAULT!';
      return;
    }

    final snapshot = _lastRallySnapshot;
    if (snapshot != null) {
      player.score = snapshot.playerScore;
      ai.score = snapshot.aiScore;
      isPlayerServing = snapshot.isPlayerServing;
      _serverNumber = snapshot.serverNumber;
      _servingPrimary = snapshot.servingPrimary;
      _playerPrimaryOnRight = snapshot.playerPrimaryOnRight;
      _aiPrimaryOnRight = snapshot.aiPrimaryOnRight;
    }

    if (playerFaulted) {
      awardAIPoint();
      lastFaultDetail = 'NVZ MOMENTUM FAULT (OVERTURNED)!';
    } else {
      awardPlayerPoint();
      lastFaultDetail = 'OPPONENT NVZ MOMENTUM FAULT (OVERTURNED)!';
    }
  }

  void _captureScoringState() {
    _lastRallySnapshot = _ScoringSnapshot(
      playerScore: player.score,
      aiScore: ai.score,
      isPlayerServing: isPlayerServing,
      serverNumber: _serverNumber,
      servingPrimary: _servingPrimary,
      playerPrimaryOnRight: _playerPrimaryOnRight,
      aiPrimaryOnRight: _aiPrimaryOnRight,
    );
  }

  void reset() {
    player.score = 0;
    ai.score = 0;
    practiceServeCount = 0;
    isPlayerServing =
        !(isPracticeMode && drillType == 'return_drill');
    _serverNumber = isPracticeMode && drillType == 'return_drill'
        ? 1
        : (gameMode == GameMode.doubles ? 2 : 1);
    _servingPrimary = true;
    _playerPrimaryOnRight = true;
    _aiPrimaryOnRight = true;
    _lastRallySnapshot = null;
    lastFaultDetail = '';
  }

  int get playerScore => player.score;
  int get aiScore => ai.score;

  void applySyncState({
    required int playerScore,
    required int aiScore,
    required bool isPlayerServing,
    required int serverNumber,
    required bool servingPrimary,
  }) {
    player.score = playerScore;
    ai.score = aiScore;
    this.isPlayerServing = isPlayerServing;
    _serverNumber = serverNumber;
    _servingPrimary = servingPrimary;
  }
}

class _ScoringSnapshot {
  const _ScoringSnapshot({
    required this.playerScore,
    required this.aiScore,
    required this.isPlayerServing,
    required this.serverNumber,
    required this.servingPrimary,
    required this.playerPrimaryOnRight,
    required this.aiPrimaryOnRight,
  });

  final int playerScore;
  final int aiScore;
  final bool isPlayerServing;
  final int serverNumber;
  final bool servingPrimary;
  final bool playerPrimaryOnRight;
  final bool aiPrimaryOnRight;
}
