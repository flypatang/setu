extends GdUnitTestSuite

const SimRngScript: GDScript = preload("res://sim/sim_rng.gd")


func _make(seed_value: int) -> SimRng:
	return SimRngScript.new(seed_value) as SimRng


func test_same_seed_gives_same_sequence() -> void:
	var a: SimRng = _make(12345)
	var b: SimRng = _make(12345)
	for i: int in range(200):
		assert_int(a.next_u64()).is_equal(b.next_u64())


func test_different_seeds_give_different_sequences() -> void:
	var a: SimRng = _make(1)
	var b: SimRng = _make(2)
	var same: int = 0
	for i: int in range(100):
		if a.next_u64() == b.next_u64():
			same += 1
	assert_int(same).is_less(3)


func test_seed_zero_is_remapped_and_not_stuck() -> void:
	var a: SimRng = _make(0)
	var b: SimRng = _make(0)
	var nonzero: int = 0
	for i: int in range(100):
		var v: int = a.next_u64()
		assert_int(v).is_equal(b.next_u64())
		if v != 0:
			nonzero += 1
	assert_int(nonzero).is_equal(100)


func test_next_float_in_unit_interval() -> void:
	var rng: SimRng = _make(777)
	var sum: float = 0.0
	for i: int in range(5000):
		var f: float = rng.next_float()
		assert_bool(f >= 0.0 and f < 1.0).is_true()
		sum += f
	var mean: float = sum / 5000.0
	assert_float(mean).is_equal_approx(0.5, 0.03)


func test_range_i_stays_within_inclusive_bounds_and_hits_both_ends() -> void:
	var rng: SimRng = _make(99)
	var saw_low: bool = false
	var saw_high: bool = false
	for i: int in range(2000):
		var v: int = rng.range_i(3, 7)
		assert_bool(v >= 3 and v <= 7).is_true()
		if v == 3:
			saw_low = true
		if v == 7:
			saw_high = true
	assert_bool(saw_low).is_true()
	assert_bool(saw_high).is_true()


func test_range_i_single_value() -> void:
	var rng: SimRng = _make(5)
	for i: int in range(20):
		assert_int(rng.range_i(4, 4)).is_equal(4)


func test_fork_is_deterministic_for_same_label() -> void:
	var a: SimRng = _make(4242)
	var b: SimRng = _make(4242)
	var fa: SimRng = a.fork("crew")
	var fb: SimRng = b.fork("crew")
	for i: int in range(100):
		assert_int(fa.next_u64()).is_equal(fb.next_u64())


func test_fork_labels_give_independent_streams() -> void:
	var rng: SimRng = _make(4242)
	var fa: SimRng = rng.fork("crew")
	var fb: SimRng = rng.fork("hazard")
	var same: int = 0
	for i: int in range(100):
		if fa.next_u64() == fb.next_u64():
			same += 1
	assert_int(same).is_less(3)


func test_fork_does_not_change_parent_sequence() -> void:
	var with_fork: SimRng = _make(31337)
	var without_fork: SimRng = _make(31337)
	with_fork.fork("anything")
	for i: int in range(100):
		assert_int(with_fork.next_u64()).is_equal(without_fork.next_u64())
