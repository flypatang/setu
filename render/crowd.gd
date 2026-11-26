class_name CrowdView
extends Node3D
## Crowd of low-detail vanaras hauling along routes (DESIGN §9, S13; art v2 S41, docs/ART.md).
## Reads the simulation, never writes it.
## One MultiMesh for vanaras, plus one per carried-item kind (plain stone, inscribed stone with RamaGlyph, timber).
##
## The vanara is a small cousin of the v2 Hanuman: a rounded chest, a big head with a pale muzzle and ears, a
## saffron dhoti and a long tail curling up behind, about 300 triangles with smooth normals. Each vertex carries
## UV.x = its limb (LIMB_* below) and UV.y = what it is made of (KIND_*), which the shader uses to animate and to
## tint it. Per-instance custom data is (carrying 0/1, seed 0..1, 0, 0).
## Vertex shader: a walk bob, legs and arms swinging from the hip and shoulder, a swaying tail; a carrying vanara
## lifts both arms over its head to hold its load and sways under it. The seed offsets the walk phase and picks the
## fur tone (gold to deep brown) and the cloth (saffron, sindoor or undyed cotton); it also sets the size in sync().
## Items use the same shader with the carrier's seed, so a load bobs in step with the vanara under it.

const MAX_INSTANCES: int = 2000
const ITEM_KINDS: Array[StringName] = [&"stone", &"inscribed_stone", &"timber"]

const LIMB_BODY: int = 0
const LIMB_ARM_L: int = 1
const LIMB_ARM_R: int = 2
const LIMB_LEG_L: int = 3
const LIMB_LEG_R: int = 4
const LIMB_TAIL: int = 5
## Material of a vertex: fur takes the per-vanara fur tone, cloth the per-vanara dye, plain keeps its colour.
const KIND_FUR: float = 0.0
const KIND_CLOTH: float = 1.0
const KIND_PLAIN: float = 2.0

## Where a load is held, in the carrier's own space (the model faces -Z). Matches the raised hands in the shader.
const _CARRY_OFFSET: Vector3 = Vector3(0.0, 1.82, -0.12)
## Joints, mirrored in _SHADER (shoulder and hip).
const _SHOULDER: Vector3 = Vector3(0.29, 1.1, 0.0)
const _HIP: Vector3 = Vector3(0.115, 0.5, 0.0)
const _ARM_LENGTH: float = 0.6

const _SHADER: String = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Joints of the vanara mesh (see CrowdView._SHOULDER and _HIP).
const vec3 SHOULDER = vec3(0.29, 1.1, 0.0);
const vec3 HIP = vec3(0.115, 0.5, 0.0);
const vec3 SHADOW_TINT = vec3(0.11, 0.11, 0.23);

varying vec3 v_color;
varying float v_kind;
varying vec3 v_pos;

vec3 swing(vec3 p, vec3 pivot, float angle) {
	vec3 d = p - pivot;
	float c = cos(angle);
	float s = sin(angle);
	return pivot + vec3(d.x, d.y * c - d.z * s, d.y * s + d.z * c);
}

vec3 swing_normal(vec3 n, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec3(n.x, n.y * c - n.z * s, n.y * s + n.z * c);
}

