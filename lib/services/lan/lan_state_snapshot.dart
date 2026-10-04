import '../../game/pickleball_game.dart';
import '../../models/pickleball.dart';
import '../../models/player.dart';
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
    required this.timestamp,
  });

  final LanEntityState ball;
  final String ballState;
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
  final int timestamp;

  Map<String, dynamic> toJson() => {
        'ball': ball.toJson(),
        'bState': ballState,
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
        'ts': timestamp,
      };

  factory LanStateSnapshot.fromJson(Map<String, dynamic> json) {
    return LanStateSnapshot(
      ball: LanEntityState.fromJson(
        Map<String, dynamic>.from(json['ball'] as Map? ?? {}),
      ),
      ballState: json['bState'] as String? ?? 'inFlight',
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
      playerScore: json['pScore'] as int? ?? 0,
      aiScore: json['aScore'] as int? ?? 0,
      serverNumber: json['srvNum'] as int? ?? 1,
      isPlayerServing: json['isPSrv'] == true,
      servingPrimary: json['srvPri'] == true,
      gameState: json['gState'] as String? ?? 'rally',
      lastMessage: json['msg'] as String?,
      timestamp: json['ts'] as int? ?? 0,
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
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void applyToGame(PickleballGame game) {
    // Synchronize ball
    game.ball.position = Vec3(ball.x, ball.y, ball.z);
    game.ball.velocity = Vec3(ball.vx, ball.vy, ball.vz);
    game.ball.state = BallState.values.firstWhere(
      (e) => e.name == ballState,
      orElse: () => BallState.inFlight,
    );

    // Synchronize players
    game.player.position = Vec3(player1.x, player1.y, player1.z);
    game.player.velocity = Vec3(player1.vx, player1.vy, player1.vz);
    game.player.stamina = player1.stamina;
    game.player.isSwinging = player1.isSwinging;
    game.player.animState = PlayerAnimState.values.firstWhere(
      (e) => e.name == player1.animState,
      orElse: () => PlayerAnimState.idle,
    );

    game.ai.position = Vec3(player2.x, player2.y, player2.z);
    game.ai.velocity = Vec3(player2.vx, player2.vy, player2.vz);
    game.ai.stamina = player2.stamina;
    game.ai.isSwinging = player2.isSwinging;
    game.ai.animState = PlayerAnimState.values.firstWhere(
      (e) => e.name == player2.animState,
      orElse: () => PlayerAnimState.idle,
    );

    if (partner1 != null && game.playerPartner != null) {
      game.playerPartner!.position = Vec3(partner1!.x, partner1!.y, partner1!.z);
      game.playerPartner!.velocity = Vec3(partner1!.vx, partner1!.vy, partner1!.vz);
      game.playerPartner!.stamina = partner1!.stamina;
      game.playerPartner!.isSwinging = partner1!.isSwinging;
      game.playerPartner!.animState = PlayerAnimState.values.firstWhere(
        (e) => e.name == partner1!.animState,
        orElse: () => PlayerAnimState.idle,
      );
    }

    if (partner2 != null && game.aiPartner != null) {
      game.aiPartner!.position = Vec3(partner2!.x, partner2!.y, partner2!.z);
      game.aiPartner!.velocity = Vec3(partner2!.vx, partner2!.vy, partner2!.vz);
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
  }
}
