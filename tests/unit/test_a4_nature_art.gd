extends GdUnitTestSuite
## Acceptance tests for A4 (art pass on gen/nature_kit.gd): bark trunks joined to the canopy, mixed leaf greens,
## tall narrow ashoka with dense blossoms, broad dense shimshapa, stone/bark rocks, triangle budget.
## Updated for B5 (art v2): vertices and colours are gathered over every surface (one per material kind), colours
## are compared on RGB (alpha is the wind weight), the tree budget follows docs/ART.md, and rocks may carry moss.

const TRI_BUDGET: int = NatureKit.TREE_TRI_BUDGET


func _verts(mi: MeshInstance3D) -> PackedVector3Array:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var all: PackedVector3Array = PackedVector3Array()
	for s: int in range(mesh.get_surface_count()):
		all.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return all


func _cols(mi: MeshInstance3D) -> PackedColorArray:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var all: PackedColorArray = PackedColorArray()
	for s: int in range(mesh.get_surface_count()):
		all.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray)
	return all


func _same_rgb(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) and is_equal_approx(a.b, b.b)


func _count_colour(mi: MeshInstance3D, target: Color) -> int:
	var n: int = 0
	for c: Color in _cols(mi):
		if _same_rgb(c, target):
			n += 1
	return n


func _max_y_of(mi: MeshInstance3D, target: Color) -> float:
	var verts: PackedVector3Array = _verts(mi)
	var cols: PackedColorArray = _cols(mi)
	var best: float = -1000.0
	for i: int in range(verts.size()):
		if _same_rgb(cols[i], target):
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
		var warm: int = 0
		var cols: PackedColorArray = _cols(mi)
		for c: Color in cols:
			# Never blue: blue is always below green. Stone and bark tones are warm (red >= green); only moss
			# (art v2) leans green.
			assert_bool(c.b <= c.g + 0.001).is_true()
			assert_float(maxf(c.r, c.g)).is_greater(0.3)
			if c.r >= c.g - 0.001:
				warm += 1
		# Stone dominates; moss is an accent.
		assert_int(warm).is_greater(cols.size() / 2)
