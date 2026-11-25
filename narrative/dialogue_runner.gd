class_name DialogueRunner
extends Node
## Plays one dialogue graph from data/dialogue/<id>.json (DESIGN §9 M16, format in data/dialogue/SCHEMA.md).
## Call start(id), then advance() after each line or shloka step, or choose(i) at a choice.
## Text always comes through tr(text_key). Flags go to GameState.set_flag. Smarana is reported through
## smarana_awarded. The runner has no UI and no timing: the caller decides when to advance.

signal line_shown(speaker: StringName, text: String)
signal shloka_shown(shloka_id: StringName)
signal smarana_awarded(amount: float)
signal finished(id: StringName)

const DEFAULT_DIALOGUE_DIR: String = "res://data/dialogue/"

## Folder the dialogue files are read from. Tests point it at user:// to use fixtures.
var dialogue_dir: String = DEFAULT_DIALOGUE_DIR
## Node that receives flags through set_flag. When unset, the GameState autoload is used.
var game_state: Node = null

enum Wait { NONE, ADVANCE, CHOICE }

var _id: StringName = &""
var _nodes: Dictionary = {}
var _current: String = ""
var _next: String = ""
var _wait: Wait = Wait.NONE
var _choices: Array[Dictionary] = []


## Loads and starts the dialogue. Returns OK, or an Error if the file or its start node is missing.
func start(id: StringName) -> Error:
	var data: Dictionary = _read_file(id)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	var raw_nodes: Variant = data.get("nodes", null)
	if not (raw_nodes is Dictionary):
		return ERR_PARSE_ERROR
	var nodes: Dictionary = raw_nodes as Dictionary
	var start_id: String = str(data.get("start", ""))
	if not nodes.has(start_id):
		return ERR_PARSE_ERROR
	_id = id
	_nodes = nodes
	_enter(start_id)
	return OK


## Moves past the current line or shloka step. Does nothing while a choice is waiting.
func advance() -> void:
	if _wait != Wait.ADVANCE:
		return
	_wait = Wait.NONE
	_enter(_next)


## Picks choice number index (0-based) of the current choice node. Returns false if no such choice is waiting.
func choose(index: int) -> bool:
	if _wait != Wait.CHOICE or index < 0 or index >= _choices.size():
		return false
	var choice: Dictionary = _choices[index]
	_apply_flags(choice.get("flags", null))
	var amount: float = 0.0
	var raw_amount: Variant = choice.get("smarana", null)
	if raw_amount is float:
		amount = raw_amount as float
	_wait = Wait.NONE
	_choices = []
	if amount > 0.0:
		smarana_awarded.emit(amount)
	_enter(_next_of(choice))
	return true


func is_running() -> bool:
	return _wait != Wait.NONE


func waiting_for_choice() -> bool:
	return _wait == Wait.CHOICE


## Node id being shown, as written in the JSON file. Empty when nothing is running.
func current_node() -> String:
	return _current


## Translated text of each option of the current choice node, in order.
func get_choice_texts() -> Array[String]:
	var texts: Array[String] = []
	if _wait != Wait.CHOICE:
		return texts
	for choice: Dictionary in _choices:
		texts.append(tr(str(choice.get("text_key", ""))))
	return texts


func _read_file(id: StringName) -> Dictionary:
	var path: String = dialogue_dir + str(id) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## Shows the node with the given id, or finishes the dialogue when the id is empty (an end of the graph).
func _enter(node_id: String) -> void:
	if node_id.is_empty():
		_finish()
		return
	if not _nodes.has(node_id):
		push_error("DialogueRunner: %s has no node '%s'" % [_id, node_id])
		_finish()
		return
	_current = node_id
	var node: Dictionary = _nodes[node_id] as Dictionary
	_apply_flags(node.get("set_flags", null))
	_next = _next_of(node)
	if node.has("shloka"):
		_wait = Wait.ADVANCE
		shloka_shown.emit(StringName(str(node["shloka"])))
		return
	if node.has("text_key"):
		line_shown.emit(StringName(str(node.get("speaker", ""))), tr(str(node["text_key"])))
	var raw_choices: Variant = node.get("choices", null)
	if raw_choices is Array and not (raw_choices as Array).is_empty():
		_choices = _to_choices(raw_choices as Array)
		_wait = Wait.CHOICE
	else:
		_wait = Wait.ADVANCE


func _finish() -> void:
	_wait = Wait.NONE
	_current = ""
	_next = ""
	_choices = []
	finished.emit(_id)


## The node id a line or choice continues to, or "" when the dialogue ends there.
func _next_of(entry: Dictionary) -> String:
	var raw: Variant = entry.get("next", null)
	if raw == null:
		return ""
	return str(raw)


func _to_choices(raw: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in raw:
		if item is Dictionary:
			out.append(item as Dictionary)
	return out


func _apply_flags(raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	var state: Node = _get_state()
	if state == null:
		push_warning("DialogueRunner: no GameState available, flags not applied")
		return
	var values: Dictionary = raw as Dictionary
	for key: Variant in values:
		state.call("set_flag", StringName(str(key)), values[key])


func _get_state() -> Node:
	if game_state != null:
		return game_state
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GameState")
