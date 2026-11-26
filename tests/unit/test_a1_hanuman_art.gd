extends GdUnitTestSuite
## Art-pass acceptance tests for A1 (gen/hanuman_model.gd): heroic temple-sculpture proportions.
## Updated for the v2 rebuild (B1): parts are found by their Materials kind (surface name) instead of by one flat
## colour, and sizes are measured on the real vertices.


func _live_model() -> HanumanModel:
	var model: HanumanModel = auto_free(HanumanModel.new()) as HanumanModel
	model.animate = false
	model.build()
	add_child(model)
	await get_tree().process_frame
	return model


## World-space positions of the vertices of every part whose name starts with `prefix`, on surfaces of `kind`
## ("" = every kind) whose colour is `colour` (alpha 0 = any colour).
func _points(model: HanumanModel, prefix: String, kind: String = "", colour: Color = Color(0.0, 0.0, 0.0, 0.0)) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for node: Node in model.find_children(prefix + "*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
		for surface: int in range(mesh.get_surface_count()):
			if kind != "" and mesh.surface_get_name(surface) != kind:
				continue
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			for index: int in range(vertices.size()):
				if colour.a > 0.0 and not _same_rgb(colours[index], colour):
					continue
				result.append(mesh_instance.global_transform * vertices[index])
	return result


func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006


func _box(points: PackedVector3Array) -> AABB:
	var box: AABB = AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		box = box.expand(point)
	return box


func _first_colour(model: HanumanModel, part_name: String) -> Color:
	var mesh_instance: MeshInstance3D = model.find_child(part_name, true, false) as MeshInstance3D
	var arrays: Array = (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[0]


## Height of the body without the gada.
func _body_height(model: HanumanModel) -> float:
	var all: PackedVector3Array = PackedVector3Array()
	for bone_name: String in HanumanModel.BONE_NAMES:
		if bone_name != "gada_socket":
			all.append_array(_points(model, bone_name + "_part_"))
	return _box(all).size.y


func test_crown_has_a_central_spire_and_five_gold_points() -> void:
	## The mukuta: the spire on the centre line is its highest point, and points rise from the band at the front,
	## at both sides and at the back.
	var model: HanumanModel = await _live_model()
	var gold: PackedVector3Array = _points(model, "head_part_", "gold")
	var top: Vector3 = gold[0]
	for point: Vector3 in gold:
		if point.y > top.y:
			top = point
	var head: Vector3 = (model.find_child("Attach_head", true, false) as Node3D).global_position
	var head_y: float = head.y
	assert_bool(absf(top.x - head.x) < 0.02 and absf(top.z - head.z) < 0.02).is_true()
	var left: bool = false
	var right: bool = false
	var front: bool = false
	var back: bool = false
	for point: Vector3 in gold:
		if point.y < head_y + 0.27:
			continue
		left = left or point.x > 0.1
		right = right or point.x < -0.1
		front = front or point.z - head.z < -0.12
		back = back or point.z - head.z > 0.12
	assert_bool(left and right and front and back).is_true()
	## The crown stands at least 15 cm tall.
	assert_bool(_box(gold).end.y - (head_y + 0.18) > 0.15).is_true()


func test_height_with_crown_between_1_7_and_1_9() -> void:
	var model: HanumanModel = await _live_model()
	var height: float = _body_height(model)
	assert_bool(height >= 1.7 and height <= 1.9).is_true()


func test_shoulders_are_about_2_2_head_widths() -> void:
	## Shoulder width: the fur of the chest and of the upper arms, measured at shoulder height.
	var model: HanumanModel = await _live_model()
	var head_width: float = _box(_points(model, "head_part_0")).size.x
	var candidates: PackedVector3Array = _points(model, "chest_part_", "fur")
	candidates.append_array(_points(model, "upper_arm_", "fur"))
	var shoulders: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in candidates:
		if point.y > 1.45:
			shoulders.append(point)
	var ratio: float = _box(shoulders).size.x / head_width
	assert_bool(ratio >= 2.0 and ratio <= 2.8).is_true()


func test_head_is_about_one_sixth_of_height() -> void:
	var model: HanumanModel = await _live_model()
	var ratio: float = _box(_points(model, "head_part_0")).size.y / _body_height(model)
	assert_bool(ratio >= 0.15 and ratio <= 0.2).is_true()


func test_muzzle_is_sindoor_tinted_and_protrudes_from_skull() -> void:
	var model: HanumanModel = await _live_model()
	var muzzle: Color = _first_colour(model, "head_part_1")
	## The muzzle is skin tinted toward SINDOOR: redder than the skin of the face, never the raw marker red.
	assert_bool(_same_rgb(muzzle, HanumanModel.MUZZLE)).is_true()
	var skin: Color = HanumanModel.SKIN
	assert_bool(muzzle.r - muzzle.g > skin.r - skin.g).is_true()
	assert_bool(muzzle.g > Palette.SINDOOR.g).is_true()
	var muzzle_box: AABB = _box(_points(model, "head_part_1"))
	var skull_box: AABB = _box(_points(model, "head_part_0"))
	assert_bool(muzzle_box.position.z < skull_box.position.z - 0.02).is_true()


func test_dhoti_is_saffron_and_wide() -> void:
	var model: HanumanModel = await _live_model()
	var cloth: AABB = _box(_points(model, "hips_part_", "cloth", Palette.SAFFRON))
	assert_bool(cloth.size.x > 0.4).is_true()
	assert_bool(cloth.size.y > 0.3).is_true()
	## It is drawn round both thighs too.
	for bone: String in ["upper_leg_l", "upper_leg_r"]:
		assert_int(_points(model, bone + "_part_", "cloth").size()).is_greater(0)


func test_gold_armlets_and_wristbands_on_both_arms() -> void:
	var model: HanumanModel = await _live_model()
	for bone: String in ["upper_arm_l", "upper_arm_r", "lower_arm_l", "lower_arm_r"]:
		assert_int(_points(model, bone + "_part_", "gold", Palette.GOLD).size()).is_greater(0)


func test_thighs_and_upper_arms_are_thick() -> void:
	var model: HanumanModel = await _live_model()
	assert_bool(_box(_points(model, "upper_leg_l_part_0")).size.x >= 0.17).is_true()
	assert_bool(_box(_points(model, "upper_arm_l_part_0")).size.x >= 0.14).is_true()


func test_tail_tip_is_raised_above_hips() -> void:
	var model: HanumanModel = await _live_model()
	var tip: Node3D = model.find_child("Attach_tail_7", true, false) as Node3D
	var base: Node3D = model.find_child("Attach_tail_0", true, false) as Node3D
	assert_bool(tip.global_position.y > base.global_position.y + 0.3).is_true()
	var last: Node3D = model.find_child("Attach_tail_%d" % (HanumanModel.TAIL_BONES - 1), true, false) as Node3D
	assert_bool(last.global_position.y > base.global_position.y + 0.4).is_true()


func test_gada_head_is_about_as_wide_as_the_head() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"walk_a")
	model.get_skeleton().reset_bone_poses()
	await get_tree().process_frame
	var head_width: float = _box(_points(model, "head_part_0")).size.x
	assert_bool(_same_rgb(_first_colour(model, "gada_socket_part_1"), Palette.GOLD)).is_true()
	var ratio: float = _box(_points(model, "gada_socket_part_1")).size.x / head_width
	assert_bool(ratio >= 0.8 and ratio <= 1.3).is_true()


func test_chest_is_lighter_than_body_fur() -> void:
	var model: HanumanModel = await _live_model()
	assert_bool(_first_colour(model, "chest_part_1").get_luminance() > Palette.HANUMAN_FUR.get_luminance()).is_true()
