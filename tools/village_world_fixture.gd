class_name VillageWorldFixture
extends RefCounted
## Authored visual QA layout, not a map generator or a legal playthrough.


static func create() -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "living_village": true, "run_mode": "long", "ruleset": "bracing_moisture_v1"})
	for tile: Tile in state.tiles:
		tile.elevation = 2
		tile.water = 0.0
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.start_house = false
		tile.paddy_dead = false
		tile.paddy_yield = 0
		tile.paddy_rain_turns = 0
		tile.brace_turns = 0
		tile.soil_moisture = 0
		if tile.q >= 1:
			tile.elevation = 1
			tile.water = 0.70
			tile.is_river = true
	state.get_tile(Vector2i(-2, 0)).building = C.Building.HALL
	state.get_tile(Vector2i(-1, 0)).building = C.Building.HOUSE
	state.get_tile(Vector2i(-2, 1)).building = C.Building.STILT_HOUSE
	state.get_tile(Vector2i(-1, 1)).building = C.Building.GRANARY
	state.get_tile(Vector2i(2, 0)).building = C.Building.RAFT_HOUSE
	state.get_tile(Vector2i(1, -1)).building = C.Building.FISH_TRAP
	for coord: Vector2i in [Vector2i(0, 0), Vector2i(0, 1)]:
		state.get_tile(coord).feature = C.Feature.PADDY
		state.get_tile(coord).paddy_yield = 2
		state.get_tile(coord).soil_moisture = 1
	for coord: Vector2i in [Vector2i(-3, 0), Vector2i(-3, 1)]:
		state.get_tile(coord).feature = C.Feature.FOREST
	state.food = 30
	state.wood = 12
	state.year = 3
	state.stats["reached_year"] = 3
	SettlementProgress.reconcile(state)
	state.settlement_progress["condition"] = "thriving"
	state.settlement_progress["candidate"] = "thriving"
	for record: Dictionary in state.settlement_progress["buildings"].values():
		record["built_year"] = 1
		record["stage"] = 2
	return state
