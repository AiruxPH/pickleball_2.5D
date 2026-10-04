import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/models/game_settings.dart';
import 'package:pickleball_3d/screens/game_over_screen.dart';
import 'package:pickleball_3d/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('try again preserves bot-vs-bot match arguments',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GameSettings()),
          Provider.value(value: settingsService),
        ],
        child: MaterialApp(
          initialRoute: '/game-over',
          onGenerateRoute: (settings) {
            if (settings.name == '/game-over') {
              return MaterialPageRoute<void>(
                builder: (_) => const GameOverScreen(),
                settings: RouteSettings(
                  name: '/game-over',
                  arguments: <String, Object>{
                    'playerScore': 3,
                    'aiScore': 11,
                    'playerWon': false,
                    'rematchArguments': <String, Object>{
                      'mode': 'bot-vs-bot',
                      'botVsBot': true,
                      'difficulty': 3,
                    },
                  },
                ),
              );
            }
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Text('Game arguments: ${settings.arguments}'),
              ),
              settings: settings,
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mode: bot-vs-bot'), findsOneWidget);
    expect(find.textContaining('botVsBot: true'), findsOneWidget);
    expect(find.textContaining('difficulty: 3'), findsOneWidget);
  });
}
