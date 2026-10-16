extends TestCase


func test_new_game_initializes_resources_rng_and_base_game_phase() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42, "is_daily": true, "is_tutorial": true})
	assert_true(state != null)
	if state == null:
		return
	assert_eq(state.population, 6)
	assert_eq(state.food, 6)
	assert_eq(state.wood, 2)
	assert_eq(state.labor, 6)
	assert_eq(state.labor_max, 6)
	assert_eq(state.capacity(), 6)
	assert_eq(state.rng.seed, SeedUtil.derive_seed(42, 1))
	assert_eq(state.phase, C.Phase.PLANNING)
	assert_eq(state.year, 1)
	assert_eq(state.turn, 1)
	assert_eq(state.stats["max_population"], 6)
	assert_eq(state.stats["reached_year"], 1)
	assert_true(state.is_daily and state.is_tutorial)
	assert_true(state.cards.is_empty() and state.card_offer.is_empty())
	assert_eq(state.pending_event, "")
	assert_eq(state.rain_inflows.size(), 3)
	assert_true(state.undo.is_empty())
	assert_eq(GameFlow.new_game({"seed": 42, "is_daily": true, "is_tutorial": true}).to_dict(), state.to_dict())
	var carpenter: GameState = GameFlow.new_game({"seed": 42, "leader": "carpenter", "difficulty": 2})
	assert_true(carpenter != null)
	if carpenter != null:
		assert_eq(carpenter.food, 4, "difficulty modifies starting food")
		assert_eq(carpenter.population, 6)
		assert_eq(carpenter.wood, 2)
		assert_near(float(carpenter.mod("house_wood")), 1.0, 0.000001)


func test_new_game_rejects_unsupported_or_invalid_configuration() -> void:
	for config: Dictionary in [
		{"map_type": "valley"}, {"map_type": "estuary"}, {"map_type": "unknown"},
		{"leader": "unknown"}, {"difficulty": -1}, {"difficulty": 11},
		{"difficulty": 1.5}, {"seed": "42"}, {"is_daily": "yes"}, {"map_type": 1},
	]:
		assert_eq(GameFlow.new_game(config), null, "invalid configuration %s" % config)


func test_begin_turn_resets_labor_with_seasonal_bonuses_and_clears_undo() -> void:
	var state: GameState = TestMaps.small(0, 2)
	state.mods["season_first_turn_labor"] = 3
	state.mods["rain_turn_labor"] = 2
	for example: Vector2i in [Vector2i(1, 13), Vector2i(2, 10), Vector2i(4, 15), Vector2i(5, 12)]:
		state.turn = example.x
		state.labor = 0
		state.phase = C.Phase.HARVEST
		state.undo.push(state.to_dict())
		GameFlow.begin_turn(state)
		assert_eq(state.phase, C.Phase.PLANNING)
		assert_eq(state.labor, example.y, "labor on turn %d" % example.x)
		assert_eq(state.labor_max, example.y)
		assert_true(state.undo.is_empty())


func test_start_year_grows_saplings_resets_paddies_and_expires_annual_modifiers() -> void:
	var state: GameState = TestMaps.small(1, 2)
	state.year = 2
	state.turn = 1
	state.food = 12
	state.wood = 15
	state.phase = C.Phase.HARVEST
	state.year_mods = [
		{"key": "year_start_food", "op": "set", "value": 100},
		{"key": "year_start_wood", "op": "set", "value": 100},
	]
	state.recompute_mods()
	state.card_offer = ["old_offer"]
	state.pending_event = "old_event"
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.SAPLING})
	TestMaps.set_tile(state, 1, 0, {
		"feature": C.Feature.PADDY, "paddy_yield": 7, "paddy_dead": true, "paddy_rain_turns": 3,
	})
	state.undo.push(state.to_dict())
	GameFlow.start_year(state)
	assert_eq(state.get_tile(Vector2i.ZERO).feature, C.Feature.FOREST)
	var paddy: Tile = state.get_tile(Vector2i(1, 0))
	assert_eq(paddy.paddy_yield, 0)
	assert_true(not paddy.paddy_dead)
	assert_eq(paddy.paddy_rain_turns, 0)
	assert_true(state.year_mods.is_empty())
	assert_eq(state.food, 12, "expired modifiers cannot grant new-year resources")
	assert_eq(state.wood, 15)
	assert_eq(state.stats["reached_year"], 2)
	assert_true(state.card_offer.is_empty())
	assert_eq(state.pending_event, "")
	assert_eq(state.rain_inflows.size(), 3)
	assert_eq(state.phase, C.Phase.PLANNING)
	assert_eq(state.labor, 10)
	assert_true(state.undo.is_empty())


