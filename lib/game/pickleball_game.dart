import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';
import '../models/player.dart';
import '../models/pickleball.dart';
import '../models/court.dart';
import '../models/game_settings.dart';
import '../models/shop_items.dart';
import '../models/ultimate_skill.dart';
import '../models/shot_mechanics.dart';
import '../models/match_foundation.dart';
import '../game/score_controller.dart';
import '../game/ball_controller.dart';
import '../game/player_controller.dart';
import '../game/ai_controller.dart';
import '../game/ai_shot_planner.dart';
import '../game/physics_controller.dart';
import '../game/game_presentation.dart';
import '../game/shot/contextual_shot_type.dart';
import '../game/shot/contact_timing_offset.dart';
import '../game/shot/shot_quality.dart';
import '../game/shot/player_aim_calculator.dart';
import '../game/shot/player_shot_trajectory_solver.dart';
import '../game/rally_phase_classifier.dart';
import '../services/audio_service.dart';

/// ─────────────────────────────────────────────────────────────
/// PickleballGame — Central game state object
///
/// Manages the entire game:
///   • Singles (1v1) or Doubles (2v2)
///   • Players, Ball, AI, Camera, Scoring
///   • Official Pickleball Rules:
///       - Diagonal Underhand Serve
///       - Two-Bounce Rule
///       - Kitchen (Non-Volley Zone) Rule
///       - First to 11 Points, Win by 2
///   • Shot Arsenal: Normal, Power, Lob, Drop (Dink), Smash
///   • Ultimate Special Skill System (Thunderbolt, Ghost, Dragon, Frostbite)
///   • Stamina Management System
/// ─────────────────────────────────────────────────────────────

enum GameState {
  waitingForServe,
  rally,
  pointScored,
  gameOver,
  paused,
}

class ServeTrajectoryPreview {
  const ServeTrajectoryPreview({
    required this.points,
    required this.launchVelocity,
    required this.targetX,
    required this.targetZ,
    required this.serverOnRight,
    required this.isLegal,
  });

  final List<Vec3> points;
  final Vec3 launchVelocity;
  final double targetX;
  final double targetZ;
  final bool serverOnRight;
  final bool isLegal;
}

class ContactFeedback {
  const ContactFeedback({
    required this.grade,
    required this.position,
    required this.playerSlot,
    required this.revision,
    required this.remaining,
  });

  final SwingTimingGrade grade;
  final Vec3 position;
  final int playerSlot;
  final int revision;
  final double remaining;
}

class PickleballGame extends ChangeNotifier {
  // ── Mode ─────────────────────────────────────────────────────
  final GameMode gameMode;
  final bool isLocalMultiplayer;
  final MatchBalanceProfile balanceProfile;

  // ── Game objects ─────────────────────────────────────────────
  final Player player;
  final Player? playerPartner;
  final Player ai;
  final Player? aiPartner;
  final Pickleball ball;
  final Court court;

  // ── Controllers ──────────────────────────────────────────────
  late BallController ballController;
  late PlayerController playerController;
  late PlayerController opponentPlayerController;
  late AIController aiController;
  AIController? partnerController;
  AIController? aiPartnerController;
  late PhysicsController physicsController;
  late ScoreController scoreController;
  Player? _nearTeamCoverageOwner;
  Player? _farTeamCoverageOwner;
  Player? _lastNearTeamCoverageOwner;
  Player? _lastFarTeamCoverageOwner;
  Player? _lastRallyHitter;
  int _coverageRevision = -1;

  Player? get nearTeamCoverageOwner => _nearTeamCoverageOwner;
  Player? get farTeamCoverageOwner => _farTeamCoverageOwner;
  Player? get lastRallyHitter => _lastRallyHitter;
  double? get nearTeamSuggestedTargetX =>
      gameMode == GameMode.doubles ? _doublesTargetX(nearTeam: true) : null;
  double? get farTeamSuggestedTargetX =>
      gameMode == GameMode.doubles ? _doublesTargetX(nearTeam: false) : null;

  Player get activeServer {
    if (scoreController.isPlayerServing) {
      return gameMode == GameMode.doubles && !scoreController.servingPrimary
          ? playerPartner!
          : player;
    }
    return gameMode == GameMode.doubles && !scoreController.servingPrimary
        ? aiPartner!
        : ai;
  }

  Player get activeReceiver {
    final serverRight = scoreController.serverShouldBeOnRight;
    if (scoreController.isPlayerServing) {
      if (gameMode != GameMode.doubles) return ai;
      return ai.assignedRightSide == serverRight ? ai : aiPartner!;
    }
    if (gameMode != GameMode.doubles) return player;
    return player.assignedRightSide == serverRight ? player : playerPartner!;
  }

  bool get isHumanServing => activeServer.isHuman;
  bool get isOpponentHumanServing =>
      isLocalMultiplayer && identical(activeServer, ai);

  // ── State ────────────────────────────────────────────────────
  GameState state;
  GameState _stateBeforePause = GameState.waitingForServe;
  bool isPracticeMode;
  double stateTimer; // time elapsed in current state
  String lastMessage; // e.g. "KITCHEN FAULT!", "TWO-BOUNCE FAULT", "OUT!"
  double messageTimer;
  double _aiServeDelay = 1.3;

  // ── Input state ───────────────────────────────────────────────
  double joystickX = 0;
  double joystickY = 0;
  bool hitPressed = false;
  bool powerPressed = false;
  bool lobPressed = false;
  bool dropPressed = false;
  bool servePressed = false;
  bool ultimatePressed = false;
  Offset? swipeDirection;
  double swingBufferTimer = 0;
  ShotType? bufferedShot;
  ShotSpin bufferedSpin = ShotSpin.flat;
  double? bufferedTimingIntent;
  double opponentJoystickX = 0;
  double opponentJoystickY = 0;
  bool opponentServePressed = false;
  Offset? opponentSwipeDirection;
  double opponentSwingBufferTimer = 0;
  ShotType? opponentBufferedShot;
  ShotSpin opponentBufferedSpin = ShotSpin.flat;
  double? opponentBufferedTimingIntent;
  ContactFeedback? contactFeedback;
  int contactFeedbackRevision = 0;
  final MatchEventLog matchEvents = MatchEventLog();
  final MatchStats matchStats = MatchStats();
  RallyPhase rallyPhase = RallyPhase.opening;
  bool _matchEndPublished = false;

  Stream<MatchEvent> get onMatchEvent => matchEvents.events;
  int get matchEventRevision => matchEvents.revision;

  // ── Ultimate Skill System ─────────────────────────────────────
  double ultimateCharge = 0.45; // 0.0 .. 1.0
  bool isUltimateArmed = false;
  double ultimateCutinTimer = 0.0;
  UltimateType? activeCutinUltimate;
  double timeDilation = 1.0;
  double slowMoTimer = 0.0;

  UltimateType get equippedUltimate => settings.equippedUltimate;
  UltimateSkill get currentUltimate => getUltimateByType(equippedUltimate);
  bool get specialSkillsEnabled =>
      balanceProfile == MatchBalanceProfile.standard;
  bool get isUltimateReady =>
      specialSkillsEnabled &&
      settings.hasEquippedPaddleSkill &&
      ultimateCharge >= 1.0;

  void addUltimateCharge(double amount) {
    if (!specialSkillsEnabled || !settings.hasEquippedPaddleSkill) return;
    final oldVal = ultimateCharge;
    ultimateCharge = (ultimateCharge + amount).clamp(0.0, 1.0);
    if (oldVal < 1.0 && ultimateCharge >= 1.0) {
      notifyListeners();
    }
  }

  // ── Visual effects ────────────────────────────────────────────
  GameEffects effects;

  // ── Score animation ───────────────────────────────────────────
  bool playerScoreAnim = false;
  bool aiScoreAnim = false;

  final GameSettings settings;
  PaddleItem get currentPaddle => getPaddleById(settings.equippedPaddleId);
  PaddleItem get _standardGameplayPaddle =>
      getPaddleById('paddle_standard');
  late final PaddleItem aiPaddle;
  late final PaddleItem? playerPartnerPaddle;
  late final PaddleItem? aiPartnerPaddle;

  /// Returns the paddle assigned for the lifetime of this match. Human slots
  /// use their equipped paddle; every bot receives one random catalog paddle.
  PaddleItem paddleFor(Player matchPlayer) {
    if (identical(matchPlayer, player)) return currentPaddle;
    if (identical(matchPlayer, ai)) {
      return ai.isHuman ? currentPaddle : aiPaddle;
    }
    if (identical(matchPlayer, playerPartner)) {
      return playerPartnerPaddle ?? currentPaddle;
    }
    if (identical(matchPlayer, aiPartner)) {
      return aiPartnerPaddle ?? currentPaddle;
    }
    return currentPaddle;
  }

  /// Returns normalized stats in competitive matches while [paddleFor]
  /// continues returning the equipped item for rendering.
  PaddleItem gameplayPaddleFor(Player matchPlayer) {
    if (balanceProfile == MatchBalanceProfile.competitive) {
      return _standardGameplayPaddle;
    }
    return paddleFor(matchPlayer);
  }

  PlayerSkinItem get currentPlayerSkin =>
      getPlayerSkinById(settings.equippedPlayerId);
  double get gameplayMoveSpeedMultiplier =>
      balanceProfile == MatchBalanceProfile.competitive
          ? 1.0
          : currentPlayerSkin.speedMultiplier;
  double get gameplayStaminaRegenMultiplier =>
      balanceProfile == MatchBalanceProfile.competitive
          ? 1.0
          : currentPlayerSkin.staminaRegenMultiplier;

  final String? drillType;
  final AudioService? audioService;
  final AIDifficulty? difficultyOverride;

  AIDifficulty get currentAIDifficulty =>
      difficultyOverride ?? settings.difficulty;

