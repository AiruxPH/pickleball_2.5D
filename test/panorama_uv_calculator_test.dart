import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/panorama/panorama_uv_calculator.dart';

void main() {
  group('PanoramaUvCalculator Tests', () {
    const imgWidth = 2048.0;
    const imgHeight = 1024.0;
    const screenWidth = 800.0;
    const screenHeight = 450.0;
    const fov = 60.0;

    test('Baseline down-court orientation (yaw=0, pitch=0) centers on middle of panorama', () {
      final slice = PanoramaUvCalculator.calculate(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        lookYaw: 0.0,
        lookPitch: 0.0,
        fovDegrees: fov,
      );

      // Center should be roughly at imgWidth / 2 = 1024
      final centerX = slice.firstSrc.left + slice.firstSrc.width / 2.0;
      expect(centerX, closeTo(1024.0, 1.0));
      expect(slice.firstDst.width, equals(screenWidth));
      expect(slice.firstDst.height, equals(screenHeight));
      expect(slice.hasWrap, isFalse);
    });

    test('Sideline 90-degree turn (yaw=-pi/2) shifts center by 25% of image width', () {
      final slice = PanoramaUvCalculator.calculate(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        lookYaw: -math.pi / 2.0,
        lookPitch: 0.0,
        fovDegrees: fov,
      );

      // Center should be at (0.5 - 0.25) * 2048 = 0.25 * 2048 = 512
      final centerX = slice.firstSrc.left + slice.firstSrc.width / 2.0;
      expect(centerX, closeTo(512.0, 1.0));
      expect(slice.hasWrap, isFalse);
    });

    test('360-degree boundary crossing splits into seamless first and wrap slices', () {
      // Facing directly backwards (yaw = pi): center should be at 0 or 2048, crossing the seam
      final slice = PanoramaUvCalculator.calculate(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        lookYaw: math.pi,
        lookPitch: 0.0,
        fovDegrees: fov,
      );

      expect(slice.hasWrap, isTrue);
      // Total screen width covered by both slices must equal screenWidth with zero gaps
      final totalDstWidth = slice.firstDst.width + slice.wrapDst!.width;
      expect(totalDstWidth, closeTo(screenWidth, 0.001));
      // First slice right edge aligns with wrap slice left edge
      expect(slice.firstDst.right, equals(slice.wrapDst!.left));
      // First source slice goes to image boundary
      expect(slice.firstSrc.right, equals(imgWidth));
      // Wrap source slice starts from 0
      expect(slice.wrapSrc!.left, equals(0.0));
    });

    test('Looking down (negative pitch) shifts viewport downward towards floor', () {
      final sliceLevel = PanoramaUvCalculator.calculate(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        lookYaw: 0.0,
        lookPitch: 0.0,
        fovDegrees: fov,
      );

      final sliceLookingDown = PanoramaUvCalculator.calculate(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        lookYaw: 0.0,
        lookPitch: -0.4,
        fovDegrees: fov,
      );

      // Top Y when looking down should be higher (farther down into the image) than level
      expect(sliceLookingDown.firstSrc.top, greaterThan(sliceLevel.firstSrc.top));
    });

    test('Overhead look-down clamp prevents out-of-bounds UV coordinates', () {
      final slice = PanoramaUvCalculator.calculate(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        lookYaw: 0.0,
        lookPitch: -math.pi / 2.0, // -90 degrees overhead
        fovDegrees: fov,
      );

      expect(slice.firstSrc.top, greaterThanOrEqualTo(0.0));
      expect(slice.firstSrc.bottom, lessThanOrEqualTo(imgHeight));
    });
  });
}
