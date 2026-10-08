// Tournament Model
// Manages an 8-player single-elimination bracket

enum TournamentRound { roundOf8, semiFinal, final_, champion }

class TournamentOpponent {
  final String name;
  final String title;
  final int difficulty; // 1=easy, 2=medium, 3=hard
  final int avatarIndex;

  const TournamentOpponent({
    required this.name,
    required this.title,
    required this.difficulty,
    required this.avatarIndex,
  });
}

const List<TournamentOpponent> kTournamentOpponents = [
  TournamentOpponent(name: 'RILEY CHASE', title: 'Club Rookie',    difficulty: 1, avatarIndex: 0),
  TournamentOpponent(name: 'MORGAN LEE',  title: 'Park Player',    difficulty: 1, avatarIndex: 1),
  TournamentOpponent(name: 'ALEX BROOKS', title: 'State Semi-Pro', difficulty: 2, avatarIndex: 2),
  TournamentOpponent(name: 'JAMIE STONE', title: 'Tour Amateur',   difficulty: 2, avatarIndex: 3),
  TournamentOpponent(name: 'TAYLOR NOVA', title: 'Regional Elite', difficulty: 2, avatarIndex: 4),
  TournamentOpponent(name: 'CASEY FORD',  title: 'Pro Circuit',    difficulty: 3, avatarIndex: 5),
  TournamentOpponent(name: 'SAM VANCE',   title: 'Tour Pro',       difficulty: 3, avatarIndex: 6),
  TournamentOpponent(name: 'LORINE DIAZ', title: 'Grand Champion', difficulty: 3, avatarIndex: 7),
];

class TournamentState {
  // Which round we are currently on (index into the 3-round bracket)
  int currentRound; // 0 = R8, 1 = SF, 2 = Final
  // Results: true = player won, false = player lost, null = not played
  List<bool?> results; // length 3
  bool isComplete;
  bool playerWon;

  TournamentState({
    this.currentRound = 0,
    List<bool?>? results,
    this.isComplete = false,
    this.playerWon = false,
  }) : results = results ?? [null, null, null];

  /// Opponent for the current round
  TournamentOpponent get currentOpponent {
    switch (currentRound) {
      case 0: return kTournamentOpponents[0]; // Round of 8 (easy)
      case 1: return kTournamentOpponents[3]; // Semi-final (medium)
      case 2: return kTournamentOpponents[7]; // Final (hard)
      default: return kTournamentOpponents[7];
    }
  }

  String get currentRoundName {
    switch (currentRound) {
      case 0: return 'QUARTER-FINAL';
      case 1: return 'SEMI-FINAL';
      case 2: return 'FINAL';
      default: return 'CHAMPION';
    }
  }

  void recordResult(bool won) {
    if (currentRound < 3) {
      results[currentRound] = won;
      if (won) {
        if (currentRound == 2) {
          isComplete = true;
          playerWon = true;
        } else {
          currentRound++;
        }
      } else {
        isComplete = true;
        playerWon = false;
      }
    }
  }

  void reset() {
    currentRound = 0;
    results = [null, null, null];
    isComplete = false;
    playerWon = false;
  }

  Map<String, dynamic> toJson() => {
    'currentRound': currentRound,
    'results': results.map((r) => r).toList(),
    'isComplete': isComplete,
    'playerWon': playerWon,
  };

  void fromJson(Map<String, dynamic> json) {
    currentRound = (json['currentRound'] as int?) ?? 0;
    isComplete = (json['isComplete'] as bool?) ?? false;
    playerWon = (json['playerWon'] as bool?) ?? false;
    if (json['results'] is List) {
      final raw = json['results'] as List;
      results = raw.map((e) => e as bool?).toList();
      while (results.length < 3) { results.add(null); }
    }
  }
}
