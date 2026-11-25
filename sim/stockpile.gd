class_name Stockpile
extends RefCounted
## A bounded store of bridge resources (DESIGN §9, S02).
## Pure simulation logic: no _process, no RNG, no wall-clock time.

signal changed(kind: String, new_count: int)

const KINDS: Array[String] = ["stone", "inscribed_stone", "timber", "rope"]
const DEFAULT_CAPACITY: int = 1000

var _counts: Dictionary = {}
var _capacities: Dictionary = {}


func _init(default_capacity: int = DEFAULT_CAPACITY) -> void:
	for kind: String in KINDS:
		_counts[kind] = 0
		_capacities[kind] = maxi(default_capacity, 0)


static func is_known_kind(kind: String) -> bool:
	return KINDS.has(kind)


func count(kind: String) -> int:
	if not is_known_kind(kind):
		push_error("Stockpile: unknown resource kind '%s'" % kind)
		return 0
	return _counts[kind] as int


func capacity(kind: String) -> int:
	if not is_known_kind(kind):
		push_error("Stockpile: unknown resource kind '%s'" % kind)
		return 0
	return _capacities[kind] as int


func set_capacity(kind: String, n: int) -> void:
	if not is_known_kind(kind):
		push_error("Stockpile: unknown resource kind '%s'" % kind)
		return
	_capacities[kind] = maxi(n, 0)
	var current: int = _counts[kind] as int
	if current > maxi(n, 0):
		_counts[kind] = maxi(n, 0)
		changed.emit(kind, maxi(n, 0))


## Adds up to n items, clamped to the remaining capacity. Returns how many were added.
func add(kind: String, n: int) -> int:
	if not is_known_kind(kind):
		push_error("Stockpile: unknown resource kind '%s'" % kind)
		return 0
	if n < 0:
		push_error("Stockpile: negative amount %d for '%s'" % [n, kind])
		return 0
	var current: int = _counts[kind] as int
	var cap: int = _capacities[kind] as int
	var added: int = mini(n, cap - current)
	if added <= 0:
		return 0
	_counts[kind] = current + added
	changed.emit(kind, current + added)
	return added


## Takes up to n items. Returns how many were actually taken (partial when stock is short).
func take(kind: String, n: int) -> int:
	if not is_known_kind(kind):
		push_error("Stockpile: unknown resource kind '%s'" % kind)
		return 0
	if n < 0:
		push_error("Stockpile: negative amount %d for '%s'" % [n, kind])
		return 0
	var current: int = _counts[kind] as int
	var taken: int = mini(n, current)
	if taken <= 0:
		return 0
	_counts[kind] = current - taken
	changed.emit(kind, current - taken)
	return taken
