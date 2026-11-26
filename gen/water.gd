class_name WaterKit
extends RefCounted
## Painted ocean (docs/ART.md "Environment"): four Gerstner waves, a fresnel reflection of the sky colours of the
## mood (SkyKit), a depth tint from shallow turquoise to Palette.DEEP_OCEAN, foam on crests and where the water
## meets geometry, and sun or moon sparkles. Lighting comes from the scene's DirectionalLight3D.
##
## ocean() returns a ready MeshInstance3D; place its origin at sea level. The wave phase is computed in the
## ocean's LOCAL space, so the node may be moved anywhere (the waves travel with it), but it must stay unrotated
## and unscaled: the shader and the CPU mirror both assume local axes parallel to the world's, in metres.
## wave_offset() mirrors the shader on the CPU so that boats, rocks or Hanuman's shadow can follow the surface;
## surface_height_at() does the world-to-local conversion for an ocean node.

## Each wave: x, y = travel direction (normalised in use), z = steepness (0..1, the sum stays below 1 so crests
## never loop), w = wavelength in metres. Scaled by the `wave_scale` argument of ocean().
const WAVES: Array[Vector4] = [
	Vector4(1.0, 0.3, 0.15, 15.0),
	Vector4(0.55, 0.85, 0.13, 8.6),
	Vector4(-0.35, 1.0, 0.11, 4.9),
	Vector4(0.9, -0.5, 0.09, 2.7),
]
const GRAVITY: float = 9.8
const MAX_SUBDIVISIONS: int = 255
const MIN_SUBDIVISIONS: int = 16
const TARGET_CELL_SIZE: float = 0.75
const OCEAN_NAME: String = "Ocean"
const FOAM_NAME: String = "ShorelineFoam"

## Placeholders in SHADER_CODE, filled in by shader() for each variant.
const DEPTH_DEFINE_TOKEN: String = "/*@DEPTH_DEFINE@*/"
const ALPHA_WRITE_TOKEN: String = "/*@ALPHA_WRITE@*/"

