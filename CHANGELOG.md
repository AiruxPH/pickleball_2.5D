# Change Log

## 2026-10-06

### Firebase online multiplayer foundation and LAN hardening
- **Reason of Change:** Finalize the host-authoritative LAN path and add the first production-shaped online multiplayer implementation using Firebase.
- **Changes Applied:**
  1. Added `firebase_core`, `firebase_auth`, and `firebase_database` through the official FlutterFire packages.
  2. Added configuration-safe Firebase bootstrap. Native builds use files produced by `flutterfire configure`; web can temporarily use `FIREBASE_*` dart-defines. Missing configuration is reported in the Online screen without breaking the rest of the app.
  3. Added anonymous authentication and a Firebase Realtime Database room service with six-character codes, host/client roles, presence, ready state, singles/doubles lobby format, match-start events, command queues, host-authoritative snapshots, disconnect cleanup, and closed-room detection.
  4. Added an Online Multiplayer mode card, route, and responsive lobby for creating/joining rooms, copying room codes, readying players, selecting 1v1/2v2, and starting a match.
  5. Reused the existing match command and state snapshot contracts for LAN and Firebase. Network clients no longer advance a competing local physics simulation; only the host simulates, while clients render authoritative snapshots.
  6. Throttled Firebase state snapshots to 10 Hz to avoid writing at render frequency. Input commands remain event-based.
  7. Hardened LAN with a two-second heartbeat, measured latency, three progressive reconnect attempts, reconnecting UI state, and explicit manual-disconnect handling.
  8. Added an explicit `MatchLobby.online` constructor so serialized online lobbies retain their correct transport type and room ID.
  9. Added locked-by-default Realtime Database rules with authenticated room reads, host-only lobby/snapshot/start mutation, self-owned presence, and validated client actions/commands.
  10. Added `FIREBASE_SETUP.md`, `firebase.json`, and deployable `database.rules.json` setup assets.
  11. Extended mode-selection coverage to include Online Multiplayer.
- **Verification:**
  - `flutter analyze` completed with no issues after integration.
  - Focused LAN, mode-selection, and widget suites passed (20/20 tests).
  - Complete Flutter suite passed (169/169 tests); the existing compact-Shop `PLAYERS` hit-test warning remains non-fatal.
  - `database.rules.json` parses as valid JSON.
- **Configuration Still Required:** Run `flutterfire configure`, enable Anonymous Authentication, create Realtime Database, and deploy `database.rules.json` before live online rooms can connect.

## 2026-10-05

### 2026-10-05 — Match UX, equipment skills, mode flow, controls, and court presentation
- **Reason of Change:** Apply the requested match-exit, control, loadout, achievements, mode-selection, profile, settings, career, and court-rendering refinements.
- **Changes Applied:**
  1. Added a guarded mid-match exit flow for system back and the pause-menu Main Menu action. The match pauses while the confirmation is open and resumes if leaving is cancelled.
  2. Removed all reachable in-match and mode-selection special-skill selection. Special shots are now paddle perks: Lightning Smash → Thunder Strike, Phantom Shot → Night Shift, Fireball Drop → Inferno X Pro, and Ice Shot → Glacier Titanium. Paddles without a perk do not charge or show the special action.
  3. Preserved and emphasized tactile action-button feedback through the shared animated press-scale, glow, haptic, and click-audio behavior used by Hit, Power, Lob, and Drop.
  4. Added persistent dynamic/fixed joystick preference, a touch-origin dynamic joystick, and a paused-match Customize Controls workflow. The joystick and action cluster can be dragged and their normalized positions are saved.
  5. Reworked Mode Select into a mode-only grid. Difficulty, court, and Bot-vs-Bot 1v1/2v2 format now appear only after selecting a mode in a setup dialog. Quick Match and the separate special-shot selector were removed.
  6. Removed global AI Difficulty from Settings; difficulty remains a per-match selection. Settings now exposes dynamic/fixed joystick style.
  7. Added persistent achievement seen-state, so the red notification badge clears after opening Achievements and only returns for a newly unlocked achievement.
  8. Scaled the player-profile dialog down by 10% on mobile screens.
  9. Changed Career Mode to a Story Mode “Coming Soon” presentation while preserving the existing career data model for future work.
  10. Continued using the existing `assets/images/courts/` theme imagery and panoramic variants in matches. Alternate camera views now blur/overscan the backdrop, panoramas retain camera-linked movement, and static fallbacks animate scale subtly during view changes.
  11. Restored the regulation 2-inch court-line width instead of the exaggerated width that expanded into white slabs at oblique sideline angles.
  12. Updated mode-selection and paddle regression tests for the new flow and equipment mapping.
- **Verification:**
  - `flutter analyze` completed with no issues.
  - Focused mode-selection, shop/loadout, and widget suites passed (24/24 tests).
  - Complete Flutter suite passed (169/169 tests); the pre-existing compact-Shop `PLAYERS` hit-test warning remains non-fatal.
  - The Dart MCP hot-reload/restart service was not available in this session; no running app could be connected through DTD.

### 2026-10-05 23:11:00+08:00
- **Reason of Change:** Integrate dynamic 360-degree equirectangular panorama court environment rendering across all camera views (Baseline, Sideline, Overhead, Player Follow, and Free Roam), and update asset paths for newly provided court images.
- **Cause of Error:**
  1. `lib/utils/constants.dart`: Legacy asset references `court_7.jpg` and `court_1.png` were renamed/replaced in `assets/images/courts/` with `court_7.png` and `court_1.jpg`, risking missing asset runtime exceptions.
  2. Previously, `GameScreen` used a frozen 2D `Image.asset(fit: BoxFit.cover)`, which remained statically locked when switching to sideline broadcast views (90° yaw) or free roam orbit, causing perspective mismatch with the rotating 3D court.
- **Features Implemented & Sliced per Rule 2:**
  1. [constants.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/utils/constants.dart):
     - Corrected `assetPath` references for `CourtTheme.tournament` (`court_7.png`) and `CourtTheme.beach` (`court_1.jpg`).
     - Added `panoramaAssetPath` getter mapping court themes to their respective 360-degree panorama backdrops (`court_7_panorama.png`, `court_1_panorama.jpg`, `court_2_panorama.jpg`, `court_5_panorama.jpg`, `grassland_panorama.jpg`, `starry_night_panorama.jpg`).
  2. [game_math.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/utils/game_math.dart):
     - Added `forwardX`, `forwardY`, `forwardZ`, `lookYaw`, and `lookPitch` angle getters on `PerspectiveCamera`.
  3. [panorama_slice.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/panorama/panorama_slice.dart):
     - Created immutable slice data model representing single or split-wrapped rectangular UV projections.
  4. [panorama_uv_calculator.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/panorama/panorama_uv_calculator.dart):
     - Implemented mathematical projection from camera yaw, pitch, and FOV into equirectangular UV source rectangles with seamless 360° horizontal seam wrapping.
  5. [court_panorama_manager.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/panorama/court_panorama_manager.dart):
     - Preloads and caches hardware-decoded `ui.Image` panoramas in GPU memory.
  6. [panorama_backdrop_painter.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/panorama/panorama_backdrop_painter.dart):
     - Lightweight `CustomPainter` rendering smooth 360° viewport slices at 120+ FPS.
  7. [court_backdrop_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/panorama/court_backdrop_view.dart):
     - Responsive backdrop widget in [game_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/game_screen.dart) connecting the camera projection to the panorama painter with automatic fallback to static 2D artwork.
  8. [panorama_uv_calculator_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/panorama_uv_calculator_test.dart):
     - Unit test suite covering center mapping, 90° sideline yaw shift, pitch clamp, and 360° seam split wrapping (5/5 tests passing).
- **Verification:**
  - `dart analyze` / `analyze_files` passed with 0 errors and 0 warnings.
  - Complete test suite passed (168/168 tests).

### 2026-10-05 21:49:00+08:00
- **Reason of Change:** Fix character foot anchoring and ground shadow projection in `SpriteCharacterRenderer` and `CharacterRenderer` to eliminate the visual illusion of characters touching the Non-Volley Zone (NVZ / Kitchen) line while in legal standing positions, and resolve background floor bleed-through.
- **Cause of Error:**
  1. `lib/game/sprite_character_renderer.dart`: Added an artificial `_feetY = 34.0` offset to the sprite destination rectangle `dst.top`. Because `atlas.anchorY` was already anchored precisely at the athlete's shoes (y=202 of 216), this added +34px downward screen displacement from the true ground contact coordinate $(X, 0, Z)$. In a forward/down-tilted perspective projection, shifting downward on screen pushes far-side characters forward toward the net, creating the false visual appearance of stepping onto the kitchen line.
  2. `lib/game/character_renderer.dart`: Contact shadows and directional cast shadows were translated downwards by `(0, 33.0)` and `(15.0, 29.0)` instead of anchoring at the ground contact point `(0, 0.0)`.
  3. Static background image artifact (`court_7.jpg`): The 2D backdrop has a perspective court baked onto its floor. When switching camera angles (Sideline at 90°, Overhead at top-down, or Free Roam), the static 2D court bleeds through around the 3D court apron, creating a dual-court visual collision.
- **Fix Applied:**
  1. [sprite_character_renderer.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/sprite_character_renderer.dart): Set `_feetY = 0.0` so the sprite anchor aligns with `screenPos` $(X, 0, Z)$ on the court surface.
  2. [character_renderer.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/character_renderer.dart): Updated `drawGroundShadows` with `isGrounded` default true, positioning contact shadow at `(0, 0.0)` and directional shadow at `(12.0, -4.0)`. Shifted procedural body by `groundOffset = -34.0` when rendered in-game (`cam != null`), placing athletic soles flush with the floor.
- **Verification:**
  - `dart analyze` / `analyze_files` passed with 0 errors and 0 warnings.
  - Complete test suite passed (163/163 tests).

### 2026-10-05 21:13:30+08:00
- **Reason of Change:** Clean up unused import warnings in `pickleball_game.dart` and `player_shot_mechanics_test.dart` identified in the problems tab.
- **Cause of Error:**
  1. `lib/game/pickleball_game.dart`: `shot_targeting.dart` was directly imported in the game controller, but direct usage was moved inside `player_aim_calculator.dart`.
  2. `test/player_shot_mechanics_test.dart`: `player_aim_calculator.dart` was imported but lacked explicit test assertions exercising it directly.
- **Fix Applied:**
  1. [pickleball_game.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/pickleball_game.dart): Removed redundant `shot_targeting.dart` import.
  2. [player_shot_mechanics_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/player_shot_mechanics_test.dart): Added unit test cases for `calculatePlayerAimDirection` validating joystick steering synthesis and sideline safety redirection.
- **Verification:**
  - `dart analyze` / `analyze_files` passed with 0 errors and 0 warnings.
  - Complete player shot mechanics test suite passed (10/10 tests).

