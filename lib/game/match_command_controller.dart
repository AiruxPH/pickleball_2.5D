import 'dart:ui';

import '../utils/constants.dart';
import 'pickleball_game.dart';

/// A source-neutral command that can come from touch controls, a keyboard,
/// a bot, replay playback, or a multiplayer transport.
enum MatchCommandType { movement, aim, serve, shot, toggleUltimate }

class MatchCommand {
  const MatchCommand._({
    required this.type,
    this.x,
    this.y,
    this.shotType,
  });

  const MatchCommand.movement(double x, double y)
      : this._(type: MatchCommandType.movement, x: x, y: y);

  const MatchCommand.aim(double x, double y)
      : this._(type: MatchCommandType.aim, x: x, y: y);

  const MatchCommand.clearAim() : this._(type: MatchCommandType.aim);

  const MatchCommand.serve() : this._(type: MatchCommandType.serve);

  const MatchCommand.shot(ShotType shotType)
      : this._(type: MatchCommandType.shot, shotType: shotType);

  const MatchCommand.toggleUltimate()
      : this._(type: MatchCommandType.toggleUltimate);

  final MatchCommandType type;
  final double? x;
  final double? y;
  final ShotType? shotType;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (shotType != null) 'shotType': shotType!.name,
      };

  factory MatchCommand.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = MatchCommandType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MatchCommandType.movement,
    );
    final shotName = json['shotType'] as String?;
    final shotType = shotName != null
        ? ShotType.values.firstWhere(
            (e) => e.name == shotName,
            orElse: () => ShotType.normal,
          )
        : null;
    return MatchCommand._(
      type: type,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      shotType: shotType,
    );
  }
}

typedef MatchCommandObserver = void Function(MatchCommand command);

/// Capability exposed to input sources. It permits commands, not direct
/// access to mutable simulation state.
abstract interface class MatchCommandSink {
  void move(double x, double y);
  void stopMoving();
  void aim(Offset direction);
  void clearAim();
  void serve();
  void shot(ShotType type);
  void toggleUltimate();
}

/// The single input gateway for a match.
///
/// Keeping input translation outside [PickleballGame] lets future bot,
/// replay, local multiplayer, and online sources issue the same commands as
/// the current UI without gaining direct access to physics or scoring state.
class MatchCommandController implements MatchCommandSink {
  MatchCommandController({
    required this.game,
    this.playerSlot = 0,
    this.onDispatched,
  });

  final PickleballGame game;
  final int playerSlot;
  final MatchCommandObserver? onDispatched;

  void dispatch(MatchCommand command) {
    switch (command.type) {
      case MatchCommandType.movement:
        _isOpponent
            ? game.setOpponentJoystick(
                _safeAxis(command.x),
                _safeAxis(command.y),
              )
            : game.setJoystick(
                _safeAxis(command.x),
                _safeAxis(command.y),
              );
        break;
      case MatchCommandType.aim:
        final x = command.x;
        final y = command.y;
        if (x == null || y == null || !x.isFinite || !y.isFinite) {
          _isOpponent ? game.setOpponentSwipe(null) : game.setSwipe(null);
        } else {
          final direction = Offset(x, y);
          final normalized =
              direction.distance == 0 ? null : direction / direction.distance;
          _isOpponent
              ? game.setOpponentSwipe(normalized)
              : game.setSwipe(
                  normalized,
                );
        }
        break;
      case MatchCommandType.serve:
        _isOpponent
            ? game.setOpponentServePressed(true)
            : game.setServePressed(true);
        break;
      case MatchCommandType.shot:
        _dispatchShot(command.shotType ?? ShotType.normal);
        break;
      case MatchCommandType.toggleUltimate:
        if (!_isOpponent) game.toggleArmUltimate();
        break;
    }
    onDispatched?.call(command);
  }

  @override
  void move(double x, double y) => dispatch(MatchCommand.movement(x, y));

  @override
  void stopMoving() => dispatch(const MatchCommand.movement(0, 0));

  @override
  void aim(Offset direction) =>
      dispatch(MatchCommand.aim(direction.dx, direction.dy));

  @override
  void clearAim() => dispatch(const MatchCommand.clearAim());

  @override
  void serve() => dispatch(const MatchCommand.serve());

  @override
  void shot(ShotType type) => dispatch(MatchCommand.shot(type));

  @override
  void toggleUltimate() => dispatch(const MatchCommand.toggleUltimate());

  bool get _isOpponent => playerSlot == 1;

  double _safeAxis(double? value) {
    if (value == null || !value.isFinite) return 0;
    return value.clamp(-1.0, 1.0).toDouble();
  }

  void _dispatchShot(ShotType type) {
    if (_isOpponent) {
      game.queueOpponentShot(type == ShotType.ultimate ? ShotType.power : type);
      return;
    }
    switch (type) {
      case ShotType.normal:
        game.setHitPressed(true);
        break;
      case ShotType.power:
        game.setPowerPressed(true);
        break;
      case ShotType.smash:
        game.queueShot(ShotType.smash);
        break;
      case ShotType.lob:
        game.setLobPressed(true);
        break;
      case ShotType.drop:
        game.setDropPressed(true);
        break;
      case ShotType.ultimate:
        game.setUltimatePressed(true);
        break;
    }
  }
}
