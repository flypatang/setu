extends GdUnitTestSuite
# Acceptance tests for S09 sim/ocean.gd (DESIGN §9, Wave S1).

const OCEAN_PATH: String = "res://sim/ocean.gd"


func _make() -> Ocean:
	var script: GDScript = load(OCEAN_PATH) as GDScript
	var ocean: Ocean = script.new() as Ocean
	return ocean


func _storm(start: int, duration: int, strength: float) -> Dictionary:
	return {"start": start, "duration": duration, "strength": strength}


func test_tide_is_zero_at_tick_zero() -> void:
	var ocean: Ocean = _make()
	assert_float(ocean.tide(0)).is_equal_approx(0.0, 0.0001)


func test_tide_has_a_2400_tick_period() -> void:
	var ocean: Ocean = _make()
	for t: int in [0, 137, 600, 1333, 2399]:
		assert_float(ocean.tide(t + 2400)).is_equal_approx(ocean.tide(t), 0.0001)


func test_tide_peaks_at_plus_point_six_a_quarter_period_in() -> void:
	var ocean: Ocean = _make()
	assert_float(ocean.tide(600)).is_equal_approx(0.6, 0.001)
	assert_float(ocean.tide(1800)).is_equal_approx(-0.6, 0.001)


func test_tide_stays_within_plus_minus_point_six() -> void:
	var ocean: Ocean = _make()
	for t: int in range(0, 2400, 7):
		var h: float = ocean.tide(t)
		assert_bool(h <= 0.6 + 0.0001 and h >= -0.6 - 0.0001).is_true()


func test_current_peaks_at_mid_ocean() -> void:
	var ocean: Ocean = _make()
	assert_float(ocean.current_at(500.0, 0)).is_equal_approx(1.0, 0.0001)


func test_current_is_the_shore_value_at_x_zero_and_x_1000() -> void:
	var ocean: Ocean = _make()
	assert_float(ocean.current_at(0.0, 0)).is_equal_approx(0.1, 0.0001)
	assert_float(ocean.current_at(1000.0, 0)).is_equal_approx(0.1, 0.0001)


func test_current_is_symmetric_about_mid_ocean() -> void:
	var ocean: Ocean = _make()
	for x: float in [50.0, 130.0, 300.0, 499.0]:
		assert_float(ocean.current_at(1000.0 - x, 0)).is_equal_approx(ocean.current_at(x, 0), 0.0001)


func test_current_rises_monotonically_from_shore_to_peak() -> void:
	var ocean: Ocean = _make()
	var previous: float = ocean.current_at(0.0, 0)
	for x: int in range(1, 501):
		var value: float = ocean.current_at(float(x), 0)
		assert_bool(value >= previous - 0.000001).is_true()
		previous = value


func test_current_uses_smoothstep_at_quarter_point() -> void:
	# smoothstep(0.5) = 0.5, so base(250) = 0.1 + 0.9 * 0.5 = 0.55.
	var ocean: Ocean = _make()
	assert_float(ocean.current_at(250.0, 0)).is_equal_approx(0.55, 0.0001)


func test_no_storms_means_no_storm_strength() -> void:
	var ocean: Ocean = _make()
	assert_float(ocean.storm_strength_at(100)).is_equal_approx(0.0, 0.0001)


func test_storm_window_is_start_inclusive_end_exclusive() -> void:
	var ocean: Ocean = _make()
	var storms: Array[Dictionary] = [_storm(100, 50, 0.5)]
	ocean.set_storms(storms)
	assert_float(ocean.storm_strength_at(99)).is_equal_approx(0.0, 0.0001)
	assert_float(ocean.storm_strength_at(100)).is_equal_approx(0.5, 0.0001)
	assert_float(ocean.storm_strength_at(149)).is_equal_approx(0.5, 0.0001)
	assert_float(ocean.storm_strength_at(150)).is_equal_approx(0.0, 0.0001)


func test_storm_multiplies_the_current() -> void:
	var ocean: Ocean = _make()
	var storms: Array[Dictionary] = [_storm(10, 20, 0.5)]
	ocean.set_storms(storms)
	assert_float(ocean.current_at(500.0, 15)).is_equal_approx(1.5, 0.0001)
	assert_float(ocean.current_at(500.0, 40)).is_equal_approx(1.0, 0.0001)


func test_set_storms_replaces_previous_storms() -> void:
	var ocean: Ocean = _make()
	var first: Array[Dictionary] = [_storm(0, 100, 1.0)]
	ocean.set_storms(first)
	var second: Array[Dictionary] = []
	ocean.set_storms(second)
	assert_float(ocean.storm_strength_at(10)).is_equal_approx(0.0, 0.0001)
	assert_float(ocean.current_at(500.0, 10)).is_equal_approx(1.0, 0.0001)


func test_storm_input_is_copied_not_shared() -> void:
	var ocean: Ocean = _make()
	var storms: Array[Dictionary] = [_storm(0, 100, 0.8)]
	ocean.set_storms(storms)
	storms[0]["strength"] = 5.0
	assert_float(ocean.storm_strength_at(10)).is_equal_approx(0.8, 0.0001)