const SHADER_CODE: String = """shader_type spatial;
/*@DEPTH_DEFINE@*/
render_mode cull_back, specular_disabled;

#ifdef DEPTH_EFFECTS
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
#endif

uniform vec3 deep_colour : source_color = vec3(0.055, 0.231, 0.361);
uniform vec3 shallow_colour : source_color = vec3(0.10, 0.55, 0.60);
uniform vec3 scatter_colour : source_color = vec3(0.15, 0.70, 0.62);
uniform vec3 foam_colour : source_color = vec3(0.95, 0.97, 1.0);
uniform vec3 sky_horizon_colour : source_color = vec3(0.72, 0.86, 0.95);
uniform vec3 sky_zenith_colour : source_color = vec3(0.16, 0.40, 0.78);
uniform float reflection_strength = 1.0;
uniform float sparkle_strength = 1.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.5;
uniform float shore_foam_width = 0.9;
uniform float depth_fade = 3.0;
uniform float ripple_strength = 0.35;
uniform float distance_fade = 220.0;
uniform float wave_scale = 1.0;
uniform float wave_speed = 1.0;
uniform float cell_size = 1.0;
uniform vec4 wave_a = vec4(1.0, 0.3, 0.15, 15.0);
uniform vec4 wave_b = vec4(0.55, 0.85, 0.13, 8.6);
uniform vec4 wave_c = vec4(-0.35, 1.0, 0.11, 4.9);
uniform vec4 wave_d = vec4(0.9, -0.5, 0.09, 2.7);

varying vec2 base_xz;
varying vec3 world_position;
varying vec3 shade_normal;
varying vec3 wave_normal;
varying float sparkle_mask;

// Integer hash: float "fract(sin)" style hashes differ by a rounding step between neighbouring cells on some GPUs,
// which shows as hard seams in the noise.
float hash21(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint n = uint(q.x) * 1597334677u ^ uint(q.y) * 3812015801u;
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

float fbm3(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.13 + 5.2) * 0.3 + vnoise(p * 4.37 + 11.7) * 0.15;
}

// One Gerstner wave: returns the offset of the point `p` and accumulates the surface tangents.
vec3 gerstner(vec4 wave, vec2 p, float t, float weight, inout vec3 tangent, inout vec3 binormal) {
	float wavelength = wave.w * wave_scale;
	float k = 6.2831853 / wavelength;
	float c = sqrt(9.8 / k) * wave_speed;
	vec2 d = normalize(wave.xy);
	float f = k * (dot(d, p) - c * t);
	float steep = wave.z * weight;
	float a = steep / k;
	tangent += vec3(-d.x * d.x * steep * sin(f), d.x * steep * cos(f), -d.x * d.y * steep * sin(f));
	binormal += vec3(-d.x * d.y * steep * sin(f), d.y * steep * cos(f), -d.y * d.y * steep * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

// Waves shorter than a few grid cells would alias in the mesh, so they fade out of the displacement.
float mesh_weight(vec4 wave) {
	return smoothstep(3.0, 5.0, wave.w * wave_scale / max(cell_size, 0.001));
}

void vertex() {
	// Ocean-local rest position (the node is unrotated and unscaled, see WaterKit), so that the waves keep the
	// same phase as WaterKit.wave_offset() wherever the ocean is placed.
	base_xz = VERTEX.xz;
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	vec3 offset = gerstner(wave_a, base_xz, TIME, mesh_weight(wave_a), t, b);
	offset += gerstner(wave_b, base_xz, TIME, mesh_weight(wave_b), t, b);
	offset += gerstner(wave_c, base_xz, TIME, mesh_weight(wave_c), t, b);
	offset += gerstner(wave_d, base_xz, TIME, mesh_weight(wave_d), t, b);
	VERTEX += offset;
	NORMAL = normalize(cross(b, t));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Analytic wave normal and height per pixel, so shading stays smooth on a coarse mesh.
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	vec3 offset = gerstner(wave_a, base_xz, TIME, 1.0, t, b);
	offset += gerstner(wave_b, base_xz, TIME, 1.0, t, b);
	offset += gerstner(wave_c, base_xz, TIME, 1.0, t, b);
	offset += gerstner(wave_d, base_xz, TIME, 1.0, t, b);
	vec3 n = normalize(cross(b, t));
	wave_normal = n;
	float amp_sum = (wave_a.z * wave_a.w + wave_b.z * wave_b.w + wave_c.z * wave_c.w + wave_d.z * wave_d.w)
			* wave_scale / 6.2831853;
	float crest = clamp(offset.y / max(amp_sum, 0.001) * 0.5 + 0.5, 0.0, 1.0);

	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	float cam_dist = length(world_position - cam_pos);
	float far_fade = exp(-cam_dist / max(distance_fade, 0.001));

	// Small ripples from two scrolling noise fields; they fade with distance so the horizon stays calm.
	vec2 rp = base_xz / sqrt(wave_scale);
	float e = 0.12;
	vec2 r1 = rp * 0.9 + vec2(TIME * 0.35, TIME * 0.22);
	vec2 r2 = rp * 2.1 + vec2(-TIME * 0.28, TIME * 0.41);
	float h0 = fbm3(r1) + fbm3(r2) * 0.5;
	float hx = fbm3(r1 + vec2(e, 0.0)) + fbm3(r2 + vec2(e, 0.0)) * 0.5;
	float hz = fbm3(r1 + vec2(0.0, e)) + fbm3(r2 + vec2(0.0, e)) * 0.5;
	vec2 ripple = vec2(h0 - hx, h0 - hz) / e * ripple_strength * (0.25 + 0.75 * far_fade);
	n = normalize(n + vec3(ripple.x, 0.0, ripple.y));
	// Far away, sub-pixel waves would shimmer: relax the normal toward flat.
	n = normalize(mix(vec3(0.0, 1.0, 0.0), n, 0.35 + 0.65 * far_fade));

	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float ndv = clamp(dot(n, view_world), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);

	// Body colour: deep in the troughs and when seen from above, lighter and greener through the crests.
	vec3 body = mix(deep_colour, shallow_colour, smoothstep(0.35, 1.0, crest) * 0.55);
	body = mix(body, deep_colour * 0.7, (1.0 - crest) * 0.35 * ndv);
	// Broad painted patches of colour, so that a large sea is never one flat tone.
	float patches = fbm3(base_xz / wave_scale * 0.035 + vec2(TIME * 0.004, 0.0));
	body *= 0.82 + 0.36 * patches;
	body = mix(body, shallow_colour, smoothstep(0.55, 0.9, patches) * 0.18);

	float foam = 0.0;
#ifdef DEPTH_EFFECTS
	float alpha = 1.0;
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	scene_view.xyz /= scene_view.w;
	float thickness = max(VERTEX.z - scene_view.z, 0.0);
	float shallow = exp(-thickness / max(depth_fade, 0.001));
	body = mix(body, shallow_colour * 1.1, shallow * 0.8);
	alpha = mix(1.0, 0.7, shallow * shallow);
	// Shoreline foam: a solid lip at the contact line and broken lace that pulses outwards behind it.
	float lace = fbm3(base_xz * 1.6 + vec2(TIME * 0.2, -TIME * 0.15));
	float reach = thickness / max(shore_foam_width, 0.001);
	float pulse = 0.5 + 0.5 * sin(reach * 5.0 - TIME * 1.6 + lace * 3.0);
	float shore = (1.0 - smoothstep(0.0, 0.35, reach)) + (1.0 - smoothstep(0.2, 1.6, reach)) * smoothstep(0.45, 0.7, lace * 0.6 + pulse * 0.4);
	foam = clamp(shore, 0.0, 1.0);
	alpha = mix(alpha, 1.0, foam);
#endif
	// Crest foam: streaks of lace on the highest, steepest parts of the waves.
	vec2 crest_dir = normalize(wave_a.xy);
	vec2 along = vec2(dot(rp, crest_dir) * 2.6, dot(rp, vec2(-crest_dir.y, crest_dir.x)) * 0.7) + offset.xz * 0.5;
	float lace2 = fbm3(along + vec2(TIME * 0.1, TIME * 0.04));
	float fine = fbm3(rp * 4.5 + vec2(-TIME * 0.2, TIME * 0.13));
	float crest_foam = smoothstep(1.0 - foam_amount * 0.4, 1.0, crest + (lace2 - 0.5) * 0.3) * smoothstep(0.4, 0.62, lace2 * 0.6 + fine * 0.4);
	foam = clamp(foam + crest_foam * (0.3 + 0.7 * far_fade), 0.0, 1.0);

	// Reflection of the sky gradient in the direction the surface mirrors.
	vec3 refl = reflect(-view_world, n);
	vec3 sky = mix(sky_horizon_colour, sky_zenith_colour, pow(clamp(refl.y, 0.0, 1.0), 0.6));
	// Far away the surface is seen at a grazing angle and averages out to the horizon colour.
	float horizon_mix = 1.0 - exp(-cam_dist / max(distance_fade * 2.5, 0.001));
	fresnel = min(mix(fresnel, max(fresnel, 0.55), horizon_mix), 0.78);

	vec3 surface = mix(body, foam_colour, foam);
	ALBEDO = surface * (1.0 - fresnel * (1.0 - foam) * reflection_strength);
	EMISSION = sky * fresnel * (1.0 - foam) * reflection_strength;
	ROUGHNESS = mix(0.12, 0.9, foam);
	SPECULAR = 0.0;
	METALLIC = 0.0;
	// Only the depth-effects variant writes the alpha: any write would move the material to the transparent pass.
	/*@ALPHA_WRITE@*/
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	shade_normal = n;
	// Sparkle cells: each glints at its own moment; only the broad sun path lets them through (see light()).
	vec2 sp = rp * 7.0 + ripple * 2.0;
	vec2 cell = floor(sp);
	float phase = hash21(cell);
	vec2 centre = vec2(hash21(cell + 5.0), hash21(cell + 13.0)) * 0.6 + 0.2;
	float dot_shape = smoothstep(0.22, 0.05, length(fract(sp) - centre));
	float glint = pow(max(sin(TIME * (1.5 + phase * 2.5) + phase * 60.0), 0.0), 8.0);
	sparkle_mask = glint * dot_shape * step(0.4, hash21(cell + 19.0)) * (1.0 - foam);
}

void light() {
	vec3 light_world = normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz);
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float ndl = dot(shade_normal, light_world);
	// Wrapped diffuse keeps the back of each wave coloured instead of black.
	float wrap = clamp((ndl + 0.45) / 1.45, 0.0, 1.0);
	// Half-desaturated light: a red sunset tints the sea without turning it brown.
	vec3 soft_light = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.3, 0.5, 0.2))), 0.5);
	DIFFUSE_LIGHT += wrap * ATTENUATION * soft_light / PI;
	// Back-lit crests glow with the scatter colour.
	float through = pow(clamp(dot(view_world, -light_world) * 0.5 + 0.5, 0.0, 1.0), 3.0) * clamp(1.0 - ndl, 0.0, 1.0);
	DIFFUSE_LIGHT += scatter_colour * through * 0.25 * ATTENUATION * LIGHT_COLOR / PI;
	// Sun path: a tight highlight plus twinkling sparkles inside a wider lobe.
	vec3 half_dir = normalize(light_world + view_world);
	// A faint shimmer broken up by the ripples, and sparkles inside a broad lobe around the mirror direction.
	float ndh_wave = clamp(dot(normalize(mix(wave_normal, vec3(0.0, 1.0, 0.0), 0.5)), half_dir), 0.0, 1.0);
	float ndh = clamp(dot(shade_normal, half_dir), 0.0, 1.0);
	float sheen = pow(ndh, 70.0) * 0.16;
	float wide = pow(ndh_wave, 40.0);
	SPECULAR_LIGHT += (sheen + wide * sparkle_mask * 12.0) * sparkle_strength * ATTENUATION * LIGHT_COLOR;
}
"""

