import 'package:flutter/foundation.dart';

enum LobbyType { local, online }

enum LobbyFormat { singles, doubles }

enum LobbySlotType { human, bot, open }

@immutable
class LobbyPlayerSlot {
  const LobbyPlayerSlot({
    required this.id,
    required this.name,
    required this.team,
    required this.type,
    this.isReady = false,
  });

  final String id;
  final String name;
  final int team;
  final LobbySlotType type;
  final bool isReady;

  LobbyPlayerSlot copyWith({bool? isReady}) => LobbyPlayerSlot(
        id: id,
        name: name,
        team: team,
        type: type,
        isReady: isReady ?? this.isReady,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'team': team,
        'type': type.name,
        'isReady': isReady,
      };

  factory LobbyPlayerSlot.fromJson(Map<String, dynamic> json) {
    return LobbyPlayerSlot(
      id: json['id'] as String? ?? 'slot',
      name: json['name'] as String? ?? 'PLAYER',
      team: json['team'] as int? ?? 1,
      type: LobbySlotType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => LobbySlotType.open,
      ),
      isReady: json['isReady'] == true,
    );
  }
}

/// Transport-neutral lobby state. Local UI owns it today; an online room can
/// later synchronize the same JSON payload without changing match startup.
class MatchLobby extends ChangeNotifier {
  MatchLobby._({
    required this.id,
    required this.type,
    required LobbyFormat format,
    required List<LobbyPlayerSlot> slots,
  })  : _format = format,
        _slots = slots;

  factory MatchLobby.local({LobbyFormat format = LobbyFormat.singles}) {
    return MatchLobby._(
      id: 'local-lobby',
      type: LobbyType.local,
      format: format,
      slots: _slotsFor(format),
    );
  }

  final String id;
  final LobbyType type;
  LobbyFormat _format;
  List<LobbyPlayerSlot> _slots;

  LobbyFormat get format => _format;
  List<LobbyPlayerSlot> get slots => List.unmodifiable(_slots);
  int get playerCount => humanSlots.length;
  int get maxPlayers => _slots.length;
  Iterable<LobbyPlayerSlot> get humanSlots =>
      _slots.where((slot) => slot.type == LobbySlotType.human);
  bool get canStart => humanSlots.isNotEmpty && humanSlots.every((s) => s.isReady);

  void setFormat(LobbyFormat value) {
    if (_format == value) return;
    _format = value;
    _slots = _slotsFor(value);
    notifyListeners();
  }

  void toggleReady(String slotId) {
    _slots = [
      for (final slot in _slots)
        if (slot.id == slotId && slot.type == LobbySlotType.human)
          slot.copyWith(isReady: !slot.isReady)
        else
          slot,
    ];
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'format': format.name,
        'slots': _slots.map((slot) => slot.toJson()).toList(),
      };

  factory MatchLobby.fromJson(Map<String, dynamic> json) {
    final format = LobbyFormat.values.firstWhere(
      (value) => value.name == json['format'],
      orElse: () => LobbyFormat.singles,
    );
    final rawSlots = json['slots'];
    return MatchLobby._(
      id: json['id'] as String? ?? 'lobby',
      type: LobbyType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => LobbyType.local,
      ),
      format: format,
      slots: rawSlots is List
          ? rawSlots
              .whereType<Map>()
              .map((slot) => LobbyPlayerSlot.fromJson(
                    Map<String, dynamic>.from(slot),
                  ))
              .toList()
          : _slotsFor(format),
    );
  }

  static List<LobbyPlayerSlot> _slotsFor(LobbyFormat format) => [
        const LobbyPlayerSlot(
          id: 'p1',
          name: 'PLAYER 1',
          team: 1,
          type: LobbySlotType.human,
        ),
        const LobbyPlayerSlot(
          id: 'p2',
          name: 'PLAYER 2',
          team: 2,
          type: LobbySlotType.human,
        ),
        if (format == LobbyFormat.doubles) ...[
          const LobbyPlayerSlot(
            id: 'bot-1',
            name: 'ALLY BOT',
            team: 1,
            type: LobbySlotType.bot,
            isReady: true,
          ),
          const LobbyPlayerSlot(
            id: 'bot-2',
            name: 'ALLY BOT',
            team: 2,
            type: LobbySlotType.bot,
            isReady: true,
          ),
        ],
      ];
}
