extends TestCase


func _state(radius: int = 1, elevation: int = 0, iterations: int = 1) -> GameState:
	var state: GameState = TestMaps.small(radius, elevation)
	state.mods["water_iterations"] = iterations
	state.mods["flow_rate"] = 0.5
	return state


func _land_water(state: GameState) -> float:
	var total: float = 0.0
	for tile: Tile in state.tiles:
		if not tile.is_sea:
			total += tile.water
	return total


func _index_of(state: GameState, coord: Vector2i) -> int:
	for i: int in state.tiles.size():
		if state.tiles[i].coord == coord:
			return i
	return -1


func test_hand_calculated_single_iteration() -> void:
	var state: GameState = _state()
	state.get_tile(Vector2i.ZERO).water = 1.0
	var result: Dictionary = WaterSim.simulate(state, 0.0, true)
	assert_near(state.get_tile(Vector2i.ZERO).water, 4.0 / 7.0, 1e-5, "W-04 center")
	for tile: Tile in state.tiles:
		if tile.coord != Vector2i.ZERO:
			assert_near(tile.water, 1.0 / 14.0, 1e-5, "W-04 neighbor %s" % tile.coord)
	assert_near(_land_water(state), 1.0, 1e-9, "W-08 redistribution conserves water")
	assert_near(float(result["to_sea"]), 0.0, 1e-9)
	assert_near(float(result["from_sea"]), 0.0, 1e-9)


func test_flow_rate_is_clamped_to_specification() -> void:
	for requested: float in [-1.0, 2.0]:
		var state: GameState = _state()
		state.mods["flow_rate"] = requested
		state.get_tile(Vector2i.ZERO).water = 1.0
		WaterSim.simulate(state, 0.0, false)
		var flow: float = 0.05 if requested < 0.0 else 0.9
		assert_near(state.get_tile(Vector2i.ZERO).water, 1.0 - 6.0 / 7.0 * flow, 1e-9)


func test_sources_share_inflow_over_all_iterations() -> void:
	var state: GameState = _state(1, 4, 4)
	for coord: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0)]:
		TestMaps.set_tile(state, coord.x, coord.y, {"elevation": 0, "is_source": true})
	var result: Dictionary = WaterSim.simulate(state, 1.2, false)
	assert_near(float(result["inflow"]), 1.2, 1e-9)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 0.6, 1e-9)
	assert_near(state.get_tile(Vector2i(1, 0)).water, 0.6, 1e-9)
	assert_near(_land_water(state), 1.2, 1e-9)
	assert_eq(result["snapshots"].size(), 0, "recording may be disabled")
	var no_source: GameState = _state(0)
	var absent: Dictionary = WaterSim.simulate(no_source, 5.0, false)
	assert_near(float(absent["inflow"]), 0.0, 1e-9, "no source means no applied inflow")
	assert_near(_land_water(no_source), 0.0, 1e-9)


func test_snapshots_include_initial_and_each_independent_iteration() -> void:
	var state: GameState = _state(1, 0, 3)
	state.get_tile(Vector2i.ZERO).water = 1.0
	var result: Dictionary = WaterSim.simulate(state, 0.0, true)
	var snapshots: Array = result["snapshots"]
	assert_eq(snapshots.size(), 4, "W-04 N + 1 snapshots")
	var center: int = _index_of(state, Vector2i.ZERO)
	assert_near(float(snapshots[0][center]), 1.0, 1e-6, "initial snapshot is preserved")
	assert_near(float(snapshots[1][center]), 4.0 / 7.0, 1e-6)
	for snapshot: PackedFloat32Array in snapshots:
		assert_eq(snapshot.size(), state.tiles.size())
	for i: int in state.tiles.size():
		assert_near(float(snapshots.back()[i]), state.tiles[i].water, 1e-6)
	var recorded: float = float(snapshots.back()[center])
	state.get_tile(Vector2i.ZERO).water = 9.0
	assert_near(float(snapshots.back()[center]), recorded, 1e-9, "snapshot does not reference live tiles")
	assert_near(float(snapshots[0][center]), 1.0, 1e-9)


