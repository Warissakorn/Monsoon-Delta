extends TestCase

const DIRECTORY: String = "user://tests/save_io"
const PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [PATH, PATH + ".tmp", DIRECTORY + "/unreadable", DIRECTORY + "/missing.json"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _state() -> GameState:
	return GameFlow.new_game({"seed": 42})


func _envelope(data: Dictionary) -> Dictionary:
	# For malformed raw shapes the companion is immaterial: shape validation
	# must reject the state before ever consulting its binary float companion.
	var bits: Dictionary = SaveIO._encode_float64(data if SaveIO._valid_state(data) else _state().to_dict())
	return {"format": "monsoon_save", "version": 1, "state": data, "float64": bits}


func _write_text(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	assert_true(file != null, "fixture file can be opened")
	if file != null:
		file.store_string(text)
		file.close()


func _write_data(data: Variant) -> void:
	_write_text(JSON.stringify(data, "", true, true))


func _write_bytes(bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	assert_true(file != null)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _assert_corrupt(data: Variant, note: String = "") -> void:
	_write_data(data)
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["state"], null, note)
	assert_eq(result["error"], "msg.save_corrupt", note)
	assert_true(not SaveIO.has_save(PATH), "corrupt checkpoint removed: " + note)


func _assert_bad_field(field: String, value: Variant, note: String = "") -> void:
	var data: Dictionary = _state().to_dict()
	data[field] = value
	_assert_corrupt(_envelope(data), field + ": " + note)


func _harvest(year: int, starving: bool = false) -> GameState:
	var state: GameState = _state()
	state.year = year
	state.stats["reached_year"] = year
	state.turn = C.TURNS_PER_YEAR
	state.food = 0 if starving else 100
	Harvest.do_harvest(state)
	state.phase = C.Phase.HARVEST
	return state


func test_planning_roundtrip_keeps_exact_floats_rng_and_empty_loaded_undo() -> void:
	var state: GameState = _state()
	state.seed = 9223372036854775807
	state.rng.seed = -9223372036854775807 - 1
	for _draw: int in range(7):
		state.rng.randi()
	state.tiles[0].water = 0.12345678901234567
	state.rain_inflows[0] = 3.141592653589793
	state.stats["max_population"] = state.population + 3
	state.undo.push(state.to_dict())
	var expected: Dictionary = state.to_dict()
	assert_eq(SaveIO.save(state, PATH), "")
	assert_true(SaveIO.has_save(PATH))
	assert_true(not FileAccess.file_exists(PATH + ".tmp"))
	var loaded: Dictionary = SaveIO.load_game(PATH)
	assert_eq(loaded["error"], "")
	assert_true(loaded["state"] is GameState)
	if not loaded["state"] is GameState:
		return
	var restored: GameState = loaded["state"]
	assert_eq(restored.to_dict(), expected)
	assert_eq(restored.index.size(), 61)
	assert_true(restored.get_tile(state.tiles[0].coord) == restored.tiles[0])
	assert_true(restored.undo.is_empty())
	assert_eq(state.undo.size(), 1, "saving must not clear the live undo stack")
	assert_near(float(restored.mod("harvest_paddy_bonus")), 1.0, 0.0)
	for draw: int in range(10):
		assert_eq(restored.rng.randi(), state.rng.randi(), "RNG continuation %d" % draw)
	SaveIO.delete_save(PATH)


func test_harvest_roundtrip_retains_summary_and_all_supported_outcomes() -> void:
	for state: GameState in [_harvest(1), _harvest(5), _harvest(2, true)]:
		var expected: Dictionary = state.to_dict()
		assert_eq(SaveIO.save(state, PATH), "")
		var result: Dictionary = SaveIO.load_game(PATH)
		assert_eq(result["error"], "")
		assert_true(result["state"] is GameState)
		if result["state"] is GameState:
			assert_eq(result["state"].to_dict(), expected, "load cannot reapply harvest")
	SaveIO.delete_save(PATH)


func test_previous_harvest_report_remains_valid_during_next_year_planning() -> void:
	var state: GameState = _harvest(1)
	var report: Dictionary = state.harvest_report.duplicate(true)
	GameFlow.continue_after_harvest(state)
	assert_eq(state.year, 2)
	assert_eq(state.phase, C.Phase.PLANNING)
	assert_eq(state.harvest_report, report)
	assert_eq(SaveIO.save(state, PATH), "")
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	if result["state"] is GameState:
		assert_eq(result["state"].to_dict(), state.to_dict())
	SaveIO.delete_save(PATH)


func test_missing_save_and_explicit_delete_are_idempotent() -> void:
	assert_true(not SaveIO.has_save(PATH))
	assert_eq(SaveIO.load_game(PATH), {"state": null, "error": ""})
	assert_eq(SaveIO.delete_save(PATH), "")
	assert_eq(SaveIO.save(_state(), PATH), "")
	assert_eq(SaveIO.delete_save(PATH), "")
	assert_true(not SaveIO.has_save(PATH))
	assert_eq(SaveIO.delete_save(PATH), "")


func test_tutorial_save_never_overwrites_or_deletes_a_normal_checkpoint() -> void:
	assert_eq(SaveIO.save(_state(), PATH), "")
	var previous: String = FileAccess.get_file_as_string(PATH)
	var tutorial: GameState = GameFlow.new_game({"seed": 1001, "is_tutorial": true})
	assert_eq(SaveIO.save(tutorial, PATH), "")
	tutorial.phase = C.Phase.GAME_OVER
	assert_eq(SaveIO.save(tutorial, PATH), "")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	SaveIO.delete_save(PATH)
	assert_eq(SaveIO.save(tutorial, PATH), "")
	assert_true(not SaveIO.has_save(PATH))


func test_game_over_save_deletes_the_checkpoint() -> void:
	var state: GameState = _state()
	assert_eq(SaveIO.save(state, PATH), "")
	state.phase = C.Phase.GAME_OVER
	state.outcome = C.Outcome.LOSE_HALL
	assert_eq(SaveIO.save(state, PATH), "")
	assert_true(not SaveIO.has_save(PATH))


func test_atomic_replacement_and_blocked_temporary_preserve_previous_save() -> void:
	var state: GameState = _state()
	assert_eq(SaveIO.save(state, PATH), "")
	state.food += 3
	assert_eq(SaveIO.save(state, PATH), "", "existing destination replaced atomically")
	var previous: String = FileAccess.get_file_as_string(PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	state.food += 5
	assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
	assert_eq(FileAccess.get_file_as_string(PATH), previous, "failed temporary open keeps good save")
	assert_eq(SaveIO.load_game(PATH)["error"], "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	SaveIO.delete_save(PATH)


func test_read_failure_keeps_file_and_returns_system_error() -> void:
	assert_eq(SaveIO.save(_state(), PATH), "")
	var previous: String = FileAccess.get_file_as_string(PATH)
	if OS.has_feature("linux") or OS.has_feature("macos"):
		var permissions: int = FileAccess.get_unix_permissions(PATH)
		assert_eq(FileAccess.set_unix_permissions(PATH, 0), OK)
		var probe: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if probe == null:
			var result: Dictionary = SaveIO.load_game(PATH)
			assert_eq(result["state"], null)
			assert_eq(result["error"], "msg.save_failed")
		else:
			probe.close() # Privileged hosts may bypass Unix permission bits.
		assert_eq(FileAccess.set_unix_permissions(PATH, permissions), OK)
		assert_eq(FileAccess.get_file_as_string(PATH), previous)
	var directory_path: String = DIRECTORY + "/unreadable"
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(directory_path)), OK)
	assert_eq(SaveIO.load_game(directory_path), {"state": null, "error": "msg.save_failed"})
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory_path)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory_path))
	SaveIO.delete_save(PATH)


