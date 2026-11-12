class_name YearExpansion
extends RefCounted
## Versioned projects, logistics and production. No I/O and no gameplay RNG.

const RESOURCES: Array[String] = ["food", "wood", "stone", "clay", "planks", "bricks", "fiber", "kits"]
const STRUCTURES: Array[String] = ["", "hall", "house", "stilt_house", "sawmill", "kiln", "granary", "gate", "reservoir", "waterwheel", "workshop", "camp"]
const EXTRA_FIELDS: Array[String] = ["ruleset", "project", "project_stage", "upgrades", "gate_half", "recovery_claimed"]
static var _config: Dictionary = {}


static func config() -> Dictionary:
	if _config.is_empty():
		_config = DataDB.balance()["year_game"].duplicate(true)
		var extra: Dictionary = DataDB.balance()["year_expansion"]
		for key: String in extra:
			if key in ["jobs", "tolerance", "initial_resources"]:
				_config[key].merge(extra[key], true)
			else:
				_config[key] = extra[key].duplicate(true) if extra[key] is Dictionary else extra[key]
		for choice: String in _config["upgrades"]:
			var recipe: Dictionary = _config["upgrades"][choice].duplicate(true)
			recipe.merge({"outputs": {}, "improves": choice})
			_config["jobs"]["improve_" + choice] = recipe
	return _config


static func create(seed_value: int, goal: String, project: String) -> Dictionary:
	if not config()["projects"].has(project):
		return {}
	var s: Dictionary = YearGame.new_game(seed_value, goal)
	var board: GameState = YearMap.generate(seed_value)
	if s.is_empty() or board == null:
		return {}
	s["board"] = board.to_dict()
	s["ruleset"] = "year365_v2"
	s["project"] = project
	s["project_stage"] = 0
	s["recovery_claimed"] = false
	s["resources"]["fiber"] = 0
	s["resources"]["kits"] = 0
	for key: String in ["kits", "earthworks", "fed_days", "irrigated_days", "recovery_repairs"]:
		s["stats"][key] = 0
	for field: String in YearCheckpoint.ARRAY_FIELDS + ["upgrades", "gate_half"]:
		s[field] = []
	for tile: Tile in board.tiles:
		var structure: String = "" if tile.building == C.Building.NONE else C.enum_name(C.Building, tile.building)
		var stock: int = 30 if tile.feature == C.Feature.FOREST else 0
		s["structures"].append(structure)
		s["health"].append(0 if structure.is_empty() else 100)
		s["deposits"].append("")
		s["stock"].append(stock)
		s["crop_growth"].append(0)
		s["crop_stress"].append(0)
		s["sapling_ready"].append(0)
		s["upgrades"].append("")
		s["gate_half"].append(false)
	# Reserve accessible deposits first; remote resources must not consume their quota.
	for near: bool in [true, false]:
		for resource: String in ["stone", "clay", "fiber"]:
			_seed_deposits(s, resource, 2 if near else 4, near)
	return s


static func _seed_deposits(s: Dictionary, resource: String, amount: int, near: bool) -> void:
	var candidates: Array[int] = []
	for index: int in range(s["structures"].size()):
		var tile: Dictionary = s["board"]["tiles"][index]
		if not s["structures"][index].is_empty() or tile["feature"] != "none" or tile["is_sea"] or tile["is_source"] or tile["is_river"] or not s["deposits"][index].is_empty():
			continue
		if (distance_to_work(s, index) <= 3) == near:
			candidates.append(index)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var height_a: int = int(s["board"]["tiles"][a]["elevation"])
		var height_b: int = int(s["board"]["tiles"][b]["elevation"])
		if height_a != height_b:
			return height_a > height_b if resource == "stone" else height_a < height_b
		return a < b
	)
	for position: int in range(mini(amount, candidates.size())):
		var index: int = candidates[position]
		s["deposits"][index] = resource
		s["stock"][index] = 60


static func distance_to_work(s: Dictionary, index: int) -> int:
	var tile: Dictionary = s["board"]["tiles"][index]
	var coord: Vector2i = Vector2i(int(tile["q"]), int(tile["r"]))
	var nearest: int = 100
	for other: int in range(s["structures"].size()):
		if s["structures"][other] in ["hall", "camp"] and int(s["health"][other]) > 0:
			var center: Dictionary = s["board"]["tiles"][other]
			nearest = mini(nearest, Hex.distance(coord, Vector2i(int(center["q"]), int(center["r"]))))
	return nearest


static func in_reach(s: Dictionary, id: String, index: int) -> bool:
	var camp_work: bool = id == "build_camp" or (id == "repair" and s["structures"][index] == "camp")
	return distance_to_work(s, index) <= int(config()["camp_build_radius"] if camp_work else config()["work_radius"])


static func upgrade(s: Dictionary, index: int) -> String:
	return String(s["upgrades"][index]) if YearGame.expanded(s) and index >= 0 else ""


