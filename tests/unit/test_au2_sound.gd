extends GdUnitTestSuite
# Acceptance tests for AU2 core/sound.gd (event bank, pooled SFX, DayFlow hooks).

const SOUND_PATH: String = "res://core/sound.gd"
const DAY_1_PATH: String = "res://data/days/day_1.json"
const PLAN_PATH: String = "res://tests/unit/fixtures/plan_day1.json"

const REQUIRED: Array[StringName] = [
	&"ui_click", &"ui_hover", &"ui_confirm", &"ui_back", &"action_select", &"route_drawn", &"crew_assigned",
	&"station_built", &"stone_inscribed", &"stone_placed", &"plank_laid", &"section_complete", &"stone_sank",
	&"section_broken", &"gong", &"jaya_chant", &"day_start", &"sunset", &"summary_open", &"dialogue_advance",
	&"shloka_open",
]

var _heard: Array[StringName] = []


func _sound() -> Node:
	var s: Node = auto_free((load(SOUND_PATH) as GDScript).new() as Node) as Node
	add_child(s)
	_heard.clear()
	s.set("hook", func(id: StringName) -> void: _heard.append(id))
	return s


func _read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_bank_has_every_required_id() -> void:
	var s: Node = _sound()
	for id: StringName in REQUIRED:
		assert_bool(s.call("has_event", id) as bool).is_true()


func test_bank_files_exist() -> void:
	var s: Node = _sound()
	var ids: Array = s.call("bank_ids") as Array
	assert_bool(ids.size() >= REQUIRED.size()).is_true()
	for id: Variant in ids:
		var files: Array = s.call("bank_files", id) as Array
		assert_bool(files.size() > 0).is_true()
		for f: Variant in files:
			assert_bool(ResourceLoader.exists(f as String)).is_true()


func test_buses_created() -> void:
	var _s: Node = _sound()
	assert_bool(AudioServer.get_bus_index("Master") >= 0).is_true()
	assert_bool(AudioServer.get_bus_index("Music") >= 0).is_true()
	assert_bool(AudioServer.get_bus_index("SFX") >= 0).is_true()


func test_play_works_headless() -> void:
	var s: Node = _sound()
	assert_bool(s.call("play", &"ui_click") as bool).is_true()
	assert_bool(s.call("play", &"gong") as bool).is_true()
	assert_bool(s.call("play", &"jaya_chant") as bool).is_true()
	assert_bool(s.call("play", &"no_such_event") as bool).is_false()
	assert_bool(_heard.has(&"ui_click")).is_true()
	assert_bool(_heard.has(&"jaya_chant")).is_true()
	assert_bool(_heard.has(&"no_such_event")).is_false()


func test_ambient_waves_while_running() -> void:
	var s: Node = _sound()
	s.call("seed_rng", 7)
	s.call("start_ambient")
	for i: int in 40:
		s.call("step_ambient", 1.0)
	assert_bool(_heard.has(&"wave")).is_true()
	_heard.clear()
	s.call("stop_ambient")
	s.call("step_ambient", 100.0)
	assert_array(_heard).is_empty()


func test_day_flow_triggers_stone_placed_and_section_complete() -> void:
	var s: Node = _sound()
	var flow: DayFlow = DayFlow.new()
	flow.load_day(_read_json(DAY_1_PATH))
	flow.queue_commands(_read_json(PLAN_PATH)["commands"] as Array)
	s.call("watch_flow", flow)
	for i: int in 96:
		flow.run_ticks(100)
		s.call("poll_flow")
	assert_bool(_heard.has(&"stone_placed")).is_true()
	assert_bool(_heard.has(&"plank_laid")).is_true()
	assert_bool(_heard.has(&"section_complete")).is_true()
	assert_bool(_heard.has(&"stone_inscribed")).is_true()
	s.call("unwatch_flow")
