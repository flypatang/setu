extends GdUnitTestSuite
## Acceptance tests for ui/hud.gd (DESIGN §9, S17). Headless: the HUD is driven by a DayFlow fixture.

const DAY_1_PATH: String = "res://data/days/day_1.json"


func before_test() -> void:
	_register_ui_strings()


func after_test() -> void:
	TranslationServer.set_locale("en")


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text) as Dictionary


func _flow(ticks: int) -> DayFlow:
	var flow: DayFlow = DayFlow.new()
	flow.load_day(_read_json(DAY_1_PATH))
	flow.run_ticks(ticks)
	return flow


func _hud() -> Hud:
	return auto_free(Hud.new()) as Hud


func test_clock_formats_time_to_sunset() -> void:
	assert_str(Hud.format_clock(0, 9600)).is_equal("08:00")
	assert_str(Hud.format_clock(4800, 9600)).is_equal("04:00")
	assert_str(Hud.format_clock(9600, 9600)).is_equal("00:00")
	assert_str(Hud.format_clock(12000, 9600)).is_equal("00:00")


func test_clock_value_updates_from_day_flow() -> void:
	var hud: Hud = _hud()
	var flow: DayFlow = _flow(0)
	hud.update_from(flow)
	assert_str(hud.clock_text()).contains("08:00")
	assert_str(hud.clock_text()).contains("1")
	flow.run_ticks(4800)
	hud.update_from(flow)
	assert_str(hud.clock_text()).contains("04:00")


func test_length_shows_bridge_against_target() -> void:
	var hud: Hud = _hud()
	var flow: DayFlow = _flow(0)
	hud.update_from(flow)
	assert_str(hud.length_text()).contains("%d" % flow.bridge.length_m())
	assert_str(hud.length_text()).contains("%d" % flow.target_m)
	assert_int(flow.target_m).is_equal(140)
	assert_str(hud.length_text()).contains("140")


func test_stockpile_counts_come_from_head_pile() -> void:
	var hud: Hud = _hud()
	var flow: DayFlow = _flow(0)
	var head: Stockpile = flow.pile("head")
	head.add("stone", 7)
	head.add("timber", 3)
	hud.update_from(flow)
	assert_str(hud.stock_text("stone")).contains("7")
	assert_str(hud.stock_text("timber")).contains("3")
	assert_str(hud.stock_text("rope")).contains("0")
	assert_str(hud.stock_text("inscribed_stone")).contains("0")


func test_morale_bar_follows_utsaha() -> void:
	var hud: Hud = _hud()
	var flow: DayFlow = _flow(0)
	flow.morale.utsaha = 73.0
	hud.update_from(flow)
	assert_float(hud.morale_value()).is_equal_approx(73.0, 0.001)
	flow.morale.utsaha = 12.0
	hud.update_from(flow)
	assert_float(hud.morale_value()).is_equal_approx(12.0, 0.001)


func test_advisor_line_shows_speaker_and_translated_text() -> void:
	var hud: Hud = _hud()
	hud.show_advisor(&"nila", "SDLG_D2_001")
	assert_str(hud.advisor_speaker_text()).is_equal(tr("SPK_NILA"))
	assert_str(hud.advisor_speaker_text()).is_equal("Nila")
	assert_str(hud.advisor_text()).is_equal(tr("SDLG_D2_001"))
	assert_str(hud.advisor_text()).is_not_equal("SDLG_D2_001")


