class_name Materials
extends RefCounted
## Painterly material system (docs/ART.md "Materials", module F2).
##
## One shared spatial shader source, one cached ShaderMaterial per KIND. A kind is chosen per mesh surface
## (see MeshKit.multi). The base colour always comes from the VERTEX COLOUR; vertex colour ALPHA is the wind
## weight for cloth and foliage (0 = rigid, 1 = free) and the opacity for water_edge.
##
## What every kind gets:
##  - triplanar noise variation of the base colour (value and a slight warm/cool hue shift);
##  - soft banded diffuse (three soft bands) whose shadow side is lifted toward NIGHT_INDIGO, never grey;
##  - a kind-specific response: gold is metallic with a bright specular and a fake sky reflection that blooms,
##    cloth and foliage wrap the light, let it through from behind and sway in the wind, stone darkens in
##    cavities and lights up on bevelled edges, fur has a grazing-angle sheen, skin a warm terminator,
##    lacquer a glossy highlight, wood a grain, water_edge moving foam.
##
## Noise space: stone, wood, foliage, lacquer and water_edge use WORLD space (continuous across neighbouring
## pieces); cloth, fur, skin and gold use OBJECT space so the pattern does not swim on moving characters.
## Append "_local" or "_world" to a kind to force one, e.g. get_material(&"lacquer_local") for a shield.


## Side length of the shared tileable noise texture, in pixels.
const NOISE_SIZE: int = 128
const DEFAULT_WIND_DIRECTION: Vector3 = Vector3(1.0, 0.0, 0.35)
const DEFAULT_SHADOW_STRENGTH: float = 0.2
const FALLBACK_KIND: StringName = &"lacquer"

const _KINDS: Array[StringName] = [
	&"stone", &"cloth", &"fur", &"skin", &"gold", &"wood", &"foliage", &"water_edge", &"lacquer",
]

## Shader variants built from the one source: 0 = opaque, 1 = opaque and double-sided, 2 = alpha blended.
const _VARIANT_OPAQUE: int = 0
const _VARIANT_TWO_SIDED: int = 1
const _VARIANT_WATER: int = 2

const _RENDER_MODE_MARKER: String = "render_mode diffuse_lambert, specular_schlick_ggx;"
const _WATER_MARKER: String = "//@WATER "

## Every kind uniform with its neutral value (mirrors the shader's defaults), set on each material before the
## kind's own values so get_shader_parameter() answers for every uniform.
const _DEFAULT_PARAMS: Dictionary[StringName, Variant] = {
	&"object_space": 0.0,
	&"noise_scale": 0.5,
	&"value_variation": 0.08,
	&"hue_variation": 0.03,
	&"detail_scale": 4.0,
	&"detail_stretch": Vector2(1.0, 1.0),
	&"detail_strength": 0.05,
	&"pit_strength": 0.0,
	&"saturation": 1.0,
	&"band_softness": 0.12,
	&"band_wobble": 0.05,
	&"wrap": 0.0,
	&"terminator_strength": 0.0,
	&"terminator_tint": Color(1.0, 0.5, 0.3),
	&"transmission": 0.0,
	&"transmission_tint": Color(1.0, 0.9, 0.6),
	&"metallic": 0.0,
	&"roughness": 0.9,
	&"spec_strength": 0.1,
	&"gloss": 16.0,
	&"spec_tint": 0.0,
	&"spec_hardness": 0.0,
	&"env_strength": 0.0,
	&"sheen_strength": 0.0,
	&"sheen_power": 3.0,
	&"sheen_tint": Color(1.0, 1.0, 1.0),
	&"cavity_strength": 0.2,
	&"edge_strength": 0.15,
	&"edge_width": 0.035,
	&"wind_amount": 0.0,
	&"wind_speed": 2.0,
	&"flow_speed": 0.0,
	&"foam_strength": 0.0,
}

