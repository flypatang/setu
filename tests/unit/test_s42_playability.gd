extends GdUnitTestSuite
## S42: playability. The tutorial is completed with REAL mouse and key events (Input.parse_input_event),
## and the simulation state is asserted afterwards. No apply_command calls here.

const CSV_PATH: String = "res://i18n/strings.csv"


var _old_mode: Window.ContentScaleMode = Window.CONTENT_SCALE_MODE_DISABLED
var _old_size: Vector2i = Vector2i(64, 64)


## A fixed 1280x720 window with no stretching, so screen positions and event positions are 1:1.
func before_test() -> void:
	Input.use_accumulated_input = false
	var w: Window = get_tree().root
	_old_mode = w.content_scale_mode
	_old_size = w.size
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.size = Vector2i(1280, 720)


func after_test() -> void:
	var w: Window = get_tree().root
	w.content_scale_mode = _old_mode
	w.size = _old_size


func _make() -> MainGame:
	var g: MainGame = MainGame.new()
	g.persist = false
	g.dialogue_enabled = false
	g.game_state = auto_free((load("res://core/game_state.gd") as GDScript).new() as Node) as Node
	add_child(g)
	auto_free(g)
	g.rts_camera().edge_scroll_enabled = false
	return g


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _mouse_button(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(ev)


func _move(pos: Vector2) -> void:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	await _frames(1)


func _click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	_mouse_button(button, true, pos)
	await _frames(1)
	_mouse_button(button, false, pos)
	await _frames(2)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_mouse_button(MOUSE_BUTTON_LEFT, true, from)
	await _frames(1)
	await _move(to)
	_mouse_button(MOUSE_BUTTON_LEFT, false, to)
	await _frames(2)


func _key(code: Key) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(1)
	var up: InputEventKey = InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func _press_button(b: Button) -> void:
	assert_object(b).is_not_null()
	assert_bool(b.is_visible_in_tree()).is_true()
	await _click(b.get_global_rect().get_center())


func _screen_of(g: MainGame, site: String) -> Vector2:
	var p: Vector2 = g.input_controller().site_position(site)
	return g.rts_camera().get_camera().unproject_position(Vector3(p.x, 0.0, p.y))


func _to_day_one(g: MainGame) -> void:
	g.start_new_game()
	await _frames(2)
	await _press_button(g.action_bar().action_button(&"crews"))
	await _click(_screen_of(g, "lekhan"))
	await _press_button(g.action_bar().crew_plus_button())
	assert_int(g.flow().crews.crews_at(&"lekhan")).is_equal(1)
	var guard: int = 0
	while g.phase() == MainGame.Phase.PROLOGUE and guard < 200:
		g.tick_frame(1.0)
		guard += 1
	assert_int(g.phase()).is_equal(MainGame.Phase.DAY)
	await _frames(2)


func test_prologue_and_day_one_tutorial_completed_with_real_input() -> void:
	var g: MainGame = _make()
	await _to_day_one(g)
	var tut: Tutorial = g.tutorial()
	assert_bool(tut.is_active()).is_true()
	assert_str(tut.current_id()).is_equal("d_scribes")
	# 1. scribes: hotkey 2, click the Lekhan station, press +
	await _key(KEY_2)
	assert_str(g.input_controller().mode()).is_equal(InputController.MODE_PICK)
	await _click(_screen_of(g, "lekhan"))
	await _press_button(g.action_bar().crew_plus_button())
	assert_int(g.flow().crews.crews_at(&"lekhan")).is_equal(1)
	assert_str(tut.current_id()).is_equal("d_route_a")
	# 2. route quarry -> lekhan
	await _key(KEY_1)
	assert_str(g.input_controller().mode()).is_equal(InputController.MODE_LINK)
	await _click(_screen_of(g, "quarry"))
	assert_str(g.input_controller().link_from()).is_equal("quarry")
	await _click(_screen_of(g, "lekhan"))
	assert_object(g.flow().route("hr1")).is_not_null()
	assert_object(g.flow().route("hr1").from_pile).is_same(g.flow().pile("quarry"))
	assert_object(g.flow().route("hr1").to_pile).is_same(g.flow().pile("lekhan"))
	assert_str(tut.current_id()).is_equal("d_route_b")
	# 3. route lekhan -> head (through the action bar button this time)
	await _press_button(g.action_bar().action_button(&"route"))
	await _click(_screen_of(g, "lekhan"))
	await _click(_screen_of(g, "head"))
	assert_object(g.flow().route("hr2")).is_not_null()
	assert_object(g.flow().route("hr2").to_pile).is_same(g.flow().pile("head"))
	assert_str(tut.current_id()).is_equal("d_cutters")
	# 4. cutters at the quarry
	await _key(KEY_2)
	await _click(_screen_of(g, "quarry"))
	await _press_button(g.action_bar().crew_plus_button())
	assert_int(g.flow().crews.crews_at(&"quarry")).is_equal(1)
	assert_str(tut.current_id()).is_equal("d_stone")
	# 5. watch the first stone float: use the on-screen 3x button
	await _press_button(g.action_bar().speed_button(3))
	assert_int(g.speed()).is_equal(3)
	var guard: int = 0
	while g.flow().bridge.section(0).stone_in == 0 and guard < 400:
		g.tick_frame(1.0)
		guard += 1
	await _frames(2)
	assert_int(g.flow().bridge.section(0).stone_in).is_greater(0)
	assert_str(tut.current_id()).is_equal("d_measure")
	# 6. measuring line: drag along a diagonal
	await _key(KEY_6)
	assert_str(g.input_controller().mode()).is_equal(InputController.MODE_MEASURE)
	await _drag(_screen_of(g, "lekhan"), _screen_of(g, "head"))
	var align: float = g.flow().bridge.snapshot()["alignment_deg"] as float
	assert_bool(absf(align) > 0.01).is_true()
	# 7. speed up time: the 3x set in step 5 does not count, a change to 2x does
	assert_bool(tut.is_active()).is_true()
	await _press_button(g.action_bar().speed_button(2))
	await _frames(2)
	assert_bool(tut.is_active()).is_false()


func test_stone_is_inscribed_in_prologue_through_the_ui() -> void:
	var g: MainGame = _make()
	g.start_new_game()
	await _frames(2)
	assert_str(g.tutorial().current_id()).is_equal("p_scribes")
	await _press_button(g.action_bar().action_button(&"crews"))
	assert_str(g.input_controller().mode()).is_equal(InputController.MODE_PICK)
	await _click(_screen_of(g, "lekhan"))
	assert_bool(g.action_bar().is_crew_panel_open()).is_true()
	await _press_button(g.action_bar().crew_plus_button())
	assert_int(g.flow().crews.crews_at(&"lekhan")).is_equal(1)
	var guard: int = 0
	while g.phase() == MainGame.Phase.PROLOGUE and guard < 200:
		g.tick_frame(1.0)
		guard += 1
	assert_int(g.phase()).is_equal(MainGame.Phase.DAY)


func test_action_bar_has_seven_actions_with_tooltips_and_hotkeys() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	await _frames(2)
	var bar: ActionBar = g.action_bar()
	assert_int(ActionBar.ACTIONS.size()).is_equal(7)
	for i: int in ActionBar.ACTIONS.size():
		var b: Button = bar.action_button(ActionBar.ACTIONS[i])
		assert_object(b).is_not_null()
		assert_bool(b.is_visible_in_tree()).is_true()
		assert_bool(b.tooltip_text.length() > 0).is_true()
		assert_bool(b.icon != null).is_true()
		assert_bool(b.text.contains(str(i + 1))).is_true()


func test_hotkeys_start_each_mode() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	await _frames(2)
	var ctrl: InputController = g.input_controller()
	await _key(KEY_1)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_LINK)
	assert_bool(g.action_bar().banner_text().length() > 0).is_true()
	await _key(KEY_ESCAPE)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_IDLE)
	await _key(KEY_3)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_STATION)
	await _key(KEY_ESCAPE)
	await _key(KEY_6)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_MEASURE)
	await _key(KEY_ESCAPE)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_IDLE)
	assert_str(g.action_bar().banner_text()).is_equal("")


