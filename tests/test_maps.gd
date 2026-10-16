class_name TestMaps
extends RefCounted
## Explicit small fixtures without generated terrain or hidden water sinks.


static func small(radius: int, elevation: int) -> GameState:
	var state := GameState.new()
	state.phase = C.Phase.PLANNING
	state.year = 1
	state.turn = 1
	state.population = 10
	state.food = 10
	state.wood = 10
	state.labor = 10
	state.labor_max = 10
	for coord: Vector2i in Hex.coords(radius):
		var tile := Tile.new(coord.x, coord.y)
		tile.elevation = elevation
		state.tiles.append(tile)
	state.rebuild_index()
	state.recompute_mods()
	return state


static func set_tile(state: GameState, q: int, r: int, properties: Dictionary) -> void:
	var tile: Tile = state.get_tile(Vector2i(q, r))
	assert(tile != null, "TestMaps.set_tile: coordinate is outside the fixture")
	for property: String in properties:
		tile.set(property, properties[property])
