class_name BuildMenu
extends Control
## S16: radial build menu (DESIGN §5, §9 S16). Seven options sit on a circle around the centre of this
## control. Mouse: hover selects, click chooses. Gamepad: a left-stick or d-pad direction selects the
## option in that direction, the accept button chooses it, the cancel button closes the menu.
## Labels are translation keys UI_BUILD_<ID>.

signal option_chosen(id: StringName)

const DEFAULT_RADIUS: float = 150.0
const BUTTON_SIZE: Vector2 = Vector2(140.0, 40.0)
const STICK_DEADZONE: float = 0.6
const SELECTED_TINT: Color = Color(1.0, 0.9, 0.5, 1.0)

var _radius: float = DEFAULT_RADIUS
var _buttons: Array[Button] = []
var _selected: int = 0
var _stick: Vector2 = Vector2.ZERO
var _stick_engaged: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	for i: int in option_ids().size():
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = BUTTON_SIZE
		button.size = BUTTON_SIZE
		button.pressed.connect(_on_button_pressed.bind(i))
		button.mouse_entered.connect(_on_button_hovered.bind(i))
		add_child(button)
		_buttons.append(button)
	resized.connect(_place_buttons)
	_place_buttons()
	refresh_labels()
	_apply_selection()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadMotion:
		_handle_stick(event as InputEventJoypadMotion)
		return
	if event.is_action_pressed(&"ui_left"):
		select_direction(Vector2.LEFT)
	elif event.is_action_pressed(&"ui_right"):
		select_direction(Vector2.RIGHT)
	elif event.is_action_pressed(&"ui_up"):
		select_direction(Vector2.UP)
	elif event.is_action_pressed(&"ui_down"):
		select_direction(Vector2.DOWN)
	elif event.is_action_pressed(&"ui_accept"):
		confirm_selection()
	elif event.is_action_pressed(&"ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## Ordered option ids; option 0 sits at the top of the circle and the rest follow clockwise.
func option_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.append(&"route")
	ids.append(&"crews")
	ids.append(&"lekhan")
	ids.append(&"gong")
	ids.append(&"shelter")
	ids.append(&"measuring_line")
	ids.append(&"chant")
	return ids


func option_direction(index: int) -> Vector2:
	var count: int = option_ids().size()
	var angle: float = -PI * 0.5 + TAU * float(index) / float(count)
	return Vector2(cos(angle), sin(angle))


## Centre of option `index` in this control's local coordinates.
func option_anchor(index: int) -> Vector2:
	return size * 0.5 + option_direction(index) * _radius


func selected_index() -> int:
	return _selected


func selected_id() -> StringName:
	return option_ids()[_selected]


func label_text(index: int) -> String:
	if index < 0 or index >= _buttons.size():
		return ""
	return _buttons[index].text


## Selects the option whose direction is closest to `direction` (screen space, y down) and returns its index.
func select_direction(direction: Vector2) -> int:
	if direction.length_squared() < 0.0001:
		return _selected
	var dir: Vector2 = direction.normalized()
	var best: int = _selected
	var best_dot: float = -INF
	for i: int in option_ids().size():
		var score: float = option_direction(i).dot(dir)
		if score > best_dot:
			best_dot = score
			best = i
	_select(best)
	return best


## Emits option_chosen for the selected option, then closes the menu.
func confirm_selection() -> void:
	option_chosen.emit(selected_id())
	close()


func open_at(screen_position: Vector2) -> void:
	position = screen_position - size * 0.5
	_select(0)
	visible = true


func close() -> void:
	visible = false


func refresh_labels() -> void:
	var ids: Array[StringName] = option_ids()
	for i: int in _buttons.size():
		_buttons[i].text = tr("UI_BUILD_" + String(ids[i]).to_upper())


func _place_buttons() -> void:
	for i: int in _buttons.size():
		_buttons[i].position = option_anchor(i) - BUTTON_SIZE * 0.5


func _select(index: int) -> void:
	_selected = clampi(index, 0, option_ids().size() - 1)
	_apply_selection()


func _apply_selection() -> void:
	for i: int in _buttons.size():
		_buttons[i].modulate = SELECTED_TINT if i == _selected else Color.WHITE


func _handle_stick(motion: InputEventJoypadMotion) -> void:
	if motion.axis == JOY_AXIS_LEFT_X:
		_stick.x = motion.axis_value
	elif motion.axis == JOY_AXIS_LEFT_Y:
		_stick.y = motion.axis_value
	else:
		return
	if _stick.length() >= STICK_DEADZONE:
		if not _stick_engaged:
			_stick_engaged = true
			select_direction(_stick)
	else:
		_stick_engaged = false


func _on_button_hovered(index: int) -> void:
	_select(index)


func _on_button_pressed(index: int) -> void:
	_select(index)
	confirm_selection()
