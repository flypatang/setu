extends GdUnitTestSuite
## Acceptance tests for F3 (gen/sky.gd SkyKit and gen/water.gd WaterKit, docs/ART.md "Environment"): a procedural
## sky per mood (gradient, two cloud layers, sun or moon disc from LIGHT0, stars at night, warm horizon, smoky
## orange inferno) and a Gerstner ocean (fresnel to the sky colour, DEEP_OCEAN depth tint, foam, sparkles).

const ALL_MOODS: Array[StringName] = [&"dawn", &"day", &"dusk", &"night", &"inferno", &"divine"]


func _f(value: Variant) -> float:
	return value as float


func _sky_param(mood: StringName, key: String) -> Variant:
	var material: ShaderMaterial = SkyKit.make_sky(mood).sky_material as ShaderMaterial
	return material.get_shader_parameter(key)


func _ocean_material(ocean: MeshInstance3D) -> ShaderMaterial:
	return ocean.material_override as ShaderMaterial


func test_sky_moods_cover_art_direction() -> void:
	assert_array(SkyKit.MOODS).contains_exactly_in_any_order(ALL_MOODS)


func test_make_sky_returns_sky_with_sky_shader_for_every_mood() -> void:
	for mood: StringName in ALL_MOODS:
		var sky: Sky = SkyKit.make_sky(mood)
		assert_object(sky).is_not_null()
		var material: ShaderMaterial = sky.sky_material as ShaderMaterial
		assert_object(material).is_not_null()
		assert_bool(material.shader.code.begins_with("shader_type sky;")).is_true()
		assert_str(str(material.get_meta(&"mood"))).is_equal(str(mood))


func test_sky_shader_has_the_required_features() -> void:
	var code: String = SkyKit.SHADER_CODE
	assert_bool(code.contains("LIGHT0_DIRECTION")).is_true()
	assert_bool(code.contains("LIGHT0_COLOR")).is_true()
	assert_bool(code.contains("TIME")).is_true()
	# Two cloud layers.
	assert_int(code.count("= cloud_layer(")).is_equal(2)
	for uniform_name: String in ["zenith_colour", "horizon_colour", "glow_colour", "cloud_cover", "high_cloud_cover",
			"cloud_speed", "sun_size", "moon_amount", "star_amount"]:
		assert_bool(code.contains("uniform") and code.contains(" " + uniform_name)).is_true()


func test_every_mood_sets_every_tunable_uniform() -> void:
	var keys: Array = SkyKit.mood_params(&"day").keys()
	assert_bool(keys.size() >= 15).is_true()
	for mood: StringName in ALL_MOODS:
		var params: Dictionary[String, Variant] = SkyKit.mood_params(mood)
		assert_array(params.keys()).contains_exactly_in_any_order(keys)
		for key: String in params:
			assert_bool(SkyKit.SHADER_CODE.contains(" " + key)).is_true()


func test_sky_shader_is_shared_between_skies() -> void:
	var a: ShaderMaterial = SkyKit.make_sky(&"day").sky_material as ShaderMaterial
	var b: ShaderMaterial = SkyKit.make_sky(&"night").sky_material as ShaderMaterial
	assert_object(a.shader).is_same(b.shader)
	assert_object(a).is_not_same(b)


func test_stars_and_moon_only_at_night() -> void:
	assert_float(_f(_sky_param(&"night", "star_amount"))).is_equal_approx(1.0, 0.001)
	assert_float(_f(_sky_param(&"night", "moon_amount"))).is_equal_approx(1.0, 0.001)
	assert_float(_f(_sky_param(&"day", "star_amount"))).is_equal_approx(0.0, 0.001)
	assert_float(_f(_sky_param(&"day", "moon_amount"))).is_equal_approx(0.0, 0.001)
	assert_float(_f(_sky_param(&"inferno", "star_amount"))).is_equal_approx(0.0, 0.001)


