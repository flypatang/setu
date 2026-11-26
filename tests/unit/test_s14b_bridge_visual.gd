extends GdUnitTestSuite
# Acceptance tests for S14b (render/bridge_view.gd visual fix, DESIGN §9), updated for S14c and S41 (art v2): sections
# are 8 m wide along z and carry 4 foundation boulders of 1.5 m whose flat tops are at 0.9 m and whose feet are under
# water; the planks form a central walkway on top of the stones (narrow, so every glyph stays readable) with rope
# lashings at the edges; set_origin_x offsets the whole bridge. The glyph tests live in test_s14c_*.gd.
# Headless and deterministic: the view reads a Bridge built on a Stockpile.

const BRIDGE_PATH: String = "res://sim/bridge.gd"
const VIEW_PATH: String = "res://render/bridge_view.gd"
const STOCKPILE_PATH: String = "res://sim/stockpile.gd"
const TOL: float = 0.02


func _make_view() -> BridgeView:
	var view_script: GDScript = load(VIEW_PATH) as GDScript
	var view: BridgeView = auto_free(view_script.new() as BridgeView)
	add_child(view)
	return view


## A bridge whose first `sections` sections are complete (4 inscribed stones, 3 timber, 1 rope each).
func _complete_bridge(sections: int) -> Bridge:
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 4 * sections)
	stock.add("timber", 3 * sections)
	stock.add("rope", sections)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, sections + 1) as Bridge
	for i: int in sections:
		b.step(i)
	return b


## Union of the parts' bounding boxes, in the root's local space.
func _root_aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for child: Node in root.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null:
			continue
		var box: AABB = mi.transform * (mi.mesh as Mesh).get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


func _parts(root: Node3D, prefix: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi != null and mi.name.begins_with(prefix):
			out.append(mi)
	return out


func _part_aabb(mi: MeshInstance3D) -> AABB:
	return mi.transform * (mi.mesh as Mesh).get_aabb()


## Colour of the highest vertex of the part's first surface.
func _vertex_colour(mi: MeshInstance3D) -> Color:
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var best: int = 0
	for i: int in verts.size():
		if verts[i].y > verts[best].y:
			best = i
	return cols[best]


func test_section_is_eight_metres_wide() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	assert_object(root).is_not_null()
	assert_float(_root_aabb(root).size.z).is_equal_approx(7.8, 0.2)


func test_four_foundation_stones_across_a_complete_section() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	assert_int(_parts(root, "Stone").size()).is_equal(4)
	assert_int(_parts(root, "Glyph").size()).is_equal(4)


func test_each_stone_is_about_1_5_metres_wide() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	for stone: MeshInstance3D in _parts(view.get_section_root(0), "Stone"):
		assert_float(_part_aabb(stone).size.z).is_equal_approx(1.5, TOL)
		# The flat top is 0.9 m above the section origin; the foot is below the waterline.
		assert_float(_part_aabb(stone).end.y).is_equal_approx(0.9, TOL)
		assert_float(_part_aabb(stone).position.y).is_less(BridgeView.WATER_Y)


func test_each_stone_is_inside_the_eight_metre_section_footprint() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	for stone: MeshInstance3D in _parts(root, "Stone"):
		var box: AABB = _part_aabb(stone)
		assert_bool(box.position.z >= -4.0 - TOL and box.end.z <= 4.0 + TOL).is_true()


func test_every_stone_carries_a_glyph_on_its_top() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	var stones: Array[MeshInstance3D] = _parts(root, "Stone")
	var glyphs: Array[MeshInstance3D] = _parts(root, "Glyph")
	assert_int(glyphs.size()).is_equal(stones.size())
	for i: int in stones.size():
		var top: float = _part_aabb(stones[i]).end.y
		assert_float(glyphs[i].position.y).is_greater(top - TOL)
		assert_float(glyphs[i].position.z).is_equal_approx(stones[i].position.z, TOL)


func test_stones_are_wet_stone_and_glyphs_sindoor() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	var stone: MeshInstance3D = _parts(root, "Stone")[0]
	var glyph: MeshInstance3D = _parts(root, "Glyph")[0]
	# The dry top is WET_STONE, leaning a little warm or dark per boulder shape (S41).
	var top: Color = _vertex_colour(stone)
	assert_float(top.r).is_equal_approx(Palette.WET_STONE.r, 0.08)
	assert_float(top.g).is_equal_approx(Palette.WET_STONE.g, 0.08)
	assert_float(top.b).is_equal_approx(Palette.WET_STONE.b, 0.08)
	assert_bool(_vertex_colour(glyph).is_equal_approx(Palette.SINDOOR)).is_true()


func test_planks_form_a_central_walkway_on_top_of_the_stones() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var planks: Array[MeshInstance3D] = _parts(view.get_section_root(0), "Plank")
	assert_int(planks.size()).is_equal(3)
	for plank: MeshInstance3D in planks:
		var box: AABB = _part_aabb(plank)
		assert_float(box.size.z).is_equal_approx(BridgeView.PLANK_SIZE.z, 0.12)
		assert_float(box.size.z).is_less_equal(3.01)
		assert_float(plank.position.z).is_equal_approx(0.0, TOL)
		assert_float(box.get_center().z).is_equal_approx(0.0, 0.06)
		# The deck rests on the stone tops (it is not buried inside them).
		assert_float(box.position.y).is_greater_equal(BridgeView.STONE_HEIGHT - TOL)


func test_rope_lashings_sit_at_both_edges() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var lashings: Array[MeshInstance3D] = _parts(view.get_section_root(0), "Lashing")
	assert_int(lashings.size()).is_equal(2)
	var a: float = lashings[0].position.z
	var b: float = lashings[1].position.z
	assert_float(absf(a)).is_greater(3.5)
	assert_float(absf(b)).is_greater(3.5)
	assert_bool(signf(a) != signf(b)).is_true()


func test_partial_section_scales_stones_with_foundation() -> void:
	# 2 of 4 inscribed stones delivered = half the foundation, so 2 of the 4 stones show with their glyphs.
	var view: BridgeView = _make_view()
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 2)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, 2) as Bridge
	b.step(0)
	view.sync(b)
	var root: Node3D = view.get_section_root(0)
	assert_int(_parts(root, "Stone").size()).is_equal(2)
	assert_int(_parts(root, "Glyph").size()).is_equal(2)


