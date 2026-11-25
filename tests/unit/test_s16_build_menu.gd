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


func after_test() -> void:
	TranslationServer.set_locale("en")


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
	assert_str(menu.label_text(0)).is_equal("Route")
	assert_str(menu.label_text(5)).is_equal("Measuring line")

	TranslationServer.set_locale("hi")
	menu.refresh_labels()
	for i: int in menu.option_ids().size():
		var id: String = String(menu.option_ids()[i])
		var expected: String = tr("UI_BUILD_" + id.to_upper())
		assert_str(menu.label_text(i)).is_equal(expected)
		assert_bool(expected == "UI_BUILD_" + id.to_upper()).is_false()
	assert_str(menu.label_text(0)).is_equal("मार्ग")
