class_name HanumanModel
extends Node3D
## Procedural Hanuman, art direction v2 (docs/ART.md "Characters"; modules M07, A1, B1).
##
## A Skeleton3D is built in code. Each bone gets one BoneAttachment3D ("Attach_<bone>") and the rigid, smooth-shaded
## parts of that bone hang under it as MeshInstance3D nodes named "<bone>_part_<n>". Nothing is skinned: the forms
## overlap at the joints. Every part is a MeshKit.multi() mesh with one surface per Materials kind (fur body, skin
## face, hands and feet, cloth dhoti and sash, gold ornaments, lacquer for the eyes and gems). The cloth carries
## wind weights in vertex colour alpha: 0 at the waist, rising toward every hem.
##
## Orientation: forward is -Z. The face and muzzle are on -Z, the toes point to -Z, and the tail curls up behind him
## on +Z. The feet sit at y = 0 and he stands about 1.88 m tall with the mukuta. The gada is held in the hand of the
## "_r" arm (bone gada_socket); its head lies along the socket's +Y.
##
## Poses are bone-rotation tables (POSES) with optional bone offsets (POSE_OFFSETS). Outside the scene tree, or with
## `animate` off, set_pose() snaps. Inside the tree the model blends to the new pose over `blend_time` and adds live
## motion on top: idle breathing (chest scale), a swaying tail that lags behind his movement, and a gentle float
## while he meditates. advance(delta) steps that motion by hand (tests, cutscenes).

const BONE_NAMES: PackedStringArray = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	"tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7",
	"tail_8", "tail_9", "tail_10", "tail_11",
	"gada_socket",
]

## Number of tail bones (tail_0 .. tail_11).
const TAIL_BONES: int = 12

## Parent of each bone. "root" has no parent. Parents always come before their children in BONE_NAMES.
const BONE_PARENTS: Dictionary = {
	"hips": "root",
	"spine": "hips",
	"chest": "spine",
	"head": "chest",
	"upper_arm_l": "chest",
	"lower_arm_l": "upper_arm_l",
	"upper_arm_r": "chest",
	"lower_arm_r": "upper_arm_r",
	"upper_leg_l": "hips",
	"lower_leg_l": "upper_leg_l",
	"upper_leg_r": "hips",
	"lower_leg_r": "upper_leg_r",
	"tail_0": "hips",
	"tail_1": "tail_0",
	"tail_2": "tail_1",
	"tail_3": "tail_2",
	"tail_4": "tail_3",
	"tail_5": "tail_4",
	"tail_6": "tail_5",
	"tail_7": "tail_6",
	"tail_8": "tail_7",
	"tail_9": "tail_8",
	"tail_10": "tail_9",
	"tail_11": "tail_10",
	"gada_socket": "lower_arm_r",
}

## Rest position of each bone in model space, in metres. The tail sweeps out behind him (+Z), rises, and curls over.
const BONE_REST: Dictionary = {
	"root": Vector3(0.0, 0.0, 0.0),
	"hips": Vector3(0.0, 0.95, 0.0),
	"spine": Vector3(0.0, 1.12, 0.0),
	"chest": Vector3(0.0, 1.32, 0.0),
	"head": Vector3(0.0, 1.54, 0.0),
	"upper_arm_l": Vector3(0.25, 1.5, 0.0),
	"lower_arm_l": Vector3(0.28, 1.2, 0.0),
	"upper_arm_r": Vector3(-0.25, 1.5, 0.0),
	"lower_arm_r": Vector3(-0.28, 1.2, 0.0),
	"upper_leg_l": Vector3(0.12, 0.92, 0.0),
	"lower_leg_l": Vector3(0.12, 0.5, 0.0),
	"upper_leg_r": Vector3(-0.12, 0.92, 0.0),
	"lower_leg_r": Vector3(-0.12, 0.5, 0.0),
	"tail_0": Vector3(0.0, 0.96, 0.12),
	"tail_1": Vector3(0.0, 0.9, 0.24),
	"tail_2": Vector3(0.0, 0.88, 0.37),
	"tail_3": Vector3(0.0, 0.91, 0.5),
	"tail_4": Vector3(0.0, 0.99, 0.61),
	"tail_5": Vector3(0.0, 1.1, 0.69),
	"tail_6": Vector3(0.0, 1.23, 0.73),
	"tail_7": Vector3(0.0, 1.36, 0.72),
	"tail_8": Vector3(0.0, 1.48, 0.67),
	"tail_9": Vector3(0.0, 1.57, 0.58),
	"tail_10": Vector3(0.0, 1.6, 0.47),
	"tail_11": Vector3(0.0, 1.55, 0.38),
	"gada_socket": Vector3(-0.28, 0.92, 0.0),
}

## Where the tail ends: after tail_11 the tip hooks down and back into a curl.
const TAIL_TIP: Vector3 = Vector3(0.0, 1.47, 0.37)
## The very end of the curl, tucked inside the hook.
const TAIL_CURL_END: Vector3 = Vector3(0.0, 1.44, 0.44)

## Lighter fur for the chest, belly and face (HANUMAN_FUR lightened by about 14%).
const FUR_LIGHT: Color = Color("#D09B56")
## Darker fur for the brow, the back of the head and the tail tuft.
const FUR_DARK: Color = Color("#9C6628")
## Warm skin of the face, ears, hands and feet.
const SKIN: Color = Color("#E6AA80")
## The muzzle: skin tinted a third of the way to SINDOOR.
const MUZZLE: Color = Color("#DF7F6C")
## Deep saffron for the inner folds of the dhoti.
const SAFFRON_DEEP: Color = Color("#D4641C")

## Seconds for one full breath at idle.
const BREATH_PERIOD: float = 3.6
## Chest scale gained at the top of a breath (x = width, y = height, z = depth).
const BREATH_SCALE: Vector3 = Vector3(0.02, 0.01, 0.034)

