extends TestCase

const CENTER: Vector2i = Vector2i.ZERO
const PRICES: Dictionary = {
	"dig": Vector2i(2, 0), "fill": Vector2i(2, 0), "paddy": Vector2i(1, 0),
	"house": Vector2i(2, 2), "stilt_house": Vector2i(3, 3), "raft_house": Vector2i(2, 3),
	"chop": Vector2i(1, 0), "plant": Vector2i(1, 0), "gate": Vector2i(3, 2),
	"toggle_gate": Vector2i(0, 0), "reservoir": Vector2i(4, 0),
	"fish_trap": Vector2i(1, 1), "granary": Vector2i(2, 3),
	"waterwheel": Vector2i(2, 2), "demolish": Vector2i(1, 0),
}
const EMPTY_COMMANDS: Array[String] = [
	"dig", "fill", "paddy", "house", "stilt_house", "raft_house", "plant",
	"gate", "reservoir", "fish_trap", "granary", "waterwheel",
]


func test_command_value_defaults_and_constructor() -> void:
	var empty := Command.new()
	assert_eq(empty.id, "")
	assert_eq(empty.coord, CENTER)
	assert_eq(empty.param, -1)
	var wheel := Command.new("waterwheel", Vector2i(-1, 1), 4)
	assert_eq(wheel.id, "waterwheel")
	assert_eq(wheel.coord, Vector2i(-1, 1))
	assert_eq(wheel.param, 4)


func test_every_command_applies_its_effect_and_current_cost_without_rng() -> void:
	for id: String in PRICES:
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		var param: int = 0 if id == "waterwheel" else -1
		match id:
			"paddy":
				tile.paddy_yield = 7
				tile.paddy_dead = true
				tile.paddy_rain_turns = 2
			"raft_house":
				tile.water = 0.1
			"chop":
				tile.feature = C.Feature.FOREST
			"toggle_gate":
				tile.building = C.Building.GATE
			"gate":
				tile.gate_open = false
			"demolish":
				tile.building = C.Building.HOUSE
				tile.gate_open = false
				tile.wheel_dir = 3
		var cmd := Command.new(id, CENTER, param)
		var price: Vector2i = PRICES[id]
		var rng_before: int = s.rng.state
		assert_eq(CommandRules.check(s, cmd), "", id)
		assert_eq(CommandRules.cost(s, cmd), price, id)
		if not CommandRules.check(s, cmd).is_empty():
			continue
		CommandRules.apply(s, cmd)
		assert_eq(s.labor, 100 - price.x, id + " labor")
		var bonus_wood: int = 2 if id == "chop" else (1 if id == "demolish" else 0)
		assert_eq(s.wood, 100 - price.y + bonus_wood, id + " wood")
		assert_eq(s.rng.state, rng_before, id + " preserves RNG")
		match id:
			"dig":
				assert_eq(tile.elevation, 1)
			"fill":
				assert_eq(tile.elevation, 3)
			"paddy":
				assert_eq(tile.feature, C.Feature.PADDY)
				_assert_paddy_reset(tile)
			"chop":
				assert_eq(tile.feature, C.Feature.NONE)
			"plant":
				assert_eq(tile.feature, C.Feature.SAPLING)
			"toggle_gate":
				assert_eq(tile.gate_open, false)
			"demolish":
				assert_eq(tile.building, C.Building.NONE)
				assert_eq(tile.gate_open, true)
				assert_eq(tile.wheel_dir, -1)
			_:
				assert_eq(tile.building, int(CommandRules.DEFS[id]["building"]), id)
				if id == "gate":
					assert_eq(tile.gate_open, true)
				elif id == "waterwheel":
					assert_eq(tile.wheel_dir, 0)
				elif id == "reservoir":
					assert_eq(tile.elevation, -1)


func test_every_command_rejects_an_invalid_target() -> void:
	for id: String in PRICES:
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		tile.feature = C.Feature.FOREST
		if id == "chop" or id == "toggle_gate":
			tile.feature = C.Feature.NONE
		elif id == "demolish":
			tile.feature = C.Feature.NONE
			tile.building = C.Building.HALL
		assert_eq(CommandRules.check(s, Command.new(id, CENTER, 0 if id == "waterwheel" else -1)), "err.target", id)


