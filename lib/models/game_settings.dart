import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'shop_items.dart';
import 'achievement.dart';
import 'tournament.dart';
import 'career.dart';
import 'ultimate_skill.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Game settings model — stores all user preferences
/// Notifies listeners when any setting changes
/// ─────────────────────────────────────────────────────────────

enum AIDifficulty { easy, medium, hard }

enum GraphicsQuality { low, medium, high }

class GameSettings extends ChangeNotifier {
  // ── AI ─────────────────────────────────────────────────────
  AIDifficulty _difficulty = AIDifficulty.medium;
  AIDifficulty get difficulty => _difficulty;
  set difficulty(AIDifficulty v) {
    _difficulty = v;
    notifyListeners();
  }

  // ── Audio ──────────────────────────────────────────────────
  double _musicVolume = 0.7;
  double get musicVolume => _musicVolume;
  set musicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  double _sfxVolume = 0.8;
  double get sfxVolume => _sfxVolume;
  set sfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  // ── Graphics & Performance ─────────────────────────────────
  GraphicsQuality _graphicsQuality = GraphicsQuality.high;
  GraphicsQuality get graphicsQuality => _graphicsQuality;
  set graphicsQuality(GraphicsQuality v) {
    _graphicsQuality = v;
    notifyListeners();
  }

  int _targetFps = 60;
  int get targetFps => _targetFps;
  set targetFps(int v) {
    _targetFps = (v == 30) ? 30 : 60;
    notifyListeners();
  }

  bool get isLowEndMode => _graphicsQuality == GraphicsQuality.low;

  // ── Controls ───────────────────────────────────────────────
  double _joystickSensitivity = 1.0;
  double get joystickSensitivity => _joystickSensitivity;
  set joystickSensitivity(double v) {
    _joystickSensitivity = v.clamp(0.5, 2.0);
    notifyListeners();
  }

  // ── Court Theme ────────────────────────────────────────────
  CourtTheme _courtTheme = CourtTheme.tournament;
  CourtTheme get courtTheme => _courtTheme;
  set courtTheme(CourtTheme v) {
    _courtTheme = v;
    notifyListeners();
  }

  // ── Equipped Ultimate Skill ────────────────────────────────
  UltimateType? get equippedPaddleSkill =>
      getPaddleById(_equippedPaddleId).specialSkill;
  bool get hasEquippedPaddleSkill => equippedPaddleSkill != null;
  UltimateType get equippedUltimate =>
      equippedPaddleSkill ?? UltimateType.thunderbolt;
  @Deprecated('Special skills are selected by equipping their paddle.')
  void equipUltimate(UltimateType type) {}

  bool _dynamicJoystick = true;
  bool get dynamicJoystick => _dynamicJoystick;
  set dynamicJoystick(bool value) {
    _dynamicJoystick = value;
    notifyListeners();
  }

  double _joystickX = 0.13;
  double _joystickY = 0.78;
  double _actionsX = 0.84;
  double _actionsY = 0.76;
  Offset get joystickHudPosition => Offset(_joystickX, _joystickY);
  Offset get actionsHudPosition => Offset(_actionsX, _actionsY);

  void setJoystickHudPosition(Offset value) {
    _joystickX = value.dx.clamp(0.06, 0.94);
    _joystickY = value.dy.clamp(0.12, 0.92);
    notifyListeners();
  }

  void setActionsHudPosition(Offset value) {
    _actionsX = value.dx.clamp(0.06, 0.94);
    _actionsY = value.dy.clamp(0.12, 0.92);
    notifyListeners();
  }

  // ── Player Profile ─────────────────────────────────────────
  String _playerName = 'John Doe';
  String get playerName => _playerName;
  set playerName(String v) {
    _playerName = v;
    notifyListeners();
  }

  int _playerLevel = 5;
  int get playerLevel => _playerLevel;
  set playerLevel(int v) {
    _playerLevel = v;
    notifyListeners();
  }

  int _playerXp = 580;
  int get playerXp => _playerXp;
  set playerXp(int v) {
    _playerXp = v;
    notifyListeners();
  }

