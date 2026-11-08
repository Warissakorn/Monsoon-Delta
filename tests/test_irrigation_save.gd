extends TestCase
const F = preload("res://tools/irrigation_fixtures.gd")
const DIRECTORY: String = "user://tests/irrigation_save"
const PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)


func _envelope(state: GameState, version: int = 6) -> Dictionary:
	var data: Dictionary = state.to_dict()
	return {"format": "monsoon_save", "version": version, "state": data, "float64": SaveIO._encode_float64(data)}


func _write(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", true, true))
	file.close()


func _reject(data: Dictionary, unsupported: bool = false) -> void:
	_write(data)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var loaded: Dictionary = SaveIO.load_game(PATH)
	assert_eq(loaded["error"], "msg.save_unsupported" if unsupported else "msg.save_corrupt")
	assert_true(loaded["state"] == null)
	if unsupported:
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	else:
		assert_true(not FileAccess.file_exists(PATH))


func test_v6_all_combinations_roundtrip_exact_fields_float64_rng_and_visual_history() -> void:
	for bracing: bool in [false, true]:
		for moisture: bool in [false, true]:
			for living: bool in [false, true]:
				var state: GameState = F.create(GameState.ruleset_for(bracing, moisture, true), living)
				assert_eq(GameFlow.apply_command(state, Command.new("irrigation_policy", F.FIELDS[0], 2)), "")
				state.get_tile(F.RESERVOIR).water = 1.1234567890123456
				state.rain_inflows[0] = 3.141592653589793
				state.rng.randi()
				var expected: Dictionary = state.to_dict()
				assert_eq(SaveIO.save(state, PATH), "")
				var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
				var envelope: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
				assert_eq(int(envelope["version"]), 6)
				for tile: Dictionary in envelope["state"]["tiles"]:
					assert_true(tile.has("irrigation_policy"))
					assert_eq(tile.has("brace_turns"), bracing)
					assert_eq(tile.has("soil_moisture"), moisture)
				var loaded: Dictionary = SaveIO.load_game(PATH)
				assert_eq(loaded["error"], "")
				assert_true(loaded["state"] is GameState)
				if loaded["state"] == null:
					continue
				var restored: GameState = loaded["state"]
				assert_eq(restored.to_dict(), expected)
				assert_true(restored.undo.is_empty() and restored.redo.is_empty())
				assert_eq(SaveIO.save(restored, PATH), "")
				assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
				for _draw: int in range(4):
					assert_eq(restored.rng.randi(), state.rng.randi())


func test_load_then_continue_matches_uninterrupted_resolution_and_policy_survives_rain_and_year() -> void:
	var state: GameState = F.create("bracing_moisture_irrigation_v1", true)
	assert_eq(GameFlow.apply_command(state, Command.new("irrigation_policy", F.FIELDS[0], 2)), "")
	assert_eq(SaveIO.save(state, PATH), "")
	var restored: GameState = SaveIO.load_game(PATH)["state"]
	for _turn: int in range(6):
		assert_eq(GameFlow.end_turn(state).to_dict(), GameFlow.end_turn(restored).to_dict())
		assert_eq(state.to_dict(), restored.to_dict())
	assert_eq(state.phase, C.Phase.HARVEST)
	assert_eq(SaveIO.save(state, PATH), "")
	restored = SaveIO.load_game(PATH)["state"]
	assert_eq(restored.to_dict(), state.to_dict())
	GameFlow.continue_after_harvest(state)
	GameFlow.continue_after_harvest(restored)
	assert_eq(restored.to_dict(), state.to_dict())
	assert_eq(state.get_tile(F.FIELDS[0]).irrigation_policy, "skip")


func test_missing_malformed_and_orphaned_policies_are_rejected_without_defaulting() -> void:
	var state: GameState = F.create()
	for value: Variant in [null, true, 1, 0.5, [], {}, "future", "FIRST", ""]:
		var data: Dictionary = _envelope(state)
		data["state"]["tiles"][0]["irrigation_policy"] = value
		_reject(data)
	var missing: Dictionary = _envelope(state)
	missing["state"]["tiles"][0].erase("irrigation_policy")
	_reject(missing)
	for dead: bool in [false, true]:
		var bad: GameState = F.create()
		var tile: Tile = bad.get_tile(F.FIELDS[0] if dead else F.HALL)
		tile.irrigation_policy = "first"
		if dead:
			tile.paddy_dead = true
			tile.soil_moisture = 0
		_reject(_envelope(bad))


func test_v1_through_v5_schemas_and_roundtrips_do_not_gain_policy_fields() -> void:
	var configs: Array[Dictionary] = [
		{}, {"run_mode": "long"}, {"living_village": true},
		{"ruleset": "bracing_v1"}, {"ruleset": "moisture_v1"},
	]
	for index: int in range(configs.size()):
		var state: GameState = GameFlow.new_game(configs[index])
		assert_eq(SaveIO.save(state, PATH), "")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var envelope: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
		assert_eq(int(envelope["version"]), index + 1)
		for tile: Dictionary in envelope["state"]["tiles"]:
			assert_true(not tile.has("irrigation_policy"))
		var loaded: Dictionary = SaveIO.load_game(PATH)
		assert_eq(loaded["error"], "")
		assert_eq(loaded["state"].to_dict(), state.to_dict())
		assert_eq(SaveIO.save(loaded["state"], PATH), "")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)


func test_future_versions_unknown_rulesets_and_in_memory_errors_preserve_the_save() -> void:
	_reject(_envelope(F.create(), 8), true)
	_reject(_envelope(F.create(), 7))
	var unknown: Dictionary = _envelope(F.create())
	unknown["state"]["ruleset"] = "irrigation_v99"
	_reject(unknown, true)
	for version: int in [1, 2, 3, 4, 5]:
		_reject(_envelope(F.create(), version))
	_reject(_envelope(GameFlow.new_game({}), 6))
	var state: GameState = F.create()
	assert_eq(SaveIO.save(state, PATH), "")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	state.get_tile(F.HALL).irrigation_policy = "skip"
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	state.get_tile(F.HALL).irrigation_policy = "future"
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)


func test_session_checkpoints_policies_and_undo_redo_but_not_receipts_or_history() -> void:
	var session: GameSession = GameSession.new()
	session.state = F.create()
	session.save_path = PATH
	assert_eq(session.checkpoint(), "")
	assert_eq(session.apply(Command.new("irrigation_policy", F.FIELDS[0], 2)), "")
	assert_eq(SaveIO.load_game(PATH)["state"].get_tile(F.FIELDS[0]).irrigation_policy, "skip")
	assert_true(session.undo())
	assert_eq(SaveIO.load_game(PATH)["state"].get_tile(F.FIELDS[0]).irrigation_policy, "normal")
	assert_true(session.redo())
	var report: TurnReport = session.advance_turn()
	assert_eq(session.turn_history()[0]["report"]["irrigation_results"], report.irrigation_results)
	assert_eq(session.last_save_error, "")
	assert_eq(SaveIO.load_game(PATH)["state"].to_dict(), session.state.to_dict())
	assert_true(not FileAccess.get_file_as_string(PATH).contains("irrigation_results"))
	var receipt: Array = session.turn_history()[0]["report"]["irrigation_results"]
	receipt[0]["source"] = "invented"
	assert_eq(session.turn_history()[0]["report"]["irrigation_results"], report.irrigation_results)
