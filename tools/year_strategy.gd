class_name YearStrategy
extends RefCounted
## Deterministic reference policy. Uses public commands only; no state injection.


static func _has_job(s: Dictionary, id: String) -> bool:
	for job: Dictionary in s["jobs"]:
		if job["id"] == id:
			return true
	return false


static func target(s: Dictionary, id: String) -> int:
	var best: int = -1
	var elevation: int = -100
	for index: int in range(61):
		if YearGame.check_order(s, id, index).is_empty() and int(s["board"]["tiles"][index]["elevation"]) > elevation:
			best = index
			elevation = int(s["board"]["tiles"][index]["elevation"])
	return best


static func _order(s: Dictionary, id: String, index: int, batches: int, repeat: bool, commands: Array) -> void:
	if YearGame.order(s, id, index, batches, repeat).is_empty():
		commands.append({"action": "order", "id": id, "tile": index, "batches": batches, "repeat": repeat})


static func plan(s: Dictionary, industry: bool = true, commands: Array = []) -> void:
	# Cancel exhausted work so it neither holds workers nor repeatedly stops time.
	var exhausted: Array[int] = []
	for job: Dictionary in s["jobs"]:
		if YearGame.job_status(s, job) == "year.job.exhausted":
			exhausted.append(int(job["tile"]))
	for index: int in exhausted:
		YearGame.edit_job(s, index, true)
		commands.append({"action": "cancel", "tile": index})
	# Keep two independent food sources before committing to industry.
	var food_jobs: int = 0
	for job: Dictionary in s["jobs"]:
		if job["id"] == "forage" and not job["paused"]:
			food_jobs += 1
	for count: int in range(food_jobs, 2):
		var index: int = target(s, "forage")
		if index >= 0:
			_order(s, "forage", index, 1, true, commands)
	# Water damage is resolved physically, not by milestone requirements.
	for index: int in range(61):
		if s["structures"][index] not in ["hall", "house", "stilt_house"] or int(s["health"][index]) >= 90:
			continue
		var error: String = YearGame.check_order(s, "repair", index)
		if error == "year.error.workers":
			for job: Dictionary in s["jobs"].duplicate(true):
				if job["id"] not in ["forage", "repair"]:
					YearGame.edit_job(s, int(job["tile"]), true)
					commands.append({"action": "cancel", "tile": int(job["tile"])})
					break
		if YearGame.check_order(s, "repair", index).is_empty():
			_order(s, "repair", index, 1, false, commands)
	# Replenish construction and maintenance materials from actual deposits.
	for pair: Array in [["gather_wood", "wood", 30], ["gather_stone", "stone", 15]]:
		if int(s["resources"][pair[1]]) < int(pair[2]) and not _has_job(s, pair[0]):
			var index: int = target(s, pair[0])
			if index >= 0:
				_order(s, pair[0], index, 3, false, commands)
	if not industry or int(s["day"]) >= 160:
		return
	for id: String in ["build_sawmill", "build_kiln"]:
		var structure: String = YearGame.config()["jobs"][id]["builds"]
		if structure not in s["structures"] and not _has_job(s, id):
			var index: int = target(s, id)
			if index >= 0:
				_order(s, id, index, 1, false, commands)
	for id: String in ["saw_planks", "fire_bricks"]:
		var resource: String = "planks" if id == "saw_planks" else "bricks"
		if int(s["resources"][resource]) < 8 and not _has_job(s, id):
			var index: int = target(s, id)
			if index >= 0:
				_order(s, id, index, 4, false, commands)
	for id: String in ["housing1", "housing2"]:
		if YearGame.learn(s, id).is_empty():
			commands.append({"action": "learn", "id": id})
