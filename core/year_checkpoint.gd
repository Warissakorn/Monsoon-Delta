class_name YearCheckpoint
extends RefCounted
## Separate format; all model fields validated before constructing GameState.

const FORMAT: String = "monsoon_year"
const RULESET: String = "year365_v1"
const ARRAY_FIELDS: Array[String] = ["structures", "health", "deposits", "stock", "crop_growth", "crop_stress", "sapling_ready"]
const FIELDS: Array[String] = ["day", "board", "weather", "resources", "population", "starvation", "knowledge", "research", "claimed", "jobs", "outcome", "goal", "structures", "health", "deposits", "stock", "crop_growth", "crop_stress", "sapling_ready", "stats", "score"]


static func envelope(s: Dictionary) -> Dictionary:
	return {"format": FORMAT, "version": 6 if YearGame.multi_year(s) else (5 if YearHeritage.enabled(s) else (4 if YearClassic.enabled(s) else (3 if s.get("ruleset") == "year365_v3" else (2 if YearGame.expanded(s) else 1)))), "ruleset": s.get("ruleset", RULESET), "state": s.duplicate(true), "float64": SaveIO._encode_float64(s["board"])}


static func valid(s: Variant) -> bool:
	if not s is Dictionary:
		return false
	var expanded: bool = YearGame.expanded(s)
	var fields: Array[String] = FIELDS.duplicate()
	if expanded:
		fields.append_array(YearExpansion.EXTRA_FIELDS)
	if s.get("ruleset") in ["year365_v3", "year365_v4", "year365_v5", "year365_v6"]:
		fields.append_array(["leader", "difficulty"])
		if not s.get("leader") is String or s["leader"] not in ["farmer", "carpenter", "fisher", "soil_doctor"] or not SaveIO._integer(s.get("difficulty"), 0, 10):
			return false
	if YearClassic.enabled(s):
		fields.append_array(YearClassic.FIELDS)
	if YearHeritage.enabled(s):
		fields.append_array(YearHeritage.FIELDS)
	if YearGame.multi_year(s):
		fields.append("campaign_years")
		if not SaveIO._integer(s.get("campaign_years"), 3, 5) or int(s["campaign_years"]) not in [3, 5]:
			return false
	if s.size() != fields.size() or not SaveIO._has_fields(s, fields):
		return false
	var count: int = 127 if expanded else 61
	for key: String in ["day", "population", "starvation", "knowledge", "score"]:
		var limit: int = YearGame.total_days(s) if key == "day" else (12 if key == "population" else 1000000)
		if not SaveIO._integer(s[key], 0, limit):
			return false
	if not s["board"] is Dictionary or not SaveIO._valid_state(s["board"], Hex.coords(6) if expanded else Hex.coords()):
		return false
	# The embedded board only carries water/terrain, never a legacy run's rules.
	if s["board"].get("ruleset", "legacy") != "legacy" or s["board"].has("settlement_progress"):
		return false
	if not s["weather"] is Array or s["weather"].size() != YearGame.total_days(s):
		return false
	for amount: Variant in s["weather"]:
		if not SaveIO._integer(amount, 0, 20000):
			return false
	var expected_weather: Array = YearWeather.generate(String(s["board"]["seed"]).to_int(), int(s.get("campaign_years", 1)))
	for index: int in range(YearGame.total_days(s)):
		if int(s["weather"][index]) != int(expected_weather[index]):
			return false
	if not s["resources"] is Dictionary or s["resources"].size() != YearGame.resources(s).size():
		return false
	for resource: String in YearGame.resources(s):
		if not SaveIO._integer(s["resources"].get(resource), 0, 1000000):
			return false
	var stats: Array = ["planks", "harvest", "food", "damage", "born", "departed"]
	if expanded:
		stats.append_array(["kits", "earthworks", "fed_days", "irrigated_days", "recovery_repairs"])
	if not s["stats"] is Dictionary or s["stats"].size() != stats.size():
		return false
	for key: String in stats:
		if not SaveIO._integer(s["stats"].get(key), 0, 1000000):
			return false
	for field: String in ARRAY_FIELDS:
		if not s[field] is Array or s[field].size() != count:
			return false
	for index: int in range(count):
		if not s["structures"][index] is String or s["structures"][index] not in YearGame.structures(s):
			return false
		if not s["deposits"][index] is String or s["deposits"][index] not in (["", "stone", "clay", "fiber"] if expanded else ["", "stone", "clay"]):
			return false
		for field: String in ["health", "stock", "crop_growth", "crop_stress", "sapling_ready"]:
			var limit: int = 100 if field == "health" else (90 if field == "crop_growth" else 10000)
			if not SaveIO._integer(s[field][index], 0, limit):
				return false
		var structure: String = s["structures"][index]
		var expected: String = "none" if structure in ["", "sawmill", "kiln", "workshop", "camp"] else structure
		if s["board"]["tiles"][index]["building"] != expected:
			return false
		if structure.is_empty() and int(s["health"][index]) != 0:
			return false
		if s["board"]["tiles"][index]["feature"] != "paddy" and int(s["crop_growth"][index]) != 0:
			return false
	if YearClassic.enabled(s):
		for field: String in YearClassic.FIELDS:
			if not s[field] is Array or s[field].size() != count:
				return false
		for index: int in range(count):
			if not SaveIO._integer(s["soil_moisture"][index], 0, int(YearClassic.config()["moisture_capacity"])) or not SaveIO._integer(s["brace_days"][index], 0, 1) or not s["irrigation_policy"][index] is String or s["irrigation_policy"][index] not in Irrigation.POLICIES:
				return false
			if s["board"]["tiles"][index]["feature"] != "paddy" and (int(s["soil_moisture"][index]) != 0 or s["irrigation_policy"][index] != "normal"):
				return false
			if int(s["brace_days"][index]) > 0 and (s["structures"][index] not in ["house", "stilt_house"] or int(s["health"][index]) == 0):
				return false
	if s["structures"].count("hall") != 1:
		return false
	for field: String in ["research", "claimed"]:
		if not s[field] is Array or s[field].size() > 12:
			return false
		var seen: Dictionary = {}
		var allowed: Dictionary = YearGame.config(s)["research" if field == "research" else "challenges"]
		for id: Variant in s[field]:
			if not id is String or not allowed.has(id) or seen.has(id):
				return false
			seen[id] = true
		if field == "research":
			for id: String in seen:
				var prerequisite: String = allowed[id]["requires"]
				if not prerequisite.is_empty() and not seen.has(prerequisite):
					return false
	if expanded:
		if not s["project"] is String or not YearExpansion.config()["projects"].has(s["project"]) or not SaveIO._integer(s["project_stage"], 0, 3) or typeof(s["recovery_claimed"]) != TYPE_BOOL:
			return false
		if not s["upgrades"] is Array or s["upgrades"].size() != count or not s["gate_half"] is Array or s["gate_half"].size() != count:
			return false
		for index: int in range(count):
			var choice: Variant = s["upgrades"][index]
			if not choice is String or (not choice.is_empty() and not YearExpansion.config()["upgrades"].has(choice)) or typeof(s["gate_half"][index]) != TYPE_BOOL:
				return false
			if not choice.is_empty():
				var target: String = YearExpansion.config()["upgrades"][choice]["target"]
				if (target == "home" and s["structures"][index] not in ["house", "stilt_house"]) or (target != "home" and s["structures"][index] != target):
					return false
			if s["gate_half"][index] and (choice != "gate_control" or not s["board"]["tiles"][index]["gate_open"]):
				return false
	if not s["goal"] is String or s["goal"] not in ["none", "growth", "forest", "rice"]:
		return false
	if not s["outcome"] is String or s["outcome"] not in ["running", "won", "lost_hall", "lost_population"]:
		return false
	if s["outcome"] == "running" and (int(s["day"]) >= YearGame.total_days(s) or int(s["population"]) == 0):
		return false
	if s["outcome"] == "won" and (int(s["day"]) != YearGame.total_days(s) or int(s["population"]) == 0):
		return false
	var hall: int = s["structures"].find("hall")
	if s["outcome"] in ["running", "won"] and int(s["health"][hall]) <= 0:
		return false
	if s["outcome"] == "lost_hall" and int(s["health"][hall]) != 0:
		return false
	if s["outcome"] == "lost_population" and int(s["population"]) != 0:
		return false
	if YearHeritage.enabled(s) and not YearHeritage.valid(s):
		return false
	if int(s["score"]) != (0 if s["outcome"] == "running" else YearGame.score(s)):
		return false
	if not s["jobs"] is Array or s["jobs"].size() > count:
		return false
	var occupied: Dictionary = {}
	for job: Variant in s["jobs"]:
		if not job is Dictionary or job.size() != (11 if expanded else 8) or not SaveIO._has_fields(job, ["id", "tile", "remaining", "progress", "paused", "repeat", "reserved", "direction"]):
			return false
		if not job["id"] is String or not YearGame.config(s)["jobs"].has(job["id"]):
			return false
		if not SaveIO._integer(job["tile"], 0, count - 1) or occupied.has(int(job["tile"])):
			return false
		occupied[int(job["tile"])] = true
		if not SaveIO._integer(job["remaining"], 1, 100) or not SaveIO._integer(job["progress"], 0, int(YearGame.config(s)["jobs"][job["id"]]["days"]) + (0 if expanded else -1)) or not SaveIO._integer(job["direction"], 0, 5):
			return false
		for field: String in ["paused", "repeat", "reserved"]:
			if typeof(job[field]) != TYPE_BOOL:
				return false
		if job["repeat"] and int(job["remaining"]) != 1:
			return false
		if job["id"] not in YearGame.repeatable(s) and (job["repeat"] or int(job["remaining"]) != 1):
			return false
		var prerequisite: String = String(YearGame.config(s)["jobs"][job["id"]].get("research", ""))
		if not prerequisite.is_empty() and prerequisite not in s["research"]:
			return false
		if not job["reserved"] and (not job["repeat"] or int(job["progress"]) != 0):
			return false
		if expanded:
			if not job.get("inputs") is Dictionary or not SaveIO._integer(job.get("stop_at"), 0, 100000) or not SaveIO._integer(job.get("reserve"), 0, 100000):
				return false
			var expected: Dictionary = YearGame.config(s)["jobs"][job["id"]]["inputs"]
			if job["inputs"].size() != expected.size():
				return false
			for resource: String in expected:
				if not SaveIO._integer(job["inputs"].get(resource), 1, int(expected[resource])):
					return false
	return YearGame.workers(s) <= int(s["population"])


