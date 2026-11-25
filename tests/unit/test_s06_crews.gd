extends GdUnitTestSuite
# Acceptance tests for S06 sim/crews.gd (DESIGN §4.2, §9 S06). Headless and deterministic.

const CREWS_PATH: String = "res://sim/crews.gd"
const STOCKPILE_PATH: String = "res://sim/stockpile.gd"


func _make_crews(total: int) -> Crews:
	var script: GDScript = load(CREWS_PATH) as GDScript
	var crews: Crews = script.new(total) as Crews
	return crews


func _make_pile(capacity: int) -> Stockpile:
	var script: GDScript = load(STOCKPILE_PATH) as GDScript
	var pile: Stockpile = script.new(capacity) as Stockpile
	return pile


func _run(crews: Crews, ticks: int) -> void:
	for t: int in range(ticks):
		crews.step(t)


# --- Assignment -----------------------------------------------------------

func test_free_crews_starts_at_total() -> void:
	var crews: Crews = _make_crews(5)
	assert_int(crews.free_crews()).is_equal(5)


func test_assign_reduces_free_crews() -> void:
	var crews: Crews = _make_crews(5)
	crews.register_site(&"quarry", _make_pile(100), &"cutter")
	assert_bool(crews.assign(&"cutter", &"quarry", 3)).is_true()
	assert_int(crews.free_crews()).is_equal(2)
	assert_int(crews.crews_at(&"quarry")).is_equal(3)


func test_cannot_assign_more_crews_than_free() -> void:
	var crews: Crews = _make_crews(2)
	crews.register_site(&"quarry", _make_pile(100), &"cutter")
	assert_bool(crews.assign(&"cutter", &"quarry", 3)).is_false()
	assert_int(crews.free_crews()).is_equal(2)
	assert_int(crews.crews_at(&"quarry")).is_equal(0)


func test_assign_rejects_unknown_site() -> void:
	var crews: Crews = _make_crews(4)
	assert_bool(crews.assign(&"cutter", &"nowhere", 1)).is_false()
	assert_int(crews.free_crews()).is_equal(4)


func test_assign_rejects_role_mismatch_with_site() -> void:
	var crews: Crews = _make_crews(4)
	crews.register_site(&"quarry", _make_pile(100), &"cutter")
	assert_bool(crews.assign(&"lumberjack", &"quarry", 1)).is_false()
	assert_int(crews.free_crews()).is_equal(4)


func test_assign_rejects_unknown_role_and_non_positive_counts() -> void:
	var crews: Crews = _make_crews(4)
	crews.register_site(&"quarry", _make_pile(100), &"cutter")
	assert_bool(crews.assign(&"piper", &"quarry", 1)).is_false()
	assert_bool(crews.assign(&"cutter", &"quarry", 0)).is_false()
	assert_bool(crews.assign(&"cutter", &"quarry", -2)).is_false()
	assert_int(crews.free_crews()).is_equal(4)


func test_unassign_returns_crews_to_free_pool() -> void:
	var crews: Crews = _make_crews(5)
	crews.register_site(&"quarry", _make_pile(100), &"cutter")
	crews.assign(&"cutter", &"quarry", 4)
	var removed: int = crews.unassign(&"cutter", &"quarry", 2)
	assert_int(removed).is_equal(2)
	assert_int(crews.crews_at(&"quarry")).is_equal(2)
	assert_int(crews.free_crews()).is_equal(3)


func test_unassign_clamps_to_assigned_count() -> void:
	var crews: Crews = _make_crews(5)
	crews.register_site(&"quarry", _make_pile(100), &"cutter")
	crews.assign(&"cutter", &"quarry", 2)
	var removed: int = crews.unassign(&"cutter", &"quarry", 10)
	assert_int(removed).is_equal(2)
	assert_int(crews.free_crews()).is_equal(5)


func test_register_site_rejects_duplicates_and_unknown_roles() -> void:
	var crews: Crews = _make_crews(1)
	assert_bool(crews.register_site(&"quarry", _make_pile(10), &"cutter")).is_true()
	assert_bool(crews.register_site(&"quarry", _make_pile(10), &"cutter")).is_false()
	assert_bool(crews.register_site(&"bad", _make_pile(10), &"piper")).is_false()


# --- Production rates -----------------------------------------------------

func test_cutter_produces_stone_at_rate() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 1)
	_run(crews, 100)
	assert_int(pile.count("stone")).is_equal(5)


func test_lumberjack_produces_timber_at_rate() -> void:
	var crews: Crews = _make_crews(2)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"forest", pile, &"lumberjack")
	crews.assign(&"lumberjack", &"forest", 2)
	_run(crews, 50)
	assert_int(pile.count("timber")).is_equal(8)


func test_lasher_converts_timber_to_rope() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	pile.add("timber", 100)
	crews.register_site(&"ropeworks", pile, &"lasher")
	crews.assign(&"lasher", &"ropeworks", 1)
	_run(crews, 100)
	assert_int(pile.count("rope")).is_equal(4)
	assert_int(pile.count("timber")).is_equal(96)


func test_lasher_stops_without_timber() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"ropeworks", pile, &"lasher")
	crews.assign(&"lasher", &"ropeworks", 1)
	_run(crews, 100)
	assert_int(pile.count("rope")).is_equal(0)
	assert_int(pile.count("timber")).is_equal(0)


