extends GdUnitTestSuite
## M16 acceptance tests: narrative/dialogue_runner.gd plays the graphs in data/dialogue/ (SCHEMA.md).
## Fixture files are written to user:// with ids prefixed m16_test_ and removed after each test.
## The runner is instantiated from its script and given a private GameState, never the autoload.

const RUNNER_PATH: String = "res://narrative/dialogue_runner.gd"
const GAME_STATE_PATH: String = "res://core/game_state.gd"
const REAL_DIR: String = "res://data/dialogue/"
const STRINGS_PATH: String = "res://i18n/strings.csv"
const SHLOKAS_PATH: String = "res://data/shlokas.json"
const MAX_CHOICES: int = 4

var _written: Array[String] = []


func after_test() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for path: String in _written:
		if dir != null and dir.file_exists(path):
			dir.remove(path)
	_written.clear()


func _make_state() -> Node:
	return auto_free((load(GAME_STATE_PATH) as GDScript).new() as Node) as Node


func _make_runner(state: Node, dir: String = "user://") -> Node:
	var runner: Node = auto_free((load(RUNNER_PATH) as GDScript).new() as Node) as Node
	runner.set("dialogue_dir", dir)
	runner.set("game_state", state)
	return runner


func _write_fixture(id: String, body: String) -> void:
	var path: String = "user://%s.json" % id
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(body)
	file.close()
	_written.append(path)


func _flag(state: Node, key: String) -> Variant:
	return state.call("get_flag", StringName(key), null)


## Collects everything a runner emits so tests can assert on it in order.
class Recorder:
	var lines: Array[String] = []
	var speakers: Array[StringName] = []
	var shlokas: Array[StringName] = []
	var smarana: Array[float] = []
	var finished_ids: Array[StringName] = []


func _record(runner: Node) -> Recorder:
	var rec: Recorder = Recorder.new()
	runner.connect("line_shown", func(speaker: StringName, text: String) -> void:
		rec.speakers.append(speaker)
		rec.lines.append(text))
	runner.connect("shloka_shown", func(shloka_id: StringName) -> void:
		rec.shlokas.append(shloka_id))
	runner.connect("smarana_awarded", func(amount: float) -> void:
		rec.smarana.append(amount))
	runner.connect("finished", func(id: StringName) -> void:
		rec.finished_ids.append(id))
	return rec


func _real_dialogue_files() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(REAL_DIR)
	assert_object(dir).is_not_null()
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			out.append(file_name)
	return out


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary


