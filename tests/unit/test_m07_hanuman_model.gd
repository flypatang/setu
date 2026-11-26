extends GdUnitTestSuite
## Acceptance tests for M07 (gen/hanuman_model.gd), DESIGN §9 and §6.2, kept through the v2 rebuild (B1).
## Bone names, height 1.7-1.9 m, palette colours only, and pose results checked in a live scene tree.
## Rigid parts only: no vertex skinning. The live motion (breathing, tail sway, pose blending) is switched off here
## so that every transform is exact; tests/unit/test_b1_hanuman_v2.gd covers the motion.

const REQUIRED_BONES: Array[String] = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	"tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7",
	"gada_socket",
]

const ALL_POSES: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike", &"meditate"]
const ATTACK_POSES: Array[StringName] = [&"attack_wind", &"attack_strike"]


func _model() -> HanumanModel:
	var model: HanumanModel = auto_free(HanumanModel.new()) as HanumanModel
	model.animate = false
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


## Exact world-space bounds of one part, from its vertices.
func _part_bounds(mesh_instance: MeshInstance3D) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	var mesh: Mesh = mesh_instance.mesh
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var world: Vector3 = mesh_instance.global_transform * vertex
			if first:
				bounds = AABB(world, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(world)
	return bounds


## World-space bounds of the body (the model must be in the tree). The gada is a carried prop and is left out.
func _body_bounds(model: HanumanModel) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		if mesh_instance.name.begins_with("gada_socket"):
			continue
		var box: AABB = _part_bounds(mesh_instance)
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
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
	## v2 keeps every M07 bone and only adds tail bones after tail_7.
	assert_int(skeleton.get_bone_count()).is_equal(HanumanModel.BONE_NAMES.size())
	for bone_name: String in HanumanModel.BONE_NAMES:
		assert_bool(REQUIRED_BONES.has(bone_name) or bone_name.begins_with("tail_")).is_true()


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
	var height: float = _body_bounds(model).size.y
	assert_bool(height >= 1.7 and height <= 1.9).is_true()


func test_feet_touch_the_ground_at_y_zero_at_idle() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"idle")
	await get_tree().process_frame
	assert_float(_body_bounds(model).position.y).is_equal_approx(0.0, 0.01)


func test_head_height_holds_in_every_pose() -> void:
	## The head stays at 1.54 m in the standing, walking and meditating poses. The attacks crouch and lunge, so there
	## the head may dip, but never below 1.4 m.
	var model: HanumanModel = await _live_model()
	for pose: StringName in ALL_POSES:
		model.set_pose(pose)
		await get_tree().process_frame
		if ATTACK_POSES.has(pose):
			assert_bool(_attachment_y(model, "head") >= 1.4 and _attachment_y(model, "head") <= 1.6).is_true()
		else:
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
		assert_bool(skeleton.get_bone_pose_scale(index).is_equal_approx(Vector3.ONE)).is_true()
		if not idle_table.has(bone_name):
			assert_bool(skeleton.get_bone_pose_rotation(index).is_equal_approx(Quaternion.IDENTITY)).is_true()
	assert_float(_attachment_y(model, "lower_leg_l")).is_equal_approx(0.5, 0.01)


func test_meditate_folds_legs_and_arms_forward() -> void:
	## Forward is -Z. The folded legs and forearms must sit in front of the hips (smaller z).
	var model: HanumanModel = await _live_model()
	model.set_pose(&"meditate")
	await get_tree().process_frame
	var hips_z: float = _attachment_z(model, "hips")
	var foot: MeshInstance3D = model.find_child("lower_leg_l_part_1", true, false) as MeshInstance3D
	assert_bool(_part_bounds(foot).get_center().z < hips_z).is_true()
	assert_bool(_attachment_z(model, "lower_arm_l") < hips_z).is_true()
	assert_bool(_attachment_z(model, "lower_arm_r") < hips_z).is_true()