### 2026-10-05 21:11:00+08:00
- **Reason of Change:** Implement forgiving, entertaining, and intelligent player hit mechanics for button-based controls, so the engine handles natural angles, contextual shot adaptation, and net-clearance safety without punishing players with cheap unforced faults.
- **Features Implemented & Sliced per Rule 2:**
  1. [contextual_shot_type.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/shot/contextual_shot_type.dart):
     - Automatically adapts high floaters ($Y \ge 26.0$) in front of the player into overhead smashes when tapping `HIT` or `POWER`.
     - Automatically softens low balls ($Y \le 20.0$) near the kitchen line into controlled dinks/drops rather than rocketing them deep or into the net.
  2. [contact_timing_offset.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/shot/contact_timing_offset.dart):
     - Calculates natural lateral angle deflection based on contact timing relative to player position and paddle arm (forehand vs backhand).
     - Early contact in front of the body pulls cross-court; late contact pushes down-the-line.
  3. [shot_quality.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/shot/shot_quality.dart):
     - Computes contact proximity and sweet-spot quality.
     - Scales speed and lift: sweet-spot contact grants crisp pace and visual camera punch; stretched/edge reach softens speed and boosts lift so off-center hits never produce instant unforced faults.
  4. [player_aim_calculator.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/shot/player_aim_calculator.dart):
     - Synthesizes joystick X/Y steering, swipe direction, and contact timing deflection.
     - Passes proposed direction through sideline boundary constraints to keep wide balls curving into playable court.
  5. [player_shot_trajectory_solver.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/shot/player_shot_trajectory_solver.dart):
     - Solves 3D launch velocity with smart net clearance cushion ($V_{y,\min}$) and in-bounds flight time limits.
  6. [pickleball_game.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/pickleball_game.dart):
     - Refactored `_executePlayerHit`, `_getAimDirection`, and `_getOpponentAimDirection` to delegate directly to the modular shot package.
  7. [player_shot_mechanics_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/player_shot_mechanics_test.dart):
     - Full regression coverage for contextual smash/dink adaptation, early/late timing deflection, quality scaling, and safe net clearance.
- **Verification:**
  - `dart analyze` / `analyze_files` passed with zero errors or warnings.
  - New player shot mechanics test suite passed (8/8 tests).
  - Existing rules and AI rally test suites passed (55/55 tests).

### 2026-10-05 — Simulation, rules, dimensions, and UI audit
- **Reason of Change:** Record the requested verification of match isolation, pickleball rules, regulation dimensions, responsive layouts, and game-UI principles.
- **Review Findings:**
  1. Simulation state is world-space and viewport-independent; `GamePresentation` and `CourtPainter` own the camera/projection, and the presentation-separation regression confirms camera and viewport changes do not alter match results. Each `GameScreen` constructs its own `PickleballGame`, although matches are not separate native 3D engine scenes because rendering uses Flutter `CustomPaint` with a perspective projection.
  2. The implemented competitive rules include traditional side-out scoring, 11 points win by 2, diagonal serves, baseline/server-side constraints, the two-bounce rule, Non-Volley Zone and momentum faults, in/out and net faults, singles service changes, and doubles server rotation including the 0-0-2 opening exception. This is strong gameplay coverage, but not a claim that every administrative edge case in the complete official rulebook is modeled.
  3. World geometry uses one regulation conversion of four units per foot: a 20 ft by 44 ft court, 7 ft NVZ, 36 in net posts with a 34 in center, 2 in lines, a six-foot character reference, and a 2.94 in ball diameter.
  4. Screens broadly use `MediaQuery`, `LayoutBuilder`, `SafeArea`, flexible/expanded regions, fitted content, lists, and scrolling. Compact layout regressions currently cover the shop, how-to-play screen, and selected mode layouts, so universal no-overflow behavior on every device and accessibility text scale is not yet proven. The full suite also emitted a non-fatal compact-shop hit-test warning for the `PLAYERS` tab, indicating that tappability/obscuration deserves a focused follow-up.
  5. The in-match UI follows core game-UI principles through hierarchy, feedback, consistent controls, readable world-object minimums, safe-area placement, pause support, and low-cost repaint separation. Formal accessibility and usability coverage remains incomplete, especially semantics, contrast validation, dynamic text scaling, minimum touch-target assertions, and systematic device-matrix tests.
- **Verification:**
  - Complete Flutter suite passed (153/153 tests); one non-fatal compact-shop hit-test warning was observed.
  - `flutter analyze` completed with no issues.

### 2026-10-05 19:01:33+08:00
- **Reason of Change:** Give both players in Bot vs Bot matches independent, context-aware decisions by adapting the useful agent concepts from the read-only reference `pickle_ball_game/lib/bot_agent.dart`.
- **Cause of Error:** Spectator matches previously combined two unrelated control systems: a command-bound `BotAgent` controlled the near player while the normal direct `AIController` controlled the far player. The near bot also used fixed recovery and aim behavior with no identity, personality, seeded variation, or side-aware perspective. When both players were moved onto the command boundary, the far-side multiplayer shot executor's fixed velocity could still produce a net fault.
- **Fix Applied:**
  1. [bot_agent.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/bot_agent.dart):
     - Added near/far court-side identity and normalized far-side observations into a local player-centric perspective.
     - Added independent bot IDs, deterministic random seeds, personality traits, aggression, recovery depth, aim spread, cached shot plans, and separate reaction/cooldown state.
     - Added patient, balanced, and aggressive play styles that independently choose safe returns, drives, lobs, drops, and smashes from ball height and opponent position.
     - Replaced the approximate landing prediction with the production 120 Hz gravity and quadratic-drag integration.
     - Preserved per-tick legal contact reflexes, the two-bounce rule, kitchen restrictions, and command-only output.
  2. [game_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/game_screen.dart):
     - Bot vs Bot now creates two separate side-aware `BotAgent` instances with different identities, personalities, seeds, targets, plans, and command sinks.
     - Runs spectator matches through the local two-player simulation path so neither bot bypasses the shared command boundary.
  3. [pickleball_game.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/pickleball_game.dart):
     - Routed far-side command-driven shots through `AIShotPlanner` using the production drag model.
     - Added a validated safe-return fallback so an independently selected shot still clears the net and lands in court.
  4. [bot_agent_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/bot_agent_test.dart):
     - Added coverage for mirrored far-side ownership, personality-specific decisions, isolated command slots, and a complete autonomous serve/return/third-shot exchange at 120 Hz.
- **Verification:**
  - Focused bot, rally, and rules suites passed (62/62 tests).
  - Complete Flutter suite passed (153/153 tests).
  - `flutter analyze` completed with no issues.
  - `git diff --check` passed.
  - The reference project was read only; no files or assets were copied or modified.

### 2026-10-05 18:48:00+08:00
- **Reason of Change:** Fix the autonomous near-side bot failing to return a served ball.
- **Cause of Error:** `BotAgent` checked both tactical decisions and the narrow paddle-contact envelope only on its difficulty-dependent thinking interval. On easy difficulty that interval is 0.28 seconds, allowing a serve to pass completely through the legal contact window between checks even though the fixed simulation runs at 120 Hz.
- **Fix Applied:**
  1. [bot_agent.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/bot_agent.dart):
     - Separated legal paddle-contact detection from reaction-paced movement and tactical updates.
     - Evaluated the return contact envelope every fixed simulation tick while preserving serve-bounce, kitchen, volley-establishment, reach-height, and swing-cooldown requirements.
     - Kept difficulty reaction time responsible for anticipation and movement rather than whether the bot can physically observe contact.
  2. [bot_agent_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/bot_agent_test.dart):
     - Added an end-to-end easy-bot regression that receives and returns an AI serve at the production 120 Hz step.
  3. [ai_rally_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/ai_rally_test.dart):
     - Added production-step serve-return coverage for the far-side opponent on easy, medium, and hard difficulties.
- **Verification:**
  - The new bot-vs-bot regression failed before the fix and passed after it.
  - Focused bot and AI rally suites passed (14/14 tests).
  - Complete Flutter suite passed (150/150 tests).
  - `flutter analyze` completed with no issues.

### 2026-10-05 12:20:47+08:00
- **Reason of Change:** Make bot returns and volleys respect the requested serve-bounce and Non-Volley Zone behavior.
- **Cause of Error:** `AIController` allowed a bot to enter the NVZ after any bounce, even when the ball had bounced outside the NVZ. The serve/return wait checks also duplicated raw rally-count logic instead of using the ball model's shared two-bounce rule.
- **Fix Applied:**
  1. [ai_controller.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/ai_controller.dart):
     - Kept the mandatory bounce for the receiving bot after a serve and for the serving side's next shot through `Pickleball.mustBounceBeforeHit`.
     - Preserved direct volleys for normal rally balls when the bot is established outside the NVZ.
     - Added side-aware detection of whether the current ball bounced in the bot's own NVZ.
     - Prevented the bot from approaching or striking while touching the NVZ unless that ball bounced in its own NVZ.
  2. [ai_rally_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/ai_rally_test.dart):
     - Added regression coverage for mandatory serve-return bounces, legal normal-rally volleys outside the NVZ, and staying outside the NVZ after a non-NVZ bounce.
     - Made the existing kitchen-bounce retrieval scenario record its actual bounce location.
- **Verification:**
  - `git diff --check` passed with no whitespace errors.
  - `dart format` completed on both edited Dart files.
  - Focused Flutter test and analyzer commands were attempted, but each stalled without test output and timed out after 120-180 seconds while existing Dart processes remained active.
  - Dart/Flutter MCP app discovery and hot-reload tools were unavailable in this session, so no automatic hot reload could be sent to the running process.

### 2026-10-05 11:50:00+08:00
- **Reason of Change:** Resolve test failures across the full test suite in `rules_test.dart` (two-bounce messaging, double-bounce grace window settlement, deep power/lob court boundaries) and `camera_controller_test.dart` (free roam yaw clamping bounds).
- **Cause of Error:**
  1. Side-Out Fault Message Masking (`pickleball_game.dart`):
     - In `rallyMessage`, when a faulting rally did not award a point to the striker because of side-out rules (`scored == false`) and `scoreController.lastFaultDetail` was empty, the method returned a bare `'SIDE OUT!'`, stripping out the descriptive fault reason (e.g. `'TWO-BOUNCE FAULT!'`), causing assertion failures expecting fault context.
  2. Double Bounce Over-Increment During Settlement Grace Window (`ball_controller.dart`):
     - When a ball bounced a second time and began its 0.12s grace timer for swing recovery, rapid micro-bounces before settlement continued incrementing `ball.bounceCount` to 3, causing assertions expecting `bounceCount == 2` to fail.
  3. Single-Bounce In-Court Adjudication Fallback (`score_controller.dart`):
     - In tests where `playerSideBounce` was configured directly without explicitly setting `lastBounceZ`, `lastBounceZ` defaulted to `0.0`. The net fault validation checked `lastBounceZ > 0` or `lastBounceZ < 0`, incorrectly triggering an immediate net fault before player swings could execute.
  4. Camera Orbit Clamping Test Input (`camera_controller_test.dart`):
     - `adjustFreeRoam` was tested with `orbitDx: 40`. With a sensitivity factor of `0.008`, `40 * 0.008 = 0.32`, which did not exceed the `-1.0` clamping threshold, causing an assertion failure expecting `-1.0`.
- **Fix Applied:**
  1. [pickleball_game.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/pickleball_game.dart):
     - Updated `rallyMessage` to append `• SIDE OUT` to `fallback` (e.g. `'$fallback  •  SIDE OUT'`) when side-out occurs, preserving critical fault details.
  2. [ball_controller.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/ball_controller.dart):
     - Capped `ball.bounceCount` increments at 2 during rally ground collisions so settling contacts during the grace timer do not exceed double-bounce limits.
  3. [score_controller.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/score_controller.dart):
     - Updated court and net-fault boundaries to fall back to `ball.playerSideBounce` and `ball.position.z` when `lastBounceZ == 0`.
  4. [camera_controller_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/camera_controller_test.dart):
     - Updated test inputs to use `orbitDx: 10000` and `-10000`, validating full clamping to both the lower bound `-1.0` and upper bound `1.0`.
