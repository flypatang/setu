extends GdUnitTestSuite
## Acceptance tests for ui/menus.gd (DESIGN §9, S19): title, pause and settings screens.
## Every setting must apply to the engine and persist in user://settings.cfg; labels must switch language.
## The suite restores every setting to its default after each test so the next test starts clean.

const SCRIPT_PATH: String = "res://ui/menus.gd"

var _resume_count: int = 0


func _on_resume() -> void:
	_resume_count += 1


## The Locale autoload (core/locale.gd), reached through the scene root so the suite compiles without autoload names.
func _locale() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Locale") as Node


func _make_menu() -> Menus:
	var script: GDScript = load(SCRIPT_PATH) as GDScript
	var menu: Menus = auto_free(script.new() as Menus) as Menus
	add_child(menu)
	return menu


func _button(menu: Menus, node_name: String) -> Button:
	return menu.find_child(node_name, true, false) as Button


func _label(menu: Menus, node_name: String) -> Label:
	return menu.find_child(node_name, true, false) as Label


func after_test() -> void:
	_locale().call("set_language", &"en")
	_resume_count = 0
	# Restore defaults through the public API so the engine state and the saved file agree again.
	var probe: Menus = _make_menu()
	probe.set_option(&"fps_cap", 60)
	probe.set_option(&"graphics", "high")
	probe.set_option(&"vsync", true)
	probe.set_option(&"fullscreen", false)
	probe.set_option(&"shloka_cards", "on")
	probe.set_option(&"volume_master", 1.0)
	probe.set_option(&"volume_music", 1.0)
	probe.set_option(&"volume_sfx", 1.0)
	probe.hide_menus()


# --- Frame rate cap -----------------------------------------------------------

func test_fps_cap_applies_to_engine() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"fps_cap", 30)).is_true()
	assert_int(Engine.max_fps).is_equal(30)
	assert_bool(menu.set_option(&"fps_cap", 0)).is_true()
	assert_int(Engine.max_fps).is_equal(0)


func test_fps_cap_rejects_other_values() -> void:
	var menu: Menus = _make_menu()
	menu.set_option(&"fps_cap", 60)
	assert_bool(menu.set_option(&"fps_cap", 45)).is_false()
	assert_int(menu.get_option(&"fps_cap") as int).is_equal(60)
	assert_int(Engine.max_fps).is_equal(60)


func test_fps_cap_persists_and_reapplies_on_start() -> void:
	var menu: Menus = _make_menu()
	menu.set_option(&"fps_cap", 30)
	assert_int(Menus.saved_option(&"fps_cap") as int).is_equal(30)
	Engine.max_fps = 0
	var second: Menus = _make_menu()
	assert_int(second.get_option(&"fps_cap") as int).is_equal(30)
	assert_int(Engine.max_fps).is_equal(30)


# --- Graphics presets ---------------------------------------------------------

func test_graphics_low_applies_scale_shadows_and_crowd_half() -> void:
	var menu: Menus = _make_menu()
	var light: DirectionalLight3D = auto_free(DirectionalLight3D.new()) as DirectionalLight3D
	add_child(light)
	light.add_to_group(&"sun")
	light.shadow_enabled = true
	menu.set_option(&"graphics", "low")
	assert_float(get_viewport().scaling_3d_scale).is_equal_approx(0.75, 0.001)
	assert_bool(light.shadow_enabled).is_false()
	assert_int(Menus.crowd_limit(100)).is_equal(50)


func test_graphics_high_restores_scale_shadows_and_full_crowd() -> void:
	var menu: Menus = _make_menu()
	var light: DirectionalLight3D = auto_free(DirectionalLight3D.new()) as DirectionalLight3D
	add_child(light)
	light.add_to_group(&"sun")
	menu.set_option(&"graphics", "low")
	menu.set_option(&"graphics", "high")
	assert_float(get_viewport().scaling_3d_scale).is_equal_approx(1.0, 0.001)
	assert_bool(light.shadow_enabled).is_true()
	assert_int(Menus.crowd_limit(100)).is_equal(100)


func test_graphics_preset_persists_and_is_readable_by_other_views() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"graphics", "medium")).is_true()
	assert_str(Menus.graphics_preset()).is_equal("medium")
	var second: Menus = _make_menu()
	assert_str(second.get_option(&"graphics") as String).is_equal("medium")


func test_graphics_rejects_unknown_preset() -> void:
	var menu: Menus = _make_menu()
	menu.set_option(&"graphics", "high")
	assert_bool(menu.set_option(&"graphics", "ultra")).is_false()
	assert_str(menu.get_option(&"graphics") as String).is_equal("high")


# --- Display -------------------------------------------------------------------

func test_vsync_persists() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"vsync", false)).is_true()
	assert_bool(Menus.saved_option(&"vsync") as bool).is_false()
	menu.set_option(&"vsync", true)
	assert_bool(Menus.saved_option(&"vsync") as bool).is_true()


