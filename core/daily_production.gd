class_name DailyProduction
extends RefCounted
## Deterministic 30-day production fixture; calendar supports the proposed year.
## No scene objects, RNG or disk access. Each day is resolved atomically.

const RESOURCES: Array[String] = ["food", "wood", "stone", "clay", "planks", "bricks"]
const BUILDINGS: Array[String] = ["sawmill", "kiln", "foundation", "barrier"]
const REWARDS: Array[String] = ["planks", "foundation", "flood"]


static func config() -> Dictionary:
	return DataDB.balance()["daily_prototype"]


static func new_state() -> Dictionary:
	var resources: Dictionary = {}
	for id: String in RESOURCES:
		resources[id] = int(config()["initial_resources"][id])
	return {
		"day": 0, "resources": resources,
		"buildings": {"sawmill": false, "kiln": false, "foundation": false, "barrier": false},
		"jobs": [], "knowledge": 0, "claimed": [], "planks_produced": 0,
		"outcome": "running",
	}


static func season(day: int) -> String:
	if day <= 120:
		return "dry"
	if day <= 180:
		return "early_rain"
	if day <= 300:
		return "flood"
	return "receding"


static func workers_used(s: Dictionary) -> int:
	var result: int = 0
	for job: Dictionary in s["jobs"]:
		if not job["paused"]:
			result += int(config()["jobs"][job["id"]]["workers"])
	return result


static func check_order(s: Dictionary, id: String, batches: int = 1) -> String:
	if s["outcome"] != "running":
		return "daily.error.finished"
	if not config()["jobs"].has(id) or batches < 1 or batches > 20:
		return "daily.error.order"
	var definition: Dictionary = config()["jobs"][id]
	var building: String = String(definition.get("builds", ""))
	if not building.is_empty() and (s["buildings"][building] or batches != 1):
		return "daily.error.built"
	var requires: String = String(definition.get("requires", ""))
	if not requires.is_empty() and not s["buildings"][requires]:
		return "daily.error.building"
	for job: Dictionary in s["jobs"]:
		if job["id"] == id:
			return "daily.error.queued"
	if workers_used(s) + int(definition["workers"]) > int(config()["population"]):
		return "daily.error.workers"
	if int(s["knowledge"]) < int(definition.get("knowledge", 0)):
		return "daily.error.knowledge"
	for resource: String in definition["inputs"]:
		if int(s["resources"][resource]) < int(definition["inputs"][resource]) * batches:
			return "daily.error.materials"
	return ""


static func order(s: Dictionary, id: String, batches: int = 1) -> String:
	var error: String = check_order(s, id, batches)
	if not error.is_empty():
		return error
	var definition: Dictionary = config()["jobs"][id]
	for resource: String in definition["inputs"]:
		s["resources"][resource] = int(s["resources"][resource]) - int(definition["inputs"][resource]) * batches
	s["knowledge"] = int(s["knowledge"]) - int(definition.get("knowledge", 0))
	s["jobs"].append({"id": id, "remaining": batches, "progress": 0, "paused": false})
	return ""


static func pause_job(s: Dictionary, id: String) -> String:
	if s["outcome"] != "running":
		return "daily.error.finished"
	for job: Dictionary in s["jobs"]:
		if job["id"] != id:
			continue
		var crew: int = int(config()["jobs"][id]["workers"])
		if job["paused"] and workers_used(s) + crew > int(config()["population"]):
			return "daily.error.workers"
		job["paused"] = not job["paused"]
		return ""
	return "daily.error.order"


static func cancel_job(s: Dictionary, id: String) -> String:
	if s["outcome"] != "running":
		return "daily.error.finished"
	for index: int in range(s["jobs"].size()):
		var job: Dictionary = s["jobs"][index]
		if job["id"] != id:
			continue
		var definition: Dictionary = config()["jobs"][id]
		# Work already started consumes that batch. Unstarted batches are refunded.
		var refundable: int = int(job["remaining"]) - (1 if int(job["progress"]) > 0 else 0)
		for resource: String in definition["inputs"]:
			s["resources"][resource] = int(s["resources"][resource]) + int(definition["inputs"][resource]) * refundable
		# Knowledge is a progression choice, not a consumable lost on cancellation.
		# Never strand the player before the next challenge by cancelling a project.
		s["knowledge"] = int(s["knowledge"]) + int(definition.get("knowledge", 0))
		s["jobs"].remove_at(index)
		return ""
	return "daily.error.order"


static func _reward(s: Dictionary, id: String, events: Array) -> void:
	if id in s["claimed"]:
		return
	s["claimed"].append(id)
	s["knowledge"] = int(s["knowledge"]) + 1
	events.append("daily.event.reward_" + id)


static func resolve_day(s: Dictionary) -> Array:
	var events: Array = []
	if s["outcome"] != "running":
		return events
	s["day"] = int(s["day"]) + 1
	var completed: Array = []
	# Only jobs present at the start of the day work; outputs cannot start new jobs.
	for job: Dictionary in s["jobs"]:
		if job["paused"]:
			continue
		var definition: Dictionary = config()["jobs"][job["id"]]
		job["progress"] = int(job["progress"]) + 1
		if int(job["progress"]) < int(definition["days"]):
			continue
		job["progress"] = 0
		job["remaining"] = int(job["remaining"]) - 1
		for resource: String in definition["outputs"]:
			s["resources"][resource] = int(s["resources"][resource]) + int(definition["outputs"][resource])
			if resource == "planks":
				s["planks_produced"] = int(s["planks_produced"]) + int(definition["outputs"][resource])
		var building: String = String(definition.get("builds", ""))
		if not building.is_empty():
			s["buildings"][building] = true
			if building == "foundation":
				_reward(s, "foundation", events)
		if int(s["planks_produced"]) >= 2:
			_reward(s, "planks", events)
		if int(job["remaining"]) == 0:
			completed.append(job)
			events.append("daily.event.complete_" + String(job["id"]))
	for job: Dictionary in completed:
		s["jobs"].erase(job)
	var food: int = int(s["resources"]["food"]) - int(config()["food_per_day"])
	s["resources"]["food"] = maxi(0, food)
	if food < 0:
		s["outcome"] = "lost_food"
		events.append("daily.event.lost_food")
		return events
	if food <= int(config()["food_warning"]):
		events.append("daily.event.food_warning")
	var day: int = int(s["day"])
	for flood: Dictionary in config()["floods"]:
		if day == int(flood["warning_day"]):
			events.append("daily.event.warning_" + String(flood["requires"]))
		if day == int(flood["day"]):
			if not s["buildings"][flood["requires"]]:
				s["outcome"] = "lost_flood"
				events.append("daily.event.lost_flood")
				return events
			events.append("daily.event.survived_" + String(flood["requires"]))
			if flood["requires"] == "foundation":
				_reward(s, "flood", events)
	if day >= int(config()["duration"]):
		s["outcome"] = "won"
		events.append("daily.event.won")
	return events


static func advance(s: Dictionary, days: int) -> Dictionary:
	var report: Dictionary = {"days": 0, "events": []}
	if days < 1 or days > 365:
		return report
	for index: int in range(days):
		if s["outcome"] != "running":
			break
		var events: Array = resolve_day(s)
		report["days"] = int(report["days"]) + 1
		report["events"].append_array(events)
		if not events.is_empty():
			break
	return report


static func preview(s: Dictionary, days: int = 1) -> Dictionary:
	var copy: Dictionary = s.duplicate(true)
	var report: Dictionary = advance(copy, days)
	return {"state": copy, "report": report}