## Per-kind uniform values; anything not listed keeps its value from _DEFAULT_PARAMS.
const _KIND_PARAMS: Dictionary[StringName, Dictionary] = {
	&"stone": {
		&"noise_scale": 0.3, &"value_variation": 0.09, &"hue_variation": 0.03,
		&"detail_scale": 1.7, &"detail_stretch": Vector2(1.0, 1.0), &"detail_strength": 0.08,
		&"pit_strength": 0.3, &"cavity_strength": 0.55, &"edge_strength": 0.45,
		&"band_softness": 0.07, &"band_wobble": 0.10, &"wrap": 0.05,
		&"spec_strength": 0.12, &"gloss": 12.0, &"roughness": 0.95,
	},
	&"cloth": {
		&"noise_scale": 0.9, &"value_variation": 0.08, &"hue_variation": 0.03,
		&"detail_scale": 5.0, &"detail_stretch": Vector2(1.0, 0.18), &"detail_strength": 0.10,
		&"band_softness": 0.16, &"band_wobble": 0.05, &"wrap": 0.45,
		&"transmission": 0.35, &"transmission_tint": Color(1.0, 0.82, 0.6),
		&"terminator_strength": 0.10, &"terminator_tint": Color(1.0, 0.55, 0.3),
		&"sheen_strength": 0.9, &"sheen_power": 3.0, &"sheen_tint": Color(1.0, 0.92, 0.8),
		&"spec_strength": 0.1, &"gloss": 8.0, &"roughness": 0.9,
		&"wind_amount": 0.10, &"wind_speed": 2.2, &"object_space": 1.0,
	},
	&"fur": {
		&"noise_scale": 1.3, &"value_variation": 0.10, &"hue_variation": 0.04,
		&"detail_scale": 3.2, &"detail_stretch": Vector2(1.0, 0.14), &"detail_strength": 0.26,
		&"band_softness": 0.18, &"band_wobble": 0.12, &"wrap": 0.30,
		&"terminator_strength": 0.12, &"terminator_tint": Color(1.0, 0.5, 0.2),
		&"sheen_strength": 1.3, &"sheen_power": 3.0, &"sheen_tint": Color(1.0, 0.88, 0.62),
		&"spec_strength": 0.3, &"gloss": 6.0, &"spec_tint": 0.7, &"roughness": 0.85,
		&"object_space": 1.0,
	},
	&"skin": {
		&"noise_scale": 0.7, &"value_variation": 0.06, &"hue_variation": 0.02,
		&"detail_scale": 9.0, &"detail_strength": 0.03,
		&"band_softness": 0.20, &"band_wobble": 0.03, &"wrap": 0.35,
		&"terminator_strength": 0.30, &"terminator_tint": Color(1.0, 0.32, 0.2),
		&"transmission": 0.08, &"transmission_tint": Color(1.0, 0.4, 0.3),
		&"sheen_strength": 0.5, &"sheen_power": 4.0, &"sheen_tint": Color(1.0, 0.9, 0.85),
		&"spec_strength": 0.5, &"gloss": 26.0, &"roughness": 0.6,
		&"object_space": 1.0,
	},
	&"gold": {
		&"noise_scale": 1.4, &"value_variation": 0.06, &"hue_variation": 0.03,
		&"detail_scale": 3.0, &"detail_strength": 0.05,
		&"band_softness": 0.07, &"band_wobble": 0.04, &"wrap": 0.15,
		&"metallic": 0.9, &"roughness": 0.32, &"env_strength": 1.0,
		&"spec_strength": 7.0, &"gloss": 36.0, &"spec_tint": 0.75, &"spec_hardness": 0.5,
		&"cavity_strength": 0.35, &"edge_strength": 0.6,
		&"object_space": 1.0,
	},
	&"wood": {
		&"noise_scale": 0.7, &"value_variation": 0.10, &"hue_variation": 0.04,
		&"detail_scale": 2.4, &"detail_stretch": Vector2(1.0, 0.08), &"detail_strength": 0.22,
		&"pit_strength": 0.05, &"cavity_strength": 0.35, &"edge_strength": 0.25,
		&"band_softness": 0.08, &"band_wobble": 0.08, &"wrap": 0.08,
		&"spec_strength": 0.3, &"gloss": 14.0, &"roughness": 0.8,
	},
	&"foliage": {
		&"noise_scale": 0.8, &"value_variation": 0.12, &"hue_variation": 0.07,
		&"detail_scale": 6.0, &"detail_strength": 0.08,
		&"band_softness": 0.22, &"band_wobble": 0.12, &"wrap": 0.6,
		&"transmission": 0.6, &"transmission_tint": Color(0.95, 1.0, 0.35),
		&"terminator_strength": 0.14, &"terminator_tint": Color(0.9, 1.0, 0.3),
		&"sheen_strength": 0.35, &"sheen_power": 3.0, &"sheen_tint": Color(0.9, 1.0, 0.7),
		&"spec_strength": 0.2, &"gloss": 10.0, &"roughness": 0.8,
		&"wind_amount": 0.14, &"wind_speed": 1.6,
	},
	&"water_edge": {
		&"noise_scale": 0.6, &"value_variation": 0.08, &"hue_variation": 0.03,
		&"detail_scale": 0.9, &"detail_strength": 0.0,
		&"band_softness": 0.25, &"wrap": 0.5,
		&"flow_speed": 0.07, &"foam_strength": 1.0,
		&"spec_strength": 4.0, &"gloss": 90.0, &"spec_hardness": 0.8, &"roughness": 0.15,
		&"env_strength": 0.25, &"sheen_strength": 0.8, &"sheen_power": 4.0, &"sheen_tint": Color(0.8, 0.92, 1.0),
	},
	&"lacquer": {
		&"noise_scale": 0.55, &"value_variation": 0.07, &"hue_variation": 0.025,
		&"detail_scale": 4.0, &"detail_stretch": Vector2(1.0, 0.25), &"detail_strength": 0.05,
		&"cavity_strength": 0.4, &"edge_strength": 0.5,
		&"band_softness": 0.07, &"band_wobble": 0.05, &"wrap": 0.10,
		&"saturation": 1.12, &"env_strength": 0.16,
		&"spec_strength": 2.2, &"gloss": 60.0, &"spec_hardness": 0.6, &"roughness": 0.3,
	},
}