func test_invalid_runtime_serialization_does_not_clobber_good_checkpoint() -> void:
	assert_eq(SaveIO.save(_state(), PATH), "")
	var previous: String = FileAccess.get_file_as_string(PATH)
	var bad_states: Array[GameState] = []
	var bad: GameState = _state()
	bad.tiles[0].water = NAN
	bad_states.append(bad)
	bad = _state()
	bad.tiles[0].water = INF
	bad_states.append(bad)
	bad = _state()
	bad.tiles[0].building = 999
	bad_states.append(bad)
	bad = _state()
	bad.tiles.append(null)
	bad_states.append(bad)
	bad = _state()
	bad.rng = null
	bad_states.append(bad)
	bad = _state()
	bad.stats["houses_lost"] = {"bad": 1}
	bad_states.append(bad)
	bad = _state()
	bad.year_mods = [{"key": "flow_rate", "op": "set", "value": {"bad": 1}}]
	bad_states.append(bad)
	bad = _state()
	bad.phase = C.Phase.EVENT
	bad_states.append(bad)
	bad = _state()
	bad.food = SaveIO.MAX_JSON_INTEGER + 1
	bad_states.append(bad)
	for state: GameState in bad_states:
		assert_eq(SaveIO.save(state, PATH), "msg.save_failed")
		assert_eq(FileAccess.get_file_as_string(PATH), previous)
	assert_eq(SaveIO.save(null, PATH), "msg.save_failed")
	assert_eq(SaveIO.save(_state(), ""), "msg.save_failed")
	assert_eq(SaveIO.save(_state(), DIRECTORY + "/missing/child.json"), "msg.save_failed")
	SaveIO.delete_save(PATH)


