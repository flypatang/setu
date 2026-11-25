class_name WorldView
extends Node3D
## Static presentation of the Setu world (DESIGN §9 S15): shore, quarry, forest, rope-works and lekhan sites at the
## positions in a day file, the ocean plane (NatureKit), a sun, a back rim light and a WorldEnvironment.
## Each visible site is built from enough parts to read from the iso camera: a rock cluster with a cliff and a
## cut-stone pile (quarry), a grove of trees (forest), an open shed with rope coils (rope-works), and a canopy over
## scribes' stones carrying the RamaGlyph (lekhan). Each has a torch that fades in at night.
## set_time_of_day(t) drives the sun angle and colour (dawn pink, noon white, sunset saffron, night indigo with lower
## energy), clamps the sun to a small positive minimum elevation, disables sun shadows at night and fades the torches.
## Rendering only: it reads the day data and never writes to the simulation.

const SITE_PREFIX: String = "Site_"
const SHORE_LENGTH: float = 600.0
const LAND_WIDTH: float = 200.0
const SEA_WIDTH: float = 600.0
const SUN_ELEVATION_MAX_DEG: float = 70.0
const SUN_ELEVATION_MIN_DEG: float = 6.0
const RIM_DAY_ENERGY: float = 0.25
const RIM_NIGHT_ENERGY: float = 0.6

## Night window: torches are full inside it, fade in from NIGHT_FADE_IN_START and out before NIGHT_FADE_OUT_END.
const NIGHT_FADE_IN_START: float = 0.8
const NIGHT_FADE_IN_END: float = 0.9
const NIGHT_FADE_OUT_START: float = 0.05
const NIGHT_FADE_OUT_END: float = 0.15
const TORCH_ENERGY: float = 6.0
const TORCH_RANGE: float = 9.0
const TORCH_OFFSET: Vector3 = Vector3(-3.0, 0.0, 3.0)
const TORCH_HEIGHT: float = 2.4

## Time of day keys (0 = midnight, 0.5 = noon) and the colour and energy the sun has at each key.
const TIME_KEYS: PackedFloat32Array = [0.0, 0.25, 0.5, 0.75, 0.95, 1.0]
const SUN_COLOURS: PackedColorArray = [
	Palette.NIGHT_INDIGO,
	Palette.DAWN_PINK,
	Color(1.0, 1.0, 1.0, 1.0),
	Palette.SAFFRON,
	Palette.NIGHT_INDIGO,
	Palette.NIGHT_INDIGO,
]
const SUN_ENERGIES: PackedFloat32Array = [0.12, 0.6, 1.0, 0.6, 0.12, 0.12]

## Quarry layout: a ring of rocks around the site centre, a cliff behind them and a cut-stone pile to one side.
const ROCK_COUNT: int = 8
const ROCK_RING_RADIUS: float = 4.5
const CLIFF_OFFSET: Vector3 = Vector3(0.0, 0.0, -7.0)
const CLIFF_SIZE: Vector3 = Vector3(9.0, 5.0, 3.0)
const CUT_STONE_OFFSET: Vector3 = Vector3(5.0, 0.0, 3.5)
const ROCK_SEED_STRIDE: int = ROCK_COUNT + 1

## Forest layout: a grove of trees spread over a disc (Vogel distribution, so spacing stays even).
const FOREST_TREE_COUNT: int = 16
const FOREST_RADIUS: float = 8.0
const GOLDEN_ANGLE: float = 2.39996323

## Rope-works shed and coils, in site-local metres.
const SHED_POST_HEIGHT: float = 2.0
const SHED_HALF_SIZE: Vector2 = Vector2(1.3, 1.1)
const ROPE_COIL_OFFSETS: PackedVector3Array = [
	Vector3(1.7, 0.15, 0.0),
	Vector3(1.5, 0.15, 1.0),
	Vector3(0.8, 0.15, -0.8),
]

