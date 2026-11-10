class_name YearPlanner
extends RefCounted
## Read-only forecasts and suggestions. All days use the real year resolver.

const HORIZON: int = 7


static func describe(year: Dictionary) -> Dictionary:
	var copy: Dictionary = year.duplicate(true)
	var days: Array[Dictionary] = []
	var risks: Array[Dictionary] = []
	var completions: Dictionary = {}
	for step: int in range(HORIZON):
		if copy["outcome"] != "running":
			break
		var before: Dictionary = copy.duplicate(true)
		var visual: Array[TurnReport] = []
		var report: Dictionary = YearGame.advance(copy, 1, visual)
		var damaged: Array[int] = []
		for index: int in range(copy["structures"].size()):
			if int(copy["health"][index]) < int(before["health"][index]):
				damaged.append(index)
				risks.append({"kind": "damage", "day": int(copy["day"]), "tile": index, "amount": int(before["health"][index]) - int(copy["health"][index])})
		for job: Dictionary in visual[0].year_jobs_completed:
			var index: int = int(job["tile"])
			if not completions.has(index):
				completions[index] = int(copy["day"])
		days.append({"day": int(copy["day"]), "food": int(copy["resources"]["food"]), "food_need": YearGame.food_need(copy), "population": int(copy["population"]), "housing": YearGame.housing(copy), "inflow": YearWeather.inflow(copy, int(copy["day"]) - 1), "outcome": copy["outcome"], "events": report["events"].duplicate(), "damaged": damaged})
	var jobs: Array[Dictionary] = job_rows(year, completions)
	return {"days": days, "risks": risks, "jobs": jobs, "advice": _advice(year, copy, days, risks, jobs)}


static func job_rows(year: Dictionary, completions: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job: Dictionary in year["jobs"]:
		var status: String = YearGame.job_status(year, job)
		var kind: String = "paused" if job["paused"] else ("working" if status in ["year.job.working", "year.job.complete"] else "blocked")
		result.append({"tile": int(job["tile"]), "id": job["id"], "kind": kind, "status": status, "completion_day": int(completions.get(int(job["tile"]), 0))})
	return result


static func _advice(year: Dictionary, after: Dictionary, days: Array[Dictionary], risks: Array[Dictionary], jobs: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {"kind": "safe", "tile": -1, "action": "", "values": [], "day": int(year["day"])}
	if year["outcome"] != "running":
		result["kind"] = "finished"
		return result
	var hall: int = year["structures"].find("hall")
	if after["outcome"] == "lost_hall":
		return {"kind": "hall", "tile": hall, "action": _repair(year, hall), "values": [int(after["day"])], "day": int(after["day"])}
	for day: Dictionary in days:
		if int(day["food"]) < int(day["food_need"]) * 3 or day["events"].has("year.event.hunger"):
			return _suggest(year, "food", ["harvest", "forage", "fish"], [int(day["day"]), int(day["food"])])
	for risk: Dictionary in risks:
		if int(risk["tile"]) == hall:
			return {"kind": "damage", "tile": hall, "action": _repair(year, hall), "values": [int(risk["day"]), int(risk["amount"])], "day": int(risk["day"])}
	if not risks.is_empty():
		var risk: Dictionary = risks[0]
		return {"kind": "damage", "tile": int(risk["tile"]), "action": _repair(year, int(risk["tile"])), "values": [int(risk["day"]), int(risk["amount"])], "day": int(risk["day"])}
	for row: Dictionary in jobs:
		if row["kind"] == "blocked":
			return {"kind": "blocked", "tile": row["tile"], "action": "", "values": [], "day": int(year["day"])}
	for index: int in range(year["structures"].size()):
		if not String(year["structures"][index]).is_empty() and int(year["health"][index]) < 100 and not _repair(year, index).is_empty():
			return {"kind": "repair", "tile": index, "action": "repair", "values": [int(year["health"][index])], "day": int(year["day"])}
	if int(year["population"]) > YearGame.housing(year):
		return _suggest(year, "housing", ["build_house"], [int(year["population"]), YearGame.housing(year)])
	var harvest: int = target(year, "harvest")
	if harvest >= 0:
		return {"kind": "harvest", "tile": harvest, "action": "harvest", "values": [], "day": int(year["day"])}
	if not year["structures"].has("sawmill") and not jobs.any(func(row: Dictionary): return row["id"] == "build_sawmill"):
		var sawmill: int = target(year, "build_sawmill")
		if sawmill >= 0:
			return {"kind": "production", "tile": sawmill, "action": "build_sawmill", "values": [], "day": int(year["day"])}
	if YearGame.workers(year) < int(year["population"]):
		return _suggest(year, "idle", ["forage", "gather_wood"], [int(year["population"]) - YearGame.workers(year)])
	return result


static func _repair(year: Dictionary, index: int) -> String:
	return "repair" if YearGame.check_order(year, "repair", index).is_empty() else ""


static func _suggest(year: Dictionary, kind: String, actions: Array[String], values: Array) -> Dictionary:
	for action: String in actions:
		var index: int = target(year, action)
		if index >= 0:
			return {"kind": kind, "tile": index, "action": action, "values": values, "day": int(year["day"])}
	return {"kind": kind, "tile": -1, "action": "", "values": values, "day": int(year["day"])}


static func target(year: Dictionary, id: String) -> int:
	var best: int = -1
	var score: float = -INF
	var hall: Dictionary = year["board"]["tiles"][year["structures"].find("hall")]
	for index: int in range(year["structures"].size()):
		if not YearGame.check_order(year, id, index).is_empty():
			continue
		if int(year["day"]) + YearGame._job_days(year, id, index) > 365:
			continue
		var tile: Dictionary = year["board"]["tiles"][index]
		var distance: int = Hex.distance(Vector2i(int(hall["q"]), int(hall["r"])), Vector2i(int(tile["q"]), int(tile["r"])))
		var value: float = float(tile["elevation"]) - float(tile["water"]) * 4.0 - float(distance) * 0.5
		if value > score:
			best = index
			score = value
	return best
