class_name Vfx
extends RefCounted
## F8: procedural visual effects (docs/ART.md "VFX"). Every factory returns a Vfx.Effect (a Node3D).
## One-shot effects free themselves after `lifetime`; looping effects run until stop() and then fade and free.
## Positional factories return an unparented node (the caller adds it to the level); the two `attach` factories
## (swing_trail, smarana_motes) parent themselves to the given node. Additive particles use HDR energy > 1 so
## they catch the glow threshold of the mood presets.

const SHAPE_GLOW: int = 0
const SHAPE_STREAK: int = 1
const SHAPE_PUFF: int = 2
const SHAPE_PETAL: int = 3
const SHAPE_RING: int = 4
const SHAPE_RIBBON: int = 5
const SHAPE_FLAME: int = 6

const MODE_ADD: String = "unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled"
const MODE_MIX: String = "unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled"
const MODE_LIT: String = "blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled"

const _SHADER_BODY: String = """
uniform int shape = 0;
uniform float energy = 1.0;
uniform bool tumble = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ring_width = 0.12;
uniform float self_lit = 0.0;
uniform float soft = 0.0;
uniform sampler2D vfx_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying float v_seed;

float vfx_noise(vec2 p) {
	return 0.5 + 0.25 * sin(p.x * 1.7 + sin(p.y * 2.3) * 1.3) + 0.25 * sin(p.y * 1.9 + sin(p.x * 1.3 + 1.7) * 1.5);
}

void vertex() {
	v_seed = fract(float(INSTANCE_ID) * 0.6180339 + 0.137);
	if (tumble) {
		float a = v_seed * 6.283 + TIME * (1.2 + v_seed * 2.2);
		float b = v_seed * 40.0 + TIME * (0.7 + fract(v_seed * 7.0) * 1.5);
		mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(a), sin(a)), vec3(0.0, -sin(a), cos(a)));
		mat3 ry = mat3(vec3(cos(b), 0.0, -sin(b)), vec3(0.0, 1.0, 0.0), vec3(sin(b), 0.0, cos(b)));
		VERTEX = ry * (rx * VERTEX);
		NORMAL = vec3(0.0, 1.0, 0.0);
	}
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float a = 0.0;
	if (shape == 0) {
		float g = clamp(1.0 - r, 0.0, 1.0);
		a = g * g * 0.55 + smoothstep(0.75, 1.0, g) * 0.9;
	} else if (shape == 1) {
		float w = 1.0 - smoothstep(0.0, 0.5, abs(p.x));
		float l = 1.0 - smoothstep(0.2, 1.0, abs(p.y));
		a = w * w * l;
	} else if (shape == 2) {
		float n = vfx_noise(p * 2.6 + v_seed * 17.0) * 0.45 + vfx_noise(p * 6.1 - v_seed * 9.0) * 0.25;
		a = (1.0 - smoothstep(0.2, 1.0, r + n * 0.6)) * (0.65 + n * 0.5);
	} else if (shape == 3) {
		float y = p.y * 0.5 + 0.5;
		float half_w = 0.62 * sin(clamp(y, 0.0, 1.0) * 3.14159) * (0.55 + 0.45 * y);
		a = 1.0 - smoothstep(half_w - 0.08, half_w, abs(p.x));
		a *= step(abs(p.y), 0.98);
	} else if (shape == 4) {
		float d = abs(r - (1.0 - ring_width));
		a = (1.0 - smoothstep(0.0, ring_width, d));
		a = a * a + (1.0 - smoothstep(0.0, ring_width * 0.35, d)) * 0.8;
		a += clamp(1.0 - ring_width - r, 0.0, 1.0) * 0.06;
	} else if (shape == 5) {
		a = UV.y * UV.y * UV.y * 0.55 + smoothstep(0.8, 0.97, UV.y) * 0.75;
		a *= smoothstep(0.0, 0.15, UV.y);
	} else {
		vec2 q = vec2(p.x * (1.25 + 0.5 * (p.y * 0.5 + 0.5)), p.y);
		float n = vfx_noise(vec2(q.x * 2.4 + v_seed * 13.0, q.y * 1.7 - TIME * 2.2 + v_seed * 5.0));
		float body = 1.0 - smoothstep(0.15, 0.95, length(vec2(q.x, q.y * 0.9 + 0.1)) + (n - 0.5) * 0.5);
		a = body * body * (1.0 - smoothstep(0.7, 1.0, r));
	}
	if (soft > 0.0) {
		float scene_depth = textureLod(vfx_depth, SCREEN_UV, 0.0).r;
		vec4 scene_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
		scene_pos.xyz /= scene_pos.w;
		a *= clamp((VERTEX.z - scene_pos.z) / soft, 0.0, 1.0);
	}
	vec4 c = COLOR * tint;
	ALBEDO = c.rgb * energy;
	EMISSION = c.rgb * self_lit;
	ALPHA = clamp(c.a * a, 0.0, 1.0);
}
"""

static var _shaders: Dictionary[String, Shader] = {}
static var _materials: Dictionary[String, ShaderMaterial] = {}
static var _quad: QuadMesh = null


