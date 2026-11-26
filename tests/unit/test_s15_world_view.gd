extends GdUnitTestSuite
## Acceptance tests for S15 (render/world_view.gd), DESIGN §9.
## Checks: a node exists for every site in data/days/day_1.json (at the JSON position), the key light takes the
## colour of the Look mood of the time of day (dawn, day, dusk; night on a night-shift day), the night light is dimmer
## than noon, the light always shines downward, and the ocean, shore, Look rig and WorldEnvironment exist.
## Since S40 (art v2) the time of day is the fraction of the working day: 0 = first light, 0.5 = noon, 1 = nightfall.
## Headless and deterministic.

const DAY_1_PATH: String = "res://data/days/day_1.json"
const DAY_3_PATH: String = "res://data/days/day_3.json"
const WORLD_VIEW_SCRIPT: String = "res://render/world_view.gd"


func _load_day_1() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DAY_1_PATH)) as Dictionary


## Day 3 has a night shift (night_from = 6400 of 9600 ticks).
func _load_day_3() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DAY_3_PATH)) as Dictionary


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
	assert_object(view.get_node_or_null("Land")).is_not_null()
	assert_object(view.get_node_or_null("Ocean")).is_not_null()
	assert_object(view.call("get_sun") as DirectionalLight3D).is_not_null()
	assert_object(view.get_node_or_null("Fill")).is_not_null()
	assert_object(view.get_node_or_null("BackRim")).is_not_null()
	assert_object(view.get_node_or_null("WorldEnvironment")).is_not_null()
	assert_object(view.call("get_environment_node") as WorldEnvironment).is_not_null()


func test_sun_colour_matches_look_mood_at_key_times() -> void:
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", _load_day_1())
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D

	view.call("set_time_of_day", 0.05)
	assert_bool(_colour_matches(sun.light_color, Look.mood_settings(&"dawn").key_color)).is_true()

	view.call("set_time_of_day", 0.5)
	assert_bool(_colour_matches(sun.light_color, Look.mood_settings(&"day").key_color)).is_true()

	view.call("set_time_of_day", 0.9)
	assert_bool(_colour_matches(sun.light_color, Look.mood_settings(&"dusk").key_color)).is_true()

	var night_view: Node3D = auto_free(_new_view())
	night_view.call("build_from_day", _load_day_3())
	var moon: DirectionalLight3D = night_view.call("get_sun") as DirectionalLight3D
	night_view.call("set_time_of_day", 0.95)
	assert_bool(_colour_matches(moon.light_color, Look.mood_settings(&"night").key_color)).is_true()


func test_night_light_is_dimmer_than_noon() -> void:
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", _load_day_3())
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D

	view.call("set_time_of_day", 0.5)
	var noon_energy: float = sun.light_energy
	view.call("set_time_of_day", 0.95)
	var night_energy: float = sun.light_energy
	assert_float(night_energy).is_less(noon_energy)
	assert_float(night_energy).is_greater(0.0)


func test_light_is_high_at_noon_and_always_shines_downward() -> void:
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", _load_day_3())
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D

	view.call("set_time_of_day", 0.5)
	var noon_down: Vector3 = -sun.transform.basis.z
	assert_float(noon_down.y).is_less(-0.5)

	# Sun or moon, the key light stays above the horizon all day (no light from below the ground).
	for step: int in range(0, 21):
		view.call("set_time_of_day", float(step) / 20.0)
		var travel: Vector3 = -sun.transform.basis.z
		assert_float(travel.y).is_less(-0.3)


func test_set_time_of_day_works_before_build() -> void:
	var view: Node3D = auto_free(_new_view())
	view.call("set_time_of_day", 0.5)
	assert_object(view.call("get_sun") as DirectionalLight3D).is_not_null()
	assert_object(view.call("get_environment_node") as WorldEnvironment).is_not_null()
