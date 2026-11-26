extends GdUnitTestSuite
## Acceptance tests for F2 additions to gen/mesh_kit.gd: smooth normals, bevel_box, multi and wind weights.


const RED: Color = Color(1.0, 0.0, 0.0)
const HALF: Color = Color(0.2, 0.4, 0.6, 0.5)


func _verts(mesh: ArrayMesh, surface: int = 0) -> PackedVector3Array:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _normals(mesh: ArrayMesh, surface: int = 0) -> PackedVector3Array:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL] as PackedVector3Array


func _colors(mesh: ArrayMesh, surface: int = 0) -> PackedColorArray:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR] as PackedColorArray


## Stored normals are compressed, so compare directions with a small tolerance.
func _same_dir(a: Vector3, b: Vector3) -> bool:
	return a.dot(b) > 0.9995 and absf(a.length() - 1.0) < 0.002


func _is_flat(mesh: ArrayMesh) -> bool:
	var normals: PackedVector3Array = _normals(mesh)
	var i: int = 0
	while i < normals.size():
		if not (_same_dir(normals[i], normals[i + 1]) and _same_dir(normals[i], normals[i + 2])):
			return false
		i += 3
	return true


## True when every triangle is wound clockwise seen from outside (Godot front face) for a solid around the origin.
func _wound_outward(mesh: ArrayMesh) -> bool:
	var verts: PackedVector3Array = _verts(mesh)
	var i: int = 0
	while i < verts.size():
		var geometric: Vector3 = (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i])
		var centroid: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		if geometric.dot(centroid) <= 0.0:
			return false
		i += 3
	return true


func test_default_primitives_stay_flat() -> void:
	assert_bool(_is_flat(MeshKit.sphere(1.0, 6, 8, RED))).is_true()
	assert_bool(_is_flat(MeshKit.cylinder(1.0, 1.0, 2.0, 8, RED))).is_true()
	assert_bool(_is_flat(MeshKit.cone(1.0, 2.0, 8, RED))).is_true()
	assert_bool(_is_flat(MeshKit.capsule(0.5, 2.0, RED))).is_true()


func test_smooth_sphere_has_radial_normals() -> void:
	var flat: ArrayMesh = MeshKit.sphere(2.0, 8, 12, RED)
	var smooth: ArrayMesh = MeshKit.sphere(2.0, 8, 12, RED, true)
	assert_int(_verts(smooth).size()).is_equal(_verts(flat).size())
	var verts: PackedVector3Array = _verts(smooth)
	var normals: PackedVector3Array = _normals(smooth)
	assert_int(normals.size()).is_equal(verts.size())
	for i: int in range(verts.size()):
		assert_bool(_same_dir(normals[i], verts[i].normalized())).is_true()
	assert_bool(_is_flat(smooth)).is_false()
	assert_bool(_wound_outward(smooth)).is_true()


func test_smooth_cylinder_sides_are_radial_and_caps_flat() -> void:
	var mesh: ArrayMesh = MeshKit.cylinder(1.0, 1.0, 2.0, 12, RED, true)
	assert_int(_verts(mesh).size()).is_equal(12 * 12)
	var verts: PackedVector3Array = _verts(mesh)
	var normals: PackedVector3Array = _normals(mesh)
	var side_count: int = 0
	var cap_count: int = 0
	for i: int in range(verts.size()):
		assert_float(normals[i].length()).is_equal_approx(1.0, 0.001)
		if absf(normals[i].y) > 0.99:
			cap_count += 1
		else:
			side_count += 1
			var radial: Vector3 = Vector3(verts[i].x, 0.0, verts[i].z).normalized()
			assert_bool(_same_dir(normals[i], radial)).is_true()
	assert_int(side_count).is_equal(12 * 6)
	assert_int(cap_count).is_equal(12 * 6)
	assert_bool(_wound_outward(mesh)).is_true()


func test_smooth_cone_normals_tilt_with_the_slope() -> void:
	var mesh: ArrayMesh = MeshKit.cone(1.0, 1.0, 12, RED, true)
	var normals: PackedVector3Array = _normals(mesh)
	var tilted: int = 0
	for n: Vector3 in normals:
		assert_float(n.length()).is_equal_approx(1.0, 0.001)
		if n.y > 0.1:
			# A cone of radius 1 and height 1 has side normals at 45 degrees.
			assert_float(n.y).is_equal_approx(sqrt(0.5), 0.01)
			tilted += 1
	assert_int(tilted).is_equal(12 * 3)
	assert_bool(_wound_outward(mesh)).is_true()


