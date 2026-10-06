# 1v1 Multiplayer Camera and Dynamic Joystick Proposal

## Executive summary

This feature is doable without rebuilding the match in Flame's `World` and
`CameraComponent`.

The project already has the important multiplayer separation:

- `PickleballGame` owns the shared world-space simulation, court rules, ball,
  and both players.
- The host advances the authoritative simulation.
- The challenger receives snapshots and sends input commands.
- `GamePresentation`, `PerspectiveCamera`, and `CourtPainter` render one local
  view of that shared state.
- Flutter widgets render the joystick, action buttons, Serve button, and HUD in
  screen space.

The recommended change is to add a real **screen-to-court transformation** to
the existing `PerspectiveCamera`, then route joystick and swipe input through a
small input-mapping layer. This removes hard-coded Player 2 axis inversions and
keeps camera orientation out of physics and networking.

Migrating the complete match renderer to Flame components can remain a future
option, but it is not required to solve the current perspective problem.

### Implementation status

Milestones A through C are now implemented for camera unprojection, touch
movement, swipe aiming, keyboard movement, and dynamic-joystick screen
coordinates. Network-rate tuning and live two-device acceptance testing remain.

---

## Goals

1. Keep one authoritative court coordinate system.
2. Keep Player 1 on the positive-Z half and Player 2 on the negative-Z half.
3. Let every client see its controlled player from the near/bottom baseline.
4. Make joystick, keyboard, swipe aiming, and future tap targeting feel natural
   from either camera.
5. Keep HUD and action controls fixed to the device screen.
6. Preserve the existing host-authoritative Firebase and LAN protocols.
7. Avoid a risky rewrite of scoring, collision, physics, or rendering.

## Non-goals for this phase

- Replacing `CourtPainter` with Flame sprite components.
- Moving physics into Forge2D.
- Giving clients authority over player or ball positions.
- Sending screen-space coordinates through Firebase or LAN.
- Changing pickleball scoring or court rules.
- Solving network latency through client-side prediction in the same change.

---

## Current project architecture

### Simulation/world space

`lib/game/pickleball_game.dart` owns the actual match. Its coordinate system is:

- X: left/right across the court.
- Y: height above the court.
- Z: depth along the court.
- Positive Z: Player 1/near half in the canonical host view.
- Negative Z: Player 2/far half in the canonical host view.

All collision, service boxes, kitchen rules, boundaries, and ball movement must
continue using this coordinate system.

### Presentation space

The match is currently not rendered through Flame's `CameraComponent`. It uses:

- `lib/utils/game_math.dart` — `PerspectiveCamera` projection math.
- `lib/game/camera_controller.dart` — local camera pose and reversed baseline.
- `lib/game/game_presentation.dart` — per-screen presentation state.
- `lib/game/game_loop.dart` — `CourtPainter`, which projects the 3D world onto
  the Flutter canvas.

`reverseBaseline` already places the challenger camera behind the opposite
baseline. This is a local presentation setting and should stay local.

### Screen-space interface

`lib/screens/game_screen.dart` and `lib/widgets/virtual_joystick.dart` render the
HUD and controls as Flutter widgets above the court painter. They therefore do
not rotate with the camera, which is the desired behavior.

---

## Problem statement

The current challenger workaround manually mirrors horizontal input:

```dart
_activeTouchCommands?.move(_isRemoteClient ? -x : x, y);
```

This works for one fixed baseline pose, but it ties gameplay input to a role.
It becomes incorrect or incomplete when:

- the camera rotates gradually;
- the view changes to sideline or overhead;
- camera yaw is not exactly 0 or 180 degrees;
- swipe aiming and movement use different inversion rules;
- a spectator or replay camera becomes controllable;
- camera smoothing temporarily changes the view direction.

The input should instead be transformed by the same camera that renders the
court.

---

## Proposed architecture