func test_validation_priority_from_phase_through_resources() -> void:
	var s: GameState = _state()
	var cmd := Command.new("waterwheel", Vector2i(99, 99), 99)
	s.phase = C.Phase.EVENT
	s.mods["unlock_waterwheel"] = 0
	assert_eq(CommandRules.check(s, cmd), "err.phase")
	s.phase = C.Phase.PLANNING
	assert_eq(CommandRules.check(s, cmd), "err.locked")
	s.mods["unlock_waterwheel"] = 1
	assert_eq(CommandRules.check(s, cmd), "err.no_tile")
	cmd.id = "paddy"
	s.turn = 4
	assert_eq(CommandRules.check(s, cmd), "err.no_tile", "tile before season")
	cmd.coord = CENTER
	var tile: Tile = s.get_tile(CENTER)
	tile.building = C.Building.HOUSE
	tile.water = 1.0
	s.labor = 0
	s.wood = 0
	assert_eq(CommandRules.check(s, cmd), "err.season")
	s.turn = 1
	assert_eq(CommandRules.check(s, cmd), "err.target")
	tile.building = C.Building.NONE
	assert_eq(CommandRules.check(s, cmd), "err.water")
	tile.water = 0.0
	assert_eq(CommandRules.check(s, cmd), "err.param")
	cmd.param = -1
	assert_eq(CommandRules.check(s, cmd), "err.labor")
	cmd.id = "house"
	assert_eq(CommandRules.check(s, cmd), "err.labor", "labor before wood")
	s.labor = 100
	assert_eq(CommandRules.check(s, cmd), "err.wood")
	s.wood = 100
	assert_eq(CommandRules.check(s, cmd), "")


func test_unknown_command_and_phase_priority() -> void:
	var s: GameState = _state()
	var cmd := Command.new("missing", Vector2i(99, 99), 99)
	assert_eq(CommandRules.check(s, cmd), "err.unknown")
	assert_eq(CommandRules.cost(s, cmd), Vector2i.ZERO)
	assert_eq(CommandRules.valid_targets(s, cmd.id).size(), 0)
	s.phase = C.Phase.GAME_OVER
	assert_eq(CommandRules.check(s, cmd), "err.phase")


func test_both_unlocks_are_required_before_target_checks() -> void:
	for id: String in ["waterwheel", "raft_house"]:
		var s: GameState = _state()
		s.mods["unlock_" + id] = 0
		assert_eq(CommandRules.check(s, Command.new(id, Vector2i(99, 99))), "err.locked", id)
		s.mods["unlock_" + id] = 1
		assert_eq(CommandRules.check(s, Command.new(id, Vector2i(99, 99))), "err.no_tile", id)


func test_dry_only_commands_reject_rain() -> void:
	var s: GameState = _state()
	s.turn = 4
	for id: String in ["paddy", "plant", "reservoir"]:
		assert_eq(CommandRules.check(s, Command.new(id, CENTER)), "err.season", id)


func test_water_requirements_use_exact_levels() -> void:
	var s: GameState = _state()
	var tile: Tile = s.get_tile(CENTER)
	for id: String in ["paddy", "house", "stilt_house", "plant", "reservoir", "granary"]:
		tile.water = 0.0999
		assert_eq(CommandRules.check(s, Command.new(id, CENTER)), "", id)
		tile.water = 0.1
		assert_eq(CommandRules.check(s, Command.new(id, CENTER)), "err.water", id)
	tile.water = 0.0999
	assert_eq(CommandRules.check(s, Command.new("raft_house", CENTER)), "err.water")
	for water: float in [0.1, 0.5, 1.0, 100.0]:
		tile.water = water
		assert_eq(CommandRules.check(s, Command.new("raft_house", CENTER)), "")


func test_empty_targets_exclude_source_and_sea_even_with_paddies() -> void:
	for property: String in ["is_source", "is_sea"]:
		for id: String in EMPTY_COMMANDS:
			var s: GameState = _state()
			var tile: Tile = s.get_tile(CENTER)
			tile.set(property, true)
			tile.water = 0.1 if id == "raft_house" else 0.0
			assert_eq(CommandRules.check(s, Command.new(id, CENTER, 0 if id == "waterwheel" else -1)), "err.target", property + " " + id)
		for id: String in ["dig", "fill"]:
			var s: GameState = _state()
			var tile: Tile = s.get_tile(CENTER)
			tile.set(property, true)
			tile.feature = C.Feature.PADDY
			assert_eq(CommandRules.check(s, Command.new(id, CENTER)), "err.target", property + " paddy " + id)


