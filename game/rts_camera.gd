class_name RtsCamera
extends Node3D
## S24: isometric RTS camera. An orthographic Camera3D sits at the true isometric pitch (-35.264 degrees)
## under a yaw pivot (45 degrees plus 90 per step). The pivot's position is the focus point on the ground (y = 0).
##
## Controls (InputMap actions registered in _init when missing):
##   cam_pan_left/right/up/down   WASD, arrow keys, left stick. Pan is relative to the screen.
##   cam_zoom_in/out              PageUp/PageDown, right/left trigger. Ortho size stays in 20..120.
##   cam_rotate_left/right        Q/E, shoulder buttons. Rotates 90 degrees with an eased 0.3 s tween.
##   middle-drag                  Drags the map with the cursor.
##   edge_scroll_enabled          Pans when the cursor is within EDGE_MARGIN pixels of the view edge.
##   wheel                        Zooms.
## Use focus_on(world_pos) to tween the focus point, and screen_to_ground(screen_pos) to pick ground.
## Input is handled in _unhandled_input and _process, so UI that consumes an event takes precedence.

const PITCH_DEG: float = -35.264
const BASE_YAW_DEG: float = 45.0
const ORTHO_MIN: float = 20.0
const ORTHO_MAX: float = 120.0
const ORTHO_START: float = 60.0
const ROTATE_TIME: float = 0.3
const FOCUS_TIME: float = 0.5
const PAN_SPEED_FACTOR: float = 0.6
const EDGE_MARGIN: float = 8.0
const ZOOM_STEP: float = 0.9
const ZOOM_RATE: float = 1.2
const CAMERA_DISTANCE: float = 200.0
const FALLBACK_VIEW: Vector2 = Vector2(1152.0, 648.0)
## sin(35.264 degrees), which is 1 / sqrt(3): converts screen-vertical drag to ground distance.
const PITCH_SIN: float = 0.5773502691896258
## cos(35.264 degrees), which is sqrt(2 / 3).
const PITCH_COS: float = 0.816496580927726

var edge_scroll_enabled: bool = true

var _camera: Camera3D
var _ortho_size: float = ORTHO_START
var _steps: int = 0
var _rotate_tween: Tween = null
var _focus_tween: Tween = null
var _focus_target: Vector3 = Vector3.ZERO
var _dragging: bool = false


func _init() -> void:
	register_input_actions()
	rotation = Vector3(0.0, deg_to_rad(BASE_YAW_DEG), 0.0)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _ortho_size
	_camera.near = 0.05
	_camera.far = 1000.0
	_camera.rotation = Vector3(deg_to_rad(PITCH_DEG), 0.0, 0.0)
	_camera.position = Vector3(0.0, PITCH_SIN * CAMERA_DISTANCE, PITCH_COS * CAMERA_DISTANCE)
	add_child(_camera)


func _ready() -> void:
	_camera.current = true


func get_camera() -> Camera3D:
	return _camera


## Ortho size (the view height in metres), always within ORTHO_MIN..ORTHO_MAX.
func ortho_size() -> float:
	return _ortho_size


func set_ortho_size(size: float) -> void:
	_ortho_size = clampf(size, ORTHO_MIN, ORTHO_MAX)
	_camera.size = _ortho_size


## direction -1 zooms in (smaller size), +1 zooms out.
func zoom_step(direction: int) -> void:
	if direction < 0:
		set_ortho_size(_ortho_size * ZOOM_STEP)
	elif direction > 0:
		set_ortho_size(_ortho_size / ZOOM_STEP)


## Rotation in 90-degree steps, modulo 4 (0..3).
func rotation_steps() -> int:
	return posmod(_steps, 4)


func is_rotating() -> bool:
	return _rotate_tween != null and _rotate_tween.is_valid() and _rotate_tween.is_running()


## Rotates by delta_steps quarter turns with an eased tween.
func rotate_steps(delta_steps: int) -> void:
	_steps += delta_steps
	_kill_rotate()
	_rotate_tween = create_tween()
	var tweener: PropertyTweener = _rotate_tween.tween_property(self, "rotation:y", _target_yaw_rad(), ROTATE_TIME)
	tweener.set_trans(Tween.TRANS_SINE)
	tweener.set_ease(Tween.EASE_IN_OUT)


## Sets the rotation immediately, with no tween (for tests and for the integrator).
func snap_rotation(steps: int) -> void:
	_steps = steps
	_kill_rotate()
	rotation = Vector3(0.0, _target_yaw_rad(), 0.0)


func focus_target() -> Vector3:
	return _focus_target


## Tweens the pivot to the ground point under world_pos (its y is ignored).
func focus_on(world_pos: Vector3) -> void:
	_focus_target = Vector3(world_pos.x, 0.0, world_pos.z)
	_kill_focus()
	_focus_tween = create_tween()
	var tweener: PropertyTweener = _focus_tween.tween_property(self, "position", _focus_target, FOCUS_TIME)
	tweener.set_trans(Tween.TRANS_SINE)
	tweener.set_ease(Tween.EASE_IN_OUT)


