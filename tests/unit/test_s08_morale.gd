extends GdUnitTestSuite
# Acceptance tests for S08 sim/morale.gd (DESIGN §4.4, §9 Wave S1).

const MORALE_PATH: String = "res://sim/morale.gd"


func _make() -> Morale:
	var script: GDScript = load(MORALE_PATH) as GDScript
	var m: Morale = script.new() as Morale
	return m


func test_factor_curve_endpoints_and_midpoint() -> void:
	var m: Morale = _make()
	m.utsaha = 0.0
	assert_float(m.factor()).is_equal_approx(0.6, 0.001)
	m.utsaha = 50.0
	assert_float(m.factor()).is_equal_approx(1.0, 0.001)
	m.utsaha = 100.0
	assert_float(m.factor()).is_equal_approx(1.3, 0.001)


func test_factor_is_piecewise_linear() -> void:
	var m: Morale = _make()
	m.utsaha = 25.0
	assert_float(m.factor()).is_equal_approx(0.8, 0.001)
	m.utsaha = 75.0
	assert_float(m.factor()).is_equal_approx(1.15, 0.001)


func test_utsaha_clamps_to_zero_and_hundred() -> void:
	var m: Morale = _make()
	m.utsaha = -40.0
	assert_float(m.utsaha).is_equal_approx(0.0, 0.0001)
	assert_float(m.factor()).is_equal_approx(0.6, 0.001)
	m.utsaha = 250.0
	assert_float(m.utsaha).is_equal_approx(100.0, 0.0001)
	assert_float(m.factor()).is_equal_approx(1.3, 0.001)


func test_night_drains_one_hundredth_per_tick() -> void:
	var m: Morale = _make()
	m.utsaha = 50.0
	m.set_effects({"night": true})
	m.step(0)
	assert_float(m.utsaha).is_equal_approx(49.99, 0.0001)
	m.step(1)
	assert_float(m.utsaha).is_equal_approx(49.98, 0.0001)


func test_storm_drains_three_hundredths_per_tick() -> void:
	var m: Morale = _make()
	m.utsaha = 50.0
	m.set_effects({"storm": true})
	m.step(0)
	assert_float(m.utsaha).is_equal_approx(49.97, 0.0001)


func test_crowding_drains_two_hundredths_per_tick() -> void:
	var m: Morale = _make()
	m.utsaha = 50.0
	m.set_effects({"crowding": true})
	m.step(0)
	assert_float(m.utsaha).is_equal_approx(49.98, 0.0001)


func test_rama_presence_gains_two_hundredths_per_tick() -> void:
	var m: Morale = _make()
	m.utsaha = 50.0
	m.set_effects({"rama_present": true})
	m.step(0)
	assert_float(m.utsaha).is_equal_approx(50.02, 0.0001)


func test_modifiers_stack_and_no_effects_means_no_change() -> void:
	var m: Morale = _make()
	m.utsaha = 50.0
	m.set_effects({})
	m.step(0)
	assert_float(m.utsaha).is_equal_approx(50.0, 0.0001)
	m.set_effects({"night": true, "storm": true, "crowding": true, "rama_present": true})
	m.step(1)
	# -0.01 - 0.03 - 0.02 + 0.02 = -0.04
	assert_float(m.utsaha).is_equal_approx(49.96, 0.0001)


func test_step_clamps_at_bounds() -> void:
	var m: Morale = _make()
	m.utsaha = 0.01
	m.set_effects({"storm": true})
	m.step(0)
	assert_float(m.utsaha).is_equal_approx(0.0, 0.0001)
	m.utsaha = 99.99
	m.set_effects({"rama_present": true})
	m.step(1)
	assert_float(m.utsaha).is_equal_approx(100.0, 0.0001)


func test_chant_adds_fifteen_instantly_and_clamps() -> void:
	var m: Morale = _make()
	m.utsaha = 40.0
	assert_bool(m.chant(0)).is_true()
	assert_float(m.utsaha).is_equal_approx(55.0, 0.0001)
	m.utsaha = 95.0
	m.chant(1200)
	assert_float(m.utsaha).is_equal_approx(100.0, 0.0001)


func test_chant_cooldown_is_1200_ticks() -> void:
	var m: Morale = _make()
	m.utsaha = 20.0
	assert_bool(m.chant(100)).is_true()
	assert_bool(m.can_chant(100)).is_false()
	assert_bool(m.can_chant(1299)).is_false()
	assert_bool(m.chant(1299)).is_false()
	assert_float(m.utsaha).is_equal_approx(35.0, 0.0001)
	assert_bool(m.can_chant(1300)).is_true()
	assert_bool(m.chant(1300)).is_true()
	assert_float(m.utsaha).is_equal_approx(50.0, 0.0001)


func test_failed_chant_changes_nothing() -> void:
	var m: Morale = _make()
	m.utsaha = 30.0
	m.chant(0)
	var before: float = m.utsaha
	assert_bool(m.chant(10)).is_false()
	assert_float(m.utsaha).is_equal_approx(before, 0.0001)


func test_progress_gains_half_point_per_section() -> void:
	var m: Morale = _make()
	m.utsaha = 50.0
	m.record_sections_completed(1)
	assert_float(m.utsaha).is_equal_approx(50.5, 0.0001)
	m.record_sections_completed(3)
	assert_float(m.utsaha).is_equal_approx(52.0, 0.0001)


func test_snapshot_and_restore_round_trip() -> void:
	var m: Morale = _make()
	m.utsaha = 61.5
	m.chant(500)
	var data: Dictionary = m.snapshot()
	var other: Morale = _make()
	other.restore(data)
	assert_float(other.utsaha).is_equal_approx(m.utsaha, 0.0001)
	assert_bool(other.can_chant(1699)).is_false()
	assert_bool(other.can_chant(1700)).is_true()
