extends TestCase


func _state(radius: int = 0, rain: bool = true) -> GameState:
	var state: GameState = TestMaps.small(radius, 0)
	state.turn = 4 if rain else 1
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.mods["water_iterations"] = 1
	state.mods["dry_inflow"] = 0.0
	state.mods["evaporation_dry"] = 0.0
	return state


func _water_everywhere(state: GameState, depth: float) -> void:
	for tile: Tile in state.tiles:
		tile.water = depth


func test_building_damage_at_threshold_and_survival_below_it() -> void:
	# spec: T-08. Only the three explicitly vulnerable buildings are removed.
	var cases: Array[Dictionary] = [
		{"building": C.Building.HOUSE, "below": 0.0999, "at": 0.1, "homes": 1},
		{"building": C.Building.STILT_HOUSE, "below": 0.4999, "at": 0.5, "homes": 1},
		{"building": C.Building.GRANARY, "below": 0.4999, "at": 0.5, "homes": 0},
	]
	for entry: Dictionary in cases:
		for at_threshold: bool in [false, true]:
			var state: GameState = _state()
			var tile: Tile = state.tiles[0]
			tile.building = int(entry["building"])
			tile.water = float(entry["at"] if at_threshold else entry["below"])
			var report: TurnReport = TurnResolver.resolve_turn(state)
			assert_eq(tile.building, C.Building.NONE if at_threshold else int(entry["building"]))
			assert_eq(report.destroyed.size(), 1 if at_threshold else 0)
			assert_eq(int(state.stats["houses_lost"]), int(entry["homes"]) if at_threshold else 0)
			if at_threshold:
				assert_eq(report.destroyed[0]["coord"], tile.coord)
				assert_eq(report.destroyed[0]["building"], int(entry["building"]))
	for building: int in [C.Building.RAFT_HOUSE, C.Building.GATE, C.Building.FISH_TRAP,
		C.Building.RESERVOIR, C.Building.WATERWHEEL]:
		var state: GameState = _state()
		state.tiles[0].building = building
		state.tiles[0].water = 2.0
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(state.tiles[0].building, building, "immune building %d" % building)
		assert_eq(report.destroyed.size(), 0)
		assert_eq(int(state.stats["houses_lost"]), 0)


func test_count_thresholds_round_and_level_four_never_destroys() -> void:
	# spec: M-03, T-08.
	var state: GameState = _state()
	state.tiles[0].building = C.Building.HOUSE
	state.mods["house_destroy_level"] = 1.6
	state.tiles[0].water = 0.3
	TurnResolver.resolve_turn(state)
	assert_eq(state.tiles[0].building, C.Building.HOUSE)
	state.tiles[0].water = 0.5
	TurnResolver.resolve_turn(state)
	assert_eq(state.tiles[0].building, C.Building.NONE)
	state.tiles[0].building = C.Building.HOUSE
	state.mods["house_destroy_level"] = 4.0
	state.tiles[0].water = 20.0
	assert_eq(TurnResolver.resolve_turn(state).destroyed.size(), 0)


func test_rain_paddy_yield_death_and_dead_paddies_count_once() -> void:
	# spec: T-08. Paddy growth is accumulated yield, not food until harvest.
	for depth: float in [0.0, 0.3, 0.5]:
		var state: GameState = _state()
		var tile: Tile = state.tiles[0]
		tile.feature = C.Feature.PADDY
		tile.water = depth
		tile.paddy_yield = 4
		tile.paddy_rain_turns = 1
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(state.food, 10)
		assert_eq(int(state.stats["food_produced"]), 0)
		if depth == 0.3:
			assert_eq(tile.paddy_yield, 5)
			assert_eq(tile.paddy_rain_turns, 2)
			assert_eq(report.paddy_gains, [Vector2i.ZERO])
			assert_true(not tile.paddy_dead)
		elif depth == 0.5:
			assert_eq(tile.paddy_yield, 0)
			assert_true(tile.paddy_dead)
			assert_eq(report.paddies_died, [Vector2i.ZERO])
			assert_eq(int(state.stats["paddies_lost"]), 1)
			tile.water = 0.3
			var repeated: TurnReport = TurnResolver.resolve_turn(state)
			assert_eq(tile.paddy_yield, 0, "dead paddy cannot grow again this year")
			assert_eq(repeated.paddies_died.size(), 0)
			assert_eq(repeated.paddy_gains.size(), 0)
			assert_eq(int(state.stats["paddies_lost"]), 1)
		else:
			assert_eq(tile.paddy_yield, 4)
			assert_eq(tile.paddy_rain_turns, 1)
			assert_eq(report.paddy_gains.size(), 0)


