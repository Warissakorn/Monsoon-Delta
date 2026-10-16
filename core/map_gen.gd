class_name MapGen
extends RefCounted

## Plains implementation from GDD section 2. The missing 03_hex_map spec's
## conventions and validation remain provisional; see docs/PROGRESS.md.


static func generate(seed_value: int) -> GameState:
	var config: Dictionary = DataDB.balance()["map_generation"]
	var attempt_count: int = int(config["max_attempts"])
	for attempt: int in range(attempt_count):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = SeedUtil.derive_seed(seed_value, attempt)
		var state: GameState = _make_terrain(seed_value, rng, config)
		_carve_river(state, rng, config)
		if not _place_village(state, rng, config):
			continue
		if not _plant_forests(state, rng, config):
			continue
		if not _passes_first_year_safety(state):
			continue
		return state
	push_error("Could not generate a plains map within the configured attempt limit.")
	return null


static func _make_terrain(
	seed_value: int, rng: RandomNumberGenerator, config: Dictionary
) -> GameState:
	var state: GameState = GameState.new()
	state.seed = seed_value
	state.rng.seed = seed_value
	state.map_type = "plains"
	state.year = 1
	state.turn = 1
	state.phase = C.Phase.PLANNING
	for coord: Vector2i in Hex.coords():
		var tile: Tile = Tile.new(coord.x, coord.y)
		var base_elevation: int = int(config["plains_bottom_elevation"])
		if coord.y <= int(config["plains_top_max_r"]):
			base_elevation = int(config["plains_top_elevation"])
		elif coord.y <= int(config["plains_middle_max_r"]):
			base_elevation = int(config["plains_middle_elevation"])
		var noise: int = int(config["elevation_noise"])
		tile.elevation = clampi(
			base_elevation + rng.randi_range(-noise, noise),
			int(config["elevation_min"]), int(config["elevation_max"])
		)
		if coord.y == C.MAP_RADIUS:
			tile.is_sea = true
			tile.elevation = int(config["sea_elevation"])
		state.tiles.append(tile)
	state.rebuild_index()
	state.recompute_mods()
	for tile: Tile in state.tiles:
		if tile.is_sea:
			tile.water = float(state.mod("sea_level_dry"))
	return state


static func _carve_river(
	state: GameState, rng: RandomNumberGenerator, config: Dictionary
) -> void:
	var cursor: Vector2i = Vector2i(0, -C.MAP_RADIUS)
	state.get_tile(cursor).is_source = true
	while true:
		var tile: Tile = state.get_tile(cursor)
		tile.is_river = true
		if tile.is_sea:
			break
		tile.elevation = int(config["river_upper_elevation"])
		if cursor.y >= int(config["river_split_r"]):
			tile.elevation = int(config["river_lower_elevation"])
		tile.water = float(config["river_initial_water"])
		var options: Array[Vector2i] = []
		for dir: int in [4, 5]:
			var next: Vector2i = Hex.neighbor(cursor, dir)
			if state.get_tile(next) != null:
				options.append(next)
		cursor = options[rng.randi_range(0, options.size() - 1)]


static func _place_village(
	state: GameState, rng: RandomNumberGenerator, config: Dictionary
) -> bool:
	var halls: Array[Tile] = []
	var house_count: int = int(config["starting_houses"])
	for tile: Tile in state.tiles:
		if tile.is_river or tile.is_sea or tile.is_source:
			continue
		if Hex.distance(Vector2i.ZERO, tile.coord) >= C.MAP_RADIUS:
			continue
		if tile.elevation < int(config["hall_elevation"]):
			continue
		if _river_distance(state, tile.coord) != int(config["hall_river_distance"]):
			continue
		if _house_locations(state, tile, config).size() >= house_count:
			halls.append(tile)
	if halls.is_empty():
		return false
	var hall: Tile = halls[rng.randi_range(0, halls.size() - 1)]
	hall.elevation = int(config["hall_elevation"])
	hall.building = C.Building.HALL
	var houses: Array[Tile] = _house_locations(state, hall, config)
	_shuffle_tiles(houses, rng)
	for index: int in range(house_count):
		houses[index].building = C.Building.HOUSE
		houses[index].start_house = true
	return true


static func _house_locations(state: GameState, hall: Tile, config: Dictionary) -> Array[Tile]:
	var result: Array[Tile] = []
	for tile: Tile in state.neighbors(hall):
		if tile.is_river or tile.is_source or tile.is_sea:
			continue
		if tile.elevation >= int(config["house_min_elevation"]):
			result.append(tile)
	return result


static func _river_distance(state: GameState, coord: Vector2i) -> int:
	var nearest: int = C.MAP_RADIUS * 2 + 1
	for tile: Tile in state.tiles:
		if tile.is_river:
			nearest = mini(nearest, Hex.distance(coord, tile.coord))
	return nearest


static func _plant_forests(
	state: GameState, rng: RandomNumberGenerator, config: Dictionary
) -> bool:
	var eligible: Array[Tile] = []
	for tile: Tile in state.tiles:
		if tile.is_river or tile.is_source or tile.is_sea or tile.building != C.Building.NONE:
			continue
		if tile.elevation >= int(config["forest_min_elevation"]):
			eligible.append(tile)
	var target: int = rng.randi_range(int(config["forest_min"]), int(config["forest_max"]))
	if eligible.size() < target:
		return false
	var planted: Array[Tile] = []
	while planted.size() < target:
		var choices: Array[Tile] = []
		var nearest: int = C.MAP_RADIUS * 2 + 1
		for tile: Tile in eligible:
			var distance: int = 0
			if not planted.is_empty():
				distance = C.MAP_RADIUS * 2 + 1
				for tree: Tile in planted:
					distance = mini(distance, Hex.distance(tile.coord, tree.coord))
			if distance < nearest:
				nearest = distance
				choices.clear()
			if distance == nearest:
				choices.append(tile)
		var chosen: Tile = choices[rng.randi_range(0, choices.size() - 1)]
		chosen.feature = C.Feature.FOREST
		planted.append(chosen)
		eligible.erase(chosen)
	return true


static func _shuffle_tiles(tiles: Array[Tile], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var tile: Tile = tiles[index]
		tiles[index] = tiles[other]
		tiles[other] = tile


static func _passes_first_year_safety(state: GameState) -> bool:
	# GDD section 2: reject maps where an untouched first year wets the hall.
	# The missing MG-05 details are approximated by evenly dividing midpoint rain.
	var preview: GameState = state.duplicate_state()
	var first_year_range: Array = DataDB.balance()["rain_table"]["1"]
	var rain_turns: int = C.TURNS_PER_YEAR - C.DRY_TURNS
	var rain_inflow: float = (
		(float(first_year_range[0]) + float(first_year_range[1])) / 2.0 / float(rain_turns)
	)
	var hall: Tile = null
	for tile: Tile in preview.tiles:
		if tile.building == C.Building.HALL:
			hall = tile
			break
	if hall == null:
		return false
	for turn: int in range(1, C.TURNS_PER_YEAR + 1):
		preview.turn = turn
		var inflow: float = rain_inflow if preview.is_rain() else float(preview.mod("dry_inflow"))
		WaterSim.simulate(preview, inflow, false)
		WaterSim.absorb(preview)
		WaterSim.evaporate(preview)
		if preview.level_of(hall) >= 1:
			return false
	return true