func test_water_cannot_flow_to_higher_surface() -> void:
	var state: GameState = _state(1, 0, 20)
	for tile: Tile in state.tiles:
		tile.water = 3.0
	TestMaps.set_tile(state, 0, 0, {"elevation": 4, "water": 0.0})
	WaterSim.simulate(state, 0.0, false)
	assert_near(state.get_tile(Vector2i.ZERO).water, 0.0, 1e-9, "W-01/W-09 elevation 4 exceeds adjacent surfaces")
	assert_near(_land_water(state), 18.0, 1e-9)


func test_closed_gate_blocks_both_directions_and_keeps_trapped_water() -> void:
	# Only these three lowered cells form a channel; all other cells are dry walls.
	var state: GameState = _state(1, 4, 12)
	TestMaps.set_tile(state, -1, 0, {"elevation": 0, "water": 2.0})
	TestMaps.set_tile(state, 0, 0, {"elevation": 0, "water": 0.75, "building": C.Building.GATE, "gate_open": false})
	TestMaps.set_tile(state, 1, 0, {"elevation": 0})
	WaterSim.simulate(state, 0.0, false)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 2.0, 1e-9, "closed gate receives no water")
	assert_near(state.get_tile(Vector2i.ZERO).water, 0.75, 1e-9, "closed gate retains trapped water")
	assert_near(state.get_tile(Vector2i(1, 0)).water, 0.0, 1e-9, "closed gate sends no water downstream")
	state.get_tile(Vector2i.ZERO).gate_open = true
	WaterSim.simulate(state, 0.0, false)
	assert_true(state.get_tile(Vector2i(1, 0)).water > 0.0, "open gate permits flow")
	assert_near(_land_water(state), 2.75, 1e-9)


func test_waterwheel_runs_once_before_first_snapshot_and_is_capped() -> void:
	for available: float in [0.2, 2.0]:
		var state: GameState = _state(1, 0, 5)
		var wheel: Tile = state.get_tile(Vector2i.ZERO)
		wheel.building = C.Building.WATERWHEEL
		wheel.wheel_dir = 0
		var source: Tile = state.neighbor_in_dir(wheel, 0)
		source.water = available
		var result: Dictionary = WaterSim.simulate(state, 0.0, true)
		var expected: float = minf(0.5, available)
		var first: PackedFloat32Array = result["snapshots"][0]
		assert_near(float(result["wheel_moved"]), expected, 1e-9, "W-03 runs once, not once per iteration")
		assert_near(float(first[_index_of(state, wheel.coord)]), expected, 1e-6)
		assert_near(float(first[_index_of(state, source.coord)]), available - expected, 1e-6)
		assert_near(_land_water(state), available, 1e-9, "wheel only transfers existing water")


func test_waterwheel_ignores_closed_gate_sea_and_missing_source() -> void:
	for blocked: String in ["closed_gate", "sea", "missing"]:
		var state: GameState = _state(0 if blocked == "missing" else 1)
		var wheel: Tile = state.get_tile(Vector2i.ZERO)
		wheel.building = C.Building.WATERWHEEL
		wheel.wheel_dir = 0
		if blocked != "missing":
			var source: Tile = state.neighbor_in_dir(wheel, 0)
			source.water = 1.0
			if blocked == "closed_gate":
				source.building = C.Building.GATE
				source.gate_open = false
			else:
				source.is_sea = true
		var result: Dictionary = WaterSim.simulate(state, 0.0, true)
		assert_near(float(result["wheel_moved"]), 0.0, 1e-9, blocked)
		assert_near(float(result["snapshots"][0][_index_of(state, wheel.coord)]), 0.0, 1e-9, blocked)


