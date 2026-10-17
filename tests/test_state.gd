extends TestCase

const STATE_FIELDS: Array[String] = [
	"version", "seed", "map_type", "leader", "difficulty", "is_daily", "is_tutorial",
	"year", "turn", "phase", "population", "food", "wood", "labor", "labor_max",
	"cards", "card_offer", "pending_event", "year_mods", "forecast_min", "forecast_max",
	"rain_inflows", "stats", "outcome", "harvest_report", "final_score",
]
const TILE_FIELDS: Array[String] = [
	"q", "r", "elevation", "water", "feature", "building", "gate_open", "wheel_dir",
	"is_source", "is_sea", "is_river", "paddy_yield", "paddy_dead", "paddy_rain_turns",
	"start_house",
]


func _populated_state() -> GameState:
	var state: GameState = TestMaps.small(1, 2)
	state.seed = 9223372036854775000
	state.map_type = "plains"
	state.leader = "carpenter"
	state.difficulty = 3
	state.is_daily = true
	state.is_tutorial = true
	state.year = 4
	state.turn = 5
	state.phase = C.Phase.HARVEST
	state.population = 17
	state.food = 28
	state.wood = 19
	state.labor = 3
	state.labor_max = 20
	state.cards = ["waterwheel", "bamboo"]
	state.card_offer = ["sandbags", "sky_reader", "floating_rice"]
	state.pending_event = "boat_trader"
	state.year_mods = [{"key": "flow_rate", "op": "set", "value": 0.625}]
	state.forecast_min = 15.125
	state.forecast_max = 22.875
	state.rain_inflows = [3.25, 4.5, 5.25]
	state.rng.seed = 9223372036854775000
	for _draw: int in range(11):
		state.rng.randi()
	state.stats = {
		"houses_lost": 2, "paddies_lost": 3, "hall_ever_wet": true,
		"max_population": 19, "food_produced": 47, "reached_year": 4,
	}
	state.outcome = C.Outcome.LOSE_POPULATION
	state.harvest_report = {"food_after": 28, "details": {"growth": 2, "growth_ratio": 2.5, "notes": ["kept"]}}
	state.final_score = 176
	TestMaps.set_tile(state, -1, 0, {
		"elevation": -3, "water": 1.125, "feature": C.Feature.PADDY,
		"paddy_yield": 7, "paddy_dead": true, "paddy_rain_turns": 2, "is_river": true,
	})
	TestMaps.set_tile(state, -1, 1, {
		"building": C.Building.STILT_HOUSE, "gate_open": false, "wheel_dir": 4,
		"start_house": true, "is_source": true,
	})
	TestMaps.set_tile(state, 1, 0, {"is_sea": true, "water": 0.625})
	state.recompute_mods()
	return state


func _assert_all_fields_equal(actual: GameState, expected: GameState) -> void:
	for field: String in STATE_FIELDS:
		assert_eq(actual.get(field), expected.get(field), "state field " + field)
	assert_eq(actual.tiles.size(), expected.tiles.size())
	for index: int in range(mini(actual.tiles.size(), expected.tiles.size())):
		for field: String in TILE_FIELDS:
			assert_eq(actual.tiles[index].get(field), expected.tiles[index].get(field), "tile %d field %s" % [index, field])
	assert_eq(actual.rng.seed, expected.rng.seed, "RNG seed")
	assert_eq(actual.rng.state, expected.rng.state, "RNG state")


func test_serialization_keeps_full_state_and_json_precision() -> void:
	var state: GameState = _populated_state()
	var saved: Dictionary = state.to_dict()
	for field: String in STATE_FIELDS:
		assert_true(saved.has(field), "serialized state missing " + field)
	for tile_data: Dictionary in saved["tiles"]:
		for field: String in TILE_FIELDS:
			assert_true(tile_data.has(field), "serialized tile missing " + field)
	assert_eq(saved["seed"], "9223372036854775000")
	assert_eq(saved["rng_seed"], str(state.rng.seed))
	assert_eq(saved["rng_state"], str(state.rng.state))
	assert_eq(saved["phase"], "harvest")
	assert_eq(saved["outcome"], "lose_population")
	assert_eq(saved["tiles"][0]["feature"], "paddy")
	assert_eq(saved["tiles"][1]["building"], "stilt_house")
	assert_true(not saved.has("mods"), "computed modifier cache must not be saved")
	assert_true(not saved.has("index"), "coordinate index must not be saved")
	var direct: GameState = GameState.from_dict(saved)
	_assert_all_fields_equal(direct, state)
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	assert_true(parsed is Dictionary, "saved JSON is an object")
	if not parsed is Dictionary:
		return
	var restored: GameState = GameState.from_dict(parsed)
	_assert_all_fields_equal(restored, state)
	assert_eq(restored.to_dict(), saved, "JSON roundtrip")
	assert_eq(typeof(restored.population), TYPE_INT, "JSON resources restore to int")
	assert_eq(typeof(restored.tiles[0].elevation), TYPE_INT, "JSON elevations restore to int")
	assert_eq(restored.get_tile(Vector2i(-1, 0)), restored.tiles[0], "coordinate cache rebuilt")
	assert_near(float(restored.mod("flow_rate")), 0.625, 0.000001, "modifier cache rebuilt")
	for draw: int in range(20):
		assert_eq(restored.rng.randi(), state.rng.randi(), "loaded RNG continuation draw %d" % draw)


