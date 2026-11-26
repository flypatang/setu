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
const DAY_START_ORTHO: float = 45.0
const FIRST_STONE_POS: Vector3 = Vector3(-6.0, 0.0, 4.0)
const MARKER_RADIUS: float = 6.5
const ROLE_BY_STATION: Dictionary = {"lekhan": "scribe", "quarry": "cutter", "forest": "lumberjack", "ropeworks": "lasher"}

## When false nothing is written to disk (tests).
var persist: bool = true
## When false event and story dialogue is skipped (tests).
var dialogue_enabled: bool = true
## When false a new game skips the guided tutorial (S42).
var tutorial_enabled: bool = true
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
var _station_n: int = 0
var _tutorial_run: bool = false
var _current_action: StringName = &""
var _markers: Dictionary = {}
var _preview: MeshInstance3D = null
var _arrow: MeshInstance3D = null
var _pulse_t: float = 0.0
var _first_stone: Node3D = null
var _floated: bool = false
var _t: float = 0.0

var _stage: Node3D = null
var _world: WorldView = null
var _bridge_view: BridgeView = null
var _crowd: CrowdView = null
var _camera: RtsCamera = null
var _controller: InputController = null
var _menus: Menus = null
var _dialogue: DialogueBox = null
var _hud: Hud = null
var _bar: ActionBar = null
var _tutorial: Tutorial = null
var _build_menu: BuildMenu = null
var _summary: DaySummary = null
var _prompt: Label = null
var _prompt_button: Button = null
var _speed_label: Label = null
var _hint: Label = null
var _continue_button: Button = null
var _credits: Control = null
var _sound_node: Node = null


func _ready() -> void:
	if game_state == null:
		game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		game_state = (load("res://core/game_state.gd") as GDScript).new() as Node
		add_child(game_state)
	if persist:
		game_state.call("load_game", SAVE_SLOT)
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_camera = RtsCamera.new()
	add_child(_camera)
	_controller = InputController.new()
	add_child(_controller)
	_controller.time_requested.connect(_on_time_requested)
	_controller.command_issued.connect(_on_command)
	_controller.mode_changed.connect(_on_mode_changed)
	_controller.link_started.connect(_on_link_started)
	_controller.site_picked.connect(_on_site_picked)
	_build_ui()
	var locale: Node = get_node_or_null("/root/Locale")
	if locale != null and locale.has_signal("language_changed"):
		locale.connect("language_changed", Callable(self, "_on_language_changed"))
	_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_translated_text()


func _on_language_changed(_code: StringName) -> void:
	_refresh_translated_text()


func _physics_process(delta: float) -> void:
	tick_frame(delta)


func _process(delta: float) -> void:
	_t += delta
	_pulse_t += delta
	_update_overlay()
	_tutorial_update()
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


## World x of the bridge head: the origin plus the length built so far today (one metre per section).
func bridge_head_x() -> float:
	var built: int = _flow.bridge.length_m() if _flow != null else 0
	return origin_x() + float(built) * BridgeView.SECTION_LENGTH


func action_bar() -> ActionBar:
	return _bar


func tutorial() -> Tutorial:
	return _tutorial


func hint_label() -> Label:
	return _hint


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
	_tutorial_run = false
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
	_camera.focus_on(Vector3(bridge_head_x(), 0.0, 0.0))
	_camera.set_ortho_size(DAY_START_ORTHO)
	_hud.visible = true
	_hud.update_from(_flow)
	_update_speed_label()
	_set_game_ui(true)
	_sound_watch()
	_sfx(&"day_start")
	_set_chapter("day_%d" % day_n)
	if _tutorial_run and day_n == 1:
		_tutorial.begin(Tutorial.SEQ_DAY)
		_frame_sites()
	elif _tutorial.is_active():
		_tutorial.skip()


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
		_sound_call(&"poll_flow")
	if _phase == Phase.PROLOGUE:
		_check_first_stone()
	elif _phase == Phase.DAY:
		_check_events()
		if _flow.is_over():
			_on_day_over()
	_tutorial_update()
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
	_sound_call(&"unwatch_flow")
	_flow = null
	_tutorial_run = false
	if _tutorial != null and _tutorial.is_active():
		_tutorial.skip()
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
	if tutorial_enabled and _flow != null:
		_tutorial_run = true
		_tutorial.begin(Tutorial.SEQ_PROLOGUE)
		_frame_sites()
		return
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
		if id == "sunset_near":
			_sfx(&"sunset")
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
	_sound_call(&"unwatch_flow")
	_sfx(&"summary_open")
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
	_setup_sites(day)
	_sync_views()


