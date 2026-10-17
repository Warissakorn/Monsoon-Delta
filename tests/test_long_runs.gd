extends TestCase


func _harvest_state(goal: String, population: int = 8) -> GameState:
	var state: GameState = TestMaps.small(2, 4)
	state.village_goal = goal
	state.population = population
	state.food = population
	state.turn = C.TURNS_PER_YEAR
	# Plenty of housing, with exactly enough food to prevent incidental births.
	for index: int in range(6):
		state.tiles[index].building = C.Building.HOUSE
	return state


func test_run_configuration_validates_ids_and_preserves_classic_defaults() -> void:
	var original: GameState = GameFlow.new_game({"seed": 42})
	var explicit: GameState = GameFlow.new_game({"seed": 42, "run_mode": "classic", "village_goal": "none"})
	assert_eq(original.to_dict(), explicit.to_dict())
	assert_eq(original.target_years(), 5)
	assert_eq(original.goal_achieved_year, 0)
	for mode: String in ["classic", "long"]:
		for goal: String in ["none", "growth", "forest", "rice"]:
			var state: GameState = GameFlow.new_game({"seed": 42, "run_mode": mode, "village_goal": goal})
			assert_true(state != null, "%s / %s" % [mode, goal])
			if state != null:
				assert_eq(state.run_mode, mode)
				assert_eq(state.village_goal, goal)
				assert_eq(state.target_years(), 10 if mode == "long" else 5)
	for config: Dictionary in [
		{"run_mode": "endless"}, {"run_mode": 10}, {"run_mode": true},
		{"village_goal": "unknown"}, {"village_goal": 1}, {"village_goal": false},
	]:
		assert_eq(GameFlow.new_game(config), null, "invalid configuration %s" % config)


func test_long_run_tools_stay_unlocked_after_new_year_and_roundtrip() -> void:
	var classic: GameState = GameFlow.new_game({"seed": 42})
	assert_eq(roundi(float(classic.mod("unlock_waterwheel"))), 0)
	assert_eq(roundi(float(classic.mod("unlock_raft_house"))), 0)
	var state: GameState = GameFlow.new_game({"seed": 42, "run_mode": "long", "village_goal": "forest"})
	state.year = 6
	state.goal_achieved_year = 4
	GameFlow.start_year(state)
	var restored: GameState = state.duplicate_state()
	assert_eq(restored.to_dict(), state.to_dict())
	assert_eq(restored.target_years(), 10)
	assert_eq(roundi(float(restored.mod("unlock_waterwheel"))), 1)
	assert_eq(roundi(float(restored.mod("unlock_raft_house"))), 1)
	assert_eq(restored.goal_achieved_year, 4)


func test_legacy_state_defaults_to_five_year_run_without_goal() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42})
	var legacy: Dictionary = state.to_dict()
	for key: String in ["run_mode", "village_goal", "goal_achieved_year"]:
		legacy.erase(key)
	var restored: GameState = GameState.from_dict(legacy)
	assert_eq(restored.to_dict(), state.to_dict())
	assert_eq(restored.target_years(), 5)
	assert_eq(Scoring.score(restored), Scoring.score(state))


func test_first_five_forecasts_match_classic_including_rng_order() -> void:
	for seed_value: int in [-103, 0, 42, 991]:
		var classic: GameState = GameFlow.new_game({"seed": seed_value, "difficulty": 10})
		var longer: GameState = GameFlow.new_game({"seed": seed_value, "difficulty": 10, "run_mode": "long"})
		for year_number: int in range(1, 6):
			classic.year = year_number
			longer.year = year_number
			Forecast.generate(classic)
			Forecast.generate(longer)
			assert_eq(longer.forecast_min, classic.forecast_min)
			assert_eq(longer.forecast_max, classic.forecast_max)
			assert_eq(longer.rain_inflows, classic.rain_inflows)
			assert_eq(longer.rng.state, classic.rng.state)


func test_extended_forecasts_ramp_linearly_and_keep_final_year_modifier() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42, "run_mode": "long", "difficulty": 10})
	for year_number: int in [6, 10]:
		state.year = year_number
		var duplicate: GameState = state.duplicate_state()
		var expected_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		expected_rng.seed = state.rng.seed
		expected_rng.state = state.rng.state
		var multiplier: float = 1.1 * 1.1 * 1.2
		var minimum: float = (22.0 + (year_number - 5) * 2.0) * multiplier
		var maximum: float = (30.0 + (year_number - 5) * 3.0) * multiplier
		var midpoint: float = (minimum + maximum) / 2.0
		var half_range: float = (maximum - minimum) / 2.0 * 1.5
		var total: float = expected_rng.randf_range(midpoint - half_range, midpoint + half_range)
		for _weight: int in range(3):
			expected_rng.randf_range(0.25, 0.45)
		Forecast.generate(state)
		Forecast.generate(duplicate)
		assert_near(state.forecast_min, midpoint - half_range, 0.000001)
		assert_near(state.forecast_max, midpoint + half_range, 0.000001)
		assert_near(state.rain_inflows[0] + state.rain_inflows[1] + state.rain_inflows[2], total, 0.000001)
		assert_eq(state.to_dict(), duplicate.to_dict(), "deterministic year %d" % year_number)
		assert_eq(state.rng.state, expected_rng.state, "exactly one total and three weight draws")


