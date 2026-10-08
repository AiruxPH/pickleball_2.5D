# Gameplay Enhancement Roadmap

Last updated: 2026-10-08  
Owner: Project team  
Status: Approved plan; implementation not started

## Purpose

This is the source of truth for the next gameplay-enhancement cycle. It records the chosen design, implementation order, acceptance gates, and progress so work can continue safely across sessions.

Use these markers throughout the document:

- `[ ]` Planned
- `[~]` In progress
- `[x]` Complete and verified
- `[!]` Blocked; add the reason to the Progress Log

When a task changes state, update its checkbox/status, append a dated Progress Log entry, and record the completed implementation in `CHANGELOG.md`. Never mark a phase complete until its tests and cross-mode checks pass.

## Product Direction

The target is a **competitive-casual** court game: easy to understand and forgiving to control, but deep enough for positioning, timing, spin, and tactical shot choice to matter.

Non-negotiable rules:

- Preserve official scoring, receiver order, two-bounce, serve, kitchen, and fault rules.
- Timing may reward or soften a return but must never cause a forced miss by itself.
- Ball physics, legality, scoring, assists, and results stay in shared world coordinates.
- LAN and online matches remain host-authoritative. Remote clients send intent and render authoritative results.
- Player 2 input is transformed into world space before commands are sent; HUD and controls remain in screen/viewport space.
- Do not add permanent HUD clutter or another required action button.
- All gameplay additions must work on Android, iOS, and web, and must scale on compact mobile and desktop layouts.
- Private/offline matches may use equipment stats and paddle-bound skills. The competitive preset makes equipment cosmetic and disables equipment stat/skill advantages.

## Confirmed Decisions

| Area | Decision |
|---|---|
| Delivery | Build all enhancements in staged, independently releasable phases |
| Tone | Competitive-casual |
| Movement help | Automatic contextual lunge and split-step; no new buttons |
| Momentum | Improves control, special gain, and presentation; never raw movement or ball speed |
| Equipment | Standard matches keep equipment identity; competitive matches normalize it to cosmetics |
| Challenge modes | Place short modes in a separate **Arcade** hub |
| Replay | Eight-second in-memory highlight replay; no saved video/file export in this cycle |
| Ranked | Defer true ranked until accounts and a trusted authoritative server exist |

## Existing Baseline

These systems already exist and should be extended rather than replaced:

- [x] Official rule/scoring foundation, including two-bounce and kitchen rules
- [x] Shared match-command input gateway
- [x] Flat, topspin, and slice physics for Hit and Power
- [x] Perfect, Good, Early, and Late timing feedback
- [x] Paddle stats and paddle-bound special skills
- [x] Singles, doubles, bot-v-bot, tournament, training, LAN, and Firebase/WebRTC online modes
- [x] Host-authoritative command and snapshot flow for multiplayer
- [x] Basic particles, audio feedback, achievements, daily challenges, and match results

## Architecture Contract

Add small shared models instead of placing more unrelated state directly in the game screen:

- `MatchEvent`: typed events for contact, bounce, rally phase, attackable ball, assist activation, point result, and match end.
- `MatchStats`: authoritative per-match counters for timing grades, spin use, winners, faults, unforced errors, saves, kitchen exchanges, streaks, rally length, and duration.
- `RallyPhase`: `opening`, `baseline`, `kitchen`, and `attackable`.
- `AimIntent`: normalized world-space direction plus resolved tactical lane (`line`, `crossCourt`, `body`, `deep`, or `kitchenAngle`).
- `MomentumState`: per-side streak and tier, reset at every point.
- `MovementAssistState`: split-step and lunge activation/recovery state.
- `BotPersonality`: `balanced`, `aggressor`, `counterpuncher`, `dinker`, or `trickster`, shared by singles and doubles AI.
- `MatchBalanceProfile`: `standard` or `competitive`.
- `ReplayFrame`: immutable lightweight render state stored in a bounded ring buffer.

Compatibility requirements:

- Add new command/snapshot fields as optional values with safe defaults for older payloads.
- Record a protocol revision when a new authoritative state field is introduced.
- Do not transmit screen coordinates, local camera rotation, Flutter widget state, or raw replay video.
- The host validates the legal receiver/contact and computes final trajectory, momentum, assists, statistics, and point results.
- Clients may predict visuals, but authoritative snapshots must correct them without duplicating events or rewards.

## Phase 0 — Shared Gameplay Foundation

Status: Complete and verified

