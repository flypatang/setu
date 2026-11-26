class_name WorldView
extends Node3D
## The painted coast of Setu (DESIGN §9 S15, S30; world art v2 per docs/ART.md, module S40).
##
## build_from_day(day) builds the static world for one day file:
##   "Land"     one terrain mesh: grass meadow with worn haul paths, blending into the beach and sloping under the sea;
##   "Shore"    the waterline dressing: washing foam (WaterKit.shoreline_foam), rocks in the shallows, driftwood;
##   "Ocean"    WaterKit.ocean tiles that share one wave phase and reach the whole 1 km bridge line;
##   "Site_<id>" one node per pile at its JSON position: the quarry (boulders, crag, cut rock face, cut-stone pile,
##              hoist), the forest (a grove of NatureKit trees with timber stacks), the rope-works (thatched shed,
##              coils, rope-walk) and the lekhan pavilion (carved pillars, lacquer roof, scribes' stones with "राम");
##   "Scenery"  seeded MultiMesh scatter (NatureKit v2 trees near the works, light trees far away, bushes, rocks,
##              grass tufts, flowers, palms), the hill line, the vanara camp and Rama's pavilion (Rama is not shown).
## Every surface uses a Materials kind (stone, wood, cloth, gold, lacquer, foliage).
##
## The lights and the environment are a Look rig ("WorldEnvironment", "Sun", "Fill", "BackRim") with a SkyKit sky.
## set_time_of_day(t) takes the fraction of the working day (the game passes tick / day_ticks: 0 = first light,
## 0.5 = noon, 1 = nightfall) and blends the Look moods dawn -> day -> dusk -> night; on a night-shift day (the day
## file's night_from) night falls at that tick. The sky, the water and the torches follow the same blend.
## Rendering only: it reads the day data and never writes to the simulation.

const SITE_PREFIX: String = "Site_"
const SHORE_LENGTH: float = 600.0
const LAND_WIDTH: float = 200.0
const SEA_WIDTH: float = 1280.0
const SEA_LEVEL: float = -0.3

## Terrain grid: fine cells over the works, coarse cells far away, and the beach sloping under the sea.
const LAND_X_MIN: float = -204.0
const LAND_FINE_X_MIN: float = -92.0
const LAND_FINE_Z: float = 80.0
const LAND_FINE_CELL: float = 1.25
const LAND_COARSE_CELL: float = 8.0
const SEA_BED_X: float = 34.0
const BEACH_SLOPE: float = 0.2
const BEACH_CURVE: float = 0.007
const SAND_EDGE_X: float = -7.0
const GROUND_KIND: StringName = &"stone"

## Ocean tiles along the bridge line (they share one local origin, so the waves run through seamlessly).
const OCEAN_TILES: int = 4
const OCEAN_X_MIN: float = 0.6
const FOAM_X: float = 3.1
const FOAM_WIDTH: float = 2.6

## Mood schedule over the working day (see _build_schedule) and the torch ramps.
const DAWN_HOLD_END: float = 0.10
const DAY_START: float = 0.22
const DUSK_BLEND_START: float = 0.74
const DUSK_FULL: float = 0.86
const DUSK_HOLD_END: float = 0.96
const NIGHT_FULL: float = 1.10
const NIGHT_SHIFT_MIN: float = 0.45
const TORCH_FADE_OUT_START: float = 0.05
const TORCH_FADE_OUT_END: float = 0.15
const TORCH_LEAD: float = 0.06
const TORCH_RAMP: float = 0.10
const TORCH_ENERGY: float = 5.0
const TORCH_RANGE: float = 12.0
const TORCH_OFFSET: Vector3 = Vector3(-3.4, 0.0, 3.4)
const TORCH_HEIGHT: float = 2.4
const SUN_YAW_SWING_DEG: float = 36.0
const SHADOW_MAX_DISTANCE: float = 300.0
const FOG_SCALE: float = 0.3

## Quarry layout: a ring of boulders around the site centre, a crag behind them and the cut face below it.
const ROCK_COUNT: int = 8
const ROCK_RING_RADIUS: float = 4.5
const CLIFF_OFFSET: Vector3 = Vector3(0.0, 0.0, -8.5)
const CLIFF_SIZE: Vector3 = Vector3(13.0, 7.5, 4.5)
const CUT_STONE_OFFSET: Vector3 = Vector3(5.4, 0.0, 3.6)
const ROCK_SEED_STRIDE: int = ROCK_COUNT + 1

## Forest layout: a grove of trees spread over a disc (Vogel distribution, so spacing stays even).
const FOREST_TREE_COUNT: int = 12
const FOREST_RADIUS: float = 10.0
const GOLDEN_ANGLE: float = 2.39996323

## Rope-works shed (site-local metres).
const SHED_POST_HEIGHT: float = 2.3
const SHED_HALF_SIZE: Vector2 = Vector2(2.2, 1.6)

## Lekhan pavilion and scribes' stones (site-local metres).
const CANOPY_HEIGHT: float = 3.1
const CANOPY_HALF_SIZE: Vector2 = Vector2(2.6, 2.0)
const STELE_SIZE: Vector3 = Vector3(1.1, 1.6, 0.4)
const STELE_XS: PackedFloat32Array = [-1.45, 0.0, 1.45]
const GLYPH_HEIGHT: float = 1.0

## Scenery scatter (S30, re-balanced for art v2): hero trees only near the works, light trees beyond.
const SCENERY_NAME: String = "Scenery"
const SCENERY_SEED: int = 3030
const SCATTER_X_MIN: float = -170.0
const SCATTER_X_MAX: float = -9.0
const SCATTER_Z_HALF: float = 120.0
const SITE_CLEARANCE: float = 11.0
const HAUL_CLEARANCE: float = 6.0
const CAMP_CLEARANCE: float = 13.0
const CORRIDOR_HALF_WIDTH: float = 4.5
const NEAR_CENTRE: Vector2 = Vector2(-36.0, 4.0)
const NEAR_RADII: Vector2 = Vector2(52.0, 66.0)
const HERO_TREE_COUNT: int = 14
const FAR_TREE_COUNT: int = 72
const ROCK_COUNT_SCATTER: int = 22
const BUSH_COUNT: int = 8
const GRASS_CLUMPS: int = 66
const GRASS_PER_CLUMP: int = 20
const FLOWER_COUNT: int = 26
const PALM_COUNT: int = 14
const PALM_X_MIN: float = -12.5
const PALM_X_MAX: float = -5.0
const SEA_ROCK_COUNT: int = 9
const HILL_COUNT: int = 8
const HILL_X: float = -186.0
const RAMA_CAMP_POS: Vector3 = Vector3(-16.0, 0.0, -62.0)
const VANARA_CAMP_POS: Vector3 = Vector3(-14.0, 0.0, 58.0)
const TENT_OFFSETS: PackedVector2Array = [
	Vector2(0.5, -6.0), Vector2(6.0, -2.5), Vector2(-5.5, -3.0), Vector2(4.0, 5.5), Vector2(-5.0, 5.0),
]
const PAVILION_HALF: Vector2 = Vector2(3.5, 2.8)
const PAVILION_POST_HEIGHT: float = 3.6

const TENT_CLOTH: Color = Color("#D9C7A0")
const KIND_STONE: StringName = &"stone"
const KIND_WOOD: StringName = &"wood"
const KIND_CLOTH: StringName = &"cloth"
const KIND_GOLD: StringName = &"gold"
const KIND_LACQUER: StringName = &"lacquer"
const KIND_FOLIAGE: StringName = &"foliage"

## One mood's reference values, read from a rig that Look.apply built for it.
class MoodRef extends RefCounted:
	var environment: Environment = null
	var key_color: Color = Color.WHITE
	var key_energy: float = 1.0
	var key_rotation: Vector3 = Vector3.ZERO
	var key_shaft: float = 1.0
	var fill_color: Color = Color.WHITE
	var fill_energy: float = 0.0
	var fill_rotation: Vector3 = Vector3.ZERO
	var rim_color: Color = Color.WHITE
	var rim_energy: float = 0.0
	var rim_rotation: Vector3 = Vector3.ZERO
	var sky: Dictionary[String, Variant] = {}
	var water: Dictionary[String, Variant] = {}


static var _mesh_cache: Dictionary[String, Mesh] = {}
static var _noise: FastNoiseLite = null
static var _env_props: PackedStringArray = PackedStringArray()

var _current_time: float = 0.5
var _torches: Array[OmniLight3D] = []
var _night_lights: Array[OmniLight3D] = []
var _night_lights_energy: PackedFloat32Array = PackedFloat32Array()
var _night_nodes: Array[Node3D] = []
var _scatter_points: Dictionary = {}
var _schedule_times: PackedFloat32Array = PackedFloat32Array()
var _schedule_moods: Array[StringName] = []
var _torch_in_start: float = DUSK_FULL - TORCH_LEAD
var _mood_refs: Dictionary[StringName, MoodRef] = {}
var _rig: Dictionary = {}
var _sky_material: ShaderMaterial = null
var _ocean_material: ShaderMaterial = null
var _foam_material: ShaderMaterial = null
var _applied_from: StringName = &""
var _applied_to: StringName = &""
var _applied_weight: float = -1.0
var _applied_time: float = -1.0
var _site_points: Array[Vector2] = []
var _path_points: Array[Vector2] = []


