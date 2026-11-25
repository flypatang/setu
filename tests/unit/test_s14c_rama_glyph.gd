extends GdUnitTestSuite
## Acceptance tests for S14c: the राम inscription as a textured quad (render/rama_glyph.gd) and its use on the
## bridge stones (render/bridge_view.gd). Headless and deterministic.

const BRIDGE_PATH: String = "res://sim/bridge.gd"
const VIEW_PATH: String = "res://render/bridge_view.gd"
const STOCKPILE_PATH: String = "res://sim/stockpile.gd"


func _complete_view(sections: int) -> BridgeView:
	var view: BridgeView = auto_free((load(VIEW_PATH) as GDScript).new() as BridgeView)
	add_child(view)
	var stock: Stockpile = (load(STOCKPILE_PATH) as GDScript).new() as Stockpile
	stock.add("inscribed_stone", 4 * sections)
	stock.add("timber", 3 * sections)
	stock.add("rope", sections)
	var b: Bridge = (load(BRIDGE_PATH) as GDScript).new(stock, sections + 1) as Bridge
	for i: int in sections:
		b.step(i)
	view.sync(b)
	return view


func _glyphs(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		if child is MeshInstance3D and child.name.begins_with("Glyph"):
			out.append(child as MeshInstance3D)
	return out


func test_texture_has_requested_width_and_is_cached() -> void:
	var tex: Texture2D = RamaGlyph.texture(256)
	assert_int(tex.get_width()).is_equal(256)
	assert_int(tex.get_height()).is_equal(roundi(256.0 / RamaGlyph.ASPECT))
	assert_bool(is_same(tex, RamaGlyph.texture(256))).is_true()
	assert_int(RamaGlyph.texture(128).get_width()).is_equal(128)


func test_texture_is_sindoor_ink_on_transparent_background() -> void:
	var img: Image = RamaGlyph.image(256)
	assert_float(img.get_pixel(0, 0).a).is_equal_approx(0.0, 0.001)
	assert_float(img.get_pixel(img.get_width() - 1, img.get_height() - 1).a).is_equal_approx(0.0, 0.001)
	var inked: int = 0
	var total: int = img.get_width() * img.get_height()
	var tint_ok: bool = true
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.9:
				inked += 1
				if c.r < 0.6 or c.g > 0.3 or c.b > 0.4:
					tint_ok = false
	assert_bool(tint_ok).is_true()
	# Bold three-letter word: a sizeable but minority share of the image is ink.
	assert_int(inked).is_greater(total / 6)
	assert_int(inked).is_less(total / 2)


func test_texture_reads_as_rama_headline_and_three_letters() -> void:
	var img: Image = RamaGlyph.image(256)
	var w: int = img.get_width()
	var h: int = img.get_height()
	# The shirorekha: some row in the upper half is inked across almost the whole word width.
	var best: int = 0
	for y: int in h / 2:
		var run: int = 0
		for x: int in w:
			if img.get_pixel(x, y).a > 0.5:
				run += 1
		best = maxi(best, run)
	assert_int(best).is_greater(int(float(w) * 0.8))
	# Below the headline the word splits into separate strokes: a row under the headline has several ink runs.
	var y_low: int = int(float(h) * 0.58)
	var runs: int = 0
	var prev: bool = false
	for x: int in w:
		var on: bool = img.get_pixel(x, y_low).a > 0.5
		if on and not prev:
			runs += 1
		prev = on
	assert_int(runs).is_greater_equal(2)
	# The texture has a blank margin all round (top-left corner pixel is transparent).
	assert_float(img.get_pixel(w / 2, 1).a).is_equal_approx(0.0, 0.001)


func test_edge_is_brushed_not_binary() -> void:
	var img: Image = RamaGlyph.image(256)
	var partial: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var a: float = img.get_pixel(x, y).a
			if a > 0.05 and a < 0.95:
				partial += 1
	assert_int(partial).is_greater(200)


func test_mesh_is_flat_quad_with_uvs_and_material_uses_texture() -> void:
	var m: ArrayMesh = RamaGlyph.quad(1.2, Palette.SINDOOR)
	var arrays: Array = m.surface_get_arrays(0)
	assert_int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal(4)
	assert_int((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size()).is_equal(4)
	assert_float(m.get_aabb().size.y).is_equal_approx(1.2, 0.001)
	assert_float(m.get_aabb().size.x).is_equal_approx(1.2 * RamaGlyph.ASPECT, 0.001)
	assert_float(m.get_aabb().size.z).is_equal_approx(0.0, 0.0001)
	var mat: StandardMaterial3D = RamaGlyph.material()
	assert_bool(is_same(mat, RamaGlyph.material())).is_true()
	assert_bool(mat.albedo_texture != null).is_true()
	assert_int(mat.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(mat.transparency).is_not_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)


func test_bridge_glyphs_use_textured_quad_about_1_2_m_wide() -> void:
	var view: BridgeView = _complete_view(1)
	var glyphs: Array[MeshInstance3D] = _glyphs(view.get_section_root(0))
	assert_int(glyphs.size()).is_equal(4)
	for g: MeshInstance3D in glyphs:
		assert_float((g.mesh as Mesh).get_aabb().size.x).is_equal_approx(1.2, 0.05)
		assert_bool(g.material_override == RamaGlyph.material()).is_true()


func test_bridge_glyph_reads_upright_from_the_iso_camera() -> void:
	var view: BridgeView = _complete_view(1)
	var g: MeshInstance3D = _glyphs(view.get_section_root(0))[0]
	# Default iso camera: yaw 45, so screen-right on the ground is (cos45, 0, -sin45) and screen-up is away from it.
	var cam: Basis = Basis(Vector3.UP, deg_to_rad(45.0))
	var right: Vector3 = cam * Vector3.RIGHT
	var away: Vector3 = cam * Vector3.FORWARD
	var text_right: Vector3 = g.transform.basis * Vector3.RIGHT
	var text_up: Vector3 = g.transform.basis * Vector3.UP
	var normal: Vector3 = g.transform.basis * Vector3.BACK
	assert_float(text_right.dot(right)).is_equal_approx(1.0, 0.001)
	assert_float(text_up.dot(away)).is_equal_approx(1.0, 0.001)
	assert_float(normal.y).is_equal_approx(1.0, 0.001)


func test_glyphs_of_neighbouring_sections_do_not_overlap() -> void:
	var view: BridgeView = _complete_view(3)
	assert_int(_glyphs(view.get_section_root(1)).size()).is_equal(0)
	var g0: MeshInstance3D = _glyphs(view.get_section_root(0))[0]
	var g2: MeshInstance3D = _glyphs(view.get_section_root(2))[0]
	var a: AABB = g0.transform * (g0.mesh as Mesh).get_aabb()
	var b: AABB = g2.transform * (g2.mesh as Mesh).get_aabb()
	assert_bool(view.get_section_root(0).position.x + a.end.x <= view.get_section_root(2).position.x + b.position.x).is_true()


func test_deck_planks_leave_stones_exposed() -> void:
	var view: BridgeView = _complete_view(1)
	var root: Node3D = view.get_section_root(0)
	var outer_stones: int = 0
	for child: Node in root.get_children():
		if child.name.begins_with("Stone") and absf((child as Node3D).position.z) > 1.5:
			outer_stones += 1
		if child.name.begins_with("Plank"):
			var box: AABB = (child as MeshInstance3D).transform * ((child as MeshInstance3D).mesh as Mesh).get_aabb()
			assert_float(box.size.z).is_less_equal(3.01)
	assert_int(outer_stones).is_equal(2)
