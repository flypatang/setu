class_name MeshKit
extends RefCounted
## Procedural primitives (DESIGN §9, M05; extended by F2 for docs/ART.md "Materials").
## By default every triangle gets its own three vertices and one face normal, so shading is flat. Pass
## `smooth = true` (or use the *_smooth functions) for analytic per-vertex normals on organic shapes. Meshes are
## never indexed, so merge() and multi() can combine flat and smooth parts freely.
## Colours are stored as vertex colours. Colour ALPHA is the wind weight read by Materials (0 = rigid,
## 1 = free) and is preserved by merge(), multi(), with_wind() and wind_weighted().
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
static func cylinder(r_top: float, r_bottom: float, h: float, sides: int, color: Color, smooth: bool = false) -> ArrayMesh:
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
		if smooth:
			# Side normals follow the slope of the (truncated) cone; an apex takes the normal of its slice's middle.
			var n0: Vector3 = _slope_normal(a0, r_top, r_bottom, h)
			var n1: Vector3 = _slope_normal(a1, r_top, r_bottom, h)
			var n_mid: Vector3 = _slope_normal((a0 + a1) * 0.5, r_top, r_bottom, h)
			if r_top > 0.0 and r_bottom > 0.0:
				_tri_n(st, b0, b1, t1, n0, n1, n1, color, origin)
				_tri_n(st, b0, t1, t0, n0, n1, n0, color, origin)
			elif r_top > 0.0:
				_tri_n(st, bottom_centre, t0, t1, n_mid, n0, n1, color, origin)
			elif r_bottom > 0.0:
				_tri_n(st, top_centre, b0, b1, n_mid, n0, n1, color, origin)
		elif r_top > 0.0 and r_bottom > 0.0:
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


static func cone(r: float, h: float, sides: int, color: Color, smooth: bool = false) -> ArrayMesh:
	return cylinder(0.0, r, h, sides, color, smooth)


## UV sphere with `rings` latitude bands (rings >= 2) and `segments` longitude slices (segments >= 3).
static func sphere(r: float, rings: int, segments: int, color: Color, smooth: bool = false) -> ArrayMesh:
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
				_radial_tri(st, a, c, d, color, origin, smooth)
			elif i == n_rings - 1:
				_radial_tri(st, a, b, c, color, origin, smooth)
			else:
				_radial_tri(st, a, b, c, color, origin, smooth)
				_radial_tri(st, a, c, d, color, origin, smooth)
	return st.commit()


## Cylinder body with a hemisphere at each end (6 rings, 12 segments per hemisphere); `h` is the total
## height including the caps. With `smooth` the capsule gets radial normals and a rounder 8 x 16 tessellation,
## and the hidden inner end caps of the body are left out.
static func capsule(r: float, h: float, color: Color, smooth: bool = false) -> ArrayMesh:
	var body_h: float = maxf(0.0, h - 2.0 * r)
	var end_offset: float = body_h * 0.5
	if smooth:
		return _smooth_capsule(r, body_h, color)
	var parts: Array[Dictionary] = [
		{"mesh": cylinder(r, r, body_h, 12, color), "transform": Transform3D(Basis(), Vector3.ZERO)},
		{"mesh": _hemisphere(r, 6, 12, color, 1.0), "transform": Transform3D(Basis(), Vector3(0.0, end_offset, 0.0))},
		{"mesh": _hemisphere(r, 6, 12, color, -1.0), "transform": Transform3D(Basis(), Vector3(0.0, -end_offset, 0.0))},
	]
	return merge(parts)


static func sphere_smooth(r: float, rings: int, segments: int, color: Color) -> ArrayMesh:
	return sphere(r, rings, segments, color, true)


static func cylinder_smooth(r_top: float, r_bottom: float, h: float, sides: int, color: Color) -> ArrayMesh:
	return cylinder(r_top, r_bottom, h, sides, color, true)


static func cone_smooth(r: float, h: float, sides: int, color: Color) -> ArrayMesh:
	return cylinder(0.0, r, h, sides, color, true)


static func capsule_smooth(r: float, h: float, color: Color) -> ArrayMesh:
	return capsule(r, h, color, true)


