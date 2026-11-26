extends GdUnitTestSuite
## Acceptance tests for S40 (render/world_view.gd, world art v2 per docs/ART.md).
## Checks: the lights and environment are a Look rig with a SkyKit sky; the time of day picks and blends the Look
## moods (dawn at tick 600, day at noon, dusk at tick 8800, night on the night-shift day 3 at tick 9000) without
## rebuilding the rig; the sea is WaterKit.ocean tiles that reach the whole bridge line, with a shoreline foam strip;
## the terrain is one Materials mesh that is flat over the works, slopes under the sea and blends sand into grass;
## no world mesh uses the old flat toon material; the sites, the vanara camp and Rama's pavilion are built from
## Materials kinds (carved pillars, gold kalasha, timber stacks, rope-walk, cut rock face); the scatter uses
## NatureKit v2 trees only near the works and light trees beyond; and the world stays inside its triangle budgets.
## Headless and deterministic.

const WORLD_VIEW_SCRIPT: String = "res://render/world_view.gd"
const DAY_TICKS: float = 9600.0
const SCENERY_BUDGET: int = 150000
## Everything that is drawn all the time: terrain, sites and scenery (the ocean tiles are culled per tile).
const LAND_BUDGET: int = 300000
const HERO_TREE_MAX: int = 24
const LIGHT_TREE_MAX_TRIS: int = 400


