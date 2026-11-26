extends GdUnitTestSuite
## F1 acceptance: the mood and post-processing system (docs/ART.md "Rendering").

const LookScript: GDScript = preload("res://core/look.gd")
const ALL_MOODS: Array[StringName] = [&"dawn", &"day", &"dusk", &"night", &"inferno", &"divine"]
const ALL_PRESETS: Array[StringName] = [&"low", &"medium", &"high"]


func _parent() -> Node3D:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	auto_free(parent)
	return parent


func _env(result: Dictionary) -> Environment:
	return result["environment"] as Environment


func _light(result: Dictionary, key: String) -> DirectionalLight3D:
	return result[key] as DirectionalLight3D


func _count(parent: Node, type_name: String) -> int:
	var total: int = 0
	for child: Node in parent.get_children():
		if child.is_class(type_name) and not child.is_queued_for_deletion():
			total += 1
	return total


func test_moods_and_presets_are_listed() -> void:
	assert_array(Look.MOODS).has_size(6)
	for mood: StringName in ALL_MOODS:
		assert_bool(Look.MOODS.has(mood)).is_true()
		assert_bool(Look.has_mood(mood)).is_true()
	assert_bool(Look.has_mood(&"noon_of_nowhere")).is_false()
	assert_array(Look.PRESETS).has_size(3)
	for preset: StringName in ALL_PRESETS:
		assert_bool(Look.PRESETS.has(preset)).is_true()


func test_apply_returns_the_nodes_under_the_parent() -> void:
	var parent: Node3D = _parent()
	var result: Dictionary = Look.apply(&"dawn", parent, &"high")
	var we: WorldEnvironment = result["world_environment"] as WorldEnvironment
	assert_object(we).is_not_null()
	assert_object(we.get_parent()).is_same(parent)
	assert_object(_env(result)).is_same(we.environment)
	for key: String in ["key", "fill", "rim"]:
		var light: DirectionalLight3D = _light(result, key)
		assert_object(light).is_not_null()
		assert_object(light.get_parent()).is_same(parent)
	assert_str(str(result["mood"])).is_equal("dawn")
	assert_str(str(result["preset"])).is_equal("high")
	assert_str(str(we.name)).is_equal("WorldEnvironment")
	assert_str(str(_light(result, "key").name)).is_equal("Sun")
	assert_str(str(_light(result, "fill").name)).is_equal("Fill")
	assert_str(str(_light(result, "rim").name)).is_equal("BackRim")


func test_apply_twice_replaces_instead_of_stacking() -> void:
	var parent: Node3D = _parent()
	Look.apply(&"day", parent, &"medium")
	var result: Dictionary = Look.apply(&"night", parent, &"medium")
	assert_int(_count(parent, "WorldEnvironment")).is_equal(1)
	assert_int(_count(parent, "DirectionalLight3D")).is_equal(3)
	assert_object(parent.get_node("WorldEnvironment")).is_same(result["world_environment"])
	assert_object(parent.get_node("Sun")).is_same(result["key"])
	assert_str(str(result["mood"])).is_equal("night")


func test_apply_replaces_a_legacy_rig() -> void:
	var parent: Node3D = _parent()
	var old_we: WorldEnvironment = WorldEnvironment.new()
	old_we.name = "WorldEnvironment"
	old_we.environment = Environment.new()
	parent.add_child(old_we)
	var old_sun: DirectionalLight3D = DirectionalLight3D.new()
	old_sun.name = "Sun"
	parent.add_child(old_sun)
	var old_rim: DirectionalLight3D = DirectionalLight3D.new()
	old_rim.name = "BackRim"
	parent.add_child(old_rim)
	var keep: Node3D = Node3D.new()
	keep.name = "LevelRoot"
	parent.add_child(keep)
	var result: Dictionary = Look.apply(&"dusk", parent, &"low")
	assert_int(_count(parent, "WorldEnvironment")).is_equal(1)
	assert_int(_count(parent, "DirectionalLight3D")).is_equal(3)
	assert_object(parent.get_node("WorldEnvironment")).is_same(result["world_environment"])
	assert_object(parent.get_node("Sun")).is_same(result["key"])
	assert_object(parent.get_node("BackRim")).is_same(result["rim"])
	assert_object(parent.get_node_or_null("LevelRoot")).is_same(keep)


