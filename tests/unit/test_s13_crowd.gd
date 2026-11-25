extends GdUnitTestSuite
## Acceptance tests for S13 (render/crowd.gd, render/rama_glyph.gd), DESIGN §9.


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


func test_instance_count_follows_routes() -> void:
	var crowd: CrowdView = _crowd()
	var flow: DayFlow = _flow(20, "stone", 5)
	crowd.sync(flow)
	assert_int(crowd.vanara_count()).is_equal(20)
	assert_int(crowd.item_count(&"stone")).is_equal(20)
	assert_int(crowd.item_count(&"inscribed_stone")).is_equal(0)
	assert_int(crowd.item_count(&"timber")).is_equal(0)


func test_no_items_when_source_empty() -> void:
	var crowd: CrowdView = _crowd()
	var flow: DayFlow = _flow(10, "stone", 0)
	crowd.sync(flow)
	assert_int(crowd.vanara_count()).is_equal(10)
	assert_int(crowd.item_count(&"stone")).is_equal(0)


func test_timber_and_inscribed_counts() -> void:
	var crowd: CrowdView = _crowd()
	crowd.sync(_flow(7, "timber", 3))
	assert_int(crowd.item_count(&"timber")).is_equal(7)
	crowd.sync(_flow(9, "inscribed_stone", 3))
	assert_int(crowd.item_count(&"inscribed_stone")).is_equal(9)
	assert_int(crowd.item_count(&"timber")).is_equal(0)


func test_budget_capped_at_2000() -> void:
	var crowd: CrowdView = _crowd()
	crowd.sync(_flow(2500, "stone", 5))
	assert_int(crowd.vanara_count()).is_equal(CrowdView.MAX_INSTANCES)


func test_sync_does_not_write_sim() -> void:
	var crowd: CrowdView = _crowd()
	var flow: DayFlow = _flow(12, "stone", 5)
	var before: String = flow.state_hash()
	crowd.sync(flow)
	assert_str(flow.state_hash()).is_equal(before)


func test_instances_move_with_tick() -> void:
	var crowd: CrowdView = _crowd()
	var flow: DayFlow = _flow(4, "stone", 50)
	crowd.sync(flow)
	var a: Vector3 = crowd.vanara_position(0)
	flow.run_ticks(40)
	crowd.sync(flow)
	assert_bool(crowd.vanara_position(0).is_equal_approx(a)).is_false()


func test_inscribed_stone_gets_a_textured_glyph_quad() -> void:
	var crowd: CrowdView = _crowd()
	crowd.sync(_flow(9, "inscribed_stone", 3))
	assert_int(crowd.item_count(&"inscribed_stone")).is_equal(9)
	assert_int(crowd.glyph_count()).is_equal(9)
	var gmi: MultiMeshInstance3D = crowd.get_node("InscribedGlyphs") as MultiMeshInstance3D
	assert_object(gmi).is_not_null()
	assert_bool(gmi.material_override == RamaGlyph.material()).is_true()
	crowd.sync(_flow(5, "stone", 3))
	assert_int(crowd.glyph_count()).is_equal(0)


func test_vanara_mesh_is_low_detail() -> void:
	var crowd: CrowdView = _crowd()
	var v: int = (crowd.vanara_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_int(v / 3).is_less(300)
	assert_int(v / 3).is_greater(60)


func test_glyph_mesh_is_a_flat_quad_with_uvs() -> void:
	var mesh: ArrayMesh = RamaGlyph.mesh(1.0, Palette.GOLD)
	assert_int(mesh.get_surface_count()).is_equal(1)
	var arrays: Array = mesh.surface_get_arrays(0)
	assert_int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal(4)
	assert_int((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size()).is_equal(4)
	assert_float(mesh.get_aabb().size.z).is_equal_approx(0.0, 0.0001)


func test_glyph_scales_with_height() -> void:
	var small: AABB = RamaGlyph.mesh(0.5, Palette.GOLD).get_aabb()
	var big: AABB = RamaGlyph.mesh(1.0, Palette.GOLD).get_aabb()
	assert_float(big.size.y).is_equal_approx(small.size.y * 2.0, 0.001)
	assert_float(big.size.y).is_equal_approx(1.0, 0.001)