## Pose tables: bone name -> euler rotation in degrees, relative to rest. Bones not listed return to rest.
## About +X a positive angle swings a hanging limb forward (-Z) and tips the chest and head back. About +Y a
## positive angle turns the "_r" shoulder back. About +Z a positive angle swings the "_l" arm outward.
## The gada lies along the socket's +Y: at rest it points from the hand back up the forearm.
const POSES: Dictionary = {
	"idle": {
		"chest": Vector3(4.0, 0.0, 0.0),
		"head": Vector3(-4.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-4.0, 0.0, 9.0),
		"lower_arm_l": Vector3(16.0, 0.0, 0.0),
		"upper_arm_r": Vector3(22.0, 0.0, -7.0),
		"lower_arm_r": Vector3(108.0, 0.0, 0.0),
		"gada_socket": Vector3(-74.0, 0.0, 12.0),
		"tail_0": Vector3(-3.0, 0.0, 0.0),
	},
	"walk_a": {
		"hips": Vector3(0.0, 6.0, 3.0),
		"spine": Vector3(-4.0, -4.0, 0.0),
		"chest": Vector3(-2.0, -8.0, 0.0),
		"head": Vector3(2.0, 6.0, 0.0),
		"upper_leg_l": Vector3(28.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-14.0, 0.0, 0.0),
		"upper_leg_r": Vector3(-22.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-20.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-28.0, 0.0, 8.0),
		"lower_arm_l": Vector3(18.0, 0.0, 0.0),
		"upper_arm_r": Vector3(28.0, 0.0, -7.0),
		"lower_arm_r": Vector3(104.0, 0.0, 0.0),
		"gada_socket": Vector3(-76.0, 0.0, 12.0),
		"tail_0": Vector3(0.0, -8.0, 0.0),
		"tail_3": Vector3(4.0, -6.0, 0.0),
	},
	"walk_b": {
		"hips": Vector3(0.0, -6.0, -3.0),
		"spine": Vector3(-4.0, 4.0, 0.0),
		"chest": Vector3(-2.0, 8.0, 0.0),
		"head": Vector3(2.0, -6.0, 0.0),
		"upper_leg_l": Vector3(-22.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-20.0, 0.0, 0.0),
		"upper_leg_r": Vector3(28.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-14.0, 0.0, 0.0),
		"upper_arm_l": Vector3(26.0, 0.0, 8.0),
		"lower_arm_l": Vector3(34.0, 0.0, 0.0),
		"upper_arm_r": Vector3(14.0, 0.0, -7.0),
		"lower_arm_r": Vector3(112.0, 0.0, 0.0),
		"gada_socket": Vector3(-72.0, 0.0, 12.0),
		"tail_0": Vector3(0.0, 8.0, 0.0),
		"tail_3": Vector3(4.0, 6.0, 0.0),
	},
	## Anticipation: he coils away from the target, weight on the back leg, the gada cocked high behind his head,
	## the free arm thrown forward for balance, the tail whipping round as a counterweight.
	"attack_wind": {
		"hips": Vector3(4.0, 14.0, 0.0),
		"spine": Vector3(8.0, 12.0, 0.0),
		"chest": Vector3(8.0, 16.0, 0.0),
		"head": Vector3(-14.0, -34.0, 0.0),
		"upper_arm_r": Vector3(-164.0, 0.0, -14.0),
		"lower_arm_r": Vector3(68.0, 0.0, 0.0),
		"gada_socket": Vector3(132.0, 0.0, 0.0),
		"upper_arm_l": Vector3(58.0, 0.0, 14.0),
		"lower_arm_l": Vector3(34.0, 0.0, 0.0),
		"upper_leg_l": Vector3(20.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-26.0, 0.0, 0.0),
		"upper_leg_r": Vector3(-26.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-10.0, 0.0, 0.0),
		"tail_0": Vector3(-6.0, -16.0, 0.0),
		"tail_2": Vector3(-4.0, -10.0, 0.0),
		"tail_5": Vector3(-4.0, -8.0, 0.0),
	},
	## The blow: the whole body uncoils through the target, a deep lunge, the gada driven forward and down, the
	## free arm thrown back and the tail streaming out behind in follow-through.
	"attack_strike": {
		"hips": Vector3(-8.0, -12.0, 0.0),
		"spine": Vector3(-12.0, -10.0, 0.0),
		"chest": Vector3(-10.0, -16.0, 0.0),
		"head": Vector3(22.0, 30.0, 0.0),
		"upper_arm_r": Vector3(78.0, 0.0, 6.0),
		"lower_arm_r": Vector3(12.0, 0.0, 0.0),
		"gada_socket": Vector3(152.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-46.0, 0.0, 22.0),
		"lower_arm_l": Vector3(30.0, 0.0, 0.0),
		"upper_leg_l": Vector3(-20.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-14.0, 0.0, 0.0),
		"upper_leg_r": Vector3(44.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-36.0, 0.0, 0.0),
		"tail_0": Vector3(12.0, 14.0, 0.0),
		"tail_2": Vector3(10.0, 10.0, 0.0),
		"tail_5": Vector3(12.0, 8.0, 0.0),
		"tail_8": Vector3(14.0, 0.0, 0.0),
	},
	## Seated in the air with his legs crossed, the gada held upright like a staff, the free hand resting in his lap.
	"meditate": {
		"chest": Vector3(-3.0, 0.0, 0.0),
		"head": Vector3(8.0, 0.0, 0.0),
		"upper_arm_l": Vector3(18.0, 0.0, 6.0),
		"lower_arm_l": Vector3(72.0, 46.0, 0.0),
		"upper_arm_r": Vector3(8.0, 0.0, -12.0),
		"lower_arm_r": Vector3(86.0, 0.0, 0.0),
		"gada_socket": Vector3(-94.0, 0.0, 0.0),
		"upper_leg_l": Vector3(84.0, -52.0, 0.0),
		"upper_leg_r": Vector3(84.0, 52.0, 0.0),
		"lower_leg_l": Vector3(8.0, 0.0, -118.0),
		"lower_leg_r": Vector3(-4.0, 0.0, 118.0),
		"tail_1": Vector3(-6.0, 0.0, 0.0),
		"tail_4": Vector3(-6.0, 0.0, 0.0),
	},
}

## Pose tables: bone name -> offset from the rest position, in metres. Only the attacks shift his weight.
const POSE_OFFSETS: Dictionary = {
	"attack_wind": {"hips": Vector3(0.0, -0.035, 0.03)},
	"attack_strike": {"hips": Vector3(0.0, -0.05, -0.06)},
}

## Seconds a pose change takes inside the scene tree; attack_strike is quicker and overshoots a little.
const STRIKE_BLEND_TIME: float = 0.06

## When true (the default) the model blends between poses and adds breathing and tail motion while it is inside the
## scene tree. When false, set_pose() snaps and nothing moves by itself.
var animate: bool = true
## Seconds a pose change takes inside the scene tree (0 snaps).
var blend_time: float = 0.12

var _skeleton: Skeleton3D = null
var _pose: StringName = &"idle"
var _time: float = 0.0
var _blend: float = 1.0
var _blend_length: float = 0.0
var _from_rot: Array[Quaternion] = []
var _to_rot: Array[Quaternion] = []
var _from_pos: Array[Vector3] = []
var _to_pos: Array[Vector3] = []
var _tail_bend: Vector2 = Vector2.ZERO
var _tail_speed: Vector2 = Vector2.ZERO
var _last_origin: Vector3 = Vector3.ZERO
var _has_last_origin: bool = false


## Builds the rig and the body parts as children of this node, then returns this node. Calling it again is a no-op
## while the rig exists.
func build() -> Node3D:
	_ensure_rig()
	return self


func get_skeleton() -> Skeleton3D:
	return _skeleton


func current_pose() -> StringName:
	return _pose


## Total triangle count of every part.
func triangle_count() -> int:
	_ensure_rig()
	var total: int = 0
	for node: Node in _skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			@warning_ignore("integer_division")
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## Sets a named pose. Outside the scene tree (or with `animate` off, or `blend_time` 0) the bones snap to it at once;
## otherwise they blend to it. An unknown name is reported with a warning and leaves the current pose unchanged.
func set_pose(pose: StringName) -> void:
	if not POSES.has(String(pose)):
		push_warning("HanumanModel: unknown pose '%s', pose unchanged." % String(pose))
		return
	_ensure_rig()
	var count: int = _skeleton.get_bone_count()
	var live: bool = _is_live() and blend_time > 0.0
	if live:
		var eased: float = _ease(_blend)
		for index: int in range(count):
			_from_rot[index] = _from_rot[index].slerp(_to_rot[index], eased)
			_from_pos[index] = _from_pos[index].lerp(_to_pos[index], eased)
	var table: Dictionary = POSES[String(pose)] as Dictionary
	var offsets: Dictionary = POSE_OFFSETS.get(String(pose), {}) as Dictionary
	for index: int in range(count):
		var bone_name: String = _skeleton.get_bone_name(index)
		var euler: Vector3 = table.get(bone_name, Vector3.ZERO) as Vector3
		_to_rot[index] = Quaternion.from_euler(euler * (PI / 180.0))
		_to_pos[index] = offsets.get(bone_name, Vector3.ZERO) as Vector3
	_pose = pose
	if live:
		_blend = 0.0
		_blend_length = minf(blend_time, STRIKE_BLEND_TIME) if pose == &"attack_strike" else blend_time
	else:
		_blend = 1.0
		for index: int in range(count):
			_from_rot[index] = _to_rot[index]
			_from_pos[index] = _to_pos[index]
		_skeleton.reset_bone_poses()
		_write_bones(false)


## Steps the pose blend, the breathing, the tail and the meditation float by `delta` seconds and writes the bones.
## _process calls this while `animate` is on; call it by hand to drive the model with `animate` off.
func advance(delta: float) -> void:
	_ensure_rig()
	var step: float = maxf(delta, 0.0)
	_time += step
	if _blend < 1.0:
		_blend = 1.0 if _blend_length <= 0.0 else minf(1.0, _blend + step / _blend_length)
	_step_tail(step)
	_write_bones(true)


## Chest scale at `time` seconds into the breathing cycle, for a breath of the given strength (1 = idle).
static func breath_scale(time: float, strength: float = 1.0) -> Vector3:
	var swell: float = 0.5 - 0.5 * cos(time * TAU / BREATH_PERIOD)
	return Vector3.ONE + BREATH_SCALE * (swell * strength)


func _process(delta: float) -> void:
	if animate and _skeleton != null and is_instance_valid(_skeleton):
		advance(delta)


