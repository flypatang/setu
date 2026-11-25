class_name Route
extends RefCounted
## A haul route between two stockpiles (DESIGN §9, S05).
## Pure simulation logic: no _process, no RNG, no wall-clock time.

const HAULER_SPEED: float = 1.2
const ITEMS_PER_HANDOFF: int = 1
const TICK_RATE: int = 20
const CROWD_HAULERS_PER_10M: float = 12.0
const NARROW_FACTOR: float = 0.5

var id: String = ""
var kind: String = "stone"
var haulers: int = 0
var points: PackedVector2Array = PackedVector2Array()
## One flag per segment (points.size() - 1): true if the segment is narrow.
var narrow: Array[bool] = []
var from_pile: Stockpile = null
var to_pile: Stockpile = null

## Fractional items accumulated towards the next whole handoff.
var _carry: float = 0.0


func _init(p_id: String = "", p_from: Stockpile = null, p_to: Stockpile = null, p_kind: String = "stone") -> void:
	id = p_id
	from_pile = p_from
	to_pile = p_to
	kind = p_kind


func setup(p_from: Stockpile, p_to: Stockpile, p_kind: String) -> void:
	from_pile = p_from
	to_pile = p_to
	kind = p_kind


## Sets the polyline and per-segment narrow flags (missing flags default to false).
func set_path(p_points: PackedVector2Array, p_narrow: Array[bool] = []) -> void:
	points = p_points
	narrow = []
	for i: int in range(maxi(points.size() - 1, 0)):
		narrow.append(i < p_narrow.size() and p_narrow[i])


func length() -> float:
	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total


func has_narrow() -> bool:
	return narrow.has(true)


## Hauler count above which the route is crowded (12 per 10 m).
func crowd_limit() -> float:
	return CROWD_HAULERS_PER_10M * length() / 10.0


## Multiplier in (0, 1]: 1 up to the crowd limit, falling off beyond it.
func crowding_factor() -> float:
	var limit: float = crowd_limit()
	if haulers <= 0 or float(haulers) <= limit:
		return 1.0
	var ratio: float = limit / float(haulers)
	return ratio * ratio


## Items per tick that the route can carry.
func capacity_per_tick() -> float:
	if haulers <= 0:
		return 0.0
	var rate: float = float(haulers) * HAULER_SPEED / float(TICK_RATE) / maxf(length(), 1.0) * float(ITEMS_PER_HANDOFF)
	if has_narrow():
		rate *= NARROW_FACTOR
	return rate * crowding_factor()


## Moves resources from source to destination. Returns the number of items moved this tick.
func step(_tick: int) -> int:
	if from_pile == null or to_pile == null:
		return 0
	var cap: float = capacity_per_tick()
	if cap <= 0.0:
		return 0
	_carry += cap
	var want: int = floori(_carry)
	if want <= 0:
		return 0
	var taken: int = from_pile.take(kind, want)
	var added: int = to_pile.add(kind, taken)
	if added < taken:
		from_pile.add(kind, taken - added)
	_carry -= float(added)
	# Do not bank throughput that could not be used (empty source or full destination).
	if added < want:
		_carry = minf(_carry, 0.999999)
	return added


func snapshot() -> Dictionary:
	var pts: Array = []
	for p: Vector2 in points:
		pts.append([p.x, p.y])
	var flags: Array = []
	for f: bool in narrow:
		flags.append(f)
	return {"id": id, "kind": kind, "haulers": haulers, "points": pts, "narrow": flags, "carry": _carry}


func restore(data: Dictionary) -> void:
	id = data.get("id", "") as String
	kind = data.get("kind", "stone") as String
	haulers = data.get("haulers", 0) as int
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Variant in data.get("points", []) as Array:
		var pa: Array = p as Array
		pts.append(Vector2(pa[0] as float, pa[1] as float))
	var flags: Array[bool] = []
	for f: Variant in data.get("narrow", []) as Array:
		flags.append(f as bool)
	points = pts
	narrow = flags
	_carry = data.get("carry", 0.0) as float
