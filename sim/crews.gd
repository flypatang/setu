class_name Crews
extends RefCounted
## Crew assignment and production for the vanara work crews (DESIGN §4.2, §9 S06).
## Each crew is a group of CREW_SIZE vanaras. A crew is assigned to a site (a Stockpile registered with a role),
## and each tick the assigned crews produce or convert resources into that site's stockpile.
## Pure simulation logic: no _process, no RNG, no wall-clock time. Advances only when step(tick) is called.

const ROLES: Array[StringName] = [&"cutter", &"lumberjack", &"lasher", &"scribe", &"hauler", &"builder"]
const CREW_SIZE: int = 10
const _EPSILON: float = 0.000001
## Banked fractional production never exceeds this many whole units, so a blocked site does not stockpile work.
const _MAX_BANKED: float = 1.0

var _total: int = 0
var _site_piles: Dictionary = {}
var _site_roles: Dictionary = {}
var _site_order: Array[StringName] = []
var _assigned: Dictionary = {}
var _progress: Dictionary = {}
## Morale factor: a float, or a Callable returning a float that is read on every step. Default 1.0.
var morale_factor: Variant = 1.0


func _init(initial_total: int = 0) -> void:
	_total = maxi(initial_total, 0)


## Units per crew per tick for a role, before the morale factor. Haulers and builders produce nothing here.
static func rate_for(role: StringName) -> float:
	match role:
		&"cutter":
			return 0.05
		&"lumberjack":
			return 0.08
		&"lasher":
			return 0.04
		&"scribe":
			return 0.06
		_:
			return 0.0


func total_crews() -> int:
	return _total


func free_crews() -> int:
	var used: int = 0
	for site_id: StringName in _assigned.keys():
		used += _assigned[site_id] as int
	return maxi(_total - used, 0)


func crews_at(site_id: StringName) -> int:
	return _assigned.get(site_id, 0) as int


## Registers a site. Its production goes into `pile`. Returns false for a duplicate id, a null pile or an unknown role.
func register_site(site_id: StringName, pile: Stockpile, role: StringName) -> bool:
	if pile == null or not ROLES.has(role) or _site_roles.has(site_id):
		return false
	_site_roles[site_id] = role
	_site_piles[site_id] = pile
	_site_order.append(site_id)
	return true


## Assigns `crews` free crews of `role` to a registered site of that role. All or nothing: returns false
## (changing nothing) for an unknown site, a role mismatch, a non-positive count, or too few free crews.
func assign(role: StringName, site_id: StringName, crews: int) -> bool:
	if crews <= 0 or not _site_has_role(site_id, role):
		return false
	if crews > free_crews():
		return false
	_assigned[site_id] = crews_at(site_id) + crews
	return true


## Removes up to `crews` crews of `role` from a site. Returns how many were actually removed.
func unassign(role: StringName, site_id: StringName, crews: int) -> int:
	if crews <= 0 or not _site_has_role(site_id, role):
		return 0
	var current: int = crews_at(site_id)
	var removed: int = mini(crews, current)
	if removed <= 0:
		return 0
	if current - removed == 0:
		_assigned.erase(site_id)
	else:
		_assigned[site_id] = current - removed
	return removed


func set_morale_factor(factor: Variant) -> void:
	morale_factor = factor


## Advances every site by one tick. Production is fractional per tick and converted to whole units in the pile.
## A unit is only produced when its input is present and its output fits, so nothing is created or destroyed
## outside the stated conversions.
func step(_tick: int) -> void:
	var morale: float = _morale_value()
	for site_id: StringName in _site_order:
		var crew_count: int = crews_at(site_id)
		if crew_count <= 0:
			continue
		var role: StringName = _site_roles[site_id] as StringName
		var rate: float = rate_for(role)
		if rate <= 0.0:
			continue
		var pile: Stockpile = _site_piles[site_id] as Stockpile
		var progress: float = (_progress.get(site_id, 0.0) as float) + rate * float(crew_count) * morale
		var possible: int = floori(progress + _EPSILON)
		var units: int = mini(possible, _limit(role, pile))
		if units > 0:
			_produce(role, pile, units)
		progress -= float(units)
		_progress[site_id] = clampf(progress, 0.0, _MAX_BANKED)


func snapshot() -> Dictionary:
	var assigned: Dictionary = {}
	for site_id: StringName in _assigned.keys():
		assigned[str(site_id)] = _assigned[site_id] as int
	var progress: Dictionary = {}
	for site_id: StringName in _progress.keys():
		progress[str(site_id)] = _progress[site_id] as float
	return {"total": _total, "assigned": assigned, "progress": progress}


## Restores assignments and production progress. Sites must already be registered by the owner (their piles are
## not part of the snapshot), and the snapshot is applied in the order the owner registered them.
func restore(data: Dictionary) -> void:
	var total_value: Variant = data.get("total", 0)
	_total = maxi(total_value as int, 0)
	_assigned.clear()
	var assigned_value: Variant = data.get("assigned", {})
	var assigned_data: Dictionary = assigned_value as Dictionary
	for key: Variant in assigned_data.keys():
		var site_id: StringName = StringName(str(key))
		_assigned[site_id] = assigned_data[key] as int
	_progress.clear()
	var progress_value: Variant = data.get("progress", {})
	var progress_data: Dictionary = progress_value as Dictionary
	for key: Variant in progress_data.keys():
		var site_id: StringName = StringName(str(key))
		_progress[site_id] = progress_data[key] as float


func _site_has_role(site_id: StringName, role: StringName) -> bool:
	if not _site_roles.has(site_id):
		return false
	return (_site_roles[site_id] as StringName) == role


func _morale_value() -> float:
	if typeof(morale_factor) == TYPE_CALLABLE:
		var callback: Callable = morale_factor as Callable
		var raw: Variant = callback.call()
		return maxf(_to_float(raw), 0.0)
	return maxf(_to_float(morale_factor), 0.0)


func _to_float(value: Variant) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return value as float
		TYPE_INT:
			return float(value as int)
		_:
			return 0.0


## Largest number of whole units the role can convert this tick, given input stock and output room.
func _limit(role: StringName, pile: Stockpile) -> int:
	match role:
		&"cutter":
			return _room(pile, "stone")
		&"lumberjack":
			return _room(pile, "timber")
		&"lasher":
			return mini(pile.count("timber"), _room(pile, "rope"))
		&"scribe":
			return mini(pile.count("stone"), _room(pile, "inscribed_stone"))
		_:
			return 0


func _room(pile: Stockpile, kind: String) -> int:
	return maxi(pile.capacity(kind) - pile.count(kind), 0)


func _produce(role: StringName, pile: Stockpile, units: int) -> void:
	match role:
		&"cutter":
			pile.add("stone", units)
		&"lumberjack":
			pile.add("timber", units)
		&"lasher":
			pile.take("timber", units)
			pile.add("rope", units)
		&"scribe":
			pile.take("stone", units)
			pile.add("inscribed_stone", units)
