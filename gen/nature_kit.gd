class_name NatureKit
extends RefCounted
## Procedural nature props (DESIGN §9 M10; art v2 per docs/ART.md "Foliage", module B5).
## Every function takes a seed and is deterministic: the same seed returns the same geometry.
##
## Trees are built from curved, tapering bark tubes (trunk, limbs) and canopies of many small LEAF CARDS set on
## dark inner cores, so the silhouette is lacy instead of a blob. Meshes have one surface per Materials kind:
## "wood" for bark, "foliage" for leaves, blossoms and grass, "stone" for rocks and cliffs. Organic shapes use
## smooth normals; leaf cards use "puffed" normals (pointing away from their cluster's centre) so a canopy shades
## as one soft volume. Foliage vertex colour ALPHA is the wind weight read by Materials (0 = rigid, 1 = free).
## Colours come from Palette only (DESIGN §6.1), as exact palette colours or blends of them.

const KIND_BARK: StringName = &"wood"
const KIND_LEAF: StringName = &"foliage"
const KIND_STONE: StringName = &"stone"

## Upper bound on the triangles of one tree (docs/ART.md: hero props are 2-4k triangles).
const TREE_TRI_BUDGET: int = 4000
## Name of the MultiMeshInstance3D child of grass_patch() that holds the swaying blades.
const BLADES_NAME: String = "Blades"
## Metadata of the "Blades" node: the tuft positions (PackedVector3Array) and tints (PackedColorArray).
const BLADE_ORIGINS_META: StringName = &"blade_origins"
const BLADE_COLOURS_META: StringName = &"blade_colours"
## Name of the ground dressing child (grass and flowers) added under trees.
const UNDERGROWTH_NAME: String = "Undergrowth"
## Name of the hidden shadows-only child of a tree.
const SHADOW_CASTER_NAME: String = "ShadowCaster"

const _GOLDEN_ANGLE: float = 2.39996323
const _STYLE_DROOP: int = 0
const _STYLE_SPREAD: int = 1

static var _tuft_mesh: ArrayMesh = null


## Ashoka: tall and narrow. A gently curved bark trunk, short branches into a column of leaf clusters whose long
## leaves droop, and dense ASHOKA_RED blossom bunches.
static func ashoka_tree(rng_seed: int, height: float = 6.0) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var h: float = maxf(height, 0.5)
	var bark: SurfaceTool = _tool()
	var leaf: SurfaceTool = _tool()
	var shade: SurfaceTool = _tool()
	# Trunk: an S-curve with a root flare.
	var phase: float = rng.randf_range(0.0, TAU)
	var sway: float = h * rng.randf_range(0.025, 0.045)
	var trunk: PackedVector3Array = PackedVector3Array()
	var trunk_r: PackedFloat32Array = PackedFloat32Array()
	var trunk_segments: int = 9
	for k: int in range(trunk_segments + 1):
		var t: float = float(k) / float(trunk_segments)
		var bend: float = sin(t * PI * 1.25)
		trunk.append(Vector3(cos(phase) * bend * sway, h * 0.9 * t, sin(phase + 0.9) * bend * sway))
		trunk_r.append(lerpf(h * 0.042, h * 0.012, pow(t, 0.8)) * (1.0 + 0.9 * exp(-t * 16.0)))
	_tube(bark, trunk, trunk_r, 8, _bark_colours(trunk.size(), 0.3))
	_tube(shade, trunk, trunk_r, 6, _bark_colours(trunk.size(), 0.0))
	# A column of clusters spiralling up the trunk, smaller toward the top.
	var clusters: int = 10
	var spin: float = rng.randf_range(0.0, TAU)
	var crown_bottom: float = h * 0.3
	var crown_top: float = h
	for i: int in range(clusters):
		var t: float = float(i) / float(clusters - 1)
		var y: float = h * (0.4 + 0.5 * t) + rng.randf_range(-0.012, 0.012) * h
		var angle: float = spin + float(i) * _GOLDEN_ANGLE
		var dist: float = h * (0.105 - 0.085 * t) * rng.randf_range(0.8, 1.1)
		var radius: float = h * (0.135 - 0.04 * t) * rng.randf_range(0.92, 1.08)
		var centre: Vector3 = _sample(trunk, y / (h * 0.9)) + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var from: Vector3 = _sample(trunk, (y - h * 0.09) / (h * 0.9))
		_limb(bark, from, centre, Vector3(0.0, h * 0.02, 0.0), h * 0.013, h * 0.005, 5, 4)
		var stretch: Vector3 = Vector3(1.0, 1.15, 1.0)
		_cluster(leaf, shade, centre, radius, stretch, rng, _STYLE_DROOP, 18, 4, h * 0.1, crown_bottom, crown_top)
		# Blossom bunches on the outer, upper side of each cluster.
		var bunches: int = 3 if i < clusters - 2 else 2
		for j: int in range(bunches):
			var yaw: float = angle + rng.randf_range(-1.4, 1.4)
			var dir: Vector3 = Vector3(cos(yaw), rng.randf_range(-0.25, 0.75), sin(yaw)).normalized()
			var pos: Vector3 = centre + dir * stretch * radius * 1.04
			_blossom(leaf, pos, dir, h * rng.randf_range(0.032, 0.042), rng, Palette.ASHOKA_RED,
				Palette.ASHOKA_RED.lerp(Palette.GOLD, 0.35), 12)
	var mi: MeshInstance3D = _wrap(_commit([KIND_BARK, KIND_LEAF], [bark, leaf]), "AshokaTree")
	_add_shadow_caster(mi, shade)
	mi.add_child(_undergrowth(rng, h * 0.3, 26, 7, [Palette.ASHOKA_RED, Palette.ASHOKA_RED, Palette.SAFFRON]))
	return mi