func _is_live() -> bool:
	return animate and is_inside_tree()


## Ease-out for pose changes; the strike overshoots slightly and settles (follow-through).
func _ease(t: float) -> float:
	var inv: float = 1.0 - clampf(t, 0.0, 1.0)
	if _pose == &"attack_strike":
		return 1.0 - inv * inv * inv + 1.1 * inv * inv * (1.0 - inv) * (1.0 - inv) * 0.6
	return 1.0 - inv * inv * inv


func _breath_strength() -> float:
	if _pose == &"idle" or _pose == &"meditate":
		return 1.0
	return 0.35


## The tail lags behind his movement: a damped spring pulls a bend (x = yaw, y = pitch, radians per bone) toward the
## bend his velocity asks for.
func _step_tail(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	var origin: Vector3 = global_position
	var want: Vector2 = Vector2.ZERO
	if _has_last_origin:
		var velocity: Vector3 = global_basis.inverse() * ((origin - _last_origin) / delta)
		want = Vector2(clampf(velocity.x * 0.012, -0.09, 0.09), clampf(velocity.z * 0.01, -0.06, 0.07))
	_last_origin = origin
	_has_last_origin = true
	var dt: float = minf(delta, 0.05)
	_tail_speed += ((want - _tail_bend) * 60.0 - _tail_speed * 9.0) * dt
	_tail_bend += _tail_speed * dt
	_tail_bend = _tail_bend.clampf(-0.12, 0.12)


## Writes the blended pose to the skeleton; with `live` the breathing, tail sway and float are added on top.
func _write_bones(live: bool) -> void:
	var eased: float = _ease(_blend)
	var chest: int = _skeleton.find_bone("chest")
	var hips: int = _skeleton.find_bone("hips")
	var first_tail: int = _skeleton.find_bone("tail_0")
	for index: int in range(_skeleton.get_bone_count()):
		var rot: Quaternion = _from_rot[index].slerp(_to_rot[index], eased)
		var pos: Vector3 = _from_pos[index].lerp(_to_pos[index], eased)
		if live:
			var tail_index: int = index - first_tail
			if tail_index >= 0 and tail_index < TAIL_BONES:
				var phase: float = _time * 1.5 - float(tail_index) * 0.55
				var grow: float = 0.4 + 0.6 * float(tail_index) / float(TAIL_BONES - 1)
				var yaw: float = sin(phase) * 0.03 * grow + _tail_bend.x
				var pitch: float = sin(phase * 0.63 + 1.3) * 0.018 * grow + _tail_bend.y
				rot = rot * Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
			elif index == hips and _pose == &"meditate":
				pos += Vector3(0.0, sin(_time * TAU / 4.2) * 0.02 * eased, 0.0)
		_skeleton.set_bone_pose_rotation(index, rot)
		_skeleton.set_bone_pose_position(index, _skeleton.get_bone_rest(index).origin + pos)
	if live:
		_skeleton.set_bone_pose_scale(chest, breath_scale(_time, _breath_strength()))


func _ensure_rig() -> void:
	if _skeleton == null or not is_instance_valid(_skeleton):
		_build_rig()


func _build_rig() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton3D"
	add_child(_skeleton)
	for bone_name: String in BONE_NAMES:
		var index: int = _skeleton.add_bone(bone_name)
		var world: Vector3 = BONE_REST[bone_name] as Vector3
		var local: Vector3 = world
		var parent_name: String = BONE_PARENTS.get(bone_name, "") as String
		if parent_name != "":
			_skeleton.set_bone_parent(index, _skeleton.find_bone(parent_name))
			local = world - (BONE_REST[parent_name] as Vector3)
		_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, local))
	_skeleton.reset_bone_poses()
	var count: int = _skeleton.get_bone_count()
	_from_rot.resize(count)
	_to_rot.resize(count)
	_from_pos.resize(count)
	_to_pos.resize(count)
	for index: int in range(count):
		_from_rot[index] = Quaternion.IDENTITY
		_to_rot[index] = Quaternion.IDENTITY
		_from_pos[index] = Vector3.ZERO
		_to_pos[index] = Vector3.ZERO
	for bone_name: String in BONE_NAMES:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "Attach_" + bone_name
		attachment.bone_name = bone_name
		_skeleton.add_child(attachment)
		var part_index: int = 0
		for group: Dictionary in _bone_groups(bone_name):
			var mesh_instance: MeshInstance3D = MeshInstance3D.new()
			mesh_instance.name = bone_name + "_part_" + str(part_index)
			mesh_instance.mesh = MeshKit.multi(group)
			attachment.add_child(mesh_instance)
			part_index += 1
	# He stands in the idle pose from the start (the gada resting on his shoulder).
	var keep_animate: bool = animate
	animate = false
	set_pose(&"idle")
	animate = keep_animate


## The parts hanging under one bone. Each entry becomes one MeshInstance3D: a dictionary of Materials kind ->
## merge() parts ({"mesh", "transform"}), in bone space (relative to the bone joint).
func _bone_groups(bone_name: String) -> Array[Dictionary]:
	match bone_name:
		"hips":
			return _hips_groups()
		"spine":
			return _spine_groups()
		"chest":
			return _chest_groups()
		"head":
			return _head_groups()
		"upper_arm_l":
			return _upper_arm_groups(1.0)
		"upper_arm_r":
			return _upper_arm_groups(-1.0)
		"lower_arm_l":
			return _lower_arm_groups(1.0)
		"lower_arm_r":
			return _lower_arm_groups(-1.0)
		"upper_leg_l", "upper_leg_r":
			return _upper_leg_groups()
		"lower_leg_l", "lower_leg_r":
			return _lower_leg_groups()
		"gada_socket":
			return _gada_groups()
	if bone_name.begins_with("tail_"):
		return _tail_groups(int(bone_name.substr(5)))
	return []


# ---------------------------------------------------------------- body