## Removes any previous world and builds the static scene for one day file (a parsed day_<n>.json dictionary).
func build_from_day(day: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_torches.clear()
	_night_lights.clear()
	_night_lights_energy.clear()
	_night_nodes.clear()
	_scatter_points.clear()
	_mood_refs.clear()
	_rig = {}
	_applied_weight = -1.0
	_applied_time = -1.0
	_build_schedule(day)
	var piles: Array = day.get("piles", []) as Array
	_site_points.clear()
	_path_points.clear()
	for raw: Variant in piles:
		var pile: Dictionary = raw as Dictionary
		var pos: Array = pile.get("pos", [0.0, 0.0]) as Array
		var point: Vector2 = Vector2(pos[0] as float, pos[1] as float)
		_site_points.append(point)
		if point.length() > 1.0:
			_path_points.append(point)
	_build_rig()
	_build_land()
	_build_ocean()
	_build_shore()
	_build_scenery()
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


## The node that holds the scenery (scattered trees, rocks, grass, flowers, palms, hills and the two camps).
func get_scenery() -> Node3D:
	return get_node_or_null(SCENERY_NAME) as Node3D


## World positions of every instance of a scatter kind: "Trees" (hero and far trees), "TreesNear", "TreesFar",
## "Rocks", "Bushes", "Grass", "Flowers", "Palms" or "SeaRocks".
## The headless renderer does not keep MultiMesh transforms, so the placement is recorded here too.
func get_scatter_points(kind: String) -> PackedVector3Array:
	return (_scatter_points.get(kind, PackedVector3Array()) as PackedVector3Array).duplicate()


func get_sun() -> DirectionalLight3D:
	return get_node_or_null(NodePath(String(Look.KEY_NAME))) as DirectionalLight3D


func get_environment_node() -> WorldEnvironment:
	return get_node_or_null(NodePath(String(Look.WORLD_ENVIRONMENT_NAME))) as WorldEnvironment


## The node that holds the ocean tiles.
func get_ocean() -> Node3D:
	return get_node_or_null(WaterKit.OCEAN_NAME) as Node3D


## The material shared by every ocean tile (a WaterKit ocean shader).
func get_ocean_material() -> ShaderMaterial:
	return _ocean_material


## The SkyKit sky material of the environment.
func get_sky_material() -> ShaderMaterial:
	return _sky_material


## Returns the torch lights built for the visible sites (quarry, forest, rope-works, lekhan).
func get_torches() -> Array[OmniLight3D]:
	return _torches.duplicate()


## The dominant Look mood at a time of day: &"dawn", &"day", &"dusk" or &"night".
func mood_at(t: float) -> StringName:
	var mix: Array = _mix_at(clampf(t, 0.0, 1.0))
	return (mix[0] as StringName) if (mix[2] as float) < 0.5 else (mix[1] as StringName)


## The two moods being blended at a time of day and the weight of the second: [from, to, weight 0..1].
func mood_mix_at(t: float) -> Array:
	return _mix_at(clampf(t, 0.0, 1.0))


## Height of the terrain at a world position (0 over the works, sloping under the sea, rising far inland).
func ground_height(x: float, z: float) -> float:
	return _ground_height(x, z)


## Drives the Look rig, the sky, the water and the torches from the time of day, 0..1 (the fraction of the
## working day: 0 = first light, 0.5 = noon, 1 = nightfall).
func set_time_of_day(t: float) -> void:
	_current_time = clampf(t, 0.0, 1.0)
	if _schedule_times.is_empty():
		_build_schedule({})
	if get_sun() == null or _rig.is_empty():
		_build_rig()
	if is_equal_approx(_applied_time, _current_time):
		return
	_applied_time = _current_time
	var mix: Array = _mix_at(_current_time)
	_apply_mix(mix[0] as StringName, mix[1] as StringName, mix[2] as float)
	var sun: DirectionalLight3D = get_sun()
	sun.rotation_degrees += Vector3(0.0, (_current_time - 0.5) * SUN_YAW_SWING_DEG, 0.0)

	var strength: float = _torch_strength(_current_time)
	for torch: OmniLight3D in _torches:
		torch.light_energy = strength * TORCH_ENERGY
	for i: int in range(_night_lights.size()):
		_night_lights[i].light_energy = strength * _night_lights_energy[i]
	for node: Node3D in _night_nodes:
		node.visible = strength > 0.02


# --- time of day ------------------------------------------------------------------------------------------------

## Mood keys over the day. Between two keys of the same mood it holds; between different moods it blends.
func _build_schedule(day: Dictionary) -> void:
	var day_ticks: float = float(day.get("day_ticks", 9600) as int)
	var night_from: int = day.get("night_from", -1) as int
	_schedule_times = PackedFloat32Array([0.0, DAWN_HOLD_END, DAY_START])
	_schedule_moods = [&"dawn", &"dawn", &"day"]
	var dusk_full: float = DUSK_FULL
	if night_from >= 0 and day_ticks > 0.0:
		var night: float = clampf(float(night_from) / day_ticks, NIGHT_SHIFT_MIN, 1.0)
		dusk_full = night - 0.08
		_schedule_times.append_array(PackedFloat32Array([night - 0.17, dusk_full, night - 0.04, night + 0.02, NIGHT_FULL]))
		_schedule_moods.append_array([&"day", &"dusk", &"dusk", &"night", &"night"] as Array[StringName])
	else:
		_schedule_times.append_array(PackedFloat32Array([DUSK_BLEND_START, DUSK_FULL, DUSK_HOLD_END, NIGHT_FULL]))
		_schedule_moods.append_array([&"day", &"dusk", &"dusk", &"night"] as Array[StringName])
	_torch_in_start = dusk_full - TORCH_LEAD


func _mix_at(t: float) -> Array:
	if _schedule_times.is_empty():
		_build_schedule({})
	var index: int = 0
	for k: int in range(_schedule_times.size() - 1):
		if t >= _schedule_times[k]:
			index = k
	var from: StringName = _schedule_moods[index]
	var to: StringName = _schedule_moods[index + 1]
	if from == to:
		return [from, to, 0.0]
	var span: float = _schedule_times[index + 1] - _schedule_times[index]
	var weight: float = clampf((t - _schedule_times[index]) / maxf(span, 0.0001), 0.0, 1.0)
	return [from, to, smoothstep(0.0, 1.0, weight)]


## Torch strength 0..1: lit at first light, out by mid-morning, and rising again as dusk settles.
func _torch_strength(t: float) -> float:
	var morning: float = clampf((TORCH_FADE_OUT_END - t) / (TORCH_FADE_OUT_END - TORCH_FADE_OUT_START), 0.0, 1.0)
	var evening: float = clampf((t - _torch_in_start) / TORCH_RAMP, 0.0, 1.0)
	return maxf(morning, evening)


## Builds the live rig with Look.apply and gives it a SkyKit sky. The per-mood values are blended in afterwards.
func _build_rig() -> void:
	_rig = Look.apply(&"day", self, &"")
	var environment: Environment = _rig["environment"] as Environment
	var sky: Sky = SkyKit.make_sky(&"day")
	_sky_material = sky.sky_material as ShaderMaterial
	environment.sky = sky
	var sun: DirectionalLight3D = _rig["key"] as DirectionalLight3D
	# The iso camera stands 200 m from the ground, so the shadow range must reach past it.
	sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = false
	sun.light_angular_distance = 0.0
	sun.shadow_blur = 1.0
	# The camera looks through a constant 200 m of air, so volumetrics never reach the ground and depth fog is a
	# flat veil: keep only a thin haze.
	environment.volumetric_fog_enabled = false
	_applied_weight = -1.0
	_applied_time = -1.0


## The reference values of a mood: a throwaway rig built by Look.apply (so the graphics preset is respected).
func _mood_ref(mood: StringName) -> MoodRef:
	if _mood_refs.has(mood):
		return _mood_refs[mood]
	var holder: Node3D = Node3D.new()
	var rig: Dictionary = Look.apply(mood, holder, &"")
	var ref: MoodRef = MoodRef.new()
	ref.environment = rig["environment"] as Environment
	var key: DirectionalLight3D = rig["key"] as DirectionalLight3D
	var fill: DirectionalLight3D = rig["fill"] as DirectionalLight3D
	var rim: DirectionalLight3D = rig["rim"] as DirectionalLight3D
	ref.key_color = key.light_color
	ref.key_energy = key.light_energy
	ref.key_rotation = key.rotation_degrees
	ref.key_shaft = key.light_volumetric_fog_energy
	ref.fill_color = fill.light_color
	ref.fill_energy = fill.light_energy
	ref.fill_rotation = fill.rotation_degrees
	ref.rim_color = rim.light_color
	ref.rim_energy = rim.light_energy
	ref.rim_rotation = rim.rotation_degrees
	ref.sky = SkyKit.mood_params(mood)
	ref.water = WaterKit.mood_params(mood)
	holder.free()
	_mood_refs[mood] = ref
	return ref


func _apply_mix(from: StringName, to: StringName, weight: float) -> void:
	if from == _applied_from and to == _applied_to and is_equal_approx(weight, _applied_weight):
		# Only the sun's yaw swing changes inside a hold: restore the mood's rotation for the caller to offset.
		var held: MoodRef = _mood_ref(from)
		var held_to: MoodRef = _mood_ref(to)
		get_sun().rotation_degrees = held.key_rotation.lerp(held_to.key_rotation, weight)
		return
	_applied_from = from
	_applied_to = to
	_applied_weight = weight
	var a: MoodRef = _mood_ref(from)
	var b: MoodRef = _mood_ref(to)
	var sun: DirectionalLight3D = _rig["key"] as DirectionalLight3D
	sun.light_color = a.key_color.lerp(b.key_color, weight)
	sun.light_energy = lerpf(a.key_energy, b.key_energy, weight)
	sun.rotation_degrees = a.key_rotation.lerp(b.key_rotation, weight)
	sun.light_volumetric_fog_energy = lerpf(a.key_shaft, b.key_shaft, weight)
	var fill: DirectionalLight3D = _rig["fill"] as DirectionalLight3D
	fill.light_color = a.fill_color.lerp(b.fill_color, weight)
	fill.light_energy = lerpf(a.fill_energy, b.fill_energy, weight)
	fill.rotation_degrees = a.fill_rotation.lerp(b.fill_rotation, weight)
	var rim: DirectionalLight3D = _rig["rim"] as DirectionalLight3D
	rim.light_color = a.rim_color.lerp(b.rim_color, weight)
	rim.light_energy = lerpf(a.rim_energy, b.rim_energy, weight)
	rim.rotation_degrees = a.rim_rotation.lerp(b.rim_rotation, weight)

	var environment: Environment = _rig["environment"] as Environment
	for prop: String in _environment_props(a.environment):
		var va: Variant = a.environment.get(prop)
		var vb: Variant = b.environment.get(prop)
		if va is float:
			var value: float = lerpf(va as float, vb as float, weight)
			environment.set(prop, value * FOG_SCALE if prop == "fog_density" else value)
		else:
			environment.set(prop, (va as Color).lerp(vb as Color, weight))
	_blend_params(_sky_material, a.sky, b.sky, weight)
	_blend_params(_ocean_material, a.water, b.water, weight)
	if _foam_material != null:
		var foam_a: Color = a.water["foam_colour"] as Color
		_foam_material.set_shader_parameter("foam_colour", foam_a.lerp(b.water["foam_colour"] as Color, weight))


## Names of the float and colour properties of an Environment (the values a mood can change).
static func _environment_props(sample: Environment) -> PackedStringArray:
	if _env_props.is_empty():
		for info: Dictionary in sample.get_property_list():
			var usage: int = info["usage"] as int
			var type: int = info["type"] as int
			if (usage & PROPERTY_USAGE_STORAGE) == 0:
				continue
			if type == TYPE_FLOAT or type == TYPE_COLOR:
				_env_props.append(info["name"] as String)
	return _env_props


static func _blend_params(material: ShaderMaterial, a: Dictionary[String, Variant], b: Dictionary[String, Variant],
		weight: float) -> void:
	if material == null:
		return
	for key: String in a:
		var va: Variant = a[key]
		var vb: Variant = b.get(key, va)
		if va is float and vb is float:
			material.set_shader_parameter(key, lerpf(va as float, vb as float, weight))
		elif va is Color and vb is Color:
			material.set_shader_parameter(key, (va as Color).lerp(vb as Color, weight))
		else:
			material.set_shader_parameter(key, va if weight < 0.5 else vb)


# --- terrain, sea and shore -------------------------------------------------------------------------------------

static func _noise01(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = SCENERY_SEED
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.fractal_octaves = 3
	return _noise.get_noise_2d(x, z) * 0.5 + 0.5


## Flat (y = 0) over the works so the crowd stands on it; the beach slopes under the sea, and the land swells
## gently far inland and along the far ends of the shore.
static func _ground_height(x: float, z: float) -> float:
	if x > 0.0:
		return -BEACH_SLOPE * x - BEACH_CURVE * x * x
	var inland: float = smoothstep(-100.0, -190.0, x)
	var along: float = smoothstep(135.0, 230.0, absf(z)) * smoothstep(-10.0, -40.0, x)
	var swell: float = maxf(inland, along)
	if swell <= 0.0:
		return 0.0
	return swell * (0.8 + 3.2 * _noise01(x * 0.021, z * 0.021)) + inland * inland * 7.0


func _ground_colour(x: float, z: float) -> Color:
	var p: Vector2 = Vector2(x, z)
	var broad: float = _noise01(x * 0.018, z * 0.018)
	var fine: float = _noise01(x * 0.11 + 40.0, z * 0.11 - 17.0)
	var meadow: Color = Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.30)
	var grass: Color = Palette.LEAF_DARK.lerp(Palette.GROVE_GREEN, 0.55).lerp(meadow, smoothstep(0.3, 0.75, broad))
	grass = grass.lerp(Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.5), smoothstep(0.62, 0.9, fine) * 0.45)
	var mottle: float = _noise01(x * 0.37 - 11.0, z * 0.37 + 5.0)
	grass = grass.lerp(Palette.LEAF_DARK, smoothstep(0.55, 0.85, mottle) * 0.3).lerp(meadow, smoothstep(0.45, 0.15, mottle) * 0.25)
	var earth: Color = Palette.SHORE_SAND.lerp(Palette.BARK, 0.48)
	# Worn earth along the haul routes (site to bridge head) and around the sites.
	var worn: float = 0.0
	for site: Vector2 in _path_points:
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(p, site, Vector2.ZERO)
		var width: float = 1.5 + 1.4 * fine
		worn = maxf(worn, smoothstep(width + 1.6, width - 0.4, p.distance_to(nearest)) * 0.85)
		worn = maxf(worn, smoothstep(9.0, 4.0, p.distance_to(site)) * (0.55 + 0.3 * fine))
	worn = maxf(worn, smoothstep(11.0, 5.0, p.distance_to(Vector2(VANARA_CAMP_POS.x, VANARA_CAMP_POS.z))) * 0.7)
	var colour: Color = grass.lerp(earth, worn)
	# The beach: dry sand, darker and cooler where the swash wets it.
	var edge: float = SAND_EDGE_X + 5.0 * (_noise01(z * 0.035, 9.0) - 0.5) + 1.5 * (fine - 0.5)
	var sand: Color = Palette.SHORE_SAND.lerp(Palette.GOLD, 0.12).darkened(0.12 + 0.08 * fine)
	var wet: Color = Palette.SHORE_SAND.lerp(Palette.BARK, 0.32).lerp(Palette.DEEP_OCEAN, 0.12)
	sand = sand.lerp(wet, smoothstep(0.2, 3.4, x))
	colour = colour.lerp(sand, smoothstep(edge - 4.5, edge + 0.5, x))
	# Far hills fade toward a cooler green so the land recedes.
	var far: float = smoothstep(-120.0, -200.0, x)
	colour = colour.lerp(Palette.LEAF_DARK.lerp(Palette.DEEP_OCEAN, 0.25), far * 0.5)
	return Color(colour.r, colour.g, colour.b, 0.0)


static func _grid_lines(from: float, fine_from: float, fine_to: float, to: float, coarse: float, coarse_to: float) -> PackedFloat32Array:
	var lines: PackedFloat32Array = PackedFloat32Array()
	var v: float = from
	while v < fine_from - 0.001:
		lines.append(v)
		v = minf(v + coarse, fine_from)
	v = fine_from
	while v < fine_to - 0.001:
		lines.append(v)
		v += LAND_FINE_CELL
	v = fine_to
	while v < to - 0.001:
		lines.append(v)
		v = minf(v + coarse_to, to)
	lines.append(to)
	return lines


