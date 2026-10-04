import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/match_command_controller.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatchCommandController', () {
    late PickleballGame game;
    late MatchCommandController commands;
    late List<MatchCommand> observed;

    setUp(() {
      game = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
      );
      observed = <MatchCommand>[];
      commands = MatchCommandController(
        game: game,
        onDispatched: observed.add,
      );
    });

    test('sanitizes movement from any input source', () {
      commands.move(2, double.nan);

      expect(game.joystickX, 1);
      expect(game.joystickY, 0);
      expect(observed.single.type, MatchCommandType.movement);
    });

    test('normalizes aim and can clear it', () {
      commands.aim(const Offset(3, 4));

      expect(game.swipeDirection!.dx, closeTo(0.6, 0.0001));
      expect(game.swipeDirection!.dy, closeTo(0.8, 0.0001));

      commands.clearAim();
      expect(game.swipeDirection, isNull);
    });

    test('routes serve and shot commands through existing game input', () {
      commands.serve();
      commands.shot(ShotType.lob);

      expect(game.servePressed, isTrue);
      expect(game.lobPressed, isTrue);
      expect(game.bufferedShot, ShotType.lob);
      expect(observed.map((command) => command.type), <MatchCommandType>[
        MatchCommandType.serve,
        MatchCommandType.shot,
      ]);
    });

    test('routes player two commands to the far-side local player', () {
      final localGame = PickleballGame(
        screenSize: const Size(800, 600),
        settings: GameSettings(),
        isLocalMultiplayer: true,
      );
      final playerTwo = MatchCommandController(game: localGame, playerSlot: 1);

      playerTwo.move(-2, 0.5);
      playerTwo.aim(const Offset(0, 5));
      playerTwo.shot(ShotType.lob);
      playerTwo.serve();

      expect(localGame.opponentJoystickX, -1);
      expect(localGame.opponentJoystickY, 0.5);
      expect(localGame.opponentSwipeDirection, const Offset(0, 1));
      expect(localGame.opponentBufferedShot, ShotType.lob);
      expect(localGame.opponentServePressed, isTrue);
      expect(localGame.ai.isHuman, isTrue);
      expect(localGame.ai.isNearSide, isFalse);
    });
  });
}
