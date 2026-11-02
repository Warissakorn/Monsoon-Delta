extends TestCase
const F = preload("res://tools/irrigation_fixtures.gd")


func _choose(state: GameState, coord: Vector2i, policy: String) -> String:
	return GameFlow.apply_command(state, Command.new("irrigation_policy", coord, Irrigation.POLICIES.find(policy)))


func _legacy_data(state: GameState) -> Dictionary:
	var data: Dictionary = state.to_dict()
	for tile: Dictionary in data["tiles"]:
		tile.erase("irrigation_policy")
	var ruleset: String = GameState.ruleset_for(state.has_bracing(), state.has_moisture())
	if ruleset == "legacy":
		data.erase("ruleset")
	else:
		data["ruleset"] = ruleset
	return data


func test_all_eight_ruleset_combinations_are_independent_and_opt_in() -> void:
	assert_eq(GameState.RULESETS.size(), 8)
	for bracing: bool in [false, true]:
		for moisture: bool in [false, true]:
			for priorities: bool in [false, true]:
				var state: GameState = GameFlow.new_game({"ruleset": GameState.ruleset_for(bracing, moisture, priorities)})
				assert_true(state != null)
				assert_eq(state.has_bracing(), bracing)
				assert_eq(state.has_moisture(), moisture)
				assert_eq(state.has_irrigation(), priorities)
				assert_eq(state.to_dict()["tiles"][0].has("irrigation_policy"), priorities)


func test_normal_allocation_is_exactly_the_previous_resolver_for_seeded_states() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 492
	for bracing: bool in [false, true]:
		for moisture: bool in [false, true]:
			for sample: int in range(12):
				var state: GameState = GameFlow.new_game({"seed": sample, "ruleset": GameState.ruleset_for(bracing, moisture, true)})
				state.turn = sample % 6 + 1
				for tile: Tile in state.tiles:
					if tile.building != C.Building.NONE:
						continue
					tile.water = random.randf_range(0.0, 1.1)
					if random.randf() < 0.4:
						tile.building = C.Building.RESERVOIR
						tile.feature = C.Feature.NONE
					else:
						tile.feature = C.Feature.PADDY
						tile.soil_moisture = random.randi_range(0, 2) if moisture else 0
				var baseline: GameState = GameState.from_dict(_legacy_data(state))
				var actual: TurnReport = TurnResolver.resolve_turn(state, false)
				var original: TurnReport = TurnResolver.resolve_turn(baseline, false)
				assert_eq(_legacy_data(state), baseline.to_dict(), "all-normal state, float64 and RNG remain exact")
				var receipt: Dictionary = actual.to_dict()
				receipt.erase("irrigation_results")
				assert_eq(receipt, original.to_dict(), "legacy receipts stay exact apart from new allocation telemetry")


func test_scarce_water_can_feed_three_fields_when_moisture_covers_the_skipped_field() -> void:
	var normal: GameState = F.create()
	var allocated: GameState = normal.duplicate_state()
	assert_eq(_choose(allocated, F.FIELDS[0], "skip"), "")
	assert_eq(_choose(allocated, F.FIELDS[1], "first"), "")
	assert_eq(_choose(allocated, F.FIELDS[2], "first"), "")
	var original: TurnReport = TurnResolver.resolve_turn(normal, false)
	var report: TurnReport = TurnResolver.resolve_turn(allocated, false)
	assert_eq(original.paddy_gains.size(), 2)
	assert_eq(report.paddy_gains.size(), 3)
	assert_eq(report.dry_paddy_water_used, 0.5)
	assert_eq(allocated.get_tile(F.RESERVOIR).water, 0.25)
	assert_eq(report.irrigation_results[0]["coord"], F.FIELDS[1])
	assert_eq(report.irrigation_results[0]["water_before"], 0.75, "allocation starts after evaporation")
	assert_eq(report.irrigation_results[1]["water_before"], 0.5)
	assert_eq(report.irrigation_results[2]["source"], "moisture")
	assert_eq(allocated.get_tile(F.FIELDS[0]).soil_moisture, 0)
	for coord: Vector2i in F.FIELDS:
		assert_eq(allocated.get_tile(coord).paddy_yield, 1, "no duplicate reservoir/moisture yield")