func test_corrupt_parse_envelope_and_version_are_rejected_without_model_errors() -> void:
	for text: String in ["", "{", "not json", "null", "[]"]:
		_write_text(text)
		assert_eq(SaveIO.load_game(PATH), {"state": null, "error": "msg.save_corrupt"})
		assert_true(not SaveIO.has_save(PATH))
	for envelope: Variant in [
		{}, {"format": "other", "version": 1, "state": {}},
		{"format": true, "version": 1, "state": {}},
		{"format": "monsoon_save", "version": 2, "state": {}},
		{"format": "monsoon_save", "version": "1", "state": {}},
		{"format": "monsoon_save", "version": 1.5, "state": {}},
		{"format": "monsoon_save", "version": true, "state": {}},
		{"format": "monsoon_save", "version": 1, "state": []},
		{"format": "monsoon_save", "version": 1, "state": {}},
	]:
		_assert_corrupt(envelope)


func test_corrupt_state_fields_and_unsupported_phases_are_rejected() -> void:
	var cases: Array[Array] = [
		["version", 2], ["version", 1.5], ["year", 0], ["year", 6], ["year", 1.5],
		["turn", 7], ["turn", "1"], ["difficulty", -1], ["difficulty", 11],
		["difficulty", 2.5], ["map_type", "valley"], ["map_type", true], ["leader", "missing"],
		["phase", "card_pick"], ["phase", "event"], ["phase", "game_over"],
		["phase", "PLANNING"], ["phase", "unknown"], ["outcome", "bad"],
		["outcome", "win"], ["population", -1], ["food", "6"], ["wood", 0.5],
		["labor", true], ["labor", 100], ["labor_max", -1], ["final_score", 5],
		["is_daily", 1], ["is_tutorial", 0], ["is_tutorial", true],
		["cards", ["waterwheel"]], ["card_offer", ["bamboo"]], ["pending_event", "flood"],
		["forecast_min", -1], ["forecast_max", 0], ["rain_inflows", [1.0, 2.0]],
		["rain_inflows", [1.0, -2.0, 3.0]], ["rain_inflows", [1.0, "2", 3.0]],
		["stats", []], ["harvest_report", []], ["population", SaveIO.MAX_JSON_INTEGER + 1],
	]
	for example: Array in cases:
		_assert_bad_field(example[0], example[1])
	for field: String in SaveIO.STATE_FIELDS:
		var data: Dictionary = _state().to_dict()
		data.erase(field)
		_assert_corrupt(_envelope(data), "missing " + field)
	_write_text(JSON.stringify(_envelope(_state().to_dict())).replace('"food":6', '"food":1e100'))
	assert_eq(SaveIO.load_game(PATH)["error"], "msg.save_corrupt")


func test_all_64_bit_seed_strings_validate_without_precision_loss() -> void:
	for value: int in [0, 9223372036854775807, -9223372036854775807 - 1]:
		var state: GameState = _state()
		state.seed = value
		state.rng.seed = value
		state.rng.state = value
		assert_eq(SaveIO.save(state, PATH), "")
		var result: Dictionary = SaveIO.load_game(PATH)
		assert_eq(result["error"], "")
		if result["state"] is GameState:
			assert_eq(result["state"].to_dict(), state.to_dict())
	for field: String in ["seed", "rng_seed", "rng_state"]:
		for bad: Variant in ["", "oops", "1x", "1.5", "+1", "01", "-0", "9223372036854775808", "-9223372036854775809", 42, null]:
			_assert_bad_field(field, bad)
	SaveIO.delete_save(PATH)


