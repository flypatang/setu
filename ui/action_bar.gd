class_name ActionBar
extends Control
## S42: the always-visible action bar, banner, toast, speed buttons and crew panel.
##
## Seven large icon + label buttons (hotkeys 1-7) emit action_requested(id). Their ids match the radial
## build menu: route, crews, lekhan, gong, shelter, measuring_line, chant. The bar also holds
## - a banner at the top that says what to click next (set_banner),
## - a toast line for short results (show_toast),
## - pause / 1x / 2x / 3x buttons at the top right (speed_requested),
## - a small crew panel with + and - per role at a clicked site (show_crew_panel).
## The bar never touches the simulation: MainGame connects the signals.

signal action_requested(id: StringName)
signal speed_requested(speed: int)
signal crew_change(site_id: String, role: String, delta: int)
signal crew_panel_closed

const ACTIONS: Array[StringName] = [
	&"route", &"crews", &"lekhan", &"gong", &"shelter", &"measuring_line", &"chant",
]
const HOTKEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const SPEEDS: Array[int] = [0, 1, 2, 3]
const BUTTON_SIZE: Vector2 = Vector2(122.0, 84.0)
const ICON_PX: int = 36
const TOAST_SECONDS: float = 4.0
const ACTIVE_TINT: Color = Color(1.0, 0.85, 0.35, 1.0)
const GOLD: Color = Color(0.91, 0.73, 0.29, 1.0)
const INK: Color = Color(0.08, 0.07, 0.06, 1.0)

## When false the hotkeys and buttons do nothing (title screen, summary).
var enabled: bool = true

var _buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _bar: PanelContainer = null
var _speed_box: HBoxContainer = null
var _banner_panel: PanelContainer = null
var _banner: Label = null
var _toast: Label = null
var _toast_timer: Timer = null
var _panel: PanelContainer = null
var _panel_title: Label = null
var _panel_role: Label = null
var _panel_count: Label = null
var _panel_free: Label = null
var _plus: Button = null
var _done: Button = null
var _panel_site: String = ""
var _panel_site_title: String = ""
var _panel_role_id: String = ""
var _panel_here: int = 0
var _panel_free_n: int = 0
var _active: StringName = &""
var _highlight: StringName = &""
var _speed: int = 1
var _t: float = 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_speed_box()
	_build_banner()
	_build_panel()


func _ready() -> void:
	refresh_texts()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh_texts()


func _process(delta: float) -> void:
	_t += delta
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
	for id: StringName in ACTIONS:
		var b: Button = _buttons[id] as Button
		if id == _active:
			b.self_modulate = ACTIVE_TINT
		elif id == _highlight:
			b.self_modulate = Color.WHITE.lerp(ACTIVE_TINT, pulse)
		else:
			b.self_modulate = Color.WHITE


func _unhandled_key_input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	for i: int in HOTKEYS.size():
		if key.keycode == HOTKEYS[i] or key.physical_keycode == HOTKEYS[i]:
			action_requested.emit(ACTIONS[i])
			get_viewport().set_input_as_handled()
			return


# --- public API ---------------------------------------------------------------

func action_button(id: StringName) -> Button:
	return _buttons.get(id, null) as Button


func speed_button(n: int) -> Button:
	return _speed_buttons.get(n, null) as Button


func crew_plus_button() -> Button:
	return _plus



func crew_panel_text() -> String:
	return "%s\n%s\n%s" % [_panel_title.text, _panel_count.text, _panel_free.text]


func is_crew_panel_open() -> bool:
	return _panel.visible


func banner_text() -> String:
	return _banner.text if _banner_panel.visible else ""


func toast_text() -> String:
	return _toast.text if _toast.visible else ""


func active_action() -> StringName:
	return _active


## Marks the action button whose mode is in progress (empty id clears it).
func set_active(id: StringName) -> void:
	_active = id


## Makes one action button pulse (the tutorial's pointer). Empty id clears it.
func set_highlight(id: StringName) -> void:
	_highlight = id


func highlighted_action() -> StringName:
	return _highlight


func set_banner(text: String) -> void:
	_banner.text = text
	_banner_panel.visible = text != ""


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = text != ""
	if _toast_timer.is_inside_tree():
		_toast_timer.start(TOAST_SECONDS)


func set_speed_display(n: int) -> void:
	_speed = n
	for k: int in _speed_buttons.keys():
		var b: Button = _speed_buttons[k] as Button
		b.self_modulate = ACTIVE_TINT if k == n else Color.WHITE


