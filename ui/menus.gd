class_name Menus
extends Control
## In-game menus (DESIGN §9, S19; as Hanumaan M33): the title, pause and settings screens.
## Each setting is applied to the engine as soon as it changes and saved to user://settings.cfg:
##   [text] shloka_cards; [video] fps_cap, graphics, vsync, fullscreen; [audio] volume_master, volume_music, volume_sfx.
## The language is saved by Locale in [general] language. Other views read the saved choices through the static
## helpers graphics_preset(), shloka_cards_mode() and crowd_limit(). Crowd nodes must join the group "crowd" and
## lights the group "sun" for the graphics preset to reach them. Every label goes through tr() and is re-applied
## on Locale.language_changed.

enum Screen { TITLE, PAUSE, SETTINGS }

signal start_requested
signal resume_requested
signal quit_to_title_requested
signal quit_requested

const SETTINGS_PATH: String = "user://settings.cfg"
const LANGUAGE_OPTION: String = "language"
const LANGUAGES: PackedStringArray = ["en", "hi"]
const BACKDROP_COLOR: Color = Color(0.06, 0.05, 0.09, 0.82)
const MENU_WIDTH: float = 460.0
const LABEL_WIDTH: float = 230.0
const OPTION_SECTIONS: Dictionary = {
	"shloka_cards": "text",
	"fps_cap": "video",
	"graphics": "video",
	"vsync": "video",
	"fullscreen": "video",
	"volume_master": "audio",
	"volume_music": "audio",
	"volume_sfx": "audio",
}
const DEFAULTS: Dictionary = {
	"shloka_cards": "on",
	"fps_cap": 60,
	"graphics": "high",
	"vsync": true,
	"fullscreen": false,
	"volume_master": 1.0,
	"volume_music": 1.0,
	"volume_sfx": 1.0,
}
const SHLOKA_MODES: PackedStringArray = ["on", "short", "off"]
const FPS_CAPS: PackedInt32Array = [30, 60, 0]
const GRAPHICS_PRESETS: PackedStringArray = ["low", "medium", "high"]
const LOW_RENDER_SCALE: float = 0.75
const MUTE_DB: float = -80.0
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

var _screen: Screen = Screen.TITLE
var _return_screen: Screen = Screen.TITLE
var _panels: Dictionary = {}
var _keys: Dictionary = {}
var _option_buttons: Dictionary = {}
var _checks: Dictionary = {}
var _sliders: Dictionary = {}
var _syncing: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var locale: Node = _locale_node()
	if locale != null:
		add_theme_font_override("font", locale.call("font_for", &"ui") as Font)
		if not locale.is_connected("language_changed", _on_language_changed):
			locale.connect("language_changed", _on_language_changed)
	_add_backdrop()
	_build_title_panel()
	_build_pause_panel()
	_build_settings_panel()
	_apply_saved_all()
	_refresh_labels()
	show_screen(Screen.TITLE)


func _exit_tree() -> void:
	var locale: Node = _locale_node()
	if locale != null and locale.is_connected("language_changed", _on_language_changed):
		locale.disconnect("language_changed", _on_language_changed)


## Shows one screen (and the menu root). Settings opened from another screen return to it with go_back().
func show_screen(screen: Screen) -> void:
	_screen = screen
	for key: int in _panels.keys():
		(_panels[key] as Control).visible = key == int(screen)
	visible = true


func current_screen() -> Screen:
	return _screen


func hide_menus() -> void:
	visible = false


## Leaves the settings screen for the screen it was opened from. Does nothing on other screens.
func go_back() -> void:
	if _screen == Screen.SETTINGS:
		show_screen(_return_screen)


## Sets one option, applies it and saves it. Returns false (and changes nothing) for an unknown option or value.
func set_option(option: StringName, value: Variant) -> bool:
	var key: String = str(option)
	if key == LANGUAGE_OPTION:
		var code: String = str(value)
		var locale: Node = _locale_node()
		if not LANGUAGES.has(code) or locale == null:
			return false
		locale.call("set_language", StringName(code))
		_sync_widgets()
		return true
	if not DEFAULTS.has(key):
		return false
	var clean: Variant = _validated(key, value)
	if clean == null:
		return false
	_store(key, clean)
	_apply(key, clean)
	_sync_widgets()
	return true