func test_tile_geometry_types_enums_and_invariants_are_validated() -> void:
	var baseline: Dictionary = _state().to_dict()
	var short_map: Array = baseline["tiles"].duplicate(true)
	short_map.pop_back()
	_assert_bad_field("tiles", short_map)
	var reordered: Array = baseline["tiles"].duplicate(true)
	reordered[0] = reordered[1]
	_assert_bad_field("tiles", reordered)
	_assert_bad_field("tiles", ["bad"])
	var cases: Array[Array] = [
		["q", 99], ["r", 0.5], ["elevation", -4], ["elevation", 5], ["water", -1],
		["water", "0.1"], ["feature", "FOREST"], ["feature", "bad"],
		["building", "bad"], ["gate_open", 1], ["is_source", "true"], ["is_sea", 0],
		["is_river", null], ["paddy_yield", -1], ["paddy_rain_turns", 0.5],
		["paddy_dead", "false"], ["wheel_dir", 6], ["start_house", 0],
	]
	for example: Array in cases:
		var data: Dictionary = baseline.duplicate(true)
		data["tiles"][0][example[0]] = example[1]
		_assert_corrupt(_envelope(data), "tile " + String(example[0]))
	for field: String in SaveIO.TILE_FIELDS:
		var data: Dictionary = baseline.duplicate(true)
		data["tiles"][0].erase(field)
		_assert_corrupt(_envelope(data), "missing tile " + field)
	var occupied: Dictionary = baseline.duplicate(true)
	occupied["tiles"][0]["feature"] = "forest"
	occupied["tiles"][0]["building"] = "house"
	_assert_corrupt(_envelope(occupied), "feature and building coexist")
	var wheel: Dictionary = baseline.duplicate(true)
	wheel["tiles"][0]["feature"] = "none"
	wheel["tiles"][0]["building"] = "waterwheel"
	wheel["tiles"][0]["wheel_dir"] = -1
	_assert_corrupt(_envelope(wheel), "waterwheel needs direction")


func test_harvest_and_stat_consistency_rejects_impossible_checkpoints() -> void:
	var data: Dictionary = _state().to_dict()
	data["stats"]["max_population"] = 0
	_assert_corrupt(_envelope(data))
	data = _state().to_dict()
	data["stats"]["reached_year"] = 2
	_assert_corrupt(_envelope(data))
	data = _state().to_dict()
	data["stats"]["hall_ever_wet"] = 1
	_assert_corrupt(_envelope(data))
	data = _harvest(1).to_dict()
	data["harvest_report"]["food_after"] += 1
	_assert_corrupt(_envelope(data))
	data = _harvest(1).to_dict()
	data["harvest_report"]["population_after"] += 1
	_assert_corrupt(_envelope(data))
	for outcome: String in ["win", "lose_population"]:
		data = _harvest(1).to_dict()
		data["outcome"] = outcome
		_assert_corrupt(_envelope(data), "bad year/population for " + outcome)
	data = _harvest(5).to_dict()
	data["outcome"] = "none"
	_assert_corrupt(_envelope(data))
	data = _harvest(2, true).to_dict()
	data["outcome"] = "none"
	_assert_corrupt(_envelope(data))
	data = _harvest(1).to_dict()
	data["turn"] = 5
	_assert_corrupt(_envelope(data))
	data = _harvest(1).to_dict()
	data["harvest_report"].erase("born")
	_assert_corrupt(_envelope(data))


func test_known_finite_modifiers_restore_and_unsafe_modifiers_are_rejected() -> void:
	var state: GameState = _state()
	state.year_mods = [
		{"key": "flow_rate", "op": "set", "value": 0.625},
		{"key": "house_wood", "op": "add", "value": -1},
		{"key": "water_iterations", "op": "set", "value": 25},
	]
	state.recompute_mods()
	assert_eq(SaveIO.save(state, PATH), "")
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	if result["state"] is GameState:
		assert_eq(result["state"].to_dict(), state.to_dict())
		assert_near(float(result["state"].mod("flow_rate")), 0.625, 0.0)
	for modifiers: Variant in [
		{}, [null], ["bad"], [{"key": "missing", "op": "set", "value": 1}],
		[{"key": "flow_rate", "op": "bad", "value": 1}],
		[{"key": "flow_rate", "op": "set", "value": "1"}],
		[{"key": "flow_rate", "op": "set"}],
		[{"key": "flow_rate", "op": "set", "value": {}}],
		[{"key": "flow_rate", "op": "set", "value": 1, "extra": true}],
		[{"key": "water_iterations", "op": "set", "value": 0}],
		[{"key": "water_iterations", "op": "set", "value": 0.5}],
		[{"key": "water_iterations", "op": "set", "value": SaveIO.MAX_WATER_ITERATIONS + 1}],
		[{"key": "water_iterations", "op": "mul", "value": SaveIO.MAX_JSON_INTEGER}],
		[{"key": "flow_rate", "op": "mul", "value": SaveIO.MAX_JSON_INTEGER}, {"key": "flow_rate", "op": "mul", "value": 10}],
	]:
		_assert_bad_field("year_mods", modifiers)
	for key: String in [
		"sea_level_dry", "sea_level_rain", "wheel_amount", "dry_inflow", "forest_absorb",
		"sapling_absorb", "evaporation_dry", "evaporation_multiplier", "fish_trap_yield", "fish_trap_multiplier",
	]:
		state = _state()
		state.year_mods = [{"key": key, "op": "set", "value": -1}]
		assert_eq(SaveIO.save(state, PATH), "msg.save_failed", "negative effective " + key)
		_assert_bad_field("year_mods", state.year_mods)
	for key: String in ["dig_labor_dry", "fill_labor_rain", "paddy_labor", "house_wood"]:
		state = _state()
		state.year_mods = [{"key": key, "op": "set", "value": 2147483648}]
		assert_eq(SaveIO.save(state, PATH), "msg.save_failed", "Vector2i cost overflow " + key)
		_assert_bad_field("year_mods", state.year_mods)


