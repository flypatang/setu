# Setu — The Bridge to Lanka (Design Document v0.2)

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

## 9. Module contracts (summary; the full contracts are written once Hanumaan's Wave 1 has stabilised the shared code)

| Id | Module | Owner |
|---|---|---|
| S01 | `sim/tick.gd`: the deterministic simulation clock and the save/load of its state | Haiku |
| S02 | `sim/resources.gd`: stockpiles and resource flows | Haiku |
| S03 | `sim/routes.gd`: spline routes, hauler chains, throughput and bottlenecks | Sonnet |
| S04 | `sim/crews.gd`: assigning crews and their roles | Haiku |
| S05 | `sim/bridge.gd`: sections, alignment, sturdiness and blessing | Sonnet |
| S06 | `sim/ocean.gd`: tides, the current field and storm events | Haiku |
| S07 | `sim/morale.gd` | Haiku |
| S08 | `sim/creatures.gd`: the makara and fish hazard areas | Haiku |
| S09 | `render/crowd.gd`: MultiMesh vanaras and the vertex animation shader | Sonnet |
| S10 | `render/bridge_view.gd`: building the bridge meshes from the simulation state | Haiku |
| S11 | `ui/build_menu.gd` (radial), `ui/hud.gd`, `ui/day_summary.gd` | Haiku |
| S12 | `game/day_flow.gd`: day timing, objectives, scoring and carry-over | Sonnet |
| S13 | `tests/playtest/bot_day.gd`: a bot that plays a day to its target | Sonnet |
| — | Reused: palette, event bus, game state, input, locale, shlokas, mesh kit, synth, music, camera, nature kit | from Hanumaan |

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
