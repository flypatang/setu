class_name Creatures
extends RefCounted
## Sea-creature zones (makara and fish) that block building (DESIGN §4.5, §9 S10).
## A zone covers the half-open span [x_from, x_to) of the bridge line and is active while
## tick < active_until. Gong towers, built near shore, halve a zone's remaining active time
## each, up to MAX_GONGS per zone. Pure simulation logic: no _process, no RNG, no wall-clock
## time. The tick only advances when step(tick) is called.

const MAX_GONGS: int = 3
## Each gong halves the remaining active time (integer halving, rounded down).
const GONG_FACTOR: float = 0.5
## Placeholder build costs for a gong tower; tune in data balancing.
const GONG_ROPE_COST: int = 4
const GONG_TIMBER_COST: int = 6

## Zone records: {id: int, x_from: float, x_to: float, active_until: int, gongs: int}.
var _zones: Array[Dictionary] = []
var _next_id: int = 1
var _tick: int = 0


## Records the current simulation tick. Zone activity is derived from it; nothing else changes.
func step(tick: int) -> void:
	_tick = tick


## Adds a creature zone over [x_from, x_to) that is active until the given tick (exclusive).
## Reversed bounds are swapped. Returns the new zone id.
func add_zone(x_from: float, x_to: float, active_until: int) -> int:
	var lo: float = minf(x_from, x_to)
	var hi: float = maxf(x_from, x_to)
	var id: int = _next_id
	_next_id += 1
	_zones.append({"id": id, "x_from": lo, "x_to": hi, "active_until": active_until, "gongs": 0})
	return id


func is_zone_active(zone_id: int) -> bool:
	return remaining_ticks(zone_id) > 0


## Ticks left before the zone expires, or 0 if it is expired or unknown.
func remaining_ticks(zone_id: int) -> int:
	var zone: Dictionary = _find(zone_id)
	if zone.is_empty():
		return 0
	var until: int = zone["active_until"] as int
	return maxi(until - _tick, 0)


func gong_count(zone_id: int) -> int:
	var zone: Dictionary = _find(zone_id)
	if zone.is_empty():
		return 0
	return zone["gongs"] as int


## True if the point x lies inside any active zone. Building at x is blocked.
func is_blocked_at(x: float) -> bool:
	for zone: Dictionary in _zones:
		if _zone_is_active(zone) and x >= (zone["x_from"] as float) and x < (zone["x_to"] as float):
			return true
	return false


## True if the span [x_a, x_b) overlaps any active zone. Building over the span is blocked.
func is_span_blocked(x_a: float, x_b: float) -> bool:
	var lo: float = minf(x_a, x_b)
	var hi: float = maxf(x_a, x_b)
	for zone: Dictionary in _zones:
		if not _zone_is_active(zone):
			continue
		if lo < (zone["x_to"] as float) and hi > (zone["x_from"] as float):
			return true
	return false


## Builds a gong tower for an active zone, paying the rope and timber cost from stock.
## Refused (returns false, nothing spent) if the zone is unknown or expired, has MAX_GONGS
## gongs already, or stock cannot cover both costs. On success the remaining active time is halved.
func build_gong(zone_id: int, stock: Stockpile) -> bool:
	var zone: Dictionary = _find(zone_id)
	if zone.is_empty() or stock == null:
		return false
	if not _zone_is_active(zone):
		return false
	if (zone["gongs"] as int) >= MAX_GONGS:
		return false
	if stock.count("rope") < GONG_ROPE_COST or stock.count("timber") < GONG_TIMBER_COST:
		return false
	stock.take("rope", GONG_ROPE_COST)
	stock.take("timber", GONG_TIMBER_COST)
	var remaining: int = remaining_ticks(zone_id)
	zone["gongs"] = (zone["gongs"] as int) + 1
	zone["active_until"] = _tick + floori(float(remaining) * GONG_FACTOR)
	return true


func snapshot() -> Dictionary:
	var zones_copy: Array[Dictionary] = []
	for zone: Dictionary in _zones:
		zones_copy.append(zone.duplicate())
	return {"tick": _tick, "next_id": _next_id, "zones": zones_copy}


func restore(data: Dictionary) -> void:
	_tick = (data.get("tick", 0)) as int
	_next_id = (data.get("next_id", 1)) as int
	_zones = []
	var zones_value: Variant = data.get("zones", [])
	if zones_value is Array:
		for item: Variant in zones_value as Array:
			if item is Dictionary:
				_zones.append((item as Dictionary).duplicate())


func _zone_is_active(zone: Dictionary) -> bool:
	return _tick < (zone["active_until"] as int)


func _find(zone_id: int) -> Dictionary:
	for zone: Dictionary in _zones:
		if (zone["id"] as int) == zone_id:
			return zone
	return {}
