class_name MainGame
extends Node3D
## S22: the playable game. Title -> prologue -> Days 1..5 -> finale -> credits -> title.
## Owns the views (world, bridge, crowd), the HUD and menus, drives the simulation from _physics_process
## through SimClock speed, plays event dialogue, shows the day summary and saves progress in GameState.

enum Phase { TITLE, PROLOGUE, DAY, SUMMARY, VIGNETTE, FINALE, CREDITS }

const LAST_DAY: int = 5
const DAY_PATH: String = "res://data/days/day_%d.json"
const PROLOGUE_PATH: String = "res://data/days/prologue.json"
const SAVE_SLOT: int = 0
const MAX_TICKS_PER_FRAME: int = 240
const FLAG_DAY: StringName = &"day_reached"
const FLAG_CUMULATIVE: StringName = &"cumulative_m"
const FLAG_CARRY: StringName = &"carry_m"
const PROLOGUE_SPEED: int = 2
const FIRST_STONE_POS: Vector3 = Vector3(-6.0, 0.0, 4.0)
const CREDITS_TEXT: String = "SETU - The Bridge to Lanka\n\nThe bridge was built in five days:\n14, 20, 21, 22 and 23 yojanas.\n\nBuilt by Nala and Nila, and by every vanara, in the name of Rama.\n\nThank you for playing."
const UI_FALLBACK: Dictionary = {
	"UI_MENU_TITLE": "Setu - The Bridge to Lanka", "UI_MENU_BEGIN": "New Game", "UI_MENU_SETTINGS": "Settings",
	"UI_MENU_QUIT": "Quit", "UI_MENU_PAUSED": "Paused", "UI_MENU_RESUME": "Resume",
	"UI_MENU_QUIT_TO_TITLE": "Quit to title", "UI_MENU_BACK": "Back", "UI_MENU_LANGUAGE": "Language",
	"UI_MENU_LANG_EN": "English", "UI_MENU_LANG_HI": "Hindi", "UI_MENU_FPS": "Frame rate",
	"UI_MENU_FPS_UNLIMITED": "Unlimited", "UI_MENU_GRAPHICS": "Graphics", "UI_MENU_GFX_LOW": "Low",
	"UI_MENU_GFX_MEDIUM": "Medium", "UI_MENU_GFX_HIGH": "High", "UI_MENU_VSYNC": "VSync",
	"UI_MENU_FULLSCREEN": "Fullscreen", "UI_MENU_SHLOKA_CARDS": "Shloka cards", "UI_MENU_SHLOKA_ON": "On",
	"UI_MENU_SHLOKA_SHORT": "Short", "UI_MENU_SHLOKA_OFF": "Off", "UI_MENU_VOLUME_MASTER": "Master volume",
	"UI_MENU_VOLUME_MUSIC": "Music volume", "UI_MENU_VOLUME_SFX": "Effects volume",
	"UI_HUD_CLOCK": "Day %d - sunset in %s", "UI_HUD_LENGTH": "Bridge %d / %d m",
	"UI_HUD_STOCK_STONE": "Stone: %d", "UI_HUD_STOCK_INSCRIBED": "Inscribed stone: %d",
	"UI_HUD_STOCK_TIMBER": "Timber: %d", "UI_HUD_STOCK_ROPE": "Rope: %d", "UI_HUD_MORALE": "Utsaha (morale): %d",
	"UI_SUM_TITLE": "Day %d complete", "UI_SUM_LENGTH": "Length: %.0f%%", "UI_SUM_ALIGN": "Alignment: %.0f%%",
	"UI_SUM_WASTE": "Waste: %.0f%%", "UI_SUM_MORALE": "Morale: %.0f", "UI_SUM_TOTAL": "Score: %.0f",
	"UI_SUM_CARRY": "Carried over to the next day: %d m", "UI_SUM_CONTINUE": "Continue",
	"UI_BUILD_ROUTE": "Haul route", "UI_BUILD_CREWS": "Assign crew", "UI_BUILD_LEKHAN": "Lekhan station",
	"UI_BUILD_GONG": "Ring gong", "UI_BUILD_SHELTER": "Shelter", "UI_BUILD_MEASURING_LINE": "Measuring line",
	"UI_BUILD_CHANT": "Jaya chant",
}
const ROUTE_PRESETS: Array = [
	["quarry", "lekhan", "stone"], ["lekhan", "head", "inscribed_stone"], ["forest", "head", "timber"],
	["forest", "ropeworks", "timber"], ["ropeworks", "head", "rope"],
]
const CREW_PRESETS: Array = [["cutter", "quarry"], ["lumberjack", "forest"], ["lasher", "ropeworks"], ["scribe", "lekhan"]]

