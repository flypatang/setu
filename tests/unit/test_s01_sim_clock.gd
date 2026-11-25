extends GdUnitTestSuite
## S01 acceptance tests for sim/sim_clock.gd (DESIGN §9). Headless and deterministic: no wall clock, no RNG.

const SimClockScript: GDScript = preload("res://sim/sim_clock.gd")


class Recorder extends RefCounted:
	var label: String = ""
	var log: Array[String] = []

	func _init(name_: String, shared_log: Array[String]) -> void:
		label = name_
		log = shared_log

	func step(tick: int) -> void:
		log.append("%s:%d" % [label, tick])


func _new_clock() -> SimClock:
	return SimClockScript.new() as SimClock


func test_one_second_at_speed_two_is_forty_ticks() -> void:
	var clock: SimClock = _new_clock()
	clock.speed = 2
	assert_int(clock.advance(1.0)).is_equal(40)


func test_one_second_at_speed_one_is_twenty_ticks() -> void:
	var clock: SimClock = _new_clock()
	clock.speed = 1
	assert_int(clock.advance(1.0)).is_equal(20)


func test_one_second_at_speed_three_is_sixty_ticks() -> void:
	var clock: SimClock = _new_clock()
	clock.speed = 3
	assert_int(clock.advance(1.0)).is_equal(60)


func test_frame_sized_steps_accumulate_to_the_same_count() -> void:
	var clock: SimClock = _new_clock()
	clock.speed = 2
	var total: int = 0
	for _i: int in range(60):
		total += clock.advance(1.0 / 60.0)
	assert_int(total).is_equal(40)


func test_paused_gives_zero_ticks() -> void:
	var clock: SimClock = _new_clock()
	clock.speed = 0
	assert_int(clock.advance(5.0)).is_equal(0)
	assert_int(clock.tick).is_equal(0)


func test_speed_is_clamped_to_zero_through_three() -> void:
	var clock: SimClock = _new_clock()
	clock.speed = 9
	assert_int(clock.speed).is_equal(3)
	clock.speed = -1
	assert_int(clock.speed).is_equal(0)


func test_registration_order_is_stable() -> void:
	var clock: SimClock = _new_clock()
	var log: Array[String] = []
	clock.register(Recorder.new("a", log))
	clock.register(Recorder.new("b", log))
	clock.step_all()
	clock.step_all()
	assert_array(log).is_equal(["a:0", "b:0", "a:1", "b:1"])


func test_step_all_advances_tick_once_per_call() -> void:
	var clock: SimClock = _new_clock()
	var log: Array[String] = []
	clock.register(Recorder.new("a", log))
	clock.step_all()
	clock.step_all()
	clock.step_all()
	assert_int(clock.tick).is_equal(3)


func test_snapshot_round_trips() -> void:
	var clock: SimClock = _new_clock()
	var log: Array[String] = []
	clock.register(Recorder.new("a", log))
	clock.speed = 2
	clock.advance(0.123)
	clock.step_all()
	clock.step_all()

	var snap: Dictionary = clock.snapshot()
	var restored: SimClock = _new_clock()
	restored.restore(snap)

	assert_int(restored.tick).is_equal(clock.tick)
	assert_int(restored.speed).is_equal(clock.speed)
	assert_int(restored.advance(0.7)).is_equal(clock.advance(0.7))
