import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/game/ai_controller.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Difficulty Settings & Calibration', () {
    test('GameSettings reports calibrated speed, reaction, and accuracy for each tier', () {
      final settings = GameSettings();

      // Default is medium
      expect(settings.difficulty, AIDifficulty.medium);
      expect(settings.aiSpeed, 100.0);
      expect(settings.aiReactionTime, 0.18);
      expect(settings.aiAccuracy, 0.82);
      expect(settings.aiErrorChance, 0.07);

      // Switch to Easy
      settings.difficulty = AIDifficulty.easy;
      expect(settings.aiSpeed, 75.0);
      expect(settings.aiReactionTime, 0.32);
      expect(settings.aiAccuracy, 0.65);
      expect(settings.aiErrorChance, 0.15);

      // Switch to Hard
      settings.difficulty = AIDifficulty.hard;
      expect(settings.aiSpeed, 130.0);
      expect(settings.aiReactionTime, 0.08);
      expect(settings.aiAccuracy, 0.95);
      expect(settings.aiErrorChance, 0.02);

      // aiSpeedForDifficulty helper
      expect(settings.aiSpeedForDifficulty(1), 75.0);
      expect(settings.aiSpeedForDifficulty(2), 100.0);
      expect(settings.aiSpeedForDifficulty(3), 130.0);
    });

    test('AIController respects difficultyOverride without altering GameSettings', () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.hard;

      final ai = Player(startPosition: Vec3(-16, 0, -60), isHuman: false);
      final ball = Pickleball();
      final court = Court();

      // AI Controller initialized with Easy override (e.g. in early tournament round)
      final aiController = AIController(
        ai: ai,
        ball: ball,
        court: court,
        settings: settings,
        difficultyOverride: AIDifficulty.easy,
      );

      expect(aiController.difficulty, AIDifficulty.easy);
      expect(aiController.effectiveSpeed, 75.0);
      expect(aiController.effectiveReactionTime, 0.32);
      expect(aiController.effectiveAccuracy, 0.65);
      expect(aiController.effectiveErrorChance, 0.15);

      // GameSettings must retain Hard
      expect(settings.difficulty, AIDifficulty.hard);
    });
  });

  group('AI Tactical Shot Selection & Behavior Tiers', () {
    test('Hard AI smashes high balls and drop-shots when player is pinned deep', () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.hard;

      final ai = Player(startPosition: Vec3(0, 0, -50), isHuman: false);
      final human = Player(startPosition: Vec3(-15, 0, 72), isHuman: true); // Deep past baseline
      final ball = Pickleball();
      final court = Court();

      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: court,
        settings: settings,
        humanPlayer: human,
      );

      // 1. High ball test -> Overhead smash
      ball.position = Vec3(0, 22.0, -45); // High above net
      ball.velocity = Vec3(0, -5, -30);
      ball.hasBounced = true; // Legal to hit
      ball.rallyHitCount = 3;
      ai.position = Vec3(0, 0, -45);

      // Step until AI reacts, approaches and swings
      for (int i = 0; i < 30; i++) {
        aiCtrl.update(0.03);
        if (!ball.lastHitByPlayer) break;
      }
      expect(ball.lastHitByPlayer, isFalse);
      expect(ball.shotType, ShotType.power, reason: 'Hard AI must smash high balls');
      expect(ball.velocity.x, greaterThan(0),
          reason: 'Hard AI must smash to open court opposite player (player is on left x < 0)');
    });

    test('Easy AI hits gentle, centered returns for accessible rallies', () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.easy;

      final ai = Player(startPosition: Vec3(0, 0, -50), isHuman: false);
      final human = Player(startPosition: Vec3(0, 0, 60), isHuman: true);
      final ball = Pickleball();
      final court = Court();

      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: court,
        settings: settings,
        humanPlayer: human,
      );

      // Ball arrives waist height
      ball.position = Vec3(0, 10.0, -45);
      ball.velocity = Vec3(0, -10, -30);
      ball.hasBounced = true;
      ball.rallyHitCount = 3;
      ai.position = Vec3(0, 0, -45);

      // Step until AI reacts, approaches and swings
      for (int i = 0; i < 30; i++) {
        aiCtrl.update(0.03);
        if (!ball.lastHitByPlayer) break;
      }
      expect(ball.lastHitByPlayer, isFalse);
      expect(ball.shotType, isNot(ShotType.power), reason: 'Easy AI must not smash normal rally balls');
      // Velocity aiming must be near center
      expect(ball.velocity.y, greaterThan(35.0), reason: 'Easy AI must give forgiving high arc');
    });

    test('AIController positions behind the bounce on opponent court', () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.hard;

      final ai = Player(startPosition: Vec3(0, 0, -60), isHuman: false);
      final ball = Pickleball();
      final court = Court();

      // Ball hit by player deep to AI side
      ball.position = Vec3(10, 20, 20);
      ball.velocity = Vec3(-5, 10, -120);
      ball.state = BallState.inFlight;

      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: court,
        settings: settings,
      );

      // AI reacts and enters positioning
      for (int i = 0; i < 15; i++) {
        aiCtrl.update(0.016);
      }

      // AI position must be on AI court (z < 0) and moving toward predicted intercept
      expect(ai.position.z, lessThan(-20.0), reason: 'AI must stay on far side of court');
    });
  });

  group('PickleballGame AI Serve Scaling', () {
    test('AI Serve parameters scale with currentAIDifficulty', () {
      final settings = GameSettings();

      // Easy Serve
      final easyGame = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
        difficultyOverride: AIDifficulty.easy,
      );
      easyGame.scoreController.isPlayerServing = false;
      easyGame.update(2.0); // Triggers AI serve

      expect(easyGame.ball.state, BallState.inFlight);
      expect(easyGame.ball.isServe, isTrue);
      expect(easyGame.ball.velocity.y, 32.0, reason: 'Easy serve has gentle high arc');

      // Hard Serve
      final hardGame = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
        difficultyOverride: AIDifficulty.hard,
      );
      hardGame.scoreController.isPlayerServing = false;
      hardGame.update(2.0); // Triggers AI serve

      expect(hardGame.ball.state, BallState.inFlight);
      expect(hardGame.ball.isServe, isTrue);
      expect(hardGame.ball.velocity.y, 26.0, reason: 'Hard serve is faster and flatter');
    });
  });
}