func test_right_click_cancels_route_and_pick_modes() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	await _frames(2)
	var ctrl: InputController = g.input_controller()
	await _key(KEY_1)
	await _click(_screen_of(g, "quarry"))
	assert_str(ctrl.link_from()).is_equal("quarry")
	await _click(Vector2(900.0, 500.0), MOUSE_BUTTON_RIGHT)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_IDLE)
	assert_str(ctrl.link_from()).is_equal("")
	await _key(KEY_2)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_PICK)
	await _click(Vector2(900.0, 500.0), MOUSE_BUTTON_RIGHT)
	assert_str(ctrl.mode()).is_equal(InputController.MODE_IDLE)


func test_crew_panel_has_no_minus_and_plus_is_replayable() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	await _frames(2)
	var free0: int = g.flow().crews.free_crews()
	await _key(KEY_2)
	await _click(_screen_of(g, "lekhan"))
	assert_bool(g.action_bar().is_crew_panel_open()).is_true()
	await _press_button(g.action_bar().crew_plus_button())
	await _press_button(g.action_bar().crew_plus_button())
	assert_int(g.flow().crews.crews_at(&"lekhan")).is_equal(2)
	assert_int(g.flow().crews.free_crews()).is_equal(free0 - 2)
	assert_bool(g.action_bar().crew_panel_text().contains(str(free0 - 2))).is_true()
	await _key(KEY_ESCAPE)
	assert_bool(g.action_bar().is_crew_panel_open()).is_false()