void vertex() {
	float carry = INSTANCE_CUSTOM.r;
	float seed = INSTANCE_CUSTOM.g;
	float limb = UV.x;
	v_kind = UV.y;
	v_pos = VERTEX;
	float phase = TIME * (7.0 + seed * 1.5) + seed * 43.0;
	float stride = sin(phase);
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	if (limb > 0.5 && limb < 2.5) {
		// Arms: swing from the shoulder; when carrying both go up over the head and sway under the load.
		float side = limb < 1.5 ? -1.0 : 1.0;
		float walk = -stride * 0.6 * side;
		float held = 2.85 + sin(phase * 2.0 + side) * 0.07;
		float angle = mix(walk, held, carry);
		vec3 pivot = vec3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z);
		float reach = clamp((pivot.y - p.y) / 0.6, 0.0, 1.0);
		p = swing(p, pivot, angle);
		n = swing_normal(n, angle);
		// Raised hands close in on the load.
		p.x -= side * 0.13 * reach * carry;
	} else if (limb > 2.5 && limb < 4.5) {
		float side = limb < 3.5 ? -1.0 : 1.0;
		float angle = stride * 0.55 * side;
		p = swing(p, vec3(HIP.x * side, HIP.y, HIP.z), angle);
		n = swing_normal(n, angle);
	} else if (limb > 4.5) {
		// Tail: sways more towards its tip (UV2 is not used; the tip is the part furthest back and up).
		float tip = clamp((p.z - 0.12) / 0.5, 0.0, 1.0);
		p.x += sin(phase * 0.5 + p.y * 3.0) * 0.09 * tip;
		p.y += cos(phase) * 0.03 * tip;
	} else {
		// Body and loads: a small shoulder roll in step with the stride, a sway under a load.
		p.x += stride * 0.015 * clamp(p.y - 0.6, 0.0, 1.0) * (1.0 + carry);
	}
	// Walk bob (twice per stride) for everything, feet stay near the ground.
	p.y += abs(cos(phase)) * 0.05 * smoothstep(0.0, 0.4, VERTEX.y);
	VERTEX = p;
	NORMAL = n;

	// Per-vanara variety: fur from gold to deep brown, cloth saffron, sindoor or undyed cotton.
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float h1 = fract(seed * 7.31 + 0.13);
	float h2 = fract(seed * 13.77 + 0.41);
	if (v_kind < 0.5) {
		col *= mix(vec3(1.12, 1.06, 0.95), vec3(0.46, 0.34, 0.27), h1 * h1);
	} else if (v_kind < 1.5) {
		float value = dot(col, vec3(0.35, 0.5, 0.15)) / 0.44;
		if (h2 > 0.8) {
			col = mix(col, vec3(0.80, 0.66, 0.42) * value, 0.85);
		} else if (h2 > 0.55) {
			col = mix(col, vec3(0.62, 0.03, 0.06) * value, 0.8);
		}
	}
	v_color = col;
}

void fragment() {
	// Orthographic cameras (the iso camera) have a constant view direction.
	vec3 view = PROJECTION_MATRIX[3][3] != 0.0 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), view), 0.0, 1.0), 3.0);
	float fur = 1.0 - step(0.5, v_kind);
	// Painted variation: streaks that run down the fur, soft blotches, and a darker value towards the ground.
	float streak = sin(v_pos.x * 37.0 + v_pos.z * 31.0 + sin(v_pos.y * 5.0) * 1.5) * sin(v_pos.y * 11.0 + v_pos.x * 4.0);
	float blotch = sin(v_pos.x * 9.0 + 1.3) * sin(v_pos.y * 7.0 + 0.4) * sin(v_pos.z * 8.0 + 2.1);
	float value = 1.0 + streak * (0.03 + 0.04 * fur) + blotch * 0.09;
	value *= mix(0.74, 1.06, smoothstep(0.0, 1.25, v_pos.y));
	ALBEDO = v_color * value;
	ROUGHNESS = 1.0;
	// A soft warm sheen at grazing angles (fur and cloth), so the crowd does not go flat in shadow.
	EMISSION = v_color * vec3(1.0, 0.86, 0.6) * rim * (0.12 + 0.16 * fur);
}