const FOAM_SHADER_CODE: String = """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 foam_colour : source_color = vec3(0.95, 0.97, 1.0);
uniform float speed = 0.5;
uniform float strip_length = 10.0;
uniform float strip_width = 2.0;

// Integer hash: float "fract(sin)" style hashes differ by a rounding step between neighbouring cells on some GPUs,
// which shows as hard seams in the noise.
float hash21(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint n = uint(q.x) * 1597334677u ^ uint(q.y) * 3812015801u;
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

void fragment() {
	// UV.y runs from the sea side (0) to the land side (1); the foam washes up the beach and slides back.
	vec2 q = vec2(UV.x * strip_length, UV.y * strip_width);
	float wash = 0.5 + 0.5 * sin(TIME * speed + vnoise(vec2(q.x * 0.2, 3.0)) * 6.0);
	float edge = mix(0.5, 0.92, wash) + (vnoise(vec2(q.x * 0.9, TIME * 0.15)) - 0.5) * 0.22;
	float behind = edge - UV.y;
	float lace = vnoise(q * 2.3 + vec2(0.0, TIME * speed * 0.5)) * 0.6 + vnoise(q * 5.1 - vec2(TIME * 0.1, 0.0)) * 0.4;
	float lip = smoothstep(0.0, 0.02, behind) * (1.0 - smoothstep(0.03, 0.1, behind));
	float trail = smoothstep(0.0, 0.03, behind) * (1.0 - smoothstep(0.1, 0.75, behind)) * smoothstep(0.42, 0.6, lace);
	float a = max(lip, trail * 0.85);
	a *= smoothstep(0.0, 0.05, UV.x) * smoothstep(1.0, 0.95, UV.x) * smoothstep(0.0, 0.1, UV.y);
	ALBEDO = foam_colour;
	ROUGHNESS = 0.9;
	ALPHA = clamp(a, 0.0, 1.0) * 0.92;
}
"""

