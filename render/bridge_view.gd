class_name BridgeView
extends Node3D
## Bridge meshes, one group per section (DESIGN §9, S14, visual fix S14b).
## Reads the Bridge simulation and never writes to it. Each section is 1 m long (along x) and 8 m wide (along z).
## It shows its foundation stones (WET_STONE, 6 across, each about 1.2 m wide and topped with a Rama glyph of about
## 0.8 m laid flat, SINDOOR), its timber deck spanning the full width (BARK) and its rope lashings at both edges (ROPE).
## Broken sections drift away along +z and sink, then are freed; any shimmer over them is removed too.
## Blessed sections play a one-off gold shimmer (once per section); the shimmer node is freed when it ends.
## Only sections whose visible state changed are rebuilt. A section rebuilt after a break (for example
## from a restored save) gets a fresh root while its old drifting root finishes its tween and is freed.
## Tweens are bound to the view or to the node they animate, so freeing the view mid-tween is safe.
## set_origin_x() offsets the whole bridge along x (the game layer uses the cumulative length of earlier days).

const SECTION_LENGTH: float = 1.0
const SECTION_WIDTH: float = 8.0
const SECTION_CENTER_X: float = 0.5
const STONES_ACROSS: int = 6
const STONE_WIDTH: float = 1.2
const STONE_DEPTH: float = 1.0
const STONE_HEIGHT: float = 0.9
const GLYPH_HEIGHT: float = 0.8
const GLYPH_LIFT: float = 0.01
## The glyph is 1.47 m wide at height 0.8 m (along x, the stone depth is 1.0 m), so it is squeezed to 0.88 m across x
## to stay on its stone and clear of the neighbouring sections' glyphs.
const GLYPH_WIDTH_SCALE: float = 0.6
const PLANK_SIZE: Vector3 = Vector3(0.25, 0.1, SECTION_WIDTH)
const PLANK_SPACING: float = 0.33
const PLANK_HEIGHT: float = 0.5
const LASHING_SIZE: Vector3 = Vector3(SECTION_LENGTH, 0.1, 0.12)
const LASHING_HEIGHT: float = 0.62
const LASHING_EDGE_Z: float = 3.85
const SHIMMER_SIZE: Vector3 = Vector3(1.02, 0.7, SECTION_WIDTH + 0.2)
const SHIMMER_ALPHA: float = 0.35
const SHIMMER_PEAK: float = 1.2
const SHIMMER_TIME: float = 0.4
const DRIFT_OFFSET: Vector3 = Vector3(0.0, -1.0, 3.0)
const DRIFT_TIME: float = 1.5

var _roots: Dictionary[int, Node3D] = {}
var _drifting: Dictionary[int, Node3D] = {}
var _drift_targets: Dictionary[int, Vector3] = {}
var _shimmers: Dictionary[int, MeshInstance3D] = {}
var _shimmered: Dictionary[int, bool] = {}
var _keys: Dictionary[int, String] = {}
var _rebuilds: int = 0
var _origin_x: float = 0.0
var _material: ShaderMaterial = null
var _stone_mesh: ArrayMesh = null
var _glyph_mesh: ArrayMesh = null
var _plank_mesh: ArrayMesh = null
var _lashing_mesh: ArrayMesh = null
var _shimmer_mesh: ArrayMesh = null


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
		if s.blessed and not s.broken and not _shimmered.has(i):
			_start_shimmer(i)


## Moves the whole bridge along x. Sections already built move with it.
func set_origin_x(x: float) -> void:
	_origin_x = x
	for index: int in _roots:
		_roots[index].position = Vector3(_section_x(index), 0.0, 0.0)
	for index: int in _shimmers:
		_shimmers[index].position = Vector3(_section_x(index) + SECTION_CENTER_X, SHIMMER_SIZE.y * 0.5, 0.0)


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


## The position a drifting section is tweening towards (its start plus DRIFT_OFFSET).
func get_drift_target(index: int) -> Vector3:
	if _drift_targets.has(index):
		return _drift_targets[index]
	return Vector3.ZERO


## True while a shimmer node exists for the section (it exists only during the pulse).
func has_shimmer(index: int) -> bool:
	return _shimmers.has(index)


func _section_x(index: int) -> float:
	return _origin_x + float(index) * SECTION_LENGTH


func _key_of(s: Bridge.Section) -> String:
	return "%d|%d|%d|%s|%s|%s" % [s.stone_in, s.timber_in, s.rope_in, s.complete, s.broken, s.blessed]


## Stones shown for a section: the sim's inscribed stones scaled onto the 6 stones across the section, rounded up.
func _visible_stones(stone_in: int) -> int:
	var scaled: int = ceili(float(stone_in * STONES_ACROSS) / float(Bridge.STONE_PER_SECTION))
	return mini(STONES_ACROSS, scaled)