func _clear_stage() -> void:
	for c: Node in _stage.get_children():
		_stage.remove_child(c)
		c.free()
	_world = null
	_bridge_view = null
	_crowd = null
	_first_stone = null
	_markers.clear()
	_preview = null
	_arrow = null
	_controller.set_sites([] as Array[Dictionary])
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
	_sound_watch()
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
	_hint.offset_right = 1500.0
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_refresh_translated_text()
	_bar = ActionBar.new()
	game_layer.add_child(_bar)
	_bar.set_font(_ui_font())
	_bar.action_requested.connect(_on_action)
	_bar.speed_requested.connect(_on_speed_requested)
	_bar.crew_change.connect(_on_crew_change)
	_tutorial = Tutorial.new()
	game_layer.add_child(_tutorial)
	_tutorial.finished.connect(_on_tutorial_finished)
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
	_bar.visible = on
	_bar.enabled = on
	if not on:
		_bar.hide_crew_panel()
		_bar.set_banner("")
		_tutorial.visible = false
	else:
		_tutorial.visible = _tutorial.is_active()


func _update_speed_label() -> void:
	if _bar != null:
		_bar.set_speed_display(_speed)
	if _speed_label != null:
		_speed_label.text = tr("UI_HUD_PAUSED") if _speed == 0 else tr("UI_HUD_SPEED") % _speed


func _make_label(parent: Node) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(l)
	parent.add_child(l)
	return l


func _apply_font(c: Control) -> void:
	var f: Font = _ui_font()
	if f != null:
		c.add_theme_font_override("font", f)


func _ui_font() -> Font:
	var locale: Node = get_node_or_null("/root/Locale")
	if locale != null:
		return locale.call("font_for", &"ui") as Font
	return null


func _refresh_translated_text() -> void:
	if _hint != null:
		_hint.text = tr("UI_HUD_CONTROLS")
	_update_speed_label()


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
		elif _bar.is_crew_panel_open():
			_bar.hide_crew_panel()
		elif _build_menu.visible:
			_build_menu.close()
		elif _controller.mode() == InputController.MODE_IDLE:
			open_pause()
		else:
			return
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.DAY or _menu_paused or (_dialogue != null and _dialogue.is_playing()):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		if _controller.mode() != InputController.MODE_IDLE:
			_controller.cancel()
		elif _bar.is_crew_panel_open():
			_bar.hide_crew_panel()
		else:
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
	_on_action(id)


## An action was chosen from the action bar, a hotkey or the radial menu.
func _on_action(id: StringName) -> void:
	if _flow == null or (_phase != Phase.DAY and _phase != Phase.PROLOGUE) or _menu_paused:
		return
	if _dialogue != null and _dialogue.is_playing():
		return
	_build_menu.close()
	_bar.hide_crew_panel()
	_controller.cancel()
	if id != &"gong" and id != &"chant":
		_sfx(&"action_select")
	_current_action = id
	match id:
		&"route":
			_controller.begin_link()
		&"crews":
			_controller.begin_pick()
		&"lekhan":
			_controller.begin_station("lekhan")
		&"shelter":
			_controller.begin_station("shelter")
		&"measuring_line":
			_controller.begin_measure()
		&"gong":
			_current_action = &""
			_controller.select_gong("1")
			_controller.request_ring_gong("1")
		&"chant":
			_current_action = &""
			_controller.request_chant()
		_:
			_current_action = &""
	_update_banner()


func _on_speed_requested(n: int) -> void:
	if _flow == null:
		return
	if n == 0:
		toggle_pause()
	else:
		set_speed(n)


func _on_mode_changed(mode: String) -> void:
	if mode == InputController.MODE_IDLE:
		_current_action = &""
	_update_banner()


