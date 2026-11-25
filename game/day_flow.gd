class_name DayFlow
extends RefCounted
## Runs one day of the game: owns the SimClock and every simulation system,
## applies player commands at their tick, and scores the day (DESIGN §9, S11).
## Pure simulation logic: no _process, no global RNG, no wall-clock time.

const DEFAULT_DAY_TICKS: int = 9600
const METERS_PER_YOJANA: int = 10
const SECTION_MARGIN: int = 10
const CURRENT_EVERY_TICKS: int = 20
const HAULERS_PER_CREW: int = 10
const NODE_RADIUS_M: float = 15.0
## Lekhan and ropeworks must be on the near shore: x strictly below this (data/days/SCHEMA.md,
## 'Resource nodes'). x == 0 (the bridge head start) is deliberately rejected.
const SHORE_MAX_X: float = 0.0
const ALIGN_TOLERANCE_DEG: float = 2.0
const W_LENGTH: float = 0.5
const W_ALIGN: float = 0.2
const W_WASTE: float = 0.15
const W_MORALE: float = 0.15

var day: int = 1
var target_m: int = 0
var day_ticks: int = DEFAULT_DAY_TICKS
var carry_in_m: int = 0

var clock: SimClock = SimClock.new()
var crews: Crews = Crews.new(0)
var morale: Morale = Morale.new()
var ocean: Ocean = Ocean.new()
var creatures: Creatures = Creatures.new()
var bridge: Bridge = null

var _piles: Dictionary = {}
var _pile_pos: Dictionary = {}
var _pile_ids: Array[String] = []
var _routes: Dictionary = {}
var _route_ids: Array[String] = []
var _station_count: int = 0
var _events: Array[Dictionary] = []
var _fired: Array[String] = []
var _queue: Array[Dictionary] = []
var _cmd_index: int = 0
var _rama_present: bool = false
var _night_from: int = -1
var _morale_sum: float = 0.0
var _morale_ticks: int = 0
var _prev_length: int = 0
var _blessed: bool = false
var _nodes: Dictionary = {}


## Loads a day description (the parsed data/days/day_<n>.json). carry_in is the
## length (m) missed on the previous day; it is added to this day's target.
func load_day(d: Dictionary, carry_in: int = 0) -> void:
	day = _int(d.get("day", 1))
	carry_in_m = maxi(carry_in, 0)
	target_m = _int(d.get("target_yojanas", 0)) * METERS_PER_YOJANA + carry_in_m
	day_ticks = _int(d.get("day_ticks", DEFAULT_DAY_TICKS))
	_rama_present = d.get("rama_present", false) as bool
	_night_from = _int(d.get("night_from", -1))
	clock = SimClock.new()
	crews = Crews.new(_int(d.get("total_crews", 0)))
	morale = Morale.new()
	ocean = Ocean.new()
	creatures = Creatures.new()
	_piles = {}
	_pile_pos = {}
	_pile_ids = []
	_routes = {}
	_route_ids = []
	_station_count = 0
	_fired = []
	_queue = []
	_cmd_index = 0
	_morale_sum = 0.0
	_morale_ticks = 0
	_prev_length = 0
	_blessed = false
	_nodes = {}
	var rn: Dictionary = d.get("resource_nodes", {}) as Dictionary
	for k: Variant in rn.keys():
		var pts: Array[Vector2] = []
		for n: Variant in rn[k] as Array:
			var na: Array = n as Array
			pts.append(Vector2(_num(na[0]), _num(na[1])))
		_nodes[str(k)] = pts
	for p: Variant in d.get("piles", []) as Array:
		_load_pile(p as Dictionary)
	var head: Stockpile = _piles.get("head", null) as Stockpile
	if head == null:
		head = Stockpile.new()
		_piles["head"] = head
		_pile_ids.append("head")
		_pile_pos["head"] = Vector2.ZERO
	bridge = Bridge.new(head, target_m + SECTION_MARGIN)
	var storms: Array[Dictionary] = []
	for s: Variant in d.get("storms", []) as Array:
		storms.append(s as Dictionary)
	ocean.set_storms(storms)
	for c: Variant in d.get("creatures", []) as Array:
		var cd: Dictionary = c as Dictionary
		creatures.add_zone(_num(cd.get("x_from", 0.0)), _num(cd.get("x_to", 0.0)),
			_int(cd.get("active_until", 0)), str(cd.get("kind", "makara")))
	_events = []
	for e: Variant in d.get("events", []) as Array:
		_events.append(e as Dictionary)
	clock.register(crews)
	clock.register(creatures)
	clock.register(bridge)
	clock.register(morale)


## Queues commands ({tick, type, args} dictionaries) to be applied at their tick.
## Equal ticks keep their queued order.
func queue_commands(cmds: Array) -> void:
	for c: Variant in cmds:
		var cd: Dictionary = c as Dictionary
		var at: int = _queue.size()
		while at > _cmd_index and _int(_queue[at - 1].get("tick", 0)) > _int(cd.get("tick", 0)):
			at -= 1
		_queue.insert(at, cd)


