import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';

/// Preloads and manages decoded hardware-backed `ui.Image` panoramas for court environments.
class CourtPanoramaManager {
  static final CourtPanoramaManager instance = CourtPanoramaManager._internal();

  CourtPanoramaManager._internal();

  final Map<String, ui.Image> _cache = {};
  final Set<String> _loading = {};

  /// Returns cached panorama image if already decoded and available.
  ui.Image? getImage(String assetPath) => _cache[assetPath];

  /// Checks if a panorama asset is currently cached in GPU memory.
  bool isLoaded(String assetPath) => _cache.containsKey(assetPath);

  /// Asynchronously loads and decodes the panorama asset into a hardware `ui.Image`.
  Future<ui.Image?> loadPanorama(String assetPath) async {
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath];
    }
    if (_loading.contains(assetPath)) {
      while (_loading.contains(assetPath)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cache[assetPath];
    }

    _loading.add(assetPath);
    try {
      final byteData = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _cache[assetPath] = frame.image;
      return frame.image;
    } catch (e) {
      debugPrint('[CourtPanoramaManager] Error loading panorama $assetPath: $e');
      return null;
    } finally {
      _loading.remove(assetPath);
    }
  }

  /// Preloads the panorama for the given court theme if configured.
  Future<void> preloadForTheme(CourtTheme theme) async {
    final path = theme.panoramaAssetPath;
    if (path != null) {
      await loadPanorama(path);
    }
  }

  /// Disposes and clears all cached panorama images.
  void clear() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _loading.clear();
  }
}
