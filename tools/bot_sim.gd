extends SceneTree
## Reproducible M3 experiments. No gameplay data files or saves are changed.

const Scenarios = preload("res://tools/balance_scenarios.gd")


func _initialize() -> void:
	var parsed: Dictionary = _settings(OS.get_cmdline_user_args())
	if not String(parsed["error"]).is_empty():
		printerr(parsed["error"])
		quit(2)
		return
	if parsed.get("help", false):
		print("Usage: --bot=farmer|greedy|random|all --runs=200 --map=plains|all --difficulty=0..10 --seed-start=1 --candidates=N --output=directory")
		print("Experiments: --scenarios=path/to/scenarios.json --revision=optional-label")
		print("Schema: {\"version\":1,\"scenarios\":[{\"id\":\"baseline\",\"mods\":{}}]}")
		print("Every invocation creates a fresh run directory. M3 supports plains only, without cards/events.")
		quit(0)
		return
	var settings: Dictionary = parsed["settings"]
	var scenarios: Array = [{"id": "baseline", "mods": {}}]
	if not String(settings["scenarios"]).is_empty():
		var loaded: Dictionary = Scenarios.load_file(String(settings["scenarios"]))
		if not String(loaded["error"]).is_empty():
			printerr(loaded["error"])
			quit(2)
			return
		scenarios = loaded["scenarios"]
	# All input is validated before directories or reports are created.
	var base_defaults: Dictionary = Dictionary(DataDB.balance()["mods_default"]).duplicate(true)
	var succeeded: bool = _experiment(settings, scenarios, base_defaults)
	# Also restore on a simulation or output failure. Each scenario starts fresh.
	Dictionary(DataDB.balance()["mods_default"]).assign(base_defaults)
	quit(0 if succeeded else 1)


func _settings(arguments: PackedStringArray) -> Dictionary:
	var settings: Dictionary = {
		"bot": "all", "runs": 200, "map": "plains", "difficulty": 0,
		"seed-start": 1, "output": "res://bot_reports", "scenarios": "", "revision": "",
		"candidates": int(DataDB.balance()["bots"]["candidate_count"]),
	}
	for argument: String in arguments:
		if argument in ["--help", "-h"]:
			return {"error": "", "help": true}
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or parts.size() != 2 or not settings.has(parts[0]):
			return {"error": "Unknown or malformed argument: " + argument}
		var key: String = parts[0]
		if key in ["runs", "difficulty", "seed-start", "candidates"]:
			if not _fits_int64(parts[1]):
				return {"error": "Expected a signed 64-bit integer for --" + key}
			settings[key] = parts[1].to_int()
		else:
			settings[key] = parts[1]
	if String(settings["bot"]) not in ["farmer", "greedy", "random", "all"]:
		return {"error": "--bot must be farmer, greedy, random, or all"}
	if String(settings["map"]) not in ["plains", "all"]:
		return {"error": "M3 currently implements plains only"}
	if int(settings["runs"]) < 1 or int(settings["candidates"]) < 1:
		return {"error": "--runs and --candidates must be positive"}
	if int(settings["difficulty"]) < 0 or int(settings["difficulty"]) > 10:
		return {"error": "--difficulty must be between 0 and 10"}
	if String(settings["output"]).is_empty():
		return {"error": "--output must name a directory"}
	if int(settings["seed-start"]) > 9223372036854775807 - (int(settings["runs"]) - 1):
		return {"error": "Seed range exceeds the signed 64-bit limit"}
	return {"error": "", "settings": settings}


func _fits_int64(value: String) -> bool:
	if not value.is_valid_int():
		return false
	var digits: String = value.trim_prefix("-").trim_prefix("+")
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
	var limit: String = "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	return digits.length() < limit.length() or (digits.length() == limit.length() and digits <= limit)


