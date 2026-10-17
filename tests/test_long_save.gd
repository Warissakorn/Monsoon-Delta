extends TestCase
## Longer games and optional goals survive disk checkpoints without changing RNG.

const PATH: String = "user://tests/long_save/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func _state(mode: String = "long", goal: String = "none") -> GameState:
	return GameFlow.new_game({"seed": 42, "run_mode": mode, "village_goal": goal})


func _envelope(data: Dictionary, version: int = 2) -> Dictionary:
	return {
		"format": "monsoon_save", "version": version, "state": data,
		"float64": SaveIO._encode_float64(data),
	}


func _write(envelope: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	assert_true(file != null)
	if file != null:
		file.store_string(JSON.stringify(envelope, "", true, true))
		file.close()


func _assert_corrupt(envelope: Dictionary, note: String = "") -> void:
	_write(envelope)
	assert_eq(SaveIO.load_game(PATH), {"state": null, "error": "msg.save_corrupt"}, note)
	assert_true(not SaveIO.has_save(PATH), note)


func _reload(state: GameState) -> GameState:
	var expected: Dictionary = state.to_dict()
	assert_eq(SaveIO.save(state, PATH), "")
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	assert_true(result["state"] is GameState)
	if not result["state"] is GameState:
		return null
	var restored: GameState = result["state"]
	assert_eq(restored.to_dict(), expected, "all simulation fields retain their exact values")
	return restored


func _controlled(state: GameState, year: int) -> void:
	# Keep a real serializable map while isolating checkpoint transitions from floods.
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 7):
		state.tiles[index].building = C.Building.HOUSE
	state.year = year
	state.turn = C.TURNS_PER_YEAR
	state.stats["reached_year"] = year
	state.food = 1000


func test_all_modes_and_goals_roundtrip_with_exact_float_and_rng_continuation() -> void:
	for mode: String in ["classic", "long"]:
		for goal: String in ["none", "growth", "forest", "rice"]:
			var state: GameState = _state(mode, goal)
			state.year = 4
			state.stats["reached_year"] = 4
			state.goal_achieved_year = 0 if goal == "none" else 3
			state.tiles[0].water = 0.013960820753117553
			state.rain_inflows[0] = 3.141592653589793
			state.rng.seed = -9223372036854775807 - 1
			for _draw: int in range(7):
				state.rng.randi()
			var restored: GameState = _reload(state)
			if restored == null:
				return
			assert_eq(restored.target_years(), 5 if mode == "classic" else 10)
			for draw: int in range(10):
				assert_eq(restored.rng.randi(), state.rng.randi(), "continued RNG draw %d" % draw)
	SaveIO.delete_save(PATH)


func test_classic_without_goal_keeps_v1_schema_and_extended_games_use_v2() -> void:
	for options: Array in [["classic", "none"], ["classic", "growth"], ["long", "none"], ["long", "rice"]]:
		var state: GameState = _state(options[0], options[1])
		assert_eq(SaveIO.save(state, PATH), "")
		var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var extended: bool = state.run_mode != "classic" or state.village_goal != "none"
		assert_eq(envelope["version"], 2.0 if extended else 1.0)
		assert_eq(envelope.size(), 4)
		for field: String in SaveIO.RUN_FIELDS:
			assert_eq(envelope["state"].has(field), extended, field)
		assert_eq(envelope["state"].size(), SaveIO.STATE_FIELDS.size() + (3 if extended else 0))
	for version: int in [0, 3]:
		_assert_corrupt(_envelope(_state().to_dict(), version), "unknown envelope versions cannot migrate a run")
	SaveIO.delete_save(PATH)