- [x] Add the typed match-event stream and one authoritative `MatchStats` collector.
- [x] Add deterministic rally-phase classification using ball state, contact height, player positions, and two-bounce state.
- [x] Add `MatchBalanceProfile` to local match setup, LAN rooms, and online rooms.
- [x] For `competitive`, normalize paddle/character gameplay modifiers, disable paddle-bound specials, and retain all equipped cosmetics.
- [x] Keep private/offline/LAN/online defaults on `standard` for backward compatibility.
- [x] Add versioned optional snapshot fields for rally phase, balance profile, and event revisions.

Acceptance gate:

- Existing rules and timing/spin tests remain unchanged and pass.
- Standard matches behave exactly as before when no new feature is active.
- Competitive matches produce identical physics for players using different equipment.
- An authoritative event is counted and displayed once, even after snapshot correction or reconnection.

## Phase 1 — Tactical Shot Depth

Status: Planned

### Directional placement

- [ ] Resolve the movement/aim direction held at contact into world-space placement intent.
- [ ] Support line, cross-court, body, deep, and kitchen-angle targets without adding buttons.
- [ ] Preserve the existing automatic target when the player supplies no aim.
- [ ] Let timing and sweet-spot quality adjust deterministic target dispersion: Perfect is most precise; Early/Late remain playable but less exact.
- [ ] Use the same mapping for rotated Player 2, bots, LAN, and online commands.

### Spin counterplay

- [ ] Make incoming physical spin affect return stability and lift, not input direction.
- [ ] Allow Good/Perfect contact to neutralize more incoming spin; Early/Late carries more disruption into placement.
- [ ] Preserve the rule that only Hit and Power apply the selected ordinary spin.
- [ ] Keep paddle-bound skills authoritative and separate from ordinary spin.

### Kitchen battles and attackable balls

- [ ] Enter the kitchen phase only when both sides are established near the non-volley zone and exchanges are low/slow.
- [ ] Keep well-timed dinks low. Stretched, Early, or Late contacts may produce a deterministic higher return based on contact quality—not random failure.
- [ ] Mark an attackable ball only when its predicted legal contact height and receiver state allow an aggressive volley/smash.
- [ ] Show a brief world-space glow/ring and audio cue that follows each local camera correctly.

Acceptance gate:

- The same input produces the same world target from either camera perspective.
- New trajectories cannot bypass two-bounce, receiver, serve, kitchen, or collision validation.
- Topspin, slice, and flat remain visually distinct after return counterplay is added.
- Indicators never reveal an illegal or unreachable ball as attackable.

## Phase 2 — Movement Skill and Rally Momentum

Status: Planned

### Automatic movement assists

- [ ] Trigger a lunge only for the legal receiver when the predicted contact is just outside normal reach, the player is moving toward it, and sufficient stamina remains.
- [ ] Limit lunge reach to 15% beyond normal contact reach, consume 15% of maximum stamina, reduce return pace by 12%, and apply 0.35 seconds of recovery.
- [ ] Permit at most one lunge for an incoming shot; never cross court boundaries or bypass kitchen momentum rules.
- [ ] Grant a split-step when a player is settled as the opponent contacts the ball: 12% acceleration for 0.35 seconds, with no increase to maximum speed.
- [ ] Compute assists on the host and synchronize the resulting state/feedback.

### Momentum

- [ ] Track momentum independently per side during a rally: Good `+1`, Perfect `+2`, cap `5`; Early, Late, or a fault resets that side.
- [ ] At tier 3, increase crowd/audio/VFX intensity only.
- [ ] At tier 5, reduce aim dispersion by 8% and increase normal special-meter gain by 10%; do not boost movement speed or ball pace.
- [ ] Reset both sides at point and match boundaries.
- [ ] Display only short milestones such as `LOCKED IN` or `PERFECT ×3`, not a permanent meter.

Acceptance gate:

- Assists save borderline balls without turning clearly lost balls into contacts.
- Low stamina and recovery state visibly constrain repeated lunges.
- Momentum never changes rule outcomes or creates a multiplayer-only advantage.
- Host and challenger agree on assist, momentum, stamina, and resulting ball state.

## Phase 3 — Distinct and Coordinated AI

Status: Planned