## When false nothing is written to disk (tests).
var persist: bool = true
## When false event and story dialogue is skipped (tests).
var dialogue_enabled: bool = true
## The GameState autoload (or a stand-in). Looked up in _ready when left null.
var game_state: Node = null

var _phase: Phase = Phase.TITLE
var _flow: DayFlow = null
var _day_dict: Dictionary = {}
var _speed: int = 1
var _last_speed: int = 1
var _menu_paused: bool = false
var _carry: int = 0
var _cumulative: int = 0
var _past: Array[Dictionary] = []
var _past_views: Array[BridgeView] = []
var _events_seen: int = 0
var _queue: Array[String] = []
var _after_dialogue: Callable = Callable()
var _route_n: int = 0
var _preset_route: int = 0
var _preset_crew: int = 0
var _first_stone: Node3D = null
var _floated: bool = false
var _t: float = 0.0
var _fallback_tr: Translation = null

var _stage: Node3D = null
var _world: WorldView = null
var _bridge_view: BridgeView = null
var _crowd: CrowdView = null
var _camera: RtsCamera = null
var _controller: InputController = null
var _menus: Menus = null
var _dialogue: DialogueBox = null
var _hud: Hud = null
var _build_menu: BuildMenu = null
var _summary: DaySummary = null
var _prompt: Label = null
var _prompt_button: Button = null
var _speed_label: Label = null
var _hint: Label = null
var _continue_button: Button = null
var _credits: Control = null


func _ready() -> void:
	if game_state == null:
		game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		game_state = (load("res://core/game_state.gd") as GDScript).new() as Node
		add_child(game_state)
	if persist:
		game_state.call("load_game", SAVE_SLOT)
	_install_ui_strings()
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_camera = RtsCamera.new()
	add_child(_camera)
	_controller = InputController.new()
	add_child(_controller)
	_controller.time_requested.connect(_on_time_requested)
	_build_ui()
	_show_title()


func _exit_tree() -> void:
	if _fallback_tr != null:
		TranslationServer.remove_translation(_fallback_tr)
		_fallback_tr = null


func _physics_process(delta: float) -> void:
	tick_frame(delta)


func _process(delta: float) -> void:
	_t += delta
	if _first_stone != null:
		var lift: float = 0.0
		if _floated:
			lift = 0.25 + 0.12 * sin(_t * 2.0)
		_first_stone.position = FIRST_STONE_POS + Vector3(0.0, 0.45 + lift, 0.0)
	if _continue_button != null:
		_continue_button.visible = _phase == Phase.TITLE and _menus.visible \
			and _menus.current_screen() == Menus.Screen.TITLE and can_continue()


# --- public API ---------------------------------------------------------------

func phase() -> Phase:
	return _phase


func flow() -> DayFlow:
	return _flow


func cumulative_m() -> int:
	return _cumulative


## World x where the current day's bridge starts (metres built on earlier days).
func origin_x() -> float:
	return float(_cumulative)


func bridge_view() -> BridgeView:
	return _bridge_view


func past_view_count() -> int:
	return _past_views.size()


func past_view(i: int) -> BridgeView:
	return _past_views[i]


func dialogue_box() -> DialogueBox:
	return _dialogue


func menus() -> Menus:
	return _menus


func rts_camera() -> RtsCamera:
	return _camera


func input_controller() -> InputController:
	return _controller


func speed() -> int:
	return _speed