func _hips_groups() -> Array[Dictionary]:
	var cloth: Array[Dictionary] = []
	var fur: Array[Dictionary] = []
	var gold: Array[Dictionary] = []
	var gems: Array[Dictionary] = []
	# The wrapped upper part of the dhoti: rigid at the waist, closed underneath.
	cloth.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.13, 0.0), Vector3(0.0, 0.04, 0.0), Vector3(0.0, -0.07, 0.0), Vector3(0.0, -0.13, 0.0)]),
		PackedFloat32Array([0.2, 0.224, 0.236, 0.218]), PackedFloat32Array([0.158, 0.176, 0.188, 0.17]), 16, Palette.SAFFRON,
		{"fixed": true, "cap1": true, "squash": 0.35, "flutes": 8, "flute0": 0.0, "flute1": 0.035, "wind0": 0.0, "wind1": 0.08,
		"front": SAFFRON_DEEP, "front_axis": Vector3(0.0, -1.0, 0.0)})))
	# The pleated fall at the front: a fan of narrow folds, alternating light and deep, free at the hem.
	for i: int in range(-2, 3):
		var f: float = float(i)
		var fold: Color = Palette.SAFFRON if i % 2 == 0 else SAFFRON_DEEP
		var out: float = 0.012 if i % 2 == 0 else 0.0
		cloth.append(_at(_tube(
			PackedVector3Array([Vector3(f * 0.02, 0.1, -0.166), Vector3(f * 0.032, -0.1, -0.216 - out),
				Vector3(f * 0.046, -0.3, -0.234 - out), Vector3(f * 0.056, -0.47, -0.23 - out)]),
			PackedFloat32Array([0.016, 0.024, 0.032, 0.036]), PackedFloat32Array([0.012, 0.014, 0.013, 0.01]), 4, fold,
			{"wind0": 0.0, "wind1": 0.75})))
	# A sindoor sash under the belt, knotted on the "_l" hip, its two ends flying free.
	cloth.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.085, 0.0), Vector3(0.0, 0.03, 0.0)]),
		PackedFloat32Array([0.228, 0.235]), PackedFloat32Array([0.181, 0.188]), 16, Palette.SINDOOR,
		{"fixed": true, "wind0": 0.0, "wind1": 0.0})))
	cloth.append(_ell(Vector3(0.208, 0.05, -0.07), Vector3(0.04, 0.045, 0.04), MeshKit.with_wind(MeshKit.sphere_smooth(1.0, 3, 6, Palette.SINDOOR), 0.0)))
	cloth.append(_at(_tube(
		PackedVector3Array([Vector3(0.218, 0.04, -0.06), Vector3(0.268, -0.12, -0.03), Vector3(0.288, -0.3, 0.02), Vector3(0.294, -0.43, 0.06)]),
		PackedFloat32Array([0.03, 0.042, 0.052, 0.056]), PackedFloat32Array([0.014, 0.012, 0.011, 0.009]), 4, Palette.SINDOOR,
		{"wind0": 0.0, "wind1": 1.0})))
	cloth.append(_at(_tube(
		PackedVector3Array([Vector3(0.212, 0.04, -0.085), Vector3(0.244, -0.1, -0.1), Vector3(0.256, -0.25, -0.09)]),
		PackedFloat32Array([0.026, 0.036, 0.044]), PackedFloat32Array([0.013, 0.012, 0.009]), 4, Palette.SINDOOR,
		{"wind0": 0.0, "wind1": 0.85})))
	# Pelvis under the cloth (seen when the legs fold).
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.05, 0.0), Vector3(0.0, -0.1, 0.0)]),
		PackedFloat32Array([0.17, 0.186, 0.17]), PackedFloat32Array([0.13, 0.145, 0.13]), 8, Palette.HANUMAN_FUR,
		{"fixed": true, "cap1": true, "squash": 0.4})))
	# Waistband (mekhala): a broad belt between two rolled rims, and a round clasp with a gem.
	gold.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.141, 0.0), Vector3(0.0, 0.13, 0.0), Vector3(0.0, 0.1, 0.0),
			Vector3(0.0, 0.089, 0.0), Vector3(0.0, 0.08, 0.0)]),
		PackedFloat32Array([0.212, 0.238, 0.228, 0.234, 0.246, 0.226]), PackedFloat32Array([0.166, 0.19, 0.181, 0.187, 0.198, 0.18]), 14, Palette.GOLD,
		{"fixed": true})))
	gold.append(_ball(Vector3(0.0, 0.115, -0.19), Vector3(0.05, 0.05, 0.02), Palette.GOLD, 3, 8))
	gems.append(_ball(Vector3(0.0, 0.115, -0.207), Vector3(0.022, 0.022, 0.012), Palette.SINDOOR, 3, 6))
	return [{&"cloth": cloth}, {&"gold": gold, &"lacquer_local": gems}, {&"fur": fur}]


func _spine_groups() -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	# Abdomen: narrow at the waist, with a lighter belly; its top tucks inside the ribcage.
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, -0.07, 0.0), Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.12, -0.004), Vector3(0.0, 0.23, -0.01)]),
		PackedFloat32Array([0.18, 0.164, 0.168, 0.176]), PackedFloat32Array([0.138, 0.13, 0.136, 0.142]), 14, Palette.HANUMAN_FUR,
		{"fixed": true, "front": FUR_LIGHT, "front_from": -0.3, "front_to": 0.45})))
	return [{&"fur": fur}]


func _chest_groups() -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	var pecs: Array[Dictionary] = []
	var gold: Array[Dictionary] = []
	var gems: Array[Dictionary] = []
	# Ribcage: a broad V from the waist to the shoulders, closing into the neck.
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, -0.13, 0.0), Vector3(0.0, -0.09, -0.004), Vector3(0.0, 0.0, -0.012), Vector3(0.0, 0.08, -0.016),
			Vector3(0.0, 0.15, -0.012), Vector3(0.0, 0.2, -0.004), Vector3(0.0, 0.236, 0.004), Vector3(0.0, 0.262, 0.008), Vector3(0.0, 0.31, 0.004)]),
		PackedFloat32Array([0.146, 0.182, 0.214, 0.25, 0.258, 0.224, 0.14, 0.086, 0.07]),
		PackedFloat32Array([0.108, 0.138, 0.16, 0.18, 0.18, 0.154, 0.114, 0.084, 0.074]), 14, Palette.HANUMAN_FUR,
		{"fixed": true, "front": FUR_LIGHT, "front_from": -0.3, "front_to": 0.45})))
	for sx: float in [-1.0, 1.0]:
		# The shoulder ball under the arm, and the trapezius sloping up to the neck.
		fur.append(_ball(Vector3(sx * 0.232, 0.174, 0.0), Vector3(0.088, 0.094, 0.09), Palette.HANUMAN_FUR, 5, 8))
		fur.append(_ball(Vector3(sx * 0.12, 0.226, 0.02), Vector3(0.11, 0.05, 0.075), Palette.HANUMAN_FUR, 4, 6))
		# Pectorals: broad flat plates, lighter than the body fur, sunk into the chest at the top.
		pecs.append(_ball(Vector3(sx * 0.098, 0.112, -0.146), Vector3(0.122, 0.088, 0.036), FUR_LIGHT, 5, 8, Vector3(10.0, sx * -24.0, sx * -6.0)))
	# Short collar (kantha) round the base of the neck.
	gold.append(_at(_tube(_necklace_path(0.105, 0.262, 0.03, 0.105, -0.115, 10), _fill(10, 0.014), _fill(10, 0.014), 3, Palette.GOLD, {"closed": true})))
	# Long necklace (hara) lying on the chest, with a pendant and a gem.
	gold.append(_at(_tube(_necklace_path(0.138, 0.256, 0.145, 0.1, -0.21, 14), _fill(14, 0.011), _fill(14, 0.011), 3, Palette.GOLD, {"closed": true})))
	gold.append(_ball(Vector3(0.0, 0.086, -0.212), Vector3(0.036, 0.042, 0.014), Palette.GOLD, 3, 8))
	gems.append(_ball(Vector3(0.0, 0.088, -0.225), Vector3(0.016, 0.02, 0.008), Palette.SINDOOR, 3, 6))
	return [{&"fur": fur}, {&"fur": pecs}, {&"gold": gold, &"lacquer_local": gems}]


## A closed loop that sits on the trapezius at the back and sides and hangs `drop` lower at the front.
static func _necklace_path(half_width: float, top_y: float, drop: float, back_z: float, front_z: float, points: int) -> PackedVector3Array:
	var path: PackedVector3Array = PackedVector3Array()
	for i: int in range(points):
		var a: float = TAU * float(i) / float(points)
		var front: float = maxf(0.0, cos(a))
		var mix: float = 0.5 + 0.5 * cos(a)
		path.append(Vector3(sin(a) * half_width, top_y - drop * pow(front, 1.3), lerpf(back_z, front_z, pow(mix, 0.8))))
	return path


func _upper_arm_groups(side: float) -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	var gold: Array[Dictionary] = []
	var gems: Array[Dictionary] = []
	# Shoulder to elbow: a full deltoid, the biceps in front and the triceps behind.
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(side * 0.008, -0.08, -0.004), Vector3(side * 0.016, -0.16, -0.006),
			Vector3(side * 0.024, -0.24, 0.0), Vector3(side * 0.03, -0.3, 0.0)]),
		PackedFloat32Array([0.1, 0.095, 0.088, 0.07, 0.064]), PackedFloat32Array([0.104, 0.104, 0.096, 0.074, 0.066]), 10, Palette.HANUMAN_FUR,
		{"fixed": true, "cap0": true, "cap1": true})))
	# Armlet (keyura): a band with rolled rims and a jewelled crest pointing up the arm.
	var mid: Vector3 = Vector3(side * 0.015, -0.15, -0.005)
	gold.append(_at(_tube(
		PackedVector3Array([mid + Vector3(0.0, 0.034, 0.0), mid + Vector3(0.0, 0.026, 0.0), mid + Vector3(0.0, -0.026, 0.0), mid + Vector3(0.0, -0.034, 0.0)]),
		PackedFloat32Array([0.086, 0.101, 0.099, 0.082]), PackedFloat32Array([0.094, 0.109, 0.107, 0.09]), 10, Palette.GOLD, {"fixed": true})))
	var crest_basis: Basis = Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(8.0))
	gold.append({"mesh": _leaf(0.1, 0.04, 0.012, Palette.GOLD), "transform": Transform3D(crest_basis, mid + Vector3(side * 0.098, -0.01, 0.0))})
	gems.append(_ball(mid + Vector3(side * 0.106, 0.0, 0.0), Vector3(0.01, 0.016, 0.014), Palette.SINDOOR, 2, 5))
	return [{&"fur": fur}, {&"gold": gold, &"lacquer_local": gems}]


