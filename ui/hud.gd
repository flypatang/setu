class_name Hud
extends Control
## In-game HUD (DESIGN §9, S17): day clock, bridge length against target, head stockpile counts,
## morale and the Nala / Nila advisor line. It reads a DayFlow through update_from() and never writes
## to the simulation. All text goes through tr() and is re-applied by refresh() and on a translation change.

const STOCK_KEYS: Dictionary = {
	"stone": "UI_HUD_STOCK_STONE",
	"inscribed_stone": "UI_HUD_STOCK_INSCRIBED",
	"timber": "UI_HUD_STOCK_TIMBER",
	"rope": "UI_HUD_STOCK_ROPE",
}
const ADVISOR_SPEAKER_KEYS: Dictionary = {"nala": "SPK_NALA", "nila": "SPK_NILA"}
const HEAD_PILE_ID: String = "head"
const MORALE_MAX: float = 100.0

var _flow: DayFlow = null
var _advisor_speaker: String = ""
var _advisor_key: String = ""

var _clock_label: Label = null
var _length_label: Label = null
var _stock_labels: Dictionary = {}
var _morale_label: Label = null
var _morale_bar: ProgressBar = null
var _advisor_name: Label = null
var _advisor_text: Label = null


func _init() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	_clock_label = _make_label(box)
	_length_label = _make_label(box)
	for kind: String in Stockpile.KINDS:
		_stock_labels[kind] = _make_label(box)
	_morale_label = _make_label(box)
	_morale_bar = ProgressBar.new()
	_morale_bar.min_value = 0.0
	_morale_bar.max_value = MORALE_MAX
	_morale_bar.show_percentage = false
	box.add_child(_morale_bar)
	_advisor_name = _make_label(box)
	_advisor_text = _make_label(box)
	_advisor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advisor_text.custom_minimum_size = Vector2(320.0, 0.0)


## Time left until sunset as "MM:SS", from the tick and the day length (20 ticks per second).
static func format_clock(tick: int, day_ticks: int) -> String:
	var seconds: int = floori(float(maxi(day_ticks - tick, 0)) / float(SimClock.TICK_RATE))
	var minutes: int = floori(float(seconds) / 60.0)
	return "%02d:%02d" % [minutes, seconds - minutes * 60]


## Reads the day's state (clock, length, head stockpile, morale) and shows it.
func update_from(flow: DayFlow) -> void:
	_flow = flow
	_render()


## Re-applies every string (used after a language change).
func refresh() -> void:
	_render()


## Shows an advisor line: speaker is "nala" or "nila"; text_key is a translation key.
func show_advisor(speaker: StringName, text_key: String) -> void:
	_advisor_speaker = str(speaker)
	_advisor_key = text_key
	_render_advisor()


func clock_text() -> String:
	return _clock_label.text


func length_text() -> String:
	return _length_label.text


## Head pile count line for a stockpile kind ("stone", "inscribed_stone", "timber" or "rope").
func stock_text(kind: String) -> String:
	if not _stock_labels.has(kind):
		return ""
	return (_stock_labels[kind] as Label).text


func morale_value() -> float:
	return _morale_bar.value


func advisor_speaker_text() -> String:
	return _advisor_name.text


func advisor_text() -> String:
	return _advisor_text.text


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_render()


func _render() -> void:
	if _flow != null and _flow.bridge != null:
		_clock_label.text = tr("UI_HUD_CLOCK") % [_flow.day, format_clock(_flow.tick(), _flow.day_ticks)]
		_length_label.text = tr("UI_HUD_LENGTH") % [_flow.bridge.length_m(), _flow.target_m]
		var head: Stockpile = _flow.pile(HEAD_PILE_ID)
		for kind: String in Stockpile.KINDS:
			var n: int = 0 if head == null else head.count(kind)
			(_stock_labels[kind] as Label).text = tr(str(STOCK_KEYS[kind])) % [n]
		var utsaha: float = _flow.morale.utsaha
		_morale_bar.value = utsaha
		_morale_label.text = tr("UI_HUD_MORALE") % [roundi(utsaha)]
	_render_advisor()


func _render_advisor() -> void:
	if _advisor_key == "":
		_advisor_name.text = ""
		_advisor_text.text = ""
		return
	var speaker_key: String = str(ADVISOR_SPEAKER_KEYS.get(_advisor_speaker, ""))
	_advisor_name.text = tr(speaker_key) if speaker_key != "" else _advisor_speaker
	_advisor_text.text = tr(_advisor_key)


func _make_label(parent: Node) -> Label:
	var label: Label = Label.new()
	parent.add_child(label)
	return label
