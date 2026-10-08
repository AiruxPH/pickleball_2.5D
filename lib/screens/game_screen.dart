import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/lan/lan_multiplayer_service.dart';
import '../services/lan/lan_state_snapshot.dart';
import '../services/online/online_multiplayer_service.dart';
import '../game/bot_agent.dart';
import '../game/camera_controller.dart';
import '../game/court_input_mapper.dart';
import '../game/game_loop.dart';
import '../game/game_presentation.dart';
import '../game/match_command_controller.dart';
import '../game/match_observation.dart';
import '../game/pickleball_game.dart';
import '../game/panorama/court_backdrop_view.dart';
import '../models/game_settings.dart';
import '../models/shot_mechanics.dart';
import '../models/match_foundation.dart';
import '../models/ultimate_skill.dart';
import '../utils/constants.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/game_button.dart';
import '../widgets/scoreboard.dart';
import '../widgets/pause_menu.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
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
  GamePresentation? _presentation;
  MatchCommandController? _commands;
  MatchCommandController? _opponentCommands;
  BotAgent? _playerBot;
  BotAgent? _opponentBot;
  Ticker? _ticker;
  Duration _lastTime = Duration.zero;
  bool _gameInitialized = false;

  // Lightweight notifiers — avoids full setState on every frame
  final ValueNotifier<int> _tickNotifier = ValueNotifier(0);
  final ValueNotifier<double> _staminaNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> _ultimateNotifier = ValueNotifier(0.45);
  final ValueNotifier<int> _scoreNotifier = ValueNotifier(0);
  final ValueNotifier<GameState> _stateNotifier =
      ValueNotifier(GameState.waitingForServe);
  int _lastScoreHash = -1;
  GameState _lastState = GameState.waitingForServe;
  double _lastStamina = 1.0;
  double _lastUltimate = 0.45;
  bool _lastUltimateArmed = false;
  double _accumulatedDt = 0.0;
  double _simulationAccumulator = 0.0;
  static const double _simulationStep = 1 / 120;

  // Swipe tracking
  Offset? _swipeStart;
  Offset? _spectatorGesturePoint;
  double _spectatorGestureScale = 1;
  bool _isPractice = false;
  bool _isTournament = false;
  bool _isCareer = false;
  bool _isBotVsBot = false;
  bool _isLocalMultiplayer = false;
  bool _isLanMultiplayer = false;
  bool _isOnlineMultiplayer = false;
  String? _lanRole;
  StreamSubscription? _lanCommandSub;
  StreamSubscription? _lanStateSyncSub;
  Timer? _onlineDisconnectTimer;
  bool _onlinePeerWasPresent = false;
  bool _onlineConnectionInterrupted = false;
  bool _onlineDisconnectDialogVisible = false;
  bool _pausedForOnlineDisconnect = false;
  bool _wasPausedBeforeOnlineDisconnect = false;
  LanStateSnapshot? _latestOnlineSnapshot;
  int _onlineSnapshotRevision = 0;
  int _appliedOnlineSnapshotRevision = 0;
  int _onlineSnapshotReceivedAtMs = 0;
  int _lastLanSyncMs = 0;
  Map<String, dynamic> _rematchArguments = <String, dynamic>{};
  final FocusNode _focusNode = FocusNode();
  AudioService? _audioService;

  // Match stats tracking
  int _smashCount = 0;
  int _longestRally = 0;
  int _currentRally = 0;
  double _matchDuration = 0;
  bool _wasDown09 = false;
  bool _customizingControls = false;
  ShotSpin _playerSpin = ShotSpin.flat;
  ShotSpin _opponentSpin = ShotSpin.flat;
  int _lastFeedbackRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gameInitialized) {
      _initGame();
    } else if (_game != null) {
      final size = MediaQuery.of(context).size;
      _presentation!.resize(size);
      final isLandscape = size.width > size.height;
      _presentation!.camera.fov =
          isLandscape ? 48.0 : CameraConstants.defaultFOV;
    }
  }

  void _initGame() {
    _gameInitialized = true;
    CharacterSpriteManager.instance.init();
    final settings = context.read<GameSettings>();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _rematchArguments =
        args == null ? <String, dynamic>{} : Map<String, dynamic>.from(args);
    _isPractice = args?['practice'] == true;
    _isTournament = args?['isTournament'] == true;
    _isCareer = args?['isCareer'] == true;
    final modeArg = args?['mode'] as String?;
    _isBotVsBot = args?['botVsBot'] == true || modeArg == 'bot-vs-bot';
    _isLanMultiplayer = args?['lanMultiplayer'] == true;
    _isOnlineMultiplayer = args?['onlineMultiplayer'] == true;
    _lanRole = (args?['lanRole'] ?? args?['onlineRole']) as String?;
    _isLocalMultiplayer = args?['localMultiplayer'] == true ||
        _isLanMultiplayer ||
        _isOnlineMultiplayer;
    final drillType = args?['drillType'] as String?;
    final gameMode = modeArg == 'doubles' || args?['gameMode'] == 'doubles'
        ? GameMode.doubles
        : GameMode.singles;
    final balanceProfile =
        MatchBalanceProfileX.fromName(args?['balanceProfile']);

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
      isPracticeMode: _isPractice,
      drillType: drillType,
      gameMode: gameMode,
      isLocalMultiplayer: _isLocalMultiplayer || _isBotVsBot,
      balanceProfile: balanceProfile,
      settings: settings,
      difficultyOverride: diffOverride,
      audioService: _audioService,
    );
    _presentation = GamePresentation(
      viewportSize: size,
      player: _game!.player,
      ball: _game!.ball,
      settings: settings,
    );
    _game!.effects = _presentation!;
    _commands = MatchCommandController(
      game: _game!,
      playerSlot: 0,
      onDispatched: (cmd) {
        if (_isLanMultiplayer && _lanRole == 'client') {
          LanMultiplayerService.instance.sendMatchCommand(cmd);
        } else if (_isOnlineMultiplayer && _lanRole == 'client') {
          OnlineMultiplayerService.instance.sendMatchCommand(cmd);
        }
      },
    );
    if (_isLocalMultiplayer || _isBotVsBot) {
      _opponentCommands = MatchCommandController(
        game: _game!,
        playerSlot: 1,
        onDispatched: (cmd) {
          if (_isLanMultiplayer && _lanRole == 'client') {
            LanMultiplayerService.instance.sendMatchCommand(cmd);
          } else if (_isOnlineMultiplayer && _lanRole == 'client') {
            OnlineMultiplayerService.instance.sendMatchCommand(cmd);
          }
        },
      );
    }
    if (_isLanMultiplayer) {
      if (_lanRole == 'host') {
        _lanCommandSub =
            LanMultiplayerService.instance.onCommandReceived.listen((cmd) {
          _opponentCommands?.dispatch(cmd);
        });
      } else if (_lanRole == 'client') {
        _lanStateSyncSub = LanMultiplayerService.instance.onStateSyncReceived
            .listen((snapshot) {
          if (_game != null) {
            snapshot.applyToGame(_game!);
          }
        });
        _presentation!.cameraController.reverseBaseline = true;
        _presentation!.cameraController.setView(CameraView.baseline);
      }
    }
    if (_isOnlineMultiplayer) {
      final onlineService = OnlineMultiplayerService.instance;
      _onlinePeerWasPresent = onlineService.remotePlayerPresent;
      onlineService.addListener(_handleOnlineConnectionChanged);
      if (_lanRole == 'host') {
        _lanCommandSub = onlineService.onCommandReceived
            .listen((cmd) => _opponentCommands?.dispatch(cmd));
      } else if (_lanRole == 'client') {
        _lanStateSyncSub = onlineService.onStateSyncReceived.listen((snapshot) {
          _latestOnlineSnapshot = snapshot;
          _onlineSnapshotReceivedAtMs = DateTime.now().millisecondsSinceEpoch;
          _onlineSnapshotRevision++;
        });
        _presentation!.cameraController.reverseBaseline = true;
        _presentation!.cameraController.setView(CameraView.baseline);
      }
    }
    if (_isBotVsBot) {
      _playerBot = BotAgent(
        observe: () => MatchObservation.fromGame(_game!),
        commands: _commands!,
        difficulty: diffOverride ?? settings.difficulty,
        id: 'near-counterpuncher',
        personality: BotPersonality.patient,
        randomSeed: 1103,
      );
      _opponentBot = BotAgent(
        observe: () => MatchObservation.fromGame(_game!),
        commands: _opponentCommands!,
        difficulty: diffOverride ?? settings.difficulty,
        id: 'far-attacker',
        side: BotCourtSide.far,
        personality: BotPersonality.aggressive,
        randomSeed: 2909,
      );
      _presentation!.cameraController.setView(CameraView.baseline);
    }
    if (isLandscape) {
      _presentation!.camera.fov = 48.0;
    }

    // Start game loop at 60 FPS
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }

  void _handleOnlineConnectionChanged() {
    if (!mounted || !_isOnlineMultiplayer) return;
    final service = OnlineMultiplayerService.instance;
    final peerPresent = service.remotePlayerPresent;

    if (peerPresent && service.status != OnlineStatus.disconnected) {
      _onlinePeerWasPresent = true;
      _onlineDisconnectTimer?.cancel();
      _onlineDisconnectTimer = null;
      if (_onlineConnectionInterrupted && !_onlineDisconnectDialogVisible) {
        _onlineConnectionInterrupted = false;
        if (_pausedForOnlineDisconnect && !_wasPausedBeforeOnlineDisconnect) {
          _game?.resume();
        }
        _pausedForOnlineDisconnect = false;
        if (mounted) setState(() {});
      }
      return;
    }

    final matchStillOwnedLocally = service.role != OnlineRole.none;
    final peerLost = service.status == OnlineStatus.disconnected ||
        (_onlinePeerWasPresent && !peerPresent);
    if (!matchStillOwnedLocally ||
        !peerLost ||
        _onlineDisconnectDialogVisible) {
      return;
    }

    if (!_onlineConnectionInterrupted) {
      _onlineConnectionInterrupted = true;
      _wasPausedBeforeOnlineDisconnect = _game?.isPaused ?? false;
      if (!_wasPausedBeforeOnlineDisconnect) {
        _game?.pause();
        _pausedForOnlineDisconnect = true;
      }
      setState(() {});
    }
    _onlineDisconnectTimer ??= Timer(
      const Duration(seconds: 4),
      _confirmOnlineDisconnect,
    );
  }

  Future<void> _confirmOnlineDisconnect() async {
    _onlineDisconnectTimer = null;
    if (!mounted || _onlineDisconnectDialogVisible) return;
    final service = OnlineMultiplayerService.instance;
    if (service.role == OnlineRole.none ||
        (service.remotePlayerPresent &&
            service.status != OnlineStatus.disconnected)) {
      return;
    }

    _onlineDisconnectDialogVisible = true;
    _ticker?.stop();
    await service.leaveRoom();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        icon: const Icon(
          Icons.wifi_off_rounded,
          color: Color(0xFFFCA5A5),
          size: 42,
        ),
        title: const Text(
          'OPPONENT DISCONNECTED',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'The other player left the match or lost their connection. '
          'This match has ended.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.home_rounded),
            label: const Text('RETURN TO MENU'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/menu', (_) => false);
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

    final clampedDt =
        ((_accumulatedDt > 0) ? _accumulatedDt : dt).clamp(0.0, 0.05);
    _accumulatedDt = 0.0;

    _matchDuration += clampedDt;
    _simulationAccumulator =
        (_simulationAccumulator + clampedDt).clamp(0.0, 0.25);
    final isNetworkClient =
        (_isLanMultiplayer || _isOnlineMultiplayer) && _lanRole == 'client';
    while (_simulationAccumulator >= _simulationStep) {
      if (!isNetworkClient) {
        _playerBot?.update(_simulationStep);
        _opponentBot?.update(_simulationStep);
        _game?.update(_simulationStep);
      } else if (_isOnlineMultiplayer) {
        _game?.predictNetworkPlayer(_simulationStep, playerSlot: 1);
      }
      _simulationAccumulator -= _simulationStep;
    }
    final game = _game;
    if (_isOnlineMultiplayer &&
        _lanRole == 'client' &&
        game != null &&
        _latestOnlineSnapshot != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final hasNewSnapshot =
          _appliedOnlineSnapshotRevision != _onlineSnapshotRevision;
      if (hasNewSnapshot) {
        _appliedOnlineSnapshotRevision = _onlineSnapshotRevision;
      }
      _latestOnlineSnapshot!.applyToGame(
        game,
        positionBlend: (clampedDt * 22).clamp(0.0, 1.0),
        player2PositionBlend: hasNewSnapshot ? 0.35 : 0,
        extrapolationSeconds:
            ((now - _onlineSnapshotReceivedAtMs) / 1000).clamp(0.0, 0.15),
      );
    }
    if (game != null &&
        game.state != GameState.paused &&
        game.state != GameState.gameOver) {
      _presentation?.update(
        clampedDt,
        effectTimeScale: game.state == GameState.rally ? game.timeDilation : 1,
      );
    }

    if (_isLanMultiplayer && _lanRole == 'host' && _game != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastLanSyncMs >= 25) {
        _lastLanSyncMs = now;
        LanMultiplayerService.instance.sendStateSync(
          LanStateSnapshot.fromGame(_game!),
        );
      }
    }
    if (_isOnlineMultiplayer && _lanRole == 'host' && _game != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Target 20 Hz; skip a frame while the prior Firebase write is pending.
      if (now - _lastLanSyncMs >= 50) {
        _lastLanSyncMs = now;
        OnlineMultiplayerService.instance
            .sendStateSync(LanStateSnapshot.fromGame(_game!));
      }
    }

    // Track rally length & score changes
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
      if (game.ball.isUltimate &&
          game.ball.lastHitByPlayer &&
          game.ball.rallyHitCount == 1) {
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

      final feedback = game.contactFeedback;
      if (feedback != null && feedback.revision != _lastFeedbackRevision) {
        _lastFeedbackRevision = feedback.revision;
        final localSlot = _isRemoteClient ? 1 : 0;
        if (!_isLocalMultiplayer || feedback.playerSlot == localSlot) {
          switch (feedback.grade) {
            case SwingTimingGrade.perfect:
              HapticFeedback.mediumImpact();
              break;
            case SwingTimingGrade.good:
              HapticFeedback.lightImpact();
              break;
            case SwingTimingGrade.early:
            case SwingTimingGrade.late:
              HapticFeedback.selectionClick();
              break;
          }
        }
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
    _onlineDisconnectTimer?.cancel();
    if (_isOnlineMultiplayer) {
      OnlineMultiplayerService.instance
          .removeListener(_handleOnlineConnectionChanged);
    }
    _lanCommandSub?.cancel();
    _lanStateSyncSub?.cancel();
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
  MatchCommandController? get _activeTouchCommands {
    final game = _game;
    if (game == null) return _commands;
    if (_isLanMultiplayer || _isOnlineMultiplayer) {
      return _lanRole == 'client' ? _opponentCommands : _commands;
    }
    if (!_isLocalMultiplayer) return _commands;
    if (game.state == GameState.waitingForServe) {
      return game.isOpponentHumanServing ? _opponentCommands : _commands;
    }
    return game.ball.lastHitByPlayer ? _opponentCommands : _commands;
  }

  bool get _isRemoteClient =>
      (_isLanMultiplayer || _isOnlineMultiplayer) && _lanRole == 'client';

  bool get _controlsFarSide => _activeTouchCommands == _opponentCommands;

  ShotSpin get _activeSpin =>
      _controlsFarSide ? _opponentSpin : _playerSpin;

  void _setActiveSpin(ShotSpin spin) {
    setState(() {
      if (_controlsFarSide) {
        _opponentSpin = spin;
      } else {
        _playerSpin = spin;
      }
    });
  }

  void _cycleSpin({required bool opponent}) {
    final current = opponent ? _opponentSpin : _playerSpin;
    final next = ShotSpin.values[(current.index + 1) % ShotSpin.values.length];
    setState(() {
      if (opponent) {
        _opponentSpin = next;
      } else {
        _playerSpin = next;
      }
    });
  }

  CourtInputMapper? get _inputMapper {
    final presentation = _presentation;
    return presentation == null ? null : CourtInputMapper(presentation.camera);
  }

  bool _localPlayerCanServe(PickleballGame game) {
    if (game.state != GameState.waitingForServe || !game.isHumanServing) {
      return false;
    }
    if (_isRemoteClient) return game.isOpponentHumanServing;
    if (_isLanMultiplayer || _isOnlineMultiplayer) {
      return !game.isOpponentHumanServing;
    }
    return true;
  }

  void _onJoystickMove(double x, double y) {
    _moveFromScreenVector(
      _activeTouchCommands,
      Offset(x, y),
      farSide: _controlsFarSide,
    );
  }

  void _moveFromScreenVector(
    MatchCommandController? commands,
    Offset vector, {
    required bool farSide,
  }) {
    final axes = _inputMapper?.commandAxesFromNormalizedScreenVector(
      vector,
      farSide: farSide,
    );
    if (axes != null) commands?.move(axes.dx, axes.dy);
  }

  void _onJoystickDrag(JoystickDrag drag) {
    final axes = _inputMapper?.commandAxesFromScreenDrag(
      origin: drag.origin,
      current: drag.current,
      farSide: _controlsFarSide,
      magnitude: drag.normalized.distance,
    );
    if (axes != null) _activeTouchCommands?.move(axes.dx, axes.dy);
  }

  void _onJoystickRelease() => _activeTouchCommands?.stopMoving();

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
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _cycleSpin(opponent: false);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyO) {
        _cycleSpin(opponent: true);
        return;
      }
      if (_isRemoteClient) {
        if (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (_game!.state == GameState.waitingForServe &&
              _game!.isOpponentHumanServing) {
            _opponentCommands?.serve();
          } else {
            _opponentCommands?.shot(
              ShotType.normal,
              spin: _opponentSpin,
            );
          }
        } else if (event.logicalKey == LogicalKeyboardKey.keyJ ||
            event.logicalKey == LogicalKeyboardKey.keyM) {
          _opponentCommands?.shot(ShotType.normal, spin: _opponentSpin);
        } else if (event.logicalKey == LogicalKeyboardKey.keyK ||
            event.logicalKey == LogicalKeyboardKey.keyN) {
          _opponentCommands?.shot(ShotType.power, spin: _opponentSpin);
        } else if (event.logicalKey == LogicalKeyboardKey.keyL ||
            event.logicalKey == LogicalKeyboardKey.keyB) {
          _opponentCommands?.shot(ShotType.lob);
        } else if (event.logicalKey == LogicalKeyboardKey.keyU ||
            event.logicalKey == LogicalKeyboardKey.keyV) {
          _opponentCommands?.shot(ShotType.drop);
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
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (_game!.state == GameState.waitingForServe &&
            identical(_game!.activeServer, _game!.player)) {
          _commands!.serve();
        } else {
          _commands!.shot(ShotType.normal, spin: _playerSpin);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyJ) {
        _commands!.shot(ShotType.normal, spin: _playerSpin);
      } else if (event.logicalKey == LogicalKeyboardKey.keyK) {
        _commands!.shot(ShotType.power, spin: _playerSpin);
      } else if (event.logicalKey == LogicalKeyboardKey.keyL) {
        _commands!.shot(ShotType.lob);
      } else if (event.logicalKey == LogicalKeyboardKey.keyU) {
        _commands!.shot(ShotType.drop);
      } else if (_isLocalMultiplayer &&
          !_isLanMultiplayer &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_game!.state == GameState.waitingForServe &&
            _game!.isOpponentHumanServing) {
          _opponentCommands!.serve();
        } else {
          _opponentCommands!.shot(ShotType.normal, spin: _opponentSpin);
        }
      } else if (_isLocalMultiplayer &&
          !_isLanMultiplayer &&
          event.logicalKey == LogicalKeyboardKey.keyM) {
        _opponentCommands!.shot(ShotType.normal, spin: _opponentSpin);
      } else if (_isLocalMultiplayer &&
          !_isLanMultiplayer &&
          event.logicalKey == LogicalKeyboardKey.keyN) {
        _opponentCommands!.shot(ShotType.power, spin: _opponentSpin);
      } else if (_isLocalMultiplayer &&
          !_isLanMultiplayer &&
          event.logicalKey == LogicalKeyboardKey.keyB) {
        _opponentCommands!.shot(ShotType.lob);
      } else if (_isLocalMultiplayer &&
          !_isLanMultiplayer &&
          event.logicalKey == LogicalKeyboardKey.keyV) {
        _opponentCommands!.shot(ShotType.drop);
      } else if (!_isLocalMultiplayer &&
          event.logicalKey == LogicalKeyboardKey.enter) {
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

    // Continuous movement keys
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (_isRemoteClient) {
      double p2x = 0, p2y = 0;
      if (keys.contains(LogicalKeyboardKey.keyA) ||
          keys.contains(LogicalKeyboardKey.arrowLeft)) {
        p2x -= 1;
      }
      if (keys.contains(LogicalKeyboardKey.keyD) ||
          keys.contains(LogicalKeyboardKey.arrowRight)) {
        p2x += 1;
      }
      if (keys.contains(LogicalKeyboardKey.keyW) ||
          keys.contains(LogicalKeyboardKey.arrowUp)) {
        p2y -= 1;
      }
      if (keys.contains(LogicalKeyboardKey.keyS) ||
          keys.contains(LogicalKeyboardKey.arrowDown)) {
        p2y += 1;
      }
      _moveFromScreenVector(
        _opponentCommands,
        Offset(p2x, p2y),
        farSide: true,
      );
      return;
    }

    double p1x = 0, p1y = 0;
    if (keys.contains(LogicalKeyboardKey.keyA)) p1x -= 1;
    if (keys.contains(LogicalKeyboardKey.keyD)) p1x += 1;
    if (keys.contains(LogicalKeyboardKey.keyW)) p1y -= 1;
    if (keys.contains(LogicalKeyboardKey.keyS)) p1y += 1;
    if (!_isLocalMultiplayer ||
        ((_isLanMultiplayer || _isOnlineMultiplayer) && _lanRole == 'host')) {
      if (keys.contains(LogicalKeyboardKey.arrowLeft)) p1x -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowRight)) p1x += 1;
      if (keys.contains(LogicalKeyboardKey.arrowUp)) p1y -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowDown)) p1y += 1;
    }
    _moveFromScreenVector(
      _commands,
      Offset(p1x, p1y),
      farSide: false,
    );
    if (_isLocalMultiplayer && !_isLanMultiplayer) {
      double p2x = 0, p2y = 0;
      if (keys.contains(LogicalKeyboardKey.arrowLeft)) p2x -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowRight)) p2x += 1;
      if (keys.contains(LogicalKeyboardKey.arrowUp)) p2y -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowDown)) p2y += 1;
      _moveFromScreenVector(
        _opponentCommands,
        Offset(p2x, p2y),
        farSide: true,
      );
    }
  }

  void _cycleSpectatorCamera() {
    final cameraController = _presentation?.cameraController;
    if (cameraController == null || !_isBotVsBot) return;
    setState(() {
      cameraController.cycleSpectatorView();
    });
    HapticFeedback.selectionClick();
  }

  void _onSwipeStart(DragStartDetails d) {
    _swipeStart = d.localPosition;
  }

  void _onSwipeUpdate(DragUpdateDetails d) {
    if (_swipeStart == null) return;
    final start = _swipeStart!;
    final delta = d.localPosition - start;
    if (delta.distance > 20) {
      final axes = _inputMapper?.commandAxesFromScreenDrag(
        origin: start,
        current: d.localPosition,
        farSide: _controlsFarSide,
      );
      if (axes != null) _activeTouchCommands?.aim(axes);
    }
  }

  void _onSwipeEnd(DragEndDetails d) {
    _swipeStart = null;
    _activeTouchCommands?.clearAim();
  }

  void _onSpectatorScaleStart(ScaleStartDetails details) {
    _spectatorGesturePoint = details.focalPoint;
    _spectatorGestureScale = 1;
  }

  void _onSpectatorScaleUpdate(ScaleUpdateDetails details) {
    final cameraController = _presentation?.cameraController;
    final previousPoint = _spectatorGesturePoint;
    if (cameraController == null ||
        previousPoint == null ||
        cameraController.view != CameraView.freeRoam) {
      return;
    }
    final delta = details.focalPoint - previousPoint;
    final scaleDelta = details.scale / _spectatorGestureScale;
    cameraController.adjustFreeRoam(
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
    _presentation!.resize(size);

    return PopScope(
      canPop: game.state == GameState.gameOver,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestLeaveMatch();
      },
      child: Scaffold(
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
                // ── Dynamic 360° Panorama Court Environment Backdrop ────────
                Positioned.fill(
                  child: _presentation != null
                      ? CourtBackdropView(
                          game: game,
                          presentation: _presentation!,
                          repaint: _tickNotifier,
                        )
                      : Image.asset(
                          game.settings.courtTheme.assetPath,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                ),

                // ── 3D Court — isolated RepaintBoundary with direct repaint Listenable ───
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: CourtPainter(
                        game: game,
                        presentation: _presentation!,
                        repaint: _tickNotifier,
                      ),
                    ),
                  ),
                ),

                // ── HUD overlay ─────────────────────────────────────
                _buildHUD(game, isLandscape: isLandscape),

                ValueListenableBuilder<int>(
                  valueListenable: _tickNotifier,
                  builder: (_, __, ___) => _buildTimingFeedback(game, size),
                ),

                // ── Pause menu overlay ──────────────────────────────
                if (game.isPaused) _buildPauseMenu(game),

                if (_onlineConnectionInterrupted &&
                    !_onlineDisconnectDialogVisible)
                  const _OnlineReconnectOverlay(),

                // ── Serve prompt (only updates on state changes) ─────
                ValueListenableBuilder<GameState>(
                  valueListenable: _stateNotifier,
                  builder: (_, state, ___) {
                    if (!_isBotVsBot && state == GameState.waitingForServe) {
                      return _buildServePrompt(game, isLandscape: isLandscape);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestLeaveMatch() async {
    final game = _game;
    if (game == null) return;
    final wasPaused = game.isPaused;
    if (!wasPaused) game.pause();
    final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF0F1E36),
            title: const Text('LEAVE MATCH?',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            content: const Text(
              'Your current match progress will be lost.',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('KEEP PLAYING'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('LEAVE'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted) return;
    if (leave) {
      if (_isOnlineMultiplayer) {
        await OnlineMultiplayerService.instance.leaveRoom();
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/menu', (_) => false);
    } else if (!wasPaused) {
      game.resume();
      setState(() {});
    }
  }

  Widget _buildHUD(PickleballGame game, {required bool isLandscape}) {
    final size = MediaQuery.of(context).size;
    final settings = context.watch<GameSettings>();
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
                      : (_isLocalMultiplayer
                          ? (_isLanMultiplayer
                              ? 'LAN ${_lanRole == 'host' ? 'HOST' : 'CLIENT'} ${game.gameMode == GameMode.doubles ? '2v2' : '1v1'}'
                              : (_isOnlineMultiplayer
                                  ? 'ONLINE ${OnlineMultiplayerService.instance.isPeerToPeerConnected ? 'P2P' : 'FIREBASE'} ${game.gameMode == GameMode.doubles ? '2v2' : '1v1'}'
                                  : 'LOCAL ${game.gameMode == GameMode.doubles ? '2v2' : '1v1'}'))
                          : (_isBotVsBot
                              ? 'BOT VS BOT'
                              : (game.gameMode == GameMode.doubles
                                  ? 'DOUBLES'
                                  : 'SINGLES'))),
                  opponentName: _isLocalMultiplayer
                      ? (_isLanMultiplayer
                          ? (_lanRole == 'host' ? 'CLIENT' : 'HOST')
                          : 'PLAYER 2')
                      : 'LORINE',
                  footer: _isBotVsBot || _isLocalMultiplayer
                      ? null
                      : _buildPlayerStatusCard(game),
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
                label: _presentation!.cameraController.view.label,
                onTap: _cycleSpectatorCamera,
              ),
            ),

          if (_isBotVsBot &&
              _presentation!.cameraController.view == CameraView.freeRoam)
            const Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(child: _FreeRoamHint()),
            ),

          if (_isLocalMultiplayer)
            Positioned(
              top: isLandscape ? 10 : 72,
              left: 0,
              right: 0,
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _tickNotifier,
                  builder: (_, __, ___) {
                    final isClient = _isRemoteClient;
                    final playerTwo =
                        isClient || _activeTouchCommands == _opponentCommands;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xDC0B1930),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: playerTwo
                              ? const Color(0xFFE85D2A)
                              : const Color(0xFF38BDF8),
                        ),
                      ),
                      child: Text(
                        _isLanMultiplayer
                            ? (isClient
                                ? 'CLIENT (P2) • LAN MATCH'
                                : 'HOST (P1) • LAN MATCH')
                            : _isOnlineMultiplayer
                                ? '${isClient ? 'CHALLENGER (P2)' : 'HOST (P1)'} • ${OnlineMultiplayerService.instance.isPeerToPeerConnected ? 'DIRECT P2P' : 'FIREBASE FALLBACK'}'
                                : '${playerTwo ? 'P2' : 'P1'} TOUCH CONTROL',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Virtual Joystick (bottom left) ────────────────
          if (!_isBotVsBot && settings.dynamicJoystick && !_customizingControls)
            Positioned(
              left: 0,
              top: size.height * 0.28,
              bottom: 0,
              width: size.width * 0.48,
              child: DynamicJoystick(
                size: joystickSize,
                onDrag: _onJoystickDrag,
                onRelease: _onJoystickRelease,
                sensitivity: settings.joystickSensitivity,
              ),
            ),
          if (!_isBotVsBot &&
              (!settings.dynamicJoystick || _customizingControls))
            Positioned(
              left: settings.joystickHudPosition.dx * size.width -
                  joystickSize / 2,
              top: settings.joystickHudPosition.dy * size.height -
                  joystickSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _customizingControls
                    ? (details) {
                        final next = settings.joystickHudPosition +
                            Offset(
                              details.delta.dx / size.width,
                              details.delta.dy / size.height,
                            );
                        settings.setJoystickHudPosition(next);
                      }
                    : null,
                child: IgnorePointer(
                  ignoring: _customizingControls,
                  child: VirtualJoystick(
                    size: joystickSize,
                    onMove: _onJoystickMove,
                    onRelease: _onJoystickRelease,
                    sensitivity: settings.joystickSensitivity,
                  ),
                ),
              ),
            ),

          // ── Compact Ergonomic Action Buttons (bottom right) ──
          if (!_isBotVsBot)
            Positioned(
              left: settings.actionsHudPosition.dx * size.width - 90,
              top: settings.actionsHudPosition.dy * size.height - 70,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _customizingControls
                    ? (details) {
                        final next = settings.actionsHudPosition +
                            Offset(
                              details.delta.dx / size.width,
                              details.delta.dy / size.height,
                            );
                        settings.setActionsHudPosition(next);
                      }
                    : null,
                child: IgnorePointer(
                  ignoring: _customizingControls,
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<GameState>(
                      valueListenable: _stateNotifier,
                      builder: (_, __, ___) => _buildActionButtons(
                        game,
                        isLandscape: isLandscape,
                        screenHeight: size.height,
                        forceShowAll: _customizingControls,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_customizingControls)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<SettingsService>().save(settings);
                    setState(() => _customizingControls = false);
                    game.resume();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('SAVE CONTROL LAYOUT'),
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
                          color:
                              isLow ? AppColors.power : const Color(0xFFD4E157),
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
      {required bool isLandscape, double screenHeight = 400, bool forceShowAll = false}) {
    final isServing = !forceShowAll && _localPlayerCanServe(game);

    // In landscape, derive button sizes from screen height so they scale
    // proportionally across all mobile device sizes (phones ~320-420px tall)
    double smallBtnSize, powerBtnSize, ultBtnSize, hitBtnSize;
    double btnSpacing, rowSpacing;

    if (isLandscape) {
      // ~46% of screen height for the whole cluster height
      // Distribute: top row uses smaller btns, bottom row uses larger btns
      final clusterH = (screenHeight * 0.82).clamp(180.0, 340.0);
      // HIT / ULT are ~half the cluster, top row buttons ~38% of cluster
      hitBtnSize = (clusterH * 0.46).clamp(52.0, 80.0);
      ultBtnSize = (clusterH * 0.42).clamp(48.0, 72.0);
      powerBtnSize = (clusterH * 0.34).clamp(40.0, 60.0);
      smallBtnSize = (clusterH * 0.30).clamp(36.0, 54.0);
      btnSpacing = (screenHeight * 0.025).clamp(5.0, 10.0);
      rowSpacing = (screenHeight * 0.020).clamp(4.0, 8.0);
    } else {
      smallBtnSize = 40.0;
      powerBtnSize = 44.0;
      ultBtnSize = 54.0;
      hitBtnSize = UISizes.hitButtonSize;
      btnSpacing = 6.0;
      rowSpacing = 6.0;
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
            onTap: () => _activeTouchCommands?.serve(),
          ),
        ],
      );
    }

    // In-play rally: 2-tier ergonomic thumb cluster
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SpinSelector(
          selected: _activeSpin,
          compact: isLandscape && screenHeight < 390,
          onSelected: _setActiveSpin,
        ),
        SizedBox(height: rowSpacing),
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
              onTap: () => _activeTouchCommands?.shot(ShotType.drop),
            ),
            SizedBox(width: btnSpacing),
            GameButton(
              label: 'LOB',
              icon: Icons.north_east_rounded,
              size: smallBtnSize,
              color: const Color(0xFF8B5CF6),
              glowColor: const Color(0x448B5CF6),
              onTap: () => _activeTouchCommands?.shot(ShotType.lob),
            ),
            SizedBox(width: btnSpacing),
            GameButton(
              label: 'POWER',
              icon: Icons.bolt_rounded,
              size: powerBtnSize,
              color: AppColors.power,
              glowColor: AppColors.powerGlow,
              onTap: () => _activeTouchCommands?.shot(
                ShotType.power,
                spin: _activeSpin,
              ),
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
              onTap: () => _activeTouchCommands?.shot(
                ShotType.normal,
                spin: _activeSpin,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimingFeedback(PickleballGame game, Size size) {
    final feedback = game.contactFeedback;
    if (feedback == null || feedback.remaining <= 0) {
      return const SizedBox.shrink();
    }
    final point = _presentation?.camera.project(feedback.position);
    if (point == null) return const SizedBox.shrink();
    final color = switch (feedback.grade) {
      SwingTimingGrade.perfect => const Color(0xFFFFD54F),
      SwingTimingGrade.good => const Color(0xFF4ADE80),
      SwingTimingGrade.early => const Color(0xFFFBBF24),
      SwingTimingGrade.late => const Color(0xFFFB7185),
    };
    final opacity = (feedback.remaining / 0.18).clamp(0.0, 1.0).toDouble();
    final left = (point.dx - 42).clamp(4.0, size.width - 88).toDouble();
    final top = (point.dy - 22).clamp(4.0, size.height - 34).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Container(
            key: const ValueKey('swing-timing-feedback'),
            width: 84,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xDD081426),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
            ),
            child: Text(
              feedback.grade.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Ultimate Action Button ────────────────────────────────────
  Widget _buildUltimateButton(PickleballGame game, {double size = 54.0}) {
    if (!game.specialSkillsEnabled ||
        !game.settings.hasEquippedPaddleSkill) {
      return const SizedBox.shrink();
    }
    return _UltimateButtonWidget(
      game: game,
      size: size,
      ultimateNotifier: _ultimateNotifier,
      onToggleArm: () => _activeTouchCommands?.toggleUltimate(),
      onArmToggled: () => setState(() {}),
    );
  }

  // ── Ultimate Skill Selector Modal ─────────────────────────────
  // Retained temporarily for save compatibility; there is no UI path to it.
  // ignore: unused_element
  void _showUltimateSelectorModal(BuildContext context, PickleballGame game) {
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                                      color: skill.primaryColor.withAlpha(35),
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
                                            settings.equipUltimate(skill.type);
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
                                        borderRadius: BorderRadius.circular(12),
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
                                  _buildMiniStat(
                                      'POWER', skill.power, skill.primaryColor),
                                  const SizedBox(width: 10),
                                  _buildMiniStat(
                                      'SPEED', skill.speed, skill.primaryColor),
                                  const SizedBox(width: 10),
                                  _buildMiniStat(
                                      'CURVE', skill.curve, skill.primaryColor),
                                  const SizedBox(width: 10),
                                  _buildMiniStat('DECEPTION', skill.deception,
                                      skill.primaryColor),
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
      onCustomizeControls: () => setState(() {
        _customizingControls = true;
        game.resume();
      }),
      onMainMenu: _requestLeaveMatch,
    );
  }

  Widget _buildServePrompt(PickleballGame game, {required bool isLandscape}) {
    final canServe = _localPlayerCanServe(game);
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
              Text(
                canServe ? 'SERVE TO HIGHLIGHTED BOX' : 'OPPONENT SERVING',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (canServe) const SizedBox(width: 8),
              if (canServe)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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

class _SpinSelector extends StatelessWidget {
  const _SpinSelector({
    required this.selected,
    required this.compact,
    required this.onSelected,
  });

  final ShotSpin selected;
  final bool compact;
  final ValueChanged<ShotSpin> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Shot spin',
      child: Container(
        key: const ValueKey('shot-spin-selector'),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xDD071426),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x6647BFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ShotSpin.values.map((spin) {
            final active = spin == selected;
            return Semantics(
              button: true,
              selected: active,
              label: '${spin.label} spin',
              child: InkWell(
                key: ValueKey('shot-spin-${spin.name}'),
                borderRadius: BorderRadius.circular(11),
                onTap: () => onSelected(spin),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 10,
                    vertical: compact ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF087FB5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    spin.label,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFFAFC5D9),
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _OnlineReconnectOverlay extends StatelessWidget {
  const _OnlineReconnectOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC071426),
        child: AbsorbPointer(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E36),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'CONNECTION INTERRUPTED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Waiting briefly for your opponent to reconnect…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            ),
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
  final VoidCallback onToggleArm;
  final VoidCallback onArmToggled;

  const _UltimateButtonWidget({
    required this.game,
    required this.size,
    required this.ultimateNotifier,
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
                Provider.of<AudioService>(context, listen: false)
                    .playButtonClick();
              } catch (_) {}
              if (isReady) {
                HapticFeedback.heavyImpact();
                widget.onToggleArm();
                widget.onArmToggled();
              }
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
