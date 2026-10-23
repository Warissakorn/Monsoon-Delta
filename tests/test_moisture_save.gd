extends TestCase
## Moisture is an explicit ruleset contract, never an implicit save migration.

const DIRECTORY: String = "user://tests/moisture_save"
const PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _state(ruleset: String = "moisture_v1", living: bool = false, mode: String = "classic") -> GameState:
	var state: GameState = GameFlow.new_game({
		"seed": 42, "ruleset": ruleset, "living_village": living,
		"run_mode": mode, "village_goal": "forest",
	})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
	for tile: Tile in state.tiles:
		if tile.building == C.Building.NONE:
			tile.feature = C.Feature.PADDY
			tile.soil_moisture = 2
			break
	state.food = 100
	return state


func _paddy(state: GameState) -> Tile:
	for tile: Tile in state.tiles:
		if tile.feature == C.Feature.PADDY:
			return tile
	return null


func _home(state: GameState) -> Tile:
	for tile: Tile in state.tiles:
		if tile.building == C.Building.HOUSE:
			return tile
	return null


func _envelope(state: GameState, version: int = 5) -> Dictionary:
	var data: Dictionary = state.to_dict()
	return {"format": "monsoon_save", "version": version, "state": data, "float64": SaveIO._encode_float64(data)}


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
		assert_eq(FileAccess.get_file_as_bytes(PATH), before)
	else:
		assert_true(not FileAccess.file_exists(PATH))


func _reload(state: GameState) -> GameState:
	var before: Dictionary = state.to_dict()
	assert_eq(SaveIO.save(state, PATH), "")
	var loaded: Dictionary = SaveIO.load_game(PATH)
	assert_eq(loaded["error"], "")
	assert_true(loaded["state"] is GameState)
	if not loaded["state"] is GameState:
		return null
	var restored: GameState = loaded["state"]
	assert_eq(restored.to_dict(), before)
	return restored


func test_v5_roundtrip_preserves_moisture_braces_float64_rng_and_living_history() -> void:
	for ruleset: String in ["moisture_v1", "bracing_moisture_v1"]:
		for living: bool in [false, true]:
			for mode: String in ["classic", "long"]:
				var state: GameState = _state(ruleset, living, mode)
				if state.has_bracing():
					assert_eq(GameFlow.apply_command(state, Command.new("brace_house", _home(state).coord)), "")
				state.tiles[0].water = 0.12345678901234567
				state.rain_inflows[0] = 3.141592653589793
				for _draw: int in range(7):
					state.rng.randi()
				var expected: Dictionary = state.to_dict()
				var restored: GameState = _reload(state)
				if restored == null:
					continue
				var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
				assert_eq(int(envelope["version"]), 5)
				assert_eq(envelope["state"]["ruleset"], ruleset)
				assert_eq(envelope["state"].has("settlement_progress"), living)
				for tile: Dictionary in envelope["state"]["tiles"]:
					assert_true(tile.has("soil_moisture"))
					assert_eq(tile.has("brace_turns"), state.has_bracing())
				assert_eq(restored.to_dict(), expected)
				assert_eq(_paddy(restored).soil_moisture, 2)
				assert_true(restored.undo.is_empty())
				for _draw: int in range(5):
					assert_eq(restored.rng.randi(), state.rng.randi())


func test_loaded_dry_turn_consumes_moisture_once_and_matches_uninterrupted_play() -> void:
	for ruleset: String in ["moisture_v1", "bracing_moisture_v1"]:
		var state: GameState = _state(ruleset)
		if state.has_bracing():
			assert_eq(GameFlow.apply_command(state, Command.new("brace_house", _home(state).coord)), "")
		var restored: GameState = _reload(state)
		if restored == null:
			continue
		var before_food: int = state.food
		for remaining: int in [1, 0, 0]:
			var actual: TurnReport = GameFlow.end_turn(restored)
			var expected: TurnReport = GameFlow.end_turn(state)
			assert_eq(actual.to_dict(), expected.to_dict())
			assert_eq(restored.to_dict(), state.to_dict())
			assert_eq(_paddy(restored).soil_moisture, remaining)
			assert_eq(restored.food, before_food, "moisture grows rice in the field, not stored food")
		assert_eq(_paddy(restored).paddy_yield, 2)
		assert_eq(_paddy(restored).paddy_rain_turns, 0)


func test_loaded_harvest_keeps_moisture_for_next_year_and_annual_rng_matches() -> void:
	var state: GameState = _state("bracing_moisture_v1", true)
	state.turn = C.TURNS_PER_YEAR
	_paddy(state).paddy_yield = 3
	_paddy(state).paddy_rain_turns = 2
	Harvest.do_harvest(state)
	state.phase = C.Phase.HARVEST
	var restored: GameState = _reload(state)
	if restored == null:
		return
	GameFlow.continue_after_harvest(state)
	GameFlow.continue_after_harvest(restored)
	assert_eq(restored.to_dict(), state.to_dict())
	assert_eq(restored.year, 2)
	assert_eq(restored.turn, 1)
	assert_eq(_paddy(restored).soil_moisture, 2)
	assert_eq(_paddy(restored).paddy_yield, 0)
	assert_eq(GameFlow.end_turn(restored).to_dict(), GameFlow.end_turn(state).to_dict())
	assert_eq(restored.to_dict(), state.to_dict())
	assert_eq(_paddy(restored).soil_moisture, 1)
	assert_eq(_paddy(restored).paddy_yield, 1)