## Lekhan canopy and scribes' stones (site-local metres).
const CANOPY_HEIGHT: float = 3.0
const CANOPY_HALF_SIZE: Vector2 = Vector2(2.0, 1.6)
const STELE_SIZE: Vector3 = Vector3(1.1, 1.6, 0.4)
const STELE_XS: PackedFloat32Array = [-1.4, 0.0, 1.4]
const GLYPH_HEIGHT: float = 1.0
const GLYPH_INK: Color = Color("#1B1B3A")


## World polish (S30): seeded scenery scattered over the land, kept clear of the sites and of the haul routes.
const SCENERY_NAME: String = "Scenery"
const SCENERY_SEED: int = 3030
const SCATTER_X_MIN: float = -170.0
const SCATTER_X_MAX: float = -7.0
const SCATTER_Z_HALF: float = 120.0
const SITE_CLEARANCE: float = 11.0
const HAUL_CLEARANCE: float = 6.0
const CAMP_CLEARANCE: float = 13.0
const CORRIDOR_HALF_WIDTH: float = 4.5
const TREE_COUNT: int = 96
const ROCK_COUNT_SCATTER: int = 36
const GRASS_COUNT: int = 140
const PALM_COUNT: int = 14
const PALM_X_MIN: float = -12.0
const PALM_X_MAX: float = -4.5
const FOAM_COUNT: int = 56
const FOAM_X: float = 3.4
const HILL_COUNT: int = 8
const HILL_X: float = -182.0
const RAMA_CAMP_POS: Vector3 = Vector3(-16.0, 0.0, -62.0)
const VANARA_CAMP_POS: Vector3 = Vector3(-14.0, 0.0, 58.0)
const TENT_OFFSETS: PackedVector2Array = [
	Vector2(0.0, 0.0), Vector2(6.0, -4.0), Vector2(-5.0, -5.0), Vector2(3.0, 6.0), Vector2(-6.0, 4.0),
]
const TENT_CLOTH: Color = Color("#D9C7A0")
const PAVILION_HALF: Vector2 = Vector2(3.5, 2.8)
const PAVILION_POST_HEIGHT: float = 3.4

var _current_time: float = 0.5
var _torches: Array[OmniLight3D] = []
var _scatter_points: Dictionary = {}