func test_float64_companion_is_required_validated_and_keeps_difficult_values() -> void:
	var state: GameState = _state()
	state.tiles[0].water = 0.013960820753117553
	state.rain_inflows[0] = 0.013960820753117553
	state.forecast_min = 0.013960820753117553
	state.year_mods = [{"key": "flow_rate", "op": "set", "value": 0.013960820753117553}]
	assert_eq(SaveIO.save(state, PATH), "")
	var loaded: Dictionary = SaveIO.load_game(PATH)
	assert_eq(loaded["error"], "")
	if loaded["state"] is GameState:
		assert_eq(loaded["state"].to_dict(), state.to_dict(), "exact bytes survive decimal-reader roundoff")
	var envelope: Dictionary = _envelope(_state().to_dict())
	for malformed: Variant in [null, {}, "bad", []]:
		var candidate: Dictionary = envelope.duplicate(true)
		candidate["float64"] = malformed
		_assert_corrupt(candidate)
	var missing: Dictionary = envelope.duplicate(true)
	missing.erase("float64")
	_assert_corrupt(missing)
	for key: String in ["forecast_min", "forecast_max"]:
		for malformed: Variant in ["00", "g000000000000000", "000000000000f07f", "000000000000f87f", "000000000000f03f", 42, null]:
			var candidate: Dictionary = envelope.duplicate(true)
			candidate["float64"][key] = malformed
			_assert_corrupt(candidate, "float64 " + key)
	for key: String in ["rain_inflows", "tile_water", "year_mod_values"]:
		var candidate: Dictionary = envelope.duplicate(true)
		candidate["float64"][key] = ["0000000000000000"]
		_assert_corrupt(candidate, "float64 count " + key)
	var bad_water: Dictionary = envelope.duplicate(true)
	bad_water["float64"]["tile_water"][0] = "000000000000f0bf"
	_assert_corrupt(bad_water, "negative exact water")


func test_invalid_utf8_and_oversized_files_are_corrupt_without_engine_errors() -> void:
	for bytes: PackedByteArray in [
		PackedByteArray([0xff]), PackedByteArray([0xc2]), PackedByteArray([0xc0, 0x80]),
		PackedByteArray([0xed, 0xa0, 0x80]), PackedByteArray([0xf4, 0x90, 0x80, 0x80]),
		PackedByteArray([0x80]),
	]:
		_write_bytes(bytes)
		assert_eq(SaveIO.load_game(PATH), {"state": null, "error": "msg.save_corrupt"})
		assert_true(not SaveIO.has_save(PATH))
	var envelope: Dictionary = _envelope(_state().to_dict())
	envelope["note"] = "น้ำ 🌧️"
	_write_data(envelope)
	assert_eq(SaveIO.load_game(PATH)["error"], "", "valid multibyte UTF-8 remains accepted")
	var oversized: PackedByteArray = PackedByteArray()
	oversized.resize(SaveIO.MAX_FILE_BYTES + 1)
	oversized.fill(32)
	_write_bytes(oversized)
	assert_eq(SaveIO.load_game(PATH), {"state": null, "error": "msg.save_corrupt"})
	assert_true(not SaveIO.has_save(PATH))
