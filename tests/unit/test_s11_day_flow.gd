extends GdUnitTestSuite

const DAY_1_PATH: String = "res://data/days/day_1.json"
const PLAN_PATH: String = "res://tests/unit/fixtures/plan_day1.json"


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text) as Dictionary


func _new_day(with_plan: bool, carry_in: int = 0) -> DayFlow:
	var flow: DayFlow = DayFlow.new()
	flow.load_day(_read_json(DAY_1_PATH), carry_in)
	if with_plan:
		flow.queue_commands(_read_json(PLAN_PATH)["commands"] as Array)
	return flow


func test_plan_finishes_day_1() -> void:
	var flow: DayFlow = _new_day(true)
	assert_int(flow.target_m).is_equal(140)
	flow.run_ticks(9600)
	assert_bool(flow.is_over()).is_true()
	assert_int(flow.tick()).is_equal(9600)
	var sc: Dictionary = flow.score()
	assert_float(sc["length_pct"] as float).is_greater_equal(90.0)
	assert_float(sc["total"] as float).is_greater(60.0)
	assert_int(flow.carry_over()).is_less(15)
	assert_bool(flow.events_fired().has("day_start")).is_true()


func test_day_end_blesses_sections() -> void:
	var flow: DayFlow = _new_day(true)
	flow.run_ticks(9600)
	var found: bool = false
	for i: int in flow.bridge.section_count():
		var s: Bridge.Section = flow.bridge.section(i)
		if s.complete:
			assert_bool(s.blessed).is_true()
			found = true
	assert_bool(found).is_true()


func test_run_is_deterministic() -> void:
	var a: DayFlow = _new_day(true)
	var b: DayFlow = _new_day(true)
	a.run_ticks(9600)
	# Split the second run into odd chunks: the result must not depend on chunking.
	for n: int in [1, 7, 999, 4000, 9000]:
		b.run_ticks(n)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.bridge.length_m()).is_equal(b.bridge.length_m())


func test_different_plans_differ() -> void:
	var a: DayFlow = _new_day(true)
	var b: DayFlow = _new_day(false)
	a.run_ticks(500)
	b.run_ticks(500)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())


func test_missed_target_carries_over() -> void:
	var flow: DayFlow = _new_day(false)
	flow.run_ticks(9600)
	assert_int(flow.bridge.length_m()).is_equal(0)
	assert_int(flow.carry_over()).is_equal(140)
	assert_float(flow.score()["length_pct"] as float).is_equal_approx(0.0, 0.001)
	assert_int(flow.next_day_target(20)).is_equal(340)
	var next_flow: DayFlow = _new_day(true, flow.carry_over())
	assert_int(next_flow.target_m).is_equal(280)


func test_met_target_carries_nothing() -> void:
	var flow: DayFlow = _new_day(true)
	flow.run_ticks(9600)
	flow.bridge.set_alignment(0.0)
	assert_int(flow.carry_over()).is_equal(maxi(140 - flow.bridge.length_m(), 0))
	assert_int(flow.next_day_target(20)).is_equal(200 + flow.carry_over())


func test_score_maths() -> void:
	var perfect: Dictionary = DayFlow.score_from(140, 140, 140, 140, 0, 560, 100.0)
	assert_float(perfect["total"] as float).is_equal_approx(100.0, 0.001)
	assert_float(perfect["waste_pct"] as float).is_equal_approx(0.0, 0.001)
	var half: Dictionary = DayFlow.score_from(70, 140, 35, 70, 10, 90, 50.0)
	assert_float(half["length_pct"] as float).is_equal_approx(50.0, 0.001)
	assert_float(half["alignment_pct"] as float).is_equal_approx(50.0, 0.001)
	assert_float(half["waste_pct"] as float).is_equal_approx(10.0, 0.001)
	assert_float(half["morale_avg"] as float).is_equal_approx(50.0, 0.001)
	# 0.5*50 + 0.2*50 + 0.15*90 + 0.15*50
	assert_float(half["total"] as float).is_equal_approx(56.0, 0.001)
	var over: Dictionary = DayFlow.score_from(200, 140, 0, 200, 0, 0, 100.0)
	assert_float(over["length_pct"] as float).is_equal_approx(100.0, 0.001)
	var empty: Dictionary = DayFlow.score_from(0, 140, 0, 0, 0, 0, 0.0)
	assert_float(empty["total"] as float).is_between(0.0, 100.0)


func test_commands_validate() -> void:
	var flow: DayFlow = _new_day(false)
	assert_bool(flow.apply_command({"tick": 0, "type": "nonsense", "args": {}})).is_false()
	assert_bool(flow.apply_command({"tick": 0, "type": "assign_crews",
		"args": {"role": "cutter", "site": "quarry", "crews": 99}})).is_false()
	assert_bool(flow.apply_command({"tick": 0, "type": "assign_crews",
		"args": {"role": "cutter", "site": "quarry", "crews": 2}})).is_true()
	assert_bool(flow.apply_command({"tick": 0, "type": "place_measuring_line", "args": {"deg": 1.5}})).is_true()
	assert_bool(flow.apply_command({"tick": 0, "type": "build_station",
		"args": {"kind": "quarry", "pos": [-62.0, -28.0]}})).is_true()
	assert_bool(flow.apply_command({"tick": 0, "type": "draw_route", "args": {
		"id": "x", "from": "quarry", "to": "nowhere", "kind": "stone", "haulers": 10,
		"points": [[0, 0], [10, 0]]}})).is_false()


func test_chant_has_cooldown() -> void:
	var flow: DayFlow = _new_day(false)
	assert_bool(flow.apply_command({"tick": 0, "type": "chant_jaya", "args": {}})).is_true()
	assert_bool(flow.apply_command({"tick": 0, "type": "chant_jaya", "args": {}})).is_false()


func test_run_stops_at_sunset() -> void:
	var flow: DayFlow = _new_day(false)
	flow.run_ticks(20000)
	assert_int(flow.tick()).is_equal(9600)
