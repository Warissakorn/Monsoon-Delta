extends TestCase
## Moisture supplements irrigation without becoming water or immediate food.


func _paddy(depth: float = 0.0, moisture: int = 0, rain: bool = false) -> GameState:
	var state: GameState = TestMaps.small(0, 1)
	state.ruleset = "moisture_v1"
	state.turn = 4 if rain else 1
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.year_mods.assign([
		{"key": "water_iterations", "op": "set", "value": 1},
		{"key": "dry_inflow", "op": "set", "value": 0},
		{"key": "evaporation_dry", "op": "set", "value": 0},
	])
	state.recompute_mods()
	state.tiles[0].feature = C.Feature.PADDY
	state.tiles[0].water = depth
	state.tiles[0].soil_moisture = moisture
	return state


func _receipt(report: TurnReport, coord: Vector2i = Vector2i.ZERO) -> Dictionary:
	for entry: Dictionary in report.moisture_changes:
		if entry["coord"] == coord:
			return entry
	return {}


func _modifier(state: GameState, key: String, value: float) -> void:
	state.year_mods.append({"key": key, "op": "set", "value": value})
	state.recompute_mods()


func test_rulesets_are_explicit_and_independent_for_new_runs() -> void:
	assert_eq(GameState.RULESETS, ["legacy", "bracing_v1", "moisture_v1", "bracing_moisture_v1"])
	for bracing: bool in [false, true]:
		for moisture: bool in [false, true]:
			var ruleset: String = GameState.ruleset_for(bracing, moisture)
			var state: GameState = GameFlow.new_game({"seed": 42, "ruleset": ruleset})
			assert_true(state != null)
			assert_eq(state.has_bracing(), bracing)
			assert_eq(state.has_moisture(), moisture)
			for tile: Tile in state.tiles:
				assert_eq(tile.soil_moisture, 0)
	for invalid: Variant in ["seasonal_works_v1", "moisture", "MOISTURE_V1", 1, true]:
		assert_eq(GameFlow.new_game({"seed": 42, "ruleset": invalid}), null)


func test_moisture_is_opted_into_tile_and_state_snapshots_only() -> void:
	var state: GameState = _paddy(0.0, 2)
	for ruleset: String in GameState.RULESETS:
		state.ruleset = ruleset
		var data: Dictionary = state.to_dict()
		assert_eq(data.has("ruleset"), ruleset != "legacy")
		assert_eq(data["tiles"][0].has("soil_moisture"), state.has_moisture())
		assert_eq(data["tiles"][0].has("brace_turns"), state.has_bracing())
		var copy: GameState = state.duplicate_state()
		assert_eq(copy.to_dict(), data)
		assert_eq(copy.tiles[0].soil_moisture, 2 if state.has_moisture() else 0)
	assert_true(not state.tiles[0].to_dict().has("soil_moisture"))
	assert_eq(Tile.from_dict(state.tiles[0].to_dict()).soil_moisture, 0)
	assert_eq(state.tiles[0].to_dict(false, true)["soil_moisture"], 2)


func test_suitable_rain_recharges_moisture_and_accumulates_only_one_yield() -> void:
	for initial: int in range(3):
		var state: GameState = _paddy(0.3, initial, true)
		var before_food: int = state.food
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(state.tiles[0].soil_moisture, 2)
		assert_eq(state.tiles[0].paddy_yield, 1)
		assert_eq(state.tiles[0].paddy_rain_turns, 1)
		assert_eq(report.paddy_gains, [Vector2i.ZERO])
		assert_eq(_receipt(report), {"coord": Vector2i.ZERO, "before": initial, "after": 2, "yield_from_moisture": 0})
		assert_eq(state.food, before_food, "paddy yield enters food only at harvest")


func test_unsuitable_rain_decays_moisture_without_using_it_for_yield() -> void:
	for initial: int in range(3):
		var state: GameState = _paddy(0.0, initial, true)
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(state.tiles[0].soil_moisture, maxi(0, initial - 1))
		assert_eq(state.tiles[0].paddy_yield, 0)
		assert_eq(state.tiles[0].paddy_rain_turns, 0)
		assert_true(report.paddy_gains.is_empty())
		assert_eq(_receipt(report)["yield_from_moisture"], 0)


