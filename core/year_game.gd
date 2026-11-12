class_name YearGame
extends RefCounted
## One playable year. State is plain data, water is resolved by shared WaterSim.

const RESOURCES: Array[String] = ["food", "wood", "stone", "clay", "planks", "bricks"]
const STRUCTURES: Array[String] = ["", "hall", "house", "stilt_house", "sawmill", "kiln", "granary", "gate", "reservoir", "waterwheel"]
const REPEATABLE: Array[String] = ["forage", "fish", "gather_wood", "gather_stone", "gather_clay", "saw_planks", "fire_bricks", "repair"]


static var _campaign_configs: Dictionary = {}


static func config(s: Dictionary = {}) -> Dictionary:
	var base: Dictionary = YearExpansion.config() if expanded(s) else DataDB.balance()["year_game"]
	if s.get("ruleset") not in ["year365_v3", "year365_v4", "year365_v5"]:
		return base
	var leader: String = s.get("leader", "farmer")
	var cache_key: String = leader + String(s["ruleset"])
	if _campaign_configs.has(cache_key):
		return _campaign_configs[cache_key]
	var result: Dictionary = base.duplicate(true)
	if YearClassic.enabled(s):
		result["jobs"].merge(YearClassic.config()["jobs"], true)
		result["tolerance"].merge(YearClassic.config()["tolerance"], true)
	var bonuses: Dictionary = DataDB.balance()["year_campaign"]["leaders"][leader]
	if leader == "carpenter":
		for id: String in ["build_house", "upgrade_house"]:
			if result["jobs"].has(id):
				var inputs: Dictionary = result["jobs"][id]["inputs"]
				if inputs.has("wood"):
					inputs["wood"] = maxi(0, int(inputs["wood"]) - int(bonuses["house_wood_discount"]))
	elif leader == "soil_doctor":
		for id: String in ["dig", "fill"]:
			result["jobs"][id]["days"] = maxi(1, int(result["jobs"][id]["days"]) - int(bonuses["earth_days_discount"]))
	elif leader == "fisher":
		result["jobs"]["fish"]["outputs"]["food"] += int(bonuses["fish_food_bonus"])
	_campaign_configs[cache_key] = result
	return result


static func expanded(s: Dictionary) -> bool:
	return s.get("ruleset", "year365_v1") in ["year365_v2", "year365_v3", "year365_v4", "year365_v5"]


static func resources(s: Dictionary) -> Array[String]:
	return YearExpansion.RESOURCES if expanded(s) else RESOURCES


static func structures(s: Dictionary) -> Array[String]:
	return YearClassic.STRUCTURES if YearClassic.enabled(s) else (YearExpansion.STRUCTURES if expanded(s) else STRUCTURES)


static func repeatable(s: Dictionary) -> Array[String]:
	var result: Array[String] = REPEATABLE.duplicate()
	if expanded(s):
		result.append_array(["gather_fiber", "assemble_kits"])
	if YearClassic.enabled(s):
		result.append("brace_house")
	return result


static func new_expanded(seed_value: int = 42, goal: String = "none", project: String = "food") -> Dictionary:
	return YearExpansion.create(seed_value, goal, project)


static func new_campaign(seed_value: int, goal: String, project: String, leader: String = "farmer", difficulty: int = 0, classic: bool = false, heritage: bool = false) -> Dictionary:
	if leader not in ["farmer", "carpenter", "fisher", "soil_doctor"] or difficulty < 0 or difficulty > 10 or (heritage and not classic):
		return {}
	var result: Dictionary = new_expanded(seed_value, goal, project)
	if result.is_empty():
		return {}
	result["ruleset"] = "year365_v3"
	result["leader"] = leader
	result["difficulty"] = difficulty
	if classic:
		YearClassic.initialize(result)
	if heritage:
		YearHeritage.initialize(result)
	return result


