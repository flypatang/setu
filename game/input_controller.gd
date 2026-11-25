class_name InputController
extends Node
## S20: turns mouse and keyboard input into S12 command dictionaries (DESIGN §5, §9 S20).
## No simulation logic: every accepted action is sent to DayFlow.apply_command at the current tick.
##
## Input (registered in _ready when missing; uses _unhandled_input, so UI overlays that consume
## an event take precedence):
##   select     left click: adds a route point, places a station, or starts a measuring drag.
##   menu       right click: finishes the route being drawn (otherwise left alone for the radial menu).
##   cancel     Escape: drops the route, station or measuring line in progress.
##   pause, speed_up, speed_down: emit time_requested (speed is not a command; the HUD applies it).
##   gong       G: rings the gong chosen with select_gong().
##   chant      J: chant_jaya.
## Ground points come from a camera raycast onto the ground plane y = 0 (x and z are metres).
## Tests may replace the raycast with set_ground_picker().
##
## Commands sent (see PlayerCommands): draw_route, build_station, place_measuring_line, ring_gong,
## assign_crews (request_assign_crews, for the build menu), chant_jaya.

signal command_issued(cmd: Dictionary, accepted: bool)
signal time_requested(action: StringName)
signal mode_changed(mode: String)

const MODE_IDLE: String = "idle"
const MODE_ROUTE: String = "route"
const MODE_STATION: String = "station"
const MODE_MEASURE: String = "measure"
const MIN_DRAG_M: float = 1.0
const PLANE_EPSILON: float = 0.000001

## Command history of every command sent to DayFlow (valid ones), for replay.
var log: PlayerCommands.CommandLog = PlayerCommands.CommandLog.new()
## The last command dictionary built, and whether DayFlow accepted it.
var last_command: Dictionary = {}
var last_accepted: bool = false

var _flow: DayFlow = null
var _camera: Camera3D = null
var _picker: Callable = Callable()
var _mode: String = MODE_IDLE
var _route_id: String = ""
var _route_from: String = ""
var _route_to: String = ""
var _route_kind: String = ""
var _route_haulers: int = 0
var _route_points: Array[Vector2] = []
var _station_kind: String = ""
var _measure_start: Vector2 = Vector2.ZERO
var _measure_dragging: bool = false
var _gong_id: String = ""


func _ready() -> void:
	ensure_input_actions()


## Binds the controller to the running day and the camera used for ground picks.
func attach(flow: DayFlow, camera: Camera3D) -> void:
	_flow = flow
	_camera = camera


## Replaces the camera raycast: the picker maps a screen point to a ground point (x, z).
func set_ground_picker(picker: Callable) -> void:
	_picker = picker


func mode() -> String:
	return _mode


## Registers the InputMap actions this controller uses, but only where they are missing.
func ensure_input_actions() -> void:
	_ensure_action(&"select", _mouse_event(MOUSE_BUTTON_LEFT))
	_ensure_action(&"menu", _mouse_event(MOUSE_BUTTON_RIGHT))
	_ensure_action(&"cancel", _key_event(KEY_ESCAPE))
	_ensure_action(&"pause", _key_event(KEY_SPACE))
	_ensure_action(&"speed_up", _key_event(KEY_EQUAL))
	_ensure_action(&"speed_down", _key_event(KEY_MINUS))
	_ensure_action(&"gong", _key_event(KEY_G))
	_ensure_action(&"chant", _key_event(KEY_J))


## Chooses the gong that the gong key rings (a zone id, as sent in ring_gong).
func select_gong(id: String) -> void:
	_gong_id = id


## Starts drawing a haul route; each select click adds a point, menu finishes it.
func begin_route(id: String, from_pile: String, to_pile: String, kind: String, haulers: int) -> void:
	_route_id = id
	_route_from = from_pile
	_route_to = to_pile
	_route_kind = kind
	_route_haulers = haulers
	_route_points.clear()
	_set_mode(MODE_ROUTE)


## Starts placing stations of one kind; each select click places one.
func begin_station(kind: String) -> void:
	_station_kind = kind
	_set_mode(MODE_STATION)


## Starts a measuring line: press to set the start, release to set the angle.
func begin_measure() -> void:
	_measure_dragging = false
	_set_mode(MODE_MEASURE)


## Drops whatever is in progress without sending a command.
func cancel() -> void:
	_route_points.clear()
	_measure_dragging = false
	_set_mode(MODE_IDLE)


func request_assign_crews(role: String, site: String, crews: int) -> bool:
	return _send(PlayerCommands.TYPE_ASSIGN_CREWS, {"role": role, "site": site, "crews": crews})


func request_ring_gong(id: String) -> bool:
	return _send(PlayerCommands.TYPE_RING_GONG, {"id": id})


func request_chant() -> bool:
	return _send(PlayerCommands.TYPE_CHANT_JAYA, {})


func request_measure(deg: float) -> bool:
	return _send(PlayerCommands.TYPE_PLACE_MEASURING_LINE, {"deg": deg})


