class_name DaySummary
extends Control
## End-of-day summary (DESIGN §9, S17): shows the score fields from DayFlow.score(), the length carried
## over to the next day, and a continue button. Read-only over the simulation. All text goes through tr().

signal continue_pressed

var _day: int = 1
var _score: Dictionary = {}
var _carry_m: int = 0
var _has_score: bool = false

var _title_label: Label = null
var _length_label: Label = null
var _align_label: Label = null
var _waste_label: Label = null
var _morale_label: Label = null
var _total_label: Label = null
var _carry_label: Label = null
var _continue_button: Button = null


func _init() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	_title_label = _make_label(box)
	_length_label = _make_label(box)
	_align_label = _make_label(box)
	_waste_label = _make_label(box)
	_morale_label = _make_label(box)
	_total_label = _make_label(box)
	_carry_label = _make_label(box)
	_continue_button = Button.new()
	_continue_button.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_button)


## Shows the finished day's score and carry-over. Call once the day is over.
func show_summary(flow: DayFlow) -> void:
	_day = flow.day
	_score = flow.score()
	_carry_m = flow.carry_over()
	_has_score = true
	_render()


## Re-applies every string (used after a language change).
func refresh() -> void:
	_render()


func title_text() -> String:
	return _title_label.text


func length_text() -> String:
	return _length_label.text


func alignment_text() -> String:
	return _align_label.text


func waste_text() -> String:
	return _waste_label.text


func morale_text() -> String:
	return _morale_label.text


func total_text() -> String:
	return _total_label.text


func carry_text() -> String:
	return _carry_label.text


func continue_button() -> Button:
	return _continue_button


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_render()


func _render() -> void:
	_title_label.text = tr("UI_SUM_TITLE") % [_day]
	_continue_button.text = tr("UI_SUM_CONTINUE")
	_carry_label.text = tr("UI_SUM_CARRY") % [_carry_m]
	if not _has_score:
		_length_label.text = ""
		_align_label.text = ""
		_waste_label.text = ""
		_morale_label.text = ""
		_total_label.text = ""
		return
	_length_label.text = tr("UI_SUM_LENGTH") % [_score["length_pct"] as float]
	_align_label.text = tr("UI_SUM_ALIGN") % [_score["alignment_pct"] as float]
	_waste_label.text = tr("UI_SUM_WASTE") % [_score["waste_pct"] as float]
	_morale_label.text = tr("UI_SUM_MORALE") % [_score["morale_avg"] as float]
	_total_label.text = tr("UI_SUM_TOTAL") % [_score["total"] as float]


func _on_continue_pressed() -> void:
	_sfx(&"ui_confirm")
	continue_pressed.emit()


func _make_label(parent: Node) -> Label:
	var label: Label = Label.new()
	parent.add_child(label)
	return label


## Plays a Sound autoload event (silent when the autoload is absent).
func _sfx(id: StringName) -> void:
	var s: Node = get_node_or_null("/root/Sound") if is_inside_tree() else null
	if s != null:
		s.call("play", id)