func _build_land() -> void:
	var key: String = "land:%s" % var_to_str(_site_points)
	var mesh: Mesh = _mesh_cache.get(key) as Mesh
	if mesh == null:
		mesh = _land_mesh()
		_mesh_cache[key] = mesh
	var land: MeshInstance3D = MeshInstance3D.new()
	land.name = "Land"
	land.mesh = mesh
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)


func _land_mesh() -> ArrayMesh:
	var xs: PackedFloat32Array = _grid_lines(LAND_X_MIN, LAND_FINE_X_MIN, 4.0, SEA_BED_X, LAND_COARSE_CELL, 3.0)
	var zs: PackedFloat32Array = _grid_lines(-SHORE_LENGTH * 0.5, -LAND_FINE_Z, LAND_FINE_Z, SHORE_LENGTH * 0.5,
		LAND_COARSE_CELL, LAND_COARSE_CELL)
	var nx: int = xs.size()
	var nz: int = zs.size()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colours: PackedColorArray = PackedColorArray()
	vertices.resize(nx * nz)
	normals.resize(nx * nz)
	colours.resize(nx * nz)
	for i: int in range(nx):
		for j: int in range(nz):
			var x: float = xs[i]
			var z: float = zs[j]
			var h: float = _ground_height(x, z)
			var slope_x: float = (_ground_height(x + 0.5, z) - _ground_height(x - 0.5, z))
			var slope_z: float = (_ground_height(x, z + 0.5) - _ground_height(x, z - 0.5))
			vertices[i * nz + j] = Vector3(x, h, z)
			normals[i * nz + j] = Vector3(-slope_x, 1.0, -slope_z).normalized()
			colours[i * nz + j] = _ground_colour(x, z)
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in range(nx - 1):
		for j: int in range(nz - 1):
			var a: int = i * nz + j
			var b: int = (i + 1) * nz + j
			var c: int = i * nz + j + 1
			var d: int = (i + 1) * nz + j + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_name(0, String(GROUND_KIND))
	mesh.surface_set_material(0, Materials.get_material(GROUND_KIND))
	return mesh


func _build_ocean() -> void:
	var ocean: Node3D = Node3D.new()
	ocean.name = WaterKit.OCEAN_NAME
	ocean.position = Vector3(0.0, SEA_LEVEL, 0.0)
	add_child(ocean)
	var depth_effects: bool = Look.resolve_preset(&"") != &"low"
	var tile_width: float = SEA_WIDTH / float(OCEAN_TILES)
	_ocean_material = null
	for i: int in range(OCEAN_TILES):
		var tile: MeshInstance3D = WaterKit.ocean(Vector2(tile_width, SHORE_LENGTH), &"day", 1.0, depth_effects)
		tile.name = "Tile%d" % i
		# Every tile keeps the same node origin (the wave phase is local) and only shifts its plane.
		(tile.mesh as PlaneMesh).center_offset = Vector3(OCEAN_X_MIN + tile_width * (float(i) + 0.5), 0.0, 0.0)
		if _ocean_material == null:
			_ocean_material = tile.material_override as ShaderMaterial
		else:
			tile.material_override = _ocean_material
		ocean.add_child(tile)


func _build_shore() -> void:
	var shore: Node3D = Node3D.new()
	shore.name = "Shore"
	add_child(shore)
	var foam: MeshInstance3D = WaterKit.shoreline_foam(SHORE_LENGTH, FOAM_WIDTH, &"day")
	# The strip runs along local x with the land on its +z side: turn it so the land lies toward -x.
	foam.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	foam.position = Vector3(FOAM_X, SEA_LEVEL + 0.05, 0.0)
	_foam_material = foam.material_override as ShaderMaterial
	shore.add_child(foam)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED + 77
	var rock_meshes: Array[Mesh] = [_rock_mesh(Vector3(2.4, 1.8, 2.0), 51), _rock_mesh(Vector3(1.6, 1.3, 1.9), 52)]
	var buckets: Array[Array] = [[], []]
	var recorded: PackedVector3Array = PackedVector3Array()
	for i: int in range(SEA_ROCK_COUNT):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z: float = side * rng.randf_range(16.0, 150.0)
		var x: float = rng.randf_range(4.0, 22.0)
		var factor: float = rng.randf_range(0.8, 1.7)
		var rot: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * factor)
		var xf: Transform3D = Transform3D(rot, Vector3(x, _ground_height(x, z) + 0.45 * factor, z))
		buckets[i % 2].append(xf)
		recorded.append(xf.origin)
	_scatter_points["SeaRocks"] = recorded
	for k: int in range(rock_meshes.size()):
		_add_multimesh(shore, "SeaRocks%d" % k, rock_meshes[k], buckets[k])

	# Driftwood on the sand.
	var parts: Dictionary = {}
	for i: int in range(5):
		var z: float = rng.randf_range(-110.0, 110.0)
		if absf(z) < 9.0:
			z += 18.0 * signf(z + 0.01)
		var length: float = rng.randf_range(1.6, 3.4)
		var log_mesh: ArrayMesh = MeshKit.cylinder_smooth(0.11, 0.17, length, 7, Palette.BARK.lerp(Palette.MOON, 0.35))
		var rot: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.08, 0.08))
		_put(parts, KIND_WOOD, log_mesh, Vector3(rng.randf_range(-4.0, 0.5), 0.14, z), rot)
	shore.add_child(_multi_node("Driftwood", parts))


# --- sites ------------------------------------------------------------------------------------------------------

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
		"builder":
			_add_bridge_gate(site)
		_:
			_add_pad(site)
	return site


func _add_quarry(site: Node3D, first_seed: int) -> void:
	for i: int in range(ROCK_COUNT):
		var angle: float = float(i) * GOLDEN_ANGLE + 0.9
		var radius: float = 2.2 + ROCK_RING_RADIUS * sqrt((float(i) + 0.5) / float(ROCK_COUNT))
		var size: Vector3 = Vector3(1.6 + 0.4 * float(i % 3), 1.2 + 0.3 * float(i % 2), 1.5 + 0.2 * float(i % 4))
		var rock: MeshInstance3D = NatureKit.rock(size, first_seed + i)
		rock.name = "Rock%d" % i
		rock.position = Vector3(cos(angle) * radius, size.y * 0.4, sin(angle) * radius - 1.0)
		site.add_child(rock)
	var cliff: MeshInstance3D = NatureKit.cliff(CLIFF_SIZE, first_seed + ROCK_COUNT)
	cliff.name = "Cliff"
	cliff.position = CLIFF_OFFSET
	site.add_child(cliff)
	for side: float in [-1.0, 1.0]:
		var crag: MeshInstance3D = NatureKit.cliff(Vector3(7.0, 4.2 + 0.8 * side, 3.4), first_seed + ROCK_COUNT + 3 + int(side))
		crag.name = "Crag%d" % site.get_child_count()
		crag.position = CLIFF_OFFSET + Vector3(side * 8.2, 0.0, 2.2)
		crag.rotation.y = -side * 0.75
		site.add_child(crag)

	# The worked face: benches of squared blocks stepping down from the crag, with chisel-fresh pale stone.
	var face: Dictionary = {}
	var pale: Color = Palette.STONE.lerp(Palette.MOON, 0.35)
	for tier: int in range(3):
		var blocks: int = 5 - tier
		var depth: float = 1.5
		var height: float = 1.0
		for k: int in range(blocks):
			var width: float = 1.7 + 0.35 * float((k + tier) % 3)
			var x: float = (float(k) - float(blocks - 1) * 0.5) * 2.1 + 0.25 * float(tier)
			var colour: Color = Palette.STONE.lerp(pale, 0.25 + 0.3 * float((k * 2 + tier) % 3)).lerp(Palette.WET_STONE, 0.18 * float(tier))
			_put(face, KIND_STONE, MeshKit.bevel_box(Vector3(width, height, depth), 0.07, colour),
				Vector3(x, height * (float(tier) + 0.5), CLIFF_OFFSET.z + 3.6 - 1.1 * float(tier)),
				Basis(Vector3.UP, 0.05 * float((k + tier) % 3 - 1)))
	site.add_child(_multi_node("QuarryFace", face))

	# Cut stones stacked for the haulers, on timber skids.
	var pile: Dictionary = {}
	var courses: Array[Vector3] = [Vector3(2.8, 0.62, 1.9), Vector3(2.2, 0.6, 1.5), Vector3(1.5, 0.58, 1.15)]
	var height_sum: float = 0.18
	for i: int in range(courses.size()):
		var size: Vector3 = courses[i]
		_put(pile, KIND_STONE, MeshKit.bevel_box(size, 0.06, Palette.STONE.lerp(pale, 0.2 + 0.25 * float(i))),
			Vector3(0.0, height_sum + size.y * 0.5, 0.0), Basis(Vector3.UP, 0.12 * float(i) - 0.1))
		height_sum += size.y
	for sz: float in [-0.6, 0.6]:
		_put(pile, KIND_WOOD, MeshKit.cylinder_smooth(0.09, 0.09, 3.2, 7, Palette.BARK), Vector3(0.0, 0.09, sz),
			Basis(Vector3.BACK, PI * 0.5))
	var cut: MeshInstance3D = _multi_node("CutStone", pile)
	cut.position = CUT_STONE_OFFSET
	site.add_child(cut)

	# A timber hoist: three poles lashed at the top with a block hanging on a rope.
	var hoist: Dictionary = {}
	var apex: Vector3 = Vector3(0.0, 4.0, 0.0)
	for i: int in range(3):
		var foot: Vector3 = Vector3(cos(TAU * float(i) / 3.0) * 1.5, 0.0, sin(TAU * float(i) / 3.0) * 1.5)
		_put_beam(hoist, KIND_WOOD, foot, apex + (apex - foot).normalized() * 0.35, 0.09, Palette.BARK)
	_put(hoist, KIND_CLOTH, MeshKit.cylinder_smooth(0.025, 0.025, 2.2, 5, _a(Palette.ROPE, 0.0)), Vector3(0.0, 2.85, 0.0))
	_put(hoist, KIND_CLOTH, MeshKit.cylinder_smooth(0.16, 0.16, 0.28, 8, _a(Palette.ROPE, 0.0)), Vector3(0.0, 3.95, 0.0))
	_put(hoist, KIND_STONE, MeshKit.bevel_box(Vector3(0.9, 0.7, 0.8), 0.06, pale), Vector3(0.0, 1.4, 0.0), Basis(Vector3.UP, 0.4))
	var hoist_node: MeshInstance3D = _multi_node("Hoist", hoist)
	hoist_node.position = Vector3(-4.6, 0.0, 3.6)
	site.add_child(hoist_node)


func _add_forest(site: Node3D, first_seed: int) -> void:
	for i: int in range(FOREST_TREE_COUNT):
		var radius: float = 4.2 + (FOREST_RADIUS - 4.2) * sqrt((float(i) + 0.5) / float(FOREST_TREE_COUNT))
		var angle: float = float(i) * GOLDEN_ANGLE
		var tree: MeshInstance3D
		if i % 2 == 0:
			tree = NatureKit.ashoka_tree(first_seed + i, 6.0)
		else:
			tree = NatureKit.shimshapa_tree(first_seed + i, 7.0)
		tree.name = "Tree%d" % i
		tree.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		tree.rotation.y = float(i) * 1.7
		site.add_child(tree)

	# Felled timber stacked in pyramids at the edge of the clearing, and a few stumps.
	var ends: Color = Palette.SHORE_SAND.lerp(Palette.BARK, 0.25)
	var stack_spots: Array[Vector3] = [Vector3(1.5, 0.0, 1.6), Vector3(-1.2, 0.0, -1.5)]
	for s: int in range(stack_spots.size()):
		var stack: Dictionary = {}
		var row_counts: Array[int] = [4, 3, 2]
		for row: int in range(row_counts.size()):
			for k: int in range(row_counts[row]):
				var r: float = 0.24
				var z: float = (float(k) - float(row_counts[row] - 1) * 0.5) * r * 2.05
				var centre: Vector3 = Vector3(0.05 * float((k + row) % 3), r + float(row) * r * 1.75, z)
				var bark: Color = Palette.BARK.lerp(Palette.HANUMAN_FUR, 0.12 * float((k + row) % 3))
				_put(stack, KIND_WOOD, MeshKit.cylinder_smooth(r, r, 3.0, 9, bark), centre, Basis(Vector3.BACK, PI * 0.5))
				for sx: float in [-1.0, 1.0]:
					_put(stack, KIND_WOOD, MeshKit.cylinder_smooth(r * 0.86, r * 0.86, 0.04, 9, ends),
						centre + Vector3(sx * 1.51, 0.0, 0.0), Basis(Vector3.BACK, PI * 0.5))
		for sz: float in [-1.05, 1.05]:
			_put(stack, KIND_WOOD, MeshKit.cylinder_smooth(0.07, 0.08, 1.5, 6, Palette.BARK), Vector3(0.9, 0.75, sz))
			_put(stack, KIND_WOOD, MeshKit.cylinder_smooth(0.07, 0.08, 1.5, 6, Palette.BARK), Vector3(-0.9, 0.75, sz))
		var node: MeshInstance3D = _multi_node("TimberStack%d" % s, stack)
		node.position = stack_spots[s]
		node.rotation.y = 0.5 + 1.1 * float(s)
		site.add_child(node)
	var stumps: Dictionary = {}
	for i: int in range(4):
		var a: float = 0.8 + float(i) * 1.9
		var at: Vector3 = Vector3(cos(a) * 2.9, 0.22, sin(a) * 2.9)
		_put(stumps, KIND_WOOD, MeshKit.cylinder_smooth(0.32, 0.42, 0.44, 10, Palette.BARK), at)
		_put(stumps, KIND_WOOD, MeshKit.cylinder_smooth(0.29, 0.29, 0.03, 10, ends), at + Vector3(0.0, 0.225, 0.0))
	site.add_child(_multi_node("Stumps", stumps))
	var petals: Node3D = Vfx.petals(AABB(Vector3(-9.0, 0.5, -9.0), Vector3(18.0, 6.0, 18.0)), Palette.ASHOKA_RED)
	petals.name = "Petals"
	site.add_child(petals)


