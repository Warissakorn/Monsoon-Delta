class_name IrrigationFixtures
extends RefCounted
## Authored core-mechanic fixtures, separate from generated player maps.

const RESERVOIR: Vector2i = Vector2i.ZERO
const FIELDS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0)]
const HALL: Vector2i = Vector2i(-2, 0)


static func create(ruleset: String = "moisture_irrigation_v1", living: bool = false) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 824, "ruleset": ruleset, "leader": "fisher"})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.building = C.Building.NONE
		tile.feature = C.Feature.NONE
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.start_house = false
	state.get_tile(HALL).building = C.Building.HALL
	state.get_tile(HALL).elevation = 4
	for coord: Vector2i in [Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(-1, 0)]:
		state.get_tile(coord).building = C.Building.HOUSE
		state.get_tile(coord).elevation = 4
		state.get_tile(coord).start_house = true
	var reservoir: Tile = state.get_tile(RESERVOIR)
	reservoir.elevation = 0
	reservoir.water = 1.0
	reservoir.building = C.Building.RESERVOIR
	for coord: Vector2i in FIELDS:
		state.get_tile(coord).feature = C.Feature.PADDY
	if state.has_moisture():
		state.get_tile(FIELDS[0]).soil_moisture = 1
	state.rain_inflows.assign([3.0, 3.0, 4.0])
	state.food = 50
	if living:
		SettlementProgress.initialize(state)
	return state
