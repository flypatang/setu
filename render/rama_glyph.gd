class_name RamaGlyph
extends RefCounted
## The Devanagari word राम as a flat textured quad (DESIGN §9, S14c; replaces the S13 extruded boxes).
## The word is rasterised ONCE from the bundled bold Noto Sans Devanagari (Locale.font_for('ui') under a
## FontVariation) into an ImageTexture: SINDOOR ink with a slightly brushed edge on a transparent background.
## Glyph outlines come straight from the TextServer and are filled on the CPU, so it also works headless.
## quad() is a flat quad facing +Z (width = height * ASPECT), centred on the origin, with UVs (v = 0 at the top).
## mesh() is the untouched legacy extruded-box version.
## material() is a shared unshaded alpha material that uses the texture.

const ASPECT: float = 1.4
const TEXT: String = "राम"
const _FONT_SIZE: int = 100
const _EMBOLDEN: float = 0.55
const _MARGIN: float = 0.06
const _SUBROWS: int = 4
const _FLATTEN_STEPS: int = 8

static var _textures: Dictionary[int, ImageTexture] = {}
static var _images: Dictionary[int, Image] = {}
static var _material: StandardMaterial3D = null


## The word as a texture, size_px wide and size_px / ASPECT high. Built once per size and cached.
static func texture(size_px: int = 256) -> Texture2D:
	var px: int = maxi(size_px, 16)
	if not _textures.has(px):
		var img: Image = image(px)
		_textures[px] = ImageTexture.create_from_image(img)
	return _textures[px]


## The source image of texture() (cached, shared: do not modify).
static func image(size_px: int = 256) -> Image:
	var px: int = maxi(size_px, 16)
	if not _images.has(px):
		_images[px] = _render(px)
	return _images[px]


## Flat textured quad facing +Z, `height` tall and height * ASPECT wide, with UVs and the colour as vertex colour.
static func quad(height: float, color: Color) -> ArrayMesh:
	var hw: float = height * ASPECT * 0.5
	var hh: float = height * 0.5
	var verts: PackedVector3Array = PackedVector3Array([
		Vector3(-hw, -hh, 0.0), Vector3(hw, -hh, 0.0), Vector3(hw, hh, 0.0), Vector3(-hw, hh, 0.0)])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	var normals: PackedVector3Array = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var colors: PackedColorArray = PackedColorArray([color, color, color, color])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Shared unshaded alpha material showing the word.
static func material() -> StandardMaterial3D:
	if _material == null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = texture()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.render_priority = 1
		_material = mat
	return _material


static func _render(px: int) -> Image:
	var w: int = px
	var h: int = maxi(1, roundi(float(px) / ASPECT))
	var polys: Array[PackedVector2Array] = _outlines()
	var cover: PackedFloat32Array = _fill(polys, w, h)
	var img: Image = Image.create(w, h, true, Image.FORMAT_RGBA8)
	var ink: Color = Palette.SINDOOR
	for y: int in h:
		for x: int in w:
			var c: float = _blur(cover, w, h, x, y)
			var n: float = _hash(x, y)
			# Bristle streaks run along the baseline, so the edge looks brushed rather than cut.
			var streak: float = _hash(y * 7 + 3, x / 6)
			var cut: float = 0.5 + (n - 0.5) * 0.22 + (streak - 0.5) * 0.2
			var a: float = smoothstep(cut - 0.14, cut + 0.14, c)
			var shade: float = 1.0 - 0.10 * _hash(x / 3 + 11, y / 3 + 5)
			img.set_pixel(x, y, Color(ink.r * shade, ink.g * shade, ink.b * shade, a))
	img.generate_mipmaps()
	return img


## The glyph outlines of TEXT in font units (y down, baseline 0), flattened to polylines.
static func _outlines() -> Array[PackedVector2Array]:
	var base: Font = _ui_font()
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = _EMBOLDEN
	var ts: TextServer = TextServerManager.get_primary_interface()
	var shaped: RID = ts.create_shaped_text()
	ts.shaped_text_add_string(shaped, TEXT, fv.get_rids(), _FONT_SIZE, {}, "hi")
	ts.shaped_text_shape(shaped)
	var out: Array[PackedVector2Array] = []
	var pen: float = 0.0
	for g: Dictionary in ts.shaped_text_get_glyphs(shaped):
		var count: int = g["repeat"] as int
		for r: int in count:
			var shift: Vector2 = Vector2(pen + (g["offset"] as Vector2).x, (g["offset"] as Vector2).y)
			var contours: Dictionary = ts.font_get_glyph_contours(g["font_rid"] as RID, _FONT_SIZE, g["index"] as int)
			var pts: PackedVector3Array = contours["points"] as PackedVector3Array
			var ends: PackedInt32Array = contours["contours"] as PackedInt32Array
			var first: int = 0
			for e: int in ends:
				out.append(_flatten(pts.slice(first, e + 1), shift))
				first = e + 1
			pen += g["advance"] as float
	ts.free_rid(shaped)
	return out


