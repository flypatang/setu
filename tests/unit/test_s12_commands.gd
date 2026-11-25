extends GdUnitTestSuite
## S12 acceptance: command objects, per-type validation and normalisation (DESIGN §9 S12).

func _route_args() -> Dictionary:
	return {
		"id": "route_1",
		"from": "forest_pile",
		"to": "bridge_head",
		"kind": "haul",
		"points": [[0.0, 0.0], [10.0, 2.0], [20.0, 4.0]],
		"haulers": 4,
	}


func test_valid_draw_route_has_no_problems() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(10, &"draw_route", _route_args())
	var problems: Array[String] = PlayerCommands.validate(cmd)
	assert_array(problems).is_empty()


func test_draw_route_needs_two_points() -> void:
	var args: Dictionary = _route_args()
	args["points"] = [[0.0, 0.0]]
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(10, &"draw_route", args)
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_draw_route_rejects_zero_haulers() -> void:
	var args: Dictionary = _route_args()
	args["haulers"] = 0
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(10, &"draw_route", args)
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_draw_route_rejects_point_with_wrong_arity() -> void:
	var args: Dictionary = _route_args()
	args["points"] = [[0.0, 0.0], [1.0, 2.0, 3.0]]
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(10, &"draw_route", args)
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_assign_crews_rejects_unknown_role() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"assign_crews", {"role": "soldier", "site": "quarry_1", "crews": 2})
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_assign_crews_accepts_each_known_role() -> void:
	for role: String in ["cutter", "lumberjack", "lasher", "scribe", "hauler", "builder"]:
		var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"assign_crews", {"role": role, "site": "quarry_1", "crews": 1})
		assert_array(PlayerCommands.validate(cmd)).is_empty()


func test_build_station_rejects_unknown_kind() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"build_station", {"kind": "temple", "pos": [3.0, 4.0]})
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_build_station_accepts_lekhan_gong_shelter() -> void:
	for kind: String in ["lekhan", "gong", "shelter"]:
		var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"build_station", {"kind": kind, "pos": [3.0, 4.0]})
		assert_array(PlayerCommands.validate(cmd)).is_empty()


func test_measuring_line_rejects_out_of_range_angle() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"place_measuring_line", {"deg": 270.0})
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_measuring_line_accepts_in_range_angle() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"place_measuring_line", {"deg": -12.5})
	assert_array(PlayerCommands.validate(cmd)).is_empty()


func test_ring_gong_requires_id() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"ring_gong", {})
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_chant_jaya_takes_no_args() -> void:
	var ok: PlayerCommands.Command = PlayerCommands.Command.new(5, &"chant_jaya", {})
	assert_array(PlayerCommands.validate(ok)).is_empty()
	var extra: PlayerCommands.Command = PlayerCommands.Command.new(5, &"chant_jaya", {"loud": true})
	assert_array(PlayerCommands.validate(extra)).is_not_empty()


func test_unknown_type_is_a_problem() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(5, &"teleport", {})
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_negative_tick_is_a_problem() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(-1, &"chant_jaya", {})
	assert_array(PlayerCommands.validate(cmd)).is_not_empty()


func test_missing_and_unknown_args_are_reported() -> void:
	var args: Dictionary = _route_args()
	args.erase("to")
	args["colour"] = "red"
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(10, &"draw_route", args)
	var problems: Array[String] = PlayerCommands.validate(cmd)
	assert_int(problems.size()).is_equal(2)


func test_to_dict_from_dict_round_trip_is_identical() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(42, &"draw_route", _route_args())
	var back: PlayerCommands.Command = PlayerCommands.Command.from_dict(cmd.to_dict())
	assert_int(back.tick).is_equal(42)
	assert_str(String(back.type)).is_equal("draw_route")
	assert_str(str(back.to_dict())).is_equal(str(cmd.to_dict()))


func test_from_dict_normalises_json_numbers() -> void:
	# JSON parses every number as float; haulers must come back as int so hashes match.
	var d: Dictionary = {"tick": 7.0, "type": "assign_crews", "args": {"role": "cutter", "site": "q", "crews": 3.0}}
	var cmd: PlayerCommands.Command = PlayerCommands.Command.from_dict(d)
	assert_int(cmd.tick).is_equal(7)
	assert_int(typeof(cmd.args["crews"])).is_equal(TYPE_INT)
	assert_array(PlayerCommands.validate(cmd)).is_empty()


func test_to_dict_returns_a_copy_of_args() -> void:
	var cmd: PlayerCommands.Command = PlayerCommands.Command.new(1, &"ring_gong", {"id": "g1"})
	var d: Dictionary = cmd.to_dict()
	(d["args"] as Dictionary)["id"] = "changed"
	assert_str(str(cmd.args["id"])).is_equal("g1")