## Root node of every effect. Drives self-freeing, rings and light animation without tweens or timers,
## so it is deterministic under test (call tick(delta) directly).
class Effect:
	extends Node3D

	const LIGHT_NONE: int = 0
	const LIGHT_FLASH: int = 1
	const LIGHT_FLICKER: int = 2

	var looping: bool = false
	## One-shot: seconds until the effect frees itself.
	var lifetime: float = 1.0
	## Looping: seconds between stop() and the free (lets live particles die out).
	var fade_time: float = 1.0

	var _age: float = 0.0
	var _stopping: bool = false
	var _stop_age: float = 0.0
	var _done: bool = false
	var _light: OmniLight3D = null
	var _light_mode: int = LIGHT_NONE
	var _light_energy: float = 0.0
	var _light_time: float = 0.2
	var _rings: Array[MeshInstance3D] = []
	var _ring_from: Array[float] = []
	var _ring_to: Array[float] = []
	var _ring_time: Array[float] = []
	var _ring_delay: Array[float] = []
	var _ring_color: Array[Color] = []

	func _process(delta: float) -> void:
		tick(delta)

	## Advances the effect. Called from _process; tests may call it directly.
	func tick(delta: float) -> void:
		if _done:
			return
		_age += delta
		_update_rings()
		_update_light()
		_advance(delta)
		if looping:
			if _stopping:
				_stop_age += delta
				if _stop_age >= fade_time:
					_finish()
		elif _age >= lifetime:
			_finish()

	## Stops emission; the node frees itself after fade_time. Safe to call more than once.
	func stop() -> void:
		if _stopping:
			return
		_stopping = true
		for child: Node in get_children():
			if child is GPUParticles3D:
				(child as GPUParticles3D).emitting = false
		if not looping:
			lifetime = minf(lifetime, _age + fade_time)

	func is_stopping() -> bool:
		return _stopping

	func is_finished() -> bool:
		return _done

	func age() -> float:
		return _age

	## Current world-unit radius of ring `index` (0 when there is no such ring).
	func ring_radius(index: int) -> float:
		if index < 0 or index >= _rings.size():
			return 0.0
		return _rings[index].scale.x * 0.5

	func add_ring(from_radius: float, to_radius: float, duration: float, delay: float, color: Color,
			energy: float, width: float, flat: bool) -> MeshInstance3D:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Vfx.quad()
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = Vfx.shader(Vfx.MODE_ADD, flat == false)
		mat.set_shader_parameter("shape", Vfx.SHAPE_RING)
		mat.set_shader_parameter("energy", energy)
		mat.set_shader_parameter("ring_width", width)
		mat.set_shader_parameter("tint", Color(color.r, color.g, color.b, 0.0))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if flat:
			mi.rotation.x = -PI * 0.5
		mi.scale = Vector3.ONE * maxf(from_radius * 2.0, 0.001)
		add_child(mi)
		_rings.append(mi)
		_ring_from.append(from_radius)
		_ring_to.append(to_radius)
		_ring_time.append(maxf(duration, 0.001))
		_ring_delay.append(delay)
		_ring_color.append(color)
		return mi

	func set_light(color: Color, energy: float, light_range: float, mode: int, time: float, offset: Vector3) -> void:
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.light_energy = energy
		_light.omni_range = light_range
		_light.omni_attenuation = 1.4
		_light.shadow_enabled = false
		_light.position = offset
		add_child(_light)
		_light_mode = mode
		_light_energy = energy
		_light_time = maxf(time, 0.001)

	func _advance(_delta: float) -> void:
		pass

	func _finish() -> void:
		_done = true
		set_process(false)
		queue_free()

	func _update_rings() -> void:
		for i: int in _rings.size():
			var t: float = clampf((_age - _ring_delay[i]) / _ring_time[i], 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - t, 3.0)
			var radius: float = lerpf(_ring_from[i], _ring_to[i], eased)
			_rings[i].scale = Vector3.ONE * maxf(radius * 2.0, 0.001)
			var alpha: float = 0.0
			if _age >= _ring_delay[i]:
				alpha = smoothstep(0.0, 0.12, t) * (1.0 - t * t)
			var c: Color = _ring_color[i]
			var mat: ShaderMaterial = _rings[i].material_override as ShaderMaterial
			mat.set_shader_parameter("tint", Color(c.r, c.g, c.b, c.a * alpha))

	func _update_light() -> void:
		if _light == null:
			return
		if _light_mode == LIGHT_FLASH:
			var t: float = clampf(_age / _light_time, 0.0, 1.0)
			_light.light_energy = _light_energy * (1.0 - t) * (1.0 - t)
		elif _light_mode == LIGHT_FLICKER:
			var f: float = 0.82 + 0.1 * sin(_age * 11.3) + 0.06 * sin(_age * 23.7 + 1.3) + 0.04 * sin(_age * 41.1)
			var fade: float = 1.0
			if _stopping:
				fade = clampf(1.0 - _stop_age / maxf(fade_time * 0.6, 0.001), 0.0, 1.0)
			_light.light_energy = _light_energy * f * fade


