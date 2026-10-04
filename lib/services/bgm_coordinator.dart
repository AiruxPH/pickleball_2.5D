import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

/// ─────────────────────────────────────────────────────────────
/// BgmCoordinator — Synchronized background music manager
///
/// Resolves the browser error:
/// "Uncaught (in promise) RethrownDartError: AbortError: The play() request was interrupted by a call to pause()."
///
/// Ensures sequential, collision-free background music transitions
/// and safely handles HTML5 Audio / Web Audio promise rejections.
/// ─────────────────────────────────────────────────────────────

class BgmCoordinator {
  int _sequenceId = 0;
  bool _isPlaying = false;
  bool _isTransitioning = false;
  String _currentTrack = '';
  double _currentVolume = 0.7;

  bool get isPlaying => _isPlaying;
  String get currentTrack => _currentTrack;

  /// Initializes the underlying FlameAudio BGM player if needed.
  Future<void> init() async {
    try {
      await FlameAudio.bgm.initialize();
    } catch (e) {
      debugPrint('BgmCoordinator init error: $e');
    }
  }

  /// Sets volume without interrupting playback if the track is already playing.
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    try {
      // Always attempt to update the player volume — even if _isPlaying is
      // temporarily out of sync (e.g. right after a track switch on web).
      FlameAudio.bgm.audioPlayer.setVolume(_currentVolume);
    } catch (e) {
      debugPrint('BgmCoordinator setVolume error: $e');
    }
  }

  /// Requests playback of [track] at [volume].
  /// Cancels superseded in-flight requests and avoids overlapping play/pause collisions.
  Future<void> playTrack(String track, double volume) async {
    final int thisSeq = ++_sequenceId;
    _currentTrack = track;
    _currentVolume = volume.clamp(0.0, 1.0);

    if (_currentVolume <= 0) {
      await pause();
      return;
    }

    // Wait if an active transition is already running
    while (_isTransitioning) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (_sequenceId != thisSeq) {
        // A newer playTrack was requested; abort this superseded one
        return;
      }
    }

    _isTransitioning = true;
    try {
      // 1. Stop current BGM cleanly if playing
      if (_isPlaying) {
        try {
          await FlameAudio.bgm.stop();
        } catch (e) {
          _suppressAbortError(e, 'FlameAudio.bgm.stop');
        }
        _isPlaying = false;
      }

      if (_sequenceId != thisSeq) return;

      // 2. Play new track
      await FlameAudio.bgm.play(track, volume: _currentVolume);
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
      if (!_suppressAbortError(e, 'FlameAudio.bgm.play')) {
        debugPrint('BgmCoordinator play error ($track): $e');
        // Fallback to loop if high-tempo mp3 fails on restricted web contexts
        if (track != 'background_loop.wav' && _sequenceId == thisSeq) {
          try {
            _currentTrack = 'background_loop.wav';
            await FlameAudio.bgm.play(_currentTrack, volume: _currentVolume);
            _isPlaying = true;
          } catch (fallbackError) {
            _suppressAbortError(fallbackError, 'BGM fallback');
          }
        }
      }
    } finally {
      _isTransitioning = false;
    }
  }

  /// Safely pauses BGM, suppressing HTML5 audio AbortError collisions.
  Future<void> pause() async {
    ++_sequenceId;
    if (!_isPlaying) return;
    try {
      await FlameAudio.bgm.pause();
    } catch (e) {
      _suppressAbortError(e, 'FlameAudio.bgm.pause');
    } finally {
      _isPlaying = false;
    }
  }

  /// Resumes BGM playback safely.
  Future<void> resume() async {
    if (_isPlaying || _currentTrack.isEmpty || _currentVolume <= 0) return;
    try {
      await FlameAudio.bgm.resume();
      _isPlaying = true;
    } catch (e) {
      if (!_suppressAbortError(e, 'FlameAudio.bgm.resume')) {
        // If resume fails, fall back to playTrack
        await playTrack(_currentTrack, _currentVolume);
      }
    }
  }

  /// Stops BGM playback safely.
  Future<void> stop() async {
    ++_sequenceId;
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      _suppressAbortError(e, 'FlameAudio.bgm.stop');
    } finally {
      _isPlaying = false;
    }
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await stop();
    try {
      FlameAudio.bgm.dispose();
    } catch (_) {}
  }

  /// Helper to catch and suppress standard browser AbortErrors caused by rapid play/pause transitions.
  bool _suppressAbortError(dynamic error, String context) {
    final str = error.toString().toLowerCase();
    if (str.contains('aborterror') ||
        str.contains('interrupted by a call to pause') ||
        str.contains('the play() request was interrupted')) {
      debugPrint('BgmCoordinator: Suppressed expected web audio abort ($context)');
      return true;
    }
    return false;
  }
}
