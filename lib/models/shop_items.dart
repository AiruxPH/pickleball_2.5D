import 'package:flutter/material.dart';
import 'ultimate_skill.dart';

/// ─────────────────────────────────────────────────────────────
/// Shop Items & Rarity Models
/// Defines all Paddles and Player Character Skins in the Pro Shop
/// ─────────────────────────────────────────────────────────────

enum ItemTier {
  common,
  rare,
  epic,
  legendary,
  mythic,
}

extension ItemTierExtension on ItemTier {
  String get displayName {
    switch (this) {
      case ItemTier.common:
        return 'COMMON';
      case ItemTier.rare:
        return 'RARE';
      case ItemTier.epic:
        return 'EPIC';
      case ItemTier.legendary:
        return 'LEGENDARY';
      case ItemTier.mythic:
        return 'MYTHIC';
    }
  }

  Color get color {
    switch (this) {
      case ItemTier.common:
        return const Color(0xFF94A3B8);
      case ItemTier.rare:
        return const Color(0xFF38BDF8);
      case ItemTier.epic:
        return const Color(0xFFA855F7);
      case ItemTier.legendary:
        return const Color(0xFFF59E0B);
      case ItemTier.mythic:
        return const Color(0xFFEC4899);
    }
  }

  Color get glowColor {
    switch (this) {
      case ItemTier.common:
        return const Color(0x3394A3B8);
      case ItemTier.rare:
        return const Color(0x6638BDF8);
      case ItemTier.epic:
        return const Color(0x66A855F7);
      case ItemTier.legendary:
        return const Color(0x77F59E0B);
      case ItemTier.mythic:
        return const Color(0x88EC4899);
    }
  }
}

/// Paddle Item representation
class PaddleItem {
  final String id;
  final String name;
  final String tagline;
  final ItemTier tier;

  // Stats (0.0 to 1.0)
  final double power;
  final double control;
  final double spin;
  final double staminaEfficiency;
  final UltimateType? specialSkill;

  // Visual Styling for 2D/3D Canvas Rendering
  final Color bladeColor1;
  final Color bladeColor2;
  final Color rimColor;
  final Color chevronColor;
  final Color gripTapeColor;
  final Color gripCollarColor;
  final String patternType; // 'plain', 'chevrons', 'honeycomb', 'lightning', 'rings'

  // Pricing
  final int coinPrice;
  final int gemPrice; // 0 if bought with coins

  const PaddleItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.tier,
    required this.power,
    required this.control,
    required this.spin,
    required this.staminaEfficiency,
    this.specialSkill,
    required this.bladeColor1,
    required this.bladeColor2,
    required this.rimColor,
    required this.chevronColor,
    this.gripTapeColor = const Color(0xFFF8FAFC),
    this.gripCollarColor = const Color(0xFF0F172A),
    this.patternType = 'chevrons',
    this.coinPrice = 0,
    this.gemPrice = 0,
  });

  bool get isGems => gemPrice > 0;
  int get price => isGems ? gemPrice : coinPrice;
}

/// Player Character / Skin representation
class PlayerSkinItem {
  final String id;
  final String name;
  final String title;
  final ItemTier tier;

  // Visual Customization for Human Player
  final Color jerseyMain;
  final Color jerseyLight;
  final Color jerseyAccent;
  final Color shortsColor;
  final Color skinColor;
  final Color shoeAccent;
  final bool hasVisor;
  final bool hasSunglasses;
  final IconData avatarIcon;

  // Perks / Stats
  final String perkTitle;
  final String perkDescription;
  final double speedMultiplier; // e.g. 1.0 to 1.15
  final double staminaRegenMultiplier; // e.g. 1.0 to 1.25

  // Pricing
  final int coinPrice;
  final int gemPrice;

  const PlayerSkinItem({
    required this.id,
    required this.name,
    required this.title,
    required this.tier,
    required this.jerseyMain,
    required this.jerseyLight,
    required this.jerseyAccent,
    required this.shortsColor,
    this.skinColor = const Color(0xFFE0AC82),
    this.shoeAccent = const Color(0xFF38BDF8),
    this.hasVisor = false,
    this.hasSunglasses = false,
    this.avatarIcon = Icons.person_rounded,
    required this.perkTitle,
    required this.perkDescription,
    this.speedMultiplier = 1.0,
    this.staminaRegenMultiplier = 1.0,
    this.coinPrice = 0,
    this.gemPrice = 0,
  });

  bool get isGems => gemPrice > 0;
  int get price => isGems ? gemPrice : coinPrice;
}

/// ─────────────────────────────────────────────────────────────
/// Pro Tour Catalogs
/// Curated items available in the Pro Shop
/// ─────────────────────────────────────────────────────────────