func test_empty_targets_reject_existing_buildings_and_non_paddy_features() -> void:
	for id: String in EMPTY_COMMANDS:
		for feature: int in [C.Feature.FOREST, C.Feature.SAPLING, C.Feature.PADDY]:
			var s: GameState = _state()
			s.get_tile(CENTER).feature = feature
			var expected: String = "" if id in ["dig", "fill"] and feature == C.Feature.PADDY else "err.target"
			assert_eq(CommandRules.check(s, Command.new(id, CENTER, 0 if id == "waterwheel" else -1)), expected, "%s feature %d" % [id, feature])
		var built: GameState = _state()
		built.get_tile(CENTER).building = C.Building.HOUSE
		assert_eq(CommandRules.check(built, Command.new(id, CENTER, 0 if id == "waterwheel" else -1)), "err.target", id)


func test_river_metadata_is_compatible_with_empty_targets() -> void:
	for id: String in EMPTY_COMMANDS:
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		tile.is_river = true
		tile.water = 0.1 if id == "raft_house" else 0.0
		assert_eq(CommandRules.check(s, Command.new(id, CENTER, 0 if id == "waterwheel" else -1)), "", id)


func test_earthworks_allow_paddies_preserve_water_and_clamp_elevation() -> void:
	var s: GameState = _state()
	var tile: Tile = s.get_tile(CENTER)
	tile.feature = C.Feature.PADDY
	tile.water = 0.75
	tile.paddy_yield = 5
	s.mods["dig_amount"] = 2.6
	tile.elevation = 1
	CommandRules.apply(s, Command.new("dig", CENTER))
	assert_eq(tile.elevation, 0)
	assert_eq(CommandRules.check(s, Command.new("dig", CENTER)), "err.target")
	s.mods["fill_amount"] = 1.6
	tile.elevation = 3
	CommandRules.apply(s, Command.new("fill", CENTER))
	assert_eq(tile.elevation, 4)
	assert_eq(CommandRules.check(s, Command.new("fill", CENTER)), "err.target")
	assert_near(tile.water, 0.75, C.EPS)
	assert_eq(tile.feature, C.Feature.PADDY)
	assert_eq(tile.paddy_yield, 5)


func test_count_modifiers_round_instead_of_truncate() -> void:
	var s: GameState = _state()
	var tile: Tile = s.get_tile(CENTER)
	s.mods["dig_amount"] = 1.5
	tile.elevation = 4
	CommandRules.apply(s, Command.new("dig", CENTER))
	assert_eq(tile.elevation, 2)
	s.mods["fill_amount"] = 1.5
	CommandRules.apply(s, Command.new("fill", CENTER))
	assert_eq(tile.elevation, 4)
	tile.elevation = 2
	s.mods["reservoir_depth"] = 3.5
	CommandRules.apply(s, Command.new("reservoir", CENTER))
	assert_eq(tile.elevation, -2)
	tile.building = C.Building.NONE
	tile.feature = C.Feature.FOREST
	s.mods["chop_wood"] = 2.5
	var wood_before: int = s.wood
	CommandRules.apply(s, Command.new("chop", CENTER))
	assert_eq(s.wood, wood_before + 3)


func test_cost_rounding_nonnegative_costs_and_earthwork_minimums() -> void:
	var s: GameState = _state()
	s.mods["house_labor"] = 1.5
	s.mods["house_wood"] = 2.5
	assert_eq(CommandRules.cost(s, Command.new("house")), Vector2i(2, 3))
	s.mods["house_labor"] = -4.0
	s.mods["house_wood"] = -3.0
	assert_eq(CommandRules.cost(s, Command.new("house")), Vector2i.ZERO)
	s.mods["paddy_labor"] = 0.0
	s.labor = 0
	assert_eq(CommandRules.check(s, Command.new("paddy", CENTER)), "")
	for turn: int in [1, 4]:
		s.turn = turn
		for id: String in ["dig", "fill"]:
			s.mods[id + "_labor_dry"] = -2.0
			s.mods[id + "_labor_rain"] = 0.0
			assert_eq(CommandRules.cost(s, Command.new(id)), Vector2i(1, 0), id)
			assert_eq(CommandRules.check(s, Command.new(id, CENTER)), "err.labor", id)


func test_only_earthwork_costs_change_in_rain() -> void:
	var s: GameState = _state()
	s.turn = 4
	for id: String in PRICES:
		var expected: Vector2i = PRICES[id]
		if id in ["dig", "fill"]:
			expected.x = 4
		assert_eq(CommandRules.cost(s, Command.new(id)), expected, id)
	s.mods["dig_labor_rain"] = 2.5
	s.mods["fill_labor_rain"] = 1.4
	assert_eq(CommandRules.cost(s, Command.new("dig")), Vector2i(3, 0))
	assert_eq(CommandRules.cost(s, Command.new("fill")), Vector2i(1, 0))