func test_dawn_and_dusk_have_a_warm_horizon() -> void:
	for mood: StringName in [&"dawn", &"dusk"]:
		var horizon: Color = SkyKit.horizon_colour(mood)
		assert_bool(horizon.r > horizon.b + 0.2).is_true()
		var glow: Color = _sky_param(mood, "glow_colour") as Color
		assert_bool(glow.r > glow.b + 0.3).is_true()
		assert_bool(_f(_sky_param(mood, "glow_strength")) > _f(_sky_param(&"day", "glow_strength"))).is_true()
	var day: Color = SkyKit.horizon_colour(&"day")
	assert_bool(day.b > day.r).is_true()


func test_inferno_is_smoky_orange() -> void:
	var horizon: Color = SkyKit.horizon_colour(&"inferno")
	assert_bool(horizon.r > 0.6 and horizon.r > horizon.g * 1.8 and horizon.g > horizon.b).is_true()
	# Smoke: heavier and darker cloud than a clear day, under a dark zenith.
	assert_bool(_f(_sky_param(&"inferno", "cloud_cover")) > _f(_sky_param(&"day", "cloud_cover"))).is_true()
	assert_bool((_sky_param(&"inferno", "cloud_shade_colour") as Color).get_luminance() < 0.12).is_true()
	assert_bool(SkyKit.zenith_colour(&"inferno").get_luminance() < 0.1).is_true()


func test_night_sky_is_dark_indigo() -> void:
	var zenith: Color = SkyKit.zenith_colour(&"night")
	assert_bool(zenith.get_luminance() < 0.08).is_true()
	assert_bool(zenith.b > zenith.r).is_true()


func test_unknown_mood_falls_back_to_day() -> void:
	assert_str(str(SkyKit.resolve_mood(&"no_such_mood"))).is_equal("day")
	assert_bool(SkyKit.horizon_colour(&"no_such_mood").is_equal_approx(SkyKit.horizon_colour(&"day"))).is_true()
	var material: ShaderMaterial = SkyKit.make_sky(&"no_such_mood").sky_material as ShaderMaterial
	assert_str(str(material.get_meta(&"mood"))).is_equal("day")


func test_apply_mood_changes_an_existing_material() -> void:
	var material: ShaderMaterial = SkyKit.sky_material(&"day")
	SkyKit.apply_mood(material, &"night")
	assert_float(_f(material.get_shader_parameter("star_amount"))).is_equal_approx(1.0, 0.001)
	assert_bool((material.get_shader_parameter("zenith_colour") as Color).is_equal_approx(SkyKit.zenith_colour(&"night"))).is_true()


func test_sky_radiance_is_realtime_and_small() -> void:
	var sky: Sky = SkyKit.make_sky(&"dusk")
	assert_int(sky.process_mode).is_equal(Sky.PROCESS_MODE_REALTIME)
	assert_int(sky.radiance_size).is_equal(Sky.RADIANCE_SIZE_256)


func test_ocean_is_a_subdivided_plane_of_the_requested_size() -> void:
	var ocean: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(40.0, 24.0), &"day")) as MeshInstance3D
	assert_str(str(ocean.name)).is_equal("Ocean")
	var plane: PlaneMesh = ocean.mesh as PlaneMesh
	assert_object(plane).is_not_null()
	assert_bool(plane.size.is_equal_approx(Vector2(40.0, 24.0))).is_true()
	assert_bool(plane.subdivide_width >= 32 and plane.subdivide_depth >= 32).is_true()
	assert_int(ocean.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_bool(ocean.extra_cull_margin >= WaterKit.max_wave_height()).is_true()


func test_ocean_subdivisions_are_capped_for_huge_seas() -> void:
	var ocean: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(600.0, 1400.0), &"day", 3.0)) as MeshInstance3D
	var plane: PlaneMesh = ocean.mesh as PlaneMesh
	assert_int(plane.subdivide_width).is_equal(WaterKit.MAX_SUBDIVISIONS)
	assert_int(plane.subdivide_depth).is_equal(WaterKit.MAX_SUBDIVISIONS)
	assert_float(_f(_ocean_material(ocean).get_shader_parameter("wave_scale"))).is_equal_approx(3.0, 0.001)
	assert_float(_f(_ocean_material(ocean).get_shader_parameter("cell_size"))).is_equal_approx(1400.0 / 256.0, 0.001)