  int _playerMaxXp = 750;
  int get playerMaxXp => _playerMaxXp;
  set playerMaxXp(int v) {
    _playerMaxXp = v;
    notifyListeners();
  }

  int _coins = 10386;
  int get coins => _coins;
  set coins(int v) {
    _coins = v;
    notifyListeners();
  }

  int _gems = 8161;
  int get gems => _gems;
  set gems(int v) {
    _gems = v;
    notifyListeners();
  }

  int _avatarIndex = 0;
  int get avatarIndex => _avatarIndex;
  set avatarIndex(int v) {
    _avatarIndex = v;
    notifyListeners();
  }

  int _matchesPlayed = 48;
  int get matchesPlayed => _matchesPlayed;
  set matchesPlayed(int v) {
    _matchesPlayed = v;
    notifyListeners();
  }

  int _matchesWon = 39;
  int get matchesWon => _matchesWon;
  set matchesWon(int v) {
    _matchesWon = v;
    notifyListeners();
  }

  int _winStreak = 7;
  int get winStreak => _winStreak;
  set winStreak(int v) {
    _winStreak = v;
    notifyListeners();
  }

  int _aces = 18;
  int get aces => _aces;
  set aces(int v) {
    _aces = v;
    notifyListeners();
  }

  // ── Extended Stats ─────────────────────────────────────────
  int _totalSmashes = 0;
  int get totalSmashes => _totalSmashes;

  int _longestRally = 0;
  int get longestRally => _longestRally;

  int _tournamentWins = 0;
  int get tournamentWins => _tournamentWins;

  int _totalCoinsSpent = 0;
  int get totalCoinsSpent => _totalCoinsSpent;

  double get winPercentage =>
      _matchesPlayed == 0 ? 0.0 : (_matchesWon / _matchesPlayed * 100);

  void recordMatchResult({
    required bool won,
    required int playerScore,
    required int aiScore,
    int smashesThisMatch = 0,
    int longestRallyThisMatch = 0,
    bool isPerfect = false,
    bool isComeback = false,
    bool isTournament = false,
    double matchDurationSeconds = 0,
  }) {
    _matchesPlayed++;
    if (won) {
      _matchesWon++;
      _winStreak++;
    } else {
      _winStreak = 0;
    }
    _totalSmashes += smashesThisMatch;
    if (longestRallyThisMatch > _longestRally) {
      _longestRally = longestRallyThisMatch;
    }
    if (isTournament && won) _tournamentWins++;

    // Achievements
    if (won) {
      updateAchievementProgress('first_win', 1);
      updateAchievementProgress('ten_wins', 1);
      updateAchievementProgress('fifty_wins', 1);
      if (isPerfect) updateAchievementProgress('perfect_game', 1);
      if (isComeback) updateAchievementProgress('comeback_kid', 1);
      if (isTournament) updateAchievementProgress('tournament_champ', 1);
      if (matchDurationSeconds > 0 && matchDurationSeconds < 180) {
        updateAchievementProgress('speed_demon', 1);
      }
    }
    if (smashesThisMatch > 0) {
      updateAchievementProgress('smash_master', smashesThisMatch);
    }
    if (longestRallyThisMatch >= 30) {
      updateAchievementProgress('rally_king', longestRallyThisMatch);
    }
    if (longestRallyThisMatch >= 50) {
      updateAchievementProgress('fifty_rally', longestRallyThisMatch);
    }
    notifyListeners();
  }

  // ── Inventory & Equipment ───────────────────────────────────
  String _equippedPaddleId = 'paddle_standard';
  String get equippedPaddleId => _equippedPaddleId;

  List<String> _unlockedPaddleIds = ['paddle_standard'];
  List<String> get unlockedPaddleIds => List.unmodifiable(_unlockedPaddleIds);

  String _equippedPlayerId = 'player_rookie';
  String get equippedPlayerId => _equippedPlayerId;

  List<String> _unlockedPlayerIds = ['player_rookie'];
  List<String> get unlockedPlayerIds => List.unmodifiable(_unlockedPlayerIds);

