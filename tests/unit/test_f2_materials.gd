extends GdUnitTestSuite
## Acceptance tests for F2 (gen/materials.gd): the painterly material system of docs/ART.md "Materials".


const ALL_KINDS: Array[StringName] = [
	&"stone", &"cloth", &"fur", &"skin", &"gold", &"wood", &"foliage", &"water_edge", &"lacquer",
]


func _f(kind: StringName, uniform_name: StringName) -> float:
	var value: Variant = Materials.get_material(kind).get_shader_parameter(uniform_name)
	assert_bool(value is float).is_true()
	return value as float


func test_kinds_lists_the_nine_art_kinds() -> void:
	var kinds: Array[StringName] = Materials.kinds()
	assert_array(kinds).has_size(9)
	for kind: StringName in ALL_KINDS:
		assert_bool(kinds.has(kind)).is_true()
		assert_bool(Materials.has_kind(kind)).is_true()
	assert_bool(Materials.has_kind(&"plastic")).is_false()


func test_every_kind_returns_a_shader_material() -> void:
	for kind: StringName in ALL_KINDS:
		var material: ShaderMaterial = Materials.get_material(kind)
		assert_object(material).is_not_null()
		assert_object(material.shader).is_not_null()
		assert_bool(material.shader.code.begins_with("shader_type spatial;")).is_true()


func test_material_is_cached_per_kind() -> void:
	for kind: StringName in ALL_KINDS:
		assert_bool(Materials.get_material(kind) == Materials.get_material(kind)).is_true()


func test_kinds_are_distinct_materials() -> void:
	var seen: Array[ShaderMaterial] = []
	for kind: StringName in ALL_KINDS:
		var material: ShaderMaterial = Materials.get_material(kind)
		assert_bool(seen.has(material)).is_false()
		seen.append(material)


func test_opaque_kinds_share_one_shader_object() -> void:
	var stone: Shader = Materials.get_material(&"stone").shader
	for kind: StringName in [&"fur", &"skin", &"gold", &"wood", &"lacquer"]:
		assert_bool(Materials.get_material(kind).shader == stone).is_true()
	assert_bool(Materials.get_material(&"cloth").shader == Materials.get_material(&"foliage").shader).is_true()


func test_all_variants_come_from_one_shader_source() -> void:
	var source: String = Materials.shader_source()
	assert_bool(source.length() > 500).is_true()
	for kind: StringName in ALL_KINDS:
		var code: String = Materials.get_material(kind).shader.code
		assert_bool(code.contains("void light()")).is_true()
		assert_bool(code.contains("uniform float value_variation")).is_true()
		# The variants differ only in their render_mode line and the water alpha lines.
		assert_int(absi(code.length() - source.length())).is_less(400)


func test_shader_has_the_painterly_features() -> void:
	var code: String = Materials.shader_source()
	assert_bool(code.contains("noise_tex")).is_true()
	assert_bool(code.contains("triplanar")).is_true()
	assert_bool(code.contains("COLOR.a")).is_true()
	assert_bool(code.contains("wind_amount")).is_true()
	assert_bool(code.contains("shadow_tint")).is_true()
	assert_bool(code.contains("smoothstep")).is_true()
	assert_bool(code.contains("METALLIC")).is_true()
	assert_bool(code.contains("SPECULAR_LIGHT")).is_true()
	assert_bool(code.contains("sheen_strength")).is_true()
	assert_bool(code.contains("cavity_strength")).is_true()
	assert_bool(code.contains("edge_strength")).is_true()
	assert_bool(code.contains("wrap")).is_true()


func test_only_water_edge_is_transparent() -> void:
	assert_bool(Materials.get_material(&"water_edge").shader.code.contains("\tALPHA = ")).is_true()
	for kind: StringName in [&"stone", &"cloth", &"fur", &"skin", &"gold", &"wood", &"foliage", &"lacquer"]:
		assert_bool(Materials.get_material(kind).shader.code.contains("\tALPHA = ")).is_false()