const _SHADER_SOURCE: String = """shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Painterly kind shader (gen/materials.gd, docs/ART.md "Materials"). One source for every kind; the kind is
// expressed through the uniforms below. Base colour = vertex colour. COLOR.a = wind weight (0 rigid, 1 free).

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Noise: R = soft blotches, G = fine grain, B = cell seams (0 on the seams: cracks), A = second blotch layer.
uniform float object_space = 0.0;
uniform float noise_scale = 0.5;
uniform float value_variation = 0.08;
uniform float hue_variation = 0.03;
uniform float detail_scale = 4.0;
uniform vec2 detail_stretch = vec2(1.0, 1.0);
uniform float detail_strength = 0.05;
uniform float pit_strength = 0.0;
uniform float saturation = 1.0;
// Diffuse.
uniform float band_softness = 0.12;
uniform float band_wobble = 0.05;
uniform float wrap = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.47, 0.47, 1.0);
uniform float shadow_strength = 0.2;
uniform float exposure = 1.0;
uniform float terminator_strength = 0.0;
uniform vec3 terminator_tint : source_color = vec3(1.0, 0.5, 0.3);
uniform float transmission = 0.0;
uniform vec3 transmission_tint : source_color = vec3(1.0, 0.9, 0.6);
// Specular, metal and sheen.
uniform float metallic = 0.0;
uniform float roughness = 0.9;
uniform float spec_strength = 0.1;
uniform float gloss = 16.0;
uniform float spec_tint = 0.0;
uniform float spec_hardness = 0.0;
uniform float env_strength = 0.0;
uniform float sheen_strength = 0.0;
uniform float sheen_power = 3.0;
uniform vec3 sheen_tint : source_color = vec3(1.0, 1.0, 1.0);
// Curvature: cavities darken, convex bevels catch light.
uniform float cavity_strength = 0.2;
uniform float edge_strength = 0.15;
uniform float edge_width = 0.035;
// Wind (vertex) and water.
uniform float wind_amount = 0.0;
uniform float wind_speed = 2.0;
uniform float wind_strength = 1.0;
uniform vec3 wind_direction = vec3(0.94, 0.0, 0.33);
uniform float flow_speed = 0.0;
uniform float foam_strength = 0.0;

varying vec3 v_color;
varying float v_weight;
varying vec3 v_noise_pos;
varying vec3 v_noise_normal;
varying float f_wobble;
varying vec3 f_view;

void vertex() {
	v_color = pow(COLOR.rgb, vec3(2.2));
	v_weight = COLOR.a;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	// Noise is anchored before the wind moves the vertex, so swaying cloth keeps its pattern.
	v_noise_pos = mix(world_pos, VERTEX, object_space);
	v_noise_normal = mix(world_normal, NORMAL, object_space);
	float sway = COLOR.a * wind_amount * wind_strength;
	if (sway > 0.0) {
		float t = TIME * wind_speed;
		float along = dot(world_pos, wind_direction);
		float gust = sin(t * 0.7 - along * 0.9) * 0.6 + sin(t * 1.9 - along * 2.3 + world_pos.y * 1.7) * 0.3;
		float flutter = sin(t * 4.3 + world_pos.x * 5.1 + world_pos.y * 4.0 + world_pos.z * 4.7) * 0.18;
		vec3 side = cross(vec3(0.0, 1.0, 0.0), wind_direction);
		vec3 offset = wind_direction * (0.55 + gust) + side * flutter + vec3(0.0, flutter * 0.6 - 0.15 * (0.5 + 0.5 * gust), 0.0);
		// World offset back to model space (rotation and uniform scale).
		mat3 basis = mat3(MODEL_MATRIX);
		VERTEX += (offset * sway) * basis / max(dot(basis[0], basis[0]), 0.000001);
	}
}

vec4 triplanar(vec3 p, vec3 w, vec2 stretch) {
	// The second texture axis runs along Y on the side projections, so stretched grain runs vertically.
	return texture(noise_tex, p.zy * stretch) * w.x + texture(noise_tex, p.xz * stretch) * w.y + texture(noise_tex, p.xy * stretch) * w.z;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	// Orthographic cameras (the iso camera) have a constant view direction.
	f_view = PROJECTION_MATRIX[3][3] != 0.0 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW);

	vec3 w = pow(abs(normalize(v_noise_normal)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 flow = vec3(1.0, 0.0, 0.6) * TIME * flow_speed;
	vec4 soft = triplanar(v_noise_pos * noise_scale + flow, w, vec2(1.0));
	vec4 detail = triplanar(v_noise_pos * detail_scale - flow * 1.7, w, detail_stretch);
	// A slow third layer hides the tiling on big walls and floors.
	vec4 macro = triplanar(v_noise_pos.yzx * (noise_scale * 0.23) + vec3(0.37, 0.11, 0.73), w.yzx, vec2(1.0));

	// Value variation (broad washes, soft blotches, grain) and a warm/cool hue drift.
	float blotch = (soft.r - 0.5) * 1.3 + (macro.a - 0.5) * 1.1;
	float grain = (detail.g - 0.5) * 0.9 + (detail.r - 0.5) * 1.5;
	vec3 albedo = v_color * (1.0 + blotch * value_variation + grain * detail_strength);
	float drift = ((soft.a - 0.5) * 1.2 + (macro.r - 0.5) * 1.2) * hue_variation;
	albedo *= vec3(1.0 + drift, 1.0 - abs(drift) * 0.3, 1.0 - drift);
	// Hairline cracks and chipped seams, gathered in patches instead of covering the surface evenly.
	float pits = (1.0 - smoothstep(0.0, 0.07, detail.b)) * smoothstep(0.42, 0.62, soft.a) * pit_strength;
	albedo *= 1.0 - pits;
	float grey = dot(albedo, vec3(0.299, 0.587, 0.114));
	albedo = max(mix(vec3(grey), albedo, saturation), vec3(0.0));

	// Screen-space curvature: positive on convex bevels, negative in cavities.
	vec3 dnx = dFdx(n);
	vec3 dny = dFdy(n);
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	float curvature = dot(dnx, dpx) / max(dot(dpx, dpx), 0.0000001) + dot(dny, dpy) / max(dot(dpy, dpy), 0.0000001);
	float curve = clamp(curvature * edge_width, -1.5, 1.5);
	float edge = smoothstep(0.25, 1.0, curve) * edge_strength;
	float cavity = clamp(smoothstep(0.1, 1.0, -curve) * cavity_strength + pits * 1.5, 0.0, 0.9);
	// Cavities darken the colour itself (direct light too); AO below only dims the ambient light, so screen-space
	// AO never dithers sunlit faces.
	albedo *= (1.0 + edge * 0.6) * (1.0 - cavity * 0.45);

	// Moving foam (water_edge only: foam_strength is 0 elsewhere).
	// Thin drifting lines where two noise layers cross, thickening toward the transparent rim.
	float foam_lines = 1.0 - smoothstep(0.0, 0.035 + (1.0 - v_weight) * 0.12, abs(soft.r - detail.a));
	float foam = clamp(foam_lines + smoothstep(0.55, 0.2, v_weight) * soft.a, 0.0, 1.0) * foam_strength;
	albedo = mix(albedo * (0.8 + soft.a * 0.4), vec3(0.9, 0.96, 1.0), foam * 0.85);

	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = mix(roughness, 0.9, foam);
	SPECULAR = 0.5;
	AO = 1.0 - cavity;
	AO_LIGHT_AFFECT = 0.0;

	// Fake sky reflection so metal and gloss read even without a reflection probe: bright warm sky above, a
	// dark horizon line, warm bounce from the ground. Tinted by the albedo for metals.
	vec3 refl = (INV_VIEW_MATRIX * vec4(reflect(-f_view, n), 0.0)).xyz;
	float sky = smoothstep(-0.05, 0.85, refl.y);
	float ground = smoothstep(0.0, -0.9, refl.y) * 0.45;
	float horizon = 1.0 - smoothstep(0.0, 0.22, abs(refl.y + 0.04));
	float env = (sky * sky * 1.25 + ground) * (1.0 - horizon * 0.6) * (0.92 + blotch * 0.12);
	vec3 env_colour = mix(vec3(1.0), albedo * 2.2 + vec3(0.02), clamp(metallic + spec_tint, 0.0, 1.0));
	EMISSION = env_colour * env * env_strength * (1.0 - cavity) * mix(mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.72, 0.5), metallic), vec3(1.0, 0.95, 0.85), sky);

	f_wobble = (soft.a - 0.5) * 2.0 * band_wobble;
//@WATER ALPHA = clamp(v_weight * (0.5 + foam * 0.5 + (1.0 - abs(dot(n, f_view))) * 0.3), 0.0, 1.0);
}

void light() {
	vec3 n = normalize(NORMAL);
	float ndl_raw = dot(n, LIGHT);
	float ndl = (ndl_raw + wrap) / (1.0 + wrap) + f_wobble;
	// Soft banded diffuse: three soft-edged bands with a little continuous falloff blended in.
	float s = band_softness;
	float band = 0.46 * smoothstep(-s, s, ndl - 0.02) + 0.30 * smoothstep(-s, s, ndl - 0.36) + 0.24 * smoothstep(-s, s, ndl - 0.72);
	band = mix(band, clamp(ndl, 0.0, 1.0), 0.22);
	// Shadows are never grey: the unlit side is lifted toward indigo, scaled by the light itself.
	vec3 shade = shadow_tint * shadow_strength;
	float lit = band * ATTENUATION;
	vec3 diffuse = LIGHT_IS_DIRECTIONAL ? mix(shade, vec3(1.0), lit) : mix(shade, vec3(1.0), band) * ATTENUATION;
	// Warm saturated terminator between light and shadow (skin, fur, leaves).
	float terminator = band * (1.0 - band) * 4.0;
	diffuse += terminator_tint * terminator * terminator_strength * ATTENUATION;
	// Light bleeding through thin cloth and leaves from behind.
	float behind = clamp(-ndl_raw, 0.0, 1.0);
	float through = pow(clamp(dot(f_view, -LIGHT), 0.0, 1.0), 2.0) * 0.7 + 0.3;
	diffuse += transmission_tint * behind * through * transmission * mix(1.0, ATTENUATION, 0.5);
	// LIGHT_COLOR arrives multiplied by PI; dividing it out matches StandardMaterial3D under the same lights.
	vec3 light = LIGHT_COLOR * (exposure / PI);
	DIFFUSE_LIGHT += light * diffuse;

	vec3 h = normalize(LIGHT + f_view);
	float ndh = max(dot(n, h), 0.0);
	float spec = pow(ndh, gloss);
	spec = mix(spec, smoothstep(0.30, 0.62, spec), spec_hardness);
	float albedo_peak = max(max(ALBEDO.r, ALBEDO.g), max(ALBEDO.b, 0.001));
	vec3 spec_colour = mix(vec3(1.0), ALBEDO / albedo_peak, spec_tint);
	float facing = smoothstep(-0.1, 0.2, ndl_raw);
	vec3 specular = spec_colour * spec * spec_strength * facing;
	// Sheen: a soft glow at grazing angles on the lit side (fur, cloth, skin).
	float graze = pow(1.0 - clamp(dot(n, f_view), 0.0, 1.0), sheen_power);
	specular += sheen_tint * graze * sheen_strength * clamp(ndl_raw * 0.6 + 0.4, 0.0, 1.0);
	SPECULAR_LIGHT += light * ATTENUATION * specular;
}
"""