func test_skip_conserves_only_production_water_and_can_be_replanned_next_turn() -> void:
	var state: GameState = F.create("irrigation_v1")
	for coord: Vector2i in F.FIELDS:
		assert_eq(_choose(state, coord, "skip"), "")
	var first: TurnReport = GameFlow.end_turn(state)
	assert_eq(first.paddy_gains.size(), 0)
	assert_eq(state.get_tile(F.RESERVOIR).water, 0.75, "skip does not prevent evaporation")
	assert_eq(_choose(state, F.FIELDS[2], "first"), "")
	var second: TurnReport = GameFlow.end_turn(state)
	assert_eq(second.paddy_gains, [F.FIELDS[2]])
	assert_eq(state.get_tile(F.RESERVOIR).water, 0.25)
	assert_eq(state.get_tile(F.FIELDS[0]).irrigation_policy, "skip")


func test_policy_changes_are_free_validated_and_exactly_undoable() -> void:
	var state: GameState = F.create()
	var before: Dictionary = state.to_dict()
	assert_eq(_choose(state, F.FIELDS[0], "skip"), "")
	var after: Dictionary = state.to_dict()
	assert_eq(state.labor, before["labor"])
	assert_eq(state.wood, before["wood"])
	assert_eq(state.rng.state, String(before["rng_state"]).to_int())
	assert_eq(_choose(state, F.FIELDS[0], "skip"), "err.irrigation_same")
	assert_eq(state.undo.size(), 1)
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), before)
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), after)
	assert_eq(_choose(state, F.HALL, "first"), "err.target")
	assert_eq(CommandRules.check(state, Command.new("irrigation_policy", F.FIELDS[0], -1)), "err.param")
	state.turn = 4
	assert_eq(_choose(state, F.FIELDS[0], "normal"), "err.season")
	state.turn = 1
	state.phase = C.Phase.HARVEST
	assert_eq(_choose(state, F.FIELDS[0], "normal"), "err.phase")
	state.phase = C.Phase.PLANNING
	state.ruleset = "moisture_v1"
	assert_eq(_choose(state, F.FIELDS[0], "normal"), "err.locked")


func test_policies_survive_years_but_reset_on_death_demolition_and_replanting() -> void:
	var state: GameState = F.create()
	assert_eq(_choose(state, F.FIELDS[0], "skip"), "")
	GameFlow.start_year(state)
	assert_eq(state.get_tile(F.FIELDS[0]).irrigation_policy, "skip")
	assert_eq(GameFlow.apply_command(state, Command.new("demolish", F.FIELDS[0])), "")
	assert_eq(state.get_tile(F.FIELDS[0]).irrigation_policy, "normal")
	assert_eq(GameFlow.apply_command(state, Command.new("paddy", F.FIELDS[0])), "")
	assert_eq(_choose(state, F.FIELDS[0], "first"), "")
	state.get_tile(F.FIELDS[0]).water = 0.8
	state.get_tile(F.FIELDS[0]).elevation = 0
	state.turn = 4
	TurnResolver.resolve_turn(state, false)
	assert_true(state.get_tile(F.FIELDS[0]).paddy_dead)
	assert_eq(state.get_tile(F.FIELDS[0]).irrigation_policy, "normal")


func test_rain_dormancy_ignores_priorities_and_hall_loss_skips_all_allocation() -> void:
	var state: GameState = F.create()
	assert_eq(_choose(state, F.FIELDS[0], "skip"), "")
	state.turn = 4
	state.get_tile(F.FIELDS[0]).water = 0.3
	state.get_tile(F.FIELDS[0]).elevation = 0
	state.get_tile(F.RESERVOIR).water = 0.0
	var report: TurnReport = TurnResolver.resolve_turn(state, false)
	assert_eq(report.paddy_gains, [F.FIELDS[0]])
	assert_true(report.irrigation_results.is_empty())
	assert_eq(state.get_tile(F.FIELDS[0]).irrigation_policy, "skip")
	state = F.create()
	state.get_tile(F.HALL).water = 1.0
	state.get_tile(F.HALL).elevation = 0
	report = TurnResolver.resolve_turn(state, false)
	assert_eq(state.outcome, C.Outcome.LOSE_HALL)
	assert_true(report.irrigation_results.is_empty())
	assert_true(report.paddy_gains.is_empty())


