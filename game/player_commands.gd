class_name PlayerCommands
extends RefCounted
## S12: every player action as a command object {tick, type, args} (DESIGN §9 S12).
## Pure logic: validates and records commands, never applies them (S11 does that).
## One class_name per file, so Command and CommandLog are inner classes:
## reach them as PlayerCommands.Command and PlayerCommands.CommandLog.
## See game/COMMANDS.md for the argument reference.

const TYPE_DRAW_ROUTE: String = "draw_route"
const TYPE_ASSIGN_CREWS: String = "assign_crews"
const TYPE_BUILD_STATION: String = "build_station"
const TYPE_PLACE_MEASURING_LINE: String = "place_measuring_line"
const TYPE_RING_GONG: String = "ring_gong"
const TYPE_CHANT_JAYA: String = "chant_jaya"

const ROLES: Array[String] = ["cutter", "lumberjack", "lasher", "scribe", "hauler", "builder"]
const STATION_KINDS: Array[String] = ["lekhan", "gong", "shelter"]
const MAX_ANGLE_DEG: float = 180.0

## type -> {arg_name: kind}. Kinds: id, role, station, count, point, points, angle.
const SPECS: Dictionary = {
	"draw_route": {"id": "id", "from": "id", "to": "id", "kind": "id", "points": "points", "haulers": "count"},
	"assign_crews": {"role": "role", "site": "id", "crews": "count"},
	"build_station": {"kind": "station", "pos": "point"},
	"place_measuring_line": {"deg": "angle"},
	"ring_gong": {"id": "id"},
	"chant_jaya": {},
}


## Returns a list of human-readable problems; an empty array means the command is valid.
static func validate(cmd: PlayerCommands.Command) -> Array[String]:
	var problems: Array[String] = []
	if cmd.tick < 0:
		problems.append("tick must be >= 0, got %d" % cmd.tick)
	var type_name: String = String(cmd.type)
	if not SPECS.has(type_name):
		problems.append("unknown command type '%s'" % type_name)
		return problems
	var spec: Dictionary = SPECS[type_name] as Dictionary
	for key: Variant in spec.keys():
		var key_str: String = str(key)
		if not cmd.args.has(key_str):
			problems.append("%s: missing arg '%s'" % [type_name, key_str])
			continue
		_check_value(type_name, key_str, spec[key] as String, cmd.args[key_str], problems)
	for key: Variant in cmd.args.keys():
		if not spec.has(str(key)):
			problems.append("%s: unknown arg '%s'" % [type_name, str(key)])
	return problems


## Returns args with JSON-friendly normalisation: counts become int, coordinates and angles float.
static func normalize_args(type_name: String, args: Dictionary) -> Dictionary:
	var spec: Dictionary = SPECS.get(type_name, {}) as Dictionary
	var out: Dictionary = {}
	for key: Variant in args.keys():
		var key_str: String = str(key)
		var kind: String = str(spec.get(key_str, ""))
		out[key_str] = _normalize_value(kind, args[key])
	return out


static func _normalize_value(kind: String, v: Variant) -> Variant:
	match kind:
		"count":
			if _is_number(v):
				return _to_int(v)
		"angle":
			if _is_number(v):
				return _to_float(v)
		"point":
			if v is Array:
				return _normalize_point(v as Array)
		"points":
			if v is Array:
				var pts: Array = []
				for p: Variant in v as Array:
					pts.append(_normalize_point(p as Array) if p is Array else p)
				return pts
	return v


static func _normalize_point(p: Array) -> Array:
	var out: Array = []
	for c: Variant in p:
		out.append(_to_float(c) if _is_number(c) else c)
	return out


