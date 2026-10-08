enum ShotSpin { flat, topspin, slice }

enum SwingTimingGrade { perfect, good, early, late }

extension ShotSpinLabel on ShotSpin {
  String get label => switch (this) {
        ShotSpin.flat => 'FLAT',
        ShotSpin.topspin => 'TOP',
        ShotSpin.slice => 'SLICE',
      };
}

extension SwingTimingGradeLabel on SwingTimingGrade {
  String get label => name.toUpperCase();
}

final class SwingTimingModifiers {
  const SwingTimingModifiers({
    required this.speedMultiplier,
    required this.liftAssist,
    required this.spinMultiplier,
    required this.chargeBonus,
  });

  final double speedMultiplier;
  final double liftAssist;
  final double spinMultiplier;
  final double chargeBonus;
}

SwingTimingGrade gradeSwingTiming({
  required double? timeToIdealContact,
  required bool isSweetSpot,
}) {
  if (timeToIdealContact == null || !timeToIdealContact.isFinite) {
    return SwingTimingGrade.good;
  }
  if (timeToIdealContact > 0.22) return SwingTimingGrade.early;
  if (timeToIdealContact < 0.02) return SwingTimingGrade.late;
  if (isSweetSpot &&
      timeToIdealContact >= 0.06 &&
      timeToIdealContact <= 0.18) {
    return SwingTimingGrade.perfect;
  }
  return SwingTimingGrade.good;
}

SwingTimingModifiers timingModifiersFor(SwingTimingGrade grade) {
  return switch (grade) {
    SwingTimingGrade.perfect => const SwingTimingModifiers(
        speedMultiplier: 1.06,
        liftAssist: 0,
        spinMultiplier: 1.15,
        chargeBonus: 0.03,
      ),
    SwingTimingGrade.good => const SwingTimingModifiers(
        speedMultiplier: 1,
        liftAssist: 0,
        spinMultiplier: 1,
        chargeBonus: 0,
      ),
    SwingTimingGrade.early => const SwingTimingModifiers(
        speedMultiplier: 0.96,
        liftAssist: 3,
        spinMultiplier: 0.85,
        chargeBonus: 0,
      ),
    SwingTimingGrade.late => const SwingTimingModifiers(
        speedMultiplier: 0.94,
        liftAssist: 2,
        spinMultiplier: 0.75,
        chargeBonus: 0,
      ),
  };
}