func test_fullscreen_persists() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"fullscreen", true)).is_true()
	assert_bool(Menus.saved_option(&"fullscreen") as bool).is_true()
	var second: Menus = _make_menu()
	assert_bool(second.get_option(&"fullscreen") as bool).is_true()
	menu.set_option(&"fullscreen", false)
	assert_bool(Menus.saved_option(&"fullscreen") as bool).is_false()


# --- Audio ---------------------------------------------------------------------

func test_volume_creates_missing_buses_and_applies() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"volume_music", 0.5)).is_true()
	assert_bool(menu.set_option(&"volume_sfx", 0.25)).is_true()
	var music: int = AudioServer.get_bus_index("Music")
	var sfx: int = AudioServer.get_bus_index("SFX")
	assert_int(music).is_greater_equal(0)
	assert_int(sfx).is_greater_equal(0)
	assert_float(AudioServer.get_bus_volume_db(music)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(AudioServer.get_bus_volume_db(sfx)).is_equal_approx(linear_to_db(0.25), 0.01)


func test_master_volume_applies_to_master_bus() -> void:
	var menu: Menus = _make_menu()
	menu.set_option(&"volume_master", 0.5)
	assert_float(AudioServer.get_bus_volume_db(0)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(Menus.saved_option(&"volume_master") as float).is_equal_approx(0.5, 0.001)


func test_volume_rejects_out_of_range() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"volume_music", 1.5)).is_false()
	assert_bool(menu.set_option(&"volume_music", -0.1)).is_false()


# --- Shloka cards --------------------------------------------------------------

func test_shloka_cards_persist_and_reject_unknown() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"shloka_cards", "short")).is_true()
	assert_str(Menus.shloka_cards_mode()).is_equal("short")
	assert_bool(menu.set_option(&"shloka_cards", "loud")).is_false()
	assert_str(menu.get_option(&"shloka_cards") as String).is_equal("short")


func test_unknown_option_is_rejected() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"no_such_option", 1)).is_false()


# --- Language and labels -------------------------------------------------------

func test_language_switch_updates_labels() -> void:
	var menu: Menus = _make_menu()
	assert_str(_button(menu, "BeginButton").text).is_equal("Begin")
	assert_bool(menu.set_option(&"language", "hi")).is_true()
	assert_str(str(_locale().call("language"))).is_equal("hi")
	assert_str(_button(menu, "BeginButton").text).is_equal("आरंभ करें")
	assert_str(_label(menu, "LanguageLabel").text).is_equal("भाषा")
	menu.set_option(&"language", "en")
	assert_str(_button(menu, "BeginButton").text).is_equal("Begin")
	assert_str(_label(menu, "LanguageLabel").text).is_equal("Language")


func test_labels_refresh_on_locale_signal() -> void:
	var menu: Menus = _make_menu()
	_locale().call("set_language", &"hi")
	assert_str(_button(menu, "ResumeButton").text).is_equal("जारी रखें")
	_locale().call("set_language", &"en")
	assert_str(_button(menu, "ResumeButton").text).is_equal("Resume")


func test_language_rejects_unsupported_code() -> void:
	var menu: Menus = _make_menu()
	assert_bool(menu.set_option(&"language", "fr")).is_false()
	assert_str(str(_locale().call("language"))).is_equal("en")


# --- Screens -------------------------------------------------------------------

func test_title_screen_is_default_and_buttons_exist() -> void:
	var menu: Menus = _make_menu()
	assert_int(menu.current_screen()).is_equal(Menus.Screen.TITLE)
	assert_bool(menu.visible).is_true()
	assert_object(_button(menu, "BeginButton")).is_not_null()
	assert_object(_button(menu, "TitleSettingsButton")).is_not_null()
	assert_object(_button(menu, "QuitButton")).is_not_null()


func test_pause_screen_resume_emits_signal() -> void:
	var menu: Menus = _make_menu()
	menu.resume_requested.connect(_on_resume)
	menu.show_screen(Menus.Screen.PAUSE)
	assert_int(menu.current_screen()).is_equal(Menus.Screen.PAUSE)
	_button(menu, "ResumeButton").pressed.emit()
	assert_int(_resume_count).is_equal(1)


func test_settings_back_returns_to_previous_screen() -> void:
	var menu: Menus = _make_menu()
	menu.show_screen(Menus.Screen.PAUSE)
	_button(menu, "PauseSettingsButton").pressed.emit()
	assert_int(menu.current_screen()).is_equal(Menus.Screen.SETTINGS)
	_button(menu, "BackButton").pressed.emit()
	assert_int(menu.current_screen()).is_equal(Menus.Screen.PAUSE)


func test_hide_menus_hides_the_root() -> void:
	var menu: Menus = _make_menu()
	menu.show_screen(Menus.Screen.PAUSE)
	menu.hide_menus()
	assert_bool(menu.visible).is_false()


func test_start_button_emits_start_requested() -> void:
	var menu: Menus = _make_menu()
	var counter: Array[int] = [0]
	menu.start_requested.connect(func() -> void: counter[0] += 1)
	_button(menu, "BeginButton").pressed.emit()
	assert_int(counter[0]).is_equal(1)
