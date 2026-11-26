class_name ShlokaCard
extends Control
## S23: shloka card (DESIGN §7, §9 S23). Shows one shloka from data/shlokas.json: the Devanagari large in gold, the IAST
## small and italic, the translation in the current language, and the reference.
## Modes: on (waits at least 4 s, then any key or click closes it), short (translation only, closes itself after 3 s,
## a key also closes it), off (closes at once and shows nothing).
## closed(shloka_id) is emitted once each time the card closes. Fonts come from Locale.font_for when the Locale node exists.

signal closed(shloka_id: StringName)

const MODE_ON: StringName = &"on"
const MODE_SHORT: StringName = &"short"
const MODE_OFF: StringName = &"off"
const MIN_ON_SECONDS: float = 4.0
const SHORT_SECONDS: float = 3.0
const DEVANAGARI_SIZE: int = 44
const IAST_SIZE: int = 22
const TRANSLATION_SIZE: int = 26
const REFERENCE_SIZE: int = 16
const SHADE_COLOR: Color = Color(0.08, 0.06, 0.05, 0.88)
const ITALIC_SKEW: float = 0.25
const TRANSLATION_WIDTH: float = 640.0

## Mode of the card. Unknown values are refused with a warning and the previous mode is kept.
var mode: StringName = MODE_ON:
	set(value):
		if value == MODE_ON or value == MODE_SHORT or value == MODE_OFF:
			mode = value
			_refresh()
		else:
			push_warning("ShlokaCard: unknown mode '%s' ignored" % str(value))