```text
Touch / joystick position (screen space)
                  |
                  v
        CourtInputMapper
                  |
       PerspectiveCamera ray
                  |
      intersect court plane Y = 0
                  |
                  v
Direction or target in world X/Z space
                  |
                  v
          MatchCommandController
                  |
        Firebase / LAN command
                  |
                  v
     Host-authoritative PickleballGame
```

Only world-space intent crosses the multiplayer boundary. The host never needs
to know which way the challenger's camera is facing.

---

## Phase 1: Add screen-to-court unprojection

Add a method to `PerspectiveCamera` that casts a ray from a screen point and
intersects the court ground plane.

The existing camera already caches the forward, right, and up basis vectors as
well as the horizontal and vertical field-of-view factors. The inverse mapping
can use those same values:

```dart
/// Converts a screen pixel into a point on a horizontal world plane.
/// Returns null when the ray is parallel to, or points away from, the plane.
Vec3? screenToGround(Offset screenPoint, {double groundY = 0}) {
  if (!_framePrepared) prepareFrame();
  if (screenSize.width <= 0 || screenSize.height <= 0) return null;

  final ndcX = screenPoint.dx / _halfScreenWidth - 1.0;
  final ndcY = 1.0 - screenPoint.dy / _halfScreenHeight;

  final halfW = 1.0 / _invHalfW;
  final halfH = 1.0 / _invHalfH;

  final rayX = _fwdX + ndcX * halfW * _rightX + ndcY * halfH * _upX;
  final rayY = _fwdY + ndcX * halfW * _rightY + ndcY * halfH * _upY;
  final rayZ = _fwdZ + ndcX * halfW * _rightZ + ndcY * halfH * _upZ;

  if (rayY.abs() < 0.0001) return null;
  final distance = (groundY - position.y) / rayY;
  if (!distance.isFinite || distance <= 0) return null;

  return Vec3(
    position.x + rayX * distance,
    groundY,
    position.z + rayZ * distance,
  );
}
```

This is the custom-renderer equivalent of Flame's `screenToWorld()`.

### Required tests

- Project a known ground point with `projectCoords()`, unproject the resulting
  pixel, and confirm the original X/Z values are recovered within tolerance.
- Repeat for normal and reversed baseline cameras.
- Repeat at the center and near all four court corners.
- Confirm points with no valid ground intersection return `null` safely.
- Confirm resize and field-of-view changes do not invalidate the inverse.

---

## Phase 2: Add a camera-aware input mapper

Create a presentation-only `CourtInputMapper`. It should not import or mutate
`PickleballGame`.

```dart
final class CourtInputMapper {
  const CourtInputMapper(this.camera);

  final PerspectiveCamera camera;

  /// Converts a screen drag into a normalized X/Z world direction.
  Vec3 directionFromScreenDrag(Offset origin, Offset current) {
    final worldOrigin = camera.screenToGround(origin);
    final worldCurrent = camera.screenToGround(current);
    if (worldOrigin == null || worldCurrent == null) {
      return Vec3(0, 0, 0);
    }

    final dx = worldCurrent.x - worldOrigin.x;
    final dz = worldCurrent.z - worldOrigin.z;
    final length = math.sqrt(dx * dx + dz * dz);
    if (length < 0.0001) return Vec3(0, 0, 0);

    return Vec3(dx / length, 0, dz / length);
  }
}
```

The mapper uses two unprojected points instead of manually negating axes. That
means normal baseline, reversed baseline, sideline, and rotated views all use
the same code.

### Command contract

The existing movement command carries player-relative axes and the simulation
mirrors the far-side depth axis internally. To avoid changing bots, replays, and
the network protocol in the first delivery, `CourtInputMapper` converts its
world X/Z result into that established command convention:

- near side: `(worldX, worldZ)`;
- far side: `(worldX, -worldZ)`.

This adaptation is based on the controlled court side, not the network role or
camera angle. A later protocol version may make commands explicitly world-space
and remove the simulation's far-side depth inversion, but that is not required
for camera-correct controls.

