extends TestCase

const YearHarvest = preload("res://core/harvest.gd")


func _state() -> GameState:
	var state: GameState = TestMaps.small(2, 0)
	state.population = 0
	state.food = 0
	state.mods["harvest_paddy_bonus"] = 0
	state.mods["jasmine_bonus"] = 0
	state.mods["fertile_silt_bonus"] = 0
	state.mods["rot_fraction"] = 0.0
	return state


func test_paddy_bonuses_round_counts_and_include_river_neighbors_once() -> void:
	var state: GameState = _state()
	state.population = 1
	state.food = 1
	state.mods["harvest_paddy_bonus"] = 1.6
	state.mods["jasmine_bonus"] = 2.5
	state.mods["fertile_silt_bonus"] = 0.6
	state.stats["food_produced"] = 5
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.PADDY, "paddy_yield": 3, "paddy_rain_turns": 3, "is_river": true})
	TestMaps.set_tile(state, -1, 0, {"feature": C.Feature.PADDY, "paddy_yield": 1, "paddy_rain_turns": 2})
	TestMaps.set_tile(state, -1, 1, {"is_river": true})
	TestMaps.set_tile(state, 1, 0, {"feature": C.Feature.PADDY, "paddy_yield": 0, "paddy_rain_turns": 3})
	TestMaps.set_tile(state, 0, -1, {"feature": C.Feature.PADDY, "paddy_yield": 9, "paddy_dead": true})
	TestMaps.set_tile(state, 2, 0, {"building": C.Building.HOUSE})
	var rng_before: int = state.rng.state
	YearHarvest.do_harvest(state)
	assert_eq(state.harvest_report["paddy_food"], 13)
	assert_eq(state.stats["food_produced"], 18)
	assert_eq(state.food, 11)
	assert_eq(state.population, 2)
	assert_eq(state.rng.state, rng_before)
	assert_eq(state.get_tile(Vector2i.ZERO).paddy_yield, 3, "harvest leaves annual yield for summary")


func test_famine_uses_ceiling_and_report_counts_actual_food_eaten() -> void:
	var state: GameState = _state()
	state.population = 5
	state.food = 5
	state.mods["food_per_person"] = 2
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.HOUSE})
	YearHarvest.do_harvest(state)
	assert_eq(state.harvest_report, {
		"paddy_food": 0, "eaten": 5, "left_hunger": 3, "left_housing": 0,
		"born": 0, "spoiled": 0, "food_after": 0, "population_after": 2,
	})
	assert_eq(state.outcome, C.Outcome.NONE)


func test_housing_is_applied_after_eating_and_before_growth() -> void:
	var state: GameState = _state()
	state.population = 5
	state.food = 15
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.HOUSE})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.HALL})
	YearHarvest.do_harvest(state)
	assert_eq(state.harvest_report["eaten"], 5)
	assert_eq(state.harvest_report["left_housing"], 3)
	assert_eq(state.harvest_report["born"], 0)
	assert_eq(state.population, 2)
	assert_eq(state.food, 10)


func test_growth_precedes_rot_and_granary_prevents_spoilage() -> void:
	var state: GameState = _state()
	state.population = 1
	state.food = 12
	state.mods["rot_fraction"] = 0.5
	state.stats["max_population"] = 1
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.STILT_HOUSE})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.RAFT_HOUSE})
	var granary_state: GameState = state.duplicate_state()
	TestMaps.set_tile(granary_state, -1, 0, {"building": C.Building.GRANARY})
	YearHarvest.do_harvest(state)
	YearHarvest.do_harvest(granary_state)
	assert_eq(state.harvest_report["born"], 3)
	assert_eq(state.harvest_report["spoiled"], 2)
	assert_eq(state.food, 3)
	assert_eq(state.population, 4)
	assert_eq(state.stats["max_population"], 4)
	assert_eq(granary_state.harvest_report["spoiled"], 0)
	assert_eq(granary_state.food, 5)


func test_year_five_win_and_zero_population_loss_are_final_population_based() -> void:
	var winner: GameState = _state()
	winner.year = 5
	winner.population = 1
	winner.food = 1
	TestMaps.set_tile(winner, 0, 0, {"building": C.Building.HOUSE})
	YearHarvest.do_harvest(winner)
	assert_eq(winner.outcome, C.Outcome.WIN)
	var loser: GameState = _state()
	loser.year = 5
	loser.population = 1
	loser.food = 0
	TestMaps.set_tile(loser, 0, 0, {"building": C.Building.HOUSE})
	YearHarvest.do_harvest(loser)
	assert_eq(loser.population, 0)
	assert_eq(loser.food, 0)
	assert_eq(loser.outcome, C.Outcome.LOSE_POPULATION)


func test_zero_food_costs_allow_free_feeding_and_growth_without_division() -> void:
	var state: GameState = _state()
	state.population = 1
	state.food = 0
	state.mods["food_per_person"] = 0
	state.mods["food_per_growth"] = 0
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.HOUSE})
	YearHarvest.do_harvest(state)
	assert_eq(state.harvest_report["eaten"], 0)
	assert_eq(state.harvest_report["left_hunger"], 0)
	assert_eq(state.harvest_report["born"], 1)
	assert_eq(state.population, 2)
	assert_eq(state.food, 0)
