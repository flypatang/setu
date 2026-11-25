# Day files (`data/days/day_<n>.json`)

Loaded by `game/day_flow.gd` (`DayFlow.load_day(dict, carry_in)`). All lengths are in metres
(1 game-yojana = 10 m; 1 section = 1 m). Ticks run at 20 Hz; a day is 9,600 ticks.

| Key | Type | Meaning |
|---|---|---|
| `day` | int | Day number 1..5 |
| `target_yojanas` | int | The day's base target. The effective target is `target_yojanas * 10 + carry_in` (length missed on the previous day) |
| `day_ticks` | int | Sunset tick, default 9600 |
| `total_crews` | int | Crews (10 vanaras each) available. Producer crews and hauler crews (`ceil(haulers / 10)` per route) both draw from this pool |
| `rama_present` | bool | Morale effect `rama_present` (+0.02/tick) |
| `night_from` | int | Tick from which the night morale effect applies; -1 for none |
| `piles` | array | Stockpiles, see below. A pile with id `head` is the bridge head (created if missing) |
| `storms` | array | `{start, duration, strength}` passed to `Ocean.set_storms` |
| `creatures` | array | `{x_from, x_to, active_until, kind}` zones; building is blocked while a zone covering the bridge head is active |
| `events` | array | `{tick, id, dialogue?}`; when the tick is reached `id` is added to `DayFlow.events_fired()` (UI/dialogue hooks) |

## Pile
`{ "id": str, "role": "cutter"|"lumberjack"|"lasher"|"scribe"|"builder", "pos": [x, z], "stock": {kind: n} }`
Piles are also the crew sites: `assign_crews {role, site: <pile id>}`. The shore is at x = 0 and the bridge runs along +x.

## Command plans (`tests/unit/fixtures/plan_day1.json`)
`{ "day": n, "commands": [ {tick, type, args} ] }` with the S12 command types:
`draw_route {id, from, to, kind, points: [[x,z],...], haulers}`, `assign_crews {role, site, crews}`,
`build_station {kind, pos}`, `place_measuring_line {deg}`, `ring_gong {id}`, `chant_jaya {}`.
Load with `DayFlow.queue_commands(commands)`; they are applied at their tick (equal ticks keep file order).
