# Setu — The Bridge to Lanka (Design Document v0.3)

> Status: **DRAFT.** Written by the design agent (Opus). This is the second game from the factory and a sequel to *Hanumaan*.
> It follows the same conventions as `flypatang/hanumaan/docs/DESIGN.md` (rules for coding agents, quality gates,
> localization, shlokas, frame-rate options and the Steam plan) unless this document says otherwise.

## 1. Vision

An isometric 3D **building and logistics strategy game**. As **Nala**, son of Vishwakarma (the divine architect),
you lead the vanara army in building a bridge **100 yojanas** long across the ocean to Lanka, in **five days**.

**Pillars**
1. **The satisfaction of logistics.** You lay out haul routes from the forests and quarries to the shore, place crews,
   and watch thousands of vanaras pass stones and trees forward in readable, rhythmic chains.
2. **Building against the sea.** The ocean pushes back with tides, currents and storms. Your engineering choices
   (foundations, how materials are mixed, the pace of work) decide whether each day's section holds.
3. **Collective devotion.** No single hero: it's the whole army's effort, cheered on by Rama. Morale (*Utsaha*) is the shared resource.

**Target:** about 45–60 minutes of play over 5 "days" plus a free-build mode. Windows and Linux. Mouse, or a gamepad with a radial menu.

## 2. Source fidelity (Valmiki Ramayana, Yuddha Kanda, sargas 19–22)

| Beat in the text | In the game |
|---|---|
| Rama meets Vibhishana, who advises asking Samudra (the ocean god) for passage | Prologue dialogue |
| Rama lies on kusha grass by the shore for three nights; the ocean doesn't appear | Prologue, a short contemplative sequence (not playable as combat) |
| Rama raises his bow; Samudra rises, says the ocean's nature can't change, but **promises to hold up whatever Nala builds**, and names Nala, son of Vishwakarma | The key cutscene, which sets up why the bridge can float |
| The vanaras uproot trees and boulders, and lines of rope keep the bridge straight | Core gameplay: gathering, hauling, measuring lines |
| Built in 5 days: **14, 20, 21, 22 and 23 yojanas** | The 5 levels, each with that day's length as its target |
| The army crosses; the gods and sages watch in wonder | Finale |

**Depiction rules:** Rama is never playable or controlled, and appears in cutscenes and as a source of morale. The ocean god is
majestic, not a monster. **No combat with Samudra.** Sea creatures are hazards of nature, not enemies to kill. You
drive them away with noise or light, or work around them.

**Valmiki and the folk tradition combined (owner decision 2026-11-26):** Valmiki's account is the frame: Samudra
promises to hold up what Nala builds. The popular tradition is shown **visibly and centrally**: every stone is inscribed
with **"राम"** before it goes into the sea, and **the inscribed stones float**. The two fit together in the story:
Samudra's promise is honoured *through* Rama's name. The little **squirrel (gilahari)** appears as a folk-tale
vignette (see §3). Every shloka is still quoted from Valmiki (§7). Folk elements are shown in scenes and gameplay,
never presented as Valmiki verses.

**Nala and Nila (owner decision 2026-11-26):** both brothers are foremen. **Nala** is the chief architect (as in
Valmiki), in charge of design and alignment at the bridge head. **Nila**, commander of the vanara army, runs the crews,
hauling and morale. Folk vignette: as boys, both were blessed (or playfully cursed) by sages so that whatever they threw into water would float.

## 3. Structure

| Level | Day | Target (yojanas) | New mechanic | Hazard |
|---|---|---|---|---|
| Prologue | — | — | Camera, selection, the first haul line, **inscribing the first stone with "राम"** (Rama watches) | — |
| Day 1 | 1 | 14 | Forests and quarries, haul chains, laying sections | Gentle tides |
| Day 2 | 2 | 20 (34 total) | **Measuring lines** (alignment bonus), mixed foundations | Cross-currents bend unaligned sections |
| Day 3 | 3 | 21 (55 total) | **Night shift** (torches, lower morale), crew roles | Squall at midday |
| Day 4 | 4 | 22 (77 total) | **Sea creatures** (makara, giant fish): sound gongs and use conch signals | A pod of makaras |
| Day 5 | 5 | 23 (100 total) | Everything; time pressure; Rama's arrival adds morale | A great storm at the finish |
| Vignette | between Days 2 and 3 | — | **The squirrel:** play a short scene as a little squirrel rolling in sand and shaking it onto the bridge. Rama strokes its back, leaving three stripes. | — |
| Free Build *(post-launch update)* | — | — | A sandbox with all tools and no timer | Hazards you can toggle |

Each "day" is about 8–12 minutes of game time and is scored for length, alignment, material efficiency and morale.
A day ends when the sun sets (the timer). Unfinished length carries over and the next target gets harder, so the
story never fails: Nala always finishes, but the score and the cutscene's tone change.