static var _cache: Dictionary[StringName, ShaderMaterial] = {}
static var _shaders: Dictionary[int, Shader] = {}
static var _noise_texture: ImageTexture = null
static var _wind_direction: Vector3 = DEFAULT_WIND_DIRECTION.normalized()
static var _wind_strength: float = 1.0
static var _shadow_tint: Color = _default_shadow_tint()
static var _shadow_strength: float = DEFAULT_SHADOW_STRENGTH
static var _exposure: float = 1.0
static var _warned_unknown: bool = false


## The cached material of a kind: stone, cloth, fur, skin, gold, wood, foliage, water_edge or lacquer, with an
## optional "_local" or "_world" suffix that forces the noise space. Unknown kinds fall back to lacquer.
static func get_material(kind: StringName) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var base: StringName = base_kind(kind)
	if not _KINDS.has(base):
		if not _warned_unknown:
			_warned_unknown = true
			push_warning("Materials: unknown kind '%s', using '%s'" % [kind, FALLBACK_KIND])
		var fallback: ShaderMaterial = get_material(FALLBACK_KIND)
		_cache[kind] = fallback
		return fallback
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = String(kind)
	material.shader = _shader_for(base)
	for key: StringName in _DEFAULT_PARAMS:
		material.set_shader_parameter(key, _DEFAULT_PARAMS[key])
	var params: Dictionary = _KIND_PARAMS[base]
	for key: Variant in params:
		material.set_shader_parameter(key as StringName, params[key])
	var text: String = String(kind)
	if text.ends_with("_local"):
		material.set_shader_parameter(&"object_space", 1.0)
	elif text.ends_with("_world") or not params.has(&"object_space"):
		material.set_shader_parameter(&"object_space", 0.0)
	material.set_shader_parameter(&"noise_tex", noise_texture())
	_apply_globals(material)
	_cache[kind] = material
	return material


