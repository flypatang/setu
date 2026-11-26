class_name Look
extends RefCounted
## Mood and post-processing system (docs/ART.md "Rendering", module F1).
##
## Look.apply(mood, parent, preset) builds, or replaces, the whole lighting rig under `parent`:
##   "WorldEnvironment"  procedural sky, tinted ambient, ACES tonemap, thresholded glow, SSAO, SSIL, SDFGI, depth and
##                       volumetric fog, and a colour grade;
##   "Sun"               the shadow-casting key light (sun, moon or firelight), in the group "sun";
##   "Fill"              a cool, shadowless fill from the opposite side;
##   "BackRim"           a shadowless rim from behind the key.
## It returns { mood, preset, world_environment, environment, key, fill, rim }.
##
## Moods: dawn, day, dusk, night, inferno (the burning of Lanka), divine (shloka cards, epilogue).
## Presets: low, medium, high. An empty preset reads the saved graphics option (Menus.graphics_preset()).
##
## The node names match the rig LevelRuntime used to build, so calling apply() on a parent that already has those
## nodes swaps them out. Look never touches the viewport: the render scale stays with Menus (see render_scale()).

const MOODS: Array[StringName] = [&"dawn", &"day", &"dusk", &"night", &"inferno", &"divine"]
const PRESETS: Array[StringName] = [&"low", &"medium", &"high"]
const DEFAULT_MOOD: StringName = &"day"
const DEFAULT_PRESET: StringName = &"high"

const WORLD_ENVIRONMENT_NAME: StringName = &"WorldEnvironment"
const KEY_NAME: StringName = &"Sun"
const FILL_NAME: StringName = &"Fill"
const RIM_NAME: StringName = &"BackRim"
const SUN_GROUP: StringName = &"sun"

const LOW_RENDER_SCALE: float = 0.75
const NIGHT_LEVEL_PREFIX: String = "lanka_"

const _LEVEL_MOODS: Dictionary[StringName, StringName] = {
	&"mahendra": &"dawn",
	&"ocean_leap": &"day",
	&"lanka_gate": &"dusk",
	&"lanka_streets": &"night",
	&"ashoka_vatika": &"night",
	&"ravana_court": &"dusk",
	&"lanka_rooftops": &"inferno",
}

## Levels whose mood is re-tuned after the base mood is built (see _tune_for_level).
const _WARM_INTERIOR_LEVELS: Array[StringName] = [&"ravana_court"]

const _SKY_SHADER: String = """shader_type sky;

uniform vec3 top_color : source_color = vec3(0.1, 0.3, 0.7);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.7, 0.6);
uniform vec3 ground_color : source_color = vec3(0.1, 0.1, 0.2);
uniform vec3 disc_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.4, 0.4, 0.6);
uniform float disc_size = 0.04;
uniform float disc_energy = 6.0;
uniform float halo = 0.35;
uniform float cloud_cover = 0.45;
uniform float cloud_speed = 0.006;
uniform float stars = 0.0;
uniform float energy = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	float t = pow(clamp(up, 0.0, 1.0), 0.55);
	vec3 col = mix(horizon_color, top_color, t);
	col = mix(col, ground_color, smoothstep(0.0, -0.25, up));
	float sun_dot = LIGHT0_ENABLED ? dot(dir, LIGHT0_DIRECTION) : -1.0;
	// A broad warm halo around the disc, strongest near the horizon.
	float glow_amount = pow(clamp(sun_dot * 0.5 + 0.5, 0.0, 1.0), 6.0) * halo;
	col += disc_color * glow_amount * (1.0 - 0.5 * clamp(up, 0.0, 1.0));
	if (stars > 0.0 && up > 0.0) {
		vec2 sp = dir.xz / (0.35 + up) * 90.0;
		float s = step(0.9965, hash(floor(sp))) * (0.5 + 0.5 * sin(TIME * 1.7 + hash(floor(sp) + 3.0) * 6.28));
		col += vec3(0.85, 0.9, 1.0) * s * stars * smoothstep(0.0, 0.25, up);
	}
	float disc = smoothstep(cos(disc_size), cos(disc_size * 0.82), sun_dot);
	col += disc_color * disc * disc_energy;
	if (up > 0.01 && cloud_cover > 0.0) {
		vec2 cp = dir.xz / (up + 0.18) * 1.6 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float d = fbm(cp);
		float d2 = fbm(cp * 2.7 + vec2(4.0, 1.0) - TIME * cloud_speed);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, d * 0.75 + d2 * 0.25);
		float lit = clamp(0.35 + 0.65 * (d2 * 0.6 + 0.4 * clamp(sun_dot, 0.0, 1.0)), 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_color, lit) + disc_color * pow(clamp(sun_dot, 0.0, 1.0), 12.0) * 0.6;
		col = mix(col, cc, c * smoothstep(0.01, 0.2, up) * 0.9);
	}
	COLOR = col * energy;
}
"""

