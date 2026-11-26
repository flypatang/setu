class_name SkyKit
extends RefCounted
## Procedural painted sky (docs/ART.md "Environment"): gradient, two drifting cloud layers, a sun or moon disc that
## follows the first DirectionalLight3D (LIGHT0), stars at night, a warm horizon at dawn and dusk and smoky orange
## for the burning of Lanka. Everything is generated in the shader; there are no textures.
##
## Use: environment.background_mode = Environment.BG_SKY; environment.sky = SkyKit.make_sky(&"dusk").
## Unknown moods fall back to DEFAULT_MOOD. Fog and water can match the sky with horizon_colour() / zenith_colour().

const MOODS: Array[StringName] = [&"dawn", &"day", &"dusk", &"night", &"inferno", &"divine"]
const DEFAULT_MOOD: StringName = &"day"
## The radiance map is refreshed every frame because the clouds move, so it stays small.
const RADIANCE_SIZE: Sky.RadianceSize = Sky.RADIANCE_SIZE_256

const SHADER_CODE: String = """shader_type sky;

uniform vec3 zenith_colour : source_color = vec3(0.16, 0.40, 0.78);
uniform vec3 horizon_colour : source_color = vec3(0.72, 0.86, 0.95);
uniform vec3 ground_colour : source_color = vec3(0.10, 0.20, 0.30);
uniform float gradient_curve = 0.55;
uniform vec3 glow_colour : source_color = vec3(1.0, 0.8, 0.5);
uniform float glow_strength = 0.2;
uniform vec3 cloud_lit_colour : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_colour : source_color = vec3(0.6, 0.66, 0.8);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 1.0) = 0.22;
uniform float high_cloud_cover : hint_range(0.0, 1.0) = 0.35;
uniform float cloud_speed = 0.006;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float sun_size = 0.045;
uniform float sun_energy = 6.0;
uniform float sun_halo = 0.35;
uniform float moon_amount : hint_range(0.0, 1.0) = 0.0;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sky_energy = 1.0;
uniform vec3 fallback_light_direction = vec3(0.35, 0.55, 0.75);
uniform vec3 fallback_light_colour : source_color = vec3(1.0, 0.95, 0.85);

// Integer hash: float "fract(sin)" style hashes differ by a rounding step between neighbouring cells on some GPUs,
// which shows as hard seams in the noise.
float hash21(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint n = uint(q.x) * 1597334677u ^ uint(q.y) * 3812015801u;
	n = (n ^ (n >> 15u)) * 2246822519u;
	n ^= n >> 13u;
	return float(n & 16777215u) / 16777215.0;
}

float hash31(vec3 p) {
	ivec3 q = ivec3(floor(p));
	uint n = uint(q.x) * 1597334677u ^ uint(q.y) * 3812015801u ^ uint(q.z) * 2798796415u;
	n = (n ^ (n >> 15u)) * 2246822519u;
	n ^= n >> 13u;
	return float(n & 16777215u) / 16777215.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += vnoise(p) * amp;
		norm += amp;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 17.3;
		amp *= 0.5;
	}
	return sum / norm;
}

// Returns (light 0..1, alpha) of one cloud layer. `stretch` pulls the noise into streaks for the high layer.
vec2 cloud_layer(vec3 dir, vec3 sun_dir, float scale, vec2 stretch, float speed, float cover, float softness,
		float seed, int octaves) {
	float up = max(dir.y, 0.0);
	vec2 plane = dir.xz / (up + 0.16);
	vec2 wind = normalize(wind_direction);
	vec2 uv = plane * scale * stretch + wind * TIME * speed + seed;
	// A slow domain warp gives brushed, billowing edges instead of plain noise blobs.
	vec2 warp = vec2(vnoise(uv * 0.7 + 3.1), vnoise(uv * 0.7 + 9.7)) - 0.5;
	uv += warp * 0.9;
	float density = fbm(uv, octaves);
	// Erode the edges with finer noise so the outline is crisp and lacy.
	density -= (fbm(uv * 3.3 + 21.0, 3) - 0.5) * 0.16;
	float threshold = 1.0 - cover;
	float alpha = smoothstep(threshold - softness * 0.5, threshold + softness * 0.5, density);
	// Light: the side of the cloud that faces the sun has less cloud between it and the sun.
	vec2 to_sun = sun_dir.xz / (max(sun_dir.y, 0.0) + 0.16) - plane;
	vec2 step_dir = to_sun / (length(to_sun) + 0.001);
	float toward = fbm(uv + step_dir * 0.45 * stretch, max(octaves - 2, 2));
	float light = clamp(0.55 + (density - toward) * 3.2 + (1.0 - alpha) * 0.35, 0.0, 1.0);
	// Three soft painted bands instead of a smooth ramp.
	light = mix(light, (smoothstep(0.2, 0.35, light) + smoothstep(0.5, 0.65, light) + smoothstep(0.8, 0.9, light)) / 3.0, 0.6);
	alpha *= smoothstep(0.0, 0.2, dir.y);
	return vec2(light, alpha);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = normalize(fallback_light_direction);
	vec3 sun_colour = fallback_light_colour;
	if (LIGHT0_ENABLED) {
		sun_dir = normalize(LIGHT0_DIRECTION);
		sun_colour = LIGHT0_COLOR;
	}
	float sun_dot = dot(dir, sun_dir);
	float up = clamp(dir.y, 0.0, 1.0);

	// Gradient, with the ground colour below the horizon (seen in reflections).
	vec3 col = mix(horizon_colour, zenith_colour, pow(up, gradient_curve));
	col = mix(col, ground_colour, smoothstep(0.0, -0.3, dir.y));

	// Warm band along the horizon on the sun's side, and a wide halo around the disc.
	vec2 flat_dir = dir.xz / (length(dir.xz) + 0.0001);
	vec2 flat_sun = sun_dir.xz / (length(sun_dir.xz) + 0.0001);
	float side = pow(max(dot(flat_dir, flat_sun), 0.0) * 0.75 + 0.25, 2.0);
	float band = exp(-abs(dir.y) * 5.5);
	col += glow_colour * glow_strength * band * side;
	float halo = pow(max(sun_dot, 0.0), 24.0) * 0.6 + pow(max(sun_dot, 0.0), 5.0) * 0.25;
	col += mix(glow_colour, sun_colour, 0.5) * halo * sun_halo;

	// Stars: one per cell of a 3D grid cut by the view sphere. Skipped for the blurry radiance map.
	if (star_amount > 0.001 && !AT_CUBEMAP_PASS) {
		vec3 sp = dir * 90.0;
		vec3 cell = floor(sp);
		float pick = hash31(cell);
		vec3 offset = vec3(hash31(cell + 11.0), hash31(cell + 23.0), hash31(cell + 37.0)) - 0.5;
		float dist = length(fract(sp) - 0.5 - offset * 0.6);
		float size = mix(0.05, 0.16, hash31(cell + 51.0));
		float twinkle = 0.7 + 0.3 * sin(TIME * (1.0 + pick * 3.0) + pick * 40.0);
		float star = step(0.9, pick) * smoothstep(size, 0.0, dist) * twinkle;
		vec3 star_tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.7), hash31(cell + 77.0));
		col += star_tint * star * star_amount * 2.2 * smoothstep(0.0, 0.25, dir.y);
	}

	// Sun or moon disc. The moon is larger, softer and has faint maria.
	float disc_size = mix(sun_size, sun_size * 1.5, moon_amount);
	float disc = smoothstep(cos(disc_size), cos(disc_size * 0.86), sun_dot);
	vec3 disc_colour = sun_colour * sun_energy;
	if (moon_amount > 0.001) {
		vec3 axis_x = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.001)));
		vec3 axis_y = cross(axis_x, sun_dir);
		vec2 face = vec2(dot(dir, axis_x), dot(dir, axis_y)) / max(disc_size, 0.001);
		float maria = fbm(face * 2.3 + 4.0, 3);
		float limb = 1.0 - 0.25 * dot(face, face);
		vec3 moon_colour = sun_colour * sun_energy * (0.72 + 0.4 * smoothstep(0.35, 0.7, maria)) * limb;
		disc_colour = mix(disc_colour, moon_colour, moon_amount);
	}
	vec3 disc_add = disc_colour * disc * step(-0.02, dir.y);

	// Clouds: a high streaked layer under a low billowing layer.
	int octaves = AT_CUBEMAP_PASS ? 3 : 5;
	vec2 high = cloud_layer(dir, sun_dir, 0.55, vec2(0.45, 1.6), cloud_speed * 0.5, high_cloud_cover * 0.8,
			cloud_softness * 1.4, 41.0, octaves - 1);
	vec2 low = cloud_layer(dir, sun_dir, 1.15, vec2(1.0, 1.0), cloud_speed, cloud_cover, cloud_softness, 7.0, octaves);
	high.y *= 0.5;
	float near_sun = pow(max(sun_dot, 0.0), 14.0);
	vec3 lit = cloud_lit_colour + mix(glow_colour, sun_colour, 0.5) * near_sun * 0.3;
	// Clouds low on the horizon take the horizon colour, so they sit in the air instead of on top of it.
	float haze = exp(-up * 7.0);
	vec3 high_col = mix(mix(cloud_shade_colour, lit, high.x * 0.6 + 0.4), horizon_colour + glow_colour * glow_strength * side, haze * 0.8);
	vec3 low_col = mix(mix(cloud_shade_colour, lit, low.x), horizon_colour + glow_colour * glow_strength * side, haze * 0.7);
	float cover_total = 1.0 - (1.0 - high.y) * (1.0 - low.y);
	col = mix(col, high_col, high.y);
	col = mix(col, low_col, low.y);
	// The disc is painted over the clouds, only dimmed by them, so it always reads as a clean shape.
	col += disc_add * (1.0 - cover_total * 0.55);
	// A thin silver lining where the low layer thins out in front of the light.
	col += sun_colour * near_sun * low.y * (1.0 - low.y) * 1.2 * sun_halo;

	COLOR = col * sky_energy;
}
"""