- [ ] Unify bot decision-making around the shared `BotPersonality` model.
- [ ] `Aggressor`: seeks deep attacks, topspin, and attackable balls.
- [ ] `Counterpuncher`: prioritizes recovery, safe depth, and opponent mistakes.
- [ ] `Dinker`: approaches the kitchen and prefers low drops/slice exchanges.
- [ ] `Trickster`: varies pace, lob/drop use, and spin more often.
- [ ] `Balanced`: preserves the current general-purpose behavior.
- [ ] Choose a stable personality at match creation; expose it in bot-v-bot setup and show a compact intro badge.
- [ ] Keep difficulty responsible for reaction/precision, while personality controls tactical preference.
- [ ] In doubles, assign one receiver from predicted landing ownership and make the partner cover open space. Reassign only when the owner cannot legally/reliably reach the ball.
- [ ] Ensure bots understand attackable balls, kitchen phases, lunge cost, momentum, and competitive balance.

Acceptance gate:

- Personalities produce measurably different shot/position distributions over seeded simulations.
- Easy bots remain forgiving without waiting unnaturally after a legal bounce.
- Doubles partners do not collide, steal the receiver's ball, or enter infinite alternating lanes.
- Seeded AI tests remain deterministic.

## Phase 4 — Arcade Hub and Progression

Status: Planned

- [ ] Add an `Arcade` tile without overcrowding the main mode grid.
- [ ] Build a responsive Arcade hub with locked/unlocked cards, best result, and concise rules.
- [ ] **Target Challenge:** score by hitting changing legal zones before time expires.
- [ ] **Rally Survival:** preserve increasingly fast legal rallies; score duration and streak.
- [ ] **Smash Defense:** defend a sequence of attackable balls with limited misses.
- [ ] **Dink Duel:** kitchen-only tactical exchanges with official volley/kitchen legality retained.
- [ ] **Tie-break:** first to 7, win by 2, using normal scoring/serve rules where applicable.
- [ ] **King of the Court v1:** single-player AI gauntlet; defeat escalating personalities without requiring more network player slots.
- [ ] Extend achievements and daily challenges with timing streak, spin, dink, target, save, and Arcade goals.
- [ ] Store only compact progress/best-score data through the existing settings persistence.

Acceptance gate:

- Every Arcade mode reuses shared physics/events rather than copying match logic.
- Back/leave flow is safe and progress is saved once.
- Cards and controls do not overlap at supported mobile/desktop sizes.
- Progress migration defaults cleanly for existing players.

## Phase 5 — Presentation, Highlights, and Match Review

Status: Planned

- [ ] Drive crowd intensity, announcements, particles, and sound from authoritative match events.
- [ ] Add restrained cues for `RALLY 10`, `PERFECT ×3`, `GREAT SAVE`, `KITCHEN BATTLE`, and attackable balls.
- [ ] Improve landing shadow, bounce/skid, and spin readability without covering court lines.
- [ ] Add a bounded replay ring buffer holding the most recent 8 seconds of lightweight authoritative state at 20 Hz.
- [ ] Auto-play a highlight only after notable points: match point, rally of 10+, smash winner, or emergency save.
- [ ] Add `SKIP`; do not replay during reconnection, disconnection resolution, or app backgrounding.
- [ ] In network matches, each client replays its own buffered authoritative snapshots from its own camera. Do not stream replay video.
- [ ] Expand the post-match panel with timing distribution, spin use, winners, faults, saves, longest rally, kitchen exchanges, and connection summary.

Acceptance gate:

- The replay is deterministic, bounded in memory, and cannot mutate live match state.
- Resuming after a replay returns directly to the authoritative current state.
- Effects remain readable from both player perspectives and pass reduced-motion/accessibility checks.
- Performance stays within the Phase 7 frame/network budgets.

## Phase 6 — Multiplayer Rooms and Social Features

Status: Planned

- [ ] Add host-selected room options: singles/doubles, court, target score, and standard/competitive balance.
- [ ] Lock gameplay-affecting room options once the match starts and mirror the final configuration to every member.
- [ ] Add coordinated rematch readiness; start only after all required players accept.
- [ ] Add preset, rate-limited emotes that never pause play or carry arbitrary text.
- [ ] Add a read-only spectator role using snapshots only; spectators cannot send movement/shot commands or occupy a player slot.
- [ ] Show a post-match connection summary using measured latency, jitter, correction count, and disconnects—never an unsupported quality claim.
- [ ] Apply every gameplay phase to LAN and Firebase/WebRTC through the same command/snapshot contracts.

Deferred from this cycle:

- [ ] True ranked matchmaking, ratings, leaderboards, and anti-cheat are blocked until persistent accounts and a trusted dedicated authoritative server exist.
- [ ] Saved/shareable replay files and video export are deferred; the first version is in-memory only.
- [ ] Online King of the Court with more than the existing player slots is deferred.