func test_cloth_and_foliage_are_double_sided() -> void:
	assert_bool(Materials.get_material(&"cloth").shader.code.contains("cull_disabled")).is_true()
	assert_bool(Materials.get_material(&"foliage").shader.code.contains("cull_disabled")).is_true()
	assert_bool(Materials.get_material(&"stone").shader.code.contains("cull_disabled")).is_false()


func test_gold_is_metallic_with_bright_specular() -> void:
	assert_float(_f(&"gold", &"metallic")).is_greater(0.5)
	assert_float(_f(&"gold", &"spec_strength")).is_greater(_f(&"stone", &"spec_strength"))
	assert_float(_f(&"gold", &"spec_strength")).is_greater(1.0)
	for kind: StringName in [&"stone", &"cloth", &"fur", &"skin", &"wood", &"foliage"]:
		assert_float(_f(kind, &"metallic")).is_equal_approx(0.0, 0.0001)


func test_cloth_and_foliage_have_wind_and_wrap() -> void:
	for kind: StringName in [&"cloth", &"foliage"]:
		assert_float(_f(kind, &"wind_amount")).is_greater(0.0)
		assert_float(_f(kind, &"wrap")).is_greater(0.2)
		assert_float(_f(kind, &"transmission")).is_greater(0.0)
	for kind: StringName in [&"stone", &"gold", &"wood", &"lacquer", &"skin", &"fur", &"water_edge"]:
		assert_float(_f(kind, &"wind_amount")).is_equal_approx(0.0, 0.0001)


func test_stone_has_cavity_and_edge() -> void:
	assert_float(_f(&"stone", &"cavity_strength")).is_greater(0.0)
	assert_float(_f(&"stone", &"edge_strength")).is_greater(0.0)
	assert_float(_f(&"stone", &"cavity_strength")).is_greater(_f(&"cloth", &"cavity_strength"))


func test_fur_has_the_strongest_sheen() -> void:
	assert_float(_f(&"fur", &"sheen_strength")).is_greater(0.0)
	for kind: StringName in [&"stone", &"wood", &"gold", &"lacquer"]:
		assert_float(_f(&"fur", &"sheen_strength")).is_greater(_f(kind, &"sheen_strength"))


func test_value_variation_is_within_the_art_range() -> void:
	for kind: StringName in ALL_KINDS:
		var variation: float = _f(kind, &"value_variation")
		assert_float(variation).is_between(0.06, 0.12)
		assert_float(_f(kind, &"hue_variation")).is_greater(0.0)


func test_shadow_tint_is_indigo_shifted() -> void:
	for kind: StringName in ALL_KINDS:
		var tint: Color = Materials.get_material(kind).get_shader_parameter(&"shadow_tint") as Color
		assert_bool(tint.b > tint.r and tint.b > tint.g).is_true()
		assert_float(_f(kind, &"shadow_strength")).is_greater(0.0)


func test_noise_texture_is_shared_and_deterministic() -> void:
	var texture: Texture2D = Materials.noise_texture()
	assert_object(texture).is_not_null()
	assert_int(texture.get_width()).is_equal(Materials.NOISE_SIZE)
	assert_int(texture.get_height()).is_equal(Materials.NOISE_SIZE)
	for kind: StringName in ALL_KINDS:
		assert_bool(Materials.get_material(kind).get_shader_parameter(&"noise_tex") == texture).is_true()
	var a: Image = Materials.build_noise_image()
	var b: Image = Materials.build_noise_image()
	assert_bool(a.get_data() == b.get_data()).is_true()
	# Each channel carries real variation (not a constant).
	var first: Color = a.get_pixel(0, 0)
	var varied: Array[bool] = [false, false, false, false]
	for i: int in range(1, 64):
		var c: Color = a.get_pixel(i * 3, i * 2)
		var delta: Array[float] = [c.r - first.r, c.g - first.g, c.b - first.b, c.a - first.a]
		for ch: int in range(4):
			if absf(delta[ch]) > 0.05:
				varied[ch] = true
	assert_array(varied).contains_exactly([true, true, true, true])