static func inputs(s: Dictionary, id: String, index: int) -> Dictionary:
	var inputs: Dictionary = YearGame.config(s)["jobs"][id]["inputs"].duplicate(true)
	if not YearGame.expanded(s):
		return inputs
	for resource: String in inputs:
		inputs[resource] = int(inputs[resource])
	if id == "saw_planks" and upgrade(s, index) == "sawmill_efficient":
		inputs["wood"] = 2
	if id == "build_workshop" and s["project"] == "craft" and int(s["project_stage"]) >= 1:
		inputs["wood"] = 2
	if id == "repair" and upgrade(s, index) == "gate_service":
		inputs["wood"] = 1
	return inputs


static func job_inputs(s: Dictionary, job: Dictionary) -> Dictionary:
	return job["inputs"] if YearGame.expanded(s) else YearGame.config(s)["jobs"][job["id"]]["inputs"]


static func choose_project(s: Dictionary, id: String) -> String:
	if not YearGame.expanded(s) or s["outcome"] != "running" or not config()["projects"].has(id) or int(s["project_stage"]) != 0:
		return "exp.error.project"
	s["project"] = id
	return ""


static func count(s: Dictionary, structure: String) -> int:
	var total: int = 0
	for index: int in range(s["structures"].size()):
		if s["structures"][index] == structure and int(s["health"][index]) > 0:
			total += 1
	return total


static func progress(s: Dictionary) -> Array[bool]:
	match String(s["project"]):
		"food": return [int(s["day"]) >= 30 and int(s["resources"]["food"]) >= 60, count(s, "granary") > 0 and (int(s["stats"]["harvest"]) >= 60 or int(s["stats"]["fed_days"]) >= 60), int(s["day"]) >= 300 and int(s["population"]) >= 6 and int(s["resources"]["food"]) >= 60]
		"water": return [count(s, "reservoir") > 0 or int(s["stats"]["earthworks"]) >= 3, int(s["day"]) >= 180 and (count(s, "gate") > 0 or int(s["stats"]["irrigated_days"]) >= 10), int(s["day"]) >= 300 and int(s["population"]) >= 6 and int(s["health"][s["structures"].find("hall")]) >= 60]
	return [int(s["stats"]["planks"]) >= 8 and int(s["resources"]["bricks"]) >= 6, int(s["stats"]["kits"]) >= 4 and count(s, "workshop") > 0, int(s["day"]) >= 300 and YearGame.housing(s) >= 8 and count(s, "workshop") > 0]


static func after_day(s: Dictionary, events: Array) -> void:
	var stage: int = int(s["project_stage"])
	var ready: Array[bool] = progress(s)
	# One stage per committed day keeps the next reward a distinct achievement.
	if stage < 3 and ready[stage]:
		var rewards: Dictionary = config()["projects"][s["project"]]
		s["knowledge"] = int(s["knowledge"]) + int(rewards["knowledge"][stage])
		for resource: String in rewards["materials"][stage]:
			s["resources"][resource] = int(s["resources"][resource]) + int(rewards["materials"][stage][resource])
		s["project_stage"] = stage + 1
		events.append("exp.event.project_" + String(s["project"]) + str(stage + 1))
	if int(s["day"]) >= 300 and int(s["stats"]["recovery_repairs"]) >= 3 and not s["recovery_claimed"]:
		s["recovery_claimed"] = true
		s["resources"]["wood"] = int(s["resources"]["wood"]) + 4
		s["knowledge"] = int(s["knowledge"]) + 1
		events.append("exp.event.recovery")


static func simulate(board: GameState, s: Dictionary, inflow: float, record_visuals: bool = false) -> Dictionary:
	var half: Array[int] = []
	for index: int in range(s["structures"].size()):
		if s["gate_half"][index] and int(s["health"][index]) > 0:
			half.append(index)
	if half.is_empty():
		return WaterSim.simulate(board, inflow, record_visuals)
	var iterations: int = int(board.mod("water_iterations"))
	var wheel: float = float(board.mod("wheel_amount"))
	board.mods["water_iterations"] = maxi(1, iterations / 2)
	var first: Dictionary = WaterSim.simulate(board, inflow * 0.5, record_visuals)
	for index: int in half:
		board.tiles[index].gate_open = false
	board.mods["water_iterations"] = maxi(1, iterations - int(board.mods["water_iterations"]))
	board.mods["wheel_amount"] = 0.0
	var second: Dictionary = WaterSim.simulate(board, inflow * 0.5, record_visuals)
	for index: int in half:
		board.tiles[index].gate_open = true
	board.mods["water_iterations"] = iterations
	board.mods["wheel_amount"] = wheel

	first["flow_edges"].append_array(second["flow_edges"])
	first["wheel_transfers"].append_array(second["wheel_transfers"])
	return first
