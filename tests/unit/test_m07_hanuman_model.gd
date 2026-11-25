extends GdUnitTestSuite
## Acceptance tests for M07 (gen/hanuman_model.gd), DESIGN §9 and §6.2.
## Bone names, height 1.7-1.9 m, palette colours only, and pose results checked in a live scene tree.
## Rigid parts only: no vertex skinning.

const REQUIRED_BONES: Array[String] = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	"tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7",
	"gada_socket",
]

const ALL_POSES: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike", &"meditate"]


func _model() -> HanumanModel:
	var model: HanumanModel = auto_free(HanumanModel.new()) as HanumanModel
	model.build()
	return model


## A model added to the scene tree, with one frame processed so BoneAttachment3D nodes and meshes have world transforms.
func _live_model() -> HanumanModel:
	var model: HanumanModel = _model()
	add_child(model)
	await get_tree().process_frame
	return model


func _mesh_instances(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result


## World-space bounds of every mesh, from the live global transforms (the model must be in the tree).
func _live_bounds(model: HanumanModel) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		var local_box: AABB = (mesh_instance.mesh as ArrayMesh).get_aabb()
		var world_box: AABB = mesh_instance.global_transform * local_box
		if first:
			bounds = world_box
			first = false
		else:
			bounds = bounds.merge(world_box)
	return bounds


func _attachment_y(model: HanumanModel, bone_name: String) -> float:
	var attachment: Node3D = model.find_child("Attach_" + bone_name, true, false) as Node3D
	return attachment.global_position.y


func _attachment_z(model: HanumanModel, bone_name: String) -> float:
	var attachment: Node3D = model.find_child("Attach_" + bone_name, true, false) as Node3D
	return attachment.global_position.z


func test_build_returns_node3d_with_skeleton() -> void:
	var model: HanumanModel = _model()
	var root: Node3D = model.build()
	assert_object(root).is_not_null()
	assert_object(model.get_skeleton()).is_not_null()


func test_build_twice_keeps_one_rig() -> void:
	var model: HanumanModel = _model()
	var count_before: int = model.get_skeleton().get_bone_count()
	model.build()
	assert_int(model.get_skeleton().get_bone_count()).is_equal(count_before)
	assert_int(model.find_children("Skeleton3D", "Skeleton3D", false, false).size()).is_equal(1)


func test_all_required_bones_exist() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	for bone_name: String in REQUIRED_BONES:
		assert_int(skeleton.find_bone(bone_name)).is_greater_equal(0)
	assert_int(skeleton.get_bone_count()).is_equal(REQUIRED_BONES.size())


func test_one_bone_attachment_per_bone() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var attachments: int = 0
	for child: Node in skeleton.get_children():
		if child is BoneAttachment3D:
			attachments += 1
	assert_int(attachments).is_equal(skeleton.get_bone_count())


func test_height_is_between_1_7_and_1_9_metres_at_idle() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"idle")
	await get_tree().process_frame
	var height: float = _live_bounds(model).size.y
	assert_bool(height >= 1.7 and height <= 1.9).is_true()


func test_feet_touch_the_ground_at_y_zero_at_idle() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"idle")
	await get_tree().process_frame
	assert_float(_live_bounds(model).position.y).is_equal_approx(0.0, 0.01)


func test_head_stays_at_1_54_in_every_pose() -> void:
	## The head bone is above the chest, and the chest pivot sits at the spine. The head height (1.54 m) holds in every pose.
	var model: HanumanModel = await _live_model()
	for pose: StringName in ALL_POSES:
		model.set_pose(pose)
		await get_tree().process_frame
		assert_float(_attachment_y(model, "head")).is_equal_approx(1.54, 0.05)


func test_idle_leaves_bones_at_rest() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"meditate")
	await get_tree().process_frame
	model.set_pose(&"idle")
	await get_tree().process_frame
	var skeleton: Skeleton3D = model.get_skeleton()
	var idle_table: Dictionary = HanumanModel.POSES["idle"] as Dictionary
	for index: int in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(index)
		## In Godot 4 the pose is the full local transform, so a bone at rest has a pose origin equal to its rest origin.
		assert_bool(skeleton.get_bone_pose_position(index).is_equal_approx(skeleton.get_bone_rest(index).origin)).is_true()
		if not idle_table.has(bone_name):
			assert_bool(skeleton.get_bone_pose_rotation(index).is_equal_approx(Quaternion.IDENTITY)).is_true()
	assert_float(_attachment_y(model, "lower_leg_l")).is_equal_approx(0.5, 0.01)


