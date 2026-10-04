import 'dart:math' as math;

import '../models/pickleball.dart';
import '../models/player.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';

enum CameraView { playerFollow, baseline, sideline, overhead }

extension CameraViewLabel on CameraView {
  String get label {
    switch (this) {
      case CameraView.playerFollow:
        return 'PLAYER';
      case CameraView.baseline:
        return 'BASELINE';
      case CameraView.sideline:
        return 'SIDELINE';
      case CameraView.overhead:
        return 'OVERHEAD';
    }
  }
}

/// Smooth camera controller shared by gameplay and spectator views.
class CameraController {
  CameraController({
    required this.camera,
    required this.player,
    required this.ball,
  })  : _smoothCamPos = camera.position.copy(),
        _smoothTarget = camera.target.copy();

  final PerspectiveCamera camera;
  final Player player;
  final Pickleball ball;

  Vec3 _smoothCamPos;
  Vec3 _smoothTarget;
  CameraView view = CameraView.playerFollow;

  void setView(CameraView nextView) {
    view = nextView;
  }

  CameraView cycleSpectatorView() {
    switch (view) {
      case CameraView.playerFollow:
      case CameraView.overhead:
        view = CameraView.baseline;
        break;
      case CameraView.baseline:
        view = CameraView.sideline;
        break;
      case CameraView.sideline:
        view = CameraView.overhead;
        break;
    }
    return view;
  }

  void update(double dt, double zoomFactor) {
    final posBlend =
        1.0 - math.exp(-CameraConstants.cameraLerpSpeed * dt);
    final targetBlend =
        1.0 - math.exp(-CameraConstants.cameraLerpSpeed * 1.5 * dt);
    final pose = _desiredPose(zoomFactor);

    _smoothCamPos = lerpVec3(_smoothCamPos, pose.position, posBlend);
    _smoothTarget = lerpVec3(_smoothTarget, pose.target, targetBlend);

    camera.position = _smoothCamPos;
    camera.target = _smoothTarget;
    final desiredFov = pose.fov;
    if (desiredFov != null) {
      camera.fov += (desiredFov - camera.fov) * posBlend;
    }
  }

  _CameraPose _desiredPose(double zoomFactor) {
    final trackedTarget = ball.state == BallState.inFlight
        ? Vec3(
            ball.position.x * 0.35,
            (ball.position.y * 0.25).clamp(4.0, 20.0),
            ball.position.z * 0.35 - 10.0,
          )
        : Vec3(player.position.x * 0.15, 6.0, -12.0);

    switch (view) {
      case CameraView.playerFollow:
        final extraBack = (ball.position.y / 30).clamp(0.0, 1.0) * 20;
        return _CameraPose(
          position: Vec3(
            player.position.x * 0.3,
            CameraConstants.cameraHeight,
            CourtDimensions.playerStartZ +
                CameraConstants.cameraDistanceBehind * zoomFactor +
                extraBack,
          ),
          target: trackedTarget,
        );
      case CameraView.baseline:
        return _CameraPose(
          position: Vec3(0, 54, 132),
          target: Vec3(
            ball.position.x * 0.18,
            (ball.position.y * 0.18).clamp(4.0, 14.0),
            ball.position.z * 0.18 - 6,
          ),
          fov: 48,
        );
      case CameraView.sideline:
        return _CameraPose(
          position: Vec3(118, 58, 12),
          target: Vec3(
            ball.position.x * 0.15,
            (ball.position.y * 0.16).clamp(3.0, 13.0),
            ball.position.z * 0.22,
          ),
          fov: 54,
        );
      case CameraView.overhead:
        return _CameraPose(
          // The Z offset avoids a world-up singularity while retaining a
          // tactical full-court view.
          position: Vec3(0, 158, 28),
          target: Vec3(ball.position.x * 0.1, 0, ball.position.z * 0.08 - 5),
          fov: 58,
        );
    }
  }
}

class _CameraPose {
  const _CameraPose({
    required this.position,
    required this.target,
    this.fov,
  });

  final Vec3 position;
  final Vec3 target;
  final double? fov;
}