## Ribbon that follows a node: samples the node's origin (base) and its local +Y * length (tip) every tick.
class Trail:
	extends Effect

	var trail_length: float = 1.0
	var trail_color: Color = Color.WHITE
	## Seconds a ribbon segment stays visible.
	var trail_life: float = 0.22

	var _target: Node3D = null
	var _mesh_instance: MeshInstance3D = null
	var _mesh: ImmediateMesh = null
	var _base: Array[Vector3] = []
	var _tip: Array[Vector3] = []
	var _ages: Array[float] = []

	func setup(target: Node3D, length: float, color: Color) -> void:
		_target = target
		trail_length = length
		trail_color = color
		looping = true
		fade_time = trail_life
		_mesh = ImmediateMesh.new()
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.top_level = true
		_mesh_instance.mesh = _mesh
		_mesh_instance.material_override = Vfx.material(Vfx.SHAPE_RIBBON, Vfx.MODE_ADD, 1.5, false, false)
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh_instance)

	func sample_count() -> int:
		return _ages.size()

	func ribbon_mesh() -> ImmediateMesh:
		return _mesh

	## Drops the current ribbon (call when a new swing starts so two swings are not bridged).
	func clear() -> void:
		_base.clear()
		_tip.clear()
		_ages.clear()
		_mesh.clear_surfaces()

	func _advance(delta: float) -> void:
		for i: int in _ages.size():
			_ages[i] += delta
		while _ages.size() > 0 and _ages[0] >= trail_life:
			_ages.remove_at(0)
			_base.remove_at(0)
			_tip.remove_at(0)
		if not _stopping and is_instance_valid(_target) and _target.is_inside_tree():
			var xf: Transform3D = _target.global_transform
			_base.append(xf.origin)
			_tip.append(xf * Vector3(0.0, trail_length, 0.0))
			_ages.append(0.0)
		_rebuild()

	func _rebuild() -> void:
		_mesh.clear_surfaces()
		var n: int = _ages.size()
		if n < 2:
			return
		if _mesh_instance.is_inside_tree():
			_mesh_instance.global_transform = Transform3D.IDENTITY
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i: int in n:
			var k: float = clampf(1.0 - _ages[i] / trail_life, 0.0, 1.0)
			var cool: Color = trail_color.lerp(Palette.SAFFRON, 0.6)
			var c: Color = cool.lerp(trail_color, k)
			c.a = trail_color.a * k * k
			# the ribbon narrows toward its tail: the base slides toward the tip as the sample ages
			var base: Vector3 = _tip[i].lerp(_base[i], 0.25 + 0.75 * k)
			_mesh.surface_set_color(c)
			_mesh.surface_set_uv(Vector2(float(i) / float(n - 1), 0.0))
			_mesh.surface_add_vertex(base)
			_mesh.surface_set_color(c)
			_mesh.surface_set_uv(Vector2(float(i) / float(n - 1), 1.0))
			_mesh.surface_add_vertex(_tip[i])
		_mesh.surface_end()


# ---------------------------------------------------------------- shared resources

static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## Shared effect shader. `billboard` faces the camera and honours the particle angle.
static func shader(mode: String, billboard: bool) -> Shader:
	var key: String = mode + ("|b" if billboard else "|n")
	if _shaders.has(key):
		return _shaders[key]
	var code: String = "shader_type spatial;\nrender_mode " + mode + ";\n" + _SHADER_BODY
	if billboard:
		var bb: String = """
	{
		float ang = INSTANCE_CUSTOM.x;
		mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		world = world * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * world;
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {"""
		var marker: String = "\n}\n\nvoid fragment() {"
		code = code.replace(marker, bb)
	var sh: Shader = Shader.new()
	sh.code = code
	_shaders[key] = sh
	return sh


## Cached particle material.
static func material(shape: int, mode: String, energy: float, billboard: bool, tumble: bool) -> ShaderMaterial:
	var key: String = "%d|%s|%.2f|%s|%s" % [shape, mode, energy, billboard, tumble]
	if _materials.has(key):
		return _materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader(mode, billboard)
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("tumble", tumble)
	mat.set_shader_parameter("self_lit", 0.3 if mode == MODE_LIT else 0.0)
	mat.set_shader_parameter("soft", 0.4 if (shape == SHAPE_PUFF or shape == SHAPE_FLAME) else 0.0)
	_materials[key] = mat
	return mat


static func _ramp(colors: Array[Color], offsets: Array[float]) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex: GradientTexture1D = GradientTexture1D.new()
	tex.gradient = g
	tex.width = 64
	return tex


static func _curve(points: Array[Vector2]) -> CurveTexture:
	var c: Curve = Curve.new()
	var top: float = 1.0
	for p: Vector2 in points:
		top = maxf(top, p.y)
	c.max_value = top
	for p: Vector2 in points:
		c.add_point(p)
	var tex: CurveTexture = CurveTexture.new()
	tex.curve = c
	tex.width = 64
	return tex


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func _process_material(dir: Vector3, spread: float, vel_min: float, vel_max: float, gravity: Vector3,
		scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vel_min
	pm.initial_velocity_max = vel_max
	pm.gravity = gravity
	pm.scale_min = scale_min
	pm.scale_max = scale_max
	return pm


static func _particles(parent: Node3D, amount: int, life: float, pm: ParticleProcessMaterial, mat: ShaderMaterial,
		one_shot: bool, bounds: float) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.process_material = pm
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.one_shot = one_shot
	p.explosiveness = 0.92 if one_shot else 0.0
	p.randomness = 0.4
	p.fixed_fps = 0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3.ONE * -bounds, Vector3.ONE * bounds * 2.0)
	p.emitting = true
	parent.add_child(p)
	return p