## Locale.font_for('ui'), looked up at run time so the script also compiles where autoloads are not yet known.
static func _ui_font() -> Font:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var loc: Node = tree.root.get_node_or_null("Locale")
		if loc != null:
			return loc.call("font_for", &"ui") as Font
	return load("res://fonts/NotoSansDevanagari.ttf") as Font


## One closed TrueType/CFF contour (z: 1 on-curve, 0 quadratic control, 2 cubic control) as a polyline.
static func _flatten(pts: PackedVector3Array, shift: Vector2) -> PackedVector2Array:
	var n: int = pts.size()
	var poly: PackedVector2Array = PackedVector2Array()
	if n < 2:
		return poly
	var start: int = -1
	for i: int in n:
		if pts[i].z > 0.5 and pts[i].z < 1.5:
			start = i
			break
	var ring: Array[Vector3] = []
	if start < 0:
		var mid: Vector2 = (Vector2(pts[0].x, pts[0].y) + Vector2(pts[n - 1].x, pts[n - 1].y)) * 0.5
		ring.append(Vector3(mid.x, mid.y, 1.0))
		for i: int in n:
			ring.append(pts[i])
	else:
		for i: int in n:
			ring.append(pts[(start + i) % n])
	var m: int = ring.size()
	var cur: Vector2 = Vector2(ring[0].x, ring[0].y)
	poly.append(cur + shift)
	var j: int = 1
	while j <= m:
		var p: Vector3 = ring[j % m]
		var pv: Vector2 = Vector2(p.x, p.y)
		if p.z > 0.5 and p.z < 1.5:
			poly.append(pv + shift)
			cur = pv
			j += 1
		elif p.z > 1.5:
			var p2: Vector3 = ring[(j + 1) % m]
			var p3: Vector3 = ring[(j + 2) % m]
			var end: Vector2 = Vector2(p3.x, p3.y)
			for s: int in range(1, _FLATTEN_STEPS + 1):
				var t: float = float(s) / float(_FLATTEN_STEPS)
				poly.append(cur.bezier_interpolate(pv, Vector2(p2.x, p2.y), end, t) + shift)
			cur = end
			j += 3
		else:
			var nx: Vector3 = ring[(j + 1) % m]
			var nv: Vector2 = Vector2(nx.x, nx.y)
			var end: Vector2 = nv if (nx.z > 0.5 and nx.z < 1.5) else (pv + nv) * 0.5
			for s: int in range(1, _FLATTEN_STEPS + 1):
				var t: float = float(s) / float(_FLATTEN_STEPS)
				poly.append(cur.lerp(pv, t).lerp(pv.lerp(end, t), t) + shift)
			cur = end
			j += 2 if (nx.z > 0.5 and nx.z < 1.5) else 1
	return poly


## Non-zero winding scanline fill with 4 sub-rows per pixel row. Returns coverage 0..1 per pixel.
static func _fill(polys: Array[PackedVector2Array], w: int, h: int) -> PackedFloat32Array:
	var lo: Vector2 = Vector2(1.0e9, 1.0e9)
	var hi: Vector2 = Vector2(-1.0e9, -1.0e9)
	for poly: PackedVector2Array in polys:
		for p: Vector2 in poly:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var size: Vector2 = hi - lo
	var scale: float = minf(float(w) * (1.0 - 2.0 * _MARGIN) / size.x, float(h) * (1.0 - 2.0 * _MARGIN) / size.y)
	var origin: Vector2 = Vector2(float(w), float(h)) * 0.5 - (lo + size * 0.5) * scale
	var edges: Array[Vector4] = []
	for poly: PackedVector2Array in polys:
		var cnt: int = poly.size()
		for i: int in cnt:
			var a: Vector2 = poly[i] * scale + origin
			var b: Vector2 = poly[(i + 1) % cnt] * scale + origin
			if not is_equal_approx(a.y, b.y):
				edges.append(Vector4(a.x, a.y, b.x, b.y))
	var cover: PackedFloat32Array = PackedFloat32Array()
	cover.resize(w * h)
	for row: int in h:
		for sub: int in _SUBROWS:
			var y: float = float(row) + (float(sub) + 0.5) / float(_SUBROWS)
			var xs: Array[Vector2] = []
			for e: Vector4 in edges:
				if (e.y <= y and y < e.w) or (e.w <= y and y < e.y):
					var x: float = e.x + (y - e.y) * (e.z - e.x) / (e.w - e.y)
					xs.append(Vector2(x, 1.0 if e.w > e.y else -1.0))
			xs.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
			var winding: int = 0
			for k: int in xs.size() - 1:
				winding += int(xs[k].y)
				if winding != 0:
					_span(cover, w, row, xs[k].x, xs[k + 1].x)
	return cover