## Removes any previous world and builds the static scene for one day file (a parsed day_<n>.json dictionary).
func build_from_day(day: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_torches.clear()
	_scatter_points.clear()
	_build_shore()
	_build_ocean()
	_build_lights()
	var piles: Array = day.get("piles", []) as Array
	_build_scenery(piles)
	var forest_seed: int = 1
	var rock_seed: int = 1
	for raw: Variant in piles:
		var pile: Dictionary = raw as Dictionary
		var site: Node3D = _build_site(pile, forest_seed, rock_seed)
		add_child(site)
		var role: String = pile.get("role", "") as String
		if role == "lumberjack":
			forest_seed += FOREST_TREE_COUNT
		elif role == "cutter":
			rock_seed += ROCK_SEED_STRIDE
	set_time_of_day(_current_time)


## Returns the site node built for a pile id, or null when there is none.
func get_site(id: String) -> Node3D:
	return get_node_or_null(NodePath(SITE_PREFIX + id)) as Node3D


## The node that holds the S30 scenery (scattered trees, rocks, grass, palms, foam, hills and the two camps).
func get_scenery() -> Node3D:
	return get_node_or_null(SCENERY_NAME) as Node3D


## World positions (x, y = 0, z) of every instance of a scenery kind: "Trees", "Rocks", "Grass", "Palms" or "Foam".
## The headless renderer does not keep MultiMesh transforms, so the placement is recorded here too.
func get_scatter_points(kind: String) -> PackedVector3Array:
	return (_scatter_points.get(kind, PackedVector3Array()) as PackedVector3Array).duplicate()


func get_sun() -> DirectionalLight3D:
	return get_node_or_null("Sun") as DirectionalLight3D


func get_environment_node() -> WorldEnvironment:
	return get_node_or_null("WorldEnvironment") as WorldEnvironment


## Returns the torch lights built for the visible sites (quarry, forest, rope-works, lekhan).
func get_torches() -> Array[OmniLight3D]:
	return _torches.duplicate()


## Drives the sun and the environment from the time of day, 0..1 (0 = midnight, 0.5 = noon).
func set_time_of_day(t: float) -> void:
	_current_time = clampf(t, 0.0, 1.0)
	if get_sun() == null:
		_build_lights()
	var sun: DirectionalLight3D = get_sun()
	var colour: Color = _sample_colour(_current_time)
	var energy: float = _sample_energy(_current_time)
	var elevation: float = maxf(sin(TAU * (_current_time - 0.25)) * SUN_ELEVATION_MAX_DEG, SUN_ELEVATION_MIN_DEG)
	sun.light_color = colour
	sun.light_energy = energy
	sun.rotation_degrees = Vector3(-elevation, 30.0, 0.0)
	sun.shadow_enabled = not _is_night(_current_time)

	var day_factor: float = clampf(energy, 0.0, 1.0)
	var rim: DirectionalLight3D = get_node_or_null("RimLight") as DirectionalLight3D
	if rim != null:
		rim.light_energy = lerpf(RIM_NIGHT_ENERGY, RIM_DAY_ENERGY, day_factor)

	var env_node: WorldEnvironment = get_environment_node()
	if env_node != null and env_node.environment != null:
		var environment: Environment = env_node.environment
		environment.background_color = Palette.NIGHT_INDIGO.lerp(colour, day_factor * 0.5)
		environment.ambient_light_color = colour
		environment.ambient_light_energy = lerpf(0.25, 0.5, day_factor)

	var torch_strength: float = _torch_strength(_current_time)
	for torch: OmniLight3D in _torches:
		torch.light_energy = torch_strength * TORCH_ENERGY


static func _is_night(t: float) -> bool:
	return t < NIGHT_FADE_OUT_END or t > NIGHT_FADE_IN_START


## Torch strength 0..1: 0 in daylight, ramps up through dusk (0.8..0.9) and down through dawn (0.05..0.15).
static func _torch_strength(t: float) -> float:
	if t >= 0.5:
		return clampf((t - NIGHT_FADE_IN_START) / (NIGHT_FADE_IN_END - NIGHT_FADE_IN_START), 0.0, 1.0)
	return clampf((NIGHT_FADE_OUT_END - t) / (NIGHT_FADE_OUT_END - NIGHT_FADE_OUT_START), 0.0, 1.0)


static func _segment_index(t: float) -> int:
	var index: int = 0
	for k: int in range(TIME_KEYS.size() - 1):
		if t >= TIME_KEYS[k]:
			index = k
	return index


static func _segment_fraction(t: float, index: int) -> float:
	var start: float = TIME_KEYS[index]
	var end: float = TIME_KEYS[index + 1]
	if end <= start:
		return 0.0
	return clampf((t - start) / (end - start), 0.0, 1.0)


static func _sample_colour(t: float) -> Color:
	var index: int = _segment_index(t)
	var fraction: float = _segment_fraction(t, index)
	return SUN_COLOURS[index].lerp(SUN_COLOURS[index + 1], fraction)


static func _sample_energy(t: float) -> float:
	var index: int = _segment_index(t)
	var fraction: float = _segment_fraction(t, index)
	return lerpf(SUN_ENERGIES[index], SUN_ENERGIES[index + 1], fraction)


func _build_lights() -> void:
	if get_node_or_null("Sun") == null:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.name = "Sun"
		sun.shadow_enabled = true
		add_child(sun)
	if get_node_or_null("RimLight") == null:
		var rim: DirectionalLight3D = DirectionalLight3D.new()
		rim.name = "RimLight"
		rim.light_color = Palette.MOON
		rim.rotation_degrees = Vector3(-20.0, 180.0, 0.0)
		add_child(rim)
	if get_node_or_null("WorldEnvironment") == null:
		var env_node: WorldEnvironment = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		var environment: Environment = Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_node.environment = environment
		add_child(env_node)


func _build_shore() -> void:
	var sand: MeshInstance3D = _mesh_node("Shore", MeshKit.box(Vector3(6.0, 0.5, SHORE_LENGTH), Palette.SHORE_SAND.darkened(0.28)))
	sand.position = Vector3(0.0, -0.25, 0.0)
	add_child(sand)
	var land: MeshInstance3D = _mesh_node("Land", MeshKit.box(Vector3(LAND_WIDTH, 0.5, SHORE_LENGTH), Palette.LEAF_DARK))
	land.position = Vector3(-LAND_WIDTH * 0.5 - 3.0, -0.25, 0.0)
	add_child(land)


func _build_ocean() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(SEA_WIDTH, SHORE_LENGTH))
	ocean.name = "Ocean"
	ocean.position = Vector3(SEA_WIDTH * 0.5 + 3.0, -0.3, 0.0)
	add_child(ocean)


