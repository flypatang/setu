class_name DialogueBox
extends Control
## S23: dialogue box (DESIGN §5, §7, §9 S23). Plays a dialogue file through DialogueRunner (narrative/dialogue_runner.gd).
## The text types out one grapheme cluster at a time, so a Devanagari conjunct is never shown half-drawn.
## Accept (ui_accept, the "interact" action when the project defines it, or a left click) reveals the rest of the
## text; a second press advances. Choices appear as buttons once the text has typed out, and they are keyboard and
## gamepad navigable. A shloka step opens a ShlokaCard and the dialogue resumes when the card closes.
## play("file") starts a file; play("file#node") starts at a node. finished(file_id) is emitted when the dialogue ends.
## While is_playing() is true the caller should leave world input alone, because the panel passes clicks through.
## The box fills its parent (full rect anchors), so it can be added under any sized Control or CanvasLayer child.

signal finished(file_id: StringName)
signal choice_selected(index: int)
signal line_shown(speaker: StringName, text: String)
signal shloka_started(shloka_id: StringName)

const ENTRY_CACHE_DIR: String = "user://dialogue_entries/"
const SPEAKER_KEY_PREFIX: String = "SPK_"
const DEFAULT_CHARS_PER_SECOND: float = 30.0
const PANEL_HEIGHT: float = 200.0
const PANEL_COLOR: Color = Color(0.08, 0.06, 0.05, 0.9)
const PANEL_MARGIN: float = 24.0
const ZWJ: int = 0x200D
const ZWNJ: int = 0x200C
const VIRAMA: int = 0x094D

## Folder the dialogue files are read from. Tests point it at user:// fixtures.
@export var dialogue_dir: String = DialogueRunner.DEFAULT_DIALOGUE_DIR
## Mode given to the ShlokaCard for shloka steps: on, short or off.
@export var shloka_mode: StringName = ShlokaCard.MODE_ON
## Typing speed in grapheme clusters per second.
@export var chars_per_second: float = DEFAULT_CHARS_PER_SECOND

var _runner: DialogueRunner = null
var _card: ShlokaCard = null
var _panel: PanelContainer = null
var _speaker_label: Label = null
var _text_label: Label = null
var _choice_box: VBoxContainer = null
var _buttons: Array[Button] = []
var _clusters: Array[String] = []
var _revealed: int = 0
var _accum: float = 0.0
var _playing: bool = false
var _card_open: bool = false
var _file_id: StringName = &""
var _choices_dirty: bool = false
var _line_seen: bool = false
var _entry_path: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


func _exit_tree() -> void:
	_remove_entry()


func _process(delta: float) -> void:
	if _playing and not _card_open:
		step_typewriter(delta)