static var _sky_shader: Shader = null


## All tuned values of one mood. Angles are in degrees; x is the pitch (negative shines downwards), y the yaw.
class Mood extends RefCounted:
	var sky_top: Color = Color.BLACK
	var sky_horizon: Color = Color.BLACK
	var sky_ground: Color = Color.BLACK
	var sky_energy: float = 1.0
	var disc_color: Color = Color.WHITE
	var disc_size: float = 0.04
	var disc_energy: float = 6.0
	var halo: float = 0.35
	var cloud_color: Color = Color.WHITE
	var cloud_shade: Color = Color.GRAY
	var cloud_cover: float = 0.45
	var stars: float = 0.0
	var ambient_color: Color = Color.WHITE
	var ambient_energy: float = 0.5
	var key_color: Color = Color.WHITE
	var key_energy: float = 1.0
	var key_rotation: Vector3 = Vector3(-50.0, -35.0, 0.0)
	var key_angular_size: float = 1.5
	var shadow_opacity: float = 1.0
	var fill_color: Color = Color.WHITE
	var fill_energy: float = 0.2
	var fill_rotation: Vector3 = Vector3(-35.0, 80.0, 0.0)
	var rim_color: Color = Color.WHITE
	var rim_energy: float = 0.4
	var rim_rotation: Vector3 = Vector3(-28.0, 145.0, 0.0)
	var fog_color: Color = Color.WHITE
	var fog_energy: float = 1.0
	var fog_density: float = 0.002
	var fog_sun_scatter: float = 0.2
	var fog_height: float = -1.0
	var fog_height_density: float = 0.05
	var fog_sky_affect: float = 0.15
	var volumetric_density: float = 0.01
	var volumetric_albedo: Color = Color.WHITE
	var volumetric_emission: Color = Color.BLACK
	var volumetric_emission_energy: float = 0.0
	var volumetric_anisotropy: float = 0.6
	var shaft_energy: float = 1.0
	var glow_intensity: float = 0.8
	var glow_strength: float = 1.0
	var glow_bloom: float = 0.02
	var glow_threshold: float = 1.0
	var exposure: float = 1.0
	var white: float = 6.0
	var saturation: float = 1.1
	var contrast: float = 1.05
	var brightness: float = 1.0
	var ssao_intensity: float = 2.0
	var ssil_intensity: float = 1.0
	var sdfgi_energy: float = 0.6


# ---------------------------------------------------------------- public API

static func has_mood(mood: StringName) -> bool:
	return MOODS.has(mood)


## The mood a level uses. Unknown "lanka_*" levels are night; anything else is day.
static func mood_for_level(level_id: StringName) -> StringName:
	if _LEVEL_MOODS.has(level_id):
		return _LEVEL_MOODS[level_id]
	if str(level_id).begins_with(NIGHT_LEVEL_PREFIX):
		return &"night"
	return DEFAULT_MOOD