func test_every_mood_uses_aces_and_colour_grading() -> void:
	for mood: StringName in ALL_MOODS:
		for preset: StringName in ALL_PRESETS:
			var env: Environment = _env(Look.apply(mood, _parent(), preset))
			assert_int(env.tonemap_mode).is_equal(Environment.TONE_MAPPER_ACES)
			assert_bool(env.adjustment_enabled).is_true()
			assert_bool(env.adjustment_saturation > 0.5 and env.adjustment_saturation < 1.6).is_true()
			assert_bool(env.adjustment_contrast > 0.8 and env.adjustment_contrast < 1.4).is_true()
			assert_bool(env.fog_enabled).is_true()
			assert_int(env.background_mode).is_equal(Environment.BG_SKY)
			assert_object(env.sky).is_not_null()


func test_high_preset_enables_everything() -> void:
	for mood: StringName in ALL_MOODS:
		var env: Environment = _env(Look.apply(mood, _parent(), &"high"))
		assert_bool(env.glow_enabled).is_true()
		assert_bool(env.ssao_enabled).is_true()
		assert_bool(env.ssil_enabled).is_true()
		assert_bool(env.sdfgi_enabled).is_true()
		assert_bool(env.volumetric_fog_enabled).is_true()


func test_medium_preset_has_volumetrics_but_no_gi() -> void:
	for mood: StringName in ALL_MOODS:
		var env: Environment = _env(Look.apply(mood, _parent(), &"medium"))
		assert_bool(env.glow_enabled).is_true()
		assert_bool(env.ssao_enabled).is_true()
		assert_bool(env.volumetric_fog_enabled).is_true()
		assert_bool(env.ssil_enabled).is_false()
		assert_bool(env.sdfgi_enabled).is_false()


func test_low_preset_is_cheap() -> void:
	for mood: StringName in ALL_MOODS:
		var result: Dictionary = Look.apply(mood, _parent(), &"low")
		var env: Environment = _env(result)
		assert_bool(env.glow_enabled).is_false()
		assert_bool(env.ssao_enabled).is_false()
		assert_bool(env.ssil_enabled).is_false()
		assert_bool(env.sdfgi_enabled).is_false()
		assert_bool(env.volumetric_fog_enabled).is_false()
		assert_bool(env.fog_enabled).is_true()
		assert_bool(_light(result, "key").shadow_enabled).is_true()
	assert_float(Look.render_scale(&"low")).is_equal_approx(0.75, 0.001)
	assert_float(Look.render_scale(&"medium")).is_equal_approx(1.0, 0.001)
	assert_float(Look.render_scale(&"high")).is_equal_approx(1.0, 0.001)
	assert_int(Look.shadow_atlas_size(&"low")).is_equal(1024)
	assert_bool(Look.shadow_atlas_size(&"high") > Look.shadow_atlas_size(&"low")).is_true()


func test_glow_is_thresholded_so_only_bright_things_bloom() -> void:
	for mood: StringName in ALL_MOODS:
		var env: Environment = _env(Look.apply(mood, _parent(), &"high"))
		assert_bool(env.glow_hdr_threshold >= 0.8).is_true()
		assert_bool(env.glow_intensity > 0.0).is_true()
		assert_bool(env.glow_bloom <= 0.15).is_true()


func test_light_rig_roles() -> void:
	for mood: StringName in ALL_MOODS:
		var result: Dictionary = Look.apply(mood, _parent(), &"high")
		var key: DirectionalLight3D = _light(result, "key")
		var fill: DirectionalLight3D = _light(result, "fill")
		var rim: DirectionalLight3D = _light(result, "rim")
		assert_bool(key.shadow_enabled).is_true()
		assert_bool(key.is_in_group(&"sun")).is_true()
		assert_bool(fill.shadow_enabled).is_false()
		assert_bool(rim.shadow_enabled).is_false()
		assert_bool(fill.is_in_group(&"sun")).is_false()
		assert_bool(rim.is_in_group(&"sun")).is_false()
		assert_bool(key.light_energy > fill.light_energy).is_true()
		assert_bool(fill.light_energy > 0.0 and rim.light_energy > 0.0).is_true()
		# The key shines downwards; the rim comes from behind the key (opposite horizontal direction).
		var key_dir: Vector3 = -key.basis.z
		var rim_dir: Vector3 = -rim.basis.z
		assert_bool(key_dir.y < -0.15).is_true()
		assert_bool(Vector2(key_dir.x, key_dir.z).dot(Vector2(rim_dir.x, rim_dir.z)) < 0.0).is_true()


func test_sunlit_moods_have_a_warm_key_and_a_cool_fill() -> void:
	for mood: StringName in [&"dawn", &"day", &"dusk"]:
		var result: Dictionary = Look.apply(mood, _parent(), &"medium")
		var key: Color = _light(result, "key").light_color
		var fill: Color = _light(result, "fill").light_color
		assert_bool(key.r > key.b).is_true()
		assert_bool(fill.b > fill.r).is_true()