func test_floating_rice_uses_modified_growth_and_death_levels() -> void:
	# spec: T-08, M-05 floating_rice effects without a card-selection phase.
	var state: GameState = _state()
	var tile: Tile = state.tiles[0]
	tile.feature = C.Feature.PADDY
	state.mods["paddy_max_level"] = 2
	state.mods["paddy_death_level"] = 3
	tile.water = 0.7
	assert_eq(TurnResolver.resolve_turn(state).paddy_gains, [Vector2i.ZERO])
	assert_eq(tile.paddy_yield, 1)
	tile.water = 1.0
	assert_eq(TurnResolver.resolve_turn(state).paddies_died, [Vector2i.ZERO])
	assert_eq(tile.paddy_yield, 0)


func test_hall_wet_report_is_current_turn_and_stat_persists() -> void:
	# spec: T-08. Shallow hall water records damage history without ending a run.
	var state: GameState = _state()
	var hall: Tile = state.tiles[0]
	hall.building = C.Building.HALL
	hall.water = 0.3
	var wet: TurnReport = TurnResolver.resolve_turn(state)
	assert_true(wet.hall_wet)
	assert_true(bool(state.stats["hall_ever_wet"]))
	assert_eq(wet.outcome, C.Outcome.NONE)
	hall.water = 0.0
	var dry: TurnReport = TurnResolver.resolve_turn(state)
	assert_true(not dry.hall_wet)
	assert_true(bool(state.stats["hall_ever_wet"]))
	hall.water = 0.5
	var lost: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(lost.outcome, C.Outcome.LOSE_HALL)
	assert_eq(state.outcome, C.Outcome.LOSE_HALL)
	assert_eq(hall.building, C.Building.HALL)


func test_hall_loss_finishes_all_damage_and_populates_after_levels() -> void:
	# spec: T-08. Complete the damage pass even when the first tile loses the hall.
	var state: GameState = _state(1)
	_water_everywhere(state, 0.6)
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.HALL})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.HOUSE})
	TestMaps.set_tile(state, 0, 1, {"feature": C.Feature.PADDY, "paddy_yield": 3})
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.FISH_TRAP})
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_eq(report.destroyed, [{"coord": Vector2i(1, 0), "building": C.Building.HOUSE}])
	assert_eq(report.paddies_died, [Vector2i(0, 1)])
	assert_eq(report.levels_after.size(), state.tiles.size())
	for level: int in report.levels_after:
		assert_eq(level, 2)
	assert_eq(state.food, 10, "hall loss skips fish production")
	assert_eq(report.fish_food, 0)
	assert_eq(int(state.stats["food_produced"]), 0)
	assert_eq(int(state.stats["houses_lost"]), 1)
	assert_eq(int(state.stats["paddies_lost"]), 1)
	assert_eq(state.phase, C.Phase.PLANNING, "resolver does not advance game flow")
	assert_eq(state.turn, 4)


func test_early_loss_skips_growth_of_surviving_paddies() -> void:
	var state: GameState = _state(1)
	_water_everywhere(state, 0.3)
	state.mods["hall_lose_level"] = 1
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.HALL})
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.PADDY, "paddy_yield": 2, "paddy_rain_turns": 1})
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_eq(state.get_tile(Vector2i.ZERO).paddy_yield, 2)
	assert_eq(state.get_tile(Vector2i.ZERO).paddy_rain_turns, 1)
	assert_eq(report.paddy_gains.size(), 0)


