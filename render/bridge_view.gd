class_name BridgeView
extends Node3D
## Bridge meshes, one group per section (DESIGN §9, S14; visual fixes S14b and S14c; art v2 S41, docs/ART.md).
## Reads the Bridge simulation and never writes to it. Each section is 1 m long (along x) and 8 m wide (along z).
##
## Foundation: 4 boulders across, each an irregular rounded stone 1.5 m wide with smooth normals in the Materials
## `stone` kind. STONE_VARIANTS shapes are built once and shared; each stone picks one (and may be turned half
## round) from its section and slot, so the causeway never repeats visibly. A boulder's flat top is at STONE_HEIGHT
## and its foot is under water (STONE_BOTTOM); its vertex colour goes from WET_STONE on top to a dark, slightly
## green wet band around WATER_Y, the sea level of render/world_view.gd. A child "Foam" ring (Materials
## `water_edge`) laps round every boulder at the waterline.
## The राम glyph (RamaGlyph textured quad, about 1.2 m wide, brush-painted SINDOOR) lies on the top of every stone of
## an even-numbered section, turned to read upright from the default iso camera (yaw 45 degrees): its baseline runs
## along the screen horizontal. Odd sections carry plain stones, so neighbouring glyphs, which are wider than one
## section, never overlap.
## Walkway: the timber planks (Materials `wood`, each bound with two rope wraps) lie across a narrow central path
## on top of the stones, narrow enough to leave every glyph readable. Rope lashings run along both edges of the
## bridge; on even sections the rope is wound round a mooring stake.
## Broken sections drift away along +z and sink, then are freed; any shimmer over them is removed too.
## Blessed sections play a one-off golden shimmer built from Vfx particles (a soft additive wash and rising motes; no
## light, so a whole day's sections can be blessed at once), once per section; the shimmer node is freed when it ends.
## Only sections whose visible state changed are rebuilt. A section rebuilt after a break (for example
## from a restored save) gets a fresh root while its old drifting root finishes its tween and is freed.
## Tweens are bound to the view or to the node they animate, so freeing the view mid-tween is safe.
## set_origin_x() offsets the whole bridge along x (the game layer uses the cumulative length of earlier days).

const SECTION_LENGTH: float = 1.0
const SECTION_WIDTH: float = 8.0
const SECTION_CENTER_X: float = 0.5
const STONES_ACROSS: int = 4
const STONE_WIDTH: float = 1.5
const STONE_DEPTH: float = 1.0
const STONE_HEIGHT: float = 0.9
## Foot of a boulder, below the waterline (local y).
const STONE_BOTTOM: float = -0.45
## Sea level under the bridge (the ocean plane of render/world_view.gd).
const WATER_Y: float = -0.3
const STONE_VARIANTS: int = 4
const FOAM_REACH: float = 0.3
const CAMERA_YAW_DEG: float = 45.0
const GLYPH_WIDTH: float = 1.2
const GLYPH_HEIGHT: float = GLYPH_WIDTH / RamaGlyph.ASPECT
const GLYPH_LIFT: float = 0.012
const PLANK_SIZE: Vector3 = Vector3(0.3, 0.07, 0.9)
const PLANK_SPACING: float = 0.33
const PLANK_HEIGHT: float = STONE_HEIGHT + 0.045
const PLANK_VARIANTS: int = 3
const LASHING_SIZE: Vector3 = Vector3(SECTION_LENGTH, 0.1, 0.12)
const LASHING_HEIGHT: float = 0.62
const LASHING_EDGE_Z: float = 3.85
const STAKE_TOP: float = 0.62
const SHIMMER_SIZE: Vector3 = Vector3(2.4, 0.7, SECTION_WIDTH + 1.5)
const SHIMMER_PEAK: float = 1.6
const SHIMMER_TIME: float = 0.7
const SHIMMER_MOTES: int = 12
const _SHIMMER_GOLD: Color = Color(0.93, 0.62, 0.16)
const DRIFT_OFFSET: Vector3 = Vector3(0.0, -1.0, 3.0)
const DRIFT_TIME: float = 1.5

