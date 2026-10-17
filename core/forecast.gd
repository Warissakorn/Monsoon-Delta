class_name Forecast
extends RefCounted
## Builds the year's hidden rain amounts using only the state's RNG (T-05).

const Constants = preload("res://core/constants.gd")
const Database = preload("res://core/data_db.gd")


static func generate(s: GameState) -> void:
	var balance: Dictionary = Database.balance()
	var rain_range: Array = balance["rain_table"][str(s.year)]
	var multiplier: float = float(s.mod("rain_inflow_multiplier"))
	if s.year == Constants.YEARS:
		multiplier *= float(s.mod("year5_inflow_multiplier"))
	var minimum: float = float(rain_range[0]) * multiplier
	var maximum: float = float(rain_range[1]) * multiplier
	var midpoint: float = (minimum + maximum) / 2.0
	var half_range: float = (maximum - minimum) / 2.0 * float(s.mod("forecast_range_multiplier"))
	minimum = midpoint - half_range
	maximum = midpoint + half_range
	var total: float = s.rng.randf_range(minimum, maximum)
	var settings: Dictionary = balance["forecast"]
	var rain_turns: int = Constants.TURNS_PER_YEAR - Constants.DRY_TURNS
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for _turn: int in range(rain_turns):
		var weight: float = s.rng.randf_range(float(settings["weight_min"]), float(settings["weight_max"]))
		weights.append(weight)
		weight_sum += weight
	s.rain_inflows.clear()
	for weight: float in weights:
		s.rain_inflows.append(total * weight / weight_sum)
	var storm: float = float(s.mod("storm_last_turn_add"))
	s.rain_inflows[rain_turns - 1] += storm
	s.forecast_min = minimum + storm
	s.forecast_max = maximum + storm
