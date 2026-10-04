import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// ─────────────────────────────────────────────────────────────
/// SfxPool — Recycled AudioPlayer pool for Web & Mobile
///
/// Prevents the browser error:
/// "The AudioContext encountered an error from the audio device or the WebAudio renderer"
/// which occurs when unbounded new AudioPlayer/AudioContext instances are created
/// during rapid rallies (hits, smashes, bounces, net hits).
///
/// Limits active SFX AudioPlayer instances to a fixed recycled circular pool of 4.
/// ─────────────────────────────────────────────────────────────

class SfxPool {
  static const int kPoolSize = 4;
  final List<AudioPlayer> _players = [];
  int _currentIndex = 0;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    try {
      for (int i = 0; i < kPoolSize; i++) {
        final player = AudioPlayer(playerId: 'sfx_pool_$i');
        try {
          await player.setReleaseMode(ReleaseMode.stop);
          if (!kIsWeb) {
            await player.setPlayerMode(PlayerMode.lowLatency);
          }
        } catch (_) {}
        _players.add(player);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('SfxPool init error: $e');
    }
  }

  /// Plays a short sound effect file (from assets/audio/) with volume control.
  void play(String filename, double volume) {
    if (!_initialized || _players.isEmpty || volume <= 0) return;

    final player = _players[_currentIndex];
    _currentIndex = (_currentIndex + 1) % _players.length;

    unawaited(_playInternal(player, filename, volume));
  }

  Future<void> _playInternal(
      AudioPlayer player, String filename, double volume) async {
    try {
      // Safely stop any previous playback on this recycled slot
      try {
        await player.stop();
      } catch (_) {}

      final cleanFile =
          filename.startsWith('audio/') ? filename : 'audio/$filename';

      await player.play(
        AssetSource(cleanFile),
        volume: volume.clamp(0.0, 1.0),
      );
    } catch (e) {
      // Gracefully suppress WebAudio interruption / context errors
      debugPrint('SfxPool sound error ($filename): $e');
    }
  }

  Future<void> dispose() async {
    for (final player in _players) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
    _initialized = false;
  }
}