func test_ocean_shader_has_the_required_features() -> void:
	var ocean: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(20.0, 20.0), &"day")) as MeshInstance3D
	var code: String = _ocean_material(ocean).shader.code
	assert_bool(code.contains("shader_type spatial;")).is_true()
	# Four Gerstner waves, in the vertex stage and again per pixel.
	assert_int(WaterKit.WAVES.size()).is_equal(4)
	assert_int(code.count("gerstner(wave_")).is_equal(8)
	assert_bool(code.contains("fresnel")).is_true()
	assert_bool(code.contains("hint_depth_texture")).is_true()
	assert_bool(code.contains("foam")).is_true()
	assert_bool(code.contains("sparkle_mask")).is_true()
	assert_bool(code.contains("void light()")).is_true()
	assert_bool(code.contains("#define DEPTH_EFFECTS")).is_true()


func test_ocean_without_depth_effects_is_a_separate_cheaper_shader() -> void:
	var rich: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(20.0, 20.0), &"day")) as MeshInstance3D
	var cheap: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(20.0, 20.0), &"day", 1.0, false)) as MeshInstance3D
	var again: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(8.0, 8.0), &"night", 1.0, false)) as MeshInstance3D
	assert_bool(_ocean_material(cheap).shader.code.contains("#define DEPTH_EFFECTS")).is_false()
	# Any write to ALPHA would put the material in the transparent pass: the Low variant must stay opaque.
	var cheap_code: String = _ocean_material(cheap).shader.code
	assert_bool(cheap_code.contains("ALPHA =")).is_false()
	assert_bool(cheap_code.contains("ALPHA")).is_false()
	assert_bool(_ocean_material(rich).shader.code.contains("ALPHA = alpha;")).is_true()
	for code: String in [cheap_code, _ocean_material(rich).shader.code]:
		assert_bool(code.contains("/*@")).is_false()
		assert_int(code.count("render_mode")).is_equal(1)
	assert_object(_ocean_material(cheap).shader).is_not_same(_ocean_material(rich).shader)
	assert_object(_ocean_material(cheap).shader).is_same(_ocean_material(again).shader)


func test_ocean_depth_tint_is_deep_ocean_and_reflects_the_mood_sky() -> void:
	var ocean: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(20.0, 20.0), &"day")) as MeshInstance3D
	var material: ShaderMaterial = _ocean_material(ocean)
	assert_bool((material.get_shader_parameter("deep_colour") as Color).is_equal_approx(Palette.DEEP_OCEAN)).is_true()
	for mood: StringName in ALL_MOODS:
		var m: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(20.0, 20.0), mood)) as MeshInstance3D
		var mat: ShaderMaterial = _ocean_material(m)
		assert_bool((mat.get_shader_parameter("sky_horizon_colour") as Color).is_equal_approx(SkyKit.horizon_colour(mood))).is_true()
		assert_bool((mat.get_shader_parameter("sky_zenith_colour") as Color).is_equal_approx(SkyKit.zenith_colour(mood))).is_true()
		var deep: Color = mat.get_shader_parameter("deep_colour") as Color
		var shallow: Color = mat.get_shader_parameter("shallow_colour") as Color
		assert_bool(shallow.get_luminance() > deep.get_luminance()).is_true()
		for key: String in WaterKit.mood_params(mood):
			assert_bool(WaterKit.SHADER_CODE.contains(" " + key)).is_true()


func test_night_ocean_is_darker_than_day() -> void:
	var day: Color = WaterKit.mood_params(&"day")["deep_colour"] as Color
	var night: Color = WaterKit.mood_params(&"night")["deep_colour"] as Color
	assert_bool(night.get_luminance() < day.get_luminance()).is_true()