func _on_link_started(_from_id: String) -> void:
	_update_banner()


func _on_site_picked(site_id: String, screen: Vector2) -> void:
	_open_crew_panel(site_id, screen)


func _on_command(cmd: Dictionary, accepted: bool) -> void:
	_tutorial.note_command(cmd, accepted)
	var args: Dictionary = cmd.get("args", {}) as Dictionary
	match str(cmd.get("type", "")):
		"draw_route":
			if accepted:
				_sfx(&"route_drawn")
				_bar.show_toast(tr("UI_TOAST_ROUTE_OK"))
			elif _flow != null and _flow.crews.free_crews() < ceili(float(InputController.LINK_HAULERS) / float(DayFlow.HAULERS_PER_CREW)):
				_bar.show_toast(tr("UI_TOAST_NO_FREE"))
			else:
				_bar.show_toast(tr("UI_TOAST_FAIL"))
		"build_station":
			if accepted:
				_station_n += 1
				var kind: String = str(args.get("kind", ""))
				var at: Array = args.get("pos", [0.0, 0.0]) as Array
				var site: Dictionary = {
					"id": "%s_%d" % [kind, _station_n], "role": str(ROLE_BY_STATION.get(kind, "")),
					"pos": Vector2(_to_f(at[0]), _to_f(at[1])),
				}
				_controller.add_site(site)
				_add_marker(site)
				_sfx(&"station_built")
				_bar.show_toast(tr("UI_TOAST_STATION_OK"))
			elif str(args.get("kind", "")) == "shelter":
				_bar.show_toast(tr("UI_TOAST_SHELTER"))
			else:
				_bar.show_toast(tr("UI_TOAST_FAIL"))
		"place_measuring_line":
			_bar.show_toast(tr("UI_TOAST_MEASURE_OK"))
		"chant_jaya":
			_sfx(&"jaya_chant" if accepted else &"ui_back")
			_bar.show_toast(tr("UI_TOAST_CHANT_OK") if accepted else tr("UI_TOAST_CHANT_WAIT"))
		"ring_gong":
			_sfx(&"gong" if accepted else &"ui_back")
			_bar.show_toast(tr("UI_TOAST_GONG_OK") if accepted else tr("UI_TOAST_GONG_FAIL"))
	_tutorial_update()


func _site_title(id: String) -> String:
	var base: String = id.get_slice("_", 0).to_upper()
	var key: String = "UI_SITE_" + base
	var text: String = tr(key)
	return id if text == key else text


func _open_crew_panel(site_id: String, screen: Vector2) -> void:
	if _flow == null:
		return
	var role: String = _controller.site_role(site_id)
	if role == "":
		return
	_bar.show_crew_panel(site_id, _site_title(site_id), role, _flow.crews.crews_at(StringName(site_id)),
		_flow.crews.free_crews(), screen)


func _on_crew_change(site_id: String, role: String, delta: int) -> void:
	if _flow == null:
		return
	var ok: bool = true
	if delta > 0:
		if _flow.crews.free_crews() <= 0:
			_bar.show_toast(tr("UI_TOAST_NO_FREE"))
			ok = false
		else:
			ok = _controller.request_assign_crews(role, site_id, 1)
			if not ok:
				_bar.show_toast(tr("UI_TOAST_ASSIGN_FAIL"))
	else:
		# The command set has no recorded "remove crew" command, so presentation must not edit crews.
		return
	_sfx(&"crew_assigned" if ok else &"ui_back")
	if ok and _phase == Phase.PROLOGUE and _speed == 0 and delta > 0:
		_prompt.visible = false
		_prompt_button.visible = false
		set_speed(PROLOGUE_SPEED)
	_open_crew_panel(site_id, _bar.get_viewport_rect().get_center())


func _on_tutorial_finished(completed: bool) -> void:
	var last: bool = _tutorial.sequence() == Tutorial.SEQ_DAY
	if not completed or last:
		_tutorial_run = false
	_bar.set_highlight(&"")
	if completed and last:
		_bar.show_toast(tr("TUT_DONE"))
	_update_banner()