static func decode(value: Variant) -> Dictionary:
	var bad: Dictionary = {"error": "msg.save_corrupt", "state": {}}
	if not value is Dictionary or not value.get("format") is String or not value.get("ruleset") is String:
		return bad
	if value["format"] != FORMAT or not SaveIO._integer(value.get("version"), 1, 6) or value["ruleset"] not in [RULESET, "year365_v2", "year365_v3", "year365_v4", "year365_v5", "year365_v6"]:
		return {"error": "msg.save_unsupported", "state": {}}
	if not value.get("state") is Dictionary:
		return bad
	var expected: String = [RULESET, "year365_v2", "year365_v3", "year365_v4", "year365_v5", "year365_v6"][int(value["version"]) - 1]
	if value["ruleset"] != expected or value["state"].get("ruleset", RULESET) != expected:
		return bad
	if not valid(value.get("state")):
		return bad
	var s: Dictionary = value["state"].duplicate(true)
	if not SaveIO._restore_float64(s["board"], value.get("float64")) or not valid(s):
		return bad
	# Canonical ints and board caches make load -> continue exactly reproducible.
	for key: String in ["day", "population", "starvation", "knowledge", "score"]:
		s[key] = int(s[key])
	if s.get("ruleset") in ["year365_v3", "year365_v4", "year365_v5", "year365_v6"]:
		s["difficulty"] = int(s["difficulty"])
	for key: String in s["resources"]:
		s["resources"][key] = int(s["resources"][key])
	for key: String in s["stats"]:
		s["stats"][key] = int(s["stats"][key])
	for field: String in ["health", "stock", "crop_growth", "crop_stress", "sapling_ready", "weather"]:
		for index: int in range(s[field].size()):
			s[field][index] = int(s[field][index])
	if YearClassic.enabled(s):
		for field: String in ["soil_moisture", "brace_days"]:
			for index: int in range(s[field].size()):
				s[field][index] = int(s[field][index])
	for job: Dictionary in s["jobs"]:
		for key: String in ["tile", "remaining", "progress", "direction"]:
			job[key] = int(job[key])
	if YearGame.expanded(s):
		s["project_stage"] = int(s["project_stage"])
		for job: Dictionary in s["jobs"]:
			for key: String in ["stop_at", "reserve"]:
				job[key] = int(job[key])
			for key: String in job["inputs"]:
				job["inputs"][key] = int(job["inputs"][key])
	if YearGame.multi_year(s):
		s["campaign_years"] = int(s["campaign_years"])
	if YearHeritage.enabled(s):
		YearHeritage.canonicalize(s)
	s["board"] = GameState.from_dict(s["board"]).to_dict()
	return {"error": "", "state": s}