## Unit world-space direction on the ground that a screen-relative pan vector moves toward.
## v.x is right, v.y is down (so v = (0, -1) is screen-up, which is away from the viewer).
func pan_direction(v: Vector2) -> Vector3:
	var dir: Vector3 = ground_right() * v.x + ground_forward() * (-v.y)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir


## Moves the focus point by a screen-relative pan vector over dt seconds.
func pan_screen(v: Vector2, dt: float) -> void:
	if v == Vector2.ZERO:
		return
	_kill_focus()
	position += pan_direction(v) * (_ortho_size * PAN_SPEED_FACTOR * dt)


## Ground point (y = 0) hit by the ray through screen_pos. For a ray parallel to the ground,
## returns the ray origin projected onto the ground.
func screen_to_ground(screen_pos: Vector2) -> Vector3:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.000001:
		return Vector3(origin.x, 0.0, origin.z)
	var t: float = -origin.y / dir.y
	return Vector3(origin.x + dir.x * t, 0.0, origin.z + dir.z * t)


## Pan vector for a cursor at pos inside a view of size view. Zero away from the edges or outside the view.
static func edge_direction(pos: Vector2, view: Vector2, margin: float) -> Vector2:
	if pos.x < 0.0 or pos.y < 0.0 or pos.x > view.x or pos.y > view.y:
		return Vector2.ZERO
	var d: Vector2 = Vector2.ZERO
	if pos.x < margin:
		d.x = -1.0
	elif pos.x > view.x - margin:
		d.x = 1.0
	if pos.y < margin:
		d.y = -1.0
	elif pos.y > view.y - margin:
		d.y = 1.0
	return d


## Registers the camera's InputMap actions when they are missing.
static func register_input_actions() -> void:
	_ensure_action(&"cam_pan_left", _evs([_key_event(KEY_A), _key_event(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)]))
	_ensure_action(&"cam_pan_right", _evs([_key_event(KEY_D), _key_event(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)]))
	_ensure_action(&"cam_pan_up", _evs([_key_event(KEY_W), _key_event(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)]))
	_ensure_action(&"cam_pan_down", _evs([_key_event(KEY_S), _key_event(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)]))
	_ensure_action(&"cam_zoom_in", _evs([_key_event(KEY_PAGEUP), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]))
	_ensure_action(&"cam_zoom_out", _evs([_key_event(KEY_PAGEDOWN), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]))
	_ensure_action(&"cam_rotate_left", _evs([_key_event(KEY_Q), _joy_button(JOY_BUTTON_LEFT_SHOULDER)]))
	_ensure_action(&"cam_rotate_right", _evs([_key_event(KEY_E), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)]))


func _process(delta: float) -> void:
	var v: Vector2 = Input.get_vector(&"cam_pan_left", &"cam_pan_right", &"cam_pan_up", &"cam_pan_down")
	if edge_scroll_enabled and is_inside_tree():
		var view: Vector2 = _view_size()
		var mouse: Vector2 = get_viewport().get_mouse_position()
		v += RtsCamera.edge_direction(mouse, view, EDGE_MARGIN)
	if v.length() > 1.0:
		v = v.normalized()
	pan_screen(v, delta)
	var zoom_in: float = Input.get_action_strength(&"cam_zoom_in")
	var zoom_out: float = Input.get_action_strength(&"cam_zoom_out")
	var zoom: float = zoom_in - zoom_out
	if absf(zoom) > 0.0001:
		set_ortho_size(_ortho_size * (1.0 - zoom * ZOOM_RATE * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step(-1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step(1)
	elif event is InputEventMouseMotion and _dragging:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		var upp: float = _ortho_size / maxf(_view_size().y, 1.0)
		_kill_focus()
		position += (-ground_right() * rel.x + ground_forward() * (rel.y / PITCH_SIN)) * upp
	elif event.is_action_pressed(&"cam_rotate_left"):
		rotate_steps(-1)
	elif event.is_action_pressed(&"cam_rotate_right"):
		rotate_steps(1)


## Unit vector on the ground toward screen-right.
func ground_right() -> Vector3:
	return global_basis.x.normalized()


## Unit vector on the ground toward screen-up (away from the viewer).
func ground_forward() -> Vector3:
	return -global_basis.z.normalized()


func _target_yaw_rad() -> float:
	return deg_to_rad(BASE_YAW_DEG + 90.0 * float(_steps))


func _view_size() -> Vector2:
	if not is_inside_tree():
		return FALLBACK_VIEW
	return get_viewport().get_visible_rect().size


func _kill_rotate() -> void:
	if _rotate_tween != null and _rotate_tween.is_valid():
		_rotate_tween.kill()
	_rotate_tween = null


func _kill_focus() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null


static func _evs(list: Array) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for ev: Variant in list:
		out.append(ev as InputEvent)
	return out


static func _ensure_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


static func _key_event(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	return ev


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	return ev


static func _joy_axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	return ev