const _STONE_SEGMENTS: int = 14
## Boulder profile from the rim of the flat top down to the foot: x = radius factor, y = height, z = how much
## of the lumpiness applies at that ring.
const _STONE_PROFILE: Array[Vector3] = [
	Vector3(0.82, STONE_HEIGHT, 0.2),
	Vector3(0.93, 0.872, 0.55),
	Vector3(0.99, 0.78, 0.9),
	Vector3(1.0, 0.55, 1.0),
	Vector3(1.0, 0.2, 1.0),
	Vector3(0.96, -0.1, 1.0),
	Vector3(0.86, STONE_BOTTOM, 0.8),
]
## Per shape: how square the plan is (superellipse exponent) and how far the stone leans warm (towards STONE,
## positive) or dark (negative) from WET_STONE.
const _STONE_SQUARENESS: Array[float] = [3.6, 2.7, 4.4, 3.1]
const _STONE_TONE: Array[float] = [0.0, 0.3, -0.16, 0.14]

var _roots: Dictionary[int, Node3D] = {}
var _drifting: Dictionary[int, Node3D] = {}
var _drift_targets: Dictionary[int, Vector3] = {}
var _shimmers: Dictionary[int, Node3D] = {}
var _shimmered: Dictionary[int, bool] = {}
var _keys: Dictionary[int, String] = {}
var _rebuilds: int = 0
var _origin_x: float = 0.0
var _stone_meshes: Array[ArrayMesh] = []
var _foam_meshes: Array[ArrayMesh] = []
var _plank_meshes: Array[ArrayMesh] = []
var _lashing_meshes: Array[ArrayMesh] = []
var _glyph_mesh: ArrayMesh = null
var _shimmer_mesh: QuadMesh = null
var _mote_mesh: QuadMesh = null
var _mote_process: ParticleProcessMaterial = null


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
		_shimmers[index].position = Vector3(_section_x(index) + SECTION_CENTER_X, 0.0, 0.0)


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


## Stones shown for a section: the sim's inscribed stones scaled onto the 4 stones across the section, rounded up.
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
		var pick: int = _pick(index, k)
		var variant: int = pick % STONE_VARIANTS
		var stone: MeshInstance3D = _add_part(root, _stone(variant), Vector3(SECTION_CENTER_X, 0.0, z))
		stone.name = "Stone%d" % k
		# Half the stones are turned end for end: the footprint stays the same, the lumps move.
		if (pick / STONE_VARIANTS) % 2 == 1:
			stone.rotation = Vector3(0.0, PI, 0.0)
		var foam: MeshInstance3D = MeshInstance3D.new()
		foam.name = "Foam"
		foam.mesh = _foam(variant)
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stone.add_child(foam)
		if index % 2 == 0:
			_add_glyph(root, z, k)
	for k: int in s.timber_in:
		var plank: MeshInstance3D = _add_part(root, _plank((index + k) % PLANK_VARIANTS),
			Vector3(SECTION_CENTER_X + (float(k) - 1.0) * PLANK_SPACING, PLANK_HEIGHT, 0.0))
		plank.name = "Plank%d" % k
	if s.rope_in > 0:
		for side: float in [-1.0, 1.0]:
			var lashing: MeshInstance3D = _add_part(root, _lashing(index % 2),
				Vector3(SECTION_CENTER_X, LASHING_HEIGHT, side * LASHING_EDGE_Z))
			lashing.name = "Lashing%d" % int(side)
	_roots[index] = root
	_rebuilds += 1


## Deterministic small hash of a section and a stone slot (chooses the boulder shape and its turn).
static func _pick(index: int, k: int) -> int:
	var v: int = (index * 73856093) ^ (k * 19349663) ^ 0x5bd1e995
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7FFFFFFF
	return (v ^ (v >> 16)) & 0xFFFF