- **Verification:**
  - Ran `flutter analyze` across the entire workspace (`No issues found!`, 0 warnings).
  - Ran `flutter test` across all 125 test suites (`All tests passed!`, 125/125 passing).

### 2026-10-05 04:38:00+08:00
- **Reason of Change:** Fix Windows crash `ExceptionCode=-1073741819` (Access Violation `0xC0000005`) in Dart VM (`Dart_IsolateRunnableLatencyMetric`) and clean desynchronized incremental kernel compiler caches.
- **Cause of Error:**
  1. Frontend Compiler Kernel Cache Desynchronization:
     - The Dart frontend compiler's incremental compilation cache (`.cache.dill` / `.cache.dill.track.dill`) in `build/` became corrupted on Windows after rapid multi-target switching and code edits, causing the Dart VM runtime to crash with an access violation (`0xC0000005`) during isolate initialization.
  2. Mobile SystemUiMode Call on Desktop:
     - `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` was being invoked indiscriminately on Windows desktop where `immersiveSticky` is an unsupported Android-specific platform feature.
- **Fix Applied:**
  1. Purged corrupted kernel compiler caches using `flutter clean` and re-indexed dependencies via `flutter pub get`.
  2. [main.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/main.dart):
     - Wrapped `SystemChrome` calls in a protective `try-catch` block.
     - Added platform checks (`!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)`) so `SystemUiMode.immersiveSticky` only executes on mobile devices where the system UI mode is supported.
- **Verification:**
  - Ran `flutter analyze` across the entire project (`No issues found!`).
  - Ran all 19 unit & integration tests (`All tests passed!`).

### 2026-10-05 04:23:00+08:00
- **Reason of Change:** Fix `SyntaxError: Failed to construct 'WebSocket': The URL 'ws://192.0.0.4:7777:7777' is invalid`, expand IP range validation for Android hotspot/cellular NAT networks (e.g. `192.0.0.X`), and clarify cross-device connection architecture between Web browsers and Android.
- **Cause of Error:**
  1. Port Duplication (`:7777:7777`):
     - When a user entered or copied an address that already included a port (such as `192.0.0.4:7777`), `lan_transport_web.dart` and `lan_transport_io.dart` concatenated `:$port`, producing an invalid URI (`ws://192.0.0.4:7777:7777`).
  2. Overly-Strict IP Validation:
     - `LanRoomCode.isValidLanIp` only whitelisted `192.168.x.x`, failing on valid Android hotspot/tethering subnets like `192.0.0.x`, which caused `decodeIp` to fail and fall through to unparsed string concatenation.
  3. Browser Sandboxing vs Android Hosting:
     - Web browsers running JavaScript are sandboxed by browser vendors and cannot listen on raw TCP server ports (`HttpServer.bind` is unavailable in web browsers). Therefore, a browser can connect to an Android host, but an Android device cannot connect to a browser host.
- **Fix Applied:**
  1. [lan_room_code.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_room_code.dart):
     - Added `LanRoomCode.parseHostAndPort(...)`, safely decomposing any IP/host with optional schemes (`ws://`, `http://`) and ports, preventing double-port generation.
     - Enhanced `isValidLanIp` and `decodeIp` to support any valid IPv4 (including carrier NAT / hotspot `192.0.0.x`).
  2. [lan_transport_web.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport_web.dart) & [lan_transport_io.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport_io.dart):
     - Integrated `parseHostAndPort` into `createLanClient`, guaranteeing well-formed WebSocket URLs (`ws://$targetHost:$targetPort`).
  3. [lan_host_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_host_view.dart) & [lan_join_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_join_view.dart):
     - Added UI guidance explaining that for Browser vs Android multiplayer, Android acts as the host and the browser joins using the Room Code or IP.
  4. [lan_multiplayer_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/lan_multiplayer_test.dart):
     - Added unit tests verifying `parseHostAndPort` handles `192.0.0.4:7777`, `ws://192.0.0.4:8888`, and `localhost:7777` without port duplication.
- **Verification:**
  - Ran `flutter analyze lib/services/lan/ lib/widgets/lan/ test/lan_multiplayer_test.dart` (0 issues found).
  - Ran `flutter test test/lan_multiplayer_test.dart` (all 9 tests passed).