func _add_rope_works(site: Node3D) -> void:
	var half: Vector2 = SHED_HALF_SIZE
	var straw: Color = _a(Palette.ROPE.lerp(Palette.GOLD, 0.35), 0.0)
	var rope: Color = _a(Palette.ROPE, 0.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post_parts: Dictionary = {}
			_put(post_parts, KIND_WOOD, MeshKit.cylinder_smooth(0.1, 0.13, SHED_POST_HEIGHT, 8, Palette.BARK),
				Vector3(0.0, SHED_POST_HEIGHT * 0.5, 0.0))
			_put(post_parts, KIND_CLOTH, MeshKit.cylinder_smooth(0.135, 0.135, 0.14, 8, rope), Vector3(0.0, SHED_POST_HEIGHT - 0.25, 0.0))
			var post: MeshInstance3D = _multi_node("ShedPost%d" % site.get_child_count(), post_parts)
			post.position = Vector3(sx * half.x, 0.0, sz * half.y)
			site.add_child(post)

	# A woven back wall: rails with upright slats.
	var back: Dictionary = {}
	for y: float in [0.35, 1.25]:
		_put(back, KIND_WOOD, MeshKit.cylinder_smooth(0.06, 0.06, half.x * 2.0, 6, Palette.BARK), Vector3(0.0, y, 0.0), Basis(Vector3.BACK, PI * 0.5))
	for k: int in range(11):
		var x: float = lerpf(-half.x + 0.2, half.x - 0.2, float(k) / 10.0)
		var slat: Color = Palette.ROPE.lerp(Palette.BARK, 0.25 + 0.3 * float(k % 3) * 0.5)
		_put(back, KIND_WOOD, MeshKit.bevel_box(Vector3(0.3, 1.5, 0.05), 0.015, slat), Vector3(x, 0.8, 0.03 * float(k % 2)))
	var back_node: MeshInstance3D = _multi_node("ShedBack", back)
	back_node.position = Vector3(0.0, 0.0, -half.y)
	site.add_child(back_node)

	# A pitched thatch roof in overlapping courses, with a ridge pole.
	var roof: Dictionary = {}
	var pitch: float = 0.5
	for side: float in [-1.0, 1.0]:
		for course: int in range(3):
			var t: float = float(course) / 3.0
			var run: float = (half.y + 0.7) / 3.0 + 0.2
			var centre_z: float = side * (half.y + 0.7) * (1.0 - t - 1.0 / 6.0)
			var centre_y: float = SHED_POST_HEIGHT + 0.12 + (t + 1.0 / 6.0) * (half.y + 0.7) * tan(pitch) + 0.03 * float(course)
			var tint: Color = _a(Palette.ROPE.lerp(Palette.GOLD, 0.25 + 0.12 * float(course)), 0.0)
			_put(roof, KIND_CLOTH, MeshKit.bevel_box(Vector3(half.x * 2.0 + 1.0 - 0.1 * float(course), 0.14, run / cos(pitch)), 0.04, tint),
				Vector3(0.0, centre_y, centre_z), Basis(Vector3.RIGHT, side * pitch))
	var ridge_y: float = SHED_POST_HEIGHT + 0.2 + (half.y + 0.7) * tan(pitch)
	_put(roof, KIND_WOOD, MeshKit.cylinder_smooth(0.09, 0.09, half.x * 2.0 + 1.3, 7, Palette.BARK), Vector3(0.0, ridge_y, 0.0), Basis(Vector3.BACK, PI * 0.5))
	for sz: float in [-1.0, 1.0]:
		_put(roof, KIND_WOOD, MeshKit.cylinder_smooth(0.07, 0.07, half.x * 2.0 + 0.4, 6, Palette.BARK),
			Vector3(0.0, SHED_POST_HEIGHT + 0.03, sz * half.y), Basis(Vector3.BACK, PI * 0.5))
	site.add_child(_multi_node("ShedRoof", roof))

	# Finished coils stacked beside the shed and under the roof.
	var coil_spots: Array[Vector3] = [Vector3(3.3, 0.0, 0.3), Vector3(3.0, 0.0, 1.6), Vector3(-0.9, 0.0, -0.4), Vector3(0.9, 0.0, 0.2)]
	for i: int in range(coil_spots.size()):
		var coil: Dictionary = {}
		var loops: int = 3 + i % 2
		var st: SurfaceTool = _tool()
		for k: int in range(loops):
			var radius: float = 0.5 - 0.035 * float(k)
			_ring(st, Vector3(0.0, 0.1 + 0.17 * float(k), 0.0), radius, 0.1, 14, 6, _a(Palette.ROPE.lerp(Palette.GOLD, 0.08 * float(k)), 0.0))
		_put(coil, KIND_CLOTH, _commit([KIND_CLOTH], [st]), Vector3.ZERO)
		var coil_node: MeshInstance3D = _multi_node("RopeCoil%d" % i, coil)
		coil_node.position = coil_spots[i]
		site.add_child(coil_node)

	# The rope-walk: strands stretched between two trestles, sagging a little, with fibre hanging to dry.
	var walk: Dictionary = {}
	var st_walk: SurfaceTool = _tool()
	var from_x: float = -3.2
	var to_x: float = 3.6
	var walk_z: float = 3.4
	for end_x: float in [from_x, to_x]:
		for lean: float in [-1.0, 1.0]:
			_put_beam(walk, KIND_WOOD, Vector3(end_x, 0.0, walk_z + lean * 0.55), Vector3(end_x, 1.5, walk_z - lean * 0.08), 0.06, Palette.BARK)
		_put(walk, KIND_WOOD, MeshKit.cylinder_smooth(0.05, 0.05, 1.2, 6, Palette.BARK), Vector3(end_x, 1.36, walk_z), Basis(Vector3.RIGHT, PI * 0.5))
	for strand: int in range(4):
		var z: float = walk_z + (float(strand) - 1.5) * 0.26
		var points: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for k: int in range(9):
			var t: float = float(k) / 8.0
			points.append(Vector3(lerpf(from_x, to_x, t), 1.38 - 0.22 * sin(PI * t) * (1.0 + 0.2 * float(strand % 2)), z))
			radii.append(0.028)
		_tube(st_walk, points, radii, 5, rope, Vector3.UP, false)
	_put(walk, KIND_CLOTH, _commit([KIND_CLOTH], [st_walk]), Vector3.ZERO)
	for k: int in range(7):
		var x: float = lerpf(from_x + 0.6, to_x - 0.6, float(k) / 6.0)
		var length: float = 0.7 + 0.2 * float(k % 3)
		var fibre: ArrayMesh = MeshKit.wind_weighted(MeshKit.box(Vector3(0.16, length, 0.03), straw), length * 0.5, -length * 0.5)
		_put(walk, KIND_CLOTH, fibre, Vector3(x, 1.2 - length * 0.5, walk_z - 0.4))
	site.add_child(_multi_node("RopeWalk", walk))


func _add_lekhan(site: Node3D) -> void:
	var half: Vector2 = CANOPY_HALF_SIZE
	var pale: Color = Palette.STONE.lerp(Palette.MOON, 0.45)
	# A two-step stone plinth.
	var plinth: Dictionary = {}
	_put(plinth, KIND_STONE, MeshKit.bevel_box(Vector3(half.x * 2.0 + 1.6, 0.16, half.y * 2.0 + 1.6), 0.05, Palette.STONE.lerp(Palette.WET_STONE, 0.3)),
		Vector3(0.0, 0.08, 0.0))
	_put(plinth, KIND_STONE, MeshKit.bevel_box(Vector3(half.x * 2.0 + 0.9, 0.16, half.y * 2.0 + 0.9), 0.05, Palette.STONE), Vector3(0.0, 0.24, 0.0))
	site.add_child(_multi_node("Plinth", plinth))
	var floor_y: float = 0.32
	var index: int = 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pillar: MeshInstance3D = _pillar_node("Pillar%d" % index, CANOPY_HEIGHT - floor_y, 0.17, pale)
			pillar.position = Vector3(sx * half.x, floor_y, sz * half.y)
			site.add_child(pillar)
			index += 1

	# The canopy: carved lintels, a red lacquer roof in two tiers with gold edges and a kalasha finial.
	var canopy: Dictionary = {}
	_put_roof(canopy, Vector3(0.0, CANOPY_HEIGHT, 0.0), half, pale, 1.0)
	site.add_child(_multi_node("Canopy", canopy))

	var stele_depth: float = STELE_SIZE.z
	for x: float in STELE_XS:
		var stele_parts: Dictionary = {}
		_put(stele_parts, KIND_STONE, MeshKit.bevel_box(STELE_SIZE, 0.07, Palette.STONE.lerp(Palette.MOON, 0.25)), Vector3.ZERO)
		_put(stele_parts, KIND_STONE, MeshKit.bevel_box(Vector3(STELE_SIZE.x + 0.24, 0.18, STELE_SIZE.z + 0.24), 0.04, Palette.WET_STONE),
			Vector3(0.0, -STELE_SIZE.y * 0.5 + 0.09, 0.0))
		var stele: MeshInstance3D = _multi_node("Stele%d" % site.get_child_count(), stele_parts)
		stele.position = Vector3(x, floor_y + STELE_SIZE.y * 0.5, 0.25)
		site.add_child(stele)
		var glyph: MeshInstance3D = MeshInstance3D.new()
		glyph.name = "RamaGlyph"
		glyph.mesh = RamaGlyph.mesh(GLYPH_HEIGHT, Palette.SINDOOR)
		glyph.material_override = Materials.get_material(KIND_LACQUER)
		glyph.position = Vector3(0.0, 0.0, stele_depth * 0.5 + 0.03)
		stele.add_child(glyph)

	# The scribes' bench: bowls of sindoor paint, and uncut stones waiting their turn.
	var bench: Dictionary = {}
	_put(bench, KIND_WOOD, MeshKit.bevel_box(Vector3(1.8, 0.1, 0.6), 0.03, Palette.BARK), Vector3(0.0, 0.5, 0.0))
	for sx: float in [-0.75, 0.75]:
		_put(bench, KIND_WOOD, MeshKit.bevel_box(Vector3(0.12, 0.5, 0.5), 0.02, Palette.BARK), Vector3(sx, 0.25, 0.0))
	for k: int in range(3):
		var at: Vector3 = Vector3(-0.55 + 0.55 * float(k), 0.6, 0.0)
		_put(bench, KIND_GOLD, MeshKit.cylinder_smooth(0.17, 0.11, 0.12, 10, Palette.GOLD.lerp(Palette.BARK, 0.35)), at)
		_put(bench, KIND_LACQUER, MeshKit.cylinder_smooth(0.14, 0.14, 0.02, 10, Palette.SINDOOR.lerp(Palette.SAFFRON, 0.5 * float(k % 2))), at + Vector3(0.0, 0.06, 0.0))
	for k: int in range(4):
		_put(bench, KIND_STONE, MeshKit.bevel_box(Vector3(0.9, 0.5, 0.7), 0.06, Palette.STONE.lerp(Palette.WET_STONE, 0.25 * float(k % 3))),
			Vector3(2.6 + 0.5 * float(k % 2), 0.25 + 0.5 * floorf(float(k) * 0.5), -0.3 + 0.2 * float(k % 2)), Basis(Vector3.UP, 0.3 * float(k)))
	var bench_node: MeshInstance3D = _multi_node("Bench", bench)
	bench_node.position = Vector3(0.0, floor_y, 1.35)
	site.add_child(bench_node)


func _add_torch(site: Node3D) -> void:
	var parts: Dictionary = {}
	_put(parts, KIND_WOOD, MeshKit.cylinder_smooth(0.06, 0.09, TORCH_HEIGHT, 7, Palette.BARK), Vector3(0.0, TORCH_HEIGHT * 0.5, 0.0))
	_put(parts, KIND_GOLD, MeshKit.cylinder_smooth(0.24, 0.1, 0.2, 10, Palette.GOLD.lerp(Palette.BARK, 0.3)), Vector3(0.0, TORCH_HEIGHT + 0.08, 0.0))
	_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(0.5, 0.2, 0.5), 0.05, Palette.WET_STONE), Vector3(0.0, 0.1, 0.0))
	var pole: MeshInstance3D = _multi_node("TorchPole", parts)
	pole.position = TORCH_OFFSET
	site.add_child(pole)
	var flame_at: Vector3 = TORCH_OFFSET + Vector3(0.0, TORCH_HEIGHT + 0.2, 0.0)
	var fire: Node3D = Vfx.fire(0.4, false)
	fire.name = "TorchFire"
	fire.position = flame_at
	site.add_child(fire)
	_night_nodes.append(fire)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = Palette.FIRE_CORE.lerp(Palette.SAFFRON, 0.4)
	light.omni_range = TORCH_RANGE
	light.omni_attenuation = 1.4
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.position = flame_at + Vector3(0.0, 0.3, 0.0)
	site.add_child(light)
	_torches.append(light)