func _lower_arm_groups(side: float) -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	var gold: Array[Dictionary] = []
	var skin: Array[Dictionary] = []
	# Elbow to wrist: a strong forearm tapering to the wrist.
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.07, -0.004), Vector3(0.0, -0.16, 0.0), Vector3(0.0, -0.255, 0.0)]),
		PackedFloat32Array([0.066, 0.076, 0.064, 0.046]), PackedFloat32Array([0.068, 0.08, 0.066, 0.05]), 8, Palette.HANUMAN_FUR,
		{"fixed": true, "cap0": true, "cap1": true})))
	# Bracelet (kankana): a cuff with rolled rims.
	gold.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, -0.188, 0.0), Vector3(0.0, -0.198, 0.0), Vector3(0.0, -0.21, 0.0), Vector3(0.0, -0.244, 0.0),
			Vector3(0.0, -0.256, 0.0)]),
		PackedFloat32Array([0.056, 0.07, 0.061, 0.064, 0.048]), PackedFloat32Array([0.058, 0.072, 0.063, 0.067, 0.05]), 8, Palette.GOLD,
		{"fixed": true})))
	# The hand: a closed fist with the thumb across the front.
	skin.append(_ball(Vector3(0.0, -0.308, -0.004), Vector3(0.046, 0.056, 0.056), SKIN, 4, 7))
	skin.append(_ball(Vector3(side * -0.012, -0.3, -0.05), Vector3(0.02, 0.032, 0.02), SKIN, 3, 5, Vector3(0.0, 0.0, side * 20.0)))
	for k: int in range(2):
		skin.append(_ball(Vector3(side * 0.03, -0.292 - float(k) * 0.032, -0.012), Vector3(0.026, 0.018, 0.038), SKIN, 2, 5))
	return [{&"fur": fur}, {&"gold": gold}, {&"skin": skin}]


func _upper_leg_groups() -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	var cloth: Array[Dictionary] = []
	# Thigh: heavy quadriceps tapering to the knee.
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.02, 0.0), Vector3(0.0, -0.1, -0.006), Vector3(0.0, -0.22, -0.006), Vector3(0.0, -0.34, 0.0), Vector3(0.0, -0.42, 0.0)]),
		PackedFloat32Array([0.102, 0.108, 0.1, 0.086, 0.08]), PackedFloat32Array([0.108, 0.118, 0.108, 0.09, 0.084]), 8, Palette.HANUMAN_FUR,
		{"fixed": true, "cap1": true})))
	# The dhoti drawn round the thigh: gathered pleats that open and move more toward the hem.
	cloth.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.05, 0.0), Vector3(0.0, -0.08, -0.006), Vector3(0.0, -0.21, -0.006), Vector3(0.0, -0.31, -0.002), Vector3(0.0, -0.375, 0.0)]),
		PackedFloat32Array([0.112, 0.122, 0.12, 0.118, 0.126]), PackedFloat32Array([0.118, 0.132, 0.128, 0.124, 0.132]), 16, Palette.SAFFRON,
		{"fixed": true, "flutes": 8, "flute0": 0.01, "flute1": 0.07, "wind0": 0.0, "wind1": 0.3,
		"front": SAFFRON_DEEP, "front_axis": Vector3(0.0, -1.0, 0.0)})))
	# A woven gold border along the hem; it is cloth too, so it moves with the pleats.
	cloth.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, -0.35, 0.0), Vector3(0.0, -0.378, 0.0)]),
		PackedFloat32Array([0.125, 0.13]), PackedFloat32Array([0.131, 0.136]), 16, Palette.GOLD,
		{"fixed": true, "flutes": 8, "flute0": 0.062, "flute1": 0.07, "wind0": 0.27, "wind1": 0.3})))
	return [{&"fur": fur}, {&"cloth": cloth}]



func _lower_leg_groups() -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	var skin: Array[Dictionary] = []
	var gold: Array[Dictionary] = []
	# Knee to ankle with the calf behind.
	fur.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.1, 0.012), Vector3(0.0, -0.2, 0.012), Vector3(0.0, -0.32, 0.004), Vector3(0.0, -0.43, 0.0)]),
		PackedFloat32Array([0.08, 0.086, 0.078, 0.058, 0.05]), PackedFloat32Array([0.084, 0.098, 0.088, 0.062, 0.054]), 8, Palette.HANUMAN_FUR,
		{"fixed": true, "cap0": true, "cap1": true})))
	# The foot, toes toward -Z, its sole on the ground (y = -0.5 below the knee).
	skin.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, -0.45, 0.05), Vector3(0.0, -0.454, -0.03), Vector3(0.0, -0.464, -0.12), Vector3(0.0, -0.475, -0.185)]),
		PackedFloat32Array([0.05, 0.056, 0.066, 0.058]), PackedFloat32Array([0.05, 0.046, 0.036, 0.025]), 7, SKIN,
		{"cap0": true, "cap1": true, "squash": 0.7})))
	# Anklet (nupura).
	gold.append(_at(_loop(Vector3(0.0, -0.39, 0.002), 0.06, 0.064, 0.014, 10, 3, Palette.GOLD)))
	return [{&"fur": fur}, {&"skin": skin}, {&"gold": gold}]


func _tail_groups(index: int) -> Array[Dictionary]:
	var fur: Array[Dictionary] = []
	var here: Vector3 = BONE_REST["tail_%d" % index] as Vector3
	var next: Vector3 = TAIL_TIP
	if index < TAIL_BONES - 1:
		next = BONE_REST["tail_%d" % (index + 1)] as Vector3
	var r0: float = _tail_radius(float(index))
	var r1: float = _tail_radius(float(index) + 1.0)
	if index < TAIL_BONES - 1:
		fur.append(_at(_tube(PackedVector3Array([Vector3.ZERO, next - here]),
			PackedFloat32Array([r0, r1]), PackedFloat32Array([r0, r1]), 6, Palette.HANUMAN_FUR,
			{"cap0": index == 0, "cap1": true, "squash": 0.7})))
	else:
		# The last bone carries the curl: the tail hooks round on itself and ends in a darker tuft.
		var curl_end: Vector3 = TAIL_CURL_END - here
		var tip: Vector3 = TAIL_TIP - here
		fur.append(_at(_tube(PackedVector3Array([Vector3.ZERO, tip * 0.55 + Vector3(0.0, 0.0, -0.016), tip, (tip + curl_end) * 0.5 + Vector3(0.0, -0.014, 0.0), curl_end]),
			PackedFloat32Array([r0, r0 * 0.96, r0 * 0.92, r0 * 0.95, r0 * 1.1]), PackedFloat32Array([r0, r0 * 0.96, r0 * 0.92, r0 * 0.95, r0 * 1.1]), 7, Palette.HANUMAN_FUR,
			{"cap1": true, "squash": 1.0})))
		fur.append(_ball(curl_end + Vector3(0.0, 0.012, 0.012), Vector3(0.036, 0.042, 0.036), FUR_DARK, 4, 6))
	return [{&"fur": fur}]


static func _tail_radius(at: float) -> float:
	return lerpf(0.06, 0.03, clampf(at / float(TAIL_BONES), 0.0, 1.0))


# ---------------------------------------------------------------- head

## Centre and radii of the smooth mask of skin that is his face (head bone space).
const _FACE_CENTRE: Vector3 = Vector3(0.0, 0.116, -0.06)
const _FACE_RADII: Vector3 = Vector3(0.104, 0.1, 0.086)


## The point of the face surface at (x, y) in head bone space, pushed `lift` metres out toward -Z.
static func _on_face(x: float, y: float, lift: float = 0.0) -> Vector3:
	var dx: float = (x - _FACE_CENTRE.x) / _FACE_RADII.x
	var dy: float = (y - _FACE_CENTRE.y) / _FACE_RADII.y
	var slice: float = sqrt(maxf(0.0, 1.0 - dx * dx - dy * dy))
	return Vector3(x, y, _FACE_CENTRE.z - _FACE_RADII.z * slice - lift)