## Opens (or refreshes) the crew panel for one site. `screen` is where it appears (clamped to the view).
func show_crew_panel(site_id: String, site_title: String, role: String, here: int, free: int, screen: Vector2) -> void:
	var fresh: bool = not _panel.visible or _panel_site != site_id
	_panel_site = site_id
	_panel_site_title = site_title
	_panel_role_id = role
	_panel_here = here
	_panel_free_n = free
	_panel_title.text = tr("UI_CREW_TITLE") % site_title
	_panel_role.text = tr("UI_CREW_ROLE_" + role.to_upper())
	_panel_count.text = tr("UI_CREW_HERE") % here
	_panel_free.text = tr("UI_CREW_FREE") % free
	_plus.disabled = free <= 0
	_panel.visible = true
	if fresh:
		var view: Vector2 = get_viewport_rect().size
		var size_px: Vector2 = _panel.get_combined_minimum_size()
		_panel.position = Vector2(
			clampf(screen.x + 24.0, 8.0, maxf(view.x - size_px.x - 8.0, 8.0)),
			clampf(screen.y - size_px.y * 0.5, 8.0, maxf(view.y - size_px.y - 130.0, 8.0)))


func hide_crew_panel() -> void:
	if _panel.visible:
		_panel.visible = false
		crew_panel_closed.emit()


func crew_panel_site() -> String:
	return _panel_site if _panel.visible else ""


func set_font(font: Font) -> void:
	if font == null:
		return
	for c: Node in _all_controls(self):
		(c as Control).add_theme_font_override("font", font)


func refresh_texts() -> void:
	for i: int in ACTIONS.size():
		var id: StringName = ACTIONS[i]
		var b: Button = _buttons[id] as Button
		b.text = "%d  %s" % [i + 1, tr("UI_BUILD_" + String(id).to_upper())]
		b.tooltip_text = tr("UI_TIP_" + _tip_key(id))
	for n: int in SPEEDS:
		var sb: Button = _speed_buttons[n] as Button
		sb.text = "II" if n == 0 else "%dx" % n
		sb.tooltip_text = tr("UI_TIP_PAUSE") if n == 0 else tr("UI_TIP_SPEED") % n
	_done.text = tr("UI_CREW_DONE")
	if _panel.visible:
		show_crew_panel(_panel_site, _panel_site_title, _panel_role_id, _panel_here, _panel_free_n, _panel.position)


# --- construction -------------------------------------------------------------

static func _tip_key(id: StringName) -> String:
	if id == &"measuring_line":
		return "MEASURE"
	return String(id).to_upper()