final List<PaddleItem> kPaddleCatalog = [
  const PaddleItem(
    id: 'paddle_standard',
    name: 'CARBON STEALTH',
    tagline: 'Your starter paddle. Good at everything, great at nothing.',
    tier: ItemTier.common,
    power: 0.50,
    control: 0.55,
    spin: 0.50,
    staminaEfficiency: 0.50,
    bladeColor1: Color(0xFF1E293B),
    bladeColor2: Color(0xFF0F172A),
    rimColor: Color(0xFF0284C7),
    chevronColor: Color(0xFF38BDF8),
    gripTapeColor: Color(0xFFF8FAFC),
    coinPrice: 0,
    gemPrice: 0,
  ),
  const PaddleItem(
    id: 'paddle_vortex',
    name: 'VORTEX COBALT',
    tagline: 'Grippy face for extra spin. Makes dinks dip over the net.',
    tier: ItemTier.rare,
    power: 0.60,
    control: 0.72,
    spin: 0.80,
    staminaEfficiency: 0.65,
    bladeColor1: Color(0xFF0369A1),
    bladeColor2: Color(0xFF082B6B),
    rimColor: Color(0xFF38BDF8),
    chevronColor: Color(0xFF7DD3FC),
    patternType: 'rings',
    coinPrice: 1500,
  ),
  const PaddleItem(
    id: 'paddle_thunder',
    name: 'THUNDER STRIKE',
    tagline: 'Heavy and hard-hitting. Built for smashes.',
    tier: ItemTier.rare,
    power: 0.82,
    control: 0.58,
    spin: 0.62,
    staminaEfficiency: 0.58,
    specialSkill: UltimateType.thunderbolt,
    bladeColor1: Color(0xFF451A03),
    bladeColor2: Color(0xFF1C1917),
    rimColor: Color(0xFFF59E0B),
    chevronColor: Color(0xFFFBBF24),
    patternType: 'lightning',
    coinPrice: 2800,
  ),
  const PaddleItem(
    id: 'paddle_glacier',
    name: 'GLACIER TITANIUM',
    tagline: 'Soft feel and easy control. Put the ball where you want it.',
    tier: ItemTier.epic,
    power: 0.68,
    control: 0.90,
    spin: 0.75,
    staminaEfficiency: 0.80,
    specialSkill: UltimateType.frostbite,
    bladeColor1: Color(0xFF0E7490),
    bladeColor2: Color(0xFF164E63),
    rimColor: Color(0xFF22D3EE),
    chevronColor: Color(0xFFA5F3FC),
    gripTapeColor: Color(0xFFE0F2FE),
    patternType: 'honeycomb',
    coinPrice: 5000,
  ),
  const PaddleItem(
    id: 'paddle_inferno',
    name: 'INFERNO X PRO',
    tagline: 'Fast drives with topspin that drop quickly after the net.',
    tier: ItemTier.epic,
    power: 0.92,
    control: 0.65,
    spin: 0.88,
    staminaEfficiency: 0.70,
    specialSkill: UltimateType.dragonMeteor,
    bladeColor1: Color(0xFF991B1B),
    bladeColor2: Color(0xFF450A0A),
    rimColor: Color(0xFFEF4444),
    chevronColor: Color(0xFFF97316),
    patternType: 'lightning',
    coinPrice: 7500,
  ),
  const PaddleItem(
    id: 'paddle_cyber',
    name: 'NIGHT SHIFT',
    tagline: 'Big sweet spot, so off-center hits still go where you aim.',
    tier: ItemTier.legendary,
    power: 0.94,
    control: 0.88,
    spin: 0.92,
    staminaEfficiency: 0.90,
    specialSkill: UltimateType.ghostPhantom,
    bladeColor1: Color(0xFF581C87),
    bladeColor2: Color(0xFF09090B),
    rimColor: Color(0xFFC084FC),
    chevronColor: Color(0xFFE879F9),
    gripTapeColor: Color(0xFF2E1065),
    patternType: 'honeycomb',
    gemPrice: 1200,
  ),
  const PaddleItem(
    id: 'paddle_gold',
    name: 'GOLD EDITION',
    tagline: 'The best paddle in the shop. Strong in every stat, and it looks the part.',
    tier: ItemTier.mythic,
    power: 0.98,
    control: 0.98,
    spin: 0.96,
    staminaEfficiency: 0.98,
    bladeColor1: Color(0xFFB45309),
    bladeColor2: Color(0xFF1E1B4B),
    rimColor: Color(0xFFFFD700),
    chevronColor: Color(0xFFFDE047),
    gripTapeColor: Color(0xFFFEF3C7),
    gripCollarColor: Color(0xFFD97706),
    patternType: 'rings',
    gemPrice: 2500,
  ),
];

