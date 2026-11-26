extends Node
## Sound autoload (AU2): pooled SFX players on the "SFX" bus, an event bank of Kenney (CC0) .ogg files with
## variation and pitch jitter, a low ambient wave bed, and DayFlow/Bridge hooks. Volumes come from the Menus
## settings through the Master/Music/SFX buses, so nothing here sets bus levels.
## Register as autoload "Sound" in project.godot. Audio never touches the simulation or its RNG.

const IMPACT: String = "res://assets/sfx/kenney/kenney_impact-sounds/"
const UI: String = "res://assets/sfx/kenney/kenney_interface-sounds/"
const RPG: String = "res://assets/sfx/kenney/kenney_rpg-audio/"
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const POOL_SIZE: int = 12
const MIN_REPEAT_MS: int = 40
const AMBIENT_MIN_S: float = 3.0
const AMBIENT_MAX_S: float = 8.0
const INSCRIBE_POLL_EVERY: int = 20

## id -> {dir, names (file stems), db, lo, hi (pitch range), also (layered ids)}.
const _SPECS: Dictionary = {
	&"ui_click": {"dir": UI, "names": ["click_001", "click_002", "click_003", "click_004", "click_005"], "db": -8.0, "lo": 0.95, "hi": 1.05},
	&"ui_hover": {"dir": UI, "names": ["tick_001", "tick_002", "tick_004"], "db": -18.0, "lo": 0.92, "hi": 1.08},
	&"ui_confirm": {"dir": UI, "names": ["confirmation_001", "confirmation_002", "confirmation_003", "confirmation_004"], "db": -8.0, "lo": 0.97, "hi": 1.03},
	&"ui_back": {"dir": UI, "names": ["back_001", "back_002", "back_003", "back_004"], "db": -9.0, "lo": 0.95, "hi": 1.05},
	&"action_select": {"dir": UI, "names": ["select_001", "select_002", "select_003", "select_004"], "db": -8.0, "lo": 0.96, "hi": 1.04},
	&"route_drawn": {"dir": UI, "names": ["drop_001", "drop_002", "drop_003", "drop_004"], "db": -7.0, "lo": 0.95, "hi": 1.05},
	&"crew_assigned": {"dir": UI, "names": ["maximize_001", "maximize_002", "maximize_003", "maximize_004", "maximize_005"], "db": -9.0, "lo": 0.95, "hi": 1.05},
	&"station_built": {"dir": IMPACT, "names": ["impactPlank_medium_000", "impactPlank_medium_001", "impactPlank_medium_002", "impactPlank_medium_003", "impactPlank_medium_004"], "db": -4.0, "lo": 0.9, "hi": 1.05},
	&"stone_inscribed": {"dir": UI, "names": ["scratch_001", "scratch_002", "scratch_003", "scratch_004", "scratch_005", "pluck_001", "pluck_002"], "db": -10.0, "lo": 0.9, "hi": 1.15},
	&"stone_placed": {"dir": IMPACT, "names": ["impactMining_000", "impactMining_001", "impactMining_002", "impactMining_003", "impactMining_004", "impactPlate_heavy_000", "impactPlate_heavy_001", "impactPlate_heavy_002"], "db": -5.0, "lo": 0.8, "hi": 1.0},
	&"plank_laid": {"dir": IMPACT, "names": ["impactWood_light_000", "impactWood_light_001", "impactWood_light_002", "impactWood_light_003", "impactWood_light_004", "impactWood_medium_000", "impactWood_medium_001"], "db": -7.0, "lo": 0.9, "hi": 1.1},
	&"section_complete": {"dir": UI, "names": ["confirmation_001", "confirmation_002", "confirmation_003", "confirmation_004"], "db": -3.0, "lo": 0.9, "hi": 1.0, "also": [&"stone_placed"]},
	&"stone_sank": {"dir": IMPACT, "names": ["impactSoft_heavy_000", "impactSoft_heavy_001", "impactSoft_heavy_002", "impactSoft_heavy_003", "impactSoft_heavy_004"], "db": -5.0, "lo": 0.7, "hi": 0.9},
	&"section_broken": {"dir": IMPACT, "names": ["impactWood_heavy_000", "impactWood_heavy_001", "impactWood_heavy_002", "impactWood_heavy_003", "impactWood_heavy_004"], "db": -2.0, "lo": 0.85, "hi": 1.05},
	&"gong": {"dir": IMPACT, "names": ["impactBell_heavy_000", "impactBell_heavy_001", "impactBell_heavy_002", "impactBell_heavy_003", "impactBell_heavy_004"], "db": -2.0, "lo": 0.9, "hi": 1.0},
	&"jaya_chant": {"dir": IMPACT, "names": ["impactBell_heavy_002", "impactBell_heavy_003"], "db": -4.0, "lo": 1.15, "hi": 1.25, "also": [&"ui_confirm", &"section_complete"]},
	&"day_start": {"dir": UI, "names": ["bong_001"], "db": -5.0, "lo": 1.0, "hi": 1.05, "also": [&"ui_confirm"]},
	&"sunset": {"dir": UI, "names": ["bong_001"], "db": -4.0, "lo": 0.6, "hi": 0.7},
	&"summary_open": {"dir": RPG, "names": ["bookOpen"], "db": -6.0, "lo": 0.95, "hi": 1.05},
	&"dialogue_advance": {"dir": RPG, "names": ["bookFlip1", "bookFlip2", "bookFlip3"], "db": -12.0, "lo": 0.95, "hi": 1.1},
	&"shloka_open": {"dir": IMPACT, "names": ["impactGlass_medium_000", "impactGlass_medium_001", "impactGlass_medium_002"], "db": -8.0, "lo": 0.9, "hi": 1.0, "also": [&"jaya_chant"]},
	&"wave": {"dir": IMPACT, "names": ["impactSoft_medium_000", "impactSoft_medium_001", "impactSoft_medium_002", "impactSoft_medium_003", "impactSoft_medium_004"], "db": -24.0, "lo": 0.55, "hi": 0.85},
}

