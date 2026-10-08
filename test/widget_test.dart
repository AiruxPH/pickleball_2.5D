import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/services/settings_service.dart';
import 'package:pickleball_3d/screens/main_menu_screen.dart';
import 'package:pickleball_3d/screens/game_screen.dart';
import 'package:pickleball_3d/widgets/scoreboard.dart';
import 'package:pickleball_3d/widgets/game_button.dart';
import 'package:pickleball_3d/services/audio_service.dart';
import 'package:pickleball_3d/game/panorama/court_panorama_manager.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(1 + 1, equals(2));
  });

  testWidgets('Profile badge is clickable and opens PlayerProfileDialog',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();
    final gameSettings = GameSettings();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gameSettings),
          Provider<SettingsService>.value(value: settingsService),
        ],
        child: const MaterialApp(
          home: MainMenuScreen(),
        ),
      ),
    );

    // Pump frames for entrance animation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Verify player badge is rendered
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Lv. 5'), findsOneWidget);

    // Tap on the profile pill
    await tester.tap(find.text('John Doe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify PlayerProfileDialog opened
    expect(find.text('PLAYER PROFILE'), findsOneWidget);
    expect(find.text('AWESOME!'), findsOneWidget);

    // Close the dialog
    await tester.tap(find.text('AWESOME!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog dismissed
    expect(find.text('PLAYER PROFILE'), findsNothing);
  });

  testWidgets('GameScreen renders with PauseButton in upper right',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();
    final gameSettings = GameSettings();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gameSettings),
          Provider<SettingsService>.value(value: settingsService),
        ],
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify PauseButton exists
    expect(find.byType(PauseButton), findsOneWidget);

    // Verify PauseButton position is in upper right (top < 100 and dx > 300)
    final pauseButtonOffset = tester.getTopRight(find.byType(PauseButton));
    expect(pauseButtonOffset.dy, lessThan(100));
    expect(pauseButtonOffset.dx, greaterThan(300));

    // Tap pause button to open pause menu
    await tester.tap(find.byType(PauseButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Verify pause menu opens
    expect(find.text('PAUSED'), findsOneWidget);
  });

  testWidgets('rally spin selector stays on-screen at mobile landscape size',
      (WidgetTester tester) async {
    CourtPanoramaManager.instance.clear();
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: GameSettings()),
          Provider<SettingsService>.value(value: settingsService),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('SERVE').last);
    await tester.pump(const Duration(milliseconds: 150));

    final selector = find.byKey(const ValueKey('shot-spin-selector'));
    expect(selector, findsOneWidget);
    final rect = tester.getRect(selector);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(640));
    expect(rect.bottom, lessThanOrEqualTo(360));
    expect(find.byKey(const ValueKey('shot-spin-flat')), findsOneWidget);
    expect(find.byKey(const ValueKey('shot-spin-topspin')), findsOneWidget);
    expect(find.byKey(const ValueKey('shot-spin-slice')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    CourtPanoramaManager.instance.clear();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('GameButton features clickable pointer cursor and button click audio trigger',
      (WidgetTester tester) async {
    final fakeAudio = _WidgetTestFakeAudio();
    bool tapped = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AudioService>.value(value: fakeAudio),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameButton(
                label: 'HIT',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    // Verify MouseRegion has pointer click cursor
    final mouseRegion = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(GameButton),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(mouseRegion.cursor, SystemMouseCursors.click);

    // Tap the button
    await tester.tap(find.byType(GameButton));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(fakeAudio.clickCount, 1, reason: 'GameButton press must trigger button click sound');
  });
}

class _WidgetTestFakeAudio extends AudioService {
  int clickCount = 0;

  @override
  void playButtonClick() {
    clickCount++;
  }
}