static func _turbulence(pm: ParticleProcessMaterial, strength: float, scale: float, speed: float) -> void:
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = strength
	pm.turbulence_noise_scale = scale
	pm.turbulence_noise_speed = Vector3(0.0, speed, 0.0)
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.18


# ---------------------------------------------------------------- one-shot effects

## Burst of gold sparks for a landed blow. `strength` 0..2 (1 = normal hit, 2 = heavy or surge hit).
static func hit_sparks(pos: Vector3, strength: float) -> Effect:
	var s: float = clampf(strength, 0.1, 3.0)
	var fx: Effect = Effect.new()
	fx.name = "HitSparks"
	fx.position = pos
	fx.lifetime = 0.75
	# streak sparks
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 180.0, 3.0 + 2.0 * s, 7.0 + 4.0 * s,
		Vector3(0.0, -14.0, 0.0), 0.5, 1.0)
	pm.damping_min = 3.0
	pm.damping_max = 6.0
	pm.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])
	pm.color_ramp = _ramp([Color(1.0, 1.0, 0.9, 1.0), _alpha(Palette.FIRE_CORE, 1.0), _alpha(Palette.SAFFRON, 0.9),
		_alpha(Palette.FIRE_EDGE, 0.0)], [0.0, 0.2, 0.6, 1.0])
	var sparks: GPUParticles3D = _particles(fx, int(10.0 + 14.0 * s), 0.42, pm,
		material(SHAPE_STREAK, MODE_ADD, 5.0, false, false), true, 4.0)
	sparks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	sparks.name = "Sparks"
	var spark_mesh: QuadMesh = QuadMesh.new()
	spark_mesh.size = Vector2(0.07, 0.42 + 0.1 * s)
	spark_mesh.material = sparks.draw_pass_1.surface_get_material(0)
	sparks.draw_pass_1 = spark_mesh
	# impact flash
	var fm: ParticleProcessMaterial = _process_material(Vector3.UP, 0.0, 0.0, 0.0, Vector3.ZERO, 1.0, 1.0)
	fm.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(0.25, 1.0), Vector2(1.0, 0.2)])
	fm.color_ramp = _ramp([Color(1.0, 0.98, 0.85, 1.0), _alpha(Palette.GOLD, 0.6), _alpha(Palette.SAFFRON, 0.0)],
		[0.0, 0.4, 1.0])
	var flash: GPUParticles3D = _particles(fx, 2, 0.16, fm, material(SHAPE_GLOW, MODE_ADD, 3.2, true, false), true, 3.0)
	flash.name = "Flash"
	fm.scale_min = 0.9 + 0.7 * s
	fm.scale_max = 1.1 + 0.8 * s
	# lingering motes
	var mm: ParticleProcessMaterial = _process_material(Vector3.UP, 180.0, 0.6, 2.2, Vector3(0.0, 0.6, 0.0), 0.05, 0.11)
	mm.damping_min = 1.5
	mm.damping_max = 2.5
	mm.color_ramp = _ramp([_alpha(Palette.FIRE_CORE, 1.0), _alpha(Palette.GOLD, 0.8), _alpha(Palette.SAFFRON, 0.0)],
		[0.0, 0.5, 1.0])
	var motes: GPUParticles3D = _particles(fx, int(4.0 + 5.0 * s), 0.7, mm, material(SHAPE_GLOW, MODE_ADD, 4.0, true, false),
		true, 3.0)
	motes.name = "Motes"
	fx.set_light(Palette.FIRE_CORE, 1.6 + 1.6 * s, 3.0 + 1.5 * s, Effect.LIGHT_FLASH, 0.22, Vector3.ZERO)
	return fx


## Soft dust on a landing or footstep, at ground level.
static func dust_puff(pos: Vector3) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "DustPuff"
	fx.position = pos
	fx.lifetime = 1.0
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 12.0, 0.25, 0.6, Vector3(0.0, 0.25, 0.0), 0.35, 0.7)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.28
	pm.emission_ring_inner_radius = 0.1
	pm.emission_ring_height = 0.05
	pm.radial_velocity_min = 1.2
	pm.radial_velocity_max = 2.4
	pm.damping_min = 2.5
	pm.damping_max = 4.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_curve = _curve([Vector2(0.0, 0.45), Vector2(0.3, 1.0), Vector2(1.0, 1.5)])
	var dust: Color = Palette.STONE.lerp(Palette.MOON, 0.25)
	pm.color_ramp = _ramp([_alpha(dust, 0.0), _alpha(dust, 0.55), _alpha(dust, 0.3), _alpha(dust, 0.0)],
		[0.0, 0.12, 0.55, 1.0])
	var puffs: GPUParticles3D = _particles(fx, 12, 0.85, pm, material(SHAPE_PUFF, MODE_LIT, 1.0, true, false), true, 3.0)
	puffs.name = "Puffs"
	puffs.position.y = 0.12
	return fx


