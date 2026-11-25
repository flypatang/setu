extends GdUnitTestSuite
## S31: UX polish in the main game. Day start framing, live-translated controls hint.

const HINT_KEY: String = "UI_HUD_CONTROLS"
const LOCALE_SCRIPT: String = "res://core/locale.gd"
const DAY_START_ORTHO: float = 45.0


func after_test() -> void:
	TranslationServer.set_locale("en")


func _make() -> MainGame:
	var g: MainGame = MainGame.new()
	g.persist = false
	g.dialogue_enabled = false
	g.game_state = auto_free((load("res://core/game_state.gd") as GDScript).new() as Node) as Node
	add_child(g)
	auto_free(g)
	return g


func test_day_start_frames_bridge_head_at_ortho_45() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	assert_float(g.rts_camera().ortho_size()).is_equal_approx(DAY_START_ORTHO, 0.001)


func test_day_start_focus_is_on_the_bridge_head() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	# Day 1 has no bridge yet, so the head is the origin of the bridge.
	assert_float(g.rts_camera().focus_target().x).is_equal_approx(g.origin_x(), 0.001)
	assert_float(g.rts_camera().focus_target().y).is_equal_approx(0.0, 0.001)


func test_day_two_focus_follows_the_cumulative_head() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	g.flow().queue_commands(BotDays.load_plan(1))
	g.set_speed(3)
	var guard: int = 0
	while g.phase() == MainGame.Phase.DAY and guard < 400:
		g.tick_frame(1.0)
		guard += 1
	g.continue_from_summary()
	assert_int(g.flow().day).is_equal(2)
	var built: float = float(g.cumulative_m())
	assert_float(g.rts_camera().focus_target().x).is_equal_approx(built, 0.001)
	assert_float(g.rts_camera().ortho_size()).is_equal_approx(DAY_START_ORTHO, 0.001)


func test_controls_hint_is_translated_live() -> void:
	# Loading the Locale script builds the translations the same way the autoload does.
	var loc: Node = auto_free((load(LOCALE_SCRIPT) as GDScript).new() as Node) as Node
	assert_object(loc).is_not_null()
	var g: MainGame = _make()
	g.begin_day(1)
	var hint: Label = g.hint_label()
	assert_object(hint).is_not_null()

	TranslationServer.set_locale("en")
	g.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	var en_text: String = hint.text
	assert_str(en_text).is_equal(str(TranslationServer.translate(HINT_KEY)))

	TranslationServer.set_locale("hi")
	g.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_str(hint.text).is_equal(str(TranslationServer.translate(HINT_KEY)))
	assert_bool(hint.text != en_text).is_true()