var _id: StringName = &""
var _open: bool = false
var _elapsed: float = 0.0
var _entry: Dictionary = {}
var _devanagari: String = ""
var _iast: String = ""
var _translation: String = ""
var _reference: String = ""
var _devanagari_label: Label = null
var _iast_label: Label = null
var _translation_label: Label = null
var _reference_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cover the whole screen regardless of the (small) parent it lives in, so the card is centred with a full shade.
	top_level = true
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	var locale: Node = get_node_or_null(^"/root/Locale")
	if locale != null and locale.has_signal(&"language_changed"):
		locale.connect(&"language_changed", _on_language_changed)
	var shade: ColorRect = ColorRect.new()
	shade.color = SHADE_COLOR
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(Palette.UI_DARK, 0.82)
	style.border_color = Color(Palette.GOLD, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	_devanagari_label = _make_label(locale_font(self, &"shloka"), DEVANAGARI_SIZE, Palette.GOLD)
	_iast_label = _make_label(locale_font(self, &"ui"), IAST_SIZE, Palette.MOON)
	_translation_label = _make_label(locale_font(self, &"ui"), TRANSLATION_SIZE, Palette.MOON)
	_translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_translation_label.custom_minimum_size = Vector2(TRANSLATION_WIDTH, 0.0)
	_reference_label = _make_label(locale_font(self, &"ui"), REFERENCE_SIZE, Palette.STONE)
	column.add_child(_devanagari_label)
	column.add_child(_iast_label)
	column.add_child(_translation_label)
	column.add_child(_reference_label)
	_apply_fonts()
	visible = _open
	_refresh()


func _exit_tree() -> void:
	var locale: Node = get_node_or_null(^"/root/Locale")
	if locale != null and locale.is_connected(&"language_changed", _on_language_changed):
		locale.disconnect(&"language_changed", _on_language_changed)


func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	advance_time(delta)


func _unhandled_input(event: InputEvent) -> void:
	if handle_input_event(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


## Opens the card for a shloka id. In mode off the card closes at once.
func show_shloka(id: StringName) -> void:
	_id = id
	_open = true
	_elapsed = 0.0
	_entry = Shlokas.get_shloka(str(id))
	_devanagari = str(_entry.get("devanagari", ""))
	_iast = str(_entry.get("iast", ""))
	_reference = str(_entry.get("ref", ""))
	_translation = _translation_of(_entry)
	_refresh()
	visible = true
	if mode == MODE_OFF:
		_close()


## Re-reads the translation and fonts for the current language. Called when the Locale language changes, so an open
## card follows a language switch.
func refresh_language() -> void:
	_apply_fonts()
	if _id.is_empty():
		return
	_translation = _translation_of(_entry)
	_refresh()


func _on_language_changed(_code: StringName) -> void:
	refresh_language()


func _apply_fonts() -> void:
	if _devanagari_label == null:
		return
	var ui_font: Font = locale_font(self, &"ui")
	var iast_font: FontVariation = FontVariation.new()
	iast_font.base_font = ui_font
	iast_font.variation_transform = Transform2D(Vector2.RIGHT, Vector2(ITALIC_SKEW, 1.0), Vector2.ZERO)
	_devanagari_label.add_theme_font_override("font", locale_font(self, &"shloka"))
	_iast_label.add_theme_font_override("font", iast_font)
	_translation_label.add_theme_font_override("font", ui_font)
	_reference_label.add_theme_font_override("font", ui_font)


## Moves the card's clock on. Mode on has no timeout; mode short closes after SHORT_SECONDS.
func advance_time(delta: float) -> void:
	if not _open:
		return
	_elapsed += delta
	if mode == MODE_SHORT and _elapsed >= SHORT_SECONDS:
		_close()


## Handles one input event. Returns true when it closed the card. In mode on, events within MIN_ON_SECONDS are ignored.
func handle_input_event(event: InputEvent) -> bool:
	if not _open or not _is_dismiss_event(event):
		return false
	if mode == MODE_ON and _elapsed < MIN_ON_SECONDS:
		return false
	_close()
	return true


func is_open() -> bool:
	return _open


func shloka_id() -> StringName:
	return _id


func devanagari_text() -> String:
	return _devanagari


func iast_text() -> String:
	return _iast


func translation_text() -> String:
	return _translation


func reference_text() -> String:
	return _reference


## True when the Devanagari line is on show (open, mode on, and the shloka has text).
func devanagari_shown() -> bool:
	return _open and mode == MODE_ON and not _devanagari.is_empty()


## True when the translation is on show (open and the shloka has a translation).
func translation_shown() -> bool:
	return _open and not _translation.is_empty()


func devanagari_color() -> Color:
	return _devanagari_label.get_theme_color("font_color")


## Font for a role from the Locale node (font_for), or the engine fallback font when no Locale node exists.
static func locale_font(host: Node, role: StringName) -> Font:
	if host.is_inside_tree():
		var locale: Node = host.get_node_or_null(^"/root/Locale")
		if locale != null and locale.has_method("font_for"):
			var font: Variant = locale.call("font_for", role)
			if font is Font:
				return font as Font
	return ThemeDB.fallback_font


func _make_label(font: Font, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The language the game is showing. Locale.set_language sets the TranslationServer locale, so that is the source of truth.
func _current_language() -> String:
	return "hi" if TranslationServer.get_locale().begins_with("hi") else "en"


func _translation_of(entry: Dictionary) -> String:
	var raw: Variant = entry.get("translation", null)
	if not (raw is Dictionary):
		return ""
	var table: Dictionary = raw as Dictionary
	var text: String = str(table.get(_current_language(), ""))
	if text.strip_edges().is_empty():
		text = str(table.get("en", ""))
	return text


func _is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventAction:
		return (event as InputEventAction).pressed
	return false


func _close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit(_id)


func _refresh() -> void:
	if _devanagari_label == null:
		return
	var full: bool = mode == MODE_ON
	_devanagari_label.text = _devanagari
	_devanagari_label.visible = full and not _devanagari.is_empty()
	_iast_label.text = _iast
	_iast_label.visible = full and not _iast.is_empty()
	_translation_label.text = _translation
	_translation_label.visible = true
	_reference_label.text = _reference
	_reference_label.visible = full and not _reference.is_empty()
