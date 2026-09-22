import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/shop_items.dart';

void main() {
  group('Pro Shop Catalog & Items', () {
    test('Paddle catalog has curated tiers and valid stats', () {
      expect(kPaddleCatalog.length, greaterThanOrEqualTo(6));
      for (final paddle in kPaddleCatalog) {
        expect(paddle.power, inInclusiveRange(0.0, 1.0));
        expect(paddle.control, inInclusiveRange(0.0, 1.0));
        expect(paddle.spin, inInclusiveRange(0.0, 1.0));
        expect(paddle.staminaEfficiency, inInclusiveRange(0.0, 1.0));
      }

      final standard = getPaddleById('paddle_standard');
      expect(standard.tier, ItemTier.common);
      expect(standard.price, 0);

      final gold = getPaddleById('paddle_gold');
      expect(gold.tier, ItemTier.mythic);
      expect(gold.isGems, true);
    });

    test('Player character catalog has valid perks and speeds', () {
      expect(kPlayerSkinCatalog.length, greaterThanOrEqualTo(5));
      for (final skin in kPlayerSkinCatalog) {
        expect(skin.speedMultiplier, greaterThanOrEqualTo(1.0));
        expect(skin.staminaRegenMultiplier, greaterThanOrEqualTo(1.0));
      }

      final rookie = getPlayerSkinById('player_rookie');
      expect(rookie.price, 0);
      expect(rookie.speedMultiplier, 1.0);
    });
  });

  group('GameSettings Shop Transactions & Loadouts', () {
    late GameSettings settings;

    setUp(() {
      settings = GameSettings();
      settings.coins = 5000;
      settings.gems = 1000;
    });

    test('Initial defaults have starter gear equipped and unlocked', () {
      expect(settings.equippedPaddleId, 'paddle_standard');
      expect(settings.isPaddleUnlocked('paddle_standard'), true);
      expect(settings.equippedPlayerId, 'player_rookie');
      expect(settings.isPlayerUnlocked('player_rookie'), true);
    });

    test('Can purchase paddle with coins when balance is sufficient', () {
      final vortex = getPaddleById('paddle_vortex'); // 1500 coins
      expect(settings.isPaddleUnlocked(vortex.id), false);

      final bought = settings.buyPaddle(vortex);
      expect(bought, true);
      expect(settings.coins, 3500); // 5000 - 1500
      expect(settings.isPaddleUnlocked(vortex.id), true);
      expect(settings.equippedPaddleId, vortex.id);
    });

    test('Cannot purchase paddle when coins are insufficient', () {
      settings.coins = 500;
      final vortex = getPaddleById('paddle_vortex'); // 1500 coins
      final bought = settings.buyPaddle(vortex);
      expect(bought, false);
      expect(settings.coins, 500);
      expect(settings.isPaddleUnlocked(vortex.id), false);
    });

    test('Can purchase paddle with gems when balance is sufficient', () {
      settings.gems = 2000;
      final cyber = getPaddleById('paddle_cyber'); // 1200 gems
      final bought = settings.buyPaddle(cyber);
      expect(bought, true);
      expect(settings.gems, 800); // 2000 - 1200
      expect(settings.isPaddleUnlocked(cyber.id), true);
      expect(settings.equippedPaddleId, cyber.id);
    });

    test('Can recruit player character skin and equip', () {
      final neon = getPlayerSkinById('player_neon'); // 2000 coins
      final bought = settings.buyPlayer(neon);
      expect(bought, true);
      expect(settings.coins, 3000); // 5000 - 2000
      expect(settings.isPlayerUnlocked(neon.id), true);
      expect(settings.equippedPlayerId, neon.id);

      // Equip back to rookie
      settings.equipPlayer('player_rookie');
      expect(settings.equippedPlayerId, 'player_rookie');

      // Re-equip neon without charging
      settings.equipPlayer(neon.id);
      expect(settings.equippedPlayerId, neon.id);
      expect(settings.coins, 3000);
    });

    test('Bonus claim and currency exchange operate properly', () {
      settings.claimBonus(2500, 500);
      expect(settings.coins, 7500);
      expect(settings.gems, 1500);

      final exchanged = settings.exchangeGemsForCoins(
        gemsToSpend: 500,
        coinsToGet: 3500,
      );
      expect(exchanged, true);
      expect(settings.gems, 1000);
      expect(settings.coins, 11000);
    });

    test('Serialization and deserialization preserves shop inventory', () {
      final vortex = getPaddleById('paddle_vortex');
      settings.buyPaddle(vortex);
      final neon = getPlayerSkinById('player_neon');
      settings.buyPlayer(neon);

      final json = settings.toJson();
      final restored = GameSettings();
      restored.fromJson(json);

      expect(restored.equippedPaddleId, vortex.id);
      expect(restored.isPaddleUnlocked(vortex.id), true);
      expect(restored.isPaddleUnlocked('paddle_standard'), true);

      expect(restored.equippedPlayerId, neon.id);
      expect(restored.isPlayerUnlocked(neon.id), true);
      expect(restored.isPlayerUnlocked('player_rookie'), true);
    });
  });
}