func _csv_entries() -> Dictionary:
	## Maps each key in strings.csv to a PackedStringArray of [en, hi].
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(STRINGS_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var is_header: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if is_header:
			is_header = false
			continue
		if row.size() < 3 or row[0].is_empty():
			continue
		out[row[0]] = PackedStringArray([row[1], row[2]])
	file.close()
	return out


func _shloka_ids() -> Array[String]:
	var out: Array[String] = []
	var data: Dictionary = _read_json(SHLOKAS_PATH)
	for entry: Variant in data["shlokas"] as Array:
		out.append(str((entry as Dictionary)["id"]))
	return out


## Returns one human-readable error per broken rule in a dialogue graph.
func _graph_errors(file_name: String, data: Dictionary, keys: Dictionary, shloka_ids: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var nodes: Dictionary = data["nodes"] as Dictionary
	var start_id: String = str(data["start"])
	if not nodes.has(start_id):
		errors.append("%s: start node '%s' does not exist" % [file_name, start_id])
	for node_id: Variant in nodes:
		var where: String = "%s:%s" % [file_name, str(node_id)]
		var node: Dictionary = nodes[node_id] as Dictionary
		var has_line: bool = node.has("speaker") and node.has("text_key")
		var has_shloka: bool = node.has("shloka")
		if has_line == has_shloka:
			errors.append("%s: must be exactly one of a line (speaker+text_key) or a shloka" % where)
		if has_shloka and not shloka_ids.has(str(node["shloka"])):
			errors.append("%s: unknown shloka '%s'" % [where, str(node["shloka"])])
		if has_line:
			errors.append_array(_text_key_errors(where, str(node["text_key"]), keys))
		var has_choices: bool = node.has("choices")
		if has_choices:
			var choices: Array = node["choices"] as Array
			if choices.size() < 1 or choices.size() > MAX_CHOICES:
				errors.append("%s: has %d choices, must be 1 to %d" % [where, choices.size(), MAX_CHOICES])
			for choice: Variant in choices:
				var choice_dict: Dictionary = choice as Dictionary
				errors.append_array(_text_key_errors(where, str(choice_dict["text_key"]), keys))
				if not choice_dict.has("next"):
					errors.append("%s: choice has no next" % where)
				else:
					errors.append_array(_next_errors(where, choice_dict["next"], nodes))
		elif has_line or has_shloka:
			if not node.has("next"):
				errors.append("%s: line has neither next nor choices" % where)
			else:
				errors.append_array(_next_errors(where, node["next"], nodes))
		if node.has("set_flags") and not (node["set_flags"] is Dictionary):
			errors.append("%s: set_flags must be an object" % where)
	return errors


func _text_key_errors(where: String, key: String, keys: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not keys.has(key):
		errors.append("%s: text_key '%s' is not in strings.csv" % [where, key])
		return errors
	var pair: PackedStringArray = keys[key] as PackedStringArray
	if pair[0].strip_edges().is_empty():
		errors.append("%s: '%s' has an empty en value" % [where, key])
	if pair[1].strip_edges().is_empty():
		errors.append("%s: '%s' has an empty hi value" % [where, key])
	return errors


func _next_errors(where: String, next: Variant, nodes: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if next == null:
		return errors
	if not nodes.has(str(next)):
		errors.append("%s: next '%s' does not exist" % [where, str(next)])
	return errors


# ---- Behaviour on fixtures ------------------------------------------------

func test_start_unknown_dialogue_returns_error() -> void:
	var runner: Node = _make_runner(_make_state())
	var err: int = runner.call("start", &"m16_test_missing") as int
	assert_int(err).is_not_equal(OK)
	assert_bool(runner.call("is_running") as bool).is_false()


func test_linear_lines_emit_in_order_and_finish() -> void:
	_write_fixture("m16_test_linear", """{
  "id": "m16_test_linear", "start": "a",
  "nodes": {
    "a": { "speaker": "narrator", "text_key": "M16_TEST_A", "next": "b" },
    "b": { "speaker": "hanuman", "text_key": "M16_TEST_B", "next": null }
  }
}""")
	var runner: Node = _make_runner(_make_state())
	var rec: Recorder = _record(runner)
	assert_int(runner.call("start", &"m16_test_linear") as int).is_equal(OK)
	assert_array(rec.lines).has_size(1)
	assert_str(rec.lines[0]).is_equal(tr("M16_TEST_A"))
	assert_str(String(rec.speakers[0])).is_equal("narrator")
	assert_bool(runner.call("is_running") as bool).is_true()

	runner.call("advance")
	assert_str(rec.lines[1]).is_equal(tr("M16_TEST_B"))
	assert_str(String(rec.speakers[1])).is_equal("hanuman")
	assert_array(rec.finished_ids).is_empty()

	runner.call("advance")
	assert_array(rec.finished_ids).has_size(1)
	assert_str(String(rec.finished_ids[0])).is_equal("m16_test_linear")
	assert_bool(runner.call("is_running") as bool).is_false()


func test_choice_applies_flags_and_reports_smarana() -> void:
	_write_fixture("m16_test_choice", """{
  "id": "m16_test_choice", "start": "q",
  "nodes": {
    "q": { "speaker": "hanuman", "text_key": "M16_TEST_Q",
      "choices": [
        { "text_key": "M16_TEST_CH_A", "next": "yes", "flags": {"brave": true, "count": 3}, "smarana": 15 },
        { "text_key": "M16_TEST_CH_B", "next": "no", "flags": {}, "smarana": 0 } ] },
    "yes": { "speaker": "narrator", "text_key": "M16_TEST_YES", "next": null },
    "no":  { "speaker": "narrator", "text_key": "M16_TEST_NO", "next": null }
  }
}""")
	var state: Node = _make_state()
	var runner: Node = _make_runner(state)
	var rec: Recorder = _record(runner)
	runner.call("start", &"m16_test_choice")
	assert_bool(runner.call("waiting_for_choice") as bool).is_true()
	var texts: Array[String] = runner.call("get_choice_texts") as Array[String]
	assert_array(texts).has_size(2)
	assert_str(texts[0]).is_equal(tr("M16_TEST_CH_A"))

	assert_bool(runner.call("choose", 0) as bool).is_true()
	assert_bool(_flag(state, "brave") as bool).is_true()
	assert_int(_flag(state, "count") as int).is_equal(3)
	assert_array(rec.smarana).has_size(1)
	assert_float(rec.smarana[0]).is_equal_approx(15.0, 0.001)
	assert_str(rec.lines[1]).is_equal(tr("M16_TEST_YES"))

	runner.call("advance")
	assert_array(rec.finished_ids).has_size(1)


func test_choice_without_smarana_emits_nothing() -> void:
	_write_fixture("m16_test_nosmarana", """{
  "id": "m16_test_nosmarana", "start": "q",
  "nodes": {
    "q": { "speaker": "hanuman", "text_key": "M16_TEST_Q",
      "choices": [ { "text_key": "M16_TEST_CH_B", "next": null, "flags": {}, "smarana": 0 } ] }
  }
}""")
	var runner: Node = _make_runner(_make_state())
	var rec: Recorder = _record(runner)
	runner.call("start", &"m16_test_nosmarana")
	runner.call("choose", 0)
	assert_array(rec.smarana).is_empty()
	assert_array(rec.finished_ids).has_size(1)


func test_out_of_range_choice_is_ignored() -> void:
	_write_fixture("m16_test_range", """{
  "id": "m16_test_range", "start": "q",
  "nodes": {
    "q": { "speaker": "hanuman", "text_key": "M16_TEST_Q",
      "choices": [ { "text_key": "M16_TEST_CH_A", "next": null, "flags": {"touched": true}, "smarana": 5 } ] }
  }
}""")
	var state: Node = _make_state()
	var runner: Node = _make_runner(state)
	var rec: Recorder = _record(runner)
	runner.call("start", &"m16_test_range")
	assert_bool(runner.call("choose", 1) as bool).is_false()
	assert_bool(runner.call("choose", -1) as bool).is_false()
	assert_bool(runner.call("waiting_for_choice") as bool).is_true()
	assert_array(rec.finished_ids).is_empty()
	assert_array(rec.smarana).is_empty()
	assert_bool(state.call("get_flag", &"touched", false) as bool).is_false()


func test_set_flags_applied_when_node_is_shown() -> void:
	_write_fixture("m16_test_setflags", """{
  "id": "m16_test_setflags", "start": "a",
  "nodes": {
    "a": { "speaker": "narrator", "text_key": "M16_TEST_A", "next": "b", "set_flags": {"seen_intro": true} },
    "b": { "speaker": "narrator", "text_key": "M16_TEST_B", "next": null }
  }
}""")
	var state: Node = _make_state()
	var runner: Node = _make_runner(state)
	runner.call("start", &"m16_test_setflags")
	assert_bool(state.call("get_flag", &"seen_intro", false) as bool).is_true()


func test_shloka_step_emits_id_and_waits_for_advance() -> void:
	_write_fixture("m16_test_shloka", """{
  "id": "m16_test_shloka", "start": "a",
  "nodes": {
    "a": { "speaker": "narrator", "text_key": "M16_TEST_A", "next": "s" },
    "s": { "shloka": "sk_opening", "next": null }
  }
}""")
	var runner: Node = _make_runner(_make_state())
	var rec: Recorder = _record(runner)
	runner.call("start", &"m16_test_shloka")
	runner.call("advance")
	assert_array(rec.shlokas).has_size(1)
	assert_str(String(rec.shlokas[0])).is_equal("sk_opening")
	assert_array(rec.finished_ids).is_empty()
	runner.call("advance")
	assert_array(rec.finished_ids).has_size(1)


# ---- The real dialogue files ----------------------------------------------

func test_pro_jambavan_walkthrough_reaches_end() -> void:
	if not FileAccess.file_exists("res://data/dialogue/pro_jambavan.json"):
		return  # Hanumaan content; this suite is shared with other games.
	var state: Node = _make_state()
	var runner: Node = _make_runner(state, REAL_DIR)
	var rec: Recorder = _record(runner)
	assert_int(runner.call("start", &"pro_jambavan") as int).is_equal(OK)
	for i: int in range(6):
		runner.call("advance")
	assert_int(rec.lines.size()).is_equal(7)
	assert_bool(runner.call("waiting_for_choice") as bool).is_true()

	runner.call("choose", 0)
	assert_str(String(_flag(state, "pro_answer") as StringName)).is_equal("devotion")
	assert_float(rec.smarana[0]).is_equal_approx(15.0, 0.001)
	assert_str(rec.lines[7]).is_equal(tr("DLG_PRO_JAM_008"))
	assert_bool(state.call("get_flag", &"grow_unlocked", false) as bool).is_true()

	runner.call("advance")
	assert_str(rec.lines[8]).is_equal(tr("DLG_PRO_JAM_009"))
	runner.call("advance")
	assert_array(rec.finished_ids).has_size(1)
	assert_str(String(rec.finished_ids[0])).is_equal("pro_jambavan")


func test_pro_jambavan_retry_branch_loops_back_to_choice() -> void:
	if not FileAccess.file_exists("res://data/dialogue/pro_jambavan.json"):
		return  # Hanumaan content; this suite is shared with other games.
	var state: Node = _make_state()
	var runner: Node = _make_runner(state, REAL_DIR)
	var rec: Recorder = _record(runner)
	runner.call("start", &"pro_jambavan")
	for i: int in range(6):
		runner.call("advance")
	runner.call("choose", 1)
	assert_array(rec.smarana).is_empty()
	assert_bool(state.call("get_flag", &"pro_answer", false) as bool).is_false()
	runner.call("advance")
	assert_bool(runner.call("waiting_for_choice") as bool).is_true()
	assert_str(runner.call("current_node") as String).is_equal("n7")


func test_every_real_dialogue_file_graph_is_valid() -> void:
	var keys: Dictionary = _csv_entries()
	var shloka_ids: Array[String] = _shloka_ids()
	var files: Array[String] = _real_dialogue_files()
	assert_array(files).is_not_empty()
	var errors: Array[String] = []
	for file_name: String in files:
		var data: Dictionary = _read_json(REAL_DIR + file_name)
		errors.append_array(_graph_errors(file_name, data, keys, shloka_ids))
	assert_array(errors).is_empty()


func test_every_real_dialogue_file_starts_cleanly() -> void:
	for file_name: String in _real_dialogue_files():
		var id: String = file_name.get_basename()
		var runner: Node = _make_runner(_make_state(), REAL_DIR)
		var err: int = runner.call("start", StringName(id)) as int
		assert_int(err).is_equal(OK)
		assert_bool(runner.call("is_running") as bool).is_true()
