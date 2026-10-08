import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// UltimateSkill — Special Signature Abilities
///
/// Players charge their Ultimate SP Gauge during rallies.
/// When at 100%, unleash an anime/arcade-tier ultimate shot!
/// ─────────────────────────────────────────────────────────────

enum UltimateType {
  thunderbolt,
  ghostPhantom,
  dragonMeteor,
  frostbite,
}

class UltimateSkill {
  final UltimateType type;
  final String name;
  final String shortName;
  final String tagline;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final double power;
  final double speed;
  final double curve;
  final double deception;

  const UltimateSkill({
    required this.type,
    required this.name,
    required this.shortName,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.glowColor,
    required this.power,
    required this.speed,
    required this.curve,
    required this.deception,
  });
}

const List<UltimateSkill> kAllUltimateSkills = [
  UltimateSkill(
    type: UltimateType.thunderbolt,
    name: 'LIGHTNING SMASH',
    shortName: 'Fastest shot',
    tagline: 'A huge smash that shakes the screen.',
    description:
        'Your hardest hit. It crosses the court faster than any other shot, so it is very hard to return.',
    icon: Icons.bolt_rounded,
    primaryColor: Color(0xFFFBBF24),
    accentColor: Color(0xFF38BDF8),
    glowColor: Color(0x88FBBF24),
    power: 0.98,
    speed: 1.00,
    curve: 0.30,
    deception: 0.60,
  ),
  UltimateSkill(
    type: UltimateType.ghostPhantom,
    name: 'PHANTOM SHOT',
    shortName: 'Trick shot',
    tagline: 'Fake balls and a late curve.',
    description:
        'Two fake balls fly beside the real one, and it curves sideways as it crosses the net. Can your opponent pick the right one?',
    icon: Icons.auto_awesome_rounded,
    primaryColor: Color(0xFFA855F7),
    accentColor: Color(0xFFEC4899),
    glowColor: Color(0x88A855F7),
    power: 0.70,
    speed: 0.82,
    curve: 1.00,
    deception: 0.95,
  ),
  UltimateSkill(
    type: UltimateType.dragonMeteor,
    name: 'FIREBALL DROP',
    shortName: 'Drop shot',
    tagline: 'Dives into the kitchen and barely bounces.',
    description:
        'Goes up high, then drops straight down into your opponent\'s kitchen and hardly bounces at all.',
    icon: Icons.local_fire_department_rounded,
    primaryColor: Color(0xFFF97316),
    accentColor: Color(0xFFEF4444),
    glowColor: Color(0x88F97316),
    power: 0.85,
    speed: 0.78,
    curve: 0.40,
    deception: 0.90,
  ),
  UltimateSkill(
    type: UltimateType.frostbite,
    name: 'ICE SHOT',
    shortName: 'Slow-down shot',
    tagline: 'Leaves ice that slows your opponent.',
    description:
        'Where it lands it leaves a patch of ice. Your opponent moves at half speed while they are on it.',
    icon: Icons.ac_unit_rounded,
    primaryColor: Color(0xFF06B6D4),
    accentColor: Color(0xFF38BDF8),
    glowColor: Color(0x8806B6D4),
    power: 0.80,
    speed: 0.85,
    curve: 0.65,
    deception: 0.75,
  ),
];

UltimateSkill getUltimateByType(UltimateType type) {
  return kAllUltimateSkills.firstWhere(
    (s) => s.type == type,
    orElse: () => kAllUltimateSkills.first,
  );
}