  bool isPaddleUnlocked(String id) => _unlockedPaddleIds.contains(id);
  bool isPlayerUnlocked(String id) => _unlockedPlayerIds.contains(id);

  bool buyPaddle(PaddleItem item) {
    if (isPaddleUnlocked(item.id)) {
      equipPaddle(item.id);
      return true;
    }
    if (item.isGems) {
      if (_gems < item.gemPrice) return false;
      _gems -= item.gemPrice;
    } else {
      if (_coins < item.coinPrice) return false;
      _coins -= item.coinPrice;
      _totalCoinsSpent += item.coinPrice;
      updateAchievementProgress('big_spender', item.coinPrice);
    }
    _unlockedPaddleIds.add(item.id);
    _equippedPaddleId = item.id;
    updateAchievementProgress('collector', 1);
    notifyListeners();
    return true;
  }

  void equipPaddle(String id) {
    if (isPaddleUnlocked(id) && _equippedPaddleId != id) {
      _equippedPaddleId = id;
      notifyListeners();
    }
  }

  bool buyPlayer(PlayerSkinItem item) {
    if (isPlayerUnlocked(item.id)) {
      equipPlayer(item.id);
      return true;
    }
    if (item.isGems) {
      if (_gems < item.gemPrice) return false;
      _gems -= item.gemPrice;
    } else {
      if (_coins < item.coinPrice) return false;
      _coins -= item.coinPrice;
      _totalCoinsSpent += item.coinPrice;
      updateAchievementProgress('big_spender', item.coinPrice);
    }
    _unlockedPlayerIds.add(item.id);
    _equippedPlayerId = item.id;
    notifyListeners();
    return true;
  }

  void equipPlayer(String id) {
    if (isPlayerUnlocked(id) && _equippedPlayerId != id) {
      _equippedPlayerId = id;
      notifyListeners();
    }
  }

  // ── Daily Bonus ────────────────────────────────────────────
  String _lastBonusClaimDate = '';
  String get lastBonusClaimDate => _lastBonusClaimDate;
  int _totalBonusClaims = 0;

  /// Returns true only if the player hasn't claimed the bonus today.
  bool get canClaimDailyBonus {
    if (_lastBonusClaimDate.isEmpty) return true;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _lastBonusClaimDate != todayStr;
  }

  /// Returns true if the bonus was successfully claimed, false if already claimed today.
  bool claimBonus(int bonusCoins, int bonusGems) {
    if (!canClaimDailyBonus) return false;
    final today = DateTime.now();
    _lastBonusClaimDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _coins += bonusCoins;
    _gems += bonusGems;
    _totalBonusClaims++;
    updateAchievementProgress('daily_devotee', 1);
    notifyListeners();
    return true;
  }