final List<PlayerSkinItem> kPlayerSkinCatalog = [
  const PlayerSkinItem(
    id: 'player_rookie',
    name: 'CHAMPION ACE',
    title: 'Pro Tour Ace',
    tier: ItemTier.common,
    jerseyMain: Color(0xFF00A896),
    jerseyLight: Color(0xFF14B8A6),
    jerseyAccent: Color(0xFFFFFFFF),
    shortsColor: Color(0xFF007A6E),
    skinColor: Color(0xFFE5A672),
    shoeAccent: Color(0xFFFF6B35),
    hasVisor: true,
    avatarIcon: Icons.person_rounded,
    perkTitle: 'Balanced Conditioning',
    perkDescription: 'Balanced speed and stamina.',
    coinPrice: 0,
  ),
  const PlayerSkinItem(
    id: 'player_neon',
    name: 'CYBER STRIKER',
    title: 'Hyper-Light Pro',
    tier: ItemTier.rare,
    jerseyMain: Color(0xFF065F46),
    jerseyLight: Color(0xFF059669),
    jerseyAccent: Color(0xFF34D399),
    shortsColor: Color(0xFF064E3B),
    shoeAccent: Color(0xFF10B981),
    hasVisor: true,
    avatarIcon: Icons.bolt_rounded,
    perkTitle: 'Quick Footwork (+8% Speed)',
    perkDescription: 'Runs faster, so deep lobs and wide shots are easier to reach.',
    speedMultiplier: 1.08,
    coinPrice: 2000,
  ),
  const PlayerSkinItem(
    id: 'player_viper',
    name: 'VIPER TACTICAL',
    title: 'Precision Master',
    tier: ItemTier.rare,
    jerseyMain: Color(0xFF18181B),
    jerseyLight: Color(0xFF27272A),
    jerseyAccent: Color(0xFFA3E635),
    shortsColor: Color(0xFF09090B),
    shoeAccent: Color(0xFF84CC16),
    hasSunglasses: true,
    avatarIcon: Icons.sports_tennis_rounded,
    perkTitle: 'Iron Lungs (+15% Stamina Regen)',
    perkDescription: 'Gets stamina back much faster between rallies.',
    staminaRegenMultiplier: 1.15,
    coinPrice: 3500,
  ),
  const PlayerSkinItem(
    id: 'player_solar',
    name: 'SOLAR BLAZE',
    title: 'Powerhouse Dynamo',
    tier: ItemTier.epic,
    jerseyMain: Color(0xFF9A3412),
    jerseyLight: Color(0xFFEA580C),
    jerseyAccent: Color(0xFFFDE047),
    shortsColor: Color(0xFF431407),
    shoeAccent: Color(0xFFF97316),
    hasVisor: true,
    avatarIcon: Icons.local_fire_department_rounded,
    perkTitle: 'Overdrive (+10% Speed & +10% Regen)',
    perkDescription: 'A bit quicker and a bit fitter than the starter kit.',
    speedMultiplier: 1.10,
    staminaRegenMultiplier: 1.10,
    coinPrice: 6000,
  ),
  const PlayerSkinItem(
    id: 'player_glacier',
    name: 'ARCTIC PRO',
    title: 'Kitchen Specialist',
    tier: ItemTier.legendary,
    jerseyMain: Color(0xFF1E3A8A),
    jerseyLight: Color(0xFF3B82F6),
    jerseyAccent: Color(0xFF67E8F9),
    shortsColor: Color(0xFF172554),
    shoeAccent: Color(0xFF38BDF8),
    hasVisor: true,
    hasSunglasses: true,
    avatarIcon: Icons.star_rounded,
    perkTitle: 'Zen Master (+12% Speed, +20% Regen)',
    perkDescription: 'Covers the court easily and stays steady at the kitchen.',
    speedMultiplier: 1.12,
    staminaRegenMultiplier: 1.20,
    gemPrice: 1000,
  ),
  const PlayerSkinItem(
    id: 'player_gold',
    name: 'GOLDEN ACE',
    title: 'Grand Champion',
    tier: ItemTier.mythic,
    jerseyMain: Color(0xFF18181B),
    jerseyLight: Color(0xFF3F3F46),
    jerseyAccent: Color(0xFFFFD700),
    shortsColor: Color(0xFF09090B),
    shoeAccent: Color(0xFFFBBF24),
    hasSunglasses: true,
    avatarIcon: Icons.workspace_premium_rounded,
    perkTitle: 'Apex Competitor (+16% Speed, +25% Regen)',
    perkDescription: 'Top stats everywhere. The reward for winning it all.',
    speedMultiplier: 1.16,
    staminaRegenMultiplier: 1.25,
    gemPrice: 2000,
  ),
];

PaddleItem getPaddleById(String id) {
  return kPaddleCatalog.firstWhere(
    (p) => p.id == id,
    orElse: () => kPaddleCatalog.first,
  );
}

PlayerSkinItem getPlayerSkinById(String id) {
  return kPlayerSkinCatalog.firstWhere(
    (s) => s.id == id,
    orElse: () => kPlayerSkinCatalog.first,
  );
}