## Optional recorder: called with the event id for every play() request (tests).
var hook: Callable = Callable()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _streams: Dictionary = {}
var _last_ms: Dictionary = {}
var _ambient_on: bool = false
var _ambient_left: float = 2.0

var _flow: DayFlow = null
var _stone_seen: int = 0
var _timber_seen: int = 0
var _lekhan: Dictionary = {}
var _poll_n: int = 0


func _init() -> void:
	_rng.randomize()
	for bus: String in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		_ensure_bus(bus)


func _ready() -> void:
	for i: int in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	if _ambient_on:
		step_ambient(delta)


# --- bank ------------------------------------------------------------------------

func has_event(id: StringName) -> bool:
	return _SPECS.has(id)


func bank_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in _SPECS.keys():
		out.append(k as StringName)
	return out


func bank_files(id: StringName) -> Array[String]:
	var out: Array[String] = []
	if not _SPECS.has(id):
		return out
	var spec: Dictionary = _SPECS[id] as Dictionary
	for n: Variant in spec["names"] as Array:
		out.append("%s%s.ogg" % [str(spec["dir"]), str(n)])
	return out


func seed_rng(s: int) -> void:
	_rng.seed = s


## Plays one event (with variation, pitch jitter and any layered events). Returns false for unknown ids.
func play(id: StringName, volume_offset_db: float = 0.0) -> bool:
	if not _SPECS.has(id):
		return false
	if hook.is_valid():
		hook.call(id)
	_play_layers(id, volume_offset_db, 0)
	return true


func _play_layers(id: StringName, offset_db: float, depth: int) -> void:
	var spec: Dictionary = _SPECS[id] as Dictionary
	_start(id, spec, offset_db)
	if depth > 0:
		return
	for other: Variant in spec.get("also", []) as Array:
		var oid: StringName = other as StringName
		if _SPECS.has(oid):
			_start(oid, _SPECS[oid] as Dictionary, offset_db - 3.0)


func _start(id: StringName, spec: Dictionary, offset_db: float) -> void:
	if _players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var last: int = _last_ms.get(id, -MIN_REPEAT_MS) as int
	if now - last < MIN_REPEAT_MS:
		return
	_last_ms[id] = now
	var files: Array[String] = bank_files(id)
	var path: String = files[_rng.randi_range(0, files.size() - 1)]
	var stream: AudioStream = _stream(path)
	if stream == null:
		return
	var player: AudioStreamPlayer = _free_player()
	player.stream = stream
	player.volume_db = (spec["db"] as float) + offset_db
	player.pitch_scale = _rng.randf_range(spec["lo"] as float, spec["hi"] as float)
	player.play()


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[path] as AudioStream


func _free_player() -> AudioStreamPlayer:
	for i: int in _players.size():
		var idx: int = (_next_player + i) % _players.size()
		if not _players[idx].playing:
			_next_player = (idx + 1) % _players.size()
			return _players[idx]
	var stolen: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return stolen


# --- ambient ---------------------------------------------------------------------

func start_ambient() -> void:
	_ambient_on = true
	_ambient_left = _rng.randf_range(0.5, AMBIENT_MIN_S)