func is_paused() -> bool:
	return _menu_paused or _speed == 0


func time_of_day() -> float:
	if _flow == null or _flow.day_ticks <= 0:
		return 0.5
	return clampf(float(_flow.tick()) / float(_flow.day_ticks), 0.0, 1.0)


func saved_day_reached() -> int:
	return _flag_int(FLAG_DAY)


func saved_cumulative_m() -> int:
	return _flag_int(FLAG_CUMULATIVE)


func can_continue() -> bool:
	var d: int = saved_day_reached()
	return d >= 1 and d <= LAST_DAY


func set_speed(n: int) -> void:
	_speed = clampi(n, 0, SimClock.MAX_SPEED)
	if _speed > 0:
		_last_speed = _speed
	if _flow != null:
		_flow.clock.speed = _speed
	_update_speed_label()


func toggle_pause() -> void:
	set_speed(_last_speed if _speed == 0 else 0)


func open_pause() -> void:
	if _phase != Phase.DAY and _phase != Phase.PROLOGUE:
		return
	_menu_paused = true
	_build_menu.close()
	_menus.show_screen(Menus.Screen.PAUSE)


func close_pause() -> void:
	_menu_paused = false
	_menus.hide_menus()


func start_new_game() -> void:
	_reset_progress()
	_menus.hide_menus()
	_phase = Phase.PROLOGUE
	_build_prologue()
	_say("pro_shore", Callable(self, "_prologue_ready"))


func continue_game() -> void:
	if not can_continue():
		return
	_menus.hide_menus()
	_cumulative = saved_cumulative_m()
	_carry = _flag_int(FLAG_CARRY)
	_past.clear()
	if _cumulative > 0:
		_past.append({"bridge": _filler_bridge(_cumulative), "origin": 0})
	begin_day(saved_day_reached())


## Prologue step: puts the scribes to work so the first stone can be inscribed.
func prologue_assign_scribes() -> void:
	if _phase != Phase.PROLOGUE or _flow == null:
		return
	_flow.apply_command({"type": "assign_crews", "args": {"role": "scribe", "site": "lekhan", "crews": 2}})
	_prompt.visible = false
	_prompt_button.visible = false
	set_speed(PROLOGUE_SPEED)


## Loads day n (1..5) with the carry-over and the cumulative length so far, and builds the views.
func begin_day(n: int) -> void:
	var day_n: int = clampi(n, 1, LAST_DAY)
	_day_dict = _read_json(DAY_PATH % day_n)
	_flow = DayFlow.new()
	_flow.load_day(_day_dict, _carry)
	_speed = 1
	_last_speed = 1
	_flow.clock.speed = 1
	_events_seen = 0
	_phase = Phase.DAY
	_menu_paused = false
	_menus.hide_menus()
	_summary.visible = false
	_credits.visible = false
	_prompt.visible = false
	_prompt_button.visible = false
	_build_stage(_day_dict)
	_camera.focus_on(Vector3(origin_x() - 20.0, 0.0, 0.0))
	_hud.visible = true
	_hud.update_from(_flow)
	_update_speed_label()
	_set_game_ui(true)
	_set_chapter("day_%d" % day_n)


## Advances the simulation by real time delta. Returns the number of ticks run.
func tick_frame(delta: float) -> int:
	if _flow == null or (_phase != Phase.DAY and _phase != Phase.PROLOGUE):
		return 0
	if _menu_paused or (_dialogue != null and _dialogue.is_playing()):
		return 0
	var n: int = mini(_flow.clock.advance(delta), MAX_TICKS_PER_FRAME)
	if n > 0:
		_flow.run_ticks(n)
		_sync_views()
	if _phase == Phase.PROLOGUE:
		_check_first_stone()
	elif _phase == Phase.DAY:
		_check_events()
		if _flow.is_over():
			_on_day_over()
	return n


