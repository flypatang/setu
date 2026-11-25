extends GdUnitTestSuite
## S23 acceptance: dialogue box (DESIGN §5, §7, §9 S23). Plays dialogue through DialogueRunner, types text by
## grapheme cluster (a Devanagari conjunct is never shown half-drawn), shows choices as buttons, starts at a node
## given as "file#node", and shows a shloka card for shloka steps before resuming.

const BOX_SCRIPT: String = "res://ui/dialogue_box.gd"
const FIXTURE_DIR: String = "user://s23_fixtures/"
const MAIN_FILE: String = "s23_main"
const CONJ_FILE: String = "s23_conj"
const CONJ_KEY: String = "S23_LINE_CONJ"
const CONJ_TEXT: String = "क्षमा"

var _box: DialogueBox = null
var _translation: Translation = null


func before_test() -> void:
	TranslationServer.set_locale("en")
	_make_fixture_dir()
	_write_fixture(MAIN_FILE, "n1", {
		"n1": {"speaker": "rama", "text_key": "S23_LINE_1", "next": "n2"},
		"n2": {"speaker": "narrator", "text_key": "S23_LINE_2",
			"choices": [
				{"text_key": "S23_CH_A", "next": "n3", "flags": {}, "smarana": 0},
				{"text_key": "S23_CH_B", "next": "n4", "flags": {}, "smarana": 0},
			]},
		"n3": {"shloka": "yk_aham_setum", "next": "n5"},
		"n4": {"speaker": "narrator", "text_key": "S23_LINE_4", "next": "n5"},
		"n5": {"speaker": "narrator", "text_key": "S23_LINE_5", "next": null},
	})
	_write_fixture(CONJ_FILE, "c1", {
		"c1": {"speaker": "rama", "text_key": CONJ_KEY, "next": null},
	})
	_translation = Translation.new()
	_translation.locale = "en"
	_translation.add_message(StringName(CONJ_KEY), CONJ_TEXT)
	TranslationServer.add_translation(_translation)
	_box = (load(BOX_SCRIPT) as GDScript).new() as DialogueBox
	_box.dialogue_dir = FIXTURE_DIR
	_box.shloka_mode = ShlokaCard.MODE_OFF
	add_child(_box)
	auto_free(_box)


func after_test() -> void:
	TranslationServer.remove_translation(_translation)
	TranslationServer.set_locale("en")
	_remove_fixture_dir()


func _make_fixture_dir() -> void:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)


