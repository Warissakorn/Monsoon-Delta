extends TestCase

const DIRECTORY: String = "user://tests/bracing_save"
const PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _state(living: bool = false, run_mode: String = "classic", goal: String = "none") -> GameState:
	return GameFlow.new_game({
		"seed": 42, "ruleset": "bracing_v1", "living_village": living,
		"run_mode": run_mode, "village_goal": goal,
	})


func _home(state: GameState) -> Tile:
	for tile: Tile in state.tiles:
		if tile.building == C.Building.HOUSE:
			return tile
	return null


func _envelope(state: GameState) -> Dictionary:
	var data: Dictionary = state.to_dict()
	return {"format": "monsoon_save", "version": 4, "state": data, "float64": SaveIO._encode_float64(data)}


func _write(envelope: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	assert_true(file != null)
	if file != null:
		file.store_string(JSON.stringify(envelope, "", true, true))
		file.close()


func _reject(envelope: Dictionary, unsupported: bool = false) -> void:
	_write(envelope)
	var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["state"], null)
	assert_eq(result["error"], "msg.save_unsupported" if unsupported else "msg.save_corrupt")
	if unsupported:
		assert_eq(FileAccess.get_file_as_bytes(PATH), before, "unsupported data must be preserved")
	else:
		assert_true(not FileAccess.file_exists(PATH), "known corrupt format follows existing deletion policy")


func test_v4_roundtrip_keeps_braces_floats_rng_and_optional_living_history() -> void:
	for living: bool in [false, true]:
		for mode: String in ["classic", "long"]:
			var state: GameState = _state(living, mode, "forest")
			assert_eq(GameFlow.apply_command(state, Command.new("brace_house", _home(state).coord)), "")
			state.tiles[0].water = 0.12345678901234567
			state.rain_inflows[0] = 3.141592653589793
			for _draw: int in range(7):
				state.rng.randi()
			var expected: Dictionary = state.to_dict()
			assert_eq(SaveIO.save(state, PATH), "")
			var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			assert_eq(int(envelope["version"]), 4)
			assert_eq(envelope["state"]["ruleset"], "bracing_v1")
			assert_eq(envelope["state"].has("settlement_progress"), living)
			for tile: Dictionary in envelope["state"]["tiles"]:
				assert_true(tile.has("brace_turns"))
			var loaded: Dictionary = SaveIO.load_game(PATH)
			assert_eq(loaded["error"], "")
			assert_true(loaded["state"] is GameState)
			if not loaded["state"] is GameState:
				continue
			var restored: GameState = loaded["state"]
			assert_eq(restored.to_dict(), expected)
			assert_eq(_home(restored).brace_turns, 1)
			assert_true(restored.undo.is_empty())
			for _draw: int in range(5):
				assert_eq(restored.rng.randi(), state.rng.randi())


func test_v1_v2_v3_keep_their_schema_and_exact_saved_bytes_after_continue() -> void:
	var configs: Array[Dictionary] = [
		{"seed": 42},
		{"seed": 42, "run_mode": "long", "village_goal": "rice"},
		{"seed": 42, "living_village": true},
	]
	for index: int in range(configs.size()):
		var state: GameState = GameFlow.new_game(configs[index])
		assert_eq(SaveIO.save(state, PATH), "")
		var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var envelope: Dictionary = JSON.parse_string(before.get_string_from_utf8())
		assert_eq(int(envelope["version"]), index + 1)
		assert_true(not envelope["state"].has("ruleset"))
		for tile: Dictionary in envelope["state"]["tiles"]:
			assert_true(not tile.has("brace_turns"))
		var loaded: Dictionary = SaveIO.load_game(PATH)
		assert_eq(loaded["error"], "")
		var restored: GameState = loaded["state"]
		assert_eq(restored.ruleset, "legacy")
		assert_eq(restored.to_dict(), state.to_dict())
		assert_eq(CommandRules.check(restored, Command.new("brace_house", _home(restored).coord)), "err.locked")
		assert_eq(SaveIO.save(restored, PATH), "")
		assert_eq(FileAccess.get_file_as_bytes(PATH), before)


