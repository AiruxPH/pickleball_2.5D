import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/models/shop_items.dart';
import 'package:pickleball_3d/screens/shop_screen.dart';
import 'package:pickleball_3d/services/settings_service.dart';

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

  group('ShopScreen Mobile Landscape Layout', () {
    testWidgets('Renders properly without overflow in 800x390 landscape phone view',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsService = SettingsService();
      await settingsService.init();
      final settings = GameSettings();

      // Configure a typical landscape phone view (800x390, e.g. iPhone / Pixel landscape)
      tester.view.physicalSize = const Size(800, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            Provider<SettingsService>.value(value: settingsService),
          ],
          child: const MaterialApp(
            home: ShopScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Top Navigation in Landscape
      expect(find.text('SHOP'), findsOneWidget);
      expect(find.text('EXIT'), findsOneWidget);
      expect(find.text('PADDLES'), findsOneWidget);
      expect(find.text('PLAYERS'), findsOneWidget);
      expect(find.text('BANK & PERKS'), findsOneWidget);

      // 2. Verify Paddles Tab opens inspection modal with stats on card tap
      await tester.tap(find.text('CARBON STEALTH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('POWER'), findsOneWidget);
      expect(find.text('CONTROL'), findsOneWidget);
      expect(find.text('SPIN RATE'), findsOneWidget);
      expect(find.text('STAMINA EFF.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Switch to Athletes Tab
      await tester.tap(find.text('PLAYERS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap athlete card to inspect in modal
      await tester.tap(find.text('CHAMPION ACE').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Balanced Conditioning'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Switch to Bank & Perks Tab
      await tester.tap(find.text('BANK & PERKS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DAILY SPONSOR CRATE'), findsOneWidget);
      expect(find.text('CURRENCY EXCHANGE'), findsOneWidget);
      expect(find.text('3500 COINS'), findsOneWidget);
      expect(find.text('8000 COINS'), findsOneWidget);
      expect(find.text('18000 COINS'), findsOneWidget);
    });

    testWidgets('Renders properly without overflow in compact 740x360 mobile landscape',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsService = SettingsService();
      await settingsService.init();
      final settings = GameSettings();

      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            Provider<SettingsService>.value(value: settingsService),
          ],
          child: const MaterialApp(
            home: ShopScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SHOP'), findsOneWidget);

      // Verify item selection updates preview
      await tester.tap(find.text('VORTEX COBALT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Athletes
      await tester.tap(find.text('PLAYERS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Bank & Perks
      await tester.tap(find.text('BANK & PERKS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DAILY SPONSOR CRATE'), findsOneWidget);
    });
  });
}