## Called by the summary's Continue button.
func continue_from_summary() -> void:
	if _phase != Phase.SUMMARY:
		return
	_summary.visible = false
	var ending: Array[String] = _ending_dialogue()
	if dialogue_enabled and not ending.is_empty():
		_phase = Phase.FINALE if _flow.day >= LAST_DAY else Phase.VIGNETTE
		for f: String in ending:
			_queue.append(f)
		_after_dialogue = Callable(self, "_advance_story")
		_pump_dialogue()
	else:
		_advance_story()


func finish_credits() -> void:
	_credits.visible = false
	return_to_title()


func return_to_title() -> void:
	_menu_paused = false
	_flow = null
	_queue.clear()
	_after_dialogue = Callable()
	_clear_stage()
	_past.clear()
	_cumulative = 0
	_carry = 0
	_show_title()


func is_story_dialogue_pending() -> bool:
	return not _queue.is_empty() or (_dialogue != null and _dialogue.is_playing())


# --- story ---------------------------------------------------------------------

func _prologue_ready() -> void:
	_prompt.text = tr("UI_PRO_PROMPT")
	_prompt_button.text = tr("UI_PRO_ASSIGN")
	_prompt.visible = true
	_prompt_button.visible = true


func _check_first_stone() -> void:
	var lekhan: Stockpile = _flow.pile("lekhan")
	if lekhan == null or lekhan.count("inscribed_stone") < 1 or _floated:
		return
	_floated = true
	_flow.clock.speed = 0
	_say("pro_first_stone", Callable(self, "_prologue_done"))


func _prologue_done() -> void:
	_floated = false
	begin_day(1)


func _check_events() -> void:
	var fired: Array[String] = _flow.events_fired()
	while _events_seen < fired.size():
		var id: String = fired[_events_seen]
		_events_seen += 1
		for e: Variant in _day_dict.get("events", []) as Array:
			var ed: Dictionary = e as Dictionary
			if str(ed.get("id", "")) == id and ed.has("dialogue") and DayFlow._int(ed.get("tick", 0)) < _flow.day_ticks:
				if dialogue_enabled:
					_queue.append(str(ed["dialogue"]))
	_pump_dialogue()


func _ending_dialogue() -> Array[String]:
	var out: Array[String] = []
	for e: Variant in _day_dict.get("events", []) as Array:
		var ed: Dictionary = e as Dictionary
		if ed.has("dialogue") and DayFlow._int(ed.get("tick", 0)) >= _flow.day_ticks:
			out.append(str(ed["dialogue"]))
	return out


func _on_day_over() -> void:
	_phase = Phase.SUMMARY
	_flow.clock.speed = 0
	_sync_views()
	var built: int = _flow.bridge.length_m()
	_past.append({"bridge": _flow.bridge, "origin": _cumulative})
	_cumulative += built
	_carry = _flow.carry_over()
	var next_day: int = _flow.day + 1
	_save_progress(next_day)
	_build_menu.close()
	_summary.show_summary(_flow)
	_summary.visible = true
	_set_game_ui(false)
	_summary.visible = true


func _advance_story() -> void:
	if _flow != null and _flow.day >= LAST_DAY:
		_show_credits()
	else:
		begin_day((_flow.day if _flow != null else 0) + 1)


func _show_credits() -> void:
	_phase = Phase.CREDITS
	_set_game_ui(false)
	_credits.visible = true
	_set_flag(FLAG_DAY, 0)
	_save()


# --- dialogue ------------------------------------------------------------------

func _say(file: String, then: Callable) -> void:
	if not dialogue_enabled:
		if then.is_valid():
			then.call()
		return
	_queue.append(file)
	_after_dialogue = then
	_pump_dialogue()


func _pump_dialogue() -> void:
	if _dialogue == null or _dialogue.is_playing() or _queue.is_empty():
		return
	var file: String = _queue.pop_front() as String
	var err: Error = _dialogue.play(StringName(file))
	if err != OK:
		_pump_dialogue()


func _on_dialogue_finished(_file_id: StringName) -> void:
	if not _queue.is_empty():
		_pump_dialogue()
		return
	if _after_dialogue.is_valid():
		var cb: Callable = _after_dialogue
		_after_dialogue = Callable()
		cb.call()