## The nine kinds of docs/ART.md.
static func kinds() -> Array[StringName]:
	return _KINDS.duplicate()


## True for a kind of kinds(), with or without a "_local" / "_world" suffix.
static func has_kind(kind: StringName) -> bool:
	return _KINDS.has(base_kind(kind))


## Strips a "_local" or "_world" suffix.
static func base_kind(kind: StringName) -> StringName:
	var text: String = String(kind)
	if text.ends_with("_local") or text.ends_with("_world"):
		return StringName(text.substr(0, text.length() - 6))
	return kind


## The one shader source every kind's material is built from.
static func shader_source() -> String:
	return _SHADER_SOURCE


## Sets the wind for every kind material, existing and future. `direction` is a world direction (zero keeps
## the current one); `strength` scales the sway (0 = still air, 1 = default breeze).
static func set_wind(direction: Vector3, strength: float) -> void:
	if direction.length_squared() > 1e-8:
		_wind_direction = direction.normalized()
	_wind_strength = maxf(0.0, strength)
	_apply_globals_to_all()


## Sets the colour the shadow side is lifted toward and how strongly, for every kind material (moods in
## core/look.gd may warm or cool it). The colour is an sRGB swatch.
static func set_shadow_tint(tint: Color, strength: float) -> void:
	_shadow_tint = tint
	_shadow_strength = maxf(0.0, strength)
	_apply_globals_to_all()