func test_ocean_waves_match_the_cpu_table() -> void:
	var ocean: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(20.0, 20.0), &"day")) as MeshInstance3D
	var names: Array[String] = ["wave_a", "wave_b", "wave_c", "wave_d"]
	var steepness: float = 0.0
	for i: int in range(4):
		var wave: Vector4 = _ocean_material(ocean).get_shader_parameter(names[i]) as Vector4
		assert_bool(wave.is_equal_approx(WaterKit.WAVES[i])).is_true()
		steepness += wave.z
	# Gerstner crests loop over themselves when the steepness sum reaches 1.
	assert_bool(steepness < 1.0).is_true()


func test_wave_offset_is_deterministic_bounded_and_moves() -> void:
	var limit: float = WaterKit.max_wave_height()
	assert_bool(limit > 0.2 and limit < 1.5).is_true()
	var lowest: float = 1000.0
	var highest: float = -1000.0
	for i: int in range(200):
		var p: Vector2 = Vector2(float(i) * 0.73, float(i) * -0.41)
		var a: Vector3 = WaterKit.wave_offset(p, 2.5)
		assert_bool(a.is_equal_approx(WaterKit.wave_offset(p, 2.5))).is_true()
		assert_bool(absf(a.y) <= limit + 0.0001).is_true()
		assert_float(WaterKit.wave_height(p, 2.5)).is_equal_approx(a.y, 0.0001)
		lowest = minf(lowest, a.y)
		highest = maxf(highest, a.y)
	assert_bool(highest > limit * 0.3 and lowest < -limit * 0.3).is_true()
	assert_bool(absf(WaterKit.wave_height(Vector2(3.0, 4.0), 0.0) - WaterKit.wave_height(Vector2(3.0, 4.0), 0.6)) > 0.01).is_true()


func test_wave_scale_enlarges_the_waves() -> void:
	assert_float(WaterKit.max_wave_height(3.0)).is_equal_approx(WaterKit.max_wave_height() * 3.0, 0.0001)
	var small: Vector3 = WaterKit.wave_offset(Vector2(2.0, 5.0), 1.0, 1.0)
	var big: Vector3 = WaterKit.wave_offset(Vector2(6.0, 15.0), sqrt(3.0), 3.0)
	# Same phase at 3x the distance and sqrt(3)x the time (deep-water dispersion), 3x the size.
	assert_bool(big.is_equal_approx(small * 3.0)).is_true()


func test_shoreline_foam_strip() -> void:
	var foam: MeshInstance3D = auto_free(WaterKit.shoreline_foam(12.0, 2.5, &"dusk")) as MeshInstance3D
	assert_str(str(foam.name)).is_equal("ShorelineFoam")
	assert_bool((foam.mesh as PlaneMesh).size.is_equal_approx(Vector2(12.0, 2.5))).is_true()
	var material: ShaderMaterial = foam.material_override as ShaderMaterial
	assert_bool(material.shader.code.contains("shader_type spatial;")).is_true()
	assert_bool(material.shader.code.contains("ALPHA")).is_true()
	assert_bool((material.get_shader_parameter("foam_colour") as Color).is_equal_approx(
			WaterKit.mood_params(&"dusk")["foam_colour"] as Color)).is_true()
	assert_float(_f(material.get_shader_parameter("strip_length"))).is_equal_approx(12.0, 0.001)


func test_nature_kit_ocean_plane_still_works() -> void:
	var old: MeshInstance3D = auto_free(NatureKit.ocean_plane(Vector2(30.0, 30.0))) as MeshInstance3D
	assert_object(old).is_not_null()
	assert_object(old.mesh as PlaneMesh).is_not_null()
	assert_object(old.material_override as ShaderMaterial).is_not_null()


func test_ocean_waves_are_computed_in_local_space() -> void:
	# No world_vertex_coords: VERTEX in vertex() is ocean-local, as wave_offset() documents.
	for depth_effects: bool in [true, false]:
		var code: String = WaterKit.shader_code(depth_effects)
		assert_bool(code.contains("world_vertex_coords")).is_false()
		assert_bool(code.contains("MODEL_MATRIX * vec4(VERTEX, 1.0)")).is_true()