## Shimshapa: a thick trunk forking into curved limbs that carry a broad, dense, layered crown. No blossoms.
static func shimshapa_tree(rng_seed: int, height: float = 7.0) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var h: float = maxf(height, 0.5)
	var bark: SurfaceTool = _tool()
	var leaf: SurfaceTool = _tool()
	var shade: SurfaceTool = _tool()
	var fork_y: float = h * 0.36
	var lean_yaw: float = rng.randf_range(0.0, TAU)
	var lean: Vector3 = Vector3(cos(lean_yaw), 0.0, sin(lean_yaw)) * h * rng.randf_range(0.02, 0.05)
	var trunk: PackedVector3Array = PackedVector3Array()
	var trunk_r: PackedFloat32Array = PackedFloat32Array()
	var trunk_segments: int = 6
	for k: int in range(trunk_segments + 1):
		var t: float = float(k) / float(trunk_segments)
		trunk.append(Vector3(0.0, fork_y * t, 0.0) + lean * sin(t * PI * 0.5) + lean.rotated(Vector3.UP, 1.6) * sin(t * PI) * 0.6)
		trunk_r.append(lerpf(h * 0.07, h * 0.05, t) * (1.0 + 1.0 * exp(-t * 9.0)))
	_tube(bark, trunk, trunk_r, 10, _bark_colours(trunk.size(), 0.3), false)
	_tube(shade, trunk, trunk_r, 6, _bark_colours(trunk.size(), 0.0))
	var fork: Vector3 = trunk[trunk.size() - 1]
	var crown_bottom: float = h * 0.4
	var crown_top: float = h
	var squash: Vector3 = Vector3(1.12, 0.72, 1.12)
	var start: float = rng.randf_range(0.0, TAU)
	var limbs: int = 6
	for i: int in range(limbs):
		var yaw: float = start + TAU * float(i) / float(limbs) + rng.randf_range(-0.22, 0.22)
		var out: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var reach: float = h * rng.randf_range(0.31, 0.4)
		var tip: Vector3 = fork + out * reach + Vector3(0.0, h * rng.randf_range(0.22, 0.33), 0.0)
		var control: Vector3 = Vector3(0.0, (tip.y - fork.y) * 0.55, 0.0) - out * reach * 0.12
		_limb(bark, fork - Vector3(0.0, h * 0.03, 0.0), tip, control, h * 0.036, h * 0.009, 6, 6)
		_cluster(leaf, shade, tip, h * rng.randf_range(0.15, 0.185), squash, rng, _STYLE_SPREAD, 18, 4, h * 0.085,
			crown_bottom, crown_top)
		var mid: Vector3 = fork + out * reach * 0.5 + Vector3(0.0, (tip.y - fork.y) * 0.95 + h * 0.07, 0.0)
		mid += Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * h * 0.03
		_cluster(leaf, shade, mid, h * rng.randf_range(0.14, 0.17), squash, rng, _STYLE_SPREAD, 15, 4, h * 0.085,
			crown_bottom, crown_top)
	# The leader and a crown of clusters close the dome.
	var top: Vector3 = fork + lean * 0.5 + Vector3(0.0, h * 0.46, 0.0)
	_limb(bark, fork - Vector3(0.0, h * 0.03, 0.0), top, lean, h * 0.034, h * 0.009, 6, 5)
	_cluster(leaf, shade, top, h * 0.19, squash, rng, _STYLE_SPREAD, 18, 4, h * 0.085, crown_bottom, crown_top)
	for i: int in range(2):
		var yaw: float = start + PI * float(i) + 0.6
		var pos: Vector3 = fork + Vector3(cos(yaw) * h * 0.17, h * 0.4, sin(yaw) * h * 0.17)
		_limb(bark, fork, pos, Vector3(0.0, h * 0.1, 0.0), h * 0.02, h * 0.006, 5, 4)
		_cluster(leaf, shade, pos, h * 0.165, squash, rng, _STYLE_SPREAD, 15, 4, h * 0.085, crown_bottom, crown_top)
	var mi: MeshInstance3D = _wrap(_commit([KIND_BARK, KIND_LEAF], [bark, leaf]), "ShimshapaTree")
	_add_shadow_caster(mi, shade)
	mi.add_child(_undergrowth(rng, h * 0.42, 44, 8, [Palette.MOON, Palette.GOLD]))
	return mi


## A low leafy shrub about `radius` wide, with white blossoms when `flowering`.
static func bush(rng_seed: int, radius: float = 0.8, flowering: bool = false) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var bark: SurfaceTool = _tool()
	var leaf: SurfaceTool = _tool()
	_bush_into(bark, leaf, Vector3.ZERO, maxf(radius, 0.1), rng, flowering)
	return _wrap(_commit([KIND_BARK, KIND_LEAF], [bark, leaf]), "Bush")


## Several shrubs scattered over an `area` (x, z) centred on the origin, in one mesh. `count` < 0 picks a
## density that suits the area. Every other shrub is in flower.
static func bushes(area: Vector2, rng_seed: int, count: int = -1) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var bark: SurfaceTool = _tool()
	var leaf: SurfaceTool = _tool()
	var total: int = count if count >= 0 else clampi(int(area.x * area.y * 0.2), 1, 12)
	for i: int in range(total):
		var radius: float = rng.randf_range(0.45, 0.8)
		var pos: Vector3 = Vector3(rng.randf_range(-0.5, 0.5) * maxf(area.x - radius * 2.0, 0.0), 0.0,
			rng.randf_range(-0.5, 0.5) * maxf(area.y - radius * 2.0, 0.0))
		_bush_into(bark, leaf, pos, radius, rng, i % 2 == 0)
	return _wrap(_commit([KIND_BARK, KIND_LEAF], [bark, leaf]), "Bushes")


## A boulder of about `size`, centred on the origin with a flat base at y = -size.y / 2: chiselled planes with
## smooth transitions, stone material, darker toward the ground and with moss on its upward faces.
static func rock(size: Vector3, rng_seed: int) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var stone: SurfaceTool = _tool()
	_boulder(stone, Vector3.ZERO, size * 0.5, rng, 12, 18, 0.16, 6, 0.6)
	var mi: MeshInstance3D = _wrap(_commit([KIND_STONE], [stone]), "Rock")
	var reach: float = maxf(size.x, size.z) * 0.5
	var tufts: MeshInstance3D = _ring_dressing(rng, reach * 0.8, reach * 1.25, 9, 2, [Palette.MOON, Palette.GOLD])
	tufts.position = Vector3(0.0, -size.y * 0.5, 0.0)
	mi.add_child(tufts)
	return mi


