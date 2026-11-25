extends GdUnitTestSuite
## Acceptance tests for the S15b visual fix of render/world_view.gd (DESIGN §9 S15).
## Checks: each of the quarry, forest, rope-works and lekhan sites is built from enough parts to read from the iso
## camera (rock cluster plus cliff and cut-stone pile; a grove of 12-20 trees; a shed with rope coils; a canopy with
## scribes' stones carrying the RamaGlyph mesh), each visible site has a torch light that is dark at noon and lit at
## night, and the sun elevation is clamped above a small positive minimum with shadows off at night.
## Headless and deterministic.

const DAY_1_PATH: String = "res://data/days/day_1.json"
const WORLD_VIEW_SCRIPT: String = "res://render/world_view.gd"
const VISIBLE_ROLES: Array[String] = ["quarry", "forest", "ropeworks", "lekhan"]


func _load_day_1() -> Dictionary:
	var file: FileAccess = FileAccess.open(DAY_1_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text) as Dictionary


func _new_view() -> Node3D:
	var script: GDScript = load(WORLD_VIEW_SCRIPT) as GDScript
	return script.new() as Node3D


func _built_view() -> Node3D:
	var view: Node3D = auto_free(_new_view())
	view.call("build_from_day", _load_day_1())
	return view


## Godot renames duplicate sibling names (e.g. "@Rock@2"), so match the part name anywhere in the node name.
func _count_prefix(node: Node, part: String) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if String(child.name).contains(part):
			count += 1
	return count


func _site(view: Node3D, id: String) -> Node3D:
	return view.call("get_site", id) as Node3D


func _torches(view: Node3D) -> Array[OmniLight3D]:
	var result: Array[OmniLight3D] = []
	for raw: Variant in view.call("get_torches") as Array:
		result.append(raw as OmniLight3D)
	return result


func test_quarry_has_rock_cluster_cliff_and_cut_stone() -> void:
	var view: Node3D = _built_view()
	var quarry: Node3D = _site(view, "quarry")
	assert_object(quarry).is_not_null()
	var rocks: int = _count_prefix(quarry, "Rock")
	assert_int(rocks).is_greater_equal(6)
	assert_int(rocks).is_less_equal(10)
	assert_int(_count_prefix(quarry, "Cliff")).is_equal(1)
	assert_int(_count_prefix(quarry, "CutStone")).is_greater_equal(1)


func test_forest_is_a_grove_of_12_to_20_trees() -> void:
	var view: Node3D = _built_view()
	var forest: Node3D = _site(view, "forest")
	assert_object(forest).is_not_null()
	var trees: int = _count_prefix(forest, "Tree")
	assert_int(trees).is_greater_equal(12)
	assert_int(trees).is_less_equal(20)


func test_rope_works_has_open_shed_and_rope_coils() -> void:
	var view: Node3D = _built_view()
	var works: Node3D = _site(view, "ropeworks")
	assert_object(works).is_not_null()
	assert_object(works.get_node_or_null("ShedRoof")).is_not_null()
	assert_object(works.get_node_or_null("ShedBack")).is_not_null()
	assert_int(_count_prefix(works, "RopeCoil")).is_greater_equal(2)


func test_lekhan_has_canopy_and_scribes_stones_with_rama_glyph() -> void:
	var view: Node3D = _built_view()
	var lekhan: Node3D = _site(view, "lekhan")
	assert_object(lekhan).is_not_null()
	assert_object(lekhan.get_node_or_null("Canopy")).is_not_null()
	var steles: int = _count_prefix(lekhan, "Stele")
	assert_int(steles).is_greater_equal(2)
	for child: Node in lekhan.get_children():
		if String(child.name).contains("Stele"):
			assert_object(child.get_node_or_null("RamaGlyph")).is_not_null()
			var glyph: MeshInstance3D = child.get_node_or_null("RamaGlyph") as MeshInstance3D
			assert_object(glyph.material_override).is_same(RamaGlyph.material())


func test_every_visible_site_has_a_torch_light() -> void:
	var view: Node3D = _built_view()
	for role: String in VISIBLE_ROLES:
		var site: Node3D = _site(view, role)
		assert_object(site).is_not_null()
		var found: bool = false
		for child: Node in site.get_children():
			if child is OmniLight3D:
				found = true
		assert_bool(found).is_true()


func test_torches_are_dark_at_noon_and_full_at_midnight() -> void:
	var view: Node3D = _built_view()
	var torches: Array[OmniLight3D] = _torches(view)
	assert_int(torches.size()).is_equal(VISIBLE_ROLES.size())

	view.call("set_time_of_day", 0.5)
	for torch: OmniLight3D in torches:
		assert_float(torch.light_energy).is_equal_approx(0.0, 0.001)

	view.call("set_time_of_day", 0.0)
	for torch: OmniLight3D in torches:
		assert_float(torch.light_energy).is_greater(0.0)


func test_torches_fade_in_after_dusk() -> void:
	var view: Node3D = _built_view()
	var torches: Array[OmniLight3D] = _torches(view)
	view.call("set_time_of_day", 0.95)
	var full: float = torches[0].light_energy
	view.call("set_time_of_day", 0.85)
	var partial: float = torches[0].light_energy
	assert_float(partial).is_greater(0.0)
	assert_float(partial).is_less(full)


func test_torch_energy_rises_monotonically_through_dusk_and_stays_bounded() -> void:
	var view: Node3D = _built_view()
	var torches: Array[OmniLight3D] = _torches(view)
	view.call("set_time_of_day", 0.95)
	var full: float = torches[0].light_energy
	var previous: float = -1.0
	for step: int in range(0, 21):
		var t: float = 0.8 + 0.01 * float(step)
		view.call("set_time_of_day", t)
		var energy: float = torches[0].light_energy
		assert_float(energy).is_between(0.0, full + 0.001)
		assert_float(energy).is_greater_equal(previous)
		previous = energy


func test_sun_elevation_is_clamped_above_small_positive_minimum_at_midnight() -> void:
	var view: Node3D = _built_view()
	view.call("set_time_of_day", 0.0)
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D
	var travel: Vector3 = -sun.transform.basis.z
	# Light still travels downward (sun above the horizon) but only at a shallow angle.
	assert_float(travel.y).is_less(0.0)
	assert_float(travel.y).is_greater(-0.2)


func test_sun_shadows_off_at_night_and_on_at_noon() -> void:
	var view: Node3D = _built_view()
	var sun: DirectionalLight3D = view.call("get_sun") as DirectionalLight3D
	view.call("set_time_of_day", 0.5)
	assert_bool(sun.shadow_enabled).is_true()
	view.call("set_time_of_day", 0.0)
	assert_bool(sun.shadow_enabled).is_false()
	view.call("set_time_of_day", 0.95)
	assert_bool(sun.shadow_enabled).is_false()