func test_all_non_wheel_commands_require_default_parameter() -> void:
	for id: String in PRICES:
		if id == "waterwheel":
			continue
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		if id == "chop":
			tile.feature = C.Feature.FOREST
		elif id in ["toggle_gate", "demolish"]:
			tile.building = C.Building.GATE
		elif id == "raft_house":
			tile.water = 0.1
		for param: int in [-2, 0, 5]:
			assert_eq(CommandRules.check(s, Command.new(id, CENTER, param)), "err.param", id)


func test_wheel_requires_existing_non_sea_neighbor_in_direction() -> void:
	var s: GameState = _state()
	for param: int in [-2, -1, 6, 99]:
		assert_eq(CommandRules.check(s, Command.new("waterwheel", CENTER, param)), "err.param")
	for direction: int in range(6):
		assert_eq(CommandRules.check(s, Command.new("waterwheel", CENTER, direction)), "")
	assert_eq(CommandRules.check(s, Command.new("waterwheel", Vector2i(1, 0), 0)), "err.param")
	var neighbor: Tile = s.neighbor_in_dir(s.get_tile(CENTER), 0)
	neighbor.is_sea = true
	assert_eq(CommandRules.check(s, Command.new("waterwheel", CENTER, 0)), "err.param")
	neighbor.is_sea = false
	neighbor.is_source = true
	assert_eq(CommandRules.check(s, Command.new("waterwheel", CENTER, 0)), "")
	neighbor.is_source = false
	neighbor.building = C.Building.GATE
	neighbor.gate_open = false
	assert_eq(CommandRules.check(s, Command.new("waterwheel", CENTER, 0)), "")


func test_toggle_is_free_in_both_seasons_and_has_no_empty_restriction() -> void:
	var s: GameState = _state()
	var tile: Tile = s.get_tile(CENTER)
	tile.building = C.Building.GATE
	tile.is_source = true
	tile.water = 5.0
	s.labor = 0
	s.wood = 0
	for turn: int in [1, 4]:
		s.turn = turn
		assert_eq(CommandRules.check(s, Command.new("toggle_gate", CENTER)), "")
		CommandRules.apply(s, Command.new("toggle_gate", CENTER))
	assert_eq(tile.gate_open, true)
	assert_eq(s.labor, 0)
	assert_eq(s.wood, 0)


func test_chop_and_demolish_use_explicit_targets_without_empty_restrictions() -> void:
	for flag: String in ["is_source", "is_sea"]:
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		tile.set(flag, true)
		tile.feature = C.Feature.FOREST
		assert_eq(CommandRules.check(s, Command.new("chop", CENTER)), "")
		tile.feature = C.Feature.SAPLING
		assert_eq(CommandRules.check(s, Command.new("demolish", CENTER)), "")


func test_demolition_refunds_current_rounded_cost_for_every_building() -> void:
	for id: String in ["house", "stilt_house", "raft_house", "gate", "reservoir", "fish_trap", "granary", "waterwheel"]:
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		var definition: Dictionary = CommandRules.DEFS[id]
		tile.building = int(definition["building"])
		tile.gate_open = false
		tile.wheel_dir = 4
		tile.elevation = -3
		var wood_key: String = String(definition.get("wood", ""))
		if not wood_key.is_empty():
			s.mods[wood_key] = 4.6
		s.mods["demolish_refund_fraction"] = 0.5
		s.wood = 0
		CommandRules.apply(s, Command.new("demolish", CENTER))
		assert_eq(s.wood, 0 if wood_key.is_empty() else 2, id + " rounded5 times half floors2")
		assert_eq(tile.building, C.Building.NONE, id)
		assert_eq(tile.elevation, -3, id + " preserves excavation")
		assert_eq(tile.gate_open, true)
		assert_eq(tile.wheel_dir, -1)


func test_demolition_salvage_respects_nonnegative_cost_and_current_mods() -> void:
	var s: GameState = _state()
	var tile: Tile = s.get_tile(CENTER)
	CommandRules.apply(s, Command.new("house", CENTER))
	s.mods["house_wood"] = 7.0
	s.mods["demolish_refund_fraction"] = 1.0
	s.wood = 0
	CommandRules.apply(s, Command.new("demolish", CENTER))
	assert_eq(s.wood, 7, "refund uses current cost, not purchase price")
	tile.building = C.Building.HOUSE
	s.mods["house_wood"] = -2.0
	CommandRules.apply(s, Command.new("demolish", CENTER))
	assert_eq(s.wood, 7)