func test_preview_is_read_only_and_matches_commit_including_mass_balance_and_telemetry() -> void:
	var state: GameState = F.create()
	assert_eq(_choose(state, F.FIELDS[2], "first"), "")
	var before: Dictionary = state.to_dict()
	var plan: Dictionary = Irrigation.plan(state)
	assert_eq(state.to_dict(), before)
	assert_true(not plan["receipts"].is_empty())
	var prediction: Dictionary = GameFlow.preview(state)
	assert_eq(state.to_dict(), before)
	var before_water: float = 0.0
	for tile: Tile in state.tiles:
		before_water += tile.water
	var report: TurnReport = GameFlow.end_turn(state)
	assert_eq(report.to_dict(), (prediction["report"] as TurnReport).to_dict())
	var predicted: GameState = prediction["state"]
	for index: int in range(state.tiles.size()):
		assert_eq(state.tiles[index].to_dict(false, true, true), predicted.tiles[index].to_dict(false, true, true))
	var after_water: float = 0.0
	for tile: Tile in state.tiles:
		after_water += tile.water
	assert_near(after_water, before_water + report.inflow - report.to_sea + report.from_sea - report.evaporated - report.absorbed - report.dry_paddy_water_used, 0.000001)


func test_full_and_reduced_visual_recording_produce_identical_semantic_receipts() -> void:
	var state: GameState = F.create()
	assert_eq(_choose(state, F.FIELDS[1], "first"), "")
	var copy: GameState = state.duplicate_state()
	var full: TurnReport = TurnResolver.resolve_turn(state, true)
	var reduced: TurnReport = TurnResolver.resolve_turn(copy, false)
	assert_eq(full.irrigation_results, reduced.irrigation_results)
	assert_eq(state.to_dict(), copy.to_dict())


func test_invalid_targets_match_full_command_validation_and_bots_see_all_policies() -> void:
	var state: GameState = F.create()
	for parameter: int in [-1, 0, 1, 2, 3]:
		var expected: Array[Vector2i] = []
		for tile: Tile in state.tiles:
			if CommandRules.check(state, Command.new("irrigation_policy", tile.coord, parameter)).is_empty():
				expected.append(tile.coord)
		assert_eq(CommandRules.valid_targets(state, "irrigation_policy", parameter), expected)
	var policies: int = 0
	for command: Command in BotGreedy.legal_commands(state):
		assert_eq(CommandRules.check(state, command), "")
		if command.id == "irrigation_policy":
			policies += 1
	assert_eq(policies, 6)
	for command: Command in BotGreedy.legal_commands(state, ["dig"]):
		assert_eq(command.id, "dig", "a caller's restricted command catalog remains respected")


func test_reservoir_choice_uses_remaining_water_stable_ties_and_adjacent_sources_only() -> void:
	var state: GameState = F.create("irrigation_v1")
	for coord: Vector2i in F.FIELDS:
		assert_eq(_choose(state, coord, "skip"), "")
	var target: Vector2i = F.FIELDS[1]
	assert_eq(_choose(state, target, "first"), "")
	var second: Tile = state.get_tile(Vector2i(2, -1))
	second.building = C.Building.RESERVOIR
	second.water = 1.0
	var receipt: Dictionary = Irrigation.plan(state)["by_tile"][target]
	assert_eq(receipt["reservoir"], F.RESERVOIR, "equal pools use the earlier tile index")
	second.water = 1.1
	receipt = Irrigation.plan(state)["by_tile"][target]
	assert_eq(receipt["reservoir"], second.coord)
	var far: Tile = state.get_tile(Vector2i(4, -4))
	far.feature = C.Feature.PADDY
	far.irrigation_policy = "first"
	receipt = Irrigation.plan(state)["by_tile"][far.coord]
	assert_eq(receipt["source"], "none")
	assert_eq(receipt["reason"], "no_reservoir")


func test_minimum_is_checked_before_each_draw_and_water_use_never_exceeds_available_water() -> void:
	var state: GameState = F.create("irrigation_v1")
	state.get_tile(F.RESERVOIR).water = 0.5
	var plan: Dictionary = Irrigation.plan(state)
	assert_eq(plan["receipts"][0]["source"], "reservoir")
	assert_eq(plan["receipts"][1]["reason"], "insufficient_water")
	assert_eq(plan["reservoir_water"][F.RESERVOIR], 0.25)
	state.get_tile(F.RESERVOIR).water = 0.5 - 2.0 * C.EPS
	assert_eq(Irrigation.plan(state)["receipts"][0]["source"], "none")
	state.get_tile(F.RESERVOIR).water = 0.5
	state.year_mods.append({"key": "dry_paddy_water_use", "op": "set", "value": 0.75})
	state.recompute_mods()
	plan = Irrigation.plan(state)
	assert_eq(plan["receipts"][0]["water_used"], 0.5)
	assert_eq(plan["reservoir_water"][F.RESERVOIR], 0.0)