static func _check_value(type_name: String, key: String, kind: String, v: Variant, problems: Array[String]) -> void:
	var label: String = "%s: arg '%s'" % [type_name, key]
	match kind:
		"id":
			if not _is_text(v) or str(v).is_empty():
				problems.append("%s must be a non-empty string" % label)
		"role":
			if not _is_text(v) or not ROLES.has(str(v)):
				problems.append("%s must be one of %s" % [label, str(ROLES)])
		"station":
			if not _is_text(v) or not STATION_KINDS.has(str(v)):
				problems.append("%s must be one of %s" % [label, str(STATION_KINDS)])
		"count":
			if not _is_number(v) or not _is_whole(v) or _to_int(v) < 1:
				problems.append("%s must be a whole number >= 1" % label)
		"angle":
			if not _is_finite_number(v) or absf(_to_float(v)) > MAX_ANGLE_DEG:
				problems.append("%s must be a number in [-%s, %s]" % [label, MAX_ANGLE_DEG, MAX_ANGLE_DEG])
		"point":
			if not _is_point(v):
				problems.append("%s must be [x, z] with finite numbers" % label)
		"points":
			if not (v is Array) or (v as Array).size() < 2:
				problems.append("%s must be an array of at least 2 points" % label)
			else:
				for p: Variant in v as Array:
					if not _is_point(p):
						problems.append("%s contains an invalid point" % label)
						break


static func _is_point(v: Variant) -> bool:
	if not (v is Array):
		return false
	var a: Array = v as Array
	return a.size() == 2 and _is_finite_number(a[0]) and _is_finite_number(a[1])


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _is_finite_number(v: Variant) -> bool:
	if not _is_number(v):
		return false
	var f: float = _to_float(v)
	return not is_nan(f) and not is_inf(f)


static func _is_whole(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or floorf(_to_float(v)) == _to_float(v)


static func _to_float(v: Variant) -> float:
	if typeof(v) == TYPE_INT:
		return float(v as int)
	return v as float


static func _to_int(v: Variant) -> int:
	if typeof(v) == TYPE_FLOAT:
		return int(v as float)
	return v as int


static func _is_text(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


class Command extends RefCounted:
	## One player action, applied by S11 at `tick`.
	var tick: int = 0
	var type: StringName = &""
	var args: Dictionary = {}

	func _init(p_tick: int = 0, p_type: StringName = &"", p_args: Dictionary = {}) -> void:
		tick = p_tick
		type = p_type
		args = p_args.duplicate(true)

	func to_dict() -> Dictionary:
		var type_name: String = String(type)
		return {
			"tick": tick,
			"type": type_name,
			"args": PlayerCommands.normalize_args(type_name, args),
		}

	static func from_dict(d: Dictionary) -> PlayerCommands.Command:
		var type_name: String = str(d.get("type", ""))
		var raw_args: Variant = d.get("args", {})
		var args_dict: Dictionary = raw_args as Dictionary if raw_args is Dictionary else {}
		var cmd: PlayerCommands.Command = PlayerCommands.Command.new(
			PlayerCommands._to_int(d.get("tick", 0)), StringName(type_name), args_dict
		)
		cmd.args = PlayerCommands.normalize_args(type_name, args_dict)
		return cmd


class CommandLog extends RefCounted:
	## Ordered record of commands. Commands at the same tick keep their record order.
	var _commands: Array[PlayerCommands.Command] = []

	func record(cmd: PlayerCommands.Command) -> void:
		_commands.append(cmd)

	func count() -> int:
		return _commands.size()

	func all() -> Array[PlayerCommands.Command]:
		var out: Array[PlayerCommands.Command] = []
		out.append_array(_commands)
		return out

	func commands_at(tick: int) -> Array[PlayerCommands.Command]:
		var out: Array[PlayerCommands.Command] = []
		for cmd: PlayerCommands.Command in _commands:
			if cmd.tick == tick:
				out.append(cmd)
		return out

	func to_json() -> String:
		return JSON.stringify(_dict_array())

	static func from_json(text: String) -> PlayerCommands.CommandLog:
		var log: PlayerCommands.CommandLog = PlayerCommands.CommandLog.new()
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Array):
			return log
		for item: Variant in parsed as Array:
			if item is Dictionary:
				log.record(PlayerCommands.Command.from_dict(item as Dictionary))
		return log

	## Canonical hash of the whole log, for the determinism gate (StateHash).
	func state_hash() -> String:
		return StateHash.hash_state({"commands": _dict_array()})

	func _dict_array() -> Array:
		var out: Array = []
		for cmd: PlayerCommands.Command in _commands:
			out.append(cmd.to_dict())
		return out