  bool exchangeGemsForCoins({required int gemsToSpend, required int coinsToGet}) {
    if (_gems >= gemsToSpend) {
      _gems -= gemsToSpend;
      _coins += coinsToGet;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Credits a validated gem-store purchase. The current shop calls this from
  /// its clearly labelled preview flow; production billing must invoke it only
  /// after the platform purchase receipt has been verified.
  bool creditGemPurchase(int amount) {
    if (amount <= 0) return false;
    _gems += amount;
    notifyListeners();
    return true;
  }

  // ── Achievements ───────────────────────────────────────────
  Map<String, int> _achievementProgress = {};
  Set<String> _unlockedAchievements = {};
  Set<String> _seenAchievements = {};

  Map<String, int> get achievementProgress => Map.unmodifiable(_achievementProgress);
  Set<String> get unlockedAchievements => Set.unmodifiable(_unlockedAchievements);
  bool get hasUnseenAchievements =>
      _unlockedAchievements.difference(_seenAchievements).isNotEmpty;

  void markAchievementsSeen() {
    _seenAchievements = Set<String>.from(_unlockedAchievements);
    notifyListeners();
  }

  bool isAchievementUnlocked(String id) => _unlockedAchievements.contains(id);
  int getAchievementProgress(String id) => _achievementProgress[id] ?? 0;

  /// Updates progress for an achievement; auto-unlocks when target reached.
  /// Returns true if this call caused an unlock.
  bool updateAchievementProgress(String id, int delta) {
    if (_unlockedAchievements.contains(id)) return false;
    final achievement = getAchievementById(id);
    if (achievement == null) return false;
    final prev = _achievementProgress[id] ?? 0;
    final next = prev + delta;
    _achievementProgress[id] = next;
    if (next >= achievement.targetCount) {
      _unlockedAchievements.add(id);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Daily Challenge ────────────────────────────────────────
  String _dailyChallengeDate = '';
  String _dailyChallengeType = '';
  int _dailyChallengeProgress = 0;
  int _dailyChallengeTarget = 0;
  bool _dailyChallengeCompleted = false;

  String get dailyChallengeType => _dailyChallengeType;
  int get dailyChallengeProgress => _dailyChallengeProgress;
  int get dailyChallengeTarget => _dailyChallengeTarget;
  bool get dailyChallengeCompleted => _dailyChallengeCompleted;

  String get dailyChallengeDescription {
    switch (_dailyChallengeType) {
      case 'win_match': return 'Win $_dailyChallengeTarget match(es)';
      case 'smash': return 'Land $_dailyChallengeTarget smash shot(s)';
      case 'rally': return 'Achieve a $_dailyChallengeTarget-shot rally';
      case 'ace': return 'Serve $_dailyChallengeTarget ace(s)';
      default: return 'Complete a match';
    }
  }

  void _refreshDailyChallenge() {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_dailyChallengeDate == todayStr) return; // Already set for today
    _dailyChallengeDate = todayStr;
    _dailyChallengeCompleted = false;
    _dailyChallengeProgress = 0;
    // Rotate based on day of year
    final dayOfYear = today.difference(DateTime(today.year)).inDays;
    final types = ['win_match', 'smash', 'rally', 'ace'];
    final targets = [1, 3, 15, 2];
    final idx = dayOfYear % types.length;
    _dailyChallengeType = types[idx];
    _dailyChallengeTarget = targets[idx];
  }

  void addDailyChallengeProgress(String type, int amount) {
    _refreshDailyChallenge();
    if (_dailyChallengeCompleted || _dailyChallengeType != type) return;
    _dailyChallengeProgress += amount;
    if (_dailyChallengeProgress >= _dailyChallengeTarget) {
      _dailyChallengeCompleted = true;
      _coins += 500;
      _gems += 50;
    }
    notifyListeners();
  }

  /// Call once on app start to ensure today's challenge is set
  void ensureDailyChallenge() => _refreshDailyChallenge();

  // ── Tournament ─────────────────────────────────────────────
  TournamentState tournament = TournamentState();

  // ── Career ─────────────────────────────────────────────────
  CareerState career = CareerState();

  // ── Leaderboard ────────────────────────────────────────────
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> get leaderboard => List.unmodifiable(_leaderboard);

  void addLeaderboardEntry(String name, int wins, double winPct) {
    _leaderboard.add({'name': name, 'wins': wins, 'winPct': winPct});
    _leaderboard.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    if (_leaderboard.length > 20) _leaderboard = _leaderboard.take(20).toList();
    notifyListeners();
  }

  // ── Serialization ──────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> achievementProgressJson = {};
    for (final e in _achievementProgress.entries) {
      achievementProgressJson[e.key] = e.value;
    }
    return {
      'difficulty': _difficulty.index,
      'musicVolume': _musicVolume,
      'sfxVolume': _sfxVolume,
      'graphicsQuality': _graphicsQuality.index,
      'targetFps': _targetFps,
      'joystickSensitivity': _joystickSensitivity,
      'dynamicJoystick': _dynamicJoystick,
      'joystickHudX': _joystickX,
      'joystickHudY': _joystickY,
      'actionsHudX': _actionsX,
      'actionsHudY': _actionsY,
      'courtTheme': _courtTheme.index,
      'playerName': _playerName,
      'playerLevel': _playerLevel,
      'playerXp': _playerXp,
      'playerMaxXp': _playerMaxXp,
      'coins': _coins,
      'gems': _gems,
      'avatarIndex': _avatarIndex,
      'matchesPlayed': _matchesPlayed,
      'matchesWon': _matchesWon,
      'winStreak': _winStreak,
      'aces': _aces,
      'totalSmashes': _totalSmashes,
      'longestRally': _longestRally,
      'tournamentWins': _tournamentWins,
      'totalCoinsSpent': _totalCoinsSpent,
      'equippedPaddleId': _equippedPaddleId,
      'unlockedPaddleIds': _unlockedPaddleIds,
      'equippedPlayerId': _equippedPlayerId,
      'unlockedPlayerIds': _unlockedPlayerIds,
      'lastBonusClaimDate': _lastBonusClaimDate,
      'totalBonusClaims': _totalBonusClaims,
      'achievementProgress': achievementProgressJson,
      'unlockedAchievements': _unlockedAchievements.toList(),
      'seenAchievements': _seenAchievements.toList(),
      'dailyChallengeDate': _dailyChallengeDate,
      'dailyChallengeType': _dailyChallengeType,
      'dailyChallengeProgress': _dailyChallengeProgress,
      'dailyChallengeTarget': _dailyChallengeTarget,
      'dailyChallengeCompleted': _dailyChallengeCompleted,
      'tournament': tournament.toJson(),
      'career': career.toJson(),
      'leaderboard': _leaderboard,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _difficulty = AIDifficulty.values[json['difficulty'] as int? ?? 1];
    _musicVolume = (json['musicVolume'] as double? ?? 0.7).clamp(0.0, 1.0);
    _sfxVolume = (json['sfxVolume'] as double? ?? 0.8).clamp(0.0, 1.0);
    _graphicsQuality = GraphicsQuality.values[json['graphicsQuality'] as int? ?? 2];
    _targetFps = (json['targetFps'] as int?) ?? 60;
    _joystickSensitivity = (json['joystickSensitivity'] as double? ?? 1.0).clamp(0.5, 2.0);
    _dynamicJoystick = json['dynamicJoystick'] as bool? ?? true;
    _joystickX = (json['joystickHudX'] as num?)?.toDouble() ?? 0.13;
    _joystickY = (json['joystickHudY'] as num?)?.toDouble() ?? 0.78;
    _actionsX = (json['actionsHudX'] as num?)?.toDouble() ?? 0.84;
    _actionsY = (json['actionsHudY'] as num?)?.toDouble() ?? 0.76;
    final courtIdx = (json['courtTheme'] as int?) ?? 0;
    _courtTheme = (courtIdx >= 0 && courtIdx < CourtTheme.values.length)
        ? CourtTheme.values[courtIdx]
        : CourtTheme.tournament;
    _playerName = (json['playerName'] as String?) ?? 'John Doe';
    _playerLevel = (json['playerLevel'] as int?) ?? 5;
    _playerXp = (json['playerXp'] as int?) ?? 580;
    _playerMaxXp = (json['playerMaxXp'] as int?) ?? 750;
    _coins = (json['coins'] as int?) ?? 10386;
    _gems = (json['gems'] as int?) ?? 8161;
    _avatarIndex = (json['avatarIndex'] as int?) ?? 0;
    _matchesPlayed = (json['matchesPlayed'] as int?) ?? 48;
    _matchesWon = (json['matchesWon'] as int?) ?? 39;
    _winStreak = (json['winStreak'] as int?) ?? 7;
    _aces = (json['aces'] as int?) ?? 18;
    _totalSmashes = (json['totalSmashes'] as int?) ?? 0;
    _longestRally = (json['longestRally'] as int?) ?? 0;
    _tournamentWins = (json['tournamentWins'] as int?) ?? 0;
    _totalCoinsSpent = (json['totalCoinsSpent'] as int?) ?? 0;

    _equippedPaddleId = (json['equippedPaddleId'] as String?) ?? 'paddle_standard';
    if (json['unlockedPaddleIds'] is List) {
      _unlockedPaddleIds = List<String>.from(json['unlockedPaddleIds'] as List);
      if (!_unlockedPaddleIds.contains('paddle_standard')) {
        _unlockedPaddleIds.insert(0, 'paddle_standard');
      }
    }
    _equippedPlayerId = (json['equippedPlayerId'] as String?) ?? 'player_rookie';
    if (json['unlockedPlayerIds'] is List) {
      _unlockedPlayerIds = List<String>.from(json['unlockedPlayerIds'] as List);
      if (!_unlockedPlayerIds.contains('player_rookie')) {
        _unlockedPlayerIds.insert(0, 'player_rookie');
      }
    }
    _lastBonusClaimDate = (json['lastBonusClaimDate'] as String?) ?? '';
    _totalBonusClaims = (json['totalBonusClaims'] as int?) ?? 0;

    // Achievements
    if (json['achievementProgress'] is Map) {
      _achievementProgress = {};
      (json['achievementProgress'] as Map).forEach((k, v) {
        _achievementProgress[k.toString()] = (v as int?) ?? 0;
      });
    }
    if (json['unlockedAchievements'] is List) {
      _unlockedAchievements = Set<String>.from(json['unlockedAchievements'] as List);
    }
    if (json['seenAchievements'] is List) {
      _seenAchievements = Set<String>.from(json['seenAchievements'] as List);
    }

    // Daily Challenge
    _dailyChallengeDate = (json['dailyChallengeDate'] as String?) ?? '';
    _dailyChallengeType = (json['dailyChallengeType'] as String?) ?? '';
    _dailyChallengeProgress = (json['dailyChallengeProgress'] as int?) ?? 0;
    _dailyChallengeTarget = (json['dailyChallengeTarget'] as int?) ?? 1;
    _dailyChallengeCompleted = (json['dailyChallengeCompleted'] as bool?) ?? false;

    // Tournament
    if (json['tournament'] is Map) {
      tournament.fromJson(json['tournament'] as Map<String, dynamic>);
    }

    // Career
    if (json['career'] is Map) {
      career.fromJson(json['career'] as Map<String, dynamic>);
    }

    // Leaderboard
    if (json['leaderboard'] is List) {
      _leaderboard = (json['leaderboard'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    _refreshDailyChallenge();
    notifyListeners();
  }

  // ── Difficulty helpers ─────────────────────────────────────
  double get aiSpeed {
    switch (_difficulty) {
      case AIDifficulty.easy:   return 90.0;  // responsive but still forgiving
      case AIDifficulty.medium: return 100.0; // agile club player
      case AIDifficulty.hard:   return 130.0; // fast and aggressive pro
    }
  }

  double aiSpeedForDifficulty(int level) {
    switch (level) {
      case 1: return 90.0;
      case 2: return 100.0;
      case 3: return 130.0;
      default: return 100.0;
    }
  }

  double get aiReactionTime {
    // Contact timing is intentionally consistent across difficulty tiers.
    // Difficulty still changes movement speed, accuracy, and error chance.
    return 0.12;
  }

  double get aiAccuracy {
    switch (_difficulty) {
      case AIDifficulty.easy:   return 0.65; // centered, easy to return
      case AIDifficulty.medium: return 0.82; // good court placement
      case AIDifficulty.hard:   return 0.95; // pinpoint corner precision
    }
  }

  double get aiErrorChance {
    switch (_difficulty) {
      case AIDifficulty.easy:   return 0.15; // occasional unforced error
      case AIDifficulty.medium: return 0.07; // rare error
      case AIDifficulty.hard:   return 0.02; // elite consistency
    }
  }

  bool get showParticles => _graphicsQuality != GraphicsQuality.low;
  bool get showShadows    => _graphicsQuality == GraphicsQuality.high;
  bool get showBallTrail  => _graphicsQuality != GraphicsQuality.low;
  bool get useReducedUltimateEffects =>
      _graphicsQuality != GraphicsQuality.high;

  int get maxTrailLength {
    switch (_graphicsQuality) {
      case GraphicsQuality.low: return 3;
      case GraphicsQuality.medium: return 6;
      case GraphicsQuality.high: return 12;
    }
  }
}