func _head_groups() -> Array[Dictionary]:
	var centre: Vector3 = Vector3(0.0, 0.12, 0.0)
	var skull: Array[Dictionary] = []
	var muzzle: Array[Dictionary] = []
	var skin: Array[Dictionary] = []
	var brow: Array[Dictionary] = []
	var eyes: Array[Dictionary] = []
	var gold: Array[Dictionary] = []
	var gems: Array[Dictionary] = []
	var ear_gold: Array[Dictionary] = []
	var ear_gems: Array[Dictionary] = []

	# Skull, a mane round the jaw and the back of the head.
	skull.append(_ball(centre, Vector3(0.13, 0.14, 0.138), Palette.HANUMAN_FUR, 7, 10))
	for sx: float in [-1.0, 1.0]:
		skull.append(_ball(centre + Vector3(sx * 0.092, -0.07, -0.006), Vector3(0.046, 0.07, 0.066), Palette.HANUMAN_FUR, 4, 6, Vector3(0.0, 0.0, sx * 14.0)))
	skull.append(_ball(centre + Vector3(0.0, -0.05, 0.07), Vector3(0.104, 0.1, 0.084), FUR_DARK, 4, 7))

	# Muzzle, tinted with sindoor, protruding on -Z.
	var muzzle_centre: Vector3 = centre + Vector3(0.0, -0.06, -0.106)
	var muzzle_radii: Vector3 = Vector3(0.066, 0.045, 0.058)
	muzzle.append(_ball(muzzle_centre, muzzle_radii, MUZZLE, 5, 10))

	# Face: a smooth mask of skin, the nose, and the ears.
	skin.append(_ball(_FACE_CENTRE, _FACE_RADII, SKIN, 7, 12))
	skin.append(_ball(Vector3(0.0, 0.112, -0.136), Vector3(0.016, 0.04, 0.02), SKIN, 3, 6))
	skin.append(_ball(Vector3(0.0, 0.086, -0.152), Vector3(0.024, 0.017, 0.02), SKIN, 3, 6))
	for sx: float in [-1.0, 1.0]:
		skin.append(_ball(centre + Vector3(sx * 0.132, -0.004, 0.006), Vector3(0.016, 0.042, 0.03), SKIN, 3, 6, Vector3(0.0, sx * -24.0, 0.0)))
		# Brow: a high, open arch lying on the forehead (a calm face, never a frown).
		brow.append(_at(_tube(
			PackedVector3Array([_on_face(sx * 0.018, 0.166, 0.002), _on_face(sx * 0.046, 0.174, 0.003),
				_on_face(sx * 0.074, 0.171, 0.003), _on_face(sx * 0.092, 0.158, 0.002)]),
			PackedFloat32Array([0.005, 0.0075, 0.0065, 0.004]), PackedFloat32Array([0.005, 0.0075, 0.0065, 0.004]), 4, FUR_DARK)))
		# Eyes: large, moon-white, a dark iris, a point of light, and a fine dark line for the upper lid.
		var eye: Vector3 = _on_face(sx * 0.046, 0.134, -0.004)
		eyes.append(_ball(eye, Vector3(0.028, 0.019, 0.012), Palette.MOON, 4, 10))
		eyes.append(_ball(eye + Vector3(sx * -0.002, -0.001, -0.008), Vector3(0.014, 0.015, 0.006), Palette.UI_DARK, 3, 9))
		eyes.append(_ball(eye + Vector3(sx * -0.002 + 0.005, 0.005, -0.0135), Vector3(0.004, 0.004, 0.002), Palette.MOON, 2, 4))
		brow.append(_at(_tube(
			PackedVector3Array([eye + Vector3(sx * -0.028, 0.002, -0.004), eye + Vector3(sx * -0.012, 0.017, -0.011),
				eye + Vector3(sx * 0.01, 0.019, -0.01), eye + Vector3(sx * 0.03, 0.008, -0.001)]),
			PackedFloat32Array([0.002, 0.0034, 0.0034, 0.002]), PackedFloat32Array([0.002, 0.0034, 0.0034, 0.002]), 3, FUR_DARK)))
		# Nostrils.
		eyes.append(_ball(Vector3(sx * 0.009, 0.082, -0.1705), Vector3(0.005, 0.0035, 0.003), Palette.UI_DARK, 2, 4))
	# The gentle smile of a devotee: a fine line across the muzzle whose corners lift a little.
	var smile: PackedVector3Array = PackedVector3Array()
	for k: int in range(7):
		var f: float = lerpf(-1.0, 1.0, float(k) / 6.0)
		var a: float = f * deg_to_rad(36.0)
		var dy: float = -0.008 + 0.009 * f * f
		var slice: float = sqrt(1.0 - (dy / muzzle_radii.y) * (dy / muzzle_radii.y))
		smile.append(muzzle_centre + Vector3(muzzle_radii.x * sin(a) * slice, dy, -(muzzle_radii.z * cos(a) * slice + 0.001)))
	eyes.append(_at(_tube(smile, PackedFloat32Array([0.001, 0.0022, 0.0026, 0.0026, 0.0026, 0.0022, 0.001]),
		PackedFloat32Array([0.001, 0.0022, 0.0026, 0.0026, 0.0026, 0.0022, 0.001]), 3, Palette.BARK)))
	# Tilak: a sindoor mark on the forehead.
	gems.append({"mesh": MeshKit.sphere_smooth(1.0, 2, 5, Palette.SINDOOR),
		"transform": Transform3D(Basis.from_euler(Vector3(deg_to_rad(-22.0), 0.0, 0.0)).scaled_local(Vector3(0.007, 0.017, 0.005)), _on_face(0.0, 0.18, 0.001))})

	_add_mukuta(gold, gems)

	# Kundala earrings: a ring hanging from each ear, with a jewel at its heart.
	for sx: float in [-1.0, 1.0]:
		var ring_basis: Basis = Basis(Vector3.UP, sx * deg_to_rad(38.0)) * Basis(Vector3.RIGHT, PI * 0.5)
		ear_gold.append({"mesh": _loop(Vector3.ZERO, 0.03, 0.03, 0.0075, 8, 3, Palette.GOLD),
			"transform": Transform3D(ring_basis, centre + Vector3(sx * 0.142, -0.068, 0.0))})
		ear_gems.append(_ball(centre + Vector3(sx * 0.146, -0.068, -0.004), Vector3(0.012, 0.012, 0.012), Palette.SINDOOR, 2, 5))
	return [
		{&"fur": skull},
		{&"skin": muzzle},
		{&"skin": skin, &"fur": brow, &"lacquer_local": eyes},
		{&"gold": gold, &"lacquer_local": gems},
		{&"gold": ear_gold, &"lacquer_local": ear_gems},
	]