func test_dry_paddy_chooses_lowest_tile_index_when_reservoir_water_ties() -> void:
	# spec: T-08. Direction order visits (+1,0) first; tile index visits (-1,0).
	var state: GameState = _state(1, false)
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": 0.75})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": 0.75})
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 0.5, 1e-9)
	assert_near(state.get_tile(Vector2i(1, 0)).water, 0.75, 1e-9)
	assert_eq(report.paddy_gains, [Vector2i.ZERO])
	assert_eq(state.get_tile(Vector2i.ZERO).paddy_yield, 1)
	assert_eq(state.get_tile(Vector2i.ZERO).paddy_rain_turns, 0)
	assert_near(report.dry_paddy_water_used, 0.25, 1e-9)


func test_dry_paddy_prefers_more_water_and_enforces_minimum() -> void:
	var state: GameState = _state(1, false)
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": 0.6})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": 0.8})
	TurnResolver.resolve_turn(state)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 0.6, 1e-9)
	assert_near(state.get_tile(Vector2i(1, 0)).water, 0.55, 1e-9)
	for depth: float in [0.49, 0.5]:
		var fixture: GameState = _state(1, false)
		TestMaps.set_tile(fixture, 0, 0, {"feature": C.Feature.PADDY})
		TestMaps.set_tile(fixture, -1, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": depth})
		var report: TurnReport = TurnResolver.resolve_turn(fixture)
		assert_eq(report.paddy_gains.size(), 1 if depth == 0.5 else 0)


func test_dry_irrigation_consumes_in_tile_order_and_after_levels_are_final() -> void:
	# spec: T-08. The second paddy sees the reservoir after the first one's use.
	var state: GameState = _state(1, false)
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": 0.6})
	TestMaps.set_tile(state, -1, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, 1, 0, {"feature": C.Feature.PADDY})
	var report: TurnReport = TurnResolver.resolve_turn(state)
	var reservoir_index: int = int(state.index[Vector2i.ZERO])
	assert_eq(report.paddy_gains, [Vector2i(-1, 0)])
	assert_near(state.get_tile(Vector2i.ZERO).water, 0.35, 1e-9)
	assert_eq(report.levels_before[reservoir_index], 2)
	assert_eq(report.levels_after[reservoir_index], 1)
	assert_near(float(report.snapshots[1][reservoir_index]), 0.6, 1e-6, "snapshot predates production")
	assert_near(report.dry_paddy_water_used, 0.25, 1e-9)
	assert_near(state.get_tile(Vector2i.ZERO).water - 0.6, -report.dry_paddy_water_used, 1e-9)
	assert_eq(state.get_tile(Vector2i(-1, 0)).paddy_yield, 1)
	assert_eq(state.get_tile(Vector2i(1, 0)).paddy_yield, 0)


func test_unusual_irrigation_amount_cannot_make_reservoir_negative() -> void:
	var state: GameState = _state(1, false)
	state.mods["dry_paddy_water_use"] = 2.0
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.RESERVOIR, "elevation": -1, "water": 0.5})
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 0.0, 1e-9)
	assert_near(report.dry_paddy_water_used, 0.5, 1e-9)
	assert_eq(report.paddy_gains, [Vector2i.ZERO])


func test_fish_production_in_both_seasons_rounds_counts_and_updates_stats() -> void:
	# spec: T-08, M-03. Yield is a rounded count; the product is whole food.
	for rain: bool in [false, true]:
		var state: GameState = _state(0, rain)
		state.tiles[0].building = C.Building.FISH_TRAP
		state.tiles[0].water = 0.1
		state.mods["fish_trap_yield"] = 2.6
		state.mods["fish_trap_multiplier"] = 1.5
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(report.fish_food, 5)
		assert_eq(state.food, 15)
		assert_eq(int(state.stats["food_produced"]), 5)
		state.tiles[0].water = 0.0999
		assert_eq(TurnResolver.resolve_turn(state).fish_food, 0)
		assert_eq(state.food, 15)


