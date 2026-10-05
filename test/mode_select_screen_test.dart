import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/services/settings_service.dart';
import 'package:pickleball_3d/screens/mode_select_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> buildTestWidget({Size size = const Size(1000, 600), Object? arguments}) async {
    final settingsService = SettingsService();
    await settingsService.init();
    final gameSettings = GameSettings();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gameSettings),
        Provider<SettingsService>.value(value: settingsService),
      ],
      child: MaterialApp(
        onGenerateRoute: (routeSettings) {
          if (routeSettings.name == '/mode-select') {
            return MaterialPageRoute(
              builder: (_) => const ModeSelectScreen(),
              settings: RouteSettings(name: '/mode-select', arguments: arguments),
            );
          }
          if (routeSettings.name == '/game') {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Text('GameScreen: ${routeSettings.arguments}'),
              ),
              settings: routeSettings,
            );
          }
          if (routeSettings.name == '/training') {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('TrainingScreen')),
              settings: routeSettings,
            );
          }
          return MaterialPageRoute(
            builder: (_) => const ModeSelectScreen(),
            settings: RouteSettings(name: '/mode-select', arguments: arguments),
          );
        },
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const ModeSelectScreen(),
        ),
      ),
    );
  }

  testWidgets('ModeSelectScreen displays player and bot match modes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(1280, 720)));
    await tester.pumpAndSettle();

    expect(find.text('SELECT MODE'), findsOneWidget);
    expect(find.text('QUICK MATCH'), findsNothing);
    expect(find.text('SINGLES 1v1'), findsOneWidget);
    expect(find.text('DOUBLES 2v2'), findsOneWidget);
    expect(find.text('BOT VS BOT'), findsOneWidget);
    expect(find.text('TRAINING'), findsNothing);
    expect(find.text('Team up with AI partner vs AI duo'), findsOneWidget);
  });

  testWidgets('BOT VS BOT launches an autonomous spectator match',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(1280, 720)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BOT VS BOT'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH FORMAT'), findsOneWidget);
    await tester.tap(find.text('START MATCH'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('mode: bot-vs-bot, botVsBot: true'),
      findsOneWidget,
    );
  });

  testWidgets('Selecting DOUBLES 2v2 displays the DIFFICULTY selector',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(1280, 720)));
    await tester.pumpAndSettle();

    // Further choices stay hidden until a mode card is selected.
    expect(find.text('DIFFICULTY'), findsNothing);

    // Tap on DOUBLES 2v2
    await tester.tap(find.text('DOUBLES 2v2'));
    await tester.pumpAndSettle();

    // Now DIFFICULTY section should be visible
    expect(find.text('DIFFICULTY'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget);
  });

  testWidgets('Tapping PLAY NOW with DOUBLES 2v2 navigates with doubles mode and difficulty',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(1280, 720)));
    await tester.pumpAndSettle();

    // Select DOUBLES 2v2
    await tester.tap(find.text('DOUBLES 2v2'));
    await tester.pumpAndSettle();

    // Select HARD difficulty
    await tester.tap(find.text('HARD'));
    await tester.pumpAndSettle();

    // Tap the setup dialog's start action.
    await tester.tap(find.text('START MATCH'));
    await tester.pumpAndSettle();

    // Verify destination received doubles mode and difficulty 3 (Hard)
    expect(find.textContaining('GameScreen: {mode: doubles, difficulty: 3}'), findsOneWidget);
  });

  testWidgets('Selecting SINGLES 1v1 updates selected mode',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(1280, 720)));
    await tester.pumpAndSettle();

    expect(find.text('START MATCH'), findsNothing);

    await tester.tap(find.text('SINGLES 1v1'));
    await tester.pumpAndSettle();

    expect(find.text('START MATCH'), findsOneWidget);
  });

  testWidgets('Portrait layout renders DOUBLES 2v2 and shows difficulty when tapped',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(400, 800)));
    await tester.pumpAndSettle();

    expect(find.text('DOUBLES 2v2'), findsOneWidget);
    expect(find.text('DIFFICULTY'), findsNothing);

    await tester.tap(find.text('DOUBLES 2v2'));
    await tester.pumpAndSettle();

    expect(find.text('DIFFICULTY'), findsOneWidget);
  });

  testWidgets('Court selection renders all professional courts with badges and allows switching',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(await buildTestWidget(size: const Size(1280, 720)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SINGLES 1v1'));
    await tester.pumpAndSettle();

    expect(find.text('SELECT COURT'), findsOneWidget);
    expect(find.text('CENTER COURT'), findsOneWidget);
    expect(find.text('TROPICAL BEACH'), findsOneWidget);
    expect(find.text('SKY ARENA'), findsOneWidget);
    expect(find.text('FOREST PARK'), findsOneWidget);

    // Verify professional venue badge labels
    expect(find.text('PRO TOUR'), findsOneWidget);
    expect(find.text('RESORT'), findsOneWidget);
    expect(find.text('CHAMPIONSHIP'), findsOneWidget);
    expect(find.text('ALPINE'), findsOneWidget);

    // Tap Forest Park court
    await tester.tap(find.text('FOREST PARK'));
    await tester.pumpAndSettle();

    // Verify it remains selected without errors
    expect(find.text('FOREST PARK'), findsOneWidget);
  });
}