func test_legacy_v1_checkpoint_migrates_only_missing_run_fields_without_rewriting() -> void:
	var state: GameState = _state("classic")
	state.tiles[0].water = 0.013960820753117553
	state.rain_inflows[0] = 0.013960820753117553
	state.rng.seed = 9223372036854775807
	state.rng.randi()
	var legacy: Dictionary = state.to_dict()
	for field: String in SaveIO.RUN_FIELDS:
		legacy.erase(field)
	_write(_envelope(legacy, 1))
	var previous: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	if result["state"] is GameState:
		assert_eq(result["state"].to_dict(), state.to_dict())
		assert_eq(result["state"].target_years(), 5)
		assert_eq(result["state"].rng.randi(), state.rng.randi())
	assert_eq(FileAccess.get_file_as_bytes(PATH), previous, "loading an older save does not rewrite it")
	SaveIO.delete_save(PATH)


func test_v1_accepts_explicit_default_triplet_but_rejects_extended_games() -> void:
	var defaults: GameState = _state("classic")
	_write(_envelope(defaults.to_dict(), 1))
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	if result["state"] is GameState:
		assert_eq(result["state"].to_dict(), defaults.to_dict())
	for state: GameState in [_state(), _state("classic", "growth"), _state("long", "forest")]:
		assert_true(SaveIO._valid_state(state.to_dict()), "supported state shape")
		_assert_corrupt(_envelope(state.to_dict(), 1), "older clients cannot ignore a longer run or goal")


func test_partial_run_fields_and_missing_v2_fields_are_corrupt() -> void:
	for version: int in [1, 2]:
		for mask: int in range(1, 7):
			var data: Dictionary = _state("classic").to_dict()
			for index: int in range(SaveIO.RUN_FIELDS.size()):
				if mask & (1 << index):
					data.erase(SaveIO.RUN_FIELDS[index])
			_assert_corrupt(_envelope(data, version), "partial triplet %d version %d" % [mask, version])
	var absent: Dictionary = _state("classic").to_dict()
	for field: String in SaveIO.RUN_FIELDS:
		absent.erase(field)
	_assert_corrupt(_envelope(absent, 2), "v2 always declares all run fields")


func test_unknown_or_malformed_run_fields_are_corrupt_without_downgrading() -> void:
	var cases: Array[Array] = [
		["run_mode", "endless"], ["run_mode", "LONG"], ["run_mode", ""],
		["run_mode", null], ["run_mode", true], ["run_mode", 10], ["run_mode", {}],
		["village_goal", "unknown"], ["village_goal", "RICE"], ["village_goal", ""],
		["village_goal", null], ["village_goal", false], ["village_goal", []],
		["goal_achieved_year", -1], ["goal_achieved_year", 2], ["goal_achieved_year", 0.5],
		["goal_achieved_year", "1"], ["goal_achieved_year", null], ["goal_achieved_year", true],
	]
	for example: Array in cases:
		var data: Dictionary = _state("long", "growth").to_dict()
		data[example[0]] = example[1]
		_assert_corrupt(_envelope(data), "invalid %s: %s" % [example[0], str(example[1])])
	var no_goal: Dictionary = _state().to_dict()
	no_goal["goal_achieved_year"] = 1
	_assert_corrupt(_envelope(no_goal), "a run without a goal cannot have a medal")


func test_year_and_stats_bounds_follow_mode_and_cannot_disagree() -> void:
	for mode: String in ["classic", "long"]:
		var last_year: int = 5 if mode == "classic" else 10
		for year: int in [0, last_year + 1]:
			var data: Dictionary = _state(mode).to_dict()
			data["year"] = year
			data["stats"]["reached_year"] = year
			_assert_corrupt(_envelope(data), "year outside mode bounds")
		var mismatch: Dictionary = _state(mode).to_dict()
		mismatch["stats"]["reached_year"] = last_year
		_assert_corrupt(_envelope(mismatch), "stats must match the actual year")
		var state: GameState = _state(mode, "rice")
		state.year = last_year
		state.stats["reached_year"] = last_year
		state.goal_achieved_year = last_year
		assert_true(_reload(state) != null, "the final planning year and medal remain valid")
	SaveIO.delete_save(PATH)


