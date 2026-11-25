class_name BridgeView
extends Node3D
## Bridge meshes, one group per section (DESIGN §9, S14).
## Reads the Bridge simulation and never writes to it. Each section shows its foundation stones
## (WET_STONE, each topped with a Rama glyph), its timber deck (BARK) and its rope lashings (ROPE).
## Broken sections drift away along +z and sink; blessed sections play a short gold shimmer.
## Only sections whose visible state changed are rebuilt.

const SECTION_LENGTH: float = 1.0
const SECTION_CENTER_X: float = 0.5
const STONE_SIZE: Vector3 = Vector3(0.9, 0.5, 0.2)
const STONE_SPACING: float = 0.25
const GLYPH_SIZE: Vector3 = Vector3(0.5, 0.02, 0.1)
const PLANK_SIZE: Vector3 = Vector3(1.0, 0.08, 0.15)
const PLANK_SPACING: float = 0.2
const PLANK_HEIGHT: float = 0.54
const LASHING_SIZE: Vector3 = Vector3(0.08, 0.12, 0.8)
const LASHING_HEIGHT: float = 0.62
const SHIMMER_SIZE: Vector3 = Vector3(1.02, 0.7, 0.92)
const SHIMMER_ALPHA: float = 0.35
const SHIMMER_PEAK: float = 1.2
const SHIMMER_TIME: float = 0.4
const DRIFT_OFFSET: Vector3 = Vector3(0.0, -1.0, 3.0)
const DRIFT_TIME: float = 1.5

var _roots: Dictionary[int, Node3D] = {}
var _drifting: Dictionary[int, Node3D] = {}
var _shimmers: Dictionary[int, MeshInstance3D] = {}
var _keys: Dictionary[int, String] = {}
var _rebuilds: int = 0
var _material: ShaderMaterial


## Brings the visuals in line with the bridge. Unchanged sections are left alone.
func sync(bridge: Bridge) -> void:
	if bridge == null:
		return
	for i: int in bridge.section_count():
		var s: Bridge.Section = bridge.section(i)
		var key: String = _key_of(s)
		if _keys.has(i) and _keys[i] == key:
			continue
		_keys[i] = key
		if s.broken:
			_start_drift(i)
		else:
			_build_section(i, s)
		if s.blessed and not _shimmers.has(i):
			_start_shimmer(i)


## The section's visual root, or null when the section shows nothing (empty or broken).
func get_section_root(index: int) -> Node3D:
	if _roots.has(index):
		return _roots[index]
	return null


## Number of visible mesh parts under a section (the gold shimmer is not counted).
func part_count(index: int) -> int:
	if not _roots.has(index):
		return 0
	var n: int = 0
	for child: Node in _roots[index].get_children():
		if child is MeshInstance3D:
			n += 1
	return n


## Total number of section rebuilds so far (for change-detection checks).
func get_rebuild_count() -> int:
	return _rebuilds


func is_drifting(index: int) -> bool:
	return _drifting.has(index)


func has_shimmer(index: int) -> bool:
	return _shimmers.has(index)


func _key_of(s: Bridge.Section) -> String:
	return "%d|%d|%d|%s|%s|%s" % [s.stone_in, s.timber_in, s.rope_in, s.complete, s.broken, s.blessed]


func _build_section(index: int, s: Bridge.Section) -> void:
	_remove_root(index)
	if s.stone_in <= 0 and s.timber_in <= 0 and s.rope_in <= 0:
		return
	var root: Node3D = Node3D.new()
	root.name = "Section%d" % index
	root.position = Vector3(float(index) * SECTION_LENGTH, 0.0, 0.0)
	add_child(root)
	for k: int in s.stone_in:
		var z: float = (float(k) - 1.5) * STONE_SPACING
		_add_part(root, MeshKit.box(STONE_SIZE, Palette.WET_STONE),
			Vector3(SECTION_CENTER_X, STONE_SIZE.y * 0.5, z))
		# TODO: replace this placeholder with RamaGlyph.mesh (render/rama_glyph.gd) once it is on main.
		_add_part(root, MeshKit.box(GLYPH_SIZE, Palette.SINDOOR),
			Vector3(SECTION_CENTER_X, STONE_SIZE.y + GLYPH_SIZE.y * 0.5, z))
	for k: int in s.timber_in:
		var z: float = (float(k) - 1.0) * PLANK_SPACING
		_add_part(root, MeshKit.box(PLANK_SIZE, Palette.BARK),
			Vector3(SECTION_CENTER_X, PLANK_HEIGHT, z))
	for k: int in s.rope_in:
		_add_part(root, MeshKit.box(LASHING_SIZE, Palette.ROPE),
			Vector3(SECTION_CENTER_X, LASHING_HEIGHT, 0.0))
	_roots[index] = root
	_rebuilds += 1


func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _flat()
	mi.position = pos
	parent.add_child(mi)


func _flat() -> ShaderMaterial:
	if _material == null:
		_material = MeshKit.flat_material()
	return _material


func _remove_root(index: int) -> void:
	if not _roots.has(index):
		return
	var old: Node3D = _roots[index]
	_roots.erase(index)
	remove_child(old)
	old.queue_free()


## A broken section leaves its slot, tweens away along +z while sinking, then is freed.
func _start_drift(index: int) -> void:
	if not _roots.has(index):
		return
	var root: Node3D = _roots[index]
	_roots.erase(index)
	_drifting[index] = root
	var target: Vector3 = root.position + DRIFT_OFFSET
	var tween: Tween = create_tween()
	tween.tween_property(root, "position", target, DRIFT_TIME)
	tween.finished.connect(func() -> void: _finish_drift(index, root))


func _finish_drift(index: int, root: Node3D) -> void:
	if _drifting.has(index) and _drifting[index] == root:
		_drifting.erase(index)
	root.queue_free()


## One-off gold pulse over a blessed section. It sits beside the section, so rebuilds do not touch it.
func _start_shimmer(index: int) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Palette.GOLD, SHIMMER_ALPHA)
	mat.emission_enabled = true
	mat.emission = Palette.GOLD
	mat.emission_energy_multiplier = 0.0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Shimmer%d" % index
	mi.mesh = MeshKit.box(SHIMMER_SIZE, Palette.GOLD)
	mi.material_override = mat
	mi.position = Vector3(float(index) * SECTION_LENGTH + SECTION_CENTER_X, SHIMMER_SIZE.y * 0.5, 0.0)
	add_child(mi)
	_shimmers[index] = mi
	var tween: Tween = create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", SHIMMER_PEAK, SHIMMER_TIME)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, SHIMMER_TIME)
