extends TestCase

const RainForecast = preload("res://core/forecast.gd")


func _state() -> GameState:
	var state: GameState = TestMaps.small(1, 0)
	state.rng.seed = 938174
	return state


func test_exact_forecast_draw_order_and_year_five_modifiers() -> void:
	var state: GameState = _state()
	state.year = 5
	state.mods["rain_inflow_multiplier"] = 1.2
	state.mods["year5_inflow_multiplier"] = 1.5
	state.mods["forecast_range_multiplier"] = 1.25
	state.mods["storm_last_turn_add"] = 2.5
	var expected_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	expected_rng.seed = state.rng.seed
	expected_rng.state = state.rng.state
	# Year 5's [22,30] becomes [39.6,54], then its range expands around 46.8.
	var minimum: float = 37.8
	var maximum: float = 55.8
	var total: float = expected_rng.randf_range(minimum, maximum)
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for _index: int in range(3):
		var weight: float = expected_rng.randf_range(0.25, 0.45)
		weights.append(weight)
		weight_sum += weight
	RainForecast.generate(state)
	assert_eq(state.rain_inflows.size(), 3)
	for index: int in range(3):
		var expected: float = total * weights[index] / weight_sum
		if index == 2:
			expected += 2.5
		assert_near(state.rain_inflows[index], expected, 0.00001, "rain turn %d" % index)
	assert_near(state.forecast_min, 40.3, 0.00001)
	assert_near(state.forecast_max, 58.3, 0.00001)
	assert_eq(state.rng.state, expected_rng.state, "exactly total+three weight draws")


func test_forecast_is_repeatable_and_only_changes_forecast_fields() -> void:
	var original: GameState = _state()
	original.year = 3
	var duplicate: GameState = original.duplicate_state()
	var original_tiles: Array = original.to_dict()["tiles"]
	RainForecast.generate(original)
	RainForecast.generate(duplicate)
	assert_eq(original.rain_inflows, duplicate.rain_inflows)
	assert_eq(original.rng.state, duplicate.rng.state)
	assert_eq(original.to_dict()["tiles"], original_tiles)
	assert_eq(original.year, 3)
	assert_eq(original.turn, 1)
	assert_eq(original.population, 10)
	assert_eq(original.food, 10)


func test_year_five_multiplier_has_no_effect_in_earlier_years() -> void:
	var state: GameState = _state()
	state.mods["year5_inflow_multiplier"] = 4.0
	RainForecast.generate(state)
	assert_near(state.forecast_min, 8.0, 0.00001)
	assert_near(state.forecast_max, 12.0, 0.00001)
	var total: float = 0.0
	for inflow: float in state.rain_inflows:
		total += inflow
	assert_true(total >= state.forecast_min and total <= state.forecast_max)
	state.turn = 4
	assert_near(state.current_inflow(), state.rain_inflows[0], 0.00001)