func test_v5_requires_ruleset_run_fields_and_moisture_on_every_tile() -> void:
	for key: String in ["ruleset", "run_mode", "village_goal", "goal_achieved_year"]:
		var envelope: Dictionary = _envelope(_state())
		envelope["state"].erase(key)
		_reject(envelope)
	for index: int in [0, 60]:
		var envelope: Dictionary = _envelope(_state())
		envelope["state"]["tiles"][index].erase("soil_moisture")
		_reject(envelope)


func test_noninteger_out_of_range_and_invalid_type_moisture_is_rejected() -> void:
	for value: Variant in [-1, 3, 0.5, true, "2", null]:
		var state: GameState = _state()
		var envelope: Dictionary = _envelope(state)
		var index: int = int(state.index[_paddy(state).coord])
		envelope["state"]["tiles"][index]["soil_moisture"] = value
		_reject(envelope)


func test_nonzero_moisture_on_nonpaddy_or_dead_paddy_is_rejected() -> void:
	for feature: String in ["none", "forest", "sapling"]:
		var state: GameState = _state()
		var envelope: Dictionary = _envelope(state)
		var index: int = int(state.index[_paddy(state).coord])
		envelope["state"]["tiles"][index]["feature"] = feature
		_reject(envelope)
	var state: GameState = _state()
	var envelope: Dictionary = _envelope(state)
	envelope["state"]["tiles"][int(state.index[_paddy(state).coord])]["paddy_dead"] = true
	_reject(envelope)


func test_bracing_and_moisture_field_contracts_are_independent() -> void:
	var no_bracing: Dictionary = _envelope(_state())
	no_bracing["state"]["tiles"][0]["brace_turns"] = 0
	_reject(no_bracing)
	var combined: Dictionary = _envelope(_state("bracing_moisture_v1"))
	combined["state"]["tiles"][0].erase("brace_turns")
	_reject(combined)
	var legacy_brace: GameState = GameFlow.new_game({"seed": 42, "ruleset": "bracing_v1"})
	var brace_data: Dictionary = _envelope(legacy_brace, 4)
	brace_data["state"]["tiles"][0]["soil_moisture"] = 0
	_reject(brace_data)


func test_moisture_data_cannot_be_loaded_through_old_envelopes_or_known_wrong_rulesets() -> void:
	for version: int in [1, 2, 3, 4]:
		_reject(_envelope(_state(), version))
	for ruleset: String in ["legacy", "bracing_v1"]:
		var state: GameState = GameFlow.new_game({"seed": 42, "ruleset": ruleset})
		var data: Dictionary = state.to_dict()
		data["tiles"][0]["soil_moisture"] = 0
		_reject({"format": "monsoon_save", "version": 4 if state.has_bracing() else 1, "state": data, "float64": SaveIO._encode_float64(data)})
		_reject(_envelope(state))


func test_legacy_and_v4_roundtrips_remain_byte_exact_without_moisture_fields() -> void:
	var configs: Array[Dictionary] = [
		{"seed": 42},
		{"seed": 42, "run_mode": "long"},
		{"seed": 42, "living_village": true},
		{"seed": 42, "ruleset": "bracing_v1", "living_village": true},
	]
	for index: int in range(configs.size()):
		var state: GameState = GameFlow.new_game(configs[index])
		assert_eq(SaveIO.save(state, PATH), "")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var envelope: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
		assert_eq(int(envelope["version"]), index + 1)
		for tile: Dictionary in envelope["state"]["tiles"]:
			assert_true(not tile.has("soil_moisture"))
		var loaded: Dictionary = SaveIO.load_game(PATH)
		assert_eq(loaded["error"], "")
		assert_eq(loaded["state"].to_dict(), state.to_dict())
		assert_eq(SaveIO.save(loaded["state"], PATH), "")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)


func test_unsupported_rulesets_or_future_versions_preserve_the_existing_file() -> void:
	var unknown: Dictionary = _envelope(_state())
	unknown["state"]["ruleset"] = "moisture_v99"
	_reject(unknown, true)
	_reject(_envelope(_state(), 6), true)
	for wrong_type: Variant in [1, true, null]:
		var malformed: Dictionary = _envelope(_state())
		malformed["state"]["ruleset"] = wrong_type
		_reject(malformed)


func test_unsavable_runtime_moisture_cannot_replace_a_good_checkpoint() -> void:
	var state: GameState = _state()
	assert_eq(SaveIO.save(state, PATH), "")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	for moisture: int in [-1, 3]:
		_paddy(state).soil_moisture = moisture
		assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	_paddy(state).soil_moisture = 2
	_paddy(state).paddy_dead = true
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	_paddy(state).paddy_dead = false
	state.ruleset = "legacy"
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed", "omitted fields cannot conceal in-memory moisture")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	state.ruleset = "moisture_v99"
	assert_eq(SaveIO.save(state, PATH), "msg.save_unsupported")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)


func test_blocked_v5_atomic_write_preserves_previous_moisture_checkpoint() -> void:
	var state: GameState = _state()
	assert_eq(SaveIO.save(state, PATH), "")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_paddy(state).soil_moisture = 1
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert_eq(SaveIO.save(state, PATH), "")
	assert_eq(_paddy(SaveIO.load_game(PATH)["state"]).soil_moisture, 1)
