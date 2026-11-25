class_name Bridge
extends RefCounted
## The bridge: an array of sections along the guide line (DESIGN §9, S07).
## Pure simulation logic: no _process, no RNG, no wall-clock time.

signal section_completed(index: int)
signal stone_sank(count: int)
signal section_broken(index: int)

const STONE_PER_SECTION: int = 4
const TIMBER_PER_SECTION: int = 3
const ROPE_PER_SECTION: int = 1
const ALIGN_TOLERANCE_DEG: float = 2.0
const ALIGN_BONUS: float = 1.2
const BREAK_FOUNDATION: float = 0.25
const DAMAGE_PER_HIT: float = 0.1
const DEFAULT_SECTIONS: int = 1000


class Section extends RefCounted:
	var index: int = 0
	var foundation: float = 0.0
	var deck: float = 0.0
	var alignment_deg: float = 0.0
	var sturdiness: float = 0.0
	var blessed: bool = false
	var broken: bool = false
	var complete: bool = false
	var stone_in: int = 0
	var timber_in: int = 0
	var rope_in: int = 0

	func to_dict() -> Dictionary:
		return {
			"index": index, "foundation": foundation, "deck": deck,
			"alignment_deg": alignment_deg, "sturdiness": sturdiness,
			"blessed": blessed, "broken": broken, "complete": complete,
			"stone_in": stone_in, "timber_in": timber_in, "rope_in": rope_in,
		}

	func from_dict(d: Dictionary) -> void:
		index = d["index"] as int
		foundation = d["foundation"] as float
		deck = d["deck"] as float
		alignment_deg = d["alignment_deg"] as float
		sturdiness = d["sturdiness"] as float
		blessed = d["blessed"] as bool
		broken = d["broken"] as bool
		complete = d["complete"] as bool
		stone_in = d["stone_in"] as int
		timber_in = d["timber_in"] as int
		rope_in = d["rope_in"] as int


var _head: Stockpile
var _sections: Array[Section] = []
var _alignment_deg: float = 0.0
var _wasted_stone: int = 0


func _init(head: Stockpile, section_count: int = DEFAULT_SECTIONS) -> void:
	_head = head
	for i: int in maxi(section_count, 0):
		var s: Section = Section.new()
		s.index = i
		_sections.append(s)


func section_count() -> int:
	return _sections.size()


func section(index: int) -> Section:
	return _sections[index]


func wasted_stone() -> int:
	return _wasted_stone


## Current measuring-line deviation (degrees) applied to the section being built.
func set_alignment(deg: float) -> void:
	_alignment_deg = deg


## Number of complete (not broken) sections.
func length_m() -> int:
	var n: int = 0
	for s: Section in _sections:
		if s.complete and not s.broken:
			n += 1
	return n


func _next_unfinished() -> Section:
	for s: Section in _sections:
		if not s.complete:
			return s
	return null


func _compute_sturdiness(s: Section) -> float:
	var v: float = s.foundation * 0.6 + s.deck * 0.4
	if absf(s.alignment_deg) <= ALIGN_TOLERANCE_DEG:
		v *= ALIGN_BONUS
	return v


## Consumes materials for the next unfinished section; uninscribed stone sinks.
func step(_tick: int) -> void:
	var loose: int = _head.take("stone", _head.count("stone"))
	if loose > 0:
		_wasted_stone += loose
		stone_sank.emit(loose)
	var s: Section = _next_unfinished()
	if s == null:
		return
	var took: int = 0
	if s.stone_in < STONE_PER_SECTION:
		var n: int = _head.take("inscribed_stone", STONE_PER_SECTION - s.stone_in)
		s.stone_in += n
		took += n
	if s.timber_in < TIMBER_PER_SECTION:
		var n: int = _head.take("timber", TIMBER_PER_SECTION - s.timber_in)
		s.timber_in += n
		took += n
	if s.rope_in < ROPE_PER_SECTION:
		var n: int = _head.take("rope", ROPE_PER_SECTION - s.rope_in)
		s.rope_in += n
		took += n
	if took == 0:
		return
	s.foundation = float(s.stone_in) / float(STONE_PER_SECTION)
	s.deck = minf(float(s.timber_in) / float(TIMBER_PER_SECTION), float(s.rope_in) / float(ROPE_PER_SECTION))
	if s.stone_in >= STONE_PER_SECTION and s.timber_in >= TIMBER_PER_SECTION and s.rope_in >= ROPE_PER_SECTION:
		s.complete = true
		s.broken = false
		s.alignment_deg = _alignment_deg
		s.sturdiness = _compute_sturdiness(s)
		section_completed.emit(s.index)


## Damages unblessed built sections weaker than the current; breaks them when the foundation fails.
func apply_current(force: float) -> void:
	for s: Section in _sections:
		if not s.complete or s.blessed or s.sturdiness >= force:
			continue
		s.foundation = maxf(s.foundation - DAMAGE_PER_HIT, 0.0)
		s.sturdiness = _compute_sturdiness(s)
		if s.foundation < BREAK_FOUNDATION:
			s.foundation = 0.0
			s.deck = 0.0
			s.sturdiness = 0.0
			s.stone_in = 0
			s.timber_in = 0
			s.rope_in = 0
			s.complete = false
			s.broken = true
			section_broken.emit(s.index)


## Day's end: every complete section is blessed and immune from then on.
func bless_all_complete() -> void:
	for s: Section in _sections:
		if s.complete and not s.broken:
			s.blessed = true


func snapshot() -> Dictionary:
	var arr: Array = []
	for s: Section in _sections:
		arr.append(s.to_dict())
	return {"sections": arr, "alignment_deg": _alignment_deg, "wasted_stone": _wasted_stone}


func restore(data: Dictionary) -> void:
	_sections.clear()
	for d: Variant in data["sections"] as Array:
		var s: Section = Section.new()
		s.from_dict(d as Dictionary)
		_sections.append(s)
	_alignment_deg = data["alignment_deg"] as float
	_wasted_stone = data["wasted_stone"] as int