static func new_game(seed_value: int = 42, goal: String = "none") -> Dictionary:
	var board: GameState = GameFlow.new_game({"seed": seed_value})
	if board == null or goal not in ["none", "growth", "forest", "rice"]:
		return {}
	var result: Dictionary = {
		"day": 0, "board": board.to_dict(), "weather": YearWeather.generate(seed_value),
		"resources": {}, "population": 6, "starvation": 0, "knowledge": 0,
		"research": [], "claimed": [], "jobs": [], "outcome": "running", "goal": goal,
		"structures": [], "health": [], "deposits": [], "stock": [],
		"crop_growth": [], "crop_stress": [], "sapling_ready": [],
		"stats": {"planks": 0, "harvest": 0, "food": 0, "damage": 0, "born": 0, "departed": 0},
		"score": 0,
	}
	for resource: String in RESOURCES:
		result["resources"][resource] = int(config()["initial_resources"][resource])
	var quarry_count: int = 0
	var clay_count: int = 0
	for tile: Tile in board.tiles:
		var structure: String = "" if tile.building == C.Building.NONE else C.enum_name(C.Building, tile.building)
		result["structures"].append(structure)
		result["health"].append(0 if structure.is_empty() else 100)
		var deposit: String = ""
		var stock: int = 0
		if tile.feature == C.Feature.FOREST:
			stock = 30
		elif structure.is_empty() and not tile.is_sea and not tile.is_source and not tile.is_river:
			if tile.elevation >= 2 and quarry_count < 3:
				deposit = "stone"
				stock = 60
				quarry_count += 1
			elif clay_count < 3:
				deposit = "clay"
				stock = 60
				clay_count += 1
		result["deposits"].append(deposit)
		result["stock"].append(stock)
		result["crop_growth"].append(0)
		result["crop_stress"].append(0)
		result["sapling_ready"].append(0)
	return result


static func board_of(s: Dictionary) -> GameState:
	return GameState.from_dict(s["board"])


static func workers(s: Dictionary) -> int:
	var used: int = 0
	for job: Dictionary in s["jobs"]:
		if not job["paused"]:
			used += int(config(s)["jobs"][job["id"]]["workers"])
	return used


static func housing(s: Dictionary) -> int:
	var total: int = 0
	for index: int in range(s["structures"].size()):
		if s["structures"][index] in ["house", "stilt_house", "raft_house"] and int(s["health"][index]) > 0:
			total += (3 if "housing3" in s["research"] else 2) + (1 if YearExpansion.upgrade(s, index) == "house_room" else 0)
	return total


static func food_need(s: Dictionary) -> int:
	return ceili(float(s["population"]) / (4.0 if "agriculture2" in s["research"] else float(config(s)["food_per_people"])))


static func storage(s: Dictionary) -> int:
	var total: int = int(config(s)["base_storage"])
	for index: int in range(s["structures"].size()):
		if s["structures"][index] == "granary" and int(s["health"][index]) > 0:
			total += int(config(s)["granary_storage"]) + (180 if YearExpansion.upgrade(s, index) == "granary_storage" else 0)
	if expanded(s) and s["project"] == "food" and int(s["project_stage"]) >= 1:
		total += 40
	return total


static func target_matches(s: Dictionary, id: String, index: int) -> bool:
	if not config(s)["jobs"].has(id) or index < 0 or index >= s["structures"].size():
		return false
	var tile: Dictionary = s["board"]["tiles"][index]
	if tile["is_sea"] or tile["is_source"]:
		return false
	var structure: String = s["structures"][index]
	var target: String = config(s)["jobs"][id]["target"]
	match target:
		"wet_channel": return structure.is_empty() and tile["feature"] == "none" and s["deposits"][index] == "" and float(tile["water"]) >= float(YearClassic.config()["build_min_water"])
		"fixed_home": return structure in ["house", "stilt_house"] and int(s["health"][index]) > 0
		"clearing": return structure.is_empty() and tile["feature"] in ["paddy", "sapling"]
		"forest": return tile["feature"] == "forest" and (id == "forage" or int(s["stock"][index]) >= 3)
		"river": return tile["is_river"] or float(tile["water"]) >= 0.1
		"stone", "clay", "fiber": return s["deposits"][index] == target and int(s["stock"][index]) >= int(config(s)["jobs"][id].get("stock", 1))
		"land": return structure.is_empty() and tile["feature"] == "none" and s["deposits"][index] == "" and not tile["is_river"]
		"channel": return structure.is_empty() and tile["feature"] == "none" and s["deposits"][index] == ""
		"earth": return structure.is_empty() and tile["feature"] in ["none", "paddy"] and (int(tile["elevation"]) > -3 if id == "dig" else int(tile["elevation"]) < 4)
		"house": return structure == "house" and int(s["health"][index]) > 0
		"home": return structure in ["house", "stilt_house"] and int(s["health"][index]) > 0
		"paddy": return tile["feature"] == "paddy" and int(s["crop_growth"][index]) >= 45
		"damaged": return not structure.is_empty() and int(s["health"][index]) < 100
		"structure": return not structure.is_empty() and structure != "hall"
		_: return structure == target and int(s["health"][index]) > 0