func _write_fixture(file_id: String, start: String, nodes: Dictionary) -> void:
	var data: Dictionary = {"id": file_id, "start": start, "nodes": nodes}
	var file: FileAccess = FileAccess.open(FIXTURE_DIR + file_id + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _remove_fixture_dir() -> void:
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	for name: String in dir.get_files():
		dir.remove(name)


func _accept_event() -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	return ev


# --- grapheme clusters -----------------------------------------------------------------------------------------

func test_conjunct_ksha_is_one_cluster() -> void:
	var clusters: Array[String] = DialogueBox.split_graphemes("क्ष")
	assert_array(clusters).has_size(1)
	assert_str(clusters[0]).is_equal("क्ष")


func test_conjunct_shri_is_one_cluster_and_spaces_split_words() -> void:
	var clusters: Array[String] = DialogueBox.split_graphemes("श्री राम")
	assert_str(clusters[0]).is_equal("श्री")
	assert_str(clusters[1]).is_equal(" ")
	assert_int(clusters.size()).is_equal(4)


func test_typewriter_never_shows_half_a_conjunct() -> void:
	_box.chars_per_second = 1.0
	_box.play(StringName(CONJ_FILE))
	_box.step_typewriter(1.0)
	assert_str(_box.revealed_text()).is_equal("क्ष")
	assert_str(_box.revealed_text()).is_not_equal("क्")


# --- playing ---------------------------------------------------------------------------------------------------

func test_play_missing_file_returns_an_error() -> void:
	var err: Error = _box.play(&"s23_does_not_exist")
	assert_int(err).is_not_equal(OK)
	assert_bool(_box.is_playing()).is_false()


func test_first_line_types_out_and_accept_reveals_then_advances() -> void:
	_box.chars_per_second = 1000.0
	assert_int(_box.play(StringName(MAIN_FILE))).is_equal(OK)
	assert_bool(_box.is_playing()).is_true()
	assert_bool(_box.is_typing()).is_true()
	_box.handle_input_event(_accept_event())
	assert_str(_box.revealed_text()).is_equal("S23_LINE_1")
	assert_bool(_box.is_typing()).is_false()
	_box.handle_input_event(_accept_event())
	_box.reveal_all()
	assert_str(_box.revealed_text()).is_equal("S23_LINE_2")


func test_choices_stay_hidden_until_the_text_has_typed_out() -> void:
	_box.play(StringName(MAIN_FILE))
	_box.reveal_all()
	_box.handle_input_event(_accept_event())
	assert_bool(_box.is_typing()).is_true()
	assert_int(_box.choice_buttons().size()).is_equal(2)
	assert_bool(_box.choice_buttons()[0].visible).is_false()
	_box.reveal_all()
	assert_bool(_box.choice_buttons()[0].visible).is_true()


func test_choice_button_emits_choice_selected_and_moves_on() -> void:
	_box.play(StringName(MAIN_FILE))
	_box.reveal_all()
	_box.handle_input_event(_accept_event())
	_box.reveal_all()
	var buttons: Array[Button] = _box.choice_buttons()
	assert_int(buttons.size()).is_equal(2)
	var picked: Array[int] = []
	_box.choice_selected.connect(func(i: int) -> void: picked.append(i))
	buttons[1].pressed.emit()
	assert_array(picked).is_equal([1])
	assert_str(_box.get_runner().current_node()).is_equal("n4")
	assert_str(_box.revealed_text()).is_equal("")


func test_accept_does_nothing_while_a_choice_waits() -> void:
	_box.play(StringName(MAIN_FILE))
	_box.reveal_all()
	_box.handle_input_event(_accept_event())
	_box.reveal_all()
	assert_bool(_box.handle_input_event(_accept_event())).is_false()
	assert_str(_box.get_runner().current_node()).is_equal("n2")


func test_play_at_a_node_reference_starts_there() -> void:
	_box.play(StringName(MAIN_FILE + "#n5"))
	_box.reveal_all()
	assert_str(_box.revealed_text()).is_equal("S23_LINE_5")


func test_finishing_the_dialogue_emits_finished_and_hides() -> void:
	_box.play(StringName(MAIN_FILE + "#n5"))
	var done: Array[StringName] = []
	_box.finished.connect(func(id: StringName) -> void: done.append(id))
	_box.reveal_all()
	_box.handle_input_event(_accept_event())
	assert_bool(_box.is_playing()).is_false()
	assert_bool(_box.visible).is_false()
	assert_array(done).is_equal([StringName(MAIN_FILE)])


# --- shloka steps ----------------------------------------------------------------------------------------------

func test_shloka_step_with_mode_off_resumes_at_once() -> void:
	_box.play(StringName(MAIN_FILE + "#n3"))
	assert_bool(_box.is_card_open()).is_false()
	assert_str(_box.get_runner().current_node()).is_equal("n5")
	_box.reveal_all()
	assert_str(_box.revealed_text()).is_equal("S23_LINE_5")


func test_shloka_step_shows_the_card_and_resumes_when_it_closes() -> void:
	_box.shloka_mode = ShlokaCard.MODE_ON
	_box.play(StringName(MAIN_FILE + "#n3"))
	assert_bool(_box.is_card_open()).is_true()
	assert_str(_box.get_runner().current_node()).is_equal("n3")
	var card: ShlokaCard = _box.get_card()
	card.advance_time(4.0)
	card.handle_input_event(_accept_event())
	assert_bool(_box.is_card_open()).is_false()
	assert_str(_box.get_runner().current_node()).is_equal("n5")
