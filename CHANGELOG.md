# Change Log

## 2026-10-05

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
