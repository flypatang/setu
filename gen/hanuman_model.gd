class_name HanumanModel
extends Node3D
## Procedural Hanuman (DESIGN §6.2, M07). A Skeleton3D is built in code with the bones listed in §9. Each bone gets
## one BoneAttachment3D, and rigid MeshKit parts hang under it. Poses are bone-rotation tables, so nothing is skinned.
## Colours come only from Palette. The feet sit at y = 0 and the standing model is about 1.82 m tall.
##
## Orientation: forward is -Z. The face and muzzle are on -Z, the toes point to -Z, and the tail curls up behind him on +Z.
## The gada is held in the right hand (bone gada_socket). Its head points up along the socket's +Y, so at rest it stands
## upright beside the right shoulder.

const BONE_NAMES: PackedStringArray = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	"tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7",
	"gada_socket",
]

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
	"gada_socket": "lower_arm_r",
}

## Rest position of each bone in model space, in metres. The tail rises and curls behind him (+Z).
const BONE_REST: Dictionary = {
	"root": Vector3(0.0, 0.0, 0.0),
	"hips": Vector3(0.0, 0.95, 0.0),
	"spine": Vector3(0.0, 1.12, 0.0),
	"chest": Vector3(0.0, 1.32, 0.0),
	"head": Vector3(0.0, 1.54, 0.0),
	"upper_arm_l": Vector3(0.23, 1.5, 0.0),
	"lower_arm_l": Vector3(0.26, 1.2, 0.0),
	"upper_arm_r": Vector3(-0.23, 1.5, 0.0),
	"lower_arm_r": Vector3(-0.26, 1.2, 0.0),
	"upper_leg_l": Vector3(0.12, 0.92, 0.0),
	"lower_leg_l": Vector3(0.12, 0.5, 0.0),
	"upper_leg_r": Vector3(-0.12, 0.92, 0.0),
	"lower_leg_r": Vector3(-0.12, 0.5, 0.0),
	"tail_0": Vector3(0.0, 0.95, 0.14),
	"tail_1": Vector3(0.0, 0.93, 0.26),
	"tail_2": Vector3(0.0, 0.97, 0.38),
	"tail_3": Vector3(0.0, 1.05, 0.47),
	"tail_4": Vector3(0.0, 1.17, 0.52),
	"tail_5": Vector3(0.0, 1.3, 0.52),
	"tail_6": Vector3(0.0, 1.42, 0.46),
	"tail_7": Vector3(0.0, 1.5, 0.37),
	"gada_socket": Vector3(-0.26, 0.92, 0.0),
}

## Where the tail tip ends: the curl turns forward and then down a little at the top.
const TAIL_TIP: Vector3 = Vector3(0.0, 1.53, 0.27)

## Slightly lighter fur for the chest and face (HANUMAN_FUR lightened by about 14%, stored as an exact 8-bit colour).
const FUR_LIGHT: Color = Color("#D09B56")

## Pose tables: bone name -> euler rotation in degrees, relative to rest. Bones not listed return to rest.
## Rotating about +X by a positive angle moves a hanging limb toward -Z (forward). Meditate folds the legs forward.
const POSES: Dictionary = {
	"idle": {
		"chest": Vector3(2.0, 0.0, 0.0),
		"upper_arm_l": Vector3(0.0, 0.0, -6.0),
		"upper_arm_r": Vector3(0.0, 0.0, 6.0),
		"tail_0": Vector3(-3.0, 0.0, 0.0),
	},
	"walk_a": {
		"hips": Vector3(0.0, 0.0, 3.0),
		"upper_leg_l": Vector3(25.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-10.0, 0.0, 0.0),
		"upper_leg_r": Vector3(-20.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-20.0, 0.0, -6.0),
		"upper_arm_r": Vector3(20.0, 0.0, 6.0),
	},
	"walk_b": {
		"hips": Vector3(0.0, 0.0, -3.0),
		"upper_leg_l": Vector3(-20.0, 0.0, 0.0),
		"upper_leg_r": Vector3(25.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-10.0, 0.0, 0.0),
		"upper_arm_l": Vector3(20.0, 0.0, -6.0),
		"upper_arm_r": Vector3(-20.0, 0.0, 6.0),
	},
	"attack_wind": {
		"chest": Vector3(0.0, -25.0, 0.0),
		"upper_arm_r": Vector3(-140.0, 0.0, -20.0),
		"lower_arm_r": Vector3(-30.0, 0.0, 0.0),
	},
	"attack_strike": {
		"chest": Vector3(0.0, 30.0, 0.0),
		"upper_arm_r": Vector3(70.0, 0.0, 0.0),
		"lower_arm_r": Vector3(-10.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-30.0, 0.0, -10.0),
	},
	"meditate": {
		"chest": Vector3(-6.0, 0.0, 0.0),
		"head": Vector3(4.0, 0.0, 0.0),
		"upper_arm_l": Vector3(40.0, 0.0, -30.0),
		"upper_arm_r": Vector3(40.0, 0.0, 30.0),
		"lower_arm_l": Vector3(60.0, 0.0, 0.0),
		"lower_arm_r": Vector3(60.0, 0.0, 0.0),
		"upper_leg_l": Vector3(80.0, 0.0, 0.0),
		"upper_leg_r": Vector3(80.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-40.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-40.0, 0.0, 0.0),
	},
}

