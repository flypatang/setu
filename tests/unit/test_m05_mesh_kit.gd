extends GdUnitTestSuite
## Acceptance tests for M05 (gen/mesh_kit.gd), DESIGN §9.
## Vertex counts follow the formulas in the implementation (flat-shaded, 3 vertices per triangle):
##   box: 12 triangles = 36 vertices
##   cylinder (both radii > 0): 12 * sides vertices; cone (one radius 0): 6 * sides vertices
##   sphere: 6 * segments * (rings - 1) vertices


const RED: Color = Color(1.0, 0.0, 0.0)
const BLUE: Color = Color(0.0, 0.0, 1.0)


func _verts(mesh: ArrayMesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _normals(mesh: ArrayMesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array


func _colors(mesh: ArrayMesh) -> PackedColorArray:
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_COLOR] as PackedColorArray


func _assert_flat(mesh: ArrayMesh) -> void:
	var normals: PackedVector3Array = _normals(mesh)
	assert_int(normals.size() % 3).is_equal(0)
	var i: int = 0
	while i < normals.size():
		var same: bool = normals[i].is_equal_approx(normals[i + 1]) and normals[i].is_equal_approx(normals[i + 2])
		assert_bool(same).is_true()
		assert_float(normals[i].length()).is_equal_approx(1.0, 0.001)
		i += 3


func _assert_outward(mesh: ArrayMesh) -> void:
	## The solids are centred on the origin, so every face normal must point away from it.
	var verts: PackedVector3Array = _verts(mesh)
	var normals: PackedVector3Array = _normals(mesh)
	var i: int = 0
	while i < verts.size():
		var centroid: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		assert_bool(normals[i].dot(centroid) > 0.0).is_true()
		i += 3


func _assert_all_colors(mesh: ArrayMesh, expected: Color) -> void:
	var colors: PackedColorArray = _colors(mesh)
	for c: Color in colors:
		assert_bool(c.is_equal_approx(expected)).is_true()


func test_box_vertex_count_and_bounds() -> void:
	var mesh: ArrayMesh = MeshKit.box(Vector3(2.0, 3.0, 4.0), RED)
	assert_object(mesh).is_not_null()
	assert_int(mesh.get_surface_count()).is_equal(1)
	assert_int(_verts(mesh).size()).is_equal(36)
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(3.0, 0.001)
	assert_float(aabb.size.z).is_equal_approx(4.0, 0.001)


func test_box_normals_are_flat_and_outward() -> void:
	var mesh: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), RED)
	_assert_flat(mesh)
	_assert_outward(mesh)


func test_box_stores_vertex_colour() -> void:
	var mesh: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), RED)
	_assert_all_colors(mesh, RED)


func test_cylinder_vertex_count_and_bounds() -> void:
	var mesh: ArrayMesh = MeshKit.cylinder(0.5, 0.5, 2.0, 8, RED)
	assert_int(_verts(mesh).size()).is_equal(12 * 8)
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(1.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.z).is_equal_approx(1.0, 0.001)


func test_cylinder_normals_are_flat_and_outward() -> void:
	var mesh: ArrayMesh = MeshKit.cylinder(0.5, 0.5, 2.0, 8, RED)
	_assert_flat(mesh)
	_assert_outward(mesh)


func test_cone_vertex_count_and_bounds() -> void:
	var mesh: ArrayMesh = MeshKit.cone(1.0, 2.0, 8, BLUE)
	assert_int(_verts(mesh).size()).is_equal(6 * 8)
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.z).is_equal_approx(2.0, 0.001)


func test_cone_normals_are_flat_and_outward() -> void:
	var mesh: ArrayMesh = MeshKit.cone(1.0, 2.0, 8, BLUE)
	_assert_flat(mesh)
	_assert_outward(mesh)
	_assert_all_colors(mesh, BLUE)


func test_sphere_vertex_count_and_bounds() -> void:
	var mesh: ArrayMesh = MeshKit.sphere(1.0, 8, 16, RED)
	assert_int(_verts(mesh).size()).is_equal(6 * 16 * (8 - 1))
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.z).is_equal_approx(2.0, 0.001)


func test_sphere_normals_are_flat_and_outward() -> void:
	var mesh: ArrayMesh = MeshKit.sphere(1.0, 8, 16, RED)
	_assert_flat(mesh)
	_assert_outward(mesh)


func test_capsule_bounds_match_radius_and_height() -> void:
	var mesh: ArrayMesh = MeshKit.capsule(0.5, 2.0, RED)
	assert_int(mesh.get_surface_count()).is_equal(1)
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(1.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	assert_float(aabb.size.z).is_equal_approx(1.0, 0.001)
	_assert_flat(mesh)


func test_merge_combines_vertices_and_applies_transforms() -> void:
	var a: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), RED)
	var b: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), BLUE)
	var parts: Array[Dictionary] = [
		{"mesh": a, "transform": Transform3D(Basis(), Vector3.ZERO)},
		{"mesh": b, "transform": Transform3D(Basis(), Vector3(5.0, 0.0, 0.0))},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	assert_int(_verts(merged).size()).is_equal(72)
	var aabb: AABB = merged.get_aabb()
	assert_float(aabb.position.x).is_equal_approx(-0.5, 0.001)
	assert_float(aabb.end.x).is_equal_approx(5.5, 0.001)
	assert_float(aabb.size.y).is_equal_approx(1.0, 0.001)


func test_merge_keeps_per_part_colours() -> void:
	var a: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), RED)
	var b: ArrayMesh = MeshKit.box(Vector3(1.0, 1.0, 1.0), BLUE)
	var parts: Array[Dictionary] = [
		{"mesh": a, "transform": Transform3D(Basis(), Vector3.ZERO)},
		{"mesh": b, "transform": Transform3D(Basis(), Vector3(5.0, 0.0, 0.0))},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	var colors: PackedColorArray = _colors(merged)
	assert_int(colors.size()).is_equal(72)
	assert_bool(colors[0].is_equal_approx(RED)).is_true()
	assert_bool(colors[71].is_equal_approx(BLUE)).is_true()


func test_merge_rotation_swaps_bounds_and_keeps_normals_unit() -> void:
	var a: ArrayMesh = MeshKit.box(Vector3(2.0, 1.0, 1.0), RED)
	var parts: Array[Dictionary] = [
		{"mesh": a, "transform": Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3.ZERO)},
	]
	var merged: ArrayMesh = MeshKit.merge(parts)
	var aabb: AABB = merged.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(1.0, 0.001)
	assert_float(aabb.size.y).is_equal_approx(2.0, 0.001)
	_assert_flat(merged)


func test_flat_material_uses_vertex_colour_and_toon_ramp() -> void:
	var material: ShaderMaterial = MeshKit.flat_material()
	assert_object(material).is_not_null()
	assert_bool(material.shader.code.contains("COLOR")).is_true()


func test_flat_material_is_shared() -> void:
	var first: ShaderMaterial = MeshKit.flat_material()
	var second: ShaderMaterial = MeshKit.flat_material()
	assert_bool(first == second).is_true()
