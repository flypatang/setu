extends GdUnitTestSuite
## S12 acceptance: recording, replaying and hashing the command log (DESIGN §9 S12).

func _sample_log() -> PlayerCommands.CommandLog:
	var log: PlayerCommands.CommandLog = PlayerCommands.CommandLog.new()
	log.record(PlayerCommands.Command.new(0, &"place_measuring_line", {"deg": 0.0}))
	log.record(PlayerCommands.Command.new(20, &"draw_route", {
		"id": "r1", "from": "forest", "to": "head", "kind": "haul",
		"points": [[0.0, 0.0], [5.0, 0.0]], "haulers": 3,
	}))
	log.record(PlayerCommands.Command.new(20, &"assign_crews", {"role": "hauler", "site": "r1", "crews": 2}))
	log.record(PlayerCommands.Command.new(300, &"chant_jaya", {}))
	return log


func test_commands_at_returns_only_that_tick_in_record_order() -> void:
	var log: PlayerCommands.CommandLog = _sample_log()
	var at20: Array[PlayerCommands.Command] = log.commands_at(20)
	assert_int(at20.size()).is_equal(2)
	assert_str(String(at20[0].type)).is_equal("draw_route")
	assert_str(String(at20[1].type)).is_equal("assign_crews")
	assert_array(log.commands_at(5)).is_empty()


func test_json_round_trip_preserves_commands_and_hash() -> void:
	var log: PlayerCommands.CommandLog = _sample_log()
	var replayed: PlayerCommands.CommandLog = PlayerCommands.CommandLog.from_json(log.to_json())
	assert_int(replayed.count()).is_equal(4)
	assert_str(replayed.to_json()).is_equal(log.to_json())
	assert_str(replayed.state_hash()).is_equal(log.state_hash())


func test_recording_and_replaying_gives_same_state_hash() -> void:
	# The determinism gate: record a session, replay it from JSON, the hash must match.
	var recorded: PlayerCommands.CommandLog = _sample_log()
	var replay: PlayerCommands.CommandLog = PlayerCommands.CommandLog.from_json(recorded.to_json())
	assert_str(replay.state_hash()).is_equal(recorded.state_hash())
	assert_str(recorded.state_hash()).is_not_empty()


func test_different_command_gives_different_hash() -> void:
	var a: PlayerCommands.CommandLog = _sample_log()
	var b: PlayerCommands.CommandLog = _sample_log()
	b.record(PlayerCommands.Command.new(301, &"ring_gong", {"id": "g1"}))
	assert_str(a.state_hash()).is_not_equal(b.state_hash())


func test_hash_is_sensitive_to_tick() -> void:
	var a: PlayerCommands.CommandLog = PlayerCommands.CommandLog.new()
	a.record(PlayerCommands.Command.new(10, &"chant_jaya", {}))
	var b: PlayerCommands.CommandLog = PlayerCommands.CommandLog.new()
	b.record(PlayerCommands.Command.new(11, &"chant_jaya", {}))
	assert_str(a.state_hash()).is_not_equal(b.state_hash())


func test_from_json_on_garbage_gives_empty_log() -> void:
	var log: PlayerCommands.CommandLog = PlayerCommands.CommandLog.from_json("this is not json")
	assert_int(log.count()).is_equal(0)
	var not_array: PlayerCommands.CommandLog = PlayerCommands.CommandLog.from_json("{\"a\": 1}")
	assert_int(not_array.count()).is_equal(0)


func test_empty_log_serialises_to_empty_array() -> void:
	var log: PlayerCommands.CommandLog = PlayerCommands.CommandLog.new()
	assert_str(log.to_json()).is_equal("[]")
