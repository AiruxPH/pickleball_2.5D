import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../pickleball_game.dart';
import '../game_presentation.dart';
import '../../utils/constants.dart';
import 'court_panorama_manager.dart';
import 'panorama_backdrop_painter.dart';

/// Renders either an interactive 360-degree panorama backdrop that tracks
/// the game camera, or falls back to the static court theme artwork when
/// no panorama is configured or while decoding.
class CourtBackdropView extends StatefulWidget {
  final PickleballGame game;
  final GamePresentation presentation;
  final Listenable? repaint;

  const CourtBackdropView({
    super.key,
    required this.game,
    required this.presentation,
    this.repaint,
  });

  @override
  State<CourtBackdropView> createState() => _CourtBackdropViewState();
}

class _CourtBackdropViewState extends State<CourtBackdropView> {
  ui.Image? _cachedPanorama;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _checkAndLoadPanorama();
  }

  @override
  void didUpdateWidget(covariant CourtBackdropView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.settings.courtTheme != widget.game.settings.courtTheme) {
      _checkAndLoadPanorama();
    }
  }

  void _checkAndLoadPanorama() {
    final theme = widget.game.settings.courtTheme;
    final path = theme.panoramaAssetPath;
    if (path == null) {
      if (_cachedPanorama != null) {
        setState(() {
          _cachedPanorama = null;
          _loadedPath = null;
        });
      }
      return;
    }

    if (path == _loadedPath && _cachedPanorama != null) return;

    final immediate = CourtPanoramaManager.instance.getImage(path);
    if (immediate != null) {
      _cachedPanorama = immediate;
      _loadedPath = path;
      return;
    }

    CourtPanoramaManager.instance.loadPanorama(path).then((img) {
      if (mounted && img != null && widget.game.settings.courtTheme.panoramaAssetPath == path) {
        setState(() {
          _cachedPanorama = img;
          _loadedPath = path;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final panorama = _cachedPanorama;
    if (panorama != null) {
      return CustomPaint(
        painter: PanoramaBackdropPainter(
          panoramaImage: panorama,
          camera: widget.presentation.camera,
          isLowEnd: widget.game.settings.isLowEndMode,
          repaint: widget.repaint,
        ),
      );
    }

    // High-performance fallback: standard 2D theme artwork
    return Image.asset(
      widget.game.settings.courtTheme.assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      cacheWidth: widget.game.settings.isLowEndMode ? 960 : 1920,
      filterQuality: widget.game.settings.isLowEndMode
          ? FilterQuality.low
          : FilterQuality.medium,
    );
  }
}