func _load_day(day: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/days/day_%d.json" % day)) as Dictionary


func _built_view(day: int = 1) -> Node3D:
	var script: GDScript = load(WORLD_VIEW_SCRIPT) as GDScript
	var view: Node3D = auto_free(script.new() as Node3D)
	view.call("build_from_day", _load_day(day))
	return view


func _mood(view: Node3D, tick: float) -> StringName:
	return view.call("mood_at", tick / DAY_TICKS) as StringName


func _tris(mesh: Mesh) -> int:
	return floori(float(mesh.get_faces().size()) / 3.0)


func _surface_names(mesh: Mesh) -> Array[String]:
	var names: Array[String] = []
	for i: int in range(mesh.get_surface_count()):
		names.append((mesh as ArrayMesh).surface_get_name(i))
	return names


func _count_children(node: Node, part: String) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if String(child.name).contains(part):
			count += 1
	return count


func _scatter(view: Node3D, kind: String) -> PackedVector3Array:
	return view.call("get_scatter_points", kind) as PackedVector3Array


# --- light, sky and time of day ---------------------------------------------------------------------------------

func test_lighting_is_a_look_rig_with_a_skykit_sky() -> void:
	var view: Node3D = _built_view()
	var env_node: WorldEnvironment = view.call("get_environment_node") as WorldEnvironment
	assert_object(env_node).is_not_null()
	var environment: Environment = env_node.environment
	assert_int(environment.tonemap_mode).is_equal(Environment.TONE_MAPPER_ACES)
	assert_int(environment.background_mode).is_equal(Environment.BG_SKY)
	var sky_material: ShaderMaterial = environment.sky.sky_material as ShaderMaterial
	assert_object(sky_material).is_not_null()
	assert_object(sky_material.shader).is_same(SkyKit.shader())
	assert_object(view.call("get_sky_material")).is_same(sky_material)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D
	assert_bool(sun.is_in_group(Look.SUN_GROUP)).is_true()
	assert_bool(sun.shadow_enabled).is_true()
	for light_name: String in ["Fill", "BackRim"]:
		var light: DirectionalLight3D = view.get_node_or_null(light_name) as DirectionalLight3D
		assert_object(light).is_not_null()
		assert_bool(light.shadow_enabled).is_false()
	assert_object(view.get_node_or_null("RimLight")).is_null()


func test_mood_follows_the_working_day() -> void:
	var view: Node3D = _built_view(1)
	assert_str(String(_mood(view, 600.0))).is_equal("dawn")
	assert_str(String(_mood(view, 4800.0))).is_equal("day")
	assert_str(String(_mood(view, 8800.0))).is_equal("dusk")


func test_night_falls_at_night_from_on_a_night_shift_day() -> void:
	var view: Node3D = _built_view(3)
	assert_str(String(_mood(view, 600.0))).is_equal("dawn")
	assert_str(String(_mood(view, 3000.0))).is_equal("day")
	assert_str(String(_mood(view, 9000.0))).is_equal("night")
	# Dusk comes just before the night shift starts (night_from = 6400).
	assert_str(String(_mood(view, 5800.0))).is_equal("dusk")
	view.call("set_time_of_day", 9000.0 / DAY_TICKS)
	for raw: Variant in view.call("get_torches") as Array:
		assert_float((raw as OmniLight3D).light_energy).is_greater(1.0)


func test_moods_blend_between_thresholds() -> void:
	var view: Node3D = _built_view(1)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D
	var mix: Array = view.call("mood_mix_at", 0.8) as Array
	assert_str(String(mix[0] as StringName)).is_equal("day")
	assert_str(String(mix[1] as StringName)).is_equal("dusk")
	assert_float(mix[2] as float).is_between(0.05, 0.95)
	var day_colour: Color = Look.mood_settings(&"day").key_color
	var dusk_colour: Color = Look.mood_settings(&"dusk").key_color
	view.call("set_time_of_day", 0.8)
	# Between the two moods: green falls from the day's value toward the dusk's.
	assert_float(sun.light_color.g).is_less(day_colour.g - 0.005)
	assert_float(sun.light_color.g).is_greater(dusk_colour.g + 0.005)
	# The weight only ever rises across a blend.
	var previous: float = -1.0
	for step: int in range(0, 13):
		var weight: float = (view.call("mood_mix_at", 0.74 + 0.01 * float(step)) as Array)[2] as float
		assert_float(weight).is_greater_equal(previous)
		previous = weight


func test_environment_and_sky_follow_the_mood() -> void:
	var view: Node3D = _built_view(3)
	var environment: Environment = (view.call("get_environment_node") as WorldEnvironment).environment
	var sky: ShaderMaterial = view.call("get_sky_material") as ShaderMaterial
	var ocean: ShaderMaterial = view.call("get_ocean_material") as ShaderMaterial
	view.call("set_time_of_day", 0.5)
	var day_ambient: Color = environment.ambient_light_color
	var day_stars: float = sky.get_shader_parameter("star_amount") as float
	var day_deep: Color = ocean.get_shader_parameter("deep_colour") as Color
	view.call("set_time_of_day", 0.95)
	assert_bool(environment.ambient_light_color.is_equal_approx(day_ambient)).is_false()
	assert_float(sky.get_shader_parameter("star_amount") as float).is_greater(day_stars + 0.5)
	assert_float((ocean.get_shader_parameter("deep_colour") as Color).get_luminance()).is_less(day_deep.get_luminance())
	assert_float(sky.get_shader_parameter("moon_amount") as float).is_equal_approx(1.0, 0.001)


func test_time_of_day_never_rebuilds_the_rig() -> void:
	var view: Node3D = _built_view(3)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D
	var env_node: WorldEnvironment = view.call("get_environment_node") as WorldEnvironment
	var child_count: int = view.get_child_count()
	for step: int in range(0, 41):
		view.call("set_time_of_day", float(step) / 40.0)
	assert_object(view.call("get_sun")).is_same(sun)
	assert_object(view.call("get_environment_node")).is_same(env_node)
	assert_int(view.get_child_count()).is_equal(child_count)


func test_sun_swings_across_the_day() -> void:
	var view: Node3D = _built_view(1)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D
	view.call("set_time_of_day", 0.3)
	var morning_yaw: float = sun.rotation_degrees.y
	view.call("set_time_of_day", 0.7)
	var afternoon_yaw: float = sun.rotation_degrees.y
	assert_float(absf(afternoon_yaw - morning_yaw)).is_greater(5.0)
	# Setting the same time twice changes nothing.
	view.call("set_time_of_day", 0.7)
	assert_float(sun.rotation_degrees.y).is_equal_approx(afternoon_yaw, 0.0001)


# --- sea and terrain --------------------------------------------------------------------------------------------

func test_ocean_is_waterkit_tiles_that_reach_the_whole_bridge() -> void:
	var view: Node3D = _built_view()
	var ocean: Node3D = view.call("get_ocean") as Node3D
	assert_object(ocean).is_not_null()
	assert_float(ocean.position.y).is_less(0.0)
	var material: ShaderMaterial = view.call("get_ocean_material") as ShaderMaterial
	assert_object(material).is_not_null()
	assert_str(material.shader.code).contains("wave_a")
	var x_min: float = 1.0e9
	var x_max: float = -1.0e9
	assert_int(ocean.get_child_count()).is_greater_equal(2)
	for child: Node in ocean.get_children():
		var tile: MeshInstance3D = child as MeshInstance3D
		# One shared material and one shared origin: the waves run through the tiles without a seam.
		assert_object(tile.material_override).is_same(material)
		assert_vector(tile.position).is_equal(Vector3.ZERO)
		var plane: PlaneMesh = tile.mesh as PlaneMesh
		x_min = minf(x_min, plane.center_offset.x - plane.size.x * 0.5)
		x_max = maxf(x_max, plane.center_offset.x + plane.size.x * 0.5)
	# The 100-yojana bridge is 1 km long (DESIGN §9 units).
	assert_float(x_min).is_less(3.0)
	assert_float(x_max).is_greater(1050.0)


func test_terrain_is_flat_over_the_works_and_slopes_under_the_sea() -> void:
	var view: Node3D = _built_view()
	for p: Vector2 in [Vector2(0.0, 0.0), Vector2(-30.0, -10.0), Vector2(-60.0, 40.0), Vector2(-90.0, -70.0)]:
		assert_float(view.call("ground_height", p.x, p.y) as float).is_equal_approx(0.0, 0.0001)
	var sea_level: float = (view.call("get_ocean") as Node3D).position.y
	assert_float(view.call("ground_height", 30.0, 0.0) as float).is_less(sea_level - 2.0)
	assert_float(view.call("ground_height", -190.0, 0.0) as float).is_greater(1.0)
	var land: MeshInstance3D = view.get_node_or_null("Land") as MeshInstance3D
	assert_object(land).is_not_null()
	var bounds: AABB = land.mesh.get_aabb()
	assert_float(bounds.position.x).is_less(-190.0)
	assert_float(bounds.end.x).is_greater(20.0)
	assert_float(bounds.size.z).is_greater_equal(590.0)


func test_terrain_blends_sand_into_grass_with_a_materials_kind() -> void:
	var view: Node3D = _built_view()
	var land: MeshInstance3D = view.get_node_or_null("Land") as MeshInstance3D
	assert_object(land.material_override).is_null()
	var kind: StringName = StringName((land.mesh as ArrayMesh).surface_get_name(0))
	assert_bool(Materials.has_kind(kind)).is_true()
	assert_object(land.mesh.surface_get_material(0)).is_same(Materials.get_material(kind))
	var arrays: Array = land.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var sand: int = 0
	var grass: int = 0
	var distinct: Dictionary = {}
	for i: int in range(vertices.size()):
		var c: Color = colours[i]
		distinct[c.to_rgba32()] = true
		if vertices[i].x > -2.0 and vertices[i].x < 0.0:
			# The beach: warm and light.
			assert_float(c.r).is_greater(c.b)
			sand += 1
		elif vertices[i].x < -110.0:
			assert_float(c.g).is_greater(c.r)
			grass += 1
	assert_int(sand).is_greater(100)
	assert_int(grass).is_greater(100)
	# No flat single-colour ground (docs/ART.md "Surface richness").
	assert_int(distinct.size()).is_greater(1000)


func test_no_world_mesh_uses_the_old_flat_material() -> void:
	var view: Node3D = _built_view()
	var flat: ShaderMaterial = MeshKit.flat_material()
	var checked: int = 0
	for node: Node in view.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry.material_override is ShaderMaterial:
			assert_bool((geometry.material_override as ShaderMaterial).shader == flat.shader).is_false()
		checked += 1
	assert_int(checked).is_greater(60)


# --- sites and camps --------------------------------------------------------------------------------------------

func test_lekhan_pavilion_has_carved_pillars_and_a_gold_finial() -> void:
	var view: Node3D = _built_view()
	var lekhan: Node3D = view.call("get_site", "lekhan") as Node3D
	assert_int(_count_children(lekhan, "Pillar")).is_equal(4)
	var pillar: MeshInstance3D = lekhan.get_node_or_null("Pillar0") as MeshInstance3D
	assert_object(pillar).is_not_null()
	# Base, shaft, carved facets, bands and capital: far more than a box, in stone with gold and lacquer bands.
	assert_int(_tris(pillar.mesh)).is_greater(300)
	assert_array(_surface_names(pillar.mesh)).contains(["stone", "gold", "lacquer"])
	assert_float(pillar.mesh.get_aabb().size.y).is_greater(2.4)
	var canopy: MeshInstance3D = lekhan.get_node_or_null("Canopy") as MeshInstance3D
	assert_array(_surface_names(canopy.mesh)).contains(["stone", "gold"])
	assert_object(lekhan.get_node_or_null("Plinth")).is_not_null()
	# The roof stands on the pillars.
	assert_float(canopy.mesh.get_aabb().position.y).is_greater(2.5)


func test_quarry_has_a_cut_rock_face_and_a_hoist() -> void:
	var view: Node3D = _built_view()
	var quarry: Node3D = view.call("get_site", "quarry") as Node3D
	var face: MeshInstance3D = quarry.get_node_or_null("QuarryFace") as MeshInstance3D
	assert_object(face).is_not_null()
	assert_array(_surface_names(face.mesh)).contains(["stone"])
	assert_float(face.mesh.get_aabb().size.y).is_greater(2.0)
	assert_object(quarry.get_node_or_null("Hoist")).is_not_null()
	assert_int(_count_children(quarry, "Crag")).is_greater_equal(1)


func test_forest_has_timber_stacks() -> void:
	var view: Node3D = _built_view()
	var forest: Node3D = view.call("get_site", "forest") as Node3D
	assert_int(_count_children(forest, "TimberStack")).is_greater_equal(2)
	var stack: MeshInstance3D = forest.get_node_or_null("TimberStack0") as MeshInstance3D
	assert_array(_surface_names(stack.mesh)).contains(["wood"])
	assert_object(forest.get_node_or_null("Stumps")).is_not_null()


func test_rope_works_has_a_rope_walk_and_coiled_rope() -> void:
	var view: Node3D = _built_view()
	var works: Node3D = view.call("get_site", "ropeworks") as Node3D
	var walk: MeshInstance3D = works.get_node_or_null("RopeWalk") as MeshInstance3D
	assert_object(walk).is_not_null()
	assert_array(_surface_names(walk.mesh)).contains(["wood", "cloth"])
	assert_float(walk.mesh.get_aabb().size.x).is_greater(5.0)
	var coil: MeshInstance3D = works.get_node_or_null("RopeCoil0") as MeshInstance3D
	assert_object(coil).is_not_null()
	# Round loops of rope, not a disc.
	assert_int(_tris(coil.mesh)).is_greater(300)
	assert_array(_surface_names((works.get_node_or_null("ShedRoof") as MeshInstance3D).mesh)).contains(["cloth", "wood"])


func test_bridge_head_has_a_gate_with_banners() -> void:
	var view: Node3D = _built_view()
	var head: Node3D = view.call("get_site", "head") as Node3D
	assert_object(head.get_node_or_null("Pad")).is_not_null()
	assert_int(_count_children(head, "GatePillar")).is_equal(2)
	assert_int(_count_children(head, "GateBanner")).is_equal(2)
	# The gate stands clear of the 8 m causeway.
	for child: Node in head.get_children():
		if String(child.name).contains("GatePillar"):
			assert_float(absf((child as Node3D).position.z)).is_greater(4.5)


func test_ramas_pavilion_is_opulent_and_shows_no_figure() -> void:
	var view: Node3D = _built_view()
	var camp: Node3D = (view.call("get_scenery") as Node3D).get_node_or_null("RamaCamp") as Node3D
	assert_int(_count_children(camp, "Pillar")).is_equal(4)
	var roof: MeshInstance3D = camp.get_node_or_null("Roof") as MeshInstance3D
	assert_array(_surface_names(roof.mesh)).contains(["stone", "gold"])
	assert_array(_surface_names((camp.get_node_or_null("GoldTrim") as MeshInstance3D).mesh)).contains_exactly(["gold"])
	assert_array(_surface_names((camp.get_node_or_null("Banners") as MeshInstance3D).mesh)).contains(["cloth"])
	assert_object(camp.get_node_or_null("BowStand")).is_not_null()
	assert_object(camp.get_node_or_null("Dais")).is_not_null()
	assert_int(_count_children(camp, "LampLight")).is_equal(2)
	assert_object(camp.find_child("Rama*", true, false)).is_null()
	assert_object(camp.find_child("Sita*", true, false)).is_null()


func test_vanara_camp_is_dressed_and_its_fire_lights_up_at_night() -> void:
	var view: Node3D = _built_view(3)
	var camp: Node3D = (view.call("get_scenery") as Node3D).get_node_or_null("VanaraCamp") as Node3D
	assert_int(_count_children(camp, "Tent")).is_greater_equal(4)
	for part: String in ["Hearth", "Campfire", "Dressing", "Banners", "Fireflies"]:
		assert_object(camp.get_node_or_null(part)).is_not_null()
	var cloth: MeshInstance3D = camp.get_node_or_null("Tent0/Cloth") as MeshInstance3D
	assert_array(_surface_names(cloth.mesh)).contains(["cloth"])
	var glow: OmniLight3D = camp.get_node_or_null("CampfireLight") as OmniLight3D
	var fireflies: Node3D = camp.get_node_or_null("Fireflies") as Node3D
	view.call("set_time_of_day", 0.5)
	assert_float(glow.light_energy).is_equal_approx(0.0, 0.001)
	assert_bool(fireflies.visible).is_false()
	view.call("set_time_of_day", 0.95)
	assert_float(glow.light_energy).is_greater(1.0)
	assert_bool(fireflies.visible).is_true()


func test_flags_and_banners_sway_in_the_wind() -> void:
	var view: Node3D = _built_view()
	var flag: MeshInstance3D = (view.call("get_scenery") as Node3D).get_node_or_null("VanaraCamp/Tent0/Flag") as MeshInstance3D
	var colours: PackedColorArray = flag.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	var lowest: float = 1.0
	var highest: float = 0.0
	for c: Color in colours:
		lowest = minf(lowest, c.a)
		highest = maxf(highest, c.a)
	# Vertex colour alpha is the wind weight: pinned at the pole, free at the tip.
	assert_float(lowest).is_equal_approx(0.0, 0.01)
	assert_float(highest).is_equal_approx(1.0, 0.01)


# --- scatter and budgets ----------------------------------------------------------------------------------------

func test_hero_trees_stand_near_the_works_and_light_trees_beyond() -> void:
	var view: Node3D = _built_view()
	var near: PackedVector3Array = _scatter(view, "TreesNear")
	var far: PackedVector3Array = _scatter(view, "TreesFar")
	assert_int(near.size()).is_between(8, HERO_TREE_MAX)
	assert_int(far.size()).is_greater(near.size() * 2)
	assert_int(_scatter(view, "Trees").size()).is_equal(near.size() + far.size())
	var works: Vector3 = Vector3(-36.0, 0.0, 4.0)
	var farthest_hero: float = 0.0
	for p: Vector3 in near:
		farthest_hero = maxf(farthest_hero, p.distance_to(works))
	assert_float(farthest_hero).is_less(70.0)
	var far_mean: float = 0.0
	for p: Vector3 in far:
		assert_float(p.distance_to(works)).is_greater(50.0)
		far_mean += p.distance_to(works) / float(far.size())
	assert_float(far_mean).is_greater(farthest_hero)


func test_scatter_meshes_match_their_distance() -> void:
	var view: Node3D = _built_view()
	var scenery: Node3D = view.call("get_scenery") as Node3D
	var hero: MultiMeshInstance3D = scenery.get_node_or_null("Trees0") as MultiMeshInstance3D
	var light: MultiMeshInstance3D = scenery.get_node_or_null("TreesFar0") as MultiMeshInstance3D
	assert_object(hero).is_not_null()
	assert_object(light).is_not_null()
	# NatureKit v2 trees near the camera: bark and leaf-card surfaces. Light trees are a fraction of the cost.
	assert_array(_surface_names(hero.multimesh.mesh)).contains(["wood", "foliage"])
	assert_array(_surface_names(light.multimesh.mesh)).contains(["wood", "foliage"])
	assert_int(_tris(hero.multimesh.mesh)).is_greater(1500)
	assert_int(_tris(light.multimesh.mesh)).is_less(LIGHT_TREE_MAX_TRIS)
	# Hero trees cast their shadow through NatureKit's simpler shadow mesh.
	var caster: MultiMeshInstance3D = scenery.get_node_or_null("TreeShadow0") as MultiMeshInstance3D
	assert_int(caster.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_int(hero.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_int(caster.multimesh.instance_count).is_equal(hero.multimesh.instance_count)


func test_grass_and_flowers_are_multimesh_clumps_near_the_works() -> void:
	var view: Node3D = _built_view()
	var scenery: Node3D = view.call("get_scenery") as Node3D
	var grass: MultiMeshInstance3D = scenery.get_node_or_null("Grass0") as MultiMeshInstance3D
	assert_object(grass).is_not_null()
	assert_int(grass.multimesh.instance_count).is_greater(400)
	assert_bool(grass.multimesh.use_colors).is_true()
	assert_array(_surface_names(grass.multimesh.mesh)).contains(["foliage"])
	assert_int(_scatter(view, "Grass").size()).is_equal(grass.multimesh.instance_count)
	for p: Vector3 in _scatter(view, "Grass"):
		assert_float(p.x).is_between(-110.0, 0.0)
		# Never on the causeway approach.
		assert_float(absf(p.z)).is_greater(1.0)
	assert_object(scenery.get_node_or_null("Flowers0")).is_not_null()
	assert_int(_scatter(view, "Flowers").size()).is_greater(8)
	assert_object(scenery.get_node_or_null("Bushes0")).is_not_null()
	assert_object(scenery.get_node_or_null("Palms0")).is_not_null()
	assert_array(_surface_names((scenery.get_node_or_null("Palms0") as MultiMeshInstance3D).multimesh.mesh)).contains(["wood", "foliage"])


func test_shore_has_rocks_in_the_shallows_clear_of_the_bridge() -> void:
	var view: Node3D = _built_view()
	var rocks: PackedVector3Array = _scatter(view, "SeaRocks")
	assert_int(rocks.size()).is_greater_equal(4)
	for p: Vector3 in rocks:
		assert_float(p.x).is_between(3.0, 30.0)
		assert_float(absf(p.z)).is_greater(10.0)


func test_world_is_deterministic() -> void:
	var a: Node3D = _built_view()
	var b: Node3D = _built_view()
	for kind: String in ["TreesNear", "TreesFar", "Grass", "Flowers", "Palms", "SeaRocks", "Bushes"]:
		var pa: PackedVector3Array = _scatter(a, kind)
		var pb: PackedVector3Array = _scatter(b, kind)
		assert_int(pa.size()).is_equal(pb.size())
		assert_int(pa.size()).is_greater(0)
		for i: int in range(pa.size()):
			assert_vector(pa[i]).is_equal(pb[i])
	var land_a: Mesh = (a.get_node_or_null("Land") as MeshInstance3D).mesh
	var land_b: Mesh = (b.get_node_or_null("Land") as MeshInstance3D).mesh
	assert_int(_tris(land_a)).is_equal(_tris(land_b))


func test_triangle_budgets() -> void:
	var view: Node3D = _built_view()
	var scenery_tris: int = 0
	var land_tris: int = 0
	var ocean: Node3D = view.call("get_ocean") as Node3D
	var scenery: Node3D = view.call("get_scenery") as Node3D
	for node: Node in view.find_children("*", "GeometryInstance3D", true, false):
		if ocean.is_ancestor_of(node):
			continue
		var tris: int = 0
		if node is MultiMeshInstance3D:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			tris = _tris(mm.mesh) * mm.instance_count
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			tris = _tris((node as MeshInstance3D).mesh)
		land_tris += tris
		if scenery.is_ancestor_of(node):
			scenery_tris += tris
	assert_int(scenery_tris).is_less(SCENERY_BUDGET)
	assert_int(scenery_tris).is_greater(20000)
	assert_int(land_tris).is_less(LAND_BUDGET)
