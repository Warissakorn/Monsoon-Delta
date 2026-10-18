extends TestCase

const PATH: String = "user://test_settlement_progress.json"


func before_each() -> void:
	SaveIO.delete_save(PATH)


func _state() -> GameState:
	return GameFlow.new_game({"seed": 42, "living_village": true})


func _home(s: GameState) -> Tile:
	for tile: Tile in s.tiles:
		if tile.building == C.Building.HOUSE:
			return tile
	return null


func _evaluate(s: GameState, year: int, comfortable: bool) -> void:
	s.year = year
	s.turn = C.TURNS_PER_YEAR
	s.food = 1000 if comfortable else 0
	s.wood = 100 if comfortable else 0
	s.harvest_report = {"left_hunger": 0 if comfortable else 1, "left_housing": 0}
	SettlementProgress.evaluate_year(s)


func _legacy_fields(s: GameState) -> Dictionary:
	var data: Dictionary = s.to_dict()
	data.erase("settlement_progress")
	return data


func _flat(s: GameState) -> void:
	for tile: Tile in s.tiles:
		tile.elevation = 4
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	s.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		s.tiles[index].building = C.Building.HOUSE
	s.food = 1000
	s.wood = 100
	SettlementProgress.reconcile(s)


func test_opt_in_does_not_change_legacy_state_or_random_stream() -> void:
	var old: GameState = GameFlow.new_game({"seed": 42})
	var living: GameState = _state()
	assert_true(not SettlementProgress.enabled(old))
	assert_true(not old.to_dict().has("settlement_progress"))
	assert_eq(_legacy_fields(living), old.to_dict())
	assert_eq(GameFlow.new_game({"living_village": "true"}), null)
	var before: Dictionary = living.to_dict()
	for tile: Tile in living.tiles:
		SettlementProgress.condition_key(living)
		SettlementProgress.building_age(living, tile)
		SettlementProgress.building_stage(living, tile)
	assert_eq(living.to_dict(), before, "view reads cannot age buildings or advance RNG")


func test_two_harvests_change_condition_and_mature_buildings_gradually() -> void:
	var s: GameState = _state()
	var home: Tile = _home(s)
	_evaluate(s, 1, true)
	assert_eq(SettlementProgress.condition(s), SettlementProgress.Condition.STABLE)
	assert_eq(SettlementProgress.building_stage(s, home), 0)
	var once: Dictionary = s.to_dict()
	SettlementProgress.evaluate_year(s)
	assert_eq(s.to_dict(), once, "a harvest cannot be evaluated twice")
	_evaluate(s, 2, true)
	assert_eq(SettlementProgress.condition_key(s), "settlement.thriving")
	assert_eq(SettlementProgress.building_age(s, home), 1)
	assert_eq(SettlementProgress.building_stage(s, home), 1)
	_evaluate(s, 3, true)
	assert_eq(SettlementProgress.building_stage(s, home), 2)
	_evaluate(s, 4, true)
	assert_eq(SettlementProgress.building_stage(s, home), 2, "development is bounded")


func test_poor_years_change_condition_then_reduce_development_gradually() -> void:
	var s: GameState = _state()
	var home: Tile = _home(s)
	for year: int in range(1, 4):
		_evaluate(s, year, true)
	_evaluate(s, 4, false)
	assert_eq(SettlementProgress.condition(s), SettlementProgress.Condition.THRIVING)
	_evaluate(s, 5, false)
	assert_eq(SettlementProgress.condition(s), SettlementProgress.Condition.STABLE)
	assert_eq(SettlementProgress.building_stage(s, home), 2)
	_evaluate(s, 6, false)
	_evaluate(s, 7, false)
	assert_eq(SettlementProgress.condition_key(s), "settlement.struggling")
	assert_eq(SettlementProgress.building_stage(s, home), 1)
	_evaluate(s, 8, false)
	assert_eq(SettlementProgress.building_stage(s, home), 0)