## A crag rising from y = 0 to about size.y: stacked chiselled masses with buttresses, strata and mossy ledges.
static func cliff(size: Vector3, rng_seed: int) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var stone: SurfaceTool = _tool()
	var h: float = size.y
	var half: Vector3 = Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	_boulder(stone, Vector3(0.0, h * 0.3, 0.0), Vector3(half.x, h * 0.3, half.z), rng, 12, 18, 0.2, 9, 0.5, true)
	var drift: Vector3 = Vector3(rng.randf_range(-0.12, 0.12) * size.x, 0.0, rng.randf_range(-0.12, 0.12) * size.z)
	_boulder(stone, drift + Vector3(0.0, h * 0.56, 0.0), Vector3(half.x * 0.78, h * 0.3, half.z * 0.78), rng, 12, 18, 0.2, 9, 0.6, true)
	drift += Vector3(rng.randf_range(-0.1, 0.1) * size.x, 0.0, rng.randf_range(-0.1, 0.1) * size.z)
	_boulder(stone, drift + Vector3(0.0, h * 0.8, 0.0), Vector3(half.x * 0.52, h * 0.21, half.z * 0.52), rng, 10, 16, 0.22, 8, 0.8, true)
	var yaw: float = rng.randf_range(0.0, TAU)
	for i: int in range(3):
		var a: float = yaw + TAU * float(i) / 3.0 + rng.randf_range(-0.4, 0.4)
		var bh: float = h * rng.randf_range(0.12, 0.2)
		var pos: Vector3 = Vector3(cos(a) * half.x * 0.8, bh, sin(a) * half.z * 0.8)
		_boulder(stone, pos, Vector3(half.x * 0.42, bh, half.z * 0.42), rng, 8, 12, 0.2, 7, 0.7, true)
	var mesh: ArrayMesh = _commit([KIND_STONE], [stone])
	var mi: MeshInstance3D = _wrap(mesh, "Cliff")
	# Lift the instance so the lowest vertex sits exactly on y = 0.
	mi.position = Vector3(0.0, -mesh.get_aabb().position.y, 0.0)
	var reach: float = maxf(size.x, size.z) * 0.5
	var tufts: MeshInstance3D = _ring_dressing(rng, reach * 1.0, reach * 1.35, 14, 3, [Palette.MOON, Palette.GOLD])
	tufts.position = Vector3(0.0, -mi.position.y, 0.0)
	mi.add_child(tufts)
	return mi


## The animated ocean, kept for older callers: a WaterKit ocean in the "day" mood (Gerstner waves, DEEP_OCEAN).
static func ocean_plane(size: Vector2) -> MeshInstance3D:
	return WaterKit.ocean(size, &"day")


## A patch of grass within `radius` of the origin. The returned node carries a low, static under-layer as its
## own mesh; the tall blades are `blades` wind-swaying tufts in its MultiMeshInstance3D child named "Blades".
static func grass_patch(rng_seed: int, radius: float = 1.5, blades: int = 24) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var st: SurfaceTool = _tool()
	var total: int = maxi(blades, 0)
	for i: int in range(maxi(total, 4)):
		var pos: Vector3 = _disc_point(rng, 0.0, radius)
		_blade(st, pos, rng.randf_range(0.0, TAU), rng.randf_range(0.1, 0.22), 0.035, rng.randf_range(0.02, 0.08),
			Palette.GROVE_GREEN, Palette.GROVE_GREEN.lerp(Palette.GOLD, rng.randf_range(0.1, 0.4)), 0.5)
	var mi: MeshInstance3D = _wrap(_commit([KIND_LEAF], [st]), "GrassPatch")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(_blades(rng, 0.0, radius, total))
	return mi


## Wild flowers scattered over an `area` (x, z) centred on the origin: thin stems with small leaves and
## petal rosettes in ASHOKA_RED, SAFFRON, GOLD and MOON. `count` < 0 picks a density that suits the area.
static func flowers(area: Vector2, rng_seed: int, count: int = -1) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var st: SurfaceTool = _tool()
	var total: int = count if count >= 0 else clampi(int(area.x * area.y * 4.0), 3, 240)
	var colours: Array[Color] = [Palette.ASHOKA_RED, Palette.SAFFRON, Palette.GOLD, Palette.MOON]
	for i: int in range(total):
		var pos: Vector3 = Vector3(rng.randf_range(-0.5, 0.5) * area.x, 0.0, rng.randf_range(-0.5, 0.5) * area.y)
		# Flowers grow in drifts of one colour: the colour follows the position, with a little mixing.
		var pick: int = int(absf(floorf(pos.x * 0.45) + floorf(pos.z * 0.45) * 3.0) + float(rng.randi_range(0, 4) / 4)) % colours.size()
		_flower(st, pos, rng, colours[pick])
	var mi: MeshInstance3D = _wrap(_commit([KIND_LEAF], [st]), "Flowers")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- shared helpers ----------------------------------------------------------------------------------------

static func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


static func _tool() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## One ArrayMesh with one surface per kind (named after it, with its Materials material). Empty tools are skipped.
static func _commit(kinds: Array[StringName], tools: Array[SurfaceTool]) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for i: int in range(kinds.size()):
		var arrays: Array = tools[i].commit_to_arrays()
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not (verts is PackedVector3Array) or (verts as PackedVector3Array).is_empty():
			continue
		var index: int = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(index, String(kinds[i]))
		mesh.surface_set_material(index, Materials.get_material(kinds[i]))
	return mesh