static func _span(cover: PackedFloat32Array, w: int, row: int, a: float, b: float) -> void:
	var x0: float = clampf(a, 0.0, float(w))
	var x1: float = clampf(b, 0.0, float(w))
	var ix: int = int(x0)
	while float(ix) < x1 and ix < w:
		var part: float = minf(x1, float(ix + 1)) - maxf(x0, float(ix))
		cover[row * w + ix] += part / float(_SUBROWS)
		ix += 1


static func _blur(cover: PackedFloat32Array, w: int, h: int, x: int, y: int) -> float:
	var sum: float = 0.0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var xx: int = clampi(x + dx, 0, w - 1)
			var yy: int = clampi(y + dy, 0, h - 1)
			var weight: float = 4.0 if (dx == 0 and dy == 0) else (2.0 if (dx == 0 or dy == 0) else 1.0)
			sum += minf(cover[yy * w + xx], 1.0) * weight
	return sum / 16.0


## Deterministic hash noise in 0..1.
static func _hash(x: int, y: int) -> float:
	var v: int = ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7FFFFFFF
	v = v ^ (v >> 16)
	return float(v & 0xFFFF) / 65535.0


const _DEPTH: float = 0.12
const _WIDTH: float = 1.75
const _T: float = 0.13

## Each stroke: [x0, y0, x1, y1] in glyph units (height 1.0, y up from 0), thickness _T.
const _STROKES: Array[Array] = [
	# shirorekha (headline) across the whole word
	[0.0, 0.89, 1.75, 0.89],
	# र : stem from the headline, sweeping leg to the lower left, foot curling back right
	[0.34, 0.89, 0.34, 0.50],
	[0.34, 0.50, 0.08, 0.14],
	[0.08, 0.14, 0.30, 0.02],
	# ा : full-height stem
	[0.66, 0.89, 0.66, 0.0],
	# म : right stem, loop (top slant, left side, bottom), tail
	[1.65, 0.89, 1.65, 0.0],
	[1.08, 0.89, 1.08, 0.50],
	[1.65, 0.60, 1.08, 0.50],
	[1.08, 0.50, 1.08, 0.02],
	[1.08, 0.02, 1.65, 0.02],
	[1.08, 0.02, 0.92, 0.0],
]


static func strokes() -> Array[Array]:
	return _STROKES


static func stroke_count() -> int:
	return _STROKES.size()


## Legacy extruded-box राम (S13), kept for existing callers; new code should use quad().
static func mesh(height: float, color: Color) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for s: Array in _STROKES:
		lo = minf(lo, minf(s[1] as float, s[3] as float))
		hi = maxf(hi, maxf(s[1] as float, s[3] as float))
	var top: float = hi + _T * 0.5
	var bottom: float = lo - _T * 0.5
	var scale: float = height / (top - bottom)
	var cx: float = _WIDTH * 0.5
	var cy: float = (top + bottom) * 0.5
	for s: Array in _STROKES:
		var a: Vector2 = Vector2(s[0] as float, s[1] as float)
		var b: Vector2 = Vector2(s[2] as float, s[3] as float)
		var length: float = a.distance_to(b) + _T
		var mid: Vector2 = (a + b) * 0.5
		var ang: float = (b - a).angle()
		var box: ArrayMesh = MeshKit.box(Vector3(length * scale, _T * scale, _DEPTH * scale), color)
		var xf: Transform3D = Transform3D(Basis(Vector3.BACK, ang), Vector3((mid.x - cx) * scale, (mid.y - cy) * scale, 0.0))
		parts.append({"mesh": box, "transform": xf})
	return MeshKit.merge(parts)