func test_demolishing_paddies_and_saplings_resets_fields_without_refund() -> void:
	for feature: int in [C.Feature.PADDY, C.Feature.SAPLING]:
		var s: GameState = _state()
		var tile: Tile = s.get_tile(CENTER)
		tile.feature = feature
		tile.paddy_yield = 9
		tile.paddy_dead = true
		tile.paddy_rain_turns = 3
		CommandRules.apply(s, Command.new("demolish", CENTER))
		assert_eq(tile.feature, C.Feature.NONE)
		_assert_paddy_reset(tile)
		assert_eq(s.wood, 100)
		assert_eq(s.labor, 99)


func test_reservoir_depth_stops_at_minus_three_and_preserves_water() -> void:
	var s: GameState = _state()
	var tile: Tile = s.get_tile(CENTER)
	tile.elevation = 0
	tile.water = 0.0999
	s.mods["reservoir_depth"] = 8.0
	CommandRules.apply(s, Command.new("reservoir", CENTER))
	assert_eq(tile.elevation, -3)
	assert_near(tile.water, 0.0999, C.EPS)


func test_valid_targets_preserves_order_state_and_respects_affordability() -> void:
	var s: GameState = _state()
	s.tiles[0].water = 0.5
	s.tiles[1].feature = C.Feature.FOREST
	s.tiles[2].is_source = true
	var expected: Array[Vector2i] = []
	for i: int in range(3, s.tiles.size()):
		expected.append(s.tiles[i].coord)
	var before: Dictionary = s.to_dict()
	assert_eq(CommandRules.valid_targets(s, "house"), expected)
	assert_eq(s.to_dict(), before, "target discovery must be read only, including RNG")
	s.wood = 0
	assert_eq(CommandRules.valid_targets(s, "house").size(), 0)
	s.wood = 100
	s.phase = C.Phase.HARVEST
	assert_eq(CommandRules.valid_targets(s, "house").size(), 0)


func test_valid_targets_for_wheel_respects_parameter_and_neighbor() -> void:
	var s: GameState = _state()
	assert_eq(CommandRules.valid_targets(s, "waterwheel").size(), 0)
	var targets: Array[Vector2i] = CommandRules.valid_targets(s, "waterwheel", 0)
	assert_true(targets.has(CENTER))
	assert_true(not targets.has(Vector2i(1, 0)))
	s.neighbor_in_dir(s.get_tile(CENTER), 0).is_sea = true
	assert_true(not CommandRules.valid_targets(s, "waterwheel", 0).has(CENTER))


func _state() -> GameState:
	var s: GameState = TestMaps.small(1, 2)
	s.labor = 100
	s.wood = 100
	s.mods["unlock_raft_house"] = 1
	s.mods["unlock_waterwheel"] = 1
	s.rng.seed = 98765
	return s


func _assert_paddy_reset(tile: Tile) -> void:
	assert_eq(tile.paddy_yield, 0)
	assert_eq(tile.paddy_dead, false)
	assert_eq(tile.paddy_rain_turns, 0)


func test_valid_targets_equal_tiles_that_pass_full_check() -> void:
	var ids: Array[String] = ["unknown"]
	ids.append_array(CommandRules.DEFS.keys())
	for ruleset: String in ["legacy", "bracing_v1"]:
		for seed_value: int in [3, 17]:
			var s: GameState = GameFlow.new_game({"seed": seed_value, "ruleset": ruleset, "run_mode": "long"})
			for turn: int in [1, C.DRY_TURNS + 1]:
				s.turn = turn
				for resources: Vector2i in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(100, 100)]:
					s.labor = resources.x
					s.wood = resources.y
					for phase: int in [C.Phase.PLANNING, C.Phase.HARVEST]:
						s.phase = phase
						for id: String in ids:
							for param: int in [-1, 0, 5, 6]:
								var expected: Array[Vector2i] = []
								for tile: Tile in s.tiles:
									if CommandRules.check(s, Command.new(id, tile.coord, param)).is_empty():
										expected.append(tile.coord)
								assert_eq(CommandRules.valid_targets(s, id, param), expected, "%s %s turn %d %s phase %d param %d" % [ruleset, id, turn, resources, phase, param])
