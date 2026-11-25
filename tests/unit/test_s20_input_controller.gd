extends GdUnitTestSuite
## S20 acceptance: input becomes S12 command dictionaries applied through DayFlow (DESIGN §9 S20).
## Tests feed synthetic events to _unhandled_input and assert the exact command dicts produced.

const DAY_PATH: String = "res://data/days/day_1.json"


func _load_flow() -> DayFlow:
	var text: String = FileAccess.get_file_as_string(DAY_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var flow: DayFlow = DayFlow.new()
	flow.load_day(parsed as Dictionary, 0)
	return flow


## Screen point (x, y) maps to ground (x / 10, y / 10), so expected coordinates are exact.
func _picker(p: Vector2) -> Vector2:
	return Vector2(p.x / 10.0, p.y / 10.0)


func _make_controller(flow: DayFlow) -> InputController:
	var ctrl: InputController = InputController.new()
	add_child(ctrl)
	auto_free(ctrl)
	ctrl.attach(flow, null)
	ctrl.set_ground_picker(Callable(self, "_picker"))
	return ctrl


func _mouse(button: int, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	ev.pressed = pressed
	ev.position = pos
	return ev


func _key(code: int) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code as Key
	ev.physical_keycode = code as Key
	ev.pressed = true
	return ev


func _pad(button: int, pressed: bool) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button as JoyButton
	ev.pressed = pressed
	return ev


func _click(ctrl: InputController, pos: Vector2) -> void:
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true, pos))
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false, pos))


func test_ensure_input_actions_registers_all_actions() -> void:
	var ctrl: InputController = InputController.new()
	auto_free(ctrl)
	ctrl.ensure_input_actions()
	for action: String in ["select", "cancel", "menu", "speed_up", "speed_down", "pause", "gong", "chant",
			"cursor_left", "cursor_right", "cursor_up", "cursor_down"]:
		assert_bool(InputMap.has_action(StringName(action))).is_true()


func test_gamepad_events_are_registered_on_actions() -> void:
	var ctrl: InputController = InputController.new()
	auto_free(ctrl)
	ctrl.ensure_input_actions()
	for pair: Array in [[&"select", JOY_BUTTON_A], [&"cancel", JOY_BUTTON_B], [&"pause", JOY_BUTTON_START],
			[&"speed_up", JOY_BUTTON_DPAD_UP], [&"speed_down", JOY_BUTTON_DPAD_DOWN], [&"gong", JOY_BUTTON_X],
			[&"chant", JOY_BUTTON_Y], [&"menu", JOY_BUTTON_LEFT_SHOULDER], [&"menu", JOY_BUTTON_RIGHT_SHOULDER]]:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.button_index = pair[1] as JoyButton
		ev.pressed = true
		assert_bool(ev.is_action_pressed(pair[0] as StringName)).is_true()


func test_assign_crews_command_dict() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	var ok: bool = ctrl.request_assign_crews("cutter", "quarry", 2)
	assert_bool(ok).is_true()
	assert_dict(ctrl.last_command).is_equal({
		"tick": 0, "type": "assign_crews", "args": {"role": "cutter", "site": "quarry", "crews": 2},
	})
	assert_int(ctrl.log.count()).is_equal(1)


func test_commands_use_the_current_tick() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	flow.run_ticks(5)
	ctrl.request_chant()
	assert_int((ctrl.last_command["tick"] as int)).is_equal(5)


func test_invalid_request_is_not_sent() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	var ok: bool = ctrl.request_assign_crews("sailor", "quarry", 2)
	assert_bool(ok).is_false()
	assert_int(ctrl.log.count()).is_equal(0)


func test_station_click_places_station_at_ground_point() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_station("lekhan")
	assert_str(ctrl.mode()).is_equal("station")
	_click(ctrl, Vector2(-300.0, 50.0))
	assert_dict(ctrl.last_command).is_equal({
		"tick": 0, "type": "build_station", "args": {"kind": "lekhan", "pos": [-30.0, 5.0]},
	})
	assert_bool(ctrl.last_accepted).is_true()