## Centre of stone slot k across the section width (slot 0 at the -z edge).
func _stone_z(k: int) -> float:
	var pitch: float = SECTION_WIDTH / float(STONES_ACROSS)
	return (float(k) - float(STONES_ACROSS - 1) * 0.5) * pitch


## The painted राम on top of one foundation stone. The glyph quad (RamaGlyph) faces +Z with its text top at +Y;
## turned -90 degrees on X it lies flat, its top running to -z, and turned by the camera yaw about Y its baseline
## runs along the screen horizontal, so it reads upright from the iso camera.
func _add_glyph(parent: Node3D, z: float, k: int) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _glyph()
	mi.material_override = RamaGlyph.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flat: Basis = Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	var yaw: Basis = Basis(Vector3.UP, deg_to_rad(CAMERA_YAW_DEG))
	mi.transform = Transform3D(yaw * flat, Vector3(SECTION_CENTER_X, STONE_HEIGHT + GLYPH_LIFT, z))
	mi.name = "Glyph%d" % k
	parent.add_child(mi)


## Adds a mesh part; its material comes from the mesh's own surface (set by MeshKit.multi).
func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## Shared meshes are built once and reused by every section.
func _stone(variant: int) -> ArrayMesh:
	if _stone_meshes.is_empty():
		for v: int in STONE_VARIANTS:
			_stone_meshes.append(_build_stone(v))
	return _stone_meshes[variant]


func _foam(variant: int) -> ArrayMesh:
	if _foam_meshes.is_empty():
		for v: int in STONE_VARIANTS:
			_foam_meshes.append(_build_foam(v))
	return _foam_meshes[variant]


func _glyph() -> ArrayMesh:
	if _glyph_mesh == null:
		_glyph_mesh = RamaGlyph.quad(GLYPH_HEIGHT, Palette.SINDOOR)
	return _glyph_mesh


func _plank(variant: int) -> ArrayMesh:
	if _plank_meshes.is_empty():
		for v: int in PLANK_VARIANTS:
			_plank_meshes.append(_build_plank(v))
	return _plank_meshes[variant]


func _lashing(variant: int) -> ArrayMesh:
	if _lashing_meshes.is_empty():
		_lashing_meshes.append(_build_lashing(true))
		_lashing_meshes.append(_build_lashing(false))
	return _lashing_meshes[variant]


## Lumpiness of boulder `variant` at angle `a` round the stone and ring `ring` down it, in -1..1.
static func _lump(variant: int, a: float, ring: float) -> float:
	var s: float = float(variant) * 2.399
	return sin(a * 2.0 + s) * 0.45 + sin(a * 3.0 + s * 1.7 + ring * 0.9) * 0.35 + sin(a * 5.0 + s * 2.9 + ring * 1.7) * 0.2