func _tutorial_update() -> void:
	if _tutorial == null or _flow == null or (_phase != Phase.DAY and _phase != Phase.PROLOGUE):
		return
	_tutorial.evaluate(_flow, _speed)
	var step: Dictionary = _tutorial.current_step()
	_bar.set_highlight(StringName(str(step.get("button", ""))))


func _update_banner() -> void:
	var mode: String = _controller.mode()
	var text: String = ""
	match mode:
		InputController.MODE_LINK:
			text = tr("UI_BANNER_ROUTE_1") if _controller.link_from() == "" else tr("UI_BANNER_ROUTE_2")
		InputController.MODE_PICK:
			text = tr("UI_BANNER_CREWS")
		InputController.MODE_STATION:
			text = tr("UI_BANNER_STATION")
		InputController.MODE_MEASURE:
			text = tr("UI_BANNER_MEASURE")
	if text != "" and _tutorial.is_active():
		var step: Dictionary = _tutorial.current_step()
		if str(step.get("banner", "")) != "" and str(step.get("action", "")) == String(_current_action):
			text = tr(str(step["banner"]))
	_bar.set_banner(text)
	_bar.set_active(_current_action if mode != InputController.MODE_IDLE else &"")


# --- site markers, hover glow, preview line, tutorial arrow ----------------------

func _setup_sites(day: Dictionary) -> void:
	_station_n = 0
	var sites: Array[Dictionary] = []
	var has_head: bool = false
	for p: Variant in day.get("piles", []) as Array:
		var pd: Dictionary = p as Dictionary
		var at: Array = pd.get("pos", [0.0, 0.0]) as Array
		var id: String = str(pd.get("id", ""))
		has_head = has_head or id == "head"
		sites.append({"id": id, "role": str(pd.get("role", "")), "pos": Vector2(_to_f(at[0]), _to_f(at[1]))})
	if not has_head:
		sites.append({"id": "head", "role": "builder", "pos": Vector2.ZERO})
	_controller.set_sites(sites)
	_markers.clear()
	for site: Dictionary in sites:
		_add_marker(site)
	_preview = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 0.25, 0.7)
	_preview.mesh = box
	_preview.material_override = _glow_material(Color(1.0, 0.85, 0.35, 0.8))
	_preview.visible = false
	_stage.add_child(_preview)
	_arrow = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.8
	cone.height = 3.6
	_arrow.mesh = cone
	_arrow.rotation = Vector3(PI, 0.0, 0.0)
	_arrow.material_override = _glow_material(Color(1.0, 0.8, 0.2, 0.95))
	_arrow.visible = false
	_stage.add_child(_arrow)


