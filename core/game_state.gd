class_name GameState
extends RefCounted
## Serializable simulation state. UI and scene objects never enter this model.

const Constants = preload("res://core/constants.gd")
const TileModel = preload("res://core/tile.gd")
const Database = preload("res://core/data_db.gd")
const UndoHistory = preload("res://core/undo_stack.gd")
const RULESETS: Array[String] = ["legacy", "bracing_v1", "moisture_v1", "bracing_moisture_v1"]
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

var version: int = 1
var seed: int = 0
var map_type: String = "plains"
var leader: String = "farmer"
var difficulty: int = 0
var run_mode: String = "classic"
var ruleset: String = "legacy"
var village_goal: String = "none"
var goal_achieved_year: int = 0
var is_daily: bool = false
var is_tutorial: bool = false
var tiles: Array[TileModel] = []
var year: int = 1
var turn: int = 1
var phase: int = Constants.Phase.PLANNING
var population: int = 0
var food: int = 0
var wood: int = 0
var labor: int = 0
var labor_max: int = 0
var cards: Array[String] = []
var card_offer: Array[String] = []
var pending_event: String = ""
var year_mods: Array[Dictionary] = []
var forecast_min: float = 0.0
var forecast_max: float = 0.0
var rain_inflows: Array[float] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stats: Dictionary = {
	"houses_lost": 0, "paddies_lost": 0, "hall_ever_wet": false,
	"max_population": 0, "food_produced": 0, "reached_year": 1,
}
var outcome: int = Constants.Outcome.NONE
var harvest_report: Dictionary = {}
var final_score: int = 0
# Optional visual history; absent from legacy state dictionaries and saves.
var settlement_progress: Dictionary = {}

# The caller replaces the whole state after undo/redo. Histories are never saved.
var undo: UndoHistory = UndoHistory.new()
var redo: UndoHistory = UndoHistory.new()

# Derived caches are rebuilt after loading, never saved.
var index: Dictionary = {}
var mods: Dictionary = {}


func _init() -> void:
	rng.seed = 0


func rebuild_index() -> void:
	index.clear()
	for i: int in range(tiles.size()):
		index[tiles[i].coord] = i


func get_tile(coord: Vector2i) -> TileModel:
	var tile_index: int = int(index.get(coord, -1))
	if tile_index < 0 or tile_index >= tiles.size():
		return null
	return tiles[tile_index]


func neighbors(tile: TileModel) -> Array[TileModel]:
	var result: Array[TileModel] = []
	for direction: Vector2i in DIRECTIONS:
		var neighbor: TileModel = get_tile(tile.coord + direction)
		if neighbor != null:
			result.append(neighbor)
	return result


func neighbor_in_dir(tile: TileModel, direction: int) -> TileModel:
	if direction < 0 or direction >= DIRECTIONS.size():
		return null
	return get_tile(tile.coord + DIRECTIONS[direction])


func season() -> int:
	return Constants.Season.DRY if turn <= Constants.DRY_TURNS else Constants.Season.RAIN


func is_rain() -> bool:
	return season() == Constants.Season.RAIN


func target_years() -> int:
	var modes: Dictionary = Database.balance()["run_modes"]
	var mode: Dictionary = modes.get(run_mode, modes["classic"])
	return int(mode["years"])


func has_bracing() -> bool:
	return ruleset in ["bracing_v1", "bracing_moisture_v1"]


func has_moisture() -> bool:
	return ruleset in ["moisture_v1", "bracing_moisture_v1"]


static func ruleset_for(bracing: bool, moisture: bool) -> String:
	if moisture:
		return "bracing_moisture_v1" if bracing else "moisture_v1"
	return "bracing_v1" if bracing else "legacy"


func mod(key: String) -> Variant:
	if mods.is_empty():
		recompute_mods()
	if not mods.has(key):
		push_error("Unknown modifier: " + key)
		return 0.0
	return mods[key]


func recompute_mods() -> void:
	var balance: Dictionary = Database.balance()
	mods = Dictionary(balance.get("mods_default", {})).duplicate(true)
	var map_data: Dictionary = Dictionary(balance.get("maps", {})).get(map_type, {})
	_apply_modifiers(map_data.get("mods", []))
	var run_data: Dictionary = Dictionary(balance.get("run_modes", {})).get(run_mode, {})
	_apply_modifiers(run_data.get("mods", []))
	_apply_modifiers(Dictionary(balance.get("leaders", {})).get(leader, []))
	var levels: Array = balance.get("difficulty_levels", [])
	for level: int in range(mini(maxi(difficulty, 0), levels.size())):
		_apply_modifiers(levels[level])
	# The M2 sandbox does not offer cards; card modifiers arrive with that milestone.
	_apply_modifiers(year_mods)


func _apply_modifiers(list: Array) -> void:
	for modifier: Dictionary in list:
		var key: String = String(modifier.get("key", ""))
		if not mods.has(key):
			push_error("Unknown modifier key: " + key)
			continue
		var value: float = float(modifier.get("value", 0.0))
		match String(modifier.get("op", "")):
			"add":
				mods[key] = float(mods[key]) + value
			"mul":
				mods[key] = float(mods[key]) * value
			"set":
				mods[key] = value
			_:
				push_error("Unknown modifier operation for: " + key)


func current_inflow() -> float:
	if not is_rain():
		return float(mod("dry_inflow"))
	var rain_index: int = turn - Constants.DRY_TURNS - 1
	if rain_index < 0 or rain_index >= rain_inflows.size():
		return 0.0
	return rain_inflows[rain_index]


func capacity() -> int:
	var per_home: int = roundi(float(mod("home_capacity"))) + roundi(float(mod("home_capacity_bonus")))
	var homes: int = 0
	for tile: TileModel in tiles:
		if tile.building in [Constants.Building.HOUSE, Constants.Building.STILT_HOUSE, Constants.Building.RAFT_HOUSE]:
			homes += 1
	return homes * per_home