# --- views ---------------------------------------------------------------------

func _build_stage(day: Dictionary) -> void:
	_clear_stage()
	_world = WorldView.new()
	_stage.add_child(_world)
	_world.build_from_day(day)
	_world.set_time_of_day(time_of_day())
	for p: Dictionary in _past:
		var v: BridgeView = BridgeView.new()
		_stage.add_child(v)
		v.set_origin_x(float(p["origin"] as int))
		v.sync(p["bridge"] as Bridge)
		_past_views.append(v)
	_bridge_view = BridgeView.new()
	_stage.add_child(_bridge_view)
	_bridge_view.set_origin_x(origin_x())
	_crowd = CrowdView.new()
	_stage.add_child(_crowd)
	_controller.attach(_flow, _camera.get_camera())
	_sync_views()


func _clear_stage() -> void:
	for c: Node in _stage.get_children():
		_stage.remove_child(c)
		c.free()
	_world = null
	_bridge_view = null
	_crowd = null
	_first_stone = null
	_past_views.clear()
	_controller.attach(null, _camera.get_camera())


func _sync_views() -> void:
	if _flow == null:
		return
	if _world != null:
		_world.set_time_of_day(time_of_day())
	if _bridge_view != null:
		_bridge_view.sync(_flow.bridge)
	if _crowd != null:
		_crowd.sync(_flow)
	_hud.update_from(_flow)


func _build_prologue() -> void:
	var d: Dictionary = _read_json(PROLOGUE_PATH)
	if d.is_empty():
		d = {
			"day": 0, "target_yojanas": 0, "day_ticks": 9600, "total_crews": 4,
			"piles": [
				{"id": "quarry", "role": "cutter", "pos": [-24.0, -12.0], "stock": {"stone": 4}},
				{"id": "lekhan", "role": "scribe", "pos": [-12.0, 4.0], "stock": {"stone": 6}},
				{"id": "head", "role": "builder", "pos": [0.0, 0.0], "stock": {}},
			],
			"events": [],
		}
	_day_dict = d
	_flow = DayFlow.new()
	_flow.load_day(d, 0)
	_flow.clock.speed = 0
	_speed = 0
	_cumulative = 0
	_carry = 0
	_past.clear()
	_build_stage(d)
	_world.set_time_of_day(0.2)
	_make_first_stone()
	_camera.focus_on(Vector3(-8.0, 0.0, 2.0))
	_camera.set_ortho_size(40.0)
	_set_game_ui(true)
	_hud.visible = false
	_hint.visible = false


func _make_first_stone() -> void:
	var stone: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.4, 0.9, 1.1)
	stone.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Palette.WET_STONE
	stone.material_override = mat
	var glyph: Label3D = Label3D.new()
	glyph.text = "राम"
	glyph.font_size = 96
	glyph.pixel_size = 0.01
	glyph.modulate = Color("#1B1B3A")
	glyph.position = Vector3(0.0, 0.0, 0.56)
	glyph.no_depth_test = false
	var locale: Node = get_node_or_null("/root/Locale")
	if locale != null:
		glyph.font = locale.call("font_for", &"shloka") as Font
	stone.add_child(glyph)
	stone.position = FIRST_STONE_POS
	_stage.add_child(stone)
	_first_stone = stone


func _filler_bridge(length: int) -> Bridge:
	var b: Bridge = Bridge.new(Stockpile.new(), length)
	for i: int in length:
		var s: Bridge.Section = b.section(i)
		s.foundation = 1.0
		s.deck = 1.0
		s.complete = true
		s.blessed = true
		s.stone_in = Bridge.STONE_PER_SECTION
		s.timber_in = Bridge.TIMBER_PER_SECTION
		s.rope_in = Bridge.ROPE_PER_SECTION
	return b


# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	var game_layer: CanvasLayer = CanvasLayer.new()
	game_layer.layer = 1
	add_child(game_layer)
	_hud = Hud.new()
	_hud.position = Vector2(16.0, 12.0)
	game_layer.add_child(_hud)
	_speed_label = _make_label(game_layer)
	_speed_label.anchor_left = 1.0
	_speed_label.anchor_right = 1.0
	_speed_label.offset_left = -220.0
	_speed_label.offset_top = 12.0
	_speed_label.offset_right = -16.0
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint = _make_label(game_layer)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 16.0
	_hint.offset_top = -34.0
	_hint.offset_bottom = -8.0
	_hint.offset_right = 900.0
	_hint.text = tr("UI_HUD_CONTROLS")
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_build_menu = BuildMenu.new()
	game_layer.add_child(_build_menu)
	_build_menu.option_chosen.connect(_on_build_option)
	_prompt = _make_label(game_layer)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.15
	_prompt.offset_left = -330.0
	_prompt.offset_right = 330.0
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.visible = false
	_prompt_button = Button.new()
	_prompt_button.anchor_left = 0.5
	_prompt_button.anchor_right = 0.5
	_prompt_button.anchor_top = 0.15
	_prompt_button.offset_left = -90.0
	_prompt_button.offset_right = 90.0
	_prompt_button.offset_top = 90.0
	_prompt_button.offset_bottom = 130.0
	_prompt_button.pressed.connect(prologue_assign_scribes)
	_prompt_button.visible = false
	_apply_font(_prompt_button)
	game_layer.add_child(_prompt_button)
	_summary = DaySummary.new()
	_summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary.visible = false
	_summary.continue_pressed.connect(continue_from_summary)
	game_layer.add_child(_summary)
	_credits = _make_credits()
	game_layer.add_child(_credits)
	var dlg_layer: CanvasLayer = CanvasLayer.new()
	dlg_layer.layer = 5
	add_child(dlg_layer)
	_dialogue = DialogueBox.new()
	dlg_layer.add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	var menu_layer: CanvasLayer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	_menus = Menus.new()
	menu_layer.add_child(_menus)
	_menus.start_requested.connect(start_new_game)
	_menus.resume_requested.connect(close_pause)
	_menus.quit_to_title_requested.connect(return_to_title)
	_menus.quit_requested.connect(_on_quit)
	_continue_button = Button.new()
	_continue_button.text = tr("UI_MENU_CONTINUE")
	_continue_button.anchor_left = 0.5
	_continue_button.anchor_right = 0.5
	_continue_button.anchor_top = 1.0
	_continue_button.anchor_bottom = 1.0
	_continue_button.offset_left = -110.0
	_continue_button.offset_right = 110.0
	_continue_button.offset_top = -90.0
	_continue_button.offset_bottom = -44.0
	_continue_button.visible = false
	_continue_button.pressed.connect(continue_game)
	_apply_font(_continue_button)
	menu_layer.add_child(_continue_button)


func _make_credits() -> Control:
	var root: ColorRect = ColorRect.new()
	root.color = Color(0.05, 0.04, 0.09, 0.92)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(box)
	var label: Label = _make_label(box)
	label.text = tr("UI_CREDITS")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	var back: Button = Button.new()
	back.text = tr("UI_CREDITS_BACK")
	back.pressed.connect(finish_credits)
	_apply_font(back)
	box.add_child(back)
	root.visible = false
	return root


func _show_title() -> void:
	_phase = Phase.TITLE
	_set_game_ui(false)
	_summary.visible = false
	_credits.visible = false
	_prompt.visible = false
	_prompt_button.visible = false
	_hud.visible = false
	_menus.show_screen(Menus.Screen.TITLE)


func _set_game_ui(on: bool) -> void:
	_hud.visible = on
	_speed_label.visible = on
	_hint.visible = on


func _update_speed_label() -> void:
	if _speed_label != null:
		_speed_label.text = tr("UI_HUD_PAUSED") if _speed == 0 else tr("UI_HUD_SPEED") % _speed


func _make_label(parent: Node) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(l)
	parent.add_child(l)
	return l


func _apply_font(c: Control) -> void:
	var locale: Node = get_node_or_null("/root/Locale")
	if locale != null:
		c.add_theme_font_override("font", locale.call("font_for", &"ui") as Font)


