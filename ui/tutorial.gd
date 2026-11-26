class_name Tutorial
extends Control
## S42: guided prologue and Day 1. Nila and Nala give short step prompts; each step waits until the
## player has really done it (accepted commands, or state read from the DayFlow). Every step names
## the action button and the site to point at, so MainGame can draw an arrow and a glow there.
## Skippable. Pure presentation: it never writes to the simulation.
##
## Steps are dictionaries: {id, speaker (nila|nala), text (tr key), banner (tr key or ""), action (the
## action id whose mode the banner belongs to), button (action button to pulse), site (site to point
## at), done: {kind: cmd|stone|speed, key: String}}.

signal step_changed(step_id: String)
signal finished(completed: bool)

const SEQ_PROLOGUE: String = "prologue"
const SEQ_DAY: String = "day1"

const PROLOGUE_STEPS: Array = [
	{"id": "p_scribes", "speaker": "nila", "text": "TUT_P_SCRIBES", "banner": "TUTB_CREWS_LEKHAN", "action": "crews",
		"button": "crews", "site": "lekhan", "done": {"kind": "cmd", "key": "assign:scribe:lekhan"}},
]
const DAY_STEPS: Array = [
	{"id": "d_scribes", "speaker": "nila", "text": "TUT_D_SCRIBES", "banner": "TUTB_CREWS_LEKHAN", "action": "crews",
		"button": "crews", "site": "lekhan", "done": {"kind": "cmd", "key": "assign:scribe:lekhan"}},
	{"id": "d_route_a", "speaker": "nila", "text": "TUT_D_ROUTE_A", "banner": "TUTB_ROUTE_A", "action": "route",
		"button": "route", "site": "quarry", "done": {"kind": "cmd", "key": "route:quarry>lekhan"}},
	{"id": "d_route_b", "speaker": "nala", "text": "TUT_D_ROUTE_B", "banner": "TUTB_ROUTE_B", "action": "route",
		"button": "route", "site": "lekhan", "done": {"kind": "cmd", "key": "route:lekhan>head"}},
	{"id": "d_cutters", "speaker": "nila", "text": "TUT_D_CUTTERS", "banner": "TUTB_CREWS_QUARRY", "action": "crews",
		"button": "crews", "site": "quarry", "done": {"kind": "cmd", "key": "assign:cutter:quarry"}},
	{"id": "d_stone", "speaker": "nala", "text": "TUT_D_STONE", "banner": "", "action": "",
		"button": "", "site": "head", "done": {"kind": "stone", "key": ""}},
	{"id": "d_measure", "speaker": "nala", "text": "TUT_D_MEASURE", "banner": "", "action": "measuring_line",
		"button": "measuring_line", "site": "", "done": {"kind": "cmd", "key": "measure"}},
	{"id": "d_speed", "speaker": "nila", "text": "TUT_D_SPEED", "banner": "", "action": "",
		"button": "", "site": "", "done": {"kind": "speed", "key": ""}},
]

var _steps: Array = []
var _sequence: String = ""
var _index: int = 0
var _active: bool = false
var _done_keys: Dictionary = {}

var _panel: PanelContainer = null
var _speaker: Label = null
var _counter: Label = null
var _text: Label = null
var _skip: Button = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -170.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	style.border_color = Color(0.91, 0.73, 0.29, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	_speaker = Label.new()
	_speaker.add_theme_color_override(&"font_color", Color(0.91, 0.73, 0.29))
	_speaker.add_theme_font_size_override(&"font_size", 20)
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_speaker)
	_counter = Label.new()
	_counter.modulate = Color(1.0, 1.0, 1.0, 0.7)
	head.add_child(_counter)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(580.0, 0.0)
	_text.add_theme_font_size_override(&"font_size", 18)
	box.add_child(_text)
	_skip = Button.new()
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip.pressed.connect(skip)
	box.add_child(_skip)
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()


## Starts a sequence (SEQ_PROLOGUE or SEQ_DAY). Earlier progress is forgotten.
func begin(sequence: String) -> void:
	_sequence = sequence
	_steps = PROLOGUE_STEPS if sequence == SEQ_PROLOGUE else DAY_STEPS
	_index = 0
	_done_keys.clear()
	_active = true
	visible = true
	_refresh()
	step_changed.emit(current_id())


## The sequence last started (SEQ_PROLOGUE or SEQ_DAY).
func sequence() -> String:
	return _sequence


func is_active() -> bool:
	return _active


func current_id() -> String:
	return str(current_step().get("id", "")) if _active else ""


func step_index() -> int:
	return _index


func step_count() -> int:
	return _steps.size()


## The current step dictionary (empty when inactive).
func current_step() -> Dictionary:
	if not _active or _index >= _steps.size():
		return {}
	return _steps[_index] as Dictionary


func skip_button() -> Button:
	return _skip


## Ends the tutorial early.
func skip() -> void:
	if _active:
		_end(false)


## Records an accepted player command; steps use these to know the player did the thing.
func note_command(cmd: Dictionary, accepted: bool) -> void:
	if not accepted:
		return
	var args: Dictionary = cmd.get("args", {}) as Dictionary
	match str(cmd.get("type", "")):
		"assign_crews":
			_done_keys["assign:%s:%s" % [str(args.get("role", "")), str(args.get("site", ""))]] = true
		"draw_route":
			_done_keys["route:%s>%s" % [str(args.get("from", "")), str(args.get("to", ""))]] = true
		"place_measuring_line":
			_done_keys["measure"] = true


## Moves to the next step(s) while the current one is done. Call every frame with the live flow.
func evaluate(flow: DayFlow, speed: int) -> void:
	var guard: int = 0
	while _active and guard < 16:
		guard += 1
		if not _step_done(current_step(), flow, speed):
			return
		_index += 1
		if _index >= _steps.size():
			_end(true)
			return
		_refresh()
		step_changed.emit(current_id())


func _step_done(step: Dictionary, flow: DayFlow, speed: int) -> bool:
	var done: Dictionary = step.get("done", {}) as Dictionary
	match str(done.get("kind", "")):
		"cmd":
			return _done_keys.has(str(done.get("key", "")))
		"stone":
			return flow != null and flow.bridge != null and flow.bridge.section_count() > 0 \
				and flow.bridge.section(0).stone_in > 0
		"speed":
			return speed >= 2
	return false


func _end(completed: bool) -> void:
	_active = false
	visible = false
	finished.emit(completed)


func _refresh() -> void:
	if not _active:
		return
	var step: Dictionary = current_step()
	if step.is_empty():
		return
	_speaker.text = tr("SPK_" + str(step["speaker"]).to_upper())
	_text.text = tr(str(step["text"]))
	_counter.text = tr("TUT_STEP") % [_index + 1, _steps.size()]
	_skip.text = tr("TUT_SKIP")
