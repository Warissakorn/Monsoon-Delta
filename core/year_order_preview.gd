class_name YearOrderPreview
extends RefCounted
## Compare the same requested horizon, continuing past notices like YearPlanner.
static func describe(s: Dictionary, id: String, tile: int, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> Dictionary:
	var planned: Dictionary = s.duplicate(true)
	var error: String = YearGame.order(planned, id, tile, batches, repeat, direction, stop_at, reserve)
	if not error.is_empty():
		return {"error": error}
	var baseline: Dictionary = s.duplicate(true)
	var reserved: Dictionary = {}
	for key: String in YearGame.resources(s):
		reserved[key] = int(s["resources"][key]) - int(planned["resources"][key])
	for _step: int in range(7):
		if baseline["outcome"] == "running":
			YearGame.resolve_day(baseline)
		if planned["outcome"] == "running":
			YearGame.resolve_day(planned)
	return {"error": "", "baseline": baseline, "planned": planned, "reserved": reserved}


static func impacts(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(before["structures"].size()):
		if int(after["health"][index]) < int(before["health"][index]):
			result.append({"tile": index, "kind": "year.event.damage", "before": int(before["health"][index]), "after": int(after["health"][index])})
		if int(after["crop_stress"][index]) >= 5 and int(before["crop_growth"][index]) > 0 and int(after["crop_growth"][index]) == 0:
			result.append({"tile": index, "kind": "year.event.crop_lost", "before": int(before["crop_growth"][index]), "after": 0})
	if int(after["stats"]["departed"]) > int(before["stats"]["departed"]):
		result.append({"tile": -1, "kind": "yearplus.migration", "before": int(before["stats"]["departed"]), "after": int(after["stats"]["departed"])})
	return result
