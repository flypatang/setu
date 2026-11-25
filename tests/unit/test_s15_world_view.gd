extends GdUnitTestSuite
## Acceptance tests for S15 (render/world_view.gd), DESIGN §9.
## Checks: a node exists for every site in data/days/day_1.json (at the JSON position), the sun colour at
## t = 0.25 / 0.5 / 0.75 / 0.95 matches DAWN_PINK / white / SAFFRON / NIGHT_INDIGO, night light is dimmer than noon,
## and the ocean, shore, lights and WorldEnvironment exist. Headless and deterministic.

const DAY_1_PATH: String = "res://data/days/day_1.json"
const WORLD_VIEW_SCRIPT: String = "res://render/world_view.gd"


func _load_day_1() -> Dictionary:
	var file: FileAccess = FileAccess.open(DAY_1_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text) as Dictionary


func _new_view() -> Node3D:
	var script: GDScript = load(WORLD_VIEW_SCRIPT) as GDScript
	var view: Node3D = script.new() as Node3D
	return view


func _colour_matches(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) < 0.01 \
		and absf(actual.g - expected.g) < 0.01 \
		and absf(actual.b - expected.b) < 0.01


func test_site_node_exists_for_every_pile_in_day_1() -> void:
	var day: Dictionary = _load_day_1()
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", day)
	var piles: Array = day["piles"] as Array
	assert_int(piles.size()).is_greater(0)
	for raw: Variant in piles:
		var pile: Dictionary = raw as Dictionary
		var id: String = pile["id"] as String
		var site: Node3D = view.call("get_site", id) as Node3D
		assert_object(site).is_not_null()
		var pos: Array = pile["pos"] as Array
		assert_float(site.position.x).is_equal_approx((pos[0] as float), 0.001)
		assert_float(site.position.z).is_equal_approx((pos[1] as float), 0.001)


func test_world_has_shore_ocean_lights_and_environment() -> void:
	var day: Dictionary = _load_day_1()
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", day)
	assert_object(view.get_node_or_null("Shore")).is_not_null()
	assert_object(view.get_node_or_null("Ocean")).is_not_null()
	assert_object(view.call("get_sun") as DirectionalLight3D).is_not_null()
	assert_object(view.get_node_or_null("RimLight")).is_not_null()
	assert_object(view.get_node_or_null("WorldEnvironment")).is_not_null()


func test_sun_colour_matches_palette_at_key_times() -> void:
	var day: Dictionary = _load_day_1()
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", day)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D

	view.call("set_time_of_day", 0.25)
	assert_bool(_colour_matches(sun.light_color, Palette.DAWN_PINK)).is_true()

	view.call("set_time_of_day", 0.5)
	assert_bool(_colour_matches(sun.light_color, Color.WHITE)).is_true()

	view.call("set_time_of_day", 0.75)
	assert_bool(_colour_matches(sun.light_color, Palette.SAFFRON)).is_true()

	view.call("set_time_of_day", 0.95)
	assert_bool(_colour_matches(sun.light_color, Palette.NIGHT_INDIGO)).is_true()


func test_night_light_is_dimmer_than_noon() -> void:
	var day: Dictionary = _load_day_1()
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", day)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D

	view.call("set_time_of_day", 0.5)
	var noon_energy: float = sun.light_energy
	view.call("set_time_of_day", 0.95)
	var night_energy: float = sun.light_energy
	assert_float(night_energy).is_less(noon_energy)
	assert_float(night_energy).is_greater(0.0)


func test_sun_is_above_horizon_at_noon_and_below_at_night() -> void:
	var day: Dictionary = _load_day_1()
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", day)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D

	view.call("set_time_of_day", 0.5)
	var noon_down: Vector3 = -sun.transform.basis.z
	assert_float(noon_down.y).is_less(-0.5)

	view.call("set_time_of_day", 0.0)
	var midnight_down: Vector3 = -sun.transform.basis.z
	# S15b: the sun elevation is clamped to a small positive minimum, so at midnight the light still travels
	# downward, only at a shallow angle.
	assert_float(midnight_down.y).is_less(0.0)
	assert_float(midnight_down.y).is_greater(-0.2)
