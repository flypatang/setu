extends GdUnitTestSuite
## Acceptance tests for M16c narrative/shlokas.gd (DESIGN §7A, §9): the schema is valid, every entry has both
## translations, and all_verified() is false while any verified_by is empty.

const DATA_PATH: String = "res://data/shlokas.json"


func _read_real_file() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _entry(id: String, verified_by: String) -> Dictionary:
	return {
		"id": id,
		"moment": "test_moment",
		"ref": "Sundara Kanda 0.0.0",
		"devanagari": "श्लोकः ॥",
		"iast": "ślokaḥ ||",
		"translation": {"en": "A verse.", "hi": "एक श्लोक।"},
		"verified_by": verified_by,
		"verified_on": "2026-01-01" if verified_by != "" else "",
	}


func _fixture(entries: Array) -> Dictionary:
	return {"_note": "fixture", "shlokas": entries}


# --- the real data file ---

func test_real_file_parses_as_an_object() -> void:
	assert_bool(_read_real_file().is_empty()).is_false()


func test_real_file_schema_is_valid() -> void:
	var problems: Array[String] = Shlokas.validate(_read_real_file())
	assert_array(problems).is_empty()


func test_every_real_entry_has_both_translations() -> void:
	var ids: Array[String] = _real_ids()
	assert_bool(ids.is_empty()).is_false()
	for id: String in ids:
		var entry: Dictionary = Shlokas.get_shloka(id)
		assert_bool(entry.is_empty()).is_false()
		var tr: Dictionary = entry["translation"] as Dictionary
		for lang: String in ["en", "hi"]:
			assert_bool(tr.has(lang)).is_true()
			assert_bool(str(tr[lang]).strip_edges() == "").is_false()


func test_all_verified_is_false_for_real_file() -> void:
	assert_bool(Shlokas.all_verified()).is_false()


# --- get_shloka ---

func test_get_shloka_returns_matching_entry() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	var first: Dictionary = (data["shlokas"] as Array)[0] as Dictionary
	var entry: Dictionary = Shlokas.get_shloka(str(first["id"]))
	assert_str(str(entry["moment"])).is_equal(str(first["moment"]))
	assert_str(str(entry["ref"])).is_equal(str(first["ref"]))


func test_get_shloka_unknown_id_returns_empty_dictionary() -> void:
	var entry: Dictionary = Shlokas.get_shloka("no_such_shloka")
	assert_int(entry.size()).is_equal(0)


# --- validate on fixtures ---

func test_validate_accepts_valid_fixture() -> void:
	var data: Dictionary = _fixture([_entry("a", "")])
	assert_array(Shlokas.validate(data)).is_empty()


func test_validate_rejects_missing_shlokas_key() -> void:
	var problems: Array[String] = Shlokas.validate({"_note": "no list"})
	assert_array(problems).is_not_empty()


func test_validate_rejects_empty_list() -> void:
	var problems: Array[String] = Shlokas.validate(_fixture([]))
	assert_array(problems).is_not_empty()


func test_validate_rejects_missing_hindi_translation() -> void:
	var entry: Dictionary = _entry("a", "")
	entry["translation"] = {"en": "Only English."}
	var problems: Array[String] = Shlokas.validate(_fixture([entry]))
	assert_array(problems).is_not_empty()


func test_validate_rejects_empty_english_translation() -> void:
	var entry: Dictionary = _entry("a", "")
	entry["translation"] = {"en": "   ", "hi": "हिन्दी"}
	var problems: Array[String] = Shlokas.validate(_fixture([entry]))
	assert_array(problems).is_not_empty()


func test_validate_rejects_missing_devanagari() -> void:
	var entry: Dictionary = _entry("a", "")
	entry.erase("devanagari")
	var problems: Array[String] = Shlokas.validate(_fixture([entry]))
	assert_array(problems).is_not_empty()


func test_validate_rejects_duplicate_ids() -> void:
	var problems: Array[String] = Shlokas.validate(_fixture([_entry("dup", ""), _entry("dup", "")]))
	assert_array(problems).is_not_empty()


# --- all_verified on fixtures ---

func test_all_verified_true_when_every_entry_is_verified() -> void:
	var data: Dictionary = _fixture([_entry("a", "Reviewer"), _entry("b", "Reviewer")])
	assert_bool(Shlokas._all_verified_in(data)).is_true()


func test_all_verified_false_when_one_entry_is_unverified() -> void:
	var data: Dictionary = _fixture([_entry("a", "Reviewer"), _entry("b", "")])
	assert_bool(Shlokas._all_verified_in(data)).is_false()


func test_all_verified_false_for_empty_list() -> void:
	assert_bool(Shlokas._all_verified_in(_fixture([]))).is_false()


func test_all_verified_false_when_schema_is_broken() -> void:
	var entry: Dictionary = _entry("a", "Reviewer")
	entry.erase("iast")
	assert_bool(Shlokas._all_verified_in(_fixture([entry]))).is_false()


## Ids read from the real data file, so this suite works unchanged in every game that shares M16c.
func _real_ids() -> Array[String]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	var ids: Array[String] = []
	for entry: Variant in data.get("shlokas", []) as Array:
		ids.append(str((entry as Dictionary).get("id", "")))
	return ids
