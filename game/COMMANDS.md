# Player commands (S12)

Every player action is a command object `{tick, type, args}`. S11 (`game/day_flow.gd`) applies each command at its
`tick`. This module only validates, records and replays commands. It never applies them.

Code: `game/player_commands.gd`, `class_name PlayerCommands`. It holds two inner classes:
`PlayerCommands.Command` and `PlayerCommands.CommandLog`.

## Command

- `tick: int`: the simulation tick, must be >= 0.
- `type: StringName`: one of the types below.
- `args: Dictionary`: arguments for that type.
- `to_dict()`: returns `{"tick": int, "type": String, "args": Dictionary}`, with args normalised.
- `Command.from_dict(d)`: rebuilds a command. JSON numbers are normalised, so counts are `int` and coordinates are `float`.

## Command types

| type | args | Notes |
|---|---|---|
| `draw_route` | `id: String`, `from: String` (pile id), `to: String` (pile id), `kind: String`, `points: [[x, z], ...]` (at least 2), `haulers: int` (>= 1) | Draws a haul route along a spline. |
| `assign_crews` | `role: String` (`cutter`, `lumberjack`, `lasher`, `scribe`, `hauler`, `builder`), `site: String`, `crews: int` (>= 1) | Each crew is 10 vanaras. |
| `build_station` | `kind: String` (`lekhan`, `gong`, `shelter`), `pos: [x, z]` | |
| `place_measuring_line` | `deg: float` in [-180, 180] | Sets the alignment line. |
| `ring_gong` | `id: String` (non-empty) | Activates a gong. |
| `chant_jaya` | none | Takes no args. Any extra key is a problem. |

Coordinates `[x, z]` are in metres. Both numbers must be finite.

## Validation

`PlayerCommands.validate(cmd: Command) -> Array[String]` returns a list of problems. An empty array means the command is valid.
It reports a negative tick, an unknown type, missing args, unknown args and bad values for each arg.

## CommandLog

- `record(cmd)`: appends a command. Commands at the same tick keep their record order.
- `count() -> int`, `all() -> Array[Command]`.
- `commands_at(tick) -> Array[Command]`: the commands at exactly that tick, in record order.
- `to_json() -> String`: a JSON array of `to_dict()` entries.
- `PlayerCommands.CommandLog.from_json(text) -> CommandLog`: returns an empty log if the text is not a JSON array.
- `state_hash() -> String`: the StateHash of the whole log. The determinism gate compares this before and after a
  record-and-replay round trip.