func test_water_absorption_evaporation_snapshots_and_damage_order() -> void:
	# spec: T-08, W-06, W-07. Snapshots stop before absorption/evaporation.
	var state: GameState = _state(0, false)
	state.mods["dry_inflow"] = 0.4
	state.mods["evaporation_dry"] = 0.25
	state.tiles[0].water = 0.2
	state.tiles[0].feature = C.Feature.FOREST
	state.tiles[0].is_source = true
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_near(report.inflow, 0.4, 1e-9)
	assert_near(report.absorbed, 0.3, 1e-9)
	assert_near(report.evaporated, 0.25, 1e-9)
	assert_near(state.tiles[0].water, 0.05, 1e-9)
	assert_eq(report.levels_before[0], 1)
	assert_eq(report.levels_after[0], 0)
	assert_eq(report.snapshots.size(), 2)
	assert_near(float(report.snapshots[0][0]), 0.2, 1e-6)
	assert_near(float(report.snapshots[1][0]), 0.6, 1e-6)
	var home: GameState = _state(0, false)
	home.tiles[0].building = C.Building.HOUSE
	home.tiles[0].water = 0.3
	home.mods["evaporation_dry"] = 0.25
	assert_eq(TurnResolver.resolve_turn(home).destroyed.size(), 0, "damage follows evaporation")
	assert_eq(home.tiles[0].building, C.Building.HOUSE)


func test_report_to_dict_uses_json_primitives_and_original_buildings() -> void:
	# spec: T-09. Internal types remain useful to bots; serialization is primitive.
	var report: TurnReport = TurnReport.new()
	report.destroyed.append({"coord": Vector2i(2, -1), "building": C.Building.STILT_HOUSE})
	report.paddies_died.append(Vector2i(-1, 0))
	report.paddy_gains.append(Vector2i(0, 1))
	report.levels_before.append(1)
	report.levels_after.append(2)
	report.snapshots.append(PackedFloat32Array([0.25]))
	report.outcome = C.Outcome.LOSE_HALL
	var data: Dictionary = report.to_dict()
	assert_eq(data["destroyed"], [{"coord": [2, -1], "building": "stilt_house"}])
	assert_eq(data["paddies_died"], [[-1, 0]])
	assert_eq(data["paddy_gains"], [[0, 1]])
	assert_eq(data["levels_before"], [1])
	assert_eq(data["levels_after"], [2])
	assert_eq(data["snapshots"], [[0.25]])
	assert_eq(data["outcome"], "lose_hall")
	assert_true(JSON.parse_string(JSON.stringify(data)) is Dictionary)
	assert_eq(report.destroyed[0]["coord"], Vector2i(2, -1))
	assert_eq(report.destroyed[0]["building"], C.Building.STILT_HOUSE)


func test_resolving_is_deterministic_preserves_rng_and_snapshot_flag_only_changes_report() -> void:
	# spec: T-08, T-10. Same state resolves identically with or without recording.
	var first: GameState = _state(1)
	_water_everywhere(first, 0.3)
	TestMaps.set_tile(first, -1, 0, {"building": C.Building.HOUSE})
	TestMaps.set_tile(first, 0, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(first, 1, 0, {"building": C.Building.FISH_TRAP})
	first.rng.seed = 123
	first.rng.randi()
	var second: GameState = first.duplicate_state()
	second.mods = first.mods.duplicate(true)
	var third: GameState = first.duplicate_state()
	third.mods = first.mods.duplicate(true)
	var rng_state: int = first.rng.state
	var report: TurnReport = TurnResolver.resolve_turn(first, true)
	var repeated: TurnReport = TurnResolver.resolve_turn(second, true)
	var no_snapshots: TurnReport = TurnResolver.resolve_turn(third, false)
	assert_eq(first.rng.state, rng_state)
	assert_eq(second.rng.state, rng_state)
	assert_eq(first.to_dict(), second.to_dict())
	assert_eq(first.to_dict(), third.to_dict())
	assert_eq(report.to_dict(), repeated.to_dict())
	assert_eq(no_snapshots.snapshots.size(), 0)
	var full: Dictionary = report.to_dict()
	var compact: Dictionary = no_snapshots.to_dict()
	full.erase("snapshots")
	compact.erase("snapshots")
	assert_eq(full, compact)
