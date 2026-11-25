class_name Ocean
extends RefCounted
## The sea (DESIGN §4.5, §9 S09): tides, the current field and scripted storms.
## Pure simulation logic: no _process, no RNG, no wall-clock time. Every query is a
## pure function of its arguments and the storms set by set_storms().

const TIDE_PERIOD_TICKS: int = 2400
const TIDE_AMPLITUDE_M: float = 0.6
const BASE_SHORE: float = 0.1
const BASE_PEAK: float = 1.0
const PEAK_X_M: float = 500.0

## Each storm is {start: int, duration: int, strength: float}. Active for ticks in [start, start + duration).
var _storms: Array[Dictionary] = []


## Tide height in metres at the given tick: a sinusoid with a 2,400-tick period and ±0.6 m amplitude.
func tide(tick: int) -> float:
	var phase: float = TAU * float(tick) / float(TIDE_PERIOD_TICKS)
	return TIDE_AMPLITUDE_M * sin(phase)


## Replaces the scripted storms. The input is copied, so later changes to the caller's array have no effect.
func set_storms(storms: Array[Dictionary]) -> void:
	_storms = []
	for storm: Dictionary in storms:
		_storms.append(storm.duplicate())


## Storm strength at a tick: the largest strength among the storms active at that tick, or 0.0 if none is.
func storm_strength_at(tick: int) -> float:
	var strongest: float = 0.0
	for storm: Dictionary in _storms:
		var start: int = storm.get("start", 0) as int
		var duration: int = storm.get("duration", 0) as int
		var strength: float = storm.get("strength", 0.0) as float
		if tick >= start and tick < start + duration:
			strongest = maxf(strongest, strength)
	return strongest


## Current force at distance x (metres from shore) and tick: base(x) * (1 + storm strength).
func current_at(x: float, tick: int) -> float:
	return _base_current(x) * (1.0 + storm_strength_at(tick))


## Storm-free current profile: smoothstep from 0.1 at the shore to 1.0 at x = 500 m, then symmetrically back to 0.1 at x = 1000 m.
func _base_current(x: float) -> float:
	var distance_to_peak: float = absf(x - PEAK_X_M)
	var t: float = clampf(1.0 - distance_to_peak / PEAK_X_M, 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	return BASE_SHORE + (BASE_PEAK - BASE_SHORE) * eased
