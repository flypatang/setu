extends GdUnitTestSuite
## Acceptance tests for S41 (bridge art v2, docs/ART.md): rounded boulders with smooth normals in the Materials
## stone, wet near the waterline, foam where they meet the water, a wooden walkway with rope lashings, a brush-painted
## SINDOOR glyph and a golden Vfx shimmer for blessed sections. Headless and deterministic.

const BRIDGE_PATH: String = "res://sim/bridge.gd"
const VIEW_PATH: String = "res://render/bridge_view.gd"
const STOCKPILE_PATH: String = "res://sim/stockpile.gd"


func _bridge(sections: int) -> Bridge:
	var stock: Stockpile = (load(STOCKPILE_PATH) as GDScript).new() as Stockpile
	stock.add("inscribed_stone", 4 * sections)
	stock.add("timber", 3 * sections)
	stock.add("rope", sections)
	var b: Bridge = (load(BRIDGE_PATH) as GDScript).new(stock, sections + 1) as Bridge
	for i: int in sections:
		b.step(i)
	return b


func _view(b: Bridge) -> BridgeView:
	var view: BridgeView = auto_free((load(VIEW_PATH) as GDScript).new() as BridgeView)
	add_child(view)
	view.sync(b)
	return view


func _parts(root: Node3D, prefix: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi != null and mi.name.begins_with(prefix):
			out.append(mi)
	return out


func _material_of(mi: MeshInstance3D) -> Material:
	if mi.material_override != null:
		return mi.material_override
	return (mi.mesh as ArrayMesh).surface_get_material(0)


func _luma(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


func test_stones_are_rounded_boulders_with_smooth_normals() -> void:
	var view: BridgeView = _view(_bridge(1))
	var stone: MeshInstance3D = _parts(view.get_section_root(0), "Stone")[0]
	var arrays: Array = (stone.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	assert_int(verts.size() / 3).is_greater(100)
	assert_int(verts.size() / 3).is_less(400)
	# Smooth shading: the same position always carries the same normal, and many normals are off-axis.
	var seen: Dictionary = {}
	var smooth: bool = true
	var off_axis: int = 0
	for i: int in verts.size():
		var key: Vector3i = Vector3i((verts[i] * 1000.0).round())
		if seen.has(key):
			if not (seen[key] as Vector3).is_equal_approx(norms[i]):
				smooth = false
		else:
			seen[key] = norms[i]
		var n: Vector3 = norms[i].abs()
		if maxf(n.x, maxf(n.y, n.z)) < 0.97:
			off_axis += 1
	assert_bool(smooth).is_true()
	assert_int(off_axis).is_greater(verts.size() / 3)


func test_stone_top_is_flat_for_the_glyph() -> void:
	var view: BridgeView = _view(_bridge(1))
	var stone: MeshInstance3D = _parts(view.get_section_root(0), "Stone")[0]
	var verts: PackedVector3Array = (stone.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var on_top: int = 0
	for v: Vector3 in verts:
		assert_float(v.y).is_less_equal(BridgeView.STONE_HEIGHT + 0.0001)
		if absf(v.y - BridgeView.STONE_HEIGHT) < 0.0001:
			on_top += 1
	assert_int(on_top).is_greater(12)


func test_stones_are_irregular_several_shapes_are_used() -> void:
	var view: BridgeView = _view(_bridge(6))
	var meshes: Dictionary = {}
	for i: int in 6:
		for stone: MeshInstance3D in _parts(view.get_section_root(i), "Stone"):
			meshes[stone.mesh.get_instance_id()] = true
	assert_int(meshes.size()).is_greater_equal(3)
	# Shapes are shared, not rebuilt per stone.
	assert_int(meshes.size()).is_less_equal(BridgeView.STONE_VARIANTS)


func test_stones_use_the_painterly_stone_material() -> void:
	var view: BridgeView = _view(_bridge(1))
	for stone: MeshInstance3D in _parts(view.get_section_root(0), "Stone"):
		assert_bool(_material_of(stone) == Materials.get_material(&"stone")).is_true()


func test_stones_darken_towards_the_waterline() -> void:
	var view: BridgeView = _view(_bridge(1))
	var stone: MeshInstance3D = _parts(view.get_section_root(0), "Stone")[0]
	var arrays: Array = (stone.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var top: float = 0.0
	var top_n: int = 0
	var wet: float = 0.0
	var wet_n: int = 0
	for i: int in verts.size():
		if verts[i].y > 0.6:
			top += _luma(cols[i])
			top_n += 1
		elif verts[i].y < BridgeView.WATER_Y + 0.1:
			wet += _luma(cols[i])
			wet_n += 1
	assert_int(top_n).is_greater(0)
	assert_int(wet_n).is_greater(0)
	assert_float(wet / float(wet_n)).is_less(top / float(top_n) * 0.8)


func test_each_stone_has_foam_at_the_waterline() -> void:
	var view: BridgeView = _view(_bridge(1))
	for stone: MeshInstance3D in _parts(view.get_section_root(0), "Stone"):
		var foam: MeshInstance3D = stone.get_node_or_null("Foam") as MeshInstance3D
		assert_object(foam).is_not_null()
		assert_bool(_material_of(foam) == Materials.get_material(&"water_edge")).is_true()
		var box: AABB = foam.transform * (foam.mesh as Mesh).get_aabb()
		assert_float(box.position.y).is_greater(BridgeView.WATER_Y - 0.1)
		assert_float(box.end.y).is_less(BridgeView.WATER_Y + 0.3)
		# The foam ring reaches a little beyond the stone's footprint.
		assert_float(box.size.z).is_greater(BridgeView.STONE_WIDTH + 0.2)
		assert_float(box.size.z).is_less(BridgeView.STONE_WIDTH + 1.2)


func test_walkway_is_wood_and_bound_with_rope() -> void:
	var view: BridgeView = _view(_bridge(1))
	var root: Node3D = view.get_section_root(0)
	for plank: MeshInstance3D in _parts(root, "Plank"):
		assert_bool(_material_of(plank) == Materials.get_material(&"wood")).is_true()
	for lashing: MeshInstance3D in _parts(root, "Lashing"):
		assert_object(_material_of(lashing)).is_not_null()
		var cols: PackedColorArray = (lashing.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		var rope: int = 0
		for c: Color in cols:
			if absf(c.r - Palette.ROPE.r) < 0.12 and absf(c.g - Palette.ROPE.g) < 0.12 and absf(c.b - Palette.ROPE.b) < 0.12:
				rope += 1
		assert_int(rope).is_greater(cols.size() / 3)
		# The rope runs the whole length of the section so neighbouring sections join up.
		var box: AABB = lashing.transform * (lashing.mesh as Mesh).get_aabb()
		assert_float(box.size.x).is_greater_equal(BridgeView.SECTION_LENGTH - 0.02)


func test_blessed_section_shimmer_is_a_golden_particle_effect() -> void:
	var b: Bridge = _bridge(1)
	var view: BridgeView = _view(b)
	b.bless_all_complete()
	view.sync(b)
	assert_bool(view.has_shimmer(0)).is_true()
	var shimmer: Node3D = view.get_node_or_null("Shimmer0") as Node3D
	assert_object(shimmer).is_not_null()
	var particles: int = 0
	for child: Node in shimmer.get_children():
		if child is GPUParticles3D:
			particles += 1
			var quad: Mesh = (child as GPUParticles3D).draw_pass_1
			assert_object(quad).is_not_null()
			var mat: ShaderMaterial = (quad as PrimitiveMesh).material as ShaderMaterial
			assert_object(mat).is_not_null()
			assert_bool(mat.shader == Vfx.shader(Vfx.MODE_ADD, true)).is_true()
	assert_int(particles).is_greater_equal(1)
	# It sits over the section it blesses.
	assert_float(shimmer.position.x).is_equal_approx(BridgeView.SECTION_CENTER_X, 0.001)


func test_glyph_paint_has_brush_tone_and_stays_sindoor() -> void:
	var img: Image = RamaGlyph.image(256)
	var lo: float = 1.0
	var hi: float = 0.0
	var inked: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.9:
				inked += 1
				lo = minf(lo, c.r)
				hi = maxf(hi, c.r)
				# Still the SINDOOR hue: red dominant, never brown or pink.
				assert_bool(c.r > c.g * 3.0 and c.r > c.b * 2.0).is_true()
	# Pigment pools and dry-brush streaks give the ink visible tonal range (it is not one flat colour).
	assert_float(hi - lo).is_greater(0.08)
	assert_float(hi).is_equal_approx(Palette.SINDOOR.r, 0.02)
	# Bold enough to read from the default camera: a quarter of the texture is ink.
	assert_int(inked).is_greater(img.get_width() * img.get_height() / 4)
