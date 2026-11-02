class_name AreaDevelopmentFixtures
extends RefCounted
## Authored initial board covering area types; ordinary commands resolve play.
const LAND: Vector2i = Vector2i.ZERO
const LOW: Vector2i = Vector2i(2, -1)
const WET: Vector2i = Vector2i(2, 0)
const FIELD: Vector2i = Vector2i(2, -2)
const DEAD: Vector2i = Vector2i(1, 1)
const FOREST: Vector2i = Vector2i(0, -2)
const SAPLING: Vector2i = Vector2i(1, -2)
const HALL: Vector2i = Vector2i(-2, 0)
const HOUSE: Vector2i = Vector2i(-1, 0)
const STILT: Vector2i = Vector2i(-3, 1)
const RAFT: Vector2i = Vector2i(0, 1)
const GATE: Vector2i = Vector2i(-1, -1)
const POND: Vector2i = Vector2i(3, -2)
const FISH: Vector2i = Vector2i(1, 0)
const GRANARY: Vector2i = Vector2i(-2, 2)
const WHEEL: Vector2i = Vector2i(-2, -1)
const SOURCE: Vector2i = Vector2i(0, -4)
const SEA: Vector2i = Vector2i(0, 4)
const RIVER: Vector2i = Vector2i(0, -3)


static func create(rain: bool = false, ruleset: String = "legacy", run_mode: String = "classic") -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 928, "ruleset": ruleset, "run_mode": run_mode})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
		tile.brace_turns = 0
		tile.soil_moisture = 0
		tile.irrigation_policy = "normal"
	state.get_tile(LAND).elevation = 2
	state.get_tile(LOW).elevation = 0
	state.get_tile(WET).elevation = 0
	state.get_tile(WET).water = 0.3
	state.get_tile(FIELD).feature = C.Feature.PADDY
	state.get_tile(FIELD).elevation = 0
	state.get_tile(FIELD).water = 0.3 if rain else 0.0
	state.get_tile(DEAD).feature = C.Feature.PADDY
	state.get_tile(DEAD).paddy_dead = true
	state.get_tile(FOREST).feature = C.Feature.FOREST
	state.get_tile(SAPLING).feature = C.Feature.SAPLING
	state.get_tile(HALL).building = C.Building.HALL
	for coord: Vector2i in [HOUSE, Vector2i(-2, 1), Vector2i(-1, 1)]:
		state.get_tile(coord).building = C.Building.HOUSE
	for entry: Array in [[STILT, C.Building.STILT_HOUSE], [RAFT, C.Building.RAFT_HOUSE], [GATE, C.Building.GATE], [POND, C.Building.RESERVOIR], [FISH, C.Building.FISH_TRAP], [GRANARY, C.Building.GRANARY], [WHEEL, C.Building.WATERWHEEL]]:
		state.get_tile(entry[0]).building = int(entry[1])
	for coord: Vector2i in [RAFT, POND, FISH]:
		state.get_tile(coord).elevation = 0
		state.get_tile(coord).water = 1.0 if coord == POND else 0.3
	state.get_tile(WHEEL).wheel_dir = 0
	state.get_tile(SOURCE).is_source = true
	state.get_tile(SOURCE).is_river = true
	state.get_tile(SOURCE).elevation = 1
	state.get_tile(SOURCE).water = 0.3
	state.get_tile(RIVER).is_river = true
	state.get_tile(RIVER).elevation = 1
	state.get_tile(RIVER).water = 0.3
	state.get_tile(SEA).is_sea = true
	state.get_tile(SEA).elevation = 0
	state.get_tile(SEA).water = float(state.mod("sea_level_rain" if rain else "sea_level_dry"))
	state.turn = 4 if rain else 1
	state.wood = 12
	state.food = 30
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	return state