func test_glyph_mesh_is_cached_across_sections() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(3))
	var g0: MeshInstance3D = _parts(view.get_section_root(0), "Glyph")[0]
	var g2: MeshInstance3D = _parts(view.get_section_root(2), "Glyph")[0]
	assert_bool(is_same(g0.mesh, g2.mesh)).is_true()


func test_set_origin_x_offsets_the_bridge() -> void:
	var view: BridgeView = _make_view()
	view.set_origin_x(20.0)
	view.sync(_complete_bridge(2))
	assert_float(view.get_section_root(0).position.x).is_equal_approx(20.0, 0.001)
	assert_float(view.get_section_root(1).position.x).is_equal_approx(21.0, 0.001)


func test_set_origin_x_moves_sections_already_built() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(2))
	view.set_origin_x(35.0)
	assert_float(view.get_section_root(0).position.x).is_equal_approx(35.0, 0.001)
	assert_float(view.get_section_root(1).position.x).is_equal_approx(36.0, 0.001)


func test_glyph_stays_on_its_stone_in_z_and_centred_in_x() -> void:
	var view: BridgeView = _make_view()
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	var stones: Array[MeshInstance3D] = _parts(root, "Stone")
	var glyphs: Array[MeshInstance3D] = _parts(root, "Glyph")
	for i: int in stones.size():
		var stone: AABB = _part_aabb(stones[i])
		var glyph: AABB = _part_aabb(glyphs[i])
		assert_bool(glyph.position.z >= stone.position.z - TOL and glyph.end.z <= stone.end.z + TOL).is_true()
		assert_float(glyph.get_center().x).is_equal_approx(stone.get_center().x, TOL)


func test_glyph_is_centred_on_its_stone_after_origin_offset() -> void:
	var view: BridgeView = _make_view()
	view.set_origin_x(12.0)
	view.sync(_complete_bridge(1))
	var root: Node3D = view.get_section_root(0)
	var stone: AABB = _part_aabb(_parts(root, "Stone")[0])
	var glyph: AABB = _part_aabb(_parts(root, "Glyph")[0])
	assert_float(root.position.x + glyph.get_center().x).is_equal_approx(root.position.x + stone.get_center().x, TOL)
	assert_float(root.position.x).is_equal_approx(12.0, 0.001)