func _experiment(settings: Dictionary, scenarios: Array, base_defaults: Dictionary) -> bool:
	var parent: String = ProjectSettings.globalize_path(String(settings["output"]))
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var output: String = parent.path_join("run_%s_%d" % [stamp, Time.get_ticks_usec()])
	if DirAccess.dir_exists_absolute(output):
		printerr("Run directory already exists: " + output)
		return false
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Could not create run directory: " + output)
		return false
	var policies: Array[String] = [String(settings["bot"])]
	if settings["bot"] == "all":
		policies = ["farmer", "greedy", "random"]
	var seed_end: int = int(settings["seed-start"]) + (int(settings["runs"]) - 1)
	var manifest: Dictionary = {
		"version": 1, "status": "running", "started_utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info(), "source": _source_info(String(settings["revision"])),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"base_mods": base_defaults.duplicate(true), "leader": "farmer", "map": "plains",
		"difficulty": settings["difficulty"], "policies": policies,
		"runs_per_policy": settings["runs"], "seed_start": str(settings["seed-start"]),
		"seed_end": str(seed_end),
		"bot_configuration": BotGreedy.configuration({"candidate_count": int(settings["candidates"])}),
		"scenario_file": settings["scenarios"], "scenarios": scenarios.duplicate(true),
		"generation_note": "Overrides also affect map-generation safety rejection. Matching seeds can produce different boards across scenarios.",
		"results": [], "error": "",
	}
	if not String(settings["scenarios"]).is_empty():
		manifest["scenario_sha256"] = FileAccess.get_sha256(String(settings["scenarios"]))
	var manifest_path: String = output.path_join("manifest.json")
	if not _write_json(manifest_path, manifest):
		return false
	print("M3 plains experiments; farmer leader, no cards/events; greedy candidates %d." % int(settings["candidates"]))
	print("Run directory: " + output)
	print("scenario / bot: completed/runs, win%, mean year, hall losses, population losses")
	var succeeded: bool = true
	for scenario: Dictionary in scenarios:
		var defaults: Dictionary = DataDB.balance()["mods_default"]
		defaults.assign(base_defaults)
		defaults.merge(scenario["mods"], true)
		var model: GameState = GameState.new()
		model.map_type = "plains"
		model.leader = "farmer"
		model.difficulty = int(settings["difficulty"])
		model.recompute_mods()
		var scenario_output: String = output.path_join(String(scenario["id"]))
		if DirAccess.make_dir_recursive_absolute(scenario_output) != OK:
			manifest["error"] = "Could not create scenario directory: " + scenario_output
			succeeded = false
			break
		for policy: String in policies:
			var result: Dictionary = _run_policy(policy, settings, scenario_output)
			result["scenario"] = scenario["id"]
			result["effective_mods"] = model.mods.duplicate(true)
			manifest["results"].append(result)
			print("%s / %s: %d/%d, %.1f%%, %.2f, %d, %d" % [
				scenario["id"], policy, result["completed"], settings["runs"],
				result["win_percent"], result["mean_year"], result["hall_losses"], result["population_losses"],
			])
			if not String(result["error"]).is_empty():
				manifest["error"] = result["error"]
				succeeded = false
			if not _write_json(manifest_path, manifest):
				manifest["error"] = "Could not update manifest: " + manifest_path
				succeeded = false
			if not succeeded:
				break
		if not succeeded:
			break
	Dictionary(DataDB.balance()["mods_default"]).assign(base_defaults)
	manifest["status"] = "complete" if succeeded else "failed"
	manifest["finished_utc"] = Time.get_datetime_string_from_system(true)
	if not _write_summary(output.path_join("summary.csv"), manifest["results"]):
		manifest["status"] = "failed"
		manifest["error"] = "Could not write summary.csv"
		succeeded = false
	if not _write_json(manifest_path, manifest):
		succeeded = false
	if not succeeded:
		printerr("Experiment incomplete: " + String(manifest["error"]))
	print("Manifest: " + manifest_path)
	return succeeded


