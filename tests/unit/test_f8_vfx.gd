extends GdUnitTestSuite
## F8 acceptance: every Vfx factory returns a node, one-shot effects free themselves, looping ones expose stop().


func _one_shots() -> Array[Vfx.Effect]:
	var list: Array[Vfx.Effect] = [
		Vfx.hit_sparks(Vector3(1.0, 2.0, 3.0), 1.0),
		Vfx.dust_puff(Vector3.ZERO),
		Vfx.size_burst(Vector3.ZERO, true),
		Vfx.size_burst(Vector3.ZERO, false),
		Vfx.shockwave(Vector3.ZERO, 4.0),
		Vfx.dissolve_embers(Vector3.ZERO, Palette.RAKSHASA_SKIN),
		Vfx.sea_spray(Vector3.ZERO),
	]
	return list


func _loopers(attach: Node3D) -> Array[Vfx.Effect]:
	var area: AABB = AABB(Vector3(-4.0, 0.0, -4.0), Vector3(8.0, 3.0, 8.0))
	var list: Array[Vfx.Effect] = [
		Vfx.swing_trail(attach, 1.2, Palette.GOLD),
		Vfx.fire(1.0),
		Vfx.smarana_motes(attach),
		Vfx.fireflies(area),
		Vfx.petals(area, Palette.ASHOKA_RED),
	]
	return list


func _count_particles(node: Node) -> int:
	var n: int = 0
	for child: Node in node.get_children():
		if child is GPUParticles3D:
			n += 1
		n += _count_particles(child)
	return n


func test_one_shot_factories_return_nodes() -> void:
	for fx: Vfx.Effect in _one_shots():
		assert_object(fx).is_not_null()
		assert_bool(fx is Node3D).is_true()
		assert_bool(fx.looping).is_false()
		assert_bool(fx.lifetime > 0.0).is_true()
		assert_int(_count_particles(fx)).is_greater(0)
		fx.free()


func test_looping_factories_return_nodes_with_stop() -> void:
	var attach: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(attach)
	for fx: Vfx.Effect in _loopers(attach):
		assert_object(fx).is_not_null()
		assert_bool(fx.looping).is_true()
		assert_bool(fx.has_method("stop")).is_true()
		if fx.get_parent() == null:
			fx.free()
	# attached effects are children of attach and are freed with it


func test_positions_are_applied() -> void:
	var fx: Vfx.Effect = Vfx.hit_sparks(Vector3(1.0, 2.0, 3.0), 0.5)
	assert_vector(fx.position).is_equal(Vector3(1.0, 2.0, 3.0))
	fx.free()
	var area: AABB = AABB(Vector3(0.0, 0.0, 0.0), Vector3(10.0, 4.0, 6.0))
	var flies: Vfx.Effect = Vfx.fireflies(area)
	assert_vector(flies.position).is_equal(area.get_center())
	flies.free()


func test_one_shot_effects_free_themselves() -> void:
	for fx: Vfx.Effect in _one_shots():
		add_child(fx)
		fx.tick(fx.lifetime * 0.5)
		assert_bool(fx.is_queued_for_deletion()).is_false()
		fx.tick(fx.lifetime * 0.5 + 0.01)
		assert_bool(fx.is_queued_for_deletion()).is_true()


func test_one_shot_frees_in_running_tree() -> void:
	var fx: Vfx.Effect = Vfx.dust_puff(Vector3.ZERO)
	fx.lifetime = 0.05
	add_child(fx)
	await get_tree().create_timer(0.3).timeout
	assert_bool(is_instance_valid(fx)).is_false()


func test_looping_effects_persist_until_stopped() -> void:
	var attach: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(attach)
	for fx: Vfx.Effect in _loopers(attach):
		if fx.get_parent() == null:
			add_child(fx)
		fx.tick(60.0)
		assert_bool(fx.is_queued_for_deletion()).is_false()
		fx.stop()
		assert_bool(fx.is_stopping()).is_true()
		for child: Node in fx.get_children():
			if child is GPUParticles3D:
				assert_bool((child as GPUParticles3D).emitting).is_false()
		fx.tick(fx.fade_time + 0.01)
		assert_bool(fx.is_queued_for_deletion()).is_true()