func test_meditate_folds_legs_and_arms_forward() -> void:
	## Forward is -Z. The folded legs and forearms must sit in front of the hips (smaller z).
	var model: HanumanModel = await _live_model()
	model.set_pose(&"meditate")
	await get_tree().process_frame
	var hips_z: float = _attachment_z(model, "hips")
	var foot: Node3D = model.find_child("lower_leg_l_part_1", true, false) as Node3D
	var foot_z: float = foot.global_position.z
	assert_bool(foot_z < hips_z).is_true()
	assert_bool(_attachment_z(model, "lower_arm_l") < hips_z).is_true()
	assert_bool(_attachment_z(model, "lower_arm_r") < hips_z).is_true()


func test_tail_curls_behind_him_on_positive_z() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"idle")
	await get_tree().process_frame
	assert_bool(_attachment_z(model, "tail_7") > 0.3).is_true()
	assert_bool(_attachment_z(model, "tail_0") > 0.0).is_true()
	## The face and muzzle sit on -Z, in front of the head.
	var muzzle: Node3D = model.find_child("head_part_1", true, false) as Node3D
	assert_bool(muzzle.global_position.z < _attachment_z(model, "head")).is_true()


func test_colours_come_only_from_palette() -> void:
	var allowed: Array[Color] = [Palette.HANUMAN_FUR, Palette.SINDOOR, Palette.SAFFRON, Palette.GOLD, HanumanModel.FUR_LIGHT, Palette.MOON, Palette.UI_DARK]
	var model: HanumanModel = _model()
	var checked: int = 0
	var used: Array[Color] = []
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		var arrays: Array = (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		for colour: Color in colours:
			var found: bool = false
			for token: Color in allowed:
				if colour.is_equal_approx(token):
					found = true
					if not used.has(token):
						used.append(token)
			assert_bool(found).is_true()
			checked += 1
	assert_int(checked).is_greater(0)
	## Every palette token the model is meant to use appears at least once.
	for token: Color in allowed:
		assert_bool(used.has(token)).is_true()


func test_gada_and_every_tail_segment_have_a_mesh() -> void:
	var model: HanumanModel = _model()
	var bones: Array[String] = ["gada_socket", "tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7"]
	for bone_name: String in bones:
		var attachment: Node = model.find_child("Attach_" + bone_name, true, false)
		assert_object(attachment).is_not_null()
		assert_int(attachment.find_children("*", "MeshInstance3D", false, false).size()).is_greater_equal(1)


func test_parts_use_the_flat_material() -> void:
	var model: HanumanModel = _model()
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		assert_object(mesh_instance.material_override).is_same(MeshKit.flat_material())


func test_set_pose_accepts_all_six_poses() -> void:
	var model: HanumanModel = _model()
	for pose: StringName in ALL_POSES:
		model.set_pose(pose)
		assert_str(String(model.current_pose())).is_equal(String(pose))


func test_unknown_pose_leaves_current_pose_unchanged() -> void:
	var model: HanumanModel = _model()
	model.set_pose(&"attack_strike")
	model.set_pose(&"no_such_pose")
	assert_str(String(model.current_pose())).is_equal("attack_strike")


func test_meditate_pose_moves_the_chest() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var chest: int = skeleton.find_bone("chest")
	model.set_pose(&"idle")
	var idle_rot: Quaternion = skeleton.get_bone_pose_rotation(chest)
	model.set_pose(&"meditate")
	var meditate_rot: Quaternion = skeleton.get_bone_pose_rotation(chest)
	assert_bool(idle_rot.is_equal_approx(meditate_rot)).is_false()


func test_attack_strike_moves_the_right_arm() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var arm: int = skeleton.find_bone("upper_arm_r")
	model.set_pose(&"idle")
	var idle_rot: Quaternion = skeleton.get_bone_pose_rotation(arm)
	model.set_pose(&"attack_strike")
	var strike_rot: Quaternion = skeleton.get_bone_pose_rotation(arm)
	assert_bool(idle_rot.is_equal_approx(strike_rot)).is_false()