func test_shadows_are_tinted_never_grey() -> void:
	for mood: StringName in ALL_MOODS:
		var env: Environment = _env(Look.apply(mood, _parent(), &"medium"))
		var ambient: Color = env.ambient_light_color
		assert_int(env.ambient_light_source).is_equal(Environment.AMBIENT_SOURCE_COLOR)
		assert_bool(ambient.s > 0.12).is_true()


func test_night_is_moonlit_and_dimmer_than_day() -> void:
	var day: Dictionary = Look.apply(&"day", _parent(), &"medium")
	var night: Dictionary = Look.apply(&"night", _parent(), &"medium")
	var moon: DirectionalLight3D = _light(night, "key")
	assert_bool(moon.light_color.b > moon.light_color.r).is_true()
	assert_bool(moon.light_energy < _light(day, "key").light_energy).is_true()
	# Night must stay readable: enough ambient to see the playfield.
	assert_bool(_env(night).ambient_light_energy >= 0.3).is_true()


func test_inferno_is_fire_coloured() -> void:
	var result: Dictionary = Look.apply(&"inferno", _parent(), &"high")
	var env: Environment = _env(result)
	assert_bool(env.fog_light_color.r > env.fog_light_color.b * 1.5).is_true()
	var key: Color = _light(result, "key").light_color
	assert_bool(key.r > key.b * 1.5).is_true()
	assert_bool(env.volumetric_fog_emission.r > env.volumetric_fog_emission.b).is_true()


func _sky_colour(env: Environment, parameter: String) -> Color:
	return (env.sky.sky_material as ShaderMaterial).get_shader_parameter(parameter) as Color


func test_inferno_is_a_dark_smoky_night_with_a_glowing_horizon() -> void:
	# B6: the first inferno was a wall of red in which nothing could be read. The sky is now black smoke overhead
	# with the orange of the fires only on the horizon.
	var env: Environment = _env(Look.apply(&"inferno", _parent(), &"high"))
	var top: Color = _sky_colour(env, "top_color")
	var horizon: Color = _sky_colour(env, "horizon_color")
	assert_bool(top.v < 0.08).is_true()
	assert_bool(horizon.v > top.v * 5.0).is_true()
	assert_bool(horizon.r > horizon.g * 1.8 and horizon.g > horizon.b * 1.8).is_true()
	assert_bool((env.sky.sky_material as ShaderMaterial).get_shader_parameter("cloud_cover") as float >= 0.7).is_true()


func test_inferno_stays_legible() -> void:
	var inferno: Dictionary = Look.apply(&"inferno", _parent(), &"high")
	var env: Environment = _env(inferno)
	var dusk: Environment = _env(Look.apply(&"dusk", _parent(), &"high"))
	# Thin, dark haze: the iso camera looks through a constant depth of fog, so it must not paint the frame.
	assert_bool(env.fog_light_color.v * env.fog_light_energy < 0.25).is_true()
	assert_bool(env.fog_density < dusk.fog_density).is_true()
	assert_bool(env.volumetric_fog_density < dusk.volumetric_fog_density).is_true()
	assert_bool(env.volumetric_fog_emission_energy <= 0.01).is_true()
	# The grade does not push the reds further, but keeps deep contrast.
	assert_bool(env.adjustment_saturation <= 1.1).is_true()
	assert_bool(env.adjustment_contrast >= 1.1).is_true()
	assert_bool(env.glow_intensity <= 1.05 and env.glow_bloom <= 0.04).is_true()
	# The key is fire-coloured but not pure red, so stone keeps its own colour under it.
	var key: Color = _light(inferno, "key").light_color
	assert_bool(key.s < 0.7).is_true()
	# Shadows stay dark and coloured.
	assert_bool(env.ambient_light_color.b > env.ambient_light_color.r).is_true()
	assert_bool(env.ambient_light_energy <= 0.35).is_true()


func test_inferno_firelight_comes_from_the_side_and_from_below() -> void:
	var inferno: Dictionary = Look.apply(&"inferno", _parent(), &"medium")
	var key_dir: Vector3 = -_light(inferno, "key").basis.z
	var rim: DirectionalLight3D = _light(inferno, "rim")
	var fill: DirectionalLight3D = _light(inferno, "fill")
	# A low key raking in from the side...
	assert_bool(key_dir.y < -0.15 and key_dir.y > -0.65).is_true()
	# ...a fire-coloured rim that shines UP from the burning streets...
	assert_bool((-rim.basis.z).y > 0.1).is_true()
	assert_bool(rim.light_color.r > rim.light_color.b * 2.0).is_true()
	# ...and a cool fill from high above for contrast.
	assert_bool(fill.light_color.b > fill.light_color.r).is_true()
	assert_bool((-fill.basis.z).y < -0.7).is_true()