static var _shaders: Dictionary[bool, Shader] = {}
static var _foam_shader: Shader = null


## Source of the ocean shader for a variant: SHADER_CODE with its placeholders filled in. Without depth effects
## the code neither reads the depth buffer nor writes the alpha, so the surface stays in the opaque pass.
static func shader_code(depth_effects: bool = true) -> String:
	var code: String = SHADER_CODE
	code = code.replace(DEPTH_DEFINE_TOKEN, "#define DEPTH_EFFECTS" if depth_effects else "")
	code = code.replace(ALPHA_WRITE_TOKEN, "ALPHA = alpha;" if depth_effects else "")
	return code


## The ocean shader. With `depth_effects` it reads the depth buffer for the shallow tint, soft shore edge and
## shoreline foam (and is drawn in the transparent pass); without, it is a cheaper opaque surface for Low
## (depth-tested and depth-written like any solid mesh).
static func shader(depth_effects: bool = true) -> Shader:
	if not _shaders.has(depth_effects):
		var s: Shader = Shader.new()
		s.code = shader_code(depth_effects)
		_shaders[depth_effects] = s
	return _shaders[depth_effects]


## Colours and strengths of the water for a mood (keys are shader uniform names). Unknown moods use SkyKit's default.
static func mood_params(mood: StringName) -> Dictionary[String, Variant]:
	var p: Dictionary[String, Variant] = {
		"deep_colour": Palette.DEEP_OCEAN,
		"shallow_colour": Color("#1E8C93"),
		"scatter_colour": Color("#35C3A8"),
		"foam_colour": Color("#F4F8FF"),
		"reflection_strength": 1.0,
		"sparkle_strength": 1.0,
		"foam_amount": 0.5,
	}
	match SkyKit.resolve_mood(mood):
		&"dawn":
			p["shallow_colour"] = Color("#3C8F9C")
			p["foam_colour"] = Color("#FFE9DC")
			p["sparkle_strength"] = 1.2
		&"dusk":
			p["deep_colour"] = Palette.DEEP_OCEAN.lerp(Palette.NIGHT_INDIGO, 0.35)
			p["shallow_colour"] = Color("#2F6F8C")
			p["scatter_colour"] = Color("#C9705A")
			p["foam_colour"] = Color("#FFD9C2")
			p["sparkle_strength"] = 1.3
		&"night":
			p["deep_colour"] = Palette.DEEP_OCEAN.lerp(Palette.NIGHT_INDIGO, 0.6).darkened(0.35)
			p["shallow_colour"] = Color("#1C4A70")
			p["scatter_colour"] = Color("#3B6FA6")
			p["foam_colour"] = Palette.MOON.darkened(0.2)
			p["sparkle_strength"] = 0.5
			p["foam_amount"] = 0.4
		&"inferno":
			p["deep_colour"] = Palette.DEEP_OCEAN.lerp(Color("#1C0F14"), 0.7)
			p["shallow_colour"] = Color("#1F4A52")
			p["scatter_colour"] = Palette.SAFFRON
			p["foam_colour"] = Color("#F2B48A")
			p["reflection_strength"] = 0.8
			p["sparkle_strength"] = 0.7
			p["foam_amount"] = 0.4
		&"divine":
			p["deep_colour"] = Palette.DEEP_OCEAN.lerp(Color("#2A7FA8"), 0.5)
			p["shallow_colour"] = Color("#5CC4C0")
			p["scatter_colour"] = Palette.GOLD
			p["foam_colour"] = Color("#FFFBEA")
			p["sparkle_strength"] = 1.5
	p["sky_horizon_colour"] = SkyKit.horizon_colour(mood)
	p["sky_zenith_colour"] = SkyKit.zenith_colour(mood)
	return p