  PickleballGame({
    @Deprecated('Rendering owns viewport size; simulation is size-independent.')
    Size? screenSize,
    this.isPracticeMode = false,
    this.drillType,
    this.gameMode = GameMode.singles,
    this.isLocalMultiplayer = false,
    this.balanceProfile = MatchBalanceProfile.standard,
    required this.settings,
    this.difficultyOverride,
    this.audioService,
    this.effects = const NoGameEffects(),
    math.Random? paddleRandom,
  })  : player = Player(
          startPosition: Vec3(16.0, 0, CourtDimensions.playerStartZ),
          isHuman: true,
          isNearSide: true,
          assignedRightSide: true,
        ),
        playerPartner = (gameMode == GameMode.doubles)
            ? Player(
                startPosition: Vec3(-16.0, 0, CourtDimensions.playerStartZ),
                isHuman: false,
                isPartner: true,
                isNearSide: true,
                assignedRightSide: false,
              )
            : null,
        ai = Player(
          startPosition: Vec3(-16.0, 0, CourtDimensions.aiStartZ),
          isHuman: isLocalMultiplayer,
          isNearSide: false,
          assignedRightSide: true,
        ),
        aiPartner = (gameMode == GameMode.doubles)
            ? Player(
                startPosition: Vec3(16.0, 0, CourtDimensions.aiStartZ),
                isHuman: false,
                isPartner: false,
                isNearSide: false,
                assignedRightSide: false,
              )
            : null,
        ball = Pickleball(),
        court = Court(),
        state = GameState.waitingForServe,
        stateTimer = 0,
        lastMessage = '',
        messageTimer = 0 {
    final matchRandom = paddleRandom ?? math.Random();
    PaddleItem randomPaddle() =>
        kPaddleCatalog[matchRandom.nextInt(kPaddleCatalog.length)];
    aiPaddle = ai.isHuman ? currentPaddle : randomPaddle();
    playerPartnerPaddle = playerPartner == null ? null : randomPaddle();
    aiPartnerPaddle = aiPartner == null ? null : randomPaddle();

    // Init controllers
    ballController = BallController(
      ball: ball,
      court: court,
      onBounce: () {
        audioService?.playBounce();
        _onBallBounce();
      },
      settings: settings,
    );
    playerController = PlayerController(player: player);
    opponentPlayerController = PlayerController(player: ai);
    aiController = AIController(
      ai: ai,
      ball: ball,
      court: court,
      settings: settings,
      difficultyOverride: difficultyOverride,
      isPracticeMode: isPracticeMode,
      drillType: drillType,
      humanPlayer: player,
      teammate: aiPartner,
      hasCoverageClaim: _hasDoublesCoverageClaim,
      preferredTargetX: () => farTeamSuggestedTargetX,
      paddleSpin: gameplayPaddleFor(ai).spin,
      onHit: (isPower) {
        _lastRallyHitter = ai;
        _onAIHit(isPower);
      },
    );

    if (gameMode == GameMode.doubles) {
      partnerController = AIController(
        ai: playerPartner!,
        ball: ball,
        court: court,
        settings: settings,
        difficultyOverride: difficultyOverride,
        isPracticeMode: isPracticeMode,
        drillType: drillType,
        humanPlayer: ai,
        teammate: player,
        hasCoverageClaim: _hasDoublesCoverageClaim,
        preferredTargetX: () => nearTeamSuggestedTargetX,
        paddleSpin: gameplayPaddleFor(playerPartner!).spin,
        onHit: (isPower) {
          _lastRallyHitter = playerPartner;
          _onAIHit(isPower);
        },
      );
      aiPartnerController = AIController(
        ai: aiPartner!,
        ball: ball,
        court: court,
        settings: settings,
        difficultyOverride: difficultyOverride,
        isPracticeMode: isPracticeMode,
        drillType: drillType,
        humanPlayer: player,
        teammate: ai,
        hasCoverageClaim: _hasDoublesCoverageClaim,
        preferredTargetX: () => farTeamSuggestedTargetX,
        paddleSpin: gameplayPaddleFor(aiPartner!).spin,
        onHit: (isPower) {
          _lastRallyHitter = aiPartner;
          _onAIHit(isPower);
        },
      );
    }

    physicsController = PhysicsController(
      ball: ball,
      player: player,
      playerPartner: playerPartner,
      ai: ai,
      aiPartner: aiPartner,
      court: court,
    );
    scoreController = ScoreController(
      player: player,
      ai: ai,
      isPracticeMode: isPracticeMode,
      drillType: drillType,
      gameMode: gameMode,
    );

    // Reset initial positions and prepare serve
    _setupServePositions();
  }

  // ── Main update loop ──────────────────────────────────────────
  void update(double dt) {
    if (state == GameState.paused || state == GameState.gameOver) return;

    matchStats.advanceTime(dt);

    // Bullet-time slow motion & cinematic cut-in decay
    if (slowMoTimer > 0) {
      slowMoTimer -= dt;
      if (slowMoTimer <= 0) timeDilation = 1.0;
    }
    if (ultimateCutinTimer > 0) {
      ultimateCutinTimer -= dt;
    }

    stateTimer += dt;

    // Tick message timer
    if (messageTimer > 0) {
      messageTimer -= dt;
      if (messageTimer <= 0) lastMessage = '';
    }

    // Tick swing buffer timer
    if (swingBufferTimer > 0) {
      swingBufferTimer -= dt;
      if (swingBufferTimer <= 0) {
        bufferedShot = null;
        bufferedSpin = ShotSpin.flat;
        bufferedTimingIntent = null;
      }
    }
    if (opponentSwingBufferTimer > 0) {
      opponentSwingBufferTimer -= dt;
      if (opponentSwingBufferTimer <= 0) {
        opponentBufferedShot = null;
        opponentBufferedSpin = ShotSpin.flat;
        opponentBufferedTimingIntent = null;
      }
    }
    final feedback = contactFeedback;
    if (feedback != null) {
      final remaining = feedback.remaining - dt;
      contactFeedback = remaining > 0
          ? ContactFeedback(
              grade: feedback.grade,
              position: feedback.position,
              playerSlot: feedback.playerSlot,
              revision: feedback.revision,
              remaining: remaining,
            )
          : null;
    }

    // Stamina regeneration
    player.regenStamina(dt * gameplayStaminaRegenMultiplier);
    ai.regenStamina(dt);
    playerPartner?.regenStamina(dt);

    // Decay screen shake
    // State machine
    switch (state) {
      case GameState.waitingForServe:
        _updateWaitingForServe(dt);
        break;
      case GameState.rally:
        _updateRally(dt);
        break;
      case GameState.pointScored:
        _updatePointScored(dt);
        break;
      case GameState.gameOver:
      case GameState.paused:
        break;
    }

    notifyListeners();
  }

  // ── Position players for regulation serve ──────────────────────
  void _setupServePositions() {
    scoreController.lastFaultDetail = '';
    final serverRight = scoreController.serverShouldBeOnRight;
    const serveZ =
        CourtDimensions.halfLength + CourtDimensions.serveBaselineOffset;

    // Preserve each teammate's official side across side-outs. Only a point
    // won by the serving team swaps that team's two court positions.
    if (gameMode == GameMode.doubles) {
      player.assignedRightSide = scoreController.playerPrimaryOnRight;
      playerPartner?.assignedRightSide = !scoreController.playerPrimaryOnRight;
      ai.assignedRightSide = scoreController.aiPrimaryOnRight;
      aiPartner?.assignedRightSide = !scoreController.aiPrimaryOnRight;
    } else {
      player.assignedRightSide = serverRight;
      ai.assignedRightSide = serverRight;
    }
    aiController.resetForRally();
    partnerController?.resetForRally();
    aiPartnerController?.resetForRally();
    _nearTeamCoverageOwner = null;
    _farTeamCoverageOwner = null;
    _lastNearTeamCoverageOwner = null;
    _lastFarTeamCoverageOwner = null;
    _lastRallyHitter = null;
    _coverageRevision = -1;
    _setRallyPhase(RallyPhase.opening);

    if (scoreController.isPlayerServing) {
      final server = activeServer;
      final teammate = identical(server, player) ? playerPartner : player;
      server.resetPosition(
        customX: _formationX(server, nearSide: true),
        customZ: serveZ,
      );
      teammate?.resetPosition(
        customX: _formationX(teammate, nearSide: true),
        customZ: CourtDimensions.playerStartZ * 0.7,
      );
      ball.resetForPlayerServe(fromRight: serverRight);

      final receiver = activeReceiver;
      final receiverPartner = identical(receiver, ai) ? aiPartner : ai;
      receiver.resetPosition(
        customX: _formationX(receiver, nearSide: false),
        customZ: CourtDimensions.aiStartZ - 10,
      );
      receiverPartner?.resetPosition(
        customX: _formationX(receiverPartner, nearSide: false),
        customZ: CourtDimensions.aiStartZ * 0.7,
      );
    } else {
      final server = activeServer;
      final teammate = identical(server, ai) ? aiPartner : ai;
      server.resetPosition(
        customX: _formationX(server, nearSide: false),
        customZ: -serveZ,
      );
      teammate?.resetPosition(
        customX: _formationX(teammate, nearSide: false),
        customZ: CourtDimensions.aiStartZ * 0.7,
      );
      ball.resetForAIServe(fromRight: serverRight);

      final receiver = activeReceiver;
      final receiverPartner =
          identical(receiver, player) ? playerPartner : player;
      receiver.resetPosition(
        customX: _formationX(receiver, nearSide: true),
        customZ: CourtDimensions.playerStartZ + 10,
      );
      receiverPartner?.resetPosition(
        customX: _formationX(receiverPartner, nearSide: true),
        customZ: CourtDimensions.playerStartZ * 0.7,
      );
    }
    _aiServeDelay = 1.1 + math.Random().nextDouble() * 0.6;
  }

