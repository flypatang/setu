class_name BotDays
extends RefCounted
## S21: reusable playtest helper. Runs one scripted day (data/days/day_<n>.json plus a command
## plan) headlessly through DayFlow and returns the score and the final state hash.

const DAY_PATH: String = "res://data/days/day_%d.json"
const PLAN_PATH: String = "res://tests/unit/fixtures/plan_day%d.json"


## Parsed JSON object at path, or an empty Dictionary when missing or malformed.
static func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## The command list of the plan fixture for day n (empty when there is none).
static func load_plan(n: int) -> Array:
	var d: Dictionary = read_json(PLAN_PATH % n)
	return d.get("commands", []) as Array


## Plays day n with the given commands from a clean start (no carry-over).
## Returns {total, length_pct, alignment_pct, waste_pct, morale_avg, length_m, target_m, gongs, hash}
## gongs[i] is the number of gong towers built for creature zone i + 1 (zones are numbered in day-file order)..
static func run_day(n: int, plan: Array) -> Dictionary:
	var flow: DayFlow = DayFlow.new()
	flow.load_day(read_json(DAY_PATH % n), 0)
	flow.queue_commands(plan)
	flow.run_ticks(flow.day_ticks)
	var sc: Dictionary = flow.score()
	sc["length_m"] = flow.bridge.length_m()
	sc["target_m"] = flow.target_m
	var gongs: Array[int] = []
	for zone_id: int in range(1, 4):
		gongs.append(flow.creatures.gong_count(zone_id))
	sc["gongs"] = gongs
	sc["hash"] = flow.state_hash()
	return sc