static var _shader: Shader = null


## The shared sky shader (compiled once).
static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader


## `mood` if it is known, else DEFAULT_MOOD.
static func resolve_mood(mood: StringName) -> StringName:
	return mood if MOODS.has(mood) else DEFAULT_MOOD


## Uniform values of the sky shader for a mood (keys are the shader's uniform names).
static func mood_params(mood: StringName) -> Dictionary[String, Variant]:
	var p: Dictionary[String, Variant] = {}
	match resolve_mood(mood):
		&"dawn":
			p = {
				"zenith_colour": Color("#3F5E9E"), "horizon_colour": Color("#F4B48C"),
				"ground_colour": Color("#2B3555"), "gradient_curve": 0.5,
				"glow_colour": Palette.SAFFRON.lerp(Palette.FIRE_EDGE, 0.35), "glow_strength": 0.55,
				"cloud_lit_colour": Color("#FFD9B8"), "cloud_shade_colour": Color("#8E7FB0"),
				"cloud_cover": 0.5, "cloud_softness": 0.16, "high_cloud_cover": 0.5, "cloud_speed": 0.005,
				"sun_size": 0.05, "sun_energy": 5.0, "sun_halo": 0.6, "moon_amount": 0.0, "star_amount": 0.08,
				"sky_energy": 1.0,
			}
		&"dusk":
			p = {
				"zenith_colour": Palette.SKY_DUSK.lerp(Color("#3A2F6B"), 0.5), "horizon_colour": Color("#E8804A"),
				"ground_colour": Palette.NIGHT_INDIGO, "gradient_curve": 0.36,
				"glow_colour": Palette.SAFFRON.lerp(Palette.SINDOOR, 0.3), "glow_strength": 0.75,
				"cloud_lit_colour": Color("#FFB070"), "cloud_shade_colour": Color("#4A3A6E"),
				"cloud_cover": 0.52, "cloud_softness": 0.16, "high_cloud_cover": 0.5, "cloud_speed": 0.004,
				"sun_size": 0.046, "sun_energy": 5.0, "sun_halo": 0.75, "moon_amount": 0.0, "star_amount": 0.25,
				"sky_energy": 1.0,
			}
		&"night":
			p = {
				"zenith_colour": Palette.NIGHT_INDIGO.darkened(0.55), "horizon_colour": Color("#27376A"),
				"ground_colour": Palette.NIGHT_INDIGO.darkened(0.6), "gradient_curve": 0.5,
				"glow_colour": Color("#4C6FB5"), "glow_strength": 0.25,
				"cloud_lit_colour": Palette.MOON.darkened(0.35), "cloud_shade_colour": Palette.NIGHT_INDIGO.lightened(0.06),
				"cloud_cover": 0.38, "cloud_softness": 0.26, "high_cloud_cover": 0.3, "cloud_speed": 0.004,
				"sun_size": 0.04, "sun_energy": 1.5, "sun_halo": 0.4, "moon_amount": 1.0, "star_amount": 1.0,
				"sky_energy": 1.0,
			}
		&"inferno":
			# Lanka burns at night: moon_amount stays 1 on purpose, so the light source reads as a faint moon
			# behind the smoke (low sun_energy and halo) and never as a daytime sun.
			p = {
				"zenith_colour": Color("#1C0F14"), "horizon_colour": Color("#C2481A"),
				"ground_colour": Color("#2A0E0A"), "gradient_curve": 0.85,
				"glow_colour": Palette.FIRE_CORE.lerp(Palette.SAFFRON, 0.6), "glow_strength": 0.45,
				"cloud_lit_colour": Color("#963C1A"), "cloud_shade_colour": Color("#1E1216"),
				"cloud_cover": 0.6, "cloud_softness": 0.3, "high_cloud_cover": 0.55, "cloud_speed": 0.012,
				"sun_size": 0.04, "sun_energy": 0.8, "sun_halo": 0.15, "moon_amount": 1.0, "star_amount": 0.0,
				"sky_energy": 1.0,
			}
		&"divine":
			p = {
				"zenith_colour": Color("#4F86CC"), "horizon_colour": Color("#F6D58E"),
				"ground_colour": Color("#C99A45"), "gradient_curve": 0.7,
				"glow_colour": Palette.GOLD, "glow_strength": 0.3,
				"cloud_lit_colour": Color("#FBE6B4"), "cloud_shade_colour": Color("#C98F5A"),
				"cloud_cover": 0.5, "cloud_softness": 0.16, "high_cloud_cover": 0.5, "cloud_speed": 0.003,
				"sun_size": 0.05, "sun_energy": 6.0, "sun_halo": 0.55, "moon_amount": 0.0, "star_amount": 0.0,
				"sky_energy": 0.85,
			}
		_:
			p = {
				"zenith_colour": Color("#2466BE"), "horizon_colour": Color("#B9DDF2"),
				"ground_colour": Palette.DEEP_OCEAN, "gradient_curve": 0.55,
				"glow_colour": Color("#FFE9B8"), "glow_strength": 0.18,
				"cloud_lit_colour": Color("#FFFFFF"), "cloud_shade_colour": Color("#8FA3CC"),
				"cloud_cover": 0.5, "cloud_softness": 0.1, "high_cloud_cover": 0.38, "cloud_speed": 0.006,
				"sun_size": 0.042, "sun_energy": 7.0, "sun_halo": 0.4, "moon_amount": 0.0, "star_amount": 0.0,
				"sky_energy": 1.0,
			}
	return p


## A new ShaderMaterial (shader_type sky) set up for `mood`.
static func sky_material(mood: StringName) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader()
	apply_mood(material, mood)
	return material


## Sets the uniforms of an existing sky material to `mood` (for example to change the mood during a cutscene).
static func apply_mood(material: ShaderMaterial, mood: StringName) -> void:
	var params: Dictionary[String, Variant] = mood_params(mood)
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	material.set_meta(&"mood", resolve_mood(mood))


## A Sky resource for Environment.sky. The sun or moon disc follows the first DirectionalLight3D in the scene.
static func make_sky(mood: StringName) -> Sky:
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material(mood)
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = RADIANCE_SIZE
	return sky


## Colour of the sky at the horizon: use it for depth fog so distant geometry melts into the sky.
static func horizon_colour(mood: StringName) -> Color:
	return mood_params(mood)["horizon_colour"] as Color


## Colour of the sky overhead.
static func zenith_colour(mood: StringName) -> Color:
	return mood_params(mood)["zenith_colour"] as Color