func test_successful_construction_demolition_and_undo_keep_exact_birth_dates() -> void:
	var s: GameState = _state()
	s.labor = 100
	s.labor_max = 100
	s.wood = 100
	var target: Vector2i = CommandRules.valid_targets(s, "house")[0]
	var before: Dictionary = s.to_dict()
	assert_eq(GameFlow.apply_command(s, Command.new("house", target)), "")
	var built: Dictionary = s.to_dict()
	s = GameFlow.undo(s)
	assert_eq(s.to_dict(), before)
	s = GameFlow.redo(s)
	assert_eq(s.to_dict(), built)
	s.year = 2
	s.turn = 2
	assert_eq(SettlementProgress.building_age(s, s.get_tile(target)), 1)
	assert_eq(GameFlow.apply_command(s, Command.new("demolish", target)), "")
	assert_true(not s.settlement_progress["buildings"].has("%d,%d" % [target.x, target.y]))
	assert_eq(GameFlow.apply_command(s, Command.new("house", target)), "")
	var record: Dictionary = s.settlement_progress["buildings"]["%d,%d" % [target.x, target.y]]
	assert_eq(record["built_year"], 2)
	assert_eq(record["built_turn"], 2)
	assert_eq(SettlementProgress.building_age(s, s.get_tile(target)), 0, "rebuilding the same house resets its age")


func test_damage_reconciliation_removes_destroyed_building_history() -> void:
	var s: GameState = TestMaps.small(1, 0)
	s.get_tile(Vector2i.ZERO).building = C.Building.HOUSE
	SettlementProgress.initialize(s)
	for tile: Tile in s.tiles:
		tile.water = 3.0
	var report: TurnReport = TurnResolver.resolve_turn(s)
	assert_eq(report.destroyed.size(), 1)
	assert_eq(s.get_tile(Vector2i.ZERO).building, C.Building.NONE)
	assert_true(s.settlement_progress["buildings"].is_empty())
	assert_eq(SettlementProgress.building_stage(s, s.get_tile(Vector2i.ZERO)), 0)


func test_preview_and_committed_turn_preserve_the_same_visual_history() -> void:
	var s: GameState = _state()
	var before: Dictionary = s.to_dict()
	var preview: Dictionary = GameFlow.preview(s)
	assert_eq(s.to_dict(), before)
	var expected: GameState = preview["state"]
	GameFlow.end_turn(s)
	assert_eq(s.settlement_progress, expected.settlement_progress)


func test_cosmetic_history_never_changes_rules_resources_capacity_or_score() -> void:
	for seed_value: int in range(1, 5):
		var classic: GameState = GameFlow.new_game({"seed": seed_value})
		var living: GameState = GameFlow.new_game({"seed": seed_value, "living_village": true})
		_flat(classic)
		_flat(living)
		for _turn: int in range(12):
			if classic.phase == C.Phase.HARVEST:
				GameFlow.continue_after_harvest(classic)
				GameFlow.continue_after_harvest(living)
			var expected: TurnReport = GameFlow.end_turn(classic)
			var actual: TurnReport = GameFlow.end_turn(living)
			assert_eq(actual.to_dict(), expected.to_dict())
			assert_eq(_legacy_fields(living), classic.to_dict(), "visual updates cannot change simulation state")
			assert_eq(living.capacity(), classic.capacity())
			assert_eq(Scoring.score(living), Scoring.score(classic))


func test_v3_roundtrip_keeps_visual_history_float64_and_rng_without_rewriting() -> void:
	var s: GameState = _state()
	s.tiles[0].water = 0.013960820753117553
	s.rain_inflows[0] = 0.013960820753117553
	s.rng.randi()
	var before: Dictionary = s.to_dict()
	assert_eq(SaveIO.save(s, PATH), "")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var envelope: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	assert_eq(envelope["version"], 3.0)
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	assert_true(result["state"] is GameState)
	if result["state"] is GameState:
		var restored: GameState = result["state"]
		assert_eq(restored.to_dict(), before)
		assert_true(restored.undo.is_empty())
		assert_eq(restored.rng.randi(), s.rng.randi())
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes, "loading cannot rewrite or upgrade a checkpoint")
	SaveIO.delete_save(PATH)


func test_legacy_v1_and_v2_remain_disabled_and_keep_original_envelopes() -> void:
	for mode: String in ["classic", "long"]:
		var s: GameState = GameFlow.new_game({"seed": 42, "run_mode": mode})
		assert_eq(SaveIO.save(s, PATH), "")
		var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var result: Dictionary = SaveIO.load_game(PATH)
		assert_eq(result["error"], "")
		if result["state"] is GameState:
			assert_true(not SettlementProgress.enabled(result["state"]))
			assert_eq(result["state"].to_dict(), s.to_dict())
		assert_eq(FileAccess.get_file_as_bytes(PATH), before)
		var envelope: Dictionary = JSON.parse_string(before.get_string_from_utf8())
		assert_eq(envelope["version"], 1.0 if mode == "classic" else 2.0)
	SaveIO.delete_save(PATH)


