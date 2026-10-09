// Career Mode Model
// Tracks seasons, ranks, XP, and match history

enum CareerRank {
  beginner,
  amateur,
  clubPlayer,
  pro,
  elite,
  champion,
  legend,
}

extension CareerRankExtension on CareerRank {
  String get displayName {
    switch (this) {
      case CareerRank.beginner:   return 'BEGINNER';
      case CareerRank.amateur:    return 'AMATEUR';
      case CareerRank.clubPlayer: return 'CLUB PLAYER';
      case CareerRank.pro:        return 'PRO';
      case CareerRank.elite:      return 'ELITE';
      case CareerRank.champion:   return 'CHAMPION';
      case CareerRank.legend:     return 'LEGEND';
    }
  }

  int get xpRequired {
    switch (this) {
      case CareerRank.beginner:   return 0;
      case CareerRank.amateur:    return 200;
      case CareerRank.clubPlayer: return 600;
      case CareerRank.pro:        return 1400;
      case CareerRank.elite:      return 3000;
      case CareerRank.champion:   return 6000;
      case CareerRank.legend:     return 12000;
    }
  }

  int get nextXpRequired {
    const values = CareerRank.values;
    final idx = values.indexOf(this);
    if (idx + 1 < values.length) {
      return values[idx + 1].xpRequired;
    }
    return xpRequired; // Already max
  }

  bool get isMax => this == CareerRank.legend;
}

class CareerMatchResult {
  final String opponentName;
  final int playerScore;
  final int opponentScore;
  final bool won;
  final int xpEarned;
  final int coinsEarned;

  const CareerMatchResult({
    required this.opponentName,
    required this.playerScore,
    required this.opponentScore,
    required this.won,
    required this.xpEarned,
    required this.coinsEarned,
  });

  Map<String, dynamic> toJson() => {
    'opponentName': opponentName,
    'playerScore': playerScore,
    'opponentScore': opponentScore,
    'won': won,
    'xpEarned': xpEarned,
    'coinsEarned': coinsEarned,
  };

  factory CareerMatchResult.fromJson(Map<String, dynamic> json) =>
      CareerMatchResult(
        opponentName: (json['opponentName'] as String?) ?? 'CPU',
        playerScore: ((json['playerScore'] as num?)?.toInt()) ?? 0,
        opponentScore: ((json['opponentScore'] as num?)?.toInt()) ?? 0,
        won: (json['won'] as bool?) ?? false,
        xpEarned: ((json['xpEarned'] as num?)?.toInt()) ?? 0,
        coinsEarned: ((json['coinsEarned'] as num?)?.toInt()) ?? 0,
      );
}

class CareerState {
  int totalXp;
  int currentSeason;
  int matchesInSeason; // 0-7 (8 matches per season)
  List<CareerMatchResult> matchHistory;

  CareerState({
    this.totalXp = 0,
    this.currentSeason = 1,
    this.matchesInSeason = 0,
    List<CareerMatchResult>? matchHistory,
  }) : matchHistory = matchHistory ?? [];

  CareerRank get rank {
    CareerRank result = CareerRank.beginner;
    for (final r in CareerRank.values) {
      if (totalXp >= r.xpRequired) result = r;
    }
    return result;
  }

  int get xpToNextRank {
    final r = rank;
    if (r.isMax) return 0;
    return r.nextXpRequired - totalXp;
  }

  double get rankProgress {
    final r = rank;
    if (r.isMax) return 1.0;
    final base = r.xpRequired;
    final next = r.nextXpRequired;
    if (next <= base) return 1.0;
    return ((totalXp - base) / (next - base)).clamp(0.0, 1.0);
  }

  /// Difficulty for the next career match (ramps up over seasons)
  int get nextMatchDifficulty {
    final total = matchHistory.length;
    if (total < 4) return 1; // easy
    if (total < 12) return 2; // medium
    return 3; // hard
  }

  /// Name of the next opponent
  String get nextOpponentName {
    const names = [
      'RILEY CHASE', 'MORGAN LEE', 'ALEX BROOKS', 'JAMIE STONE',
      'TAYLOR NOVA', 'CASEY FORD', 'SAM VANCE', 'LORINE DIAZ',
      'JORDAN PEAK', 'RILEY STORM', 'DREW CHASE', 'QUINN NOVA',
    ];
    return names[matchHistory.length % names.length];
  }

  void addResult(CareerMatchResult result) {
    matchHistory.add(result);
    totalXp += result.xpEarned;
    matchesInSeason++;
    if (matchesInSeason >= 8) {
      matchesInSeason = 0;
      currentSeason++;
    }
  }

  Map<String, dynamic> toJson() => {
    'totalXp': totalXp,
    'currentSeason': currentSeason,
    'matchesInSeason': matchesInSeason,
    'matchHistory': matchHistory.map((r) => r.toJson()).toList(),
  };

  void fromJson(Map<String, dynamic> json) {
    totalXp = ((json['totalXp'] as num?)?.toInt()) ?? 0;
    currentSeason = ((json['currentSeason'] as num?)?.toInt()) ?? 1;
    matchesInSeason = ((json['matchesInSeason'] as num?)?.toInt()) ?? 0;
    if (json['matchHistory'] is List) {
      matchHistory = (json['matchHistory'] as List)
          .map((e) => CareerMatchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }
}
