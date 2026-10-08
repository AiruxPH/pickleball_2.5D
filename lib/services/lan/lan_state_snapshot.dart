import '../../game/pickleball_game.dart';
import '../../models/pickleball.dart';
import '../../models/player.dart';
import '../../models/shot_mechanics.dart';
import '../../utils/game_math.dart';

class LanEntityState {
  const LanEntityState({
    required this.x,
    required this.y,
    required this.z,
    this.vx = 0,
    this.vy = 0,
    this.vz = 0,
    this.stamina = 1.0,
    this.isSwinging = false,
    this.animState = 'idle',
  });

  final double x;
  final double y;
  final double z;
  final double vx;
  final double vy;
  final double vz;
  final double stamina;
  final bool isSwinging;
  final String animState;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        if (vx != 0) 'vx': vx,
        if (vy != 0) 'vy': vy,
        if (vz != 0) 'vz': vz,
        'stamina': stamina,
        if (isSwinging) 'swing': true,
        if (animState != 'idle') 'anim': animState,
      };

  factory LanEntityState.fromJson(Map<String, dynamic> json) {
    return LanEntityState(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      vx: (json['vx'] as num?)?.toDouble() ?? 0.0,
      vy: (json['vy'] as num?)?.toDouble() ?? 0.0,
      vz: (json['vz'] as num?)?.toDouble() ?? 0.0,
      stamina: (json['stamina'] as num?)?.toDouble() ?? 1.0,
      isSwinging: json['swing'] == true,
      animState: json['anim'] as String? ?? 'idle',
    );
  }
}

class LanStateSnapshot {
  const LanStateSnapshot({
    required this.ball,
    required this.ballState,
    this.ballSpin = 'flat',
    this.ballSpinStrength = 0,
    required this.player1,
    required this.player2,
    this.partner1,
    this.partner2,
    required this.playerScore,
    required this.aiScore,
    required this.serverNumber,
    required this.isPlayerServing,
    required this.servingPrimary,
    required this.gameState,
    this.lastMessage,
    this.timingGrade,
    this.timingPosition,
    this.timingPlayerSlot = 0,
    this.timingRevision = 0,
    this.timingRemaining = 0,
    required this.timestamp,
  });

  final LanEntityState ball;
  final String ballState;
  final String ballSpin;
  final double ballSpinStrength;
  final LanEntityState player1;
  final LanEntityState player2;
  final LanEntityState? partner1;
  final LanEntityState? partner2;
  final int playerScore;
  final int aiScore;
  final int serverNumber;
  final bool isPlayerServing;
  final bool servingPrimary;
  final String gameState;
  final String? lastMessage;
  final String? timingGrade;
  final LanEntityState? timingPosition;
  final int timingPlayerSlot;
  final int timingRevision;
  final double timingRemaining;
  final int timestamp;

  Map<String, dynamic> toJson() => {
        'ball': ball.toJson(),
        'bState': ballState,
        if (ballSpin != 'flat') 'bSpin': ballSpin,
        if (ballSpinStrength != 0) 'bSpinS': ballSpinStrength,
        'p1': player1.toJson(),
        'p2': player2.toJson(),
        if (partner1 != null) 'part1': partner1!.toJson(),
        if (partner2 != null) 'part2': partner2!.toJson(),
        'pScore': playerScore,
        'aScore': aiScore,
        'srvNum': serverNumber,
        'isPSrv': isPlayerServing,
        'srvPri': servingPrimary,
        'gState': gameState,
        if (lastMessage != null && lastMessage!.isNotEmpty) 'msg': lastMessage,
        if (timingGrade != null) 'timingGrade': timingGrade,
        if (timingPosition != null) 'timingPos': timingPosition!.toJson(),
        if (timingRevision != 0) 'timingRev': timingRevision,
        if (timingRevision != 0) 'timingSlot': timingPlayerSlot,
        if (timingRemaining > 0) 'timingLeft': timingRemaining,
        'ts': timestamp,
      };