  double _formationX(Player member, {required bool nearSide}) {
    if (nearSide) return member.assignedRightSide ? 16.0 : -16.0;
    return member.assignedRightSide ? -16.0 : 16.0;
  }

  bool _hasDoublesCoverageClaim(Player candidate) {
    if (gameMode != GameMode.doubles) return true;
    return candidate.isNearSide
        ? identical(candidate, _nearTeamCoverageOwner)
        : identical(candidate, _farTeamCoverageOwner);
  }

  double _doublesTargetX({required bool nearTeam}) {
    // Alternate the intended lane once per exchange. Near and far teams use
    // opposite lanes within an exchange, producing real cross-court changes
    // instead of feeding the same receiver forever.
    final exchange = ball.rallyHitCount ~/ 2;
    final targetRight = (exchange + (nearTeam ? 0 : 1)).isEven;
    return targetRight ? 16.0 : -16.0;
  }

  void _updateDoublesCoverageOwner() {
    if (gameMode != GameMode.doubles || !ball.isInPlay) return;

    final revision = ball.rallyHitCount * 2 + (ball.lastHitByPlayer ? 1 : 0);
    if (revision == _coverageRevision) return;
    _coverageRevision = revision;

    final incomingNear = !ball.lastHitByPlayer && ball.velocity.z > 2.0;
    final incomingFar = ball.lastHitByPlayer && ball.velocity.z < -2.0;
    if (!incomingNear && !incomingFar) return;

    // The diagonal receiver owns the serve return. Later balls are assigned
    // once per incoming shot from their projected first-bounce location.
    if (ball.rallyHitCount == 0) {
      final receiver = activeReceiver;
      if (receiver.isNearSide) {
        _nearTeamCoverageOwner = receiver;
        _lastNearTeamCoverageOwner = receiver;
        _farTeamCoverageOwner = null;
      } else {
        _farTeamCoverageOwner = receiver;
        _lastFarTeamCoverageOwner = receiver;
        _nearTeamCoverageOwner = null;
      }
      return;
    }

    final target = _predictCoverageTarget();
    if (incomingNear && playerPartner != null) {
      _nearTeamCoverageOwner = _selectDoublesCoverageOwner(
        player,
        playerPartner!,
        target,
        previousOwner: _lastNearTeamCoverageOwner,
      );
      _lastNearTeamCoverageOwner = _nearTeamCoverageOwner;
      _farTeamCoverageOwner = null;
    } else if (incomingFar && aiPartner != null) {
      _farTeamCoverageOwner = _selectDoublesCoverageOwner(
        ai,
        aiPartner!,
        target,
        previousOwner: _lastFarTeamCoverageOwner,
      );
      _lastFarTeamCoverageOwner = _farTeamCoverageOwner;
      _nearTeamCoverageOwner = null;
    }
  }

  Player _selectDoublesCoverageOwner(
    Player first,
    Player second,
    Vec3 target, {
    required Player? previousOwner,
  }) {
    double distance(Player member) {
      return dist2D(
        member.position.x,
        member.position.z,
        target.x,
        target.z,
      );
    }

    // A ball through the middle is genuinely shared territory. Give it to
    // the teammate who did not own the previous incoming shot, preventing a
    // center-positioned bot from monopolizing an entire rally.
    if (target.x.abs() < 5.0) {
      return identical(previousOwner, first) ? second : first;
    }

    // Normal doubles coverage starts with the official left/right formation,
    // not whichever bot happened to drift closest during the previous shot.
    final nearSide = first.isNearSide;
    final firstHomeX = _formationX(first, nearSide: nearSide);
    final firstOwnsLane = target.x * firstHomeX >= 0;
    final laneOwner = firstOwnsLane ? first : second;
    final teammate = firstOwnsLane ? second : first;

    // Preserve a realistic emergency poach when the lane owner is badly out
    // of position, while keeping ordinary shots assigned to both lanes.
    const poachAdvantage = 14.0;
    return distance(teammate) + poachAdvantage < distance(laneOwner)
        ? teammate
        : laneOwner;
  }

  Vec3 _predictCoverageTarget() {
    if (ball.hasBounced) return ball.position.copy();

    var x = ball.position.x;
    var y = ball.position.y;
    var z = ball.position.z;
    var vx = ball.velocity.x;
    var vy = ball.velocity.y;
    var vz = ball.velocity.z;
    const step = 0.025;

    for (var i = 0; i < 160; i++) {
      vy -= PhysicsConstants.gravity * step;
      final speed = math.sqrt(vx * vx + vy * vy + vz * vz);
      if (speed > 0.1) {
        final drag = (1.0 - PhysicsConstants.ballDragCoefficient * speed * step)
            .clamp(0.0, 1.0);
        vx *= drag;
        vy *= drag;
        vz *= drag;
      }
      x += vx * step;
      y += vy * step;
      z += vz * step;
      if (y <= PhysicsConstants.ballRadius) {
        return Vec3(x, PhysicsConstants.ballRadius, z);
      }
    }
    return Vec3(x, y, z);
  }

  // ── State: Waiting for serve ───────────────────────────────────
  void _updateWaitingForServe(double dt) {
    if (identical(activeServer, player)) {
      _updatePlayerServePosition(dt);
      if (isLocalMultiplayer) {
        opponentPlayerController.updateMovement(
          dt,
          opponentJoystickX,
          -opponentJoystickY,
        );
        ai.clampToCourt();
      }
    } else if (isOpponentHumanServing) {
      _updateOpponentServePosition(dt);
      playerController.updateMovement(dt, joystickX, joystickY);
      player.clampToCourt();
    } else {
      // The human remains free to move while receiving or while their partner
      // is the active server.
      playerController.updateMovement(dt, joystickX, joystickY);
      player.clampToCourt();
      if (isLocalMultiplayer && !identical(activeServer, ai)) {
        opponentPlayerController.updateMovement(
          dt,
          opponentJoystickX,
          -opponentJoystickY,
        );
        ai.clampToCourt();
      }
    }

    // Position ball above server
    final server = activeServer;
    if (scoreController.isPlayerServing) {
      ball.position = Vec3(
        server.position.x,
        PhysicsConstants.serveBallHeight,
        server.position.z - 2,
      );
      if (!isHumanServing && stateTimer > _aiServeDelay) {
        _partnerServe();
      }
    } else {
      ball.position = Vec3(
        server.position.x,
        PhysicsConstants.serveBallHeight,
        server.position.z + 2,
      );
      // AI starts serving after a short natural delay
      if (!isOpponentHumanServing && stateTimer > _aiServeDelay) {
        _aiServe();
      }
    }

    // Player presses serve
    if (servePressed && isHumanServing) {
      servePressed = false;
      if (identical(activeServer, player)) _playerServe();
    }
    if (opponentServePressed && isOpponentHumanServing) {
      opponentServePressed = false;
      _aiServe();
    }
  }

  void _updateOpponentServePosition(double dt) {
    final serverRight = scoreController.serverShouldBeOnRight;
    const sideMargin = 5.0;
    const serveZ =
        -CourtDimensions.halfLength - CourtDimensions.serveBaselineOffset;
    opponentPlayerController.updateMovement(
      dt,
      opponentJoystickX,
      -opponentJoystickY,
    );
    ai.position.x = serverRight
        ? ai.position.x.clamp(
            -CourtDimensions.halfWidth + sideMargin,
            -sideMargin,
          )
        : ai.position.x.clamp(
            sideMargin,
            CourtDimensions.halfWidth - sideMargin,
          );
    ai.position.z = serveZ;
    ai.velocity.z = 0;
  }

  void _updatePlayerServePosition(double dt) {
    final serverRight = scoreController.serverShouldBeOnRight;
    const sideMargin = 5.0;
    const serveZ =
        CourtDimensions.halfLength + CourtDimensions.serveBaselineOffset;

    // Only lateral positioning is legal before contact. Keeping Z fixed
    // prevents the server's feet from crossing or touching the baseline.
    playerController.updateMovement(dt, joystickX, 0);
    player.position.x = serverRight
        ? player.position.x.clamp(
            sideMargin,
            CourtDimensions.halfWidth - sideMargin,
          )
        : player.position.x.clamp(
            -CourtDimensions.halfWidth + sideMargin,
            -sideMargin,
          );
    player.position.z = serveZ;
    player.velocity.z = 0;
  }

  ServeTrajectoryPreview getPlayerServeTrajectory({int samples = 24}) {
    final serverRight = scoreController.serverShouldBeOnRight;
    final targetX = serverRight ? -16.0 : 16.0;
    const targetZ = -55.0; // Deep in AI service box past the kitchen line (-28)
    final start = Vec3(
      activeServer.position.x,
      PhysicsConstants.serveBallHeight,
      activeServer.position.z - 2,
    );
    const vy = 32.0;
    const g = PhysicsConstants.gravity;
    final y0 = start.y;
    final tFlight = (vy + math.sqrt(vy * vy + 2 * g * y0)) / g;
    final vz = (targetZ - start.z) / tFlight;
    final vx = (targetX - start.x) / tFlight;
    final sampleCount = samples.clamp(8, 40).toInt();
    final points = <Vec3>[];
    for (int i = 0; i <= sampleCount; i++) {
      final t = tFlight * i / sampleCount;
      points.add(Vec3(
        start.x + vx * t,
        math.max(0, start.y + vy * t - 0.5 * g * t * t),
        start.z + vz * t,
      ));
    }

    return ServeTrajectoryPreview(
      points: points,
      launchVelocity: Vec3(vx, vy, vz),
      targetX: targetX,
      targetZ: targetZ,
      serverOnRight: serverRight,
      isLegal: court.isValidServiceBox(targetX, targetZ, serverRight),
    );
  }