## Divine burst when Hanuman changes size: an expanding ring and outward motes when growing,
## a collapsing ring and inward-rushing motes when shrinking.
static func size_burst(pos: Vector3, growing: bool) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "SizeBurst"
	fx.position = pos
	fx.lifetime = 1.1
	var gold: Color = Palette.GOLD.lerp(Palette.FIRE_CORE, 0.5)
	if growing:
		fx.add_ring(0.3, 3.2, 0.55, 0.0, gold, 3.5, 0.1, true).position.y = 0.08
		fx.add_ring(0.2, 2.2, 0.6, 0.08, Palette.SAFFRON, 2.5, 0.16, false).position.y = 1.0
	else:
		fx.add_ring(2.6, 0.25, 0.45, 0.0, gold, 3.5, 0.1, true).position.y = 0.08
		fx.add_ring(1.8, 0.15, 0.5, 0.05, Palette.SAFFRON, 2.5, 0.16, false).position.y = 0.7
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 180.0, 0.0, 0.3, Vector3(0.0, 0.8, 0.0), 0.07, 0.16)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 0.5 if growing else 2.2
	pm.radial_velocity_min = 3.0 if growing else -5.5
	pm.radial_velocity_max = 6.5 if growing else -3.0
	pm.damping_min = 3.0 if growing else 0.0
	pm.damping_max = 5.0 if growing else 0.5
	pm.scale_curve = _curve([Vector2(0.0, 0.3), Vector2(0.2, 1.0), Vector2(1.0, 0.0)])
	pm.color_ramp = _ramp([Color(1.0, 0.97, 0.8, 1.0), _alpha(Palette.GOLD, 1.0), _alpha(Palette.SAFFRON, 0.0)],
		[0.0, 0.45, 1.0])
	var motes: GPUParticles3D = _particles(fx, 40, 0.8 if growing else 0.5, pm,
		material(SHAPE_GLOW, MODE_ADD, 4.0, true, false), true, 6.0)
	motes.name = "Motes"
	motes.position.y = 1.0
	# soft core bloom
	var cm: ParticleProcessMaterial = _process_material(Vector3.UP, 0.0, 0.0, 0.0, Vector3.ZERO, 2.6, 3.0)
	if growing:
		cm.scale_curve = _curve([Vector2(0.0, 0.3), Vector2(0.3, 1.0), Vector2(1.0, 1.3)])
	else:
		cm.scale_curve = _curve([Vector2(0.0, 1.2), Vector2(0.7, 0.5), Vector2(1.0, 0.1)])
	cm.color_ramp = _ramp([_alpha(Palette.FIRE_CORE, 0.0), _alpha(Palette.FIRE_CORE, 0.55), _alpha(Palette.GOLD, 0.0)],
		[0.0, 0.25, 1.0])
	var core: GPUParticles3D = _particles(fx, 1, 0.5, cm, material(SHAPE_GLOW, MODE_ADD, 1.6, true, false), true, 5.0)
	core.name = "Core"
	core.position.y = 1.0
	fx.set_light(Palette.GOLD, 3.0, 6.0, Effect.LIGHT_FLASH, 0.5, Vector3(0.0, 1.0, 0.0))
	return fx


## Ground shockwave for the Smarana surge: a gold ring that expands to `radius`, with a dust front.
static func shockwave(pos: Vector3, radius: float) -> Effect:
	var r: float = maxf(radius, 0.5)
	var fx: Effect = Effect.new()
	fx.name = "Shockwave"
	fx.position = pos
	fx.lifetime = 0.9
	var gold: Color = Palette.GOLD.lerp(Palette.FIRE_CORE, 0.4)
	fx.add_ring(0.2, r, 0.5, 0.0, gold, 4.0, 0.07, true).position.y = 0.1
	fx.add_ring(0.1, r * 0.82, 0.62, 0.06, Palette.SAFFRON, 2.2, 0.2, true).position.y = 0.06
	var speed: float = r / 0.5
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 25.0, 0.4, 1.2, Vector3(0.0, 0.3, 0.0), 0.5, 0.95)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.5
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.05
	pm.radial_velocity_min = speed * 1.1
	pm.radial_velocity_max = speed * 1.5
	pm.damping_min = speed * 1.6
	pm.damping_max = speed * 2.2
	pm.angle_max = 360.0
	pm.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(0.4, 1.0), Vector2(1.0, 1.4)])
	var dust: Color = Palette.STONE.lerp(Palette.GOLD, 0.3)
	pm.color_ramp = _ramp([_alpha(dust, 0.0), _alpha(dust, 0.38), _alpha(dust, 0.0)], [0.0, 0.2, 1.0])
	var front: GPUParticles3D = _particles(fx, int(clampf(10.0 * r, 16.0, 64.0)), 0.8, pm,
		material(SHAPE_PUFF, MODE_LIT, 1.0, true, false), true, r + 3.0)
	front.name = "DustFront"
	front.position.y = 0.2
	var sm: ParticleProcessMaterial = _process_material(Vector3.UP, 40.0, 1.0, 3.0, Vector3(0.0, -5.0, 0.0), 0.05, 0.12)
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	sm.emission_ring_axis = Vector3.UP
	sm.emission_ring_radius = 0.4
	sm.emission_ring_inner_radius = 0.2
	sm.emission_ring_height = 0.05
	sm.radial_velocity_min = speed * 0.7
	sm.radial_velocity_max = speed * 1.3
	sm.damping_min = speed
	sm.damping_max = speed * 1.6
	sm.color_ramp = _ramp([Color(1.0, 0.97, 0.8, 1.0), _alpha(Palette.GOLD, 1.0), _alpha(Palette.SAFFRON, 0.0)],
		[0.0, 0.4, 1.0])
	var sparks: GPUParticles3D = _particles(fx, int(clampf(8.0 * r, 16.0, 56.0)), 0.7, sm,
		material(SHAPE_GLOW, MODE_ADD, 4.0, true, false), true, r + 3.0)
	sparks.name = "Sparks"
	sparks.position.y = 0.15
	fx.set_light(Palette.GOLD, 4.0, r + 2.0, Effect.LIGHT_FLASH, 0.45, Vector3(0.0, 0.8, 0.0))
	return fx


