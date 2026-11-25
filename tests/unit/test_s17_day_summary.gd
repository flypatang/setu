extends GdUnitTestSuite
## Acceptance tests for ui/day_summary.gd (DESIGN §9, S17). Headless: driven by DayFlow fixtures.

const DAY_1_PATH: String = "res://data/days/day_1.json"
const PLAN_PATH: String = "res://tests/unit/fixtures/plan_day1.json"

var _continued: bool = false


func after_test() -> void:
	TranslationServer.set_locale("en")


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text) as Dictionary


func _finished_flow(with_plan: bool) -> DayFlow:
	var flow: DayFlow = DayFlow.new()
	flow.load_day(_read_json(DAY_1_PATH))
	if with_plan:
		flow.queue_commands(_read_json(PLAN_PATH)["commands"] as Array)
	flow.run_ticks(9600)
	return flow


func _summary() -> DaySummary:
	return auto_free(DaySummary.new()) as DaySummary


func _on_continued() -> void:
	_continued = true


func test_summary_shows_score_fields() -> void:
	var flow: DayFlow = _finished_flow(true)
	var sc: Dictionary = flow.score()
	var summary: DaySummary = _summary()
	summary.show_summary(flow)
	assert_str(summary.total_text()).contains("%.0f" % (sc["total"] as float))
	assert_str(summary.length_text()).contains("%.0f" % (sc["length_pct"] as float))
	assert_str(summary.alignment_text()).contains("%.0f" % (sc["alignment_pct"] as float))
	assert_str(summary.waste_text()).contains("%.0f" % (sc["waste_pct"] as float))
	assert_str(summary.morale_text()).contains("%.0f" % (sc["morale_avg"] as float))


func test_summary_shows_carry_over_and_day() -> void:
	var flow: DayFlow = _finished_flow(false)
	var summary: DaySummary = _summary()
	summary.show_summary(flow)
	assert_str(summary.title_text()).contains("1")
	assert_str(summary.carry_text()).contains("%d" % flow.carry_over())
	assert_int(flow.carry_over()).is_equal(140)
	assert_str(summary.carry_text()).contains("140")


func test_continue_button_emits_signal() -> void:
	var flow: DayFlow = _finished_flow(true)
	var summary: DaySummary = _summary()
	summary.show_summary(flow)
	_continued = false
	summary.continue_pressed.connect(_on_continued)
	summary.continue_button().pressed.emit()
	assert_bool(_continued).is_true()


func test_summary_labels_translate_when_locale_switches() -> void:
	var flow: DayFlow = _finished_flow(true)
	var summary: DaySummary = _summary()
	summary.show_summary(flow)
	var en_title: String = summary.title_text()
	var en_button: String = summary.continue_button().text
	var en_total: String = summary.total_text()

	TranslationServer.set_locale("hi")
	summary.refresh()
	assert_str(summary.title_text()).is_not_equal(en_title)
	assert_str(summary.continue_button().text).is_not_equal(en_button)
	assert_str(summary.total_text()).is_not_equal(en_total)
	assert_str(summary.total_text()).contains("%.0f" % (flow.score()["total"] as float))

	TranslationServer.set_locale("en")
	summary.refresh()
	assert_str(summary.title_text()).is_equal(en_title)
	assert_str(summary.continue_button().text).is_equal(en_button)
	assert_str(summary.total_text()).is_equal(en_total)