func test_surface_height_follows_a_moved_ocean() -> void:
	var ocean: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(40.0, 40.0), &"day", 2.0)) as MeshInstance3D
	ocean.position = Vector3(120.0, -3.0, -75.0)
	# Unrotated and unscaled, as the kit requires.
	assert_bool(ocean.transform.basis.is_equal_approx(Basis.IDENTITY)).is_true()
	for i: int in range(20):
		var local: Vector2 = Vector2(float(i) * 1.3 - 9.0, float(i) * -0.7 + 4.0)
		var world: Vector3 = Vector3(120.0 + local.x, 50.0, -75.0 + local.y)
		var expected: float = -3.0 + WaterKit.wave_height(local, 1.75, 2.0)
		assert_float(WaterKit.surface_height_at(ocean, world, 1.75)).is_equal_approx(expected, 0.0001)
	# The same world point on an ocean at the origin has a different phase: the waves travel with the node.
	var at_origin: MeshInstance3D = auto_free(WaterKit.ocean(Vector2(40.0, 40.0), &"day", 2.0)) as MeshInstance3D
	var probe: Vector3 = Vector3(123.0, 0.0, -71.0)
	assert_bool(absf((WaterKit.surface_height_at(ocean, probe, 1.75) + 3.0)
			- WaterKit.surface_height_at(at_origin, probe, 1.75)) > 0.001).is_true()


func test_surface_height_uses_the_global_position_in_the_tree() -> void:
	var parent: Node3D = auto_free(Node3D.new()) as Node3D
	parent.position = Vector3(10.0, 2.0, 5.0)
	var ocean: MeshInstance3D = WaterKit.ocean(Vector2(20.0, 20.0), &"day")
	ocean.position = Vector3(4.0, 0.5, -1.0)
	parent.add_child(ocean)
	add_child(parent)
	var expected: float = 2.5 + WaterKit.wave_height(Vector2(1.0, 2.0), 0.4)
	assert_float(WaterKit.surface_height_at(ocean, Vector3(15.0, 0.0, 6.0), 0.4)).is_equal_approx(expected, 0.0001)


func test_inferno_keeps_a_faint_moon_behind_the_smoke() -> void:
	# Intended: Lanka burns at night, so the disc is a dim moon, never a daytime sun.
	assert_float(_f(_sky_param(&"inferno", "moon_amount"))).is_equal_approx(1.0, 0.001)
	assert_bool(_f(_sky_param(&"inferno", "sun_energy")) < _f(_sky_param(&"night", "sun_energy"))).is_true()
	assert_bool(_f(_sky_param(&"inferno", "sun_halo")) < _f(_sky_param(&"night", "sun_halo"))).is_true()


func test_every_sky_mood_and_ocean_variant_survives_a_frame_in_the_tree() -> void:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(root)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	world.environment = environment
	root.add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	root.add_child(sun)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 6.0, 12.0)
	root.add_child(camera)
	for mood: StringName in ALL_MOODS:
		environment.sky = SkyKit.make_sky(mood)
		var oceans: Array[MeshInstance3D] = []
		for depth_effects: bool in [true, false]:
			var ocean: MeshInstance3D = WaterKit.ocean(Vector2(30.0, 30.0), mood, 1.0, depth_effects)
			ocean.position = Vector3(7.0, 0.0, -3.0) if depth_effects else Vector3(-40.0, 0.0, 0.0)
			root.add_child(ocean)
			oceans.append(ocean)
		var foam: MeshInstance3D = WaterKit.shoreline_foam(10.0, 2.0, mood)
		root.add_child(foam)
		await get_tree().process_frame
		assert_object((environment.sky.sky_material as ShaderMaterial).shader).is_not_null()
		for ocean: MeshInstance3D in oceans:
			assert_bool(ocean.is_inside_tree()).is_true()
			assert_object(_ocean_material(ocean).shader).is_not_null()
			assert_bool(ocean.get_aabb().size.x > 29.0).is_true()
			ocean.queue_free()
		foam.queue_free()
		await get_tree().process_frame
