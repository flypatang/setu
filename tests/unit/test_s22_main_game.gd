extends GdUnitTestSuite
## S22: the playable game flow (title, prologue, days, summary, vignette, finale).

const FRAME: float = 1.0


func _make() -> MainGame:
	var g: MainGame = MainGame.new()
	g.persist = false
	g.dialogue_enabled = false
	g.game_state = auto_free((load("res://core/game_state.gd") as GDScript).new() as Node) as Node
	add_child(g)
	auto_free(g)
	return g


## Plays the current day to the summary with the bot plan of that day.
func _play_day(g: MainGame, n: int) -> void:
	g.flow().queue_commands(BotDays.load_plan(n))
	g.set_speed(3)
	var guard: int = 0
	while g.phase() == MainGame.Phase.DAY and guard < 400:
		g.tick_frame(FRAME)
		guard += 1


func test_starts_on_title() -> void:
	var g: MainGame = _make()
	assert_int(g.phase()).is_equal(MainGame.Phase.TITLE)


func test_new_game_enters_prologue_then_day_one() -> void:
	var g: MainGame = _make()
	g.start_new_game()
	assert_int(g.phase()).is_equal(MainGame.Phase.PROLOGUE)
	g.prologue_assign_scribes()
	var guard: int = 0
	while g.phase() == MainGame.Phase.PROLOGUE and guard < 50:
		g.tick_frame(FRAME)
		guard += 1
	assert_int(g.phase()).is_equal(MainGame.Phase.DAY)
	assert_int(g.flow().day).is_equal(1)
	assert_int(g.flow().target_m).is_equal(140)


func test_day_one_bot_carries_into_day_two() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	_play_day(g, 1)
	assert_int(g.phase()).is_equal(MainGame.Phase.SUMMARY)
	var built: int = g.flow().bridge.length_m()
	var carry: int = g.flow().carry_over()
	assert_int(built).is_greater(0)
	g.continue_from_summary()
	assert_int(g.phase()).is_equal(MainGame.Phase.DAY)
	assert_int(g.flow().day).is_equal(2)
	assert_int(g.flow().target_m).is_equal(200 + carry)
	assert_int(g.flow().tick()).is_equal(0)
	assert_int(g.cumulative_m()).is_equal(built)


func test_cumulative_origin_offset_is_applied() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	assert_float(g.origin_x()).is_equal_approx(0.0, 0.001)
	_play_day(g, 1)
	var built: int = g.flow().bridge.length_m()
	g.continue_from_summary()
	assert_float(g.origin_x()).is_equal_approx(float(built), 0.001)
	assert_object(g.bridge_view()).is_not_null()
	assert_int(g.past_view_count()).is_equal(1)
	# The finished day-1 bridge stays visible, at origin 0.
	var first: Node3D = g.past_view(0).get_section_root(0)
	assert_object(first).is_not_null()
	assert_float(first.position.x).is_equal_approx(0.0, 0.001)


func test_progress_is_saved_at_day_end() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	_play_day(g, 1)
	assert_int(g.saved_day_reached()).is_equal(2)
	assert_int(g.saved_cumulative_m()).is_equal(g.flow().bridge.length_m())


func test_continue_resumes_saved_progress() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	_play_day(g, 1)
	var built: int = g.flow().bridge.length_m()
	var carry: int = g.flow().carry_over()
	var h: MainGame = MainGame.new()
	h.persist = false
	h.dialogue_enabled = false
	h.game_state = g.game_state
	add_child(h)
	auto_free(h)
	assert_bool(h.can_continue()).is_true()
	h.continue_game()
	assert_int(h.phase()).is_equal(MainGame.Phase.DAY)
	assert_int(h.flow().day).is_equal(2)
	assert_int(h.cumulative_m()).is_equal(built)
	assert_int(h.flow().target_m).is_equal(200 + carry)
	assert_float(h.origin_x()).is_equal_approx(float(built), 0.001)


func test_pause_stops_ticks() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	g.set_speed(2)
	g.tick_frame(1.0)
	var t: int = g.flow().tick()
	assert_int(t).is_equal(40)
	g.open_pause()
	assert_int(g.tick_frame(1.0)).is_equal(0)
	assert_int(g.flow().tick()).is_equal(t)
	g.close_pause()
	g.tick_frame(1.0)
	assert_int(g.flow().tick()).is_equal(t + 40)
	g.set_speed(0)
	assert_int(g.tick_frame(1.0)).is_equal(0)
	assert_int(g.flow().tick()).is_equal(t + 40)


func test_time_of_day_follows_tick() -> void:
	var g: MainGame = _make()
	g.begin_day(1)
	g.set_speed(3)
	g.tick_frame(80.0)
	assert_float(g.time_of_day()).is_equal_approx(float(g.flow().tick()) / float(g.flow().day_ticks), 0.001)


func test_event_dialogue_plays_and_blocks_the_sim() -> void:
	var g: MainGame = _make()
	g.dialogue_enabled = true
	g.begin_day(1)
	g.set_speed(1)
	g.tick_frame(0.2)
	assert_bool(g.dialogue_box().is_playing()).is_true()
	var t: int = g.flow().tick()
	g.tick_frame(1.0)
	assert_int(g.flow().tick()).is_equal(t)


func test_day_two_ends_with_the_squirrel_vignette() -> void:
	var g: MainGame = _make()
	g.begin_day(2)
	_play_day(g, 2)
	assert_int(g.phase()).is_equal(MainGame.Phase.SUMMARY)
	g.dialogue_enabled = true
	g.continue_from_summary()
	assert_int(g.phase()).is_equal(MainGame.Phase.VIGNETTE)
	assert_bool(g.dialogue_box().is_playing()).is_true()


func test_finale_credits_then_title() -> void:
	var g: MainGame = _make()
	g.begin_day(5)
	_play_day(g, 5)
	assert_int(g.phase()).is_equal(MainGame.Phase.SUMMARY)
	g.continue_from_summary()
	assert_int(g.phase()).is_equal(MainGame.Phase.CREDITS)
	g.finish_credits()
	assert_int(g.phase()).is_equal(MainGame.Phase.TITLE)
	assert_bool(g.can_continue()).is_false()
