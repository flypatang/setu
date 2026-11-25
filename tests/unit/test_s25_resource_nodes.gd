extends GdUnitTestSuite

const DAY_1_PATH: String = "res://data/days/day_1.json"


func _flow() -> DayFlow:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DAY_1_PATH)) as Dictionary
	var f: DayFlow = DayFlow.new()
	f.load_day(d)
	return f


func _station(f: DayFlow, kind: String, x: float, z: float) -> bool:
	return f.apply_command({"type": "build_station", "args": {"kind": kind, "pos": [x, z]}})


func test_quarry_near_node_accepted() -> void:
	assert_bool(_station(_flow(), "quarry", -62.0, -28.0)).is_true()


func test_quarry_far_from_node_rejected() -> void:
	assert_bool(_station(_flow(), "quarry", -5.0, 0.0)).is_false()


func test_quarry_near_forest_node_rejected() -> void:
	assert_bool(_station(_flow(), "quarry", -60.0, 40.0)).is_false()


func test_forest_near_node_accepted() -> void:
	assert_bool(_station(_flow(), "forest", -60.0, 45.0)).is_true()


func test_forest_far_from_node_rejected() -> void:
	assert_bool(_station(_flow(), "forest", -60.0, 0.0)).is_false()


func test_lekhan_shore_accepted_and_bridge_side_rejected() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "lekhan", -5.0, 3.0)).is_true()
	assert_bool(_station(f, "lekhan", 5.0, 3.0)).is_false()


func test_ropeworks_shore_accepted_and_bridge_side_rejected() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "ropeworks", -20.0, 3.0)).is_true()
	assert_bool(_station(f, "ropeworks", 0.0, 3.0)).is_false()


func test_assign_cutters_to_pile_at_node_accepted() -> void:
	var f: DayFlow = _flow()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "cutter", "site": "quarry", "crews": 1}})).is_true()


func test_assign_cutters_to_far_station_rejected() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "lekhan", -5.0, 3.0)).is_true()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "cutter", "site": "lekhan_1", "crews": 1}})).is_false()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "lumberjack", "site": "lekhan_1", "crews": 1}})).is_false()


func test_assign_lumberjack_to_forest_accepted() -> void:
	var f: DayFlow = _flow()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "lumberjack", "site": "forest", "crews": 1}})).is_true()


func test_new_station_at_node_can_be_crewed() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "quarry", -75.0, -20.0)).is_true()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "cutter", "site": "quarry_1", "crews": 1}})).is_true()


func test_lekhan_at_exactly_shore_limit_rejected() -> void:
	var f: DayFlow = _flow()
	assert_float(DayFlow.SHORE_MAX_X).is_equal(0.0)
	assert_bool(_station(f, "lekhan", DayFlow.SHORE_MAX_X, 3.0)).is_false()
	assert_bool(_station(f, "lekhan", -0.1, 3.0)).is_true()


func test_quarry_exactly_15m_from_node_accepted() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "quarry", -60.0, -15.0)).is_true()


func test_quarry_just_over_15m_from_node_rejected() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "quarry", -60.0, -14.9)).is_false()


func test_assign_cutter_to_forest_site_rejected() -> void:
	var f: DayFlow = _flow()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "cutter", "site": "forest", "crews": 1}})).is_false()


func test_assign_cutter_boundary_15m_and_over() -> void:
	var f: DayFlow = _flow()
	assert_bool(_station(f, "quarry", -60.0, -15.0)).is_true()
	assert_bool(f.apply_command({"type": "assign_crews", "args": {"role": "cutter", "site": "quarry_1", "crews": 1}})).is_true()