func test_tail_curls_behind_him_on_positive_z() -> void:
	var model: HanumanModel = await _live_model()
	model.set_pose(&"idle")
	await get_tree().process_frame
	assert_bool(_attachment_z(model, "tail_7") > 0.3).is_true()
	assert_bool(_attachment_z(model, "tail_0") > 0.0).is_true()
	## The face and muzzle sit on -Z, in front of the head.
	var muzzle: MeshInstance3D = model.find_child("head_part_1", true, false) as MeshInstance3D
	assert_bool(_part_bounds(muzzle).get_center().z < _attachment_z(model, "head") - 0.05).is_true()


func test_colours_come_only_from_palette() -> void:
	## Palette tokens, plus the model's own tones derived from them (lighter and darker fur, skin, the sindoor-tinted
	## muzzle, deep saffron). A vertex may also sit on the ramp between two fur tones or two saffron tones.
	var allowed: Array[Color] = [
		Palette.HANUMAN_FUR, Palette.SINDOOR, Palette.SAFFRON, Palette.GOLD, Palette.MOON, Palette.UI_DARK, Palette.BARK,
		HanumanModel.FUR_LIGHT, HanumanModel.FUR_DARK, HanumanModel.SKIN, HanumanModel.MUZZLE, HanumanModel.SAFFRON_DEEP,
	]
	var ramps: Array[Array] = [
		[Palette.HANUMAN_FUR, HanumanModel.FUR_LIGHT],
		[Palette.SAFFRON, HanumanModel.SAFFRON_DEEP],
	]
	var model: HanumanModel = _model()
	var checked: int = 0
	var off_palette: int = 0
	var used: Array[Color] = []
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		var mesh: Mesh = mesh_instance.mesh
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var last: Color = Color(-1.0, -1.0, -1.0)
			for colour: Color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
				checked += 1
				var rgb: Color = Color(colour.r, colour.g, colour.b)
				if rgb.is_equal_approx(last):
					continue
				last = rgb
				var found: bool = false
				for token: Color in allowed:
					if _same_rgb(rgb, token):
						found = true
						if not used.has(token):
							used.append(token)
				if not found:
					for ramp: Array in ramps:
						if _on_ramp(rgb, ramp[0] as Color, ramp[1] as Color):
							found = true
				if not found:
					off_palette += 1
	assert_int(checked).is_greater(0)
	assert_int(off_palette).is_equal(0)
	## Every tone the model is meant to use appears at least once.
	for token: Color in allowed:
		assert_bool(used.has(token)).is_true()


func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006


func _on_ramp(colour: Color, from: Color, to: Color) -> bool:
	for step: int in range(101):
		if _same_rgb(colour, from.lerp(to, float(step) / 100.0)):
			return true
	return false


func test_gada_and_every_tail_segment_have_a_mesh() -> void:
	var model: HanumanModel = _model()
	var bones: Array[String] = ["gada_socket", "tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7"]
	for bone_name: String in bones:
		var attachment: Node = model.find_child("Attach_" + bone_name, true, false)
		assert_object(attachment).is_not_null()
		assert_int(attachment.find_children("*", "MeshInstance3D", false, false).size()).is_greater_equal(1)


func test_parts_use_the_painterly_kind_materials() -> void:
	## v2: no flat toon override; every surface is named after its Materials kind and carries that kind's material.
	var model: HanumanModel = _model()
	var surfaces: int = 0
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		assert_object(mesh_instance.material_override).is_null()
		var mesh: Mesh = mesh_instance.mesh
		for surface: int in range(mesh.get_surface_count()):
			var kind: StringName = StringName((mesh as ArrayMesh).surface_get_name(surface))
			assert_bool(Materials.has_kind(kind)).is_true()
			assert_object(mesh.surface_get_material(surface)).is_same(Materials.get_material(kind))
			surfaces += 1
	assert_int(surfaces).is_greater(20)


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