func _build_site(pile: Dictionary, forest_seed: int, rock_seed: int) -> Node3D:
	var id: String = pile.get("id", "") as String
	var role: String = pile.get("role", "") as String
	var pos: Array = pile.get("pos", [0.0, 0.0]) as Array
	var site: Node3D = Node3D.new()
	site.name = SITE_PREFIX + id
	site.position = Vector3((pos[0] as float), 0.0, (pos[1] as float))
	match role:
		"cutter":
			_add_quarry(site, rock_seed)
			_add_torch(site)
		"lumberjack":
			_add_forest(site, forest_seed)
			_add_torch(site)
		"lasher":
			_add_rope_works(site)
			_add_torch(site)
		"scribe":
			_add_lekhan(site)
			_add_torch(site)
		_:
			_add_pad(site)
	return site


func _add_quarry(site: Node3D, first_seed: int) -> void:
	for i: int in range(ROCK_COUNT):
		var angle: float = float(i) * GOLDEN_ANGLE
		var radius: float = 1.5 + ROCK_RING_RADIUS * sqrt((float(i) + 0.5) / float(ROCK_COUNT))
		var size: Vector3 = Vector3(1.6 + 0.4 * float(i % 3), 1.2 + 0.3 * float(i % 2), 1.5 + 0.2 * float(i % 4))
		var rock: MeshInstance3D = NatureKit.rock(size, first_seed + i)
		rock.name = "Rock%d" % i
		rock.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		site.add_child(rock)
	var cliff: MeshInstance3D = NatureKit.cliff(CLIFF_SIZE, first_seed + ROCK_COUNT)
	cliff.position = CLIFF_OFFSET
	site.add_child(cliff)
	_add_cut_stone_pile(site)


func _add_cut_stone_pile(site: Node3D) -> void:
	var courses: Array[Vector3] = [
		Vector3(2.6, 0.6, 1.8),
		Vector3(2.1, 0.6, 1.5),
		Vector3(1.5, 0.6, 1.2),
	]
	var height: float = 0.0
	for size: Vector3 in courses:
		var stone: MeshInstance3D = _mesh_node("CutStone%d" % site.get_child_count(), MeshKit.box(size, Palette.STONE))
		stone.position = CUT_STONE_OFFSET + Vector3(0.0, height + size.y * 0.5, 0.0)
		site.add_child(stone)
		height += size.y


func _add_forest(site: Node3D, first_seed: int) -> void:
	for i: int in range(FOREST_TREE_COUNT):
		var radius: float = FOREST_RADIUS * sqrt((float(i) + 0.5) / float(FOREST_TREE_COUNT))
		var angle: float = float(i) * GOLDEN_ANGLE
		var tree: MeshInstance3D
		if i % 2 == 0:
			tree = NatureKit.ashoka_tree(first_seed + i, 6.0)
		else:
			tree = NatureKit.shimshapa_tree(first_seed + i, 7.0)
		tree.name = "Tree%d" % i
		tree.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		site.add_child(tree)