func test_long_year_five_and_nine_continue_identically_after_reloading_harvest() -> void:
	for year: int in [5, 9]:
		var reference: GameState = _state("long", "growth")
		_controlled(reference, year)
		var resumed: GameState = _reload(reference)
		if resumed == null:
			return
		assert_eq(GameFlow.end_turn(resumed).to_dict(), GameFlow.end_turn(reference).to_dict())
		assert_eq(resumed.to_dict(), reference.to_dict())
		assert_eq(reference.phase, C.Phase.HARVEST)
		assert_eq(reference.outcome, C.Outcome.NONE, "year five is not a long-run ending")
		assert_eq(reference.goal_achieved_year, year, "harvest awards the first earned goal medal")
		resumed = _reload(resumed)
		if resumed == null:
			return
		GameFlow.continue_after_harvest(reference)
		GameFlow.continue_after_harvest(resumed)
		assert_eq(reference.year, year + 1)
		assert_eq(reference.phase, C.Phase.PLANNING)
		assert_eq(resumed.to_dict(), reference.to_dict(), "next year's forecast and RNG continue exactly")
		assert_true(_reload(resumed) != null)
	SaveIO.delete_save(PATH)


func test_harvest_outcomes_respect_long_target_and_keep_earned_goal() -> void:
	var final: GameState = _state("long", "growth")
	_controlled(final, 10)
	assert_true(GameFlow.end_turn(final) != null)
	assert_eq(final.outcome, C.Outcome.WIN)
	assert_eq(final.goal_achieved_year, 10)
	var restored: GameState = _reload(final)
	if restored == null:
		return
	assert_true(RunGoals.progress(restored)["achieved"])
	GameFlow.continue_after_harvest(final)
	GameFlow.continue_after_harvest(restored)
	assert_eq(restored.to_dict(), final.to_dict(), "saved final medal contributes to the same final score")
	assert_eq(restored.phase, C.Phase.GAME_OVER)
	var early_win: GameState = _state()
	_controlled(early_win, 5)
	GameFlow.end_turn(early_win)
	var malformed: Dictionary = early_win.to_dict()
	malformed["outcome"] = "win"
	_assert_corrupt(_envelope(malformed), "long games cannot win in year five")
	var missing_win: GameState = _state()
	_controlled(missing_win, 10)
	GameFlow.end_turn(missing_win)
	malformed = missing_win.to_dict()
	malformed["outcome"] = "none"
	_assert_corrupt(_envelope(malformed), "a populated final harvest must finish the run")
	var loss: GameState = _state()
	_controlled(loss, 8)
	loss.food = 0
	GameFlow.end_turn(loss)
	assert_eq(loss.outcome, C.Outcome.LOSE_POPULATION)
	assert_true(_reload(loss) != null, "late-year population loss is still a resumable annual summary")
	SaveIO.delete_save(PATH)


func test_bad_runtime_run_fields_never_replace_the_good_checkpoint() -> void:
	var valid: GameState = _state("long", "rice")
	assert_eq(SaveIO.save(valid, PATH), "")
	var previous: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var bad_states: Array[GameState] = []
	for mode: String in ["unknown", "LONG"]:
		var state: GameState = valid.duplicate_state()
		state.run_mode = mode
		bad_states.append(state)
	var bad_goal: GameState = valid.duplicate_state()
	bad_goal.village_goal = "missing"
	bad_states.append(bad_goal)
	for year: int in [-1, 2]:
		var state: GameState = valid.duplicate_state()
		state.goal_achieved_year = year
		bad_states.append(state)
	var none_medal: GameState = _state()
	none_medal.goal_achieved_year = 1
	bad_states.append(none_medal)
	var invalid_year: GameState = valid.duplicate_state()
	invalid_year.year = 11
	invalid_year.stats["reached_year"] = 11
	bad_states.append(invalid_year)
	for bad: GameState in bad_states:
		assert_eq(SaveIO.save(bad, PATH), "msg.save_failed")
		assert_eq(FileAccess.get_file_as_bytes(PATH), previous)
	assert_true(SaveIO.load_game(PATH)["state"] is GameState)
	SaveIO.delete_save(PATH)
