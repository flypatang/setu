class_name SimClock
extends RefCounted
## Fixed-tick clock for the simulation (DESIGN §8, §9 S01). Runs at 20 Hz; speed scales how many ticks
## each real second yields. Pure logic: no _process, no wall clock, advances only when asked.

const TICK_RATE: int = 20
const MAX_SPEED: int = 3
const _EPSILON: float = 0.000000001

## Current simulation tick. step_all() passes it to each system, then increments it.
var tick: int = 0

## 0 = paused, 1, 2, 3 = speed multiplier. Values outside 0..MAX_SPEED are clamped.
var speed: int = 0:
	set(value):
		speed = clampi(value, 0, MAX_SPEED)

var _systems: Array[Object] = []
## Fractional ticks carried between advance() calls.
var _accum: float = 0.0


## Returns how many fixed ticks to run for this real-time delta. Does not step systems itself.
func advance(real_delta: float) -> int:
	if speed <= 0 or real_delta <= 0.0:
		return 0
	_accum += real_delta * float(speed) * float(TICK_RATE)
	var count: int = floori(_accum + _EPSILON)
	_accum -= float(count)
	if _accum < 0.0:
		_accum = 0.0
	return count


## Adds a system whose step(tick: int) method is called by step_all(). Duplicates are ignored.
func register(system: Object) -> void:
	if system != null and not _systems.has(system):
		_systems.append(system)


## Calls step(tick) on every registered system in registration order, then advances the tick by one.
func step_all() -> void:
	for system: Object in _systems:
		if system.has_method("step"):
			system.call("step", tick)
	tick += 1


func snapshot() -> Dictionary:
	return {"tick": tick, "speed": speed, "accum": _accum}


func restore(data: Dictionary) -> void:
	var tick_value: Variant = data.get("tick", 0)
	var speed_value: Variant = data.get("speed", 0)
	var accum_value: Variant = data.get("accum", 0.0)
	tick = tick_value as int
	speed = speed_value as int
	_accum = accum_value as float