## Applies one command immediately. Returns false when it is invalid or refused.
func apply_command(cmd: Dictionary) -> bool:
	var type: String = str(cmd.get("type", ""))
	var args: Dictionary = cmd.get("args", {}) as Dictionary
	match type:
		"draw_route":
			return _cmd_draw_route(args)
		"assign_crews":
			if not _assign_allowed(str(args.get("role", "")), str(args.get("site", ""))):
				return false
			return crews.assign(StringName(str(args.get("role", ""))),
				StringName(str(args.get("site", ""))), _int(args.get("crews", 0)))
		"build_station":
			return _cmd_build_station(args)
		"place_measuring_line":
			bridge.set_alignment(_num(args.get("deg", 0.0)))
			return true
		"ring_gong":
			var head: Stockpile = _piles["head"] as Stockpile
			return creatures.build_gong(_int(args.get("id", -1)), head)
		"chant_jaya":
			return morale.chant(clock.tick)
	return false


func is_over() -> bool:
	return clock.tick >= day_ticks


func tick() -> int:
	return clock.tick


func pile(id: String) -> Stockpile:
	return _piles.get(id, null) as Stockpile


func route(id: String) -> Route:
	return _routes.get(id, null) as Route


func events_fired() -> Array[String]:
	return _fired.duplicate()


func run_ticks(n: int) -> void:
	var left: int = n
	while left > 0 and not is_over():
		_step_one()
		left -= 1
	if is_over():
		_finish()


func carry_over() -> int:
	return maxi(target_m - bridge.length_m(), 0)


## Target for the next day: its base target plus whatever this day missed.
func next_day_target(base_yojanas: int) -> int:
	return base_yojanas * METERS_PER_YOJANA + carry_over()


func morale_avg() -> float:
	if _morale_ticks <= 0:
		return morale.utsaha
	return _morale_sum / float(_morale_ticks)


func score() -> Dictionary:
	var complete: int = 0
	var aligned: int = 0
	var stone_built: int = 0
	for i: int in bridge.section_count():
		var s: Bridge.Section = bridge.section(i)
		if s.complete and not s.broken:
			complete += 1
			if absf(s.alignment_deg) <= ALIGN_TOLERANCE_DEG:
				aligned += 1
			stone_built += s.stone_in
	return score_from(bridge.length_m(), target_m, aligned, complete,
		bridge.wasted_stone(), stone_built, morale_avg())


## Pure score maths. length_pct and alignment_pct: higher is better; waste_pct: lower is better.
static func score_from(length_m: int, target: int, aligned: int, complete: int,
		wasted_stone: int, built_stone: int, morale_average: float) -> Dictionary:
	var length_pct: float = 100.0 if target <= 0 else clampf(100.0 * float(length_m) / float(target), 0.0, 100.0)
	var alignment_pct: float = 0.0 if complete <= 0 else 100.0 * float(aligned) / float(complete)
	var used: int = wasted_stone + built_stone
	var waste_pct: float = 0.0 if used <= 0 else 100.0 * float(wasted_stone) / float(used)
	var m: float = clampf(morale_average, 0.0, 100.0)
	var total: float = W_LENGTH * length_pct + W_ALIGN * alignment_pct \
		+ W_WASTE * (100.0 - waste_pct) + W_MORALE * m
	return {
		"length_pct": length_pct, "alignment_pct": alignment_pct, "waste_pct": waste_pct,
		"morale_avg": m, "total": clampf(total, 0.0, 100.0),
	}


func snapshot() -> Dictionary:
	var piles: Dictionary = {}
	for id: String in _pile_ids:
		var p: Stockpile = _piles[id] as Stockpile
		var counts: Dictionary = {}
		for kind: String in Stockpile.KINDS:
			counts[kind] = p.count(kind)
		piles[id] = counts
	var routes: Dictionary = {}
	for id: String in _route_ids:
		routes[id] = (_routes[id] as Route).snapshot()
	return {
		"day": day, "target_m": target_m, "clock": clock.snapshot(), "crews": crews.snapshot(),
		"morale": morale.snapshot(), "bridge": bridge.snapshot(), "creatures": creatures.snapshot(),
		"piles": piles, "routes": routes, "fired": _fired.duplicate(), "cmd_index": _cmd_index,
		"morale_sum": _morale_sum, "morale_ticks": _morale_ticks, "prev_length": _prev_length,
		"blessed": _blessed, "stations": _station_count,
	}


func state_hash() -> String:
	return StateHash.hash_state(snapshot())


# --- internals -------------------------------------------------------------

static func _num(v: Variant) -> float:
	match typeof(v):
		TYPE_INT:
			return float(v as int)
		TYPE_FLOAT:
			return v as float
	return 0.0


static func _int(v: Variant) -> int:
	return roundi(_num(v))


func _load_pile(p: Dictionary) -> void:
	var id: String = str(p.get("id", ""))
	if id == "" or _piles.has(id):
		return
	var stock: Stockpile = Stockpile.new()
	var start: Dictionary = p.get("stock", {}) as Dictionary
	for kind: Variant in start.keys():
		stock.add(str(kind), _int(start[kind]))
	_piles[id] = stock
	_pile_ids.append(id)
	var pos: Array = p.get("pos", [0.0, 0.0]) as Array
	_pile_pos[id] = Vector2(_num(pos[0]), _num(pos[1]))
	crews.register_site(StringName(id), stock, StringName(str(p.get("role", ""))))