func _add_pad(site: Node3D) -> void:
	var parts: Dictionary = {}
	_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(4.4, 0.16, 4.4), 0.05, Palette.WET_STONE), Vector3(0.0, 0.08, 0.0))
	site.add_child(_multi_node("Pad", parts))


## The bridge head: a paved landing with two gate pillars flying saffron banners either side of the causeway.
func _add_bridge_gate(site: Node3D) -> void:
	var parts: Dictionary = {}
	for k: int in range(9):
		var x: float = -4.6 + 1.5 * float(k % 3) + 0.2 * float((k % 6) >= 3)
		var z: float = -3.0 + 3.0 * floorf(float(k) / 3.0)
		_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(1.38, 0.1, 2.8), 0.03, Palette.STONE.lerp(Palette.WET_STONE, 0.2 + 0.25 * float((k * 5) % 3) * 0.5)),
			Vector3(x, 0.0, z))
	site.add_child(_multi_node("Pad", parts))
	var pale: Color = Palette.STONE.lerp(Palette.MOON, 0.45)
	for sz: float in [-1.0, 1.0]:
		var pillar: MeshInstance3D = _pillar_node("GatePillar%d" % site.get_child_count(), 3.4, 0.2, pale)
		pillar.position = Vector3(-2.2, 0.0, sz * 5.6)
		site.add_child(pillar)
		var top: Dictionary = {}
		_put_kalasha(top, Vector3(0.0, 3.4, 0.0), 0.85)
		_put(top, KIND_WOOD, MeshKit.cylinder_smooth(0.035, 0.045, 2.4, 6, Palette.BARK), Vector3(0.0, 4.5, 0.0))
		_put(top, KIND_CLOTH, _banner_mesh(1.7, 0.75, Palette.SAFFRON), Vector3(0.03, 5.2, 0.0), Basis(Vector3.BACK, -PI * 0.5))
		var top_node: MeshInstance3D = _multi_node("GateBanner%d" % site.get_child_count(), top)
		top_node.position = pillar.position
		site.add_child(top_node)


# --- shared builders --------------------------------------------------------------------------------------------

static func _a(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, alpha)


static func _put(parts: Dictionary, kind: StringName, mesh: ArrayMesh, at: Vector3, rot: Basis = Basis.IDENTITY) -> void:
	if not parts.has(kind):
		parts[kind] = []
	(parts[kind] as Array).append({"mesh": mesh, "transform": Transform3D(rot, at)})


## A round beam from `from` to `to`.
static func _put_beam(parts: Dictionary, kind: StringName, from: Vector3, to: Vector3, radius: float, colour: Color) -> void:
	var axis: Vector3 = to - from
	var length: float = axis.length()
	if length < 0.001:
		return
	var up: Vector3 = axis / length
	var side: Vector3 = up.cross(Vector3.RIGHT)
	if side.length_squared() < 0.001:
		side = up.cross(Vector3.BACK)
	side = side.normalized()
	var rot: Basis = Basis(side.cross(up).normalized() * -1.0, up, side)
	if rot.determinant() < 0.0:
		rot = Basis(side.cross(up).normalized(), up, side)
	_put(parts, kind, MeshKit.cylinder_smooth(radius * 0.85, radius, length, 7, colour), (from + to) * 0.5, rot)


## One MeshInstance3D whose mesh has one surface per Materials kind.
func _multi_node(node_name: String, parts: Dictionary) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = MeshKit.multi(parts)
	if parts.has(KIND_CLOTH) or parts.has(KIND_FOLIAGE):
		mi.extra_cull_margin = 0.5
	return mi


## A carved pillar standing on y = 0: stepped base, tapering shaft with a ring of facets and gold bands, and a
## flared capital under a square abacus.
func _pillar_node(node_name: String, height: float, radius: float, stone: Color) -> MeshInstance3D:
	var parts: Dictionary = {}
	var shade: Color = stone.lerp(Palette.WET_STONE, 0.35)
	_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(radius * 3.4, 0.22, radius * 3.4), 0.05, shade), Vector3(0.0, 0.11, 0.0))
	_put(parts, KIND_STONE, MeshKit.cylinder_smooth(radius * 1.25, radius * 1.5, 0.2, 12, stone), Vector3(0.0, 0.32, 0.0))
	var shaft_from: float = 0.42
	var shaft_to: float = height - 0.44
	var shaft: float = shaft_to - shaft_from
	_put(parts, KIND_STONE, MeshKit.cylinder_smooth(radius * 0.82, radius, shaft, 12, stone), Vector3(0.0, shaft_from + shaft * 0.5, 0.0))
	# Carved facets around the lower shaft and a beaded ring above them.
	for k: int in range(8):
		var a: float = TAU * float(k) / 8.0
		_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(radius * 0.62, shaft * 0.3, radius * 0.3), 0.025, stone.lerp(Palette.MOON, 0.2)),
			Vector3(sin(a) * radius * 0.92, shaft_from + shaft * 0.2, cos(a) * radius * 0.92), Basis(Vector3.UP, a))
	_put(parts, KIND_GOLD, MeshKit.cylinder_smooth(radius * 1.12, radius * 1.12, 0.09, 12, Palette.GOLD), Vector3(0.0, shaft_from + shaft * 0.4, 0.0))
	_put(parts, KIND_GOLD, MeshKit.cylinder_smooth(radius * 1.0, radius * 1.0, 0.07, 12, Palette.GOLD), Vector3(0.0, shaft_from + shaft * 0.82, 0.0))
	_put(parts, KIND_LACQUER, MeshKit.cylinder_smooth(radius * 0.93, radius * 0.96, shaft * 0.1, 12, Palette.SINDOOR), Vector3(0.0, shaft_from + shaft * 0.9, 0.0))
	_put(parts, KIND_STONE, MeshKit.cylinder_smooth(radius * 1.6, radius * 0.9, 0.24, 12, stone), Vector3(0.0, height - 0.32, 0.0))
	_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(radius * 3.6, 0.2, radius * 3.6), 0.05, shade), Vector3(0.0, height - 0.1, 0.0))
	return _multi_node(node_name, parts)


## A pavilion roof whose eaves sit at `at`: stone lintels with a dentil band, a gold cornice, two red lacquer tiers
## and a kalasha.
func _put_roof(parts: Dictionary, at: Vector3, half: Vector2, stone: Color, finial: float) -> void:
	var w: float = half.x * 2.0
	var d: float = half.y * 2.0
	_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(w + 0.7, 0.26, d + 0.7), 0.05, stone), at + Vector3(0.0, 0.13, 0.0))
	# Dentils: a repeated relief motif under the cornice.
	var count_x: int = int(w / 0.42)
	for k: int in range(count_x + 1):
		var x: float = lerpf(-half.x - 0.2, half.x + 0.2, float(k) / float(count_x))
		for sz: float in [-1.0, 1.0]:
			_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(0.18, 0.14, 0.1), 0.02, stone.lerp(Palette.MOON, 0.3)), at + Vector3(x, 0.1, sz * (half.y + 0.38)))
	var count_z: int = int(d / 0.42)
	for k: int in range(count_z + 1):
		var z: float = lerpf(-half.y - 0.2, half.y + 0.2, float(k) / float(count_z))
		for sx: float in [-1.0, 1.0]:
			_put(parts, KIND_STONE, MeshKit.bevel_box(Vector3(0.1, 0.14, 0.18), 0.02, stone.lerp(Palette.MOON, 0.3)), at + Vector3(sx * (half.x + 0.38), 0.1, z))
	_put(parts, KIND_GOLD, MeshKit.bevel_box(Vector3(w + 1.3, 0.12, d + 1.3), 0.04, Palette.GOLD), at + Vector3(0.0, 0.32, 0.0))
	# Tiers: square frustums (a four-sided cone turned 45 degrees and stretched to the plan).
	var turn: Basis = Basis(Vector3.UP, PI * 0.25)
	var unit: float = sqrt(2.0)
	var lower: Basis = Basis.from_scale(Vector3((w + 1.5) * 0.5, 1.0, (d + 1.5) * 0.5)) * turn
	_put(parts, KIND_STONE, MeshKit.cylinder(unit * 0.55, unit, 0.7, 4, Palette.SINDOOR.lerp(Palette.RAKSHASA_ARMOR, 0.45)), at + Vector3(0.0, 0.73, 0.0), lower)
	_put(parts, KIND_GOLD, MeshKit.bevel_box(Vector3((w + 1.5) * 0.56, 0.1, (d + 1.5) * 0.56), 0.03, Palette.GOLD), at + Vector3(0.0, 1.12, 0.0))
	var upper: Basis = Basis.from_scale(Vector3((w + 1.5) * 0.26, 1.0, (d + 1.5) * 0.26)) * turn
	_put(parts, KIND_STONE, MeshKit.cylinder(unit * 0.3, unit, 0.75, 4, Palette.SINDOOR.lerp(Palette.RAKSHASA_ARMOR, 0.6)), at + Vector3(0.0, 1.54, 0.0), upper)
	_put_kalasha(parts, at + Vector3(0.0, 1.9, 0.0), finial)
	# Gold hip ribs down the four corners of the lower tier.
	for hx: float in [-1.0, 1.0]:
		for hz: float in [-1.0, 1.0]:
			var eave: Vector3 = at + Vector3(hx * (w + 1.5) * 0.5, 0.4, hz * (d + 1.5) * 0.5)
			var ridge: Vector3 = at + Vector3(hx * (w + 1.5) * 0.275, 1.1, hz * (d + 1.5) * 0.275)
			_put_beam(parts, KIND_GOLD, eave, ridge, 0.05, Palette.GOLD)
	# Small gold finials on the four corners of the cornice.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_put(parts, KIND_GOLD, MeshKit.cone_smooth(0.09, 0.3, 8, Palette.GOLD), at + Vector3(sx * (half.x + 0.55), 0.53, sz * (half.y + 0.55)))


## A gold kalasha finial (pot, neck, bud) standing on `at`.
static func _put_kalasha(parts: Dictionary, at: Vector3, s: float) -> void:
	_put(parts, KIND_GOLD, MeshKit.cylinder_smooth(0.16 * s, 0.22 * s, 0.1 * s, 10, Palette.GOLD), at + Vector3(0.0, 0.05 * s, 0.0))
	_put(parts, KIND_GOLD, MeshKit.sphere_smooth(0.26 * s, 6, 12, Palette.GOLD), at + Vector3(0.0, 0.3 * s, 0.0), Basis.from_scale(Vector3(1.0, 0.82, 1.0)))
	_put(parts, KIND_GOLD, MeshKit.cylinder_smooth(0.14 * s, 0.08 * s, 0.12 * s, 10, Palette.GOLD), at + Vector3(0.0, 0.56 * s, 0.0))
	_put(parts, KIND_GOLD, MeshKit.cone_smooth(0.09 * s, 0.34 * s, 8, Palette.GOLD), at + Vector3(0.0, 0.78 * s, 0.0))


## A banner `length` long hanging along +y from y = 0 (pinned there, free at the far end), `height` wide along z.
## Turn it with a rot to fly it sideways from a pole.
static func _banner_mesh(length: float, height: float, colour: Color) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	var segments: int = 5
	var piece: float = length / float(segments)
	for k: int in range(segments):
		var taper: float = 1.0 - 0.35 * float(k) / float(segments)
		var tint: Color = colour.lerp(Palette.GOLD, 0.18) if k == segments - 1 else colour
		parts.append({
			"mesh": MeshKit.box(Vector3(0.03, piece, height * taper), tint),
			"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, piece * (float(k) + 0.5), 0.0)),
		})
	return MeshKit.wind_weighted(MeshKit.merge(parts), 0.0, length)