func has_building(building: int) -> bool:
	for tile: TileModel in tiles:
		if tile.building == building:
			return true
	return false


func level_of(tile: TileModel) -> int:
	if tile.water < 0.1:
		return 0
	if tile.water < 0.5:
		return 1
	if tile.water < 1.0:
		return 2
	return 3


func duplicate_state() -> GameState:
	return GameState.from_dict(to_dict())


func to_dict() -> Dictionary:
	var tile_data: Array[Dictionary] = []
	for tile: TileModel in tiles:
		tile_data.append(tile.to_dict(has_bracing(), has_moisture()))
	var data: Dictionary = {
		"version": version,
		"seed": str(seed),
		"map_type": map_type,
		"leader": leader,
		"difficulty": difficulty,
		"run_mode": run_mode,
		"village_goal": village_goal,
		"goal_achieved_year": goal_achieved_year,
		"is_daily": is_daily,
		"is_tutorial": is_tutorial,
		"tiles": tile_data,
		"year": year,
		"turn": turn,
		"phase": Constants.enum_name(Constants.Phase, phase),
		"population": population,
		"food": food,
		"wood": wood,
		"labor": labor,
		"labor_max": labor_max,
		"cards": cards.duplicate(),
		"card_offer": card_offer.duplicate(),
		"pending_event": pending_event,
		"year_mods": _canonical_value(year_mods),
		"forecast_min": forecast_min,
		"forecast_max": forecast_max,
		"rain_inflows": rain_inflows.duplicate(),
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
		"stats": _canonical_dictionary(stats),
		"outcome": Constants.enum_name(Constants.Outcome, outcome),
		"harvest_report": _canonical_dictionary(harvest_report),
		"final_score": final_score,
	}
	if not settlement_progress.is_empty():
		data["settlement_progress"] = _canonical_dictionary(settlement_progress)
	if ruleset != "legacy":
		data["ruleset"] = ruleset
	return data


static func from_dict(data: Dictionary) -> GameState:
	var state: GameState = GameState.new()
	state.version = int(data.get("version", 1))
	state.seed = String(data.get("seed", "0")).to_int()
	state.map_type = String(data.get("map_type", "plains"))
	state.leader = String(data.get("leader", "farmer"))
	state.difficulty = int(data.get("difficulty", 0))
	state.run_mode = String(data.get("run_mode", "classic"))
	state.ruleset = String(data.get("ruleset", "legacy"))
	state.village_goal = String(data.get("village_goal", "none"))
	state.goal_achieved_year = int(data.get("goal_achieved_year", 0))
	state.is_daily = bool(data.get("is_daily", false))
	state.is_tutorial = bool(data.get("is_tutorial", false))
	for tile_data: Dictionary in data.get("tiles", []):
		state.tiles.append(TileModel.from_dict(tile_data))
	state.year = int(data.get("year", 1))
	state.turn = int(data.get("turn", 1))
	state.phase = Constants.enum_value(Constants.Phase, String(data.get("phase", "planning")))
	state.population = int(data.get("population", 0))
	state.food = int(data.get("food", 0))
	state.wood = int(data.get("wood", 0))
	state.labor = int(data.get("labor", 0))
	state.labor_max = int(data.get("labor_max", 0))
	for id: Variant in data.get("cards", []):
		state.cards.append(String(id))
	for id: Variant in data.get("card_offer", []):
		state.card_offer.append(String(id))
	state.pending_event = String(data.get("pending_event", ""))
	for modifier: Dictionary in data.get("year_mods", []):
		state.year_mods.append(_canonical_dictionary(modifier))
	state.forecast_min = float(data.get("forecast_min", 0.0))
	state.forecast_max = float(data.get("forecast_max", 0.0))
	for inflow: Variant in data.get("rain_inflows", []):
		state.rain_inflows.append(float(inflow))
	# Setting the seed resets the generator, so restore its state afterwards.
	state.rng.seed = String(data.get("rng_seed", "0")).to_int()
	state.rng.state = String(data.get("rng_state", str(state.rng.state))).to_int()
	state.stats = _canonical_dictionary(Dictionary(data.get("stats", state.stats)))
	for key: String in ["houses_lost", "paddies_lost", "max_population", "food_produced", "reached_year"]:
		if state.stats.has(key):
			state.stats[key] = int(state.stats[key])
	if state.stats.has("hall_ever_wet"):
		state.stats["hall_ever_wet"] = bool(state.stats["hall_ever_wet"])
	state.outcome = Constants.enum_value(Constants.Outcome, String(data.get("outcome", "none")))
	state.harvest_report = _canonical_dictionary(Dictionary(data.get("harvest_report", {})))
	for key: String in ["paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after"]:
		if state.harvest_report.has(key):
			state.harvest_report[key] = int(state.harvest_report[key])
	state.final_score = int(data.get("final_score", 0))
	state.settlement_progress = _canonical_dictionary(Dictionary(data.get("settlement_progress", {})))
	state.rebuild_index()
	state.recompute_mods()
	return state


static func _canonical_dictionary(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in data:
		result[key] = _canonical_value(data[key])
	return result


static func _canonical_value(value: Variant) -> Variant:
	# JSON reads every number as float. Untyped dictionaries therefore use one
	# canonical representation on save and load: integral numbers become ints,
	# while fractional numbers remain floats. Typed state fields keep their types.
	if value is Dictionary:
		return _canonical_dictionary(value)
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_canonical_value(entry))
		return result
	if typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		if is_finite(number) and number == floorf(number) and number >= -9223372036854775808.0 and number < 9223372036854775808.0:
			return int(number)
	return value
