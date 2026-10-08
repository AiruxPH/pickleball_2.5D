import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/pickleball_game.dart';
import 'package:pickleball_3d/game/rally_phase_classifier.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/match_foundation.dart';
import 'package:pickleball_3d/models/pickleball.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/models/shot_mechanics.dart';
import 'package:pickleball_3d/utils/constants.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  group('Match foundation', () {
    test('unknown balance values safely default to standard', () {
      expect(MatchBalanceProfileX.fromName('future-profile'),
          MatchBalanceProfile.standard);
      expect(MatchBalanceProfileX.fromName('competitive'),
          MatchBalanceProfile.competitive);
    });

    test('stats apply each authoritative event revision only once', () {
      final stats = MatchStats();
      const event = MatchEvent(
        type: MatchEventType.contact,
        revision: 1,
        elapsedSeconds: 2.5,
        timingGrade: SwingTimingGrade.perfect,
        spin: ShotSpin.topspin,
      );

      stats.record(event);
      stats.record(event);

      expect(stats.contacts, 1);
      expect(stats.timing[SwingTimingGrade.perfect], 1);
      expect(stats.spin[ShotSpin.topspin], 1);
      expect(stats.elapsedSeconds, 2.5);
    });

    test('stats serialize and restore compact authoritative state', () {
      final original = MatchStats()
        ..record(const MatchEvent(
          type: MatchEventType.pointResult,
          revision: 4,
          elapsedSeconds: 8,
          rallyHits: 12,
          isFault: true,
        ));
      final restored = MatchStats()..applyJson(original.toJson());

      expect(restored.pointsPlayed, 1);
      expect(restored.faults, 1);
      expect(restored.longestRally, 12);
      expect(restored.lastAppliedEventRevision, 4);
    });

    test('competitive profile normalizes gameplay but keeps visual paddle', () {
      final game = PickleballGame(
        settings: GameSettings(),
        balanceProfile: MatchBalanceProfile.competitive,
      );

      expect(game.balanceProfile, MatchBalanceProfile.competitive);
      expect(game.paddleFor(game.player), same(game.currentPaddle));
      expect(game.gameplayPaddleFor(game.player).id, 'paddle_standard');
      expect(game.gameplayMoveSpeedMultiplier, 1.0);
      expect(game.gameplayStaminaRegenMultiplier, 1.0);
      expect(game.specialSkillsEnabled, isFalse);
      game.dispose();
    });
  });

  group('Rally phase classification', () {
    late Pickleball ball;
    late Player near;
    late Player far;

    setUp(() {
      ball = Pickleball();
      near = Player(
        startPosition: Vec3(0, 0, 60),
        isHuman: true,
        isNearSide: true,
      );
      far = Player(
        startPosition: Vec3(0, 0, -60),
        isHuman: false,
        isNearSide: false,
      );
    });

    test('serve and first two contacts stay in opening phase', () {
      ball
        ..state = BallState.inFlight
        ..isServe = true
        ..rallyHitCount = 0;

      expect(
        RallyPhaseClassifier.classify(
          ball: ball,
          nearTeam: [near],
          farTeam: [far],
        ),
        RallyPhase.opening,
      );
    });

    test('high incoming volley becomes attackable', () {
      ball
        ..state = BallState.inFlight
        ..isServe = false
        ..rallyHitCount = 3
        ..lastHitByPlayer = false
        ..hasBounced = false
        ..position = Vec3(0, CourtDimensions.netHeight + 8, 18)
        ..velocity = Vec3(0, 0, 60);

      expect(
        RallyPhaseClassifier.classify(
          ball: ball,
          nearTeam: [near],
          farTeam: [far],
        ),
        RallyPhase.attackable,
      );
    });

    test('settled low exchange near both kitchen lines is kitchen phase', () {
      near.position.z = CourtDimensions.kitchenDepth + 4;
      far.position.z = -CourtDimensions.kitchenDepth - 4;
      ball
        ..state = BallState.inFlight
        ..isServe = false
        ..rallyHitCount = 6
        ..lastHitByPlayer = true
        ..hasBounced = true
        ..position = Vec3(0, 5, -10)
        ..velocity = Vec3(0, 5, -70);

      expect(
        RallyPhaseClassifier.classify(
          ball: ball,
          nearTeam: [near],
          farTeam: [far],
        ),
        RallyPhase.kitchen,
      );
    });
  });
}