static func _wrap(mesh: ArrayMesh, node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	# The wind moves foliage a little outside the mesh bounds.
	mi.extra_cull_margin = 0.5
	return mi


## Trees cast their shadow through a simpler hidden mesh (the trunk and one soft mass per leaf cluster, inside
## the leaf shell). The outer leaves then stay free of the speckled self-shadowing that hundreds of small
## overlapping cards cause, while the ground and the inner canopy still get a soft tree-shaped shadow.
static func _add_shadow_caster(tree: MeshInstance3D, shade: SurfaceTool) -> void:
	tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caster: MeshInstance3D = _wrap(_commit([KIND_LEAF], [shade]), SHADOW_CASTER_NAME)
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	tree.add_child(caster)


static func _with_alpha(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, alpha)


static func _shade(colour: Color, factor: float) -> Color:
	return Color(clampf(colour.r * factor, 0.0, 1.0), clampf(colour.g * factor, 0.0, 1.0), clampf(colour.b * factor, 0.0, 1.0), colour.a)


static func _leaf_shadow() -> Color:
	return Palette.LEAF_DARK.lerp(Palette.NIGHT_INDIGO, 0.3)


static func _leaf_sun() -> Color:
	return Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.32)


static func _vertex(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_normal(n)
	st.set_color(c)
	st.add_vertex(p)


## A triangle with per-vertex normals and colours. It is wound clockwise (Godot's front face) as seen from the
## side its normals point to, so two-sided foliage keeps its puffed normals when viewed from outside.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	var g: Vector3 = (b - a).cross(c - a)
	if g.length_squared() < 1e-14:
		return
	_vertex(st, a, na, ca)
	if g.dot(na + nb + nc) >= 0.0:
		_vertex(st, c, nc, cc)
		_vertex(st, b, nb, cb)
	else:
		_vertex(st, b, nb, cb)
		_vertex(st, c, nc, cc)


static func _perpendicular(dir: Vector3) -> Vector3:
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = dir.cross(Vector3.RIGHT)
	return side.normalized()


## Point at parameter t (0..1) along a polyline.
static func _sample(points: PackedVector3Array, t: float) -> Vector3:
	var f: float = clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var i: int = mini(int(f), points.size() - 2)
	return points[i].lerp(points[i + 1], f - float(i))


static func _disc_point(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var dist: float = sqrt(lerpf(inner * inner, outer * outer, rng.randf()))
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


# --- wood --------------------------------------------------------------------------------------------------

## BARK along a tube, darker at its first ring (the root) by `root_dark`.
static func _bark_colours(count: int, root_dark: float) -> PackedColorArray:
	var cols: PackedColorArray = PackedColorArray()
	for k: int in range(count):
		var t: float = float(k) / float(maxi(count - 1, 1))
		var dark: float = root_dark * exp(-t * 7.0)
		cols.append(Palette.BARK if dark < 0.01 else _shade(Palette.BARK, 1.0 - dark))
	return cols


## A smooth-shaded tube through `points` with one radius and colour per point. The end is closed with a
## rounded tip when `capped`.
static func _tube(st: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, sides: int,
		cols: PackedColorArray, capped: bool = true) -> void:
	var count: int = points.size()
	if count < 2:
		return
	var ref: Vector3 = Vector3.RIGHT
	var prev_pos: PackedVector3Array = PackedVector3Array()
	var prev_nrm: PackedVector3Array = PackedVector3Array()
	var tangent: Vector3 = Vector3.UP
	for k: int in range(count):
		tangent = (points[mini(k + 1, count - 1)] - points[maxi(k - 1, 0)]).normalized()
		var u: Vector3 = ref - tangent * ref.dot(tangent)
		if u.length_squared() < 1e-6:
			u = _perpendicular(tangent)
		u = u.normalized()
		ref = u
		var v: Vector3 = tangent.cross(u)
		var pos: PackedVector3Array = PackedVector3Array()
		var nrm: PackedVector3Array = PackedVector3Array()
		for s: int in range(sides):
			var a: float = TAU * float(s) / float(sides)
			var radial: Vector3 = u * cos(a) + v * sin(a)
			pos.append(points[k] + radial * radii[k])
			nrm.append(radial)
		if k > 0:
			for s: int in range(sides):
				var s2: int = (s + 1) % sides
				_tri(st, prev_pos[s], prev_pos[s2], pos[s2], prev_nrm[s], prev_nrm[s2], nrm[s2], cols[k - 1], cols[k - 1], cols[k])
				_tri(st, prev_pos[s], pos[s2], pos[s], prev_nrm[s], nrm[s2], nrm[s], cols[k - 1], cols[k], cols[k])
		prev_pos = pos
		prev_nrm = nrm
	if capped:
		var tip: Vector3 = points[count - 1] + tangent * radii[count - 1]
		for s: int in range(sides):
			var s2: int = (s + 1) % sides
			_tri(st, prev_pos[s], prev_pos[s2], tip, prev_nrm[s], prev_nrm[s2], tangent, cols[count - 1], cols[count - 1], cols[count - 1])


## A curved, tapering branch from `from` to `to`. `bend` offsets the middle of the curve.
static func _limb(st: SurfaceTool, from: Vector3, to: Vector3, bend: Vector3, r_from: float, r_to: float,
		sides: int, segments: int) -> void:
	var control: Vector3 = (from + to) * 0.5 + bend
	var points: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for k: int in range(segments + 1):
		var t: float = float(k) / float(segments)
		var inv: float = 1.0 - t
		points.append(from * inv * inv + control * 2.0 * inv * t + to * t * t)
		radii.append(lerpf(r_from, r_to, t))
	_tube(st, points, radii, sides, _bark_colours(points.size(), 0.0))


# --- foliage -----------------------------------------------------------------------------------------------

## One leaf card: a folded kite from `base` along `dir`, its tip sagging by `droop`. Normals lean toward the
## direction away from `puff` (the cluster centre). `c0` is the stem colour and `c1` the tip colour.
static func _leaf(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float, droop: float,
		puff: Vector3, c0: Color, c1: Color, jitter: float, w0: float, w1: float) -> void:
	var side: Vector3 = _perpendicular(dir)
	var face: Vector3 = side.cross(dir).normalized()
	var tip: Vector3 = base + dir * length + Vector3.DOWN * droop * length
	var mid: Vector3 = base + dir * length * 0.42 + Vector3.DOWN * droop * length * 0.25
	var left: Vector3 = mid - side * width * 0.5 + face * width * 0.22
	var right: Vector3 = mid + side * width * 0.5 + face * width * 0.22
	var cm: Color = _shade(c0.lerp(c1, 0.55), jitter)
	var wm: float = lerpf(w0, w1, 0.5)
	var nb: Vector3 = ((base - puff).normalized() * 0.8 + face * 0.2).normalized()
	var nt: Vector3 = ((tip - puff).normalized() * 0.8 + face * 0.2).normalized()
	var nl: Vector3 = ((left - puff).normalized() * 0.8 + (face - side * 0.5) * 0.2).normalized()
	var nr: Vector3 = ((right - puff).normalized() * 0.8 + (face + side * 0.5) * 0.2).normalized()
	_tri(st, base, left, tip, nb, nl, nt, _with_alpha(c0, w0), _with_alpha(cm, wm), _with_alpha(c1, w1))
	_tri(st, base, tip, right, nb, nt, nr, _with_alpha(c0, w0), _with_alpha(c1, w1), _with_alpha(cm, wm))


## A leaf cluster: `sprigs` fans of `leaves` leaf cards on the surface of an ellipsoid, over a few dark sprigs
## deep inside it. `shade`, when given, receives the cluster's soft mass for the tree's shadow caster.
## _STYLE_DROOP hangs long narrow leaves (ashoka); _STYLE_SPREAD lays rounder leaves outward in pads (shimshapa).
## The leaf colour goes from shadow greens low and inside the crown to sunlit greens on top.
static func _cluster(st: SurfaceTool, shade: SurfaceTool, centre: Vector3, radius: float, stretch: Vector3, rng: RandomNumberGenerator,
		style: int, sprigs: int, leaves: int, leaf_length: float, crown_bottom: float, crown_top: float) -> void:
	var shadow: Color = _leaf_shadow()
	var sun: Color = _leaf_sun()
	var deep: Color = _shade(Palette.LEAF_DARK, 0.55)
	if shade != null:
		_core(shade, centre, stretch * radius * 0.58, rng, shadow)
	var spin: float = rng.randf_range(0.0, TAU)
	var lowest: float = -0.95 if style == _STYLE_DROOP else -0.75
	# The last `inner` sprigs sit deep inside the cluster, in shadow colours: they give the canopy depth where
	# the outer shell lets the eye through.
	var inner: int = maxi(sprigs / 4, 2)
	for i: int in range(sprigs + inner):
		var is_inner: bool = i >= sprigs
		var y: float = 1.0 - (1.0 - lowest) * (float(i) + 0.5) / float(sprigs)
		if is_inner:
			y = 0.8 - 1.6 * (float(i - sprigs) + 0.5) / float(inner)
		var ring: float = sqrt(maxf(1.0 - y * y, 0.0))
		var phi: float = spin + float(i) * _GOLDEN_ANGLE
		var out: Vector3 = Vector3(cos(phi) * ring, y, sin(phi) * ring)
		var origin: Vector3 = centre + out * stretch * radius * (rng.randf_range(0.2, 0.45) if is_inner else rng.randf_range(0.7, 0.98))
		var height01: float = clampf((origin.y - crown_bottom) / maxf(crown_top - crown_bottom, 0.001), 0.0, 1.0)
		var light: float = 0.5 * height01 + 0.5 * (out.y * 0.5 + 0.5) + rng.randf_range(-0.14, 0.14)
		var c0: Color = Palette.LEAF_DARK
		var c1: Color = Palette.GROVE_GREEN
		if light < 0.36:
			c0 = shadow
			c1 = Palette.LEAF_DARK
		elif light > 0.68:
			c0 = Palette.GROVE_GREEN
			c1 = sun
		if is_inner:
			c0 = deep
			c1 = _shade(Palette.LEAF_DARK, 0.8)
		# The leaves of a sprig fan out like shingles, all pointing down and outward along the cluster's surface.
		var down: Vector3 = Vector3.DOWN - out * Vector3.DOWN.dot(out)
		if down.length_squared() < 0.04:
			var yaw: float = rng.randf_range(0.0, TAU)
			down = Vector3(cos(yaw), 0.0, sin(yaw))
			down -= out * down.dot(out)
		down = down.normalized()
		var fan: float = 1.9 if style == _STYLE_DROOP else 2.4
		# Sprigs on top of the cluster open into a full rosette that covers the crown.
		var count: int = leaves
		if out.y > 0.6 or is_inner:
			fan = TAU * float(leaves + 1) / float(leaves + 2)
			count = leaves + 2
		for k: int in range(count):
			var a: float = (float(k) / float(maxi(count - 1, 1)) - 0.5) * fan + rng.randf_range(-0.2, 0.2)
			var along: Vector3 = down.rotated(out, a)
			var length: float = leaf_length * rng.randf_range(0.8, 1.25)
			var dir: Vector3
			var width: float
			var droop: float
			if style == _STYLE_DROOP:
				dir = (out * 0.35 + along * 0.6 + Vector3.DOWN * rng.randf_range(0.6, 1.0)).normalized()
				width = length * 0.3
				droop = 0.2
			else:
				dir = (out * 0.5 + along + Vector3.DOWN * rng.randf_range(0.0, 0.25)).normalized()
				width = length * 0.56
				droop = 0.12
			_leaf(st, origin, dir, length, width, droop, centre, c0, c1, rng.randf_range(0.9, 1.1), 0.35, 1.0)


## The soft mass of a leaf cluster (for the shadow caster): a lumpy smooth ellipsoid.
static func _core(st: SurfaceTool, centre: Vector3, half: Vector3, rng: RandomNumberGenerator, colour: Color) -> void:
	var points: Array[PackedVector3Array] = _lump_points(half, rng, 4, 7, 0.2, 0, false)
	var normals: Array[PackedVector3Array] = _grid_normals(points)
	var colours: Array[PackedColorArray] = []
	for i: int in range(points.size()):
		var row: PackedColorArray = PackedColorArray()
		for j: int in range(points[i].size()):
			var up: float = normals[i][j].y * 0.5 + 0.5
			row.append(_with_alpha(_shade(colour.lerp(Palette.LEAF_DARK, up * 0.4), 0.5), 0.35))
		colours.append(row)
	_emit_grid(st, centre, points, normals, colours)


## A round bunch of small petals bursting from `pos` toward `out`.
static func _blossom(st: SurfaceTool, pos: Vector3, out: Vector3, size: float, rng: RandomNumberGenerator,
		petal: Color, heart: Color, petals: int) -> void:
	var u: Vector3 = _perpendicular(out)
	var v: Vector3 = out.cross(u)
	var puff: Vector3 = pos - out * size * 0.5
	var twist: float = rng.randf_range(0.0, TAU)
	var c0: Color = _with_alpha(heart, 0.45)
	var c1: Color = _with_alpha(petal, 0.6)
	for k: int in range(petals):
		var a: float = twist + float(k) * _GOLDEN_ANGLE
		var tilt: float = 0.25 + 1.2 * float(k) / float(maxi(petals - 1, 1))
		var dir: Vector3 = (out * cos(tilt) + (u * cos(a) + v * sin(a)) * sin(tilt)).normalized()
		var side: Vector3 = _perpendicular(dir)
		var length: float = size * rng.randf_range(0.8, 1.15)
		var tip: Vector3 = pos + dir * length
		var mid: Vector3 = pos + dir * length * 0.6
		var left: Vector3 = mid - side * length * 0.3
		var right: Vector3 = mid + side * length * 0.3
		var nb: Vector3 = out
		var nt: Vector3 = (tip - puff).normalized()
		_tri(st, pos, left, tip, nb, (left - puff).normalized(), nt, c0, c1, c1)
		_tri(st, pos, tip, right, nb, nt, (right - puff).normalized(), c0, c1, c1)


static func _bush_into(bark: SurfaceTool, leaf: SurfaceTool, origin: Vector3, radius: float,
		rng: RandomNumberGenerator, flowering: bool) -> void:
	var clusters: int = 4
	var spin: float = rng.randf_range(0.0, TAU)
	for i: int in range(clusters):
		var a: float = spin + TAU * float(i) / float(clusters - 1)
		var dist: float = radius * 0.45 if i < clusters - 1 else 0.0
		var r: float = radius * rng.randf_range(0.48, 0.6)
		var centre: Vector3 = origin + Vector3(cos(a) * dist, radius * (0.5 if i < clusters - 1 else 0.85) * rng.randf_range(0.9, 1.1), sin(a) * dist)
		_limb(bark, origin, centre, Vector3(cos(a), 0.0, sin(a)) * radius * 0.12, radius * 0.045, radius * 0.02, 4, 3)
		_cluster(leaf, null, centre, r, Vector3(1.1, 0.8, 1.1), rng, _STYLE_SPREAD, 14, 4, radius * 0.36, origin.y, origin.y + radius * 1.4)
		if flowering:
			for j: int in range(3):
				var yaw: float = rng.randf_range(0.0, TAU)
				var dir: Vector3 = Vector3(cos(yaw), rng.randf_range(0.2, 1.0), sin(yaw)).normalized()
				_blossom(leaf, centre + dir * Vector3(1.1, 0.8, 1.1) * r * 1.05, dir, radius * 0.11, rng,
					Palette.MOON, Palette.GOLD, 6)


## One curved grass blade rooted at `pos`: rigid at the root, free at the tip.
static func _blade(st: SurfaceTool, pos: Vector3, yaw: float, height: float, width: float, lean: float,
		root: Color, tip_colour: Color, tip_weight: float) -> void:
	var side: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw))
	var segments: int = 3
	var prev_l: Vector3 = pos - side * width * 0.5
	var prev_r: Vector3 = pos + side * width * 0.5
	var prev_c: Color = _with_alpha(root, 0.0)
	# The normal follows the blade's facing with only a little lift: foliage is two-sided and the renderer mirrors
	# the normal on the back face, so a mostly upward normal would turn half of the blades dark.
	var prev_n: Vector3 = (forward + Vector3.UP * 0.3).normalized()
	for k: int in range(1, segments + 1):
		var t: float = float(k) / float(segments)
		var centre: Vector3 = pos + Vector3.UP * height * t + forward * lean * t * t
		var half: float = width * 0.5 * (1.0 - t)
		var colour: Color = _with_alpha(root.lerp(tip_colour, t), tip_weight * pow(t, 1.5))
		var normal: Vector3 = (forward + Vector3.UP * (0.3 - 0.5 * t)).normalized()
		var left: Vector3 = centre - side * half
		var right: Vector3 = centre + side * half
		if k == segments:
			_tri(st, prev_l, prev_r, centre, prev_n, prev_n, normal, prev_c, prev_c, colour)
		else:
			_tri(st, prev_l, prev_r, right, prev_n, prev_n, normal, prev_c, prev_c, colour)
			_tri(st, prev_l, right, left, prev_n, normal, normal, prev_c, colour, colour)
		prev_l = left
		prev_r = right
		prev_c = colour
		prev_n = normal