func _add_rope_works(site: Node3D) -> void:
	var half: Vector2 = SHED_HALF_SIZE
	var post_size: Vector3 = Vector3(0.25, SHED_POST_HEIGHT, 0.25)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post: MeshInstance3D = _mesh_node("ShedPost%d" % site.get_child_count(), MeshKit.box(post_size, Palette.BARK))
			post.position = Vector3(sx * (half.x - 0.125), SHED_POST_HEIGHT * 0.5, sz * (half.y - 0.125))
			site.add_child(post)
	var back: MeshInstance3D = _mesh_node("ShedBack", MeshKit.box(Vector3(half.x * 2.0, 1.4, 0.12), Palette.BARK))
	back.position = Vector3(0.0, 0.7, -half.y + 0.06)
	site.add_child(back)
	var roof: MeshInstance3D = _mesh_node("ShedRoof", MeshKit.box(Vector3(half.x * 2.0 + 0.6, 0.18, half.y * 2.0 + 0.6), Palette.ROPE))
	roof.position = Vector3(0.0, SHED_POST_HEIGHT + 0.09, 0.0)
	site.add_child(roof)
	for offset: Vector3 in ROPE_COIL_OFFSETS:
		var coil: MeshInstance3D = _mesh_node("RopeCoil%d" % site.get_child_count(), MeshKit.cylinder(0.5, 0.5, 0.3, 12, Palette.ROPE))
		coil.position = offset
		site.add_child(coil)


func _add_lekhan(site: Node3D) -> void:
	var half: Vector2 = CANOPY_HALF_SIZE
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post: MeshInstance3D = _mesh_node("CanopyPost%d" % site.get_child_count(), MeshKit.box(Vector3(0.2, CANOPY_HEIGHT, 0.2), Palette.BARK))
			post.position = Vector3(sx * (half.x - 0.1), CANOPY_HEIGHT * 0.5, sz * (half.y - 0.1))
			site.add_child(post)
	var canopy: MeshInstance3D = _mesh_node("Canopy", MeshKit.box(Vector3(half.x * 2.0, 0.2, half.y * 2.0), Palette.SHORE_SAND))
	canopy.position = Vector3(0.0, CANOPY_HEIGHT + 0.1, 0.0)
	site.add_child(canopy)
	var stele_depth: float = STELE_SIZE.z
	for x: float in STELE_XS:
		var stele: MeshInstance3D = _mesh_node("Stele%d" % site.get_child_count(), MeshKit.box(STELE_SIZE, Palette.WET_STONE))
		stele.position = Vector3(x, STELE_SIZE.y * 0.5, 0.0)
		site.add_child(stele)
		var glyph: MeshInstance3D = _mesh_node("RamaGlyph", RamaGlyph.mesh(GLYPH_HEIGHT, GLYPH_INK))
		glyph.position = Vector3(0.0, 0.0, stele_depth * 0.5 + 0.03)
		stele.add_child(glyph)


func _add_torch(site: Node3D) -> void:
	var pole: MeshInstance3D = _mesh_node("TorchPole", MeshKit.box(Vector3(0.12, TORCH_HEIGHT, 0.12), Palette.BARK))
	pole.position = TORCH_OFFSET + Vector3(0.0, TORCH_HEIGHT * 0.5, 0.0)
	site.add_child(pole)
	var flame: MeshInstance3D = _mesh_node("TorchFlame", MeshKit.sphere(0.2, 4, 6, Palette.FIRE_CORE))
	flame.position = TORCH_OFFSET + Vector3(0.0, TORCH_HEIGHT + 0.2, 0.0)
	site.add_child(flame)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = Palette.FIRE_CORE
	light.omni_range = TORCH_RANGE
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.position = flame.position
	site.add_child(light)
	_torches.append(light)


func _add_pad(site: Node3D) -> void:
	var pad: MeshInstance3D = _mesh_node("Pad", MeshKit.box(Vector3(4.0, 0.2, 4.0), Palette.WET_STONE))
	pad.position = Vector3(0.0, 0.1, 0.0)
	site.add_child(pad)