var _skeleton: Skeleton3D = null
var _pose: StringName = &"idle"


## Builds the rig and the body parts as children of this node, then returns this node. Calling it again is a no-op
## while the rig exists.
func build() -> Node3D:
	_ensure_rig()
	return self


func get_skeleton() -> Skeleton3D:
	return _skeleton


func current_pose() -> StringName:
	return _pose


## Sets the bone rotations for a named pose. Position and scale are reset to rest first. An unknown name is
## reported with a warning and leaves the current pose unchanged.
func set_pose(pose: StringName) -> void:
	if not POSES.has(String(pose)):
		push_warning("HanumanModel: unknown pose '%s', pose unchanged." % String(pose))
		return
	_ensure_rig()
	_skeleton.reset_bone_poses()
	var table: Dictionary = POSES[String(pose)] as Dictionary
	for bone_key: Variant in table:
		var index: int = _skeleton.find_bone(bone_key as String)
		if index < 0:
			continue
		var euler: Vector3 = table[bone_key] as Vector3
		_skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(euler * (PI / 180.0)))
	_pose = pose


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
	for bone_name: String in BONE_NAMES:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "Attach_" + bone_name
		attachment.bone_name = bone_name
		_skeleton.add_child(attachment)
		var part_index: int = 0
		for part: Dictionary in _bone_parts(bone_name):
			var mesh_instance: MeshInstance3D = MeshInstance3D.new()
			mesh_instance.name = bone_name + "_part_" + str(part_index)
			mesh_instance.mesh = part["mesh"] as ArrayMesh
			mesh_instance.transform = part["transform"] as Transform3D
			mesh_instance.material_override = MeshKit.flat_material()
			attachment.add_child(mesh_instance)
			part_index += 1


