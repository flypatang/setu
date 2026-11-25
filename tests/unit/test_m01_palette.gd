extends GdUnitTestSuite
## M01 acceptance: every §6.1 palette token exists as a Color and matches its hex value.

const Pal: GDScript = preload("res://core/palette.gd")


func _expect(value: Color, hex: String) -> void:
	assert_object(value).is_not_null()
	assert_bool(value.is_equal_approx(Color.html(hex))).is_true()


func test_saffron_matches_hex() -> void:
	_expect(Pal.SAFFRON, "#F28C28")


func test_sindoor_matches_hex() -> void:
	_expect(Pal.SINDOOR, "#D7263D")


func test_gold_matches_hex() -> void:
	_expect(Pal.GOLD, "#E9B949")


func test_hanuman_fur_matches_hex() -> void:
	_expect(Pal.HANUMAN_FUR, "#C98B3B")


func test_deep_ocean_matches_hex() -> void:
	_expect(Pal.DEEP_OCEAN, "#0E3B5C")


func test_night_indigo_matches_hex() -> void:
	_expect(Pal.NIGHT_INDIGO, "#1B1B3A")


func test_moon_matches_hex() -> void:
	_expect(Pal.MOON, "#DDE6F2")


func test_grove_green_matches_hex() -> void:
	_expect(Pal.GROVE_GREEN, "#2E7D4F")


func test_ashoka_red_matches_hex() -> void:
	_expect(Pal.ASHOKA_RED, "#E04E39")


func test_rakshasa_skin_matches_hex() -> void:
	_expect(Pal.RAKSHASA_SKIN, "#4B3F72")


func test_rakshasa_armor_matches_hex() -> void:
	_expect(Pal.RAKSHASA_ARMOR, "#7A1F2B")


func test_stone_matches_hex() -> void:
	_expect(Pal.STONE, "#B8A88A")


func test_fire_core_matches_hex() -> void:
	_expect(Pal.FIRE_CORE, "#FFD166")


func test_fire_edge_matches_hex() -> void:
	_expect(Pal.FIRE_EDGE, "#EF476F")


func test_ui_dark_matches_hex() -> void:
	_expect(Pal.UI_DARK, "#14110F")