## An animated ocean surface `size` metres wide (x, z), centred on its origin at sea level. Move it freely, but
## keep it unrotated and unscaled (the waves are computed in its local space).
## `wave_scale` enlarges the waves (1 suits the gameplay camera; 2-4 reads better from high in the air).
## `depth_effects = false` gives the cheaper opaque variant for the Low graphics preset.
static func ocean(size: Vector2, mood: StringName, wave_scale: float = 1.0, depth_effects: bool = true) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = subdivisions_for(size.x)
	plane.subdivide_depth = subdivisions_for(size.y)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader(depth_effects)
	apply_mood(material, mood)
	var scale: float = maxf(wave_scale, 0.01)
	material.set_shader_parameter("wave_scale", scale)
	material.set_shader_parameter("cell_size", maxf(size.x / float(plane.subdivide_width + 1), size.y / float(plane.subdivide_depth + 1)))
	material.set_shader_parameter("distance_fade", 220.0 * scale)
	var names: Array[String] = ["wave_a", "wave_b", "wave_c", "wave_d"]
	for i: int in range(WAVES.size()):
		material.set_shader_parameter(names[i], WAVES[i])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = OCEAN_NAME
	mi.mesh = plane
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The waves move vertices outside the flat plane's bounds.
	mi.extra_cull_margin = max_wave_height(scale) * 2.0 + 1.0
	mi.set_meta(&"wave_scale", scale)
	return mi


