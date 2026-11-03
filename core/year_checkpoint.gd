class_name YearCheckpoint
extends RefCounted
## Separate format; all model fields validated before constructing GameState.

const FORMAT: String = "monsoon_year"
const RULESET: String = "year365_v1"
const ARRAY_FIELDS: Array[String] = ["structures", "health", "deposits", "stock", "crop_growth", "crop_stress", "sapling_ready"]
const FIELDS: Array[String] = ["day", "board", "weather", "resources", "population", "starvation", "knowledge", "research", "claimed", "jobs", "outcome", "goal", "structures", "health", "deposits", "stock", "crop_growth", "crop_stress", "sapling_ready", "stats", "score"]


static func envelope(s: Dictionary) -> Dictionary:
	return {"format": FORMAT, "version": 1, "ruleset": RULESET, "state": s.duplicate(true), "float64": SaveIO._encode_float64(s["board"])}


static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.size() != FIELDS.size() or not SaveIO._has_fields(s, FIELDS):
		return false
	for key: String in ["day", "population", "starvation", "knowledge", "score"]:
		var limit: int = 365 if key == "day" else (12 if key == "population" else 1000000)
		if not SaveIO._integer(s[key], 0, limit):
			return false
	if not s["board"] is Dictionary or not SaveIO._valid_state(s["board"]):
		return false
	# The embedded board only carries water/terrain, never a legacy run's rules.
	if s["board"].get("ruleset", "legacy") != "legacy" or s["board"].has("settlement_progress"):
		return false
	if not s["weather"] is Array or s["weather"].size() != 365:
		return false
	for amount: Variant in s["weather"]:
		if not SaveIO._integer(amount, 0, 20000):
			return false
	var expected_weather: Array = YearWeather.generate(String(s["board"]["seed"]).to_int())
	for index: int in range(365):
		if int(s["weather"][index]) != int(expected_weather[index]):
			return false
	if not s["resources"] is Dictionary or s["resources"].size() != YearGame.RESOURCES.size():
		return false
	for resource: String in YearGame.RESOURCES:
		if not SaveIO._integer(s["resources"].get(resource), 0, 1000000):
			return false
	if not s["stats"] is Dictionary or s["stats"].size() != 6:
		return false
	for key: String in ["planks", "harvest", "food", "damage", "born", "departed"]:
		if not SaveIO._integer(s["stats"].get(key), 0, 1000000):
			return false
	for field: String in ARRAY_FIELDS:
		if not s[field] is Array or s[field].size() != 61:
			return false
	for index: int in range(61):
		if not s["structures"][index] is String or s["structures"][index] not in YearGame.STRUCTURES:
			return false
		if not s["deposits"][index] is String or s["deposits"][index] not in ["", "stone", "clay"]:
			return false
		for field: String in ["health", "stock", "crop_growth", "crop_stress", "sapling_ready"]:
			var limit: int = 100 if field == "health" else (90 if field == "crop_growth" else 10000)
			if not SaveIO._integer(s[field][index], 0, limit):
				return false
		var structure: String = s["structures"][index]
		var expected: String = "none" if structure in ["", "sawmill", "kiln"] else structure
		if s["board"]["tiles"][index]["building"] != expected:
			return false
		if structure.is_empty() and int(s["health"][index]) != 0:
			return false
		if s["board"]["tiles"][index]["feature"] != "paddy" and int(s["crop_growth"][index]) != 0:
			return false
	if s["structures"].count("hall") != 1:
		return false
	for field: String in ["research", "claimed"]:
		if not s[field] is Array or s[field].size() > 12:
			return false
		var seen: Dictionary = {}
		var allowed: Dictionary = YearGame.config()["research" if field == "research" else "challenges"]
		for id: Variant in s[field]:
			if not id is String or not allowed.has(id) or seen.has(id):
				return false
			seen[id] = true
		if field == "research":
			for id: String in seen:
				var prerequisite: String = allowed[id]["requires"]
				if not prerequisite.is_empty() and not seen.has(prerequisite):
					return false
	if not s["goal"] is String or s["goal"] not in ["none", "growth", "forest", "rice"]:
		return false
	if not s["outcome"] is String or s["outcome"] not in ["running", "won", "lost_hall", "lost_population"]:
		return false
	if s["outcome"] == "running" and (int(s["day"]) >= 365 or int(s["population"]) == 0):
		return false
	if s["outcome"] == "won" and (int(s["day"]) != 365 or int(s["population"]) == 0):
		return false
	var hall: int = s["structures"].find("hall")
	if s["outcome"] in ["running", "won"] and int(s["health"][hall]) <= 0:
		return false
	if s["outcome"] == "lost_hall" and int(s["health"][hall]) != 0:
		return false
	if s["outcome"] == "lost_population" and int(s["population"]) != 0:
		return false
	if int(s["score"]) != (0 if s["outcome"] == "running" else YearGame.score(s)):
		return false
	if not s["jobs"] is Array or s["jobs"].size() > 61:
		return false
	var occupied: Dictionary = {}
	for job: Variant in s["jobs"]:
		if not job is Dictionary or job.size() != 8 or not SaveIO._has_fields(job, ["id", "tile", "remaining", "progress", "paused", "repeat", "reserved", "direction"]):
			return false
		if not job["id"] is String or not YearGame.config()["jobs"].has(job["id"]):
			return false
		if not SaveIO._integer(job["tile"], 0, 60) or occupied.has(int(job["tile"])):
			return false
		occupied[int(job["tile"])] = true
		if not SaveIO._integer(job["remaining"], 1, 100) or not SaveIO._integer(job["progress"], 0, int(YearGame.config()["jobs"][job["id"]]["days"]) - 1) or not SaveIO._integer(job["direction"], 0, 5):
			return false
		for field: String in ["paused", "repeat", "reserved"]:
			if typeof(job[field]) != TYPE_BOOL:
				return false
		if job["repeat"] and int(job["remaining"]) != 1:
			return false
		if job["id"] not in YearGame.REPEATABLE and (job["repeat"] or int(job["remaining"]) != 1):
			return false
		var prerequisite: String = String(YearGame.config()["jobs"][job["id"]].get("research", ""))
		if not prerequisite.is_empty() and prerequisite not in s["research"]:
			return false
		if not job["reserved"] and (not job["repeat"] or int(job["progress"]) != 0):
			return false
	return YearGame.workers(s) <= int(s["population"])