func _build_section(index: int, s: Bridge.Section) -> void:
	_remove_root(index)
	if s.stone_in <= 0 and s.timber_in <= 0 and s.rope_in <= 0:
		return
	var root: Node3D = Node3D.new()
	root.name = "Section%d" % index
	root.position = Vector3(_section_x(index), 0.0, 0.0)
	add_child(root)
	var stones: int = _visible_stones(s.stone_in)
	for k: int in stones:
		var z: float = _stone_z(k)
		var stone: MeshInstance3D = _add_part(root, _stone(), Vector3(SECTION_CENTER_X, STONE_HEIGHT * 0.5, z))
		stone.name = "Stone%d" % k
		_add_glyph(root, z, k)
	for k: int in s.timber_in:
		var plank: MeshInstance3D = _add_part(root, _plank(),
			Vector3(SECTION_CENTER_X + (float(k) - 1.0) * PLANK_SPACING, PLANK_HEIGHT, 0.0))
		plank.name = "Plank%d" % k
	if s.rope_in > 0:
		for side: float in [-1.0, 1.0]:
			var lashing: MeshInstance3D = _add_part(root, _lashing(),
				Vector3(SECTION_CENTER_X, LASHING_HEIGHT, side * LASHING_EDGE_Z))
			lashing.name = "Lashing%d" % int(side)
	_roots[index] = root
	_rebuilds += 1


## Centre of stone slot k across the section width (slot 0 at the -z edge).
func _stone_z(k: int) -> float:
	var pitch: float = SECTION_WIDTH / float(STONES_ACROSS)
	return (float(k) - float(STONES_ACROSS - 1) * 0.5) * pitch


## The inscribed राम on top of one foundation stone. The glyph (RamaGlyph, S13) is built facing +Z; rotated -90
## degrees on X it lies flat on the stone top, its height running across the stone (along z).
func _add_glyph(parent: Node3D, z: float, k: int) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _glyph()
	mi.material_override = _flat()
	mi.position = Vector3(SECTION_CENTER_X, STONE_HEIGHT + GLYPH_LIFT, z)
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.scale = Vector3(GLYPH_WIDTH_SCALE, 1.0, 1.0)
	mi.name = "Glyph%d" % k
	parent.add_child(mi)


func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _flat()
	mi.position = pos
	parent.add_child(mi)
	return mi


## Shared meshes are built once and reused by every section.
func _stone() -> ArrayMesh:
	if _stone_mesh == null:
		_stone_mesh = MeshKit.box(Vector3(STONE_DEPTH, STONE_HEIGHT, STONE_WIDTH), Palette.WET_STONE)
	return _stone_mesh


func _glyph() -> ArrayMesh:
	if _glyph_mesh == null:
		_glyph_mesh = RamaGlyph.mesh(GLYPH_HEIGHT, Palette.SINDOOR)
	return _glyph_mesh


func _plank() -> ArrayMesh:
	if _plank_mesh == null:
		_plank_mesh = MeshKit.box(PLANK_SIZE, Palette.BARK)
	return _plank_mesh


func _lashing() -> ArrayMesh:
	if _lashing_mesh == null:
		_lashing_mesh = MeshKit.box(LASHING_SIZE, Palette.ROPE)
	return _lashing_mesh


func _shimmer() -> ArrayMesh:
	if _shimmer_mesh == null:
		_shimmer_mesh = MeshKit.box(SHIMMER_SIZE, Palette.GOLD)
	return _shimmer_mesh


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
## Any live shimmer over the section is removed at once so no gold box is left behind.
func _start_drift(index: int) -> void:
	_cancel_shimmer(index)
	if not _roots.has(index):
		return
	var root: Node3D = _roots[index]
	_roots.erase(index)
	_drifting[index] = root
	var target: Vector3 = root.position + DRIFT_OFFSET
	_drift_targets[index] = target
	var tween: Tween = create_tween()
	tween.tween_property(root, "position", target, DRIFT_TIME)
	tween.finished.connect(func() -> void: _finish_drift(index, root))


func _finish_drift(index: int, root: Node3D) -> void:
	if _drifting.has(index) and _drifting[index] == root:
		_drifting.erase(index)
		_drift_targets.erase(index)
	root.queue_free()


## One-off gold pulse over a blessed section. It sits beside the section, so rebuilds do not touch it.
## The pulse is started once per section; its tween belongs to the shimmer node, so freeing the node
## (on completion or on a break) also ends the tween.
func _start_shimmer(index: int) -> void:
	_shimmered[index] = true
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Palette.GOLD, SHIMMER_ALPHA)
	mat.emission_enabled = true
	mat.emission = Palette.GOLD
	mat.emission_energy_multiplier = 0.0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Shimmer%d" % index
	mi.mesh = _shimmer()
	mi.material_override = mat
	mi.position = Vector3(_section_x(index) + SECTION_CENTER_X, SHIMMER_SIZE.y * 0.5, 0.0)
	add_child(mi)
	_shimmers[index] = mi
	var tween: Tween = mi.create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", SHIMMER_PEAK, SHIMMER_TIME)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, SHIMMER_TIME)
	tween.tween_callback(_finish_shimmer.bind(index, mi))


func _finish_shimmer(index: int, mi: MeshInstance3D) -> void:
	if _shimmers.has(index) and _shimmers[index] == mi:
		_shimmers.erase(index)
	mi.queue_free()


func _cancel_shimmer(index: int) -> void:
	if not _shimmers.has(index):
		return
	var mi: MeshInstance3D = _shimmers[index]
	_shimmers.erase(index)
	mi.queue_free()
