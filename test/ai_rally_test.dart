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

  group('AI Opponent Return & Rally Mechanics', () {
    test('Hard AI cleanly returns player serve over net onto player court', () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.hard;

      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
      );

      // Player serves
      game.setServePressed(true);
      game.update(0.016);

      expect(game.ball.state, BallState.inFlight);
      expect(game.ball.isServe, isTrue);

      bool aiHit = false;
      bool landedOnPlayerSide = false;
      for (int i = 0; i < 200; i++) {
        game.update(0.016);
        if (!game.ball.lastHitByPlayer && !aiHit) {
          aiHit = true;
        }
        if (aiHit && game.ball.hasBounced && game.ball.position.z > 0) {
          landedOnPlayerSide = true;
          break;
        }
      }

      expect(aiHit, isTrue,
          reason: 'AI must reach and hit the return of serve');
      expect(game.ball.netCollision, isFalse,
          reason: 'AI return must not hit the net');
      expect(landedOnPlayerSide, isTrue,
          reason: 'AI return must land in the player half (z > 0)');
      expect(game.ball.position.z, greaterThan(15.0),
          reason: 'AI return must land deep beyond NVZ');
    });

    test('Medium AI cleanly returns player serve over net onto player court',
        () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.medium;

      final game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: settings,
      );

      game.setServePressed(true);
      game.update(0.016);

      bool aiHit = false;
      bool landedOnPlayerSide = false;
      for (int i = 0; i < 200; i++) {
        game.update(0.016);
        if (!game.ball.lastHitByPlayer && !aiHit) {
          aiHit = true;
        }
        if (aiHit && game.ball.hasBounced && game.ball.position.z > 0) {
          landedOnPlayerSide = true;
          break;
        }
      }

      expect(aiHit, isTrue, reason: 'Medium AI must hit the return');
      expect(game.ball.netCollision, isFalse,
          reason: 'Medium AI return must clear net');
      expect(landedOnPlayerSide, isTrue,
          reason: 'Return must land on player side');
    });

    for (final difficulty in AIDifficulty.values) {
      test('$difficulty returns a serve at the production 120 Hz step', () {
        final settings = GameSettings()..difficulty = difficulty;
        final game = PickleballGame(
          screenSize: const Size(800, 600),
          settings: settings,
        );

        game.setServePressed(true);
        game.update(1 / 120);

        var aiHit = false;
        for (var i = 0; i < 720 && game.state == GameState.rally; i++) {
          game.update(1 / 120);
          if (!game.ball.lastHitByPlayer && game.ball.rallyHitCount >= 1) {
            aiHit = true;
            break;
          }
        }

        expect(aiHit, isTrue,
            reason: '$difficulty AI must not miss its serve contact window');
      });
    }

    test('AI retrieves bounced balls inside the kitchen', () {
      final settings = GameSettings();
      settings.difficulty = AIDifficulty.hard;

      final ai = Player(startPosition: Vec3(0, 0, -50), isHuman: false);
      final ball = Pickleball();
      final court = Court();

      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: court,
        settings: settings,
      );

      // Short dink landing in AI kitchen at z = -14
      ball.position = Vec3(0, 4.0, -14.0);
      ball.velocity = Vec3(0, -5.0, -10.0);
      ball.hasBounced = true; // Bounced legally in kitchen
      ball.lastBounceZ = -14.0;
      ball.rallyHitCount = 3;

      for (int i = 0; i < 40; i++) {
        aiCtrl.update(0.025);
        if (!ball.lastHitByPlayer) break;
      }

      expect(ball.lastHitByPlayer, isFalse,
          reason: 'AI must step in and return bounced kitchen ball');
      expect(ball.velocity.z, greaterThan(0),
          reason: 'Return must head back over net toward player side');
      expect(aiCtrl.lastShotPlan, isNotNull);
      expect(aiCtrl.lastShotPlan!.predictedNetClearance, greaterThan(0));
      expect(aiCtrl.lastShotPlan!.predictedLanding.z,
          inInclusiveRange(0, CourtDimensions.halfLength));
    });

    test('AI waits for the serve to bounce before returning it', () {
      final settings = GameSettings()..difficulty = AIDifficulty.hard;
      final ai = Player(startPosition: Vec3(0, 0, -45), isHuman: false);
      final ball = Pickleball()
        ..position = Vec3(0, 10, -45)
        ..velocity = Vec3(0, -5, -30)
        ..state = BallState.inFlight
        ..rallyHitCount = 0
        ..hasBounced = false;
      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: Court(),
        settings: settings,
      );

      for (int i = 0; i < 20; i++) {
        aiCtrl.update(0.03);
      }

      expect(ball.lastHitByPlayer, isTrue,
          reason: 'The receiving bot cannot volley a serve');
      expect(ball.rallyHitCount, 0);
    });

    test('AI may volley a normal rally ball while clear of the NVZ', () {
      final settings = GameSettings()..difficulty = AIDifficulty.hard;
      final ai = Player(startPosition: Vec3(0, 0, -45), isHuman: false);
      final ball = Pickleball()
        ..position = Vec3(0, 10, -45)
        ..velocity = Vec3(0, -5, -30)
        ..state = BallState.inFlight
        ..rallyHitCount = 2
        ..hasBounced = false;
      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: Court(),
        settings: settings,
      );

      for (int i = 0; i < 20 && ball.lastHitByPlayer; i++) {
        aiCtrl.update(0.03);
      }

      expect(ball.lastHitByPlayer, isFalse,
          reason: 'A normal rally ball may be volleyed outside the NVZ');
      expect(ai.isInKitchen(includeFootMargin: true), isFalse);
    });

    test('AI stays outside the NVZ when the ball bounced outside it', () {
      final settings = GameSettings()..difficulty = AIDifficulty.hard;
      final ai = Player(startPosition: Vec3(0, 0, -31), isHuman: false);
      final ball = Pickleball()
        ..position = Vec3(0, 6, -22)
        ..velocity = Vec3(0, -4, -10)
        ..state = BallState.inFlight
        ..rallyHitCount = 3
        ..hasBounced = true
        ..lastBounceZ = -40;
      final aiCtrl = AIController(
        ai: ai,
        ball: ball,
        court: Court(),
        settings: settings,
      );

      for (int i = 0; i < 30 && ball.lastHitByPlayer; i++) {
        aiCtrl.update(0.03);
      }

      expect(ball.lastHitByPlayer, isFalse,
          reason: 'The bot can play the bounced ball from outside the NVZ');
      expect(ai.isInKitchen(includeFootMargin: true), isFalse,
          reason: 'An outside-NVZ bounce does not justify entering the NVZ');
    });
  });
}