func test_duplicate_state_is_independent_and_preserves_rng() -> void:
	var state: GameState = _populated_state()
	var original: Dictionary = state.to_dict()
	var duplicate: GameState = state.duplicate_state()
	_assert_all_fields_equal(duplicate, state)
	assert_true(duplicate != state)
	assert_true(duplicate.tiles[0] != state.tiles[0])
	assert_true(duplicate.rng != state.rng)
	duplicate.tiles[0].water += 8.0
	duplicate.cards.append("sandbags")
	duplicate.card_offer.clear()
	duplicate.year_mods[0]["value"] = 0.9
	duplicate.stats["houses_lost"] = 99
	duplicate.harvest_report["details"]["notes"].append("changed")
	duplicate.mods["flow_rate"] = 0.8
	duplicate.rng.randi()
	assert_eq(state.to_dict(), original, "mutating duplicate must leave original unchanged")
	assert_near(float(state.mod("flow_rate")), 0.625, 0.000001, "modifier caches are independent")
	var clone: GameState = state.duplicate_state()
	for draw: int in range(20):
		assert_eq(clone.rng.randi(), state.rng.randi(), "cloned RNG continuation draw %d" % draw)


func test_from_dict_does_not_keep_mutable_input_aliases() -> void:
	var source: GameState = _populated_state()
	var saved: Dictionary = source.to_dict()
	var state: GameState = GameState.from_dict(saved)
	var baseline: Dictionary = state.to_dict()
	saved["cards"].append("sandbags")
	saved["stats"]["houses_lost"] = 99
	saved["year_mods"][0]["value"] = 0.9
	saved["harvest_report"]["details"]["notes"].append("changed")
	saved["tiles"][0]["water"] = 100.0
	assert_eq(state.to_dict(), baseline)
	assert_eq(source.to_dict(), baseline, "to_dict must not expose mutable state collections")


func test_nested_json_numbers_use_canonical_integral_types() -> void:
	var state: GameState = TestMaps.small(0, 0)
	state.harvest_report = {
		"nested": {"integer": 2, "whole_float": 2.0, "fraction": 2.5, "series": [3, 3.0, 3.75]},
	}
	state.year_mods = [{"key": "flow_rate", "op": "set", "value": 1.0}]
	var saved: Dictionary = state.to_dict()
	assert_eq(saved["harvest_report"]["nested"]["integer"], 2)
	assert_eq(saved["harvest_report"]["nested"]["whole_float"], 2)
	assert_eq(saved["harvest_report"]["nested"]["fraction"], 2.5)
	assert_eq(saved["harvest_report"]["nested"]["series"], [3, 3, 3.75])
	assert_eq(saved["year_mods"][0]["value"], 1)
	var restored: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(restored.to_dict(), saved, "nested counts survive JSON's numeric type conversion")
	assert_near(float(restored.mod("flow_rate")), 1.0, 0.000001)


func test_neighbors_seasons_and_current_rain_inflow() -> void:
	var state: GameState = TestMaps.small(1, 2)
	var center: Tile = state.get_tile(Vector2i.ZERO)
	var adjacent: Array[Tile] = state.neighbors(center)
	assert_eq(adjacent.size(), 6)
	for direction: int in range(6):
		var neighbor: Tile = state.neighbor_in_dir(center, direction)
		assert_eq(neighbor, adjacent[direction], "ordered state neighbors")
		assert_eq(Vector2i(neighbor.q, neighbor.r), Hex.direction(direction))
	assert_eq(state.get_tile(Vector2i(2, 0)), null)
	assert_eq(state.neighbors(state.get_tile(Vector2i(1, 0))).size(), 3)
	state.turn = 3
	assert_eq(state.season(), C.Season.DRY)
	assert_true(not state.is_rain())
	state.rain_inflows = [2.0, 3.0, 4.0]
	for turn_number: int in range(4, 7):
		state.turn = turn_number
		assert_eq(state.season(), C.Season.RAIN)
		assert_true(state.is_rain())
		assert_near(state.current_inflow(), float(turn_number - 2), 0.000001)
