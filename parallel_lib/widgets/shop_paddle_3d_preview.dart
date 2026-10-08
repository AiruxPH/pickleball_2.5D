import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../models/shop_items.dart';
import 'shop_paddle_preview.dart';

/// Displays the shop's real GLB paddle on supported platforms.
///
/// Desktop and widget-test targets retain the lightweight painted preview because
/// model_viewer_plus is backed by Android/iOS WebViews or an HTML element on web.
class ShopPaddle3dPreview extends StatelessWidget {
  const ShopPaddle3dPreview({
    super.key,
    required this.paddle,
    required this.width,
    required this.height,
  });

  final PaddleItem paddle;
  final double width;
  final double height;

  bool get _supportsModelViewer =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!_supportsModelViewer) {
      return ShopPaddlePreview(
        paddle: paddle,
        width: width,
        height: height,
      );
    }
    
    // We expect the user to provide distinct .glb files named like 'paddle_p1.glb'
    // in the future. For now, it will attempt to load the specific model, 
    // and if the user hasn't added it yet, we can use a fallback or they will get an error.
    // To be safe against crashes, we just use the paddle id in the filename.
    final modelPath = 'assets/models/paddle_${paddle.id}.glb';

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ModelViewer(
          // In Flutter, if the asset doesn't exist, it might show a blank/error in model-viewer.
          // Since the user said they'll provide separate GLB files, we construct the path here.
          // If you want a fallback, you'd have to check if the file exists which is async.
          // We'll trust the user will provide them. For testing, you might need to copy 
          // `pickleball_paddle.glb` to `paddle_p1.glb`, etc.
          src: modelPath,
          alt: '${paddle.name} pickleball paddle in 3D',
          backgroundColor: Colors.transparent,
          autoRotate: true,
          cameraControls: true,
          disableZoom: true,
          interactionPrompt: InteractionPrompt.none,
          loading: Loading.eager,
        ),
      ),
    );
  }
}
