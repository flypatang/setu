extends SceneTree
## Dev-only: boots main.tscn, jumps to a day, runs the bot plan for N ticks, and screenshots the real game UI.
## Usage: godot --path . -s dev/preview/game_shot.gd -- <day> <ticks> <lang en|hi> <out.png>

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var day: int = int(args[0]) if args.size() > 0 else 1
	var ticks: int = int(args[1]) if args.size() > 1 else 3000
	var lang: String = args[2] if args.size() > 2 else "en"
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	var game: MainGame = scene.instantiate() as MainGame
	get_root().add_child(game)
	await process_frame
	(get_root().get_node("/root/Locale") as Node).call("set_language", StringName(lang))
	game.begin_day(day)
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/unit/fixtures/plan_day%d.json" % day)) as Dictionary
	game.flow().queue_commands(plan.get("commands", []) as Array)
	game.flow().run_ticks(ticks)
	game.call("_sync_views")
	if game.dialogue_box() != null:
		game.dialogue_box().visible = false
	for i: int in 20:
		await process_frame
	get_root().get_texture().get_image().save_png(args[3] if args.size() > 3 else "/tmp/game.png")
	quit()
