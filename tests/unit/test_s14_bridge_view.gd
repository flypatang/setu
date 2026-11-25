extends GdUnitTestSuite
# Acceptance tests for S14 render/bridge_view.gd (DESIGN §9, S14).
# Headless: the view reads a Bridge built on a Stockpile and never runs the simulation.

const BRIDGE_PATH: String = "res://sim/bridge.gd"
const VIEW_PATH: String = "res://render/bridge_view.gd"
const STOCKPILE_PATH: String = "res://sim/stockpile.gd"


func _make_view() -> BridgeView:
	var view_script: GDScript = load(VIEW_PATH) as GDScript
	var view: BridgeView = auto_free(view_script.new() as BridgeView)
	add_child(view)
	return view


func _make_stock() -> Stockpile:
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	return stock_script.new() as Stockpile


func _make_bridge(stock: Stockpile, sections: int) -> Bridge:
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	return bridge_script.new(stock, sections) as Bridge


func test_empty_bridge_builds_nothing() -> void:
	var view: BridgeView = _make_view()
	var b: Bridge = _make_bridge(_make_stock(), 5)
	view.sync(b)
	assert_object(view.get_section_root(0)).is_null()
	assert_int(view.get_rebuild_count()).is_equal(0)


func test_completed_section_has_expected_parts() -> void:
	# A complete section: 4 foundation stones, each with a glyph, 3 planks and 1 lashing = 12 parts.
	var view: BridgeView = _make_view()
	var stock: Stockpile = _make_stock()
	stock.add("inscribed_stone", 4)
	stock.add("timber", 3)
	stock.add("rope", 1)
	var b: Bridge = _make_bridge(stock, 5)
	b.step(0)
	assert_bool(b.section(0).complete).is_true()
	view.sync(b)
	assert_object(view.get_section_root(0)).is_not_null()
	assert_int(view.part_count(0)).is_equal(12)


func test_partial_section_shows_only_delivered_parts() -> void:
	# 2 inscribed stones (2 stones + 2 glyphs) and 1 plank, no lashing = 5 parts.
	var view: BridgeView = _make_view()
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 2)
	stock.add("timber", 1)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, 5) as Bridge
	b.step(0)
	assert_bool(b.section(0).complete).is_false()
	view.sync(b)
	assert_int(view.part_count(0)).is_equal(5)


func test_unchanged_sync_does_not_rebuild() -> void:
	var view: BridgeView = _make_view()
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 4)
	stock.add("timber", 3)
	stock.add("rope", 1)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, 5) as Bridge
	b.step(0)
	view.sync(b)
	var before: int = view.get_rebuild_count()
	view.sync(b)
	view.sync(b)
	assert_int(view.get_rebuild_count()).is_equal(before)


func test_changed_section_rebuilds_only_that_section() -> void:
	var view: BridgeView = _make_view()
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 4)
	stock.add("timber", 3)
	stock.add("rope", 1)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, 5) as Bridge
	b.step(0)
	view.sync(b)
	var before: int = view.get_rebuild_count()
	# Feed section 1 partially: only section 1 changes.
	stock.add("inscribed_stone", 1)
	b.step(1)
	view.sync(b)
	assert_int(view.get_rebuild_count()).is_equal(before + 1)


func test_broken_section_drifts_away() -> void:
	var view: BridgeView = _make_view()
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 4)
	stock.add("timber", 3)
	stock.add("rope", 1)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, 5) as Bridge
	b.step(0)
	view.sync(b)
	assert_object(view.get_section_root(0)).is_not_null()
	# Strong current breaks the unblessed section after enough hits.
	for i: int in 10:
		b.apply_current(5.0)
	assert_bool(b.section(0).broken).is_true()
	view.sync(b)
	assert_bool(view.is_drifting(0)).is_true()
	assert_object(view.get_section_root(0)).is_null()


func test_blessed_section_shimmers() -> void:
	var view: BridgeView = _make_view()
	var stock_script: GDScript = load(STOCKPILE_PATH) as GDScript
	var stock: Stockpile = stock_script.new() as Stockpile
	stock.add("inscribed_stone", 4)
	stock.add("timber", 3)
	stock.add("rope", 1)
	var bridge_script: GDScript = load(BRIDGE_PATH) as GDScript
	var b: Bridge = bridge_script.new(stock, 5) as Bridge
	b.step(0)
	view.sync(b)
	assert_bool(view.has_shimmer(0)).is_false()
	b.bless_all_complete()
	view.sync(b)
	assert_bool(view.has_shimmer(0)).is_true()
	assert_bool(view.has_shimmer(1)).is_false()
