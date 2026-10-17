extends SceneTree
## Run with: godot --headless --path . --script res://tools/bot_sim.gd -- --bot=all


func _initialize() -> void:
	var settings: Dictionary = {
		"bot": "all", "runs": 200, "map": "plains", "difficulty": 0,
		"seed-start": 1, "output": "res://bot_reports",
		"candidates": int(DataDB.balance()["bots"]["candidate_count"]),
	}
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--help", "-h"]:
			print("Usage: --bot=farmer|greedy|random|all --runs=200 --map=plains|all --difficulty=0..10 --seed-start=1 --candidates=N --output=directory")
			print("M3 supports plains only; --map=all runs the available plains map. Cards/events are not implemented in M3.")
			quit(0)
			return
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or parts.size() != 2 or not settings.has(parts[0]):
			_reject("Unknown or malformed argument: " + argument)
			return
		var key: String = parts[0]
		if key in ["runs", "difficulty", "seed-start", "candidates"]:
			if not parts[1].is_valid_int():
				_reject("Expected an integer for --" + key)
				return
			settings[key] = parts[1].to_int()
		else:
			settings[key] = parts[1]
	if String(settings["bot"]) not in ["farmer", "greedy", "random", "all"]:
		_reject("--bot must be farmer, greedy, random, or all")
		return
	if String(settings["map"]) not in ["plains", "all"]:
		_reject("Unsupported map '%s': M3 currently implements plains only" % settings["map"])
		return
	if int(settings["runs"]) < 1 or int(settings["candidates"]) < 1:
		_reject("--runs and --candidates must be positive")
		return
	if int(settings["difficulty"]) < 0 or int(settings["difficulty"]) > 10:
		_reject("--difficulty must be between 0 and 10")
		return
	if String(settings["output"]).is_empty():
		_reject("--output must name a directory")
		return
	var output: String = ProjectSettings.globalize_path(String(settings["output"]))
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_reject("Could not create output directory: " + output)
		return
	if settings["map"] == "all":
		print("Available M3 maps: plains. --map=all runs plains only.")
	print("M3 core simulation: plains, no cards/events; greedy candidates %d." % int(settings["candidates"]))
	print("bot      map     runs  win%%  mean_year  hall  pop  mean_population  mean_score  seconds")
	var policies: Array[String] = [String(settings["bot"])]
	if settings["bot"] == "all":
		policies = ["farmer", "greedy", "random"]
	for policy: String in policies:
		if not _run_policy(policy, settings, output):
			quit(1)
			return
	quit(0)


func _run_policy(policy: String, settings: Dictionary, output: String) -> bool:
	var difficulty: int = int(settings["difficulty"])
	var path: String = output.path_join("%s_plains_d%d.csv" % [policy, difficulty])
	var csv: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if csv == null:
		printerr("Cannot write bot report: " + path)
		return false
	csv.store_csv_line(PackedStringArray([
		"bot", "map", "difficulty", "seed", "win", "outcome", "year", "population", "score", "turns", "actions", "seconds",
	]))
	var wins: int = 0
	var hall_losses: int = 0
	var population_losses: int = 0
	var years: int = 0
	var populations: int = 0
	var scores: int = 0
	var started: int = Time.get_ticks_usec()
	for run: int in int(settings["runs"]):
		var seed_value: int = int(settings["seed-start"]) + run
		var game_started: int = Time.get_ticks_usec()
		var result: Dictionary = BotGreedy.play_game(seed_value, policy, difficulty, {"candidate_count": int(settings["candidates"])})
		if not String(result["error"]).is_empty():
			printerr("%s seed %d failed: %s" % [policy, seed_value, result["error"]])
			return false
		var state: GameState = result["state"]
		var won: bool = state.outcome == C.Outcome.WIN
		wins += int(won)
		hall_losses += int(state.outcome == C.Outcome.LOSE_HALL)
		population_losses += int(state.outcome == C.Outcome.LOSE_POPULATION)
		years += state.year
		populations += state.population
		scores += state.final_score
		var elapsed: float = float(Time.get_ticks_usec() - game_started) / 1000000.0
		csv.store_csv_line(PackedStringArray([
			policy, "plains", str(difficulty), str(seed_value), str(int(won)),
			C.enum_name(C.Outcome, state.outcome), str(state.year), str(state.population),
			str(state.final_score), str(result["turns"]), str(result["actions"]), "%.6f" % elapsed,
		]))
		if (run + 1) % 20 == 0:
			csv.flush()
			print("Progress %s: %d/%d games" % [policy, run + 1, int(settings["runs"])])
	var runs: float = float(settings["runs"])
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
	csv.flush()
	print("%-8s %-7s %4d %5.1f %10.2f %5d %4d %16.2f %11.2f %8.2f" % [
		policy, "plains", int(settings["runs"]), 100.0 * wins / runs, years / runs,
		hall_losses, population_losses, populations / runs, scores / runs, elapsed,
	])
	print("CSV: " + path)
	return true


func _reject(message: String) -> void:
	printerr(message)
	quit(2)