func test_waterwheel_uses_tile_index_order() -> void:
	var state: GameState = _state()
	var source: Tile = state.get_tile(Vector2i.ZERO)
	source.water = 0.7
	var wheels: Array[Tile] = []
	for tile: Tile in state.tiles:
		if tile.coord == Vector2i.ZERO:
			continue
		if wheels.size() == 2:
			break
		tile.building = C.Building.WATERWHEEL
		for direction: int in 6:
			if state.neighbor_in_dir(tile, direction) == source:
				tile.wheel_dir = direction
				break
		wheels.append(tile)
	var result: Dictionary = WaterSim.simulate(state, 0.0, true)
	var first: PackedFloat32Array = result["snapshots"][0]
	assert_near(float(first[_index_of(state, wheels[0].coord)]), 0.5, 1e-6)
	assert_near(float(first[_index_of(state, wheels[1].coord)]), 0.2, 1e-6)
	assert_near(float(result["wheel_moved"]), 0.7, 1e-9)


func test_sea_exchange_is_reported_and_season_level_is_restored() -> void:
	for direction: String in ["to_sea", "from_sea"]:
		var state: GameState = _state(1, 4)
		TestMaps.set_tile(state, 0, 0, {"elevation": 0, "water": 1.0 if direction == "to_sea" else 0.0})
		TestMaps.set_tile(state, 1, 0, {"elevation": 0, "is_sea": true, "water": 0.0 if direction == "to_sea" else 1.0})
		state.mods["sea_level_dry"] = 0.2
		state.mods["sea_level_rain"] = 0.6
		state.turn = 1 if direction == "to_sea" else 4
		var before: float = _land_water(state)
		var result: Dictionary = WaterSim.simulate(state, 0.0, false)
		assert_near(float(result[direction]), 0.25, 1e-9)
		assert_near(float(result["from_sea" if direction == "to_sea" else "to_sea"]), 0.0, 1e-9)
		assert_near(state.get_tile(Vector2i(1, 0)).water, 0.2 if state.turn == 1 else 0.6, 1e-9)
		assert_near(_land_water(state) - before, -float(result["to_sea"]) + float(result["from_sea"]), 1e-9)


func test_absorption_is_limited_by_water_and_skips_sea() -> void:
	var state: GameState = _state()
	state.mods["forest_absorb"] = 0.3
	state.mods["sapling_absorb"] = 0.1
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.FOREST, "water": 0.2})
	TestMaps.set_tile(state, 1, 0, {"feature": C.Feature.FOREST, "water": 0.8})
	TestMaps.set_tile(state, -1, 0, {"feature": C.Feature.SAPLING, "water": 0.4})
	TestMaps.set_tile(state, 0, 1, {"feature": C.Feature.FOREST, "is_sea": true, "water": 0.7})
	TestMaps.set_tile(state, 0, -1, {"feature": C.Feature.PADDY, "water": 0.4})
	assert_near(WaterSim.absorb(state), 0.6, 1e-9, "W-06 sum of limited absorption")
	assert_near(state.get_tile(Vector2i.ZERO).water, 0.0, 1e-9)
	assert_near(state.get_tile(Vector2i(1, 0)).water, 0.5, 1e-9)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 0.3, 1e-9)
	assert_near(state.get_tile(Vector2i(0, 1)).water, 0.7, 1e-9)
	assert_near(state.get_tile(Vector2i(0, -1)).water, 0.4, 1e-9)


func test_evaporation_applies_multiplier_only_to_dry_land() -> void:
	var state: GameState = _state()
	state.mods["evaporation_dry"] = 0.25
	state.mods["evaporation_multiplier"] = 2.0
	TestMaps.set_tile(state, 0, 0, {"water": 0.2})
	TestMaps.set_tile(state, 1, 0, {"water": 0.8})
	TestMaps.set_tile(state, -1, 0, {"is_sea": true, "water": 0.7})
	assert_near(WaterSim.evaporate(state), 0.7, 1e-9)
	assert_near(state.get_tile(Vector2i.ZERO).water, 0.0, 1e-9)
	assert_near(state.get_tile(Vector2i(1, 0)).water, 0.3, 1e-9)
	assert_near(state.get_tile(Vector2i(-1, 0)).water, 0.7, 1e-9)
	state.turn = 4
	var before: float = _land_water(state)
	assert_near(WaterSim.evaporate(state), 0.0, 1e-9, "W-07 rain never evaporates")
	assert_near(_land_water(state), before, 1e-9)