func test_loaded_braced_run_resolves_identically_without_reapplying_price() -> void:
	var state: GameState = _state(true)
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", _home(state).coord)), "")
	assert_eq(SaveIO.save(state, PATH), "")
	var restored: GameState = SaveIO.load_game(PATH)["state"]
	assert_eq(restored.wood, state.wood)
	assert_eq(restored.labor, state.labor)
	var uninterrupted: TurnReport = GameFlow.end_turn(state)
	var continued: TurnReport = GameFlow.end_turn(restored)
	assert_eq(continued.to_dict(), uninterrupted.to_dict())
	assert_eq(restored.to_dict(), state.to_dict())
	assert_eq(_home(restored).brace_turns, 0)


func test_missing_ruleset_run_fields_or_tile_field_is_rejected() -> void:
	for key: String in ["ruleset", "run_mode", "village_goal", "goal_achieved_year"]:
		var envelope: Dictionary = _envelope(_state())
		envelope["state"].erase(key)
		_reject(envelope)
	var missing_tile: Dictionary = _envelope(_state())
	missing_tile["state"]["tiles"][0].erase("brace_turns")
	_reject(missing_tile)


func test_brace_values_and_non_house_braces_are_rejected_before_deserialization() -> void:
	for value: Variant in [-1, 2, 0.5, true, "1", null]:
		var envelope: Dictionary = _envelope(_state())
		envelope["state"]["tiles"][0]["brace_turns"] = value
		_reject(envelope)
	for building: String in ["none", "hall", "raft_house", "granary", "gate"]:
		var state: GameState = _state()
		var envelope: Dictionary = _envelope(state)
		var index: int = int(state.index[_home(state).coord])
		envelope["state"]["tiles"][index]["building"] = building
		envelope["state"]["tiles"][index]["brace_turns"] = 1
		_reject(envelope)


func test_braces_cannot_survive_into_harvest_checkpoint() -> void:
	var state: GameState = _state()
	state.turn = C.TURNS_PER_YEAR
	state.food = 100
	Harvest.do_harvest(state)
	state.phase = C.Phase.HARVEST
	assert_eq(SaveIO.save(state, PATH), "")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_home(state).brace_turns = 1
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	_reject(_envelope(state))


func test_new_fields_cannot_be_smuggled_into_old_envelopes() -> void:
	for version: int in [1, 2, 3]:
		var envelope: Dictionary = _envelope(_state(version == 3))
		envelope["version"] = version
		_reject(envelope)
	var legacy: GameState = GameFlow.new_game({"seed": 42})
	var legacy_data: Dictionary = legacy.to_dict()
	legacy_data["tiles"][0]["brace_turns"] = 0
	_reject({"format": "monsoon_save", "version": 1, "state": legacy_data, "float64": SaveIO._encode_float64(legacy_data)})
	var explicit_legacy: Dictionary = _envelope(_state())
	explicit_legacy["state"]["ruleset"] = "legacy"
	_reject(explicit_legacy)


func test_unknown_rulesets_and_future_envelopes_preserve_files() -> void:
	var unknown: Dictionary = _envelope(_state())
	unknown["state"]["ruleset"] = "bracing_v99"
	_reject(unknown, true)
	var future: Dictionary = _envelope(_state())
	future["version"] = 5
	_reject(future, true)
	for wrong_type: Variant in [1, true, null]:
		var malformed: Dictionary = _envelope(_state())
		malformed["state"]["ruleset"] = wrong_type
		_reject(malformed)


func test_unsupported_or_orphaned_in_memory_state_cannot_replace_existing_save() -> void:
	var state: GameState = _state()
	assert_eq(SaveIO.save(state, PATH), "")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	state.ruleset = "bracing_v99"
	assert_eq(SaveIO.save(state, PATH), "msg.save_unsupported")
	state.phase = C.Phase.GAME_OVER
	assert_eq(SaveIO.save(state, PATH), "msg.save_unsupported")
	assert_eq(FileAccess.get_file_as_bytes(PATH), before)
	state.phase = C.Phase.PLANNING
	state.ruleset = "legacy"
	_home(state).brace_turns = 1
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), before)


func test_blocked_v4_atomic_write_keeps_last_good_checkpoint() -> void:
	var state: GameState = _state()
	assert_eq(SaveIO.save(state, PATH), "")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", _home(state).coord)), "")
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert_eq(SaveIO.save(state, PATH), "")
	assert_eq(SaveIO.load_game(PATH)["state"].to_dict(), state.to_dict())