  void _playerServe() {
    final trajectory = getPlayerServeTrajectory();
    ball.position = trajectory.points.first.copy();

    ball.velocity = trajectory.launchVelocity.copy();
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = true;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.rallyHitCount = 0;
    ball.isServe = true;
    ball.serverOnRight = trajectory.serverOnRight;
    ball.shotType = ShotType.normal;

    state = GameState.rally;
    stateTimer = 0;
    audioService?.playHit(isPower: false);
    effects.spawnHitSparks(ball.position, AppColors.ballColor, power: 0.2);
    player.isSwinging = true;
    player.animState = PlayerAnimState.serve;
    player.animTimer = 0;
  }

  void _aiServe() {
    final serverRight = scoreController.serverShouldBeOnRight;
    final rng = math.Random();
    final diff = currentAIDifficulty;

    double baseTargetX;
    double targetZ;
    double vy;

    if (isPracticeMode) {
      baseTargetX = serverRight ? 18.5 : -18.5;
      targetZ = 60.0;
      vy = 28.0;
    } else {
      switch (diff) {
        case AIDifficulty.easy:
          // Gentle, centered in diagonal box, easy to return
          baseTargetX = serverRight ? 14.0 : -14.0;
          targetZ = 48.0 + rng.nextDouble() * 5.0;
          vy = 32.0;
          break;
        case AIDifficulty.medium:
          // Solid depth and pace
          baseTargetX = serverRight ? 18.0 : -18.0;
          targetZ = 54.0 + rng.nextDouble() * 6.0;
          vy = 30.0;
          break;
        case AIDifficulty.hard:
          // Aggressive corner drive deep into service box
          baseTargetX = serverRight ? 23.0 : -23.0;
          targetZ = 58.0 + rng.nextDouble() * 5.0;
          vy = 26.0;
          break;
      }
    }

    final targetX = (baseTargetX +
            (rng.nextDouble() - 0.5) * (diff == AIDifficulty.hard ? 2.5 : 5.0))
        .clamp(
      serverRight ? 4.0 : -CourtDimensions.halfWidth + 4.0,
      serverRight ? CourtDimensions.halfWidth - 4.0 : -4.0,
    );

    const g = PhysicsConstants.gravity;
    final y0 = ball.position.y;
    final tFlight = (vy + math.sqrt(vy * vy + 2 * g * y0)) / g;

    final server = activeServer;
    final vz = (targetZ - server.position.z) / tFlight;
    final vx = (targetX - server.position.x) / tFlight;

    ball.velocity = Vec3(vx, vy, vz);
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = false;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.rallyHitCount = 0;
    ball.isServe = true;
    ball.serverOnRight = serverRight;
    ball.shotType = ShotType.normal;

    state = GameState.rally;
    stateTimer = 0;
    audioService?.playHit(isPower: false);
    effects.spawnHitSparks(ball.position, AppColors.ballColor,
        power: 0.2, dirZ: 1.0);
    server.animState = PlayerAnimState.serve;
    server.animTimer = 0;
  }

  void _partnerServe() {
    final trajectory = getPlayerServeTrajectory();
    final server = activeServer;
    ball.position = trajectory.points.first.copy();
    ball.velocity = trajectory.launchVelocity.copy();
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = true;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.rallyHitCount = 0;
    ball.isServe = true;
    ball.serverOnRight = trajectory.serverOnRight;
    ball.shotType = ShotType.normal;

    state = GameState.rally;
    stateTimer = 0;
    audioService?.playHit(isPower: false);
    effects.spawnHitSparks(ball.position, AppColors.ballColor, power: 0.2);
    server.animState = PlayerAnimState.serve;
    server.animTimer = 0;
  }

  // ── State: Rally ───────────────────────────────────────────────
  void _updateRally(double dt) {
    final effectiveDt = dt * timeDilation;

    // Update ball physics with effectiveDt (bullet time)
    ballController.update(effectiveDt);

    // Ground faults must become dead balls before any player or bot can swing.
    // Otherwise a same-frame return can reset bounceCount and erase a valid
    // second-bounce call.
    final immediatePointResult = scoreController.checkPoint(ball, court);
    if (immediatePointResult != PointResult.none) {
      _handlePointResult(immediatePointResult);
      return;
    }

    _refreshRallyPhase();

    // ── Special Ultimate Ball Trajectory Logic ──────────────────
    if (ball.isUltimate && ball.isInPlay) {
      ball.ultimateAnimTimer += effectiveDt;

      // 1. Ghost Phantom: 3-clone illusion & mid-air vortex swerve
      if (ball.ultimateType == UltimateType.ghostPhantom) {
        final wave = math.sin(ball.ultimateAnimTimer * 18.0) * 11.0;
        ball.updateGhostClones(wave);

        // Lateral vortex swerve right around the net
        if (ball.position.z > -15 && ball.position.z < 20) {
          ball.velocity.x +=
              math.cos(ball.ultimateAnimTimer * 14.0) * 35.0 * effectiveDt;
        }
      }

      // 2. Dragon Meteor: diving comet into kitchen with near-zero bounce
      if (ball.ultimateType == UltimateType.dragonMeteor) {
        if (ball.position.z < 25 && ball.velocity.z < 0) {
          ball.velocity.y -= 85.0 * effectiveDt; // steep dive
        }
        if (ball.hasBounced && ball.bounceCount == 1) {
          ball.velocity.y *= 0.20; // dies on ground
          ball.velocity.x *= 0.40;
          ball.velocity.z *= 0.40;
        }
      }

      // 3. Frostbite Blizzard: spawn freeze ring on bounce
      if (ball.ultimateType == UltimateType.frostbite) {
        if (ball.hasBounced && ball.iceZoneTimer <= 0 && ball.position.z < 0) {
          ball.iceZoneCenter = Vec3(ball.position.x, 0, ball.position.z);
          ball.iceZoneRadius = 26.0;
          ball.iceZoneTimer = 3.5;
        }
      }

      // 4. Thunderbolt Smash: decay lightning flash
      if (ball.ultimateType == UltimateType.thunderbolt &&
          ball.lightningFlash > 0) {
        ball.lightningFlash =
            math.max(0, ball.lightningFlash - effectiveDt * 3.0);
      }
    }

    // ── Frostbite Ice Zone Field Update ─────────────────────────
    if (ball.iceZoneTimer > 0) {
      ball.iceZoneTimer -= dt;
      if (ball.iceZoneCenter != null) {
        final dist = dist2D(
          ai.position.x,
          ai.position.z,
          ball.iceZoneCenter!.x,
          ball.iceZoneCenter!.z,
        );
        if (dist < ball.iceZoneRadius + 8) {
          ai.speedMultiplier = 0.50; // slowed down!
        } else {
          ai.speedMultiplier = 1.0;
        }
      }
    } else {
      ai.speedMultiplier = 1.0;
      ball.iceZoneCenter = null;
    }

    // Update player movement
    playerController.updateMovement(
      dt,
      joystickX,
      joystickY,
      speedMultiplier: gameplayMoveSpeedMultiplier,
    );
    player.clampToCourt();
    if (isLocalMultiplayer) {
      opponentPlayerController.updateMovement(
        dt,
        opponentJoystickX,
        -opponentJoystickY,
      );
      ai.clampToCourt();
    }

    // USA Pickleball NVZ Momentum Rule:
    // If player executed a volley and momentum carries them into NVZ or onto NVZ line
    final playerTeamMomentumOffender = player.kitchenMomentumFlag &&
            player.isInKitchen(includeFootMargin: true)
        ? player
        : (playerPartner?.kitchenMomentumFlag == true &&
                playerPartner!.isInKitchen(includeFootMargin: true)
            ? playerPartner
            : null);
    if (playerTeamMomentumOffender != null) {
      playerTeamMomentumOffender.kitchenMomentumFlag = false;
      scoreController.lastFaultDetail =
          playerTeamMomentumOffender.isTouchingKitchenLine()
              ? 'KITCHEN LINE TOUCH VIOLATION!'
              : 'NVZ MOMENTUM FAULT!';
      _handlePointResult(PointResult.kitchenFault, playerFaulted: true);
      return;
    }

    // Check AI kitchen momentum violation
    final aiTeamMomentumOffender =
        ai.kitchenMomentumFlag && ai.isInKitchen(includeFootMargin: true)
            ? ai
            : (aiPartner?.kitchenMomentumFlag == true &&
                    aiPartner!.isInKitchen(includeFootMargin: true)
                ? aiPartner
                : null);
    if (aiTeamMomentumOffender != null) {
      aiTeamMomentumOffender.kitchenMomentumFlag = false;
      scoreController.lastFaultDetail = 'OPPONENT NVZ MOMENTUM FAULT!';
      _handlePointResult(PointResult.kitchenFault, playerFaulted: false);
      return;
    }

    // Update NVZ foot establishment and clear momentum if stopped
    player.updateKitchenStatus(dt);
    playerPartner?.updateKitchenStatus(dt);
    ai.updateKitchenStatus(dt);
    aiPartner?.updateKitchenStatus(dt);

    // Check Player Swing Inputs / Queued Buffered Shots
    if (ultimatePressed) {
      if (isUltimateReady) {
        isUltimateArmed = true;
        if (bufferedShot == null) queueShot(ShotType.ultimate);
      }
      ultimatePressed = false;
    } else if (powerPressed) {
      if (bufferedShot == null) queueShot(ShotType.power);
      powerPressed = false;
    } else if (lobPressed) {
      if (bufferedShot == null) queueShot(ShotType.lob);
      lobPressed = false;
    } else if (dropPressed) {
      if (bufferedShot == null) queueShot(ShotType.drop);
      dropPressed = false;
    } else if (hitPressed) {
      if (bufferedShot == null) queueShot(ShotType.normal);
      hitPressed = false;
    }

    // Initiate swing animation immediately if shot is queued and player can swing
    if (bufferedShot != null && player.canSwing) {
      final dir = _getAimDirection();
      player.isSwinging = true;
      player.swingCooldown = 0.40;
      player.isForehand = dir.dx >= 0;
      player.animState = player.isForehand
          ? PlayerAnimState.forehand
          : PlayerAnimState.backhand;
      player.animTimer = 0;
      player.swingArm = 0;
    }

    if (isLocalMultiplayer && opponentBufferedShot != null && ai.canSwing) {
      final dir = _getOpponentAimDirection();
      ai.isSwinging = true;
      ai.swingCooldown = 0.40;
      ai.isForehand = dir.dx <= 0;
      ai.animState =
          ai.isForehand ? PlayerAnimState.forehand : PlayerAnimState.backhand;
      ai.animTimer = 0;
      ai.swingArm = 0;
    }

    // Check if ball makes contact with swinging paddle
    if (player.isSwinging &&
        !ball.lastHitByPlayer &&
        ball.state != BallState.dead) {
      final distToBall = dist2D(
        ball.position.x,
        ball.position.z,
        player.position.x,
        player.position.z,
      );
      final hitRadius =
          30.0 + (gameplayPaddleFor(player).control - 0.50) * 12.0;
      final lungeRadius = hitRadius * 1.15;
      
      bool withinNormalReach = distToBall < hitRadius;
      bool withinLungeReach = distToBall < lungeRadius;

      if (withinLungeReach &&
          ball.position.y < 42 &&
          ball.position.z > -8 &&
          ball.canBeHitAfterBounce) {
        
        if (!withinNormalReach) {
          if (player.stamina >= StaminaConstants.maxStamina * 0.15) {
            player.useStamina(StaminaConstants.maxStamina * 0.15);
            player.isLunging = true;
            player.hasLungedThisShot = true;
            player.lungeRecoveryTimer = 0.35;
          } else {
            // Can't reach it and don't have stamina to lunge
            withinLungeReach = false; 
          }
        }

        if (withinLungeReach) {
          _executePlayerHit(
            bufferedShot ??
                (isUltimateArmed ? ShotType.ultimate : ShotType.normal),
            requestedSpin: bufferedSpin,
            timingIntent: bufferedTimingIntent,
          );
          bufferedShot = null;
          bufferedSpin = ShotSpin.flat;
          bufferedTimingIntent = null;
          swingBufferTimer = 0;
        }
      }
    }

    if (isLocalMultiplayer &&
        ai.isSwinging &&
        ball.lastHitByPlayer &&
        ball.state != BallState.dead) {
      final distToBall = dist2D(
        ball.position.x,
        ball.position.z,
        ai.position.x,
        ai.position.z,
      );
      if (distToBall < 30 &&
          ball.position.y < 42 &&
          ball.position.z < 8 &&
          ball.canBeHitAfterBounce) {
        _executeOpponentHit(
          opponentBufferedShot ?? ShotType.normal,
          requestedSpin: opponentBufferedSpin,
          timingIntent: opponentBufferedTimingIntent,
        );
        opponentBufferedShot = null;
        opponentBufferedSpin = ShotSpin.flat;
        opponentBufferedTimingIntent = null;
        opponentSwingBufferTimer = 0;
      }
    }

    // Update player animation
    playerController.updateAnimation(dt);
    if (isLocalMultiplayer) opponentPlayerController.updateAnimation(dt);

    // Update AI controllers
    _updateDoublesCoverageOwner();
    if (!isLocalMultiplayer) aiController.update(effectiveDt);
    partnerController?.update(effectiveDt);
    aiPartnerController?.update(effectiveDt);

    // Physics: paddle collisions
    final collision = physicsController.update(dt);
    if (collision.playerHit) {
      effects.pulseCamera(shake: 0.3, zoom: 0.95);
      audioService?.playHit(isPower: collision.powerHit);
    }
    if (collision.aiHit) {
      audioService?.playHit(isPower: collision.powerHit);
    }
    if (collision.netHit) {
      audioService?.playNetHit();
      effects.spawnNetPuff(ball.position);
    }
    if (collision.powerHit) {
      effects.pulseCamera(zoom: 0.90);
    }

    // Check scoring & rule conditions
    final pointResult = scoreController.checkPoint(ball, court);
    if (pointResult != PointResult.none) {
      _handlePointResult(pointResult);
    }
  }

