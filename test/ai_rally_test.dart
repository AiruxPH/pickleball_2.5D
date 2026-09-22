import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/court.dart';
import 'package:pickleball_3d/game/ai_controller.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
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

      expect(aiHit, isTrue, reason: 'AI must reach and hit the return of serve');
      expect(game.ball.netCollision, isFalse, reason: 'AI return must not hit the net');
      expect(landedOnPlayerSide, isTrue, reason: 'AI return must land in the player half (z > 0)');
      expect(game.ball.position.z, greaterThan(15.0), reason: 'AI return must land deep beyond NVZ');
    });

    test('Medium AI cleanly returns player serve over net onto player court', () {
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
      expect(game.ball.netCollision, isFalse, reason: 'Medium AI return must clear net');
      expect(landedOnPlayerSide, isTrue, reason: 'Return must land on player side');
    });

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
      ball.rallyHitCount = 3;

      for (int i = 0; i < 40; i++) {
        aiCtrl.update(0.025);
        if (!ball.lastHitByPlayer) break;
      }

      expect(ball.lastHitByPlayer, isFalse, reason: 'AI must step in and return bounced kitchen ball');
      expect(ball.velocity.z, greaterThan(80.0), reason: 'Return must head back over net toward player side');
    });
  });
}