## Restores the default NIGHT_INDIGO shadow tint.
static func reset_shadow_tint() -> void:
	set_shadow_tint(_default_shadow_tint(), DEFAULT_SHADOW_STRENGTH)


## Scales the direct light every kind material receives (1 = the same brightness as StandardMaterial3D under
## the same lights). A knob for core/look.gd moods and graphics presets.
static func set_exposure(exposure: float) -> void:
	_exposure = maxf(0.0, exposure)
	_apply_globals_to_all()


## The shared tileable noise texture bound to every kind material.
static func noise_texture() -> ImageTexture:
	if _noise_texture == null:
		_noise_texture = ImageTexture.create_from_image(build_noise_image())
	return _noise_texture


## Deterministic tileable RGBA noise: R = soft blotches, G = fine grain, B = cell seams, A = second blotch layer.
static func build_noise_image() -> Image:
	var r: PackedByteArray = _noise_channel(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.022, 3, 1101)
	var g: PackedByteArray = _noise_channel(FastNoiseLite.TYPE_SIMPLEX, 0.09, 3, 2203)
	var b: PackedByteArray = _noise_channel(FastNoiseLite.TYPE_CELLULAR, 0.04, 1, 3307)
	var a: PackedByteArray = _noise_channel(FastNoiseLite.TYPE_PERLIN, 0.035, 2, 4409)
	var count: int = NOISE_SIZE * NOISE_SIZE
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 4)
	for i: int in range(count):
		data[i * 4] = r[i]
		data[i * 4 + 1] = g[i]
		data[i * 4 + 2] = b[i]
		data[i * 4 + 3] = a[i]
	var image: Image = Image.create_from_data(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_RGBA8, data)
	image.generate_mipmaps()
	return image


