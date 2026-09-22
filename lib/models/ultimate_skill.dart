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
  final String japaneseName;
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
    required this.japaneseName,
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
    name: 'THUNDERBOLT SMASH',
    japaneseName: 'JINRAI SPIKE',
    tagline: 'Supersonic Plasma Spike & Shockwave',
    description:
        'Hurls a blistering 260 km/h electric plasma spike with heavy arena screen shake and a thunder shockwave that stuns opponents.',
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
    name: 'GHOST PHANTOM',
    japaneseName: 'GENEI DANCE',
    tagline: 'Triple Clone Illusion & Vortex Curve',
    description:
        'Splits the ball into 3 holographic ghost clones in mid-air and executes an impossible vortex curve right before bouncing.',
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
    name: 'DRAGON METEOR',
    japaneseName: 'GOUKA COMET',
    tagline: 'Inferno Comet with Zero-Bounce Drop',
    description:
        'Ignites the ball into a roaring fireball that plummets straight into the opponent kitchen with near-zero bounce height.',
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
    name: 'FROSTBITE BLIZZARD',
    japaneseName: 'ZETTAI REIDO',
    tagline: 'Cryo Ice Core & 50% Speed Freeze Zone',
    description:
        'Encases the ball in sub-zero frost crystals. On court contact, creates a freezing ice ring that slows opponent movement by 50%.',
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
