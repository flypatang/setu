class_name RamaGlyph
extends RefCounted
## The Devanagari word राम built from extruded box strokes (DESIGN §9, S13). No fonts, no textures.
## The glyph lies in the XY plane facing +Z, centred on the origin, total height = the requested height.

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
