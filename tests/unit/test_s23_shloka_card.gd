extends GdUnitTestSuite
## S23 acceptance: shloka card (DESIGN §7, §9 S23). Mode on waits at least 4 s, then any key closes it.
## Mode short shows the translation only and closes after 3 s. Mode off closes at once. Text follows the locale.

const CARD_SCRIPT: String = "res://ui/shloka_card.gd"
const SHLOKA_ID: String = "yk_nala_son_of_vishwakarma"

var _card: ShlokaCard = null


func before_test() -> void:
	_card = (load(CARD_SCRIPT) as GDScript).new() as ShlokaCard
	add_child(_card)
	auto_free(_card)


func after_test() -> void:
	TranslationServer.set_locale("en")


func _key_event() -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	return ev


func test_on_mode_has_four_second_minimum_before_any_key_closes() -> void:
	_card.mode = ShlokaCard.MODE_ON
	_card.show_shloka(StringName(SHLOKA_ID))
	assert_bool(_card.is_open()).is_true()
	_card.advance_time(3.9)
	_card.handle_input_event(_key_event())
	assert_bool(_card.is_open()).is_true()
	_card.advance_time(0.2)
	_card.handle_input_event(_key_event())
	assert_bool(_card.is_open()).is_false()


func test_on_mode_closes_with_closed_signal_carrying_the_id() -> void:
	_card.mode = ShlokaCard.MODE_ON
	_card.show_shloka(StringName(SHLOKA_ID))
	_card.advance_time(4.0)
	var got: Array[StringName] = []
	_card.closed.connect(func(id: StringName) -> void: got.append(id))
	_card.handle_input_event(_key_event())
	assert_array(got).is_equal([StringName(SHLOKA_ID)])


func test_on_mode_does_not_close_by_itself() -> void:
	_card.mode = ShlokaCard.MODE_ON
	_card.show_shloka(StringName(SHLOKA_ID))
	_card.advance_time(60.0)
	assert_bool(_card.is_open()).is_true()


func test_short_mode_shows_translation_only_and_closes_after_three_seconds() -> void:
	_card.mode = ShlokaCard.MODE_SHORT
	_card.show_shloka(StringName(SHLOKA_ID))
	assert_bool(_card.devanagari_shown()).is_false()
	assert_bool(_card.translation_shown()).is_true()
	_card.advance_time(2.9)
	assert_bool(_card.is_open()).is_true()
	_card.advance_time(0.2)
	assert_bool(_card.is_open()).is_false()


func test_off_mode_skips_the_card_at_once() -> void:
	_card.mode = ShlokaCard.MODE_OFF
	var got: Array[StringName] = []
	_card.closed.connect(func(id: StringName) -> void: got.append(id))
	_card.show_shloka(StringName(SHLOKA_ID))
	assert_bool(_card.is_open()).is_false()
	assert_array(got).is_equal([StringName(SHLOKA_ID)])


func test_on_mode_shows_devanagari_iast_and_reference_from_data() -> void:
	var entry: Dictionary = Shlokas.get_shloka(SHLOKA_ID)
	_card.mode = ShlokaCard.MODE_ON
	_card.show_shloka(StringName(SHLOKA_ID))
	assert_bool(_card.devanagari_shown()).is_true()
	assert_str(_card.devanagari_text()).is_equal(str(entry.get("devanagari", "")))
	assert_str(_card.iast_text()).is_equal(str(entry.get("iast", "")))
	assert_str(_card.reference_text()).is_equal(str(entry.get("ref", "")))


func test_devanagari_is_drawn_in_gold() -> void:
	assert_bool(_card.devanagari_color() == Palette.GOLD).is_true()


func test_translation_follows_the_locale() -> void:
	TranslationServer.set_locale("en")
	_card.show_shloka(StringName(SHLOKA_ID))
	assert_str(_card.translation_text()).contains("Nala")
	TranslationServer.set_locale("hi")
	_card.show_shloka(StringName(SHLOKA_ID))
	assert_str(_card.translation_text()).contains("नल")


func test_unknown_shloka_id_opens_without_crashing() -> void:
	_card.mode = ShlokaCard.MODE_ON
	_card.show_shloka(&"no_such_shloka")
	assert_bool(_card.is_open()).is_true()
	assert_str(_card.devanagari_text()).is_empty()