## The shared mesh of one grass tuft (five blades). Its vertex colours are a grey ramp, dark at the root: the
## MultiMesh instance colour tints it. Alpha is the wind weight.
static func _tuft() -> ArrayMesh:
	if _tuft_mesh == null:
		var rng: RandomNumberGenerator = _rng(7919)
		var st: SurfaceTool = _tool()
		for i: int in range(5):
			var yaw: float = TAU * float(i) / 5.0 + rng.randf_range(-0.4, 0.4)
			var pos: Vector3 = Vector3(cos(yaw * 1.7), 0.0, sin(yaw * 1.7)) * rng.randf_range(0.0, 0.07)
			_blade(st, pos, yaw, rng.randf_range(0.26, 0.5), 0.06, rng.randf_range(0.06, 0.2),
				Color(0.8, 0.8, 0.8, 1.0), Color(1.0, 1.0, 1.0, 1.0), 1.0)
		_tuft_mesh = _commit([KIND_LEAF], [st])
	return _tuft_mesh


## `count` tinted, scaled copies of the tuft between `inner` and `outer` metres from the origin.
## The alpha of the tint stays 1 so the tuft's own wind weights pass through.
static func _blades(rng: RandomNumberGenerator, inner: float, outer: float, count: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft()
	mm.instance_count = count
	var origins: PackedVector3Array = PackedVector3Array()
	var tints: PackedColorArray = PackedColorArray()
	for i: int in range(count):
		var pos: Vector3 = _disc_point(rng, inner, outer)
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var mix: float = rng.randf()
		var colour: Color = Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.15 + mix * 0.4)
		mm.set_instance_color(i, Color(colour.r, colour.g, colour.b, 1.0))
		origins.append(pos)
		tints.append(Color(colour.r, colour.g, colour.b, 1.0))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = BLADES_NAME
	node.multimesh = mm
	# The layout is also kept as metadata: a headless rendering server stores no per-instance data to read back.
	node.set_meta(BLADE_ORIGINS_META, origins)
	node.set_meta(BLADE_COLOURS_META, tints)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 0.5
	return node


