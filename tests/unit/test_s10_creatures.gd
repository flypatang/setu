extends GdUnitTestSuite
# Acceptance tests for S10 sim/creatures.gd (DESIGN §9, Wave S1).
# Covers: building is blocked in an active zone, the gong maths, and zones expiring.

const CREATURES_PATH: String = "res://sim/creatures.gd"
const STOCKPILE_PATH: String = "res://sim/stockpile.gd"
const STATE_HASH_PATH: String = "res://sim/state_hash.gd"


func _make() -> Creatures:
	var script: GDScript = load(CREATURES_PATH) as GDScript
	var creatures: Creatures = script.new() as Creatures
	return creatures


func _make_stock(rope: int, timber: int) -> Stockpile:
	var script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = script.new() as Stockpile
	stock.add("rope", rope)
	stock.add("timber", timber)
	return stock


func test_building_blocked_while_zone_active() -> void:
	var c: Creatures = _make()
	c.add_zone(10.0, 20.0, 100)
	c.step(50)
	assert_bool(c.is_blocked_at(15.0)).is_true()
	assert_bool(c.is_blocked_at(25.0)).is_false()
	assert_bool(c.is_span_blocked(18.0, 22.0)).is_true()
	assert_bool(c.is_span_blocked(30.0, 40.0)).is_false()


func test_zone_range_is_half_open() -> void:
	var c: Creatures = _make()
	c.add_zone(10.0, 20.0, 100)
	c.step(0)
	assert_bool(c.is_blocked_at(10.0)).is_true()
	assert_bool(c.is_blocked_at(20.0)).is_false()
	# A span that only touches the far edge does not overlap the zone.
	assert_bool(c.is_span_blocked(20.0, 21.0)).is_false()


func test_zone_bounds_given_reversed_are_normalised() -> void:
	var c: Creatures = _make()
	c.add_zone(20.0, 10.0, 100)
	c.step(0)
	assert_bool(c.is_blocked_at(15.0)).is_true()


func test_zone_expires_at_active_until() -> void:
	var c: Creatures = _make()
	var zone_id: int = c.add_zone(0.0, 10.0, 100)
	c.step(99)
	assert_bool(c.is_zone_active(zone_id)).is_true()
	assert_bool(c.is_blocked_at(5.0)).is_true()
	c.step(100)
	assert_bool(c.is_zone_active(zone_id)).is_false()
	assert_bool(c.is_blocked_at(5.0)).is_false()
	assert_int(c.remaining_ticks(zone_id)).is_equal(0)


func test_gong_halves_remaining_active_time() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(100, 100)
	var zone_id: int = c.add_zone(0.0, 10.0, 200)
	c.step(100)
	assert_int(c.remaining_ticks(zone_id)).is_equal(100)
	assert_bool(c.build_gong(zone_id, stock)).is_true()
	assert_int(c.gong_count(zone_id)).is_equal(1)
	assert_int(c.remaining_ticks(zone_id)).is_equal(50)


func test_gong_costs_rope_and_timber() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(100, 100)
	var zone_id: int = c.add_zone(0.0, 10.0, 200)
	c.step(0)
	c.build_gong(zone_id, stock)
	assert_int(stock.count("rope")).is_equal(100 - Creatures.GONG_ROPE_COST)
	assert_int(stock.count("timber")).is_equal(100 - Creatures.GONG_TIMBER_COST)


func test_gong_refused_without_resources() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(Creatures.GONG_ROPE_COST - 1, 100)
	var zone_id: int = c.add_zone(0.0, 10.0, 200)
	c.step(0)
	assert_bool(c.build_gong(zone_id, stock)).is_false()
	assert_int(c.gong_count(zone_id)).is_equal(0)
	assert_int(c.remaining_ticks(zone_id)).is_equal(200)
	assert_int(stock.count("rope")).is_equal(Creatures.GONG_ROPE_COST - 1)
	assert_int(stock.count("timber")).is_equal(100)


