extends GdUnitTestSuite
## Acceptance tests for M06 gen/synth.gd (DESIGN §9): length = dur x 44100, no sample above 1.0, silence is zeros.

const RATE: int = 44100


func _max_abs(buf: PackedVector2Array) -> float:
	var m: float = 0.0
	for i: int in range(buf.size()):
		var s: Vector2 = buf[i]
		m = maxf(m, maxf(absf(s.x), absf(s.y)))
	return m


func test_tone_length_equals_duration() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.5, 0, {})
	assert_int(buf.size()).is_equal(int(0.5 * RATE))


func test_noise_length_equals_duration() -> void:
	var buf: PackedVector2Array = Synth.noise(0.25, {}, 0.0)
	assert_int(buf.size()).is_equal(int(0.25 * RATE))


func test_mix_length_is_longest_input() -> void:
	var a: PackedVector2Array = Synth.tone(440.0, 0.1, 0, {})
	var b: PackedVector2Array = Synth.tone(220.0, 0.2, 0, {})
	var out: PackedVector2Array = Synth.mix([a, b])
	assert_int(out.size()).is_equal(int(0.2 * RATE))


func test_tone_never_exceeds_one_for_every_wave() -> void:
	for wave: int in range(4):
		var buf: PackedVector2Array = Synth.tone(330.0, 0.2, wave, {"gain": 1.0})
		assert_float(_max_abs(buf)).is_less_equal(1.0)


func test_noise_never_exceeds_one() -> void:
	var buf: PackedVector2Array = Synth.noise(0.2, {"gain": 1.0}, 800.0)
	assert_float(_max_abs(buf)).is_less_equal(1.0)


func test_mix_never_exceeds_one_when_inputs_are_loud() -> void:
	var a: PackedVector2Array = Synth.tone(200.0, 0.3, 1, {"gain": 1.0})
	var b: PackedVector2Array = Synth.tone(200.0, 0.3, 1, {"gain": 1.0})
	var c: PackedVector2Array = Synth.noise(0.3, {"gain": 1.0}, 0.0)
	var out: PackedVector2Array = Synth.mix([a, b, c])
	assert_float(_max_abs(out)).is_less_equal(1.0)


func test_zero_gain_tone_is_silence() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.1, 0, {"gain": 0.0})
	assert_float(_max_abs(buf)).is_equal_approx(0.0, 0.000001)


func test_zero_gain_noise_is_silence() -> void:
	var buf: PackedVector2Array = Synth.noise(0.1, {"gain": 0.0}, 0.0)
	assert_float(_max_abs(buf)).is_equal_approx(0.0, 0.000001)


func test_tone_is_not_silent_with_default_gain() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.1, 0, {})
	assert_float(_max_abs(buf)).is_greater(0.1)


func test_release_fades_to_zero_at_end() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.2, 0, {"release": 0.05})
	var last: Vector2 = buf[buf.size() - 1]
	assert_float(absf(last.x)).is_equal_approx(0.0, 0.001)


func test_noise_is_deterministic_for_same_seed() -> void:
	var a: PackedVector2Array = Synth.noise(0.05, {"seed": 7}, 2000.0)
	var b: PackedVector2Array = Synth.noise(0.05, {"seed": 7}, 2000.0)
	assert_int(a.size()).is_equal(b.size())
	assert_bool(a == b).is_true()


func test_channels_are_identical_for_mono_source() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.05, 0, {})
	for i: int in range(buf.size()):
		var s: Vector2 = buf[i]
		assert_float(s.x).is_equal_approx(s.y, 0.000001)


func test_to_stream_is_16_bit_stereo_44100() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.1, 0, {})
	var stream: AudioStreamWAV = Synth.to_stream(buf)
	assert_object(stream).is_not_null()
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.mix_rate).is_equal(RATE)
	assert_bool(stream.stereo).is_true()


func test_to_stream_data_size_is_four_bytes_per_frame() -> void:
	var buf: PackedVector2Array = Synth.tone(440.0, 0.1, 0, {})
	var stream: AudioStreamWAV = Synth.to_stream(buf)
	assert_int(stream.data.size()).is_equal(buf.size() * 4)
