class_name YearHeritage
extends RefCounted
## Daily building history and permanent ambition medals, opt-in year365_v5 only.
const FIELDS: Array[String] = ["settlement_progress", "goal_medal"]
const PROGRESS_FIELDS: Array[String] = ["version", "condition", "observed_day", "evaluated_day", "candidate", "candidate_periods", "hungry_days", "displaced", "buildings"]
const MEDAL_FIELDS: Array[String] = ["day", "population", "forests", "harvest"]

static func enabled(s: Dictionary) -> bool:
	return s.get("ruleset") == "year365_v5"


static func config() -> Dictionary:
	return DataDB.balance()["year_heritage"]


static func initialize(s: Dictionary) -> void:
	s["ruleset"] = "year365_v5"
	s["settlement_progress"] = {"version": 1, "condition": "stable", "observed_day": 0, "evaluated_day": 0, "candidate": "stable", "candidate_periods": 0, "hungry_days": 0, "displaced": 0, "buildings": {}}
	s["goal_medal"] = {"day": 0, "population": 0, "forests": 0, "harvest": 0}
	reconcile(s)


static func key(s: Dictionary, index: int) -> String:
	var tile: Dictionary = s["board"]["tiles"][index]
	return "%d,%d" % [int(tile["q"]), int(tile["r"])]


static func reconcile(s: Dictionary, constructed: int = -1) -> void:
	if not enabled(s):
		return
	var previous: Dictionary = s["settlement_progress"]["buildings"]
	var current: Dictionary = {}
	for index: int in range(s["structures"].size()):
		var building: String = s["structures"][index]
		if building.is_empty() or int(s["health"][index]) <= 0:
			continue
		var id: String = key(s, index)
		if index != constructed and previous.has(id) and previous[id]["building"] == building:
			current[id] = previous[id]
		else:
			current[id] = {"building": building, "built_day": int(s["day"]), "stage": 0}
	s["settlement_progress"]["buildings"] = current


static func building(s: Dictionary, index: int) -> Dictionary:
	if not enabled(s) or index < 0 or index >= s["structures"].size():
		return {}
	return s["settlement_progress"]["buildings"].get(key(s, index), {}).duplicate(true)


static func age(s: Dictionary, index: int) -> int:
	var record: Dictionary = building(s, index)
	return int(s["day"]) - int(record["built_day"]) if not record.is_empty() else 0


static func progress(s: Dictionary) -> Dictionary:
	var result: Dictionary = {"population": int(s["population"]), "forests": YearGame.forests(s), "harvest": int(s["stats"]["harvest"]), "required_population": 0, "required_forests": 0, "required_harvest": 0, "achieved": int(s["goal_medal"]["day"]) > 0, "achieved_day": int(s["goal_medal"]["day"]), "bonus": 0, "met_now": false}
	if s["goal"] == "none":
		return result
	var goal: Dictionary = config()["goals"][s["goal"]]
	for metric: String in ["population", "forests", "harvest"]:
		result["required_" + metric] = int(goal[metric])
	result["bonus"] = int(config()["goal_bonus"])
	result["met_now"] = _met(String(s["goal"]), result)
	return result


static func _met(goal: String, receipt: Dictionary) -> bool:
	if goal == "none":
		return false
	for metric: String in ["population", "forests", "harvest"]:
		if int(receipt[metric]) < int(config()["goals"][goal][metric]):
			return false
	return true


static func after_day(s: Dictionary, events: Array) -> void:
	if not enabled(s):
		return
	reconcile(s)
	var history: Dictionary = s["settlement_progress"]
	var day: int = int(s["day"])
	if int(history["observed_day"]) >= day:
		return
	history["observed_day"] = day
	if int(s["starvation"]) > 0:
		history["hungry_days"] = int(history["hungry_days"]) + 1
	if "year.event.housing_low" in events:
		history["displaced"] = int(history["displaced"]) + 1
	if day % int(config()["period_days"]) == 0:
		_evaluate(s, events)
	# No posthumous reward; an earlier medal survives either loss condition.
	if s["outcome"] == "running" and int(s["goal_medal"]["day"]) == 0 and progress(s)["met_now"]:
		s["goal_medal"] = {"day": day, "population": int(s["population"]), "forests": YearGame.forests(s), "harvest": int(s["stats"]["harvest"])}
		events.append("yearheritage.event.medal")