static func decode(value: Variant) -> Dictionary:
	var bad: Dictionary = {"error": "msg.save_corrupt", "state": {}}
	if not value is Dictionary or not value.get("format") is String or not value.get("ruleset") is String:
		return bad
	if value["format"] != FORMAT or not SaveIO._integer(value.get("version"), 1, 1) or value["ruleset"] != RULESET:
		return {"error": "msg.save_unsupported", "state": {}}
	if not valid(value.get("state")):
		return bad
	var s: Dictionary = value["state"].duplicate(true)
	if not SaveIO._restore_float64(s["board"], value.get("float64")) or not valid(s):
		return bad
	# Canonical ints and board caches make load -> continue exactly reproducible.
	for key: String in ["day", "population", "starvation", "knowledge", "score"]:
		s[key] = int(s[key])
	for key: String in s["resources"]:
		s["resources"][key] = int(s["resources"][key])
	for key: String in s["stats"]:
		s["stats"][key] = int(s["stats"][key])
	for field: String in ["health", "stock", "crop_growth", "crop_stress", "sapling_ready", "weather"]:
		for index: int in range(s[field].size()):
			s[field][index] = int(s[field][index])
	for job: Dictionary in s["jobs"]:
		for key: String in ["tile", "remaining", "progress", "direction"]:
			job[key] = int(job[key])
	s["board"] = GameState.from_dict(s["board"]).to_dict()
	return {"error": "", "state": s}