---

## Phase 3: Upgrade the dynamic joystick contract

The current dynamic joystick already provides:

- a floating origin;
- a left-side control zone;
- normalized output;
- independent Flutter overlay rendering;
- release/cancel handling.

Its callback only exposes normalized X/Y, however. Camera unprojection needs the
screen origin and current knob position. Extend the callback with a small value
object:

```dart
@immutable
final class JoystickDrag {
  const JoystickDrag({
    required this.origin,
    required this.current,
    required this.normalized,
  });

  final Offset origin;
  final Offset current;
  final Offset normalized;
}
```

Recommended callback:

```dart
final ValueChanged<JoystickDrag> onDrag;
```

The `DynamicJoystick` should continue tracking coordinates in its Flutter
overlay, then convert them into the `GameWidget`/court canvas coordinate system
before invoking `onDrag`. Since its current control zone begins below the top
HUD, its local Y coordinate must include that zone's screen offset.

### Pointer ownership

Flutter's pan gesture normally tracks one gesture, but the component should
still make ownership explicit so a second finger pressing Hit or Serve cannot
move or reset the joystick.

Recommended implementation options:

1. Use a `Listener` and store the active `pointer` ID. This gives direct,
   deterministic multi-touch ownership.
2. Keep `GestureDetector`, but isolate the joystick hit region and add widget
   tests for simultaneous joystick and action-button touches.

Option 1 is preferred for the multiplayer control layer.

### Dynamic joystick behavior

- Spawn only in the configured movement zone.
- Lock to the first accepted pointer until up/cancel.
- Clamp the knob to the configured radius.
- Apply a radial dead zone, not separate X/Y dead zones.
- Preserve analog magnitude outside the dead zone.
- Always issue a zero movement command on pointer up, cancel, app pause, route
  change, disconnect, or loss of focus.
- Keep the visual joystick inside a `RepaintBoundary`.

---

## Phase 4: Route all directional inputs consistently

The following inputs should use the same camera-aware mapping policy:

### Touch joystick

Convert origin/current screen positions through `CourtInputMapper`, preserve the
joystick magnitude, and send normalized world X/Z intent.

### Swipe aiming

Unproject the swipe start and current positions. Use their X/Z difference as the
aim direction. Remove `_isRemoteClient ? Offset(-dx, dy) : delta`.

### Keyboard

Keyboard input has no screen position. Build its direction using camera-relative
ground axes:

- right/left: sample screen center and center plus/minus a horizontal offset;
- forward/back: sample screen center and center plus/minus a vertical offset;
- combine and normalize those world directions.

This makes WASD/arrow controls camera-relative too.

### Tap-to-target or trajectory editing

Convert the tapped canvas coordinate directly with `screenToGround()` and send
the resulting world target. Do not send raw pixels.

---

## Phase 5: Keep UI and player authority local

The following remain Flutter overlay elements and must never pass through the
world camera:

- scoreboard;
- pause button;
- Serve button;
- Hit, Drop, Lob, and Power buttons;
- ultimate meter;
- connection/latency indicator;
- ready-state and match messages.

Button visibility must depend on local slot authority, not merely whether the
active server is human:

```text
host browser       -> controls slot 0 only
challenger browser -> controls slot 1 only
Serve visible      -> local slot is the authoritative active server
```

The camera controls what a client sees. The assigned slot controls what that
client may command. These are related presentation choices but must remain
separate concepts.

---

## Networking and performance

### Preserve host authority

The client sends intent only. The host remains responsible for:

- collision and court bounds;
- acceleration and stamina;
- paddle contacts;
- ball physics;
- serve legality;
- scoring and match state.

### Command frequency

Do not write joystick commands on every Flutter pointer event without a limit.
Recommended behavior:

- update local joystick visuals at display refresh rate;
- send movement intent at a fixed 15–20 Hz;
- send immediately when direction changes materially;
- always send an immediate zero command on release;
- continue using the sequenced per-player Firebase command mailbox;
- deduplicate unchanged direction values.

