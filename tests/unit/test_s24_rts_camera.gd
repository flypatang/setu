extends GdUnitTestSuite
## S24 acceptance: the isometric RTS camera (game/rts_camera.gd).
## Covers the isometric projection, zoom clamping, screen-relative panning after each rotation,
## the screen-to-ground round trip, edge scrolling, middle-drag and focus tweens.

const PITCH_RAD: float = -0.6154797087  # deg_to_rad(-35.264)


func _make_cam() -> RtsCamera:
	var cam: RtsCamera = RtsCamera.new()
	cam.edge_scroll_enabled = false  # headless mouse sits at (0, 0), which would count as an edge
	add_child(cam)
	auto_free(cam)
	return cam


func _flat(v: Vector3) -> Vector3:
	var f: Vector3 = Vector3(v.x, 0.0, v.z)
	return f.normalized()


func test_camera_is_orthographic_at_isometric_pitch() -> void:
	var cam: RtsCamera = _make_cam()
	var c: Camera3D = cam.get_camera()
	assert_object(c).is_not_null()
	assert_int(c.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_float(c.rotation.x).is_equal_approx(PITCH_RAD, 0.001)
	assert_float(c.size).is_equal_approx(60.0, 0.001)


func test_zoom_clamps_between_20_and_120() -> void:
	var cam: RtsCamera = _make_cam()
	cam.set_ortho_size(1000.0)
	assert_float(cam.ortho_size()).is_equal_approx(120.0, 0.001)
	assert_float(cam.get_camera().size).is_equal_approx(120.0, 0.001)
	cam.set_ortho_size(0.0)
	assert_float(cam.ortho_size()).is_equal_approx(20.0, 0.001)
	for i: int in range(300):
		cam.zoom_step(-1)
	assert_float(cam.ortho_size()).is_equal_approx(20.0, 0.001)
	for i: int in range(300):
		cam.zoom_step(1)
	assert_float(cam.ortho_size()).is_equal_approx(120.0, 0.001)


func test_pan_is_screen_relative_after_each_snapped_rotation() -> void:
	var cam: RtsCamera = _make_cam()
	for steps: int in range(4):
		cam.snap_rotation(steps)
		var c: Camera3D = cam.get_camera()
		var cam_right: Vector3 = _flat(c.global_transform.basis.x)
		var cam_forward: Vector3 = _flat(-c.global_transform.basis.z)
		var right_dir: Vector3 = cam.pan_direction(Vector2(1.0, 0.0))
		var up_dir: Vector3 = cam.pan_direction(Vector2(0.0, -1.0))
		assert_float(right_dir.x).is_equal_approx(cam_right.x, 0.001)
		assert_float(right_dir.z).is_equal_approx(cam_right.z, 0.001)
		assert_float(up_dir.x).is_equal_approx(cam_forward.x, 0.001)
		assert_float(up_dir.z).is_equal_approx(cam_forward.z, 0.001)
		assert_int(cam.rotation_steps()).is_equal(steps)


func test_rotation_tween_reaches_target_yaw() -> void:
	var cam: RtsCamera = _make_cam()
	cam.snap_rotation(0)
	cam.rotate_steps(1)
	assert_bool(cam.is_rotating()).is_true()
	var frames: int = 0
	while cam.is_rotating() and frames < 300:
		await await_idle_frame()
		frames += 1
	assert_bool(cam.is_rotating()).is_false()
	assert_int(cam.rotation_steps()).is_equal(1)
	var c: Camera3D = cam.get_camera()
	var cam_right: Vector3 = _flat(c.global_transform.basis.x)
	var right_dir: Vector3 = cam.pan_direction(Vector2(1.0, 0.0))
	assert_float(right_dir.x).is_equal_approx(cam_right.x, 0.01)
	assert_float(right_dir.z).is_equal_approx(cam_right.z, 0.01)


func test_pan_speed_scales_with_zoom() -> void:
	var cam: RtsCamera = _make_cam()
	cam.snap_rotation(0)
	cam.set_ortho_size(60.0)
	cam.position = Vector3.ZERO
	cam.pan_screen(Vector2(1.0, 0.0), 1.0)
	var moved: float = Vector3(cam.position.x, 0.0, cam.position.z).length()
	assert_float(moved).is_equal_approx(60.0 * 0.6, 0.01)


func test_screen_to_ground_round_trips_projected_point() -> void:
	var cam: RtsCamera = _make_cam()
	for steps: int in range(4):
		cam.snap_rotation(steps)
		cam.position = Vector3(10.0, 0.0, 5.0)
		var g: Vector3 = Vector3(12.5, 0.0, 3.0)
		var c: Camera3D = cam.get_camera()
		var p: Vector2 = c.unproject_position(g)
		var back: Vector3 = cam.screen_to_ground(p)
		assert_float(back.x).is_equal_approx(g.x, 0.01)
		assert_float(back.y).is_equal_approx(0.0, 0.01)
		assert_float(back.z).is_equal_approx(g.z, 0.01)


func test_edge_direction_detects_margins() -> void:
	var view: Vector2 = Vector2(800.0, 600.0)
	assert_bool(RtsCamera.edge_direction(Vector2(2.0, 300.0), view, 8.0) == Vector2(-1.0, 0.0)).is_true()
	assert_bool(RtsCamera.edge_direction(Vector2(798.0, 300.0), view, 8.0) == Vector2(1.0, 0.0)).is_true()
	assert_bool(RtsCamera.edge_direction(Vector2(400.0, 2.0), view, 8.0) == Vector2(0.0, -1.0)).is_true()
	assert_bool(RtsCamera.edge_direction(Vector2(400.0, 598.0), view, 8.0) == Vector2(0.0, 1.0)).is_true()
	assert_bool(RtsCamera.edge_direction(Vector2(400.0, 300.0), view, 8.0) == Vector2.ZERO).is_true()
	assert_bool(RtsCamera.edge_direction(Vector2(-5.0, 300.0), view, 8.0) == Vector2.ZERO).is_true()


func test_middle_drag_moves_map_with_the_cursor() -> void:
	var cam: RtsCamera = _make_cam()
	cam.snap_rotation(0)
	cam.position = Vector3.ZERO
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	cam._unhandled_input(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(20.0, 0.0)
	cam._unhandled_input(motion)
	# Dragging right moves the map right, so the pivot moves along the negative screen-right ground direction.
	var right: Vector3 = cam.ground_right()
	var along: float = cam.position.dot(right)
	var across: float = cam.position.dot(cam.ground_forward())
	assert_float(along).is_less(0.0)
	assert_float(absf(across)).is_less(0.001)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	cam._unhandled_input(release)
	var start_pos: Vector3 = cam.position
	var motion2: InputEventMouseMotion = InputEventMouseMotion.new()
	motion2.relative = Vector2(20.0, 20.0)
	cam._unhandled_input(motion2)
	assert_float(cam.position.x).is_equal_approx(start_pos.x, 0.0001)
	assert_float(cam.position.z).is_equal_approx(start_pos.z, 0.0001)


func test_focus_on_tweens_pivot_to_ground_point() -> void:
	var cam: RtsCamera = _make_cam()
	cam.focus_on(Vector3(20.0, 3.0, -4.0))
	assert_float(cam.focus_target().x).is_equal_approx(20.0, 0.001)
	assert_float(cam.focus_target().y).is_equal_approx(0.0, 0.001)
	assert_float(cam.focus_target().z).is_equal_approx(-4.0, 0.001)
	var frames: int = 0
	while frames < 300 and (absf(cam.position.x - 20.0) > 0.01 or absf(cam.position.z + 4.0) > 0.01):
		await await_idle_frame()
		frames += 1
	assert_float(cam.position.x).is_equal_approx(20.0, 0.01)
	assert_float(cam.position.z).is_equal_approx(-4.0, 0.01)
	assert_float(cam.position.y).is_equal_approx(0.0, 0.001)
