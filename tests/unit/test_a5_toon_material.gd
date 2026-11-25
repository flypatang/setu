extends GdUnitTestSuite


func test_material_is_shader_material() -> void:
	var material: ShaderMaterial = MeshKit.flat_material()
	assert_object(material).is_not_null()
	assert_object(material.shader).is_not_null()


func test_material_is_cached() -> void:
	assert_bool(MeshKit.flat_material() == MeshKit.flat_material()).is_true()


func test_shader_has_vertex_colour_rim_and_ramp() -> void:
	var code: String = MeshKit.flat_material().shader.code
	assert_bool(code.contains("ALBEDO")).is_true()
	assert_bool(code.contains("COLOR")).is_true()
	assert_bool(code.contains("light()")).is_true()
	assert_bool(code.contains("0.35")).is_true()
	assert_bool(code.contains("step(")).is_true()


func test_shader_is_spatial() -> void:
	assert_bool(MeshKit.flat_material().shader.code.begins_with("shader_type spatial;")).is_true()
