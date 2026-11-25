extends GdUnitTestSuite
## Art-pass acceptance tests for A1 (gen/hanuman_model.gd): heroic temple-sculpture proportions.


func _live_model() -> HanumanModel:
	var model: HanumanModel = auto_free(HanumanModel.new()) as HanumanModel
	model.build()
	add_child(model)
	await get_tree().process_frame
	return model


func _world_box(mesh_instance: MeshInstance3D) -> AABB:
	return mesh_instance.global_transform * (mesh_instance.mesh as ArrayMesh).get_aabb()


func _mesh_colour(mesh_instance: MeshInstance3D) -> Color:
	var arrays: Array = (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[0]


## Meshes of the given colour whose names start with the prefix.
func _parts(model: HanumanModel, prefix: String, colour: Color) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children(prefix + "*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if _mesh_colour(mesh_instance).is_equal_approx(colour):
			result.append(mesh_instance)
	return result


func _merged(items: Array[MeshInstance3D]) -> AABB:
	var box: AABB = _world_box(items[0])
	for item: MeshInstance3D in items:
		box = box.merge(_world_box(item))
	return box


func _body_height(model: HanumanModel) -> float:
	var all: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if not (node as Node).name.begins_with("gada_socket"):
			all.append(node as MeshInstance3D)
	return _merged(all).size.y


func test_crown_has_five_gold_points() -> void:
	var model: HanumanModel = await _live_model()
	var cones: int = 0
	for item: MeshInstance3D in _parts(model, "head_part_", Palette.GOLD):
		if _world_box(item).size.y > 0.12:
			cones += 1
	assert_int(cones).is_equal(5)


func test_height_with_crown_between_1_7_and_1_9() -> void:
	var model: HanumanModel = await _live_model()
	var height: float = _body_height(model)
	assert_bool(height >= 1.7 and height <= 1.9).is_true()


func test_shoulders_are_about_2_2_head_widths() -> void:
	var model: HanumanModel = await _live_model()
	var skull: MeshInstance3D = model.find_child("head_part_0", true, false) as MeshInstance3D
	var head_width: float = _world_box(skull).size.x
	var shoulders: AABB = _merged(_parts(model, "chest_part_", Palette.HANUMAN_FUR))
	var ratio: float = shoulders.size.x / head_width
	assert_bool(ratio >= 2.0 and ratio <= 2.8).is_true()


func test_head_is_about_one_sixth_of_height() -> void:
	var model: HanumanModel = await _live_model()
	var skull: MeshInstance3D = model.find_child("head_part_0", true, false) as MeshInstance3D
	var ratio: float = _world_box(skull).size.y / _body_height(model)
	assert_bool(ratio >= 0.15 and ratio <= 0.2).is_true()


func test_muzzle_is_sindoor_and_protrudes_from_skull() -> void:
	var model: HanumanModel = await _live_model()
	var muzzle: MeshInstance3D = model.find_child("head_part_1", true, false) as MeshInstance3D
	var skull: MeshInstance3D = model.find_child("head_part_0", true, false) as MeshInstance3D
	assert_bool(_mesh_colour(muzzle).is_equal_approx(Palette.SINDOOR)).is_true()
	assert_bool(_world_box(muzzle).position.z < _world_box(skull).position.z - 0.04).is_true()


func test_dhoti_is_saffron_and_wide() -> void:
	var model: HanumanModel = await _live_model()
	var cloth: AABB = _merged(_parts(model, "hips_part_", Palette.SAFFRON))
	assert_bool(cloth.size.x > 0.45).is_true()
	assert_bool(cloth.size.y > 0.3).is_true()


func test_gold_armlets_and_wristbands_on_both_arms() -> void:
	var model: HanumanModel = await _live_model()
	for bone: String in ["upper_arm_l", "upper_arm_r", "lower_arm_l", "lower_arm_r"]:
		assert_int(_parts(model, bone + "_part_", Palette.GOLD).size()).is_greater_equal(1)


func test_thighs_and_upper_arms_are_thick() -> void:
	var model: HanumanModel = await _live_model()
	var thigh: MeshInstance3D = model.find_child("upper_leg_l_part_0", true, false) as MeshInstance3D
	var arm: MeshInstance3D = model.find_child("upper_arm_l_part_0", true, false) as MeshInstance3D
	assert_bool(_world_box(thigh).size.x >= 0.17).is_true()
	assert_bool(_world_box(arm).size.x >= 0.14).is_true()


func test_tail_tip_is_raised_above_hips() -> void:
	var model: HanumanModel = await _live_model()
	var tip: Node3D = model.find_child("Attach_tail_7", true, false) as Node3D
	var base: Node3D = model.find_child("Attach_tail_0", true, false) as Node3D
	assert_bool(tip.global_position.y > base.global_position.y + 0.4).is_true()


func test_gada_head_is_about_as_wide_as_the_head() -> void:
	var model: HanumanModel = await _live_model()
	var skull: MeshInstance3D = model.find_child("head_part_0", true, false) as MeshInstance3D
	var head_width: float = _world_box(skull).size.x
	var club: MeshInstance3D = model.find_child("gada_socket_part_1", true, false) as MeshInstance3D
	assert_bool(_mesh_colour(club).is_equal_approx(Palette.GOLD)).is_true()
	var ratio: float = _world_box(club).size.x / head_width
	assert_bool(ratio >= 0.8 and ratio <= 1.3).is_true()


func test_chest_is_lighter_than_body_fur() -> void:
	var model: HanumanModel = await _live_model()
	var plate: MeshInstance3D = model.find_child("chest_part_1", true, false) as MeshInstance3D
	assert_bool(_mesh_colour(plate).get_luminance() > Palette.HANUMAN_FUR.get_luminance()).is_true()