func _all_controls(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c: Node in root.get_children():
		if c is Button or c is Label:
			out.append(c)
		out.append_array(_all_controls(c))
	return out


func _panel_style(alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(INK, alpha)
	style.border_color = Color(GOLD, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	return style


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -124.0
	_bar.offset_bottom = -36.0
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.add_theme_stylebox_override(&"panel", _panel_style(0.72))
	add_child(_bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	_bar.add_child(row)
	for id: StringName in ACTIONS:
		var b: Button = Button.new()
		b.name = String(id)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = BUTTON_SIZE
		b.icon = make_icon(id)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.pressed.connect(_on_action_pressed.bind(id))
		row.add_child(b)
		_buttons[id] = b


func _build_speed_box() -> void:
	_speed_box = HBoxContainer.new()
	_speed_box.name = "Speed"
	_speed_box.anchor_left = 1.0
	_speed_box.anchor_right = 1.0
	_speed_box.offset_left = -236.0
	_speed_box.offset_right = -16.0
	_speed_box.offset_top = 46.0
	_speed_box.offset_bottom = 90.0
	_speed_box.add_theme_constant_override(&"separation", 6)
	add_child(_speed_box)
	for n: int in SPEEDS:
		var b: Button = Button.new()
		b.name = "speed_%d" % n
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(50.0, 40.0)
		b.pressed.connect(_on_speed_pressed.bind(n))
		_speed_box.add_child(b)
		_speed_buttons[n] = b
	set_speed_display(_speed)


func _build_banner() -> void:
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "Banner"
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.offset_top = 14.0
	_banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_panel.add_theme_stylebox_override(&"panel", _panel_style(0.82))
	_banner_panel.visible = false
	add_child(_banner_panel)
	_banner = Label.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(560.0, 0.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override(&"font_size", 20)
	_banner.add_theme_color_override(&"font_color", Color(1.0, 0.93, 0.7))
	_banner_panel.add_child(_banner)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -300.0
	_toast.offset_right = 300.0
	_toast.offset_top = -158.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_bottom = -128.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override(&"font_size", 18)
	_toast.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0))
	_toast.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	_toast.add_theme_constant_override(&"outline_size", 6)
	_toast.visible = false
	add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_on_toast_timeout)
	add_child(_toast_timer)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "CrewPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(&"panel", _panel_style(0.92))
	_panel.visible = false
	add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_panel.add_child(box)
	_panel_title = _label(box)
	_panel_title.add_theme_color_override(&"font_color", GOLD)
	_panel_role = _label(box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	box.add_child(row)
	_panel_count = _label(row)
	_panel_count.custom_minimum_size = Vector2(120.0, 0.0)
	_panel_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus = _small_button(row, "+")
	_plus.pressed.connect(_on_crew_pressed.bind(1))
	_panel_free = _label(box)
	_done = Button.new()
	_done.focus_mode = Control.FOCUS_NONE
	_done.custom_minimum_size = Vector2(0.0, 36.0)
	_done.pressed.connect(hide_crew_panel)
	box.add_child(_done)


func _label(parent: Node) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _small_button(parent: Node, text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(48.0, 44.0)
	b.add_theme_font_size_override(&"font_size", 24)
	parent.add_child(b)
	return b


# --- signals ------------------------------------------------------------------

func _on_action_pressed(id: StringName) -> void:
	if enabled:
		action_requested.emit(id)


func _on_speed_pressed(n: int) -> void:
	if enabled:
		speed_requested.emit(n)


func _on_crew_pressed(delta: int) -> void:
	if _panel_site != "":
		crew_change.emit(_panel_site, _panel_role_id, delta)


func _on_toast_timeout() -> void:
	_toast.visible = false


# --- icons --------------------------------------------------------------------

## A small procedural icon for an action (drawn into an image, no art files).
static func make_icon(id: StringName) -> ImageTexture:
	var img: Image = Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c: Color = GOLD
	var w: Color = Color(1.0, 0.97, 0.9)
	match id:
		&"route":
			_line(img, Vector2(4.0, 28.0), Vector2(30.0, 8.0), 3.0, c)
			_disc(img, Vector2(6.0, 27.0), 4.0, w)
			_disc(img, Vector2(18.0, 18.0), 2.5, w)
			_tri(img, Vector2(33.0, 5.0), Vector2(22.0, 8.0), Vector2(30.0, 17.0), w)
		&"crews":
			for x: float in [10.0, 18.0, 26.0]:
				_disc(img, Vector2(x, 12.0), 4.0, w)
				_rect(img, Rect2(x - 4.0, 18.0, 8.0, 12.0), c)
		&"lekhan":
			_rect(img, Rect2(6.0, 5.0, 24.0, 28.0), c)
			_line(img, Vector2(10.0, 13.0), Vector2(26.0, 13.0), 2.0, INK)
			_line(img, Vector2(18.0, 13.0), Vector2(18.0, 28.0), 2.0, INK)
			_line(img, Vector2(10.0, 20.0), Vector2(26.0, 20.0), 2.0, INK)
		&"gong":
			_disc(img, Vector2(18.0, 20.0), 12.0, c)
			_disc(img, Vector2(18.0, 20.0), 6.0, w)
			_line(img, Vector2(4.0, 4.0), Vector2(32.0, 4.0), 2.0, w)
		&"shelter":
			_tri(img, Vector2(18.0, 4.0), Vector2(2.0, 18.0), Vector2(34.0, 18.0), c)
			_rect(img, Rect2(6.0, 18.0, 24.0, 14.0), w)
			_rect(img, Rect2(15.0, 22.0, 6.0, 10.0), c)
		&"measuring_line":
			_line(img, Vector2(3.0, 28.0), Vector2(33.0, 8.0), 3.0, c)
			for t: float in [0.15, 0.4, 0.65, 0.9]:
				var p: Vector2 = Vector2(3.0, 28.0).lerp(Vector2(33.0, 8.0), t)
				_line(img, p, p + Vector2(-3.0, -5.0), 2.0, w)
		&"chant":
			_disc(img, Vector2(18.0, 18.0), 5.0, w)
			for r: float in [9.0, 14.0]:
				_ring(img, Vector2(18.0, 18.0), r, c)
	return ImageTexture.create_from_image(img)


static func _put(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


static func _disc(img: Image, center: Vector2, r: float, col: Color) -> void:
	for y: int in range(int(center.y - r) - 1, int(center.y + r) + 2):
		for x: int in range(int(center.x - r) - 1, int(center.x + r) + 2):
			if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) <= r:
				_put(img, x, y, col)


static func _ring(img: Image, center: Vector2, r: float, col: Color) -> void:
	for y: int in range(int(center.y - r) - 2, int(center.y + r) + 3):
		for x: int in range(int(center.x - r) - 2, int(center.x + r) + 3):
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if absf(d - r) <= 1.0:
				_put(img, x, y, col)


static func _rect(img: Image, rect: Rect2, col: Color) -> void:
	for y: int in range(int(rect.position.y), int(rect.end.y)):
		for x: int in range(int(rect.position.x), int(rect.end.x)):
			_put(img, x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var steps: int = maxi(int(a.distance_to(b) * 2.0), 1)
	for i: int in steps + 1:
		_disc(img, a.lerp(b, float(i) / float(steps)), width * 0.5, col)


static func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var lo: Vector2 = Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var hi: Vector2 = Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	for y: int in range(int(lo.y), int(hi.y) + 1):
		for x: int in range(int(lo.x), int(hi.x) + 1):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var d1: float = (p - b).cross(a - b)
			var d2: float = (p - c).cross(b - c)
			var d3: float = (p - a).cross(c - a)
			var neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (neg and pos):
				_put(img, x, y, col)