## Sets the colours of an ocean (or shoreline foam) material to `mood`.
static func apply_mood(material: ShaderMaterial, mood: StringName) -> void:
	var params: Dictionary[String, Variant] = mood_params(mood)
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	material.set_meta(&"mood", SkyKit.resolve_mood(mood))


## A strip of washing foam to lay along a beach: `length` along local x, `width` along local z, with the land on
## the +z side. Lay it a few centimetres above the sand. Works on every graphics preset (no depth buffer).
static func shoreline_foam(length: float, width: float, mood: StringName) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(length, width)
	plane.subdivide_width = clampi(int(length / 2.0), 1, 64)
	if _foam_shader == null:
		_foam_shader = Shader.new()
		_foam_shader.code = FOAM_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _foam_shader
	material.set_shader_parameter("foam_colour", mood_params(mood)["foam_colour"])
	material.set_shader_parameter("strip_length", length)
	material.set_shader_parameter("strip_width", width)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = FOAM_NAME
	mi.mesh = plane
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Grid subdivisions for one side of the plane: about TARGET_CELL_SIZE metres per cell, within the limits.
static func subdivisions_for(side: float) -> int:
	return clampi(int(ceilf(side / TARGET_CELL_SIZE)), MIN_SUBDIVISIONS, MAX_SUBDIVISIONS)


## Highest a crest can rise above sea level (the sum of the wave amplitudes).
static func max_wave_height(wave_scale: float = 1.0) -> float:
	var total: float = 0.0
	for wave: Vector4 in WAVES:
		total += wave.z * wave.w * wave_scale / TAU
	return total


## CPU mirror of the shader's waves: the offset of the surface point that rests at `rest_xz` (ocean-LOCAL metres,
## i.e. relative to the ocean node's origin) at `time` seconds (the shader uses the engine's shader TIME). y is the
## height above sea level. This is the full-detail surface that the per-pixel shading shows. The mesh itself fades
## out waves shorter than a few grid cells (mesh_weight() in the shader) so its geometry can sit up to a few
## centimetres from this value.
static func wave_offset(rest_xz: Vector2, time: float, wave_scale: float = 1.0) -> Vector3:
	var offset: Vector3 = Vector3.ZERO
	for wave: Vector4 in WAVES:
		var k: float = TAU / (wave.w * wave_scale)
		var c: float = sqrt(GRAVITY / k)
		var d: Vector2 = Vector2(wave.x, wave.y).normalized()
		var f: float = k * (d.dot(rest_xz) - c * time)
		var a: float = wave.z / k
		offset += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
	return offset


## Height of the water above sea level at `rest_xz` (ignores the small sideways drift of Gerstner waves).
static func wave_height(rest_xz: Vector2, time: float, wave_scale: float = 1.0) -> float:
	return wave_offset(rest_xz, time, wave_scale).y


## World-space y of the water surface of `ocean` (made by ocean(), unrotated and unscaled) at the world position
## `world_position`, at `time` seconds. Converts to the ocean's local space and uses its own wave scale.
static func surface_height_at(ocean: Node3D, world_position: Vector3, time: float) -> float:
	var origin: Vector3 = ocean.global_position if ocean.is_inside_tree() else ocean.position
	var scale: float = ocean.get_meta(&"wave_scale", 1.0) as float
	return origin.y + wave_height(Vector2(world_position.x - origin.x, world_position.z - origin.z), time, scale)
