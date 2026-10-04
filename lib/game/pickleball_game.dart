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
import '../game/score_controller.dart';
import '../game/ball_controller.dart';
import '../game/player_controller.dart';
import '../game/ai_controller.dart';
import '../game/camera_controller.dart';
import '../game/physics_controller.dart';
import '../game/vfx.dart';
import '../game/shot_targeting.dart';
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

class PickleballGame extends ChangeNotifier {
  // ── Mode ─────────────────────────────────────────────────────
  final GameMode gameMode;
  final bool isLocalMultiplayer;

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
  late CameraController cameraController;
  late PhysicsController physicsController;
  late ScoreController scoreController;

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

  // ── Camera ───────────────────────────────────────────────────
  late PerspectiveCamera camera;
  Size screenSize;

  // ── State ────────────────────────────────────────────────────
  GameState state;
  GameState _stateBeforePause = GameState.waitingForServe;
  bool isPracticeMode;
  double stateTimer;        // time elapsed in current state
  double animTime = 0;      // visual animation pulse timer
  String lastMessage;       // e.g. "KITCHEN FAULT!", "TWO-BOUNCE FAULT", "OUT!"
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
  double opponentJoystickX = 0;
  double opponentJoystickY = 0;
  bool opponentServePressed = false;
  Offset? opponentSwipeDirection;
  double opponentSwingBufferTimer = 0;
  ShotType? opponentBufferedShot;

  // ── Ultimate Skill System ─────────────────────────────────────
  double ultimateCharge = 0.45; // 0.0 .. 1.0
  bool isUltimateArmed = false;
  double ultimateCutinTimer = 0.0;
  UltimateType? activeCutinUltimate;
  double timeDilation = 1.0;
  double slowMoTimer = 0.0;

  UltimateType get equippedUltimate => settings.equippedUltimate;
  UltimateSkill get currentUltimate => getUltimateByType(equippedUltimate);
  bool get isUltimateReady => ultimateCharge >= 1.0;

  void addUltimateCharge(double amount) {
    final oldVal = ultimateCharge;
    ultimateCharge = (ultimateCharge + amount).clamp(0.0, 1.0);
    if (oldVal < 1.0 && ultimateCharge >= 1.0) {
      notifyListeners();
    }
  }

  // ── Visual effects ────────────────────────────────────────────
  final VfxSystem vfx = VfxSystem();
  double cameraZoom;        // 1.0 = normal, <1 = zoomed in slightly
  double screenShake;       // 0..1

  // ── Score animation ───────────────────────────────────────────
  bool playerScoreAnim = false;
  bool aiScoreAnim = false;

  final GameSettings settings;
  PaddleItem get currentPaddle => getPaddleById(settings.equippedPaddleId);
  PlayerSkinItem get currentPlayerSkin =>
      getPlayerSkinById(settings.equippedPlayerId);

  final String? drillType;
  final AudioService? audioService;
  final AIDifficulty? difficultyOverride;

  AIDifficulty get currentAIDifficulty => difficultyOverride ?? settings.difficulty;