func _mesh_node(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = MeshKit.flat_material()
	return mi


# --- S30 world polish -------------------------------------------------------------------------------------------

func _build_scenery(piles: Array) -> void:
	var scenery: Node3D = Node3D.new()
	scenery.name = SCENERY_NAME
	add_child(scenery)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED
	var sites: Array[Vector2] = []
	for raw: Variant in piles:
		var pos: Array = (raw as Dictionary).get("pos", [0.0, 0.0]) as Array
		sites.append(Vector2(pos[0] as float, pos[1] as float))
	var camps: Array[Vector2] = [Vector2(RAMA_CAMP_POS.x, RAMA_CAMP_POS.z), Vector2(VANARA_CAMP_POS.x, VANARA_CAMP_POS.z)]

	var tree_meshes: Array[Mesh] = [
		_free_mesh(NatureKit.ashoka_tree(11, 6.0)), _free_mesh(NatureKit.ashoka_tree(12, 7.0)),
		_free_mesh(NatureKit.shimshapa_tree(13, 7.0)), _free_mesh(NatureKit.shimshapa_tree(14, 6.0)),
	]
	_add_scatter(scenery, "Trees", tree_meshes, _scatter(rng, TREE_COUNT, SCATTER_X_MIN, SCATTER_X_MAX, sites, camps, 1.0), 0.8, 1.3)
	var rock_meshes: Array[Mesh] = [
		_free_mesh(NatureKit.rock(Vector3(1.4, 1.0, 1.2), 21)), _free_mesh(NatureKit.rock(Vector3(1.0, 0.8, 1.6), 22)),
		_free_mesh(NatureKit.rock(Vector3(2.0, 1.4, 1.7), 23)),
	]
	_add_scatter(scenery, "Rocks", rock_meshes, _scatter(rng, ROCK_COUNT_SCATTER, SCATTER_X_MIN, SCATTER_X_MAX, sites, camps, 1.0), 0.7, 1.5)
	var grass_meshes: Array[Mesh] = [_free_mesh(NatureKit.grass_patch(31, 1.5, 24)), _free_mesh(NatureKit.grass_patch(32, 1.2, 20))]
	_add_scatter(scenery, "Grass", grass_meshes, _scatter(rng, GRASS_COUNT, SCATTER_X_MIN, SCATTER_X_MAX, sites, camps, 0.5), 0.8, 1.6)
	var palm_meshes: Array[Mesh] = [_palm_mesh(41), _palm_mesh(42)]
	_add_scatter(scenery, "Palms", palm_meshes, _scatter(rng, PALM_COUNT, PALM_X_MIN, PALM_X_MAX, sites, camps, 0.6), 0.9, 1.25)
	_build_foam(scenery, rng)
	_build_hills(scenery, rng)
	_build_vanara_camp(scenery)
	_build_rama_camp(scenery)


static func _free_mesh(mi: MeshInstance3D) -> Mesh:
	var mesh: Mesh = mi.mesh
	mi.free()
	return mesh


## Rejection-samples `count` land positions that keep clear of every site, haul route (site to head), camp and the z = 0 corridor.
func _scatter(rng: RandomNumberGenerator, count: int, x_min: float, x_max: float, sites: Array[Vector2],
		camps: Array[Vector2], clearance_scale: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var attempts: int = 0
	while result.size() < count and attempts < count * 60:
		attempts += 1
		var p: Vector2 = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(-SCATTER_Z_HALF, SCATTER_Z_HALF))
		if _scatter_blocked(p, sites, camps, clearance_scale):
			continue
		result.append(p)
	return result


func _scatter_blocked(p: Vector2, sites: Array[Vector2], camps: Array[Vector2], clearance_scale: float) -> bool:
	if absf(p.y) < CORRIDOR_HALF_WIDTH:
		return true
	for site: Vector2 in sites:
		if p.distance_to(site) < SITE_CLEARANCE * clearance_scale:
			return true
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(p, site, Vector2.ZERO)
		if p.distance_to(nearest) < HAUL_CLEARANCE * clearance_scale:
			return true
	for camp: Vector2 in camps:
		if p.distance_to(camp) < CAMP_CLEARANCE:
			return true
	return false


func _add_scatter(parent: Node3D, base_name: String, meshes: Array[Mesh], points: PackedVector2Array,
		scale_min: float, scale_max: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED + base_name.hash() % 1000
	var recorded: PackedVector3Array = PackedVector3Array()
	var buckets: Array[Array] = []
	for i: int in range(meshes.size()):
		buckets.append([])
	for i: int in range(points.size()):
		var scale: float = rng.randf_range(scale_min, scale_max)
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale))
		var xf: Transform3D = Transform3D(basis, Vector3(points[i].x, 0.0, points[i].y))
		buckets[i % meshes.size()].append(xf)
		recorded.append(xf.origin)
	_scatter_points[base_name] = recorded
	for k: int in range(meshes.size()):
		_add_multimesh(parent, "%s%d" % [base_name, k], meshes[k], buckets[k])


