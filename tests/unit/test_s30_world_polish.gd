extends GdUnitTestSuite
## Acceptance tests for S30 (render/world_view.gd world polish), DESIGN §9.
## Checks: scattered trees, rocks and grass exist as MultiMeshes and keep clear of the sites and the haul corridor,
## palms stand near the beach, a foam strip lines the shoreline, a hill line stands far inland, vanara tents carry SAFFRON
## flags, Rama's camp pavilion has GOLD trim and no figure, the forest site holds trees, the scenery is deterministic
## and the triangle budget is reasonable. Headless and deterministic.

const DAY_1_PATH: String = "res://data/days/day_1.json"
const WORLD_VIEW_SCRIPT: String = "res://render/world_view.gd"
const SITE_CLEARANCE: float = 9.0
const TRIANGLE_BUDGET: int = 150000


func _load_day_1() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(DAY_1_PATH)
	return JSON.parse_string(text) as Dictionary


func _built_view() -> Node3D:
	var script: GDScript = load(WORLD_VIEW_SCRIPT) as GDScript
	var view: Node3D = auto_free(script.new() as Node3D)
	view.call("build_from_day", _load_day_1())
	return view


func _scenery(view: Node3D) -> Node3D:
	return view.call("get_scenery") as Node3D


## Collects the multimeshes under the scenery whose node name starts with a prefix.
func _multimeshes(view: Node3D, prefix: String) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for child: Node in _scenery(view).get_children():
		if String(child.name).begins_with(prefix) and child is MultiMeshInstance3D:
			result.append(child as MultiMeshInstance3D)
	return result


func _count(view: Node3D, prefix: String) -> int:
	var total: int = 0
	for mmi: MultiMeshInstance3D in _multimeshes(view, prefix):
		total += mmi.multimesh.instance_count
	return total