void light() {
	// Soft wrapped diffuse with one gentle band; the shadow side is lifted toward indigo, never grey.
	float w = clamp(dot(NORMAL, LIGHT) * 0.62 + 0.38, 0.0, 1.0);
	float soft = w * w * (3.0 - 2.0 * w);
	float band = mix(soft, smoothstep(0.3, 0.62, w), 0.3) * ATTENUATION;
	vec3 light = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += light * band + light * (1.0 - band) * SHADOW_TINT;
}
"""

static var _shader: Shader = null
static var _crowd_material: ShaderMaterial = null

var _vanara_mesh: ArrayMesh = null
var _item_meshes: Dictionary = {}
var _vanara_mm: MultiMesh = null
var _item_mms: Dictionary = {}
var _vanara_pos: PackedVector3Array = PackedVector3Array()
var _vanara_carry: PackedByteArray = PackedByteArray()
var _vanara_variety: PackedFloat32Array = PackedFloat32Array()
var _item_pos: Dictionary = {}
var _item_counts: Dictionary = {}
var _vanara_n: int = 0


func _init() -> void:
	_vanara_mesh = _build_vanara()
	_item_meshes[&"stone"] = _build_stone(false)
	_item_meshes[&"inscribed_stone"] = _build_stone(true)
	_item_meshes[&"timber"] = _build_timber()
	_vanara_mm = _make_mm(_vanara_mesh)
	_add_mmi(_vanara_mm, "Vanaras")
	for k: StringName in ITEM_KINDS:
		var mm: MultiMesh = _make_mm(_item_meshes[k] as ArrayMesh)
		_item_mms[k] = mm
		_item_counts[k] = 0
		_item_pos[k] = [] as Array[Vector3]
		_add_mmi(mm, String(k))


func vanara_mesh() -> ArrayMesh:
	return _vanara_mesh


func item_mesh(kind: StringName) -> ArrayMesh:
	return _item_meshes.get(kind, null) as ArrayMesh


func vanara_count() -> int:
	return _vanara_n


func item_count(kind: StringName) -> int:
	return _item_counts.get(kind, 0) as int


func vanara_position(i: int) -> Vector3:
	return _vanara_pos[i]


## True when vanara i is hauling a load (its arms are raised and an item is drawn over it).
func vanara_carrying(i: int) -> bool:
	return _vanara_carry[i] != 0


## The per-instance seed of vanara i, in 0..1: it sets its fur tone, its cloth, its walk phase and its size.
func vanara_variety(i: int) -> float:
	return _vanara_variety[i]


## Height factor of vanara i (0.88 to 1.1).
func vanara_size(i: int) -> float:
	return _size(_vanara_variety[i])


## World position of carried item i of a kind (the i-th carrying vanara of that kind, in route order).
func item_position(kind: StringName, i: int) -> Vector3:
	return (_item_pos[kind] as Array[Vector3])[i]


## Repositions every instance from the simulation state. Read-only on the sim.
func sync(day_flow: DayFlow) -> void:
	var routes: Dictionary = day_flow.snapshot().get("routes", {}) as Dictionary
	var ids: Array = routes.keys()
	ids.sort()
	var tick: int = day_flow.tick()
	var n: int = 0
	var counts: Dictionary = {}
	var positions: Dictionary = {}
	for k: StringName in ITEM_KINDS:
		counts[k] = 0
		positions[k] = [] as Array[Vector3]
	_vanara_pos.resize(0)
	_vanara_carry.resize(0)
	_vanara_variety.resize(0)
	for id: Variant in ids:
		var route: Route = day_flow.route(str(id))
		if route == null or route.points.size() < 2:
			continue
		var total: float = route.length()
		if total <= 0.0:
			continue
		var kind: StringName = StringName(route.kind)
		if kind == &"rope":
			kind = &"timber"
		var carrying: bool = route.from_pile != null and route.from_pile.count(route.kind) > 0
		var shows_item: bool = carrying and ITEM_KINDS.has(kind)
		var travelled: float = route.HAULER_SPEED * float(tick) / float(Route.TICK_RATE)
		for h: int in range(route.haulers):
			if n >= MAX_INSTANCES:
				break
			var d: float = fposmod(travelled + total * float(h) / float(route.haulers), total)
			var at: Dictionary = _sample(route.points, d)
			var p: Vector3 = at["pos"] as Vector3
			var yaw: float = at["yaw"] as float
			var variety: float = _seed(n)
			var size: float = _size(variety)
			var facing: Basis = Basis(Vector3.UP, yaw)
			var data: Color = Color(1.0 if shows_item else 0.0, variety, 0.0, 0.0)
			_vanara_mm.set_instance_transform(n, Transform3D(facing.scaled(Vector3(size, size, size)), p))
			_vanara_mm.set_instance_custom_data(n, data)
			_vanara_pos.append(p)
			_vanara_carry.append(1 if shows_item else 0)
			_vanara_variety.append(variety)
			n += 1
			if shows_item:
				var c: int = counts[kind] as int
				var held: Vector3 = p + facing * (_CARRY_OFFSET * size)
				var mm: MultiMesh = _item_mms[kind] as MultiMesh
				mm.set_instance_transform(c, Transform3D(facing, held))
				mm.set_instance_custom_data(c, Color(0.0, variety, 0.0, 0.0))
				(positions[kind] as Array[Vector3]).append(held)
				counts[kind] = c + 1
	_vanara_n = n
	_vanara_mm.visible_instance_count = n
	for k: StringName in ITEM_KINDS:
		_item_counts[k] = counts[k]
		_item_pos[k] = positions[k]
		(_item_mms[k] as MultiMesh).visible_instance_count = counts[k] as int


## Per-instance seed in 0..1 (golden-ratio sequence: neighbours in a line differ strongly).
static func _seed(n: int) -> float:
	return fposmod(float(n) * 0.6180339 + 0.137, 1.0)


## Per-instance height factor, 0.88 to 1.1.
static func _size(variety: float) -> float:
	return 0.88 + 0.22 * fposmod(variety * 5.37 + 0.29, 1.0)


static func _sample(points: PackedVector2Array, dist: float) -> Dictionary:
	var left: float = dist
	for i: int in range(points.size() - 1):
		var seg: float = points[i].distance_to(points[i + 1])
		if left <= seg or i == points.size() - 2:
			var t: float = 0.0 if seg <= 0.0 else clampf(left / seg, 0.0, 1.0)
			var q: Vector2 = points[i].lerp(points[i + 1], t)
			var dir: Vector2 = points[i + 1] - points[i]
			# Model faces -Z; yaw so that -Z points along the travel direction (x, z = point x, y).
			return {"pos": Vector3(q.x, 0.0, q.y), "yaw": atan2(-dir.x, -dir.y)}
		left -= seg
	return {"pos": Vector3.ZERO, "yaw": 0.0}


## The one material shared by the vanaras and their loads.
static func crowd_material() -> ShaderMaterial:
	if _crowd_material == null:
		_shader = Shader.new()
		_shader.code = _SHADER
		_crowd_material = ShaderMaterial.new()
		_crowd_material.shader = _shader
	return _crowd_material


func _add_mmi(mm: MultiMesh, node_name: String) -> void:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = crowd_material()
	mmi.custom_aabb = AABB(Vector3(-400.0, -5.0, -400.0), Vector3(800.0, 30.0, 800.0))
	add_child(mmi)


func _make_mm(mesh: ArrayMesh) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	return mm


## A mesh part: `limb` and `kind` go into the UVs of every vertex of the part.
static func _part(mesh: ArrayMesh, offset: Vector3, euler: Vector3 = Vector3.ZERO, limb: int = LIMB_BODY,
		kind: float = KIND_PLAIN, stretch: Vector3 = Vector3.ONE) -> Dictionary:
	var b: Basis = Basis.from_euler(euler * (PI / 180.0)).scaled_local(stretch)
	return {"mesh": mesh, "transform": Transform3D(b, offset), "limb": limb, "kind": kind}


## Combines parts into one surface with vertices, normals, colours and UVs (limb, kind). Not indexed.
static func _assemble(parts: Array[Dictionary]) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	for part: Dictionary in parts:
		var merged: ArrayMesh = MeshKit.merge([part])
		if merged.get_surface_count() == 0:
			continue
		var arrays: Array = merged.surface_get_arrays(0)
		var uv: Vector2 = Vector2(float(part.get("limb", LIMB_BODY) as int), part.get("kind", KIND_PLAIN) as float)
		var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		verts.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		norms.append_array(arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		cols.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
		for i: int in count:
			uvs.append(uv)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## About 300 triangles, smooth normals. Faces -Z, feet at y = 0, arms hanging (the shader raises them).
## Proportions follow the v2 Hanuman at crowd scale: a deep chest and heavy shoulders, long arms, short legs, a big
## head with a pale muzzle and round ears, a saffron dhoti with a sash end, and a tail that sweeps back and curls up.
static func _build_vanara() -> ArrayMesh:
	var fur: Color = Palette.HANUMAN_FUR
	var dark: Color = fur.darkened(0.28)
	var face: Color = Palette.SHORE_SAND.lerp(Palette.HANUMAN_FUR, 0.3)
	var cloth: Color = Palette.SAFFRON
	var parts: Array[Dictionary] = []
	# Chest (broad, flattened front to back) over a narrower waist.
	parts.append(_part(MeshKit.cylinder(0.25, 0.165, 0.46, 8, fur, true), Vector3(0.0, 0.93, 0.0), Vector3.ZERO,
		LIMB_BODY, KIND_FUR, Vector3(1.0, 1.0, 0.76)))
	# Dhoti with a sash end hanging at the front.
	parts.append(_part(MeshKit.cylinder(0.175, 0.23, 0.3, 7, cloth, true), Vector3(0.0, 0.6, 0.0), Vector3.ZERO,
		LIMB_BODY, KIND_CLOTH, Vector3(1.0, 1.0, 0.85)))
	parts.append(_part(MeshKit.box(Vector3(0.12, 0.26, 0.03), cloth.lightened(0.15)), Vector3(0.0, 0.47, -0.2),
		Vector3(8.0, 0.0, 0.0), LIMB_BODY, KIND_CLOTH))
	# Head, pale muzzle, round ears.
	parts.append(_part(MeshKit.sphere(0.2, 4, 8, fur, true), Vector3(0.0, 1.34, -0.03), Vector3.ZERO,
		LIMB_BODY, KIND_FUR, Vector3(1.0, 0.95, 1.0)))
	parts.append(_part(MeshKit.sphere(0.115, 3, 6, face, true), Vector3(0.0, 1.28, -0.16), Vector3.ZERO,
		LIMB_BODY, KIND_PLAIN, Vector3(1.05, 0.82, 0.9)))
	for side: float in [-1.0, 1.0]:
		parts.append(_part(MeshKit.sphere(0.07, 2, 4, face.darkened(0.12), true), Vector3(side * 0.2, 1.38, 0.0),
			Vector3.ZERO, LIMB_BODY, KIND_PLAIN, Vector3(0.6, 1.0, 1.0)))
	# Long arms hang from heavy shoulders; short legs from the hips, with feet.
	for side: float in [-1.0, 1.0]:
		var arm: int = LIMB_ARM_L if side < 0.0 else LIMB_ARM_R
		var leg: int = LIMB_LEG_L if side < 0.0 else LIMB_LEG_R
		parts.append(_part(MeshKit.sphere(0.1, 2, 5, fur, true), Vector3(side * _SHOULDER.x, _SHOULDER.y, 0.0),
			Vector3.ZERO, arm, KIND_FUR))
		parts.append(_part(MeshKit.cylinder(0.085, 0.06, _ARM_LENGTH, 5, fur, true),
			Vector3(side * _SHOULDER.x, _SHOULDER.y - _ARM_LENGTH * 0.5, 0.0), Vector3.ZERO, arm, KIND_FUR))
		parts.append(_part(MeshKit.cylinder(0.1, 0.07, _HIP.y, 5, dark, true),
			Vector3(side * _HIP.x, _HIP.y * 0.5, 0.0), Vector3.ZERO, leg, KIND_FUR))
		parts.append(_part(MeshKit.box(Vector3(0.11, 0.06, 0.21), dark), Vector3(side * _HIP.x, 0.03, -0.05),
			Vector3.ZERO, leg, KIND_FUR))
	# Tail: three segments sweeping back and curling up, with a tuft.
	var tail: Array[Vector3] = [Vector3(0.0, 0.6, 0.12), Vector3(0.0, 0.52, 0.42), Vector3(0.0, 0.8, 0.64), Vector3(0.0, 1.12, 0.6)]
	for i: int in tail.size() - 1:
		var a: Vector3 = tail[i]
		var b: Vector3 = tail[i + 1]
		var along: Vector3 = b - a
		var pitch: float = rad_to_deg(atan2(along.z, along.y))
		var r0: float = 0.06 - 0.008 * float(i)
		parts.append(_part(MeshKit.cylinder(r0 - 0.008, r0, along.length() + 0.04, 4, fur.darkened(0.08 * float(i)), true),
			(a + b) * 0.5, Vector3(pitch, 0.0, 0.0), LIMB_TAIL, KIND_FUR))
	parts.append(_part(MeshKit.sphere(0.075, 2, 4, dark, true), tail[3], Vector3.ZERO, LIMB_TAIL, KIND_FUR))
	return _assemble(parts)


## A rough-hewn block (a chunky bevelled stone). The inscribed one carries the राम strokes in SINDOOR on top.
static func _build_stone(inscribed: bool) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	parts.append(_part(MeshKit.bevel_box(Vector3(0.6, 0.34, 0.46), 0.07, Palette.STONE), Vector3.ZERO))
	if inscribed:
		var glyph: ArrayMesh = RamaGlyph.mesh(0.26, Palette.SINDOOR)
		parts.append(_part(glyph, Vector3(0.0, 0.175, 0.0), Vector3(-90.0, 0.0, 0.0)))
	return _assemble(parts)


## A log carried across the shoulders: bark outside, pale cut wood at both ends.
static func _build_timber() -> ArrayMesh:
	var parts: Array[Dictionary] = []
	var bark: Color = Palette.BARK.lightened(0.08)
	var cut: Color = Palette.SHORE_SAND.lerp(Palette.BARK, 0.25)
	parts.append(_part(MeshKit.cylinder(0.085, 0.1, 1.3, 7, bark, true), Vector3.ZERO, Vector3(0.0, 0.0, 90.0)))
	for side: float in [-1.0, 1.0]:
		parts.append(_part(MeshKit.cylinder(0.07, 0.07, 0.02, 7, cut), Vector3(side * 0.655, 0.0, 0.0), Vector3(0.0, 0.0, 90.0)))
	return _assemble(parts)