func _t_or(text: String) -> String:
	return text


func _install_ui_strings() -> void:
	var tr_en: Translation = Translation.new()
	tr_en.locale = "en"
	var any: bool = false
	for key: Variant in UI_FALLBACK.keys():
		var k: String = str(key)
		if TranslationServer.translate(k) == StringName(k) or str(TranslationServer.translate(k)) == k:
			tr_en.add_message(k, str(UI_FALLBACK[k]))
			any = true
	if any:
		_fallback_tr = tr_en
		TranslationServer.add_translation(tr_en)


# --- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _phase != Phase.DAY and _phase != Phase.PROLOGUE:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		if _menu_paused:
			if _menus.current_screen() == Menus.Screen.SETTINGS:
				_menus.go_back()
			else:
				close_pause()
		elif _build_menu.visible:
			_build_menu.close()
		elif _controller.mode() == InputController.MODE_IDLE:
			open_pause()
		else:
			return
		get_viewport().set_input_as_handled()
	elif not _menu_paused and _phase == Phase.DAY:
		match key.keycode:
			KEY_0:
				set_speed(0)
			KEY_1:
				set_speed(1)
			KEY_2:
				set_speed(2)
			KEY_3:
				set_speed(3)


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.DAY or _menu_paused or (_dialogue != null and _dialogue.is_playing()):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT \
			and _controller.mode() == InputController.MODE_IDLE:
		_build_menu.visible = true
		_build_menu.open_at(mb.position)


func _on_time_requested(action: StringName) -> void:
	if _phase != Phase.DAY:
		return
	match action:
		&"pause":
			toggle_pause()
		&"speed_up":
			set_speed(mini(maxi(_speed, 1) + 1, SimClock.MAX_SPEED))
		&"speed_down":
			set_speed(maxi(_speed - 1, 1))


func _on_build_option(id: StringName) -> void:
	if _flow == null or _phase != Phase.DAY:
		return
	match id:
		&"route":
			for i: int in ROUTE_PRESETS.size():
				var p: Array = ROUTE_PRESETS[(_preset_route + i) % ROUTE_PRESETS.size()] as Array
				if _flow.pile(str(p[0])) != null and _flow.pile(str(p[1])) != null:
					_preset_route = (_preset_route + i + 1) % ROUTE_PRESETS.size()
					_route_n += 1
					_controller.begin_route("hr%d" % _route_n, str(p[0]), str(p[1]), str(p[2]), 20)
					break
		&"crews":
			for i: int in CREW_PRESETS.size():
				var p: Array = CREW_PRESETS[(_preset_crew + i) % CREW_PRESETS.size()] as Array
				if _flow.pile(str(p[1])) != null:
					_preset_crew = (_preset_crew + i + 1) % CREW_PRESETS.size()
					_controller.request_assign_crews(str(p[0]), str(p[1]), 1)
					break
		&"lekhan":
			_controller.begin_station("lekhan")
		&"gong":
			_controller.select_gong("1")
			_controller.request_ring_gong("1")
		&"measuring_line":
			_controller.begin_measure()
		&"chant":
			_controller.request_chant()


func _on_quit() -> void:
	get_tree().quit()


# --- save / state --------------------------------------------------------------

func _reset_progress() -> void:
	game_state.call("reset")
	_cumulative = 0
	_carry = 0
	_past.clear()


func _set_flag(key: StringName, value: int) -> void:
	game_state.call("set_flag", key, value)


func _flag_int(key: StringName) -> int:
	var v: Variant = game_state.call("get_flag", key, 0)
	if v is int:
		return v as int
	if v is float:
		return roundi(v as float)
	return 0


func _set_chapter(name_: String) -> void:
	game_state.set("chapter", StringName(name_))


func _save_progress(next_day: int) -> void:
	_set_flag(FLAG_DAY, next_day)
	_set_flag(FLAG_CUMULATIVE, _cumulative)
	_set_flag(FLAG_CARRY, _carry)
	_save()


func _save() -> void:
	if persist:
		game_state.call("save_game", SAVE_SLOT)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
