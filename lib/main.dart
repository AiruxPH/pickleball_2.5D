import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/game_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/how_to_play_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/mode_select_screen.dart';
import 'screens/tournament_screen.dart';
import 'screens/career_screen.dart';
import 'screens/training_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/achievements_screen.dart';
import 'services/settings_service.dart';
import 'services/audio_service.dart';
import 'services/character_sprite_manager.dart';
import 'models/game_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable all orientations for responsive mobile & desktop gameplay
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full-screen immersive mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load saved settings
  final settingsService = SettingsService();
  await settingsService.init();
  final gameSettings = GameSettings();
  await settingsService.load(gameSettings);

  // Ensure daily challenge is set for today
  gameSettings.ensureDailyChallenge();

  // Initialize Audio Service & start background music
  final audioService = AudioService();
  await audioService.init();
  audioService.setMusicVolume(gameSettings.musicVolume);
  audioService.setSfxVolume(gameSettings.sfxVolume);
  audioService.playBGM();

  // Pre-load 3D character sprites
  await CharacterSpriteManager.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gameSettings),
        Provider<SettingsService>.value(value: settingsService),
        Provider<AudioService>.value(value: audioService),
      ],
      child: const PickleballApp(),
    ),
  );
}

class PickleballApp extends StatelessWidget {
  const PickleballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pickleball Champions Mobile',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            try {
              context.read<AudioService>().handleUserInteraction();
            } catch (_) {}
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B132B),
      ),
      // Named routes for navigation
      initialRoute: '/',
      routes: {
        '/':             (context) => const SplashScreen(),
        '/menu':         (context) => const MainMenuScreen(),
        '/game':         (context) => const GameScreen(),
        '/settings':     (context) => const SettingsScreen(),
        '/how-to-play':  (context) => const HowToPlayScreen(),
        '/game-over':    (context) => const GameOverScreen(),
        '/shop':         (context) => const ShopScreen(),
        '/mode-select':  (context) => const ModeSelectScreen(),
        '/tournament':   (context) => const TournamentScreen(),
        '/career':       (context) => const CareerScreen(),
        '/training':     (context) => const TrainingScreen(),
        '/leaderboard':  (context) => const LeaderboardScreen(),
        '/achievements': (context) => const AchievementsScreen(),
      },
    );
  }
}
