class_name YearAreaDevelopment
extends RefCounted
## Contextual orders and disposable forecasts. All commits belong to YearSession.

static func role(s: Dictionary, index: int) -> String:
	var tile: Dictionary = s["board"]["tiles"][index]
	if tile["is_source"] or tile["is_sea"]:
		return "protected"
	var structure: String = s["structures"][index]
	if structure in ["house", "stilt_house", "raft_house", "hall"]:
		return "home"
	if structure in ["gate", "reservoir", "waterwheel"]:
		return "waterworks"
	if not structure.is_empty():
		return "industry"
	if tile["feature"] == "paddy":
		return "field"
	if tile["feature"] in ["forest", "sapling"]:
		return "forest"
	return "deposit" if not String(s["deposits"][index]).is_empty() else "land"


static func options(s: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if index < 0 or index >= s["structures"].size():
		return result
	for id: String in YearGame.config(s)["jobs"]:
		if YearGame.target_matches(s, id, index):
			result.append({"action": "order", "id": id, "error": YearGame.check_order(s, id, index)})
	if s["structures"][index] == "gate":
		result.append({"action": "gate", "id": "", "error": "" if s["outcome"] == "running" and int(s["health"][index]) > 0 else "year.error.target"})
	if YearClassic.enabled(s) and s["board"]["tiles"][index]["feature"] == "paddy":
		for policy: String in Irrigation.POLICIES:
			result.append({"action": "irrigation", "id": policy, "error": "" if s["outcome"] == "running" and s["irrigation_policy"][index] != policy else "year.error.target"})
	return result


static func expected_output(s: Dictionary, id: String, index: int) -> Dictionary:
	if id == "harvest":
		return {"food": int(s["crop_growth"][index]) + (20 if "agriculture1" in s["research"] else 0) + (int(DataDB.balance()["year_campaign"]["leaders"]["farmer"]["harvest_bonus"]) if s.get("leader") == "farmer" else 0)}
	return YearGame.outputs(s, id)