## A defeated rakshasa dissolves into rising embers (no gore). `pos` is at the feet; `color` is the body colour.
static func dissolve_embers(pos: Vector3, color: Color) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "DissolveEmbers"
	fx.position = pos
	fx.lifetime = 2.0
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 35.0, 0.5, 1.6, Vector3(0.0, 1.4, 0.0), 0.07, 0.16)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.85, 0.3)
	_turbulence(pm, 1.4, 1.6, 0.6)
	pm.scale_curve = _curve([Vector2(0.0, 0.5), Vector2(0.15, 1.0), Vector2(1.0, 0.0)])
	var hot: Color = color.lerp(Palette.FIRE_EDGE, 0.55)
	pm.color_ramp = _ramp([_alpha(color.lightened(0.2), 1.0), _alpha(hot, 1.0), _alpha(Palette.SAFFRON, 1.0),
		_alpha(Palette.FIRE_CORE, 0.9), _alpha(Palette.SAFFRON, 0.0)], [0.0, 0.1, 0.3, 0.65, 1.0])
	var embers: GPUParticles3D = _particles(fx, 80, 1.5, pm, material(SHAPE_GLOW, MODE_ADD, 2.8, true, false), true, 5.0)
	embers.name = "Embers"
	embers.explosiveness = 0.75
	embers.position.y = 0.9
	# body-coloured wisps that carry the silhouette upward for a moment
	var wm: ParticleProcessMaterial = _process_material(Vector3.UP, 20.0, 0.3, 0.9, Vector3(0.0, 0.7, 0.0), 0.55, 0.95)
	wm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	wm.emission_box_extents = Vector3(0.3, 0.8, 0.25)
	wm.angle_max = 360.0
	wm.scale_curve = _curve([Vector2(0.0, 0.7), Vector2(1.0, 1.5)])
	var dark: Color = color.darkened(0.35)
	wm.color_ramp = _ramp([_alpha(dark, 0.0), _alpha(dark, 0.55), _alpha(dark, 0.0)], [0.0, 0.15, 1.0])
	var wisps: GPUParticles3D = _particles(fx, 14, 1.1, wm, material(SHAPE_PUFF, MODE_MIX, 1.0, true, false), true, 5.0)
	wisps.name = "Wisps"
	wisps.explosiveness = 0.8
	wisps.position.y = 0.9
	fx.set_light(hot, 1.6, 4.0, Effect.LIGHT_FLASH, 0.9, Vector3(0.0, 1.0, 0.0))
	return fx


## White spray where a wave breaks or something hits the sea.
static func sea_spray(pos: Vector3) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "SeaSpray"
	fx.position = pos
	fx.lifetime = 1.5
	var white: Color = Palette.MOON.lerp(Color.WHITE, 0.5)
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 32.0, 3.5, 7.5, Vector3(0.0, -9.8, 0.0), 0.06, 0.16)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.3)])
	pm.color_ramp = _ramp([_alpha(white, 0.95), _alpha(white, 0.8), _alpha(Palette.MOON, 0.0)], [0.0, 0.7, 1.0])
	var drops: GPUParticles3D = _particles(fx, 46, 1.1, pm, material(SHAPE_GLOW, MODE_LIT, 1.5, true, false), true, 6.0)
	drops.name = "Droplets"
	var mm: ParticleProcessMaterial = _process_material(Vector3.UP, 38.0, 1.5, 3.6, Vector3(0.0, -2.2, 0.0), 0.7, 1.3)
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mm.emission_sphere_radius = 0.3
	mm.damping_min = 1.2
	mm.damping_max = 2.0
	mm.angle_max = 360.0
	mm.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(0.4, 1.0), Vector2(1.0, 1.6)])
	var mist_c: Color = Palette.MOON.lerp(Palette.DEEP_OCEAN, 0.12)
	mm.color_ramp = _ramp([_alpha(mist_c, 0.0), _alpha(mist_c, 0.5), _alpha(mist_c, 0.0)], [0.0, 0.15, 1.0])
	var mist: GPUParticles3D = _particles(fx, 16, 1.2, mm, material(SHAPE_PUFF, MODE_LIT, 1.0, true, false), true, 6.0)
	mist.name = "Mist"
	return fx


