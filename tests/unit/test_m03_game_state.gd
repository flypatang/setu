extends GdUnitTestSuite
## Acceptance tests for core/game_state.gd (DESIGN §9, M03).
## Save slots used here are 90-99 so they never collide with a real player's saves.

const SCRIPT_PATH: String = "res://core/game_state.gd"


func _make_state() -> Node:
	var script: GDScript = load(SCRIPT_PATH) as GDScript
	var state: Node = script.new() as Node
	return auto_free(state) as Node


func _remove_slot(slot: int) -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and dir.file_exists("save_%d.json" % slot):
		dir.remove("save_%d.json" % slot)


func after_test() -> void:
	for slot: int in range(90, 100):
		_remove_slot(slot)


func test_defaults_are_empty() -> void:
	var state: Node = _make_state()
	assert_str(str(state.get("chapter"))).is_equal("prologue")
	assert_dict(state.get("flags") as Dictionary).is_empty()
	assert_int(state.get("vows") as int).is_equal(0)
	assert_array(state.get("unlocked") as Array).is_empty()
	assert_dict(state.get("last_shrine") as Dictionary).is_empty()


func test_set_and_get_flag() -> void:
	var state: Node = _make_state()
	state.call("set_flag", &"met_sita", true)
	assert_bool(state.call("get_flag", &"met_sita", false) as bool).is_true()


func test_get_flag_returns_default_when_unset() -> void:
	var state: Node = _make_state()
	assert_int(state.call("get_flag", &"missing", 42) as int).is_equal(42)
	assert_bool(state.call("get_flag", &"missing", false) as bool).is_false()


func test_unlock_and_is_unlocked() -> void:
	var state: Node = _make_state()
	assert_bool(state.call("is_unlocked", &"leap") as bool).is_false()
	state.call("unlock", &"leap")
	assert_bool(state.call("is_unlocked", &"leap") as bool).is_true()
	state.call("unlock", &"leap")
	assert_array(state.get("unlocked") as Array).has_size(1)


func test_reset_restores_defaults() -> void:
	var state: Node = _make_state()
	state.set("chapter", &"chapter_3")
	state.set("vows", 7)
	state.call("set_flag", &"x", 1)
	state.call("unlock", &"leap")
	state.call("reset")
	assert_str(str(state.get("chapter"))).is_equal("prologue")
	assert_int(state.get("vows") as int).is_equal(0)
	assert_dict(state.get("flags") as Dictionary).is_empty()
	assert_array(state.get("unlocked") as Array).is_empty()
	assert_dict(state.get("last_shrine") as Dictionary).is_empty()


func test_save_reset_load_gives_identical_state() -> void:
	var state: Node = _make_state()
	state.set("chapter", &"chapter_2")
	state.set("vows", 3)
	state.call("set_flag", &"met_sita", true)
	state.call("set_flag", &"ring_given", "anguthi")
	state.call("set_flag", &"shrines_lit", 4)
	state.call("set_flag", &"courage", 0.75)
	state.call("unlock", &"leap")
	state.call("unlock", &"grow")
	var shrine: Dictionary = {"id": &"grove_1", "pos": Vector3(1.5, 0.0, -2.0)}
	state.set("last_shrine", shrine)

	assert_int(state.call("save_game", 90) as int).is_equal(OK)

	state.call("reset")
	assert_int(state.get("vows") as int).is_equal(0)

	assert_int(state.call("load_game", 90) as int).is_equal(OK)
	assert_str(str(state.get("chapter"))).is_equal("chapter_2")
	assert_int(state.get("vows") as int).is_equal(3)
	assert_bool(state.call("get_flag", &"met_sita", false) as bool).is_true()
	assert_str(state.call("get_flag", &"ring_given", "") as String).is_equal("anguthi")
	assert_int(state.call("get_flag", &"shrines_lit", 0) as int).is_equal(4)
	assert_float(state.call("get_flag", &"courage", 0.0) as float).is_equal_approx(0.75, 0.001)
	assert_bool(state.call("is_unlocked", &"leap") as bool).is_true()
	assert_bool(state.call("is_unlocked", &"grow") as bool).is_true()
	assert_array(state.get("unlocked") as Array).has_size(2)
	var loaded_shrine: Dictionary = state.get("last_shrine") as Dictionary
	assert_str(str(loaded_shrine["id"])).is_equal("grove_1")
	assert_vector(loaded_shrine["pos"] as Vector3).is_equal(Vector3(1.5, 0.0, -2.0))


func test_load_missing_slot_returns_file_not_found() -> void:
	var state: Node = _make_state()
	assert_int(state.call("load_game", 91) as int).is_equal(ERR_FILE_NOT_FOUND)


func test_load_missing_slot_leaves_state_untouched() -> void:
	var state: Node = _make_state()
	state.set("vows", 5)
	state.call("load_game", 92)
	assert_int(state.get("vows") as int).is_equal(5)


func test_slots_are_independent() -> void:
	var state: Node = _make_state()
	state.set("vows", 1)
	state.call("save_game", 93)
	state.set("vows", 2)
	state.call("save_game", 94)
	state.call("load_game", 93)
	assert_int(state.get("vows") as int).is_equal(1)
	state.call("load_game", 94)
	assert_int(state.get("vows") as int).is_equal(2)
