extends GdUnitTestSuite

const MIN_SCORE: float = 90.0


func _run(n: int) -> Dictionary:
	return BotDays.run_day(n, BotDays.load_plan(n))


func test_day_2_reaches_90() -> void:
	assert_float(_run(2)["total"] as float).is_greater_equal(MIN_SCORE)


func test_day_3_reaches_90() -> void:
	assert_float(_run(3)["total"] as float).is_greater_equal(MIN_SCORE)


func test_day_4_reaches_90() -> void:
	assert_float(_run(4)["total"] as float).is_greater_equal(MIN_SCORE)


func test_day_5_reaches_90() -> void:
	assert_float(_run(5)["total"] as float).is_greater_equal(MIN_SCORE)


func test_day_1_plan_still_reaches_90() -> void:
	assert_float(_run(1)["total"] as float).is_greater_equal(MIN_SCORE)


func test_days_reach_target_length() -> void:
	for n: int in range(2, 6):
		var r: Dictionary = _run(n)
		assert_float(r["length_pct"] as float).is_greater_equal(99.9)


func test_runs_are_deterministic() -> void:
	for n: int in range(2, 6):
		var a: Dictionary = _run(n)
		var b: Dictionary = _run(n)
		assert_str(a["hash"] as String).is_not_empty()
		assert_str(a["hash"] as String).is_equal(b["hash"] as String)


func test_day_4_gongs_shorten_creature_zones() -> void:
	var gongs: Array = _run(4)["gongs"] as Array
	assert_int(gongs[0] as int).is_greater(0)
	assert_int(gongs[1] as int).is_greater(0)


func test_day_3_plan_chants_for_night_morale() -> void:
	var chants: int = 0
	for c: Variant in BotDays.load_plan(3):
		if (c as Dictionary)["type"] == "chant_jaya":
			chants += 1
	assert_int(chants).is_greater(0)


func test_plans_place_measuring_lines() -> void:
	for n: int in range(2, 6):
		var found: bool = false
		for c: Variant in BotDays.load_plan(n):
			if (c as Dictionary)["type"] == "place_measuring_line":
				found = true
		assert_bool(found).is_true()