## The current value of an option, as saved (or its default).
func get_option(option: StringName) -> Variant:
	return Menus.saved_option(option)


## The saved value of an option without needing a Menus instance. Returns null for an unknown option.
static func saved_option(option: StringName) -> Variant:
	var key: String = str(option)
	if key == LANGUAGE_OPTION:
		return _current_language()
	if not DEFAULTS.has(key):
		return null
	var default_value: Variant = DEFAULTS[key]
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return default_value
	var stored: Variant = config.get_value(str(OPTION_SECTIONS[key]), key, default_value)
	var clean: Variant = _validated(key, stored)
	if clean == null:
		return default_value
	return clean


## The Locale autoload (core/locale.gd), or null when it is not in the scene tree.
static func _locale_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Locale")


static func _current_language() -> String:
	var locale: Node = _locale_node()
	if locale == null:
		return "en"
	return str(locale.call("language"))


## "low", "medium" or "high": read by the other views to pick their detail level.
static func graphics_preset() -> String:
	return str(saved_option(&"graphics"))


## "on", "short" or "off": how shloka cards are shown.
static func shloka_cards_mode() -> String:
	return str(saved_option(&"shloka_cards"))


## How many of total crowd instances to draw under the saved graphics preset.
static func crowd_limit(total: int) -> int:
	return _visible_count(total, graphics_preset())


static func _visible_count(total: int, preset: String) -> int:
	if preset == "low":
		return floori(total * 0.5)
	return total


static func _validated(key: String, value: Variant) -> Variant:
	match key:
		"shloka_cards":
			var mode: String = str(value)
			return mode if SHLOKA_MODES.has(mode) else null
		"fps_cap":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return null
			var cap: int = value as int
			return cap if FPS_CAPS.has(cap) else null
		"graphics":
			var preset: String = str(value)
			return preset if GRAPHICS_PRESETS.has(preset) else null
		"vsync", "fullscreen":
			return value if typeof(value) == TYPE_BOOL else null
		"volume_master", "volume_music", "volume_sfx":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return null
			var level: float = value as float
			return level if level >= 0.0 and level <= 1.0 else null
		_:
			return null


func _store(key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(str(OPTION_SECTIONS[key]), key, value)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Menus: could not save setting '%s' (error %d)" % [key, err])


func _apply(key: String, value: Variant) -> void:
	match key:
		"fps_cap":
			Engine.max_fps = value as int
		"graphics":
			_apply_graphics(str(value))
		"vsync":
			var vsync_on: bool = value as bool
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)
		"fullscreen":
			var full: bool = value as bool
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
		"volume_master":
			_set_bus_volume(BUS_MASTER, value as float)
		"volume_music":
			_set_bus_volume(BUS_MUSIC, value as float)
		"volume_sfx":
			_set_bus_volume(BUS_SFX, value as float)


func _apply_saved_all() -> void:
	for key: String in DEFAULTS.keys():
		_apply(key, saved_option(StringName(key)))


func _apply_graphics(preset: String) -> void:
	var low: bool = preset == "low"
	if not is_inside_tree():
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.scaling_3d_scale = LOW_RENDER_SCALE if low else 1.0
		viewport.msaa_3d = Viewport.MSAA_2X if preset == "high" else Viewport.MSAA_DISABLED
	for node: Node in get_tree().get_nodes_in_group(&"sun"):
		var light: DirectionalLight3D = node as DirectionalLight3D
		if light != null:
			light.shadow_enabled = not low
	for node: Node in get_tree().get_nodes_in_group(&"crowd"):
		var crowd: MultiMeshInstance3D = node as MultiMeshInstance3D
		if crowd != null and crowd.multimesh != null:
			crowd.multimesh.visible_instance_count = _visible_count(crowd.multimesh.instance_count, preset)


func _set_bus_volume(bus: String, level: float) -> void:
	var index: int = _ensure_bus(bus)
	var decibels: float = MUTE_DB if level <= 0.0 else linear_to_db(level)
	AudioServer.set_bus_volume_db(index, decibels)