  void _executePlayerHit(
    ShotType shotType, {
    ShotSpin requestedSpin = ShotSpin.flat,
    double? timingIntent,
  }) {
    if (gameMode == GameMode.doubles &&
        ball.rallyHitCount == 0 &&
        !identical(activeReceiver, player)) {
      scoreController.lastFaultDetail = 'WRONG RECEIVER FAULT!';
      _handlePointResult(
        PointResult.wrongReceiverFault,
        playerFaulted: true,
      );
      return;
    }

    // ── Rule Check 1: Two-Bounce Rule ──────────────────────────
    if (ball.rallyHitCount < 2 && !ball.hasBounced) {
      _handlePointResult(PointResult.twoBounceFault, playerFaulted: true);
      return;
    }

    // ── Rule Check 2: Kitchen (Non-Volley Zone) Rule ────────────
    // A volley means hitting the ball before it bounces.
    // If the ball bounces first, entering the Kitchen and hitting it is completely legal.
    // But you cannot volley while inside the Kitchen or touching the Kitchen line.
    // Furthermore, after leaving the Kitchen, both feet must be established outside before you volley.
    if (!ball.hasBounced) {
      if (player.isInKitchen(includeFootMargin: true)) {
        scoreController.lastFaultDetail = player.isTouchingKitchenLine()
            ? 'KITCHEN LINE TOUCH VIOLATION!'
            : 'KITCHEN VOLLEY FAULT!';
        _handlePointResult(PointResult.kitchenFault, playerFaulted: true);
        return;
      }

      if (!player.hasEstablishedOutsideKitchen) {
        scoreController.lastFaultDetail =
            'NVZ FAULT: FEET NOT ESTABLISHED OUTSIDE!';
        _handlePointResult(PointResult.kitchenFault, playerFaulted: true);
        return;
      }

      // Arm kitchen momentum flag when striking a legal volley outside the kitchen
      player.kitchenMomentumFlag = true;
    }

    final paddle = gameplayPaddleFor(player);
    final staminaDiscount =
        (1.0 - (paddle.staminaEfficiency - 0.50) * 0.35).clamp(0.65, 1.0);

    // ── Check if executing Ultimate ────────────────────────────
    ShotType activeShot = shotType;
    final isExecutingUltimate = specialSkillsEnabled &&
        (isUltimateArmed || shotType == ShotType.ultimate);
    if (!specialSkillsEnabled && activeShot == ShotType.ultimate) {
      activeShot = ShotType.normal;
    }

    if (isExecutingUltimate) {
      activeShot = ShotType.ultimate;
      ultimateCharge = 0.0;
      isUltimateArmed = false;
      ball.isUltimate = true;
      final ultType = equippedUltimate;
      ball.ultimateType = ultType;
      ball.ultimateAnimTimer = 0;
      activeCutinUltimate = ultType;
      // Keep the cinematic readable without carrying its most expensive
      // full-screen rendering work through most of the shot.
      ultimateCutinTimer = 0.9;
      slowMoTimer = 0.35;
      timeDilation = 0.25;
      final ultSkill = getUltimateByType(ultType);
      lastMessage = '${ultSkill.name}!';
      messageTimer = 2.0;
    } else {
      // Intelligently adapt shot to match context (e.g. auto-smash floaters, kitchen dink assist)
      activeShot = resolveContextualShotType(
        requestedShot: activeShot,
        player: player,
        ball: ball,
      );

      // Stamina check for non-ultimate shots
      if (activeShot == ShotType.power &&
          !player
              .useStamina(StaminaConstants.powerShotCost * staminaDiscount)) {
        activeShot = ShotType.normal;
      } else if (activeShot == ShotType.lob &&
          !player.useStamina(StaminaConstants.lobShotCost * staminaDiscount)) {
        activeShot = ShotType.normal;
      } else if (activeShot == ShotType.drop &&
          !player.useStamina(StaminaConstants.dropShotCost * staminaDiscount)) {
        activeShot = ShotType.normal;
      }
    }

    final hitRadius = 30.0 + (paddle.control - 0.50) * 12.0;
    final quality = calculateShotQuality(
      player: player,
      ball: ball,
      hitRadius: hitRadius,
    );
    final timingGrade = gradeSwingTiming(
      timeToIdealContact: timingIntent,
      isSweetSpot: quality.isSweetSpot,
    );
    final timing = timingModifiersFor(timingGrade);

    final dir = _getAimDirection();
    final solution = solvePlayerShotTrajectory(
      shotType: activeShot,
      player: player,
      ball: ball,
      aimDirection: dir,
      quality: quality,
      paddle: paddle,
      joystickY: joystickY,
      isNearSide: true,
      timingGrade: timingGrade,
      paceMultiplier: player.hasLungedThisShot ? 0.88 : 1.0,
    );

    switch (activeShot) {
      case ShotType.ultimate:
        final ultType = ball.ultimateType ?? equippedUltimate;
        switch (ultType) {
          case UltimateType.thunderbolt:
            effects.pulseCamera(shake: 0.75, zoom: 0.78);
            ball.lightningFlash = 1.0;
            break;
          case UltimateType.ghostPhantom:
            effects.pulseCamera(shake: 0.40, zoom: 0.85);
            break;
          case UltimateType.dragonMeteor:
            effects.pulseCamera(shake: 0.55, zoom: 0.82);
            break;
          case UltimateType.frostbite:
            effects.pulseCamera(shake: 0.45, zoom: 0.84);
            break;
        }
        break;
      case ShotType.power:
        effects.pulseCamera(shake: 0.35, zoom: 0.90);
        addUltimateCharge(0.18);
        break;
      case ShotType.lob:
        addUltimateCharge(0.15);
        break;
      case ShotType.drop:
        addUltimateCharge(0.15);
        break;
      case ShotType.smash:
        effects.pulseCamera(shake: 0.50, zoom: 0.88);
        addUltimateCharge(0.20);
        break;
      case ShotType.normal:
        addUltimateCharge(0.12);
        break;
    }

    // Rally streak bonus to charge
    if (ball.rallyHitCount > 0 && ball.rallyHitCount % 4 == 0) {
      addUltimateCharge(0.08);
    }

    if (quality.isSweetSpot && activeShot != ShotType.ultimate) {
      effects.pulseCamera(shake: 0.20, zoom: 0.96);
    }
    if (timing.chargeBonus > 0 && activeShot != ShotType.ultimate) {
      addUltimateCharge(timing.chargeBonus);
    }

    final spinBonus = 1.0 + (paddle.spin - 0.50) * 0.35;
    final baseSpin = activeShot == ShotType.drop ? -500.0 : 500.0;

    final appliedSpin = activeShot == ShotType.normal ||
            activeShot == ShotType.power
        ? requestedSpin
        : ShotSpin.flat;
    final physicalSpinStrength = appliedSpin == ShotSpin.flat
        ? 0.0
        : ((0.75 + paddle.spin * 0.50) * timing.spinMultiplier)
            .clamp(0.0, 1.35)
            .toDouble();

    // Compensate for horizontal curve (Magnus effect)
    double lateralCurve = 0;
    if (appliedSpin == ShotSpin.topspin) {
      lateralCurve = 40.0 * physicalSpinStrength;
    } else if (appliedSpin == ShotSpin.slice) {
      lateralCurve = -40.0 * physicalSpinStrength;
    }

    if (lateralCurve != 0) {
       final distZ = true ? -55.0 - ball.position.z : 55.0 - ball.position.z;
       final approxTime = distZ.abs() / math.max(1.0, solution.forwardSpeed);
       final directionSign = solution.launchVelocity.z > 0 ? 1.0 : -1.0;
       final correction = 0.5 * lateralCurve * directionSign * approxTime;
       solution.launchVelocity.x -= correction;
    }

    ball.velocity = solution.launchVelocity;
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = true;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.isServe = false;
    ball.impactFlash = activeShot == ShotType.power ? 1.0 : 0.7;
    ball.shotSpin = appliedSpin;
    ball.spinStrength = physicalSpinStrength;
    ball.spinRate = switch (appliedSpin) {
      ShotSpin.topspin => 720.0 * physicalSpinStrength,
      ShotSpin.slice => -540.0 * physicalSpinStrength,
      ShotSpin.flat => baseSpin * spinBonus,
    };
    ball.shotType = activeShot;
    ball.rallyHitCount++;
    
    if (ai.velocity.x.abs() < 2.0 && ai.velocity.z.abs() < 2.0) {
      ai.splitStepTimer = 0.35;
    }
    ai.hasLungedThisShot = false;
    
    _lastRallyHitter = player;
    _publishContactFeedback(player, timingGrade, playerSlot: 0);
    _publishContactEvent(
      hitter: player,
      playerSlot: 0,
      shotType: activeShot,
      timingGrade: timingGrade,
      spin: appliedSpin,
    );

    final isPowerHit = solution.isPowerHit;
    audioService?.playTimingHit(
      isPower: isPowerHit,
      grade: timingGrade,
    );

    final sparkColor = activeShot == ShotType.ultimate
        ? getUltimateByType(ball.ultimateType ?? equippedUltimate).primaryColor
        : (isPowerHit ? AppColors.power : AppColors.ballColor);
    effects.spawnHitSparks(
      ball.position,
      sparkColor,
      power: activeShot == ShotType.ultimate
          ? 1.0
          : (isPowerHit ? 0.8 : 0.4) +
              (timingGrade == SwingTimingGrade.perfect ? 0.15 : 0),
    );
  }

