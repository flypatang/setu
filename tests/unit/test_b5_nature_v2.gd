extends GdUnitTestSuite
## Acceptance tests for B5 (nature v2, docs/ART.md "Foliage"): curved bark trunks on the wood material, canopies
## of many wind-weighted leaf cards on the foliage material, drooping ashoka foliage with ASHOKA_RED blossoms, a
## broad shimshapa, smooth mossy stone rocks and cliffs, MultiMesh grass, flowers, bushes and the WaterKit ocean.


func _surface_index(mi: MeshInstance3D, surface_name: String) -> int:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	for s: int in range(mesh.get_surface_count()):
		if mesh.surface_get_name(s) == surface_name:
			return s
	return -1


func _verts(mi: MeshInstance3D, surface_name: String) -> PackedVector3Array:
	var index: int = _surface_index(mi, surface_name)
	if index < 0:
		return PackedVector3Array()
	return (mi.mesh as ArrayMesh).surface_get_arrays(index)[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _normals(mi: MeshInstance3D, surface_name: String) -> PackedVector3Array:
	var index: int = _surface_index(mi, surface_name)
	if index < 0:
		return PackedVector3Array()
	return (mi.mesh as ArrayMesh).surface_get_arrays(index)[Mesh.ARRAY_NORMAL] as PackedVector3Array


func _cols(mi: MeshInstance3D, surface_name: String) -> PackedColorArray:
	var index: int = _surface_index(mi, surface_name)
	if index < 0:
		return PackedColorArray()
	return (mi.mesh as ArrayMesh).surface_get_arrays(index)[Mesh.ARRAY_COLOR] as PackedColorArray


func _total_tris(mi: MeshInstance3D) -> int:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var total: int = 0
	for s: int in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _same_rgb(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) and is_equal_approx(a.b, b.b)


func _count_rgb(cols: PackedColorArray, target: Color) -> int:
	var n: int = 0
	for c: Color in cols:
		if _same_rgb(c, target):
			n += 1
	return n


## Share of triangles whose three vertex normals are not all the same (smooth shading).
func _smooth_share(normals: PackedVector3Array) -> float:
	var smooth: int = 0
	var tris: int = normals.size() / 3
	for t: int in range(tris):
		if not normals[t * 3].is_equal_approx(normals[t * 3 + 1]) or not normals[t * 3].is_equal_approx(normals[t * 3 + 2]):
			smooth += 1
	return float(smooth) / float(maxi(tris, 1))


func _trees(seed_value: int, height: float) -> Array[MeshInstance3D]:
	var a: MeshInstance3D = NatureKit.ashoka_tree(seed_value, height)
	var s: MeshInstance3D = NatureKit.shimshapa_tree(seed_value, height)
	auto_free(a)
	auto_free(s)
	return [a, s]


func _blades(mi: MeshInstance3D) -> MultiMeshInstance3D:
	return mi.get_node_or_null(NodePath(NatureKit.BLADES_NAME)) as MultiMeshInstance3D


func _origins(mi: MeshInstance3D) -> PackedVector3Array:
	return _blades(mi).get_meta(NatureKit.BLADE_ORIGINS_META) as PackedVector3Array


func test_trees_have_wood_and_foliage_surfaces_with_painterly_materials() -> void:
	for t: MeshInstance3D in _trees(5, 6.0):
		var mesh: ArrayMesh = t.mesh as ArrayMesh
		assert_int(mesh.get_surface_count()).is_equal(2)
		var wood: int = _surface_index(t, "wood")
		var foliage: int = _surface_index(t, "foliage")
		assert_int(wood).is_greater_equal(0)
		assert_int(foliage).is_greater_equal(0)
		assert_object(mesh.surface_get_material(wood)).is_same(Materials.get_material(&"wood"))
		assert_object(mesh.surface_get_material(foliage)).is_same(Materials.get_material(&"foliage"))
		# The surface materials must not be hidden by an override.
		assert_object(t.material_override).is_null()


func test_trunks_are_curved_and_smooth() -> void:
	for t: MeshInstance3D in _trees(9, 6.0):
		var verts: PackedVector3Array = _verts(t, "wood")
		var cols: PackedColorArray = _cols(t, "wood")
		assert_int(_count_rgb(cols, Palette.BARK)).is_greater(0)
		assert_float(_smooth_share(_normals(t, "wood"))).is_greater(0.9)
		# The trunk's centre line wanders: the bark low on the trunk is centred elsewhere than at the root.
		var low: Vector3 = Vector3.ZERO
		var low_n: int = 0
		var high: Vector3 = Vector3.ZERO
		var high_n: int = 0
		for v: Vector3 in verts:
			if v.y < 0.25:
				low += v
				low_n += 1
			elif v.y > 1.2 and v.y < 2.0:
				high += v
				high_n += 1
		assert_int(low_n).is_greater(0)
		assert_int(high_n).is_greater(0)
		var offset: Vector3 = high / float(high_n) - low / float(low_n)
		assert_float(Vector2(offset.x, offset.z).length()).is_greater(0.03)


func test_trunk_flares_at_the_root() -> void:
	for t: MeshInstance3D in _trees(4, 6.0):
		var root_reach: float = 0.0
		var waist_reach: float = 0.0
		for v: Vector3 in _verts(t, "wood"):
			var reach: float = Vector2(v.x, v.z).length()
			if v.y < 0.15:
				root_reach = maxf(root_reach, reach)
			elif v.y > 0.9 and v.y < 1.3:
				waist_reach = maxf(waist_reach, reach)
		assert_float(root_reach).is_greater(waist_reach * 1.2)


func test_canopies_are_many_leaf_cards_with_wind_weights() -> void:
	for t: MeshInstance3D in _trees(3, 6.0):
		var cols: PackedColorArray = _cols(t, "foliage")
		# Hundreds of small cards, not a handful of blobs.
		assert_int(cols.size() / 3).is_greater(1200)
		var free: int = 0
		var held: int = 0
		for c: Color in cols:
			if c.a > 0.95:
				free += 1
			elif c.a < 0.5:
				held += 1
		# Every leaf has a free tip and a held stem.
		assert_int(free).is_greater(500)
		assert_int(held).is_greater(500)
		assert_float(_smooth_share(_normals(t, "foliage"))).is_greater(0.9)


func test_canopy_colours_run_from_shadow_to_sunlit() -> void:
	for t: MeshInstance3D in _trees(3, 6.0):
		var verts: PackedVector3Array = _verts(t, "foliage")
		var cols: PackedColorArray = _cols(t, "foliage")
		assert_int(_count_rgb(cols, Palette.GROVE_GREEN)).is_greater(0)
		assert_int(_count_rgb(cols, Palette.LEAF_DARK)).is_greater(0)
		var top: float = t.mesh.get_aabb().end.y
		var low_lum: float = 0.0
		var low_n: int = 0
		var high_lum: float = 0.0
		var high_n: int = 0
		for i: int in range(verts.size()):
			if _same_rgb(cols[i], Palette.ASHOKA_RED):
				continue
			if verts[i].y > top * 0.8:
				high_lum += cols[i].get_luminance()
				high_n += 1
			elif verts[i].y < top * 0.55:
				low_lum += cols[i].get_luminance()
				low_n += 1
		assert_int(low_n).is_greater(0)
		assert_int(high_n).is_greater(0)
		assert_float(high_lum / float(high_n)).is_greater(low_lum / float(low_n))


func test_ashoka_foliage_droops_and_carries_red_blossoms() -> void:
	var tree: MeshInstance3D = NatureKit.ashoka_tree(3, 6.0)
	auto_free(tree)
	var verts: PackedVector3Array = _verts(tree, "foliage")
	var cols: PackedColorArray = _cols(tree, "foliage")
	assert_int(_count_rgb(cols, Palette.ASHOKA_RED)).is_greater(150)
	assert_int(_count_rgb(_cols(tree, "wood"), Palette.ASHOKA_RED)).is_equal(0)
	# Leaf cards are emitted stem first: most free tips (alpha 1) hang below their stem.
	var drooping: int = 0
	var leaves: int = 0
	for i: int in range(0, verts.size() - 2, 3):
		# Leaf stems carry wind weight 0.35 (stored in 8 bits).
		if absf(cols[i].a - 0.35) > 0.01:
			continue
		for k: int in [1, 2]:
			if cols[i + k].a > 0.95:
				leaves += 1
				if verts[i + k].y < verts[i].y:
					drooping += 1
	assert_int(leaves).is_greater(500)
	assert_float(float(drooping) / float(leaves)).is_greater(0.8)


func test_shimshapa_is_broad_dense_and_without_blossoms() -> void:
	var pair: Array[MeshInstance3D] = _trees(3, 6.0)
	var ashoka_box: AABB = pair[0].mesh.get_aabb()
	var shim_box: AABB = pair[1].mesh.get_aabb()
	assert_float(maxf(shim_box.size.x, shim_box.size.z)).is_greater(maxf(ashoka_box.size.x, ashoka_box.size.z) * 1.5)
	assert_float(maxf(shim_box.size.x, shim_box.size.z)).is_greater(shim_box.size.y * 0.8)
	assert_int(_count_rgb(_cols(pair[1], "foliage"), Palette.ASHOKA_RED)).is_equal(0)
	assert_int(_cols(pair[1], "foliage").size() / 3).is_greater(2000)


func test_trees_scale_with_height_and_stay_in_budget() -> void:
	for seed_value: int in [1, 2, 3, 5, 8, 13, 4347]:
		for t: MeshInstance3D in _trees(seed_value, 6.0):
			assert_int(_total_tris(t)).is_less(NatureKit.TREE_TRI_BUDGET)
			assert_int(_total_tris(t)).is_greater(1500)
	var small: MeshInstance3D = NatureKit.shimshapa_tree(7, 4.0)
	var large: MeshInstance3D = NatureKit.shimshapa_tree(7, 9.0)
	auto_free(small)
	auto_free(large)
	assert_float(large.mesh.get_aabb().size.y).is_equal_approx(small.mesh.get_aabb().size.y * 2.25, 0.05)
	assert_float(large.mesh.get_aabb().size.y).is_between(8.0, 10.5)


func test_trees_are_deterministic_and_differ_by_seed() -> void:
	var a: MeshInstance3D = NatureKit.shimshapa_tree(11)
	var b: MeshInstance3D = NatureKit.shimshapa_tree(11)
	var c: MeshInstance3D = NatureKit.shimshapa_tree(12)
	auto_free(a)
	auto_free(b)
	auto_free(c)
	assert_bool(_verts(a, "foliage") == _verts(b, "foliage")).is_true()
	assert_bool(_cols(a, "foliage") == _cols(b, "foliage")).is_true()
	assert_bool(_verts(a, "wood") == _verts(b, "wood")).is_true()
	assert_bool(_verts(a, "foliage") == _verts(c, "foliage")).is_false()


func test_trees_cast_shadows_through_a_hidden_caster_and_have_undergrowth() -> void:
	for t: MeshInstance3D in _trees(6, 6.0):
		assert_int(t.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var caster: MeshInstance3D = t.get_node_or_null(NodePath(NatureKit.SHADOW_CASTER_NAME)) as MeshInstance3D
		assert_object(caster).is_not_null()
		assert_int(caster.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		assert_int(_total_tris(caster)).is_greater(0)
		# The caster is simpler than the tree and stays inside its bounds.
		assert_int(_total_tris(caster)).is_less(_total_tris(t) / 2)
		assert_bool(t.mesh.get_aabb().grow(0.2).encloses(caster.mesh.get_aabb())).is_true()
		var undergrowth: MeshInstance3D = t.get_node_or_null(NodePath(NatureKit.UNDERGROWTH_NAME)) as MeshInstance3D
		assert_object(undergrowth).is_not_null()
		var blades: MultiMeshInstance3D = _blades(undergrowth)
		assert_object(blades).is_not_null()
		assert_int(blades.multimesh.instance_count).is_greater(10)


func test_rock_is_smooth_stone_with_moss_and_a_flat_base() -> void:
	var size: Vector3 = Vector3(2.5, 2.0, 2.5)
	var rock: MeshInstance3D = NatureKit.rock(size, 9275)
	auto_free(rock)
	var mesh: ArrayMesh = rock.mesh as ArrayMesh
	assert_int(mesh.get_surface_count()).is_equal(1)
	assert_str(mesh.surface_get_name(0)).is_equal("stone")
	assert_object(mesh.surface_get_material(0)).is_same(Materials.get_material(&"stone"))
	assert_object(rock.material_override).is_null()
	assert_float(_smooth_share(_normals(rock, "stone"))).is_greater(0.6)
	var box: AABB = mesh.get_aabb()
	# Sits on the ground where LevelBuilder puts it (centred, lifted by half its height) and fills its size box.
	assert_float(box.position.y).is_equal_approx(-size.y * 0.5, 0.001)
	assert_float(box.size.y).is_between(size.y * 0.7, size.y * 1.3)
	assert_float(box.size.x).is_between(size.x * 0.6, size.x * 1.4)
	assert_float(box.size.z).is_between(size.z * 0.6, size.z * 1.4)
	var verts: PackedVector3Array = _verts(rock, "stone")
	var cols: PackedColorArray = _cols(rock, "stone")
	var grounded: int = 0
	var mossy: int = 0
	var mossy_low: int = 0
	for i: int in range(verts.size()):
		if is_equal_approx(verts[i].y, -size.y * 0.5):
			grounded += 1
		if cols[i].g > cols[i].r + 0.01:
			mossy += 1
			if verts[i].y < 0.0:
				mossy_low += 1
	# A flat base, not a single touching point.
	assert_int(grounded).is_greater(30)
	# Moss grows on the upward faces only.
	assert_int(mossy).is_greater(0)
	assert_int(mossy_low).is_equal(0)
	assert_int(_total_tris(rock)).is_less(1000)


func test_rock_is_darker_at_the_ground_than_on_top() -> void:
	var rock: MeshInstance3D = NatureKit.rock(Vector3(2.0, 2.0, 2.0), 17)
	auto_free(rock)
	var verts: PackedVector3Array = _verts(rock, "stone")
	var cols: PackedColorArray = _cols(rock, "stone")
	var low: float = 0.0
	var low_n: int = 0
	var high: float = 0.0
	var high_n: int = 0
	for i: int in range(verts.size()):
		if verts[i].y < -0.6:
			low += cols[i].get_luminance()
			low_n += 1
		elif verts[i].y > 0.3:
			high += cols[i].get_luminance()
			high_n += 1
	assert_int(low_n).is_greater(0)
	assert_int(high_n).is_greater(0)
	assert_float(high / float(high_n)).is_greater(low / float(low_n))


func test_cliff_is_a_tall_smooth_stone_crag_on_the_ground() -> void:
	var size: Vector3 = Vector3(4.0, 6.0, 4.0)
	var cliff: MeshInstance3D = NatureKit.cliff(size, 8545)
	auto_free(cliff)
	var mesh: ArrayMesh = cliff.mesh as ArrayMesh
	assert_str(mesh.surface_get_name(0)).is_equal("stone")
	assert_object(mesh.surface_get_material(0)).is_same(Materials.get_material(&"stone"))
	var box: AABB = mesh.get_aabb()
	assert_float(cliff.position.y + box.position.y).is_equal_approx(0.0, 0.001)
	assert_float(box.size.y).is_between(size.y * 0.8, size.y * 1.25)
	assert_float(_smooth_share(_normals(cliff, "stone"))).is_greater(0.6)
	assert_int(_total_tris(cliff)).is_less(NatureKit.TREE_TRI_BUDGET)
	var again: MeshInstance3D = NatureKit.cliff(size, 8545)
	auto_free(again)
	assert_bool(_verts(cliff, "stone") == _verts(again, "stone")).is_true()
	assert_bool(_cols(cliff, "stone") == _cols(again, "stone")).is_true()


func test_grass_patch_blades_are_a_multimesh() -> void:
	var grass: MeshInstance3D = NatureKit.grass_patch(9, 1.5, 40)
	auto_free(grass)
	var blades: MultiMeshInstance3D = _blades(grass)
	assert_object(blades).is_not_null()
	var mm: MultiMesh = blades.multimesh
	assert_int(mm.instance_count).is_equal(40)
	assert_bool(mm.use_colors).is_true()
	assert_object(mm.mesh).is_not_null()
	assert_object(mm.mesh.surface_get_material(0)).is_same(Materials.get_material(&"foliage"))
	# The layout is read from metadata: the headless rendering server keeps no per-instance data.
	var origins: PackedVector3Array = _origins(grass)
	var tints: PackedColorArray = blades.get_meta(NatureKit.BLADE_COLOURS_META) as PackedColorArray
	assert_int(origins.size()).is_equal(40)
	assert_int(tints.size()).is_equal(40)
	var spread: float = 0.0
	for i: int in range(origins.size()):
		var origin: Vector3 = origins[i]
		spread = maxf(spread, Vector2(origin.x, origin.z).length())
		assert_float(Vector2(origin.x, origin.z).length()).is_less_equal(1.5 + 0.001)
		assert_float(origin.y).is_equal_approx(0.0, 0.001)
		# Green, never blue; alpha stays 1 so the mesh's own wind weights pass through.
		var c: Color = tints[i]
		assert_bool(c.g > c.b and c.g >= c.r - 0.2).is_true()
		assert_float(c.a).is_equal_approx(1.0, 0.001)
	assert_float(spread).is_greater(0.75)


func test_grass_blades_sway_from_a_rigid_root() -> void:
	var grass: MeshInstance3D = NatureKit.grass_patch(2, 1.0, 8)
	auto_free(grass)
	var tuft: ArrayMesh = _blades(grass).multimesh.mesh as ArrayMesh
	var verts: PackedVector3Array = tuft.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var cols: PackedColorArray = tuft.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	var top: float = tuft.get_aabb().end.y
	assert_float(top).is_between(0.2, 0.8)
	var free_tips: int = 0
	for i: int in range(verts.size()):
		if verts[i].y < 0.001:
			assert_float(cols[i].a).is_equal_approx(0.0, 0.001)
		if cols[i].a > 0.99:
			free_tips += 1
			assert_float(verts[i].y).is_greater(top * 0.4)
	assert_int(free_tips).is_greater(0)


func test_grass_patch_is_deterministic() -> void:
	var a: MeshInstance3D = NatureKit.grass_patch(31, 2.0, 30)
	var b: MeshInstance3D = NatureKit.grass_patch(31, 2.0, 30)
	var c: MeshInstance3D = NatureKit.grass_patch(32, 2.0, 30)
	auto_free(a)
	auto_free(b)
	auto_free(c)
	assert_bool(_origins(a) == _origins(b)).is_true()
	assert_bool(_blades(a).get_meta(NatureKit.BLADE_COLOURS_META) == _blades(b).get_meta(NatureKit.BLADE_COLOURS_META)).is_true()
	assert_bool(_origins(a) == _origins(c)).is_false()
	assert_int(_blades(a).multimesh.instance_count).is_equal(30)
	# All patches share one tuft mesh.
	assert_object(_blades(a).multimesh.mesh).is_same(_blades(c).multimesh.mesh)


func test_grass_patch_without_blades_is_still_valid() -> void:
	var grass: MeshInstance3D = NatureKit.grass_patch(1, 1.0, 0)
	auto_free(grass)
	assert_object(grass.mesh).is_not_null()
	assert_int(_blades(grass).multimesh.instance_count).is_equal(0)


func test_flowers_fill_the_area_in_palette_colours() -> void:
	var area: Vector2 = Vector2(4.0, 2.0)
	var flowers: MeshInstance3D = NatureKit.flowers(area, 5)
	auto_free(flowers)
	assert_str(flowers.name).is_equal("Flowers")
	var mesh: ArrayMesh = flowers.mesh as ArrayMesh
	assert_str(mesh.surface_get_name(0)).is_equal("foliage")
	assert_object(mesh.surface_get_material(0)).is_same(Materials.get_material(&"foliage"))
	var box: AABB = mesh.get_aabb()
	assert_float(box.size.x).is_between(area.x * 0.5, area.x + 1.0)
	assert_float(box.size.z).is_between(area.y * 0.5, area.y + 1.0)
	assert_float(box.position.y).is_equal_approx(0.0, 0.001)
	assert_float(box.end.y).is_between(0.15, 0.7)
	var cols: PackedColorArray = _cols(flowers, "foliage")
	var petals: int = 0
	for target: Color in [Palette.ASHOKA_RED, Palette.SAFFRON, Palette.GOLD, Palette.MOON]:
		petals += _count_rgb(cols, target)
	assert_int(petals).is_greater(50)
	# Stems are green.
	assert_int(_count_rgb(cols, Palette.GROVE_GREEN)).is_greater(0)


func test_flowers_count_and_determinism() -> void:
	var few: MeshInstance3D = NatureKit.flowers(Vector2(3.0, 3.0), 8, 4)
	var many: MeshInstance3D = NatureKit.flowers(Vector2(3.0, 3.0), 8, 40)
	var again: MeshInstance3D = NatureKit.flowers(Vector2(3.0, 3.0), 8, 40)
	var other: MeshInstance3D = NatureKit.flowers(Vector2(3.0, 3.0), 9, 40)
	var none: MeshInstance3D = NatureKit.flowers(Vector2(3.0, 3.0), 8, 0)
	for mi: MeshInstance3D in [few, many, again, other, none]:
		auto_free(mi)
	assert_int(_total_tris(many)).is_greater(_total_tris(few) * 5)
	assert_bool(_verts(many, "foliage") == _verts(again, "foliage")).is_true()
	assert_bool(_cols(many, "foliage") == _cols(again, "foliage")).is_true()
	assert_bool(_verts(many, "foliage") == _verts(other, "foliage")).is_false()
	assert_int((none.mesh as ArrayMesh).get_surface_count()).is_equal(0)
	# The default density follows the area.
	var auto_small: MeshInstance3D = NatureKit.flowers(Vector2(1.0, 1.0), 3)
	var auto_large: MeshInstance3D = NatureKit.flowers(Vector2(5.0, 5.0), 3)
	auto_free(auto_small)
	auto_free(auto_large)
	assert_int(_total_tris(auto_large)).is_greater(_total_tris(auto_small))


func test_bush_is_a_low_leafy_shrub() -> void:
	var plain: MeshInstance3D = NatureKit.bush(4, 0.8)
	var flowering: MeshInstance3D = NatureKit.bush(4, 0.8, true)
	var again: MeshInstance3D = NatureKit.bush(4, 0.8, true)
	for mi: MeshInstance3D in [plain, flowering, again]:
		auto_free(mi)
	assert_int(_surface_index(plain, "wood")).is_greater_equal(0)
	assert_int(_surface_index(plain, "foliage")).is_greater_equal(0)
	var box: AABB = plain.mesh.get_aabb()
	assert_float(box.end.y).is_between(0.6, 1.8)
	assert_float(maxf(box.size.x, box.size.z)).is_between(1.0, 2.6)
	assert_int(_cols(plain, "foliage").size() / 3).is_greater(200)
	assert_int(_total_tris(plain)).is_less(1500)
	# Only the flowering bush carries white blossoms.
	assert_int(_count_rgb(_cols(plain, "foliage"), Palette.MOON)).is_equal(0)
	assert_int(_count_rgb(_cols(flowering, "foliage"), Palette.MOON)).is_greater(0)
	assert_bool(_verts(flowering, "foliage") == _verts(again, "foliage")).is_true()


func test_bushes_scatter_over_the_area() -> void:
	var area: Vector2 = Vector2(8.0, 3.0)
	var one: MeshInstance3D = NatureKit.bushes(area, 2, 1)
	var five: MeshInstance3D = NatureKit.bushes(area, 2, 5)
	var again: MeshInstance3D = NatureKit.bushes(area, 2, 5)
	var auto_count: MeshInstance3D = NatureKit.bushes(area, 2)
	for mi: MeshInstance3D in [one, five, again, auto_count]:
		auto_free(mi)
	assert_int(_total_tris(five)).is_greater(_total_tris(one) * 3)
	assert_bool(_verts(five, "foliage") == _verts(again, "foliage")).is_true()
	assert_int(_total_tris(auto_count)).is_greater(0)
	var box: AABB = five.mesh.get_aabb()
	assert_float(box.size.x).is_less(area.x + 1.5)
	assert_float(box.size.z).is_less(area.y + 1.5)
	assert_float(box.size.x).is_greater(box.size.z)


func test_ocean_plane_delegates_to_water_kit() -> void:
	var ocean: MeshInstance3D = NatureKit.ocean_plane(Vector2(120.0, 80.0))
	auto_free(ocean)
	assert_str(ocean.name).is_equal(WaterKit.OCEAN_NAME)
	var plane: PlaneMesh = ocean.mesh as PlaneMesh
	assert_object(plane).is_not_null()
	assert_float(plane.size.x).is_equal_approx(120.0, 0.001)
	assert_float(plane.size.y).is_equal_approx(80.0, 0.001)
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	assert_object(material).is_not_null()
	assert_str(material.shader.code).is_equal(WaterKit.shader_code())
	assert_bool((material.get_shader_parameter("deep_colour") as Color).is_equal_approx(Palette.DEEP_OCEAN)).is_true()


func test_rocks_and_cliffs_are_dressed_with_tufts() -> void:
	var rock: MeshInstance3D = NatureKit.rock(Vector3(2.0, 1.6, 2.0), 3)
	var cliff: MeshInstance3D = NatureKit.cliff(Vector3(4.0, 6.0, 4.0), 3)
	auto_free(rock)
	auto_free(cliff)
	var rock_dressing: MeshInstance3D = rock.get_node_or_null(NodePath(NatureKit.UNDERGROWTH_NAME)) as MeshInstance3D
	var cliff_dressing: MeshInstance3D = cliff.get_node_or_null(NodePath(NatureKit.UNDERGROWTH_NAME)) as MeshInstance3D
	assert_object(rock_dressing).is_not_null()
	assert_object(cliff_dressing).is_not_null()
	# The dressing stands on the ground: at the rock's base, and at y = 0 under the lifted cliff.
	assert_float(rock_dressing.position.y).is_equal_approx(-0.8, 0.001)
	assert_float(cliff.position.y + cliff_dressing.position.y).is_equal_approx(0.0, 0.001)
	assert_int(_blades(rock_dressing).multimesh.instance_count).is_greater(0)
