extends GdUnitTestSuite
## Acceptance tests for M11 gen/sfx_library.gd (DESIGN §9): every id returns a non-empty stream,
## and the second call returns the cached object.

const IDS: Array[StringName] = [
	&"whoosh",
	&"impact_light",
	&"impact_heavy",
	&"step",
	&"fire_loop",
	&"ui_tick",
	&"grow",
	&"shrink",
	&"chant_bell",
]


func test_every_id_returns_non_empty_stream() -> void:
	for id: StringName in IDS:
		var stream: AudioStreamWAV = SfxLibrary.get_sfx(id)
		assert_object(stream).is_not_null()
		assert_int(stream.data.size()).is_greater(0)
		assert_float(stream.get_length()).is_greater(0.0)


func test_streams_are_16_bit_stereo_at_synth_rate() -> void:
	for id: StringName in IDS:
		var stream: AudioStreamWAV = SfxLibrary.get_sfx(id)
		assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_bool(stream.stereo).is_true()
		assert_int(stream.mix_rate).is_equal(Synth.SAMPLE_RATE)


func test_second_call_returns_cached_object() -> void:
	for id: StringName in IDS:
		var first: AudioStreamWAV = SfxLibrary.get_sfx(id)
		var second: AudioStreamWAV = SfxLibrary.get_sfx(id)
		assert_bool(is_same(first, second)).is_true()