  factory LanStateSnapshot.fromJson(Map<String, dynamic> json) {
    return LanStateSnapshot(
      ball: LanEntityState.fromJson(
        Map<String, dynamic>.from(json['ball'] as Map? ?? {}),
      ),
      ballState: json['bState'] as String? ?? 'inFlight',
      ballSpin: json['bSpin'] as String? ?? 'flat',
      ballSpinStrength: (json['bSpinS'] as num?)?.toDouble() ?? 0,
      player1: LanEntityState.fromJson(
        Map<String, dynamic>.from(json['p1'] as Map? ?? {}),
      ),
      player2: LanEntityState.fromJson(
        Map<String, dynamic>.from(json['p2'] as Map? ?? {}),
      ),
      partner1: json['part1'] is Map
          ? LanEntityState.fromJson(Map<String, dynamic>.from(json['part1']))
          : null,
      partner2: json['part2'] is Map
          ? LanEntityState.fromJson(Map<String, dynamic>.from(json['part2']))
          : null,
      playerScore: (json['pScore'] as num?)?.toInt() ?? 0,
      aiScore: (json['aScore'] as num?)?.toInt() ?? 0,
      serverNumber: (json['srvNum'] as num?)?.toInt() ?? 1,
      isPlayerServing: json['isPSrv'] == true,
      servingPrimary: json['srvPri'] == true,
      gameState: json['gState'] as String? ?? 'rally',
      lastMessage: json['msg'] as String?,
      timingGrade: json['timingGrade'] as String?,
      timingPosition: json['timingPos'] is Map
          ? LanEntityState.fromJson(
              Map<String, dynamic>.from(json['timingPos'] as Map),
            )
          : null,
      timingPlayerSlot: (json['timingSlot'] as num?)?.toInt() ?? 0,
      timingRevision: (json['timingRev'] as num?)?.toInt() ?? 0,
      timingRemaining: (json['timingLeft'] as num?)?.toDouble() ?? 0,
      timestamp: (json['ts'] as num?)?.toInt() ?? 0,
    );
  }

