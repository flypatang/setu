extends GdUnitTestSuite
## Acceptance tests for core/locale.gd (DESIGN §9, M16b).
## The settings file is backed up before each test and restored afterwards, so a real player's choice survives.

const SCRIPT_PATH: String = "res://core/locale.gd"
const SETTINGS_PATH: String = "user://settings.cfg"
const STRINGS_CSV: String = "res://i18n/strings.csv"

var _settings_backup: PackedByteArray = PackedByteArray()
var _had_settings: bool = false


func before_test() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS_PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	_remove_settings()


func after_test() -> void:
	_remove_settings()
	if _had_settings:
		var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_settings_backup)
			file.close()
	TranslationServer.set_locale("en")


func _remove_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _make_locale() -> Node:
	var script: GDScript = load(SCRIPT_PATH) as GDScript
	var locale: Node = script.new() as Node
	return auto_free(locale) as Node


func test_default_language_is_english() -> void:
	var locale: Node = _make_locale()
	assert_str(str(locale.call("language"))).is_equal("en")


func test_switching_language_changes_translated_text() -> void:
	var locale: Node = _make_locale()
	locale.call("set_language", &"en")
	assert_str(tr("SPK_HANUMAN")).is_equal("Hanuman")
	locale.call("set_language", &"hi")
	assert_str(str(locale.call("language"))).is_equal("hi")
	assert_str(tr("SPK_HANUMAN")).is_equal("हनुमान")
	locale.call("set_language", &"en")
	assert_str(tr("SPK_HANUMAN")).is_equal("Hanuman")


func test_set_language_emits_language_changed() -> void:
	var locale: Node = _make_locale()
	var received: Array[StringName] = []
	locale.connect("language_changed", func(code: StringName) -> void: received.append(code))
	locale.call("set_language", &"hi")
	assert_int(received.size()).is_equal(1)
	assert_str(str(received[0])).is_equal("hi")


func test_unsupported_language_is_ignored() -> void:
	var locale: Node = _make_locale()
	locale.call("set_language", &"fr")
	assert_str(str(locale.call("language"))).is_equal("en")


func test_language_persists_across_restart() -> void:
	var script: GDScript = load(SCRIPT_PATH) as GDScript
	var first: Node = script.new() as Node
	first.call("set_language", &"hi")
	first.free()
	var second: Node = _make_locale()
	assert_str(str(second.call("language"))).is_equal("hi")
	assert_str(tr("SPK_HANUMAN")).is_equal("हनुमान")


func test_every_key_has_non_empty_en_and_hi() -> void:
	var locale: Node = _make_locale()
	assert_object(locale).is_not_null()
	var en: Translation = load("res://i18n/strings.en.translation") as Translation
	var hi: Translation = load("res://i18n/strings.hi.translation") as Translation
	assert_object(en).is_not_null()
	assert_object(hi).is_not_null()
	var csv: FileAccess = FileAccess.open(STRINGS_CSV, FileAccess.READ)
	assert_object(csv).is_not_null()
	var header: PackedStringArray = csv.get_csv_line()
	assert_int(header.size()).is_equal(3)
	var key_count: int = 0
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() < 3 or row[0].strip_edges() == "":
			continue
		key_count += 1
		var key: String = row[0]
		assert_str(en.get_message(key).strip_edges()).override_failure_message("empty en for %s" % key).is_not_empty()
		assert_str(hi.get_message(key).strip_edges()).override_failure_message("empty hi for %s" % key).is_not_empty()
	csv.close()
	assert_int(key_count).is_greater(0)


func test_font_for_ui_uses_devanagari_then_latin_fallback() -> void:
	var locale: Node = _make_locale()
	var font: Font = locale.call("font_for", &"ui") as Font
	assert_object(font).is_not_null()
	var system_font: SystemFont = font as SystemFont
	assert_object(system_font).is_not_null()
	assert_bool(Array(system_font.font_names).has("Noto Sans Devanagari")).is_true()
	assert_bool(Array(system_font.font_names).has("Noto Sans")).is_true()


func test_font_for_shloka_uses_serif_devanagari() -> void:
	var locale: Node = _make_locale()
	var font: Font = locale.call("font_for", &"shloka") as Font
	var system_font: SystemFont = font as SystemFont
	assert_object(system_font).is_not_null()
	assert_bool(Array(system_font.font_names).has("Noto Serif Devanagari")).is_true()
