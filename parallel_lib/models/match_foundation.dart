import 'dart:async';

import '../utils/constants.dart';
import '../utils/game_math.dart';
import 'shot_mechanics.dart';

enum MatchBalanceProfile { standard, competitive }

extension MatchBalanceProfileX on MatchBalanceProfile {
  String get label => switch (this) {
        MatchBalanceProfile.standard => 'STANDARD',
        MatchBalanceProfile.competitive => 'COMPETITIVE',
      };

  String get description => switch (this) {
        MatchBalanceProfile.standard => 'Equipment stats and paddle skills enabled',
        MatchBalanceProfile.competitive => 'Cosmetic equipment with normalized stats',
      };

  static MatchBalanceProfile fromName(Object? value) {
    return MatchBalanceProfile.values.firstWhere(
      (profile) => profile.name == value,
      orElse: () => MatchBalanceProfile.standard,
    );
  }
}

enum RallyPhase { opening, baseline, kitchen, attackable }

enum MatchEventType {
  contact,
  bounce,
  rallyPhaseChanged,
  attackableBall,
  pointResult,
  matchEnded,
}

class MatchEvent {
  const MatchEvent({
    required this.type,
    required this.revision,
    required this.elapsedSeconds,
    this.playerSlot,
    this.nearTeam,
    this.position,
    this.shotType,
    this.timingGrade,
    this.spin,
    this.rallyPhase,
    this.result,
    this.rallyHits = 0,
    this.isFault = false,
    this.isWinner = false,
  });

  final MatchEventType type;
  final int revision;
  final double elapsedSeconds;
  final int? playerSlot;
  final bool? nearTeam;
  final Vec3? position;
  final ShotType? shotType;
  final SwingTimingGrade? timingGrade;
  final ShotSpin? spin;
  final RallyPhase? rallyPhase;
  final String? result;
  final int rallyHits;
  final bool isFault;
  final bool isWinner;
}

class MatchEventLog {
  final StreamController<MatchEvent> _controller =
      StreamController<MatchEvent>.broadcast(sync: true);
  int _revision = 0;

  Stream<MatchEvent> get events => _controller.stream;
  int get revision => _revision;

  MatchEvent publish(
    MatchEvent Function(int revision) create, {
    void Function(MatchEvent event)? beforeEmit,
  }) {
    final event = create(++_revision);
    beforeEmit?.call(event);
    _controller.add(event);
    return event;
  }

  void adoptRevision(int revision) {
    if (revision > _revision) _revision = revision;
  }

  void dispose() => _controller.close();
}

class MatchStats {
  double elapsedSeconds = 0;
  int contacts = 0;
  int bounces = 0;
  int pointsPlayed = 0;
  int winners = 0;
  int faults = 0;
  int longestRally = 0;
  int kitchenExchanges = 0;
  int lastAppliedEventRevision = 0;

  final Map<SwingTimingGrade, int> timing = {
    for (final grade in SwingTimingGrade.values) grade: 0,
  };
  final Map<ShotSpin, int> spin = {
    for (final value in ShotSpin.values) value: 0,
  };

  void record(MatchEvent event) {
    if (event.revision <= lastAppliedEventRevision) return;
    lastAppliedEventRevision = event.revision;
    elapsedSeconds = event.elapsedSeconds > elapsedSeconds
        ? event.elapsedSeconds
        : elapsedSeconds;
    switch (event.type) {
      case MatchEventType.contact:
        contacts++;
        if (event.timingGrade != null) {
          timing[event.timingGrade!] = (timing[event.timingGrade!] ?? 0) + 1;
        }
        if (event.spin != null) {
          spin[event.spin!] = (spin[event.spin!] ?? 0) + 1;
        }
        break;
      case MatchEventType.bounce:
        bounces++;
        break;
      case MatchEventType.pointResult:
        pointsPlayed++;
        if (event.isFault) faults++;
        if (event.isWinner) winners++;
        if (event.rallyHits > longestRally) longestRally = event.rallyHits;
        break;
      case MatchEventType.rallyPhaseChanged:
        if (event.rallyPhase == RallyPhase.kitchen) kitchenExchanges++;
        break;
      case MatchEventType.attackableBall:
      case MatchEventType.matchEnded:
        break;
    }
  }

  void advanceTime(double dt) {
    if (dt.isFinite && dt > 0) elapsedSeconds += dt;
  }

  void reset() {
    elapsedSeconds = 0;
    contacts = 0;
    bounces = 0;
    pointsPlayed = 0;
    winners = 0;
    faults = 0;
    longestRally = 0;
    kitchenExchanges = 0;
    lastAppliedEventRevision = 0;
    for (final key in timing.keys) {
      timing[key] = 0;
    }
    for (final key in spin.keys) {
      spin[key] = 0;
    }
  }

  Map<String, dynamic> toJson() => {
        't': elapsedSeconds,
        'c': contacts,
        'b': bounces,
        'p': pointsPlayed,
        'w': winners,
        'f': faults,
        'lr': longestRally,
        'k': kitchenExchanges,
        'er': lastAppliedEventRevision,
        'timing': {
          for (final entry in timing.entries)
            if (entry.value != 0) entry.key.name: entry.value,
        },
        'spin': {
          for (final entry in spin.entries)
            if (entry.value != 0) entry.key.name: entry.value,
        },
      };

  void applyJson(Map<String, dynamic> json) {
    elapsedSeconds = (json['t'] as num?)?.toDouble() ?? elapsedSeconds;
    contacts = (json['c'] as num?)?.toInt() ?? contacts;
    bounces = (json['b'] as num?)?.toInt() ?? bounces;
    pointsPlayed = (json['p'] as num?)?.toInt() ?? pointsPlayed;
    winners = (json['w'] as num?)?.toInt() ?? winners;
    faults = (json['f'] as num?)?.toInt() ?? faults;
    longestRally = (json['lr'] as num?)?.toInt() ?? longestRally;
    kitchenExchanges = (json['k'] as num?)?.toInt() ?? kitchenExchanges;
    lastAppliedEventRevision =
        (json['er'] as num?)?.toInt() ?? lastAppliedEventRevision;
    _applyEnumCounts(json['timing'], SwingTimingGrade.values, timing);
    _applyEnumCounts(json['spin'], ShotSpin.values, spin);
  }

  static void _applyEnumCounts<T extends Enum>(
    Object? raw,
    List<T> values,
    Map<T, int> destination,
  ) {
    if (raw is! Map) return;
    for (final value in values) {
      destination[value] = (raw[value.name] as num?)?.toInt() ?? 0;
    }
  }
}