## "low", "medium" or "high". An empty or unknown preset resolves to the saved graphics option.
static func resolve_preset(preset: StringName = &"") -> StringName:
	var wanted: StringName = StringName(str(preset).to_lower())
	if PRESETS.has(wanted):
		return wanted
	var saved: StringName = StringName(Menus.graphics_preset().to_lower())
	if PRESETS.has(saved):
		return saved
	return DEFAULT_PRESET


## The 3D render scale a preset asks for (Menus applies it to the viewport).
static func render_scale(preset: StringName = &"") -> float:
	return LOW_RENDER_SCALE if resolve_preset(preset) == &"low" else 1.0


## The directional shadow atlas size of a preset, in pixels (DESIGN §8: 1024 on Low).
static func shadow_atlas_size(preset: StringName = &"") -> int:
	match resolve_preset(preset):
		&"low":
			return 1024
		&"medium":
			return 2048
		_:
			return 4096


## The tuned values of a mood (a fresh object each call; unknown moods give the day mood).
static func mood_settings(mood: StringName) -> Mood:
	match mood:
		&"dawn":
			return _dawn()
		&"dusk":
			return _dusk()
		&"night":
			return _night()
		&"inferno":
			return _inferno()
		&"divine":
			return _divine()
		_:
			return _day()


## Builds the rig for the mood of `level_id`, with that level's extra tuning (the court is a warm lamp-lit interior).
static func apply_for_level(level_id: StringName, parent: Node3D, preset: StringName = &"") -> Dictionary:
	var mood: StringName = mood_for_level(level_id)
	var spec: Mood = mood_settings(mood)
	_tune_for_level(level_id, spec)
	return _build(mood, spec, parent, preset)


## Builds, or replaces, the environment and the three lights of `mood` under `parent` and returns the nodes.
static func apply(mood: StringName, parent: Node3D, preset: StringName = &"") -> Dictionary:
	var resolved: StringName = mood if has_mood(mood) else DEFAULT_MOOD
	return _build(resolved, mood_settings(resolved), parent, preset)


# ---------------------------------------------------------------- building

static func _build(mood: StringName, spec: Mood, parent: Node3D, preset: StringName) -> Dictionary:
	var quality: StringName = resolve_preset(preset)
	_remove_old_rig(parent)
	var env: Environment = _make_environment(spec, quality)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = WORLD_ENVIRONMENT_NAME
	we.environment = env
	parent.add_child(we)
	var key: DirectionalLight3D = _make_key(spec, quality)
	parent.add_child(key)
	var fill: DirectionalLight3D = _make_side_light(FILL_NAME, spec.fill_color, spec.fill_energy, spec.fill_rotation)
	parent.add_child(fill)
	var rim: DirectionalLight3D = _make_side_light(RIM_NAME, spec.rim_color, spec.rim_energy, spec.rim_rotation)
	parent.add_child(rim)
	if parent.is_inside_tree():
		RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size(quality), true)
	return {
		"mood": mood,
		"preset": quality,
		"world_environment": we,
		"environment": env,
		"key": key,
		"fill": fill,
		"rim": rim,
	}


static func _remove_old_rig(parent: Node3D) -> void:
	var names: Array[StringName] = [WORLD_ENVIRONMENT_NAME, KEY_NAME, FILL_NAME, RIM_NAME]
	for node_name: StringName in names:
		var old: Node = parent.get_node_or_null(NodePath(str(node_name)))
		if old == null:
			continue
		parent.remove_child(old)
		old.queue_free()


static func _make_key(spec: Mood, quality: StringName) -> DirectionalLight3D:
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = KEY_NAME
	key.rotation_degrees = spec.key_rotation
	key.light_color = spec.key_color
	key.light_energy = spec.key_energy
	key.light_angular_distance = spec.key_angular_size if quality != &"low" else 0.0
	key.light_volumetric_fog_energy = spec.shaft_energy
	key.shadow_enabled = true
	key.shadow_opacity = spec.shadow_opacity
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 1.6
	key.shadow_blur = 1.0 if quality == &"low" else 1.6
	key.directional_shadow_max_distance = 90.0
	key.directional_shadow_blend_splits = quality == &"high"
	match quality:
		&"low":
			key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		&"medium":
			key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_:
			key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	key.add_to_group(SUN_GROUP)
	return key