## Box with every edge and corner chamfered by `bevel` (clamped to just under half the smallest side; 0 gives a
## plain box). Each vertex keeps the normal of the face it lies on, so the six faces stay flat while the edge
## strips and corner triangles shade as rounded edges that catch the stone edge highlight of Materials.
static func bevel_box(size: Vector3, bevel: float, color: Color) -> ArrayMesh:
	var b: float = clampf(bevel, 0.0, minf(size.x, minf(size.y, size.z)) * 0.49)
	if b <= 0.0:
		return box(size, color)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3 = size * 0.5
	var origin: Vector3 = Vector3.ZERO
	var signs: Array[float] = [-1.0, 1.0]
	# Six inset faces.
	for axis: int in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for s: float in signs:
			var n: Vector3 = _axis_vector(axis, s)
			var p00: Vector3 = _bevel_point(half, b, axis, s, u, -1.0, v, -1.0)
			var p10: Vector3 = _bevel_point(half, b, axis, s, u, 1.0, v, -1.0)
			var p11: Vector3 = _bevel_point(half, b, axis, s, u, 1.0, v, 1.0)
			var p01: Vector3 = _bevel_point(half, b, axis, s, u, -1.0, v, 1.0)
			_tri_n(st, p00, p10, p11, n, n, n, color, origin)
			_tri_n(st, p00, p11, p01, n, n, n, color, origin)
	# Twelve edge strips: the edge between the faces of axes `a` and `c` runs along axis `along`.
	for along: int in range(3):
		var a: int = (along + 1) % 3
		var c: int = (along + 2) % 3
		for sa: float in signs:
			for sc: float in signs:
				var na: Vector3 = _axis_vector(a, sa)
				var nc: Vector3 = _axis_vector(c, sc)
				var a0: Vector3 = _bevel_point(half, b, a, sa, c, sc, along, -1.0)
				var a1: Vector3 = _bevel_point(half, b, a, sa, c, sc, along, 1.0)
				var c0: Vector3 = _bevel_point(half, b, c, sc, a, sa, along, -1.0)
				var c1: Vector3 = _bevel_point(half, b, c, sc, a, sa, along, 1.0)
				_tri_n(st, a0, a1, c1, na, na, nc, color, origin)
				_tri_n(st, a0, c1, c0, na, nc, nc, color, origin)
	# Eight corner triangles.
	for sx: float in signs:
		for sy: float in signs:
			for sz: float in signs:
				var px: Vector3 = _bevel_point(half, b, 0, sx, 1, sy, 2, sz)
				var py: Vector3 = _bevel_point(half, b, 1, sy, 0, sx, 2, sz)
				var pz: Vector3 = _bevel_point(half, b, 2, sz, 0, sx, 1, sy)
				_tri_n(st, px, py, pz, _axis_vector(0, sx), _axis_vector(1, sy), _axis_vector(2, sz), color, origin)
	return st.commit()


## Builds one ArrayMesh with ONE SURFACE PER MATERIAL KIND (docs/ART.md "Materials"). Keys are Materials kinds
## (StringName or String, e.g. &"stone", &"gold", &"cloth_world"); each value is an ArrayMesh, or an Array of
## ArrayMesh and/or merge() parts ({"mesh": ArrayMesh, "transform": Transform3D}). Every surface gets
## Materials.get_material(kind) through surface_set_material and is named after its kind. Surfaces follow the
## dictionary's order; kinds without geometry are skipped. Vertex colour alpha (wind weight) is preserved.
static func multi(parts_by_kind: Dictionary) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	for key: Variant in parts_by_kind:
		var kind: StringName = StringName(str(key))
		var merged: ArrayMesh = merge(_as_parts(parts_by_kind[key]))
		if merged.get_surface_count() == 0:
			continue
		var index: int = result.get_surface_count()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged.surface_get_arrays(0))
		result.surface_set_name(index, String(kind))
		result.surface_set_material(index, Materials.get_material(kind))
	return result


## Copy of `mesh` with every vertex colour alpha (wind weight) set to `weight` (0 = rigid, 1 = free).
static func with_wind(mesh: ArrayMesh, weight: float) -> ArrayMesh:
	return _remap_alpha(mesh, 0.0, 0.0, clampf(weight, 0.0, 1.0), true)


## Copy of `mesh` whose wind weight ramps linearly with height: 0 at y = `rigid_y`, 1 at y = `free_y`, clamped
## outside. `free_y` may be below `rigid_y` (a banner pinned along its top) or above it (grass rooted at its base).
static func wind_weighted(mesh: ArrayMesh, rigid_y: float, free_y: float) -> ArrayMesh:
	return _remap_alpha(mesh, rigid_y, free_y, 0.0, false)


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