  void _executeOpponentHit(
    ShotType shotType, {
    ShotSpin requestedSpin = ShotSpin.flat,
    double? timingIntent,
  }) {
    if (gameMode == GameMode.doubles &&
        ball.rallyHitCount == 0 &&
        !identical(activeReceiver, ai)) {
      scoreController.lastFaultDetail = 'WRONG RECEIVER FAULT!';
      _handlePointResult(
        PointResult.wrongReceiverFault,
        playerFaulted: false,
      );
      return;
    }
    if (ball.rallyHitCount < 2 && !ball.hasBounced) {
      _handlePointResult(PointResult.twoBounceFault, playerFaulted: false);
      return;
    }
    if (!ball.hasBounced) {
      if (ai.isInKitchen(includeFootMargin: true)) {
        scoreController.lastFaultDetail = ai.isTouchingKitchenLine()
            ? 'OPPONENT KITCHEN LINE TOUCH!'
            : 'OPPONENT KITCHEN VOLLEY FAULT!';
        _handlePointResult(PointResult.kitchenFault, playerFaulted: false);
        return;
      }
      if (!ai.hasEstablishedOutsideKitchen) {
        scoreController.lastFaultDetail =
            'OPPONENT NVZ FAULT: FEET NOT ESTABLISHED!';
        _handlePointResult(PointResult.kitchenFault, playerFaulted: false);
        return;
      }
      ai.kitchenMomentumFlag = true;
    }

    var activeShot = shotType == ShotType.ultimate
        ? (specialSkillsEnabled ? ShotType.power : ShotType.normal)
        : shotType;
    final timingGrade = gradeSwingTiming(
      timeToIdealContact: timingIntent,
      isSweetSpot: true,
    );
    final timing = timingModifiersFor(timingGrade);
    double forwardSpeed;
    double upSpeed;
    switch (activeShot) {
      case ShotType.power:
        if (!ai.useStamina(StaminaConstants.powerShotCost)) {
          activeShot = ShotType.normal;
        }
        forwardSpeed = activeShot == ShotType.power ? 165 : 130;
        upSpeed = activeShot == ShotType.power ? 38 : 40;
        break;
      case ShotType.lob:
        if (!ai.useStamina(StaminaConstants.lobShotCost)) {
          activeShot = ShotType.normal;
        }
        forwardSpeed = activeShot == ShotType.lob ? 95 : 130;
        upSpeed = activeShot == ShotType.lob ? 68 : 40;
        break;
      case ShotType.drop:
        if (!ai.useStamina(StaminaConstants.dropShotCost)) {
          activeShot = ShotType.normal;
        }
        forwardSpeed = activeShot == ShotType.drop ? 82 : 130;
        upSpeed = activeShot == ShotType.drop ? 36 : 40;
        break;
      case ShotType.smash:
        forwardSpeed = 210;
        upSpeed = 12;
        break;
      case ShotType.normal:
      case ShotType.ultimate:
        forwardSpeed = 130;
        upSpeed = 40;
        break;
    }

    final deepRecoveryFactor =
        ((-ball.position.z - CourtDimensions.playerStartZ) /
                (CourtDimensions.playerMaxZ - CourtDimensions.playerStartZ))
            .clamp(0.0, 1.0)
            .toDouble();
    if (deepRecoveryFactor > 0 && activeShot != ShotType.smash) {
      forwardSpeed *= 1.0 +
          (activeShot == ShotType.lob
                  ? 0.24
                  : (activeShot == ShotType.power ? 0.18 : 0.15)) *
              deepRecoveryFactor;
      upSpeed += (activeShot == ShotType.lob ? 8 : 15) * deepRecoveryFactor;
    }
    forwardSpeed *= timing.speedMultiplier;
    upSpeed += timing.liftAssist;

    final dir = _getOpponentAimDirection();
    final aimDirX = dir.dx.clamp(-0.85, 0.85);
    final targetZ = switch (activeShot) {
      ShotType.drop => 16.0,
      ShotType.smash || ShotType.power => 50.0,
      _ => 55.0,
    };
    final targetX = (aimDirX * CourtDimensions.halfWidth * 0.88).clamp(
      -CourtDimensions.halfWidth + 3,
      CourtDimensions.halfWidth - 3,
    );
    var shotPlan = AIShotPlanner.plan(
      start: ball.position,
      target: Vec3(targetX.toDouble(), PhysicsConstants.ballRadius, targetZ),
      type: activeShot,
      preferredHorizontalSpeed: forwardSpeed,
      preferredVerticalSpeed: upSpeed,
    );
    shotPlan ??= AIShotPlanner.plan(
      start: ball.position,
      target: Vec3(0, PhysicsConstants.ballRadius, 48),
      type: ShotType.normal,
      preferredHorizontalSpeed: 115,
      preferredVerticalSpeed: 42,
    );
    ball.velocity = shotPlan?.launchVelocity ??
        Vec3(
          aimDirX * forwardSpeed,
          upSpeed,
          math.sqrt(math.max(0.05, 1.0 - aimDirX * aimDirX)) * forwardSpeed,
        );
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = false;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.isServe = false;
    ball.impactFlash = activeShot == ShotType.power ? 1.0 : 0.7;
    final paddle = gameplayPaddleFor(ai);
    final appliedSpin = activeShot == ShotType.normal ||
            activeShot == ShotType.power
        ? requestedSpin
        : ShotSpin.flat;
    final physicalSpinStrength = appliedSpin == ShotSpin.flat
        ? 0.0
        : ((0.75 + paddle.spin * 0.50) * timing.spinMultiplier)
            .clamp(0.0, 1.35)
            .toDouble();
    ball.shotSpin = appliedSpin;
    ball.spinStrength = physicalSpinStrength;
    ball.spinRate = switch (appliedSpin) {
      ShotSpin.topspin => 720.0 * physicalSpinStrength,
      ShotSpin.slice => -540.0 * physicalSpinStrength,
      ShotSpin.flat => activeShot == ShotType.drop ? -500 : 500,
    };
    ball.shotType = activeShot;
    ball.rallyHitCount++;
    
    if (player.velocity.x.abs() < 2.0 && player.velocity.z.abs() < 2.0) {
      player.splitStepTimer = 0.35;
    }
    player.hasLungedThisShot = false;

    _lastRallyHitter = ai;
    _publishContactFeedback(ai, timingGrade, playerSlot: 1);
    final isPower =
        activeShot == ShotType.power || activeShot == ShotType.smash;
    _onAIHit(isPower, timingGrade: timingGrade);
  }