func _instance_positions(view: Node3D, kind: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for p: Vector3 in view.call("get_scatter_points", kind) as PackedVector3Array:
		result.append(p)
	return result


func _site_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for raw: Variant in _load_day_1()["piles"] as Array:
		var pos: Array = (raw as Dictionary)["pos"] as Array
		result.append(Vector2(pos[0] as float, pos[1] as float))
	return result


func test_trees_rocks_and_grass_are_scattered() -> void:
	var view: Node3D = _built_view()
	assert_object(_scenery(view)).is_not_null()
	assert_int(_count(view, "Trees")).is_greater_equal(40)
	assert_int(_count(view, "Rocks")).is_greater_equal(15)
	assert_int(_count(view, "Grass")).is_greater_equal(30)


func test_scatter_avoids_sites_and_haul_corridor() -> void:
	var view: Node3D = _built_view()
	var sites: Array[Vector2] = _site_points()
	for prefix: String in ["Trees", "Rocks"]:
		for p: Vector3 in _instance_positions(view, prefix):
			assert_float(absf(p.z)).is_greater(3.0)
			for s: Vector2 in sites:
				assert_float(Vector2(p.x, p.z).distance_to(s)).is_greater(SITE_CLEARANCE)


func test_scatter_is_on_land_only() -> void:
	var view: Node3D = _built_view()
	for p: Vector3 in _instance_positions(view, "Trees"):
		assert_float(p.x).is_less(0.0)


func test_palms_stand_near_the_beach() -> void:
	var view: Node3D = _built_view()
	var palms: Array[Vector3] = _instance_positions(view, "Palms")
	assert_int(palms.size()).is_greater_equal(6)
	for p: Vector3 in palms:
		assert_float(p.x).is_between(-14.0, 0.0)


func test_foam_lines_the_shore() -> void:
	# S40: the foam is one WaterKit.shoreline_foam strip along the waterline (it was a MultiMesh of boxes).
	var view: Node3D = _built_view()
	var shore: Node3D = view.get_node_or_null("Shore") as Node3D
	assert_object(shore).is_not_null()
	var foam: MeshInstance3D = shore.get_node_or_null(WaterKit.FOAM_NAME) as MeshInstance3D
	assert_object(foam).is_not_null()
	assert_float(foam.position.x).is_between(2.0, 8.0)
	# The strip runs along the shore (world z) for the whole length of the land.
	var along: Vector3 = foam.transform.basis.x
	assert_float(absf(along.z)).is_equal_approx(1.0, 0.001)
	assert_float((foam.mesh as PlaneMesh).size.x).is_greater_equal(500.0)


func test_hill_line_is_far_inland() -> void:
	var view: Node3D = _built_view()
	var hills: Node3D = _scenery(view).get_node_or_null("Hills") as Node3D
	assert_object(hills).is_not_null()
	assert_int(hills.get_child_count()).is_greater_equal(4)
	for child: Node in hills.get_children():
		assert_float((child as Node3D).position.x).is_less(-120.0)


func test_vanara_tents_have_saffron_flags() -> void:
	var view: Node3D = _built_view()
	var camp: Node3D = _scenery(view).get_node_or_null("VanaraCamp") as Node3D
	assert_object(camp).is_not_null()
	var tents: int = 0
	for child: Node in camp.get_children():
		if String(child.name).begins_with("Tent"):
			tents += 1
			var flag: MeshInstance3D = child.get_node_or_null("Flag") as MeshInstance3D
			assert_object(flag).is_not_null()
			var arrays: Array = flag.mesh.surface_get_arrays(0)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			assert_float(cols[0].r).is_equal_approx(Palette.SAFFRON.r, 0.01)
			assert_float(cols[0].g).is_equal_approx(Palette.SAFFRON.g, 0.01)
	assert_int(tents).is_greater_equal(3)


func test_rama_camp_has_gold_trim_and_no_rama() -> void:
	var view: Node3D = _built_view()
	var camp: Node3D = _scenery(view).get_node_or_null("RamaCamp") as Node3D
	assert_object(camp).is_not_null()
	assert_float(camp.position.x).is_between(-40.0, -5.0)
	var trim: MeshInstance3D = camp.get_node_or_null("GoldTrim") as MeshInstance3D
	assert_object(trim).is_not_null()
	var cols: PackedColorArray = trim.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	assert_float(cols[0].b).is_equal_approx(Palette.GOLD.b, 0.01)
	assert_object(camp.find_child("Rama*", true, false)).is_null()
	assert_object(camp.find_child("Hanuman*", true, false)).is_null()


func test_forest_site_visibly_contains_trees() -> void:
	var view: Node3D = _built_view()
	var forest: Node3D = view.call("get_site", "forest") as Node3D
	var trees: int = 0
	for child: Node in forest.get_children():
		if String(child.name).contains("Tree"):
			trees += 1
	assert_int(trees).is_greater_equal(12)


func test_scenery_is_deterministic() -> void:
	var a: Node3D = _built_view()
	var b: Node3D = _built_view()
	var pa: Array[Vector3] = _instance_positions(a, "Trees")
	var pb: Array[Vector3] = _instance_positions(b, "Trees")
	assert_int(pa.size()).is_equal(pb.size())
	for i: int in range(pa.size()):
		assert_vector(pa[i]).is_equal(pb[i])


func test_rebuild_does_not_duplicate_scenery() -> void:
	var view: Node3D = _built_view()
	var before: int = _count(view, "Trees")
	view.call("build_from_day", _load_day_1())
	assert_int(_count(view, "Trees")).is_equal(before)


func test_scenery_triangle_budget() -> void:
	var view: Node3D = _built_view()
	var tris: int = 0
	for child: Node in _scenery(view).find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
		tris += (mm.mesh.get_faces().size() / 3) * mm.instance_count
	for child: Node in _scenery(view).find_children("*", "MeshInstance3D", true, false):
		tris += ((child as MeshInstance3D).mesh.get_faces().size() / 3)
	assert_int(tris).is_less(TRIANGLE_BUDGET)
	assert_int(tris).is_greater(1000)