## 4. Core systems

### 4.1 Resources
- **Stone** (from quarries: slow to cut, heavy, strong), **Timber** (from forests: fast, light, needs lashing),
  **Rope** (made from bark and grass at rope-works; needed for lashing and measuring lines).
- **Inscribed Stone:** at **Lekhan** stations (scribe crews), stones are painted with "राम". **Only inscribed stones float.** An uninscribed stone placed in the sea sinks and is wasted, which makes the inscription step a real logistics stage. The "राम" lettering is always rendered legibly on the stone mesh (a decal or vertex-coloured glyph), including in crowd shots at mid zoom.
- **Foundation** sections need Stone ≥ 60%. **Deck** sections need Timber ≥ 40% and Rope.

### 4.2 Crews (vanaras)
- **Scribes** at Lekhan stations inscribe stones (throughput is a balancing lever).
- **Haulers** form chains along a drawn route (a spline). Throughput = hauler count × speed ÷ route length, with
  bottlenecks at the narrowest point. Hauling **passes items hand to hand**, so it reads visually as a stream of goods.
- **Cutters** at quarries and forests, **Lashers** at rope-works, and **Builders** at the bridge head (Nala's team).
- Each crew is a group of 10 vanaras (instanced rendering; budget of 2,000 visible vanaras).

### 4.3 The bridge head
- Building moves forward along a guide path. Each **section** (1/10 of a yojana) needs a foundation plus a deck.
- **Alignment:** sections placed within ±2° of the measuring line get a 20% sturdiness bonus. Unaligned sections bend under current.
- **Sturdiness and the sea:** each tick, a section's sturdiness is compared with the current's force. Weak sections
  get damaged, and broken ones float away (they must be rebuilt). Samudra's promise: **a finished section, once
  blessed at day's end, never breaks.** This is a key rule of the fiction and the game.

### 4.4 Morale (Utsaha)
- Shared morale from 0–100. It rises with good progress, Rama's presence, songs (a *Jaya* chant ability), and rest
  shelters. It falls at night, in storms, and with overcrowded routes. Morale scales crew speed (0.6× to 1.3×).

### 4.5 Hazards
- **Tides** (sinusoidal, they change the depth of the work area), **currents** (vector fields, stronger in the
  deep water at mid-ocean), **storms** (scripted events plus random ones in Free Build), **sea creatures** (they block an
  area of sea; drive them away with gong towers or work around them).

## 5. Controls
**Nala and Nila as advisors:** Nala's hints are about the bridge (alignment, sturdiness); Nila's are about crews and morale.

Mouse: left-click to select or place, right-drag to rotate the camera (in 90° snaps), wheel to zoom, and a radial build
menu on right-click. Gamepad: cursor on the left stick, radial menu on the shoulder buttons. Time controls: pause, 1×, 2× and 3×.

## 6. Art and audio
- The same palette and toon style as Hanumaan (`core/palette.gd`). New colours: `SHORE_SAND #E8D3A2`,
  `ROPE #A57C52`, `WET_STONE #8A8F87`, `DAWN_PINK #F4A6A6`.
- A day-night cycle drives the lighting (dawn pink, midday white, sunset saffron, night indigo with torches).
- **Reused from Hanumaan:** the vanara body generator (a variant of the Hanuman model at lower detail), the mesh kit,
  the nature kit (trees, rocks), the ocean shader, the synth library and the music player (a new raga set: **Raga
  Yaman** for the day, **Raga Darbari** for night and the storm).

## 7. Languages and shlokas
English and Hindi, as in Hanumaan §7A. **Candidate shloka moments** (texts to be chosen from Yuddha Kanda 19–22
and checked against the IITK text before release): Samudra's promise, the start of building on Day 1, and the
army's crossing.

## 8. Technical approach
- **Godot 4.7.2.** Systems are data-driven: levels and days are JSON files, and the whole simulation runs in a
  **deterministic fixed tick (20 Hz)**, separate from rendering. That makes it fully testable headless, and a
  bot can play an entire day as a test.
- Crowds use `MultiMeshInstance3D` for the vanaras, with animation done in a vertex shader (no per-unit nodes).
- **Code shared with Hanumaan** is copied from that repo's `core/` and `gen/` at a fixed commit and recorded in
  `SHARED.md`. Once both games are done, the factory pulls it out into a shared addon.

## 9. Module contracts

Rules for coding agents are the same as in Hanumaan §9: one module per task, tests first, strict static typing, and
only the files you own. **Every `sim/` module is pure logic:** it extends `RefCounted` (not Node), uses no `_process`, no
global RNG and no wall-clock time, and advances only when `step(tick: int)` is called. Rendering reads the simulation;
it never writes to it.

**Units:** 1 world unit = 1 m. A yojana is scaled down for play: **1 game-yojana = 10 m of bridge**, so the 100-yojana
bridge is 1 km. 1 section = 1 m. Ticks run at 20 Hz; one in-game day is 9,600 ticks (8 minutes at 1×).

### Shared modules (copied from Hanumaan at a fixed commit, recorded in `SHARED.md`)
`core/palette.gd` (plus the Setu colour tokens), `core/game_state.gd`, `core/locale.gd`, `narrative/shlokas.gd`,
`narrative/dialogue_runner.gd`, `gen/mesh_kit.gd`, `gen/synth.gd`, `gen/sfx_library.gd`, `gen/nature_kit.gd`,
`gen/hanuman_model.gd` (the vanara base), and `gameplay/camera/iso_camera.gd` once Hanumaan M35 is done.
These are copied by the integrator (Opus), not written by coding agents.

### Wave S0: simulation core
**S01 `sim/sim_clock.gd`** (`class_name SimClock`): `tick: int`, `speed: int` (0 = paused, 1, 2, 3),
`advance(real_delta: float) -> int` returns how many fixed ticks to run (accumulator), `register(system: Object)`,
and `step_all()` calls `step(tick)` on the registered systems in registration order. `snapshot() -> Dictionary`, `restore(d)`.
*Tests:* 1 s of real time at speed 2 gives exactly 40 ticks; paused gives 0; the order is stable; a snapshot round-trips.

**S02 `sim/stockpile.gd`** (`class_name Stockpile`): resource kinds `stone`, `inscribed_stone`, `timber`, `rope`, with
`add(kind, n)`, `take(kind, n) -> int` (returns how many were actually taken), `count(kind)`, `capacity` per kind, and a
`changed` signal. Several stockpiles exist (quarry, forest, rope-works, lekhan station, bridge head).
*Tests:* it clamps to capacity; a take is partial when stock is short; an unknown kind is an error.

**S03 `sim/sim_rng.gd`** (`class_name SimRng`): a seeded xorshift with `next_float()`, `range_i(a, b)` and `fork(label) -> SimRng`
(derives a child seed deterministically from the label). *Tests:* the same seed gives the same sequence; forks are independent but deterministic.

**S04 `sim/state_hash.gd`**: `hash_state(d: Dictionary) -> String` (sorted keys, canonical floats rounded to 1e-4, then SHA-256).
*Tests:* key order doesn't matter; tiny float noise below 1e-4 doesn't matter.

### Wave S1: systems
**S05 `sim/routes.gd`** (owner: **Sonnet**): `Route {id, from_pile, to_pile, points: PackedVector2Array, haulers: int}`.
`length()`; `capacity_per_tick() = haulers × HAULER_SPEED(1.2 m/s) ÷ 20 ÷ max(length, 1) × ITEMS_PER_HANDOFF(1)`, limited
by the narrowest segment (segments carrying the `narrow` flag halve throughput); a crowding penalty above 12
haulers per 10 m; `step(tick)` moves resources from the source to the destination, accumulating fractional items.
*Tests:* doubling the haulers doubles the throughput below the crowding cap; a narrow segment halves it; nothing is
created out of nothing (conservation: the source loses exactly what the destination gains, plus whatever is in transit).

**S06 `sim/crews.gd`**: crew roles `cutter`, `lumberjack`, `lasher`, `scribe`, `hauler`, `builder`, each crew
= 10 vanaras. `assign(role, site_id, crews)`, `unassign`, `free_crews() -> int`. Production per crew per tick: cutter stone 0.05,
lumberjack timber 0.08, lasher rope 0.04 (uses 0.04 timber), and scribe converts stone to inscribed_stone at 0.06.
Everything is multiplied by the morale factor (S08). *Tests:* the production rates, the morale multiplier, and that you can't assign more crews than are free.

**S07 `sim/bridge.gd`** (owner: **Sonnet**): an array of sections along the guide line. `Section {index, foundation: float 0..1,
deck: float 0..1, alignment_deg: float, sturdiness: float, blessed: bool, broken: bool}`. Building at the bridge head consumes
**inscribed_stone** (foundation, 4 per section) and **timber + rope** (deck, 3 + 1 per section), only for the next unfinished
section. **An uninscribed stone delivered to the head is wasted** (counted in stats; the "stone sinks" event fires).
Alignment comes from the player's measuring line: sections within ±2° get a 1.2× sturdiness bonus. `apply_current(force)`
damages unblessed sections whose sturdiness < force, and breaks them when foundation < 0.25. `bless_all_complete()` runs
at day's end: complete sections become `blessed` and are immune from then on. `length_m()` counts complete sections.
*Tests:* the material costs; that only inscribed stone builds foundations; the alignment bonus; blessed sections never break; a broken section must be rebuilt.

**S08 `sim/morale.gd`**: `utsaha: float` from 0 to 100; `factor() -> float` maps 0 → 0.6, 50 → 1.0 and 100 → 1.3 (piecewise
linear). Modifiers are applied each tick from a `Dictionary` of active effects (night −0.01/tick, storm −0.03, crowding −0.02,
Rama present +0.02, Jaya chant +15 instantly with a 1,200-tick cooldown, progress +0.5 per section completed).
*Tests:* the factor curve, clamping, and the chant cooldown.

**S09 `sim/ocean.gd`**: `tide(tick) -> float` (a sinusoid with a 2,400-tick period, ±0.6 m), and a current field
`current_at(x: float, tick) -> float` that rises with the distance from shore toward mid-ocean (a peak of 1.0 at x = 500 m),
plus scripted storms `{start, duration, strength}` from the level JSON. *Tests:* the period, the peak position, and the storm window.

**S10 `sim/creatures.gd`**: makara and fish zones `{x_from, x_to, active_until}`. Building is blocked in an active zone.
Gong towers (built near shore, each costing rope and timber) shorten the zone's active time by 50% per gong, up to 3 gongs.
*Tests:* building is blocked while a zone is active; the gong maths; zones expire.

### Wave S2: game layer
**S11 `game/day_flow.gd`** (owner: **Sonnet**): loads `data/days/day_<n>.json` (the target length, the start piles, storms,
creatures, events and dialogue triggers), owns the SimClock and all the systems, runs the day until sunset (tick 9,600), and
computes the score `{length_pct, alignment_pct, waste_pct, morale_avg, total 0..100}`. If a target is missed, the missing
length carries over to the next day's target. **The story never fails.**
*Tests:* a scripted input plan finishes Day 1; the score maths; carry-over.

**S12 `game/player_commands.gd`**: every player action is a command object `{tick, type, args}` applied by day_flow at
its tick (`draw_route`, `assign_crews`, `build_station`, `place_measuring_line`, `ring_gong`, `chant_jaya`). Commands can be
recorded and replayed, which is what the bot and the determinism gate use.
*Tests:* recording and replaying gives the same state hash.

### Wave S3: presentation
**S13 `render/crowd.gd`** (owner: **Sonnet**): a `MultiMeshInstance3D` of vanaras (a low-detail mesh from the HanumanModel
parts), positioned along routes from the simulation state, with a vertex-shader walk cycle and up to 2,000 instances.
Carried items are drawn as a second MultiMesh, with **inscribed stones showing the "राम" glyph** (an SDF or vertex-coloured
mesh glyph built from strokes).
**S14 `render/bridge_view.gd`**: builds and updates the bridge meshes per section (foundation stones with the "राम" glyph,
timber deck, rope lashings), with broken sections drifting away and a gold shimmer when a section is blessed.
**S15 `render/world_view.gd`**: the shore, quarries, forests, ocean (NatureKit), and the day-night lighting driven by the sim tick.
**S16 `ui/build_menu.gd`** (radial), **S17 `ui/hud.gd`** (the day clock, length/target, stockpiles, morale, and the advisor
portraits for Nala and Nila), **S18 `ui/day_summary.gd`**, **S19 `ui/menus.gd`** (as in Hanumaan M33: language, fps, graphics).
**S20 `game/input_controller.gd`**: turns mouse and gamepad input into the S12 commands (no simulation logic).
**S21 `tests/playtest/bot_day.gd`** (owner: **Sonnet**): a bot that plays each day to at least 90% using command plans.

### Content (Opus)
**SC1** `data/days/day_1..5.json` and `prologue.json` · **SC2** dialogue and strings (English and Hindi), including the Nala and Nila
advisor lines, the Samudra cutscene and the squirrel vignette · **SC3** `data/shlokas.json` from Yuddha Kanda 19–22 (Samudra's promise,
the start of building, the crossing).

## 10. Quality gates
As in Hanumaan §10, plus: **Gate S (simulation):** the bot must finish Day 1 with a ≥ 90% score at 3× speed within 60 s of
wall time, and the same seed with the same inputs must produce an identical bridge (a hash of the simulation state).

## 11. Owner decisions
| Date | Decision |
|---|---|
| 2026-11-26 | Combine Valmiki and the folk tradition: stones inscribed with "राम" float, and this is shown prominently; the squirrel is a vignette (§2, §3, §4.1). |
| 2026-11-26 | Nala and Nila both appear as foremen (§2). |
| 2026-11-26 | Free Build is left out of the first release and comes as a free update later. |

## 12. Open questions for the owner
None at the moment.
