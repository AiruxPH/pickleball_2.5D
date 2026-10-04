import '../utils/constants.dart';
import '../utils/game_math.dart';
import '../models/player.dart';
import '../models/pickleball.dart';

/// ─────────────────────────────────────────────────────────────
/// CameraController — Smooth dynamic camera follow
///
/// Camera sits behind player, looking toward net.
/// Smoothly follows player X position.
/// Pulls back slightly when ball is high/far.
/// Zooms in during power shots.
/// ─────────────────────────────────────────────────────────────

class CameraController {
  final PerspectiveCamera camera;
  final Player player;
  final Pickleball ball;

  // Smooth camera position (lerped)
  Vec3 _smoothCamPos;
  Vec3 _smoothTarget;

  CameraController({
    required this.camera,
    required this.player,
    required this.ball,
  })  : _smoothCamPos = camera.position.copy(),
        _smoothTarget = camera.target.copy();

  void update(double dt, double zoomFactor) {
    final lerpSpeed = CameraConstants.cameraLerpSpeed * dt;

    // ── Desired camera position ─────────────────────────────
    // Follow player X, stay fixed distance behind + above
    final desiredX = player.position.x * 0.3; // slight X follow

    // Pull back when ball is high or far
    final extraBack = (ball.position.y / 30).clamp(0.0, 1.0) * 20;
    final desiredZ = CourtDimensions.playerStartZ +
        CameraConstants.cameraDistanceBehind * zoomFactor +
        extraBack;

    final desiredCamPos = Vec3(
      desiredX,
      CameraConstants.cameraHeight,
      desiredZ,
    );

    // ── Desired look target ─────────────────────────────────
    // Tilt slightly forward so player is framed clearly above bottom HUD controls
    final desiredTarget = ball.state == BallState.inFlight
        ? Vec3(
            ball.position.x * 0.35,
            (ball.position.y * 0.25).clamp(4.0, 20.0),
            ball.position.z * 0.35 - 10.0,
          )
        : Vec3(player.position.x * 0.15, 6.0, -12.0);

    // ── Smooth lerp ─────────────────────────────────────────
    _smoothCamPos = lerpVec3(_smoothCamPos, desiredCamPos, lerpSpeed);
    _smoothTarget = lerpVec3(_smoothTarget, desiredTarget, lerpSpeed * 1.5);

    // Apply to camera
    camera.position = _smoothCamPos;
    camera.target = _smoothTarget;
  }
}