  PickleballGame({
    required this.screenSize,
    this.isPracticeMode = false,
    this.drillType,
    this.gameMode = GameMode.singles,
    this.isLocalMultiplayer = false,
    required this.settings,
    this.difficultyOverride,
    this.audioService,
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
        messageTimer = 0,
        cameraZoom = 1.0,
        screenShake = 0 {
    // Camera starts behind player, looking toward net
    camera = PerspectiveCamera(
      position: Vec3(
        0,
        CameraConstants.cameraHeight,
        CourtDimensions.playerStartZ + CameraConstants.cameraDistanceBehind,
      ),
      target: Vec3(0, 0, 0),
      screenSize: screenSize,
    );

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
      onHit: _onAIHit,
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
        onHit: _onAIHit,
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
        onHit: _onAIHit,
      );
    }

    cameraController = CameraController(
        camera: camera, player: player, ball: ball);
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

    // Bullet-time slow motion & cinematic cut-in decay
    if (slowMoTimer > 0) {
      slowMoTimer -= dt;
      if (slowMoTimer <= 0) timeDilation = 1.0;
    }
    if (ultimateCutinTimer > 0) {
      ultimateCutinTimer -= dt;
    }

    stateTimer += dt;
    animTime += dt;

    // Tick message timer
    if (messageTimer > 0) {
      messageTimer -= dt;
      if (messageTimer <= 0) lastMessage = '';
    }

    // Tick swing buffer timer
    if (swingBufferTimer > 0) {
      swingBufferTimer -= dt;
      if (swingBufferTimer <= 0) bufferedShot = null;
    }
    if (opponentSwingBufferTimer > 0) {
      opponentSwingBufferTimer -= dt;
      if (opponentSwingBufferTimer <= 0) opponentBufferedShot = null;
    }

    // Stamina regeneration
    player.regenStamina(dt * currentPlayerSkin.staminaRegenMultiplier);
    ai.regenStamina(dt);
    playerPartner?.regenStamina(dt);

    // Decay screen shake
    if (screenShake > 0) {
      screenShake = math.max(0, screenShake - dt * 3);
    }

    // World-space particles & court marks (follow bullet-time during rallies)
    vfx.enabled = settings.showParticles;
    vfx.update(state == GameState.rally ? dt * timeDilation : dt);

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

    // Update camera
    cameraController.update(dt, cameraZoom);

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
      playerPartner?.assignedRightSide =
          !scoreController.playerPrimaryOnRight;
      ai.assignedRightSide = scoreController.aiPrimaryOnRight;
      aiPartner?.assignedRightSide = !scoreController.aiPrimaryOnRight;
    } else {
      player.assignedRightSide = serverRight;
      ai.assignedRightSide = serverRight;
    }
    aiController.resetForRally();
    partnerController?.resetForRally();
    aiPartnerController?.resetForRally();

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
    vfx.spawnHitSparks(ball.position, AppColors.ballColor, power: 0.2);
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

    final targetX = (baseTargetX + (rng.nextDouble() - 0.5) * (diff == AIDifficulty.hard ? 2.5 : 5.0)).clamp(
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
    vfx.spawnHitSparks(ball.position, AppColors.ballColor,
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
    vfx.spawnHitSparks(ball.position, AppColors.ballColor, power: 0.2);
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
      speedMultiplier: currentPlayerSkin.speedMultiplier,
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
    final playerTeamMomentumOffender =
        player.kitchenMomentumFlag && player.isInKitchen(includeFootMargin: true)
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
        queueShot(ShotType.ultimate);
      }
      ultimatePressed = false;
    } else if (powerPressed) {
      queueShot(ShotType.power);
      powerPressed = false;
    } else if (lobPressed) {
      queueShot(ShotType.lob);
      lobPressed = false;
    } else if (dropPressed) {
      queueShot(ShotType.drop);
      dropPressed = false;
    } else if (hitPressed) {
      queueShot(ShotType.normal);
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
      ai.animState = ai.isForehand
          ? PlayerAnimState.forehand
          : PlayerAnimState.backhand;
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
      final hitRadius = 30.0 + (currentPaddle.control - 0.50) * 12.0;
      if (distToBall < hitRadius &&
          ball.position.y < 42 &&
          ball.position.z > -8) {
        _executePlayerHit(bufferedShot ??
            (isUltimateArmed ? ShotType.ultimate : ShotType.normal));
        bufferedShot = null;
        swingBufferTimer = 0;
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
      if (distToBall < 30 && ball.position.y < 42 && ball.position.z < 8) {
        _executeOpponentHit(opponentBufferedShot ?? ShotType.normal);
        opponentBufferedShot = null;
        opponentSwingBufferTimer = 0;
      }
    }

    // Update player animation
    playerController.updateAnimation(dt);
    if (isLocalMultiplayer) opponentPlayerController.updateAnimation(dt);

    // Update AI controllers
    if (!isLocalMultiplayer) aiController.update(effectiveDt);
    partnerController?.update(effectiveDt);
    aiPartnerController?.update(effectiveDt);

    // Physics: paddle collisions
    final collision = physicsController.update(dt);
    if (collision.playerHit) {
      screenShake = 0.3;
      cameraZoom = 0.95;
      audioService?.playHit(isPower: collision.powerHit);
    }
    if (collision.aiHit) {
      audioService?.playHit(isPower: collision.powerHit);
    }
    if (collision.netHit) {
      audioService?.playNetHit();
      vfx.spawnNetPuff(ball.position);
    }
    if (collision.powerHit) {
      cameraZoom = 0.90;
    }

    // Camera zoom recovery
    if (cameraZoom < 1.0) {
      cameraZoom = math.min(1.0, cameraZoom + dt * 1.5);
    }

    // Check scoring & rule conditions
    final pointResult = scoreController.checkPoint(ball, court);
    if (pointResult != PointResult.none) {
      _handlePointResult(pointResult);
    }
  }

