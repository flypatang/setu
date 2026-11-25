extends GdUnitTestSuite
## S04 acceptance: StateHash.hash_state is canonical (DESIGN §9 S04).


func test_key_order_does_not_matter() -> void:
	var a: Dictionary = {"stone": 10, "rope": 3, "morale": 0.5}
	var b: Dictionary = {"morale": 0.5, "rope": 3, "stone": 10}
	assert_str(StateHash.hash_state(a)).is_equal(StateHash.hash_state(b))


func test_nested_key_order_does_not_matter() -> void:
	var a: Dictionary = {"stock": {"stone": 1, "timber": 2}, "tick": 5}
	var b: Dictionary = {"tick": 5, "stock": {"timber": 2, "stone": 1}}
	assert_str(StateHash.hash_state(a)).is_equal(StateHash.hash_state(b))


func test_float_noise_below_tolerance_does_not_matter() -> void:
	var a: Dictionary = {"x": 0.3}
	var b: Dictionary = {"x": 0.1 + 0.2}
	assert_str(StateHash.hash_state(a)).is_equal(StateHash.hash_state(b))


func test_float_difference_above_tolerance_changes_hash() -> void:
	var a: Dictionary = {"x": 0.3}
	var b: Dictionary = {"x": 0.31}
	assert_str(StateHash.hash_state(a)).is_not_equal(StateHash.hash_state(b))


func test_array_order_matters() -> void:
	var a: Dictionary = {"queue": [1, 2, 3]}
	var b: Dictionary = {"queue": [3, 2, 1]}
	assert_str(StateHash.hash_state(a)).is_not_equal(StateHash.hash_state(b))


func test_different_values_give_different_hashes() -> void:
	var a: Dictionary = {"tick": 100}
	var b: Dictionary = {"tick": 101}
	assert_str(StateHash.hash_state(a)).is_not_equal(StateHash.hash_state(b))


func test_bool_int_and_string_are_distinct() -> void:
	var h_bool: String = StateHash.hash_state({"v": true})
	var h_int: String = StateHash.hash_state({"v": 1})
	var h_str: String = StateHash.hash_state({"v": "1"})
	assert_str(h_bool).is_not_equal(h_int)
	assert_str(h_int).is_not_equal(h_str)
	assert_str(h_bool).is_not_equal(h_str)


func test_hash_is_64_char_lowercase_hex() -> void:
	var h: String = StateHash.hash_state({"tick": 0})
	assert_int(h.length()).is_equal(64)
	assert_bool(h == h.to_lower()).is_true()
	for i: int in range(h.length()):
		var c: String = h.substr(i, 1)
		assert_bool("0123456789abcdef".contains(c)).is_true()


func test_same_input_gives_same_hash() -> void:
	var d: Dictionary = {"a": [1, 2.5, "x", false], "b": {"c": 3}}
	assert_str(StateHash.hash_state(d)).is_equal(StateHash.hash_state(d.duplicate(true)))


func test_empty_dictionary_has_stable_hash() -> void:
	assert_str(StateHash.hash_state({})).is_equal(StateHash.hash_state({}))
	assert_int(StateHash.hash_state({}).length()).is_equal(64)