static func _make_side_light(light_name: StringName, color: Color, energy: float, rotation: Vector3) -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = light_name
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	light.light_specular = 0.3
	light.light_volumetric_fog_energy = 0.0
	light.shadow_enabled = false
	light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	return light


static func _make_sky(spec: Mood, quality: StringName) -> Sky:
	if _sky_shader == null:
		_sky_shader = Shader.new()
		_sky_shader.code = _SKY_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _sky_shader
	material.set_shader_parameter("top_color", spec.sky_top)
	material.set_shader_parameter("horizon_color", spec.sky_horizon)
	material.set_shader_parameter("ground_color", spec.sky_ground)
	material.set_shader_parameter("disc_color", spec.disc_color)
	material.set_shader_parameter("cloud_color", spec.cloud_color)
	material.set_shader_parameter("cloud_shade", spec.cloud_shade)
	material.set_shader_parameter("disc_size", spec.disc_size)
	material.set_shader_parameter("disc_energy", spec.disc_energy)
	material.set_shader_parameter("halo", spec.halo)
	material.set_shader_parameter("cloud_cover", spec.cloud_cover)
	material.set_shader_parameter("stars", spec.stars)
	material.set_shader_parameter("energy", spec.sky_energy)
	var sky: Sky = Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_64 if quality == &"low" else Sky.RADIANCE_SIZE_128
	# The clouds drift, but reflections do not need to follow them every frame.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	return sky


static func _make_environment(spec: Mood, quality: StringName) -> Environment:
	var low: bool = quality == &"low"
	var high: bool = quality == &"high"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _make_sky(spec, quality)
	# A flat tinted ambient keeps shadows coloured (indigo or violet, never grey) and identical on every preset.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = spec.ambient_color
	env.ambient_light_energy = spec.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = spec.exposure
	env.tonemap_white = spec.white

	env.glow_enabled = not low
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = spec.glow_intensity
	env.glow_strength = spec.glow_strength
	env.glow_bloom = spec.glow_bloom
	env.glow_hdr_threshold = spec.glow_threshold
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = 14.0
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.35)
	env.set_glow_level(2, 0.9)
	env.set_glow_level(3, 0.7)
	env.set_glow_level(4, 0.45)
	env.set_glow_level(5, 0.3)
	env.set_glow_level(6, 0.0)

	env.ssao_enabled = not low
	env.ssao_radius = 1.2
	env.ssao_intensity = spec.ssao_intensity
	env.ssao_power = 1.6
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.25
	env.ssao_ao_channel_affect = 0.0

	env.ssil_enabled = high
	env.ssil_radius = 5.0
	env.ssil_intensity = spec.ssil_intensity
	env.ssil_sharpness = 0.98
	env.ssil_normal_rejection = 1.0

	env.sdfgi_enabled = high
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.3
	env.sdfgi_energy = spec.sdfgi_energy
	env.sdfgi_read_sky_light = false
	env.sdfgi_bounce_feedback = 0.4
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = spec.fog_color
	env.fog_light_energy = spec.fog_energy
	env.fog_sun_scatter = spec.fog_sun_scatter
	env.fog_sky_affect = spec.fog_sky_affect
	env.fog_aerial_perspective = 0.0
	env.fog_height = spec.fog_height
	if low:
		# Simple fog: the depth and height haze stand in for the missing volumetrics.
		env.fog_density = spec.fog_density * 1.6 + spec.volumetric_density * 0.25
		env.fog_height_density = spec.fog_height_density * 1.3
	else:
		env.fog_density = spec.fog_density
		env.fog_height_density = spec.fog_height_density

	env.volumetric_fog_enabled = not low
	env.volumetric_fog_density = spec.volumetric_density
	env.volumetric_fog_albedo = spec.volumetric_albedo
	env.volumetric_fog_emission = spec.volumetric_emission
	env.volumetric_fog_emission_energy = spec.volumetric_emission_energy
	env.volumetric_fog_anisotropy = spec.volumetric_anisotropy
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_detail_spread = 1.4
	env.volumetric_fog_gi_inject = 0.6 if high else 0.0
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_sky_affect = 0.15
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.9

	env.adjustment_enabled = true
	env.adjustment_saturation = spec.saturation
	env.adjustment_contrast = spec.contrast
	# Without glow the Low preset loses a little lift; give some of it back so it still looks intentional.
	env.adjustment_brightness = spec.brightness * (1.04 if low else 1.0)
	return env


