import 'dart:math' as math;

import '../models/pickleball.dart';
import '../models/player.dart';
import '../utils/constants.dart';
import '../utils/game_math.dart';

enum CameraView { playerFollow, baseline, sideline, overhead, freeRoam }

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
      case CameraView.freeRoam:
        return 'FREE ROAM';
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
  double _freeRoamYaw = 0;
  double _freeRoamPitch = 0.52;
  double _freeRoamDistance = 170;
  Vec3 _freeRoamTarget = Vec3(0, 5, 0);

  void setView(CameraView nextView) {
    view = nextView;
  }

  double get freeRoamPitch => _freeRoamPitch;
  double get freeRoamDistance => _freeRoamDistance;
  double get freeRoamYaw => _freeRoamYaw;

  void adjustFreeRoam({
    double orbitDx = 0,
    double orbitDy = 0,
    double zoomFactor = 1,
  }) {
    if (view != CameraView.freeRoam) return;
    _freeRoamYaw = _wrapAngle(_freeRoamYaw - orbitDx * 0.008);
    _freeRoamPitch = (_freeRoamPitch - orbitDy * 0.006).clamp(0.26, 1.12);
    if (zoomFactor.isFinite && zoomFactor > 0) {
      _freeRoamDistance = (_freeRoamDistance / zoomFactor).clamp(110.0, 260.0);
    }
  }

  void resetFreeRoam() {
    _freeRoamYaw = 0;
    _freeRoamPitch = 0.52;
    _freeRoamDistance = 170;
    _freeRoamTarget = Vec3(0, 5, 0);
  }

  CameraView cycleSpectatorView() {
    switch (view) {
      case CameraView.playerFollow:
      case CameraView.freeRoam:
        view = CameraView.baseline;
        break;
      case CameraView.baseline:
        view = CameraView.sideline;
        break;
      case CameraView.sideline:
        view = CameraView.overhead;
        break;
      case CameraView.overhead:
        view = CameraView.freeRoam;
        break;
    }
    return view;
  }

  void update(double dt, double zoomFactor) {
    final posBlend = 1.0 - math.exp(-CameraConstants.cameraLerpSpeed * dt);
    final targetBlend =
        1.0 - math.exp(-CameraConstants.cameraLerpSpeed * 1.5 * dt);
    final pose = _desiredPose(zoomFactor);

    _smoothCamPos = lerpVec3(_smoothCamPos, pose.position, posBlend);
    _smoothTarget = lerpVec3(_smoothTarget, pose.target, targetBlend);

    camera.position = _smoothCamPos;
    camera.target = _smoothTarget;
    camera.up = pose.up?.copy() ?? Vec3(0, 1, 0);
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
          position: Vec3(0, 68, 160),
          target: Vec3(
            ball.position.x * 0.18,
            (ball.position.y * 0.18).clamp(4.0, 14.0),
            ball.position.z * 0.18 - 6,
          ),
          fov: 55,
        );
      case CameraView.sideline:
        return _CameraPose(
          position: Vec3(120, 69, 0),
          target: Vec3(
            ball.position.x * 0.10,
            (ball.position.y * 0.12).clamp(4.0, 10.0),
            (ball.position.z * 0.12).clamp(-8.0, 8.0),
          ),
          fov: 60,
        );
      case CameraView.overhead:
        return _CameraPose(
          position: Vec3(0, 230, 0),
          target: Vec3(0, 0, 0),
          up: Vec3(0, 0, -1),
          fov: 60,
        );
      case CameraView.freeRoam:
        final horizontal = math.cos(_freeRoamPitch) * _freeRoamDistance;
        return _CameraPose(
          position: Vec3(
            _freeRoamTarget.x + math.sin(_freeRoamYaw) * horizontal,
            _freeRoamTarget.y + math.sin(_freeRoamPitch) * _freeRoamDistance,
            _freeRoamTarget.z + math.cos(_freeRoamYaw) * horizontal,
          ),
          target: _freeRoamTarget.copy(),
          fov: 52,
        );
    }
  }

  static double _wrapAngle(double value) {
    final wrapped = (value + math.pi) % (math.pi * 2);
    return wrapped < 0 ? wrapped + math.pi : wrapped - math.pi;
  }
}

class _CameraPose {
  const _CameraPose({
    required this.position,
    required this.target,
    this.fov,
    this.up,
  });

  final Vec3 position;
  final Vec3 target;
  final double? fov;
  final Vec3? up;
}
