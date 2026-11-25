extends GdUnitTestSuite
## Acceptance tests for A4 (art pass on gen/nature_kit.gd): bark trunks joined to the canopy, mixed leaf greens,
## tall narrow ashoka with dense blossoms, broad dense shimshapa, stone/bark rocks, triangle budget.

const TRI_BUDGET: int = 1500


func _verts(mi: MeshInstance3D) -> PackedVector3Array:
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _cols(mi: MeshInstance3D) -> PackedColorArray:
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	return arrays[Mesh.ARRAY_COLOR] as PackedColorArray


func _count_colour(mi: MeshInstance3D, target: Color) -> int:
	var n: int = 0
	for c: Color in _cols(mi):
		if c.is_equal_approx(target):
			n += 1
	return n


func _max_y_of(mi: MeshInstance3D, target: Color) -> float:
	var verts: PackedVector3Array = _verts(mi)
	var cols: PackedColorArray = _cols(mi)
	var best: float = -1000.0
	for i: int in range(verts.size()):
		if cols[i].is_equal_approx(target):
			best = maxf(best, verts[i].y)
	return best


func _tris(mi: MeshInstance3D) -> int:
	return int(_verts(mi).size() / 3.0)


func _trees(seed_value: int) -> Array[MeshInstance3D]:
	var a: MeshInstance3D = NatureKit.ashoka_tree(seed_value)
	var s: MeshInstance3D = NatureKit.shimshapa_tree(seed_value)
	auto_free(a)
	auto_free(s)
	return [a, s]


func test_trunks_use_bark_not_stone() -> void:
	for t: MeshInstance3D in _trees(5):
		assert_int(_count_colour(t, Palette.BARK)).is_greater(0)
		assert_int(_count_colour(t, Palette.STONE)).is_equal(0)


func test_canopies_mix_both_greens() -> void:
	for t: MeshInstance3D in _trees(5):
		assert_int(_count_colour(t, Palette.GROVE_GREEN)).is_greater(0)
		assert_int(_count_colour(t, Palette.LEAF_DARK)).is_greater(0)


func test_branches_reach_into_canopy() -> void:
	for t: MeshInstance3D in _trees(9):
		var top: float = t.mesh.get_aabb().end.y
		# Bark (branches) must climb into the upper canopy, not stop at the trunk's top.
		assert_float(_max_y_of(t, Palette.BARK)).is_greater(top * 0.6)


func test_ashoka_tall_narrow_with_dense_blossoms() -> void:
	var tree: MeshInstance3D = NatureKit.ashoka_tree(3, 6.0)
	auto_free(tree)
	var box: AABB = tree.mesh.get_aabb()
	assert_float(box.size.y).is_greater(5.0)
	assert_float(maxf(box.size.x, box.size.z)).is_less(box.size.y * 0.65)
	assert_int(_count_colour(tree, Palette.ASHOKA_RED)).is_greater(150)


func test_shimshapa_broader_than_ashoka_and_dense() -> void:
	var ashoka: MeshInstance3D = NatureKit.ashoka_tree(3, 6.0)
	var shim: MeshInstance3D = NatureKit.shimshapa_tree(3, 6.0)
	auto_free(ashoka)
	auto_free(shim)
	var wa: float = maxf(ashoka.mesh.get_aabb().size.x, ashoka.mesh.get_aabb().size.z)
	var ws: float = maxf(shim.mesh.get_aabb().size.x, shim.mesh.get_aabb().size.z)
	assert_float(ws).is_greater(wa * 1.5)
	assert_int(_count_colour(shim, Palette.ASHOKA_RED)).is_equal(0)


func test_tree_triangle_budget_and_determinism() -> void:
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7]:
		var pair: Array[MeshInstance3D] = _trees(seed_value)
		for t: MeshInstance3D in pair:
			assert_int(_tris(t)).is_less(TRI_BUDGET)
	var a: MeshInstance3D = NatureKit.ashoka_tree(77)
	var b: MeshInstance3D = NatureKit.ashoka_tree(77)
	auto_free(a)
	auto_free(b)
	assert_bool(_verts(a) == _verts(b)).is_true()


func test_rocks_and_cliffs_use_stone_or_bark_tones() -> void:
	var rock: MeshInstance3D = NatureKit.rock(Vector3(1, 1, 1), 4)
	var cliff: MeshInstance3D = NatureKit.cliff(Vector3(4, 6, 3), 8)
	auto_free(rock)
	auto_free(cliff)
	for mi: MeshInstance3D in [rock, cliff]:
		for c: Color in _cols(mi):
			# Warm, never green or blue: red >= green >= blue.
			assert_bool(c.r >= c.g - 0.001 and c.g >= c.b - 0.001).is_true()
			assert_float(c.r).is_greater(0.3)