static func _evaluate(s: Dictionary, events: Array) -> void:
	var history: Dictionary = s["settlement_progress"]
	var target: int = SettlementProgress.Condition.STABLE
	if int(history["hungry_days"]) > 0 or int(history["displaced"]) > 0 or int(s["resources"]["food"]) == 0 or int(s["population"]) == 0:
		target = SettlementProgress.Condition.STRUGGLING
	elif YearGame.housing(s) >= int(s["population"]) and int(s["resources"]["food"]) >= YearGame.food_need(s) * int(config()["comfortable_food_days"]) and int(s["resources"]["wood"]) >= int(YearGame.config(s)["jobs"]["build_house"]["inputs"]["wood"]) * int(config()["house_cost_reserve"]):
		target = SettlementProgress.Condition.THRIVING
	var current: int = SettlementProgress.CONDITION_IDS.find(history["condition"])
	var old: String = history["condition"]
	if current == target:
		history["candidate"] = history["condition"]
		history["candidate_periods"] = 0
	else:
		var candidate: String = SettlementProgress.CONDITION_IDS[target]
		history["candidate_periods"] = int(history["candidate_periods"]) + 1 if history["candidate"] == candidate else 1
		history["candidate"] = candidate
		if int(history["candidate_periods"]) >= int(config()["confirmation_periods"]):
			current += 1 if target > current else -1
			history["condition"] = SettlementProgress.CONDITION_IDS[current]
			history["candidate"] = history["condition"]
			history["candidate_periods"] = 0
	for record: Dictionary in history["buildings"].values():
		if current == SettlementProgress.Condition.THRIVING and int(s["day"]) - int(record["built_day"]) >= int(config()["maturity_days"]):
			record["stage"] = mini(int(config()["max_stage"]), int(record["stage"]) + 1)
		elif current == SettlementProgress.Condition.STRUGGLING:
			record["stage"] = maxi(0, int(record["stage"]) - 1)
	history["evaluated_day"] = int(s["day"])
	history["hungry_days"] = 0
	history["displaced"] = 0
	if old != history["condition"]:
		events.append("yearheritage.event.condition")


static func score_parts(s: Dictionary) -> Dictionary:
	var parts: Dictionary = {"people": int(s["population"]) * 100, "food": int(s["resources"]["food"]), "challenges": s["claimed"].size() * 50, "project": int(s["project_stage"]) * 100, "goal": int(config()["goal_bonus"]) if int(s["goal_medal"]["day"]) > 0 else 0}
	var base: int = 0
	for amount: int in parts.values():
		base += amount
	var multiplier: float = 1.0 + float(s["difficulty"]) * float(DataDB.balance()["year_campaign"]["score_per_difficulty"])
	parts.merge({"base": base, "multiplier": multiplier, "total": roundi(float(base) * multiplier)})
	return parts


static func valid(s: Dictionary) -> bool:
	var history: Variant = s.get("settlement_progress")
	var medal: Variant = s.get("goal_medal")
	if not history is Dictionary or history.size() != PROGRESS_FIELDS.size() or not SaveIO._has_fields(history, PROGRESS_FIELDS):
		return false
	if not SaveIO._integer(history["version"], 1, 1) or not SaveIO._integer(history["observed_day"], int(s["day"]), int(s["day"])):
		return false
	var period: int = int(config()["period_days"])
	var evaluated: int = int(s["day"]) / period * period
	if not SaveIO._integer(history["evaluated_day"], evaluated, evaluated):
		return false
	for field: String in ["condition", "candidate"]:
		if not history[field] is String or history[field] not in SettlementProgress.CONDITION_IDS:
			return false
	if not SaveIO._integer(history["candidate_periods"], 0, int(config()["confirmation_periods"]) - 1):
		return false
	if (int(history["candidate_periods"]) == 0) != (history["candidate"] == history["condition"]):
		return false
	for field: String in ["hungry_days", "displaced"]:
		if not SaveIO._integer(history[field], 0, int(s["day"]) - evaluated):
			return false
	if not history["buildings"] is Dictionary:
		return false
	var count: int = 0
	for index: int in range(s["structures"].size()):
		if s["structures"][index] == "" or int(s["health"][index]) <= 0:
			continue
		count += 1
		var record: Variant = history["buildings"].get(key(s, index))
		if not record is Dictionary or record.size() != 3 or not SaveIO._has_fields(record, ["building", "built_day", "stage"]):
			return false
		if not record["building"] is String or record["building"] != s["structures"][index] or not SaveIO._integer(record["built_day"], 0, int(s["day"])):
			return false
		var max_stage: int = mini(int(config()["max_stage"]), (int(s["day"]) - int(record["built_day"])) / int(config()["maturity_days"]))
		if not SaveIO._integer(record["stage"], 0, max_stage):
			return false
	if count != history["buildings"].size():
		return false
	if not medal is Dictionary or medal.size() != MEDAL_FIELDS.size() or not SaveIO._has_fields(medal, MEDAL_FIELDS):
		return false
	for field: String in MEDAL_FIELDS:
		var maximum: int = int(s["day"]) if field == "day" else (12 if field == "population" else (127 if field == "forests" else int(s["stats"]["harvest"])))
		if not SaveIO._integer(medal[field], 0, maximum):
			return false
	if int(medal["day"]) == 0:
		return int(medal["population"]) == 0 and int(medal["forests"]) == 0 and int(medal["harvest"]) == 0
	return _met(String(s["goal"]), medal)


static func canonicalize(s: Dictionary) -> void:
	for field: String in ["version", "observed_day", "evaluated_day", "candidate_periods", "hungry_days", "displaced"]:
		s["settlement_progress"][field] = int(s["settlement_progress"][field])
	for record: Dictionary in s["settlement_progress"]["buildings"].values():
		record["built_day"] = int(record["built_day"])
		record["stage"] = int(record["stage"])
	for field: String in MEDAL_FIELDS:
		s["goal_medal"][field] = int(s["goal_medal"][field])