func test_route_drawn_by_clicks_and_finished_with_menu() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_route("r1", "forest", "head", "stone", 10)
	assert_str(ctrl.mode()).is_equal("route")
	_click(ctrl, Vector2(-600.0, 400.0))
	_click(ctrl, Vector2(-300.0, 200.0))
	_click(ctrl, Vector2(0.0, 0.0))
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2.ZERO))
	assert_str(ctrl.mode()).is_equal("idle")
	assert_dict(ctrl.last_command).is_equal({
		"tick": 0, "type": "draw_route",
		"args": {
			"id": "r1", "from": "forest", "to": "head", "kind": "stone", "haulers": 10,
			"points": [[-60.0, 40.0], [-30.0, 20.0], [0.0, 0.0]],
		},
	})
	assert_bool(ctrl.last_accepted).is_true()


func test_route_with_one_point_is_not_sent() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_route("r2", "forest", "head", "stone", 10)
	_click(ctrl, Vector2(-600.0, 400.0))
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2.ZERO))
	assert_int(ctrl.log.count()).is_equal(0)
	assert_str(ctrl.mode()).is_equal("idle")


func test_cancel_drops_route_in_progress() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_route("r3", "forest", "head", "stone", 10)
	_click(ctrl, Vector2(-600.0, 400.0))
	_click(ctrl, Vector2(0.0, 0.0))
	ctrl._unhandled_input(_key(KEY_ESCAPE))
	assert_str(ctrl.mode()).is_equal("idle")
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2.ZERO))
	assert_int(ctrl.log.count()).is_equal(0)


func test_measuring_line_angle_comes_from_drag() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_measure()
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true, Vector2(0.0, 0.0)))
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false, Vector2(100.0, 100.0)))
	assert_str(ctrl.last_command["type"] as String).is_equal("place_measuring_line")
	assert_float(((ctrl.last_command["args"] as Dictionary)["deg"] as float)).is_equal_approx(45.0, 0.001)
	assert_str(ctrl.mode()).is_equal("idle")


func test_measuring_line_ignores_tiny_drag() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_measure()
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true, Vector2(0.0, 0.0)))
	ctrl._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false, Vector2(1.0, 0.0)))
	assert_int(ctrl.log.count()).is_equal(0)


func test_gong_key_rings_selected_gong() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.select_gong("3")
	ctrl._unhandled_input(_key(KEY_G))
	assert_dict(ctrl.last_command).is_equal({"tick": 0, "type": "ring_gong", "args": {"id": "3"}})


func test_gong_key_without_selection_sends_nothing() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl._unhandled_input(_key(KEY_G))
	assert_int(ctrl.log.count()).is_equal(0)


func test_chant_key_sends_chant_command() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl._unhandled_input(_key(KEY_J))
	assert_dict(ctrl.last_command).is_equal({"tick": 0, "type": "chant_jaya", "args": {}})


func test_time_keys_request_time_control_without_commands() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	var requested: Array[StringName] = []
	ctrl.time_requested.connect(func(action: StringName) -> void: requested.append(action))
	ctrl._unhandled_input(_key(KEY_SPACE))
	ctrl._unhandled_input(_key(KEY_EQUAL))
	ctrl._unhandled_input(_key(KEY_MINUS))
	assert_array(requested).is_equal([&"pause", &"speed_up", &"speed_down"])
	assert_int(ctrl.log.count()).is_equal(0)


func test_gamepad_a_places_station_at_cursor() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_station("lekhan")
	ctrl.set_cursor(Vector2(300.0, 50.0))
	ctrl._unhandled_input(_pad(JOY_BUTTON_A, true))
	assert_dict(ctrl.last_command).is_equal({
		"tick": 0, "type": "build_station", "args": {"kind": "lekhan", "pos": [30.0, 5.0]},
	})
	assert_bool(ctrl.last_accepted).is_true()


func test_gamepad_route_drawn_at_cursor_and_finished_with_shoulder() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_route("r4", "forest", "head", "stone", 10)
	ctrl.set_cursor(Vector2(600.0, 400.0))
	ctrl._unhandled_input(_pad(JOY_BUTTON_A, true))
	ctrl.set_cursor(Vector2(300.0, 200.0))
	ctrl._unhandled_input(_pad(JOY_BUTTON_A, true))
	ctrl._unhandled_input(_pad(JOY_BUTTON_RIGHT_SHOULDER, true))
	assert_str(ctrl.mode()).is_equal("idle")
	assert_dict(ctrl.last_command).is_equal({
		"tick": 0, "type": "draw_route",
		"args": {
			"id": "r4", "from": "forest", "to": "head", "kind": "stone", "haulers": 10,
			"points": [[60.0, 40.0], [30.0, 20.0]],
		},
	})


