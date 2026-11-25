extends GdUnitTestSuite
## Acceptance tests for the M05b fix to gen/mesh_kit.gd (DESIGN §9 M05b).
## Covers mirrored merges, degenerate-argument clamping and hemisphere-based capsules.
## Capsule triangle count: body cylinder (12 sides) = 12 * 12 vertices; each hemisphere with
## 6 rings and 12 segments = 3 * 12 * (2 * 6 - 1) = 396 vertices; total 144 + 2 * 396 = 936.


const RED: Color = Color(1.0, 0.0, 0.0)


func _verts(mesh: ArrayMesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _normals(mesh: ArrayMesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array


func _assert_outward(mesh: ArrayMesh) -> void:
	## Every face normal must point away from the mesh centre, and the winding must be Godot's front face:
	## clockwise seen from outside, i.e. the counter-clockwise cross product points AGAINST the stored normal.
	var verts: PackedVector3Array = _verts(mesh)
	var normals: PackedVector3Array = _normals(mesh)
	var centre: Vector3 = mesh.get_aabb().get_center()
	var i: int = 0
	while i < verts.size():
		var centroid: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		assert_bool(normals[i].dot(centroid - centre) > 0.0).is_true()
		var geometric: Vector3 = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		assert_bool(geometric.dot(normals[i]) < 0.0).is_true()
		i += 3


func test_mirrored_merge_keeps_outward_normals() -> void:
	var box: ArrayMesh = MeshKit.box(Vector3(1.0, 2.0, 3.0), RED)
	var parts: Array[Dictionary] = [
		{"mesh": box, "transform": Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	assert_int(_verts(merged).size()).is_equal(36)
	var aabb: AABB = merged.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(1.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.z).is_equal_approx(3.0, 0.001)
	_assert_outward(merged)


func test_mirrored_part_normals_stay_unit_length() -> void:
	var sphere: ArrayMesh = MeshKit.sphere(1.0, 6, 8, RED)
	var parts: Array[Dictionary] = [
		{"mesh": sphere, "transform": Transform3D(Basis.from_scale(Vector3(1.0, 1.0, -2.0)), Vector3.ZERO)},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	var normals: PackedVector3Array = _normals(merged)
	for n: Vector3 in normals:
		assert_float(n.length()).is_equal_approx(1.0, 0.001)
	_assert_outward(merged)


func test_unmirrored_merge_keeps_winding() -> void:
	var box: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), RED)
	var parts: Array[Dictionary] = [
		{"mesh": box, "transform": Transform3D(Basis(), Vector3.ZERO)},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	var verts: PackedVector3Array = _verts(merged)
	var original: PackedVector3Array = _verts(box)
	for i: int in range(verts.size()):
		assert_bool(verts[i].is_equal_approx(original[i])).is_true()


func test_degenerate_cylinder_sides_are_clamped_to_three() -> void:
	var mesh: ArrayMesh = MeshKit.cylinder(0.5, 0.5, 1.0, 1, RED)
	assert_int(_verts(mesh).size()).is_equal(12 * 3)


func test_degenerate_cone_sides_are_clamped_to_three() -> void:
	var mesh: ArrayMesh = MeshKit.cone(1.0, 1.0, 0, RED)
	assert_int(_verts(mesh).size()).is_equal(6 * 3)


func test_degenerate_sphere_segments_are_clamped_to_three() -> void:
	var mesh: ArrayMesh = MeshKit.sphere(1.0, 4, 2, RED)
	assert_int(_verts(mesh).size()).is_equal(6 * 3 * (4 - 1))


func test_degenerate_sphere_rings_are_clamped_to_two() -> void:
	var mesh: ArrayMesh = MeshKit.sphere(1.0, 1, 2, RED)
	assert_int(_verts(mesh).size()).is_equal(6 * 3 * (2 - 1))


func test_capsule_uses_hemispheres_triangle_count() -> void:
	var mesh: ArrayMesh = MeshKit.capsule(0.5, 2.0, RED)
	assert_int(_verts(mesh).size()).is_equal(936)


func test_capsule_normals_are_outward() -> void:
	var mesh: ArrayMesh = MeshKit.capsule(0.5, 2.0, RED)
	_assert_outward(mesh)