func test_smooth_capsule_is_round_and_keeps_its_height() -> void:
	var mesh: ArrayMesh = MeshKit.capsule(0.5, 2.0, RED, true)
	assert_bool(_is_flat(mesh)).is_false()
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.x).is_equal_approx(1.0, 0.02)
	var verts: PackedVector3Array = _verts(mesh)
	var normals: PackedVector3Array = _normals(mesh)
	for i: int in range(verts.size()):
		# Every normal points away from the capsule's axis segment.
		var axis_point: Vector3 = Vector3(0.0, clampf(verts[i].y, -0.5, 0.5), 0.0)
		assert_bool(_same_dir(normals[i], (verts[i] - axis_point).normalized())).is_true()


func test_smooth_convenience_functions() -> void:
	assert_bool(_is_flat(MeshKit.sphere_smooth(1.0, 8, 12, RED))).is_false()
	assert_bool(_is_flat(MeshKit.cylinder_smooth(1.0, 0.5, 2.0, 12, RED))).is_false()
	assert_bool(_is_flat(MeshKit.capsule_smooth(0.5, 2.0, RED))).is_false()


func test_bevel_box_bounds_and_counts() -> void:
	var mesh: ArrayMesh = MeshKit.bevel_box(Vector3(2.0, 3.0, 4.0), 0.2, RED)
	assert_int(mesh.get_surface_count()).is_equal(1)
	# 6 faces and 12 edge strips (2 triangles each) plus 8 corner triangles.
	assert_int(_verts(mesh).size()).is_equal((6 * 2 + 12 * 2 + 8) * 3)
	var aabb: AABB = mesh.get_aabb()
	assert_bool(aabb.position.is_equal_approx(Vector3(-1.0, -1.5, -2.0))).is_true()
	assert_bool(aabb.size.is_equal_approx(Vector3(2.0, 3.0, 4.0))).is_true()
	for c: Color in _colors(mesh):
		assert_bool(c.is_equal_approx(RED)).is_true()


func test_bevel_box_normals_are_axis_aligned_and_outward() -> void:
	var mesh: ArrayMesh = MeshKit.bevel_box(Vector3(2.0, 2.0, 2.0), 0.25, RED)
	var verts: PackedVector3Array = _verts(mesh)
	var normals: PackedVector3Array = _normals(mesh)
	for i: int in range(verts.size()):
		assert_float(normals[i].length()).is_equal_approx(1.0, 0.001)
		# Each vertex takes the normal of the face it lies on, so the bevel strips shade as rounded edges.
		var axis: int = normals[i].abs().max_axis_index()
		assert_float(absf(normals[i][axis])).is_equal_approx(1.0, 0.001)
		assert_float(verts[i][axis] * normals[i][axis]).is_equal_approx(1.0, 0.001)
	assert_bool(_wound_outward(mesh)).is_true()
	assert_bool(_is_flat(mesh)).is_false()


func test_bevel_box_cuts_the_corners() -> void:
	var mesh: ArrayMesh = MeshKit.bevel_box(Vector3(2.0, 2.0, 2.0), 0.25, RED)
	for v: Vector3 in _verts(mesh):
		var on_faces: int = 0
		for axis: int in range(3):
			if absf(absf(v[axis]) - 1.0) < 0.001:
				on_faces += 1
		assert_int(on_faces).is_equal(1)


func test_bevel_box_clamps_bevel() -> void:
	var zero: ArrayMesh = MeshKit.bevel_box(Vector3(1.0, 1.0, 1.0), 0.0, RED)
	assert_int(_verts(zero).size()).is_equal(36)
	var huge: ArrayMesh = MeshKit.bevel_box(Vector3(1.0, 2.0, 3.0), 50.0, RED)
	assert_bool(huge.get_aabb().size.is_equal_approx(Vector3(1.0, 2.0, 3.0))).is_true()
	assert_bool(_verts(huge).size() > 36).is_true()