static func _tool() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(kinds: Array[StringName], tools: Array[SurfaceTool]) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for i: int in range(kinds.size()):
		var arrays: Array = tools[i].commit_to_arrays()
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not (verts is PackedVector3Array) or (verts as PackedVector3Array).is_empty():
			continue
		var index: int = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(index, String(kinds[i]))
		mesh.surface_set_material(index, Materials.get_material(kinds[i]))
	return mesh


## A smooth-shaded triangle, wound so that its front faces the side its normals point to.
static func _stri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot(na + nb + nc) < 0.0:
		_stri(st, a, c, b, na, nc, nb, ca, cc, cb)
		return
	st.set_normal(na)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(nc)
	st.set_color(cc)
	st.add_vertex(c)
	st.set_normal(nb)
	st.set_color(cb)
	st.add_vertex(b)


## A smooth tube through `points` with one radius per point; `closed` joins the last ring to the first.
## `ref` must not be parallel to the tube (it fixes the ring orientation so the tube does not twist).
static func _tube(st: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, sides: int, colour: Color,
		ref: Vector3, closed: bool) -> void:
	var count: int = points.size()
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	for i: int in range(count):
		var prev: Vector3 = points[(i - 1 + count) % count] if (closed or i > 0) else points[i]
		var next: Vector3 = points[(i + 1) % count] if (closed or i < count - 1) else points[i]
		var tangent: Vector3 = (next - prev).normalized()
		var side: Vector3 = tangent.cross(ref)
		if side.length_squared() < 0.0001:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		for s: int in range(sides):
			var angle: float = TAU * float(s) / float(sides)
			var normal: Vector3 = side * cos(angle) + up * sin(angle)
			ring.append(points[i] + normal * radii[i])
			normals.append(normal)
		rings.append(ring)
		ring_normals.append(normals)
	var last: int = count if closed else count - 1
	for i: int in range(last):
		var j: int = (i + 1) % count
		for s: int in range(sides):
			var s2: int = (s + 1) % sides
			_stri(st, rings[i][s], rings[j][s], rings[j][s2], ring_normals[i][s], ring_normals[j][s], ring_normals[j][s2], colour, colour, colour)
			_stri(st, rings[i][s], rings[j][s2], rings[i][s2], ring_normals[i][s], ring_normals[j][s2], ring_normals[i][s2], colour, colour, colour)


## A horizontal torus (a loop of rope) centred on `centre`.
static func _ring(st: SurfaceTool, centre: Vector3, radius: float, thickness: float, segments: int, sides: int, colour: Color) -> void:
	var points: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for k: int in range(segments):
		var angle: float = TAU * float(k) / float(segments)
		points.append(centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		radii.append(thickness)
	_tube(st, points, radii, sides, colour, Vector3.UP, true)


# --- scenery ----------------------------------------------------------------------------------------------------

func _build_scenery() -> void:
	var scenery: Node3D = Node3D.new()
	scenery.name = SCENERY_NAME
	add_child(scenery)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED

	# Hero trees (NatureKit v2 leaf-card trees) stand only around the works, where the camera lives.
	var hero_points: PackedVector2Array = _scatter(rng, HERO_TREE_COUNT, SCATTER_X_MIN, SCATTER_X_MAX, 1.0, 1)
	var hero_meshes: Array[Mesh] = []
	var hero_shadows: Array[Mesh] = []
	for k: int in range(4):
		hero_meshes.append(_tree_mesh(k, false))
		hero_shadows.append(_tree_mesh(k, true))
	var hero_buckets: Array[Array] = _scatter_buckets("TreesNear", hero_points, hero_meshes.size(), 0.85, 1.25, 0.0)
	for k: int in range(hero_meshes.size()):
		var mmi: MultiMeshInstance3D = _add_multimesh(scenery, "Trees%d" % k, hero_meshes[k], hero_buckets[k])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 0.5
		var caster: MultiMeshInstance3D = _add_multimesh(scenery, "TreeShadow%d" % k, hero_shadows[k], hero_buckets[k])
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	# Light trees fill the land beyond: a few smooth leaf masses on a trunk.
	var far_points: PackedVector2Array = _scatter(rng, FAR_TREE_COUNT, SCATTER_X_MIN, SCATTER_X_MAX, 1.0, -1)
	var far_meshes: Array[Mesh] = [_far_tree_mesh(61, false), _far_tree_mesh(62, true), _far_tree_mesh(63, false)]
	var far_buckets: Array[Array] = _scatter_buckets("TreesFar", far_points, far_meshes.size(), 0.85, 1.5, 0.0)
	for k: int in range(far_meshes.size()):
		var far_mmi: MultiMeshInstance3D = _add_multimesh(scenery, "TreesFar%d" % k, far_meshes[k], far_buckets[k])
		far_mmi.extra_cull_margin = 0.5
	var all_trees: PackedVector3Array = PackedVector3Array()
	all_trees.append_array(_scatter_points["TreesNear"] as PackedVector3Array)
	all_trees.append_array(_scatter_points["TreesFar"] as PackedVector3Array)
	_scatter_points["Trees"] = all_trees

	var rock_meshes: Array[Mesh] = [
		_rock_mesh(Vector3(1.4, 1.0, 1.2), 21), _rock_mesh(Vector3(1.0, 0.8, 1.6), 22), _rock_mesh(Vector3(2.0, 1.4, 1.7), 23),
	]
	var rock_points: PackedVector2Array = _scatter(rng, ROCK_COUNT_SCATTER, SCATTER_X_MIN, SCATTER_X_MAX, 1.0, 0)
	var rock_buckets: Array[Array] = _scatter_buckets("Rocks", rock_points, rock_meshes.size(), 0.7, 1.6, 0.36)
	for k: int in range(rock_meshes.size()):
		_add_multimesh(scenery, "Rocks%d" % k, rock_meshes[k], rock_buckets[k])

	var bush_meshes: Array[Mesh] = [_bush_mesh(71, false), _bush_mesh(72, true)]
	var bush_points: PackedVector2Array = _scatter(rng, BUSH_COUNT, SCATTER_X_MIN, SCATTER_X_MAX, 0.8, 1)
	var bush_buckets: Array[Array] = _scatter_buckets("Bushes", bush_points, bush_meshes.size(), 0.9, 1.5, 0.0)
	for k: int in range(bush_meshes.size()):
		var bush_mmi: MultiMeshInstance3D = _add_multimesh(scenery, "Bushes%d" % k, bush_meshes[k], bush_buckets[k])
		bush_mmi.extra_cull_margin = 0.5

	_build_grass(scenery, rng)

	var palm_meshes: Array[Mesh] = [_palm_mesh(41), _palm_mesh(42), _palm_mesh(43)]
	var palm_points: PackedVector2Array = _scatter(rng, PALM_COUNT, PALM_X_MIN, PALM_X_MAX, 0.6, 0)
	var palm_buckets: Array[Array] = _scatter_buckets("Palms", palm_points, palm_meshes.size(), 0.9, 1.3, 0.0)
	for k: int in range(palm_meshes.size()):
		var palm_mmi: MultiMeshInstance3D = _add_multimesh(scenery, "Palms%d" % k, palm_meshes[k], palm_buckets[k])
		palm_mmi.extra_cull_margin = 1.0

	_build_hills(scenery, rng)
	_build_vanara_camp(scenery)
	_build_rama_camp(scenery)


## True inside the ellipse around the works where the camera spends the day.
static func _is_near(p: Vector2) -> bool:
	var q: Vector2 = (p - NEAR_CENTRE) / NEAR_RADII
	return q.length_squared() < 1.0


## Rejection-samples `count` land positions that keep clear of every site, haul route (site to head), camp and
## the z = 0 corridor. `zone`: 1 = only near the works, -1 = only away from them, 0 = anywhere.
func _scatter(rng: RandomNumberGenerator, count: int, x_min: float, x_max: float, clearance_scale: float, zone: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var attempts: int = 0
	while result.size() < count and attempts < count * 80:
		attempts += 1
		var p: Vector2 = Vector2(rng.randf_range(x_min, x_max), rng.randf_range(-SCATTER_Z_HALF, SCATTER_Z_HALF))
		if zone != 0 and _is_near(p) != (zone > 0):
			continue
		if _scatter_blocked(p, clearance_scale):
			continue
		result.append(p)
	return result


func _scatter_blocked(p: Vector2, clearance_scale: float) -> bool:
	if absf(p.y) < CORRIDOR_HALF_WIDTH:
		return true
	for site: Vector2 in _site_points:
		if p.distance_to(site) < SITE_CLEARANCE * clearance_scale:
			return true
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(p, site, Vector2.ZERO)
		if p.distance_to(nearest) < HAUL_CLEARANCE * clearance_scale:
			return true
	var camps: Array[Vector2] = [Vector2(RAMA_CAMP_POS.x, RAMA_CAMP_POS.z), Vector2(VANARA_CAMP_POS.x, VANARA_CAMP_POS.z)]
	for camp: Vector2 in camps:
		if p.distance_to(camp) < CAMP_CLEARANCE:
			return true
	return false


## Turns scatter points into seeded transforms on the terrain, split into `bucket_count` round-robin buckets, and
## records their positions under `kind`. `lift` raises each instance by that fraction of its factor.
func _scatter_buckets(kind: String, points: PackedVector2Array, bucket_count: int, scale_min: float, scale_max: float,
		lift: float) -> Array[Array]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED + kind.hash() % 1000
	var recorded: PackedVector3Array = PackedVector3Array()
	var buckets: Array[Array] = []
	for i: int in range(bucket_count):
		buckets.append([])
	for i: int in range(points.size()):
		var factor: float = rng.randf_range(scale_min, scale_max)
		var rot: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(factor, factor, factor))
		var origin: Vector3 = Vector3(points[i].x, _ground_height(points[i].x, points[i].y) + lift * factor, points[i].y)
		buckets[i % bucket_count].append(Transform3D(rot, origin))
		recorded.append(origin)
	_scatter_points[kind] = recorded
	return buckets


func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array, colours: PackedColorArray = PackedColorArray()) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colours.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i] as Transform3D)
		if mm.use_colors:
			mm.set_instance_color(i, colours[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	parent.add_child(mmi)
	return mmi


## Grass tufts (the NatureKit tuft mesh, tinted per instance) in clumps around the works, with flower drifts.
func _build_grass(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var patch: MeshInstance3D = NatureKit.grass_patch(31, 1.0, 4)
	var tuft: Mesh = (patch.get_node(NatureKit.BLADES_NAME) as MultiMeshInstance3D).multimesh.mesh
	patch.free()
	var clumps: PackedVector2Array = _scatter(rng, GRASS_CLUMPS, -100.0, SCATTER_X_MAX, 0.42, 1)
	var transforms: Array[Transform3D] = []
	var tints: PackedColorArray = PackedColorArray()
	var recorded: PackedVector3Array = PackedVector3Array()
	for clump: Vector2 in clumps:
		var radius: float = rng.randf_range(1.3, 2.8)
		var warm: float = rng.randf_range(0.1, 0.5)
		for k: int in range(GRASS_PER_CLUMP):
			var angle: float = rng.randf_range(0.0, TAU)
			var distance: float = radius * sqrt(rng.randf())
			var p: Vector2 = clump + Vector2(cos(angle), sin(angle)) * distance
			if _scatter_blocked(p, 0.3):
				continue
			var factor: float = rng.randf_range(1.7, 2.9)
			var rot: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(factor, factor * rng.randf_range(0.8, 1.2), factor))
			var origin: Vector3 = Vector3(p.x, _ground_height(p.x, p.y), p.y)
			transforms.append(Transform3D(rot, origin))
			var tint: Color = Palette.GROVE_GREEN.lerp(Palette.GOLD, clampf(warm + rng.randf_range(-0.1, 0.15), 0.05, 0.6))
			tints.append(Color(tint.r, tint.g, tint.b, 1.0))
			recorded.append(origin)
	_scatter_points["Grass"] = recorded
	var grass: MultiMeshInstance3D = _add_multimesh(parent, "Grass0", tuft, transforms, tints)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.extra_cull_margin = 0.5

	var flower_meshes: Array[Mesh] = [_flower_mesh(81), _flower_mesh(82), _flower_mesh(83)]
	var flower_points: PackedVector2Array = PackedVector2Array()
	for i: int in range(mini(FLOWER_COUNT, clumps.size())):
		var around: Vector2 = clumps[(i * 7) % clumps.size()]
		var p: Vector2 = around + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		if not _scatter_blocked(p, 0.3):
			flower_points.append(p)
	var flower_buckets: Array[Array] = _scatter_buckets("Flowers", flower_points, flower_meshes.size(), 1.3, 2.0, 0.0)
	for k: int in range(flower_meshes.size()):
		var flowers: MultiMeshInstance3D = _add_multimesh(parent, "Flowers%d" % k, flower_meshes[k], flower_buckets[k])
		flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flowers.extra_cull_margin = 0.5


static func _take_mesh(mi: MeshInstance3D) -> Mesh:
	var mesh: Mesh = mi.mesh
	mi.free()
	return mesh


## One of four NatureKit v2 trees (or, with `shadow`, its simpler shadow-caster mesh).
static func _tree_mesh(variant: int, shadow: bool) -> Mesh:
	var key: String = "tree:%d:%s" % [variant, shadow]
	if not _mesh_cache.has(key):
		var tree: MeshInstance3D
		if variant % 2 == 0:
			tree = NatureKit.ashoka_tree(11 + variant, 6.0 + float(variant) * 0.5)
		else:
			tree = NatureKit.shimshapa_tree(11 + variant, 7.0 - float(variant - 1) * 0.5)
		var caster: MeshInstance3D = tree.get_node_or_null(NatureKit.SHADOW_CASTER_NAME) as MeshInstance3D
		_mesh_cache["tree:%d:%s" % [variant, true]] = caster.mesh if caster != null else tree.mesh
		_mesh_cache["tree:%d:%s" % [variant, false]] = tree.mesh
		tree.free()
	return _mesh_cache[key]


static func _rock_mesh(size: Vector3, rng_seed: int) -> Mesh:
	var key: String = "rock:%d" % rng_seed
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _take_mesh(NatureKit.rock(size, rng_seed))
	return _mesh_cache[key]


static func _bush_mesh(rng_seed: int, flowering: bool) -> Mesh:
	var key: String = "bush:%d" % rng_seed
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _take_mesh(NatureKit.bush(rng_seed, 0.9, flowering))
	return _mesh_cache[key]


static func _flower_mesh(rng_seed: int) -> Mesh:
	var key: String = "flowers:%d" % rng_seed
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _take_mesh(NatureKit.flowers(Vector2(2.6, 2.6), rng_seed, 9))
	return _mesh_cache[key]


## A light tree for the distance: a tapering trunk under a few overlapping smooth leaf masses, lit from above.
## `tall` gives a narrow ashoka-like column, otherwise a broad crown.
static func _far_tree_mesh(rng_seed: int, tall: bool) -> Mesh:
	var key: String = "far:%d" % rng_seed
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var parts: Dictionary = {}
	var trunk: float = 2.6 if tall else 2.2
	_put(parts, KIND_WOOD, MeshKit.cylinder_smooth(0.16, 0.3, trunk, 6, Palette.BARK), Vector3(0.0, trunk * 0.5, 0.0))
	var shade: Color = Palette.LEAF_DARK.darkened(0.25)
	var mid: Color = Palette.LEAF_DARK.lerp(Palette.GROVE_GREEN, 0.35)
	var sun: Color = Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.08).darkened(0.1)
	var blobs: int = 4 if tall else 3
	for k: int in range(blobs):
		var t: float = float(k) / float(blobs - 1)
		var radius: float = lerpf(1.5, 0.85, t) if tall else lerpf(2.0, 1.35, t)
		var spread: float = 0.3 if tall else 1.0 * (1.0 - t * 0.6)
		var angle: float = rng.randf_range(0.0, TAU)
		var centre: Vector3 = Vector3(cos(angle) * spread, trunk + (1.15 if tall else 0.7) * float(k) + 0.5, sin(angle) * spread)
		var squash: Vector3 = Vector3(0.8, 1.15, 0.8) if tall else Vector3(1.15, 0.72, 1.15)
		var colour: Color = shade.lerp(mid, t * 1.6) if t < 0.6 else mid.lerp(sun, (t - 0.6) * 2.5)
		_put(parts, KIND_FOLIAGE, MeshKit.sphere_smooth(radius, 4, 7, _a(colour, 0.25 + 0.25 * t)), centre,
			Basis(Vector3.UP, angle).scaled(squash))
	var mesh: Mesh = MeshKit.multi(parts)
	_mesh_cache[key] = mesh
	return mesh


## A coconut palm: a curved ringed trunk, a crown of arching feathered fronds that sway, and a few coconuts.
static func _palm_mesh(rng_seed: int) -> Mesh:
	var key: String = "palm:%d" % rng_seed
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var wood: SurfaceTool = _tool()
	var leaf: SurfaceTool = _tool()
	var height: float = rng.randf_range(5.2, 6.6)
	var lean: float = rng.randf_range(0.7, 1.6)
	var points: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var rings: int = 8
	for k: int in range(rings + 1):
		var t: float = float(k) / float(rings)
		points.append(Vector3(lean * t * t, height * t, 0.0))
		radii.append(lerpf(0.24, 0.13, t) * (1.08 if k % 2 == 0 else 0.94))
	_tube(wood, points, radii, 7, Palette.BARK.lerp(Palette.STONE, 0.3), Vector3.BACK, false)
	var top: Vector3 = points[rings]
	var nut_colour: Color = Palette.BARK.darkened(0.25)
	for k: int in range(3):
		var a: float = TAU * float(k) / 3.0 + 0.4
		var nut: ArrayMesh = MeshKit.sphere_smooth(0.17, 4, 6, nut_colour)
		var arrays: Array = nut.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var offset: Vector3 = top + Vector3(cos(a) * 0.24, -0.22, sin(a) * 0.24)
		for v: int in range(0, verts.size(), 3):
			_stri(wood, verts[v] + offset, verts[v + 1] + offset, verts[v + 2] + offset, normals[v], normals[v + 1], normals[v + 2],
				nut_colour, nut_colour, nut_colour)
	var fronds: int = 9
	var leaflets: int = 9
	for f: int in range(fronds):
		var yaw: float = TAU * float(f) / float(fronds) + rng.randf_range(-0.2, 0.2)
		var out: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var side: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw))
		var length: float = rng.randf_range(2.5, 3.3)
		var rise: float = rng.randf_range(0.35, 0.9)
		var droop: float = rng.randf_range(0.75, 1.2)
		var spine: PackedVector3Array = PackedVector3Array()
		for k: int in range(leaflets + 2):
			var t: float = float(k) / float(leaflets + 1)
			spine.append(top + out * (length * t) + Vector3.UP * (rise * sin(PI * t * 0.8) - droop * t * t * length * 0.45))
		for k: int in range(1, leaflets + 1):
			var t: float = float(k) / float(leaflets + 1)
			var width: float = 0.75 * sin(PI * clampf(t * 0.85 + 0.12, 0.0, 1.0)) + 0.12
			var base_a: Vector3 = spine[k - 1].lerp(spine[k], 0.45)
			var base_b: Vector3 = spine[k].lerp(spine[k + 1], 0.55)
			var colour: Color = Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.12 + 0.2 * t).lerp(Palette.LEAF_DARK, 0.25 * float(f % 2))
			var root: Color = _a(colour.lerp(Palette.LEAF_DARK, 0.4), t * 0.6)
			var tip: Color = _a(colour, minf(t * 0.6 + 0.35, 1.0))
			var normal: Vector3 = (Vector3.UP + out * 0.35).normalized()
			for flip: float in [-1.0, 1.0]:
				var tip_point: Vector3 = spine[k] + side * flip * width + out * 0.18 - Vector3.UP * (0.28 * width + 0.08)
				_stri(leaf, base_a, base_b, tip_point, normal, normal, (normal + side * flip * 0.5).normalized(), root, root, tip)
	var mesh: Mesh = _commit([KIND_WOOD, KIND_FOLIAGE], [wood, leaf])
	_mesh_cache[key] = mesh
	return mesh


