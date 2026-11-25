extends GdUnitTestSuite
# Acceptance tests for S02 sim/stockpile.gd (DESIGN §9, Wave S0).

const STOCKPILE_PATH: String = "res://sim/stockpile.gd"


func _make(default_capacity: int) -> Stockpile:
	var script: GDScript = load(STOCKPILE_PATH) as GDScript
	var sp: Stockpile = script.new(default_capacity) as Stockpile
	return sp


func test_add_within_capacity_increases_count() -> void:
	var sp: Stockpile = _make(100)
	var added: int = sp.add("stone", 40)
	assert_int(added).is_equal(40)
	assert_int(sp.count("stone")).is_equal(40)


func test_add_clamps_to_capacity() -> void:
	var sp: Stockpile = _make(100)
	sp.add("timber", 80)
	var added: int = sp.add("timber", 50)
	assert_int(added).is_equal(20)
	assert_int(sp.count("timber")).is_equal(100)
	assert_int(sp.capacity("timber")).is_equal(100)


func test_capacity_is_per_kind() -> void:
	var sp: Stockpile = _make(10)
	sp.set_capacity("rope", 3)
	assert_int(sp.add("rope", 50)).is_equal(3)
	assert_int(sp.add("stone", 50)).is_equal(10)


func test_take_is_partial_when_stock_is_short() -> void:
	var sp: Stockpile = _make(100)
	sp.add("inscribed_stone", 5)
	var taken: int = sp.take("inscribed_stone", 8)
	assert_int(taken).is_equal(5)
	assert_int(sp.count("inscribed_stone")).is_equal(0)


func test_take_full_amount_when_stock_suffices() -> void:
	var sp: Stockpile = _make(100)
	sp.add("rope", 10)
	assert_int(sp.take("rope", 4)).is_equal(4)
	assert_int(sp.count("rope")).is_equal(6)


func test_take_from_empty_returns_zero() -> void:
	var sp: Stockpile = _make(100)
	assert_int(sp.take("stone", 3)).is_equal(0)
	assert_int(sp.count("stone")).is_equal(0)


func test_unknown_kind_is_an_error_and_changes_nothing() -> void:
	var sp: Stockpile = _make(100)
	assert_bool(Stockpile.is_known_kind("gold")).is_false()
	assert_bool(Stockpile.is_known_kind("stone")).is_true()
	assert_int(sp.add("gold", 5)).is_equal(0)
	assert_int(sp.take("gold", 5)).is_equal(0)
	assert_int(sp.count("gold")).is_equal(0)
	assert_int(sp.capacity("gold")).is_equal(0)


func test_changed_signal_emits_kind_and_new_count() -> void:
	var sp: Stockpile = _make(100)
	var hits: Array[String] = []
	sp.changed.connect(func(kind: String, new_count: int) -> void:
		hits.append("%s:%d" % [kind, new_count]))
	sp.add("stone", 7)
	sp.take("stone", 2)
	assert_int(hits.size()).is_equal(2)
	assert_str(hits[0]).is_equal("stone:7")
	assert_str(hits[1]).is_equal("stone:5")


func test_no_signal_when_nothing_changes() -> void:
	var sp: Stockpile = _make(100)
	var hits: Array[int] = []
	sp.changed.connect(func(_kind: String, new_count: int) -> void:
		hits.append(new_count))
	sp.take("stone", 5)
	sp.add("stone", 0)
	assert_int(hits.size()).is_equal(0)