static func check_order(s: Dictionary, id: String, index: int, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> String:
	if s["outcome"] != "running":
		return "year.error.finished"
	if not config(s)["jobs"].has(id) or batches < 1 or batches > 100 or direction < 0 or direction > 5:
		return "year.error.order"
	if not target_matches(s, id, index):
		return "year.error.target"
	var definition: Dictionary = config(s)["jobs"][id]
	if stop_at < 0 or stop_at > 100000 or reserve < 0 or reserve > 100000 or (not expanded(s) and (stop_at > 0 or reserve > 0)):
		return "year.error.order"
	if expanded(s):
		if not YearExpansion.in_reach(s, id, index):
			return "exp.error.camp"
		if definition.has("improves") and not String(s["upgrades"][index]).is_empty():
			return "exp.error.improved"
	var reusable: bool = id in repeatable(s)
	if (not reusable and (batches != 1 or repeat)) or (repeat and batches != 1):
		return "year.error.order"
	if definition.has("research") and definition["research"] not in s["research"]:
		return "year.error.research"
	if id == "build_wheel":
		var tile: Dictionary = s["board"]["tiles"][index]
		var source: Vector2i = Vector2i(int(tile["q"]), int(tile["r"])) + Hex.direction(direction)
		var found: bool = false
		for neighbor: Dictionary in s["board"]["tiles"]:
			if Vector2i(int(neighbor["q"]), int(neighbor["r"])) == source and not neighbor["is_sea"]:
				found = true
				break
		if not found:
			return "year.error.target"
	if id == "plant_paddy" and int(s["day"]) >= 300:
		return "year.error.season"
	if id.begins_with("build_") and id not in ["build_gate", "build_wheel", "build_raft", "build_fish_trap"] and float(s["board"]["tiles"][index]["water"]) >= 0.5:
		return "year.error.water"
	for job: Dictionary in s["jobs"]:
		if int(job["tile"]) == index:
			return "year.error.occupied"
	if workers(s) + int(definition["workers"]) > int(s["population"]):
		return "year.error.workers"
	var inputs: Dictionary = YearExpansion.inputs(s, id, index)
	for resource: String in inputs:
		if int(s["resources"][resource]) < int(inputs[resource]) * batches:
			return "year.error.materials"
	if expanded(s) and inputs.has("wood") and int(s["resources"]["wood"]) - int(inputs["wood"]) * batches < reserve:
		return "exp.error.reserve"
	return ""


static func order(s: Dictionary, id: String, index: int, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> String:
	var error: String = check_order(s, id, index, batches, repeat, direction, stop_at, reserve)
	if not error.is_empty():
		return error
	var inputs: Dictionary = YearExpansion.inputs(s, id, index)
	for resource: String in inputs:
		s["resources"][resource] = int(s["resources"][resource]) - int(inputs[resource]) * batches
	var job: Dictionary = {"id": id, "tile": index, "remaining": batches, "progress": 0, "paused": false, "repeat": repeat, "reserved": true, "direction": direction}
	if expanded(s):
		job.merge({"inputs": inputs, "stop_at": stop_at, "reserve": reserve})
	s["jobs"].append(job)
	return ""


static func edit_job(s: Dictionary, index: int, cancel: bool) -> String:
	if s["outcome"] != "running":
		return "year.error.finished"
	for position: int in range(s["jobs"].size()):
		var job: Dictionary = s["jobs"][position]
		if int(job["tile"]) != index:
			continue
		var definition: Dictionary = config(s)["jobs"][job["id"]]
		if cancel:
			var refund: int = maxi(0, int(job["remaining"]) - (1 if int(job["progress"]) > 0 else 0)) if job["reserved"] else 0
			for resource: String in YearExpansion.job_inputs(s, job):
				s["resources"][resource] = int(s["resources"][resource]) + refund * int(YearExpansion.job_inputs(s, job)[resource])
			s["jobs"].remove_at(position)
		else:
			if job["paused"] and workers(s) + int(definition["workers"]) > int(s["population"]):
				return "year.error.workers"
			job["paused"] = not job["paused"]
		return ""
	return "year.error.order"


static func learn(s: Dictionary, id: String) -> String:
	if s["outcome"] != "running" or not config(s)["research"].has(id) or id in s["research"]:
		return "year.error.research"
	var definition: Dictionary = config(s)["research"][id]
	if (not String(definition["requires"]).is_empty() and definition["requires"] not in s["research"]) or int(s["knowledge"]) < int(definition["cost"]):
		return "year.error.knowledge"
	s["knowledge"] = int(s["knowledge"]) - int(definition["cost"])
	s["research"].append(id)
	return ""


static func toggle_gate(s: Dictionary, index: int) -> String:
	if s["outcome"] != "running" or index < 0 or index >= s["structures"].size() or s["structures"][index] != "gate" or int(s["health"][index]) <= 0:
		return "year.error.target"
	if expanded(s) and s["upgrades"][index] == "gate_control":
		if not s["board"]["tiles"][index]["gate_open"]:
			s["board"]["tiles"][index]["gate_open"] = true
			s["gate_half"][index] = true
		elif s["gate_half"][index]:
			s["gate_half"][index] = false
		else:
			s["board"]["tiles"][index]["gate_open"] = false
	else:
		s["board"]["tiles"][index]["gate_open"] = not s["board"]["tiles"][index]["gate_open"]
	return ""


static func _job_days(s: Dictionary, id: String, index: int = -1) -> int:
	if id == "brace_house":
		return 1
	var days: int = 1 if id == "repair" and "housing3" in s["research"] else int(config(s)["jobs"][id]["days"])
	if expanded(s) and index >= 0:
		if id == "repair" and YearExpansion.upgrade(s, index) == "gate_service":
			days = 1
		if (id == "saw_planks" and YearExpansion.upgrade(s, index) == "sawmill_fast") or (id == "assemble_kits" and s["project"] == "craft" and int(s["project_stage"]) >= 2) or (id.begins_with("improve_") and s["project"] == "craft" and int(s["project_stage"]) >= 3):
			days = maxi(1, days - 1)
		if YearExpansion.distance_to_work(s, index) >= 2:
			days += 1
	return days


static func job_status(s: Dictionary, job: Dictionary) -> String:
	if job["paused"]:
		return "year.job.paused"
	var index: int = int(job["tile"])
	var id: String = job["id"]
	var tile: Dictionary = s["board"]["tiles"][index]
	if expanded(s):
		if not YearExpansion.in_reach(s, id, index):
			return "exp.job.camp"
		var outputs: Dictionary = config(s)["jobs"][id]["outputs"]
		for resource: String in outputs:
			if int(job["progress"]) == 0 and int(job["stop_at"]) > 0 and int(s["resources"][resource]) >= int(job["stop_at"]):
				return "exp.job.target"
		if not job["reserved"] and job["inputs"].has("wood") and int(s["resources"]["wood"]) - int(job["inputs"]["wood"]) < int(job["reserve"]):
			return "exp.job.reserve"
	if id in ["forage", "gather_wood"] and tile["feature"] != "forest":
		return "year.job.exhausted"
	if config(s)["jobs"][id].has("stock") and int(s["stock"][index]) < int(config(s)["jobs"][id]["stock"]):
		return "year.job.exhausted"
	if id == "clear_land" and tile["feature"] not in ["paddy", "sapling"]:
		return "year.job.complete"
	if id == "brace_house" and (s["structures"][index] not in ["house", "stilt_house"] or int(s["health"][index]) == 0):
		return "year.job.damage"
	if id == "repair" and int(s["health"][index]) >= 100:
		return "year.job.complete"
	if id == "harvest" and int(s["crop_growth"][index]) < 45:
		return "year.job.crop"
	if id in ["saw_planks", "fire_bricks", "assemble_kits"] and int(s["health"][index]) <= 0:
		return "year.job.damage"
	if id == "fish" and float(tile["water"]) < 0.05:
		return "year.job.water"
	if id not in ["fish", "build_gate", "build_wheel", "build_raft", "build_fish_trap", "brace_house", "dig", "repair", "demolish"] and float(tile["water"]) >= 0.75:
		return "year.job.water"
	if not job["reserved"]:
		for resource: String in YearExpansion.job_inputs(s, job):
			if int(s["resources"][resource]) < int(YearExpansion.job_inputs(s, job)[resource]):
				return "year.job.materials"
	return "year.job.working"


static func outputs(s: Dictionary, id: String) -> Dictionary:
	var result: Dictionary = config(s)["jobs"][id]["outputs"].duplicate(true)
	if result.has("food"):
		result["food"] = int(result["food"]) + (1 if "agriculture3" in s["research"] else 0) + (1 if expanded(s) and s["project"] == "food" and int(s["project_stage"]) >= 2 else 0)
	return result


static func _finish_job(s: Dictionary, job: Dictionary, events: Array, visual: TurnReport = null) -> void:
	var id: String = job["id"]
	var index: int = int(job["tile"])
	var definition: Dictionary = config(s)["jobs"][id]
	var tile: Dictionary = s["board"]["tiles"][index]
	var before: Dictionary = YearLedger.snapshot(s) if visual != null else {}
	for resource: String in outputs(s, id):
		var amount: int = int(outputs(s, id)[resource])
		s["resources"][resource] = int(s["resources"][resource]) + amount
		if resource in (["food", "planks", "kits"] if expanded(s) else ["food", "planks"]):
			s["stats"][resource] = int(s["stats"][resource]) + amount
	if id == "fish" and visual != null:
		var coord: Vector2i = Vector2i(int(tile["q"]), int(tile["r"]))
		visual.fish_food_by_tile[coord] = int(outputs(s, id).get("food", 0))
		visual.fish_food += int(outputs(s, id).get("food", 0))
	if definition.has("stock"):
		s["stock"][index] = maxi(0, int(s["stock"][index]) - int(definition["stock"]))
		if int(s["stock"][index]) == 0:
			s["deposits"][index] = ""
		if id == "gather_wood" and int(s["stock"][index]) == 0:
			tile["feature"] = "none"
			events.append("year.event.exhausted")
	if definition.has("builds"):
		var building: String = definition["builds"]
		s["structures"][index] = building
		s["health"][index] = 100
		tile["building"] = "none" if building in ["sawmill", "kiln", "workshop", "camp"] else building
		if building == "reservoir":
			tile["elevation"] = maxi(-3, int(tile["elevation"]) - 2)
		if building == "waterwheel":
			tile["wheel_dir"] = int(job["direction"])
	if definition.has("improves"):
		s["upgrades"][index] = definition["improves"]
		if definition["improves"] == "reservoir_deep":
			tile["elevation"] = maxi(-3, int(tile["elevation"]) - 1)
	if expanded(s) and id in ["dig", "fill", "levee"]:
		s["stats"]["earthworks"] = int(s["stats"]["earthworks"]) + 1
	match id:
		"clear_land": YearClassic.clear(s, index)
		"brace_house": s["brace_days"][index] = 1
		"plant_paddy":
			tile["feature"] = "paddy"
			s["crop_growth"][index] = 0
		"plant_forest":
			tile["feature"] = "sapling"
			s["sapling_ready"][index] = int(s["day"]) + (15 if "agriculture3" in s["research"] else 30)
		"harvest":
			var amount: int = int(s["crop_growth"][index]) + (20 if "agriculture1" in s["research"] else 0) + (int(DataDB.balance()["year_campaign"]["leaders"]["farmer"]["harvest_bonus"]) if s.get("leader") == "farmer" else 0)
			s["resources"]["food"] = int(s["resources"]["food"]) + amount
			s["stats"]["food"] = int(s["stats"]["food"]) + amount
			s["stats"]["harvest"] = int(s["stats"]["harvest"]) + amount
			s["crop_growth"][index] = 0
			if visual != null:
				visual.year_harvest_food_by_tile[Vector2i(int(tile["q"]), int(tile["r"]))] = amount
		"dig": tile["elevation"] = maxi(-3, int(tile["elevation"]) - 1)
		"fill": tile["elevation"] = mini(4, int(tile["elevation"]) + 1)
		"levee": tile["elevation"] = mini(4, int(tile["elevation"]) + 2)
		"repair":
			s["health"][index] = mini(100, int(s["health"][index]) + (80 if expanded(s) and s["project"] == "water" and int(s["project_stage"]) >= 3 else 60))
			if expanded(s) and int(s["day"]) >= 300:
				s["stats"]["recovery_repairs"] = int(s["stats"]["recovery_repairs"]) + 1
		"demolish":
			if expanded(s):
				s["upgrades"][index] = ""
				s["gate_half"][index] = false
			if YearClassic.enabled(s):
				s["brace_days"][index] = 0
			s["structures"][index] = ""
			s["health"][index] = 0
			tile["building"] = "none"
			s["resources"]["wood"] = int(s["resources"]["wood"]) + 2

	YearHeritage.reconcile(s, index if definition.has("builds") else -1)
	YearLedger.record(visual, s, before, "year.action." + id, index)
	YearLedger.fact(visual, s, index, "year.action." + id, "", "")


static func _work(s: Dictionary, events: Array, visual: TurnReport = null) -> void:
	var before_labor: int = int(s["population"]) - workers(s)
	var done: Array = []
	for job: Dictionary in s["jobs"]:
		var status: String = job_status(s, job)
		if status != "year.job.working":
			if status in ["exp.job.target", "exp.job.reserve"]:
				job["paused"] = true
				events.append("exp.event.policy_pause")
			continue
		var definition: Dictionary = config(s)["jobs"][job["id"]]
		if not job["reserved"]:
			var before_inputs: Dictionary = YearLedger.snapshot(s) if visual != null else {}
			for resource: String in YearExpansion.job_inputs(s, job):
				s["resources"][resource] = int(s["resources"][resource]) - int(YearExpansion.job_inputs(s, job)[resource])
			job["reserved"] = true
			YearLedger.record(visual, s, before_inputs, "yearplus.cause.inputs", int(job["tile"]))
		job["progress"] = int(job["progress"]) + 1
		if int(job["progress"]) < _job_days(s, job["id"], int(job["tile"])):
			continue
		_finish_job(s, job, events, visual)
		if visual != null:
			visual.year_jobs_completed.append({"tile": int(job["tile"]), "id": String(job["id"])})
		job["progress"] = 0
		if job["repeat"]:
			job["reserved"] = false
		else:
			job["remaining"] = int(job["remaining"]) - 1
			if int(job["remaining"]) == 0:
				done.append(job)
				events.append("year.event.work_complete")
	for job: Dictionary in done:
		s["jobs"].erase(job)
	var labor_before: Dictionary = YearLedger.snapshot(s) if visual != null else {}
	if visual != null:
		labor_before["labor"] = before_labor
	YearLedger.record(visual, s, labor_before, "yearplus.cause.workers")


static func _water(s: Dictionary, events: Array, visual: TurnReport = null) -> void:
	var board: GameState = board_of(s)
	var season: String = DailyProduction.season(int(s["day"]))
	board.turn = 4 if season in ["early_rain", "flood"] else 1
	board.year_mods = [
		{"key": "water_iterations", "op": "set", "value": float(config(s)["water_iterations"])},
		{"key": "forest_absorb", "op": "set", "value": float(config(s)["forest_absorb"]) + (0.015 if "agriculture3" in s["research"] else 0.0)},
		{"key": "evaporation_dry", "op": "set", "value": float(config(s)["evaporation"])},
		{"key": "wheel_amount", "op": "set", "value": 0.12},
	]
	board.recompute_mods()
	for index: int in range(board.tiles.size()):
		if int(s["health"][index]) == 0:
			if s["structures"][index] == "waterwheel":
				board.tiles[index].building = C.Building.NONE
			elif s["structures"][index] == "gate":
				board.tiles[index].gate_open = true
	var water_result: Dictionary
	if expanded(s):
		water_result = YearExpansion.simulate(board, s, YearWeather.inflow(s, int(s["day"]) - 1), visual != null)
	else:
		water_result = WaterSim.simulate(board, YearWeather.inflow(s, int(s["day"]) - 1), visual != null)
	if visual != null:
		visual.flow_edges.assign(water_result["flow_edges"])
		visual.wheel_transfers.assign(water_result["wheel_transfers"])
	WaterSim.absorb(board)
	WaterSim.evaporate(board)
	var damaged: bool = false
	for index: int in range(board.tiles.size()):
		var tile: Tile = board.tiles[index]
		var structure: String = s["structures"][index]
		if structure == "waterwheel" and int(s["health"][index]) == 0:
			tile.building = C.Building.WATERWHEEL
		if not structure.is_empty() and int(s["health"][index]) > 0:
			var tolerance: float = float(config(s)["tolerance"][structure]) + (0.25 if "housing2" in s["research"] else 0.0)
			if YearExpansion.upgrade(s, index) in ["house_safe", "granary_raised"]:
				tolerance += 0.4
			if YearClassic.enabled(s) and int(s["brace_days"][index]) > 0:
				YearLedger.fact(visual, s, index, "yearplus.braced", tolerance, tolerance + float(YearClassic.config()["brace_bonus"]))
				tolerance += float(YearClassic.config()["brace_bonus"])
			if tile.water >= tolerance and structure != "raft_house":
				var before_damage: Dictionary = YearLedger.snapshot(s) if visual != null else {}
				var old_health: int = int(s["health"][index])
				s["health"][index] = maxi(0, int(s["health"][index]) - int(config(s)["damage_per_day"]))
				s["stats"]["damage"] = int(s["stats"]["damage"]) + int(config(s)["damage_per_day"])
				damaged = true
				YearLedger.record(visual, s, before_damage, "year.event.damage", index)
				YearLedger.fact(visual, s, index, "year.event.damage", old_health, int(s["health"][index]))
				if int(s["health"][index]) == 0 and structure == "hall":
					s["outcome"] = "lost_hall"
				if int(s["health"][index]) == 0 and structure == "gate":
					tile.gate_open = true
		if tile.feature == C.Feature.SAPLING and int(s["day"]) >= int(s["sapling_ready"][index]):
			tile.feature = C.Feature.FOREST
			s["sapling_ready"][index] = 0
			s["stock"][index] = 30
			events.append("year.event.forest_grown")
			YearLedger.fact(visual, s, index, "year.event.forest_grown", "sapling", "forest")
		if YearClassic.enabled(s):
			s["brace_days"][index] = 0
			continue
		if tile.feature != C.Feature.PADDY:
			continue
		if tile.water >= 1.0:
			s["crop_stress"][index] = int(s["crop_stress"][index]) + 1
			if int(s["crop_stress"][index]) >= 5 and int(s["crop_growth"][index]) > 0:
				YearLedger.fact(visual, s, index, "year.event.crop_lost", int(s["crop_growth"][index]), 0)
				s["crop_growth"][index] = 0
				events.append("year.event.crop_lost")
			continue
		s["crop_stress"][index] = 0
		var watered: bool = season in ["early_rain", "flood"] or tile.water >= 0.1
		if not watered:
			var radius: int = 2 if "water2" in s["research"] else 1
			if expanded(s) and s["project"] == "water" and int(s["project_stage"]) >= 2:
				radius += 1
			for other: int in range(board.tiles.size()):
				var source: Tile = board.tiles[other]
				if s["structures"][other] == "reservoir" and int(s["health"][other]) > 0 and source.water >= 0.04 and Hex.distance(tile.coord, source.coord) <= radius + (1 if YearExpansion.upgrade(s, other) == "reservoir_reach" else 0):
					source.water -= 0.01 if "water2" in s["research"] else 0.02
					watered = true
					if expanded(s):
						s["stats"]["irrigated_days"] = int(s["stats"]["irrigated_days"]) + 1
					break
		if watered:
			var previous: int = int(s["crop_growth"][index])
			s["crop_growth"][index] = mini(90, previous + 1)
			if visual != null and previous < 90:
				visual.paddy_gains.append(tile.coord)
				YearLedger.fact(visual, s, index, "yearplus.crop_growth", previous, int(s["crop_growth"][index]))
			if previous == 44:
				events.append("year.event.harvest_ready")
	if YearClassic.enabled(s):
		YearClassic.crops_and_fish(s, board, season, events, visual)
	if damaged:
		events.append("year.event.damage")
	s["board"] = board.to_dict()


static func _population(s: Dictionary, events: Array, visual: TurnReport = null) -> void:
	var before: Dictionary = YearLedger.snapshot(s) if visual != null else {}
	var need: int = food_need(s)
	if int(s["resources"]["food"]) < need:
		s["resources"]["food"] = 0
		s["starvation"] = int(s["starvation"]) + 1
		events.append("year.event.hunger")
		if int(s["starvation"]) % 3 == 0:
			s["population"] = maxi(0, int(s["population"]) - 1)
			s["stats"]["departed"] = int(s["stats"]["departed"]) + 1
	else:
		s["resources"]["food"] = int(s["resources"]["food"]) - need
		s["starvation"] = 0
		if expanded(s):
			s["stats"]["fed_days"] = int(s["stats"]["fed_days"]) + 1
	YearLedger.record(visual, s, before, "yearplus.cause.food")
	before = YearLedger.snapshot(s) if visual != null else {}
	if int(s["resources"]["food"]) < need * 7:
		events.append("year.event.food_low")
	var capacity: int = housing(s)
	if int(s["population"]) > capacity and int(s["day"]) % 14 == 0:
		s["population"] = maxi(0, int(s["population"]) - 1)
		s["stats"]["departed"] = int(s["stats"]["departed"]) + 1
		events.append("year.event.housing_low")
	YearLedger.record(visual, s, before, "year.event.housing_low")
	before = YearLedger.snapshot(s) if visual != null else {}
	if int(s["day"]) % 60 == 0 and int(s["population"]) < mini(capacity, int(config(s)["max_population"])) and int(s["resources"]["food"]) >= int(s["population"]) * 10:
		s["population"] = int(s["population"]) + 1
		s["resources"]["food"] = int(s["resources"]["food"]) - 8
		s["stats"]["born"] = int(s["stats"]["born"]) + 1
		events.append("year.event.birth")
	YearLedger.record(visual, s, before, "year.event.birth")
	before = YearLedger.snapshot(s) if visual != null else {}
	# Population loss suspends the lowest priority work, never overcommits people.
	for index: int in range(s["jobs"].size() - 1, -1, -1):
		if workers(s) <= int(s["population"]):
			break
		s["jobs"][index]["paused"] = true
	if int(s["population"]) == 0:
		s["outcome"] = "lost_population"
	YearLedger.record(visual, s, before, "yearplus.cause.workers")
	before = YearLedger.snapshot(s) if visual != null else {}
	if int(s["resources"]["food"]) > storage(s):
		s["resources"]["food"] = storage(s)
		if int(s["day"]) % 7 == 0:
			events.append("year.event.storage")

	YearLedger.record(visual, s, before, "year.event.storage")


static func forests(s: Dictionary) -> int:
	var count: int = 0
	for tile: Dictionary in s["board"]["tiles"]:
		if tile["feature"] == "forest":
			count += 1
	return count


static func _challenges(s: Dictionary, events: Array) -> void:
	var ready: Dictionary = {
		"production": int(s["stats"]["planks"]) >= 8,
		"reserves": int(s["day"]) >= 30 and int(s["resources"]["food"]) >= 60,
		"shelter": housing(s) >= 8,
		"harvest": int(s["stats"]["harvest"]) >= 60,
		"early_rain": int(s["day"]) >= 180 and int(s["population"]) >= 6,
		"flood": int(s["day"]) >= 300,
		"forest": int(s["day"]) >= 300 and forests(s) >= 10,
	}
	for id: String in ready:
		if ready[id] and id not in s["claimed"]:
			s["claimed"].append(id)
			s["knowledge"] = int(s["knowledge"]) + int(config(s)["challenges"][id])
			events.append("year.event.challenge_" + id)


static func goal_met(s: Dictionary) -> bool:
	if YearHeritage.enabled(s):
		return YearHeritage.progress(s)["met_now"]
	match String(s["goal"]):
		"growth": return int(s["population"]) >= 10
		"forest": return int(s["population"]) >= 6 and forests(s) >= 12
		"rice": return int(s["population"]) >= 6 and int(s["stats"]["harvest"]) >= 180
	return false


static func score(s: Dictionary) -> int:
	if YearHeritage.enabled(s):
		return int(YearHeritage.score_parts(s)["total"])
	var base: int = int(s["population"]) * 100 + int(s["resources"]["food"]) + s["claimed"].size() * 50 + (250 if s["outcome"] == "won" and goal_met(s) else 0) + (int(s["project_stage"]) * 100 if expanded(s) else 0)
	return roundi(float(base) * (1.0 + float(s.get("difficulty", 0)) * float(DataDB.balance()["year_campaign"]["score_per_difficulty"])))


static func resolve_day(s: Dictionary, visual: TurnReport = null) -> Array:
	var events: Array = []
	if s["outcome"] != "running":
		return events
	YearLedger.begin(visual, s)
	s["day"] = int(s["day"]) + 1
	_work(s, events, visual)
	_water(s, events, visual)
	_population(s, events, visual)
	var day: int = int(s["day"])
	if day in [121, 181, 301]:
		events.append("year.event.season")
	# Reveal only the forecast horizon, then stop at the first warning of a surge.
	var coming: int = mini(364, day + 2)
	if day < 363 and int(s["weather"][coming]) >= 1800 and (coming == 0 or int(s["weather"][coming - 1]) < 1800):
		events.append("year.event.storm")
	var before_rewards: Dictionary = YearLedger.snapshot(s) if visual != null else {}
	if s["outcome"] == "running":
		_challenges(s, events)
		if expanded(s):
			YearExpansion.after_day(s, events)
	YearHeritage.after_day(s, events)
	if s["outcome"] == "running":
		if day == 365:
			s["outcome"] = "won"
			events.append("year.event.won")
	YearLedger.record(visual, s, before_rewards, "yearplus.cause.rewards")
	if s["outcome"] != "running":
		s["score"] = score(s)
		if s["outcome"] != "won":
			events.append("year.event." + String(s["outcome"]))
	# Stop once a work site becomes blocked, rather than skipping blindly.
	for job: Dictionary in s["jobs"]:
		if not job["paused"] and job_status(s, job) not in ["year.job.working", "year.job.complete"]:
			events.append("year.event.work_blocked")
			break
	YearLedger.finish(visual, s, events)
	return events


static func advance(s: Dictionary, days: int, visual_reports: Variant = null) -> Dictionary:
	var report: Dictionary = {"days": 0, "events": []}
	if days < 1 or days > 365:
		return report
	for step: int in range(days):
		if s["outcome"] != "running":
			break
		var visual: TurnReport = TurnReport.new() if visual_reports is Array else null
		var events: Array = resolve_day(s, visual)
		if visual != null:
			visual_reports.append(visual)
		report["days"] = int(report["days"]) + 1
		report["events"].append_array(events)
		if not events.is_empty():
			break
	return report


static func preview(s: Dictionary, days: int = 1, visual_reports: Variant = null) -> Dictionary:
	var copy: Dictionary = s.duplicate(true)
	return {"state": copy, "report": advance(copy, days, visual_reports)}
