class_name Synth
extends RefCounted
## Procedural audio synthesis (DESIGN §7, §9 M06). Produces stereo sample buffers at 44100 Hz.
##
## Buffers are PackedVector2Array: x = left sample, y = right sample, each in [-1, 1].
## Envelope dictionary keys (all optional):
##   "attack"  (float, seconds, default 0.01)  linear rise from 0 to 1
##   "decay"   (float, seconds, default 0.0)   fall from 1 to "sustain"
##   "sustain" (float 0..1, default 1.0)       level held until the release
##   "release" (float, seconds, default 0.01)  linear fall to 0 at the end of the buffer
##   "gain"    (float 0..1, default 0.5)       output amplitude
##   "seed"    (int, default 1234)             noise seed, for deterministic output
## Wave ids for tone(): 0 = sine, 1 = square, 2 = sawtooth, 3 = triangle.

const SAMPLE_RATE: int = 44100
const DEFAULT_SEED: int = 1234


static func _env_float(env: Dictionary, key: String, fallback: float) -> float:
	if env.has(key):
		var raw: Variant = env[key]
		if raw is int:
			return float(raw as int)
		if raw is float:
			return raw as float
	return fallback


static func _envelope(t: float, dur: float, env: Dictionary) -> float:
	var attack: float = maxf(_env_float(env, "attack", 0.01), 0.0)
	var decay: float = maxf(_env_float(env, "decay", 0.0), 0.0)
	var sustain: float = clampf(_env_float(env, "sustain", 1.0), 0.0, 1.0)
	var release: float = maxf(_env_float(env, "release", 0.01), 0.0)
	var level: float = 1.0
	if attack > 0.0 and t < attack:
		level = t / attack
	elif decay <= 0.0:
		level = sustain
	else:
		level = lerpf(1.0, sustain, clampf((t - attack) / decay, 0.0, 1.0))
	if release > 0.0 and t > dur - release:
		level *= clampf((dur - t) / release, 0.0, 1.0)
	return clampf(level, 0.0, 1.0)


static func _frame_count(dur: float) -> int:
	return maxi(roundi(maxf(dur, 0.0) * SAMPLE_RATE), 0)


static func tone(freq: float, dur: float, wave: int, env: Dictionary) -> PackedVector2Array:
	var count: int = _frame_count(dur)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(count)
	var gain: float = clampf(_env_float(env, "gain", 0.5), 0.0, 1.0)
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var phase: float = fposmod(freq * t, 1.0)
		var w: float = 0.0
		match wave:
			1:
				w = 1.0 if phase < 0.5 else -1.0
			2:
				w = 2.0 * phase - 1.0
			3:
				w = 4.0 * absf(phase - 0.5) - 1.0
			_:
				w = sin(TAU * phase)
		var s: float = clampf(w * _envelope(t, dur, env) * gain, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


static func noise(dur: float, env: Dictionary, filter_hz: float) -> PackedVector2Array:
	var count: int = _frame_count(dur)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(count)
	var gain: float = clampf(_env_float(env, "gain", 0.5), 0.0, 1.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = roundi(_env_float(env, "seed", float(DEFAULT_SEED)))
	# One-pole low-pass coefficient; a non-positive cutoff leaves the noise unfiltered.
	var alpha: float = 1.0
	if filter_hz > 0.0:
		alpha = 1.0 - exp(-TAU * filter_hz / SAMPLE_RATE)
	var y: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var x: float = rng.randf() * 2.0 - 1.0
		y += alpha * (x - y)
		var s: float = clampf(y * _envelope(t, dur, env) * gain, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


static func mix(buffers: Array) -> PackedVector2Array:
	var length: int = 0
	for buf: Variant in buffers:
		var typed: PackedVector2Array = buf as PackedVector2Array
		length = maxi(length, typed.size())
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(length)
	for buf: Variant in buffers:
		var typed: PackedVector2Array = buf as PackedVector2Array
		for i: int in range(typed.size()):
			out[i] = out[i] + typed[i]
	for i: int in range(length):
		var s: Vector2 = out[i]
		out[i] = Vector2(clampf(s.x, -1.0, 1.0), clampf(s.y, -1.0, 1.0))
	return out


static func to_stream(buf: PackedVector2Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(buf.size() * 4)
	for i: int in range(buf.size()):
		var s: Vector2 = buf[i]
		data.encode_s16(i * 4, roundi(clampf(s.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, roundi(clampf(s.y, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = true
	stream.data = data
	return stream