## One flower: a thin stem, two small leaves and a petal rosette with a GOLD heart.
static func _flower(st: SurfaceTool, pos: Vector3, rng: RandomNumberGenerator, colour: Color) -> void:
	var height: float = rng.randf_range(0.16, 0.4)
	var yaw: float = rng.randf_range(0.0, TAU)
	var lean: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw)) * height * rng.randf_range(0.05, 0.3)
	var head: Vector3 = pos + Vector3.UP * height + lean
	var side: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw)) * 0.012
	var up: Vector3 = Vector3.UP
	var c_root: Color = _with_alpha(Palette.LEAF_DARK, 0.0)
	var c_top: Color = _with_alpha(Palette.GROVE_GREEN, 0.6)
	_tri(st, pos - side, pos + side, head, up, up, up, c_root, c_root, c_top)
	for k: int in range(2):
		var a: float = yaw + PI * float(k) + 1.2
		var dir: Vector3 = Vector3(cos(a), 0.7, sin(a)).normalized()
		_leaf(st, pos + (head - pos) * 0.2, dir, height * 0.45, height * 0.16, 0.3, pos - up * 0.3,
			Palette.LEAF_DARK, Palette.GROVE_GREEN, 1.0, 0.1, 0.5)
	var axis: Vector3 = (Vector3.UP + lean.normalized() * 0.5).normalized()
	var u: Vector3 = _perpendicular(axis)
	var v: Vector3 = axis.cross(u)
	var petals: int = rng.randi_range(5, 6)
	var size: float = rng.randf_range(0.08, 0.13)
	var c0: Color = _with_alpha(colour.lerp(Palette.GOLD, 0.4), 0.6)
	var c1: Color = _with_alpha(colour, 0.7)
	var c2: Color = _with_alpha(colour.lerp(Palette.MOON, 0.3), 0.7)
	for k: int in range(petals):
		var a: float = TAU * float(k) / float(petals)
		var radial: Vector3 = u * cos(a) + v * sin(a)
		var cross: Vector3 = axis.cross(radial)
		var tip: Vector3 = head + radial * size + axis * size * 0.3
		var mid: Vector3 = head + radial * size * 0.55 + axis * size * 0.08
		var n: Vector3 = (axis + radial * 0.5).normalized()
		_tri(st, head, mid - cross * size * 0.32, tip, axis, n, n, c0, c1, c2)
		_tri(st, head, tip, mid + cross * size * 0.32, axis, n, n, c0, c2, c1)
	var gold: Color = _with_alpha(Palette.GOLD, 0.6)
	var heart: Vector3 = head + axis * size * 0.28
	for k: int in range(3):
		var a: float = TAU * float(k) / 3.0
		var b: float = TAU * float(k + 1) / 3.0
		var p1: Vector3 = head + (u * cos(a) + v * sin(a)) * size * 0.25 + axis * size * 0.05
		var p2: Vector3 = head + (u * cos(b) + v * sin(b)) * size * 0.25 + axis * size * 0.05
		_tri(st, p1, p2, heart, axis, axis, axis, gold, gold, gold)