func test_night_stone_is_not_a_single_blue() -> void:
	# B6: a neutral-enough moon and ambient, so stone, grass and sand keep different hues at night.
	var night: Dictionary = Look.apply(&"night", _parent(), &"medium")
	assert_bool(_light(night, "key").light_color.s < 0.5).is_true()
	assert_bool(_env(night).ambient_light_color.s < 0.7).is_true()
	assert_bool(_env(night).adjustment_saturation <= 1.1).is_true()


func test_divine_is_bright_and_golden() -> void:
	var divine: Environment = _env(Look.apply(&"divine", _parent(), &"high"))
	var night: Environment = _env(Look.apply(&"night", _parent(), &"high"))
	assert_bool(divine.fog_light_color.r > divine.fog_light_color.b).is_true()
	assert_bool(divine.glow_intensity > night.glow_intensity).is_true()


func test_moods_are_visibly_different() -> void:
	var seen: Array[Color] = []
	for mood: StringName in ALL_MOODS:
		var env: Environment = _env(Look.apply(mood, _parent(), &"medium"))
		for other: Color in seen:
			assert_bool(env.fog_light_color.is_equal_approx(other)).is_false()
		seen.append(env.fog_light_color)


func test_volumetric_light_shafts_come_from_the_key() -> void:
	for mood: StringName in [&"dawn", &"dusk"]:
		var result: Dictionary = Look.apply(mood, _parent(), &"medium")
		assert_bool(_light(result, "key").light_volumetric_fog_energy >= 1.0).is_true()
		assert_bool(_env(result).volumetric_fog_density > 0.0).is_true()
		assert_bool(_env(result).volumetric_fog_anisotropy > 0.3).is_true()


func test_unknown_mood_falls_back_to_day() -> void:
	var result: Dictionary = Look.apply(&"noon_of_nowhere", _parent(), &"medium")
	assert_str(str(result["mood"])).is_equal("day")
	assert_object(result["world_environment"]).is_not_null()


func test_empty_or_unknown_preset_resolves_to_a_valid_one() -> void:
	var result: Dictionary = Look.apply(&"day", _parent())
	assert_bool(ALL_PRESETS.has(result["preset"] as StringName)).is_true()
	assert_bool(ALL_PRESETS.has(Look.resolve_preset(&""))).is_true()
	assert_bool(ALL_PRESETS.has(Look.resolve_preset(&"ultra_mega"))).is_true()
	assert_str(str(Look.resolve_preset(&"low"))).is_equal("low")
	assert_str(str(Look.resolve_preset(&"High"))).is_equal("high")


func test_mood_for_level() -> void:
	assert_str(str(Look.mood_for_level(&"mahendra"))).is_equal("dawn")
	assert_str(str(Look.mood_for_level(&"ocean_leap"))).is_equal("day")
	assert_str(str(Look.mood_for_level(&"lanka_gate"))).is_equal("dusk")
	assert_str(str(Look.mood_for_level(&"lanka_streets"))).is_equal("night")
	assert_str(str(Look.mood_for_level(&"ashoka_vatika"))).is_equal("night")
	assert_str(str(Look.mood_for_level(&"ravana_court"))).is_equal("dusk")
	assert_str(str(Look.mood_for_level(&"lanka_rooftops"))).is_equal("inferno")
	assert_str(str(Look.mood_for_level(&"lanka_unknown_alley"))).is_equal("night")
	assert_str(str(Look.mood_for_level(&"test_tiny"))).is_equal("day")
	for level_id: StringName in [&"mahendra", &"ocean_leap", &"lanka_gate", &"lanka_streets", &"ashoka_vatika",
			&"ravana_court", &"lanka_rooftops", &"test_tiny"]:
		assert_bool(Look.has_mood(Look.mood_for_level(level_id))).is_true()


func test_the_court_interior_is_warmer_than_the_gate() -> void:
	var court: Dictionary = Look.apply_for_level(&"ravana_court", _parent(), &"medium")
	var gate: Dictionary = Look.apply_for_level(&"lanka_gate", _parent(), &"medium")
	assert_str(str(court["mood"])).is_equal("dusk")
	var court_ambient: Color = _env(court).ambient_light_color
	var gate_ambient: Color = _env(gate).ambient_light_color
	assert_bool(court_ambient.r - court_ambient.b > gate_ambient.r - gate_ambient.b).is_true()


func test_script_can_be_loaded_directly() -> void:
	assert_object(LookScript).is_not_null()
	assert_bool(LookScript.can_instantiate()).is_true()
