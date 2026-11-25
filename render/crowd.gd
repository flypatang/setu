class_name CrowdView
extends Node3D
## Crowd of low-detail vanaras hauling along routes (DESIGN §9, S13). Reads the simulation, never writes it.
## One MultiMesh for vanaras, plus one per carried-item kind (plain stone, inscribed stone, timber).
## Inscribed stones get a second MultiMesh with the textured RamaGlyph quad lying on top of each carried stone (S14c).

const MAX_INSTANCES: int = 2000
const ITEM_KINDS: Array[StringName] = [&"stone", &"inscribed_stone", &"timber"]
const _CARRY_HEIGHT: float = 1.45
const _GLYPH_HEIGHT: float = 0.28
const _GLYPH_LIFT: float = 0.16

const _SHADER: String = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float legs = 1.0;
const float AMBIENT = 0.30;
varying vec3 v_color;

void vertex() {
	v_color = pow(COLOR.rgb, vec3(2.2));
	float id = float(INSTANCE_ID);
	float phase = TIME * 7.0 + id * 1.7;
	VERTEX.y += abs(sin(phase)) * 0.06;
	if (legs > 0.5 && VERTEX.y < 0.7) {
		VERTEX.z += sin(phase) * 0.18 * sign(VERTEX.x + 0.0001) * (0.7 - VERTEX.y);
	}
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 1.0;
	EMISSION = v_color * AMBIENT * 0.35;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = 0.28 * step(0.05, ndl) + 0.25 * step(0.40, ndl) + 0.27 * step(0.70, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp;
}
"""

static var _shader: Shader = null

var _vanara_mesh: ArrayMesh = null
var _item_meshes: Dictionary = {}
var _vanara_mm: MultiMesh = null
var _item_mms: Dictionary = {}
var _vanara_pos: PackedVector3Array = PackedVector3Array()
var _item_counts: Dictionary = {}
var _vanara_n: int = 0
var _glyph_mm: MultiMesh = null


func _init() -> void:
	_vanara_mesh = _build_vanara()
	_item_meshes[&"stone"] = _build_stone(false)
	_item_meshes[&"inscribed_stone"] = _build_stone(true)
	_item_meshes[&"timber"] = _build_timber()
	_vanara_mm = _make_mm(_vanara_mesh, 1.0)
	_add_mmi(_vanara_mm, "Vanaras")
	for k: StringName in ITEM_KINDS:
		var mm: MultiMesh = _make_mm(_item_meshes[k] as ArrayMesh, 0.0)
		_item_mms[k] = mm
		_item_counts[k] = 0
		_add_mmi(mm, String(k))
	_glyph_mm = _make_mm(RamaGlyph.mesh(_GLYPH_HEIGHT, Palette.SINDOOR), 0.0)
	var gmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	gmi.name = "InscribedGlyphs"
	gmi.multimesh = _glyph_mm
	gmi.material_override = RamaGlyph.material()
	gmi.custom_aabb = AABB(Vector3(-400.0, -5.0, -400.0), Vector3(800.0, 30.0, 800.0))
	add_child(gmi)


func vanara_mesh() -> ArrayMesh:
	return _vanara_mesh


func item_mesh(kind: StringName) -> ArrayMesh:
	return _item_meshes.get(kind, null) as ArrayMesh


## Number of textured राम quads shown (one per carried inscribed stone).
func glyph_count() -> int:
	return _glyph_mm.visible_instance_count


func vanara_count() -> int:
	return _vanara_n


func item_count(kind: StringName) -> int:
	return _item_counts.get(kind, 0) as int


func vanara_position(i: int) -> Vector3:
	return _vanara_pos[i]


## Repositions every instance from the simulation state. Read-only on the sim.
func sync(day_flow: DayFlow) -> void:
	var routes: Dictionary = day_flow.snapshot().get("routes", {}) as Dictionary
	var ids: Array = routes.keys()
	ids.sort()
	var tick: int = day_flow.tick()
	var n: int = 0
	var counts: Dictionary = {}
	for k: StringName in ITEM_KINDS:
		counts[k] = 0
	_vanara_pos.resize(0)
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
		var travelled: float = route.HAULER_SPEED * float(tick) / float(Route.TICK_RATE)
		for h: int in range(route.haulers):
			if n >= MAX_INSTANCES:
				break
			var d: float = fposmod(travelled + total * float(h) / float(route.haulers), total)
			var at: Dictionary = _sample(route.points, d)
			var p: Vector3 = at["pos"] as Vector3
			var yaw: float = at["yaw"] as float
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), p)
			_vanara_mm.set_instance_transform(n, xf)
			_vanara_pos.append(p)
			n += 1
			if carrying and ITEM_KINDS.has(kind):
				var c: int = counts[kind] as int
				var ixf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0.0, _CARRY_HEIGHT, 0.0))
				(_item_mms[kind] as MultiMesh).set_instance_transform(c, ixf)
				if kind == &"inscribed_stone":
					var lay: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0.0, _GLYPH_LIFT, 0.0))
					_glyph_mm.set_instance_transform(c, ixf * lay)
				counts[kind] = c + 1
	_vanara_n = n
	_vanara_mm.visible_instance_count = n
	for k: StringName in ITEM_KINDS:
		_item_counts[k] = counts[k]
		(_item_mms[k] as MultiMesh).visible_instance_count = counts[k] as int
	_glyph_mm.visible_instance_count = counts[&"inscribed_stone"] as int


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


func _add_mmi(mm: MultiMesh, node_name: String) -> void:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	var mat: ShaderMaterial = ShaderMaterial.new()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SHADER
	mat.shader = _shader
	mat.set_shader_parameter("legs", 1.0 if node_name == "Vanaras" else 0.0)
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-400.0, -5.0, -400.0), Vector3(800.0, 30.0, 800.0))
	add_child(mmi)


func _make_mm(mesh: ArrayMesh, _legs: float) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	return mm


static func _part(mesh: ArrayMesh, offset: Vector3, euler: Vector3 = Vector3.ZERO) -> Dictionary:
	var b: Basis = Basis.from_euler(euler * (PI / 180.0))
	return {"mesh": mesh, "transform": Transform3D(b, offset)}


## About 150 triangles: torso, head, snout, two arms, two legs, tail. Faces -Z, feet at y=0.
static func _build_vanara() -> ArrayMesh:
	var fur: Color = Palette.HANUMAN_FUR
	var dark: Color = fur.darkened(0.25)
	var parts: Array[Dictionary] = []
	parts.append(_part(MeshKit.box(Vector3(0.36, 0.5, 0.22), fur), Vector3(0.0, 0.95, 0.0)))
	parts.append(_part(MeshKit.sphere(0.15, 3, 6, fur), Vector3(0.0, 1.38, -0.02)))
	parts.append(_part(MeshKit.box(Vector3(0.12, 0.09, 0.1), dark), Vector3(0.0, 1.34, -0.16)))
	parts.append(_part(MeshKit.box(Vector3(0.1, 0.45, 0.1), fur), Vector3(-0.24, 0.9, 0.0), Vector3(0, 0, 8)))
	parts.append(_part(MeshKit.box(Vector3(0.1, 0.45, 0.1), fur), Vector3(0.24, 0.9, 0.0), Vector3(0, 0, -8)))
	parts.append(_part(MeshKit.box(Vector3(0.13, 0.7, 0.14), dark), Vector3(-0.11, 0.35, 0.0)))
	parts.append(_part(MeshKit.box(Vector3(0.13, 0.7, 0.14), dark), Vector3(0.11, 0.35, 0.0)))
	parts.append(_part(MeshKit.box(Vector3(0.06, 0.06, 0.55), fur), Vector3(0.0, 0.8, 0.35), Vector3(-25, 0, 0)))
	return MeshKit.merge(parts)


static func _build_stone(_inscribed: bool) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	parts.append(_part(MeshKit.box(Vector3(0.5, 0.3, 0.4), Palette.STONE), Vector3.ZERO))
	return MeshKit.merge(parts)


static func _build_timber() -> ArrayMesh:
	return MeshKit.merge([_part(MeshKit.cylinder(0.07, 0.07, 1.1, 6, Palette.BARK), Vector3.ZERO, Vector3(0, 0, 90))])
