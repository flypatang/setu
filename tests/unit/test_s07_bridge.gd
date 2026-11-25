extends GdUnitTestSuite
# Acceptance tests for S07 sim/bridge.gd (DESIGN §9, S07).

const BRIDGE_PATH: String = "res://sim/bridge.gd"

var _sank: int = 0
var _completed: Array[int] = []
var _broken: Array[int] = []


func _make(stock: Stockpile, sections: int = 5) -> Bridge:
	var script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = script.new(stock, sections) as Bridge
	_sank = 0
	_completed.clear()
	_broken.clear()
	b.stone_sank.connect(func(n: int) -> void: _sank += n)
	b.section_completed.connect(func(i: int) -> void: _completed.append(i))
	b.section_broken.connect(func(i: int) -> void: _broken.append(i))
	return b


func _feed(stock: Stockpile, sections: int) -> void:
	stock.add("inscribed_stone", 4 * sections)
	stock.add("timber", 3 * sections)
	stock.add("rope", sections)


func _build(b: Bridge, n: int) -> void:
	for t: int in n:
		b.step(t)


func test_material_costs() -> void:
	var sp: Stockpile = Stockpile.new()
	_feed(sp, 1)
	sp.add("inscribed_stone", 2)
	sp.add("timber", 1)
	sp.add("rope", 1)
	var b: Bridge = _make(sp, 1)
	_build(b, 20)
	assert_int(b.length_m()).is_equal(1)
	assert_int(sp.count("inscribed_stone")).is_equal(2)
	assert_int(sp.count("timber")).is_equal(1)
	assert_int(sp.count("rope")).is_equal(1)
	assert_array(_completed).is_equal([0])


func test_only_inscribed_stone_builds_foundation() -> void:
	var sp: Stockpile = Stockpile.new()
	sp.add("stone", 10)
	sp.add("timber", 3)
	sp.add("rope", 1)
	var b: Bridge = _make(sp)
	_build(b, 10)
	assert_int(b.length_m()).is_equal(0)
	assert_float(b.section(0).foundation).is_equal_approx(0.0, 0.0001)
	assert_int(_sank).is_equal(10)
	assert_int(b.wasted_stone()).is_equal(10)
	assert_int(sp.count("stone")).is_equal(0)


func test_alignment_bonus() -> void:
	var sp: Stockpile = Stockpile.new()
	_feed(sp, 2)
	var b: Bridge = _make(sp)
	b.set_alignment(1.5)
	b.step(0)
	b.set_alignment(5.0)
	b.step(1)
	assert_int(b.length_m()).is_equal(2)
	assert_float(b.section(0).sturdiness).is_equal_approx(1.2, 0.0001)
	assert_float(b.section(1).sturdiness).is_equal_approx(1.0, 0.0001)


func test_blessed_never_break() -> void:
	var sp: Stockpile = Stockpile.new()
	_feed(sp, 2)
	var b: Bridge = _make(sp)
	b.set_alignment(10.0)
	_build(b, 10)
	b.bless_all_complete()
	assert_bool(b.section(0).blessed).is_true()
	for i: int in 50:
		b.apply_current(5.0)
	assert_bool(b.section(0).broken).is_false()
	assert_int(b.length_m()).is_equal(2)
	assert_array(_broken).is_empty()


func test_unblessed_breaks_and_must_be_rebuilt() -> void:
	var sp: Stockpile = Stockpile.new()
	_feed(sp, 1)
	var b: Bridge = _make(sp)
	b.set_alignment(10.0)
	_build(b, 10)
	assert_int(b.length_m()).is_equal(1)
	for i: int in 20:
		b.apply_current(5.0)
	assert_bool(b.section(0).broken).is_true()
	assert_array(_broken).is_equal([0])
	assert_int(b.length_m()).is_equal(0)
	_feed(sp, 1)
	b.set_alignment(0.0)
	_build(b, 10)
	assert_bool(b.section(0).broken).is_false()
	assert_int(b.length_m()).is_equal(1)
	assert_array(_completed).is_equal([0, 0])


func test_strong_section_not_damaged() -> void:
	var sp: Stockpile = Stockpile.new()
	_feed(sp, 1)
	var b: Bridge = _make(sp)
	b.set_alignment(0.0)
	_build(b, 10)
	b.apply_current(0.5)
	assert_float(b.section(0).foundation).is_equal_approx(1.0, 0.0001)


func test_snapshot_restore_roundtrip() -> void:
	var sp: Stockpile = Stockpile.new()
	_feed(sp, 3)
	var b: Bridge = _make(sp)
	_build(b, 10)
	b.bless_all_complete()
	var snap: Dictionary = b.snapshot()
	var b2: Bridge = _make(Stockpile.new())
	b2.restore(snap)
	assert_int(b2.length_m()).is_equal(b.length_m())
	assert_bool(b2.section(0).blessed).is_true()
	assert_dict(b2.snapshot()).is_equal(snap)
