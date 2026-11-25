class_name Morale
extends RefCounted
## Shared crew morale, Utsaha (DESIGN §4.4, §9 S08). Scales crew speed through factor().
## Pure simulation logic: no _process, no RNG, no wall-clock time. Advances only when step(tick) is called.

const UTSAHA_MIN: float = 0.0
const UTSAHA_MAX: float = 100.0
const UTSAHA_START: float = 50.0

const FACTOR_MIN: float = 0.6
const FACTOR_MID: float = 1.0
const FACTOR_MAX: float = 1.3

const NIGHT_PER_TICK: float = -0.01
const STORM_PER_TICK: float = -0.03
const CROWDING_PER_TICK: float = -0.02
const RAMA_PER_TICK: float = 0.02
const CHANT_BOOST: float = 15.0
const CHANT_COOLDOWN_TICKS: int = 1200
const PROGRESS_PER_SECTION: float = 0.5

## Morale on the 0..100 scale. Writes are clamped.
var utsaha: float = UTSAHA_START:
	set(value):
		utsaha = clampf(value, UTSAHA_MIN, UTSAHA_MAX)

## Active per-tick effects. Recognised keys: "night", "storm", "crowding", "rama_present" (all bool).
var _effects: Dictionary = {}
## First tick on which the Jaya chant may be used again.
var _chant_ready_tick: int = 0


## Replaces the set of active effects. Unknown keys are ignored by step().
func set_effects(active: Dictionary) -> void:
	_effects = active.duplicate()


## Maps utsaha to a crew speed multiplier: 0 -> 0.6, 50 -> 1.0, 100 -> 1.3, piecewise linear.
func factor() -> float:
	var u: float = clampf(utsaha, UTSAHA_MIN, UTSAHA_MAX)
	if u <= UTSAHA_START:
		return FACTOR_MIN + (FACTOR_MID - FACTOR_MIN) * (u - UTSAHA_MIN) / (UTSAHA_START - UTSAHA_MIN)
	return FACTOR_MID + (FACTOR_MAX - FACTOR_MID) * (u - UTSAHA_START) / (UTSAHA_MAX - UTSAHA_START)


## Applies every active per-tick modifier once.
func step(_tick: int) -> void:
	var delta: float = 0.0
	if _effect_on("night"):
		delta += NIGHT_PER_TICK
	if _effect_on("storm"):
		delta += STORM_PER_TICK
	if _effect_on("crowding"):
		delta += CROWDING_PER_TICK
	if _effect_on("rama_present"):
		delta += RAMA_PER_TICK
	utsaha = utsaha + delta


## True when the Jaya chant is off cooldown at `tick`.
func can_chant(tick: int) -> bool:
	return tick >= _chant_ready_tick


## Uses the Jaya chant: +15 utsaha instantly and a 1,200-tick cooldown. Returns false (no change) on cooldown.
func chant(tick: int) -> bool:
	if not can_chant(tick):
		return false
	utsaha = utsaha + CHANT_BOOST
	_chant_ready_tick = tick + CHANT_COOLDOWN_TICKS
	return true


## Progress bonus: +0.5 utsaha for each bridge section completed.
func record_sections_completed(count: int) -> void:
	if count <= 0:
		return
	utsaha = utsaha + PROGRESS_PER_SECTION * float(count)


func snapshot() -> Dictionary:
	return {"utsaha": utsaha, "chant_ready_tick": _chant_ready_tick, "effects": _effects.duplicate()}


func restore(data: Dictionary) -> void:
	var utsaha_value: Variant = data.get("utsaha", UTSAHA_START)
	var ready_value: Variant = data.get("chant_ready_tick", 0)
	var effects_value: Variant = data.get("effects", {})
	utsaha = utsaha_value as float
	_chant_ready_tick = ready_value as int
	_effects = (effects_value as Dictionary).duplicate()


func _effect_on(key: String) -> bool:
	return _effects.get(key, false) as bool