func test_v3_rejects_missing_future_or_mismatched_building_records() -> void:
	var original: Dictionary = _state().to_dict()
	var progress: Dictionary = original["settlement_progress"]
	var key: String = String(progress["buildings"].keys()[0])
	for change: Dictionary in [
		{"field": "condition", "value": "rich"},
		{"field": "candidate_years", "value": 2},
		{"field": "buildings", "value": {}},
		{"field": "evaluated_year", "value": 2},
	]:
		var data: Dictionary = original.duplicate(true)
		data["settlement_progress"][change["field"]] = change["value"]
		assert_true(not SaveIO._valid_state(data), String(change["field"]))
	for change: Dictionary in [
		{"field": "built_year", "value": 2},
		{"field": "built_turn", "value": 2},
		{"field": "building", "value": "none"},
		{"field": "stage", "value": 1},
	]:
		var data: Dictionary = original.duplicate(true)
		data["settlement_progress"]["buildings"][key][change["field"]] = change["value"]
		assert_true(not SaveIO._valid_state(data), String(change["field"]))
	for envelope_version: int in [1, 2, 3]:
		var data: Dictionary = original.duplicate(true)
		if envelope_version == 3:
			data.erase("settlement_progress")
		var envelope: Dictionary = {
			"format": "monsoon_save", "version": envelope_version,
			"state": data, "float64": SaveIO._encode_float64(data),
		}
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(envelope, "", true, true))
		file.close()
		assert_eq(SaveIO.load_game(PATH)["error"], "msg.save_corrupt")


func test_reload_each_turn_and_harvest_keeps_enabled_history_exact() -> void:
	var s: GameState = _state()
	_flat(s)
	for _turn: int in range(18):
		if s.phase == C.Phase.HARVEST:
			GameFlow.continue_after_harvest(s)
		GameFlow.end_turn(s)
		var before: Dictionary = s.to_dict()
		assert_eq(SaveIO.save(s, PATH), "")
		var result: Dictionary = SaveIO.load_game(PATH)
		assert_eq(result["error"], "")
		if not result["state"] is GameState:
			return
		s = result["state"]
		assert_eq(s.to_dict(), before, "annual evaluation and visual stages survive every checkpoint")
	assert_eq(SettlementProgress.condition(s), SettlementProgress.Condition.THRIVING)
	assert_eq(SettlementProgress.building_stage(s, _home(s)), 2)
	SaveIO.delete_save(PATH)


func test_actual_harvest_food_by_tile_is_pure_and_totals_exact_food() -> void:
	var s: GameState = _state()
	var targets: Array[Vector2i] = CommandRules.valid_targets(s, "paddy")
	var alive: Tile = s.get_tile(targets[0])
	alive.feature = C.Feature.PADDY
	alive.paddy_yield = 3
	alive.paddy_rain_turns = 3
	var dead: Tile = s.get_tile(targets[1])
	dead.feature = C.Feature.PADDY
	dead.paddy_yield = 9
	dead.paddy_dead = true
	var before: Dictionary = s.to_dict()
	var actual: Dictionary = Harvest.paddy_food_by_tile(s)
	assert_eq(s.to_dict(), before)
	assert_eq(actual.size(), 1)
	assert_eq(actual[alive.coord], 4)
	Harvest.do_harvest(s)
	assert_eq(s.harvest_report["paddy_food"], actual[alive.coord])
	assert_eq(Harvest.paddy_food_by_tile(s), actual)


func test_session_harvest_locations_are_transient_and_clear_on_reload() -> void:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	assert_eq(session.start({"seed": 42, "living_village": true}), "")
	_flat(session.state)
	var s: GameState = session.state
	s.turn = C.TURNS_PER_YEAR
	var paddy: Tile = s.tiles[4]
	paddy.feature = C.Feature.PADDY
	paddy.paddy_yield = 2
	session.advance_turn()
	assert_eq(session.last_harvest_food_by_tile, {paddy.coord: 3})
	assert_true(not s.to_dict().has("last_harvest_food_by_tile"))
	assert_eq(session.load_game(), "")
	assert_true(session.last_harvest_food_by_tile.is_empty())
	SaveIO.delete_save(PATH)
