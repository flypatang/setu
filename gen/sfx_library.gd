class_name SfxLibrary
extends RefCounted
## Named sound effects, synthesised at runtime from Synth (DESIGN §7, §9 M11).
##
## Call get_sfx(id) to get a stream. Each stream is built on first request and cached for the
## rest of the session, so the second call returns the same object. Ids: whoosh, impact_light,
## impact_heavy, step, fire_loop, ui_tick, grow, shrink, chant_bell.

static var _cache: Dictionary = {}


static func get_sfx(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id] as AudioStreamWAV
	var stream: AudioStreamWAV = _build(id)
	if stream == null:
		push_error("SfxLibrary: unknown sound id '%s'" % String(id))
		return null
	_cache[id] = stream
	return stream


static func _build(id: StringName) -> AudioStreamWAV:
	match id:
		&"whoosh":
			return _whoosh()
		&"impact_light":
			return _impact_light()
		&"impact_heavy":
			return _impact_heavy()
		&"step":
			return _step()
		&"fire_loop":
			return _fire_loop()
		&"ui_tick":
			return _ui_tick()
		&"grow":
			return _grow()
		&"shrink":
			return _shrink()
		&"chant_bell":
			return _chant_bell()
		_:
			return null


static func _silence(seconds: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(maxi(roundi(seconds * Synth.SAMPLE_RATE), 0))
	return out


static func _after(seconds: float, buf: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = _silence(seconds)
	out.append_array(buf)
	return out


static func _whoosh() -> AudioStreamWAV:
	var buf: PackedVector2Array = Synth.noise(
		0.35, {"attack": 0.05, "decay": 0.3, "sustain": 0.0, "release": 0.05, "gain": 0.4, "seed": 11}, 1200.0)
	return Synth.to_stream(buf)


static func _impact_light() -> AudioStreamWAV:
	var thud: PackedVector2Array = Synth.tone(180.0, 0.12, 0, {"attack": 0.002, "decay": 0.1, "sustain": 0.0, "release": 0.02, "gain": 0.6})
	var crack: PackedVector2Array = Synth.noise(0.08, {"attack": 0.001, "decay": 0.07, "sustain": 0.0, "release": 0.01, "gain": 0.4, "seed": 21}, 3000.0)
	return Synth.to_stream(Synth.mix([thud, crack]))


static func _impact_heavy() -> AudioStreamWAV:
	var boom: PackedVector2Array = Synth.tone(90.0, 0.4, 0, {"attack": 0.002, "decay": 0.35, "sustain": 0.0, "release": 0.04, "gain": 0.7})
	var crash: PackedVector2Array = Synth.noise(0.2, {"attack": 0.001, "decay": 0.18, "sustain": 0.0, "release": 0.02, "gain": 0.5, "seed": 31}, 800.0)
	return Synth.to_stream(Synth.mix([boom, crash]))


static func _step() -> AudioStreamWAV:
	var buf: PackedVector2Array = Synth.noise(
		0.08, {"attack": 0.005, "decay": 0.06, "sustain": 0.0, "release": 0.01, "gain": 0.3, "seed": 41}, 600.0)
	return Synth.to_stream(buf)


static func _fire_loop() -> AudioStreamWAV:
	var buf: PackedVector2Array = Synth.noise(
		1.0, {"attack": 0.0, "sustain": 1.0, "release": 0.0, "gain": 0.25, "seed": 51}, 400.0)
	var stream: AudioStreamWAV = Synth.to_stream(buf)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = buf.size()
	return stream


static func _ui_tick() -> AudioStreamWAV:
	var buf: PackedVector2Array = Synth.tone(2000.0, 0.03, 0, {"attack": 0.001, "decay": 0.025, "sustain": 0.0, "release": 0.005, "gain": 0.25})
	return Synth.to_stream(buf)


static func _grow() -> AudioStreamWAV:
	# Rising two-note chime: C5 then G5.
	var low: PackedVector2Array = Synth.tone(523.25, 0.15, 3, {"attack": 0.005, "decay": 0.12, "sustain": 0.0, "release": 0.02, "gain": 0.4})
	var high: PackedVector2Array = Synth.tone(783.99, 0.15, 3, {"attack": 0.005, "decay": 0.12, "sustain": 0.0, "release": 0.02, "gain": 0.4})
	var buf: PackedVector2Array = Synth.mix([low, _after(0.08, high)])
	return Synth.to_stream(buf)


static func _shrink() -> AudioStreamWAV:
	# Falling two-note chime: G5 then C5.
	var high: PackedVector2Array = Synth.tone(783.99, 0.15, 3, {"attack": 0.005, "decay": 0.12, "sustain": 0.0, "release": 0.02, "gain": 0.4})
	var low: PackedVector2Array = Synth.tone(523.25, 0.15, 3, {"attack": 0.005, "decay": 0.12, "sustain": 0.0, "release": 0.02, "gain": 0.4})
	var buf: PackedVector2Array = Synth.mix([high, _after(0.08, low)])
	return Synth.to_stream(buf)


static func _chant_bell() -> AudioStreamWAV:
	# A struck bell: fundamental plus two overtones with a long decay.
	var env: Dictionary = {"attack": 0.003, "decay": 1.4, "sustain": 0.0, "release": 0.2, "gain": 0.45}
	var fundamental: PackedVector2Array = Synth.tone(220.0, 1.5, 0, env)
	var partial_a: PackedVector2Array = Synth.tone(440.0, 1.5, 0, {"attack": 0.003, "decay": 0.9, "sustain": 0.0, "release": 0.2, "gain": 0.2})
	var partial_b: PackedVector2Array = Synth.tone(660.0, 1.5, 0, {"attack": 0.003, "decay": 0.5, "sustain": 0.0, "release": 0.2, "gain": 0.1})
	return Synth.to_stream(Synth.mix([fundamental, partial_a, partial_b]))
