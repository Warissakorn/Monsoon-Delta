class_name RiverSchoolFixtures
extends RefCounted
## Prepared, deterministic practice boards. No checkpoints or runtime rule edits.

const IDS: Array[String] = ["river_school_01", "river_school_03"]
const REVISION: int = 1
const HALL: Vector2i = Vector2i(-2, 0)
const HOUSES: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
const CHANNEL: Vector2i = Vector2i(1, -2)
const PADDY: Vector2i = Vector2i(2, -2)
const FISH: Vector2i = Vector2i(0, -3)
const DRAIN: Vector2i = Vector2i(2, -1)
const FIRST_SITES: Array[Vector2i] = [CHANNEL, PADDY]
const PADDY_SITES: Array[Vector2i] = [Vector2i(1, -3), CHANNEL, Vector2i(1, -1), PADDY, Vector2i(2, -1)]


static func create(id: String) -> GameState:
	if id not in IDS:
		return null
	var state: GameState = GameFlow.new_game({
		"seed": 1701 if id == "river_school_01" else 1703,
		"leader": "farmer" if id == "river_school_01" else "fisher",
		"is_tutorial": true,
	})
	if state == null:
		return null
	# The map is authored before play. All later changes use ordinary commands
	# and the unchanged resolver, including evaporation and flood damage.
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
		tile.gate_open = true
		tile.wheel_dir = -1
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.paddy_yield = 0
		tile.paddy_dead = false
		tile.paddy_rain_turns = 0
		tile.start_house = false
		tile.brace_turns = 0
		tile.soil_moisture = 0
	for r: int in range(-C.MAP_RADIUS, C.MAP_RADIUS + 1):
		var river: Tile = state.get_tile(Vector2i(0, r))
		river.elevation = 1 if r < 0 else 0
		river.water = 0.3
		river.is_river = true
	state.get_tile(Vector2i(0, -C.MAP_RADIUS)).is_source = true
	var sea: Tile = state.get_tile(Vector2i(0, C.MAP_RADIUS))
	sea.is_sea = true
	sea.water = 0.0
	for coord: Vector2i in FIRST_SITES if id == "river_school_01" else PADDY_SITES:
		state.get_tile(coord).elevation = 2
	state.get_tile(HALL).elevation = 4
	state.get_tile(HALL).building = C.Building.HALL
	for coord: Vector2i in HOUSES:
		var house: Tile = state.get_tile(coord)
		house.elevation = 4
		house.building = C.Building.HOUSE
		house.start_house = true
	state.population = 6
	state.food = 6 if id == "river_school_01" else 0
	state.wood = 2
	# A declared practice weather schedule, not a modifier to live balance.
	# Forecast generation already consumed its usual draws in new_game; retry
	# reconstructs that exact RNG state, and preview/turn resolution draw none.
	state.rain_inflows.assign([3.0, 3.0, 4.0])
	state.forecast_min = 10.0
	state.forecast_max = 10.0
	GameFlow.begin_turn(state)
	return state


static func solutions(id: String) -> Array[Dictionary]:
	if id not in IDS:
		return []
	var canal: Array = _empty_turns()
	canal[0] = [_command("dig", CHANNEL), _command("dig", PADDY), _command("paddy", PADDY)]
	if id == "river_school_01":
		return [{"id": "canal", "turns": canal}]
	var fish: Array = _empty_turns()
	fish[0] = [_command("fish_trap", FISH)]
	var rice: Array = _empty_turns()
	rice[0] = [
		_command("dig", Vector2i(1, -3)), _command("paddy", Vector2i(1, -3)),
		_command("dig", CHANNEL), _command("paddy", CHANNEL),
	]
	rice[1] = [
		_command("dig", Vector2i(1, -1)), _command("paddy", Vector2i(1, -1)),
		_command("dig", PADDY), _command("paddy", PADDY),
	]
	var mixed: Array = canal.duplicate(true)
	mixed[0].append(_command("fish_trap", FISH))
	mixed[1] = [_command("dig", DRAIN)]
	return [
		{"id": "fish_only", "turns": fish},
		{"id": "rice_only", "turns": rice},
		{"id": "mixed", "turns": mixed},
	]


static func manifest(id: String) -> Dictionary:
	var state: GameState = create(id)
	if state == null:
		return {}
	return {
		"scenario_id": id, "revision": REVISION, "ruleset": state.ruleset,
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"initial_state": state.to_dict(),
		"targets": {"hall": HALL, "houses": HOUSES.duplicate(), "channel": CHANNEL, "paddy": PADDY, "fish": FISH, "drain": DRAIN, "paddy_sites": FIRST_SITES.duplicate() if id == "river_school_01" else PADDY_SITES.duplicate()},
		"resources": {"population": state.population, "food": state.food, "wood": state.wood, "labor": state.labor},
		"weather": {"rain_inflows": state.rain_inflows.duplicate(), "forecast_min": state.forecast_min, "forecast_max": state.forecast_max},
		"prepared": {"background_elevation": 3, "village_elevation": 4, "river_upper_elevation": 1, "river_lower_elevation": 0, "paddy_site_elevation": 2, "starting_paddies": 0, "starting_fish_traps": 0, "starting_forests": 0},
		"solutions": solutions(id),
		"expected": {"canal_paddy_food": 3} if id == "river_school_01" else {"fish_only_food": 6, "rice_only_paddy_food": 6, "mixed_paddy_food": 2, "mixed_fish_food": 6},
	}


static func _empty_turns() -> Array:
	return [[], [], [], [], [], []]


static func _command(id: String, coord: Vector2i) -> Dictionary:
	return {"id": id, "coord": coord}
