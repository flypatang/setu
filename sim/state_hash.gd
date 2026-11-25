class_name StateHash
extends RefCounted
## Canonical SHA-256 hash of a simulation state dictionary (DESIGN §9 S04).
## Same logical state gives the same hash regardless of dictionary key order,
## and floats that differ by less than 1e-4 are treated as equal.

const FLOAT_SCALE: float = 10000.0


## Returns the lowercase hex SHA-256 of the canonical form of `d`.
static func hash_state(d: Dictionary) -> String:
	var canonical: String = _canonical(d)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(canonical.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func _canonical(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			var b: bool = v as bool
			return "true" if b else "false"
		TYPE_INT:
			var i: int = v as int
			return "i" + str(i)
		TYPE_FLOAT:
			var f: float = v as float
			return "f" + _format_float(f)
		TYPE_STRING, TYPE_STRING_NAME:
			return _quote(str(v))
		TYPE_DICTIONARY:
			return _canonical_dict(v as Dictionary)
		TYPE_ARRAY:
			return _canonical_array(v as Array)
		_:
			return "v" + _quote(var_to_str(v))


static func _canonical_dict(d: Dictionary) -> String:
	var keys: Array[String] = []
	var by_key: Dictionary = {}
	for k: Variant in d.keys():
		var key_str: String = str(k)
		keys.append(key_str)
		by_key[key_str] = d[k]
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for key_str: String in keys:
		parts.append(_quote(key_str) + ":" + _canonical(by_key[key_str]))
	return "{" + ",".join(parts) + "}"


static func _canonical_array(a: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in a:
		parts.append(_canonical(item))
	return "[" + ",".join(parts) + "]"


static func _format_float(f: float) -> String:
	if is_nan(f):
		return "nan"
	if is_inf(f):
		return "inf" if f > 0.0 else "-inf"
	var rounded: float = roundf(f * FLOAT_SCALE) / FLOAT_SCALE
	if rounded == 0.0:
		rounded = 0.0 # normalise -0.0 to 0.0
	return "%.4f" % rounded


static func _quote(s: String) -> String:
	return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