  // ── VFX event hooks ────────────────────────────────────────────
  void _onAIHit(
    bool isPower, {
    SwingTimingGrade timingGrade = SwingTimingGrade.good,
  }) {
    final hitter = _lastRallyHitter ?? ai;
    _publishContactEvent(
      hitter: hitter,
      playerSlot: identical(hitter, playerPartner)
          ? 2
          : identical(hitter, aiPartner)
              ? 3
              : identical(hitter, player)
                  ? 0
                  : 1,
      shotType: ball.shotType,
      timingGrade: timingGrade,
      spin: ball.shotSpin,
    );
    audioService?.playTimingHit(isPower: isPower, grade: timingGrade);
    effects.spawnHitSparks(
      ball.position,
      isPower ? AppColors.power : AppColors.ballColor,
      power: isPower ? 0.8 : 0.4,
      dirZ: ball.velocity.z >= 0 ? 1.0 : -1.0,
    );
  }

  void _onBallBounce() {
    _recordEvent((revision) => MatchEvent(
          type: MatchEventType.bounce,
          revision: revision,
          elapsedSeconds: matchStats.elapsedSeconds,
          nearTeam: ball.playerSideBounce,
          position: ball.position.copy(),
          rallyPhase: rallyPhase,
          rallyHits: ball.rallyHitCount,
        ));
    final theme = settings.courtTheme;
    final dust = Color.lerp(theme.surfaceColorLight, Colors.white, 0.55)!;
    final intensity = (ball.speed / 140.0).clamp(0.0, 1.0);
    effects.spawnBounce(ball.position, dust, intensity);
  }

  Offset _getAimDirection() {
    final timingDx = calculateContactTimingOffset(
      player: player,
      ball: ball,
      isNearSide: true,
    );
    return calculatePlayerAimDirection(
      swipeDirection: swipeDirection,
      joystickX: joystickX,
      joystickY: joystickY,
      timingOffsetDx: timingDx,
      contactX: ball.position.x,
      isNearSide: true,
    );
  }

  Offset _getOpponentAimDirection() {
    final timingDx = calculateContactTimingOffset(
      player: ai,
      ball: ball,
      isNearSide: false,
    );
    return calculatePlayerAimDirection(
      swipeDirection: opponentSwipeDirection,
      joystickX: opponentJoystickX,
      joystickY: opponentJoystickY,
      timingOffsetDx: timingDx,
      contactX: ball.position.x,
      isNearSide: false,
    );
  }

  // ── State: Point scored ─────────────────────────────────────────
  void _handlePointResult(
    PointResult result, {
    bool? playerFaulted,
  }) {
    bool awardPlayerRally() {
      final scored = scoreController.awardPlayerPoint();
      playerScoreAnim = !isPracticeMode && scored;
      aiScoreAnim = false;
      return scored;
    }

    bool awardAIRally() {
      final scored = scoreController.awardAIPoint();
      aiScoreAnim = !isPracticeMode && scored;
      playerScoreAnim = false;
      return scored;
    }

    String rallyMessage(bool scored, String fallback) {
      if (isPracticeMode) return fallback;
      if (scoreController.lastFaultDetail.isNotEmpty) {
        return scored
            ? scoreController.lastFaultDetail
            : '${scoreController.lastFaultDetail}  •  SIDE OUT';
      }
      return scored
          ? fallback
          : (fallback.isNotEmpty ? '$fallback  •  SIDE OUT' : 'SIDE OUT!');
    }

    String msg = '';
    switch (result) {
      case PointResult.playerPoint:
        final scored = awardPlayerRally();
        msg = rallyMessage(scored, isPracticeMode ? 'GREAT SHOT!' : 'POINT!');
        if (!isPracticeMode) addUltimateCharge(0.25);
        break;
      case PointResult.aiPoint:
        final scored = awardAIRally();
        msg = rallyMessage(scored, 'POINT!');
        break;
      case PointResult.netFault:
      case PointResult.serviceFault:
        final faultByPlayer = ball.lastHitByPlayer;
        final scored = faultByPlayer ? awardAIRally() : awardPlayerRally();
        final fallback =
            result == PointResult.netFault ? 'NET FAULT!' : 'SERVICE FAULT!';
        msg = rallyMessage(scored, fallback);
        break;
      case PointResult.kitchenFault:
      case PointResult.twoBounceFault:
      case PointResult.wrongReceiverFault:
        final faultByPlayer = playerFaulted ?? ball.lastHitByPlayer;
        final scored = faultByPlayer ? awardAIRally() : awardPlayerRally();
        final fallback = result == PointResult.kitchenFault
            ? 'KITCHEN VIOLATION!'
            : (result == PointResult.wrongReceiverFault
                ? 'WRONG RECEIVER!'
                : 'TWO-BOUNCE FAULT!');
        msg = rallyMessage(scored, fallback);
        break;
      case PointResult.doubleBounceFault:
        final scored =
            ball.playerSideBounce ? awardAIRally() : awardPlayerRally();
        msg = rallyMessage(scored, 'DOUBLE BOUNCE!');
        break;
      case PointResult.none:
        return;
    }

    final detail = scoreController.lastFaultDetail.toUpperCase();
    final isExplicitFault = result != PointResult.playerPoint &&
        result != PointResult.aiPoint &&
        result != PointResult.none;
    _recordEvent((revision) => MatchEvent(
          type: MatchEventType.pointResult,
          revision: revision,
          elapsedSeconds: matchStats.elapsedSeconds,
          nearTeam: result == PointResult.playerPoint,
          result: result.name,
          rallyPhase: rallyPhase,
          rallyHits: ball.rallyHitCount,
          isFault: isExplicitFault || detail.contains('FAULT'),
          isWinner: detail.contains('WINNER'),
        ));

    lastMessage = msg;
    messageTimer = isPracticeMode ? 1.4 : 2.2;
    ball.state = BallState.dead;

    // Reset transient ultimate buffs / zones
    ball.isUltimate = false;
    ball.ghostClones1.clear();
    ball.ghostClones2.clear();
    ball.iceZoneCenter = null;
    ball.iceZoneTimer = 0;
    ai.speedMultiplier = 1.0;
    timeDilation = 1.0;
    slowMoTimer = 0;
    isUltimateArmed = false;

    // If point resulted directly from a kitchen fault, clear momentum flags now.
    // Otherwise, retain momentum flags so that if striker's momentum carries them
    // into the kitchen after the ball became dead, it faults per Rule 9.B.
    if (result == PointResult.kitchenFault) {
      player.kitchenMomentumFlag = false;
      playerPartner?.kitchenMomentumFlag = false;
      ai.kitchenMomentumFlag = false;
      aiPartner?.kitchenMomentumFlag = false;
    }

    // Always enter dead-ball adjudication first. A game-winning volley can
    // still be overturned if the striker's momentum carries into the NVZ.
    state = GameState.pointScored;
    stateTimer = 0;
  }

  // ── State: Point scored (delay then reset) ─────────────────────
  void _updatePointScored(double dt) {
    // Continue updating player deceleration during dead ball / point scored
    playerController.updateMovement(
      dt,
      0,
      0,
      speedMultiplier: gameplayMoveSpeedMultiplier,
    );
    player.clampToCourt();
    player.updateKitchenStatus(dt);
    playerPartner?.updateKitchenStatus(dt);
    ai.updateKitchenStatus(dt);
    aiPartner?.updateKitchenStatus(dt);

    // USA Pickleball Rule 9.B: Momentum carrying into NVZ AFTER rally ended is a fault!
    // Even if you hit the ball while standing outside, it is still a fault if your momentum
    // makes you step into or touch the Kitchen afterward. This applies even if the rally has already ended.
    final playerTeamMomentumOffender = player.kitchenMomentumFlag &&
            player.isInKitchen(includeFootMargin: true)
        ? player
        : (playerPartner?.kitchenMomentumFlag == true &&
                playerPartner!.isInKitchen(includeFootMargin: true)
            ? playerPartner
            : null);
    final aiTeamMomentumOffender =
        ai.kitchenMomentumFlag && ai.isInKitchen(includeFootMargin: true)
            ? ai
            : (aiPartner?.kitchenMomentumFlag == true &&
                    aiPartner!.isInKitchen(includeFootMargin: true)
                ? aiPartner
                : null);
    if (playerTeamMomentumOffender != null) {
      playerTeamMomentumOffender.kitchenMomentumFlag = false;
      final previousPlayerScore = player.score;
      final previousAIScore = ai.score;
      scoreController.overturnPointForKitchenFault(playerFaulted: true);
      lastMessage = 'NVZ MOMENTUM FAULT (POINT OVERTURNED)!';
      messageTimer = 2.5;
      playerScoreAnim = player.score > previousPlayerScore;
      aiScoreAnim = ai.score > previousAIScore;
      audioService?.playNetHit();
    } else if (aiTeamMomentumOffender != null) {
      aiTeamMomentumOffender.kitchenMomentumFlag = false;
      final previousPlayerScore = player.score;
      final previousAIScore = ai.score;
      scoreController.overturnPointForKitchenFault(playerFaulted: false);
      lastMessage = 'OPPONENT NVZ MOMENTUM FAULT (POINT AWARDED)!';
      messageTimer = 2.5;
      playerScoreAnim = player.score > previousPlayerScore;
      aiScoreAnim = ai.score > previousAIScore;
      audioService?.playBounce();
    }

    // Do not finalize a winning score until any active volley momentum has
    // either resolved safely or produced an NVZ fault.
    final momentumPending = player.kitchenMomentumFlag ||
        (playerPartner?.kitchenMomentumFlag ?? false) ||
        ai.kitchenMomentumFlag ||
        (aiPartner?.kitchenMomentumFlag ?? false);
    if (scoreController.isGameOver &&
        (!momentumPending || stateTimer >= 0.75)) {
      state = GameState.gameOver;
      stateTimer = 0;
      if (!_matchEndPublished) {
        _matchEndPublished = true;
        _recordEvent((revision) => MatchEvent(
              type: MatchEventType.matchEnded,
              revision: revision,
              elapsedSeconds: matchStats.elapsedSeconds,
              nearTeam: player.score > ai.score,
              result: player.score > ai.score ? 'playerWin' : 'opponentWin',
              rallyHits: ball.rallyHitCount,
            ));
      }
      return;
    }

    final resetDelay = isPracticeMode ? 1.0 : 2.0;
    if (stateTimer > resetDelay) {
      // Reset for next point
      playerScoreAnim = false;
      aiScoreAnim = false;
      _setupServePositions();
      state = GameState.waitingForServe;
      stateTimer = 0;
    }
  }

