class_name Shlokas
extends RefCounted
## Shloka library (DESIGN §7A, §9 M16c). Loads res://data/shlokas.json. All functions are static; nothing is stored.
## Release export must refuse to run unless all_verified() is true.

const DATA_PATH: String = "res://data/shlokas.json"
const _REQUIRED_TEXT: Array[String] = ["id", "moment", "ref", "devanagari", "iast"]
const _REQUIRED_LANGS: Array[String] = ["en", "hi"]
const _VERIFY_FIELDS: Array[String] = ["verified_by", "verified_on"]


## Returns the shloka entry with this id, or an empty Dictionary when there is none.
static func get_shloka(id: String) -> Dictionary:
	var data: Dictionary = _load_data()
	var raw: Variant = data.get("shlokas")
	if not (raw is Array):
		return {}
	for item: Variant in raw as Array:
		if item is Dictionary:
			var entry: Dictionary = item as Dictionary
			if str(entry.get("id", "")) == id:
				return entry
	return {}


## True only when the shloka file is schema-valid, is not empty, and every entry has a non-empty verified_by.
static func all_verified() -> bool:
	return _all_verified_in(_load_data())


## Returns a list of human-readable problems with the shloka data. An empty list means the data is valid.
static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var raw: Variant = data.get("shlokas")
	if not (raw is Array):
		problems.append("missing 'shlokas' array")
		return problems
	var arr: Array = raw as Array
	if arr.is_empty():
		problems.append("'shlokas' is empty")
	var seen: Dictionary = {}
	for i: int in range(arr.size()):
		var where: String = "shlokas[%d]" % i
		var item: Variant = arr[i]
		if not (item is Dictionary):
			problems.append("%s is not an object" % where)
			continue
		var entry: Dictionary = item as Dictionary
		for key: String in _REQUIRED_TEXT:
			if not _is_nonempty_string(entry, key):
				problems.append("%s: '%s' must be a non-empty string" % [where, key])
		for key: String in _VERIFY_FIELDS:
			if not (entry.get(key) is String):
				problems.append("%s: '%s' must be a string" % [where, key])
		var id: String = str(entry.get("id", ""))
		if id != "" and seen.has(id):
			problems.append("%s: duplicate id '%s'" % [where, id])
		seen[id] = true
		var tr_raw: Variant = entry.get("translation")
		if not (tr_raw is Dictionary):
			problems.append("%s: 'translation' must be an object" % where)
		else:
			var tr: Dictionary = tr_raw as Dictionary
			for lang: String in _REQUIRED_LANGS:
				if not _is_nonempty_string(tr, lang):
					problems.append("%s: translation '%s' is missing or empty" % [where, lang])
	return problems


## Same rule as all_verified(), applied to an already-loaded dictionary.
static func _all_verified_in(data: Dictionary) -> bool:
	if not validate(data).is_empty():
		return false
	var raw: Array = data.get("shlokas") as Array
	for item: Variant in raw:
		var entry: Dictionary = item as Dictionary
		if str(entry.get("verified_by", "")).strip_edges() == "":
			return false
	return true


static func _is_nonempty_string(d: Dictionary, key: String) -> bool:
	var v: Variant = d.get(key)
	return v is String and (v as String).strip_edges() != ""


static func _load_data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