## Ground dressing in a ring around a prop: swaying grass tufts plus a few flowers. Returns a node named
## "Undergrowth" whose mesh is the flowers and whose "Blades" child is the grass.
static func _ring_dressing(rng: RandomNumberGenerator, inner: float, outer: float, tufts: int, blooms: int,
		colours: Array[Color]) -> MeshInstance3D:
	var st: SurfaceTool = _tool()
	for i: int in range(blooms):
		_flower(st, _disc_point(rng, inner, outer), rng, colours[i % colours.size()])
	var mi: MeshInstance3D = _wrap(_commit([KIND_LEAF], [st]), UNDERGROWTH_NAME)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(_blades(rng, inner, outer, tufts))
	return mi


static func _undergrowth(rng: RandomNumberGenerator, radius: float, tufts: int, blooms: int,
		colours: Array[Color]) -> MeshInstance3D:
	return _ring_dressing(rng, radius * 0.12, radius, tufts, blooms, colours)


# --- stone -------------------------------------------------------------------------------------------------

## A chiselled boulder centred on `centre` with half extents `half` and a flat base, coloured as weathered stone.
static func _boulder(st: SurfaceTool, centre: Vector3, half: Vector3, rng: RandomNumberGenerator, rings: int,
		segments: int, jitter: float, cuts: int, moss: float, crag: bool = false) -> void:
	var points: Array[PackedVector3Array] = _lump_points(half, rng, rings, segments, jitter, cuts, true, crag)
	var normals: Array[PackedVector3Array] = _grid_normals(points)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi() & 0x7fffffff
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.9
	var moss_colour: Color = Palette.GROVE_GREEN.lerp(Palette.STONE, 0.3)
	var colours: Array[PackedColorArray] = []
	for i: int in range(points.size()):
		var row: PackedColorArray = PackedColorArray()
		for j: int in range(points[i].size()):
			var p: Vector3 = points[i][j]
			var n: Vector3 = normals[i][j]
			var unit: Vector3 = Vector3(p.x / maxf(half.x, 0.001), p.y / maxf(half.y, 0.001), p.z / maxf(half.z, 0.001))
			var h01: float = clampf(unit.y * 0.5 + 0.5, 0.0, 1.0)
			# Darker and warmer toward the ground, sun-bleached on top, with strata and blotches.
			var c: Color = Palette.STONE.lerp(Palette.BARK, 0.42 * pow(1.0 - h01, 1.5))
			c = c.lerp(Palette.MOON, 0.2 * h01 * maxf(n.y, 0.0))
			var strata: float = sin((centre.y + p.y) * 5.0 + noise.get_noise_3dv(unit * 1.3) * 2.5)
			c = _shade(c, 1.0 + 0.05 * strata + 0.06 * noise.get_noise_3dv(unit * 2.7 + Vector3(9.0, 0.0, 0.0)))
			var patch: float = smoothstep(-0.25, 0.3, noise.get_noise_3dv(unit * 1.6 + Vector3(0.0, 7.0, 0.0)))
			var grows: float = smoothstep(0.45, 0.85, n.y) * patch * moss
			c = c.lerp(moss_colour, clampf(grows, 0.0, 0.85))
			row.append(Color(c.r, c.g, c.b, 1.0))
		colours.append(row)
	_emit_grid(st, centre, points, normals, colours)