func _cmd_draw_route(args: Dictionary) -> bool:
	var id: String = str(args.get("id", ""))
	var from_id: String = str(args.get("from", ""))
	var to_id: String = str(args.get("to", ""))
	var kind: String = str(args.get("kind", "stone"))
	var haulers: int = _int(args.get("haulers", 0))
	if id == "" or _routes.has(id) or haulers <= 0 or not Stockpile.is_known_kind(kind):
		return false
	if not _piles.has(from_id) or not _piles.has(to_id):
		return false
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Variant in args.get("points", []) as Array:
		var pa: Array = p as Array
		pts.append(Vector2(_num(pa[0]), _num(pa[1])))
	if pts.size() < 2:
		return false
	var site: StringName = StringName("route_" + id)
	if not crews.register_site(site, _piles[from_id] as Stockpile, &"hauler"):
		return false
	var need: int = ceili(float(haulers) / float(HAULERS_PER_CREW))
	if not crews.assign(&"hauler", site, need):
		return false
	var r: Route = Route.new(id, _piles[from_id] as Stockpile, _piles[to_id] as Stockpile, kind)
	r.haulers = haulers
	r.set_path(pts)
	_routes[id] = r
	_route_ids.append(id)
	clock.register(r)
	return true


func _cmd_build_station(args: Dictionary) -> bool:
	var kind: String = str(args.get("kind", ""))
	var roles: Dictionary = {"quarry": &"cutter", "forest": &"lumberjack", "ropeworks": &"lasher", "lekhan": &"scribe"}
	if not roles.has(kind):
		return false
	var pos: Array = args.get("pos", [0.0, 0.0]) as Array
	var at: Vector2 = Vector2(_num(pos[0]), _num(pos[1]))
	if (kind == "quarry" or kind == "forest") and not _near_node(kind, at):
		return false
	if (kind == "lekhan" or kind == "ropeworks") and at.x >= SHORE_MAX_X:
		return false
	_station_count += 1
	var id: String = "%s_%d" % [kind, _station_count]
	_load_pile({"id": id, "role": str(roles[kind]), "pos": pos})
	return _piles.has(id)


## True when some node of this kind lies within NODE_RADIUS_M of at.
func _near_node(kind: String, at: Vector2) -> bool:
	for n: Vector2 in _nodes.get(kind, [] as Array[Vector2]) as Array[Vector2]:
		if n.distance_to(at) <= NODE_RADIUS_M:
			return true
	return false


func _assign_allowed(role: String, site: String) -> bool:
	var kind: String = ""
	if role == "cutter":
		kind = "quarry"
	elif role == "lumberjack":
		kind = "forest"
	else:
		return true
	if not _pile_pos.has(site):
		return true  # unknown site: intentionally left to crews.assign to reject
	return _near_node(kind, _pile_pos[site] as Vector2)


func _step_one() -> void:
	var t: int = clock.tick
	_apply_due_commands(t)
	_fire_events(t)
	var effects: Dictionary = {
		"night": _night_from >= 0 and t >= _night_from,
		"storm": ocean.storm_strength_at(t) > 0.0,
		"rama_present": _rama_present,
		"crowding": _any_crowded(),
	}
	morale.set_effects(effects)
	crews.set_morale_factor(morale.factor())
	var head_x: float = float(_prev_length)
	if creatures.is_span_blocked(head_x, head_x + 1.0):
		# Building is blocked; keep the head stockpile untouched this tick.
		_step_blocked(t)
	else:
		clock.step_all()
	_morale_sum += morale.utsaha
	_morale_ticks += 1
	var length_now: int = bridge.length_m()
	if length_now > _prev_length:
		morale.record_sections_completed(length_now - _prev_length)
	_prev_length = length_now
	if t % CURRENT_EVERY_TICKS == 0:
		bridge.apply_current(ocean.current_at(float(_prev_length), t))


func _step_blocked(t: int) -> void:
	# Everything except the bridge head advances while a creature zone blocks it.
	crews.step(t)
	creatures.step(t)
	morale.step(t)
	for id: String in _route_ids:
		(_routes[id] as Route).step(t)
	clock.tick += 1


func _apply_due_commands(t: int) -> void:
	while _cmd_index < _queue.size() and _int(_queue[_cmd_index].get("tick", 0)) <= t:
		apply_command(_queue[_cmd_index])
		_cmd_index += 1


func _fire_events(t: int) -> void:
	for e: Dictionary in _events:
		if _int(e.get("tick", 0)) == t:
			_fired.append(str(e.get("id", "")))


func _any_crowded() -> bool:
	for id: String in _route_ids:
		if (_routes[id] as Route).crowding_factor() < 1.0:
			return true
	return false


func _finish() -> void:
	if _blessed:
		return
	_blessed = true
	bridge.bless_all_complete()
