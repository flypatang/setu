class_name SimRng
extends RefCounted
## Deterministic seeded PRNG for the simulation (xorshift64*). Pure logic: no global RNG, no wall-clock time.
## Seed 0 is remapped to a fixed non-zero constant, because an all-zero xorshift state never changes.

const _ZERO_SEED_REMAP: int = 2654435769
const _MULTIPLIER: int = 2685821657736338717
const _FNV_OFFSET: int = 1469598103934665603
const _FNV_PRIME: int = 1099511628211

var _seed: int = 0
var _state: int = 0


func _init(seed_value: int = 0) -> void:
	_seed = seed_value
	_state = seed_value if seed_value != 0 else _ZERO_SEED_REMAP


## Logical (unsigned) right shift of a 64-bit int; GDScript's >> is arithmetic for negative values.
func _lsr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


## Returns the next raw 64-bit value (may be negative when read as a signed int).
func next_u64() -> int:
	var x: int = _state
	x = x ^ _lsr(x, 12)
	x = x ^ (x << 25)
	x = x ^ _lsr(x, 27)
	_state = x
	return x * _MULTIPLIER


## Returns a float in [0, 1) with 53 bits of precision.
func next_float() -> float:
	var bits: int = _lsr(next_u64(), 11)
	return float(bits) * (1.0 / 9007199254740992.0)


## Returns an int in the inclusive range [a, b]. If b < a the bounds are swapped.
func range_i(a: int, b: int) -> int:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	var span: int = hi - lo + 1
	var v: int = _lsr(next_u64(), 1) % span
	return lo + v


## Returns a child generator whose seed is derived from this generator's original seed and the label.
## Same seed and label always give the same child; forking does not consume this generator's sequence.
func fork(label: String) -> SimRng:
	var h: int = _FNV_OFFSET
	for b: int in label.to_utf8_buffer():
		h = (h ^ b) * _FNV_PRIME
	return SimRng.new(_seed ^ h)
