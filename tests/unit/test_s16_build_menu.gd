extends GdUnitTestSuite
## S16 acceptance: radial build menu (DESIGN §5, §9 S16). Options sit on a circle, gamepad direction
## selects the matching option, mouse hover and click work, and labels come from tr() keys UI_BUILD_<ID>.

const MENU_SCRIPT: String = "res://ui/build_menu.gd"
const MENU_SIZE: Vector2 = Vector2(400.0, 400.0)


func _make_menu() -> BuildMenu:
	var menu: BuildMenu = (load(MENU_SCRIPT) as GDScript).new() as BuildMenu
	menu.size = MENU_SIZE
	add_child(menu)
	auto_free(menu)
	return menu


var _translations: Array[Translation] = []


## Installs test-local en and hi catalogues for the UI_BUILD_* keys; the shared strings CSV is not used here.
func _install_build_translations() -> void:
	var en: Translation = Translation.new()
	en.locale = "en"
	en.add_message(&"UI_BUILD_ROUTE", "Route")
	en.add_message(&"UI_BUILD_CREWS", "Crews")
	en.add_message(&"UI_BUILD_LEKHAN", "Inscribe")
	en.add_message(&"UI_BUILD_GONG", "Gong")
	en.add_message(&"UI_BUILD_SHELTER", "Shelter")
	en.add_message(&"UI_BUILD_MEASURING_LINE", "Measuring line")
	en.add_message(&"UI_BUILD_CHANT", "Chant")
	var hi: Translation = Translation.new()
	hi.locale = "hi"
	hi.add_message(&"UI_BUILD_ROUTE", "मार्ग")
	hi.add_message(&"UI_BUILD_CREWS", "दल")
	hi.add_message(&"UI_BUILD_LEKHAN", "लेखन")
	hi.add_message(&"UI_BUILD_GONG", "घंटा")
	hi.add_message(&"UI_BUILD_SHELTER", "आश्रय")
	hi.add_message(&"UI_BUILD_MEASURING_LINE", "माप की रस्सी")
	hi.add_message(&"UI_BUILD_CHANT", "उद्घोष")
	_translations = [en, hi]
	for t: Translation in _translations:
		TranslationServer.add_translation(t)


func before_test() -> void:
	_install_build_translations()


func after_test() -> void:
	TranslationServer.set_locale("en")
	for t: Translation in _translations:
		TranslationServer.remove_translation(t)
	_translations.clear()


func test_menu_lists_the_seven_contract_options() -> void:
	var menu: BuildMenu = _make_menu()
	var ids: Array[StringName] = menu.option_ids()
	assert_int(ids.size()).is_equal(7)
	assert_array(ids).contains([&"route", &"crews", &"lekhan", &"gong", &"shelter", &"measuring_line", &"chant"])


func test_options_are_laid_out_on_a_circle() -> void:
	var menu: BuildMenu = _make_menu()
	var centre: Vector2 = menu.size * 0.5
	for i: int in menu.option_ids().size():
		var anchor: Vector2 = menu.option_anchor(i)
		assert_float((anchor - centre).length()).is_equal_approx(BuildMenu.DEFAULT_RADIUS, 0.001)
		var button: Button = menu.get_child(i) as Button
		assert_object(button).is_not_null()
		var button_centre: Vector2 = button.position + button.size * 0.5
		assert_float(button_centre.distance_to(anchor)).is_equal_approx(0.0, 0.01)


func test_options_are_evenly_spaced_around_the_circle() -> void:
	var menu: BuildMenu = _make_menu()
	var count: int = menu.option_ids().size()
	var step: float = TAU / float(count)
	for i: int in count:
		var a: Vector2 = menu.option_direction(i)
		var b: Vector2 = menu.option_direction((i + 1) % count)
		assert_float(a.angle_to(b)).is_equal_approx(step, 0.001)


func test_gamepad_up_selects_route() -> void:
	var menu: BuildMenu = _make_menu()
	var index: int = menu.select_direction(Vector2.UP)
	assert_int(index).is_equal(0)
	assert_str(String(menu.selected_id())).is_equal("route")


func test_gamepad_right_selects_lekhan() -> void:
	var menu: BuildMenu = _make_menu()
	menu.select_direction(Vector2.RIGHT)
	assert_str(String(menu.selected_id())).is_equal("lekhan")


func test_gamepad_left_selects_measuring_line() -> void:
	var menu: BuildMenu = _make_menu()
	menu.select_direction(Vector2.LEFT)
	assert_str(String(menu.selected_id())).is_equal("measuring_line")


func test_accept_emits_the_selected_option() -> void:
	var menu: BuildMenu = _make_menu()
	var chosen: Array[StringName] = []
	menu.option_chosen.connect(func(id: StringName) -> void: chosen.append(id))
	menu.select_direction(Vector2.LEFT)
	menu.confirm_selection()
	assert_array(chosen).has_size(1)
	assert_str(String(chosen[0])).is_equal("measuring_line")