func test_labels_translate_when_locale_switches() -> void:
	var hud: Hud = _hud()
	var flow: DayFlow = _flow(0)
	flow.pile("head").add("stone", 5)
	hud.show_advisor(&"nala", "SDLG_D1_001")
	hud.update_from(flow)
	var en_stock: String = hud.stock_text("stone")
	var en_clock: String = hud.clock_text()
	var en_speaker: String = hud.advisor_speaker_text()

	TranslationServer.set_locale("hi")
	hud.refresh()
	assert_str(hud.stock_text("stone")).is_not_equal(en_stock)
	assert_str(hud.stock_text("stone")).contains("5")
	assert_str(hud.clock_text()).is_not_equal(en_clock)
	assert_str(hud.clock_text()).contains("08:00")
	assert_str(hud.advisor_speaker_text()).is_equal("नल")
	assert_str(hud.advisor_speaker_text()).is_not_equal(en_speaker)

	TranslationServer.set_locale("en")
	hud.refresh()
	assert_str(hud.stock_text("stone")).is_equal(en_stock)
	assert_str(hud.clock_text()).is_equal(en_clock)
	assert_str(hud.advisor_speaker_text()).is_equal(en_speaker)


## UI strings (UI_HUD_*, UI_SUM_*) for this suite. Registered in-memory so the tests do not depend on
## i18n/strings.csv (owned by SC2); the same values are the intended rows for en and hi.
func _register_ui_strings() -> void:
	var en_table: Translation = Translation.new()
	en_table.locale = "en"
	en_table.add_message("UI_HUD_CLOCK", "Day %d — sunset in %s")
	en_table.add_message("UI_HUD_LENGTH", "Bridge %d / %d m")
	en_table.add_message("UI_HUD_STOCK_STONE", "Stone: %d")
	en_table.add_message("UI_HUD_STOCK_INSCRIBED", "Inscribed: %d")
	en_table.add_message("UI_HUD_STOCK_TIMBER", "Timber: %d")
	en_table.add_message("UI_HUD_STOCK_ROPE", "Rope: %d")
	en_table.add_message("UI_HUD_MORALE", "Morale %d")
	en_table.add_message("UI_SUM_TITLE", "Day %d complete")
	en_table.add_message("UI_SUM_LENGTH", "Length: %.0f%%")
	en_table.add_message("UI_SUM_ALIGN", "Alignment: %.0f%%")
	en_table.add_message("UI_SUM_WASTE", "Waste: %.0f%%")
	en_table.add_message("UI_SUM_MORALE", "Morale: %.0f")
	en_table.add_message("UI_SUM_TOTAL", "Score: %.0f")
	en_table.add_message("UI_SUM_CARRY", "Carried to tomorrow: %d m")
	en_table.add_message("UI_SUM_CONTINUE", "Continue")
	TranslationServer.add_translation(en_table)
	var hi_table: Translation = Translation.new()
	hi_table.locale = "hi"
	hi_table.add_message("UI_HUD_CLOCK", "दिन %d — सूर्यास्त में %s
")
	hi_table.add_message("UI_HUD_LENGTH", "सेतु %d / %d मी.
")
	hi_table.add_message("UI_HUD_STOCK_STONE", "पत्थर: %d
")
	hi_table.add_message("UI_HUD_STOCK_INSCRIBED", "लिखे पत्थर: %d
")
	hi_table.add_message("UI_HUD_STOCK_TIMBER", "लकड़ी: %d
")
	hi_table.add_message("UI_HUD_STOCK_ROPE", "रस्सी: %d
")
	hi_table.add_message("UI_HUD_MORALE", "उत्साह %d
")
	hi_table.add_message("UI_SUM_TITLE", "दिन %d पूर्ण
")
	hi_table.add_message("UI_SUM_LENGTH", "लंबाई: %.0f%%
")
	hi_table.add_message("UI_SUM_ALIGN", "संरेखण: %.0f%%
")
	hi_table.add_message("UI_SUM_WASTE", "बर्बादी: %.0f%%
")
	hi_table.add_message("UI_SUM_MORALE", "उत्साह: %.0f
")
	hi_table.add_message("UI_SUM_TOTAL", "कुल अंक: %.0f
")
	hi_table.add_message("UI_SUM_CARRY", "कल पर शेष: %d मी.
")
	hi_table.add_message("UI_SUM_CONTINUE", "आगे बढ़ें
")
	TranslationServer.add_translation(hi_table)