func _ensure_bus(bus: String) -> int:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus)
	if bus != BUS_MASTER:
		AudioServer.set_bus_send(index, BUS_MASTER)
	return index


# --- Building the screens -------------------------------------------------------

func _add_backdrop() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)


func _make_panel(screen: Screen, panel_name: String) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	center.name = panel_name + "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = panel_name
	column.custom_minimum_size = Vector2(MENU_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	_panels[int(screen)] = center
	return column


func _build_title_panel() -> void:
	var column: VBoxContainer = _make_panel(Screen.TITLE, "TitlePanel")
	var title: Label = _make_label("TitleLabel", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_localize(title, "UI_MENU_TITLE")
	_add_button(column, "BeginButton", "UI_MENU_BEGIN", _on_begin_pressed)
	_add_button(column, "TitleSettingsButton", "UI_MENU_SETTINGS", _open_settings)
	_add_button(column, "QuitButton", "UI_MENU_QUIT", _on_quit_pressed)


func _build_pause_panel() -> void:
	var column: VBoxContainer = _make_panel(Screen.PAUSE, "PausePanel")
	var heading: Label = _make_label("PausedLabel", 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_localize(heading, "UI_MENU_PAUSED")
	_add_button(column, "ResumeButton", "UI_MENU_RESUME", _on_resume_pressed)
	_add_button(column, "PauseSettingsButton", "UI_MENU_SETTINGS", _open_settings)
	_add_button(column, "QuitToTitleButton", "UI_MENU_QUIT_TO_TITLE", _on_quit_to_title_pressed)


func _build_settings_panel() -> void:
	var column: VBoxContainer = _make_panel(Screen.SETTINGS, "SettingsPanel")
	var heading: Label = _make_label("SettingsHeading", 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_localize(heading, "UI_MENU_SETTINGS")
	_add_option_row(column, LANGUAGE_OPTION, "LanguageLabel", "UI_MENU_LANGUAGE", "LanguageOption")
	_add_option_row(column, "shloka_cards", "ShlokaLabel", "UI_MENU_SHLOKA_CARDS", "ShlokaOption")
	_add_option_row(column, "fps_cap", "FpsLabel", "UI_MENU_FPS", "FpsOption")
	_add_option_row(column, "graphics", "GraphicsLabel", "UI_MENU_GRAPHICS", "GraphicsOption")
	_add_check(column, "vsync", "VsyncCheck", "UI_MENU_VSYNC")
	_add_check(column, "fullscreen", "FullscreenCheck", "UI_MENU_FULLSCREEN")
	_add_slider_row(column, "volume_master", "VolumeMasterLabel", "UI_MENU_VOLUME_MASTER", "VolumeMasterSlider")
	_add_slider_row(column, "volume_music", "VolumeMusicLabel", "UI_MENU_VOLUME_MUSIC", "VolumeMusicSlider")
	_add_slider_row(column, "volume_sfx", "VolumeSfxLabel", "UI_MENU_VOLUME_SFX", "VolumeSfxSlider")
	_add_button(column, "BackButton", "UI_MENU_BACK", _on_back_pressed)


func _make_label(label_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _add_button(parent: Control, button_name: String, key: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.custom_minimum_size = Vector2(0.0, 44.0)
	parent.add_child(button)
	button.pressed.connect(handler)
	button.pressed.connect(_sfx.bind(&"ui_back" if button_name == "BackButton" or button_name == "ResumeButton" else &"ui_click"))
	button.mouse_entered.connect(_sfx.bind(&"ui_hover"))
	_localize(button, key)
	return button


func _make_row(column: VBoxContainer, label_name: String, key: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var label: Label = Label.new()
	label.name = label_name
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)
	_localize(label, key)
	return row


func _add_option_row(column: VBoxContainer, option: String, label_name: String, key: String, widget_name: String) -> void:
	var row: HBoxContainer = _make_row(column, label_name, key)
	var button: OptionButton = OptionButton.new()
	button.name = widget_name
	button.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(button)
	_option_buttons[option] = button
	button.item_selected.connect(_on_option_selected.bind(option))


func _add_check(column: VBoxContainer, option: String, widget_name: String, key: String) -> void:
	var check: CheckBox = CheckBox.new()
	check.name = widget_name
	column.add_child(check)
	_localize(check, key)
	_checks[option] = check
	check.toggled.connect(_on_check_toggled.bind(option))


func _add_slider_row(column: VBoxContainer, option: String, label_name: String, key: String, widget_name: String) -> void:
	var row: HBoxContainer = _make_row(column, label_name, key)
	var slider: HSlider = HSlider.new()
	slider.name = widget_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(200.0, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	_sliders[option] = slider
	slider.value_changed.connect(_on_slider_changed.bind(option))


## Records the text key of a node so that it is re-translated on every language change.
func _localize(node: Control, key: String) -> void:
	_keys[node] = key
	_set_text(node, key)


func _set_text(node: Control, key: String) -> void:
	var text: String = tr(key)
	if node is Label:
		(node as Label).text = text
	elif node is Button:
		(node as Button).text = text


func _refresh_labels() -> void:
	for node: Variant in _keys.keys():
		_set_text(node as Control, str(_keys[node]))
	for option: String in _option_buttons.keys():
		_fill_option(_option_buttons[option] as OptionButton, option)
	_sync_widgets()


func _choices(option: String) -> Array:
	match option:
		LANGUAGE_OPTION:
			return Array(LANGUAGES)
		"shloka_cards":
			return Array(SHLOKA_MODES)
		"fps_cap":
			return Array(FPS_CAPS)
		"graphics":
			return Array(GRAPHICS_PRESETS)
		_:
			return []


func _choice_text(option: String, value: Variant) -> String:
	match option:
		LANGUAGE_OPTION:
			return tr("UI_MENU_LANG_HI") if str(value) == "hi" else tr("UI_MENU_LANG_EN")
		"shloka_cards":
			return tr("UI_MENU_SHLOKA_" + str(value).to_upper())
		"fps_cap":
			var cap: int = value as int
			return tr("UI_MENU_FPS_UNLIMITED") if cap == 0 else str(cap)
		"graphics":
			return tr("UI_MENU_GFX_" + str(value).to_upper())
		_:
			return str(value)


func _fill_option(button: OptionButton, option: String) -> void:
	button.clear()
	for value: Variant in _choices(option):
		button.add_item(_choice_text(option, value))


## Shows the saved values in every widget.
func _sync_widgets() -> void:
	_syncing = true
	for option: String in _option_buttons.keys():
		var button: OptionButton = _option_buttons[option] as OptionButton
		var index: int = _choices(option).find(get_option(StringName(option)))
		if index >= 0:
			button.select(index)
	for option: String in _checks.keys():
		(_checks[option] as CheckBox).button_pressed = (get_option(StringName(option)) as bool)
	for option: String in _sliders.keys():
		(_sliders[option] as HSlider).value = (get_option(StringName(option)) as float)
	_syncing = false


func _on_option_selected(index: int, option: String) -> void:
	if _syncing:
		return
	var choices: Array = _choices(option)
	if index >= 0 and index < choices.size():
		set_option(StringName(option), choices[index])


func _on_check_toggled(pressed: bool, option: String) -> void:
	if not _syncing:
		set_option(StringName(option), pressed)


func _on_slider_changed(level: float, option: String) -> void:
	if not _syncing:
		set_option(StringName(option), level)


func _on_language_changed(_code: StringName) -> void:
	_refresh_labels()


func _open_settings() -> void:
	_return_screen = _screen
	show_screen(Screen.SETTINGS)


func _on_back_pressed() -> void:
	go_back()


func _on_begin_pressed() -> void:
	start_requested.emit()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_quit_to_title_pressed() -> void:
	quit_to_title_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


## Plays a Sound autoload event (silent when the autoload is absent).
func _sfx(id: StringName) -> void:
	var s: Node = get_node_or_null("/root/Sound") if is_inside_tree() else null
	if s != null:
		s.call("play", id)