func test_water_level_boundaries_use_water_depth() -> void:
	var state: GameState = _state(0, 4)
	var tile: Tile = state.get_tile(Vector2i.ZERO)
	var depths: Array[float] = [0.0, 0.0999, 0.1, 0.4999, 0.5, 0.9999, 1.0, 2.0]
	var levels: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
	for i: int in depths.size():
		tile.water = depths[i]
		assert_eq(state.level_of(tile), levels[i], "W-02 depth %s" % depths[i])


func test_mass_balance_and_determinism_for_100_seeds_and_six_turns() -> void:
	var total_to_sea: float = 0.0
	var total_from_sea: float = 0.0
	var total_absorbed: float = 0.0
	var total_evaporated: float = 0.0
	for seed_value: int in range(1, 101):
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		var state: GameState = _state(2, 0, random.randi_range(1, 12))
		state.seed = seed_value
		state.mods["flow_rate"] = random.randf_range(0.05, 0.9)
		state.mods["sea_level_dry"] = 0.2
		state.mods["sea_level_rain"] = 0.6
		state.mods["sapling_absorb"] = 0.12
		for tile: Tile in state.tiles:
			tile.elevation = random.randi_range(-1, 4)
			tile.water = random.randf_range(0.0, 2.0)
			tile.feature = [C.Feature.NONE, C.Feature.FOREST, C.Feature.SAPLING][random.randi_range(0, 2)]
		TestMaps.set_tile(state, -2, 0, {"elevation": 2, "is_sea": true, "water": 0.2})
		TestMaps.set_tile(state, 2, 0, {"elevation": -3, "is_sea": true, "water": 0.2})
		TestMaps.set_tile(state, -1, 0, {"elevation": -1, "is_source": true})
		TestMaps.set_tile(state, 0, -1, {"is_source": true})
		TestMaps.set_tile(state, 0, 0, {"building": C.Building.WATERWHEEL, "feature": C.Feature.NONE, "wheel_dir": 0})
		TestMaps.set_tile(state, 0, 1, {"building": C.Building.GATE, "feature": C.Feature.NONE, "gate_open": false})
		for turn: int in range(1, 7):
			state.turn = turn
			state.get_tile(Vector2i(0, 1)).gate_open = turn % 2 == 0
			var incoming: float = random.randf_range(0.1, 3.0)
			var before: float = _land_water(state)
			var duplicate: GameState = state.duplicate_state()
			# Mod overrides are fixture configuration, not serialized game modifiers.
			duplicate.mods = state.mods.duplicate(true)
			var rng_before: int = state.rng.state
			var result: Dictionary = WaterSim.simulate(state, incoming, false)
			var repeated: Dictionary = WaterSim.simulate(duplicate, incoming, false)
			var label: String = "seed %d turn %d" % [seed_value, turn]
			assert_eq(result, repeated, "deterministic report " + label)
			assert_eq(state.rng.state, rng_before, "simulation must not consume RNG " + label)
			for i: int in state.tiles.size():
				assert_eq(state.tiles[i].water, duplicate.tiles[i].water, "deterministic water " + label)
			var absorbed: float = WaterSim.absorb(state)
			var evaporated: float = WaterSim.evaporate(state)
			var expected: float = incoming - float(result["to_sea"]) + float(result["from_sea"]) - absorbed - evaporated
			assert_near(_land_water(state) - before, expected, 1e-3, "W-08 " + label)
			assert_near(float(result["inflow"]), incoming, 1e-9, label)
			if turn >= 4:
				assert_near(evaporated, 0.0, 1e-9, "rain " + label)
			for tile: Tile in state.tiles:
				assert_true(is_finite(tile.water) and tile.water >= 0.0, "valid water " + label)
			total_to_sea += float(result["to_sea"])
			total_from_sea += float(result["from_sea"])
			total_absorbed += absorbed
			total_evaporated += evaporated
	assert_true(total_to_sea > 0.0 and total_from_sea > 0.0, "mass fixtures exercise both sea exchange directions")
	assert_true(total_absorbed > 0.0 and total_evaporated > 0.0, "mass fixtures exercise both water sinks")


