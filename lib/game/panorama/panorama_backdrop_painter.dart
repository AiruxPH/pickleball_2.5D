import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../utils/game_math.dart';
import 'panorama_uv_calculator.dart';

/// Renders a dynamic 360-degree panorama backdrop that smoothly tracks
/// the perspective camera's yaw, pitch, and field of view.
class PanoramaBackdropPainter extends CustomPainter {
  final ui.Image panoramaImage;
  final PerspectiveCamera camera;
  final bool isLowEnd;

  static final Paint _paintHighQuality = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  static final Paint _paintLowQuality = Paint()
    ..filterQuality = FilterQuality.low
    ..isAntiAlias = false;

  PanoramaBackdropPainter({
    required this.panoramaImage,
    required this.camera,
    required this.isLowEnd,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final slices = PanoramaUvCalculator.calculate(
      imageWidth: panoramaImage.width.toDouble(),
      imageHeight: panoramaImage.height.toDouble(),
      screenWidth: size.width,
      screenHeight: size.height,
      lookYaw: camera.lookYaw,
      lookPitch: camera.lookPitch,
      fovDegrees: camera.fov,
    );

    final paint = isLowEnd ? _paintLowQuality : _paintHighQuality;

    canvas.drawImageRect(panoramaImage, slices.firstSrc, slices.firstDst, paint);
    if (slices.hasWrap) {
      canvas.drawImageRect(panoramaImage, slices.wrapSrc!, slices.wrapDst!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PanoramaBackdropPainter oldDelegate) {
    return oldDelegate.panoramaImage != panoramaImage ||
        oldDelegate.camera.lookYaw != camera.lookYaw ||
        oldDelegate.camera.lookPitch != camera.lookPitch ||
        oldDelegate.camera.fov != camera.fov;
  }
}