func test_dry_moisture_supports_two_turns_then_stops_without_changing_water_or_food() -> void:
	var state: GameState = _paddy(0.0, 2)
	var before_food: int = state.food
	var before_rng: int = state.rng.state
	for turn: int in range(3):
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(state.tiles[0].soil_moisture, maxi(0, 1 - turn))
		assert_eq(state.tiles[0].paddy_yield, mini(2, turn + 1))
		assert_eq(state.tiles[0].paddy_rain_turns, 0)
		assert_eq(_receipt(report)["yield_from_moisture"], 1 if turn < 2 else 0)
		assert_eq(report.dry_paddy_water_used, 0.0)
		assert_eq(state.tiles[0].water, 0.0)
		assert_eq(state.food, before_food)
		assert_eq(state.rng.state, before_rng)


func test_dry_paddy_does_not_gain_moisture_from_surface_water() -> void:
	var state: GameState = _paddy(0.3)
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(state.tiles[0].soil_moisture, 0)
	assert_eq(state.tiles[0].paddy_yield, 0)
	assert_true(report.paddy_gains.is_empty())
	assert_eq(_receipt(report)["after"], 0)


func test_reservoir_is_used_first_without_double_yield_or_free_water() -> void:
	var state: GameState = TestMaps.small(1, 1)
	state.ruleset = "moisture_v1"
	state.turn = 1
	for tile: Tile in state.tiles:
		tile.water = 0.6
	state.tiles[0].feature = C.Feature.PADDY
	state.tiles[0].soil_moisture = 2
	state.tiles[1].building = C.Building.RESERVOIR
	_modifier(state, "evaporation_dry", 0.0)
	_modifier(state, "paddy_death_level", 4.0)
	var legacy: GameState = state.duplicate_state()
	legacy.ruleset = "legacy"
	legacy.tiles[0].soil_moisture = 0
	var report: TurnReport = TurnResolver.resolve_turn(state)
	var original: TurnReport = TurnResolver.resolve_turn(legacy)
	assert_eq(state.tiles[0].paddy_yield, 1)
	assert_eq(state.tiles[0].soil_moisture, 1)
	assert_eq(_receipt(report, state.tiles[0].coord)["yield_from_moisture"], 0)
	assert_eq(report.paddy_gains.size(), 1)
	assert_eq(report.dry_paddy_water_used, 0.25)
	assert_eq(report.dry_paddy_water_used, original.dry_paddy_water_used)
	for index: int in range(state.tiles.size()):
		assert_eq(state.tiles[index].water, legacy.tiles[index].water)


func test_shared_reservoir_exhaustion_falls_back_only_for_the_next_paddy() -> void:
	var state: GameState = TestMaps.small(1, 1)
	state.ruleset = "moisture_v1"
	for tile: Tile in state.tiles:
		tile.water = 0.6
	var reservoir: Tile = state.get_tile(Vector2i.ZERO)
	reservoir.building = C.Building.RESERVOIR
	var paddies: Array[Tile] = []
	for tile: Tile in state.tiles:
		if tile != reservoir and paddies.size() < 2:
			tile.feature = C.Feature.PADDY
			tile.soil_moisture = 2
			paddies.append(tile)
	_modifier(state, "evaporation_dry", 0.0)
	_modifier(state, "paddy_death_level", 4.0)
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(report.dry_paddy_water_used, 0.25)
	assert_eq(report.paddy_gains.size(), 2)
	assert_eq(_receipt(report, paddies[0].coord)["yield_from_moisture"], 0)
	assert_eq(_receipt(report, paddies[1].coord)["yield_from_moisture"], 1)
	for tile: Tile in paddies:
		assert_eq(tile.paddy_yield, 1)
		assert_eq(tile.soil_moisture, 1)
	assert_eq(reservoir.water, 0.35)