This reduces Realtime Database traffic and host-side command processing while
remaining responsive.

### Snapshot frequency

Keep authoritative snapshots independent from input frequency. The current
10 Hz snapshots with client interpolation are a reasonable baseline. Tune only
after measuring latency and frame time.

---

## Optional future Flame migration

If the renderer is later moved fully into Flame, the same architecture maps to:

```dart
final world = CourtWorld();
final camera = CameraComponent.withFixedResolution(
  world: world,
  width: 720,
  height: 1280,
);

camera.viewfinder.angle = isPlayer2 ? math.pi : 0;
```

Use Flame's screen/world conversion for pointer positions and keep UI in
`GameWidget` overlays or viewport-space components.

That migration should be proposed separately because the current renderer has
custom 3D perspective projection, panorama backgrounds, sprite scaling, and
court-plane matrices that a standard 2D `CameraComponent` does not replace
automatically.

---

## Delivery plan

### Milestone A — Camera inverse and tests

- Add `PerspectiveCamera.screenToGround()`.
- Add projection/unprojection round-trip tests.
- No gameplay behavior change.

### Milestone B — Touch movement and aiming

- Add `CourtInputMapper`.
- Extend dynamic joystick callback with screen coordinates.
- Route touch movement and swipe aiming through the mapper.
- Remove role-based manual inversion.

### Milestone C — Keyboard and multi-touch hardening

- Make keyboard directions camera-relative.
- Add explicit pointer ownership.
- Test simultaneous movement and action presses.
- Stop movement reliably on lifecycle interruption.

### Milestone D — Network tuning

- Add fixed-rate movement command publishing and unchanged-value deduplication.
- Measure Firebase writes, host frame time, snapshot delay, and perceived input
  latency on two browsers and two physical devices.

### Milestone E — Controlled rollout

- Test host and challenger from Chrome/Edge on one computer.
- Test two computers on the same network.
- Test two remote networks.
- Verify serve ownership, side-outs, rematches, reconnects, and leaving midway.

---

## Acceptance criteria

The work is complete when:

1. Each client always sees its assigned player from the intended near-side
   perspective.
2. Moving the joystick left moves the controlled character left on that
   client's screen for both players.
3. Moving forward always moves toward the top of the client's court view.
4. The behavior remains correct while the camera is smoothly moving.
5. Swipe aiming follows the displayed direction for both clients.
6. Only the active local server sees an actionable Serve button.
7. HUD and controls never rotate with the court.
8. The client never directly mutates ball, score, or authoritative positions.
9. No repeated Firebase permission errors or unhandled command futures occur.
10. Movement stops on pointer release, cancellation, disconnect, and app pause.
11. Projection/unprojection and multiplayer command tests pass.
12. No visible frame regression occurs on the target mobile device.

---

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Unprojection becomes unstable near the horizon | Reject parallel/back-facing rays and keep gameplay cameras angled toward the court. |
| Joystick-local coordinates do not match canvas coordinates | Convert through the widget's render box or provide the control-zone screen offset explicitly; cover with widget tests. |
| Too many Firebase movement writes | Publish at a fixed rate, deduplicate, and immediately send only important state changes. |
| Input changes accidentally affect rules | Keep mapper in the presentation/input layer and test `PickleballGame` independently. |
| Camera pose is not prepared before input | Prepare/update the camera before accepting input and after viewport resize. |
| Full Flame migration expands scope | Treat it as a separate project after the current input solution is stable. |

---

## Recommendation

Proceed with Milestones A through C first. They solve the inverted-control issue
at the correct abstraction boundary and improve touch, swipe, keyboard, and
future camera modes together.

After those changes are stable, complete Milestone D using measured network
traffic rather than guessing. Do not migrate the match to Flame's
`CameraComponent` solely for this fix; the existing `PerspectiveCamera` can
provide the equivalent transformation with much lower risk.