## A line of rounded hills along the far edge of the land, hazed toward the sea colour.
func _build_hills(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var hills: Node3D = Node3D.new()
	hills.name = "Hills"
	parent.add_child(hills)
	for i: int in range(HILL_COUNT):
		var radius: float = rng.randf_range(18.0, 28.0)
		var colour: Color = Palette.LEAF_DARK.lerp(Palette.GROVE_GREEN, rng.randf_range(0.1, 0.5)).lerp(Palette.DEEP_OCEAN, 0.2)
		var parts: Dictionary = {}
		_put(parts, KIND_FOLIAGE, MeshKit.sphere_smooth(radius, 7, 12, _a(colour, 0.0)), Vector3.ZERO)
		var hill: MeshInstance3D = _multi_node("Hill%d" % i, parts)
		var z: float = lerpf(-SCATTER_Z_HALF * 1.6, SCATTER_Z_HALF * 1.6, float(i) / float(HILL_COUNT - 1))
		hill.position = Vector3(HILL_X - rng.randf_range(0.0, 10.0), -radius * 0.2, z)
		hill.scale = Vector3(1.3, 0.75, 1.9)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hills.add_child(hill)


## The vanara camp: striped tents flying saffron flags around a cook-fire, with pots, rugs and drums.
func _build_vanara_camp(parent: Node3D) -> void:
	var camp: Node3D = Node3D.new()
	camp.name = "VanaraCamp"
	camp.position = VANARA_CAMP_POS
	parent.add_child(camp)
	var trims: Array[Color] = [Palette.SAFFRON, Palette.SINDOOR, Palette.GOLD]
	for i: int in range(TENT_OFFSETS.size()):
		var tent: Node3D = Node3D.new()
		tent.name = "Tent%d" % i
		tent.position = Vector3(TENT_OFFSETS[i].x, 0.0, TENT_OFFSETS[i].y)
		# Each tent opens toward the fire in the middle of the camp.
		tent.rotation.y = atan2(-TENT_OFFSETS[i].x, -TENT_OFFSETS[i].y)
		var cloth: Dictionary = {}
		var canvas: Color = _a(TENT_CLOTH.lerp(Palette.SHORE_SAND, 0.3 * float(i % 3)), 0.0)
		var trim: Color = _a(trims[i % trims.size()], 0.0)
		_put(cloth, KIND_CLOTH, MeshKit.cylinder(0.12, 2.25, 2.3, 8, canvas, true), Vector3(0.0, 1.5, 0.0))
		_put(cloth, KIND_CLOTH, MeshKit.cylinder(2.27, 2.1, 0.36, 8, trim), Vector3(0.0, 0.18, 0.0))
		_put(cloth, KIND_CLOTH, MeshKit.cylinder(1.3, 1.52, 0.2, 8, trim), Vector3(0.0, 1.55, 0.0))
		# The door: a dark opening with the flap tied back.
		_put(cloth, KIND_CLOTH, MeshKit.box(Vector3(0.9, 1.3, 0.1), _a(Palette.NIGHT_INDIGO.lerp(Palette.BARK, 0.4), 0.0)), Vector3(0.0, 0.68, 1.72),
			Basis(Vector3.RIGHT, -0.62))
		_put(cloth, KIND_WOOD, MeshKit.cylinder_smooth(0.035, 0.05, 1.5, 6, Palette.BARK), Vector3(0.0, 3.3, 0.0))
		_put(cloth, KIND_GOLD, MeshKit.sphere_smooth(0.09, 4, 8, Palette.GOLD), Vector3(0.0, 4.08, 0.0))
		for k: int in range(4):
			var a: float = TAU * (float(k) + 0.5) / 4.0
			_put_beam(cloth, KIND_CLOTH, Vector3(cos(a) * 2.0, 0.5, sin(a) * 2.0), Vector3(cos(a) * 3.0, 0.02, sin(a) * 3.0), 0.02, _a(Palette.ROPE, 0.0))
		tent.add_child(_multi_node("Cloth", cloth))
		var flag_parts: Dictionary = {}
		_put(flag_parts, KIND_CLOTH, _banner_mesh(1.1, 0.5, Palette.SAFFRON), Vector3.ZERO, Basis(Vector3.BACK, -PI * 0.5))
		var flag: MeshInstance3D = _multi_node("Flag", flag_parts)
		flag.position = Vector3(0.04, 3.72, 0.0)
		tent.add_child(flag)
		camp.add_child(tent)

	# The cook-fire: a ring of stones, crossed logs and a pot on a tripod.
	var hearth: Dictionary = {}
	for k: int in range(9):
		var a: float = TAU * float(k) / 9.0
		_put(hearth, KIND_STONE, MeshKit.sphere_smooth(0.24, 4, 7, Palette.WET_STONE.lerp(Palette.STONE, 0.4 * float(k % 3) * 0.5)),
			Vector3(cos(a) * 0.95, 0.1, sin(a) * 0.95), Basis.from_scale(Vector3(1.0, 0.7, 1.2)))
	for k: int in range(3):
		_put(hearth, KIND_WOOD, MeshKit.cylinder_smooth(0.09, 0.11, 1.3, 6, Palette.BARK.darkened(0.3)), Vector3(0.0, 0.16, 0.0),
			Basis(Vector3.UP, TAU * float(k) / 3.0) * Basis(Vector3.BACK, PI * 0.5 - 0.15))
	camp.add_child(_multi_node("Hearth", hearth))
	var fire: Node3D = Vfx.fire(0.9, false)
	fire.name = "Campfire"
	fire.position = Vector3(0.0, 0.25, 0.0)
	camp.add_child(fire)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "CampfireLight"
	glow.light_color = Palette.FIRE_CORE.lerp(Palette.SAFFRON, 0.5)
	glow.omni_range = 14.0
	glow.omni_attenuation = 1.3
	glow.light_energy = 0.0
	glow.position = Vector3(0.0, 1.2, 0.0)
	camp.add_child(glow)
	_night_lights.append(glow)
	_night_lights_energy.append(6.0)

	# Camp dressing: water pots, woven rugs, drums and a rack of banners.
	var dressing: Dictionary = {}
	var terracotta: Color = Palette.ASHOKA_RED.lerp(Palette.BARK, 0.45)
	var pot_spots: Array[Vector3] = [Vector3(2.2, 0.0, 0.8), Vector3(2.7, 0.0, 0.2), Vector3(2.5, 0.0, 1.4), Vector3(-2.4, 0.0, -0.6)]
	for at: Vector3 in pot_spots:
		_put(dressing, KIND_LACQUER, MeshKit.sphere_smooth(0.3, 5, 10, terracotta), at + Vector3(0.0, 0.27, 0.0), Basis.from_scale(Vector3(1.0, 0.88, 1.0)))
		_put(dressing, KIND_LACQUER, MeshKit.cylinder_smooth(0.16, 0.12, 0.14, 10, terracotta.lightened(0.1)), at + Vector3(0.0, 0.58, 0.0))
	var rug_colours: Array[Color] = [Palette.SINDOOR, Palette.SAFFRON, Palette.RAKSHASA_ARMOR]
	for k: int in range(3):
		var a: float = 0.9 + TAU * float(k) / 3.0
		var at: Vector3 = Vector3(cos(a) * 2.6, 0.02, sin(a) * 2.6)
		var turn: Basis = Basis(Vector3.UP, -a + 0.2)
		_put(dressing, KIND_CLOTH, MeshKit.box(Vector3(1.9, 0.03, 1.2), _a(Palette.GOLD.lerp(Palette.ROPE, 0.3), 0.0)), at, turn)
		_put(dressing, KIND_CLOTH, MeshKit.box(Vector3(1.6, 0.035, 0.95), _a(rug_colours[k], 0.0)), at + Vector3(0.0, 0.005, 0.0), turn)
		_put(dressing, KIND_CLOTH, MeshKit.box(Vector3(0.5, 0.04, 0.5), _a(Palette.GOLD, 0.0)), at + Vector3(0.0, 0.008, 0.0), turn * Basis(Vector3.UP, PI * 0.25))
	for k: int in range(2):
		var at: Vector3 = Vector3(-2.9 + 0.75 * float(k), 0.32, 1.6 + 0.3 * float(k))
		_put(dressing, KIND_WOOD, MeshKit.cylinder_smooth(0.3, 0.26, 0.64, 10, Palette.BARK.lerp(Palette.SINDOOR, 0.35)), at)
		_put(dressing, KIND_CLOTH, MeshKit.cylinder_smooth(0.31, 0.31, 0.03, 10, _a(TENT_CLOTH, 0.0)), at + Vector3(0.0, 0.33, 0.0))
		_put(dressing, KIND_GOLD, MeshKit.cylinder_smooth(0.315, 0.315, 0.05, 10, Palette.GOLD), at + Vector3(0.0, 0.27, 0.0))
	camp.add_child(_multi_node("Dressing", dressing))
	var banners: Dictionary = {}
	for k: int in range(3):
		var at: Vector3 = Vector3(-8.5 + 1.6 * float(k), 0.0, -8.0 - 0.5 * float(k % 2))
		_put(banners, KIND_WOOD, MeshKit.cylinder_smooth(0.04, 0.06, 4.6, 6, Palette.BARK), at + Vector3(0.0, 2.3, 0.0))
		_put(banners, KIND_CLOTH, _banner_mesh(2.3, 0.7, rug_colours[k].lerp(Palette.SAFFRON, 0.4)), at + Vector3(0.05, 4.5, 0.0), Basis(Vector3.RIGHT, PI))
	camp.add_child(_multi_node("Banners", banners))
	var fireflies: Node3D = Vfx.fireflies(AABB(Vector3(-12.0, 0.4, -12.0), Vector3(24.0, 4.0, 24.0)))
	fireflies.name = "Fireflies"
	camp.add_child(fireflies)
	_night_nodes.append(fireflies)


## Rama's pavilion: a stepped dais under a red and gold roof on carved pillars, with banners, lamps, a kusha-grass
## seat and the great bow on its stand. Rama himself is not shown.
func _build_rama_camp(parent: Node3D) -> void:
	var camp: Node3D = Node3D.new()
	camp.name = "RamaCamp"
	camp.position = RAMA_CAMP_POS
	parent.add_child(camp)
	var half: Vector2 = PAVILION_HALF
	var marble: Color = Palette.STONE.lerp(Color.WHITE, 0.55)
	var dais: Dictionary = {}
	for step: int in range(3):
		var grow: float = 2.6 - 0.8 * float(step)
		var colour: Color = Palette.STONE.lerp(marble, 0.3 * float(step))
		_put(dais, KIND_STONE, MeshKit.bevel_box(Vector3(half.x * 2.0 + grow, 0.2, half.y * 2.0 + grow), 0.05, colour), Vector3(0.0, 0.1 + 0.2 * float(step), 0.0))
	var floor_y: float = 0.6
	# An inlaid carpet with a gold border, and the kusha-grass seat where Rama kept his vigil.
	_put(dais, KIND_CLOTH, MeshKit.box(Vector3(half.x * 2.0 - 1.0, 0.03, half.y * 2.0 - 1.0), _a(Palette.GOLD, 0.0)), Vector3(0.0, floor_y + 0.015, 0.0))
	_put(dais, KIND_CLOTH, MeshKit.box(Vector3(half.x * 2.0 - 1.4, 0.035, half.y * 2.0 - 1.4), _a(Palette.SINDOOR.lerp(Palette.RAKSHASA_ARMOR, 0.3), 0.0)), Vector3(0.0, floor_y + 0.02, 0.0))
	_put(dais, KIND_CLOTH, MeshKit.bevel_box(Vector3(2.2, 0.12, 1.3), 0.04, _a(Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.55), 0.0)), Vector3(-0.4, floor_y + 0.09, 0.0))
	var dais_node: MeshInstance3D = _multi_node("Dais", dais)
	camp.add_child(dais_node)
	var index: int = 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pillar: MeshInstance3D = _pillar_node("Pillar%d" % index, PAVILION_POST_HEIGHT, 0.2, marble)
			pillar.position = Vector3(sx * (half.x - 0.3), floor_y, sz * (half.y - 0.3))
			camp.add_child(pillar)
			index += 1
	var roof_y: float = floor_y + PAVILION_POST_HEIGHT
	var trim: Dictionary = {}
	_put(trim, KIND_GOLD, MeshKit.bevel_box(Vector3(half.x * 2.0 + 0.5, 0.16, half.y * 2.0 + 0.5), 0.05, Palette.GOLD), Vector3.ZERO)
	var trim_node: MeshInstance3D = _multi_node("GoldTrim", trim)
	trim_node.position = Vector3(0.0, roof_y + 0.08, 0.0)
	camp.add_child(trim_node)
	var roof: Dictionary = {}
	_put_roof(roof, Vector3(0.0, roof_y + 0.16, 0.0), Vector2(half.x - 0.3, half.y - 0.3), marble, 1.35)
	camp.add_child(_multi_node("Roof", roof))

	# Saffron banners on tall poles at the front corners, and hanging pennants along the eaves.
	var banners: Dictionary = {}
	for sz: float in [-1.0, 1.0]:
		var at: Vector3 = Vector3(half.x + 1.9, 0.0, sz * (half.y + 1.6))
		_put(banners, KIND_WOOD, MeshKit.cylinder_smooth(0.05, 0.07, 6.4, 7, Palette.BARK), at + Vector3(0.0, 3.2, 0.0))
		_put(banners, KIND_GOLD, MeshKit.cone_smooth(0.1, 0.36, 8, Palette.GOLD), at + Vector3(0.0, 6.55, 0.0))
		_put(banners, KIND_CLOTH, _banner_mesh(2.2, 0.95, Palette.SAFFRON), at + Vector3(0.05, 5.8, 0.0), Basis(Vector3.BACK, -PI * 0.5))
	for k: int in range(7):
		var x: float = lerpf(-half.x + 0.5, half.x - 0.5, float(k) / 6.0)
		var colour: Color = Palette.SAFFRON if k % 2 == 0 else Palette.GOLD
		for sz: float in [-1.0, 1.0]:
			_put(banners, KIND_CLOTH, _banner_mesh(0.55, 0.4, colour), Vector3(x, roof_y + 0.1, sz * (half.y + 0.1)), Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, PI * 0.5))
	camp.add_child(_multi_node("Banners", banners))

	# The bow Kodanda resting on a stand, a quiver beside it.
	var bow: Dictionary = {}
	var st: SurfaceTool = _tool()
	var points: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for k: int in range(13):
		var t: float = float(k) / 12.0
		var a: float = lerpf(-1.15, 1.15, t)
		points.append(Vector3(0.0, 1.25 + sin(a) * 1.15, cos(a) * 0.55 - 0.3))
		radii.append(0.045 * (0.55 + 0.45 * sin(PI * t)))
	_tube(st, points, radii, 6, Palette.GOLD, Vector3.RIGHT, false)
	_put(bow, KIND_GOLD, _commit([KIND_GOLD], [st]), Vector3.ZERO)
	_put(bow, KIND_CLOTH, MeshKit.cylinder_smooth(0.012, 0.012, 2.1, 4, _a(Palette.MOON, 0.0)), Vector3(0.0, 1.25, -0.08))
	_put(bow, KIND_WOOD, MeshKit.bevel_box(Vector3(0.5, 0.14, 0.9), 0.03, Palette.BARK), Vector3(0.0, 0.07, 0.0))
	_put(bow, KIND_WOOD, MeshKit.cylinder_smooth(0.05, 0.06, 1.2, 6, Palette.BARK), Vector3(0.0, 0.7, 0.32))
	_put(bow, KIND_LACQUER, MeshKit.cylinder_smooth(0.12, 0.09, 0.9, 8, Palette.SINDOOR), Vector3(0.0, 0.5, 0.75), Basis(Vector3.RIGHT, 0.2))
	_put(bow, KIND_GOLD, MeshKit.cylinder_smooth(0.125, 0.125, 0.08, 8, Palette.GOLD), Vector3(0.0, 0.9, 0.83), Basis(Vector3.RIGHT, 0.2))
	var bow_node: MeshInstance3D = _multi_node("BowStand", bow)
	bow_node.position = Vector3(1.3, floor_y, 0.2)
	camp.add_child(bow_node)

	# Standing lamps either side of the steps.
	for sz: float in [-1.0, 1.0]:
		var lamp: Dictionary = {}
		_put(lamp, KIND_GOLD, MeshKit.cylinder_smooth(0.16, 0.24, 0.12, 10, Palette.GOLD), Vector3(0.0, 0.06, 0.0))
		_put(lamp, KIND_GOLD, MeshKit.cylinder_smooth(0.04, 0.06, 1.3, 8, Palette.GOLD), Vector3(0.0, 0.75, 0.0))
		_put(lamp, KIND_GOLD, MeshKit.sphere_smooth(0.09, 4, 8, Palette.GOLD), Vector3(0.0, 0.75, 0.0))
		_put(lamp, KIND_GOLD, MeshKit.cylinder_smooth(0.24, 0.08, 0.14, 10, Palette.GOLD), Vector3(0.0, 1.45, 0.0))
		var lamp_node: MeshInstance3D = _multi_node("Lamp%d" % camp.get_child_count(), lamp)
		lamp_node.position = Vector3(half.x + 0.3, floor_y, sz * 1.9)
		camp.add_child(lamp_node)
		var flame: Node3D = Vfx.fire(0.25, false)
		flame.name = "LampFlame%d" % camp.get_child_count()
		flame.position = lamp_node.position + Vector3(0.0, 1.55, 0.0)
		camp.add_child(flame)
		var glow: OmniLight3D = OmniLight3D.new()
		glow.name = "LampLight%d" % camp.get_child_count()
		glow.light_color = Palette.FIRE_CORE
		glow.omni_range = 9.0
		glow.light_energy = 0.0
		glow.position = lamp_node.position + Vector3(0.0, 1.9, 0.0)
		camp.add_child(glow)
		_night_lights.append(glow)
		_night_lights_energy.append(3.5)
	var garden: MeshInstance3D = NatureKit.flowers(Vector2(half.x * 2.0 + 5.0, 2.0), 91, 40)
	garden.name = "Garden"
	garden.position = Vector3(0.0, 0.0, half.y + 3.0)
	garden.scale = Vector3(1.6, 1.6, 1.6)
	camp.add_child(garden)
