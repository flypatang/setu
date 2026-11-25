extends Node
## Autoload `Locale` (DESIGN §9, M16b): the player's language (en / hi), its translations and its fonts.
## The choice is saved in user://settings.cfg under [general] language and restored on start.
## Translations are generated from i18n/strings.csv by Godot's CSV importer and added to TranslationServer at runtime.

signal language_changed(code: StringName)

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "general"
const SETTINGS_KEY: String = "language"
const DEFAULT_LANGUAGE: String = "en"
const SUPPORTED_LANGUAGES: PackedStringArray = ["en", "hi"]
const TRANSLATION_PATH_FORMAT: String = "res://i18n/strings.%s.translation"
const UI_FONT_NAMES: PackedStringArray = ["Noto Sans Devanagari", "Noto Sans"]
const SHLOKA_FONT_NAMES: PackedStringArray = ["Noto Serif Devanagari"]

var _language: String = DEFAULT_LANGUAGE
var _fonts: Dictionary = {}


func _init() -> void:
	_load_translations()
	_language = _read_saved_language()
	TranslationServer.set_locale(_language)


func language() -> StringName:
	return StringName(_language)


func set_language(code: StringName) -> void:
	var text: String = str(code)
	if not SUPPORTED_LANGUAGES.has(text):
		push_warning("Locale: unsupported language '%s' ignored" % text)
		return
	_language = text
	TranslationServer.set_locale(text)
	_save_language()
	language_changed.emit(StringName(text))


## Bundled Noto fonts (SIL OFL, fonts/OFL.txt) with fallbacks, so Devanagari and IAST diacritics always render.
## ui: Noto Sans Devanagari, then Noto Sans. shloka: Noto Serif Devanagari, then Noto Sans.
## Falls back to a SystemFont by name if the bundled files are missing.
const FONT_FILES: Dictionary = {
	"ui": ["res://fonts/NotoSansDevanagari.ttf", "res://fonts/NotoSans.ttf"],
	"shloka": ["res://fonts/NotoSerifDevanagari.ttf", "res://fonts/NotoSans.ttf"],
}


func font_for(role: StringName) -> Font:
	var key: String = str(role)
	if not _fonts.has(key):
		_fonts[key] = _build_font(key)
	return _fonts[key] as Font


func _build_font(key: String) -> Font:
	var paths: Array = FONT_FILES.get(key, FONT_FILES["ui"]) as Array
	var primary: FontFile = null
	var fallbacks: Array[Font] = []
	for path: Variant in paths:
		var f: FontFile = load(str(path)) as FontFile if ResourceLoader.exists(str(path)) else null
		if f == null:
			continue
		if primary == null:
			primary = f.duplicate() as FontFile
		else:
			fallbacks.append(f)
	if primary == null:
		var sys: SystemFont = SystemFont.new()
		sys.font_names = _font_names_for(key)
		return sys
	primary.fallbacks = fallbacks
	return primary


func _font_names_for(role: String) -> PackedStringArray:
	match role:
		"shloka":
			return SHLOKA_FONT_NAMES
		"ui":
			return UI_FONT_NAMES
		_:
			push_warning("Locale: unknown font role '%s', using the ui font" % role)
			return UI_FONT_NAMES


func _load_translations() -> void:
	for code: String in SUPPORTED_LANGUAGES:
		if TranslationServer.get_translation_object(code) != null:
			continue
		var translation: Translation = load(TRANSLATION_PATH_FORMAT % code) as Translation
		if translation == null:
			push_error("Locale: missing translation for '%s'; run the project import" % code)
			continue
		TranslationServer.add_translation(translation)


func _read_saved_language() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_LANGUAGE
	var saved: String = str(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_LANGUAGE))
	if not SUPPORTED_LANGUAGES.has(saved):
		return DEFAULT_LANGUAGE
	return saved


func _save_language() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, _language)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Locale: could not save language (error %d)" % err)