# ---------------------------------------------------------------- looping effects

## Looping fire with smoke and embers. `size` 1 = a brazier or torch-bowl; 3+ = a burning roof.
## Pass with_light = false for dense fields of fire (the level then lights the scene itself).
static func fire(size: float, with_light: bool = true) -> Effect:
	var s: float = clampf(size, 0.2, 8.0)
	var fx: Effect = Effect.new()
	fx.name = "Fire"
	fx.looping = true
	fx.fade_time = 2.6
	var bounds: float = 4.0 + 5.0 * s
	# flames
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 9.0, 1.4 * s, 2.6 * s, Vector3(0.0, 1.8 * s, 0.0),
		0.6 * s, 1.0 * s)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.24 * s
	pm.angle_min = -14.0
	pm.angle_max = 14.0
	_turbulence(pm, 0.5 * s, 1.5 / s, 0.8)
	pm.scale_curve = _curve([Vector2(0.0, 0.55), Vector2(0.2, 1.0), Vector2(0.6, 0.7), Vector2(1.0, 0.12)])
	pm.color_ramp = _ramp([_alpha(Palette.FIRE_CORE, 0.0), _alpha(Palette.FIRE_CORE, 0.5), _alpha(Palette.SAFFRON, 0.45),
		_alpha(Palette.SAFFRON.lerp(Palette.FIRE_EDGE, 0.55), 0.32), _alpha(Palette.RAKSHASA_ARMOR, 0.0)],
		[0.0, 0.08, 0.35, 0.72, 1.0])
	var flames: GPUParticles3D = _particles(fx, int(clampf(12.0 + 5.0 * s, 14.0, 48.0)), 0.85, pm,
		material(SHAPE_FLAME, MODE_ADD, 0.8, true, false), false, bounds)
	flames.name = "Flames"
	flames.position.y = 0.15 * s
	flames.preprocess = 1.0
	# embers
	var em: ParticleProcessMaterial = _process_material(Vector3.UP, 28.0, 1.2 * s, 3.2 * s, Vector3(0.0, 1.2, 0.0), 0.035, 0.085)
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = 0.3 * s
	_turbulence(em, 2.2, 1.2, 0.5)
	em.color_ramp = _ramp([_alpha(Palette.FIRE_CORE, 1.0), _alpha(Palette.SAFFRON, 1.0), _alpha(Palette.FIRE_EDGE, 0.8),
		_alpha(Palette.FIRE_EDGE, 0.0)], [0.0, 0.35, 0.8, 1.0])
	var embers: GPUParticles3D = _particles(fx, int(clampf(8.0 + 8.0 * s, 10.0, 60.0)), 2.2, em,
		material(SHAPE_GLOW, MODE_ADD, 5.0, true, false), false, bounds)
	embers.name = "Embers"
	embers.position.y = 0.5 * s
	embers.preprocess = 2.0
	# smoke
	var sm: ParticleProcessMaterial = _process_material(Vector3(0.15, 1.0, 0.05), 12.0, 0.9 * s, 1.6 * s,
		Vector3(0.25, 0.5, 0.0), 0.8 * s, 1.3 * s)
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.2 * s
	sm.angle_max = 360.0
	sm.angular_velocity_min = -20.0
	sm.angular_velocity_max = 20.0
	sm.scale_curve = _curve([Vector2(0.0, 0.5), Vector2(0.5, 1.2), Vector2(1.0, 2.0)])
	var smoke_a: Color = Palette.RAKSHASA_ARMOR.lerp(Palette.UI_DARK, 0.8).lerp(Palette.SAFFRON, 0.08)
	var smoke_b: Color = Palette.NIGHT_INDIGO.lerp(Palette.UI_DARK, 0.5)
	sm.color_ramp = _ramp([_alpha(smoke_a, 0.0), _alpha(smoke_a, 0.42), _alpha(smoke_b, 0.3), _alpha(smoke_b, 0.0)],
		[0.0, 0.2, 0.6, 1.0])
	var smoke: GPUParticles3D = _particles(fx, int(clampf(8.0 + 4.0 * s, 10.0, 32.0)), 3.0, sm,
		material(SHAPE_PUFF, MODE_MIX, 1.0, true, false), false, bounds + 4.0)
	smoke.name = "Smoke"
	smoke.position.y = 1.2 * s
	smoke.preprocess = 3.0
	smoke.sorting_offset = -1.0
	if with_light:
		fx.set_light(Palette.SAFFRON.lerp(Palette.FIRE_CORE, 0.4), 2.2 + 0.9 * s, 4.0 + 4.0 * s, Effect.LIGHT_FLICKER, 1.0,
			Vector3(0.0, 0.7 * s, 0.0))
	return fx


## Gada or tail arc: a glowing ribbon between the node's origin and its local +Y * length.
## Parents itself to `attach`; call stop() when the swing ends (it fades and frees) or keep one alive
## for the whole fight and call (trail as Vfx.Trail).clear() between swings.
static func swing_trail(attach: Node3D, length: float, color: Color) -> Effect:
	var trail: Trail = Trail.new()
	trail.name = "SwingTrail"
	trail.setup(attach, length, color)
	if attach != null:
		attach.add_child(trail)
	return trail