static func _tune_for_level(level_id: StringName, spec: Mood) -> void:
	if not _WARM_INTERIOR_LEVELS.has(level_id):
		return
	# Ravana's court: a lamp-lit golden hall. Warmer bounce, less sky haze, a firelight key and a richer bloom.
	spec.ambient_color = Color(0.4, 0.32, 0.56)
	spec.ambient_energy = 0.3
	spec.contrast = 1.12
	spec.key_color = Color(1.0, 0.8, 0.56)
	spec.key_energy = 0.68
	spec.key_rotation = Vector3(-58.0, -30.0, 0.0)
	spec.fill_color = Color(0.5, 0.42, 0.78)
	spec.fill_energy = 0.14
	spec.rim_color = Color(1.0, 0.62, 0.3)
	spec.rim_energy = 0.3
	spec.fog_color = Color(0.5, 0.33, 0.24)
	spec.fog_density = 0.0003
	spec.fog_height_density = 0.005
	spec.volumetric_density = 0.003
	spec.volumetric_albedo = Color(1.0, 0.8, 0.6)
	spec.volumetric_emission = Color(0.45, 0.22, 0.1)
	spec.volumetric_emission_energy = 0.03
	spec.glow_intensity = 0.9
	spec.glow_threshold = 1.05
	spec.saturation = 1.06


# ---------------------------------------------------------------- the moods

## Sunrise over Mahendra: a low peach-gold sun, long violet shadows, mist in the hollows.
static func _dawn() -> Mood:
	var m: Mood = Mood.new()
	m.sky_top = Color(0.2, 0.33, 0.62)
	m.sky_horizon = Color(1.0, 0.66, 0.46)
	m.sky_ground = Color(0.3, 0.25, 0.38)
	m.sky_energy = 1.0
	m.disc_color = Color(1.0, 0.78, 0.5)
	m.disc_size = 0.05
	m.disc_energy = 7.0
	m.halo = 0.6
	m.cloud_color = Color(1.0, 0.8, 0.68)
	m.cloud_shade = Color(0.52, 0.4, 0.6)
	m.cloud_cover = 0.5
	m.ambient_color = Color(0.5, 0.46, 0.78)
	m.ambient_energy = 0.32
	m.key_color = Color(1.0, 0.8, 0.56)
	m.key_energy = 1.05
	m.key_rotation = Vector3(-30.0, -40.0, 0.0)
	m.key_angular_size = 2.0
	m.fill_color = Color(0.5, 0.62, 1.0)
	m.fill_energy = 0.14
	m.fill_rotation = Vector3(-40.0, 75.0, 0.0)
	m.rim_color = Color(1.0, 0.7, 0.5)
	m.rim_energy = 0.25
	m.rim_rotation = Vector3(-25.0, 150.0, 0.0)
	m.fog_color = Color(0.98, 0.72, 0.6)
	m.fog_density = 0.00048
	m.fog_sun_scatter = 0.35
	m.fog_height = -3.0
	m.fog_height_density = 0.03
	m.volumetric_density = 0.0035
	m.volumetric_albedo = Color(1.0, 0.86, 0.76)
	m.volumetric_anisotropy = 0.7
	m.shaft_energy = 2.2
	m.glow_intensity = 0.85
	m.glow_threshold = 1.05
	m.glow_bloom = 0.03
	m.saturation = 1.14
	m.contrast = 1.06
	m.brightness = 1.0
	m.ssao_intensity = 2.2
	return m


