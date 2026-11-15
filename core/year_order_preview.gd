class_name YearOrderPreview
extends RefCounted
## Compare the same requested horizon, continuing past notices like YearPlanner.
static func describe(s: Dictionary, id: String, tile: int, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0, until_complete: bool = false, action: String = "order") -> Dictionary:
	var planned: Dictionary = s.duplicate(true)
	var error: String = "year.error.order"
	match action:
		"order": error = YearGame.order(planned, id, tile, batches, repeat, direction, stop_at, reserve)
		"gate": error = YearGame.toggle_gate(planned, tile)
		"irrigation": error = YearClassic.policy(planned, tile, id)
	if not error.is_empty():
		return {"error": error}
	var baseline: Dictionary = s.duplicate(true)
	var reserved: Dictionary = {}
	for key: String in YearGame.resources(s):
		reserved[key] = int(s["resources"][key]) - int(planned["resources"][key])
	var horizon: int = YearGame.total_days(s) - int(s["day"]) if until_complete and action == "order" else (1 if until_complete else 7)
	var completion_day: int = int(s["day"]) if action != "order" else 0
	var simulated: int = 0
	var reason: String = "horizon"
	for _step: int in range(horizon):
		if baseline["outcome"] == "running":
			YearGame.resolve_day(baseline)
		if planned["outcome"] == "running":
			var visual: TurnReport = TurnReport.new()
			YearGame.resolve_day(planned, visual)
			var finished_batch: bool = visual.year_jobs_completed.any(func(job: Dictionary): return int(job["tile"]) == tile and job["id"] == id)
			var present: bool = planned["jobs"].any(func(job: Dictionary): return int(job["tile"]) == tile and job["id"] == id)
			if completion_day == 0 and finished_batch and (repeat or not present):
				completion_day = int(planned["day"])
		simulated += 1
		if until_complete and (completion_day > 0 or action != "order"):
			reason = "completed"
			break
		if until_complete and planned["outcome"] != "running":
			reason = "campaign_end"
			break
		if until_complete:
			var halted: bool = false
			for job: Dictionary in planned["jobs"]:
				if int(job["tile"]) == tile and job["id"] == id and (job["paused"] or YearGame.job_status(planned, job) in ["year.job.exhausted", "year.job.damage"]):
					halted = true
			if halted:
				reason = "blocked"
				break
	return {"error": "", "baseline": baseline, "planned": planned, "reserved": reserved, "days": simulated, "completion_day": completion_day, "completed": completion_day > 0 or action != "order", "reason": reason}


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