static func _smooth_capsule(r: float, body_h: float, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 8
	var segments: int = 16
	var half: float = body_h * 0.5
	for sign: float in [1.0, -1.0]:
		var centre: Vector3 = Vector3(0.0, sign * half, 0.0)
		for i: int in range(rings):
			for k: int in range(segments):
				var a: Vector3 = _hemisphere_point(r, rings, segments, i, k, sign)
				var b: Vector3 = _hemisphere_point(r, rings, segments, i, k + 1, sign)
				var c: Vector3 = _hemisphere_point(r, rings, segments, i + 1, k + 1, sign)
				var d: Vector3 = _hemisphere_point(r, rings, segments, i + 1, k, sign)
				_tri_n(st, a + centre, c + centre, d + centre, a.normalized(), c.normalized(), d.normalized(), color, centre)
				if i > 0:
					_tri_n(st, a + centre, b + centre, c + centre, a.normalized(), b.normalized(), c.normalized(), color, centre)
	if body_h > 0.0:
		for k: int in range(segments):
			var a0: float = TAU * float(k) / float(segments)
			var a1: float = TAU * float(k + 1) / float(segments)
			var n0: Vector3 = Vector3(sin(a0), 0.0, cos(a0))
			var n1: Vector3 = Vector3(sin(a1), 0.0, cos(a1))
			var up: Vector3 = Vector3(0.0, half, 0.0)
			_tri_n(st, n0 * r - up, n1 * r - up, n1 * r + up, n0, n1, n1, color, Vector3.ZERO)
			_tri_n(st, n0 * r - up, n1 * r + up, n0 * r + up, n0, n1, n0, color, Vector3.ZERO)
	return st.commit()


## Outward normal of a (truncated) cone's side at angle `a`.
static func _slope_normal(a: float, r_top: float, r_bottom: float, h: float) -> Vector3:
	var n: Vector3 = Vector3(sin(a) * h, r_bottom - r_top, cos(a) * h)
	if n.length_squared() < 1e-12:
		return Vector3(sin(a), 0.0, cos(a))
	return n.normalized()


static func _axis_vector(axis: int, value: float) -> Vector3:
	var v: Vector3 = Vector3.ZERO
	v[axis] = value
	return v


## Point of a bevelled box on the face of `face_axis` (side `face_sign`), next to the corner on sides `sign_u` and
## `sign_v` of the two other axes: on the face plane, inset by the bevel along both other axes.
static func _bevel_point(half: Vector3, bevel: float, face_axis: int, face_sign: float, axis_u: int, sign_u: float, axis_v: int, sign_v: float) -> Vector3:
	var p: Vector3 = Vector3.ZERO
	p[face_axis] = face_sign * half[face_axis]
	p[axis_u] = sign_u * (half[axis_u] - bevel)
	p[axis_v] = sign_v * (half[axis_v] - bevel)
	return p


## Normalises a multi() value into merge() parts.
static func _as_parts(value: Variant) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if value is ArrayMesh:
		parts.append({"mesh": value as ArrayMesh, "transform": Transform3D()})
	elif value is Array:
		for item: Variant in value as Array:
			if item is ArrayMesh:
				parts.append({"mesh": item as ArrayMesh, "transform": Transform3D()})
			elif item is Dictionary:
				var part: Dictionary = item as Dictionary
				if not part.has("transform"):
					part = {"mesh": part.get("mesh"), "transform": Transform3D()}
				parts.append(part)
	return parts


## Rebuilds every surface with a new vertex colour alpha, keeping names and materials.
static func _remap_alpha(mesh: ArrayMesh, rigid_y: float, free_y: float, constant: float, use_constant: bool) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	if mesh == null:
		return result
	var span: float = free_y - rigid_y
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var source: Variant = arrays[Mesh.ARRAY_COLOR]
		var cols: PackedColorArray = PackedColorArray()
		if source is PackedColorArray:
			cols = (source as PackedColorArray).duplicate()
		if cols.size() != verts.size():
			cols.resize(verts.size())
			cols.fill(Color.WHITE)
		for i: int in range(verts.size()):
			var weight: float = constant
			if not use_constant:
				if absf(span) < 1e-6:
					weight = 1.0 if verts[i].y >= rigid_y else 0.0
				else:
					weight = clampf((verts[i].y - rigid_y) / span, 0.0, 1.0)
			var c: Color = cols[i]
			c.a = weight
			cols[i] = c
		arrays[Mesh.ARRAY_COLOR] = cols
		result.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		result.surface_set_name(s, mesh.surface_get_name(s))
		result.surface_set_material(s, mesh.surface_get_material(s))
	return result


## Sphere triangle: flat, or with radial normals when `smooth`.
static func _radial_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, interior: Vector3, smooth: bool) -> void:
	if smooth:
		_tri_n(st, a, b, c, (a - interior).normalized(), (b - interior).normalized(), (c - interior).normalized(), color, interior)
	else:
		_tri(st, a, b, c, color, interior)


## Like _tri(), but with one given normal per vertex (smooth shading). The geometric normal still decides the
## winding, so the triangle faces away from `interior`.
static func _tri_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color, interior: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var centroid: Vector3 = (a + b + c) / 3.0
	var p1: Vector3 = b
	var p2: Vector3 = c
	var n1: Vector3 = nb
	var n2: Vector3 = nc
	if n.dot(centroid - interior) < 0.0:
		p1 = c
		p2 = b
		n1 = nc
		n2 = nb
	st.set_normal(na)
	st.set_color(color)
	st.add_vertex(a)
	st.set_normal(n2)
	st.set_color(color)
	st.add_vertex(p2)
	st.set_normal(n1)
	st.set_color(color)
	st.add_vertex(p1)


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