## High sun over the open ocean: clear, bright, saturated, with a thin sea haze.
static func _day() -> Mood:
	var m: Mood = Mood.new()
	m.sky_top = Color(0.1, 0.34, 0.78)
	m.sky_horizon = Color(0.66, 0.84, 0.96)
	m.sky_ground = Color(0.1, 0.25, 0.4)
	m.sky_energy = 1.1
	m.disc_color = Color(1.0, 0.96, 0.84)
	m.disc_size = 0.035
	m.disc_energy = 9.0
	m.halo = 0.3
	m.cloud_color = Color(1.0, 0.98, 0.94)
	m.cloud_shade = Color(0.56, 0.62, 0.8)
	m.cloud_cover = 0.42
	m.ambient_color = Color(0.5, 0.56, 0.86)
	m.ambient_energy = 0.3
	m.key_color = Color(1.0, 0.94, 0.8)
	m.key_energy = 0.82
	m.key_rotation = Vector3(-55.0, -35.0, 0.0)
	m.key_angular_size = 1.2
	m.fill_color = Color(0.56, 0.72, 1.0)
	m.fill_energy = 0.14
	m.fill_rotation = Vector3(-40.0, 80.0, 0.0)
	m.rim_color = Color(1.0, 0.9, 0.72)
	m.rim_energy = 0.2
	m.fog_color = Color(0.68, 0.82, 0.95)
	m.fog_density = 0.00036
	m.fog_sun_scatter = 0.2
	m.fog_height = -3.0
	m.fog_height_density = 0.015
	m.volumetric_density = 0.0015
	m.volumetric_albedo = Color(0.9, 0.95, 1.0)
	m.volumetric_anisotropy = 0.6
	m.shaft_energy = 1.2
	m.glow_intensity = 0.7
	m.glow_threshold = 1.2
	m.glow_bloom = 0.02
	m.saturation = 1.16
	m.contrast = 1.07
	m.ssao_intensity = 2.0
	return m


## Sunset at the gate of Lanka: amber light raking in, violet sky, deep indigo shadows.
static func _dusk() -> Mood:
	var m: Mood = Mood.new()
	m.sky_top = Color(0.16, 0.14, 0.4)
	m.sky_horizon = Color(0.98, 0.45, 0.28)
	m.sky_ground = Color(0.16, 0.12, 0.26)
	m.sky_energy = 0.9
	m.disc_color = Color(1.0, 0.56, 0.28)
	m.disc_size = 0.055
	m.disc_energy = 7.0
	m.halo = 0.7
	m.cloud_color = Color(1.0, 0.6, 0.45)
	m.cloud_shade = Color(0.36, 0.24, 0.5)
	m.cloud_cover = 0.52
	m.stars = 0.25
	m.ambient_color = Color(0.36, 0.36, 0.74)
	m.ambient_energy = 0.32
	m.key_color = Color(1.0, 0.74, 0.5)
	m.key_energy = 1.0
	m.key_rotation = Vector3(-26.0, -48.0, 0.0)
	m.key_angular_size = 2.2
	m.fill_color = Color(0.42, 0.48, 0.95)
	m.fill_energy = 0.15
	m.fill_rotation = Vector3(-42.0, 70.0, 0.0)
	m.rim_color = Color(1.0, 0.5, 0.4)
	m.rim_energy = 0.28
	m.rim_rotation = Vector3(-24.0, 140.0, 0.0)
	m.fog_color = Color(0.7, 0.42, 0.42)
	m.fog_density = 0.0003
	m.fog_sun_scatter = 0.4
	m.fog_height = -3.0
	m.fog_height_density = 0.0225
	m.volumetric_density = 0.0035
	m.volumetric_albedo = Color(1.0, 0.76, 0.66)
	m.volumetric_anisotropy = 0.72
	m.shaft_energy = 2.4
	m.glow_intensity = 0.9
	m.glow_threshold = 1.05
	m.glow_bloom = 0.03
	m.saturation = 1.06
	m.contrast = 1.08
	m.ssao_intensity = 2.3
	return m


