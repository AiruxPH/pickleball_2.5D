/// Stable traits that make two bots at the same difficulty play differently.
final class BotPersonality {
  const BotPersonality({
    required this.name,
    required this.aggressionAdjustment,
    required this.recoveryDepth,
    required this.aimSpread,
  });

  final String name;
  final double aggressionAdjustment;
  final double recoveryDepth;
  final double aimSpread;

  static const counterpuncher = BotPersonality(
    name: 'Counterpuncher',
    aggressionAdjustment: -0.22,
    recoveryDepth: 52,
    aimSpread: 0.08,
  );

  static const balanced = BotPersonality(
    name: 'Balanced',
    aggressionAdjustment: 0,
    recoveryDepth: 46,
    aimSpread: 0.06,
  );

  static const aggressor = BotPersonality(
    name: 'Aggressor',
    aggressionAdjustment: 0.25,
    recoveryDepth: 35,
    aimSpread: 0.1,
  );

  static const dinker = BotPersonality(
    name: 'Dinker',
    aggressionAdjustment: -0.15,
    recoveryDepth: 20, // Approaches the kitchen
    aimSpread: 0.05,
  );

  static const trickster = BotPersonality(
    name: 'Trickster',
    aggressionAdjustment: 0.10,
    recoveryDepth: 42,
    aimSpread: 0.12, // More erratic aim
  );

  static const values = [
    counterpuncher,
    balanced,
    aggressor,
    dinker,
    trickster,
  ];
}