func test_insufficient_reservoir_uses_moisture_without_spending_any_reservoir_water() -> void:
	var state: GameState = TestMaps.small(1, 1)
	state.ruleset = "moisture_v1"
	for tile: Tile in state.tiles:
		tile.water = 0.3
	state.tiles[0].feature = C.Feature.PADDY
	state.tiles[0].soil_moisture = 1
	state.tiles[1].building = C.Building.RESERVOIR
	_modifier(state, "evaporation_dry", 0.0)
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(state.tiles[0].paddy_yield, 1)
	assert_eq(state.tiles[0].soil_moisture, 0)
	assert_eq(report.dry_paddy_water_used, 0.0)
	assert_eq(state.tiles[1].water, 0.3)
	assert_eq(_receipt(report, state.tiles[0].coord)["yield_from_moisture"], 1)


func test_water_damage_clears_moisture_before_production() -> void:
	var state: GameState = _paddy(0.6, 2, true)
	state.tiles[0].paddy_yield = 3
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_true(state.tiles[0].paddy_dead)
	assert_eq(state.tiles[0].soil_moisture, 0)
	assert_eq(state.tiles[0].paddy_yield, 0)
	assert_eq(report.paddies_died, [Vector2i.ZERO])
	assert_eq(_receipt(report), {"coord": Vector2i.ZERO, "before": 2, "after": 0, "yield_from_moisture": 0})
	var next: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(next.moisture_changes.size(), 1)
	assert_eq(_receipt(next)["after"], 0)
	assert_true(next.paddies_died.is_empty())


func test_hall_loss_clears_dead_paddies_but_skips_surviving_moisture_updates() -> void:
	var state: GameState = _paddy(0.3, 1, true)
	# Disconnected cells isolate the damage branches from water redistribution.
	var hall := Tile.new(3, 0)
	hall.building = C.Building.HALL
	hall.water = 0.6
	var doomed := Tile.new(6, 0)
	doomed.feature = C.Feature.PADDY
	doomed.water = 0.6
	doomed.soil_moisture = 2
	state.tiles.append_array([hall, doomed])
	state.rebuild_index()
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_eq(state.tiles[0].soil_moisture, 1, "rain recharge is skipped after hall loss")
	assert_eq(state.tiles[0].paddy_yield, 0)
	assert_eq(doomed.soil_moisture, 0)
	assert_eq(report.moisture_changes.size(), 2)
	assert_eq(_receipt(report)["before"], _receipt(report)["after"])
	assert_eq(_receipt(report, doomed.coord)["after"], 0)
	assert_true(report.paddy_gains.is_empty())


func test_harvest_and_next_year_keep_living_moisture_until_dry_turn_uses_it() -> void:
	var state: GameState = TestMaps.small(1, 1)
	state.ruleset = "moisture_v1"
	state.turn = C.TURNS_PER_YEAR
	state.food = 100
	state.population = 2
	for tile: Tile in state.tiles:
		tile.water = 0.3
		tile.building = C.Building.RAFT_HOUSE
	state.tiles[0].building = C.Building.NONE
	state.tiles[0].feature = C.Feature.PADDY
	GameFlow.end_turn(state)
	assert_eq(state.phase, C.Phase.HARVEST)
	assert_eq(state.tiles[0].soil_moisture, 2)
	GameFlow.continue_after_harvest(state)
	assert_eq(state.year, 2)
	assert_eq(state.turn, 1)
	assert_eq(state.tiles[0].paddy_yield, 0)
	assert_eq(state.tiles[0].paddy_rain_turns, 0)
	assert_eq(state.tiles[0].soil_moisture, 2)
	var report: TurnReport = GameFlow.end_turn(state)
	assert_eq(state.tiles[0].paddy_yield, 1)
	assert_eq(state.tiles[0].soil_moisture, 1)
	assert_eq(_receipt(report, state.tiles[0].coord)["yield_from_moisture"], 1)