func _glow_material(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = color
	return m


func _add_marker(site: Dictionary) -> void:
	var id: String = str(site["id"])
	if _markers.has(id) or _stage == null:
		return
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = MARKER_RADIUS - 0.5
	torus.outer_radius = MARKER_RADIUS + 0.5
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _glow_material(Color(1.0, 0.85, 0.35, 0.0))
	var pos: Vector2 = site["pos"] as Vector2
	ring.position = Vector3(pos.x, 0.3, pos.y)
	ring.visible = false
	_stage.add_child(ring)
	_markers[id] = ring


func _hovered_site() -> String:
	if _flow == null or _controller == null:
		return ""
	return _controller.site_at(_controller.pick_ground(get_viewport().get_mouse_position()))


func _update_overlay() -> void:
	if _markers.is_empty() or _flow == null or (_phase != Phase.DAY and _phase != Phase.PROLOGUE):
		return
	var mode: String = _controller.mode()
	var hover: String = _hovered_site()
	var from_id: String = _controller.link_from()
	var step: Dictionary = _tutorial.current_step()
	var target: String = str(step.get("site", ""))
	var pulse: float = 0.5 + 0.5 * sin(_pulse_t * 5.0)
	for id: String in _markers.keys():
		var ring: MeshInstance3D = _markers[id] as MeshInstance3D
		var a: float = 0.0
		if mode == InputController.MODE_PICK:
			a = 0.35
		elif mode == InputController.MODE_LINK:
			if from_id == "" and _controller.can_start_route(id):
				a = 0.35
			elif from_id != "" and id != from_id:
				a = 0.35
		if id == from_id and from_id != "":
			a = 0.9
		if id == hover:
			a = maxf(a, 0.8)
		if id == target:
			a = maxf(a, 0.45 + 0.45 * pulse)
		ring.visible = a > 0.01
		var mat: StandardMaterial3D = ring.material_override as StandardMaterial3D
		mat.albedo_color = Color(1.0, 0.85, 0.35, a)
		var s: float = 1.0 + (0.08 * pulse if id == hover or id == target else 0.0)
		ring.scale = Vector3(s, 1.0, s)
	if target != "" and _markers.has(target) and _tutorial.is_active():
		var at: Vector3 = (_markers[target] as MeshInstance3D).position
		_arrow.visible = true
		_arrow.position = Vector3(at.x, 5.0 + 1.5 * pulse, at.z)
	else:
		_arrow.visible = false
	_preview.visible = false
	if mode == InputController.MODE_LINK and from_id != "":
		var a2: Vector2 = _controller.site_position(from_id)
		var b2: Vector2 = _controller.pick_ground(get_viewport().get_mouse_position())
		if hover != "":
			b2 = _controller.site_position(hover)
		if not (is_inf(b2.x) or is_inf(b2.y)):
			var d: Vector2 = b2 - a2
			if d.length() > 0.5:
				_preview.visible = true
				_preview.position = Vector3((a2.x + b2.x) * 0.5, 0.6, (a2.y + b2.y) * 0.5)
				_preview.rotation = Vector3(0.0, atan2(-d.y, d.x), 0.0)
				_preview.scale = Vector3(d.length(), 1.0, 1.0)


## Frames every site on screen, clear of the HUD, the tutorial panel and the action bar.
func _frame_sites() -> void:
	var sites: Array[Dictionary] = _controller.sites()
	if sites.is_empty() or not _camera.is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var right: Vector3 = _camera.ground_right()
	var fwd: Vector3 = _camera.ground_forward()
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for s: Dictionary in sites:
		var p: Vector2 = s["pos"] as Vector2
		var w: Vector3 = Vector3(p.x, 0.0, p.y)
		var uv: Vector2 = Vector2(w.dot(right), w.dot(fwd))
		lo = Vector2(minf(lo.x, uv.x), minf(lo.y, uv.y))
		hi = Vector2(maxf(hi.x, uv.x), maxf(hi.y, uv.y))
	var pad: float = MARKER_RADIUS + 6.0
	var usable: Rect2 = Rect2(Vector2(view.x * 0.21, view.y * 0.08), Vector2(view.x * 0.77, view.y * 0.6))
	var ext_u: float = hi.x - lo.x + 2.0 * pad
	var ext_v: float = (hi.y - lo.y) * RtsCamera.PITCH_SIN + 2.0 * pad
	var ppm: float = minf(usable.size.x / ext_u, usable.size.y / ext_v)
	var size: float = clampf(view.y / maxf(ppm, 0.001), RtsCamera.ORTHO_MIN, RtsCamera.ORTHO_MAX)
	ppm = view.y / size
	var centre: Vector2 = (lo + hi) * 0.5
	var off: Vector2 = usable.get_center() - view * 0.5
	var focus: Vector3 = right * (centre.x - off.x / ppm) + fwd * (centre.y + off.y / (ppm * RtsCamera.PITCH_SIN))
	_camera.set_ortho_size(size)
	_camera.position = Vector3(focus.x, 0.0, focus.z)
	_camera.focus_on(focus)


# --- sound ---------------------------------------------------------------------

## The Sound autoload, or a private instance when running without it (tests).
func _sound() -> Node:
	if _sound_node == null:
		_sound_node = get_node_or_null("/root/Sound")
	if _sound_node == null:
		_sound_node = (load("res://core/sound.gd") as GDScript).new() as Node
		add_child(_sound_node)
	return _sound_node


func _sfx(id: StringName) -> void:
	_sound().call("play", id)


func _sound_call(method: StringName) -> void:
	if _sound_node != null:
		_sound_node.call(method)


func _sound_watch() -> void:
	_sound().call("watch_flow", _flow)


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


static func _to_f(v: Variant) -> float:
	if v is float or v is int:
		return v as float
	return str(v).to_float()