func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i] as Transform3D)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = MeshKit.flat_material()
	parent.add_child(mmi)
	return mmi


## A palm-like tree: a leaning segmented trunk crowned with a ring of drooping fronds and a few coconuts.
func _palm_mesh(rng_seed: int) -> Mesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var parts: Array[Dictionary] = []
	var lean: float = rng.randf_range(0.08, 0.18)
	var top: Vector3 = Vector3.ZERO
	for i: int in range(4):
		var seg: ArrayMesh = MeshKit.cylinder(0.14 - 0.012 * float(i), 0.17 - 0.012 * float(i), 1.3, 6, Palette.BARK)
		var centre: Vector3 = Vector3(lean * 1.3 * float(i), 0.65 + 1.3 * float(i), 0.0)
		parts.append({"mesh": seg, "transform": Transform3D(Basis(Vector3.BACK, -lean), centre)})
		top = centre + Vector3(0.0, 0.65, 0.0)
	var frond: ArrayMesh = MeshKit.box(Vector3(2.4, 0.05, 0.5), Palette.GROVE_GREEN)
	for i: int in range(7):
		var yaw: float = TAU * float(i) / 7.0
		var droop: float = rng.randf_range(0.35, 0.6)
		var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -droop)
		var offset: Vector3 = basis * Vector3(1.1, 0.0, 0.0)
		parts.append({"mesh": frond, "transform": Transform3D(basis, top + offset)})
	var nut: ArrayMesh = MeshKit.sphere(0.16, 3, 5, Palette.BARK)
	for i: int in range(3):
		var a: float = TAU * float(i) / 3.0
		parts.append({"mesh": nut, "transform": Transform3D(Basis.IDENTITY, top + Vector3(cos(a) * 0.25, -0.2, sin(a) * 0.25))})
	return MeshKit.merge(parts)


## Foam: thin pale strips that hug the waterline along the shore.
func _build_foam(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var foam_colour: Color = Palette.MOON.lerp(Color.WHITE, 0.6)
	var strip: ArrayMesh = MeshKit.box(Vector3(0.5, 0.06, 1.0), foam_colour)
	var transforms: Array[Transform3D] = []
	for i: int in range(FOAM_COUNT):
		var z: float = lerpf(-SCATTER_Z_HALF, SCATTER_Z_HALF, (float(i) + rng.randf_range(0.0, 0.8)) / float(FOAM_COUNT))
		var length: float = rng.randf_range(2.0, 5.0)
		var width: float = rng.randf_range(0.6, 1.4)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(width, 1.0, length))
		transforms.append(Transform3D(basis, Vector3(FOAM_X + rng.randf_range(0.0, 1.2), -0.22, z)))
	var recorded: PackedVector3Array = PackedVector3Array()
	for xf: Transform3D in transforms:
		recorded.append(xf.origin)
	_scatter_points["Foam"] = recorded
	_add_multimesh(parent, "Foam", strip, transforms)