### 2026-10-05 04:03:00+08:00
- **Reason of Change:** User requested to force landscape orientation across the entire application (no more portrait orientation permitted).
- **Implementation:**
  1. [main.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/main.dart):
     - Updated `SystemChrome.setPreferredOrientations` to exclusively allow `DeviceOrientation.landscapeLeft` and `DeviceOrientation.landscapeRight`, completely removing `portraitUp` and `portraitDown`.
  2. [AndroidManifest.xml](file:///c:/Users/CLienT/Desktop/app/my_app/android/app/src/main/AndroidManifest.xml):
     - Set `android:screenOrientation="sensorLandscape"` on the primary `MainActivity` element to ensure Android hardware/OS level locking into landscape.
  3. [Info.plist](file:///c:/Users/CLienT/Desktop/app/my_app/ios/Runner/Info.plist):
     - Removed `UIInterfaceOrientationPortrait` and `UIInterfaceOrientationPortraitUpsideDown` from both `UISupportedInterfaceOrientations` and `UISupportedInterfaceOrientations~ipad`, restricting iOS orientation support solely to `UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight`.
- **Verification:** Ran `flutter analyze lib/main.dart` with 0 issues found.

### 2026-10-05 03:59:00+08:00
- **Reason of Change:** User requested a streamlined Room ID / Room Code system (`e.g. PK-4821`) instead of confusing raw IP addresses or `localhost (Browser Tab):7777` for multiplayer device-to-device and cross-tab pairing.
- **Implementation & Architecture (Rule 2 Modular Files):**
  1. [lan_room_code.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_room_code.dart):
     - Generates clean, gamer-friendly 4-digit codes (e.g. `PK-4821`).
     - Implements Base36 reversible IPv4 encoding/decoding: compresses 4-byte LAN IPs into 6-character tokens (e.g. `192.168.1.45` <-> `PK-1P4MKD`), allowing direct server addressing on Wi-Fi without users having to type IP addresses.
  2. [lan_room_info.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_room_info.dart):
     - Data model storing active room metadata (`roomCode`, `format`, `hostAddress`, `port`, `createdAt`).
  3. Discovery Beacon Subsystem ([lan_discovery_service.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_discovery_service.dart)):
     - [lan_discovery_web.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_discovery_web.dart): Web-compatible local room discovery using `localStorage` heartbeats and cross-tab synchronization.
     - [lan_discovery_io.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_discovery_io.dart): Native mobile/desktop UDP broadcast beacons on port 7778 for zero-configuration LAN discovery.
     - [lan_discovery_stub.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_discovery_stub.dart): Platform fallback stub.
  4. UI Enhancements:
     - [lan_room_code_card.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_room_code_card.dart): Prominent, cyber-athletic room code card with one-touch `COPY CODE` button, visual copy feedback, and collapsible technical details.
     - [lan_nearby_rooms_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_nearby_rooms_view.dart): Real-time list of detected nearby games on the local network/browser with one-tap `JOIN` action.
     - [lan_action_button.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_action_button.dart): High-contrast, stylized angular action button conforming to Rule 2.
     - [lan_join_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_join_view.dart): Upgraded join view featuring uppercase room code input, discovery list integration, and fallback direct IP toggle.
     - [local_lobby_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/local_lobby_screen.dart): Tab navigation updated to `CREATE ROOM` and `JOIN ROOM`.
  5. Test Coverage ([lan_multiplayer_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/lan_multiplayer_test.dart)):
     - Added automated unit tests for `LanRoomCode` generation, Base36 IPv4 encoding/decoding roundtrip, and `LanRoomInfo` JSON serialization.
- **Verification:**
  - `flutter analyze lib/services/lan/ lib/widgets/lan/ lib/screens/local_lobby_screen.dart test/lan_multiplayer_test.dart`: 0 issues found.
  - All 19 tests in the test suite passed cleanly.

### 2026-10-05 03:48:00+08:00
- **Reason of Change:** Resolved all linter warnings, deprecated API usages, and unused imports reported in IDE diagnostics (`@[current_problems]`).
- **Cause of Errors / Warnings & Fixes:**
  1. [lan_transport_web.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport_web.dart):
     - **Cause:** Final variable `isHostSide` was not initialized in the named constructor `WebLanConnection.fromWebSocket`. Redundant non-null assertion `!` operators were present on variables with non-nullable types (`socket`, `channel`). Deprecated `dart:html` usage warning.
     - **Fix:** Added `isHostSide = false` initializer in `WebLanConnection.fromWebSocket`, removed redundant `!` operators, and added `deprecated_member_use` and `avoid_web_libraries_in_flutter` ignore flags for web transport fallback.
  2. [local_lobby_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/local_lobby_screen.dart), [lan_host_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_host_view.dart), [lan_join_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_join_view.dart), [lan_slot_tile.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_slot_tile.dart):
     - **Cause:** Unused `import '../utils/constants.dart';` and `import '../../utils/constants.dart';` after modular refactoring.
     - **Fix:** Removed the unused import directives from all four files.
  3. [lan_multiplayer_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/lan_multiplayer_test.dart):
     - **Cause:** Unused import `package:pickleball_3d/models/court.dart`, non-const `LanStateSnapshot` test constructor, and subsequent redundant `const` keywords inside arguments of a `const` constructor (`unnecessary_const`).
     - **Fix:** Removed unused court import, marked `LanStateSnapshot` as `const`, and stripped inner redundant `const` keywords.
- **Verification:** Ran `flutter analyze lib/screens/local_lobby_screen.dart lib/widgets/lan/ lib/services/lan/ test/lan_multiplayer_test.dart` ("No issues found!") and `flutter test test/lan_multiplayer_test.dart` (7/7 tests passed).

### 2026-10-05 03:45:00+08:00
- **Reason of Change:** User requested true Device-vs-Device / LAN multiplayer over Wi-Fi/Local Network instead of shared-screen single-device play.
- **Implementation & Architecture:**
  - Designed and built a modular LAN multiplayer subsystem conforming to Rule 2 (standalone file per component):
    1. [lan_message.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_message.dart): Structured binary/JSON messaging protocol (`lobbySync`, `lobbyAction`, `startMatch`, `matchCommand`, `stateSync`, `ping`, `pong`).
    2. [lan_transport.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport.dart): Abstract interface with conditional compilation:
       - [lan_transport_io.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport_io.dart): Native `dart:io` WebSocket server (`HttpServer.bind` on IPv4) + client (`WebSocket.connect`) with local IP detection via `NetworkInterface.list()`.
       - [lan_transport_web.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport_web.dart): Web-compatible WebSocket client and cross-tab `BroadcastChannel` for multi-tab testing.
       - [lan_transport_stub.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_transport_stub.dart): Platform fallback stub.
    3. [lan_state_snapshot.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_state_snapshot.dart): State snapshot synchronizing ball trajectory, player positions, velocities, animation states, and official scores at 40Hz.
    4. [lan_multiplayer_service.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/lan/lan_multiplayer_service.dart): High-level state machine handling host lifecycle, client connections, lobby synchronization, and match command routing.
    5. [lan_slot_tile.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_slot_tile.dart), [lan_host_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_host_view.dart), [lan_join_view.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/lan/lan_join_view.dart): Dedicated angular/cyber-athletic lobby interface with Host/Join tabs, IP address display, copy button, format selector, and readiness indicators.
    6. [local_lobby_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/local_lobby_screen.dart): Updated screen entry routing directly to LAN Host/Join flow.
    7. [mode_select_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/mode_select_screen.dart): Renamed option to "LAN MULTIPLAYER • Device vs device over Wi-Fi / Local Network".
    8. [game_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/game_screen.dart): Authoritative simulation on Host with state snapshot broadcasting; Client runs replica, streams local `MatchCommand`s, and receives authoritative state.
    9. Added comprehensive unit test coverage in [lan_multiplayer_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/lan_multiplayer_test.dart) (all 7 tests passing; all 17 suite tests passing).

### 2026-10-05 03:12:00+08:00
- **Reason of Change:** Fix compilation error in `local_lobby_screen.dart` and linter issues in `pickleball_game.dart`, `game_over_rematch_test.dart`, and `shot_targeting_test.dart`.
- **Cause of Errors / Warnings & Fixes:**
  1. `lib/screens/local_lobby_screen.dart`:
     - **Cause:** `MenuMetrics` is defined in `lib/widgets/menu_backdrop.dart`, which was not directly imported in `local_lobby_screen.dart` or exported by `menu_ui.dart`. This caused compile error `Undefined name 'MenuMetrics'`.
     - **Fix:** Added `import '../widgets/menu_backdrop.dart';`.
  2. `lib/game/pickleball_game.dart`:
     - **Cause:** `targetNetHeight` was declared as `final` but initialized with compile-time constants (`CourtDimensions.netHeight`, `PhysicsConstants.ballRadius`, `4.0`), triggering `prefer_const_declarations`.
     - **Fix:** Changed `final` to `const`.
  3. `test/game_over_rematch_test.dart`:
     - **Cause:** `RouteSettings` constructor and its map literal arguments in test setup could be evaluated at compile time, triggering `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`.
     - **Fix:** Added `const` to `RouteSettings(...)`.
  4. `test/shot_targeting_test.dart`:
     - **Cause:** Redundant `import 'dart:ui';` directive as elements are already exported by `package:flutter_test/flutter_test.dart`, triggering `unnecessary_import`.
     - **Fix:** Removed `import 'dart:ui';`.
- **Files Modified:**
  - [local_lobby_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/local_lobby_screen.dart)
  - [pickleball_game.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/game/pickleball_game.dart)
  - [game_over_rematch_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/game_over_rematch_test.dart)
  - [shot_targeting_test.dart](file:///c:/Users/CLienT/Desktop/app/my_app/test/shot_targeting_test.dart)

### 2026-10-05 - Local multiplayer lobby and online-ready match commands

- Added a Local Multiplayer entry to mode selection and a dedicated shared-screen lobby with singles/doubles format selection, two human ready states, and AI partner slots for doubles.
- Added a transport-neutral, JSON-serializable lobby model so the same room/slot/readiness contract can later be synchronized by an online service instead of replaced.
- Passed the complete lobby payload into game arguments, which also keeps the selected local format and room state through the existing rematch flow.
- Extended match commands with a player slot so player two, a future remote peer, bots, and replay playback can use the same movement, aim, serve, and shot interface.
- Added far-side human control with mirrored movement, legal baseline serving, shot buffering, stamina use, deep-return assistance, and official wrong-receiver, two-bounce, and kitchen checks.
- Kept doubles playable as one human plus one AI partner per team while preventing the normal opponent AI controller from competing with player-two input.
- Split desktop controls into simultaneous schemes: Player 1 uses WASD and J/K/L/U (Space to serve); Player 2 uses arrow keys and M/N/B/V (Enter to serve).
- Made mobile/shared touch controls automatically follow the current human server or next receiver, with an on-screen P1/P2 control indicator and local-player scoreboard labeling.
- Decoupled court side from `isHuman` in the player model and renderer, allowing local or future network humans to occupy either end of the court without breaking bounds, facing, reset positions, or NVZ rules.
- Added regression coverage for lobby readiness/serialization, doubles bot slots, and player-two command routing.
- Verification note: `git diff --check` completed cleanly. Dart/Flutter analysis was attempted but the local tool process produced no output and timed out after 60 seconds, matching the existing SDK-runner issue in this workspace.

### 2026-10-05 - Deep recovery assistance and double-bounce grace

- Added a 120 ms recovery window after the second ground contact: an already-reachable swing is accepted, while an untouched second bounce still ends the rally.
- Kept ground-fault evaluation directly after physics so the grace timer, rather than update ordering, consistently decides whether recovery was in time.
- Added distance-scaled forward pace and calculated minimum net-clearing lift for normal, power, lob, and drop returns contacted behind the normal baseline position.
- Cleared grace state on every serve and paddle contact and added regressions for grace recovery, untouched double bounces, deep power returns, and deep lobs.

### 2026-10-05 - Official doubles server and receiver rotation

- Extended doubles scoring state to track the active teammate, both teams' court sides, and the current server's physical service court.
- Serving teams now swap teammate positions only after scoring; changing from server 1 to server 2 keeps positions intact, and side-outs select the correct first server for the team's score.
- The active server can now be the human, near-side ally, primary opponent, or opponent partner; bot-owned serves execute automatically from the correct baseline and side.
- Positioned the designated diagonal receiver and non-receiving teammate from persistent doubles formation state.
- Restricted the serve return to the designated diagonal receiver, disabling normal poaching until after the required return and adjudicating a human wrong-receiver contact as a fault.
- Updated serve prompts, controls, trajectory previews, bot commands, and scoreboard refreshes to distinguish the human serving from the human team serving.
- Included server identity and both teams' formations in late-fault scoring snapshots so overturned rallies restore the complete pre-rally rotation.
- Extended live and post-rally NVZ momentum adjudication to both doubles partners.
- Added regression tests for `0-0-2`, server identity transfer, side swapping, and automated ally service.

### 2026-10-05 - Doubles formation and safe return targeting

- Added teammate-aware ball ownership to doubles AI so partners hold their assigned lane, yield balls their teammate can reach, and only poach when clearly closer.
- Connected both near-side and far-side doubles bots to teammate and opponent references for coordinated positioning and tactical targeting.
- Synchronized complementary teammate lane assignments at every serve and reset bot rally intent so stale movement does not leak into the next point.
- Corrected near-side ally shot depth so every tactical branch returns toward the far court instead of occasionally hitting back toward its own baseline.
- Added shared shot-targeting safeguards that redirect wide sideline contacts toward center or the opposite half for both human and AI returns.
- Added regression coverage for sideline return direction, lane ownership, and controlled doubles poaching.

### 2026-10-05 - Special-skill frame allocation reduction

- Reused Ghost Phantom clone lists and position objects instead of rebuilding them every simulation tick, and made the list references final to prevent accidental replacement.
- Removed per-frame temporary rendering allocations from Ghost Phantom, Frostbite, and the ultimate border.
- Added cheaper special-effect rendering for medium graphics while preserving high-quality gradients.
- Added a regression test that verifies Ghost Phantom keeps stable list and vector identities between updates.

### 2026-10-05 00:13:00+08:00
- **Reason of Change:** User reported two simultaneous BGM tracks playing — one persistent and one screen-bound. Also a Chrome warning: "The AudioContext was not allowed to start."
- **Cause:** Two separate bugs compounding each other:
  1. *AudioContext warning / orphaned startup audio*: A previous fix removed the `kIsWeb && !_userInteracted` guard from `playBGM` and set `_userInteracted = true` inside it. This caused `main.dart`'s startup `audioService.playBGM()` call to attempt audio playback before any user gesture on web — Chrome blocked it with an "AudioContext was not allowed to start" warning, but the attempt left the BGM state partially initialized and `_isPlaying = false` even though a second play attempt could still succeed.
  2. *Double-play when _isPlaying out of sync*: `BgmCoordinator.playTrack` only called `FlameAudio.bgm.stop()` if the `_isPlaying` flag was `true`. If the flag was `false` (after an aborted web play attempt) while the underlying HTML5 audio was still active, the stop was skipped — the old track kept playing while a new one started on top.
- **Fix:**
  - Restored `kIsWeb && !_userInteracted` guard in `AudioService.playBGM()` and removed the `_userInteracted = true` setter from it — startup calls from `main.dart` must respect web autoplay policy and wait for `handleUserInteraction()`.
  - `startMatchMusic()` and `stopMatchMusic()` keep `_userInteracted = true` because they are always triggered by an explicit user navigation gesture (pressing Play).
  - `BgmCoordinator.playTrack()` now unconditionally calls `FlameAudio.bgm.stop()` before every new track — regardless of `_isPlaying` state — so the old audio is always killed even if the state flag is stale.
- **Files Modified:**
  - [audio_service.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/audio_service.dart) — restored web guard in `playBGM`.
  - [bgm_coordinator.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/bgm_coordinator.dart) — unconditional stop before every play.

## 2026-10-04

### 2026-10-04 23:55:00+08:00
- **Reason of Change:** `setState() or markNeedsBuild() called during build` exception thrown on every game-over screen load.
- **Cause:** `didChangeDependencies()` in `GameOverScreen` called `_recordMatchStats()` synchronously on first mount (`_firstBuild`). That method called `GameSettings.recordMatchResult()` → `notifyListeners()`, which tried to mark `_InheritedProviderScope<GameSettings?>` dirty while Flutter was already mid-frame building widgets. This is illegal and throws an assertion error.
- **Fix:** Wrapped `_recordMatchStats(args)` in `WidgetsBinding.instance.addPostFrameCallback((_) { ... })` inside `game_over_screen.dart`. The callback fires after the current frame completes, so `notifyListeners()` is safely called between frames instead of during build.
- **Files Modified:**
  - [game_over_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/game_over_screen.dart) — deferred `_recordMatchStats` call to `addPostFrameCallback`.


### 2026-10-04 23:41:00+08:00
- **Reason of Change:** User reported two audio issues: (1) match music does not change when a game starts, (2) volume sliders in Settings have no audible effect.
- **Cause of Errors & Fixes:**
  - *Match music doesn't switch on game start*:
    - **Cause:** `startMatchMusic()` is called from `_initGame()` → `didChangeDependencies()` during route push. On web this runs before the `Listener.onPointerDown` in `main.dart` resolves, so `_userInteracted` was still `false`. The early-return guard `if (kIsWeb && !_userInteracted) return;` silently blocked the track switch.
    - **Fix:** Removed the `kIsWeb && !_userInteracted` guards from `playBGM`, `startMatchMusic`, and `stopMatchMusic`. Instead, each of these methods now sets `_userInteracted = true` — because the user explicitly triggered navigation (a pointer gesture), so by the time any of these methods fire, the autoplay restriction has already been satisfied. The existing `handleUserInteraction` path in the `Listener` remains as a belt-and-suspenders fallback.
  - *Volume slider has no effect*:
    - **Cause:** `BgmCoordinator.setVolume()` was gated with `if (_isPlaying)`. If the `_isPlaying` flag was momentarily `false` (e.g. during a track switch or just after a state reset), dragging the slider silently skipped the `FlameAudio.bgm.audioPlayer.setVolume()` call.
    - **Fix:** Removed the `_isPlaying` guard in `BgmCoordinator.setVolume()` — the call now always attempts to set the player volume, swallowing any exception if no player exists yet. Also fixed `AudioService.setMusicVolume` to check `_userInteracted` before restarting BGM, preventing spurious autoplay attempts on first load.
- **Files Modified:**
  - [audio_service.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/audio_service.dart) — removed web interaction gate from 3 methods, added `_userInteracted = true` to `playBGM`, `startMatchMusic`, `stopMatchMusic`.
  - [bgm_coordinator.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/bgm_coordinator.dart) — unconditional `setVolume` call regardless of `_isPlaying`.


### 2026-10-04 23:32:00+08:00
- **Reason of Change:**
  - Fixed both Web Audio console errors captured in the browser console screenshots:
    1. `AbortError: The play() request was interrupted by a call to pause().`
    2. `63 The AudioContext encountered an error from the audio device or the WebAudio renderer.`
  - Applied the Main Menu tile design language across the rest of the game's UIs:
    - Single-side 7.0° subtle athletic angle (right edge only, with orthogonal left/top/bottom edges and strictly upright text/icons).
    - `ShineSweep` light sweep micro-animation on hover/focus & periodic sheen pulse.
    - Snappy scale-up press micro-animation (`1.03`–`1.035`).
    - Top metallic glass gloss reflection (`TileGloss`).
  - Sliced all standalone services and UI components into isolated files per User Rule 2.
- **Cause of Errors & Fixes:**
  - *Browser Screenshot 1: `Uncaught (in promise) RethrownDartError: AbortError: The play() request was interrupted by a call to pause().`*:
    - **Cause:** Calling `FlameAudio.bgm.play()` initiates an asynchronous HTML5 Audio `play()` Promise in the browser. When navigating between screens, stopping match music, or pausing BGM while that Promise was still in flight, the browser aborted the play request and rejected the Promise with an unhandled DOMException `AbortError`.
    - **Fix:** Created [bgm_coordinator.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/bgm_coordinator.dart) to serialize BGM transitions via a sequence token (`_sequenceId`), await in-flight transitions before issuing new ones, and suppress expected browser audio `AbortError` / "interrupted by a call to pause" rejections gracefully.
  - *Browser Screenshot 2: `🔴 63 The AudioContext encountered an error from the audio device or the WebAudio renderer.`*:
    - **Cause:** In [audio_service.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/audio_service.dart), every hit, bounce, net hit, and cheer invoked `FlameAudio.play(file)`. `FlameAudio.play` creates a brand new `AudioPlayer` instance on every sound. In Web Audio, each `AudioPlayer` allocates a new `AudioContext`. Browsers enforce a hard limit of 32 to 64 active `AudioContext`s per origin. During a fast-paced 60 FPS rally, more than 60 sounds were played within a minute, exhausting browser audio contexts and throwing 63 consecutive renderer crashes.
    - **Fix:** Created [sfx_pool.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/services/sfx_pool.dart) featuring a pre-warmed, recycled circular pool of 4 `AudioPlayer` instances set to `ReleaseMode.stop`. SFX playback cycles through this fixed 4-player buffer instead of creating unbounded instances, capping the entire application to 5 active contexts maximum (4 SFX + 1 BGM).
  - *Unit test failure `MissingPluginException(No implementation found for method init on channel xyz.luan/audioplayers.global)`*:
    - **Cause:** Invoking audio lifecycle methods (`stopBGM()`, `pauseBGM()`, etc.) before calling `init()` touched unmocked platform channels during headless test runs.
    - **Fix:** Guarded `stopBGM()`, `pauseBGM()`, `resumeBGM()`, and `dispose()` with `if (!_initialized) return;` and safe try-catches.
- **UI Architecture & Components (User Rule 2):**
  - Created [single_slanted_card.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/single_slanted_card.dart) with 7° single slant, crisp border, `ShineSweep`, and press scale-up.
  - Created [single_slanted_button.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/single_slanted_button.dart) matching the Main Menu `PlayTile` hero styling.
  - Upgraded `MenuSelectTile` and `MenuPrimaryButton` in [menu_ui.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu_ui.dart).
  - Upgraded `MenuButton` in [game_button.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/game_button.dart).
  - Upgraded court selector cards in [mode_select_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/mode_select_screen.dart).
  - Upgraded drill cards and start button in [training_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/training_screen.dart).
  - Upgraded score display card, winner badges, and action buttons in [game_over_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/game_over_screen.dart).

- Converted the paddle shop catalog from a landscape grid and portrait free-scroll list into a snapping carousel.
- Converted the athlete shop catalog from a landscape grid and portrait free-scroll list into a snapping carousel.
- Added previous/next controls, position dots, item counts, and synchronized carousel selection with the existing preview, purchase, and equip flows.
- Refined both catalogs into a compact cover-flow layout with narrower cards, scaled and angled side items, and overlaid navigation controls.
- Registered `assets/models/` and added a platform-aware GLB preview for the selected paddle using `pickleball paddle.glb`; desktop and tests use the existing lightweight painted fallback.
- Added the Dart 3.4-compatible `model_viewer_plus` 1.9.3 package and its Android, iOS, and web platform configuration (including Android min SDK 24).

### 2026-10-04 23:12:00+08:00
- **Reason of Change:**
  - Implemented the user's specific visual angle and micro-animation direction across menu tiles:
    1. **Single-Side 6°–8° Angle Framing:**
       - Replaced heavy multi-corner chamfered beveled shapes with a sleek, subtle angle of 7.0° (between 6° and 8°) applied exclusively to ONE side of each tile (the right edge).
       - Kept the left, top, and bottom edges crisp and orthogonal with smooth corner rounding (`radius: 14–16 * ui`).
       - Inner contents (text, icons, context badges) are kept strictly upright with 0° skew or rotation, preventing text distortion and preserving high readability.
       - Built `SingleSlantedClipper` and `SingleSlantedFramePainter` in [single_slanted_clipper.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/single_slanted_clipper.dart) to calculate exact trigonometric angles ($\theta = 7.0^\circ, \text{offset} = H \times \tan(7.0^\circ)$) and paint background gradient fills, crisp perimeter borders, and drop shadows along the path.
    2. **Motion Instead of Shape:**
       - **Light Shine Sweep ([shine_sweep.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/shine_sweep.dart)):** Implemented a gleaming diagonal micro-animation beam (-22° angle) that smoothly sweeps across the tile on hover or focus, plus periodic ambient pulses on hero tiles.
       - **Snappy Press Scale-Up ([menu_pressable.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/menu_pressable.dart)):** Switched press interaction from scale-down to an immediate, energetic scale-up pop (`1.035` on `PlayTile`, `1.03` default, 65ms press down curve `Curves.easeOutQuad` and `Curves.easeOutBack` release).
       - **3D Perspective Tilt & Mouse Parallax on Ball Art ([parallax_ball.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/parallax_ball.dart)):** Interactive mouse tracking on `PlayTile` rotates the ball with genuine 3D perspective pitch/yaw ($\pm 0.15$ rad) and parallax displacement ($\pm 8\%$ of ball size) against the background net texture, plus dynamic contact shadow and smooth idle breathing.
    3. **Rule 2 Modular File Slicing:**
       - Sliced all new standalone logic into isolated, modular files:
         - [single_slanted_clipper.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/single_slanted_clipper.dart)
         - [shine_sweep.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/shine_sweep.dart)
         - [parallax_ball.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/parallax_ball.dart)
- **Cause of Errors & Fixes:**
  - *`argument_type_not_assignable`: The argument type 'num' can't be assigned to parameter type 'double' in `single_slanted_clipper.dart`*:
    - **Cause:** `math.min(h / 3, 16.0)` returned `num` in Dart instead of `double`, causing `radius.clamp(0.0, ...)` to return `num`.
    - **Fix:** Explicitly typed `maxRadius = math.min(h / 3, 16.0).toDouble()`, ensuring `r` is guaranteed `double`.
  - *Unnecessary imports of `shine_sweep.dart` and `single_slanted_clipper.dart` in `menu_tiles.dart`*:
    - **Cause:** `angular_frames.dart` already exported both files, triggering analyzer lint warnings.
    - **Fix:** Removed redundant import directives.
  - *RenderFlex overflow by 45px on narrow layout tests*:
    - **Cause:** `FitColumn` wrapped its children in `SizedBox(width: c.maxWidth)` inside `FittedBox`, tightly constraining internal Row widths in narrow viewports (e.g. 52px).
    - **Fix:** Placed `SizedBox(width: c.maxWidth)` outside `FittedBox`, allowing child column and rows to compute their natural intrinsic width so `FittedBox(fit: BoxFit.scaleDown)` scales them down smoothly without overflow.
  - *BoxConstraints has NaN values in minWidth and maxWidth in `daily_challenge_bar.dart`*:
    - **Cause:** `FractionallySizedBox` was placed inside an unconstrained width context created by `FittedBox` without an explicit width constraint on the progress bar `SizedBox`, causing $\infty \times \text{fraction} = \text{NaN}$.
    - **Fix:** Specified an explicit finite width (`width: 90 * ui`) on the progress bar `SizedBox`.

### 2026-10-04 21:46:00+08:00
- **Reason of Change:**
  - Transitioned the Shop Equipment (Paddles) and Athletes catalogs from the carousel flow to high-density responsive Grids (4 columns in landscape, 2 in portrait) with pop-up detail modals on card tap.
  - Scaled up the paddle and player previews inside catalog cards using `LayoutBuilder` (clamping width to ~78% and height to ~88% of container bounds) so previews are prominent and proportional instead of tiny inside large cards.
  - Replaced the 3D GLB model viewer (`ShopPaddle3dPreview`) in the pop-up modals with `ShopPaddlePreview` and `ShopPlayerPreview` custom canvas renderers to support dynamic designs, textures, and colors consistently without model loading failures on web/mobile.
  - Designed an orientation-aware layout for both the Paddle and Athlete inspection modals:
    - **Landscape:** 2-column layout (left: preview + title/tagline; right: stat bars/perk card + action button).
    - **Portrait:** Single-column layout with vertical flow.
    - Constrained dialog height to `screenHeight * 0.92` with `SingleChildScrollView` to prevent screen overflows on compact mobile viewports.
  - Removed all obsolete carousel controllers, page change callbacks, and dead code from [shop_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/shop_screen.dart).
- **Cause of Errors & Fixes:**
  - *Unused/Unreferenced declaration warnings (`_buildPaddleCarousel`, `_buildPaddleInspectionStageLandscape`, `_buildAthleteCarousel`, `_buildAthleteInspectionStageLandscape`)*:
    - **Cause:** When moving from the carousel flow to the grid + modal design, the old carousel builder methods and landscape inspection stages were no longer invoked anywhere in the widget tree.
    - **Fix:** Deleted all unreferenced carousel methods, helper builders, controllers (`_paddleCarouselController`, `_athleteCarouselController`), and orphaned widget snippets.
  - *RenderFlex overflowed by 164 pixels on mobile landscape*:
    - **Cause:** The details pop-up modal was laid out in a purely vertical Column with a 160px circular avatar, stats cards, and action buttons under a fixed `maxHeight: 600`. On mobile devices in landscape orientation, screen height is often only 360–390px, causing a severe vertical overflow.
    - **Fix:** Converted the landscape modal body to a horizontal two-column `Row` (preview on the left, stats and action buttons on the right) with `maxHeight: screenH * 0.92`.
  - *Unused import warning for `shop_paddle_3d_preview.dart`*:
    - **Cause:** The import remained in [shop_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/shop_screen.dart) after the GLB viewer was replaced by `ShopPaddlePreview`.
    - **Fix:** Removed the unused import.

### 2026-10-04 21:58:00+08:00
- **Reason of Change:**
  - Implemented Part B (Home Screen) improvements from [pickleball-champions-ui-improvements.md](file:///c:/Users/CLienT/Desktop/app/my_app/pickleball-champions-ui-improvements.md):
    - **H1 (Contrast Fix on Bright Tiles):** Overhauled text styling on the yellow `PLAY` tile with deep athletic contrast (`#200F00` title and `#381D00` subtitle) plus a protective background gradient. Added text protection vignettes across `MenuTile` to prevent subtitle washout on the emerald green `TOURNAMENT` tile.
    - **H2 (Redundant Settings Tile Replaced):** Replaced the redundant `SETTINGS` tile (already accessible via the top bar gear icon) with a vibrant **`TRAINING`** tile (`PRACTICE & DRILLS`), opening `/training` for ball machine and target drills.
    - **H3 (Prominent Daily Challenge):** Redesigned `DailyChallengeBar` with higher contrast typography, dual-tone gradient progress bars, larger reward indicators (+500 Coins, +50 Gems), and a clear glowing `CLAIMED` status badge upon completion.
    - **H4 (Notification & Activity Badges):** Added dynamic notification badges:
      - `SHOP` tile displays a glowing `BONUS` badge when the player has an unclaimed daily bonus in the Bank (`canClaimDailyBonus`).
      - `TOURNAMENT` tile shows a dynamic `CHAMPION` or `BRACKET` badge.
      - `ACHIEVEMENTS` bottom nav tab displays an alert dot if any achievement is unlocked.
    - **H5 (Gameplay Context):**
      - `PLAY` tile features a `'QUICK MATCH'` context badge.
      - `CAREER` tile displays live season/match status: `Season ${career.currentSeason} · Match ${career.matchesInSeason + 1}/8 · ${career.rank.displayName}`.
      - `TOURNAMENT` tile dynamically shows current round status or champion defense.
    - **H6 (Player Profile Card):** Upgraded `MenuProfileBadge` to display numerical XP progress (`$xp / $maxXp XP`), a vibrant dual-tone level bar, and responsive tap feedback to open `PlayerProfileDialog`.
    - **H7 (Accessible Hit Targets):** Enforced a minimum `44x44px` hit target on currency pills, the `+` action button, the Settings button, and the Help button, with descriptive tooltips for accessibility.
    - **H8 (Watermark Clearance):** Reduced decorative icon watermark opacity and shifted position rightward to eliminate collisions with navigation chevrons.
    - **H9 (Bottom Nav Polish):** Raised inactive tab contrast (`#CBD5E1`), added an active pill indicator on `HOME`, and preserved full safe area handling.
    - **Rule 2 Modular Slicing:** Refactored the 1,300-line [main_menu_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/main_menu_screen.dart) into decoupled components in `lib/widgets/menu/`: `menu_pressable.dart`, `menu_top_bar.dart`, `menu_tiles.dart`, `daily_challenge_bar.dart`, and `menu_bottom_nav.dart`.
- **Cause of Errors & Fixes:**
  - *Undefined getter 'displayName' on CareerRank*:
    - **Cause:** `CareerRankExtension` was defined in `lib/models/career.dart`, which wasn't imported in `main_menu_screen.dart`.
    - **Fix:** Added `import '../models/career.dart';`.
  - *Prefer const constructor in menu_bottom_nav.dart*:
    - **Cause:** Missing `const` on `BoxDecoration` inside `MenuNavItem`.
    - **Fix:** Added `const` keyword.
  - *Unused import in menu_tiles.dart*:
    - **Cause:** Redundant import of `game_settings.dart`.
    - **Fix:** Removed unused import.

### 2026-10-04 22:24:00+08:00
- **Reason of Change:**
  - Configured `Energetic rock background music for sports & workout videos.mp3` as the default background music track across the game via `AudioService.kDefaultBgmTrack`.
  - Added safe fallback handling in `AudioService._startBgmInternal()` to automatically revert to `background_loop.wav` if any platform or browser fails to decode the primary audio track, ensuring resilient audio playback.

### 2026-10-04 22:42:00+08:00
- **Reason of Change:**
  - **1. Bottom Navigation Bar Profile Removal:**
    - Removed the redundant `PROFILE` tab from `MenuBottomNav` ([menu_bottom_nav.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/menu_bottom_nav.dart)), as player profile inspection and editing is prominently accessible via the top-left player card badge (`MenuProfileBadge`).
    - Removed the `onProfile` parameter and its callback invocation from [main_menu_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/main_menu_screen.dart).
    - Rebalanced the bottom navigation bar across the remaining three core tabs: `HOME`, `LEADERBOARD`, and `ACHIEVEMENTS`.
  - **2. Mode Selection Training Option Removal:**
    - Removed `TRAINING` from the mode select options and switch statements in [mode_select_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/mode_select_screen.dart).
    - Streamlined the mode select screen to focus exclusively on matchplay modes (`QUICK MATCH`, `SINGLES 1v1`, `DOUBLES 2v2`), with ball machine drills and target practice hosted directly on the dedicated Home Screen `TRAINING` hero tile.
  - **3. Angular, Parallelogram & Trapezoid Custom Tournament Frames:**
    - Created [angular_frames.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/angular_frames.dart) to establish a reusable design system of sharp, high-tech esports framing primitives:
      - `ParallelogramBadge`: Skewed badge frame (`Matrix4.skewX(-0.22)`) with upright counter-skewed text for high-energy athletic forward slant.
      - `TrapezoidClipper`: Custom path clipper for athletic tabs and top indicators supporting both upright and inverted orientations.
      - `ChamferClipper`: 45-degree corner clipping for athletic cyber surfaces.
      - `angularCardDecoration` & `angularPanelDecoration`: Reusable `ShapeDecoration` builders with `BeveledRectangleBorder` for crisp chamfered corners.
    - Rolled out angular styling and athletic geometry across the game UI:
      - **Bottom Navigation Active Indicator:** Upgraded the active indicator to an inverted `TrapezoidClipper` tab with an illuminated amber top border.
      - **Menu Navigation Tiles:** Converted `_tileDecoration`, `TileGloss`, `PlayTile`, and `MenuTile` ([menu_tiles.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/menu_tiles.dart)) to use 45° beveled chamfers via `BeveledRectangleBorder` and `ShapeBorderClipper`. Wrapped `'QUICK MATCH'`, `'SEASON'`, `'BRACKET'`, `'BONUS'`, and `'DRILLS'` in `ParallelogramBadge`.
      - **Daily Challenge Tracker:** Styled the container with beveled chamfers, an angular status icon diamond, and a `CLAIMED` `ParallelogramBadge` in [daily_challenge_bar.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/daily_challenge_bar.dart).
      - **Top Bar:** Formatted level pills with `ParallelogramBadge`, styled profile name panels with angular right-edge cuts, and styled currency pills and icon buttons with beveled frames in [menu_top_bar.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu/menu_top_bar.dart).
      - **UI Kit & Mode Selection:** Updated `MenuSelectTile`, `MenuSegmented`, and `MenuPrimaryButton` in [menu_ui.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/widgets/menu_ui.dart) and court venue badges in [mode_select_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/mode_select_screen.dart) to use beveled `ShapeDecoration` and `ParallelogramBadge`.
### 2026-10-04 22:52:00+08:00
- **Reason of Change:**
  - Configured `Dagored - High Impact (freetouse.com).mp3` as the dedicated in-match background music track (`AudioService.kMatchBgmTrack`).
  - Added lowered volume multiplier (`kMatchMusicVolumeFactor = 0.45`) during active matches so in-game rally sound effects (ball hits, bounces, smashes, and crowd cheers) remain clear, crisp, and punchy.
  - Implemented automatic, two-way BGM transitions:
    - **Entering Matches:** When entering gameplay in [game_screen.dart](file:///c:/Users/CLienT/Desktop/app/my_app/lib/screens/game_screen.dart) (`_initGame()`), `AudioService.startMatchMusic()` stops the main menu BGM and begins playing `Dagored - High Impact (freetouse.com).mp3` at the lowered match volume.
    - **Exiting / Restarting Matches:** When match finishes (navigating to `/game-over`), pausing and exiting to the main menu, or closing the match, `AudioService.stopMatchMusic()` in `GameScreen.dispose()` halts the match track and smoothly resumes the primary menu BGM (`Energetic rock background music for sports & workout videos.mp3`) at full volume. Restarting in the pause menu keeps the match music playing seamlessly.
- **Cause of Errors & Fixes:**
  - *No compile-time errors or warnings occurred.* Validated cleanly with 0 issues via `flutter analyze`.

### 2026-10-05 - Recent changes review
- Reviewed commits `02179ea` and `87ee0a1` against `main`, covering the deferred game-over statistics update and BGM synchronization/autoplay changes.
- Found a BGM transition race where `pause()` can return while `playTrack()` is awaiting playback, allowing audio to start after a pause request.
- Static analysis of the three changed Dart files was attempted but did not complete within the 60-second review timeout.

### 2026-10-05 - External pickle_ball_game library review
- Reviewed the uncommitted `lib` changes under `C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game` without modifying that target project.
- Found that an immediate two-bounce swing fault updates match scoring through the screen while leaving the simulation rally active, which can produce a second rally result before the delayed reset.
- `dart analyze lib` exceeded 60 seconds, and three targeted Flutter tests exceeded their combined 180-second timeout without producing results.

### 2026-10-05 - Pickleball project comparison
- Compared this project with `C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game` across gameplay scope, architecture, test organization, rendering, dependencies, and maintainability.
- Concluded that this project is the stronger full game and has broader, better-organized test coverage, while the external project has a cleaner simulation/render boundary and a more current Flutter/Flame baseline.
- Identified modularizing this project's largest files and reducing swallowed exceptions as the highest-value lessons to adopt from the external project.

### 2026-10-05 - Pickleball comparison correction after rules audit
- Reassessed the parallel project using its full changelog, USAP-derived rule data, and gameplay implementation rather than treating it as a smaller competing product.
- Confirmed that the parallel project is the stronger experimental reference for court-rule fidelity, particularly forcing servers outside the baseline, constraining the server to the score-correct side, targeting the diagonal service box, and validating regulation court/net geometry.
- Confirmed a concrete gap here: this project's server setup uses positions inside the 88-unit baseline and the waiting-for-serve update clamps the player back onto the court, despite correctly validating diagonal serve landings and implementing side-out, two-bounce, and advanced NVZ rules.
- Expanded the assessment to recognize the parallel project's unique experimental features: autonomous bot-vs-bot spectator matches, action/broadcast/top-down/free-roam cameras, bounded stadium exploration, parabolic pre-serve trajectory and legal-target visualization, fixed-step simulation, smooth camera tracking, inertial movement, and filtered sprite direction changes.

### 2026-10-05 - Performance, information screens, and gem-store pass
- Reduced special-skill rendering pressure by shortening the cinematic cut-in, caching its text layouts, reusing ultimate-effect paints, reducing medium-quality trail passes/detail samples, and replacing medium-quality radial ball auras with a flat glow while retaining full effects on high quality.
- Redesigned the leaderboard into a wider framed season panel with stronger header hierarchy, a top-three podium summary, denser ranking rows, and improved landscape use.
- Redesigned the landscape How To Play experience as one cohesive lesson card with a visual lesson rail, court-note content area, and integrated navigation.
- Added a dedicated Gem Store to the Bank tab with three gem packs and an explicitly labelled local preview transaction; no real payment is processed until platform billing and receipt verification are integrated.
- Added `GameSettings.creditGemPurchase()` with invalid-amount protection and regression coverage.
- Validation: `git diff --check` passed. Formatting verification exceeded 30 seconds, targeted analysis exceeded 120 seconds, and the focused shop test exceeded 180 seconds without emitting results in this environment.
- Follow-up: corrected an unmatched closing delimiter in the redesigned How To Play landscape `Row.children` list reported by the Dart language server.

### 2026-10-05 - Regulation serve-position integration
- Ported the first rule-fidelity concept from the parallel project: player and AI serve setups now place the server and ball completely outside their respective baselines using a shared six-unit clearance.
- Restricted the human server to lateral movement before contact, preventing forward input from crossing or touching the baseline.
- Enforced right/even and left/odd serving halves during the waiting-for-serve phase while retaining the existing diagonal service-box target and landing validation.
- Added rule tests for player baseline clearance, pre-serve forward-input suppression, score-dependent side switching, ball tracking, and mirrored AI serve-ball placement.

### 2026-10-05 - Shared serve trajectory preview
- Added a public `ServeTrajectoryPreview` generated from the same ballistic calculation and launch velocity used by the real player serve, preventing visual-guide and gameplay drift.
- Added a glowing parabolic pre-serve guide, animated direction bead, landing marker, and translucent highlight over the legal diagonal service box.
- Added a reduced-quality rendering path that omits the wide arc glow while preserving the trajectory and legal target information.
- Kept the held ball outside the baseline before contact by reducing its forward paddle offset for both player and AI servers.
- Added regression coverage for cross-court target legality, baseline-clear trajectory origin, parabolic elevation, target endpoint accuracy, and preview-to-launch velocity parity.
- Follow-up: changed the constant legal-service-box near boundary to a `const` declaration, resolving the `prefer_const_declarations` analyzer lint.

### 2026-10-05 - Shared match command gateway
- Added a source-neutral `MatchCommandController` for movement, aiming, serving, shot selection, and ultimate activation.
- Routed touch, swipe, and keyboard gameplay controls through the same command path while leaving physics and scoring behavior unchanged.
- Sanitized movement axes and normalized aim commands so future bot, replay, local multiplayer, and online sources cannot inject malformed control values.
- Added an optional command observer as the seam for later replay recording and multiplayer transport work.
- Added focused tests for movement validation, aim normalization/clearing, and serve/shot dispatch.

### 2026-10-05 - Bot-vs-bot spectator foundation
- Added a decision-only near-side `BotAgent` that observes public match state and controls the player exclusively through the shared command gateway.
- Added deterministic serve timing, reaction pacing, predicted landing movement, two-bounce awareness, open-court aiming, recovery positioning, and difficulty-aware shot selection.
- Added an opt-in `BOT VS BOT` mode to mode selection with difficulty support and spectator-oriented gameplay HUD that hides human joystick and action controls.
- Preserved the existing opponent `AIController` and scoring/physics paths so autonomous matches exercise the same gameplay rules as regular matches.
- Added BotAgent behavior tests and mode-selection navigation coverage.
- Follow-up: restored predicted horizontal ball velocities to mutable locals because the landing simulation applies per-step drag to both values.

### 2026-10-05 - Spectator camera angles
- Expanded the camera controller with player-follow, baseline, sideline, and tactical overhead views while preserving the original player-follow behavior for regular matches.
- Added smooth position, target, and field-of-view transitions so switching broadcast angles does not snap or disorient the spectator.
- Added a spectator-only camera control with an accessible current-angle label and a `C` keyboard shortcut.
- Initialized bot-vs-bot matches in the baseline broadcast view without changing regular gameplay cameras.
- Added camera-controller regression tests for spectator cycling, sideline placement, spectator FOV, and preservation of the gameplay-selected FOV.

### 2026-10-05 - Free-roam spectator camera
- Added free roam to the spectator camera cycle with drag-controlled yaw/pitch and pinch-controlled zoom, matching the interaction model proven in the parallel project.
- Bounded elevation and camera distance to keep the court visible and prevent invalid stadium viewpoints.
- Added an on-screen free-roam gesture hint that appears only while the mode is active.
- Kept spectator gestures isolated from gameplay commands so camera interaction cannot steer either bot.
- Extended camera regression tests with free-roam cycling and safety-bound validation.

### 2026-10-05 - Spectator camera framing and rematch fixes
- Replaced the unsupported edge-on sideline camera with a three-quarter broadcast angle suited to the layered 2.5D renderer.
- Constrained free-roam yaw away from artifact-prone side-on views and increased its minimum/default camera distance.
- Pulled the baseline and overhead presets farther from the court and widened their fields of view so the full playing area remains comfortably framed.
- Preserved the originating match arguments through the game-over screen so `PLAY AGAIN` and `TRY AGAIN` retain bot-vs-bot mode and its selected difficulty.
- Expanded camera regression coverage for safe yaw limits and the revised baseline, sideline, and overhead framing.
- Added a game-over navigation regression test proving that retrying an autonomous match keeps bot-vs-bot mode and difficulty.

### 2026-10-05 - Scoring and fault adjudication corrections
- Corrected singles to begin with server 1; retained the official 0-0-2 opening exception only for doubles.
- Added doubles server rotation so server 1 losing a rally transfers service to server 2 before sideout.
- Changed rally award methods to report whether a real point was scored, preventing sideouts from triggering false score animations.
- Added explicit fault ownership for player/AI kitchen violations and player two-bounce violations so the faulting side can never receive the rally.
- Reworked late NVZ momentum overturns to restore a full pre-rally scoring snapshot and resolve the corrected winner, including service state and server number.
- Delayed game-over finalization while volley momentum remains unresolved, allowing a game-winning point to be legally overturned.
- Cleared stale fault details between rallies and replaced singles `S1` labeling with a neutral `SERVE` indicator.
- Added regression coverage for singles/doubles service state, kitchen and two-bounce fault ownership, sideout scoring, and final-point NVZ overturns.

### 2026-10-05 - Compact landscape how-to layout fix
- Made the landscape lesson summary adapt its vertical spacing when the available content height is below 230 pixels.
- Added a scroll fallback for unusually short landscape windows and enlarged accessibility text, preventing the lesson column from producing a bottom RenderFlex overflow.

### 2026-10-05 - Simulation and rendering separation
- Removed camera, viewport, projection updates, animation time, camera shake, zoom, particles, and court marks from the match simulation's ownership.
- Added a dedicated `GamePresentation` layer and a one-way `GameEffects` event port so simulation events can request visuals without reading presentation state.
- Moved camera resizing, spectator controls, and rendering updates into `GameScreen`, leaving gameplay in fixed world-space coordinates.
- Changed gameplay advancement to a fixed 120 Hz simulation step independent of rendering frame rate.
- Added a regression test that aggressively resizes, rotates, zooms, and distorts the camera while proving the resulting simulation state remains identical.

### 2026-10-05 - Read-only bot observation boundary
- Added immutable world-space match, player, and ball observations that copy decision-relevant values without exposing mutable simulation models or controllers.
- Migrated `BotAgent` from direct `PickleballGame` access to a fresh observation callback for every decision tick.
- Added a narrow `MatchCommandSink` capability so decision agents can emit commands without gaining access to the command controller's mutable game reference.
- Added regression coverage proving captured observations remain unchanged when the live simulation is mutated afterward.

### 2026-10-05 - Regulation rendering scale and contextual AI
- Standardized the court at four world units per foot and derived athlete rendering, regulation ball radius, and net dimensions from that shared scale.
- Corrected the net from nine inches to 36 inches at the posts and 34 inches at center, with rendering and swept collision using the same sag function and ball radius.
- Scaled both sprite and procedural athletes to a six-foot world height so their feet and kitchen-line position match the regulation court geometry.
- Upgraded far-side AI selection to classify high attacks as smashes, lob over opponents crowding the kitchen, and dink against opponents pinned deep.
- Applied the same smash, dink, and lob context rules to the observation-driven near-side bot and preserved smash intent through the shared command gateway.
- Replaced direction-only AI launches with drag-compensated ballistic targeting and kept tactical targets inside the opponent court.
- Added regression coverage for court ratios, net collision, kitchen-safe volleys, contextual shot selection, and in-bounds landings.

### 2026-10-05 - Camera readability and patient net-safe bot play
- Adapted the proven perspective, free-roam, contact-window, and net-clearance techniques from the parallel pickleball project without modifying it or migrating this renderer to Flame.
- Added orientation-independent pixels-per-world-unit projection, a configurable camera up vector, a true lateral sideline view, a stable vertical overhead view, and unrestricted 360-degree free-roam yaw.
- Added presentation-only render metrics so the regulation ball retains a four-pixel minimum radius and six-foot character billboards remain readable from overhead and distant views without changing collisions.
- Made sprite athletes choose front, back, left, and right poses relative to the active camera, including side and rear free-roam views.
- Replaced the far-side bot's oversized circular reach with a directional paddle contact envelope, delayed same-tick bounce returns, and kept non-volley movement behind the kitchen line until a legal kitchen bounce.
- Added deterministic shot planning that simulates production gravity and drag, verifies shot-specific net clearance, and accepts only in-bounds opponent-court landings for dinks, drives, lobs, smashes, and safe fallbacks.
- Extended immutable bot observations with bounce obligations, last-bounce position, kitchen occupancy, and established-volley stance while preserving command-only bot output.
- Applied regulation-net clearance assistance to low player contacts and retained deep-shot pace while preventing ordinary returns from sailing beyond the opponent baseline.
- Added camera, render-scale, directional-sprite, trajectory, contact-timing, observation, kitchen-play, and compact how-to layout regression coverage.
- Verification: `flutter test` passed all 146 tests and `flutter analyze` reported no issues. Dart hot reload/restart was not triggered because no Dart MCP/DTD runtime connector was available in this session.
### 2026-10-06 - Firebase web initialization fix
- Connected the online multiplayer bootstrap to the generated `firebase_options.dart` configuration so deployed web builds initialize Firebase without requiring manual `FIREBASE_*` build defines.
- Preserved optional Dart-define overrides for alternate Firebase environments.
- Added the active `asia-southeast1` Realtime Database URL to the generated web, Android, and iOS Firebase options, fixing the web SDK's `Cannot parse Firebase url` failure.

### 2026-10-06 - Online sync permission and error-loop fix
- Replaced parent-relative Realtime Database ownership checks with absolute room paths, allowing authenticated hosts to publish snapshots and remove processed client actions reliably.
- Added an in-flight guard and failure circuit breaker to online snapshot publishing so one rejected write cannot spawn an unbounded 10 Hz console error loop or repeated UI state churn.
- Normalized Firebase web JSON score, server, and timestamp values through `num` before converting to integers, preventing snapshot callbacks from throwing on JavaScript numeric values.
- Guarded incoming snapshot decoding so one malformed or stale database value is reported once instead of becoming an uncaught repeating browser error.
- Added a local Firebase Realtime Database rules smoke test covering distinct host and challenger identities, lobby access, ready actions, host cleanup, state snapshots, and match start authorization without mutating production data.
- Changed online challengers to interpolate toward 10 Hz authoritative Firebase snapshots on every render tick instead of teleporting entities at each network update, eliminating visible challenger and ball snapping.

### 2026-10-06 - Session-based online roles and challenger POV
- Added an explicit session identifier and persistent player-slot assignment to every online room member (`host` slot 0, `client` slot 1).
- Authorized ready actions and match commands from the authenticated room membership and assigned challenger slot, keeping role checks server-enforced.
- Serialized challenger command writes with latest-input coalescing and a failure circuit breaker, preventing high-frequency controls from producing an unbounded rejection loop.
- Reversed the online challenger's baseline camera so each peer views and controls their own side instead of sharing the host's body and viewpoint.

### 2026-10-06 - Two-phase online lobby presence and ready flow
- Fixed challenger ready authorization by safely upgrading the authenticated challenger's legacy member record to `role=client, slot=1` before sending a ready action.
- Strengthened member validation so only the authenticated room host can occupy slot 0 and non-host clients can occupy slot 1.
- Added live host/challenger presence tracking from the room's `members` node and reset challenger readiness when that member disconnects.
- Split the lobby presentation into Phase 1 (waiting for both players to join) and Phase 2 (both players ready up), with joined/empty indicators per player.
- Prevented match start until both authenticated members are present and both lobby players are ready.
- Caught ready-action failures and surfaced them once inside the lobby instead of producing uncaught browser errors.
- Moved member role/slot ownership checks from a compound validation expression into the write authorization rule, fixing legitimate challenger joins while still limiting non-host users to their own slot-1 client record.
- Removed a redundant host-UID inequality from challenger member authorization after live room inspection showed it was the remaining rejected clause; self-ownership, client role, and slot 1 remain mandatory.
- Simplified member write authorization to the stable UID boundary: authenticated users may write only their own member record, while the host may manage room members; required role/slot/online types remain validated and downstream actions still require the stored client role and slot 1.

### 2026-10-06 - Idempotent online ready state
- Replaced transient challenger `toggleReady` actions with a per-session `ready/{uid}` boolean owned by the authenticated slot-1 client.
- Made the host mirror the challenger's exact ready value into the lobby instead of repeatedly toggling state, eliminating checked/unchecked flicker when an event is replayed.
- Registered disconnect cleanup and explicit leave cleanup for challenger readiness so stale sessions cannot remain ready.
- Removed host-side processing and deletion of ready action records, eliminating the repeated `/actions` permission-denied loop.
- Added no-cache Hosting headers for `index.html`, `flutter_service_worker.js`, and `main.dart.js` so browsers cannot remain pinned to the retired `/actions` multiplayer protocol after a deployment.
### 2026-10-06 - Online command mailbox and player-specific controls

- Replaced the Firebase push/delete command queue with one sequenced mailbox per challenger. The host now deduplicates commands without deleting client records, eliminating the rejected `/commands` write loop and reducing database churn.
- Restricted each command mailbox to its authenticated challenger UID in Realtime Database rules.
- Mirrored the challenger camera's horizontal joystick and swipe axes so controls remain screen-relative from the reversed baseline view.
- Made Serve controls local-slot aware: only the currently serving browser receives the Serve button and actionable prompt; the other browser sees `OPPONENT SERVING`.
- Corrected online HUD role detection so online challengers are consistently identified as P2.
### 2026-10-06 - Camera-aware multiplayer input proposal

- Reworked `1v1_flame_court_game_dynamic_joystick_and_camera_guide.md` into a project-specific implementation proposal.
- Corrected the guide's assumption that the current match uses Flame's `World` and `CameraComponent`; documented the actual `PickleballGame` + `PerspectiveCamera` + `CourtPainter` architecture.
- Replaced the recommended Player 2 axis-negation workaround with a staged screen-to-court unprojection and camera-aware input mapper design.
- Added dynamic-joystick pointer ownership, world-space command semantics, Firebase input-rate guidance, delivery milestones, acceptance criteria, risks, and an optional future Flame migration boundary.
### 2026-10-06 - Camera-aware court controls implementation

- Added `PerspectiveCamera.screenToGround()` to invert rendered screen pixels onto the horizontal court plane using the camera's cached perspective basis.
- Added `CourtInputMapper` to convert camera-relative screen drags and normalized control vectors into the existing near-side/far-side movement command convention.
- Routed dynamic joystick, fixed joystick, swipe aiming, and keyboard movement through the camera-aware mapper, removing the challenger's hard-coded horizontal inversion.
- Extended `DynamicJoystick` to report its global screen origin, current pointer position, and normalized analog magnitude while retaining its existing callback compatibility and release behavior.
- Added projection round-trip, reversed-baseline mapping, analog magnitude, and dynamic-joystick widget regressions.
- Updated the implementation proposal to record Milestones A-C as implemented and accurately document the compatibility adapter used by the current command protocol.
- Validation: targeted Flutter analysis passed with no issues; 26 focused graphics, input, command, and multiplayer tests passed.
- Built the release web bundle and deployed the camera-aware controls to Firebase Hosting at `https://pickleball-simulator.web.app`.
### 2026-10-06 - Challenger latency and snapshot smoothing

- Added presentation-only client prediction for the online challenger's controlled avatar, giving immediate movement feedback while the host remains authoritative for rules, scoring, ball physics, and final positions.
- Reconciled the predicted Player 2 position only when a new authoritative snapshot arrives instead of dragging it toward an old snapshot every rendered frame.
- Added up to 150 ms of velocity-based snapshot extrapolation for remote entities, removing the repeated ease-stop-jump pattern between Firebase updates.
- Raised the online host snapshot target from 10 Hz to 20 Hz while retaining the existing in-flight write guard so slow connections cannot accumulate writes.
- Extended snapshot application with per-player blend overrides and regression coverage for extrapolation and preserving predicted Player 2 state.
- Validation: targeted Flutter analysis passed with no issues; 17 focused multiplayer and input tests passed.
- Built and deployed the challenger prediction and 20 Hz snapshot release to Firebase Hosting.
### 2026-10-06 - Bounded Firebase realtime pipelining

- Replaced the single in-flight Firebase snapshot gate with a bounded three-write pipeline, allowing the 20 Hz host target to survive ordinary 150 ms database acknowledgement latency.
- Replaced the challenger's single in-flight command gate with a bounded three-write pipeline and latest-movement coalescing, improving authoritative input cadence without allowing an unbounded network queue.
- Preserved Serve/shot/skill commands in a small priority queue so continuous joystick updates cannot overwrite discrete actions while writes are busy.
- Kept sequence-based host deduplication and circuit breakers for rejected Firebase writes.
- Validation: targeted Flutter analysis passed with no issues; 21 focused multiplayer and control tests passed.
- Built and deployed the bounded Firebase pipeline release to Firebase Hosting.
### 2026-10-06 - Cross-platform WebRTC gameplay transport

- Added `flutter_webrtc` 1.6.2+hotfix.3 for Web, Android, and iOS data-channel support.
- Added Firebase-authenticated SDP offer/answer and ICE-candidate signaling scoped to each online room.
- Added two peer-to-peer gameplay channels: unordered low-retry `realtime` traffic for movement/snapshots and ordered reliable traffic for Serve, shots, and other discrete commands.
- Routed online gameplay through WebRTC whenever both channels are open, while retaining the bounded Firebase transport as an automatic fallback.
- Added STUN-assisted direct connectivity, remote-candidate queuing until SDP is ready, malformed-message isolation, buffered-snapshot dropping, and full peer/channel cleanup on leaving a room.
- Added an in-match `DIRECT P2P` versus `FIREBASE FALLBACK` indicator so transport selection is visible during testing.
- Added Android Internet permission; data-only WebRTC requires no camera or microphone permission on Android or iOS.
- Deployed the new authenticated Realtime Database signaling rules.
- Validation: full Flutter analysis passed with no issues; 21 focused multiplayer/control tests passed; the WebRTC-enabled release web build completed successfully.
- Built and deployed the WebRTC-enabled release to Firebase Hosting at `https://pickleball-simulator.web.app`.
- Android native verification was attempted with `flutter build apk --debug`; the initial native dependency/Gradle build produced no error output but exceeded the six-minute command timeout before producing a new APK. Android compilation therefore remains to be confirmed in a follow-up build; iOS compilation requires macOS/Xcode.
### 2026-10-06 - WebRTC asynchronous error containment

- Confirmed from the in-match `DIRECT P2P` indicator that SDP/ICE negotiation and both gameplay channels opened successfully in Chrome and Edge.
- Guarded every fire-and-forget WebRTC operation (SDP callbacks, ICE publication/addition, data-channel sends, and unknown-channel cleanup) so transient channel-close or ICE races cannot surface as generic unhandled browser errors.
- Added named peer-connection and data-channel state diagnostics to the console for actionable follow-up logs.
- Prevented duplicate concurrent offer/answer acceptance while an asynchronous remote-description operation is pending.
- Validation: targeted Flutter analysis passed with no issues.
- Rebuilt the release web bundle and deployed the hardened WebRTC client to Firebase Hosting at `https://pickleball-simulator.web.app`.

### 2026-10-06 - Rally sequencing and bot paddle loadouts

- Solidified the opening two-bounce sequence: the serve must bounce before the return, the return must bounce before the third shot, and volleys become legal from the fourth stroke onward (subject to kitchen rules).
- Added an 80 ms shared-world contact lock after every court bounce so a hit cannot erase the visual bounce in the same simulation tick; early button presses remain buffered and execute when contact becomes legal.
- Applied the post-bounce lock consistently to Player 1, local/online Player 2, and AI contact decisions.
- Expanded only the AI's post-bounce backswing recovery reach so Easy bots can honor the delay without losing fast legal returns; volley reach remains unchanged.
- Assigned every bot a random paddle from the full catalog once per match and exposed stable per-player paddle lookup for rendering. Human slots retain their equipped paddle.
- Added regressions for the bounce delay, buffered recovery shot, stable bot paddle assignment, and opening-rally behavior.
- Validation: Flutter analysis passed with no issues; all 48 rules tests and all 23 AI/bot rally tests passed.
- A connected Dart Tooling Daemon was unavailable, so the required hot restart could not be triggered automatically.

### 2026-10-06 - Bot contact timing and movement pacing

- Added a 120 ms minimum travel window after an incoming ball reaches the bot's half of the court before the bot may make contact, keeping the existing forgiving lateral hitbox while making hits visually believable.
- Increased velocity-dependent ball drag from `0.0018` to `0.0025`, so hard shots now launch quickly and shed a noticeably larger share of speed than slower shots instead of appearing constant-speed.
- Increased human/local-player movement speed from 80 to 100 world units per second, acceleration from 400 to 520, and braking from 600 to 680 for faster court recovery without changing boundaries.
- Added a regression proving high-speed balls decelerate proportionally more than slower balls.
- Validation: all 72 focused rules, AI, and bot tests passed.
- A connected Dart Tooling Daemon was unavailable, so the required hot restart could not be triggered automatically.