func test_space_suffix_variants() -> void:
	var local_stone: ShaderMaterial = Materials.get_material(&"stone_local")
	var world_fur: ShaderMaterial = Materials.get_material(&"fur_world")
	assert_bool(local_stone != Materials.get_material(&"stone")).is_true()
	assert_bool(local_stone == Materials.get_material(&"stone_local")).is_true()
	assert_float(local_stone.get_shader_parameter(&"object_space") as float).is_equal_approx(1.0, 0.0001)
	assert_float(world_fur.get_shader_parameter(&"object_space") as float).is_equal_approx(0.0, 0.0001)
	# Kinds worn by moving characters default to object space so the noise does not swim.
	assert_float(_f(&"fur", &"object_space")).is_equal_approx(1.0, 0.0001)
	assert_float(_f(&"skin", &"object_space")).is_equal_approx(1.0, 0.0001)
	assert_float(_f(&"stone", &"object_space")).is_equal_approx(0.0, 0.0001)
	assert_str(String(Materials.base_kind(&"stone_local"))).is_equal("stone")
	assert_str(String(Materials.base_kind(&"water_edge"))).is_equal("water_edge")
	assert_bool(Materials.has_kind(&"water_edge_local")).is_true()


func test_unknown_kind_falls_back_to_lacquer() -> void:
	var material: ShaderMaterial = Materials.get_material(&"no_such_kind")
	assert_object(material).is_not_null()
	assert_bool(material == Materials.get_material(&"lacquer")).is_true()


func test_set_wind_updates_every_material() -> void:
	Materials.set_wind(Vector3(0.0, 0.0, 2.0), 0.5)
	for kind: StringName in ALL_KINDS:
		var material: ShaderMaterial = Materials.get_material(kind)
		var dir: Vector3 = material.get_shader_parameter(&"wind_direction") as Vector3
		assert_bool(dir.is_equal_approx(Vector3(0.0, 0.0, 1.0))).is_true()
		assert_float(material.get_shader_parameter(&"wind_strength") as float).is_equal_approx(0.5, 0.0001)
	Materials.set_wind(Vector3.ZERO, 1.0)
	var kept: Vector3 = Materials.get_material(&"cloth").get_shader_parameter(&"wind_direction") as Vector3
	assert_float(kept.length()).is_equal_approx(1.0, 0.001)
	Materials.set_wind(Materials.DEFAULT_WIND_DIRECTION, 1.0)


func test_set_shadow_tint_updates_every_material() -> void:
	Materials.set_shadow_tint(Color(0.2, 0.1, 0.9), 0.3)
	for kind: StringName in ALL_KINDS:
		var material: ShaderMaterial = Materials.get_material(kind)
		assert_bool((material.get_shader_parameter(&"shadow_tint") as Color).is_equal_approx(Color(0.2, 0.1, 0.9))).is_true()
		assert_float(material.get_shader_parameter(&"shadow_strength") as float).is_equal_approx(0.3, 0.0001)
	Materials.reset_shadow_tint()
	assert_float(_f(&"stone", &"shadow_strength")).is_equal_approx(Materials.DEFAULT_SHADOW_STRENGTH, 0.0001)


func test_set_exposure_updates_every_material() -> void:
	for kind: StringName in ALL_KINDS:
		assert_float(_f(kind, &"exposure")).is_equal_approx(1.0, 0.0001)
	Materials.set_exposure(0.5)
	for kind: StringName in ALL_KINDS:
		assert_float(_f(kind, &"exposure")).is_equal_approx(0.5, 0.0001)
	Materials.set_exposure(1.0)
	assert_float(_f(&"stone", &"exposure")).is_equal_approx(1.0, 0.0001)


func test_direct_light_matches_standard_material_brightness() -> void:
	# LIGHT_COLOR arrives multiplied by PI in light(); the shader must divide it out.
	assert_bool(Materials.shader_source().contains("exposure / PI")).is_true()