## Outline of boulder `variant` at profile ring `ring`: one point per segment, before the footprint is normalised.
## The plan is a rounded rectangle (a superellipse) pushed in and out by _lump().
static func _stone_ring(variant: int, ring: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var prof: Vector3 = _STONE_PROFILE[ring]
	for j: int in _STONE_SEGMENTS:
		var a: float = TAU * float(j) / float(_STONE_SEGMENTS)
		var c: float = cos(a)
		var sn: float = sin(a)
		var e: float = _STONE_SQUARENESS[variant]
		var r: float = pow(pow(absf(c), e) + pow(absf(sn), e), -1.0 / e)
		r *= prof.x * (1.0 + _lump(variant, a, float(ring)) * 0.1 * prof.z)
		var y: float = prof.y
		if ring > 0 and ring < _STONE_PROFILE.size() - 1:
			y += _lump(variant, a + 1.3, float(ring) + 2.0) * 0.045 * prof.z
		out.append(Vector3(c * r * STONE_DEPTH * 0.5, minf(y, STONE_HEIGHT), sn * r * STONE_WIDTH * 0.5))
	return out


## All rings of boulder `variant`, scaled so its footprint is exactly STONE_DEPTH by STONE_WIDTH.
static func _stone_rings(variant: int) -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	var max_x: float = 0.0
	var max_z: float = 0.0
	var min_x: float = 0.0
	var min_z: float = 0.0
	for i: int in _STONE_PROFILE.size():
		var ring: PackedVector3Array = _stone_ring(variant, i)
		for p: Vector3 in ring:
			max_x = maxf(max_x, p.x)
			min_x = minf(min_x, p.x)
			max_z = maxf(max_z, p.z)
			min_z = minf(min_z, p.z)
		rings.append(ring)
	var fit: Vector3 = Vector3(STONE_DEPTH / (max_x - min_x), 1.0, STONE_WIDTH / (max_z - min_z))
	var shift: Vector3 = Vector3(-(max_x + min_x) * 0.5, 0.0, -(max_z + min_z) * 0.5)
	for ring: PackedVector3Array in rings:
		for j: int in ring.size():
			ring[j] = (ring[j] + shift) * fit
	return rings


## The colour of the dry top of boulder `variant`: WET_STONE, leaning a little warm or dark per shape.
static func _stone_tone(variant: int) -> Color:
	var tone: float = _STONE_TONE[variant]
	if tone >= 0.0:
		return Palette.WET_STONE.lerp(Palette.STONE, tone)
	return Palette.WET_STONE.darkened(-tone)


## Stone colour at a point: the shape's dry tone on top, mottled on the flanks, darkening to a wet, faintly green
## band at the waterline.
static func _stone_colour(variant: int, p: Vector3) -> Color:
	var dry: Color = _stone_tone(variant)
	if p.y >= STONE_HEIGHT - 0.001:
		return dry
	var around: float = atan2(p.z, p.x)
	var wobble: float = _lump(variant, around * 2.0, 4.0) * 0.09
	var wet: float = 1.0 - smoothstep(WATER_Y + 0.1, WATER_Y + 0.8, p.y + wobble)
	var algae: float = 1.0 - smoothstep(0.0, 0.24, absf(p.y + wobble - (WATER_Y + 0.16)))
	var dark: Color = dry.darkened(0.58).lerp(Palette.DEEP_OCEAN, 0.25)
	var mottle: float = _lump(variant, around * 3.0 + p.y * 5.0, 9.0)
	var col: Color = dry.lerp(Palette.STONE, 0.1 + 0.1 * mottle).darkened(0.05 - 0.05 * mottle)
	return col.lerp(dark, wet * 0.9).lerp(Palette.LEAF_DARK, algae * 0.25)


## One irregular rounded boulder: a flat top at STONE_HEIGHT (so the glyph lies on it), round shoulders, lumpy
## flanks and a foot under water. Smooth normals: every vertex takes the average of the faces round it.
static func _build_stone(variant: int) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = _stone_rings(variant)
	var seg: int = _STONE_SEGMENTS
	var points: PackedVector3Array = PackedVector3Array([Vector3(0.0, STONE_HEIGHT, 0.0)])
	for ring: PackedVector3Array in rings:
		points.append_array(ring)
	var tris: PackedInt32Array = PackedInt32Array()
	for j: int in seg:
		var j1: int = (j + 1) % seg
		tris.append_array(PackedInt32Array([0, 1 + j, 1 + j1]))
		for i: int in rings.size() - 1:
			var a: int = 1 + i * seg + j
			var b: int = 1 + i * seg + j1
			var c: int = 1 + (i + 1) * seg + j1
			var d: int = 1 + (i + 1) * seg + j
			tris.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var inside: Vector3 = Vector3(0.0, (STONE_HEIGHT + STONE_BOTTOM) * 0.5, 0.0)
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(points.size())
	var t: int = 0
	while t < tris.size():
		var n: Vector3 = _face_normal(points[tris[t]], points[tris[t + 1]], points[tris[t + 2]], inside)
		for o: int in 3:
			normals[tris[t + o]] += n
		t += 3
	# The top is truly flat: its centre and rim point straight up, so light does not roll off under the glyph.
	normals[0] = Vector3.UP
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	t = 0
	while t < tris.size():
		var ia: int = tris[t]
		var ib: int = tris[t + 1]
		var ic: int = tris[t + 2]
		var n: Vector3 = (points[ib] - points[ia]).cross(points[ic] - points[ia])
		# Godot's front faces are clockwise: emit a, c, b when (a, b, c) has an outward cross product.
		if n.dot((points[ia] + points[ib] + points[ic]) / 3.0 - inside) < 0.0:
			var swap: int = ib
			ib = ic
			ic = swap
		for vi: int in [ia, ic, ib]:
			st.set_normal(normals[vi].normalized())
			st.set_color(_stone_colour(variant, points[vi]))
			st.add_vertex(points[vi])
		t += 3
	return MeshKit.multi({&"stone": st.commit()})


## Area-weighted normal of a triangle, pointing away from `inside`.
static func _face_normal(a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> Vector3:
	var n: Vector3 = (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		return -n
	return n


## Foam lapping round boulder `variant`: a sloping skirt from the stone's flank just above WATER_Y out to
## FOAM_REACH. Vertex alpha is the opacity read by the Materials `water_edge` kind: dense at the stone, gone outside.
static func _build_foam(variant: int) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = _stone_rings(variant)
	var flank: PackedVector3Array = rings[rings.size() - 2]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = flank.size()
	var white: Color = Color(0.93, 0.97, 1.0, 0.95)
	var clear: Color = Color(0.72, 0.88, 0.95, 0.0)
	var inner: PackedVector3Array = PackedVector3Array()
	var mid: PackedVector3Array = PackedVector3Array()
	var outer: PackedVector3Array = PackedVector3Array()
	for j: int in seg:
		var p: Vector3 = Vector3(flank[j].x, 0.0, flank[j].z)
		var dir: Vector3 = p.normalized()
		var reach: float = FOAM_REACH * (0.75 + 0.25 * _lump(variant, float(j) * 1.9, 7.0))
		inner.append(p * 0.9 + Vector3(0.0, WATER_Y + 0.09, 0.0))
		mid.append(p + dir * reach * 0.4 + Vector3(0.0, WATER_Y + 0.05, 0.0))
		outer.append(p + dir * reach + Vector3(0.0, WATER_Y + 0.02, 0.0))
	for j: int in seg:
		var j1: int = (j + 1) % seg
		_foam_quad(st, inner[j], inner[j1], mid[j1], mid[j], white, white.lerp(clear, 0.35))
		_foam_quad(st, mid[j], mid[j1], outer[j1], outer[j], white.lerp(clear, 0.35), clear)
	return MeshKit.multi({&"water_edge": st.commit()})


## One upward-facing quad of the foam skirt: a and b on the inner edge, c and d on the outer.
static func _foam_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inner: Color, outer: Color) -> void:
	var pts: Array[Vector3] = [a, b, c, a, c, d]
	var cols: Array[Color] = [inner, inner, outer, inner, outer, outer]
	var order: Array[int] = [0, 1, 2, 3, 4, 5]
	if (b - a).cross(c - a).y > 0.0:
		order = [0, 2, 1, 3, 5, 4]
	for o: int in order:
		st.set_normal(Vector3.UP)
		st.set_color(cols[o])
		st.add_vertex(pts[o])


static func _at(mesh: ArrayMesh, offset: Vector3, euler_deg: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"mesh": mesh, "transform": Transform3D(Basis.from_euler(euler_deg * (PI / 180.0)), offset)}


## One hewn plank of the walkway, lying across the bridge (long axis z), sun-bleached to a different tone per
## variant and a little skewed, with a rope wrap near each end that binds it to the stones.
static func _build_plank(variant: int) -> ArrayMesh:
	var tones: Array[float] = [0.34, 0.5, 0.42]
	var skews: Array[float] = [1.6, -2.2, 0.7]
	var shifts: Array[float] = [0.03, -0.04, 0.0]
	var wood: Color = Palette.BARK.lerp(Palette.SHORE_SAND, tones[variant])
	var parts: Array[Dictionary] = []
	var length: float = PLANK_SIZE.z - 0.08
	parts.append(_at(MeshKit.bevel_box(Vector3(PLANK_SIZE.x - 0.03, PLANK_SIZE.y, length), 0.018, wood),
		Vector3(0.0, 0.0, shifts[variant]), Vector3(0.0, skews[variant], 0.0)))
	for side: float in [-1.0, 1.0]:
		var wrap: ArrayMesh = MeshKit.bevel_box(Vector3(PLANK_SIZE.x, PLANK_SIZE.y + 0.03, 0.055), 0.02, Palette.ROPE)
		parts.append(_at(wrap, Vector3(0.0, 0.0, side * (length * 0.5 - 0.12) + shifts[variant])))
	return MeshKit.multi({&"wood": parts})


## The rope lashing along one edge of a section: two strands running the length of the section against the outer
## stones. With `stake` the rope is wound round a timber mooring stake driven in beside the stones.
static func _build_lashing(stake: bool) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	var rope: Color = Palette.ROPE
	var strand: ArrayMesh = MeshKit.cylinder(0.04, 0.04, SECTION_LENGTH, 6, rope, true)
	parts.append(_at(strand, Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.0, 90.0)))
	parts.append(_at(MeshKit.cylinder(0.035, 0.035, SECTION_LENGTH, 6, rope.darkened(0.12), true),
		Vector3(0.0, -0.07, 0.01), Vector3(0.0, 0.0, 90.0)))
	if stake:
		var post_h: float = STAKE_TOP + LASHING_HEIGHT - WATER_Y
		var post: ArrayMesh = MeshKit.cylinder(0.065, 0.085, post_h, 7, Palette.BARK.lerp(Palette.SHORE_SAND, 0.18), true)
		parts.append(_at(post, Vector3(0.0, STAKE_TOP - post_h * 0.5, 0.0), Vector3(3.0, 0.0, -4.0)))
		for i: int in 3:
			var coil: ArrayMesh = MeshKit.cylinder(0.105, 0.105, 0.05, 8, rope.lightened(0.06 * float(i)), true)
			parts.append(_at(coil, Vector3(0.0, -0.09 + 0.065 * float(i), 0.0), Vector3(4.0 * float(i - 1), 0.0, 6.0)))
	return MeshKit.multi({&"wood": parts})


func _remove_root(index: int) -> void:
	if not _roots.has(index):
		return
	var old: Node3D = _roots[index]
	_roots.erase(index)
	remove_child(old)
	old.queue_free()


## A broken section leaves its slot, tweens away along +z while sinking, then is freed.
## Any live shimmer over the section is removed at once so no gold is left behind.
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


## One-off golden shimmer over a blessed section, built from Vfx materials: a soft additive wash lying over the
## stones and motes of gold rising from them. It sits beside the section, so rebuilds do not
## touch it. It is started once per section; its tween belongs to the shimmer node, so freeing the node (on
## completion or on a break) also ends the tween.
func _start_shimmer(index: int) -> void:
	_shimmered[index] = true
	var fx: Node3D = Node3D.new()
	fx.name = "Shimmer%d" % index
	fx.position = Vector3(_section_x(index) + SECTION_CENTER_X, 0.0, 0.0)
	var wash_mat: ShaderMaterial = Vfx.material(Vfx.SHAPE_GLOW, Vfx.MODE_ADD, 1.0, false, false).duplicate() as ShaderMaterial
	wash_mat.set_shader_parameter("tint", Color(_SHIMMER_GOLD, 0.0))
	wash_mat.set_shader_parameter("energy", SHIMMER_PEAK)
	var wash: MeshInstance3D = MeshInstance3D.new()
	wash.name = "Wash"
	wash.mesh = _shimmer_quad()
	wash.material_override = wash_mat
	wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wash.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	wash.position = Vector3(0.0, STONE_HEIGHT + 0.16, 0.0)
	fx.add_child(wash)
	var motes: GPUParticles3D = GPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = SHIMMER_MOTES
	motes.lifetime = SHIMMER_TIME * 1.7
	motes.one_shot = true
	motes.explosiveness = 0.75
	motes.randomness = 0.5
	motes.process_material = _mote_material()
	motes.draw_pass_1 = _mote_quad()
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.visibility_aabb = AABB(Vector3(-2.0, -1.0, -SECTION_WIDTH), Vector3(4.0, 6.0, SECTION_WIDTH * 2.0))
	motes.position = Vector3(0.0, STONE_HEIGHT + 0.1, 0.0)
	motes.emitting = true
	fx.add_child(motes)
	add_child(fx)
	_shimmers[index] = fx
	var tween: Tween = fx.create_tween()
	tween.tween_method(_set_wash.bind(wash_mat), 0.0, 1.0, SHIMMER_TIME * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_wash.bind(wash_mat), 1.0, 0.0, SHIMMER_TIME * 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_finish_shimmer.bind(index, fx))


## Opacity of a shimmer wash, 0..1 (tween target).
func _set_wash(amount: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("tint", Color(_SHIMMER_GOLD, amount * 0.34))


func _shimmer_quad() -> QuadMesh:
	if _shimmer_mesh == null:
		_shimmer_mesh = QuadMesh.new()
		_shimmer_mesh.size = Vector2(SHIMMER_SIZE.x, SHIMMER_SIZE.z)
	return _shimmer_mesh


func _mote_quad() -> QuadMesh:
	if _mote_mesh == null:
		_mote_mesh = QuadMesh.new()
		_mote_mesh.size = Vector2.ONE
		_mote_mesh.material = Vfx.material(Vfx.SHAPE_GLOW, Vfx.MODE_ADD, 2.2, true, false)
	return _mote_mesh


func _mote_material() -> ParticleProcessMaterial:
	if _mote_process == null:
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(SECTION_LENGTH * 0.5, 0.05, SECTION_WIDTH * 0.5)
		pm.direction = Vector3.UP
		pm.spread = 18.0
		pm.initial_velocity_min = 0.7
		pm.initial_velocity_max = 2.0
		pm.gravity = Vector3(0.0, 0.5, 0.0)
		pm.damping_min = 0.4
		pm.damping_max = 0.9
		pm.scale_min = 0.12
		pm.scale_max = 0.3
		var curve: Curve = Curve.new()
		curve.add_point(Vector2(0.0, 0.0))
		curve.add_point(Vector2(0.18, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		var curve_tex: CurveTexture = CurveTexture.new()
		curve_tex.curve = curve
		pm.scale_curve = curve_tex
		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([Color(Palette.FIRE_CORE, 1.0), Color(_SHIMMER_GOLD, 0.95), Color(Palette.SAFFRON, 0.0)])
		var ramp: GradientTexture1D = GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp
		_mote_process = pm
	return _mote_process


func _finish_shimmer(index: int, fx: Node3D) -> void:
	if _shimmers.has(index) and _shimmers[index] == fx:
		_shimmers.erase(index)
	fx.queue_free()


func _cancel_shimmer(index: int) -> void:
	if not _shimmers.has(index):
		return
	var fx: Node3D = _shimmers[index]
	_shimmers.erase(index)
	fx.queue_free()
