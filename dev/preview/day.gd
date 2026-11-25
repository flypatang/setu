extends SceneTree
## Dev-only: plays the Day 1 fixture plan for N ticks and renders world + bridge + crowd.
## Usage: godot --path . -s dev/preview/day.gd -- <ticks> <time_of_day 0..1> <out.png>

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ticks: int = int(args[0]) if args.size() > 0 else 4000
	var tod: float = float(args[1]) if args.size() > 1 else 0.4
	var day: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/days/day_1.json")) as Dictionary
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/unit/fixtures/plan_day1.json"))
	var flow: DayFlow = DayFlow.new()
	flow.load_day(day)
	flow.queue_commands((plan as Dictionary).get("commands", []) as Array if plan is Dictionary else plan as Array)
	flow.run_ticks(ticks)
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var world: WorldView = WorldView.new()
	root3d.add_child(world)
	world.build_from_day(day)
	world.set_time_of_day(tod)
	var bv: BridgeView = BridgeView.new()
	root3d.add_child(bv)
	bv.sync(flow.bridge)
	var crowd: CrowdView = CrowdView.new()
	root3d.add_child(crowd)
	crowd.sync(flow)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 70.0
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = Vector3(20, 0, 0) + cam.basis.z * 200.0
	cam.far = 1000.0
	root3d.add_child(cam)
	cam.make_current()
	for i: int in 12:
		await process_frame
	get_root().get_texture().get_image().save_png(args[2] if args.size() > 2 else "/tmp/day.png")
	print("bridge length m: ", flow.bridge.length_m(), " tick: ", flow.tick())
	quit()