func _unhandled_input(event: InputEvent) -> void:
	if handle_input_event(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


## Starts a dialogue. "file#node" or node_id starts at that node. Returns OK, or the error that stopped the start.
func play(file_id: StringName, node_id: StringName = &"") -> Error:
	if _runner == null:
		push_error("DialogueBox: play() called before the box is in the tree")
		return ERR_UNCONFIGURED
	var file: String = str(file_id)
	var node: String = str(node_id)
	var hash_at: int = file.find("#")
	if hash_at >= 0:
		if node.is_empty():
			node = file.substr(hash_at + 1)
		file = file.substr(0, hash_at)
	if file.is_empty():
		return ERR_INVALID_PARAMETER
	_reset()
	_file_id = StringName(file)
	_runner.dialogue_dir = dialogue_dir
	var start_id: StringName = StringName(file)
	if not node.is_empty():
		start_id = _write_entry(file, node)
		if start_id.is_empty():
			return ERR_FILE_NOT_FOUND
		_runner.dialogue_dir = ENTRY_CACHE_DIR
	_playing = true
	visible = true
	var err: Error = _runner.start(start_id)
	# start() has read the whole file into memory, so the "file#node" copy is no longer needed.
	_remove_entry()
	if err != OK:
		push_warning("DialogueBox: could not start '%s' (error %d)" % [str(start_id), err])
		_playing = false
		visible = false
		return err
	_sync()
	return OK


## Handles one input event. Returns true when the event was used. Choices and the card take their own input.
func handle_input_event(event: InputEvent) -> bool:
	if not _playing or _card_open or not _is_advance_event(event):
		return false
	if is_typing():
		reveal_all()
		return true
	if _runner.waiting_for_choice() or not _runner.is_running():
		return false
	_advance_runner()
	return true


func is_playing() -> bool:
	return _playing


func is_typing() -> bool:
	return _revealed < _clusters.size()


func is_card_open() -> bool:
	return _card_open


func revealed_text() -> String:
	return _text_label.text if _text_label != null else ""


## Moves the typewriter on by delta seconds at chars_per_second.
func step_typewriter(delta: float) -> void:
	if not is_typing():
		return
	_accum += delta * chars_per_second
	var steps: int = int(_accum)
	if steps <= 0:
		return
	_accum -= float(steps)
	_revealed = mini(_revealed + steps, _clusters.size())
	_update_text()
	if not is_typing():
		_sync()


## Shows the whole current line at once.
func reveal_all() -> void:
	_revealed = _clusters.size()
	_accum = 0.0
	_update_text()
	_sync()


## The choice buttons of the current choice node (empty when no choice is waiting).
func choice_buttons() -> Array[Button]:
	return _buttons.duplicate()


func get_runner() -> DialogueRunner:
	return _runner


func get_card() -> ShlokaCard:
	return _card


## Splits text into grapheme clusters for typing. A combining mark, a ZWJ or ZWNJ joins the cluster before it, and a
## Devanagari consonant after a virama joins too, so conjuncts such as "क्ष" and "श्री" stay whole.
static func split_graphemes(text: String) -> Array[String]:
	var out: Array[String] = []
	var current: String = ""
	var prev: int = -1
	for i: int in text.length():
		var cp: int = text.unicode_at(i)
		var ch: String = text.substr(i, 1)
		if i > 0 and _joins_previous(prev, cp):
			current += ch
		else:
			if not current.is_empty():
				out.append(current)
			current = ch
		prev = cp
	if not current.is_empty():
		out.append(current)
	return out


static func _joins_previous(prev: int, cp: int) -> bool:
	if _is_combining(cp) or cp == ZWJ or cp == ZWNJ:
		return true
	if prev == ZWJ:
		return true
	return prev == VIRAMA and _is_devanagari_consonant(cp)


static func _is_combining(cp: int) -> bool:
	return (cp >= 0x0300 and cp <= 0x036F) \
		or (cp >= 0x0900 and cp <= 0x0903) \
		or (cp >= 0x093A and cp <= 0x094F) \
		or (cp >= 0x0951 and cp <= 0x0957) \
		or (cp >= 0x0962 and cp <= 0x0963) \
		or (cp >= 0x1AB0 and cp <= 0x1AFF) \
		or (cp >= 0x1DC0 and cp <= 0x1DFF) \
		or (cp >= 0x20D0 and cp <= 0x20FF) \
		or (cp >= 0xFE00 and cp <= 0xFE0F) \
		or (cp >= 0x1F3FB and cp <= 0x1F3FF)


static func _is_devanagari_consonant(cp: int) -> bool:
	return (cp >= 0x0915 and cp <= 0x0939) or (cp >= 0x0958 and cp <= 0x095F)


func _build() -> void:
	_runner = DialogueRunner.new()
	add_child(_runner)
	_runner.line_shown.connect(_on_line_shown)
	_runner.shloka_shown.connect(_on_shloka_shown)
	_runner.finished.connect(_on_runner_finished)

	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(8)
	style.set_content_margin_all(PANEL_MARGIN)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.custom_minimum_size = Vector2(0.0, PANEL_HEIGHT)
	add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_override("font", ShlokaCard.locale_font(self, &"ui"))
	_speaker_label.add_theme_color_override("font_color", Palette.GOLD)
	column.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_override("font", ShlokaCard.locale_font(self, &"ui"))
	_text_label.add_theme_color_override("font_color", Palette.MOON)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	column.add_child(_choice_box)

	_card = ShlokaCard.new()
	_card.closed.connect(_on_card_closed)
	add_child(_card)


func _reset() -> void:
	_remove_entry()
	_clear_choices()
	_clusters = []
	_revealed = 0
	_accum = 0.0
	_card_open = false
	_choices_dirty = true
	_line_seen = false
	if _card != null:
		_card.visible = false
	if _panel != null:
		_panel.visible = true


func _is_advance_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_accept"):
		return true
	if InputMap.has_action(&"interact") and event.is_action_pressed(&"interact"):
		return true
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return false


## Writes a copy of a dialogue file whose start is the given node, so the runner can begin there.
func _write_entry(file: String, node: String) -> StringName:
	var source: String = dialogue_dir + file + ".json"
	if not FileAccess.file_exists(source):
		return &""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not (parsed is Dictionary):
		return &""
	var data: Dictionary = (parsed as Dictionary).duplicate(true)
	var raw_nodes: Variant = data.get("nodes", null)
	if not (raw_nodes is Dictionary) or not (raw_nodes as Dictionary).has(node):
		return &""
	data["start"] = node
	DirAccess.make_dir_recursive_absolute(ENTRY_CACHE_DIR)
	# The process id keeps two running games from writing the same entry file.
	var entry_id: String = "%s@%s@%d" % [file, node, OS.get_process_id()]
	var path: String = ENTRY_CACHE_DIR + entry_id + ".json"
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return &""
	out.store_string(JSON.stringify(data))
	out.close()
	_entry_path = path
	return StringName(entry_id)


## Deletes the copy written for a "file#node" start, if there is one.
func _remove_entry() -> void:
	if _entry_path.is_empty():
		return
	if FileAccess.file_exists(_entry_path):
		DirAccess.remove_absolute(_entry_path)
	_entry_path = ""


func _advance_runner() -> void:
	_choices_dirty = true
	_line_seen = false
	_runner.advance()
	_sync()


func _on_line_shown(speaker: StringName, text: String) -> void:
	_line_seen = true
	var speaker_text: String = str(speaker)
	_speaker_label.text = "" if speaker_text.is_empty() else tr(SPEAKER_KEY_PREFIX + speaker_text.to_upper())
	_clusters = split_graphemes(text)
	_revealed = 0
	_accum = 0.0
	_choices_dirty = true
	_clear_choices()
	_update_text()
	line_shown.emit(speaker, text)


func _on_shloka_shown(shloka_id: StringName) -> void:
	_card_open = true
	_panel.visible = false
	_clear_choices()
	shloka_started.emit(shloka_id)
	_card.mode = shloka_mode
	_card.show_shloka(shloka_id)


func _on_card_closed(_shloka_id: StringName) -> void:
	_card_open = false
	if not _playing:
		return
	_panel.visible = true
	_advance_runner()


func _on_runner_finished(_runner_id: StringName) -> void:
	_remove_entry()
	_playing = false
	_card_open = false
	_clear_choices()
	visible = false
	finished.emit(_file_id)


func _on_choice_pressed(index: int) -> void:
	if not _playing or not _runner.waiting_for_choice():
		return
	_clear_choices()
	_choices_dirty = true
	_line_seen = false
	choice_selected.emit(index)
	_runner.choose(index)
	_sync()


## Brings the choice buttons in line with the runner: built for a new choice node, shown once the text is out.
func _sync() -> void:
	if not _playing or _card_open or not _runner.waiting_for_choice():
		_set_buttons_visible(false)
		if not _runner.waiting_for_choice():
			_clear_choices()
		return
	if _choices_dirty:
		# A choice node with no text_key shows no line, so the previous line must not stay on screen above it.
		if not _line_seen:
			_clear_text()
		_build_choices()
	_set_buttons_visible(not is_typing())


func _clear_text() -> void:
	_clusters = []
	_revealed = 0
	_accum = 0.0
	_speaker_label.text = ""
	_update_text()


func _build_choices() -> void:
	_clear_choices()
	var texts: Array[String] = _runner.get_choice_texts()
	for i: int in texts.size():
		var button: Button = Button.new()
		button.text = texts[i]
		button.focus_mode = Control.FOCUS_ALL
		button.visible = false
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choice_box.add_child(button)
		_buttons.append(button)
	_choices_dirty = false


func _set_buttons_visible(shown: bool) -> void:
	for button: Button in _buttons:
		button.visible = shown
	if shown and not _buttons.is_empty() and _buttons[0].is_inside_tree():
		_buttons[0].grab_focus()


func _clear_choices() -> void:
	for button: Button in _buttons:
		if button.get_parent() == _choice_box:
			_choice_box.remove_child(button)
		button.queue_free()
	_buttons.clear()


func _update_text() -> void:
	if _text_label == null:
		return
	var shown: String = ""
	for i: int in _revealed:
		shown += _clusters[i]
	_text_label.text = shown