## The mukuta: a layered band round the brow, a stepped dome, a tall central spire with a kalasha finial, a jewelled
## crest at the front, and leaf points round the sides and back.
func _add_mukuta(gold: Array[Dictionary], gems: Array[Dictionary]) -> void:
	var band_x: float = 0.129
	var band_z: float = 0.138
	# Band with rolled rims.
	gold.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.184, 0.0), Vector3(0.0, 0.191, 0.0), Vector3(0.0, 0.199, 0.0), Vector3(0.0, 0.219, 0.0),
			Vector3(0.0, 0.226, 0.0), Vector3(0.0, 0.232, 0.0)]),
		PackedFloat32Array([band_x - 0.014, band_x + 0.006, band_x - 0.002, band_x - 0.004, band_x + 0.003, band_x - 0.016]),
		PackedFloat32Array([band_z - 0.014, band_z + 0.006, band_z - 0.002, band_z - 0.004, band_z + 0.003, band_z - 0.016]), 14, Palette.GOLD,
		{"fixed": true})))
	# Stepped tiers: each a little bowl with a flared lip, then the dome.
	gold.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.228, 0.0), Vector3(0.0, 0.246, 0.0), Vector3(0.0, 0.253, 0.0), Vector3(0.0, 0.257, 0.0),
			Vector3(0.0, 0.272, 0.0), Vector3(0.0, 0.279, 0.0), Vector3(0.0, 0.283, 0.0), Vector3(0.0, 0.304, 0.0)]),
		PackedFloat32Array([0.116, 0.106, 0.113, 0.094, 0.08, 0.087, 0.064, 0.028]),
		PackedFloat32Array([0.124, 0.112, 0.119, 0.098, 0.084, 0.09, 0.066, 0.028]), 12, Palette.GOLD,
		{"fixed": true, "flutes": 6, "flute0": 0.03, "flute1": 0.03})))
	# Central spire: neck, kalasha bulb, bead, point.
	gold.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.302, 0.0), Vector3(0.0, 0.309, 0.0), Vector3(0.0, 0.32, 0.0), Vector3(0.0, 0.329, 0.0),
			Vector3(0.0, 0.334, 0.0), Vector3(0.0, 0.34, 0.0), Vector3(0.0, 0.352, 0.0)]),
		PackedFloat32Array([0.028, 0.015, 0.026, 0.017, 0.008, 0.012, 0.0]),
		PackedFloat32Array([0.028, 0.015, 0.026, 0.017, 0.008, 0.012, 0.0]), 6, Palette.GOLD, {"fixed": true})))
	# Front crest and its gem.
	gold.append({"mesh": _leaf(0.116, 0.054, 0.014, Palette.GOLD),
		"transform": Transform3D(Basis(Vector3.RIGHT, deg_to_rad(9.0)), Vector3(0.0, 0.212, -band_z - 0.004))})
	gems.append(_ball(Vector3(0.0, 0.252, -band_z - 0.022), Vector3(0.015, 0.02, 0.008), Palette.SINDOOR, 3, 6))
	# Side and back points, leaning outward like the petals of a lotus.
	for degrees: float in [52.0, -52.0, 112.0, -112.0, 180.0]:
		var a: float = deg_to_rad(degrees)
		var out: Vector3 = Vector3(sin(a), 0.0, -cos(a))
		var point_basis: Basis = Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, deg_to_rad(-12.0))
		gold.append({"mesh": _leaf(0.086, 0.042, 0.012, Palette.GOLD),
			"transform": Transform3D(point_basis, Vector3(out.x * band_x, 0.218, out.z * band_z))})
		gems.append(_ball(Vector3(out.x * (band_x + 0.004), 0.209, out.z * (band_z + 0.004)), Vector3(0.009, 0.009, 0.009), Palette.SINDOOR, 2, 4))


# ---------------------------------------------------------------- gada

func _gada_groups() -> Array[Dictionary]:
	var shaft: Array[Dictionary] = []
	var head: Array[Dictionary] = []
	var trim: Array[Dictionary] = []
	# Shaft with a pommel below the hand and grip rings.
	shaft.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, -0.17, 0.0), Vector3(0.0, -0.15, 0.0), Vector3(0.0, -0.128, 0.0), Vector3(0.0, -0.11, 0.0),
			Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.5, 0.0)]),
		PackedFloat32Array([0.0, 0.03, 0.03, 0.02, 0.022, 0.028]), PackedFloat32Array([0.0, 0.03, 0.03, 0.02, 0.022, 0.028]), 8, Palette.GOLD,
		{"fixed": true})))
	for y: float in [-0.07, 0.07]:
		shaft.append(_at(_loop(Vector3(0.0, y, 0.0), 0.027, 0.027, 0.008, 8, 3, Palette.GOLD)))
	# Head: a heavy bulb, broadest above its middle, bound by a raised band.
	head.append(_ball(Vector3(0.0, 0.65, 0.0), Vector3(0.15, 0.14, 0.15), Palette.GOLD, 7, 14))
	head.append(_at(_loop(Vector3(0.0, 0.65, 0.0), 0.152, 0.152, 0.012, 14, 3, Palette.GOLD)))
	# Stepped collar under the head and a kalasha finial on top.
	trim.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.46, 0.0), Vector3(0.0, 0.48, 0.0), Vector3(0.0, 0.49, 0.0), Vector3(0.0, 0.515, 0.0), Vector3(0.0, 0.53, 0.0)]),
		PackedFloat32Array([0.03, 0.05, 0.04, 0.066, 0.05]), PackedFloat32Array([0.03, 0.05, 0.04, 0.066, 0.05]), 6, Palette.GOLD, {"fixed": true})))
	trim.append(_at(_tube(
		PackedVector3Array([Vector3(0.0, 0.775, 0.0), Vector3(0.0, 0.79, 0.0), Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.818, 0.0),
			Vector3(0.0, 0.832, 0.0), Vector3(0.0, 0.862, 0.0)]),
		PackedFloat32Array([0.06, 0.04, 0.02, 0.034, 0.016, 0.0]), PackedFloat32Array([0.06, 0.04, 0.02, 0.034, 0.016, 0.0]), 6, Palette.GOLD, {"fixed": true})))
	return [{&"gold": shaft}, {&"gold": head}, {&"gold": trim}]


# ---------------------------------------------------------------- mesh helpers

static func _part(mesh: ArrayMesh, offset: Vector3, euler_degrees: Vector3 = Vector3.ZERO,
		size_scale: Vector3 = Vector3.ONE) -> Dictionary:
	var part_basis: Basis = Basis.from_euler(euler_degrees * (PI / 180.0)).scaled_local(size_scale)
	return {"mesh": mesh, "transform": Transform3D(part_basis, offset)}


## A merge() part with no transform.
static func _at(mesh: ArrayMesh) -> Dictionary:
	return {"mesh": mesh, "transform": Transform3D()}


## A unit sphere mesh placed as an ellipsoid: `radii` along its own axes, turned by `euler_degrees`.
static func _ell(centre: Vector3, radii: Vector3, unit_sphere: ArrayMesh, euler_degrees: Vector3 = Vector3.ZERO) -> Dictionary:
	return _part(unit_sphere, centre, euler_degrees, radii)


## An ellipsoid of the given radii and tessellation, turned by `euler_degrees`.
static func _ball(centre: Vector3, radii: Vector3, color: Color, rings: int, segments: int, euler_degrees: Vector3 = Vector3.ZERO) -> Dictionary:
	return _part(MeshKit.sphere_smooth(1.0, rings, segments, color), centre, euler_degrees, radii)


static func _fill(count: int, value: float) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count)
	result.fill(value)
	return result


## A closed ring (torus) in the XZ plane: an ellipse of radii `rx`, `rz` round `centre`, swept by a circle `thick`.
static func _loop(centre: Vector3, rx: float, rz: float, thick: float, points: int, sides: int, color: Color) -> ArrayMesh:
	var path: PackedVector3Array = PackedVector3Array()
	for i: int in range(points):
		var a: float = TAU * float(i) / float(points)
		path.append(centre + Vector3(cos(a) * rx, 0.0, sin(a) * rz))
	return _tube(path, _fill(points, thick), _fill(points, thick), sides, color, {"closed": true})


## A pointed leaf standing on its base at the origin: `height` along +Y, `width` along X, `thick` along Z.
static func _leaf(height: float, width: float, thick: float, color: Color) -> ArrayMesh:
	return _tube(
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, height * 0.34, 0.0), Vector3(0.0, height * 0.7, 0.0), Vector3(0.0, height, 0.0)]),
		PackedFloat32Array([width * 0.3, width * 0.5, width * 0.32, 0.0]),
		PackedFloat32Array([thick * 0.5, thick * 0.5, thick * 0.36, 0.0]), 4, color, {"fixed": true})


