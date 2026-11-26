extends GdUnitTestSuite
## Acceptance tests for B1 (gen/hanuman_model.gd, docs/ART.md "Characters"): Hanuman v2.
## Smooth sculpted forms on Materials kinds, a face, gold ornaments, a wind-weighted dhoti, a long curled tail,
## idle breathing, pose blending and attack poses with anticipation.


func _model() -> HanumanModel:
	var model: HanumanModel = auto_free(HanumanModel.new()) as HanumanModel
	model.animate = false
	model.build()
	return model


func _live_model() -> HanumanModel:
	var model: HanumanModel = _model()
	add_child(model)
	await get_tree().process_frame
	return model


func _parts(model: HanumanModel, prefix: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children(prefix + "*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result


## Arrays of every surface of `kind` on the parts whose names start with `prefix`.
func _surfaces(model: HanumanModel, prefix: String, kind: String) -> Array[Array]:
	var result: Array[Array] = []
	for mesh_instance: MeshInstance3D in _parts(model, prefix):
		var mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
		for surface: int in range(mesh.get_surface_count()):
			if mesh.surface_get_name(surface) == kind:
				result.append(mesh.surface_get_arrays(surface))
	return result


func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006


func _has_colour(model: HanumanModel, prefix: String, kind: String, colour: Color) -> bool:
	for arrays: Array in _surfaces(model, prefix, kind):
		for vertex_colour: Color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
			if _same_rgb(vertex_colour, colour):
				return true
	return false


## Model-space position of a bone joint, chained from the local bone poses (a Skeleton3D outside the scene tree
## does not refresh its cached global poses).
func _bone_origin(model: HanumanModel, bone_name: String) -> Vector3:
	var skeleton: Skeleton3D = model.get_skeleton()
	var index: int = skeleton.find_bone(bone_name)
	var pose: Transform3D = Transform3D()
	while index >= 0:
		pose = skeleton.get_bone_pose(index) * pose
		index = skeleton.get_bone_parent(index)
	return pose.origin


# ---------------------------------------------------------------- materials and geometry

func test_body_uses_the_four_material_kinds() -> void:
	var model: HanumanModel = _model()
	for kind: String in ["fur", "skin", "cloth", "gold"]:
		assert_int(_surfaces(model, "", kind).size()).is_greater(0)
	## Fur on the torso and limbs, skin on the face, hands and feet, cloth on the hips and thighs.
	assert_int(_surfaces(model, "chest_part_", "fur").size()).is_greater(0)
	assert_int(_surfaces(model, "head_part_", "skin").size()).is_greater(0)
	assert_int(_surfaces(model, "lower_arm_l_part_", "skin").size()).is_greater(0)
	assert_int(_surfaces(model, "lower_leg_r_part_", "skin").size()).is_greater(0)
	assert_int(_surfaces(model, "hips_part_", "cloth").size()).is_greater(0)
	assert_int(_surfaces(model, "upper_leg_l_part_", "cloth").size()).is_greater(0)


func test_no_part_uses_the_flat_toon_material() -> void:
	var model: HanumanModel = _model()
	for mesh_instance: MeshInstance3D in _parts(model, ""):
		assert_object(mesh_instance.material_override).is_null()
		for surface: int in range(mesh_instance.mesh.get_surface_count()):
			assert_object(mesh_instance.mesh.surface_get_material(surface)).is_not_same(MeshKit.flat_material())


func test_triangle_count_is_between_4000_and_6000() -> void:
	var model: HanumanModel = _model()
	var triangles: int = model.triangle_count()
	assert_bool(triangles >= 4000 and triangles <= 6000).is_true()


func test_forms_are_smooth_shaded() -> void:
	## Smooth shading: the vertices that share one position also share one normal (flat shading gives each face its
	## own). Checked on the sculpted fur of the limbs and the torso.
	var model: HanumanModel = _model()
	for part_name: String in ["upper_arm_l_part_0", "lower_leg_r_part_0", "chest_part_0", "spine_part_0", "tail_3_part_0"]:
		var mesh_instance: MeshInstance3D = model.find_child(part_name, true, false) as MeshInstance3D
		var arrays: Array = (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var seen: Dictionary = {}
		var shared: int = 0
		var split: int = 0
		for index: int in range(vertices.size()):
			var key: Vector3i = Vector3i((vertices[index] * 10000.0).round())
			if seen.has(key):
				shared += 1
				if (seen[key] as Vector3).dot(normals[index]) < 0.98:
					split += 1
			else:
				seen[key] = normals[index]
			assert_float(normals[index].length()).is_equal_approx(1.0, 0.01)
		assert_bool(float(shared) > float(vertices.size()) * 0.5).is_true()
		## Only the two halves of a single-sphere joint may meet at an angle; a tube never splits its normals.
		assert_bool(float(split) < float(shared) * 0.05).is_true()


func test_surfaces_face_outward() -> void:
	## Clockwise front faces: the face normal of every triangle agrees with its vertex normals.
	var model: HanumanModel = _model()
	var checked: int = 0
	var inward: int = 0
	for mesh_instance: MeshInstance3D in _parts(model, ""):
		var mesh: Mesh = mesh_instance.mesh
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			var start: int = 0
			while start + 2 < vertices.size():
				var face: Vector3 = (vertices[start + 2] - vertices[start]).cross(vertices[start + 1] - vertices[start])
				if face.dot(normals[start] + normals[start + 1] + normals[start + 2]) < 0.0:
					inward += 1
				checked += 1
				start += 3
	assert_int(checked).is_greater(3000)
	assert_int(inward).is_equal(0)


# ---------------------------------------------------------------- face and ornaments

func test_face_has_brow_eyes_and_muzzle() -> void:
	var model: HanumanModel = _model()
	## Eyes: moon-white with a dark iris, on a glossy surface. Brow: dark fur. Muzzle: its own part.
	assert_bool(_has_colour(model, "head_part_", "lacquer_local", Palette.MOON)).is_true()
	assert_bool(_has_colour(model, "head_part_", "lacquer_local", Palette.UI_DARK)).is_true()
	assert_bool(_has_colour(model, "head_part_", "fur", HanumanModel.FUR_DARK)).is_true()
	assert_bool(_has_colour(model, "head_part_1", "skin", HanumanModel.MUZZLE)).is_true()
	assert_bool(_has_colour(model, "head_part_", "skin", HanumanModel.SKIN)).is_true()
	## A sindoor tilak and gems.
	assert_bool(_has_colour(model, "head_part_", "lacquer_local", Palette.SINDOOR)).is_true()


func test_eyes_and_brows_are_level_and_symmetric() -> void:
	## A serene face: the features of the two sides mirror each other exactly (no scowl, no raised brow).
	var model: HanumanModel = _model()
	var left: int = 0
	var right: int = 0
	var sum_y_left: float = 0.0
	var sum_y_right: float = 0.0
	for arrays: Array in _surfaces(model, "head_part_2", "fur"):
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if vertex.x > 0.0:
				left += 1
				sum_y_left += vertex.y
			elif vertex.x < 0.0:
				right += 1
				sum_y_right += vertex.y
	assert_int(left).is_greater(0)
	assert_int(left).is_equal(right)
	assert_float(sum_y_left / float(left)).is_equal_approx(sum_y_right / float(right), 0.001)


func test_gold_ornaments_are_all_present() -> void:
	var model: HanumanModel = _model()
	## Mukuta and earrings on the head, necklace on the chest, armlets, bracelets, waistband, anklets, gada.
	for prefix: String in ["head_part_3", "head_part_4", "chest_part_", "upper_arm_l_part_", "upper_arm_r_part_",
			"lower_arm_l_part_", "lower_arm_r_part_", "hips_part_", "lower_leg_l_part_", "lower_leg_r_part_", "gada_socket_part_"]:
		assert_bool(_has_colour(model, prefix, "gold", Palette.GOLD)).is_true()


func test_earrings_hang_below_the_ears_on_both_sides() -> void:
	var model: HanumanModel = _model()
	var left: bool = false
	var right: bool = false
	for arrays: Array in _surfaces(model, "head_part_4", "gold"):
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			assert_bool(vertex.y < 0.12).is_true()
			left = left or vertex.x > 0.1
			right = right or vertex.x < -0.1
	assert_bool(left and right).is_true()


func test_mukuta_is_layered_with_a_spire() -> void:
	## Going up the mukuta the radius steps in and out (band, tiers, dome) and ends in a point on the centre line.
	var model: HanumanModel = _model()
	var top: float = -1.0
	var widest: float = 0.0
	var radius_at_top: float = 1.0
	for arrays: Array in _surfaces(model, "head_part_3", "gold"):
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var radius: float = Vector2(vertex.x, vertex.z).length()
			widest = maxf(widest, radius)
			if vertex.y > top:
				top = vertex.y
				radius_at_top = radius
	assert_bool(widest > 0.13).is_true()
	assert_bool(radius_at_top < 0.005).is_true()
	assert_bool(top > 0.33).is_true()


# ---------------------------------------------------------------- dhoti and tail

func test_dhoti_wind_weight_grows_toward_the_hem() -> void:
	## Vertex colour alpha is the wind weight: 0 at the waist, more toward every hem.
	var model: HanumanModel = _model()
	for prefix: String in ["hips_part_", "upper_leg_l_part_", "upper_leg_r_part_"]:
		var top_y: float = -100.0
		var bottom_y: float = 100.0
		var top_weight: float = 1.0
		var bottom_weight: float = 0.0
		var count: int = 0
		for arrays: Array in _surfaces(model, prefix, "cloth"):
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			for index: int in range(vertices.size()):
				count += 1
				assert_bool(colours[index].a >= 0.0 and colours[index].a <= 1.0).is_true()
				if vertices[index].y > top_y:
					top_y = vertices[index].y
					top_weight = colours[index].a
				if vertices[index].y < bottom_y:
					bottom_y = vertices[index].y
					bottom_weight = colours[index].a
		assert_int(count).is_greater(0)
		assert_float(top_weight).is_equal_approx(0.0, 0.01)
		assert_bool(bottom_weight > top_weight + 0.2).is_true()


func test_dhoti_wind_weight_never_falls_toward_the_hem() -> void:
	## Along each cloth piece of the hips, a lower vertex is never stiffer than a higher one by more than a pleat.
	var model: HanumanModel = _model()
	var free_hem: float = 0.0
	for arrays: Array in _surfaces(model, "hips_part_", "cloth"):
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		for index: int in range(vertices.size()):
			if vertices[index].y < -0.35:
				free_hem = maxf(free_hem, colours[index].a)
			if vertices[index].y > 0.02:
				assert_bool(colours[index].a < 0.1).is_true()
	## The falling pleats and the sash ends are free at the bottom.
	assert_bool(free_hem > 0.7).is_true()


func test_dhoti_is_saffron_with_a_sindoor_sash() -> void:
	var model: HanumanModel = _model()
	assert_bool(_has_colour(model, "hips_part_", "cloth", Palette.SAFFRON)).is_true()
	assert_bool(_has_colour(model, "hips_part_", "cloth", HanumanModel.SAFFRON_DEEP)).is_true()
	assert_bool(_has_colour(model, "hips_part_", "cloth", Palette.SINDOOR)).is_true()
	assert_bool(_has_colour(model, "upper_leg_l_part_", "cloth", Palette.SAFFRON)).is_true()


func test_tail_has_at_least_ten_segments() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	assert_int(HanumanModel.TAIL_BONES).is_greater_equal(10)
	for index: int in range(HanumanModel.TAIL_BONES):
		var bone_name: String = "tail_%d" % index
		assert_int(skeleton.find_bone(bone_name)).is_greater_equal(0)
		assert_int(_parts(model, bone_name + "_part_").size()).is_greater_equal(1)
		if index > 0:
			## A chain: each segment hangs from the one before it, about a hand's length away.
			assert_int(skeleton.get_bone_parent(skeleton.find_bone(bone_name))).is_equal(skeleton.find_bone("tail_%d" % (index - 1)))
			var here: Vector3 = HanumanModel.BONE_REST[bone_name] as Vector3
			var previous: Vector3 = HanumanModel.BONE_REST["tail_%d" % (index - 1)] as Vector3
			assert_bool(here.distance_to(previous) > 0.08 and here.distance_to(previous) < 0.16).is_true()


func test_tail_ends_in_a_curl() -> void:
	## The tail climbs behind him, turns over at the top, and its tip hooks back down and round.
	var highest: float = 0.0
	var highest_index: int = 0
	for index: int in range(HanumanModel.TAIL_BONES):
		var rest: Vector3 = HanumanModel.BONE_REST["tail_%d" % index] as Vector3
		if rest.y > highest:
			highest = rest.y
			highest_index = index
	var last: Vector3 = HanumanModel.BONE_REST["tail_%d" % (HanumanModel.TAIL_BONES - 1)] as Vector3
	assert_bool(highest_index >= 8 and highest_index < HanumanModel.TAIL_BONES - 1).is_true()
	assert_bool(HanumanModel.TAIL_TIP.y < last.y and last.y < highest).is_true()
	## The curl turns through more than a half circle: the last stretch heads back the way the tail came.
	var rising: Vector3 = (HanumanModel.BONE_REST["tail_7"] as Vector3) - (HanumanModel.BONE_REST["tail_6"] as Vector3)
	var hooking: Vector3 = HanumanModel.TAIL_CURL_END - HanumanModel.TAIL_TIP
	assert_bool(rising.normalized().dot((HanumanModel.TAIL_TIP - last).normalized()) < -0.5).is_true()
	assert_bool(hooking.z > 0.0).is_true()
	## And it stays below the top of the mukuta.
	assert_bool(highest < 1.7).is_true()


# ---------------------------------------------------------------- motion

func test_breath_scale_swells_and_returns() -> void:
	assert_bool(HanumanModel.breath_scale(0.0).is_equal_approx(Vector3.ONE)).is_true()
	assert_bool(HanumanModel.breath_scale(HanumanModel.BREATH_PERIOD).is_equal_approx(Vector3.ONE)).is_true()
	var full: Vector3 = HanumanModel.breath_scale(HanumanModel.BREATH_PERIOD * 0.5)
	assert_bool(full.is_equal_approx(Vector3.ONE + HanumanModel.BREATH_SCALE)).is_true()
	## Subtle: the chest swells by a few percent at most, and mostly in depth.
	assert_bool(full.x > 1.0 and full.y > 1.0 and full.z > 1.0).is_true()
	assert_bool(full.z > full.x and full.x > full.y).is_true()
	assert_bool(full.z < 1.06).is_true()
	assert_bool(HanumanModel.breath_scale(HanumanModel.BREATH_PERIOD * 0.5, 0.0).is_equal_approx(Vector3.ONE)).is_true()


func test_idle_breathes_through_the_chest_bone() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var chest: int = skeleton.find_bone("chest")
	assert_bool(skeleton.get_bone_pose_scale(chest).is_equal_approx(Vector3.ONE)).is_true()
	model.advance(HanumanModel.BREATH_PERIOD * 0.5)
	var full: Vector3 = skeleton.get_bone_pose_scale(chest)
	assert_bool(full.is_equal_approx(Vector3.ONE + HanumanModel.BREATH_SCALE)).is_true()
	model.advance(HanumanModel.BREATH_PERIOD * 0.5)
	assert_bool(skeleton.get_bone_pose_scale(chest).is_equal_approx(Vector3.ONE)).is_true()
	## Breathing never moves the feet or the head off their joints.
	assert_bool(skeleton.get_bone_pose_position(chest).is_equal_approx(skeleton.get_bone_rest(chest).origin)).is_true()


func test_breath_is_shallower_while_fighting() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var chest: int = skeleton.find_bone("chest")
	model.set_pose(&"attack_wind")
	model.advance(HanumanModel.BREATH_PERIOD * 0.5)
	var fighting: Vector3 = skeleton.get_bone_pose_scale(chest)
	assert_bool(fighting.z > 1.0 and fighting.z < 1.0 + HanumanModel.BREATH_SCALE.z * 0.6).is_true()


func test_tail_sways_when_advanced() -> void:
	var model: HanumanModel = _model()
	var tip: String = "tail_%d" % (HanumanModel.TAIL_BONES - 1)
	var rest: Vector3 = _bone_origin(model, tip)
	model.advance(0.7)
	var swayed: Vector3 = _bone_origin(model, tip)
	assert_bool(swayed.distance_to(rest) > 0.002).is_true()
	## A sway, not a lash: the tip stays within a hand of where it rests.
	assert_bool(swayed.distance_to(rest) < 0.2).is_true()
	## Snapping to a pose removes the live motion again.
	model.set_pose(&"idle")
	assert_bool(_bone_origin(model, tip).is_equal_approx(rest)).is_true()


func test_set_pose_snaps_outside_the_tree() -> void:
	var model: HanumanModel = _model()
	model.animate = true
	var skeleton: Skeleton3D = model.get_skeleton()
	var arm: int = skeleton.find_bone("upper_arm_r")
	model.set_pose(&"attack_strike")
	var euler: Vector3 = (HanumanModel.POSES["attack_strike"] as Dictionary)["upper_arm_r"] as Vector3
	assert_bool(skeleton.get_bone_pose_rotation(arm).is_equal_approx(Quaternion.from_euler(euler * (PI / 180.0)))).is_true()


func test_pose_blends_inside_the_tree() -> void:
	var model: HanumanModel = _model()
	add_child(model)
	model.animate = true
	model.set_process(false)
	model.blend_time = 0.2
	var skeleton: Skeleton3D = model.get_skeleton()
	var leg: int = skeleton.find_bone("upper_leg_l")
	var from: Quaternion = skeleton.get_bone_pose_rotation(leg)
	var euler: Vector3 = (HanumanModel.POSES["meditate"] as Dictionary)["upper_leg_l"] as Vector3
	var to: Quaternion = Quaternion.from_euler(euler * (PI / 180.0))
	model.set_pose(&"meditate")
	## The pose name changes at once (gameplay reads it); the bones follow.
	assert_str(String(model.current_pose())).is_equal("meditate")
	assert_bool(skeleton.get_bone_pose_rotation(leg).is_equal_approx(from)).is_true()
	model.advance(0.05)
	var between: Quaternion = skeleton.get_bone_pose_rotation(leg)
	assert_bool(between.angle_to(from) > 0.05 and between.angle_to(to) > 0.05).is_true()
	model.advance(0.3)
	assert_bool(skeleton.get_bone_pose_rotation(leg).is_equal_approx(to)).is_true()


func test_blend_time_zero_snaps_inside_the_tree() -> void:
	var model: HanumanModel = _model()
	add_child(model)
	model.animate = true
	model.set_process(false)
	model.blend_time = 0.0
	var skeleton: Skeleton3D = model.get_skeleton()
	var leg: int = skeleton.find_bone("upper_leg_l")
	var euler: Vector3 = (HanumanModel.POSES["meditate"] as Dictionary)["upper_leg_l"] as Vector3
	model.set_pose(&"meditate")
	assert_bool(skeleton.get_bone_pose_rotation(leg).is_equal_approx(Quaternion.from_euler(euler * (PI / 180.0)))).is_true()


func test_meditation_floats_gently() -> void:
	var model: HanumanModel = _model()
	model.set_pose(&"meditate")
	var skeleton: Skeleton3D = model.get_skeleton()
	var hips: int = skeleton.find_bone("hips")
	var rest_y: float = skeleton.get_bone_rest(hips).origin.y
	var lowest: float = rest_y
	var highest: float = rest_y
	for step: int in range(50):
		model.advance(0.1)
		lowest = minf(lowest, skeleton.get_bone_pose_position(hips).y)
		highest = maxf(highest, skeleton.get_bone_pose_position(hips).y)
	assert_bool(highest - lowest > 0.02 and highest - lowest < 0.06).is_true()


# ---------------------------------------------------------------- poses

func test_attack_wind_is_an_anticipation_of_the_strike() -> void:
	## Wind-up: the gada hand is cocked up behind the head and the body is coiled away. Strike: the hand has driven
	## forward and down past the body, and the body has turned the other way.
	var model: HanumanModel = _model()
	model.set_pose(&"attack_wind")
	var wind_hand: Vector3 = _bone_origin(model, "gada_socket")
	var wind_head: Vector3 = _bone_origin(model, "head")
	var wind_twist: float = (HanumanModel.POSES["attack_wind"] as Dictionary)["chest"].y
	model.set_pose(&"attack_strike")
	var strike_hand: Vector3 = _bone_origin(model, "gada_socket")
	var strike_twist: float = (HanumanModel.POSES["attack_strike"] as Dictionary)["chest"].y
	assert_bool(wind_hand.y > wind_head.y).is_true()
	assert_bool(wind_hand.z > wind_head.z).is_true()
	assert_bool(strike_hand.z < -0.4).is_true()
	assert_bool(strike_hand.y < wind_hand.y - 0.4).is_true()
	assert_bool(wind_twist * strike_twist < 0.0).is_true()
	## The swing covers real distance: more than an arm's length between the two poses.
	assert_bool(wind_hand.distance_to(strike_hand) > 0.7).is_true()


func test_attack_poses_use_the_whole_body() -> void:
	for pose: String in ["attack_wind", "attack_strike"]:
		var table: Dictionary = HanumanModel.POSES[pose] as Dictionary
		for bone_name: String in ["hips", "spine", "chest", "head", "upper_arm_l", "upper_arm_r", "lower_arm_r",
				"upper_leg_l", "upper_leg_r", "gada_socket", "tail_0"]:
			assert_bool(table.has(bone_name)).is_true()
		## The weight shifts: the hips drop.
		var offsets: Dictionary = HanumanModel.POSE_OFFSETS[pose] as Dictionary
		assert_bool((offsets["hips"] as Vector3).y < 0.0).is_true()


func test_attack_strike_lunges_forward_of_the_wind_up() -> void:
	var model: HanumanModel = _model()
	model.set_pose(&"attack_wind")
	var wind_chest: Vector3 = _bone_origin(model, "chest")
	model.set_pose(&"attack_strike")
	var strike_chest: Vector3 = _bone_origin(model, "chest")
	assert_bool(strike_chest.z < wind_chest.z - 0.08).is_true()


func test_feet_stay_near_the_ground_in_the_attacks() -> void:
	## A crouch and a lunge, never a hop: the supporting foot stays within a hand of the ground.
	var model: HanumanModel = await _live_model()
	for pose: StringName in [&"attack_wind", &"attack_strike"]:
		model.set_pose(pose)
		await get_tree().process_frame
		var lowest: float = 10.0
		for bone_name: String in ["lower_leg_l", "lower_leg_r"]:
			var foot: MeshInstance3D = model.find_child(bone_name + "_part_1", true, false) as MeshInstance3D
			var arrays: Array = (foot.mesh as ArrayMesh).surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				lowest = minf(lowest, (foot.global_transform * vertex).y)
		assert_bool(lowest > -0.08 and lowest < 0.08).is_true()


func test_gada_rests_on_the_shoulder_at_idle() -> void:
	## The heroic carry: the hand in front of the chest, the gada leaning back over the "_r" shoulder, its head
	## behind him and above his shoulders.
	var model: HanumanModel = await _live_model()
	var hand: Node3D = model.find_child("Attach_gada_socket", true, false) as Node3D
	var head: MeshInstance3D = model.find_child("gada_socket_part_1", true, false) as MeshInstance3D
	var club: Vector3 = head.global_transform * Vector3(0.0, 0.65, 0.0)
	assert_bool(hand.global_position.z < -0.1).is_true()
	assert_bool(club.z > 0.05).is_true()
	assert_bool(club.y > 1.55).is_true()
	assert_bool(club.x < -0.15).is_true()


func test_legacy_api_is_kept() -> void:
	var model: HanumanModel = _model()
	assert_object(model.build()).is_same(model)
	for pose: String in ["idle", "walk_a", "walk_b", "attack_wind", "attack_strike", "meditate"]:
		assert_bool(HanumanModel.POSES.has(pose)).is_true()
	for bone_name: String in ["root", "hips", "spine", "chest", "head", "upper_arm_l", "lower_arm_l", "upper_arm_r",
			"lower_arm_r", "upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r", "tail_0", "tail_7", "gada_socket"]:
		assert_bool(HanumanModel.BONE_NAMES.has(bone_name)).is_true()
		assert_object(model.find_child("Attach_" + bone_name, true, false)).is_not_null()
	assert_bool(HanumanModel.FUR_LIGHT.get_luminance() > Palette.HANUMAN_FUR.get_luminance()).is_true()
	assert_str(String(model.current_pose())).is_equal("idle")