## Grid of points (rings + 1 rows from the top pole down, `segments` columns) on a noise-displaced ellipsoid.
## `cuts` random planes chisel flat facets into it (`crag`: sheer faces and a ledge on top). With `flat_bottom` the lower half is fuller and ends in a
## flat base at y = -half.y.
static func _lump_points(half: Vector3, rng: RandomNumberGenerator, rings: int, segments: int, jitter: float,
		cuts: int, flat_bottom: bool, crag: bool = false) -> Array[PackedVector3Array]:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi() & 0x7fffffff
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.75
	noise.fractal_octaves = 2
	var planes: Array[Plane] = []
	for k: int in range(cuts):
		var yaw: float = rng.randf_range(0.0, TAU)
		var pitch: float = rng.randf_range(-0.25, 1.0)
		var depth: float = rng.randf_range(0.68, 0.9)
		if crag:
			# Crags: sheer, deeper cuts and one sloping ledge on top.
			pitch = rng.randf_range(-0.12, 0.3) if k > 0 else rng.randf_range(1.0, 1.35)
			depth = rng.randf_range(0.5, 0.8) if k > 0 else rng.randf_range(0.7, 0.85)
		var normal: Vector3 = Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)).normalized()
		planes.append(Plane(normal, depth))
	var points: Array[PackedVector3Array] = []
	for i: int in range(rings + 1):
		var theta: float = PI * float(i) / float(rings)
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in range(segments):
			var phi: float = TAU * float(j) / float(segments)
			var dir: Vector3 = Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var q: Vector3 = dir * (1.0 + jitter * noise.get_noise_3dv(dir * 1.6) * 1.6)
			if flat_bottom and dir.y < 0.0:
				var fill: float = lerpf(1.0, 1.0 / maxf(sqrt(1.0 - dir.y * dir.y), 0.35), 0.75)
				q.x *= fill
				q.z *= fill
				q.y *= 1.6
			for plane: Plane in planes:
				var over: float = plane.normal.dot(q) - plane.d
				if over > 0.0:
					q -= plane.normal * over
			if flat_bottom:
				q.y = maxf(q.y, -1.0)
				if i == rings:
					q = Vector3(0.0, -1.0, 0.0)
			row.append(q * half)
		points.append(row)
	return points


## Smooth outward normals of a _lump_points grid, from central differences.
static func _grid_normals(points: Array[PackedVector3Array]) -> Array[PackedVector3Array]:
	var rows: int = points.size()
	var normals: Array[PackedVector3Array] = []
	for i: int in range(rows):
		var segments: int = points[i].size()
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in range(segments):
			var p: Vector3 = points[i][j]
			var n: Vector3 = Vector3.ZERO
			if i > 0 and i < rows - 1:
				var du: Vector3 = points[i][(j + 1) % segments] - points[i][(j + segments - 1) % segments]
				var dv: Vector3 = points[i + 1][j] - points[i - 1][j]
				n = du.cross(dv)
			if n.length_squared() < 1e-12:
				n = p if p.length_squared() > 1e-12 else Vector3.UP
			n = n.normalized()
			if n.dot(p) < 0.0:
				n = -n
			row.append(n)
		normals.append(row)
	# Poles: the average of the neighbouring ring.
	for pole: int in [0, rows - 1]:
		var near: int = 1 if pole == 0 else rows - 2
		var sum: Vector3 = Vector3.ZERO
		for n: Vector3 in normals[near]:
			sum += n
		var average: Vector3 = sum.normalized() if sum.length_squared() > 1e-8 else (Vector3.UP if pole == 0 else Vector3.DOWN)
		for j: int in range(normals[pole].size()):
			normals[pole][j] = average
	return normals


static func _emit_grid(st: SurfaceTool, centre: Vector3, points: Array[PackedVector3Array],
		normals: Array[PackedVector3Array], colours: Array[PackedColorArray]) -> void:
	for i: int in range(points.size() - 1):
		var segments: int = points[i].size()
		for j: int in range(segments):
			var j2: int = (j + 1) % segments
			var i2: int = i + 1
			_tri(st, centre + points[i][j], centre + points[i][j2], centre + points[i2][j2],
				normals[i][j], normals[i][j2], normals[i2][j2], colours[i][j], colours[i][j2], colours[i2][j2])
			_tri(st, centre + points[i][j], centre + points[i2][j2], centre + points[i2][j],
				normals[i][j], normals[i2][j2], normals[i2][j], colours[i][j], colours[i2][j2], colours[i2][j])