## Ground point (x, z) under a screen position. Returns (INF, INF) when the ray misses the ground.
func pick_ground(screen: Vector2) -> Vector2:
	if _picker.is_valid():
		return _picker.call(screen) as Vector2
	if _camera == null or not _camera.is_inside_tree():
		return Vector2(INF, INF)
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var dir: Vector3 = _camera.project_ray_normal(screen)
	if not ray_hits_ground(origin, dir):
		return Vector2(INF, INF)
	return ray_to_ground(origin, dir)


## True when a ray from origin along dir reaches the ground plane y = 0 in front of the origin.
static func ray_hits_ground(origin: Vector3, dir: Vector3) -> bool:
	if dir.y >= -PLANE_EPSILON:
		return false
	return -origin.y / dir.y >= 0.0


## Where a ray meets the ground plane y = 0, as (x, z). Returns (INF, INF) on a miss.
static func ray_to_ground(origin: Vector3, dir: Vector3) -> Vector2:
	if not ray_hits_ground(origin, dir):
		return Vector2(INF, INF)
	var t: float = -origin.y / dir.y
	var hit: Vector3 = origin + dir * t
	return Vector2(hit.x, hit.z)


func _unhandled_input(event: InputEvent) -> void:
	if _flow == null:
		return
	if event.is_action_pressed(&"cancel"):
		cancel()
		_consume()
		return
	if event.is_action_pressed(&"pause"):
		time_requested.emit(&"pause")
		_consume()
		return
	if event.is_action_pressed(&"speed_up"):
		time_requested.emit(&"speed_up")
		_consume()
		return
	if event.is_action_pressed(&"speed_down"):
		time_requested.emit(&"speed_down")
		_consume()
		return
	if event.is_action_pressed(&"gong"):
		if _gong_id != "":
			request_ring_gong(_gong_id)
		_consume()
		return
	if event.is_action_pressed(&"chant"):
		request_chant()
		_consume()
		return
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	match _mode:
		MODE_ROUTE:
			_route_input(event, mouse)
		MODE_STATION:
			if event.is_action_pressed(&"select"):
				_place_station(mouse.position)
				_consume()
		MODE_MEASURE:
			_measure_input(event, mouse)


func _route_input(event: InputEvent, mouse: InputEventMouse) -> void:
	if event.is_action_pressed(&"select"):
		var p: Vector2 = pick_ground(mouse.position)
		if _is_valid_ground(p):
			_route_points.append(p)
		_consume()
	elif event.is_action_pressed(&"menu"):
		_finish_route()
		_consume()


func _measure_input(event: InputEvent, mouse: InputEventMouse) -> void:
	if event.is_action_pressed(&"select"):
		_measure_start = pick_ground(mouse.position)
		_measure_dragging = _is_valid_ground(_measure_start)
		_consume()
	elif event.is_action_released(&"select") and _measure_dragging:
		_measure_dragging = false
		var end: Vector2 = pick_ground(mouse.position)
		_finish_measure(end)
		_consume()


func _finish_route() -> void:
	var pts: Array = []
	for p: Vector2 in _route_points:
		pts.append([p.x, p.y])
	_set_mode(MODE_IDLE)
	_route_points.clear()
	if pts.size() < 2:
		return
	_send(PlayerCommands.TYPE_DRAW_ROUTE, {
		"id": _route_id, "from": _route_from, "to": _route_to, "kind": _route_kind,
		"points": pts, "haulers": _route_haulers,
	})


func _place_station(screen: Vector2) -> void:
	var p: Vector2 = pick_ground(screen)
	if not _is_valid_ground(p):
		return
	_send(PlayerCommands.TYPE_BUILD_STATION, {"kind": _station_kind, "pos": [p.x, p.y]})


func _finish_measure(end: Vector2) -> void:
	_set_mode(MODE_IDLE)
	if not _is_valid_ground(end):
		return
	var d: Vector2 = end - _measure_start
	if d.length() < MIN_DRAG_M:
		return
	request_measure(rad_to_deg(atan2(d.y, d.x)))


## Builds the command at the current tick, validates it, applies it through DayFlow and reports it.
func _send(type: StringName, args: Dictionary) -> bool:
	var cmd: Dictionary = {"tick": _flow.tick(), "type": String(type), "args": args}
	last_command = cmd
	var problems: Array[String] = PlayerCommands.validate(PlayerCommands.Command.from_dict(cmd))
	var ok: bool = false
	if problems.is_empty():
		log.record(PlayerCommands.Command.from_dict(cmd))
		ok = _flow.apply_command(cmd)
	last_accepted = ok
	command_issued.emit(cmd, ok)
	return ok


func _set_mode(mode: String) -> void:
	if _mode != mode:
		_mode = mode
		mode_changed.emit(mode)


func _consume() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


static func _is_valid_ground(p: Vector2) -> bool:
	return not (is_nan(p.x) or is_nan(p.y) or is_inf(p.x) or is_inf(p.y))


static func _ensure_action(action: StringName, ev: InputEvent) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	InputMap.action_add_event(action, ev)


static func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	return ev


static func _key_event(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	return ev
