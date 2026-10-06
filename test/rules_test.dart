import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/game/score_controller.dart';
import 'package:pickleball_3d/game/ball_controller.dart';
import 'package:pickleball_3d/game/physics_controller.dart';
import 'package:pickleball_3d/game/ai_controller.dart';
import 'package:pickleball_3d/services/audio_service.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/models/shop_items.dart';
import 'package:pickleball_3d/models/ultimate_skill.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Pickleball Court & Serving Rules', () {
    test('Service diagonal & kitchen clearance validation', () {
      final court = Court();
      // Human serving from right box (x > 0)
      // Opponent AI court is z in [-88, 0], AI Kitchen is [-28, 0]
      // Valid landing must be in AI right box (which is x < 0 from player perspective, z < -28)

      // Inside Kitchen on AI side (fault)
      expect(court.isValidServiceBox(-15, -15, true), isFalse,
          reason: 'Serve inside kitchen should be a fault');

      // AI left side when serving from right (fault - wrong diagonal)
      expect(court.isValidServiceBox(15, -45, true), isFalse,
          reason: 'Serve to wrong diagonal quadrant should be a fault');

      // Correct diagonal quadrant past kitchen (legal serve)
      expect(court.isValidServiceBox(-15, -45, true), isTrue,
          reason: 'Serve to correct diagonal past kitchen should be legal');

      // Human serving from left box (serverOnRight = false)
      // Legal landing should be x > 0 and z < -28
      expect(court.isValidServiceBox(15, -45, false), isTrue,
          reason: 'Serve from left box to diagonal right box should be legal');
      expect(court.isValidServiceBox(-15, -45, false), isFalse,
          reason: 'Serve from left box to diagonal left box should be a fault');
    });

    test('Kitchen boundary detection for players', () {
      final playerInKitchen = Player(
        startPosition: Vec3(0, 0, 15), // Inside human kitchen (0 to 28)
        isHuman: true,
      );
      expect(playerInKitchen.isInKitchen(), isTrue);

      final playerDeep = Player(
        startPosition: Vec3(0, 0, 60), // Outside kitchen
        isHuman: true,
      );
      expect(playerDeep.isInKitchen(), isFalse);
    });

    test('Serve setup stays outside baseline and on score-correct side', () {
      final settings = GameSettings();
      final game = PickleballGame(
        screenSize: const Size(800, 450),
        settings: settings,
      );

      expect(game.player.position.z, greaterThan(CourtDimensions.halfLength));
      expect(game.ball.position.z, greaterThan(CourtDimensions.halfLength));
      expect(game.player.position.x, greaterThan(0),
          reason: 'An even-score player server starts on the right');

      game.setJoystick(0, -1);
      game.update(0.25);
      expect(
        game.player.position.z,
        CourtDimensions.halfLength + CourtDimensions.serveBaselineOffset,
        reason: 'Forward input cannot carry the server onto the court',
      );

      game.scoreController.awardPlayerPoint();
      game.update(0.016);
      expect(game.player.position.x, lessThan(0),
          reason: 'An odd-score player server is restricted to the left');
      expect(game.ball.position.x, game.player.position.x);

      game.dispose();
    });

    test('Player and AI serve balls reset completely outside each baseline',
        () {
      final ball = Pickleball();

      ball.resetForPlayerServe(fromRight: true);
      expect(ball.position.z, greaterThan(CourtDimensions.halfLength));
      expect(ball.position.x, greaterThan(0));

      ball.resetForAIServe(fromRight: true);
      expect(ball.position.z, lessThan(-CourtDimensions.halfLength));
      expect(ball.position.x, lessThan(0),
          reason: 'The AI right court is mirrored from the player camera');
    });

    test('Serve preview is legal, parabolic, and matches launch velocity', () {
      final game = PickleballGame(
        screenSize: const Size(800, 450),
        settings: GameSettings(),
      );
      final preview = game.getPlayerServeTrajectory(samples: 20);

      expect(preview.isLegal, isTrue);
      expect(preview.targetX, lessThan(0),
          reason: 'A right-side server targets the opposite service court');
      expect(preview.targetZ, lessThan(-CourtDimensions.kitchenDepth));
      expect(preview.points.first.z, greaterThan(CourtDimensions.halfLength));
      expect(preview.points.last.x, closeTo(preview.targetX, 0.001));
      expect(preview.points.last.z, closeTo(preview.targetZ, 0.001));
      expect(
        preview.points.map((point) => point.y).reduce((a, b) => a > b ? a : b),
        greaterThan(preview.points.first.y),
      );

      game.setServePressed(true);
      game.update(0.016);
      expect(game.ball.velocity.x, closeTo(preview.launchVelocity.x, 0.001));
      expect(game.ball.velocity.y, closeTo(preview.launchVelocity.y, 0.001));
      expect(game.ball.velocity.z, closeTo(preview.launchVelocity.z, 0.001));

      game.dispose();
    });
  });

  group('Two-Bounce Rule & Volley Constraints', () {
    test('Ball tracks rallyHitCount and restricts early volleys', () {
      final ball = Pickleball();

      // Reset for serve
      ball.resetForPlayerServe(fromRight: true);
      expect(ball.rallyHitCount, 0);
      expect(ball.canVolley, isFalse,
          reason: 'Receiver cannot volley the serve (1st bounce required)');

      // Receiver hits return of serve
      ball.rallyHitCount = 1;
      expect(ball.canVolley, isFalse,
          reason: 'Server cannot volley the return (2nd bounce required)');

      // 3rd shot onwards: volleys are permitted
      ball.rallyHitCount = 2;
      expect(ball.canVolley, isTrue,
          reason: 'After two bounces in the rally, volleys are permitted');

      ball.rallyHitCount = 5;
      expect(ball.canVolley, isTrue);
    });

    test('Court bounce briefly delays paddle contact', () {
      final ball = Pickleball()
        ..state = BallState.inFlight
        ..position = Vec3(0, PhysicsConstants.ballRadius, 40)
        ..velocity = Vec3(0, -8, 0);
      final controller = BallController(ball: ball, court: Court());

      controller.update(0.016);

      expect(ball.hasBounced, isTrue);
      expect(ball.canBeHitAfterBounce, isFalse);
      expect(ball.postBounceHitLockTimer,
          closeTo(PhysicsConstants.postBounceHitDelay, 0.0001));

      controller.update(PhysicsConstants.postBounceHitDelay);
      expect(ball.canBeHitAfterBounce, isTrue);
    });

    test('Bots keep a random catalog paddle for the whole match', () {
      final game = PickleballGame(
        settings: GameSettings(),
        paddleRandom: math.Random(7),
      );

      final assigned = game.aiPaddle;
      expect(kPaddleCatalog, contains(assigned));
      expect(game.paddleFor(game.ai), same(assigned));
      expect(game.paddleFor(game.ai), same(assigned));
      expect(game.paddleFor(game.player), same(game.currentPaddle));

      game.dispose();
    });
  });

  group('Score Controller & Win-By-2 Rule', () {
    test('Standard game to 11 requires a 2-point lead', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: false,
      );

      // Simulate 10-10 tie
      player.score = 10;
      ai.score = 10;
      expect(scoreCtrl.isGameOver, isFalse);

      // 11-10 is NOT game over (win by 2 required)
      player.score = 11;
      ai.score = 10;
      expect(scoreCtrl.isGameOver, isFalse,
          reason: 'Game should not end at 11-10 because win-by-2 is required');

      // AI ties 11-11
      ai.score = 11;
      expect(scoreCtrl.isGameOver, isFalse);

      // Player reaches 12-11
      player.score = 12;
      ai.score = 11;
      expect(scoreCtrl.isGameOver, isFalse);

      // Player reaches 13-11 (2-point lead!)
      player.score = 13;
      ai.score = 11;
      expect(scoreCtrl.isGameOver, isTrue);
      expect(player.score > ai.score, isTrue);
    });

    test('Server side alternates based on server score', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: false,
      );

      // Even score (0): server on right
      player.score = 0;
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);

      player.score = 1;
      expect(scoreCtrl.serverShouldBeOnRight, isFalse);

      player.score = 2;
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);
    });
  });

  group('Stamina System & Shot Types', () {
    test('Stamina deductions and regeneration', () {
      final player = Player(
        startPosition: Vec3(0, 0, 60),
        isHuman: true,
      );

      expect(player.stamina, 1.0);

      // Power shot costs 0.35
      final usedPower = player.useStamina(StaminaConstants.powerShotCost);
      expect(usedPower, isTrue);
      expect(player.stamina, closeTo(0.65, 0.001));

      // Lob shot costs 0.15
      final usedLob = player.useStamina(StaminaConstants.lobShotCost);
      expect(usedLob, isTrue);
      expect(player.stamina, closeTo(0.50, 0.001));

      // Drop shot costs 0.10
      final usedDrop = player.useStamina(StaminaConstants.dropShotCost);
      expect(usedDrop, isTrue);
      expect(player.stamina, closeTo(0.40, 0.001));

      // Cannot spend more than available
      expect(player.useStamina(0.50), isFalse);
      expect(player.stamina, closeTo(0.40, 0.001));

      // Stamina regenerates over time
      player.regenStamina(1.0); // 1 second * 0.22/s
      expect(player.stamina, closeTo(0.62, 0.001));
    });
  });

  group('Game Modes (Singles vs Doubles)', () {
    test('Singles mode initializes 2 players', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        gameMode: GameMode.singles,
        settings: GameSettings(),
      );
      expect(game.gameMode, GameMode.singles);
      expect(game.playerPartner, isNull);
      expect(game.aiPartner, isNull);
      expect(game.player, isNotNull);
      expect(game.ai, isNotNull);
    });

    test('Doubles mode initializes 4 players with assigned positions', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        gameMode: GameMode.doubles,
        settings: GameSettings(),
      );
      expect(game.gameMode, GameMode.doubles);
      expect(game.playerPartner, isNotNull);
      expect(game.aiPartner, isNotNull);
      expect(game.player, isNotNull);
      expect(game.ai, isNotNull);

      // Player partner is human team partner
      expect(game.playerPartner!.isPartner, isTrue);
      // AI partner is opponent AI
      expect(game.aiPartner!.isPartner, isFalse);
      expect(game.aiPartner!.isHuman, isFalse);
    });
  });

  group('Physics & Ball Bounce Fixes', () {
    test('Ball bounces upward on ground collision', () {
      final ball = Pickleball();
      final court = Court();
      final controller = BallController(ball: ball, court: court);

      // Ball is falling toward the court surface
      ball.position = Vec3(0, 5, 0);
      ball.velocity = Vec3(0, -30, 0);
      ball.state = BallState.inFlight;

      for (var i = 0; i < 3 && !ball.hasBounced; i++) {
        controller.update(0.1);
      }

      expect(ball.velocity.y, greaterThan(0),
          reason:
              'Ball vertical velocity must be positive after ground contact');
      expect(ball.hasBounced, isTrue);
      expect(ball.bounceCount, 1);
    });

    test('Player serve lands inside regulation diagonal service box', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        gameMode: GameMode.singles,
        settings: GameSettings(),
      );

      // Player serves from right box (x > 0)
      game.setServePressed(true);
      game.update(0.016); // Processes serve

      expect(game.ball.state, BallState.inFlight);
      expect(game.ball.velocity.z, lessThan(0),
          reason: 'Serve must travel toward AI');

      // Simulate flight until ground contact
      const dt = 0.016;
      for (int i = 0; i < 140; i++) {
        game.update(dt);
        if (game.ball.hasBounced) break;
      }

      expect(game.ball.hasBounced, isTrue,
          reason: 'Serve should reach the ground');
      expect(
          game.court.isInsideCourt(game.ball.position.x, game.ball.lastBounceZ),
          isTrue,
          reason: 'Serve must not overshoot court bounds');
      expect(
          game.court.isValidServiceBox(
              game.ball.position.x, game.ball.lastBounceZ, true),
          isTrue,
          reason:
              'Serve must land legally in the AI diagonal box past the kitchen');
    });

    test('Legal winner awards point to the striker', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl =
          ScoreController(player: player, ai: ai, isPracticeMode: false);
      final court = Court();
      final ball = Pickleball();

      // Player strikes ball deep into AI court
      ball.state = BallState.inFlight;
      ball.lastHitByPlayer = true;
      ball.isServe = false;
      ball.position = Vec3(-10, 0, -50); // Inside AI court

      // 1st bounce in court
      ball.bounceCount = 1;
      ball.hasBounced = true;
      ball.lastBounceZ = -50;
      ball.playerSideBounce = false;

      // 2nd bounce (AI fails to reach it)
      ball.bounceCount = 2;
      final result = scoreCtrl.checkPoint(ball, court);
      expect(result, PointResult.playerPoint,
          reason:
              'When ball bounces twice on AI side, player must be awarded the point');
    });
  });

  group('Ultimate Skill System & Energy Mechanics', () {
    test('SP gauge accumulation, capping, and readiness', () {
      final settings = GameSettings();
      settings.buyPaddle(getPaddleById('paddle_thunder'));
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
      );

      // Gauge starts at initial charge
      expect(game.ultimateCharge, greaterThanOrEqualTo(0.40));
      expect(game.isUltimateReady, isFalse);

      // Add partial charge
      game.addUltimateCharge(0.30);
      expect(game.ultimateCharge, closeTo(0.75, 0.01));

      // Add exceeding charge — must cap at 1.0
      game.addUltimateCharge(0.50);
      expect(game.ultimateCharge, 1.0);
      expect(game.isUltimateReady, isTrue);

      // Arming ultimate
      game.toggleArmUltimate();
      expect(game.isUltimateArmed, isTrue);

      // Toggling off
      game.toggleArmUltimate();
      expect(game.isUltimateArmed, isFalse);
    });

    test('All 4 Ultimate Skills exist with complete stats and unique perks',
        () {
      expect(kAllUltimateSkills.length, 4);

      for (final skill in kAllUltimateSkills) {
        expect(skill.name.isNotEmpty, isTrue);
        expect(skill.shortName.isNotEmpty, isTrue);
        expect(skill.tagline.isNotEmpty, isTrue);
        expect(skill.description.isNotEmpty, isTrue);
        expect(skill.power, greaterThan(0));
        expect(skill.speed, greaterThan(0));
      }

      final thunder = getUltimateByType(UltimateType.thunderbolt);
      expect(thunder.name, contains('LIGHTNING'));

      final ghost = getUltimateByType(UltimateType.ghostPhantom);
      expect(ghost.name, contains('PHANTOM'));

      final dragon = getUltimateByType(UltimateType.dragonMeteor);
      expect(dragon.name, contains('FIREBALL'));

      final frost = getUltimateByType(UltimateType.frostbite);
      expect(frost.name, contains('ICE'));
    });

    test('equipping a signature paddle determines the special skill', () {
      final settings = GameSettings();
      expect(settings.hasEquippedPaddleSkill, isFalse);

      settings.buyPaddle(getPaddleById('paddle_cyber'));
      expect(settings.equippedUltimate, UltimateType.ghostPhantom);

      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
      );
      expect(game.equippedUltimate, UltimateType.ghostPhantom);
      expect(game.currentUltimate.name, contains('PHANTOM'));
    });
  });

  group('Training Mode & Ultra-Hard AI Rules', () {
    test('Training Mode never increments scores on player or AI points', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: true,
      );

      expect(player.score, 0);
      expect(ai.score, 0);

      // Award player points multiple times
      for (int i = 0; i < 15; i++) {
        scoreCtrl.awardPlayerPoint();
      }
      expect(player.score, 0,
          reason: 'Player score must not increment in training mode');
      expect(ai.score, 0,
          reason: 'AI score must not increment in training mode');
      expect(scoreCtrl.isGameOver, isFalse,
          reason: 'Training mode should never end from score');

      // Award AI points multiple times
      for (int i = 0; i < 15; i++) {
        scoreCtrl.awardAIPoint();
      }
      expect(player.score, 0);
      expect(ai.score, 0);
      expect(scoreCtrl.isGameOver, isFalse);
    });

    test('Training Mode alternates serve sides using practiceServeCount', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: true,
      );

      // Initial serve is right side (count 0)
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);

      scoreCtrl.awardPlayerPoint();
      // Next serve is left side (count 1)
      expect(scoreCtrl.serverShouldBeOnRight, isFalse);

      scoreCtrl.awardAIPoint();
      // Next serve is right side (count 2)
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);
    });

    test('Drills enforce designated server: Return Drill locks AI serve', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: true,
        drillType: 'return_drill',
      );

      // AI serves in return drill
      expect(scoreCtrl.isPlayerServing, isFalse);

      // Even if player wins the rally, AI continues serving in return drill
      scoreCtrl.awardPlayerPoint();
      expect(scoreCtrl.isPlayerServing, isFalse);
    });

    test('AIController operates at ultra-hard difficulty in Training Mode', () {
      final ai = Player(startPosition: Vec3(0, 0, -60), isHuman: false);
      final ball = Pickleball();
      final court = Court();
      final settings = GameSettings();

      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: court,
        settings: settings,
        isPracticeMode: true,
      );

      // Speed must be significantly higher than standard hard (110.0)
      expect(aiCtrl.effectiveSpeed, 145.0);
      // Reaction time must be near-instantaneous
      expect(aiCtrl.effectiveReactionTime, 0.02);
      // Accuracy must be elite
      expect(aiCtrl.effectiveAccuracy, 0.98);
      // Unforced error chance must be zero
      expect(aiCtrl.effectiveErrorChance, 0.0);

      // In practice mode, stamina is kept replenished
      ai.useStamina(0.8);
      expect(ai.stamina, lessThan(1.0));
      aiCtrl.update(0.016);
      expect(ai.stamina, 1.0,
          reason: 'AI must have infinite stamina in practice mode');
    });
  });

  group('Audio Service & Background Music', () {
    test('AudioService handles volume clamping and playback state safely', () {
      final audioService = AudioService();
      expect(audioService.musicVolume, 0.7);
      expect(audioService.sfxVolume, 0.8);

      // Volume adjustments
      audioService.setMusicVolume(0.5);
      expect(audioService.musicVolume, 0.5);

      audioService.setMusicVolume(1.5);
      expect(audioService.musicVolume, 1.0, reason: 'Volume must clamp to 1.0');

      audioService.setMusicVolume(-0.2);
      expect(audioService.musicVolume, 0.0, reason: 'Volume must clamp to 0.0');

      audioService.setSfxVolume(0.6);
      expect(audioService.sfxVolume, 0.6);

      // Safe call verification (handles uninitialized state gracefully)
      audioService.playBGM();
      audioService.handleUserInteraction();
      audioService.pauseBGM();
      audioService.resumeBGM();
      audioService.stopBGM();
      audioService.playHit();
      audioService.playHit(isPower: true);
      audioService.playBounce();
      audioService.playNetHit();
      audioService.playButtonClick();
      audioService.playCrowdCheer();
      audioService.playVictory();
      audioService.playDefeat();
      audioService.dispose();
    });

    test(
        'PickleballGame triggers hit and bounce sound effects via AudioService',
        () {
      final fakeAudio = _FakeAudioService();
      final settings = GameSettings();
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
        audioService: fakeAudio,
      );

      expect(fakeAudio.hitCount, 0);
      expect(fakeAudio.bounceCount, 0);

      // 1. Serve triggers paddle hit sound
      game.setServePressed(true);
      game.update(0.016);
      expect(fakeAudio.hitCount, 1,
          reason: 'Serving the ball must play paddle hit SFX');
      expect(fakeAudio.powerHitCount, 0,
          reason: 'Serve is a normal hit, not a power smash');

      // 2. Ball flight to ground triggers court bounce sound
      for (int i = 0; i < 140; i++) {
        game.update(0.016);
        if (fakeAudio.bounceCount > 0) break;
      }
    });
  });

  group('Official USA Pickleball Rulebook Specifications', () {
    test(
        'Sideout scoring: only serving team scores; receiving rally win causes sideout',
        () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: false,
      );

      // Singles has one server; 0-0-2 is a doubles-only announcement.
      expect(scoreCtrl.serverNumber, 1);
      expect(scoreCtrl.isPlayerServing, isTrue);

      // Serving team (player) wins rally -> score increases, keeps serve
      expect(scoreCtrl.awardPlayerPoint(), isTrue);
      expect(player.score, 1);
      expect(ai.score, 0);
      expect(scoreCtrl.isPlayerServing, isTrue);

      // Opponent (AI - receiving team) wins next rally -> sideout! AI serves, but AI score remains 0
      expect(scoreCtrl.awardAIPoint(), isFalse);
      expect(ai.score, 0,
          reason: 'Receiving team does not score a point on sideout');
      expect(scoreCtrl.isPlayerServing, isFalse,
          reason: 'Serve passes to AI (sideout)');
      expect(scoreCtrl.serverNumber, 1,
          reason: 'After sideout, new serving team starts with server 1');

      // AI serving wins rally -> AI scores a point
      scoreCtrl.awardAIPoint();
      expect(ai.score, 1, reason: 'Serving team scores when winning a rally');
    });

    test('Doubles rotates server 1 to server 2 before a sideout', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: false,
        gameMode: GameMode.doubles,
      );

      expect(scoreCtrl.serverNumber, 2, reason: 'Doubles opens at 0-0-2');

      // Opening server 2 loses, so the serve crosses to the opponent team.
      expect(scoreCtrl.awardAIPoint(), isFalse);
      expect(scoreCtrl.isPlayerServing, isFalse);
      expect(scoreCtrl.serverNumber, 1);

      // Opponent server 1 loses: teammate becomes server 2, no sideout yet.
      expect(scoreCtrl.awardPlayerPoint(), isFalse);
      expect(scoreCtrl.isPlayerServing, isFalse);
      expect(scoreCtrl.serverNumber, 2);

      // Opponent server 2 loses: now the player team receives the serve.
      expect(scoreCtrl.awardPlayerPoint(), isFalse);
      expect(scoreCtrl.isPlayerServing, isTrue);
      expect(scoreCtrl.serverNumber, 1);
      expect(player.score, 0);
      expect(ai.score, 0);
    });

    test('Doubles tracks server identity and court side through rotation', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: false,
        gameMode: GameMode.doubles,
      );

      expect(scoreCtrl.serverNumber, 2);
      expect(scoreCtrl.servingPrimary, isTrue);
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);

      // The opening server scores and swaps to the left service court.
      expect(scoreCtrl.awardPlayerPoint(), isTrue);
      expect(scoreCtrl.playerPrimaryOnRight, isFalse);
      expect(scoreCtrl.servingPrimary, isTrue);
      expect(scoreCtrl.serverShouldBeOnRight, isFalse);

      // Opening server 2 loses: sideout to opponent server 1.
      expect(scoreCtrl.awardAIPoint(), isFalse);
      expect(scoreCtrl.isPlayerServing, isFalse);
      expect(scoreCtrl.serverNumber, 1);
      expect(scoreCtrl.servingPrimary, isTrue);
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);

      // Server 1 loses. Partner becomes server 2 without swapping sides.
      expect(scoreCtrl.awardPlayerPoint(), isFalse);
      expect(scoreCtrl.serverNumber, 2);
      expect(scoreCtrl.servingPrimary, isFalse);
      expect(scoreCtrl.serverShouldBeOnRight, isFalse);

      // Server 2 scores, keeps the serve, and swaps to the right court.
      expect(scoreCtrl.awardAIPoint(), isTrue);
      expect(ai.score, 1);
      expect(scoreCtrl.aiPrimaryOnRight, isFalse);
      expect(scoreCtrl.servingPrimary, isFalse);
      expect(scoreCtrl.serverShouldBeOnRight, isTrue);
    });

    test('Doubles ally automatically serves when it owns server 2', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        gameMode: GameMode.doubles,
      );

      // Opening player server 2 loses, then both opponent servers lose.
      game.scoreController.awardAIPoint();
      game.scoreController.awardPlayerPoint();
      game.scoreController.awardPlayerPoint();
      // Player server 1 loses, transferring service to the ally as server 2.
      game.scoreController.awardAIPoint();

      expect(game.scoreController.isPlayerServing, isTrue);
      expect(game.scoreController.serverNumber, 2);
      expect(game.scoreController.servingPrimary, isFalse);
      expect(identical(game.activeServer, game.playerPartner), isTrue);
      expect(game.isHumanServing, isFalse);

      game.state = GameState.pointScored;
      game.update(2.1);
      expect(game.state, GameState.waitingForServe);
      expect(game.playerPartner!.position.z,
          greaterThan(CourtDimensions.halfLength));

      game.update(2.0);

      expect(game.state, GameState.rally);
      expect(game.ball.lastHitByPlayer, isTrue);
      expect(game.ball.velocity.z, lessThan(0));
      expect(game.playerPartner!.animState, PlayerAnimState.serve);
    });

    test('Late receiver fault restores serve and awards serving team', () {
      final player = Player(startPosition: Vec3(16, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false)
        ..score = 5;
      final scoreCtrl = ScoreController(
        player: player,
        ai: ai,
        isPracticeMode: false,
      )..isPlayerServing = false;

      // Player appears to win as receiver, producing a provisional sideout.
      expect(scoreCtrl.awardPlayerPoint(), isFalse);
      expect(scoreCtrl.isPlayerServing, isTrue);

      // A late player NVZ fault means the AI actually won while serving.
      scoreCtrl.overturnPointForKitchenFault(playerFaulted: true);

      expect(ai.score, 6);
      expect(player.score, 0);
      expect(scoreCtrl.isPlayerServing, isFalse);
      expect(scoreCtrl.serverNumber, 1);
    });

    test(
        'Kitchen Momentum Rule: momentum flag faults when entering NVZ after a volley',
        () {
      final player = Player(
        startPosition: Vec3(0, 0, 35), // Outside kitchen (>28)
        isHuman: true,
      );
      expect(player.isInKitchen(), isFalse);
      expect(player.isInKitchenOrMomentum(), isFalse);

      // Arm kitchen momentum flag (e.g. from volleying outside kitchen)
      player.kitchenMomentumFlag = true;
      expect(player.isInKitchenOrMomentum(), isTrue);

      // Player steps into kitchen (z <= 28)
      player.position.z = 25;
      expect(player.isInKitchen(), isTrue);
      expect(player.isInKitchenOrMomentum(), isTrue);

      // If player recovers and retreats outside kitchen and stops
      player.position.z = 32;
      player.velocity = Vec3(0, 0, 2); // low speed < 8
      player.clearKitchenMomentumIfStopped();
      expect(player.isInKitchenOrMomentum(), isFalse,
          reason: 'Momentum flag clears once player is stopped outside NVZ');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Kitchen (Non-Volley Zone / NVZ) Comprehensive Rules & Mechanics
    // ─────────────────────────────────────────────────────────────────────────
    test('NVZ Dimensions: 7ft each side of net, 14ft total area around net',
        () {
      final court = Court();
      // 1 game unit = 0.25ft (4 units/ft). 7ft = 28 units.
      expect(court.kitchenDepth, 28.0);
      expect(court.playerKitchenFar, 28.0);
      expect(court.aiKitchenFar, -28.0);
      expect((court.playerKitchenFar - court.aiKitchenFar), 56.0,
          reason: 'Total NVZ depth must be 14 feet (56 world units)');
    });

    test('Kitchen Line is part of the Kitchen (touching line is NVZ contact)',
        () {
      final playerOnLine = Player(
        startPosition: Vec3(0, 0, 28.0), // Directly on kitchen line
        isHuman: true,
      );
      expect(playerOnLine.isInKitchen(), isTrue);
      expect(playerOnLine.isTouchingKitchenLine(), isTrue);

      final playerFootTouching = Player(
        startPosition: Vec3(0, 0, 28.8), // Stance foot contacts line tolerance
        isHuman: true,
      );
      expect(playerFootTouching.isInKitchen(), isTrue);
      expect(playerFootTouching.isTouchingKitchenLine(), isTrue);

      final playerDeep = Player(
        startPosition: Vec3(0, 0, 36.0),
        isHuman: true,
      );
      expect(playerDeep.isInKitchen(), isFalse);
      expect(playerDeep.isTouchingKitchenLine(), isFalse);
    });

    test('Fault: Volleying while inside Kitchen or touching line is a fault',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: false,
      );
      game.state = GameState.rally;

      // Ball in flight (has not bounced) -> volley attempt
      game.ball.state = BallState.inFlight;
      game.ball.rallyHitCount = 3;
      game.ball.hasBounced = false;
      game.ball.lastHitByPlayer = false;

      // Standing inside Kitchen (z = 15)
      game.player.position = Vec3(0, 0, 15);
      game.ball.position = Vec3(0, 15.0, 10);

      game.setHitPressed(true);
      game.update(0.016);

      expect(game.lastMessage, contains('KITCHEN'));
      expect(game.scoreController.lastFaultDetail, contains('KITCHEN'));
      expect(game.player.score, 0,
          reason: 'The player who committed the fault cannot score');
      expect(game.ai.score, 0,
          reason: 'The receiving team earns a sideout, not a point');
      expect(game.scoreController.isPlayerServing, isFalse,
          reason: 'Player fault transfers the serve to the opponent');
    });

    test('Player two-bounce violation awards the rally to the opponent', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
      );
      game.state = GameState.rally;
      game.ball
        ..state = BallState.inFlight
        ..rallyHitCount = 1
        ..hasBounced = false
        ..lastHitByPlayer = false
        ..position = Vec3(0, 15, 40);
      game.player.position = Vec3(0, 0, 42);

      game.setHitPressed(true);
      game.update(0.016);

      expect(game.lastMessage, contains('TWO-BOUNCE'));
      expect(game.player.score, 0);
      expect(game.ai.score, 0);
      expect(game.scoreController.isPlayerServing, isFalse);
    });

    test('Untouched second bounce is called after the recovery grace window',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings()..difficulty = AIDifficulty.easy,
      );
      game.state = GameState.rally;
      game.ai.position = Vec3(30, 0, -80);
      game.ball
        ..state = BallState.inFlight
        ..position = Vec3(0, PhysicsConstants.ballRadius, -40)
        ..velocity = Vec3(0, -8, 0)
        ..isServe = false
        ..rallyHitCount = 3
        ..bounceCount = 1
        ..hasBounced = true
        ..lastHitByPlayer = true
        ..playerSideBounce = false;

      game.update(0.016);

      expect(game.state, GameState.rally);
      expect(game.ball.secondBounceGraceTimer, greaterThan(0));

      for (var i = 0; i < 10 && game.state == GameState.rally; i++) {
        game.update(0.016);
      }

      expect(game.state, GameState.pointScored);
      expect(game.ball.state, BallState.dead);
      expect(game.ball.bounceCount, 2);
      expect(game.ball.rallyHitCount, 3,
          reason: 'An untouched second bounce must still end the rally');
      expect(game.player.score, 1);
      expect(game.lastMessage, contains('DOUBLE BOUNCE'));
    });

    test('Queued player swing may recover inside second-bounce grace window',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
      );
      game.state = GameState.rally;
      game.player.position = Vec3(0, 0, 40);
      game.ball
        ..state = BallState.inFlight
        ..position = Vec3(0, PhysicsConstants.ballRadius, 40)
        ..velocity = Vec3(0, -8, 0)
        ..isServe = false
        ..rallyHitCount = 3
        ..bounceCount = 1
        ..hasBounced = true
        ..lastHitByPlayer = false
        ..playerSideBounce = true;
      game.setHitPressed(true);

      game.update(0.016);

      expect(game.state, GameState.rally);
      expect(game.ball.canBeHitAfterBounce, isFalse);
      expect(game.ball.rallyHitCount, 3,
          reason: 'Contact must not occur in the bounce frame');

      for (var i = 0; i < 6 && game.ball.rallyHitCount == 3; i++) {
        game.update(0.016);
      }

      expect(game.ball.state, BallState.inFlight);
      expect(game.ball.bounceCount, 0);
      expect(game.ball.rallyHitCount, 4);
      expect(game.ball.lastHitByPlayer, isTrue);
    });

    test('Deep power return receives enough lift to clear the net', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
      );
      game.state = GameState.rally;
      game.player.position = Vec3(0, 0, 82);
      game.ball
        ..state = BallState.inFlight
        ..position = Vec3(0, 8, 82)
        ..velocity = Vec3(0, 0, 0)
        ..isServe = false
        ..rallyHitCount = 3
        ..bounceCount = 1
        ..hasBounced = true
        ..lastHitByPlayer = false
        ..playerSideBounce = true;

      game.setPowerPressed(true);
      game.update(0.016);

      expect(game.ball.lastHitByPlayer, isTrue);
      expect(game.ball.velocity.y, greaterThan(48));
      expect(game.ball.velocity.z, lessThan(-170));
    });

    test('Deep lob return receives additional forward depth', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
      );
      game.state = GameState.rally;
      game.player.position = Vec3(0, 0, 82);
      game.ball
        ..state = BallState.inFlight
        ..position = Vec3(0, 10, 82)
        ..velocity = Vec3(0, 0, 0)
        ..isServe = false
        ..rallyHitCount = 3
        ..bounceCount = 1
        ..hasBounced = true
        ..lastHitByPlayer = false
        ..playerSideBounce = true;

      game.setLobPressed(true);
      game.update(0.016);

      expect(game.ball.lastHitByPlayer, isTrue);
      expect(game.ball.velocity.y, greaterThanOrEqualTo(68));
      expect(game.ball.velocity.z, lessThan(-105));
    });

    test('Game-winning point remains overturnable during NVZ momentum', () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
      );
      game.player.score = 10;
      game.ai.score = 9;
      game.scoreController.isPlayerServing = true;
      game.state = GameState.rally;
      game.player
        ..position = Vec3(0, 0, 34)
        ..velocity = Vec3(0, 0, -20)
        ..hasEstablishedOutsideKitchen = true
        ..kitchenMomentumFlag = true;
      game.ball
        ..state = BallState.inFlight
        ..lastHitByPlayer = true
        ..hasBounced = true
        ..bounceCount = 2
        ..playerSideBounce = false;

      game.update(0.016);
      expect(game.player.score, 11);
      expect(game.state, GameState.pointScored,
          reason: 'Final score waits for momentum adjudication');

      game.player.position.z = 25;
      game.update(0.016);

      expect(game.player.score, 10);
      expect(game.state, isNot(GameState.gameOver));
      expect(game.scoreController.isPlayerServing, isFalse,
          reason: 'Overturned serving point becomes a sideout');
    });

    test('Fault: Volleying while foot touches the Kitchen line is a violation',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: false,
      );
      game.state = GameState.rally;

      game.ball.state = BallState.inFlight;
      game.ball.rallyHitCount = 3;
      game.ball.hasBounced = false;
      game.ball.lastHitByPlayer = false;

      // Player foot touching the Kitchen line (z = 28.2)
      game.player.position = Vec3(0, 0, 28.2);
      game.ball.position = Vec3(0, 15.0, 24.0);

      game.setHitPressed(true);
      game.update(0.016);

      expect(game.lastMessage, contains('KITCHEN'));
      expect(game.scoreController.lastFaultDetail, contains('KITCHEN'));
    });

    test('Legal: Ball bounces inside Kitchen -> step inside -> hit -> legal',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: false,
      );
      game.state = GameState.rally;

      // Ball bounces inside Kitchen at z = 14
      game.ball.state = BallState.inFlight;
      game.ball.rallyHitCount = 3;
      game.ball.hasBounced = true; // Bounced first!
      game.ball.lastHitByPlayer = false;

      // Player steps inside Kitchen to hit the bounced ball
      game.player.position = Vec3(0, 0, 14);
      game.ball.position = Vec3(0, 15.0, 10);

      game.setHitPressed(true);
      game.update(0.016);

      expect(game.ball.lastHitByPlayer, isTrue,
          reason: 'Hit must execute legally');
      expect(game.player.kitchenMomentumFlag, isFalse,
          reason: 'No momentum flag on bounced shot');
      expect(game.state, isNot(GameState.pointScored),
          reason: 'Rally continues legally');
    });

    test(
        'Fault: Volley outside Kitchen -> momentum carries into Kitchen -> fault',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: false,
      );
      game.state = GameState.rally;

      // Player stands outside Kitchen at z = 34 with forward movement
      game.player.position = Vec3(0, 0, 34);
      game.player.velocity = Vec3(0, 0, -20.0);
      game.player.hasEstablishedOutsideKitchen = true;
      game.ball.position = Vec3(0, 15.0, 30);
      game.ball.state = BallState.inFlight;
      game.ball.rallyHitCount = 3;
      game.ball.hasBounced = false; // Volley!
      game.ball.lastHitByPlayer = false;

      game.setHitPressed(true);
      game.update(0.016);

      expect(game.player.kitchenMomentumFlag, isTrue,
          reason: 'Momentum flag armed on volley');

      // Momentum carries player forward into Kitchen (z = 25)
      game.player.position.z = 25;
      game.update(0.016);

      expect(game.lastMessage, contains('MOMENTUM'));
    });

    test(
        'Momentum fault applies even if rally has already ended (point overturned)',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: false,
      );
      game.state = GameState.rally;

      // Score 2-1
      game.player.score = 2;
      game.ai.score = 1;
      game.scoreController.isPlayerServing = true;

      // Player hits winning volley outside Kitchen while moving forward
      game.player.position = Vec3(0, 0, 34);
      game.player.velocity = Vec3(0, 0, -20.0);
      game.player.hasEstablishedOutsideKitchen = true;
      game.ball.state = BallState.inFlight;
      game.ball.rallyHitCount = 3;
      game.ball.hasBounced = false;
      game.ball.lastHitByPlayer = false;
      game.ball.position = Vec3(0, 15.0, 30);

      game.setHitPressed(true);
      game.update(0.016);
      expect(game.player.kitchenMomentumFlag, isTrue);

      // Keep forward velocity active as ball double bounces on AI side -> point awarded to player
      game.player.velocity = Vec3(0, 0, -20.0);
      game.ball.position = Vec3(0, 0, -50);
      game.ball.hasBounced = true;
      game.ball.bounceCount = 2;
      game.ball.playerSideBounce = false;
      game.update(0.016);

      expect(game.state, GameState.pointScored);
      expect(game.player.score, 3, reason: 'Initially awarded 3rd point');
      expect(game.player.kitchenMomentumFlag, isTrue,
          reason: 'Momentum flag kept during dead ball');

      // During follow-through, momentum carries player into Kitchen
      game.player.position.z = 25;
      game.update(0.016);

      // Point must be overturned!
      expect(game.player.score, 2, reason: 'Point was overturned back to 2!');
      expect(game.lastMessage, contains('OVERTURNED'));
    });

    test(
        'Both feet must be established outside Kitchen after leaving before volleying',
        () {
      final player = Player(
        startPosition: Vec3(0, 0, 15), // Inside kitchen
        isHuman: true,
      );
      player.updateKitchenStatus(0.016);
      expect(player.isInKitchen(), isTrue);
      expect(player.hasEstablishedOutsideKitchen, isFalse);

      // Player moves outside (z = 35)
      player.position.z = 35;
      expect(player.isInKitchen(), isFalse);

      // 0.016s outside: feet not established yet
      player.updateKitchenStatus(0.016);
      expect(player.hasEstablishedOutsideKitchen, isFalse);
      expect(player.canVolley(), isFalse,
          reason: 'Must establish feet outside before volleying');

      // 0.25s outside: feet established
      player.updateKitchenStatus(0.25);
      expect(player.hasEstablishedOutsideKitchen, isTrue);
      expect(player.canVolley(), isTrue, reason: 'Legally permitted to volley');
    });

    test(
        'Serve must clear the Kitchen: touching the Kitchen line is short and a fault',
        () {
      final court = Court();

      // Serve on AI side kitchen line (z = -28.0) -> FAULT
      expect(court.isValidServiceBox(-15, -28.0, true), isFalse,
          reason: 'Serve touching kitchen line is short and a fault');

      // Serve touching line boundary (z = -28.2) -> FAULT
      expect(court.isValidServiceBox(-15, -28.2, true), isFalse,
          reason: 'Serve within kitchen line boundary is a fault');

      // Serve inside kitchen (z = -15.0) -> FAULT
      expect(court.isValidServiceBox(-15, -15.0, true), isFalse,
          reason: 'Serve inside kitchen is a fault');

      // Serve clearing kitchen line into diagonal box (z = -45.0) -> LEGAL
      expect(court.isValidServiceBox(-15, -45.0, true), isTrue,
          reason: 'Serve clearing kitchen diagonally is legal');
    });

    test(
        'Swept Net Collision: detects fast ball crossing z=0 below net height without tunneling',
        () {
      final ball = Pickleball();
      final player = Player(startPosition: Vec3(0, 0, 60), isHuman: true);
      final ai = Player(startPosition: Vec3(0, 0, -60), isHuman: false);
      final court = Court();
      final physics = PhysicsController(
        ball: ball,
        player: player,
        ai: ai,
        court: court,
      );

      // Ball fast moving from z = 3 to z = -3 (skipped z=0 entirely in one frame)
      // at height y = 2.0 (below netHeight = 3.0)
      ball.prevPosition = Vec3(0, 2.0, 3.0);
      ball.position = Vec3(0, 2.0, -3.0);
      ball.velocity = Vec3(0, 0, -200);
      ball.state = BallState.inFlight;

      final collision = physics.update(0.016);
      expect(collision.netHit, isTrue,
          reason:
              'Fast ball crossing net plane below net height must trigger net collision');
      expect(ball.netCollision, isTrue);
    });

    test(
        'Player power shot cleanly clears the net and lands in bounds on opponent side',
        () {
      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isPracticeMode: true,
        drillType: 'return_drill',
      );

      // Start rally: simulate waiting for serve then AI serve
      game.update(2.0); // Triggers AI serve

      // Wait for ball to land on player side (1st bounce)
      for (int i = 0; i < 100; i++) {
        game.update(0.016);
        if (game.ball.hasBounced && game.ball.position.z > 0) break;
      }
      expect(game.ball.hasBounced, isTrue);

      // Move player close to ball and trigger power shot
      game.player.position =
          Vec3(game.ball.position.x, 0, game.ball.position.z + 10);
      game.setPowerPressed(true);
      for (var i = 0; i < 6 && !game.ball.lastHitByPlayer; i++) {
        game.update(0.016);
      }

      // Verify player executed hit
      expect(game.ball.lastHitByPlayer, isTrue);
      expect(game.ball.shotType, ShotType.power);
      expect(game.ball.velocity.z, lessThan(0),
          reason: 'Ball should travel toward opponent');

      // Trace ball flight until it reaches the net plane (z <= 0)
      bool reachedNet = false;
      double heightAtNet = 0;
      bool hitNet = false;
      for (int i = 0; i < 80; i++) {
        final prevZ = game.ball.position.z;
        game.update(0.016);
        if (game.ball.netCollision) hitNet = true;
        if (prevZ > 0 && game.ball.position.z <= 0) {
          reachedNet = true;
          heightAtNet = game.ball.position.y;
          break;
        }
      }

      expect(hitNet, isFalse, reason: 'Power shot must not crash into the net');
      expect(reachedNet, isTrue, reason: 'Power shot must reach the net');
      expect(heightAtNet, greaterThan(CourtDimensions.netHeight),
          reason: 'Ball must be above the net when crossing z=0');

      // Continue simulating until first bounce on opponent side
      for (int i = 0; i < 80; i++) {
        game.update(0.016);
        if (game.ball.hasBounced && game.ball.position.z < 0) break;
      }

      expect(game.ball.hasBounced, isTrue);
      expect(game.ball.lastBounceZ, lessThan(0),
          reason: 'Ball must bounce on opponent side');
      expect(
          game.court.isInsideCourt(game.ball.position.x, game.ball.lastBounceZ),
          isTrue,
          reason: 'Power shot must land in bounds on opponent side, not OUT');
    });
  });
}

class _FakeAudioService extends AudioService {
  int hitCount = 0;
  int powerHitCount = 0;
  int bounceCount = 0;
  int clickCount = 0;
  int netHitCount = 0;

  @override
  void playHit({bool isPower = false}) {
    hitCount++;
    if (isPower) powerHitCount++;
  }

  @override
  void playBounce() {
    bounceCount++;
  }

  @override
  void playButtonClick() {
    clickCount++;
  }

  @override
  void playNetHit() {
    netHitCount++;
  }
}