Acceptance gate:

- Standard and competitive room settings cannot diverge between host and clients.
- Spectators cannot mutate room or match state under client code or Firebase rules.
- Rematch/disconnect/reconnect flows always provide a usable exit or resolution state.
- Legacy rooms/payloads fall back safely to standard settings.

## Phase 7 — Final Quality and Release Gate

Status: Planned

- [ ] Profile representative low/mid-range mobile hardware and current Chrome/Edge builds.
- [ ] Maintain a 60 FPS target; no recurring frame over 32 ms during normal rallies, effects, or replay playback.
- [ ] Keep authoritative snapshots at the existing tuned cadence; new fields must not create per-frame database writes or console floods.
- [ ] Bound replay and event history memory and clear it at match disposal.
- [ ] Verify touch, keyboard, rotated Player 2 camera, app background/resume, and connection loss.
- [ ] Verify minimum supported mobile layouts, desktop resizing, safe areas, text scaling, and reduced motion.
- [ ] Run `flutter analyze` and the complete Flutter test suite.
- [ ] Perform two-device/manual matrices for Android↔Android, web↔web, and mobile↔web where available.
- [ ] Update this roadmap, `CHANGELOG.md`, Firebase rules documentation when applicable, and deployment notes.
- [ ] After any non-comment `lib/**/*.dart` edit, discover a running Dart/Flutter app and trigger the required DTD hot reload or hot restart; log when no DTD connection is available.

## Test Matrix Required for Every Phase

| Area | Required coverage |
|---|---|
| Unit | Deterministic thresholds, modifiers, state transitions, serialization defaults, and stats |
| Rules | Serve, receiver, two-bounce, kitchen, side-out, doubles ownership, and faults |
| Trajectory | Timing, spin, aim lanes, pop-ups, attackable prediction, and assist returns |
| AI | Every difficulty/personality, seeded simulations, doubles coordination, and no infinite patterns |
| UI | Compact mobile, tablet/desktop, orientation/resize, safe areas, no overlap |
| Multiplayer | Host authority, Player 2 camera/input, legacy payloads, duplicate events, reconnect/disconnect |
| Performance | Frame time, snapshot size/cadence, replay memory, and effect count |
| Regression | Full `flutter test` plus `flutter analyze` before completing a phase |

## Delivery Order

Implement strictly in this order unless the Decision Log explains a change:

1. Shared events, stats, rally phases, and balance profile
2. Directional placement, spin counterplay, kitchen/attackable-ball gameplay
3. Lunge, split-step, and momentum
4. Unified AI personalities and doubles coordination
5. Arcade hub and progression
6. Presentation, in-memory highlights, and post-match review
7. Multiplayer room/social extensions
8. Full performance, compatibility, and release validation

Each phase must land as a playable, testable increment. Multiplayer schema work ships with the gameplay feature that needs it, not as a final retrofit.

## Decision Log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-08 | Use a staged roadmap covering gameplay, AI, Arcade, presentation, and multiplayer | Keeps releases testable while preserving the complete vision |
| 2026-10-08 | Use competitive-casual tuning | Adds mastery without making normal timing frustrating |
| 2026-10-08 | Make movement assistance contextual and automatic | Preserves mobile control simplicity |
| 2026-10-08 | Keep momentum away from raw speed/pace | Avoids runaway snowballing and network unfairness |
| 2026-10-08 | Normalize equipment in competitive rooms | Competitive results should come from play, while cosmetics remain visible |
| 2026-10-08 | Put short challenges in a separate Arcade hub | Keeps the primary mode screen clean |
| 2026-10-08 | Keep only an 8-second in-memory replay buffer | Provides highlights without storage/export complexity |
| 2026-10-08 | Defer true ranked | Client-host authority is not sufficient for trustworthy ratings or anti-cheat |

## Progress Log

### 2026-10-08 — Roadmap created

- [x] Audited current rules, timing/spin, AI, game modes, effects, progression, and multiplayer foundations.
- [x] Locked the product direction and major scope decisions.
- [x] Created the staged implementation and acceptance plan.
- [x] Completed Phase 0 with typed events/statistics, rally phases, competitive balance, room integration, and protocol revision 2 snapshots.
- [x] Verified Phase 0 focused gameplay, rules, lobby, snapshot, and mode-selection coverage.
- [x] Final release gate passed: `flutter analyze` reported no issues and the complete Flutter suite passed 207/207 tests.
- [ ] Next action: begin Phase 1 with world-space directional placement and tactical aim lanes.