func test_mouse_hover_selects_and_click_emits() -> void:
	var menu: BuildMenu = _make_menu()
	var chosen: Array[StringName] = []
	menu.option_chosen.connect(func(id: StringName) -> void: chosen.append(id))
	var gong: Button = menu.get_child(3) as Button
	gong.mouse_entered.emit()
	assert_str(String(menu.selected_id())).is_equal("gong")
	gong.pressed.emit()
	assert_array(chosen).has_size(1)
	assert_str(String(chosen[0])).is_equal("gong")


func test_labels_use_translation_keys_and_translate() -> void:
	var menu: BuildMenu = _make_menu()
	TranslationServer.set_locale("en")
	menu.refresh_labels()
	assert_str(menu.label_text(0)).is_equal("Haul route")
	assert_str(menu.label_text(5)).is_equal("Measuring line")

	TranslationServer.set_locale("hi")
	menu.refresh_labels()
	for i: int in menu.option_ids().size():
		var id: String = String(menu.option_ids()[i])
		var expected: String = tr("UI_BUILD_" + id.to_upper())
		assert_str(menu.label_text(i)).is_equal(expected)
		assert_bool(expected == "UI_BUILD_" + id.to_upper()).is_false()
	assert_str(menu.label_text(0)).is_equal("ढुलाई मार्ग")


func test_gamepad_diagonal_and_bottom_directions_select_their_options() -> void:
	var menu: BuildMenu = _make_menu()
	menu.select_direction(Vector2(1.0, -1.0))
	assert_str(String(menu.selected_id())).is_equal("crews")
	menu.select_direction(Vector2(-1.0, -1.0))
	assert_str(String(menu.selected_id())).is_equal("chant")
	menu.select_direction(Vector2.DOWN)
	var down_index: int = menu.selected_index()
	assert_bool(down_index == 3 or down_index == 4).is_true()
	assert_float(menu.option_direction(down_index).y).is_greater(0.8)


func test_shelter_and_chant_are_laid_out_and_selectable() -> void:
	var menu: BuildMenu = _make_menu()
	menu.select_direction(menu.option_direction(4))
	assert_str(String(menu.selected_id())).is_equal("shelter")
	menu.select_direction(menu.option_direction(6))
	assert_str(String(menu.selected_id())).is_equal("chant")


func test_cancel_action_closes_the_menu() -> void:
	var menu: BuildMenu = _make_menu()
	menu.open_at(Vector2(200.0, 200.0))
	assert_bool(menu.visible).is_true()
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._unhandled_input(cancel)
	assert_bool(menu.visible).is_false()


func test_menu_starts_closed() -> void:
	var menu: BuildMenu = _make_menu()
	assert_bool(menu.visible).is_false()


func test_joypad_stick_sweep_updates_selection_while_held() -> void:
	var menu: BuildMenu = _make_menu()
	menu.open_at(Vector2(200.0, 200.0))
	var stick_x: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick_x.axis = JOY_AXIS_LEFT_X
	stick_x.axis_value = 1.0
	menu._unhandled_input(stick_x)
	assert_str(String(menu.selected_id())).is_equal("lekhan")

	# Sweep from right to up without releasing past the deadzone: the selection must follow the stick.
	var stick_y: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick_y.axis = JOY_AXIS_LEFT_Y
	stick_y.axis_value = -1.0
	menu._unhandled_input(stick_y)
	assert_str(String(menu.selected_id())).is_equal("crews")
	stick_x.axis_value = 0.0
	menu._unhandled_input(stick_x)
	assert_str(String(menu.selected_id())).is_equal("route")

	# Re-push left after a release: the selection follows again.
	stick_y.axis_value = 0.0
	menu._unhandled_input(stick_y)
	stick_x.axis_value = -1.0
	menu._unhandled_input(stick_x)
	assert_str(String(menu.selected_id())).is_equal("measuring_line")


func test_stick_state_is_reset_on_reopen() -> void:
	var menu: BuildMenu = _make_menu()
	menu.open_at(Vector2(200.0, 200.0))
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	menu._unhandled_input(motion)
	# Stick still held when the menu closes.
	menu.close()
	menu.open_at(Vector2(200.0, 200.0))
	menu._unhandled_input(motion)
	assert_str(String(menu.selected_id())).is_equal("lekhan")


func test_open_near_edge_keeps_the_circle_inside_the_viewport() -> void:
	var menu: BuildMenu = _make_menu()
	var viewport_rect: Rect2 = menu.get_viewport_rect()
	menu.open_at(viewport_rect.position)
	var centre: Vector2 = menu.global_position + menu.size * 0.5
	var extent: Vector2 = Vector2(BuildMenu.DEFAULT_RADIUS, BuildMenu.DEFAULT_RADIUS) + BuildMenu.BUTTON_SIZE * 0.5
	assert_float(centre.x - extent.x).is_greater_equal(viewport_rect.position.x - 0.01)
	assert_float(centre.y - extent.y).is_greater_equal(viewport_rect.position.y - 0.01)
	menu.open_at(viewport_rect.end)
	centre = menu.global_position + menu.size * 0.5
	assert_float(centre.x + extent.x).is_less_equal(viewport_rect.end.x + 0.01)
	assert_float(centre.y + extent.y).is_less_equal(viewport_rect.end.y + 0.01)
