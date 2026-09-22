import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

/// ─────────────────────────────────────────────────────────────
/// AudioService — manages game background music and sound effects
///
/// Background music track:
///   'background.mp3' (Wild Bounty Showdown.mp3)
///
/// Handles browser Web Audio autoplay policy by queuing BGM
/// until the first user gesture (pointerdown/click/tap).
/// ─────────────────────────────────────────────────────────────

class AudioService {
  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;
  bool _initialized = false;
  bool _bgmPlaying = false;
  bool _bgmWanted = false;
  bool _userInteracted = !kIsWeb;
  String _currentTrack = 'background.mp3';

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get isBgmPlaying => _bgmPlaying;
  bool get isInitialized => _initialized;
  bool get userInteracted => _userInteracted;

  // ── Init ────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    try {
      await FlameAudio.bgm.initialize();
      _initialized = true;
      try {
        await FlameAudio.audioCache.loadAll([
          'hit.wav',
          'smash.wav',
          'bounce.wav',
          'button_click.wav',
        ]);
      } catch (_) {}
    } catch (e) {
      debugPrint('AudioService init: $e');
    }
  }

  // ── User Interaction Unlocker (Web Audio autoplay policy) ───
  Future<void> handleUserInteraction() async {
    _userInteracted = true;
    if (_bgmWanted && !_bgmPlaying && _musicVolume > 0) {
      await _startBgmInternal();
    }
  }

  // ── Volume ──────────────────────────────────────────────────
  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    try {
      if (_initialized) {
        if (_musicVolume <= 0) {
          pauseBGM();
        } else {
          FlameAudio.bgm.audioPlayer.setVolume(_musicVolume);
          if (!_bgmPlaying) {
            playBGM();
          }
        }
      }
    } catch (e) {
      debugPrint('AudioService setMusicVolume error: $e');
    }
  }

  void setSfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
  }

  // ── Background music ────────────────────────────────────────
  void playBGM({String track = 'background.mp3'}) {
    _bgmWanted = true;
    _currentTrack = track;
    if (_musicVolume <= 0) return;

    // Web browsers require a user gesture before starting Web Audio
    if (kIsWeb && !_userInteracted) {
      return;
    }

    _startBgmInternal();
  }

  Future<void> _startBgmInternal() async {
    if (_musicVolume <= 0) return;
    if (!_initialized) {
      await init();
    }
    try {
      if (_bgmPlaying) {
        try {
          await FlameAudio.bgm.stop();
        } catch (_) {}
      }
      await FlameAudio.bgm.play(_currentTrack, volume: _musicVolume);
      _bgmPlaying = true;
    } catch (e) {
      _bgmPlaying = false;
      debugPrint('AudioService _startBgmInternal error: $e');
    }
  }

  void stopBGM() {
    _bgmWanted = false;
    try {
      if (_initialized) {
        FlameAudio.bgm.stop();
        _bgmPlaying = false;
      }
    } catch (e) {
      debugPrint('AudioService stopBGM error: $e');
    }
  }

  void pauseBGM() {
    try {
      if (_initialized && _bgmPlaying) {
        FlameAudio.bgm.pause();
        _bgmPlaying = false;
      }
    } catch (e) {
      debugPrint('AudioService pauseBGM error: $e');
    }
  }

  void resumeBGM() {
    _bgmWanted = true;
    if (kIsWeb && !_userInteracted) {
      return;
    }
    try {
      if (_initialized && _musicVolume > 0 && !_bgmPlaying) {
        FlameAudio.bgm.resume();
        _bgmPlaying = true;
      }
    } catch (e) {
      debugPrint('AudioService resumeBGM error: $e');
    }
  }

  // ── Sound effects ────────────────────────────────────────────
  void playHit({bool isPower = false}) {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      final file = isPower ? 'smash.wav' : 'hit.wav';
      FlameAudio.play(file, volume: _sfxVolume)
          .then<void>((_) {}, onError: (_) {});
    } catch (e) {
      debugPrint('AudioService playHit error: $e');
    }
  }

  void playBounce() {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      FlameAudio.play('bounce.wav', volume: (_sfxVolume * 0.85).clamp(0.0, 1.0))
          .then<void>((_) {}, onError: (_) {});
    } catch (e) {
      debugPrint('AudioService playBounce error: $e');
    }
  }

  void playNetHit() {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      FlameAudio.play('bounce.wav', volume: (_sfxVolume * 0.55).clamp(0.0, 1.0))
          .then<void>((_) {}, onError: (_) {});
    } catch (e) {
      debugPrint('AudioService playNetHit error: $e');
    }
  }

  void playButtonClick() {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      FlameAudio.play('button_click.wav', volume: (_sfxVolume * 0.75).clamp(0.0, 1.0))
          .then<void>((_) {}, onError: (_) {});
    } catch (e) {
      debugPrint('AudioService playButtonClick error: $e');
    }
  }

  void playCrowdCheer() {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      FlameAudio.play('hit.wav', volume: (_sfxVolume * 0.5).clamp(0.0, 1.0))
          .then<void>((_) {}, onError: (_) {});
    } catch (_) {}
  }

  void playVictory() {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      FlameAudio.play('smash.wav', volume: _sfxVolume)
          .then<void>((_) {}, onError: (_) {});
    } catch (_) {}
  }

  void playDefeat() {
    if (!_initialized || _sfxVolume <= 0) return;
    try {
      FlameAudio.play('bounce.wav', volume: (_sfxVolume * 0.6).clamp(0.0, 1.0))
          .then<void>((_) {}, onError: (_) {});
    } catch (_) {}
  }

  // ── Cleanup ─────────────────────────────────────────────────
  void dispose() {
    stopBGM();
    try {
      if (_initialized) {
        FlameAudio.bgm.dispose();
      }
    } catch (_) {}
  }
}
