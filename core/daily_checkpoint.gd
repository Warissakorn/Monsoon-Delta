class_name DailyCheckpoint
extends RefCounted
## Pure validation/canonicalization for a separate prototype save format.

const FORMAT: String = "monsoon_delta_daily_prototype"
const RULESET: String = "daily_production_v1"


static func envelope(state: Dictionary) -> Dictionary:
	return {"format": FORMAT, "version": 1, "ruleset": RULESET, "state": state.duplicate(true)}


static func _integer(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= low and number <= high


static func decode(value: Variant) -> Dictionary:
	var bad: Dictionary = {"error": "msg.save_corrupt", "state": {}}
	if not value is Dictionary:
		return bad
	if not value.get("format") is String or not value.get("ruleset") is String:
		return bad
	if value["format"] != FORMAT or not _integer(value.get("version"), 1, 1) or value["ruleset"] != RULESET:
		return {"error": "msg.save_unsupported", "state": {}}
	if not value.get("state") is Dictionary:
		return bad
	var s: Dictionary = value["state"].duplicate(true)
	var fields: Array[String] = ["day", "resources", "buildings", "jobs", "knowledge", "claimed", "planks_produced", "outcome"]
	if s.size() != fields.size():
		return bad
	for field: String in fields:
		if not s.has(field):
			return bad
	for field: String in ["day", "knowledge", "planks_produced"]:
		var limit: int = int(DailyProduction.config()["duration"]) if field == "day" else 1000000
		if not _integer(s[field], 0, limit):
			return bad
		s[field] = int(s[field])
	if not s["resources"] is Dictionary or s["resources"].size() != DailyProduction.RESOURCES.size():
		return bad
	for resource: String in DailyProduction.RESOURCES:
		if not _integer(s["resources"].get(resource), 0, 1000000):
			return bad
		s["resources"][resource] = int(s["resources"][resource])
	if not s["buildings"] is Dictionary or s["buildings"].size() != DailyProduction.BUILDINGS.size():
		return bad
	for building: String in DailyProduction.BUILDINGS:
		if typeof(s["buildings"].get(building)) != TYPE_BOOL:
			return bad
	if not s["claimed"] is Array or s["claimed"].size() > DailyProduction.REWARDS.size():
		return bad
	var seen: Dictionary = {}
	for reward: Variant in s["claimed"]:
		if not reward is String or reward not in DailyProduction.REWARDS or seen.has(reward):
			return bad
		seen[reward] = true
	if ("planks" in seen) != (int(s["planks_produced"]) >= 2):
		return bad
	if ("foundation" in seen) != bool(s["buildings"]["foundation"]):
		return bad
	if bool(s["buildings"]["barrier"]) and not s["buildings"]["foundation"]:
		return bad
	if not s["outcome"] is String or s["outcome"] not in ["running", "won", "lost_food", "lost_flood"]:
		return bad
	if (s["outcome"] == "running" and int(s["day"]) >= int(DailyProduction.config()["duration"])) or (s["outcome"] == "won" and int(s["day"]) != int(DailyProduction.config()["duration"])):
		return bad
	if s["outcome"] == "won" and not s["buildings"]["barrier"]:
		return bad
	if not s["jobs"] is Array or s["jobs"].size() > DailyProduction.config()["jobs"].size():
		return bad
	seen.clear()
	for raw: Variant in s["jobs"]:
		if not raw is Dictionary or raw.size() != 4:
			return bad
		var id: Variant = raw.get("id")
		if not id is String or not DailyProduction.config()["jobs"].has(id) or seen.has(id):
			return bad
		seen[id] = true
		var definition: Dictionary = DailyProduction.config()["jobs"][id]
		if not _integer(raw.get("remaining"), 1, 20) or not _integer(raw.get("progress"), 0, int(definition["days"]) - 1) or typeof(raw.get("paused")) != TYPE_BOOL:
			return bad
		raw["remaining"] = int(raw["remaining"])
		raw["progress"] = int(raw["progress"])
		var building: String = String(definition.get("builds", ""))
		if not building.is_empty() and (s["buildings"][building] or int(raw["remaining"]) != 1):
			return bad
		var requires: String = String(definition.get("requires", ""))
		if not requires.is_empty() and not s["buildings"][requires]:
			return bad
	if DailyProduction.workers_used(s) > int(DailyProduction.config()["population"]):
		return bad
	return {"error": "", "state": s}