## Smooth-shaded tube: an ellipse (radii rx[i], rz[i]) swept along `path`. This one primitive makes the limbs, the
## torso, the cloth, the rings and the turned gold work.
## Options:
##   fixed        keep every ring in the XZ plane (a lathe with shifting centres) instead of following the path;
##   closed       the path is a loop (a ring), no ends;
##   cap0, cap1   close the start / end with a dome; `squash` scales the dome's depth (1 = hemisphere);
##   flutes       number of ridges round the section, with depth flute0 at the start and flute1 at the end;
##   front        second colour blended in where the surface faces `front_axis` (default -Z, the front of the body),
##                between the facing values front_from and front_to;
##   wind0, wind1 wind weight (vertex colour alpha) at the start and the end, interpolated along the path.
static func _tube(path: PackedVector3Array, rx: PackedFloat32Array, rz: PackedFloat32Array, sides: int, color: Color,
		opts: Dictionary = {}) -> ArrayMesh:
	var closed: bool = opts.get("closed", false) as bool
	var fixed: bool = opts.get("fixed", false) as bool
	var cap0: bool = (opts.get("cap0", false) as bool) and not closed
	var cap1: bool = (opts.get("cap1", false) as bool) and not closed
	var squash: float = opts.get("squash", 0.85) as float
	var flutes: int = opts.get("flutes", 0) as int
	var flute0: float = opts.get("flute0", 0.0) as float
	var flute1: float = opts.get("flute1", flute0) as float
	var front: Color = opts.get("front", color) as Color
	var front_axis: Vector3 = opts.get("front_axis", Vector3(0.0, 0.0, -1.0)) as Vector3
	var front_from: float = opts.get("front_from", 0.1) as float
	var front_to: float = opts.get("front_to", 0.8) as float
	var wind0: float = opts.get("wind0", 1.0) as float
	var wind1: float = opts.get("wind1", wind0) as float
	var count: int = path.size()

	# Ring frames along the path (parallel transport, so a curved tube does not twist).
	var centres: PackedVector3Array = PackedVector3Array()
	var axes_u: PackedVector3Array = PackedVector3Array()
	var axes_v: PackedVector3Array = PackedVector3Array()
	var radii_u: PackedFloat32Array = PackedFloat32Array()
	var radii_v: PackedFloat32Array = PackedFloat32Array()
	var along: PackedFloat32Array = PackedFloat32Array()
	var tangents: PackedVector3Array = PackedVector3Array()
	var previous_u: Vector3 = Vector3.ZERO
	for i: int in range(count):
		var before: Vector3 = path[(i - 1 + count) % count] if closed else path[maxi(i - 1, 0)]
		var after: Vector3 = path[(i + 1) % count] if closed else path[mini(i + 1, count - 1)]
		var tangent: Vector3 = (after - before).normalized()
		var u: Vector3 = Vector3.RIGHT
		var v: Vector3 = Vector3.BACK
		if not fixed:
			var reference: Vector3 = previous_u
			if i == 0:
				reference = Vector3.RIGHT if absf(tangent.x) < 0.9 else Vector3.BACK
			u = (reference - tangent * reference.dot(tangent)).normalized()
			v = tangent.cross(u)
		previous_u = u
		tangents.append(tangent)
		centres.append(path[i])
		axes_u.append(u)
		axes_v.append(v)
		radii_u.append(rx[i])
		radii_v.append(rz[i])
		along.append(float(i) / float(maxi(count - 1, 1)))
	if cap0:
		_add_cap(centres, axes_u, axes_v, radii_u, radii_v, along, tangents, 0, -1.0, squash, true)
	if cap1:
		_add_cap(centres, axes_u, axes_v, radii_u, radii_v, along, tangents, centres.size() - 1, 1.0, squash, false)

	var rings: int = centres.size()
	var points: PackedVector3Array = PackedVector3Array()
	points.resize(rings * sides)
	for i: int in range(rings):
		var depth: float = lerpf(flute0, flute1, along[i])
		for j: int in range(sides):
			var angle: float = TAU * float(j) / float(sides)
			var ripple: float = 1.0
			if flutes > 0:
				ripple = 1.0 + depth * cos(angle * float(flutes))
			points[i * sides + j] = centres[i] + axes_u[i] * (radii_u[i] * cos(angle) * ripple) + axes_v[i] * (radii_v[i] * sin(angle) * ripple)

	# Smooth normals from the grid itself, so flutes, tapers and domes all shade correctly.
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(rings * sides)
	for i: int in range(rings):
		var up_ring: int = (i + 1) % rings if closed else mini(i + 1, rings - 1)
		var down_ring: int = (i - 1 + rings) % rings if closed else maxi(i - 1, 0)
		var pole: bool = maxf(radii_u[i], radii_v[i]) < 1e-6
		for j: int in range(sides):
			var normal: Vector3 = Vector3.ZERO
			if not pole:
				var around: Vector3 = points[i * sides + (j + 1) % sides] - points[i * sides + (j - 1 + sides) % sides]
				var lengthwise: Vector3 = points[up_ring * sides + j] - points[down_ring * sides + j]
				normal = around.cross(lengthwise)
				if normal.dot(points[i * sides + j] - centres[i]) < 0.0:
					normal = -normal
			if normal.length_squared() < 1e-16:
				var other: int = up_ring if i == 0 else down_ring
				normal = centres[i] - centres[other]
				if normal.length_squared() < 1e-16:
					normal = Vector3.UP
			normals[i * sides + j] = normal.normalized()

	var colors: PackedColorArray = PackedColorArray()
	colors.resize(rings * sides)
	var blend_front: bool = not front.is_equal_approx(color)
	for i: int in range(rings):
		var weight: float = clampf(lerpf(wind0, wind1, along[i]), 0.0, 1.0)
		for j: int in range(sides):
			var tint: Color = color
			if blend_front:
				tint = color.lerp(front, smoothstep(front_from, front_to, normals[i * sides + j].dot(front_axis)))
			tint.a = weight
			colors[i * sides + j] = tint

	var out_points: PackedVector3Array = PackedVector3Array()
	var out_normals: PackedVector3Array = PackedVector3Array()
	var out_colors: PackedColorArray = PackedColorArray()
	var last_ring: int = rings if closed else rings - 1
	for i: int in range(last_ring):
		var next_ring: int = (i + 1) % rings
		for j: int in range(sides):
			var next_side: int = (j + 1) % sides
			var a: int = i * sides + j
			var b: int = i * sides + next_side
			var c: int = next_ring * sides + next_side
			var d: int = next_ring * sides + j
			_emit(out_points, out_normals, out_colors, points, normals, colors, a, b, c)
			_emit(out_points, out_normals, out_colors, points, normals, colors, a, c, d)
	var mesh: ArrayMesh = ArrayMesh.new()
	if out_points.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_points
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_COLOR] = out_colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Adds the two rings of a dome (a shoulder ring and the pole) before the first ring or after the last one.
static func _add_cap(centres: PackedVector3Array, axes_u: PackedVector3Array, axes_v: PackedVector3Array,
		radii_u: PackedFloat32Array, radii_v: PackedFloat32Array, along: PackedFloat32Array, tangents: PackedVector3Array,
		ring: int, direction: float, squash: float, at_start: bool) -> void:
	var centre: Vector3 = centres[ring]
	var u: Vector3 = axes_u[ring]
	var v: Vector3 = axes_v[ring]
	var ru: float = radii_u[ring]
	var rv: float = radii_v[ring]
	var t: float = along[ring]
	var tangent: Vector3 = tangents[ring]
	var axis: Vector3 = u.cross(v).normalized()
	if axis.dot(tangent) < 0.0:
		axis = -axis
	axis *= direction
	var depth: float = (ru + rv) * 0.5 * squash
	var steps: Array[float] = [deg_to_rad(52.0), PI * 0.5]
	for k: int in range(steps.size()):
		var phi: float = steps[k]
		var at: int = 0 if at_start else centres.size()
		centres.insert(at, centre + axis * (depth * sin(phi)))
		axes_u.insert(at, u)
		axes_v.insert(at, v)
		radii_u.insert(at, ru * maxf(cos(phi), 0.0) if k == 0 else 0.0)
		radii_v.insert(at, rv * maxf(cos(phi), 0.0) if k == 0 else 0.0)
		along.insert(at, t)
		tangents.insert(at, tangent)


## Appends one triangle, wound clockwise seen from outside (Godot's front face), dropping degenerate ones.
static func _emit(out_points: PackedVector3Array, out_normals: PackedVector3Array, out_colors: PackedColorArray,
		points: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, a: int, b: int, c: int) -> void:
	var face: Vector3 = (points[c] - points[a]).cross(points[b] - points[a])
	if face.length_squared() < 1e-16:
		return
	var second: int = b
	var third: int = c
	if face.dot(normals[a] + normals[b] + normals[c]) < 0.0:
		second = c
		third = b
	for index: int in [a, second, third]:
		out_points.append(points[index])
		out_normals.append(normals[index])
		out_colors.append(colors[index])