  factory LanStateSnapshot.fromGame(PickleballGame game) {
    return LanStateSnapshot(
      ball: LanEntityState(
        x: game.ball.position.x,
        y: game.ball.position.y,
        z: game.ball.position.z,
        vx: game.ball.velocity.x,
        vy: game.ball.velocity.y,
        vz: game.ball.velocity.z,
      ),
      ballState: game.ball.state.name,
      ballSpin: game.ball.shotSpin.name,
      ballSpinStrength: game.ball.spinStrength,
      player1: LanEntityState(
        x: game.player.position.x,
        y: game.player.position.y,
        z: game.player.position.z,
        vx: game.player.velocity.x,
        vy: game.player.velocity.y,
        vz: game.player.velocity.z,
        stamina: game.player.stamina,
        isSwinging: game.player.isSwinging,
        animState: game.player.animState.name,
      ),
      player2: LanEntityState(
        x: game.ai.position.x,
        y: game.ai.position.y,
        z: game.ai.position.z,
        vx: game.ai.velocity.x,
        vy: game.ai.velocity.y,
        vz: game.ai.velocity.z,
        stamina: game.ai.stamina,
        isSwinging: game.ai.isSwinging,
        animState: game.ai.animState.name,
      ),
      partner1: game.playerPartner != null
          ? LanEntityState(
              x: game.playerPartner!.position.x,
              y: game.playerPartner!.position.y,
              z: game.playerPartner!.position.z,
              vx: game.playerPartner!.velocity.x,
              vy: game.playerPartner!.velocity.y,
              vz: game.playerPartner!.velocity.z,
              stamina: game.playerPartner!.stamina,
              isSwinging: game.playerPartner!.isSwinging,
              animState: game.playerPartner!.animState.name,
            )
          : null,
      partner2: game.aiPartner != null
          ? LanEntityState(
              x: game.aiPartner!.position.x,
              y: game.aiPartner!.position.y,
              z: game.aiPartner!.position.z,
              vx: game.aiPartner!.velocity.x,
              vy: game.aiPartner!.velocity.y,
              vz: game.aiPartner!.velocity.z,
              stamina: game.aiPartner!.stamina,
              isSwinging: game.aiPartner!.isSwinging,
              animState: game.aiPartner!.animState.name,
            )
          : null,
      playerScore: game.scoreController.playerScore,
      aiScore: game.scoreController.aiScore,
      serverNumber: game.scoreController.serverNumber,
      isPlayerServing: game.scoreController.isPlayerServing,
      servingPrimary: game.scoreController.servingPrimary,
      gameState: game.state.name,
      lastMessage: game.lastMessage,
      timingGrade: game.contactFeedback?.grade.name,
      timingPosition: game.contactFeedback == null
          ? null
          : LanEntityState(
              x: game.contactFeedback!.position.x,
              y: game.contactFeedback!.position.y,
              z: game.contactFeedback!.position.z,
            ),
      timingPlayerSlot: game.contactFeedback?.playerSlot ?? 0,
      timingRevision: game.contactFeedbackRevision,
      timingRemaining: game.contactFeedback?.remaining ?? 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void applyToGame(
    PickleballGame game, {
    double positionBlend = 1.0,
    double? player1PositionBlend,
    double? player2PositionBlend,
    double extrapolationSeconds = 0,
  }) {
    final blend = positionBlend.clamp(0.0, 1.0);
    final extrapolation = extrapolationSeconds.clamp(0.0, 0.15).toDouble();
    Vec3 blended(
      Vec3 current,
      LanEntityState target, {
      bool velocity = false,
      double? positionBlendOverride,
    }) {
      final entityBlend =
          (positionBlendOverride ?? blend).clamp(0.0, 1.0).toDouble();
      final tx = velocity ? target.vx : target.x + target.vx * extrapolation;
      final ty = velocity ? target.vy : target.y + target.vy * extrapolation;
      final tz = velocity ? target.vz : target.z + target.vz * extrapolation;
      return Vec3(
        current.x + (tx - current.x) * entityBlend,
        current.y + (ty - current.y) * entityBlend,
        current.z + (tz - current.z) * entityBlend,
      );
    }

    // Synchronize ball
    game.ball.position = blended(game.ball.position, ball);
    game.ball.velocity = blended(game.ball.velocity, ball, velocity: true);
    game.ball.state = BallState.values.firstWhere(
      (e) => e.name == ballState,
      orElse: () => BallState.inFlight,
    );
    game.ball.shotSpin = ShotSpin.values.firstWhere(
      (value) => value.name == ballSpin,
      orElse: () => ShotSpin.flat,
    );
    game.ball.spinStrength = ballSpinStrength.clamp(0.0, 1.35).toDouble();

    // Synchronize players
    game.player.position = blended(
      game.player.position,
      player1,
      positionBlendOverride: player1PositionBlend,
    );
    game.player.velocity = blended(
      game.player.velocity,
      player1,
      velocity: true,
      positionBlendOverride: player1PositionBlend,
    );
    game.player.stamina = player1.stamina;
    game.player.isSwinging = player1.isSwinging;
    game.player.animState = PlayerAnimState.values.firstWhere(
      (e) => e.name == player1.animState,
      orElse: () => PlayerAnimState.idle,
    );

    game.ai.position = blended(
      game.ai.position,
      player2,
      positionBlendOverride: player2PositionBlend,
    );
    game.ai.velocity = blended(
      game.ai.velocity,
      player2,
      velocity: true,
      positionBlendOverride: player2PositionBlend,
    );
    game.ai.stamina = player2.stamina;
    game.ai.isSwinging = player2.isSwinging;
    game.ai.animState = PlayerAnimState.values.firstWhere(
      (e) => e.name == player2.animState,
      orElse: () => PlayerAnimState.idle,
    );

    if (partner1 != null && game.playerPartner != null) {
      game.playerPartner!.position =
          blended(game.playerPartner!.position, partner1!);
      game.playerPartner!.velocity =
          blended(game.playerPartner!.velocity, partner1!, velocity: true);
      game.playerPartner!.stamina = partner1!.stamina;
      game.playerPartner!.isSwinging = partner1!.isSwinging;
      game.playerPartner!.animState = PlayerAnimState.values.firstWhere(
        (e) => e.name == partner1!.animState,
        orElse: () => PlayerAnimState.idle,
      );
    }

    if (partner2 != null && game.aiPartner != null) {
      game.aiPartner!.position = blended(game.aiPartner!.position, partner2!);
      game.aiPartner!.velocity =
          blended(game.aiPartner!.velocity, partner2!, velocity: true);
      game.aiPartner!.stamina = partner2!.stamina;
      game.aiPartner!.isSwinging = partner2!.isSwinging;
      game.aiPartner!.animState = PlayerAnimState.values.firstWhere(
        (e) => e.name == partner2!.animState,
        orElse: () => PlayerAnimState.idle,
      );
    }

    // Synchronize scoring
    game.scoreController.applySyncState(
      playerScore: playerScore,
      aiScore: aiScore,
      isPlayerServing: isPlayerServing,
      serverNumber: serverNumber,
      servingPrimary: servingPrimary,
    );

    // Synchronize state & announcements
    game.state = GameState.values.firstWhere(
      (e) => e.name == gameState,
      orElse: () => GameState.rally,
    );
    if (lastMessage != null && lastMessage!.isNotEmpty) {
      game.lastMessage = lastMessage!;
    }
    final feedbackPosition = timingPosition;
    final gradeName = timingGrade;
    if (feedbackPosition != null &&
        gradeName != null &&
        timingRevision > game.contactFeedbackRevision) {
      final grade = SwingTimingGrade.values.firstWhere(
        (value) => value.name == gradeName,
        orElse: () => SwingTimingGrade.good,
      );
      game.applySyncedContactFeedback(
        ContactFeedback(
          grade: grade,
          position: Vec3(
            feedbackPosition.x,
            feedbackPosition.y,
            feedbackPosition.z,
          ),
          playerSlot: timingPlayerSlot,
          revision: timingRevision,
          remaining: timingRemaining.clamp(0.0, 0.65).toDouble(),
        ),
      );
    } else if (timingRevision != 0 &&
        timingRevision >= game.contactFeedbackRevision) {
      game.contactFeedbackRevision = timingRevision;
      game.contactFeedback = null;
    }
  }
}