func _run_policy(policy: String, settings: Dictionary, output: String) -> Dictionary:
	var difficulty: int = int(settings["difficulty"])
	var path: String = output.path_join("%s_plains_d%d.csv" % [policy, difficulty])
	var result: Dictionary = {
		"bot": policy, "map": "plains", "difficulty": difficulty, "runs": int(settings["runs"]),
		"completed": 0, "wins": 0, "hall_losses": 0, "population_losses": 0,
		"win_percent": 0.0, "mean_year": 0.0, "mean_population": 0.0, "mean_score": 0.0,
		"seconds": 0.0, "csv": path, "error": "",
	}
	var csv: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if csv == null:
		result["error"] = "Cannot write bot report: " + path
		return result
	csv.store_csv_line(PackedStringArray([
		"bot", "map", "difficulty", "seed", "win", "outcome", "year", "population", "score", "turns", "actions", "seconds",
	]))
	var years: int = 0
	var populations: int = 0
	var scores: int = 0
	var started: int = Time.get_ticks_usec()
	for run: int in int(settings["runs"]):
		var seed_value: int = int(settings["seed-start"]) + run
		var game_started: int = Time.get_ticks_usec()
		var played: Dictionary = BotGreedy.play_game(seed_value, policy, difficulty, {"candidate_count": int(settings["candidates"])})
		if not String(played["error"]).is_empty():
			result["error"] = "%s seed %d failed: %s" % [policy, seed_value, played["error"]]
			break
		var state: GameState = played["state"]
		var won: bool = state.outcome == C.Outcome.WIN
		result["wins"] += int(won)
		result["hall_losses"] += int(state.outcome == C.Outcome.LOSE_HALL)
		result["population_losses"] += int(state.outcome == C.Outcome.LOSE_POPULATION)
		years += state.year
		populations += state.population
		scores += state.final_score
		var elapsed: float = float(Time.get_ticks_usec() - game_started) / 1000000.0
		csv.store_csv_line(PackedStringArray([
			policy, "plains", str(difficulty), str(seed_value), str(int(won)),
			C.enum_name(C.Outcome, state.outcome), str(state.year), str(state.population),
			str(state.final_score), str(played["turns"]), str(played["actions"]), "%.6f" % elapsed,
		]))
		result["completed"] += 1
		if (run + 1) % 20 == 0:
			csv.flush()
			print("Progress %s: %d/%d games" % [policy, run + 1, int(settings["runs"])])
		if csv.get_error() != OK:
			result["error"] = "Could not write bot report: " + path
			break
	csv.flush()
	if csv.get_error() != OK:
		result["error"] = "Could not flush bot report: " + path
	csv.close()
	var completed: float = float(result["completed"])
	if completed > 0:
		result["win_percent"] = 100.0 * int(result["wins"]) / completed
		result["mean_year"] = years / completed
		result["mean_population"] = populations / completed
		result["mean_score"] = scores / completed
	result["seconds"] = float(Time.get_ticks_usec() - started) / 1000000.0
	return result


func _source_info(label: String) -> Dictionary:
	var info: Dictionary = {"label": label, "git_revision": "", "git_dirty": null}
	var root: String = ProjectSettings.globalize_path("res://")
	if not DirAccess.dir_exists_absolute(root.path_join(".git")) and not FileAccess.file_exists(root.path_join(".git")):
		return info
	var lines: Array = []
	if OS.execute("git", PackedStringArray(["-C", root, "rev-parse", "HEAD"]), lines) == 0:
		info["git_revision"] = "".join(lines).strip_edges()
		lines.clear()
		if OS.execute("git", PackedStringArray(["-C", root, "status", "--porcelain"]), lines) == 0:
			info["git_dirty"] = not "".join(lines).strip_edges().is_empty()
	return info


func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write manifest: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var succeeded: bool = file.get_error() == OK
	file.close()
	if not succeeded:
		printerr("Could not flush manifest: " + path)
	return succeeded


func _write_summary(path: String, results: Array) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var keys: PackedStringArray = PackedStringArray([
		"scenario", "bot", "map", "difficulty", "runs", "completed", "wins", "win_percent",
		"mean_year", "hall_losses", "population_losses", "mean_population", "mean_score", "seconds", "error",
	])
	file.store_csv_line(keys)
	for result: Dictionary in results:
		var row: PackedStringArray = PackedStringArray()
		for key: String in keys:
			row.append(str(result[key]))
		file.store_csv_line(row)
	file.flush()
	var succeeded: bool = file.get_error() == OK
	file.close()
	return succeeded
