import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/match_observation.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('observation is detached from mutable simulation models', () {
    final game = PickleballGame(settings: GameSettings());
    game.player.position = Vec3(4, 0, 60);
    game.ball
      ..position = Vec3(-3, 12, 8)
      ..velocity = Vec3(7, -2, 30);

    final observation = MatchObservation.fromGame(game);

    game.player.position.x = 99;
    game.ball.position
      ..x = 88
      ..y = 77
      ..z = 66;
    game.ball.velocity.z = -100;

    expect(observation.nearPlayer.position.x, 4);
    expect(observation.ball.position.x, -3);
    expect(observation.ball.position.y, 12);
    expect(observation.ball.position.z, 8);
    expect(observation.ball.velocity.z, 30);
  });
}