func test_scribe_converts_stone_to_inscribed_stone() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	pile.add("stone", 50)
	crews.register_site(&"lekhan", pile, &"scribe")
	crews.assign(&"scribe", &"lekhan", 1)
	_run(crews, 100)
	assert_int(pile.count("inscribed_stone")).is_equal(6)
	assert_int(pile.count("stone")).is_equal(44)


func test_production_scales_linearly_with_crews() -> void:
	var one: Crews = _make_crews(1)
	var one_pile: Stockpile = _make_pile(1000)
	one.register_site(&"quarry", one_pile, &"cutter")
	one.assign(&"cutter", &"quarry", 1)
	_run(one, 100)

	var two: Crews = _make_crews(2)
	var two_pile: Stockpile = _make_pile(1000)
	two.register_site(&"quarry", two_pile, &"cutter")
	two.assign(&"cutter", &"quarry", 2)
	_run(two, 100)

	assert_int(two_pile.count("stone")).is_equal(one_pile.count("stone") * 2)


func test_unassigned_crews_produce_nothing() -> void:
	var crews: Crews = _make_crews(3)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	_run(crews, 200)
	assert_int(pile.count("stone")).is_equal(0)


# --- Morale ----------------------------------------------------------------

func test_float_morale_factor_scales_production() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 1)
	crews.set_morale_factor(0.5)
	_run(crews, 200)
	assert_int(pile.count("stone")).is_equal(5)


func test_callable_morale_factor_is_read_each_tick() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 1)
	var factor: Callable = func() -> float: return 0.5
	crews.set_morale_factor(factor)
	_run(crews, 200)
	assert_int(pile.count("stone")).is_equal(5)


func test_zero_morale_produces_nothing() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 1)
	crews.set_morale_factor(0.0)
	_run(crews, 500)
	assert_int(pile.count("stone")).is_equal(0)


func test_default_morale_factor_is_one() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 1)
	_run(crews, 100)
	assert_int(pile.count("stone")).is_equal(5)


# --- Conservation and capacity ---------------------------------------------

func test_scribe_conserves_stone_plus_inscribed() -> void:
	var crews: Crews = _make_crews(3)
	var pile: Stockpile = _make_pile(1000)
	pile.add("stone", 50)
	crews.register_site(&"lekhan", pile, &"scribe")
	crews.assign(&"scribe", &"lekhan", 3)
	_run(crews, 1000)
	assert_int(pile.count("stone") + pile.count("inscribed_stone")).is_equal(50)
	assert_int(pile.count("stone")).is_equal(0)


func test_lasher_conserves_timber_plus_rope() -> void:
	var crews: Crews = _make_crews(2)
	var pile: Stockpile = _make_pile(1000)
	pile.add("timber", 37)
	crews.register_site(&"ropeworks", pile, &"lasher")
	crews.assign(&"lasher", &"ropeworks", 2)
	_run(crews, 1000)
	assert_int(pile.count("timber") + pile.count("rope")).is_equal(37)


func test_production_respects_pile_capacity() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(3)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 1)
	_run(crews, 400)
	assert_int(pile.count("stone")).is_equal(3)


func test_scribe_does_not_destroy_stone_when_inscribed_is_full() -> void:
	var crews: Crews = _make_crews(1)
	var pile: Stockpile = _make_pile(2)
	pile.add("stone", 2)
	pile.add("inscribed_stone", 2)
	crews.register_site(&"lekhan", pile, &"scribe")
	crews.assign(&"scribe", &"lekhan", 1)
	_run(crews, 200)
	assert_int(pile.count("stone")).is_equal(2)
	assert_int(pile.count("inscribed_stone")).is_equal(2)


# --- Snapshot and determinism ----------------------------------------------

func test_snapshot_restore_resumes_identically() -> void:
	var crews: Crews = _make_crews(4)
	var pile: Stockpile = _make_pile(1000)
	crews.register_site(&"quarry", pile, &"cutter")
	crews.assign(&"cutter", &"quarry", 3)
	_run(crews, 37)
	var saved: Dictionary = crews.snapshot()
	var stone_at_save: int = pile.count("stone")

	var copy: Crews = _make_crews(4)
	var copy_pile: Stockpile = _make_pile(1000)
	copy_pile.add("stone", stone_at_save)
	copy.register_site(&"quarry", copy_pile, &"cutter")
	copy.restore(saved)
	assert_int(copy.free_crews()).is_equal(crews.free_crews())
	assert_int(copy.crews_at(&"quarry")).is_equal(3)

	_run(crews, 50)
	_run(copy, 50)
	assert_int(copy_pile.count("stone")).is_equal(pile.count("stone"))


func test_identical_runs_produce_identical_results() -> void:
	var first: Crews = _make_crews(3)
	var first_pile: Stockpile = _make_pile(1000)
	first_pile.add("timber", 20)
	first.register_site(&"ropeworks", first_pile, &"lasher")
	first.assign(&"lasher", &"ropeworks", 3)
	first.set_morale_factor(0.7)
	_run(first, 333)

	var second: Crews = _make_crews(3)
	var second_pile: Stockpile = _make_pile(1000)
	second_pile.add("timber", 20)
	second.register_site(&"ropeworks", second_pile, &"lasher")
	second.assign(&"lasher", &"ropeworks", 3)
	second.set_morale_factor(0.7)
	_run(second, 333)

	assert_int(second_pile.count("rope")).is_equal(first_pile.count("rope"))
	assert_int(second_pile.count("timber")).is_equal(first_pile.count("timber"))