## Faint golden motes that rise around a character while Smarana is high. Parents itself to `attach`
## (emits around the node's origin up to roughly 2 m).
static func smarana_motes(attach: Node3D) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "SmaranaMotes"
	fx.looping = true
	fx.fade_time = 2.4
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 25.0, 0.25, 0.7, Vector3(0.0, 0.35, 0.0), 0.06, 0.13)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.75
	pm.emission_ring_inner_radius = 0.35
	pm.emission_ring_height = 1.4
	pm.orbit_velocity_min = 0.08
	pm.orbit_velocity_max = 0.22
	_turbulence(pm, 0.5, 1.4, 0.3)
	pm.scale_curve = _curve([Vector2(0.0, 0.0), Vector2(0.2, 1.0), Vector2(0.75, 0.8), Vector2(1.0, 0.0)])
	pm.color_ramp = _ramp([_alpha(Palette.FIRE_CORE, 0.0), _alpha(Palette.FIRE_CORE, 1.0), _alpha(Palette.GOLD, 0.9),
		_alpha(Palette.SAFFRON, 0.0)], [0.0, 0.2, 0.65, 1.0])
	var motes: GPUParticles3D = _particles(fx, 36, 2.2, pm, material(SHAPE_GLOW, MODE_ADD, 2.8, true, false), false, 6.0)
	motes.name = "Motes"
	motes.position.y = 0.9
	if attach != null:
		attach.add_child(fx)
	return fx


## Fireflies drifting and blinking inside `area` (level-local AABB). The node sits at the area centre.
static func fireflies(area: AABB) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "Fireflies"
	fx.looping = true
	fx.fade_time = 5.0
	fx.position = area.get_center()
	var half: Vector3 = area.size * 0.5
	var pm: ParticleProcessMaterial = _process_material(Vector3.UP, 180.0, 0.1, 0.4, Vector3.ZERO, 0.1, 0.18)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = half
	_turbulence(pm, 1.2, 2.5, 0.2)
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.3
	var glow: Color = Palette.FIRE_CORE.lerp(Palette.GROVE_GREEN.lightened(0.3), 0.45)
	# blink: three pulses over a life
	pm.color_ramp = _ramp([_alpha(glow, 0.0), _alpha(glow, 1.0), _alpha(glow, 0.12), _alpha(glow, 1.0), _alpha(glow, 0.1),
		_alpha(glow, 0.9), _alpha(glow, 0.0)], [0.0, 0.12, 0.3, 0.45, 0.65, 0.82, 1.0])
	pm.hue_variation_min = -0.03
	pm.hue_variation_max = 0.03
	var ground: float = maxf(area.size.x * area.size.z, 1.0)
	var count: int = int(clampf(ground * 0.5, 8.0, 160.0))
	var flies: GPUParticles3D = _particles(fx, count, 6.0, pm, material(SHAPE_GLOW, MODE_ADD, 2.3, true, false), false, 1.0)
	flies.name = "Flies"
	flies.randomness = 1.0
	flies.preprocess = 6.0
	flies.visibility_aabb = AABB(-half - Vector3.ONE * 3.0, area.size + Vector3.ONE * 6.0)
	return fx


## Petals drifting down through `area` (Ashoka grove). The node sits at the area centre.
static func petals(area: AABB, color: Color) -> Effect:
	var fx: Effect = Effect.new()
	fx.name = "Petals"
	fx.looping = true
	fx.fade_time = 7.0
	fx.position = area.get_center()
	var half: Vector3 = area.size * 0.5
	var fall: float = 0.75
	var life: float = clampf(area.size.y / fall, 3.0, 12.0)
	fx.fade_time = life
	var pm: ParticleProcessMaterial = _process_material(Vector3(0.5, -1.0, 0.2), 30.0, fall * 0.8, fall * 1.2, Vector3.ZERO,
		0.16, 0.27)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(half.x, half.y * 0.15, half.z)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = 60.0
	pm.angular_velocity_max = 220.0
	_turbulence(pm, 0.9, 2.0, 0.25)
	pm.turbulence_influence_min = 0.08
	pm.turbulence_influence_max = 0.22
	pm.color_ramp = _ramp([_alpha(color, 0.0), _alpha(color.lightened(0.12), 1.0), _alpha(color, 1.0), _alpha(color, 0.0)],
		[0.0, 0.08, 0.88, 1.0])
	pm.hue_variation_min = -0.025
	pm.hue_variation_max = 0.035
	var ground: float = maxf(area.size.x * area.size.z, 1.0)
	var count: int = int(clampf(ground * 1.2, 12.0, 320.0))
	var fall_p: GPUParticles3D = _particles(fx, count, life, pm, material(SHAPE_PETAL, MODE_LIT, 1.15, false, true), false, 1.0)
	fall_p.name = "Petals"
	fall_p.position.y = half.y * 0.85
	fall_p.randomness = 1.0
	fall_p.preprocess = life
	fall_p.visibility_aabb = AABB(Vector3(-half.x - 4.0, -area.size.y - 3.0, -half.z - 4.0),
		Vector3(area.size.x + 8.0, area.size.y + 5.0, area.size.z + 8.0))
	return fx
