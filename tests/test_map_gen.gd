extends TestCase
## Plains is the available M1 map. Valley/estuary arrive in a later milestone.


func test_plains_structure_for_fifty_seeds() -> void:
	for seed_value: int in range(1, 51):
		var state: GameState = MapGen.generate(seed_value)
		assert_true(state != null, "generation failed for seed %d" % seed_value)
		if state == null:
			continue
		assert_eq(state.tiles.size(), 61, "seed %d" % seed_value)
		assert_eq(state.seed, seed_value)
		assert_eq(state.map_type, "plains")
		var seas: int = 0
		var sources: int = 0
		var forests: int = 0
		var houses: Array[Tile] = []
		var halls: Array[Tile] = []
		var river: Array[Tile] = []
		var coordinates: Dictionary = {}
		for tile: Tile in state.tiles:
			assert_true(not coordinates.has(tile.coord), "duplicate tile")
			coordinates[tile.coord] = true
			assert_eq(state.get_tile(tile.coord), tile, "generated coordinate index")
			assert_true(tile.elevation >= 0 and tile.elevation <= 4, "plains elevation range")
			assert_true(tile.water >= 0.0, "nonnegative initial water")
			assert_true(tile.building == C.Building.NONE or tile.feature == C.Feature.NONE, "building and feature cannot overlap")
			if tile.is_sea:
				seas += 1
				assert_eq(tile.r, 4, "sea belongs to bottom edge")
				assert_eq(tile.elevation, 0)
			if tile.is_source:
				sources += 1
				assert_eq(tile.coord, Vector2i(0, -4), "top source")
				assert_true(tile.is_river)
			if tile.is_river:
				river.append(tile)
			if tile.feature == C.Feature.FOREST:
				forests += 1
				assert_true(tile.elevation >= 2, "forest needs high ground")
				assert_true(not tile.is_river and not tile.is_sea and not tile.is_source)
			if tile.building == C.Building.HALL:
				halls.append(tile)
			if tile.building == C.Building.HOUSE:
				houses.append(tile)
		assert_eq(seas, 5)
		assert_eq(sources, 1)
		assert_eq(halls.size(), 1)
		assert_eq(houses.size(), 3)
		assert_true(forests >= 8 and forests <= 12, "forest count")
		if halls.size() != 1:
			continue
		var hall: Tile = halls[0]
		assert_eq(hall.elevation, 2)
		assert_true(not hall.is_river and not hall.is_sea and not hall.is_source)
		assert_true(Hex.distance(Vector2i.ZERO, hall.coord) < 4, "hall lies inside map edge")
		var nearest_river: int = 100
		for tile: Tile in river:
			nearest_river = mini(nearest_river, Hex.distance(hall.coord, tile.coord))
		assert_eq(nearest_river, 2, "hall is two hexes from river")
		for house: Tile in houses:
			assert_eq(Hex.distance(hall.coord, house.coord), 1)
			assert_true(house.elevation >= 2)
			assert_true(house.start_house)
			assert_true(not house.is_river and not house.is_source and not house.is_sea)
		_assert_river_reaches_sea(state, river, seed_value)


func _assert_river_reaches_sea(state: GameState, river: Array[Tile], seed_value: int) -> void:
	var source: Tile = state.get_tile(Vector2i(0, -4))
	if source == null or not source.is_river:
		fail("seed %d has no river source" % seed_value)
		return
	var queue: Array[Tile] = [source]
	var visited: Dictionary = {source.coord: true}
	var reaches_sea: bool = false
	var read_index: int = 0
	while read_index < queue.size():
		var tile: Tile = queue[read_index]
		read_index += 1
		for neighbor: Tile in state.neighbors(tile):
			if neighbor.is_sea:
				reaches_sea = true
			if neighbor.is_river and not visited.has(neighbor.coord):
				visited[neighbor.coord] = true
				queue.append(neighbor)
	assert_true(reaches_sea, "seed %d river must reach a sea neighbor" % seed_value)
	assert_eq(visited.size(), river.size(), "every river hex is connected to the source")


func test_same_seed_generates_identical_state() -> void:
	for seed_value: int in range(1, 51):
		var first: GameState = MapGen.generate(seed_value)
		var second: GameState = MapGen.generate(seed_value)
		assert_true(first != null and second != null, "seed %d" % seed_value)
		if first != null and second != null:
			assert_eq(first.to_dict(), second.to_dict(), "deterministic seed %d" % seed_value)


func test_untouched_first_year_midpoint_rain_keeps_hall_dry() -> void:
	var rain_range: Array = DataDB.balance()["rain_table"]["1"]
	var rain_per_turn: float = (float(rain_range[0]) + float(rain_range[1])) / 6.0
	for seed_value: int in range(1, 51):
		var state: GameState = MapGen.generate(seed_value)
		if state == null:
			fail("generation failed for seed %d" % seed_value)
			continue
		var hall: Tile = null
		for tile: Tile in state.tiles:
			if tile.building == C.Building.HALL:
				hall = tile
		if hall == null:
			fail("seed %d has no hall" % seed_value)
			continue
		for turn_number: int in range(1, 7):
			state.turn = turn_number
			var inflow: float = rain_per_turn if state.is_rain() else float(state.mod("dry_inflow"))
			WaterSim.simulate(state, inflow, false)
			WaterSim.absorb(state)
			WaterSim.evaporate(state)
			assert_eq(state.level_of(hall), 0, "seed %d hall flooded on turn %d" % [seed_value, turn_number])