## A line of rounded green hills along the far edge of the land.
func _build_hills(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var hills: Node3D = Node3D.new()
	hills.name = "Hills"
	parent.add_child(hills)
	for i: int in range(HILL_COUNT):
		var radius: float = rng.randf_range(16.0, 26.0)
		var colour: Color = Palette.LEAF_DARK.lerp(Palette.GROVE_GREEN, rng.randf_range(0.1, 0.5))
		var hill: MeshInstance3D = _mesh_node("Hill%d" % i, MeshKit.sphere(radius, 5, 9, colour))
		var z: float = lerpf(-SCATTER_Z_HALF * 1.4, SCATTER_Z_HALF * 1.4, float(i) / float(HILL_COUNT - 1))
		hill.position = Vector3(HILL_X - rng.randf_range(0.0, 10.0), -radius * 0.45, z)
		hill.scale = Vector3(1.3, 0.7, 1.9)
		hills.add_child(hill)


func _build_vanara_camp(parent: Node3D) -> void:
	var camp: Node3D = Node3D.new()
	camp.name = "VanaraCamp"
	camp.position = VANARA_CAMP_POS
	parent.add_child(camp)
	for i: int in range(TENT_OFFSETS.size()):
		var tent: Node3D = Node3D.new()
		tent.name = "Tent%d" % i
		tent.position = Vector3(TENT_OFFSETS[i].x, 0.0, TENT_OFFSETS[i].y)
		tent.rotation.y = float(i) * 0.7
		var body: MeshInstance3D = _mesh_node("Cloth", MeshKit.cone(2.0, 2.4, 4, TENT_CLOTH))
		body.position = Vector3(0.0, 1.2, 0.0)
		body.rotation.y = PI * 0.25
		tent.add_child(body)
		var pole: MeshInstance3D = _mesh_node("Pole", MeshKit.box(Vector3(0.08, 1.4, 0.08), Palette.BARK))
		pole.position = Vector3(0.0, 2.9, 0.0)
		tent.add_child(pole)
		var flag: MeshInstance3D = _mesh_node("Flag", MeshKit.box(Vector3(0.9, 0.5, 0.04), Palette.SAFFRON))
		flag.position = Vector3(0.45, 3.35, 0.0)
		tent.add_child(flag)
		camp.add_child(tent)
	var fire: MeshInstance3D = _mesh_node("Campfire", MeshKit.cone(0.4, 0.7, 5, Palette.FIRE_EDGE))
	fire.position = Vector3(0.0, 0.35, 0.0)
	camp.add_child(fire)


## Rama's camp: an open pavilion with a GOLD-trimmed roof and a saffron banner. Rama himself is not shown.
func _build_rama_camp(parent: Node3D) -> void:
	var camp: Node3D = Node3D.new()
	camp.name = "RamaCamp"
	camp.position = RAMA_CAMP_POS
	parent.add_child(camp)
	var floor_mesh: MeshInstance3D = _mesh_node("Dais", MeshKit.box(Vector3(PAVILION_HALF.x * 2.0 + 1.0, 0.3, PAVILION_HALF.y * 2.0 + 1.0), Palette.STONE))
	floor_mesh.position = Vector3(0.0, 0.15, 0.0)
	camp.add_child(floor_mesh)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post: MeshInstance3D = _mesh_node("Post%d" % camp.get_child_count(), MeshKit.box(Vector3(0.25, PAVILION_POST_HEIGHT, 0.25), Palette.BARK))
			post.position = Vector3(sx * (PAVILION_HALF.x - 0.2), 0.3 + PAVILION_POST_HEIGHT * 0.5, sz * (PAVILION_HALF.y - 0.2))
			camp.add_child(post)
	var roof_y: float = 0.3 + PAVILION_POST_HEIGHT
	var roof: MeshInstance3D = _mesh_node("Roof", MeshKit.box(Vector3(PAVILION_HALF.x * 2.0 + 0.8, 0.3, PAVILION_HALF.y * 2.0 + 0.8), Palette.SINDOOR))
	roof.position = Vector3(0.0, roof_y + 0.15, 0.0)
	camp.add_child(roof)
	var trim: MeshInstance3D = _mesh_node("GoldTrim", MeshKit.box(Vector3(PAVILION_HALF.x * 2.0 + 1.0, 0.18, PAVILION_HALF.y * 2.0 + 1.0), Palette.GOLD))
	trim.position = Vector3(0.0, roof_y - 0.05, 0.0)
	camp.add_child(trim)
	var spire: MeshInstance3D = _mesh_node("Spire", MeshKit.cone(1.0, 1.6, 4, Palette.GOLD))
	spire.position = Vector3(0.0, roof_y + 1.1, 0.0)
	spire.rotation.y = PI * 0.25
	camp.add_child(spire)
	var banner: MeshInstance3D = _mesh_node("Banner", MeshKit.box(Vector3(1.0, 0.6, 0.04), Palette.SAFFRON))
	banner.position = Vector3(0.6, roof_y + 2.4, 0.0)
	camp.add_child(banner)