static func _noise_channel(type: FastNoiseLite.NoiseType, frequency: float, octaves: int, noise_seed: int) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = type
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	noise.fractal_octaves = octaves
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var image: Image = noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE, false, false, 0.25, true)
	image.convert(Image.FORMAT_L8)
	return image.get_data()


static func _shader_for(base: StringName) -> Shader:
	var variant: int = _VARIANT_OPAQUE
	if base == &"water_edge":
		variant = _VARIANT_WATER
	elif base == &"cloth" or base == &"foliage":
		variant = _VARIANT_TWO_SIDED
	if _shaders.has(variant):
		return _shaders[variant]
	var code: String = _SHADER_SOURCE
	if variant == _VARIANT_TWO_SIDED:
		code = code.replace(_RENDER_MODE_MARKER, "render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;")
	elif variant == _VARIANT_WATER:
		code = code.replace(_RENDER_MODE_MARKER, "render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;")
		code = code.replace(_WATER_MARKER, "\t")
	var shader: Shader = Shader.new()
	shader.code = code
	_shaders[variant] = shader
	return shader


static func _default_shadow_tint() -> Color:
	# NIGHT_INDIGO's hue at full value: the palette token itself is too dark to act as a light colour.
	var indigo: Color = Palette.NIGHT_INDIGO
	var peak: float = maxf(indigo.r, maxf(indigo.g, indigo.b))
	return Color(indigo.r / peak, indigo.g / peak, indigo.b / peak)


static func _apply_globals(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"wind_direction", _wind_direction)
	material.set_shader_parameter(&"wind_strength", _wind_strength)
	material.set_shader_parameter(&"shadow_tint", _shadow_tint)
	material.set_shader_parameter(&"shadow_strength", _shadow_strength)
	material.set_shader_parameter(&"exposure", _exposure)


static func _apply_globals_to_all() -> void:
	for kind: StringName in _cache:
		_apply_globals(_cache[kind])