func test_year_reset_does_not_restore_dead_paddy_moisture() -> void:
	var state: GameState = _paddy(0.0, 2)
	state.tiles[0].paddy_dead = true
	GameFlow.start_year(state)
	assert_true(not state.tiles[0].paddy_dead)
	assert_eq(state.tiles[0].soil_moisture, 0)


func test_earthworks_preserve_moisture_and_demolish_undo_redo_restore_it_exactly() -> void:
	var state: GameState = _paddy(0.0, 2)
	state.labor = 100
	for id: String in ["dig", "fill"]:
		assert_eq(GameFlow.apply_command(state, Command.new(id, Vector2i.ZERO)), "")
		assert_eq(state.tiles[0].soil_moisture, 2)
	var before: Dictionary = state.to_dict()
	var rng_before: int = state.rng.state
	assert_eq(GameFlow.apply_command(state, Command.new("demolish", Vector2i.ZERO)), "")
	assert_eq(state.tiles[0].feature, C.Feature.NONE)
	assert_eq(state.tiles[0].soil_moisture, 0)
	var demolished: Dictionary = state.to_dict()
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), before)
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), demolished)
	assert_eq(GameFlow.apply_command(state, Command.new("paddy", Vector2i.ZERO)), "")
	assert_eq(state.tiles[0].soil_moisture, 0)
	assert_eq(state.rng.state, rng_before)


func test_preview_and_quiet_resolution_match_exact_state_and_semantic_receipts() -> void:
	var state: GameState = _paddy(0.0, 2)
	var before: Dictionary = state.to_dict()
	var rng_before: int = state.rng.state
	var prediction: Dictionary = GameFlow.preview(state)
	assert_eq(state.to_dict(), before)
	assert_eq(state.rng.state, rng_before)
	assert_true(state.undo.is_empty())
	assert_true(state.redo.is_empty())
	var quiet: GameState = state.duplicate_state()
	var quiet_report: TurnReport = TurnResolver.resolve_turn(quiet, false)
	var actual: TurnReport = TurnResolver.resolve_turn(state, true)
	assert_eq(state.to_dict(), prediction["state"].to_dict())
	assert_eq(state.to_dict(), quiet.to_dict())
	assert_eq(actual.moisture_changes, prediction["report"].moisture_changes)
	assert_eq(actual.moisture_changes, quiet_report.moisture_changes)
	assert_true(quiet_report.snapshots.is_empty())
	assert_eq(actual.to_dict()["moisture_changes"][0]["coord"], [0, 0])
	assert_eq(state.rng.state, rng_before)


func test_legacy_and_bracing_reports_and_yields_keep_existing_behavior() -> void:
	for ruleset: String in ["legacy", "bracing_v1"]:
		for rain: bool in [false, true]:
			var state: GameState = _paddy(0.3, 0, rain)
			state.ruleset = ruleset
			var report: TurnReport = TurnResolver.resolve_turn(state)
			assert_eq(state.tiles[0].paddy_yield, 1 if rain else 0)
			assert_eq(state.tiles[0].soil_moisture, 0)
			assert_true(report.moisture_changes.is_empty())
			assert_true(not report.to_dict().has("moisture_changes"))
			assert_true(not state.to_dict()["tiles"][0].has("soil_moisture"))


func test_combined_ruleset_keeps_brace_and_moisture_semantics_independent() -> void:
	var state: GameState = _paddy(0.0, 2)
	state.ruleset = "bracing_moisture_v1"
	var house := Tile.new(3, 0)
	house.building = C.Building.HOUSE
	house.water = 0.3
	state.tiles.append(house)
	state.rebuild_index()
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", house.coord)), "")
	var before: Dictionary = state.to_dict()
	var prediction: Dictionary = GameFlow.preview(state)
	assert_eq(state.to_dict(), before)
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_true(report.brace_results[0]["prevented_loss"])
	assert_eq(house.building, C.Building.HOUSE)
	assert_eq(house.brace_turns, 0)
	assert_eq(_receipt(report)["yield_from_moisture"], 1)
	assert_eq(state.to_dict(), prediction["state"].to_dict())