func test_gamepad_cancel_drops_route_in_progress() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_route("r5", "forest", "head", "stone", 10)
	ctrl.set_cursor(Vector2(600.0, 400.0))
	ctrl._unhandled_input(_pad(JOY_BUTTON_A, true))
	ctrl._unhandled_input(_pad(JOY_BUTTON_B, true))
	assert_str(ctrl.mode()).is_equal("idle")
	ctrl._unhandled_input(_pad(JOY_BUTTON_LEFT_SHOULDER, true))
	assert_int(ctrl.log.count()).is_equal(0)


func test_gamepad_measuring_line_from_cursor_drag() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.begin_measure()
	ctrl.set_cursor(Vector2(0.0, 0.0))
	ctrl._unhandled_input(_pad(JOY_BUTTON_A, true))
	ctrl.set_cursor(Vector2(100.0, 100.0))
	ctrl._unhandled_input(_pad(JOY_BUTTON_A, false))
	assert_str(ctrl.last_command["type"] as String).is_equal("place_measuring_line")
	assert_float(((ctrl.last_command["args"] as Dictionary)["deg"] as float)).is_equal_approx(45.0, 0.001)


func test_gamepad_buttons_map_to_time_gong_and_chant() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	var requested: Array[StringName] = []
	ctrl.time_requested.connect(func(action: StringName) -> void: requested.append(action))
	ctrl._unhandled_input(_pad(JOY_BUTTON_START, true))
	ctrl._unhandled_input(_pad(JOY_BUTTON_DPAD_UP, true))
	ctrl._unhandled_input(_pad(JOY_BUTTON_DPAD_DOWN, true))
	assert_array(requested).is_equal([&"pause", &"speed_up", &"speed_down"])
	assert_int(ctrl.log.count()).is_equal(0)
	ctrl.select_gong("3")
	ctrl._unhandled_input(_pad(JOY_BUTTON_X, true))
	assert_dict(ctrl.last_command).is_equal({"tick": 0, "type": "ring_gong", "args": {"id": "3"}})
	ctrl._unhandled_input(_pad(JOY_BUTTON_Y, true))
	assert_dict(ctrl.last_command).is_equal({"tick": 0, "type": "chant_jaya", "args": {}})


func test_move_cursor_follows_stick_and_stays_on_screen() -> void:
	var flow: DayFlow = _load_flow()
	var ctrl: InputController = _make_controller(flow)
	ctrl.set_cursor(Vector2(100.0, 100.0))
	ctrl.move_cursor(Vector2(0.0, -1.0), 0.1)
	assert_float(ctrl.cursor().x).is_equal_approx(100.0, 0.001)
	assert_float(ctrl.cursor().y).is_equal_approx(10.0, 0.001)
	ctrl.move_cursor(Vector2(0.0, -1.0), 10.0)
	assert_float(ctrl.cursor().y).is_equal_approx(0.0, 0.001)
	ctrl.move_cursor(Vector2.ZERO, 1.0)
	assert_float(ctrl.cursor().y).is_equal_approx(0.0, 0.001)


func test_ray_to_ground_straight_down() -> void:
	assert_bool(InputController.ray_hits_ground(Vector3(3.0, 10.0, -2.0), Vector3(0.0, -1.0, 0.0))).is_true()
	var hit: Vector2 = InputController.ray_to_ground(Vector3(3.0, 10.0, -2.0), Vector3(0.0, -1.0, 0.0))
	assert_float(hit.x).is_equal_approx(3.0, 0.001)
	assert_float(hit.y).is_equal_approx(-2.0, 0.001)


func test_ray_pointing_away_from_ground_misses() -> void:
	assert_bool(InputController.ray_hits_ground(Vector3(0.0, 10.0, 0.0), Vector3(0.0, 1.0, 0.0))).is_false()


func test_camera_centre_picks_ground_under_camera() -> void:
	var flow: DayFlow = _load_flow()
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	auto_free(cam)
	cam.position = Vector3(0.0, 50.0, 0.0)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cam.make_current()
	var ctrl: InputController = InputController.new()
	add_child(ctrl)
	auto_free(ctrl)
	ctrl.attach(flow, cam)
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var ground: Vector2 = ctrl.pick_ground(centre)
	assert_float(ground.x).is_equal_approx(0.0, 0.01)
	assert_float(ground.y).is_equal_approx(0.0, 0.01)