## Moonlit Lanka: silver-blue moon, indigo air, a faint warm bounce from the lamps so stone is not a single blue,
## and gold left to glow. Readable, never black.
static func _night() -> Mood:
	var m: Mood = Mood.new()
	m.sky_top = Color(0.02, 0.03, 0.1)
	m.sky_horizon = Color(0.1, 0.12, 0.3)
	m.sky_ground = Color(0.01, 0.012, 0.04)
	m.sky_energy = 1.0
	m.disc_color = Color(0.87, 0.9, 0.95)
	m.disc_size = 0.045
	m.disc_energy = 3.0
	m.halo = 0.18
	m.cloud_color = Color(0.36, 0.42, 0.62)
	m.cloud_shade = Color(0.07, 0.08, 0.2)
	m.cloud_cover = 0.4
	m.stars = 1.6
	m.ambient_color = Color(0.2, 0.25, 0.54)
	m.ambient_energy = 0.34
	m.key_color = Color(0.56, 0.68, 1.0)
	m.key_energy = 0.5
	m.key_rotation = Vector3(-52.0, -30.0, 0.0)
	m.key_angular_size = 1.6
	m.shadow_opacity = 0.9
	m.fill_color = Color(0.72, 0.5, 0.4)
	m.fill_energy = 0.1
	m.fill_rotation = Vector3(-38.0, 85.0, 0.0)
	m.rim_color = Color(0.4, 0.7, 1.0)
	m.rim_energy = 0.2
	m.fog_color = Color(0.08, 0.11, 0.34)
	m.fog_density = 0.0006
	m.fog_sun_scatter = 0.1
	m.fog_height = -3.0
	m.fog_height_density = 0.02
	m.volumetric_density = 0.003
	m.volumetric_albedo = Color(0.62, 0.7, 1.0)
	m.volumetric_emission = Color(0.06, 0.07, 0.2)
	m.volumetric_emission_energy = 0.04
	m.volumetric_anisotropy = 0.55
	m.shaft_energy = 1.4
	m.glow_intensity = 1.0
	m.glow_threshold = 0.95
	m.glow_bloom = 0.04
	m.saturation = 1.08
	m.contrast = 1.1
	m.brightness = 1.02
	m.ssao_intensity = 1.8
	return m


