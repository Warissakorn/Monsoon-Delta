class_name EndTurnFixtures
extends RefCounted
## Authored initial boards for end-turn UI checks, using unchanged game rules.
const HOME: Vector2i = Vector2i(-1, 0)
const FIELD: Vector2i = Vector2i(2, -2)
const HALL: Vector2i = Vector2i(-2, 0)


static func create(damage: bool = false, turn: int = 4) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 812})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.get_tile(HALL).elevation = 4
	state.get_tile(HALL).building = C.Building.HALL
	for coord: Vector2i in [Vector2i(-2, 1), Vector2i(-1, 1), HOME]:
		state.get_tile(coord).building = C.Building.HOUSE
		state.get_tile(coord).elevation = 4
	if damage:
		state.get_tile(HOME).elevation = 0
		state.get_tile(HOME).water = 0.3
	state.get_tile(FIELD).feature = C.Feature.PADDY
	state.get_tile(FIELD).elevation = 0
	state.get_tile(FIELD).water = 0.8 if damage else 0.3
	var fish: Tile = state.get_tile(Vector2i(1, 0))
	fish.building = C.Building.FISH_TRAP
	fish.elevation = 0
	fish.water = 0.3
	state.food = 50
	state.turn = turn
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	return state