## The rigid parts hanging under one bone, each a MeshKit mesh and a transform relative to the bone joint.
func _bone_parts(bone_name: String) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var fur: Color = Palette.HANUMAN_FUR
	var gold: Color = Palette.GOLD
	match bone_name:
		"hips":
			# Saffron dhoti: a wide cone frustum to the knees, a gold waist sash, and a drape of cloth at the front.
			parts.append(_part(MeshKit.cylinder(0.2, 0.31, 0.46, 12, Palette.SAFFRON), Vector3(0.0, -0.13, 0.0),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.85)))
			parts.append(_part(MeshKit.cylinder(0.225, 0.225, 0.05, 12, gold), Vector3(0.0, 0.1, 0.0),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.85)))
			parts.append(_part(MeshKit.box(Vector3(0.12, 0.3, 0.03), Palette.SAFFRON), Vector3(0.0, -0.2, -0.27),
				Vector3(-8.0, 0.0, 0.0)))
		"spine":
			parts.append(_part(MeshKit.cylinder(0.18, 0.17, 0.24, 10, fur), Vector3(0.0, 0.1, 0.0),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.75)))
		"chest":
			# Broad V-shaped torso: a frustum wide at the shoulders and narrow at the waist, with a lighter chest plate.
			parts.append(_part(MeshKit.cylinder(0.27, 0.17, 0.42, 12, fur), Vector3(0.0, 0.1, 0.0),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.62)))
			parts.append(_part(MeshKit.cylinder(0.215, 0.145, 0.36, 10, FUR_LIGHT), Vector3(0.0, 0.1, -0.035),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.62)))
			# Trapezius slope up to the neck.
			parts.append(_part(MeshKit.cylinder(0.07, 0.2, 0.07, 10, fur), Vector3(0.0, 0.265, 0.0),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.8)))
			# Deltoids at the shoulder joints.
			parts.append(_part(MeshKit.sphere(0.105, 5, 8, fur), Vector3(0.23, 0.18, 0.0)))
			parts.append(_part(MeshKit.sphere(0.105, 5, 8, fur), Vector3(-0.23, 0.18, 0.0)))
			# Sacred thread-style gold chest band.
			parts.append(_part(MeshKit.cylinder(0.23, 0.215, 0.04, 12, gold), Vector3(0.0, 0.17, -0.005),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.64)))
		"head":
			# Skull (parts 0), protruding sindoor muzzle on -Z (part 1), lighter face mask, brow ridge, eyes, ears, crown.
			parts.append(_part(MeshKit.sphere(0.148, 6, 10, fur), Vector3(0.0, 0.1, 0.0),
				Vector3.ZERO, Vector3(1.0, 1.1, 1.0)))
			parts.append(_part(MeshKit.sphere(0.082, 5, 8, Palette.SINDOOR), Vector3(0.0, 0.045, -0.15),
				Vector3.ZERO, Vector3(1.15, 0.85, 1.25)))
			parts.append(_part(MeshKit.sphere(0.108, 5, 8, FUR_LIGHT), Vector3(0.0, 0.1, -0.085),
				Vector3.ZERO, Vector3(1.05, 0.95, 0.8)))
			parts.append(_part(MeshKit.box(Vector3(0.27, 0.05, 0.08), fur), Vector3(0.0, 0.16, -0.125)))
			for sx: float in [-1.0, 1.0]:
				parts.append(_part(MeshKit.sphere(0.03, 4, 6, Palette.MOON), Vector3(sx * 0.06, 0.125, -0.17),
					Vector3.ZERO, Vector3(1.0, 0.8, 0.6)))
				parts.append(_part(MeshKit.sphere(0.014, 3, 5, Palette.UI_DARK), Vector3(sx * 0.06, 0.125, -0.188)))
				parts.append(_part(MeshKit.sphere(0.04, 4, 6, fur), Vector3(sx * 0.15, 0.105, 0.0),
					Vector3.ZERO, Vector3(0.5, 1.0, 0.8)))
			# Gold crown (mukuta): a band and five tall points at 72 degree steps.
			parts.append(_part(MeshKit.cylinder(0.155, 0.16, 0.05, 12, gold), Vector3(0.0, 0.195, 0.0)))
			for k: int in range(5):
				var angle: float = TAU * float(k) / 5.0
				parts.append(_part(MeshKit.cone(0.042, 0.15, 5, gold),
					Vector3(sin(angle) * 0.105, 0.27, cos(angle) * 0.105)))
		"upper_arm_l", "upper_arm_r":
			parts.append(_part(MeshKit.cylinder(0.09, 0.07, 0.3, 8, fur), Vector3(0.0, -0.15, 0.0)))
			# Gold armlet.
			parts.append(_part(MeshKit.cylinder(0.098, 0.098, 0.06, 8, gold), Vector3(0.0, -0.1, 0.0)))
		"lower_arm_l", "lower_arm_r":
			parts.append(_part(MeshKit.cylinder(0.07, 0.052, 0.28, 8, fur), Vector3(0.0, -0.14, 0.0)))
			# Gold wristband and a fist.
			parts.append(_part(MeshKit.cylinder(0.066, 0.066, 0.045, 8, gold), Vector3(0.0, -0.23, 0.0)))
			parts.append(_part(MeshKit.sphere(0.06, 4, 8, fur), Vector3(0.0, -0.3, 0.0)))
		"upper_leg_l", "upper_leg_r":
			parts.append(_part(MeshKit.cylinder(0.105, 0.08, 0.44, 8, fur), Vector3(0.0, -0.22, 0.0)))
		"lower_leg_l", "lower_leg_r":
			parts.append(_part(MeshKit.cylinder(0.08, 0.055, 0.46, 8, fur), Vector3(0.0, -0.23, 0.0)))
			# Foot: its toes point to -Z (forward).
			parts.append(_part(MeshKit.box(Vector3(0.13, 0.07, 0.26), fur), Vector3(0.0, -0.465, -0.05)))
		"gada_socket":
			# Gada in the right hand: a gold shaft rising from the socket, a wide club head, and a gold collar.
			parts.append(_part(MeshKit.cylinder(0.026, 0.03, 0.66, 8, gold), Vector3(0.0, 0.31, 0.0)))
			parts.append(_part(MeshKit.sphere(0.15, 6, 10, gold), Vector3(0.0, 0.74, 0.0)))
			parts.append(_part(MeshKit.cylinder(0.07, 0.04, 0.06, 8, gold), Vector3(0.0, 0.62, 0.0)))
			parts.append(_part(MeshKit.cone(0.04, 0.07, 6, gold), Vector3(0.0, 0.89, 0.0)))
		_:
			if bone_name.begins_with("tail_"):
				var index: int = int(bone_name.substr(5))
				var here: Vector3 = BONE_REST[bone_name] as Vector3
				var next: Vector3 = TAIL_TIP
				if index < 7:
					next = BONE_REST["tail_%d" % (index + 1)] as Vector3
				var along: Vector3 = next - here
				var radius: float = lerpf(0.058, 0.032, float(index) / 7.0)
				var aim: Basis = Basis(Quaternion(Vector3.UP, along.normalized()))
				var seg: Mesh = MeshKit.cylinder(radius * 0.92, radius, along.length() * 1.08, 6, fur)
				parts.append({"mesh": seg, "transform": Transform3D(aim, along * 0.5)})
				if index == 7:
					# Raised curl at the tip: a gold-free fur ball ending the tail.
					parts.append(_part(MeshKit.sphere(0.04, 4, 6, fur), along))
	return parts


static func _part(mesh: ArrayMesh, offset: Vector3, euler_degrees: Vector3 = Vector3.ZERO,
		size_scale: Vector3 = Vector3.ONE) -> Dictionary:
	var part_basis: Basis = Basis.from_euler(euler_degrees * (PI / 180.0)).scaled(size_scale)
	return {"mesh": mesh, "transform": Transform3D(part_basis, offset)}