func test_merge_preserves_alpha_and_smooth_normals() -> void:
	var parts: Array[Dictionary] = [
		{"mesh": MeshKit.sphere(1.0, 6, 8, HALF, true), "transform": Transform3D(Basis(), Vector3(3.0, 0.0, 0.0))},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	for c: Color in _colors(merged):
		assert_float(c.a).is_equal_approx(0.5, 0.01)
	var verts: PackedVector3Array = _verts(merged)
	var normals: PackedVector3Array = _normals(merged)
	for i: int in range(verts.size()):
		assert_bool(_same_dir(normals[i], (verts[i] - Vector3(3.0, 0.0, 0.0)).normalized())).is_true()


func test_multi_builds_one_surface_per_kind() -> void:
	var stone_parts: Array[Dictionary] = [
		{"mesh": MeshKit.bevel_box(Vector3.ONE, 0.05, RED), "transform": Transform3D()},
		{"mesh": MeshKit.box(Vector3.ONE, RED), "transform": Transform3D(Basis(), Vector3(2.0, 0.0, 0.0))},
	]
	var mesh: ArrayMesh = MeshKit.multi({
		&"stone": stone_parts,
		&"gold": MeshKit.sphere(0.5, 6, 8, RED, true),
		&"cloth": [MeshKit.box(Vector3.ONE, HALF)],
	})
	assert_int(mesh.get_surface_count()).is_equal(3)
	assert_bool(mesh.surface_get_material(0) == Materials.get_material(&"stone")).is_true()
	assert_bool(mesh.surface_get_material(1) == Materials.get_material(&"gold")).is_true()
	assert_bool(mesh.surface_get_material(2) == Materials.get_material(&"cloth")).is_true()
	assert_str(mesh.surface_get_name(0)).is_equal("stone")
	assert_str(mesh.surface_get_name(1)).is_equal("gold")
	assert_str(mesh.surface_get_name(2)).is_equal("cloth")
	assert_int(_verts(mesh, 0).size()).is_equal(132 + 36)
	assert_int(_verts(mesh, 1).size()).is_equal(_verts(MeshKit.sphere(0.5, 6, 8, RED)).size())
	assert_int(_verts(mesh, 2).size()).is_equal(36)


func test_multi_preserves_vertex_alpha_for_wind() -> void:
	var mesh: ArrayMesh = MeshKit.multi({&"foliage": MeshKit.box(Vector3.ONE, HALF)})
	var colors: PackedColorArray = _colors(mesh)
	assert_int(colors.size()).is_equal(36)
	for c: Color in colors:
		assert_float(c.a).is_equal_approx(0.5, 0.01)
		assert_float(c.g).is_equal_approx(0.4, 0.01)


func test_multi_skips_empty_kinds_and_accepts_string_keys() -> void:
	var empty_parts: Array[Dictionary] = []
	var mesh: ArrayMesh = MeshKit.multi({
		&"stone": empty_parts,
		"wood": MeshKit.box(Vector3.ONE, RED),
		&"fur_world": MeshKit.box(Vector3.ONE, RED),
	})
	assert_int(mesh.get_surface_count()).is_equal(2)
	assert_bool(mesh.surface_get_material(0) == Materials.get_material(&"wood")).is_true()
	assert_bool(mesh.surface_get_material(1) == Materials.get_material(&"fur_world")).is_true()
	assert_int(MeshKit.multi({}).get_surface_count()).is_equal(0)


func test_wind_weighted_ramps_alpha_by_height() -> void:
	var source: ArrayMesh = MeshKit.multi({&"cloth": MeshKit.box(Vector3(1.0, 2.0, 1.0), RED)})
	var mesh: ArrayMesh = MeshKit.wind_weighted(source, 1.0, -1.0)
	assert_int(mesh.get_surface_count()).is_equal(1)
	assert_bool(mesh.surface_get_material(0) == Materials.get_material(&"cloth")).is_true()
	var verts: PackedVector3Array = _verts(mesh)
	var colors: PackedColorArray = _colors(mesh)
	assert_int(colors.size()).is_equal(verts.size())
	for i: int in range(verts.size()):
		# Pinned along the top edge (y = 1), free at the hem (y = -1).
		var expected: float = 0.0 if verts[i].y > 0.0 else 1.0
		assert_float(colors[i].a).is_equal_approx(expected, 0.01)
		assert_float(colors[i].r).is_equal_approx(1.0, 0.01)
	# The source mesh is not modified.
	for c: Color in _colors(source):
		assert_float(c.a).is_equal_approx(1.0, 0.01)


func test_with_wind_sets_a_constant_weight() -> void:
	var mesh: ArrayMesh = MeshKit.with_wind(MeshKit.sphere(1.0, 4, 6, RED, true), 0.25)
	for c: Color in _colors(mesh):
		assert_float(c.a).is_equal_approx(0.25, 0.01)
	assert_bool(_is_flat(mesh)).is_false()
