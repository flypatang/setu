extends GdUnitTestSuite
## Proves the test pipeline itself works. Every module adds its own suite next to this one.


func test_main_scene_loads() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	assert_object(scene).is_not_null()


func test_physics_tick_is_fixed_at_60() -> void:
	assert_int(Engine.physics_ticks_per_second).is_equal(60)