func test_at_most_three_gongs_per_zone() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(1000, 1000)
	var zone_id: int = c.add_zone(0.0, 10.0, 200)
	c.step(100)
	assert_bool(c.build_gong(zone_id, stock)).is_true()
	assert_bool(c.build_gong(zone_id, stock)).is_true()
	assert_bool(c.build_gong(zone_id, stock)).is_true()
	# 100 -> 50 -> 25 -> 12 (integer halving)
	assert_int(c.remaining_ticks(zone_id)).is_equal(12)
	var rope_before: int = stock.count("rope")
	assert_bool(c.build_gong(zone_id, stock)).is_false()
	assert_int(c.gong_count(zone_id)).is_equal(Creatures.MAX_GONGS)
	assert_int(c.remaining_ticks(zone_id)).is_equal(12)
	assert_int(stock.count("rope")).is_equal(rope_before)


func test_gong_on_expired_zone_refused() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(100, 100)
	var zone_id: int = c.add_zone(0.0, 10.0, 100)
	c.step(100)
	assert_bool(c.build_gong(zone_id, stock)).is_false()
	assert_int(c.gong_count(zone_id)).is_equal(0)
	assert_int(stock.count("rope")).is_equal(100)


func test_gong_on_unknown_zone_refused() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(100, 100)
	assert_bool(c.build_gong(999, stock)).is_false()
	assert_int(stock.count("rope")).is_equal(100)


func test_gong_can_expire_a_zone_with_one_tick_left() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(100, 100)
	var zone_id: int = c.add_zone(0.0, 10.0, 101)
	c.step(100)
	assert_int(c.remaining_ticks(zone_id)).is_equal(1)
	assert_bool(c.build_gong(zone_id, stock)).is_true()
	assert_int(c.remaining_ticks(zone_id)).is_equal(0)
	assert_bool(c.is_blocked_at(5.0)).is_false()


func test_snapshot_restore_preserves_blocking_and_gongs() -> void:
	var c: Creatures = _make()
	var stock: Stockpile = _make_stock(100, 100)
	var zone_id: int = c.add_zone(0.0, 10.0, 300)
	c.add_zone(40.0, 60.0, 500)
	c.step(120)
	c.build_gong(zone_id, stock)
	var snap: Dictionary = c.snapshot()
	var restored: Creatures = _make()
	restored.restore(snap)
	assert_int(restored.gong_count(zone_id)).is_equal(1)
	assert_int(restored.remaining_ticks(zone_id)).is_equal(90)
	assert_bool(restored.is_blocked_at(5.0)).is_true()
	assert_bool(restored.is_blocked_at(50.0)).is_true()
	var hash_script: GDScript = load(STATE_HASH_PATH) as GDScript
	var original_hash: String = hash_script.call("hash_state", snap) as String
	var restored_hash: String = hash_script.call("hash_state", restored.snapshot()) as String
	assert_str(restored_hash).is_equal(original_hash)


func test_identical_operations_give_identical_hash() -> void:
	var hash_script: GDScript = load(STATE_HASH_PATH) as GDScript
	var hashes: Array[String] = []
	for run: int in 2:
		var c: Creatures = _make()
		var stock: Stockpile = _make_stock(100, 100)
		var zone_id: int = c.add_zone(0.0, 10.0, 400)
		c.add_zone(30.0, 35.0, 250)
		for t: int in 200:
			c.step(t)
		c.build_gong(zone_id, stock)
		hashes.append(hash_script.call("hash_state", c.snapshot()) as String)
	assert_str(hashes[1]).is_equal(hashes[0])


func test_makara_and_fish_zones_both_block() -> void:
	var c: Creatures = _make()
	var makara_id: int = c.add_zone(0.0, 10.0, 100, "makara")
	var fish_id: int = c.add_zone(20.0, 30.0, 50, "fish")
	c.step(10)
	assert_str(c.zone_kind(makara_id)).is_equal("makara")
	assert_str(c.zone_kind(fish_id)).is_equal("fish")
	assert_bool(c.is_blocked_at(5.0)).is_true()
	assert_bool(c.is_blocked_at(25.0)).is_true()
	assert_array(c.active_zone_ids()).has_size(2)
	c.step(50)
	assert_array(c.active_zone_ids()).contains_exactly([makara_id])
	assert_bool(c.is_blocked_at(25.0)).is_false()
	c.step(100)
	assert_array(c.active_zone_ids()).is_empty()


func test_unknown_kind_is_rejected() -> void:
	var c: Creatures = _make()
	assert_int(c.add_zone(0.0, 10.0, 100, "kraken")).is_equal(-1)
	c.step(0)
	assert_bool(c.is_blocked_at(5.0)).is_false()
