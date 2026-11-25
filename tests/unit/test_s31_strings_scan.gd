extends GdUnitTestSuite
## S31: every tr("KEY") used by main_game.gd exists in i18n/strings.csv with English and Hindi text,
## and the leftover English fallback dictionary and unused helpers are gone.

const GAME_SCRIPT: String = "res://game/main_game.gd"
const STRINGS_CSV: String = "res://i18n/strings.csv"
const TR_PATTERN: String = "tr\\(\"([A-Za-z0-9_]+)\"\\)"


## Parses CSV text with quoted fields (RFC 4180 style). Returns rows of fields.
static func _parse_csv(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var row: PackedStringArray = PackedStringArray()
	var field: String = ""
	var in_quotes: bool = false
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var c: String = text[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			else:
				field += c
		elif c == "\"":
			in_quotes = true
		elif c == ",":
			row.append(field)
			field = ""
		elif c == "\n":
			row.append(field)
			rows.append(row)
			row = PackedStringArray()
			field = ""
		elif c != "\r":
			field += c
		i += 1
	if field != "" or not row.is_empty():
		row.append(field)
		rows.append(row)
	return rows


func _csv_map() -> Dictionary:
	var out: Dictionary = {}
	var rows: Array[PackedStringArray] = _parse_csv(FileAccess.get_file_as_string(STRINGS_CSV))
	for r: PackedStringArray in rows:
		if r.size() >= 3 and r[0] != "" and r[0] != "keys":
			out[r[0]] = {"en": r[1], "hi": r[2]}
	return out


func _game_source() -> String:
	return FileAccess.get_file_as_string(GAME_SCRIPT)


func test_csv_parser_handles_quoted_commas_and_newlines() -> void:
	var rows: Array[PackedStringArray] = _parse_csv("a,b,c\nk,\"x, \"\"y\"\"\nz\",h\n")
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[1][1]).is_equal("x, \"y\"\nz")
	assert_str(rows[1][2]).is_equal("h")


func test_every_tr_key_in_main_game_exists_in_csv_with_en_and_hi() -> void:
	var regex: RegEx = RegEx.create_from_string(TR_PATTERN)
	var matches: Array[RegExMatch] = regex.search_all(_game_source())
	assert_int(matches.size()).is_greater(0)
	var table: Dictionary = _csv_map()
	for m: RegExMatch in matches:
		var key: String = m.get_string(1)
		assert_bool(table.has(key)).is_true()
		var entry: Dictionary = table[key] as Dictionary
		assert_bool((entry["en"] as String).strip_edges() != "").is_true()
		assert_bool((entry["hi"] as String).strip_edges() != "").is_true()


func test_leftover_fallback_strings_and_helpers_are_removed() -> void:
	var src: String = _game_source()
	assert_bool(src.contains("UI_FALLBACK")).is_false()
	assert_bool(src.contains("CREDITS_TEXT")).is_false()
	assert_bool(src.contains("_t_or")).is_false()
	assert_bool(src.contains("_fallback_tr")).is_false()
