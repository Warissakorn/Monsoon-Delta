class_name VillageAdvisor
extends RefCounted
## Read-only presentation priorities. Forecasts come from the shared resolver.

const NO_COORD: Vector2i = Vector2i(2147483647, 2147483647)


static func describe(state: GameState, prediction: Dictionary, harvest: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"kind": "safe", "severity": "safe", "icon": "hall", "key": "advisor.safe",
		"values": [], "coord": NO_COORD, "action": "", "commands": [],
		"timing": "advisor.this_turn",
	}
	if state.phase != C.Phase.PLANNING or prediction.is_empty():
		result["kind"] = "resolved"
		result["key"] = "advisor.resolved"
		result["timing"] = "advisor.actual"
		return result
	var report: TurnReport = prediction["report"]
	if report.outcome == C.Outcome.LOSE_HALL:
		result.merge({"kind": "hall", "severity": "critical", "icon": "hall", "key": "preview.lose_hall", "action": "focus"}, true)
		for tile: Tile in state.tiles:
			if tile.building == C.Building.HALL:
				result["coord"] = tile.coord
				break
		return result
	if not harvest.is_empty():
		if int(harvest["population_after"]) == 0:
			result.merge({"kind": "population", "severity": "critical", "icon": "people", "key": "preview.lose_population", "action": "food", "commands": ["fish_trap", "paddy"]}, true)
			if int(harvest["left_hunger"]) == 0:
				result["action"] = "housing"
				result["commands"] = ["stilt_house", "house", "raft_house"]
			return result
		if int(harvest["left_hunger"]) > 0:
			result.merge({"kind": "hunger", "severity": "danger", "icon": "food", "key": "advisor.hunger", "values": [int(harvest["left_hunger"])], "action": "food", "commands": ["fish_trap", "paddy"]}, true)
			return result
		if int(harvest["left_housing"]) > 0:
			result.merge({"kind": "housing", "severity": "danger", "icon": "house", "key": "advisor.housing", "values": [int(harvest["left_housing"])], "action": "housing", "commands": ["stilt_house", "house", "raft_house"]}, true)
			return result
	if not report.destroyed.is_empty():
		result.merge({"kind": "destroyed", "severity": "danger", "icon": "broken_house", "key": "preview.destroyed", "values": [report.destroyed.size()], "coord": report.destroyed[0]["coord"], "action": "focus"}, true)
		return result
	if not report.paddies_died.is_empty():
		result.merge({"kind": "crops", "severity": "danger", "icon": "dead_rice", "key": "preview.paddies_died", "values": [report.paddies_died.size()], "coord": report.paddies_died[0], "action": "focus"}, true)
		return result
	# Before harvest, stored food is an actual quantity, never a future yield promise.
	if harvest.is_empty():
		var meal: int = state.population * maxi(0, roundi(float(state.mod("food_per_person"))))
		if state.food < meal:
			result.merge({"kind": "prepare_food", "severity": "prepare", "icon": "food", "key": "advisor.prepare_food", "values": [state.food, meal], "action": "food", "commands": ["fish_trap", "paddy"], "timing": "advisor.stored"}, true)
			return result
		if state.population > state.capacity():
			result.merge({"kind": "prepare_housing", "severity": "prepare", "icon": "house", "key": "advisor.prepare_housing", "values": [state.population, state.capacity()], "action": "housing", "commands": ["stilt_house", "house", "raft_house"], "timing": "advisor.actual"}, true)
	return result