func test_attached_effects_parent_to_attach() -> void:
	var attach: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(attach)
	var trail: Vfx.Effect = Vfx.swing_trail(attach, 1.0, Palette.GOLD)
	var motes: Vfx.Effect = Vfx.smarana_motes(attach)
	assert_object(trail.get_parent()).is_same(attach)
	assert_object(motes.get_parent()).is_same(attach)


func test_swing_trail_builds_ribbon_when_moving() -> void:
	var attach: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(attach)
	var trail: Vfx.Trail = Vfx.swing_trail(attach, 1.0, Palette.GOLD) as Vfx.Trail
	assert_object(trail).is_not_null()
	for i: int in 5:
		attach.position = Vector3(float(i) * 0.3, 0.0, 0.0)
		trail.tick(0.016)
	assert_int(trail.sample_count()).is_equal(5)
	assert_int(trail.ribbon_mesh().get_surface_count()).is_equal(1)
	# samples age out when the node stops being sampled
	trail.stop()
	trail.tick(trail.fade_time * 0.5)
	trail.tick(trail.fade_time * 0.5 + 0.01)
	assert_int(trail.sample_count()).is_equal(0)
	assert_bool(trail.is_queued_for_deletion()).is_true()


func test_fire_scales_with_size_and_has_light() -> void:
	var small: Vfx.Effect = Vfx.fire(0.5)
	var big: Vfx.Effect = Vfx.fire(3.0)
	assert_int(_count_particles(small)).is_equal(3)
	var small_amount: int = 0
	var big_amount: int = 0
	for child: Node in small.get_children():
		if child is GPUParticles3D:
			small_amount += (child as GPUParticles3D).amount
	for child: Node in big.get_children():
		if child is GPUParticles3D:
			big_amount += (child as GPUParticles3D).amount
	assert_int(big_amount).is_greater(small_amount)
	var lights: int = 0
	for child: Node in big.get_children():
		if child is OmniLight3D:
			lights += 1
	assert_int(lights).is_equal(1)
	small.free()
	big.free()


func test_hit_sparks_scale_with_strength() -> void:
	var weak: Vfx.Effect = Vfx.hit_sparks(Vector3.ZERO, 0.2)
	var strong: Vfx.Effect = Vfx.hit_sparks(Vector3.ZERO, 2.0)
	var weak_p: GPUParticles3D = weak.get_child(0) as GPUParticles3D
	var strong_p: GPUParticles3D = strong.get_child(0) as GPUParticles3D
	assert_int(strong_p.amount).is_greater(weak_p.amount)
	assert_bool(weak_p.one_shot).is_true()
	weak.free()
	strong.free()


func test_particle_materials_are_unshaded_hdr_for_bloom() -> void:
	var fx: Vfx.Effect = Vfx.hit_sparks(Vector3.ZERO, 1.0)
	var p: GPUParticles3D = fx.get_child(0) as GPUParticles3D
	var mat: ShaderMaterial = p.draw_pass_1.surface_get_material(0) as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_bool(mat.shader.code.contains("blend_add")).is_true()
	assert_bool(mat.shader.code.contains("unshaded")).is_true()
	var energy: float = mat.get_shader_parameter("energy")
	assert_bool(energy > 1.0).is_true()
	fx.free()


func test_shockwave_ring_reaches_radius() -> void:
	var fx: Vfx.Effect = Vfx.shockwave(Vector3.ZERO, 5.0)
	add_child(fx)
	assert_float(fx.ring_radius(0)).is_less(1.0)
	fx.tick(fx.lifetime * 0.45)
	assert_float(fx.ring_radius(0)).is_greater(2.0)
	fx.tick(fx.lifetime)
	assert_float(fx.ring_radius(0)).is_equal_approx(5.0, 0.01)