  // ── Pause / Resume ─────────────────────────────────────────────
  void pause() {
    if (state != GameState.gameOver && state != GameState.paused) {
      _stateBeforePause = state;
      state = GameState.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (state == GameState.paused) {
      state = _stateBeforePause;
      notifyListeners();
    }
  }

  void restartMatch() {
    player.score = 0;
    ai.score = 0;
    scoreController.reset();
    _setupServePositions();
    state = GameState.waitingForServe;
    stateTimer = 0;
    lastMessage = '';
    messageTimer = 0;
    ultimateCharge = 0.45;
    isUltimateArmed = false;
    ultimateCutinTimer = 0;
    timeDilation = 1.0;
    slowMoTimer = 0;
    matchStats.reset();
    rallyPhase = RallyPhase.opening;
    _matchEndPublished = false;
    ai.speedMultiplier = 1.0;
    effects.clear();
    notifyListeners();
  }

  // ── Input setters ──────────────────────────────────────────────
  void setJoystick(double x, double y) {
    joystickX = x;
    joystickY = y;
  }

  void setOpponentJoystick(double x, double y) {
    opponentJoystickX = x;
    opponentJoystickY = y;
  }

  /// Advances only the locally controlled avatar for network-side prediction.
  /// Host snapshots remain authoritative for all match state.
  void predictNetworkPlayer(double dt, {required int playerSlot}) {
    if (isPaused || state == GameState.gameOver) return;
    if (playerSlot == 1) {
      if (state == GameState.waitingForServe && isOpponentHumanServing) {
        _updateOpponentServePosition(dt);
      } else {
        opponentPlayerController.updateMovement(
          dt,
          opponentJoystickX,
          -opponentJoystickY,
        );
        ai.clampToCourt();
      }
      return;
    }
    if (state == GameState.waitingForServe && identical(activeServer, player)) {
      _updatePlayerServePosition(dt);
    } else {
      playerController.updateMovement(dt, joystickX, joystickY);
      player.clampToCourt();
    }
  }

  double? captureSwingTimingIntent({required int playerSlot}) {
    final hitter = playerSlot == 1 ? ai : player;
    final forwardSign = hitter.isNearSide ? -1.0 : 1.0;
    final idealContactZ = hitter.position.z + forwardSign * 3.5;
    final relativeVelocityZ = ball.velocity.z - hitter.velocity.z;
    if (!relativeVelocityZ.isFinite || relativeVelocityZ.abs() < 2.0) {
      return null;
    }
    return ((idealContactZ - ball.position.z) / relativeVelocityZ)
        .clamp(-0.35, 0.60)
        .toDouble();
  }

  void _publishContactFeedback(
    Player hitter,
    SwingTimingGrade grade, {
    required int playerSlot,
  }) {
    contactFeedbackRevision++;
    contactFeedback = ContactFeedback(
      grade: grade,
      position:
          Vec3(hitter.position.x, hitter.position.y + 28, hitter.position.z),
      playerSlot: playerSlot,
      revision: contactFeedbackRevision,
      remaining: 0.65,
    );
  }

  void applySyncedContactFeedback(ContactFeedback feedback) {
    if (feedback.revision < contactFeedbackRevision) return;
    contactFeedbackRevision = feedback.revision;
    contactFeedback = feedback;
  }

  void applySyncedFoundation({
    required RallyPhase phase,
    required int eventRevision,
    Map<String, dynamic>? stats,
  }) {
    rallyPhase = phase;
    matchEvents.adoptRevision(eventRevision);
    if (stats != null) matchStats.applyJson(stats);
  }

  void _refreshRallyPhase() {
    _setRallyPhase(RallyPhaseClassifier.classify(
      ball: ball,
      nearTeam: [player, if (playerPartner != null) playerPartner!],
      farTeam: [ai, if (aiPartner != null) aiPartner!],
    ));
  }

  void _setRallyPhase(RallyPhase next) {
    if (rallyPhase == next) return;
    rallyPhase = next;
    _recordEvent((revision) => MatchEvent(
          type: MatchEventType.rallyPhaseChanged,
          revision: revision,
          elapsedSeconds: matchStats.elapsedSeconds,
          rallyPhase: next,
          position: ball.position.copy(),
          rallyHits: ball.rallyHitCount,
        ));
    if (next == RallyPhase.attackable) {
      _recordEvent((revision) => MatchEvent(
            type: MatchEventType.attackableBall,
            revision: revision,
            elapsedSeconds: matchStats.elapsedSeconds,
            nearTeam: !ball.lastHitByPlayer,
            rallyPhase: next,
            position: ball.position.copy(),
            rallyHits: ball.rallyHitCount,
          ));
    }
  }

  void _publishContactEvent({
    required Player hitter,
    required int playerSlot,
    required ShotType shotType,
    required SwingTimingGrade timingGrade,
    required ShotSpin spin,
  }) {
    _recordEvent((revision) => MatchEvent(
          type: MatchEventType.contact,
          revision: revision,
          elapsedSeconds: matchStats.elapsedSeconds,
          playerSlot: playerSlot,
          nearTeam: hitter.isNearSide,
          position: hitter.position.copy(),
          shotType: shotType,
          timingGrade: timingGrade,
          spin: spin,
          rallyPhase: rallyPhase,
          rallyHits: ball.rallyHitCount,
        ));
  }

  void _recordEvent(MatchEvent Function(int revision) create) {
    matchEvents.publish(create, beforeEmit: matchStats.record);
  }

  void queueOpponentShot(
    ShotType type, {
    ShotSpin spin = ShotSpin.flat,
    double? timingIntent,
  }) {
    if (!isLocalMultiplayer) return;
    opponentBufferedShot = type;
    opponentBufferedSpin = spin;
    opponentBufferedTimingIntent = timingIntent;
    opponentSwingBufferTimer = 0.35;
  }

  void queueShot(
    ShotType type, {
    ShotSpin spin = ShotSpin.flat,
    double? timingIntent,
  }) {
    bufferedShot = type;
    bufferedSpin = spin;
    bufferedTimingIntent = timingIntent;
    swingBufferTimer = 0.35;
  }

  void setHitPressed(
    bool v, {
    ShotSpin spin = ShotSpin.flat,
    double? timingIntent,
  }) {
    if (v) queueShot(ShotType.normal, spin: spin, timingIntent: timingIntent);
    hitPressed = v;
  }

  void setPowerPressed(
    bool v, {
    ShotSpin spin = ShotSpin.flat,
    double? timingIntent,
  }) {
    if (v) queueShot(ShotType.power, spin: spin, timingIntent: timingIntent);
    powerPressed = v;
  }

  void setLobPressed(bool v, {double? timingIntent}) {
    if (v) queueShot(ShotType.lob, timingIntent: timingIntent);
    lobPressed = v;
  }

  void setDropPressed(bool v, {double? timingIntent}) {
    if (v) queueShot(ShotType.drop, timingIntent: timingIntent);
    dropPressed = v;
  }

  void setServePressed(bool v) => servePressed = v;
  void setSwipe(Offset? dir) => swipeDirection = dir;
  void setOpponentServePressed(bool v) => opponentServePressed = v;
  void setOpponentSwipe(Offset? dir) => opponentSwipeDirection = dir;

  void setUltimatePressed(bool v) {
    ultimatePressed = v;
    if (v && isUltimateReady) {
      isUltimateArmed = true;
      queueShot(ShotType.ultimate);
      notifyListeners();
    }
  }

  void toggleArmUltimate() {
    if (isUltimateReady) {
      isUltimateArmed = !isUltimateArmed;
      if (isUltimateArmed) {
        queueShot(ShotType.ultimate);
      }
      notifyListeners();
    }
  }

  // ── Getters ────────────────────────────────────────────────────
  bool get isGameOver => state == GameState.gameOver;
  bool get isPaused => state == GameState.paused;
  bool get playerWon => player.score > ai.score && isGameOver;

  @override
  void dispose() {
    matchEvents.dispose();
    super.dispose();
  }
}

// Extend Offset with normalize helper
extension OffsetExt on Offset {
  Offset normalize() {
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return const Offset(0, -1);
    return Offset(dx / len, dy / len);
  }
}