  void _executePlayerHit(ShotType shotType) {
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
        scoreController.lastFaultDetail = 'NVZ FAULT: FEET NOT ESTABLISHED OUTSIDE!';
        _handlePointResult(PointResult.kitchenFault, playerFaulted: true);
        return;
      }

      // Arm kitchen momentum flag when striking a legal volley outside the kitchen
      player.kitchenMomentumFlag = true;
    }

    final paddle = currentPaddle;
    final staminaDiscount =
        (1.0 - (paddle.staminaEfficiency - 0.50) * 0.35).clamp(0.65, 1.0);

    // ── Check if executing Ultimate ────────────────────────────
    final isExecutingUltimate =
        isUltimateArmed || shotType == ShotType.ultimate;
    ShotType activeShot = shotType;

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
      // Stamina check for non-ultimate shots
      if (activeShot == ShotType.power &&
          !player.useStamina(StaminaConstants.powerShotCost * staminaDiscount)) {
        activeShot = ShotType.normal;
      } else if (activeShot == ShotType.lob &&
          !player.useStamina(StaminaConstants.lobShotCost * staminaDiscount)) {
        activeShot = ShotType.normal;
      } else if (activeShot == ShotType.drop &&
          !player.useStamina(StaminaConstants.dropShotCost * staminaDiscount)) {
        activeShot = ShotType.normal;
      }
    }

    final dir = _getAimDirection();
    double forwardSpeed;
    double upSpeed;

    switch (activeShot) {
      case ShotType.ultimate:
        final ultType = ball.ultimateType ?? equippedUltimate;
        switch (ultType) {
          case UltimateType.thunderbolt:
            forwardSpeed = 245.0;
            upSpeed = 26.0;
            screenShake = 0.75;
            cameraZoom = 0.78;
            ball.lightningFlash = 1.0;
            break;
          case UltimateType.ghostPhantom:
            forwardSpeed = 155.0;
            upSpeed = 40.0;
            screenShake = 0.40;
            cameraZoom = 0.85;
            break;
          case UltimateType.dragonMeteor:
            forwardSpeed = 135.0;
            upSpeed = 55.0;
            screenShake = 0.55;
            cameraZoom = 0.82;
            break;
          case UltimateType.frostbite:
            forwardSpeed = 175.0;
            upSpeed = 34.0;
            screenShake = 0.45;
            cameraZoom = 0.84;
            break;
        }
        break;
      case ShotType.power:
        forwardSpeed = 165.0;
        upSpeed = 38.0;
        screenShake = 0.35;
        cameraZoom = 0.90;
        addUltimateCharge(0.18);
        break;
      case ShotType.lob:
        forwardSpeed = 95.0;
        upSpeed = 68.0;
        addUltimateCharge(0.15);
        break;
      case ShotType.drop:
        forwardSpeed = 82.0;
        upSpeed = 36.0;
        addUltimateCharge(0.15);
        break;
      case ShotType.smash:
        // Overhead smash: fast drive with controlled elevation
        forwardSpeed = 210.0;
        upSpeed = 12.0;
        screenShake = 0.50;
        cameraZoom = 0.88;
        addUltimateCharge(0.20);
        break;
      case ShotType.normal:
        forwardSpeed = 130.0;
        upSpeed = 40.0;
        addUltimateCharge(0.12);
        break;
    }

    // Rally streak bonus to charge
    if (ball.rallyHitCount > 0 && ball.rallyHitCount % 4 == 0) {
      addUltimateCharge(0.08);
    }

    // Apply paddle power bonus (+0% to +12% speed)
    final powerBonus = 1.0 + (paddle.power - 0.50) * 0.25;
    forwardSpeed *= powerBonus;

    // Reward difficult contacts near the back line with additional depth.
    // The assist fades to zero at the normal starting position.
    final deepRecoveryFactor = ((ball.position.z -
                CourtDimensions.playerStartZ) /
            (CourtDimensions.playerMaxZ - CourtDimensions.playerStartZ))
        .clamp(0.0, 1.0)
        .toDouble();
    if (deepRecoveryFactor > 0 &&
        activeShot != ShotType.smash &&
        activeShot != ShotType.ultimate) {
      final forwardBoost = activeShot == ShotType.lob
          ? 0.24
          : (activeShot == ShotType.power ? 0.18 : 0.15);
      forwardSpeed *= 1.0 + forwardBoost * deepRecoveryFactor;
      final liftBoost = activeShot == ShotType.lob
          ? 8.0
          : (activeShot == ShotType.power ? 18.0 : 15.0);
      upSpeed += liftBoost * deepRecoveryFactor;
    }

    final spinBonus = 1.0 + (paddle.spin - 0.50) * 0.35;
    final baseSpin = activeShot == ShotType.drop ? -500.0 : 500.0;

    // Compute directional unit vector with normalized horizontal speed
    final aimDirX = dir.dx.clamp(-0.85, 0.85);
    final aimDirZ = -math.sqrt(math.max(0.05, 1.0 - aimDirX * aimDirX));
    if (deepRecoveryFactor > 0 &&
        activeShot != ShotType.smash &&
        activeShot != ShotType.ultimate) {
      final assistedForwardZ =
          math.max(1.0, aimDirZ.abs() * forwardSpeed * 0.88);
      final timeToNet = ball.position.z / assistedForwardZ;
      final targetNetHeight = CourtDimensions.netHeight +
          PhysicsConstants.ballRadius +
          4.0;
      final minimumUpSpeed = (targetNetHeight -
                  ball.position.y +
                  0.5 * PhysicsConstants.gravity * timeToNet * timeToNet) /
              timeToNet +
          4.0 * deepRecoveryFactor;
      upSpeed = math.max(
        upSpeed,
        minimumUpSpeed.clamp(0.0, 82.0).toDouble(),
      );
    }
    ball.velocity = Vec3(
      aimDirX * forwardSpeed,
      upSpeed,
      aimDirZ * forwardSpeed,
    );
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = true;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.isServe = false;
    ball.impactFlash = activeShot == ShotType.power ? 1.0 : 0.7;
    ball.spinRate = baseSpin * spinBonus;
    ball.shotType = activeShot;
    ball.rallyHitCount++;

    final isPowerHit = activeShot == ShotType.power ||
        activeShot == ShotType.smash ||
        activeShot == ShotType.ultimate;
    audioService?.playHit(isPower: isPowerHit);

    final sparkColor = activeShot == ShotType.ultimate
        ? getUltimateByType(ball.ultimateType ?? equippedUltimate).primaryColor
        : (isPowerHit ? AppColors.power : AppColors.ballColor);
    vfx.spawnHitSparks(
      ball.position,
      sparkColor,
      power: activeShot == ShotType.ultimate ? 1.0 : (isPowerHit ? 0.8 : 0.4),
    );
  }

  void _executeOpponentHit(ShotType shotType) {
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

    var activeShot = shotType == ShotType.ultimate ? ShotType.power : shotType;
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

    final deepRecoveryFactor = ((-ball.position.z -
                CourtDimensions.playerStartZ) /
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

    final dir = _getOpponentAimDirection();
    final aimDirX = dir.dx.clamp(-0.85, 0.85);
    final aimDirZ = math.sqrt(math.max(0.05, 1.0 - aimDirX * aimDirX));
    ball.velocity = Vec3(
      aimDirX * forwardSpeed,
      upSpeed,
      aimDirZ * forwardSpeed,
    );
    ball.state = BallState.inFlight;
    ball.lastHitByPlayer = false;
    ball.bounceCount = 0;
    ball.secondBounceGraceTimer = 0;
    ball.hasBounced = false;
    ball.isServe = false;
    ball.impactFlash = activeShot == ShotType.power ? 1.0 : 0.7;
    ball.spinRate = activeShot == ShotType.drop ? -500 : 500;
    ball.shotType = activeShot;
    ball.rallyHitCount++;
    final isPower = activeShot == ShotType.power || activeShot == ShotType.smash;
    _onAIHit(isPower);
  }

  // ── VFX event hooks ────────────────────────────────────────────
  void _onAIHit(bool isPower) {
    audioService?.playHit(isPower: isPower);
    vfx.spawnHitSparks(
      ball.position,
      isPower ? AppColors.power : AppColors.ballColor,
      power: isPower ? 0.8 : 0.4,
      dirZ: ball.velocity.z >= 0 ? 1.0 : -1.0,
    );
  }

  void _onBallBounce() {
    final theme = settings.courtTheme;
    final dust = Color.lerp(theme.surfaceColorLight, Colors.white, 0.55)!;
    final intensity = (ball.speed / 140.0).clamp(0.0, 1.0);
    vfx.spawnBounce(ball.position, dust, intensity);
  }

  Offset _getAimDirection() {
    final proposed = swipeDirection ?? Offset(joystickX * 0.6, -1);
    return ShotTargeting.constrainReturnDirection(proposed, ball.position.x);
  }

  Offset _getOpponentAimDirection() {
    final proposed = opponentSwipeDirection ?? Offset(opponentJoystickX * 0.6, 1);
    final constrained = ShotTargeting.constrainReturnDirection(
      Offset(proposed.dx, -1),
      ball.position.x,
    );
    return Offset(constrained.dx, 1);
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
      return scored ? fallback : 'SIDE OUT!';
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
        final fallback = result == PointResult.netFault
            ? 'NET FAULT!'
            : 'SERVICE FAULT!';
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
        final scored = ball.playerSideBounce
            ? awardAIRally()
            : awardPlayerRally();
        msg = rallyMessage(scored, 'DOUBLE BOUNCE!');
        break;
      case PointResult.none:
        return;
    }

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
      speedMultiplier: currentPlayerSkin.speedMultiplier,
    );
    player.clampToCourt();
    player.updateKitchenStatus(dt);
    playerPartner?.updateKitchenStatus(dt);
    ai.updateKitchenStatus(dt);
    aiPartner?.updateKitchenStatus(dt);

    // USA Pickleball Rule 9.B: Momentum carrying into NVZ AFTER rally ended is a fault!
    // Even if you hit the ball while standing outside, it is still a fault if your momentum
    // makes you step into or touch the Kitchen afterward. This applies even if the rally has already ended.
    final playerTeamMomentumOffender =
        player.kitchenMomentumFlag && player.isInKitchen(includeFootMargin: true)
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
    ai.speedMultiplier = 1.0;
    vfx.clear();
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

  void queueOpponentShot(ShotType type) {
    if (!isLocalMultiplayer) return;
    opponentBufferedShot = type;
    opponentSwingBufferTimer = 0.35;
  }

  void queueShot(ShotType type) {
    bufferedShot = type;
    swingBufferTimer = 0.35;
  }

  void setHitPressed(bool v) {
    if (v) queueShot(ShotType.normal);
    hitPressed = v;
  }

  void setPowerPressed(bool v) {
    if (v) queueShot(ShotType.power);
    powerPressed = v;
  }

  void setLobPressed(bool v) {
    if (v) queueShot(ShotType.lob);
    lobPressed = v;
  }

  void setDropPressed(bool v) {
    if (v) queueShot(ShotType.drop);
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
}

// Extend Offset with normalize helper
extension OffsetExt on Offset {
  Offset normalize() {
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return const Offset(0, -1);
    return Offset(dx / len, dy / len);
  }
}
