import 'package:flutter/foundation.dart';
import 'sfx_pool.dart';
import 'bgm_coordinator.dart';

/// ─────────────────────────────────────────────────────────────
/// AudioService — manages game background music and sound effects
///
/// Features:
/// 1. Recycled SfxPool (4 players) to prevent Web Audio context exhaustion:
///    "The AudioContext encountered an error from the audio device or the WebAudio renderer."
/// 2. Sequenced BgmCoordinator to eliminate HTML5 audio race conditions:
///    "AbortError: The play() request was interrupted by a call to pause()."
/// 3. Seamless transitions between Menu BGM and Match BGM with lowered match volume.
/// ─────────────────────────────────────────────────────────────

class AudioService {
  static const String kDefaultBgmTrack =
      'Energetic rock background music for sports & workout videos.mp3';
  static const String kMatchBgmTrack =
      'Dagored - High Impact (freetouse.com).mp3';

  /// Volume multiplier during active matches so sound effects (hits, smashes, cheers) remain prominent.
  static const double kMatchMusicVolumeFactor = 0.45;

  final SfxPool _sfxPool = SfxPool();
  final BgmCoordinator _bgmCoordinator = BgmCoordinator();

  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;
  bool _initialized = false;
  bool _bgmWanted = false;
  bool _userInteracted = !kIsWeb;
  bool _inMatch = false;
  String _currentTrack = kDefaultBgmTrack;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get isBgmPlaying => _bgmCoordinator.isPlaying;
  bool get isInitialized => _initialized;
  bool get userInteracted => _userInteracted;
  bool get isInMatch => _inMatch;
  String get currentTrack => _currentTrack;

  /// Effective volume accounting for whether match music (lower volume) or menu BGM is active.
  double get _effectiveMusicVolume {
    if (_inMatch) {
      return (_musicVolume * kMatchMusicVolumeFactor).clamp(0.0, 1.0);
    }
    return _musicVolume.clamp(0.0, 1.0);
  }

  // ── Init ────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _bgmCoordinator.init();
      await _sfxPool.init();
      _initialized = true;
    } catch (e) {
      debugPrint('AudioService init error: $e');
    }
  }

  // ── User Interaction Unlocker (Web Audio autoplay policy) ───
  Future<void> handleUserInteraction() async {
    _userInteracted = true;
    if (_bgmWanted && !isBgmPlaying && _musicVolume > 0) {
      await _startBgmInternal();
    }
  }

  // ── Volume ──────────────────────────────────────────────────
  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    if (!_initialized) return;

    if (_musicVolume <= 0) {
      pauseBGM();
    } else {
      // Always update coordinator volume with effective level (handles match vs menu)
      _bgmCoordinator.setVolume(_effectiveMusicVolume);
      // If BGM should be playing but isn't (e.g. was paused at 0), restart it
      if (_bgmWanted && !isBgmPlaying && _userInteracted) {
        _startBgmInternal();
      }
    }
  }

  void setSfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
  }

  // ── Background music ────────────────────────────────────────
  void playBGM({String track = kDefaultBgmTrack}) {
    _bgmWanted = true;
    _inMatch = false;

    if (_currentTrack == track && isBgmPlaying) {
      _bgmCoordinator.setVolume(_effectiveMusicVolume);
      return;
    }

    _currentTrack = track;
    if (_musicVolume <= 0) return;
    // Respect Web Audio autoplay policy — wait for handleUserInteraction()
    if (kIsWeb && !_userInteracted) return;

    _startBgmInternal();
  }

  // ── Match Music Controls ─────────────────────────────────────
  /// Starts high-intensity match music with lowered volume during gameplay.
  void startMatchMusic() {
    _inMatch = true;
    _bgmWanted = true;
    // Navigation to game screen counts as user interaction — unlock Web Audio
    _userInteracted = true;

    if (_currentTrack == kMatchBgmTrack && isBgmPlaying) {
      _bgmCoordinator.setVolume(_effectiveMusicVolume);
      return;
    }

    _currentTrack = kMatchBgmTrack;
    if (_musicVolume <= 0) return;

    _startBgmInternal();
  }

  /// Stops match music and transitions back to the main menu background music track.
  void stopMatchMusic() {
    _inMatch = false;
    _bgmWanted = true;
    _userInteracted = true;

    if (_currentTrack == kDefaultBgmTrack && isBgmPlaying) {
      _bgmCoordinator.setVolume(_effectiveMusicVolume);
      return;
    }

    _currentTrack = kDefaultBgmTrack;
    if (_musicVolume <= 0) {
      pauseBGM();
      return;
    }

    _startBgmInternal();
  }

  Future<void> _startBgmInternal() async {
    final effectiveVol = _effectiveMusicVolume;
    if (effectiveVol <= 0 || _musicVolume <= 0) return;
    if (!_initialized) {
      await init();
    }
    await _bgmCoordinator.playTrack(_currentTrack, effectiveVol);
  }

  void stopBGM() {
    _bgmWanted = false;
    if (!_initialized) return;
    try {
      _bgmCoordinator.stop();
    } catch (_) {}
  }

  void pauseBGM() {
    if (!_initialized) return;
    try {
      _bgmCoordinator.pause();
    } catch (_) {}
  }

  void resumeBGM() {
    _bgmWanted = true;
    if (!_initialized) return;
    if (kIsWeb && !_userInteracted) return;
    if (_musicVolume > 0 && !isBgmPlaying) {
      try {
        _bgmCoordinator.resume();
      } catch (_) {}
    }
  }

  // ── Sound effects (Recycled Pool: Prevents WebAudio Exhaustion) ───
  void playHit({bool isPower = false}) {
    if (!_initialized || _sfxVolume <= 0) return;
    final file = isPower ? 'smash.wav' : 'hit.wav';
    _sfxPool.play(file, _sfxVolume);
  }

  void playBounce() {
    if (!_initialized || _sfxVolume <= 0) return;
    _sfxPool.play('bounce.wav', (_sfxVolume * 0.85).clamp(0.0, 1.0));
  }

  void playNetHit() {
    if (!_initialized || _sfxVolume <= 0) return;
    _sfxPool.play('bounce.wav', (_sfxVolume * 0.55).clamp(0.0, 1.0));
  }

  void playButtonClick() {
    if (!_initialized || _sfxVolume <= 0) return;
    _sfxPool.play('button_click.wav', (_sfxVolume * 0.75).clamp(0.0, 1.0));
  }

  void playCrowdCheer() {
    if (!_initialized || _sfxVolume <= 0) return;
    _sfxPool.play('hit.wav', (_sfxVolume * 0.5).clamp(0.0, 1.0));
  }

  void playVictory() {
    if (!_initialized || _sfxVolume <= 0) return;
    _sfxPool.play('smash.wav', _sfxVolume);
  }

  void playDefeat() {
    if (!_initialized || _sfxVolume <= 0) return;
    _sfxPool.play('bounce.wav', (_sfxVolume * 0.6).clamp(0.0, 1.0));
  }

  // ── Cleanup ─────────────────────────────────────────────────
  void dispose() {
    if (!_initialized) return;
    try {
      stopBGM();
      _bgmCoordinator.dispose();
      _sfxPool.dispose();
    } catch (_) {}
  }
}
