class_name MeshKit
extends RefCounted
## Procedural flat-shaded primitives (DESIGN §9, M05). Every triangle gets its own three vertices and one
## face normal, so shading is flat. Colours are stored as vertex colours and read by flat_material().
## All solids are centred on the origin, which lets triangle winding and normals be made outward-facing.


const _TOON_SHADER: String = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Rim disabled: the fresnel term washed every face out under the orthographic iso camera (see the 2026-11-26 art
// review). Rim lighting comes from a back DirectionalLight in each level's light rig instead.
const float WARM_RIM_STRENGTH = 0.25;
const vec3 WARM_RIM = vec3(1.0, 0.82, 0.55);
const float AMBIENT = 0.30;

varying vec3 v_color;

void vertex() {
	v_color = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 1.0;
	// Orthographic cameras (the iso camera) have a constant view direction; VIEW is unreliable there.
	vec3 view_dir = PROJECTION_MATRIX[3][3] != 0.0 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), view_dir), 0.0, 1.0), 4.0);
	EMISSION = v_color * AMBIENT * 0.35 + WARM_RIM * fres * WARM_RIM_STRENGTH;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = 0.28 * step(0.05, ndl) + 0.25 * step(0.40, ndl) + 0.27 * step(0.70, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp;
}
"""

static var _flat_material: ShaderMaterial = null
static var _warned_degenerate: bool = false


static func flat_material() -> ShaderMaterial:
	if _flat_material == null:
		var shader: Shader = Shader.new()
		shader.code = _TOON_SHADER
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		_flat_material = material
	return _flat_material


static func box(size: Vector3, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var origin: Vector3 = Vector3.ZERO
	# +X
	_quad(st, Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz), color, origin)
	# -X
	_quad(st, Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz), color, origin)
	# +Y
	_quad(st, Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), color, origin)
	# -Y
	_quad(st, Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), color, origin)
	# +Z
	_quad(st, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), color, origin)
	# -Z
	_quad(st, Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), color, origin)
	return st.commit()


## Truncated cone along Y, centred on the origin. A zero radius turns the top or bottom into an apex.
static func cylinder(r_top: float, r_bottom: float, h: float, sides: int, color: Color) -> ArrayMesh:
	var n_sides: int = _clamp_sides(sides)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = h * 0.5
	var origin: Vector3 = Vector3.ZERO
	var top_centre: Vector3 = Vector3(0.0, half, 0.0)
	var bottom_centre: Vector3 = Vector3(0.0, -half, 0.0)
	for i: int in range(n_sides):
		var a0: float = TAU * float(i) / float(n_sides)
		var a1: float = TAU * float(i + 1) / float(n_sides)
		var t0: Vector3 = Vector3(sin(a0) * r_top, half, cos(a0) * r_top)
		var t1: Vector3 = Vector3(sin(a1) * r_top, half, cos(a1) * r_top)
		var b0: Vector3 = Vector3(sin(a0) * r_bottom, -half, cos(a0) * r_bottom)
		var b1: Vector3 = Vector3(sin(a1) * r_bottom, -half, cos(a1) * r_bottom)
		if r_top > 0.0 and r_bottom > 0.0:
			_quad(st, b0, b1, t1, t0, color, origin)
		elif r_top > 0.0:
			_tri(st, bottom_centre, t0, t1, color, origin)
		elif r_bottom > 0.0:
			_tri(st, top_centre, b0, b1, color, origin)
		if r_top > 0.0:
			_tri(st, top_centre, t0, t1, color, origin)
		if r_bottom > 0.0:
			_tri(st, bottom_centre, b0, b1, color, origin)
	return st.commit()


static func cone(r: float, h: float, sides: int, color: Color) -> ArrayMesh:
	return cylinder(0.0, r, h, sides, color)


## UV sphere with `rings` latitude bands (rings >= 2) and `segments` longitude slices (segments >= 3).
static func sphere(r: float, rings: int, segments: int, color: Color) -> ArrayMesh:
	var n_rings: int = _clamp_rings(rings)
	var n_segments: int = _clamp_sides(segments)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin: Vector3 = Vector3.ZERO
	for i: int in range(n_rings):
		for k: int in range(n_segments):
			var a: Vector3 = _sphere_point(r, n_rings, n_segments, i, k)
			var b: Vector3 = _sphere_point(r, n_rings, n_segments, i, k + 1)
			var c: Vector3 = _sphere_point(r, n_rings, n_segments, i + 1, k + 1)
			var d: Vector3 = _sphere_point(r, n_rings, n_segments, i + 1, k)
			if i == 0:
				_tri(st, a, c, d, color, origin)
			elif i == n_rings - 1:
				_tri(st, a, b, c, color, origin)
			else:
				_quad(st, a, b, c, d, color, origin)
	return st.commit()


## Cylinder body with a hemisphere at each end (6 rings, 12 segments per hemisphere); `h` is the total
## height including the caps.
static func capsule(r: float, h: float, color: Color) -> ArrayMesh:
	var body_h: float = maxf(0.0, h - 2.0 * r)
	var end_offset: float = body_h * 0.5
	var parts: Array[Dictionary] = [
		{"mesh": cylinder(r, r, body_h, 12, color), "transform": Transform3D(Basis(), Vector3.ZERO)},
		{"mesh": _hemisphere(r, 6, 12, color, 1.0), "transform": Transform3D(Basis(), Vector3(0.0, end_offset, 0.0))},
		{"mesh": _hemisphere(r, 6, 12, color, -1.0), "transform": Transform3D(Basis(), Vector3(0.0, -end_offset, 0.0))},
	]
	return merge(parts)


## Combines meshes into one flat-shaded ArrayMesh. Each part is {"mesh": ArrayMesh, "transform": Transform3D}.
## Vertices get the part transform. Normals get the inverse-transpose of its basis, so they stay perpendicular
## to their faces under non-uniform scale. When the basis is mirrored (negative determinant) each triangle's
## winding is reversed so the faces still point outward.
static func merge(parts: Array[Dictionary]) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for part: Dictionary in parts:
		var mesh: ArrayMesh = part["mesh"] as ArrayMesh
		var xf: Transform3D = part["transform"] as Transform3D
		if mesh == null:
			continue
		var basis: Basis = xf.basis
		var normal_basis: Basis = basis.inverse().transposed()
		var mirrored: bool = basis.determinant() < 0.0
		for s: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			var order: Array[int] = [0, 1, 2]
			if mirrored:
				order = [0, 2, 1]
			var tri_start: int = 0
			while tri_start + 2 < verts.size():
				for j: int in range(3):
					var vi: int = tri_start + order[j]
					var n: Vector3 = norms[vi] if norms.size() > vi else Vector3.UP
					var c: Color = cols[vi] if cols.size() > vi else Color.WHITE
					st.set_normal((normal_basis * n).normalized())
					st.set_color(c)
					st.add_vertex(xf * verts[vi])
					count += 1
				tri_start += 3
	if count == 0:
		return ArrayMesh.new()
	return st.commit()


## Clamps a sides/segments argument to the minimum of 3, warning once.
static func _clamp_sides(value: int) -> int:
	if value >= 3:
		return value
	_warn_degenerate("sides/segments below 3 clamped to 3")
	return 3


## Clamps a rings argument to the minimum of 2, warning once.
static func _clamp_rings(value: int) -> int:
	if value >= 2:
		return value
	_warn_degenerate("rings below 2 clamped to 2")
	return 2


static func _warn_degenerate(message: String) -> void:
	if _warned_degenerate:
		return
	_warned_degenerate = true
	push_warning("MeshKit: " + message)


## Upper (sign = 1) or lower (sign = -1) half of a UV sphere, open at the equator.
static func _hemisphere(r: float, rings: int, segments: int, color: Color, sign: float) -> ArrayMesh:
	var n_rings: int = _clamp_rings(rings)
	var n_segments: int = _clamp_sides(segments)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin: Vector3 = Vector3.ZERO
	for i: int in range(n_rings):
		for k: int in range(n_segments):
			var a: Vector3 = _hemisphere_point(r, n_rings, n_segments, i, k, sign)
			var b: Vector3 = _hemisphere_point(r, n_rings, n_segments, i, k + 1, sign)
			var c: Vector3 = _hemisphere_point(r, n_rings, n_segments, i + 1, k + 1, sign)
			var d: Vector3 = _hemisphere_point(r, n_rings, n_segments, i + 1, k, sign)
			if i == 0:
				_tri(st, a, c, d, color, origin)
			else:
				_quad(st, a, b, c, d, color, origin)
	return st.commit()


static func _hemisphere_point(r: float, rings: int, segments: int, row: int, col: int, sign: float) -> Vector3:
	var phi: float = (PI * 0.5) * float(row) / float(rings)
	var theta: float = TAU * float(col) / float(segments)
	var rad: float = r * sin(phi)
	return Vector3(rad * sin(theta), sign * r * cos(phi), rad * cos(theta))


static func _sphere_point(r: float, rings: int, segments: int, row: int, col: int) -> Vector3:
	var phi: float = PI * float(row) / float(rings)
	var theta: float = TAU * float(col) / float(segments)
	var rad: float = r * sin(phi)
	return Vector3(rad * sin(theta), r * cos(phi), rad * cos(theta))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, interior: Vector3) -> void:
	_tri(st, a, b, c, color, interior)
	_tri(st, a, c, d, color, interior)


## Adds one flat triangle whose normal points away from `interior`, wound clockwise (Godot's front face).
## Degenerate triangles are dropped.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, interior: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var centroid: Vector3 = (a + b + c) / 3.0
	var p1: Vector3 = b
	var p2: Vector3 = c
	if n.dot(centroid - interior) < 0.0:
		p1 = c
		p2 = b
		n = -n
	var normal: Vector3 = n.normalized()
	# Godot treats CLOCKWISE triangles (seen from the front) as front faces, so emit a, p2, p1: seen from outside
	# this is clockwise while the stored normal still points outward. (Found 2026-11-26: the old a, p1, p2 order
	# rendered every MeshKit solid inside-out under back-face culling.)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(p2)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(p1)
