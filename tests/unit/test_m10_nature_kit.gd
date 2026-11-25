extends GdUnitTestSuite
## Acceptance tests for M10 (gen/nature_kit.gd), DESIGN §9.
## Checks: the same seed gives the same result, each tree has fewer than 1500 triangles, and the ocean plane
## has a ShaderMaterial with animated vertex waves in the DEEP_OCEAN colour family. Ashoka trees carry ASHOKA_RED blossoms.

const TRI_BUDGET: int = 1500


func _surface_arrays(mi: MeshInstance3D) -> Array:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	return mesh.surface_get_arrays(0)


func _vertices(mi: MeshInstance3D) -> PackedVector3Array:
	var arrays: Array = _surface_arrays(mi)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _colors(mi: MeshInstance3D) -> PackedColorArray:
	var arrays: Array = _surface_arrays(mi)
	return arrays[Mesh.ARRAY_COLOR] as PackedColorArray


func _triangle_count(mi: MeshInstance3D) -> int:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var total: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array:
			total += (indices as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _has_colour(colours: PackedColorArray, target: Color) -> bool:
	for c: Color in colours:
		if c.is_equal_approx(target):
			return true
	return false


func test_ashoka_tree_returns_mesh_instance() -> void:
	var tree: MeshInstance3D = NatureKit.ashoka_tree(1)
	auto_free(tree)
	assert_object(tree).is_not_null()
	assert_object(tree.mesh).is_not_null()
	assert_int(_vertices(tree).size()).is_greater(0)


func test_ashoka_tree_same_seed_same_result() -> void:
	var a: MeshInstance3D = NatureKit.ashoka_tree(42)
	var b: MeshInstance3D = NatureKit.ashoka_tree(42)
	auto_free(a)
	auto_free(b)
	assert_bool(_vertices(a) == _vertices(b)).is_true()
	assert_bool(_colors(a) == _colors(b)).is_true()


func test_shimshapa_tree_same_seed_same_result() -> void:
	var a: MeshInstance3D = NatureKit.shimshapa_tree(7)
	var b: MeshInstance3D = NatureKit.shimshapa_tree(7)
	auto_free(a)
	auto_free(b)
	assert_bool(_vertices(a) == _vertices(b)).is_true()
	assert_bool(_colors(a) == _colors(b)).is_true()


func test_trees_stay_within_triangle_budget() -> void:
	for seed_value: int in [1, 2, 3, 5, 8, 13]:
		var ashoka: MeshInstance3D = NatureKit.ashoka_tree(seed_value)
		var shimshapa: MeshInstance3D = NatureKit.shimshapa_tree(seed_value)
		auto_free(ashoka)
		auto_free(shimshapa)
		assert_int(_triangle_count(ashoka)).is_less(TRI_BUDGET)
		assert_int(_triangle_count(shimshapa)).is_less(TRI_BUDGET)


func test_ashoka_tree_has_red_blossoms_on_green_canopy() -> void:
	var tree: MeshInstance3D = NatureKit.ashoka_tree(3)
	auto_free(tree)
	var colours: PackedColorArray = _colors(tree)
	assert_bool(_has_colour(colours, Palette.ASHOKA_RED)).is_true()
	assert_bool(_has_colour(colours, Palette.GROVE_GREEN)).is_true()


func test_shimshapa_tree_has_no_blossoms() -> void:
	var tree: MeshInstance3D = NatureKit.shimshapa_tree(3)
	auto_free(tree)
	assert_bool(_has_colour(_colors(tree), Palette.ASHOKA_RED)).is_false()


func test_rock_same_seed_same_result() -> void:
	var a: MeshInstance3D = NatureKit.rock(Vector3(1.0, 0.8, 1.2), 11)
	var b: MeshInstance3D = NatureKit.rock(Vector3(1.0, 0.8, 1.2), 11)
	auto_free(a)
	auto_free(b)
	assert_bool(_vertices(a) == _vertices(b)).is_true()
	assert_bool(_colors(a) == _colors(b)).is_true()


func test_rock_has_stone_colour_and_triangles() -> void:
	var rock_mi: MeshInstance3D = NatureKit.rock(Vector3(1.0, 1.0, 1.0), 4)
	auto_free(rock_mi)
	assert_int(_triangle_count(rock_mi)).is_greater(0)
	assert_int(_triangle_count(rock_mi)).is_less(TRI_BUDGET)
	var colours: PackedColorArray = _colors(rock_mi)
	assert_int(colours.size()).is_greater(0)
	var first: Color = colours[0]
	assert_float(first.r).is_between(0.0, 1.0)


func test_cliff_same_seed_same_result() -> void:
	var a: MeshInstance3D = NatureKit.cliff(Vector3(4.0, 6.0, 3.0), 21)
	var b: MeshInstance3D = NatureKit.cliff(Vector3(4.0, 6.0, 3.0), 21)
	auto_free(a)
	auto_free(b)
	assert_bool(_vertices(a) == _vertices(b)).is_true()


func test_cliff_rises_from_ground() -> void:
	var cliff_mi: MeshInstance3D = NatureKit.cliff(Vector3(4.0, 6.0, 3.0), 21)
	auto_free(cliff_mi)
	var aabb: AABB = cliff_mi.mesh.get_aabb()
	# The lowest vertex sits exactly on y = 0 and the mass rises to about the requested height.
	assert_float(cliff_mi.position.y + aabb.position.y).is_equal_approx(0.0, 0.001)
	assert_float(aabb.size.y).is_greater(3.0)


func test_ocean_plane_has_shader_material() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(200.0, 200.0))
	auto_free(ocean)
	assert_object(ocean.mesh).is_not_null()
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	assert_object(material).is_not_null()
	assert_object(material.shader).is_not_null()


func test_ocean_shader_has_animated_vertex_waves() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(100.0, 100.0))
	auto_free(ocean)
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	var code: String = material.shader.code
	assert_bool(code.contains("void vertex()")).is_true()
	assert_bool(code.contains("TIME")).is_true()
	assert_bool(code.contains("VERTEX.y")).is_true()


func test_ocean_colour_is_deep_ocean_with_lighter_crest() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(100.0, 100.0))
	auto_free(ocean)
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	var deep: Color = material.get_shader_parameter("deep_colour") as Color
	var crest: Color = material.get_shader_parameter("crest_colour") as Color
	assert_bool(deep.is_equal_approx(Palette.DEEP_OCEAN)).is_true()
	assert_float(crest.get_luminance()).is_greater(deep.get_luminance())


func test_ocean_plane_covers_requested_size() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(120.0, 80.0))
	auto_free(ocean)
	var aabb: AABB = ocean.mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(120.0, 0.01)
	assert_float(aabb.size.z).is_equal_approx(80.0, 0.01)


func test_grass_patch_same_seed_same_result() -> void:
	var a: MeshInstance3D = NatureKit.grass_patch(9, 1.5, 18)
	var b: MeshInstance3D = NatureKit.grass_patch(9, 1.5, 18)
	auto_free(a)
	auto_free(b)
	assert_bool(_vertices(a) == _vertices(b)).is_true()
	assert_bool(_colors(a) == _colors(b)).is_true()


func test_grass_patch_has_triangles_within_budget() -> void:
	var grass: MeshInstance3D = NatureKit.grass_patch(5, 1.5, 18)
	auto_free(grass)
	assert_int(_triangle_count(grass)).is_greater(0)
	assert_int(_triangle_count(grass)).is_less(TRI_BUDGET)