func test_complete_five_year_phase_sequence_and_final_summary() -> void:
	# A dry, source-free fixture isolates turn flow from flood and food strategy.
	var state: GameState = TestMaps.small(1, 4)
	state.population = 6
	state.food = 1000000
	state.get_tile(Vector2i.ZERO).building = C.Building.HALL
	for tile: Tile in state.tiles:
		if tile.coord != Vector2i.ZERO:
			tile.building = C.Building.HOUSE
	GameFlow.start_year(state)
	for year_number: int in range(1, 6):
		assert_eq(state.year, year_number)
		assert_eq(state.stats["reached_year"], year_number)
		for turn_number: int in range(1, 7):
			assert_eq(state.turn, turn_number)
			assert_eq(state.phase, C.Phase.PLANNING)
			assert_eq(state.labor, state.population)
			state.undo.push(state.to_dict())
			var rng_before: int = state.rng.state
			var report: TurnReport = GameFlow.end_turn(state)
			assert_true(report != null)
			assert_eq(state.rng.state, rng_before, "resolving and harvesting cannot consume RNG")
			assert_true(state.undo.is_empty())
			if turn_number < 6:
				assert_eq(state.turn, turn_number + 1)
				assert_eq(state.phase, C.Phase.PLANNING)
		assert_eq(state.phase, C.Phase.HARVEST)
		assert_true(not state.harvest_report.is_empty())
		assert_eq(state.outcome, C.Outcome.WIN if year_number == 5 else C.Outcome.NONE)
		assert_eq(state.final_score, 0, "terminal harvest first presents the year summary")
		GameFlow.continue_after_harvest(state)
		if year_number < 5:
			assert_eq(state.turn, 1)
			assert_eq(state.phase, C.Phase.PLANNING)
	assert_eq(state.phase, C.Phase.GAME_OVER)
	assert_eq(state.final_score, Scoring.score(state))


func test_hall_loss_finishes_immediately_but_hunger_waits_for_summary() -> void:
	var flooded: GameState = TestMaps.small(0, 0)
	flooded.turn = 4
	flooded.rain_inflows = [0.0, 0.0, 0.0]
	flooded.get_tile(Vector2i.ZERO).building = C.Building.HALL
	flooded.get_tile(Vector2i.ZERO).water = 1.0
	flooded.undo.push(flooded.to_dict())
	var report: TurnReport = GameFlow.end_turn(flooded)
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_eq(flooded.phase, C.Phase.GAME_OVER)
	assert_eq(flooded.outcome, C.Outcome.LOSE_HALL)
	assert_eq(flooded.final_score, Scoring.score(flooded))
	assert_true(flooded.undo.is_empty())
	var hungry: GameState = TestMaps.small(0, 4)
	hungry.turn = 6
	hungry.population = 1
	hungry.food = 0
	hungry.rain_inflows = [0.0, 0.0, 0.0]
	report = GameFlow.end_turn(hungry)
	assert_eq(report.outcome, C.Outcome.NONE, "end_turn returns the resolve-only report")
	assert_eq(hungry.outcome, C.Outcome.LOSE_POPULATION)
	assert_eq(hungry.phase, C.Phase.HARVEST)
	GameFlow.continue_after_harvest(hungry)
	assert_eq(hungry.phase, C.Phase.GAME_OVER)
	assert_eq(hungry.final_score, Scoring.score(hungry))


func test_invalid_phase_flow_calls_do_not_advance_or_change_state() -> void:
	var state: GameState = TestMaps.small(0, 2)
	var before: Dictionary = state.to_dict()
	GameFlow.continue_after_harvest(state)
	assert_eq(state.to_dict(), before)
	state.phase = C.Phase.HARVEST
	before = state.to_dict()
	assert_eq(GameFlow.end_turn(state), null)
	assert_eq(state.to_dict(), before)