## Lanka burning, seen at night: a black smoky sky with an orange glow on the horizon, a low fire-coloured key
## raking in from the side, a cool moonlit fill from above so stone keeps its own colour, and a red-orange rim
## that shines UP from the fires below. The haze is thin and dark: the iso camera looks through a constant depth
## of it, so a bright or dense fog would wash the whole frame red.
static func _inferno() -> Mood:
	var m: Mood = Mood.new()
	m.sky_top = Color(0.02, 0.016, 0.03)
	m.sky_horizon = Color(0.62, 0.24, 0.06)
	m.sky_ground = Color(0.03, 0.014, 0.012)
	m.sky_energy = 0.8
	m.disc_color = Color(1.0, 0.5, 0.2)
	m.disc_size = 0.04
	m.disc_energy = 0.6
	m.halo = 0.15
	m.cloud_color = Color(0.5, 0.2, 0.08)
	m.cloud_shade = Color(0.03, 0.022, 0.03)
	m.cloud_cover = 0.8
	m.stars = 0.1
	m.ambient_color = Color(0.2, 0.2, 0.4)
	m.ambient_energy = 0.3
	m.key_color = Color(1.0, 0.64, 0.38)
	m.key_energy = 0.85
	m.key_rotation = Vector3(-31.0, -42.0, 0.0)
	m.key_angular_size = 1.0
	m.shadow_opacity = 0.95
	m.fill_color = Color(0.45, 0.56, 0.92)
	m.fill_energy = 0.3
	m.fill_rotation = Vector3(-62.0, 80.0, 0.0)
	m.rim_color = Color(1.0, 0.36, 0.14)
	m.rim_energy = 0.32
	m.rim_rotation = Vector3(16.0, 145.0, 0.0)
	m.fog_color = Color(0.2, 0.085, 0.05)
	m.fog_energy = 0.8
	m.fog_density = 0.00016
	m.fog_sun_scatter = 0.1
	m.fog_height = -3.0
	m.fog_height_density = 0.008
	m.fog_sky_affect = 0.05
	m.volumetric_density = 0.0009
	m.volumetric_albedo = Color(0.7, 0.5, 0.4)
	m.volumetric_emission = Color(0.6, 0.2, 0.06)
	m.volumetric_emission_energy = 0.006
	m.volumetric_anisotropy = 0.6
	m.shaft_energy = 1.2
	m.glow_intensity = 1.0
	m.glow_strength = 1.0
	m.glow_threshold = 1.0
	m.glow_bloom = 0.03
	m.saturation = 1.06
	m.contrast = 1.14
	m.brightness = 1.0
	m.ssao_intensity = 2.4
	return m


## Shloka cards and the epilogue: soft gold radiance, high key, gentle contrast, generous bloom.
static func _divine() -> Mood:
	var m: Mood = Mood.new()
	m.sky_top = Color(0.42, 0.56, 0.9)
	m.sky_horizon = Color(1.0, 0.88, 0.62)
	m.sky_ground = Color(0.6, 0.48, 0.42)
	m.sky_energy = 1.15
	m.disc_color = Color(1.0, 0.9, 0.62)
	m.disc_size = 0.06
	m.disc_energy = 8.0
	m.halo = 0.9
	m.cloud_color = Color(1.0, 0.95, 0.82)
	m.cloud_shade = Color(0.72, 0.62, 0.74)
	m.cloud_cover = 0.5
	m.ambient_color = Color(0.74, 0.64, 0.82)
	m.ambient_energy = 0.36
	m.key_color = Color(1.0, 0.88, 0.62)
	m.key_energy = 0.9
	m.key_rotation = Vector3(-42.0, -38.0, 0.0)
	m.key_angular_size = 3.0
	m.shadow_opacity = 0.8
	m.fill_color = Color(0.66, 0.74, 1.0)
	m.fill_energy = 0.18
	m.fill_rotation = Vector3(-40.0, 78.0, 0.0)
	m.rim_color = Color(1.0, 0.86, 0.56)
	m.rim_energy = 0.35
	m.rim_rotation = Vector3(-26.0, 148.0, 0.0)
	m.fog_color = Color(1.0, 0.86, 0.6)
	m.fog_density = 0.00048
	m.fog_sun_scatter = 0.5
	m.fog_height = -3.0
	m.fog_height_density = 0.0175
	m.volumetric_density = 0.0035
	m.volumetric_albedo = Color(1.0, 0.92, 0.74)
	m.volumetric_emission = Color(1.0, 0.8, 0.45)
	m.volumetric_emission_energy = 0.016
	m.volumetric_anisotropy = 0.75
	m.shaft_energy = 2.6
	m.glow_intensity = 1.15
	m.glow_strength = 1.1
	m.glow_threshold = 1.0
	m.glow_bloom = 0.05
	m.saturation = 1.1
	m.contrast = 1.0
	m.brightness = 1.02
	m.ssao_intensity = 1.6
	return m
