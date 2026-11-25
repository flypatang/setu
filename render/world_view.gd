class_name WorldView
extends Node3D
## Static presentation of the Setu world (DESIGN §9 S15): shore, quarry rocks, forest, rope-works and lekhan
## station markers at the positions in a day file, the ocean plane (NatureKit), a sun, a back rim light and a
## WorldEnvironment. set_time_of_day(t) drives the sun angle and colour (dawn pink, noon white, sunset saffron,
## night indigo with lower energy). Rendering only: it reads the day data and never writes to the simulation.

const SITE_PREFIX: String = "Site_"
const SHORE_LENGTH: float = 600.0
const LAND_WIDTH: float = 200.0
const SEA_WIDTH: float = 600.0
const SUN_ELEVATION_MAX_DEG: float = 70.0
const RIM_DAY_ENERGY: float = 0.25
const RIM_NIGHT_ENERGY: float = 0.6

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

## Offsets (metres, relative to the quarry site) of the rock blocks.
const ROCK_OFFSETS: PackedVector2Array = [
	Vector2(0.0, 0.0),
	Vector2(3.0, 2.0),
	Vector2(-2.0, 3.0),
	Vector2(2.0, -3.0),
]
const FOREST_TREE_COUNT: int = 8
const GOLDEN_ANGLE: float = 2.39996323


var _current_time: float = 0.5


## Removes any previous world and builds the static scene for one day file (a parsed day_<n>.json dictionary).
func build_from_day(day: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_build_shore()
	_build_ocean()
	_build_lights()
	var piles: Array = day.get("piles", []) as Array
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
			rock_seed += ROCK_OFFSETS.size()
	set_time_of_day(_current_time)


## Returns the site node built for a pile id, or null when there is none.
func get_site(id: String) -> Node3D:
	return get_node_or_null(NodePath(SITE_PREFIX + id)) as Node3D


func get_sun() -> DirectionalLight3D:
	return get_node_or_null("Sun") as DirectionalLight3D


func get_environment_node() -> WorldEnvironment:
	return get_node_or_null("WorldEnvironment") as WorldEnvironment


## Drives the sun and the environment from the time of day, 0..1 (0 = midnight, 0.5 = noon).
func set_time_of_day(t: float) -> void:
	_current_time = clampf(t, 0.0, 1.0)
	if get_sun() == null:
		_build_lights()
	var sun: DirectionalLight3D = get_sun()
	var colour: Color = _sample_colour(_current_time)
	var energy: float = _sample_energy(_current_time)
	var elevation: float = sin(TAU * (_current_time - 0.25)) * SUN_ELEVATION_MAX_DEG
	sun.light_color = colour
	sun.light_energy = energy
	sun.rotation_degrees = Vector3(-elevation, 30.0, 0.0)

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
	var sand: MeshInstance3D = _mesh_node("Shore", MeshKit.box(Vector3(6.0, 0.5, SHORE_LENGTH), Palette.SHORE_SAND))
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
		"lumberjack":
			_add_forest(site, forest_seed)
		"lasher":
			_add_rope_works(site)
		"scribe":
			_add_lekhan(site)
		_:
			_add_pad(site)
	return site


func _add_quarry(site: Node3D, first_seed: int) -> void:
	for i: int in range(ROCK_OFFSETS.size()):
		var rock: MeshInstance3D = NatureKit.rock(Vector3(2.5, 1.8, 2.2), first_seed + i)
		var offset: Vector2 = ROCK_OFFSETS[i]
		rock.position = Vector3(offset.x, 0.0, offset.y)
		site.add_child(rock)


func _add_forest(site: Node3D, first_seed: int) -> void:
	for i: int in range(FOREST_TREE_COUNT):
		var radius: float = 3.0 + 2.0 * float(i % 3)
		var angle: float = float(i) * GOLDEN_ANGLE
		var tree: MeshInstance3D
		if i % 2 == 0:
			tree = NatureKit.ashoka_tree(first_seed + i, 6.0)
		else:
			tree = NatureKit.shimshapa_tree(first_seed + i, 7.0)
		tree.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		site.add_child(tree)


func _add_rope_works(site: Node3D) -> void:
	var shed: MeshInstance3D = _mesh_node("Shed", MeshKit.box(Vector3(2.0, 1.2, 2.0), Palette.BARK))
	shed.position = Vector3(0.0, 0.6, 0.0)
	site.add_child(shed)
	var coil: MeshInstance3D = _mesh_node("RopeCoil", MeshKit.cylinder(0.5, 0.5, 0.3, 12, Palette.ROPE))
	coil.position = Vector3(1.6, 0.15, 0.0)
	site.add_child(coil)


func _add_lekhan(site: Node3D) -> void:
	var table: MeshInstance3D = _mesh_node("Table", MeshKit.box(Vector3(2.0, 0.8, 1.4), Palette.BARK))
	table.position = Vector3(0.0, 0.4, 0.0)
	site.add_child(table)
	var stele: MeshInstance3D = _mesh_node("Stele", MeshKit.box(Vector3(0.4, 2.0, 0.4), Palette.WET_STONE))
	stele.position = Vector3(-1.0, 1.0, 0.0)
	site.add_child(stele)


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