func test_long_run_completes_ten_years_and_does_not_stop_at_five() -> void:
	# A source-free fixture isolates the complete phase sequence from strategy.
	var state: GameState = TestMaps.small(1, 4)
	state.run_mode = "long"
	state.population = 6
	state.food = 1000000
	state.get_tile(Vector2i.ZERO).building = C.Building.HALL
	for tile: Tile in state.tiles:
		if tile.coord != Vector2i.ZERO:
			tile.building = C.Building.HOUSE
	GameFlow.start_year(state)
	for year_number: int in range(1, 11):
		assert_eq(state.year, year_number)
		for turn_number: int in range(1, C.TURNS_PER_YEAR + 1):
			assert_eq(state.turn, turn_number)
			assert_true(GameFlow.end_turn(state) != null)
		assert_eq(state.phase, C.Phase.HARVEST)
		assert_eq(state.outcome, C.Outcome.WIN if year_number == 10 else C.Outcome.NONE)
		GameFlow.continue_after_harvest(state)
		assert_eq(state.phase, C.Phase.GAME_OVER if year_number == 10 else C.Phase.PLANNING)
	assert_eq(state.final_score, Scoring.score(state))


func test_growth_goal_uses_population_after_hunger_and_housing() -> void:
	var state: GameState = _harvest_state("growth", 12)
	state.year = 3
	state.food = 11
	Harvest.do_harvest(state)
	assert_eq(state.population, 11)
	assert_eq(state.goal_achieved_year, 0, "pre-harvest population cannot earn a medal")
	state.population = 12
	state.food = 12
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 3)
	assert_true(bool(RunGoals.progress(state)["achieved"]))
	state.year = 4
	state.population = 5
	state.food = 5
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 3, "first earned year persists after a setback")


func test_forest_goal_requires_eight_mature_forests_and_eight_people() -> void:
	var state: GameState = _harvest_state("forest")
	for index: int in range(6, 13):
		state.tiles[index].feature = C.Feature.FOREST
	state.tiles[13].feature = C.Feature.SAPLING
	Harvest.do_harvest(state)
	assert_eq(RunGoals.progress(state)["forests"], 7)
	assert_eq(state.goal_achieved_year, 0, "saplings are not mature forest")
	state.tiles[13].feature = C.Feature.FOREST
	state.population = 7
	state.food = 7
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 0, "forest alone is insufficient")
	state.population = 8
	state.food = 8
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 1)


func test_rice_goal_uses_actual_single_year_harvest_and_minimum_population() -> void:
	var state: GameState = _harvest_state("rice", 7)
	# Prevent excess harvest from creating births while checking the population gate.
	state.mods["food_per_growth"] = 1000
	state.tiles[6].feature = C.Feature.PADDY
	state.tiles[6].paddy_yield = 17
	Harvest.do_harvest(state)
	assert_eq(state.harvest_report["paddy_food"], 18, "farmer's bonus is part of harvested food")
	assert_eq(state.goal_achieved_year, 0)
	state.population = 8
	state.food = 8
	state.tiles[6].paddy_yield = 16
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 0, "17 food is below the annual target")
	state.food = 8
	state.tiles[6].paddy_yield = 17
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 1)
	assert_eq(RunGoals.progress(state)["required_paddy_food"], 18)


func test_goal_score_is_awarded_once_and_uses_difficulty_multiplier() -> void:
	var state: GameState = _harvest_state("growth", 12)
	state.difficulty = 3
	assert_eq(Scoring.score(state), 172, "unearned goal gives no bonus")
	Harvest.do_harvest(state)
	assert_eq(Scoring.score(state), 221, "(120 population + 50 medal) times 1.3")
	Harvest.do_harvest(state)
	assert_eq(state.goal_achieved_year, 1)
	assert_eq(Scoring.score(state), 65, "earned medal persists even after a later population loss")
	var no_goal: GameState = _harvest_state("none", 12)
	Harvest.do_harvest(no_goal)
	assert_eq(no_goal.goal_achieved_year, 0)
	assert_eq(RunGoals.progress(no_goal)["score"], 0)
	assert_true(not bool(RunGoals.progress(no_goal)["achieved"]))


func test_goal_preview_and_undo_preserve_live_state_and_goal_metadata() -> void:
	var state: GameState = _harvest_state("growth", 12)
	state.run_mode = "long"
	state.rain_inflows = [0.0, 0.0, 0.0]
	var before: Dictionary = state.to_dict()
	var preview: GameState = GameFlow.preview(state)["state"]
	Harvest.do_harvest(preview)
	assert_eq(preview.goal_achieved_year, 1)
	assert_eq(state.to_dict(), before, "preview must not grant the live medal")
	Harvest.do_harvest(state)
	state.turn = 1
	state.year = 2
	GameFlow.start_year(state)
	before = state.to_dict()
	assert_eq(GameFlow.apply_command(state, Command.new("dig", state.tiles[7].coord)), "")
	var restored: GameState = GameFlow.undo(state)
	assert_eq(restored.to_dict(), before)
	assert_eq(restored.run_mode, "long")
	assert_eq(restored.village_goal, "growth")
	assert_eq(restored.goal_achieved_year, 1)
	assert_eq(GameFlow.redo(restored).goal_achieved_year, 1)