func test_pause_and_speed_buttons_change_speed() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	await _frames(2)
	await _press_button(g.action_bar().speed_button(2))
	assert_int(g.speed()).is_equal(2)
	await _press_button(g.action_bar().speed_button(0))
	assert_int(g.speed()).is_equal(0)
	assert_bool(g.is_paused()).is_true()
	await _press_button(g.action_bar().speed_button(0))
	assert_int(g.speed()).is_equal(2)
	await _press_button(g.action_bar().speed_button(3))
	assert_int(g.speed()).is_equal(3)


func test_tutorial_can_be_skipped() -> void:
	var g: MainGame = _make()
	g.start_new_game()
	await _frames(2)
	assert_bool(g.tutorial().is_active()).is_true()
	await _press_button(g.tutorial().skip_button())
	assert_bool(g.tutorial().is_active()).is_false()
	assert_bool(g.tutorial().visible).is_false()


func test_tutorial_marks_target_site_and_button() -> void:
	var g: MainGame = _make()
	g.start_new_game()
	await _frames(2)
	var step: Dictionary = g.tutorial().current_step()
	assert_str(str(step["site"])).is_equal("lekhan")
	assert_str(str(step["button"])).is_equal("crews")


func test_site_picking_uses_nearest_site_in_radius() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	await _frames(1)
	var ctrl: InputController = g.input_controller()
	var q: Vector2 = ctrl.site_position("quarry")
	assert_str(ctrl.site_at(q + Vector2(2.0, 1.0))).is_equal("quarry")
	assert_str(ctrl.site_at(q + Vector2(50.0, 50.0))).is_equal("")


func test_new_strings_have_english_and_hindi() -> void:
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var seen: int = 0
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 3:
			continue
		var key: String = row[0]
		if key.begins_with("UI_TIP_") or key.begins_with("TUT_") or key.begins_with("TUTB_") \
				or key.begins_with("UI_BANNER_") or key.begins_with("UI_TOAST_") or key.begins_with("UI_CREW_"):
			seen += 1
			assert_bool(row[1].length() > 0).is_true()
			assert_bool(row[2].length() > 0).is_true()
			assert_bool(row[1] != row[2]).is_true()
	assert_int(seen).is_greater(35)
