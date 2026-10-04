import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../game/bot_agent.dart';
import '../game/camera_controller.dart';
import '../game/game_loop.dart';
import '../game/match_command_controller.dart';
import '../game/pickleball_game.dart';
import '../models/game_settings.dart';
import '../models/ultimate_skill.dart';
import '../utils/constants.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/game_button.dart';
import '../widgets/scoreboard.dart';
import '../widgets/pause_menu.dart';
import '../services/audio_service.dart';
import '../services/character_sprite_manager.dart';

/// ─────────────────────────────────────────────────────────────
/// GameScreen — the main gameplay screen
///
/// Hosts:
///   • Ticker-driven game loop (60 FPS target)
///   • CustomPaint court renderer
///   • HUD overlay (scoreboard, joystick, buttons)
///   • Pause menu overlay
///   • Swipe detection for shot aiming
/// ─────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  PickleballGame? _game;
  MatchCommandController? _commands;
  BotAgent? _playerBot;
  Ticker? _ticker;
  Duration _lastTime = Duration.zero;
  bool _gameInitialized = false;

  // Lightweight notifiers — avoids full setState on every frame
  final ValueNotifier<int> _tickNotifier = ValueNotifier(0);
  final ValueNotifier<double> _staminaNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> _ultimateNotifier = ValueNotifier(0.45);
  final ValueNotifier<int> _scoreNotifier = ValueNotifier(0);
  final ValueNotifier<GameState> _stateNotifier = ValueNotifier(GameState.waitingForServe);
  int _lastScoreHash = -1;
  GameState _lastState = GameState.waitingForServe;
  double _lastStamina = 1.0;
  double _lastUltimate = 0.45;
  bool _lastUltimateArmed = false;
  double _accumulatedDt = 0.0;

  // Swipe tracking
  Offset? _swipeStart;
  Offset? _spectatorGesturePoint;
  double _spectatorGestureScale = 1;
  bool _isPractice = false;
  bool _isTournament = false;
  bool _isCareer = false;
  bool _isBotVsBot = false;
  Map<String, dynamic> _rematchArguments = <String, dynamic>{};
  final FocusNode _focusNode = FocusNode();
  AudioService? _audioService;

  // Match stats tracking
  int _smashCount = 0;
  int _longestRally = 0;
  int _currentRally = 0;
  double _matchDuration = 0;
  bool _wasDown09 = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gameInitialized) {
      _initGame();
    } else if (_game != null) {
      final size = MediaQuery.of(context).size;
      _game!.screenSize = size;
      _game!.camera.screenSize = size;
      final isLandscape = size.width > size.height;
      _game!.camera.fov = isLandscape ? 48.0 : CameraConstants.defaultFOV;
    }
  }

  void _initGame() {
    _gameInitialized = true;
    CharacterSpriteManager.instance.init();
    final settings = context.read<GameSettings>();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _rematchArguments = args == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(args);
    _isPractice = args?['practice'] == true;
    _isTournament = args?['isTournament'] == true;
    _isCareer = args?['isCareer'] == true;
    final modeArg = args?['mode'] as String?;
    _isBotVsBot = args?['botVsBot'] == true || modeArg == 'bot-vs-bot';
    final drillType = args?['drillType'] as String?;
    final gameMode = modeArg == 'doubles' ? GameMode.doubles : GameMode.singles;

    AIDifficulty? diffOverride;
    final diffArg = args?['difficulty'];
    if (diffArg is int && diffArg >= 1 && diffArg <= 3) {
      diffOverride = AIDifficulty.values[diffArg - 1];
    } else if (diffArg is AIDifficulty) {
      diffOverride = diffArg;
    }

    try {
      _audioService = context.read<AudioService>();
      _audioService?.startMatchMusic();
    } catch (_) {}

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    _game = PickleballGame(
      screenSize: size,
      isPracticeMode: _isPractice,
      drillType: drillType,
      gameMode: gameMode,
      settings: settings,
      difficultyOverride: diffOverride,
      audioService: _audioService,
    );
    _commands = MatchCommandController(game: _game!);
    if (_isBotVsBot) {
      _playerBot = BotAgent(
        game: _game!,
        commands: _commands!,
        difficulty: diffOverride ?? settings.difficulty,
      );
      _game!.cameraController.setView(CameraView.baseline);
    }
    if (isLandscape) {
      _game!.camera.fov = 48.0;
    }

    // Start game loop at 60 FPS
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    // Frame pacing support for 30 FPS target (battery saver / low-end devices)
    final targetFps = _game?.settings.targetFps ?? 60;
    if (targetFps == 30) {
      _accumulatedDt += dt;
      if (_accumulatedDt < 0.030) {
        return; // skip intermediate tick to preserve battery and maintain smooth 30 FPS
      }
    }

    final clampedDt = ((_accumulatedDt > 0) ? _accumulatedDt : dt).clamp(0.0, 0.05);
    _accumulatedDt = 0.0;

    _matchDuration += clampedDt;
    _playerBot?.update(clampedDt);
    _game?.update(clampedDt);

    // Track rally length & score changes
    final game = _game;
    if (game != null) {
      final rallyHits = game.ball.rallyHitCount;
      if (rallyHits > _currentRally) {
        _currentRally = rallyHits;
        if (_currentRally > _longestRally) _longestRally = _currentRally;
      } else if (rallyHits == 0 && _currentRally > 0) {
        _currentRally = 0;
      }
      // Track 0-9 deficit
      if (!_wasDown09 && game.player.score == 0 && game.ai.score == 9) {
        _wasDown09 = true;
      }
      if (game.ball.isUltimate && game.ball.lastHitByPlayer && game.ball.rallyHitCount == 1) {
        _smashCount++;
      }

      // Check for score update to notify Scoreboard (no full-screen rebuild)
      final scoreHash = Object.hash(
        game.player.score,
        game.ai.score,
        game.scoreController.isPlayerServing,
        game.scoreController.serverNumber,
        game.scoreController.servingPrimary,
        game.playerScoreAnim,
        game.aiScoreAnim,
      );
      if (scoreHash != _lastScoreHash) {
        _lastScoreHash = scoreHash;
        _scoreNotifier.value++;
      }

      // Check for game state update (serves, rally transitions)
      if (game.state != _lastState) {
        _lastState = game.state;
        _stateNotifier.value = game.state;
      }
    }

    // Check for game over — only setState when transitioning
    if ((_game?.isGameOver ?? false) && mounted) {
      _ticker?.stop();
      _navigateToGameOver();
      return;
    }

    // Update stamina notifier only when it changes meaningfully (threshold 0.01)
    final stamina = _game?.player.stamina ?? 1.0;
    if ((stamina - _lastStamina).abs() >= 0.01) {
      _lastStamina = stamina;
      _staminaNotifier.value = stamina;
    }

    // Update ultimate notifier
    final ultCharge = _game?.ultimateCharge ?? 0.0;
    final ultArmed = _game?.isUltimateArmed ?? false;
    if ((ultCharge - _lastUltimate).abs() >= 0.01 ||
        ultArmed != _lastUltimateArmed) {
      _lastUltimate = ultCharge;
      _lastUltimateArmed = ultArmed;
      _ultimateNotifier.value = ultCharge;
    }

    // Notify CustomPaint to repaint via lightweight ValueNotifier (zero widget rebuilds)
    if (mounted) _tickNotifier.value++;
  }

  void _navigateToGameOver() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/game-over', arguments: {
        'playerScore': _game?.player.score ?? 0,
        'aiScore': _game?.ai.score ?? 0,
        'playerWon': _game?.playerWon ?? false,
        'smashes': _smashCount,
        'longestRally': _longestRally,
        'matchDuration': _matchDuration,
        'isTournament': _isTournament,
        'isCareer': _isCareer,
        'wasDown09': _wasDown09,
        'rematchArguments': _rematchArguments,
      });
    });
  }

  @override
  void dispose() {
    _audioService?.stopMatchMusic();
    _ticker?.stop();
    _ticker?.dispose();
    _focusNode.dispose();
    _tickNotifier.dispose();
    _staminaNotifier.dispose();
    _ultimateNotifier.dispose();
    _scoreNotifier.dispose();
    _stateNotifier.dispose();
    super.dispose();
  }

  // ── Input handlers ─────────────────────────────────────────
  void _onJoystickMove(double x, double y) => _commands?.move(x, y);
  void _onJoystickRelease() => _commands?.stopMoving();

  void _handleKeyEvent(KeyEvent event) {
    if (_game == null) return;
    if (_isBotVsBot) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyC) {
        _cycleSpectatorCamera();
      } else if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.keyP)) {
        setState(() {
          if (_game!.isPaused) {
            _game!.resume();
          } else {
            _game!.pause();
          }
        });
      }
      return;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyJ) {
        if (_game!.state == GameState.waitingForServe &&
            _game!.isHumanServing) {
          _commands!.serve();
        } else {
          _commands!.shot(ShotType.normal);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyK) {
        _commands!.shot(ShotType.power);
      } else if (event.logicalKey == LogicalKeyboardKey.keyL) {
        _commands!.shot(ShotType.lob);
      } else if (event.logicalKey == LogicalKeyboardKey.keyU) {
        _commands!.shot(ShotType.drop);
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _commands!.serve();
      } else if (event.logicalKey == LogicalKeyboardKey.keyQ ||
          event.logicalKey == LogicalKeyboardKey.keyE) {
        if (_game!.ultimateCharge >= 1.0) {
          setState(() {
            _commands!.toggleUltimate();
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        setState(() {
          if (_game!.isPaused) {
            _game!.resume();
          } else {
            _game!.pause();
          }
        });
      }
    }

    // Continuous movement keys (WASD / Arrows)
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    double jx = 0;
    double jy = 0;
    if (keys.contains(LogicalKeyboardKey.arrowLeft) || keys.contains(LogicalKeyboardKey.keyA)) {
      jx -= 1.0;
    }
    if (keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(LogicalKeyboardKey.keyD)) {
      jx += 1.0;
    }
    if (keys.contains(LogicalKeyboardKey.arrowUp) || keys.contains(LogicalKeyboardKey.keyW)) {
      jy -= 1.0;
    }
    if (keys.contains(LogicalKeyboardKey.arrowDown) || keys.contains(LogicalKeyboardKey.keyS)) {
      jy += 1.0;
    }
    if (jx != 0 || jy != 0) {
      _commands!.move(jx, jy);
    } else if (event is KeyUpEvent) {
      _commands!.stopMoving();
    }
  }

  void _cycleSpectatorCamera() {
    final game = _game;
    if (game == null || !_isBotVsBot) return;
    setState(() {
      game.cameraController.cycleSpectatorView();
    });
    HapticFeedback.selectionClick();
  }

  void _onSwipeStart(DragStartDetails d) {
    _swipeStart = d.localPosition;
  }

  void _onSwipeUpdate(DragUpdateDetails d) {
    if (_swipeStart == null) return;
    final delta = d.localPosition - _swipeStart!;
    if (delta.distance > 20) {
      _commands?.aim(delta);
    }
  }

  void _onSwipeEnd(DragEndDetails d) {
    _swipeStart = null;
    _commands?.clearAim();
  }

  void _onSpectatorScaleStart(ScaleStartDetails details) {
    _spectatorGesturePoint = details.focalPoint;
    _spectatorGestureScale = 1;
  }

  void _onSpectatorScaleUpdate(ScaleUpdateDetails details) {
    final game = _game;
    final previousPoint = _spectatorGesturePoint;
    if (game == null ||
        previousPoint == null ||
        game.cameraController.view != CameraView.freeRoam) {
      return;
    }
    final delta = details.focalPoint - previousPoint;
    final scaleDelta = details.scale / _spectatorGestureScale;
    game.cameraController.adjustFreeRoam(
      orbitDx: delta.dx,
      orbitDy: delta.dy,
      zoomFactor: scaleDelta,
    );
    _spectatorGesturePoint = details.focalPoint;
    _spectatorGestureScale = details.scale;
  }

  void _onSpectatorScaleEnd(ScaleEndDetails details) {
    _spectatorGesturePoint = null;
    _spectatorGestureScale = 1;
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (!_gameInitialized || game == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Keep camera updated with current viewport size & aspect ratio
    game.screenSize = size;
    game.camera.screenSize = size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onPanStart: _isBotVsBot ? null : _onSwipeStart,
          onPanUpdate: _isBotVsBot ? null : _onSwipeUpdate,
          onPanEnd: _isBotVsBot ? null : _onSwipeEnd,
          onScaleStart: _isBotVsBot ? _onSpectatorScaleStart : null,
          onScaleUpdate: _isBotVsBot ? _onSpectatorScaleUpdate : null,
          onScaleEnd: _isBotVsBot ? _onSpectatorScaleEnd : null,
          child: Stack(
            children: [
              // ── Custom Court Environment Artwork Backdrop ────────
              Positioned.fill(
                child: Image.asset(
                  game.settings.courtTheme.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: game.settings.isLowEndMode ? 960 : 1920,
                  filterQuality: game.settings.isLowEndMode
                      ? FilterQuality.low
                      : FilterQuality.medium,
                ),
              ),

              // ── 3D Court — isolated RepaintBoundary with direct repaint Listenable ───
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CourtPainter(
                      game: game,
                      repaint: _tickNotifier,
                    ),
                  ),
                ),
              ),

              // ── HUD overlay ─────────────────────────────────────
              _buildHUD(game, isLandscape: isLandscape),

              // ── Pause menu overlay ──────────────────────────────
              if (game.isPaused) _buildPauseMenu(game),

              // ── Serve prompt (only updates on state changes) ─────
              ValueListenableBuilder<GameState>(
                valueListenable: _stateNotifier,
                builder: (_, state, ___) {
                  if (!_isBotVsBot &&
                      state == GameState.waitingForServe &&
                      game.isHumanServing) {
                    return _buildServePrompt(game, isLandscape: isLandscape);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHUD(PickleballGame game, {required bool isLandscape}) {
    final size = MediaQuery.of(context).size;
    // In landscape, derive joystick & button sizing from screen height
    // so controls are always comfortably thumb-sized regardless of device
    final joystickSize = isLandscape
        ? (size.height * 0.52).clamp(90.0, 140.0)
        : UISizes.joystickSize;

    return SafeArea(
      child: Stack(
        children: [
          // ── Scoreboard & Player Status (top left) ─────────
          Positioned(
            top: isLandscape ? 8 : UISizes.hudPadding,
            left: isLandscape ? 12 : UISizes.hudPadding,
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _scoreNotifier,
                builder: (_, __, ___) => Scoreboard(
                  playerScore: game.player.score,
                  aiScore: game.ai.score,
                  playerScoreAnim: game.playerScoreAnim,
                  aiScoreAnim: game.aiScoreAnim,
                  isServing: game.scoreController.isPlayerServing,
                  serverNumber: game.gameMode == GameMode.doubles
                      ? game.scoreController.serverNumber
                      : null,
                  isPractice: _isPractice,
                  modeName: _isPractice
                      ? 'PRACTICE'
                      : (_isBotVsBot
                          ? 'BOT VS BOT'
                          : (game.gameMode == GameMode.doubles
                              ? 'DOUBLES'
                              : 'SINGLES')),
                  footer:
                      _isBotVsBot ? null : _buildPlayerStatusCard(game),
                ),
              ),
            ),
          ),

          // ── Pause button (upper right) ─────────────────────
          Positioned(
            top: isLandscape ? 8 : UISizes.hudPadding,
            right: isLandscape ? 16 : UISizes.hudPadding,
            child: PauseButton(
              onTap: () => setState(() => game.pause()),
            ),
          ),

          if (_isBotVsBot)
            Positioned(
              top: isLandscape ? 8 : UISizes.hudPadding,
              right: isLandscape ? 64 : 62,
              child: _SpectatorCameraButton(
                label: game.cameraController.view.label,
                onTap: _cycleSpectatorCamera,
              ),
            ),

          if (_isBotVsBot &&
              game.cameraController.view == CameraView.freeRoam)
            const Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(child: _FreeRoamHint()),
            ),

          // ── Virtual Joystick (bottom left) ────────────────
          if (!_isBotVsBot)
            Positioned(
              bottom: isLandscape ? 8 : 28,
              left: isLandscape ? 16 : 20,
              child: VirtualJoystick(
                size: joystickSize,
                onMove: _onJoystickMove,
                onRelease: _onJoystickRelease,
                sensitivity:
                    context.read<GameSettings>().joystickSensitivity,
              ),
            ),

          // ── Compact Ergonomic Action Buttons (bottom right) ──
          if (!_isBotVsBot)
            Positioned(
              bottom: isLandscape ? 8 : 24,
              right: isLandscape ? 16 : 16,
              child: RepaintBoundary(
                child: ValueListenableBuilder<GameState>(
                  valueListenable: _stateNotifier,
                  builder: (_, __, ___) => _buildActionButtons(
                    game,
                    isLandscape: isLandscape,
                    screenHeight: size.height,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Sleek Broadcast Player Status Card (SP & Stamina docked under Scoreboard) ──
  // ── Sleek Broadcast Player Status Card (SP & Stamina docked in Scoreboard footer) ──
  Widget _buildPlayerStatusCard(PickleballGame game) {
    return Row(
      children: [
        // Left: SP Ultimate Gauge with Quick Selector
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: _ultimateNotifier,
            builder: (context, charge, _) {
              final isReady = charge >= 1.0;
              final isArmed = game.isUltimateArmed;
              final ultSkill = game.currentUltimate;

              return GestureDetector(
                onTap: () => _showUltimateSelectorModal(context, game),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ultSkill.icon,
                                size: 9.5,
                                color: isArmed
                                    ? Colors.white
                                    : (isReady
                                        ? ultSkill.primaryColor
                                        : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 2.5),
                              Flexible(
                                child: Text(
                                  'SP',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.orbitron,
                                    fontSize: 6.8,
                                    fontWeight: FontWeight.w800,
                                    color: isReady
                                        ? ultSkill.primaryColor
                                        : const Color(0xFF94A3B8),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArmed
                                  ? 'ARMED'
                                  : (isReady
                                      ? 'READY'
                                      : '${(charge * 100).toInt()}%'),
                              style: TextStyle(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w800,
                                color: isArmed
                                    ? Colors.white
                                    : (isReady
                                        ? ultSkill.primaryColor
                                        : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 9.5,
                              color: ultSkill.primaryColor.withAlpha(180),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1.5),
                      child: SizedBox(
                        height: 2.2,
                        child: LinearProgressIndicator(
                          value: charge.clamp(0.0, 1.0),
                          backgroundColor: const Color(0x33334155),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isReady
                                ? ultSkill.primaryColor
                                : const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Subtle vertical divider
        Container(
          width: 0.8,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          color: Colors.white12,
        ),

        // Right: Stamina Gauge
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: _staminaNotifier,
            builder: (context, stamina, _) {
              final isLow = stamina < StaminaConstants.powerShotCost;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 9.5,
                              color: isLow
                                  ? AppColors.power
                                  : const Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                'STAMINA',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.orbitron,
                                  fontSize: 6.8,
                                  fontWeight: FontWeight.w800,
                                  color: isLow
                                      ? AppColors.power
                                      : const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(stamina * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 6.5,
                          fontWeight: FontWeight.w800,
                          color: isLow
                              ? AppColors.power
                              : const Color(0xFFD4E157),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: SizedBox(
                      height: 2.2,
                      child: LinearProgressIndicator(
                        value: stamina.clamp(0.0, 1.0),
                        backgroundColor: const Color(0x33334155),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLow ? AppColors.power : const Color(0xFFD4E157),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Action Controls: Context-Aware & Ultra-Compact Thumb Cluster ──
  Widget _buildActionButtons(PickleballGame game,
      {required bool isLandscape, double screenHeight = 400}) {
    final isServing = game.state == GameState.waitingForServe &&
        game.isHumanServing;

    // In landscape, derive button sizes from screen height so they scale
    // proportionally across all mobile device sizes (phones ~320-420px tall)
    double smallBtnSize, powerBtnSize, ultBtnSize, hitBtnSize;
    double btnSpacing, rowSpacing;

    if (isLandscape) {
      // ~46% of screen height for the whole cluster height
      // Distribute: top row uses smaller btns, bottom row uses larger btns
      final clusterH = (screenHeight * 0.82).clamp(180.0, 340.0);
      // HIT / ULT are ~half the cluster, top row buttons ~38% of cluster
      hitBtnSize   = (clusterH * 0.46).clamp(52.0, 80.0);
      ultBtnSize   = (clusterH * 0.42).clamp(48.0, 72.0);
      powerBtnSize = (clusterH * 0.34).clamp(40.0, 60.0);
      smallBtnSize = (clusterH * 0.30).clamp(36.0, 54.0);
      btnSpacing   = (screenHeight * 0.025).clamp(5.0, 10.0);
      rowSpacing   = (screenHeight * 0.020).clamp(4.0, 8.0);
    } else {
      smallBtnSize = 40.0;
      powerBtnSize = 44.0;
      ultBtnSize   = 54.0;
      hitBtnSize   = UISizes.hitButtonSize;
      btnSpacing   = 6.0;
      rowSpacing   = 6.0;
    }

    // During player serve: only display hero SERVE button & ULTIMATE
    if (isServing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildUltimateButton(game, size: ultBtnSize),
          SizedBox(width: isLandscape ? btnSpacing + 4 : 12),
          GameButton(
            label: 'SERVE',
            icon: Icons.sports_tennis_rounded,
            size: hitBtnSize,
            color: const Color(0xFF0284C7),
            glowColor: const Color(0x770284C7),
            onTap: () => _commands?.serve(),
          ),
        ],
      );
    }

    // In-play rally: 2-tier ergonomic thumb cluster
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Top row: Shot Modifiers (DROP, LOB, POWER/SMASH)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameButton(
              label: 'DROP',
              icon: Icons.south_west_rounded,
              size: smallBtnSize,
              color: const Color(0xFF06B6D4),
              glowColor: const Color(0x4406B6D4),
              onTap: () => _commands?.shot(ShotType.drop),
            ),
            SizedBox(width: btnSpacing),
            GameButton(
              label: 'LOB',
              icon: Icons.north_east_rounded,
              size: smallBtnSize,
              color: const Color(0xFF8B5CF6),
              glowColor: const Color(0x448B5CF6),
              onTap: () => _commands?.shot(ShotType.lob),
            ),
            SizedBox(width: btnSpacing),
            GameButton(
              label: 'POWER',
              icon: Icons.bolt_rounded,
              size: powerBtnSize,
              color: AppColors.power,
              glowColor: AppColors.powerGlow,
              onTap: () => _commands?.shot(ShotType.power),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),

        // Bottom row: ULTIMATE + Primary HIT
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildUltimateButton(game, size: ultBtnSize),
            SizedBox(width: btnSpacing + 2),
            GameButton(
              label: 'HIT',
              icon: Icons.sports_tennis_rounded,
              size: hitBtnSize,
              color: AppColors.primary,
              glowColor: AppColors.primaryGlow,
              onTap: () => _commands?.shot(ShotType.normal),
            ),
          ],
        ),
      ],
    );
  }

  // ── Ultimate Action Button ────────────────────────────────────
  Widget _buildUltimateButton(PickleballGame game, {double size = 54.0}) {
    return _UltimateButtonWidget(
      game: game,
      size: size,
      ultimateNotifier: _ultimateNotifier,
      onOpenSelector: () => _showUltimateSelectorModal(context, game),
      onToggleArm: () => _commands?.toggleUltimate(),
      onArmToggled: () => setState(() {}),
    );
  }

  // ── Ultimate Skill Selector Modal ─────────────────────────────
  void _showUltimateSelectorModal(
      BuildContext context, PickleballGame game) {
    final settings = context.read<GameSettings>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final equipped = settings.equippedUltimate;
            final mqSize = MediaQuery.of(context).size;
            final isLandscapeModal = mqSize.width > mqSize.height;

            return Container(
              constraints: BoxConstraints(
                maxHeight: isLandscapeModal
                    ? mqSize.height * 0.95
                    : mqSize.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xF00B132B),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SPECIAL SHOTS',
                              style: TextStyle(
                                fontFamily: AppFonts.orbitron,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select special skill to equip for matches',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  // List of skills
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      shrinkWrap: true,
                      itemCount: kAllUltimateSkills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final skill = kAllUltimateSkills[index];
                        final isCurrent = skill.type == equipped;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? skill.primaryColor.withAlpha(25)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent
                                  ? skill.primaryColor
                                  : Colors.white.withAlpha(20),
                              width: isCurrent ? 2.0 : 1.0,
                            ),
                            boxShadow: [
                              if (isCurrent)
                                BoxShadow(
                                  color: skill.glowColor,
                                  blurRadius: 12,
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Icon Badge
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color:
                                          skill.primaryColor.withAlpha(35),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: skill.primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      skill.icon,
                                      color: skill.primaryColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name + Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              skill.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              skill.shortName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: skill.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          skill.tagline,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: skill.accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Equip Button / Equipped Badge
                                  ElevatedButton(
                                    onPressed: isCurrent
                                        ? null
                                        : () {
                                            settings
                                                .equipUltimate(skill.type);
                                            setModalState(() {});
                                            setState(() {});
                                            HapticFeedback.mediumImpact();
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrent
                                          ? const Color(0xFF334155)
                                          : skill.primaryColor,
                                      foregroundColor: isCurrent
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF0F172A),
                                      minimumSize: const Size(88, 42),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      isCurrent ? 'EQUIPPED' : 'EQUIP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                skill.description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFCBD5E1),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Mini Stats Row
                              Row(
                                children: [
                                  _buildMiniStat('POWER', skill.power,
                                      skill.primaryColor),
                                  const SizedBox(width: 10),
                                  _buildMiniStat('SPEED', skill.speed,
                                      skill.primaryColor),
                                  const SizedBox(width: 10),
                                  _buildMiniStat('CURVE', skill.curve,
                                      skill.primaryColor),
                                  const SizedBox(width: 10),
                                  _buildMiniStat('DECEPTION',
                                      skill.deception, skill.primaryColor),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStat(String label, double val, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: val,
              minHeight: 3.5,
              backgroundColor: const Color(0x33475569),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseMenu(PickleballGame game) {
    return PauseMenu(
      onResume: () => setState(() => game.resume()),
      onRestart: () => setState(() {
        game.restartMatch();
        game.resume();
        _lastTime = Duration.zero;
        if (!(_ticker?.isActive ?? false)) _ticker?.start();
        _audioService?.startMatchMusic();
      }),
      onSettings: () => Navigator.pushNamed(context, '/settings'),
      onMainMenu: () => Navigator.pushReplacementNamed(context, '/menu'),
    );
  }

  Widget _buildServePrompt(PickleballGame game, {required bool isLandscape}) {
    return Positioned(
      top: isLandscape ? 102 : 122,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF20B132B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.ballColor.withAlpha(180), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x60000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ballColor,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ballColor.withAlpha(220),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SERVE TO HIGHLIGHTED BOX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withAlpha(180),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRESS SERVE',
                  style: TextStyle(
                    color: Color(0xFFBAE6FD),
                    fontSize: 9.0,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpectatorCameraButton extends StatelessWidget {
  const _SpectatorCameraButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change spectator camera. Current view: $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x5548CAE4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_rounded,
                size: 17,
                color: Color(0xFF67E8F9),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeRoamHint extends StatelessWidget {
  const _FreeRoamHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x445EE7F7)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'DRAG TO ORBIT  •  PINCH TO ZOOM',
            style: TextStyle(
              color: Color(0xFFBAE6FD),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _UltimateButtonWidget extends StatefulWidget {
  final PickleballGame game;
  final double size;
  final ValueNotifier<double> ultimateNotifier;
  final VoidCallback onOpenSelector;
  final VoidCallback onToggleArm;
  final VoidCallback onArmToggled;

  const _UltimateButtonWidget({
    required this.game,
    required this.size,
    required this.ultimateNotifier,
    required this.onOpenSelector,
    required this.onToggleArm,
    required this.onArmToggled,
  });

  @override
  State<_UltimateButtonWidget> createState() => _UltimateButtonWidgetState();
}

class _UltimateButtonWidgetState extends State<_UltimateButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.ultimateNotifier,
      builder: (context, charge, _) {
        final isReady = charge >= 1.0;
        final isArmed = widget.game.isUltimateArmed;
        final ultSkill = widget.game.currentUltimate;
        final size = widget.size;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (_) => _pressCtrl.forward(),
            onTapCancel: () => _pressCtrl.reverse(),
            onTapUp: (_) {
              _pressCtrl.reverse();
              try {
                Provider.of<AudioService>(context, listen: false).playButtonClick();
              } catch (_) {}
              if (isReady) {
                HapticFeedback.heavyImpact();
                widget.onToggleArm();
                widget.onArmToggled();
              } else {
                HapticFeedback.lightImpact();
                widget.onOpenSelector();
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onOpenSelector();
            },
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isArmed
                      ? LinearGradient(
                          colors: [
                            Colors.white,
                            ultSkill.primaryColor,
                            ultSkill.accentColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : isReady
                          ? LinearGradient(
                              colors: [
                                ultSkill.primaryColor,
                                ultSkill.accentColor,
                                const Color(0xFF0F172A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                  border: Border.all(
                    color: isArmed
                        ? Colors.white
                        : isReady
                            ? ultSkill.primaryColor
                            : Colors.white.withAlpha(40),
                    width: isArmed ? 3.0 : (isReady ? 2.5 : 1.5),
                  ),
                  boxShadow: [
                    if (isArmed) ...[
                      BoxShadow(
                        color: Colors.white.withAlpha(200),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: ultSkill.primaryColor.withAlpha(220),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ] else if (isReady) ...[
                      BoxShadow(
                        color: ultSkill.glowColor,
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Charging circular border arc when not ready
                    if (!isReady)
                      SizedBox(
                        width: size - 6,
                        height: size - 6,
                        child: CircularProgressIndicator(
                          value: charge,
                          strokeWidth: 3.0,
                          backgroundColor: Colors.white.withAlpha(25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ultSkill.primaryColor,
                          ),
                        ),
                      ),

                    // Button contents: Icon + Label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ultSkill.icon,
                          size: isReady ? (size * 0.40) : (size * 0.35),
                          color: isArmed
                              ? const Color(0xFF0F172A)
                              : isReady
                                  ? Colors.white
                                  : ultSkill.primaryColor.withAlpha(200),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isArmed
                              ? 'ARMED!'
                              : isReady
                                  ? 'ULT'
                                  : '${(charge * 100).toInt()}%',
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            fontSize: isArmed ? 8.5 : 9.0,
                            fontWeight: FontWeight.w900,
                            color: isArmed
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),

                    // "READY" small top pill
                    if (isReady && !isArmed)
                      Positioned(
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: ultSkill.primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'READY',
                            style: TextStyle(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