func test_sandbox_edit_changes_one_step_within_data_bounds() -> void:
	var state: GameState = _state(0)
	var coord := Vector2i.ZERO
	assert_true(GameFlow.sandbox_edit(state, coord, -1))
	assert_eq(state.get_tile(coord).elevation, -1)
	assert_true(GameFlow.sandbox_edit(state, coord, 1))
	assert_eq(state.get_tile(coord).elevation, 0)
	var limits: Dictionary = DataDB.balance()["sandbox"]
	for edge: String in ["elevation_min", "elevation_max"]:
		var amount: int = -1 if edge == "elevation_min" else 1
		state.get_tile(coord).elevation = int(limits[edge]) - amount
		assert_true(GameFlow.sandbox_edit(state, coord, amount), "may reach " + edge)
		assert_eq(state.get_tile(coord).elevation, int(limits[edge]))
		assert_true(not GameFlow.sandbox_edit(state, coord, amount), "may not cross " + edge)
		assert_eq(state.get_tile(coord).elevation, int(limits[edge]))


func test_sandbox_edit_rejects_occupied_special_missing_and_invalid_steps() -> void:
	var restrictions: Array[Dictionary] = [
		{"is_source": true}, {"is_sea": true},
		{"feature": C.Feature.FOREST}, {"feature": C.Feature.SAPLING}, {"feature": C.Feature.PADDY},
	]
	for building: int in range(1, C.Building.size()):
		restrictions.append({"building": building})
	for properties: Dictionary in restrictions:
		var state: GameState = _state(0)
		TestMaps.set_tile(state, 0, 0, properties)
		var before: Dictionary = state.to_dict()
		assert_true(not GameFlow.sandbox_edit(state, Vector2i.ZERO, -1), "protected tile %s" % properties)
		assert_true(not GameFlow.sandbox_edit(state, Vector2i.ZERO, 1), "protected tile %s" % properties)
		assert_eq(state.to_dict(), before, "rejected edit preserves state")
	var plain: GameState = _state(0)
	for amount: int in [-2, 0, 2]:
		assert_true(not GameFlow.sandbox_edit(plain, Vector2i.ZERO, amount), "only +/- 1 are allowed")
	assert_true(not GameFlow.sandbox_edit(plain, Vector2i(9, 9), 1), "missing tile")
	assert_eq(plain.get_tile(Vector2i.ZERO).elevation, 0)


func test_sandbox_step_reports_rain_absorption_without_evaporation() -> void:
	var state: GameState = _state(0)
	TestMaps.set_tile(state, 0, 0, {"water": 0.8, "is_source": true, "feature": C.Feature.FOREST})
	state.mods["forest_absorb"] = 0.3
	state.mods["evaporation_dry"] = 10.0
	state.turn = 1
	var result: Dictionary = GameFlow.sandbox_step(state, 0.4)
	assert_true(state.is_rain(), "sandbox steps in rain season")
	assert_near(float(result["before"]), 0.8, 1e-9)
	assert_near(float(result["inflow"]), 0.4, 1e-9)
	assert_near(float(result["absorbed"]), 0.3, 1e-9)
	assert_near(float(result["evaporated"]), 0.0, 1e-9)
	assert_near(float(result["after"]), 0.9, 1e-9)
	assert_near(state.get_tile(Vector2i.ZERO).water, 0.9, 1e-9)
	assert_near(float(result["balance_error"]), 0.0, 1e-9)
	assert_eq(result["snapshots"].size(), 2)
	assert_near(float(result["snapshots"][1][0]), 1.2, 1e-6, "snapshots precede absorption")
