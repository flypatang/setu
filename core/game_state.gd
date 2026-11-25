extends Node
## Autoload `GameState` (DESIGN §9, M03): the story progress and the save/load of it.
## Saves are JSON files at user://save_<slot>.json. Ints and Vector3 are tagged so they
## come back with the same Variant type they were saved with (plain JSON turns ints into floats).

const SAVE_VERSION: int = 1
const SAVE_PATH_FORMAT: String = "user://save_%d.json"
const DEFAULT_CHAPTER: StringName = &"prologue"

var chapter: StringName = DEFAULT_CHAPTER
var flags: Dictionary = {}
var vows: int = 0
var unlocked: Array[StringName] = []
var last_shrine: Dictionary = {}


func set_flag(key: StringName, value: Variant) -> void:
	flags[key] = value


func get_flag(key: StringName, default: Variant = null) -> Variant:
	return flags.get(key, default)


func unlock(ability: StringName) -> void:
	if not unlocked.has(ability):
		unlocked.append(ability)


func is_unlocked(ability: StringName) -> bool:
	return unlocked.has(ability)


func reset() -> void:
	chapter = DEFAULT_CHAPTER
	flags = {}
	vows = 0
	unlocked = []
	last_shrine = {}


func save_game(slot: int) -> Error:
	if slot < 0:
		return ERR_INVALID_PARAMETER
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"chapter": str(chapter),
		"flags": _encode(flags),
		"vows": vows,
		"unlocked": _encode(unlocked),
		"last_shrine": _encode(last_shrine),
	}
	var file: FileAccess = FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


func load_game(slot: int) -> Error:
	if slot < 0:
		return ERR_INVALID_PARAMETER
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return ERR_PARSE_ERROR
	var data: Dictionary = parsed as Dictionary
	if not _is_valid_save(data):
		return ERR_PARSE_ERROR

	var new_unlocked: Array[StringName] = []
	for entry: Variant in _decode(data["unlocked"]) as Array:
		new_unlocked.append(StringName(str(entry)))

	chapter = StringName(str(data["chapter"]))
	flags = _decode(data["flags"]) as Dictionary
	vows = _decode(data["vows"]) as int
	unlocked = new_unlocked
	last_shrine = _decode(data["last_shrine"]) as Dictionary
	return OK


func _slot_path(slot: int) -> String:
	return SAVE_PATH_FORMAT % slot


func _is_valid_save(data: Dictionary) -> bool:
	for key: String in ["chapter", "flags", "vows", "unlocked", "last_shrine"]:
		if not data.has(key):
			return false
	return data["flags"] is Dictionary and data["unlocked"] is Array and data["last_shrine"] is Dictionary


## Turns a Variant into something JSON can store, tagging the types JSON cannot represent.
func _encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return {"__int": value}
		TYPE_STRING_NAME:
			return {"__sn": str(value)}
		TYPE_VECTOR3:
			var v3: Vector3 = value as Vector3
			return {"__v3": [v3.x, v3.y, v3.z]}
		TYPE_DICTIONARY:
			var dict: Dictionary = {}
			var source: Dictionary = value as Dictionary
			for key: Variant in source:
				dict[str(key)] = _encode(source[key])
			return dict
		TYPE_ARRAY:
			var arr: Array = []
			for item: Variant in value as Array:
				arr.append(_encode(item))
			return arr
		_:
			return value


## Reverses _encode.
func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value as Dictionary
		if source.size() == 1 and source.has("__int"):
			return int(source["__int"] as float)
		if source.size() == 1 and source.has("__sn"):
			return StringName(str(source["__sn"]))
		if source.size() == 1 and source.has("__v3"):
			var c: Array = source["__v3"] as Array
			return Vector3(c[0] as float, c[1] as float, c[2] as float)
		var dict: Dictionary = {}
		for key: Variant in source:
			dict[key] = _decode(source[key])
		return dict
	if value is Array:
		var arr: Array = []
		for item: Variant in value as Array:
			arr.append(_decode(item))
		return arr
	return value
