extends GdUnitTestSuite
# Acceptance tests for S05 sim/routes.gd (DESIGN §9, Wave S1).

const ROUTES_PATH: String = "res://sim/routes.gd"


func _make(src: Stockpile, dst: Stockpile, length_m: float, n_haulers: int) -> Route:
	var script: GDScript = load(ROUTES_PATH) as GDScript
	var r: Route = script.new("r1", src, dst, "stone") as Route
	r.set_path(PackedVector2Array([Vector2(0, 0), Vector2(length_m, 0)]))
	r.haulers = n_haulers
	return r


func test_length_sums_segments() -> void:
	var r: Route = _make(Stockpile.new(), Stockpile.new(), 10.0, 1)
	r.set_path(PackedVector2Array([Vector2(0, 0), Vector2(3, 4), Vector2(3, 10)]))
	assert_float(r.length()).is_equal_approx(11.0, 0.0001)


func test_capacity_formula() -> void:
	var r: Route = _make(Stockpile.new(), Stockpile.new(), 20.0, 10)
	assert_float(r.capacity_per_tick()).is_equal_approx(10.0 * 1.2 / 20.0 / 20.0, 0.0001)


func test_doubling_haulers_doubles_throughput_below_crowd_cap() -> void:
	var a: Route = _make(Stockpile.new(), Stockpile.new(), 50.0, 5)
	var b: Route = _make(Stockpile.new(), Stockpile.new(), 50.0, 10)
	assert_float(b.capacity_per_tick()).is_equal_approx(a.capacity_per_tick() * 2.0, 0.00001)


func test_narrow_segment_halves_throughput() -> void:
	var a: Route = _make(Stockpile.new(), Stockpile.new(), 20.0, 8)
	var b: Route = _make(Stockpile.new(), Stockpile.new(), 20.0, 8)
	var flags: Array[bool] = [true]
	b.set_path(PackedVector2Array([Vector2(0, 0), Vector2(20, 0)]), flags)
	assert_float(b.capacity_per_tick()).is_equal_approx(a.capacity_per_tick() * 0.5, 0.00001)


func test_crowding_penalty_above_twelve_per_ten_metres() -> void:
	var ok: Route = _make(Stockpile.new(), Stockpile.new(), 10.0, 12)
	var crowded: Route = _make(Stockpile.new(), Stockpile.new(), 10.0, 24)
	assert_float(ok.crowding_factor()).is_equal_approx(1.0, 0.00001)
	assert_float(crowded.crowding_factor()).is_less(1.0)
	assert_float(crowded.capacity_per_tick()).is_less(ok.capacity_per_tick() * 2.0)


func test_conservation_source_loses_what_destination_gains() -> void:
	var src: Stockpile = Stockpile.new(1000)
	var dst: Stockpile = Stockpile.new(1000)
	src.add("stone", 500)
	var r: Route = _make(src, dst, 10.0, 100)
	var moved: int = 0
	for t: int in range(200):
		moved += r.step(t)
	assert_int(moved).is_greater(0)
	assert_int(src.count("stone")).is_equal(500 - moved)
	assert_int(dst.count("stone")).is_equal(moved)
	assert_int(src.count("stone") + dst.count("stone")).is_equal(500)


func test_full_destination_loses_nothing() -> void:
	var src: Stockpile = Stockpile.new(1000)
	var dst: Stockpile = Stockpile.new(1000)
	src.add("stone", 100)
	dst.set_capacity("stone", 3)
	var r: Route = _make(src, dst, 100.0, 100)
	for t: int in range(400):
		r.step(t)
	assert_int(dst.count("stone")).is_equal(3)
	assert_int(src.count("stone")).is_equal(97)


func test_fractional_accumulation_matches_rate() -> void:
	var src: Stockpile = Stockpile.new(10000)
	var dst: Stockpile = Stockpile.new(10000)
	src.add("stone", 10000)
	var r: Route = _make(src, dst, 24.0, 10) # 0.025 items/tick
	for t: int in range(400):
		r.step(t)
	assert_int(dst.count("stone")).is_equal(10)


func test_snapshot_restore_roundtrip() -> void:
	var src: Stockpile = Stockpile.new(1000)
	var dst: Stockpile = Stockpile.new(1000)
	src.add("stone", 100)
	var r: Route = _make(src, dst, 24.0, 7)
	for t: int in range(13):
		r.step(t)
	var snap: Dictionary = r.snapshot()
	var other: Route = _make(src, dst, 1.0, 1)
	other.restore(snap)
	assert_dict(other.snapshot()).is_equal(snap)
	assert_float(other.length()).is_equal_approx(r.length(), 0.0001)
