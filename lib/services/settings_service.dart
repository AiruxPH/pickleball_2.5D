import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_settings.dart';

/// ─────────────────────────────────────────────────────────────
/// SettingsService — loads and saves GameSettings to disk
/// ─────────────────────────────────────────────────────────────

class SettingsService {
  static const String _settingsKey = 'pickleball3d_settings';
  late SharedPreferences _prefs;

  /// Call once at app startup before runApp
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load settings from disk into [GameSettings]
  Future<void> load(GameSettings settings) async {
    final raw = _prefs.getString(_settingsKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        settings.fromJson(json);
      } catch (_) {
        // Corrupt data — ignore, use defaults
      }
    }
  }

  /// Save [GameSettings] to disk
  Future<void> save(GameSettings settings) async {
    final json = jsonEncode(settings.toJson());
    await _prefs.setString(_settingsKey, json);
  }
}
