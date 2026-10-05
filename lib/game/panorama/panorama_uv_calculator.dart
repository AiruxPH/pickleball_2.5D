import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'panorama_slice.dart';

/// Calculates source and destination rectangle slices for sampling a 360°
/// equirectangular panorama image based on camera orientation and FOV.
class PanoramaUvCalculator {
  const PanoramaUvCalculator();

  /// Computes panorama slices for the given camera angles and viewport dimensions.
  static PanoramaSlice calculate({
    required double imageWidth,
    required double imageHeight,
    required double screenWidth,
    required double screenHeight,
    required double lookYaw,
    required double lookPitch,
    required double fovDegrees,
  }) {
    final sw = screenWidth > 0 ? screenWidth : 1.0;
    final sh = screenHeight > 0 ? screenHeight : 1.0;
    final aspect = sw / sh;

    final fovYRad = (fovDegrees * math.pi / 180.0).clamp(0.1, math.pi * 0.85);
    final fovXRad = 2.0 * math.atan(math.tan(fovYRad / 2.0) * aspect);

    // Horizontal and vertical angular span visible in the viewport
    final spanXFraction = (fovXRad / (2.0 * math.pi)).clamp(0.05, 0.95);
    final spanYFraction = (fovYRad / math.pi).clamp(0.05, 0.95);

    final srcWidth = spanXFraction * imageWidth;
    final srcHeight = spanYFraction * imageHeight;

    // Center U mapping: 0 rad = facing baseline down-court (image center)
    var yawFraction = (lookYaw / (2.0 * math.pi)) % 1.0;
    if (yawFraction < 0) yawFraction += 1.0;
    final centerX = ((yawFraction + 0.5) % 1.0) * imageWidth;

    var leftX = centerX - srcWidth / 2.0;
    while (leftX < 0) {
      leftX += imageWidth;
    }
    while (leftX >= imageWidth) {
      leftX -= imageWidth;
    }

    // Center V mapping: negative pitch (looking down) shifts viewport down towards floor
    final pitchFraction = (lookPitch / math.pi).clamp(-0.45, 0.45);
    final centerY = imageHeight * (0.5 - pitchFraction);
    final topY = (centerY - srcHeight / 2.0).clamp(0.0, imageHeight - srcHeight);

    // Check if the viewport crosses the 360° horizontal seam
    if (leftX + srcWidth <= imageWidth) {
      return PanoramaSlice(
        firstSrc: Rect.fromLTWH(leftX, topY, srcWidth, srcHeight),
        firstDst: Rect.fromLTWH(0, 0, sw, sh),
      );
    } else {
      final w1 = imageWidth - leftX;
      final f1 = (w1 / srcWidth).clamp(0.0, 1.0);
      final dstW1 = sw * f1;

      final w2 = srcWidth - w1;
      final dstW2 = sw - dstW1;

      return PanoramaSlice(
        firstSrc: Rect.fromLTWH(leftX, topY, w1, srcHeight),
        firstDst: Rect.fromLTWH(0, 0, dstW1, sh),
        wrapSrc: Rect.fromLTWH(0, topY, w2, srcHeight),
        wrapDst: Rect.fromLTWH(dstW1, 0, dstW2, sh),
      );
    }
  }
}
