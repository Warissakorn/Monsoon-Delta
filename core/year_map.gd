class_name YearMap
extends RefCounted
## Extend the existing seeded village; preserve the inner river and homes.


static func generate(seed_value: int) -> GameState:
	var original: GameState = GameFlow.new_game({"seed": seed_value})
	if original == null:
		return null
	var result: GameState = original.duplicate_state()
	result.tiles.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SeedUtil.derive_seed(seed_value, 127)
	for coord: Vector2i in Hex.coords(6):
		var old: Tile = original.get_tile(coord)
		var tile: Tile = Tile.from_dict(old.to_dict()) if old != null else Tile.new(coord.x, coord.y)
		if old == null:
			tile.elevation = clampi((3 if coord.y < 1 else 1) + rng.randi_range(-1, 1), 0, 4)
			if coord.y < 4 and rng.randf() < 0.4:
				tile.feature = C.Feature.FOREST
		# The old coast becomes the wetland within the larger local basin.
		tile.is_sea = coord.y == 6
		tile.is_source = coord == Vector2i(0, -6)
		if tile.is_sea:
			tile.elevation = 0
			tile.water = 0.0
			tile.feature = C.Feature.NONE
		if coord in [Vector2i(0, -6), Vector2i(0, -5)]:
			tile.is_river = true
			tile.elevation = 1
			tile.water = 0.3
			tile.feature = C.Feature.NONE
		result.tiles.append(tile)
	result.rebuild_index()
	for tile: Tile in original.tiles:
		if not tile.is_river or not tile.is_sea:
			continue
		var cursor: Vector2i = tile.coord
		while cursor.y < 6:
			cursor = Hex.neighbor(cursor, 5)
			var extension: Tile = result.get_tile(cursor)
			extension.is_river = true
			extension.elevation = 0
			extension.feature = C.Feature.NONE
			extension.water = 0.0 if extension.is_sea else 0.3
	return result