func stop_ambient() -> void:
	_ambient_on = false


func is_ambient_on() -> bool:
	return _ambient_on


## Advances the wave bed by delta seconds; plays a soft randomised wave when due.
func step_ambient(delta: float) -> void:
	if not _ambient_on:
		return
	_ambient_left -= delta
	while _ambient_left <= 0.0:
		play(&"wave", _rng.randf_range(-3.0, 1.0))
		_ambient_left += _rng.randf_range(AMBIENT_MIN_S, AMBIENT_MAX_S)
		if delta >= AMBIENT_MAX_S and _ambient_left <= 0.0:
			_ambient_left = 0.1


# --- DayFlow hooks ---------------------------------------------------------------

## Follows a running day: bridge signals plus polled stone/timber/inscription progress. Starts the wave bed.
func watch_flow(flow: DayFlow) -> void:
	unwatch_flow()
	_flow = flow
	if _flow == null:
		return
	_flow.bridge.section_completed.connect(_on_section_completed)
	_flow.bridge.stone_sank.connect(_on_stone_sank)
	_flow.bridge.section_broken.connect(_on_section_broken)
	var totals: Vector2i = _bridge_totals()
	_stone_seen = totals.x
	_timber_seen = totals.y
	_poll_n = 0
	_connect_lekhan()
	start_ambient()


func unwatch_flow() -> void:
	if _flow != null and _flow.bridge != null:
		if _flow.bridge.section_completed.is_connected(_on_section_completed):
			_flow.bridge.section_completed.disconnect(_on_section_completed)
		if _flow.bridge.stone_sank.is_connected(_on_stone_sank):
			_flow.bridge.stone_sank.disconnect(_on_stone_sank)
		if _flow.bridge.section_broken.is_connected(_on_section_broken):
			_flow.bridge.section_broken.disconnect(_on_section_broken)
	for id: Variant in _lekhan.keys():
		var pile: Stockpile = (_lekhan[id] as Dictionary)["pile"] as Stockpile
		if pile.changed.is_connected(_on_lekhan_changed.bind(id as String)):
			pile.changed.disconnect(_on_lekhan_changed.bind(id as String))
	_lekhan.clear()
	_flow = null
	stop_ambient()


## Call after the flow advanced: plays stone_placed / plank_laid / stone_inscribed for new progress.
func poll_flow() -> void:
	if _flow == null:
		return
	var totals: Vector2i = _bridge_totals()
	if totals.x > _stone_seen:
		play(&"stone_placed")
	if totals.y > _timber_seen:
		play(&"plank_laid")
	_stone_seen = totals.x
	_timber_seen = totals.y
	_poll_n += 1
	if _poll_n % INSCRIBE_POLL_EVERY == 0:
		_connect_lekhan()


func _bridge_totals() -> Vector2i:
	var stone: int = 0
	var timber: int = 0
	var b: Bridge = _flow.bridge
	for i: int in b.section_count():
		var s: Bridge.Section = b.section(i)
		stone += s.stone_in
		timber += s.timber_in
		if not s.complete and s.stone_in == 0 and s.timber_in == 0:
			break
	return Vector2i(stone, timber)


## Follows every Lekhan pile (stations can be built mid-day) to hear stones being inscribed.
func _connect_lekhan() -> void:
	var piles: Dictionary = _flow.snapshot().get("piles", {}) as Dictionary
	for id: Variant in piles.keys():
		var key: String = str(id)
		if key.begins_with("lekhan") and not _lekhan.has(key):
			var pile: Stockpile = _flow.pile(key)
			if pile == null:
				continue
			_lekhan[key] = {"pile": pile, "count": pile.count("inscribed_stone")}
			pile.changed.connect(_on_lekhan_changed.bind(key))


func _on_lekhan_changed(kind: String, new_count: int, key: String) -> void:
	if kind != "inscribed_stone" or not _lekhan.has(key):
		return
	var rec: Dictionary = _lekhan[key] as Dictionary
	if new_count > (rec["count"] as int):
		play(&"stone_inscribed")
	rec["count"] = new_count


func _on_section_completed(_index: int) -> void:
	play(&"section_complete")


func _on_stone_sank(_count: int) -> void:
	play(&"stone_sank")


func _on_section_broken(_index: int) -> void:
	play(&"section_broken")


# --- buses -----------------------------------------------------------------------

static func _ensure_bus(bus: String) -> int:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus)
	if bus != BUS_MASTER:
		AudioServer.set_bus_send(index, BUS_MASTER)
	return index
