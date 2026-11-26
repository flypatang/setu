extends GdUnitTestSuite
## Acceptance tests for S41 (crowd art v2, docs/ART.md): a low-detail vanara in the v2 Hanuman style (about 300
## triangles, fur and saffron cloth, a tail), per-instance variety, a carry animation in the vertex shader and
## visible carried stones and timber. Headless and deterministic.


func _flow(haulers: int, kind: String, stock: int) -> DayFlow:
	var flow: DayFlow = DayFlow.new()
	var d: Dictionary = {
		"day": 1, "target_yojanas": 2, "day_ticks": 400, "total_crews": 300,
		"piles": [
			{"id": "quarry", "role": "cutter", "pos": [-60.0, 0.0], "stock": {kind: stock}},
			{"id": "head", "role": "builder", "pos": [0.0, 0.0], "stock": {}},
		],
	}
	flow.load_day(d)
	var ok: bool = flow.apply_command({"tick": 0, "type": "draw_route", "args": {
		"id": "r1", "from": "quarry", "to": "head", "kind": kind, "haulers": haulers,
		"points": [[-60.0, 0.0], [-30.0, 10.0], [0.0, 0.0]]}})
	assert_bool(ok).is_true()
	return flow


func _crowd() -> CrowdView:
	var crowd: CrowdView = auto_free(CrowdView.new()) as CrowdView
	add_child(crowd)
	return crowd


func _vanara_mmi(crowd: CrowdView) -> MultiMeshInstance3D:
	return crowd.get_node("Vanaras") as MultiMeshInstance3D


func _close(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol


func test_vanara_is_about_300_triangles_with_limb_data() -> void:
	var crowd: CrowdView = _crowd()
	var arrays: Array = crowd.vanara_mesh().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	assert_int(verts.size() / 3).is_between(240, 360)
	assert_int(uvs.size()).is_equal(verts.size())
	# Every animated limb is present: body 0, arms 1 and 2, legs 3 and 4, tail 5.
	var limbs: Dictionary = {}
	for uv: Vector2 in uvs:
		limbs[roundi(uv.x)] = true
	for limb: int in 6:
		assert_bool(limbs.has(limb)).is_true()


func test_vanara_has_fur_saffron_cloth_and_a_tail_behind() -> void:
	var crowd: CrowdView = _crowd()
	var arrays: Array = crowd.vanara_mesh().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var fur: int = 0
	var saffron: int = 0
	var tail_back: float = 0.0
	var tail_top: float = 0.0
	for i: int in verts.size():
		if _close(cols[i], Palette.HANUMAN_FUR, 0.02):
			fur += 1
		if _close(cols[i], Palette.SAFFRON, 0.02):
			saffron += 1
		if roundi(uvs[i].x) == CrowdView.LIMB_TAIL:
			tail_back = maxf(tail_back, verts[i].z)
			tail_top = maxf(tail_top, verts[i].y)
	assert_int(fur).is_greater(verts.size() / 4)
	assert_int(saffron).is_greater(30)
	# The model faces -Z, so the tail trails towards +Z and curls up.
	assert_float(tail_back).is_greater(0.4)
	assert_float(tail_top).is_greater(0.9)
	# Feet on the ground, head at roughly 1.5 m.
	var box: AABB = crowd.vanara_mesh().get_aabb()
	assert_float(box.position.y).is_equal_approx(0.0, 0.03)
	assert_float(box.end.y).is_between(1.35, 1.75)


func test_vanara_normals_are_smooth_on_the_body() -> void:
	var crowd: CrowdView = _crowd()
	var norms: PackedVector3Array = crowd.vanara_mesh().surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var distinct: Dictionary = {}
	for n: Vector3 in norms:
		distinct[Vector3i((n * 50.0).round())] = true
	# A flat-shaded 300 triangle mesh of boxes has a few dozen normals; smooth limbs give many more.
	assert_int(distinct.size()).is_greater(60)


func test_shader_animates_the_carry_in_the_vertex_stage() -> void:
	var crowd: CrowdView = _crowd()
	var mmi: MultiMeshInstance3D = _vanara_mmi(crowd)
	var mat: ShaderMaterial = mmi.material_override as ShaderMaterial
	assert_object(mat).is_not_null()
	var code: String = mat.shader.code
	var vertex_stage: String = code.substr(code.find("void vertex()"), code.find("void fragment()") - code.find("void vertex()"))
	assert_bool(vertex_stage.contains("INSTANCE_CUSTOM")).is_true()
	assert_bool(vertex_stage.contains("TIME")).is_true()
	assert_bool(vertex_stage.contains("carry")).is_true()
	assert_bool(mmi.multimesh.use_custom_data).is_true()


func test_carrying_flag_follows_the_source_pile() -> void:
	var crowd: CrowdView = _crowd()
	crowd.sync(_flow(6, "stone", 5))
	for i: int in 6:
		assert_bool(crowd.vanara_carrying(i)).is_true()
	crowd.sync(_flow(6, "stone", 0))
	for i: int in 6:
		assert_bool(crowd.vanara_carrying(i)).is_false()


func test_vanaras_vary_in_size_and_tone() -> void:
	var crowd: CrowdView = _crowd()
	crowd.sync(_flow(24, "stone", 5))
	var scales: Dictionary = {}
	var seeds: Dictionary = {}
	for i: int in 24:
		var s: float = crowd.vanara_size(i)
		assert_float(s).is_between(0.85, 1.15)
		scales[roundi(s * 100.0)] = true
		assert_float(crowd.vanara_variety(i)).is_between(0.0, 1.0)
		seeds[roundi(crowd.vanara_variety(i) * 1000.0)] = true
	assert_int(scales.size()).is_greater(4)
	assert_int(seeds.size()).is_greater(12)


func test_carried_item_is_held_above_its_vanara() -> void:
	var crowd: CrowdView = _crowd()
	crowd.sync(_flow(5, "timber", 9))
	assert_int(crowd.item_count(&"timber")).is_equal(5)
	for i: int in 5:
		var item: Vector3 = crowd.item_position(&"timber", i)
		var carrier: Vector3 = crowd.vanara_position(i)
		assert_float(item.y - carrier.y).is_between(1.3, 2.1)
		assert_float(Vector2(item.x - carrier.x, item.z - carrier.z).length()).is_less(0.5)


func test_carried_stone_and_timber_are_visible_shapes() -> void:
	var crowd: CrowdView = _crowd()
	var stone: AABB = crowd.item_mesh(&"stone").get_aabb()
	var timber: AABB = crowd.item_mesh(&"timber").get_aabb()
	# Big enough to read at the default zoom: a stone about half a metre, a log over a metre long.
	assert_float(stone.get_longest_axis_size()).is_between(0.45, 0.9)
	assert_float(stone.size.y).is_greater(0.25)
	assert_float(timber.get_longest_axis_size()).is_between(1.0, 1.8)
	var tv: PackedVector3Array = crowd.item_mesh(&"timber").surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	assert_int(tv.size() / 3).is_between(12, 120)
	# The inscribed stone shows SINDOOR paint, the plain one does not.
	var sindoor: int = 0
	for c: Color in crowd.item_mesh(&"inscribed_stone").surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		if _close(c, Palette.SINDOOR, 0.02):
			sindoor += 1
	assert_int(sindoor).is_greater(0)
	for c: Color in crowd.item_mesh(&"stone").surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		assert_bool(_close(c, Palette.SINDOOR, 0.02)).is_false()
