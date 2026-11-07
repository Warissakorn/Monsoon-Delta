class_name TransportCheckpoint
extends RefCounted
## A distinct envelope; nested year v2 and its float64 values stay intact.

const FORMAT: String = "monsoon_transport"
const FIELDS: Array[String] = ["sites", "land", "water", "ports", "inventory", "work", "shipments", "sequence", "initial_stock", "gathered", "produced", "claimed"]


static func envelope(model: Dictionary) -> Dictionary:
	return {"format": FORMAT, "version": 1, "ruleset": TransportGame.RULESET, "year": YearCheckpoint.envelope(model["year"]), "transport": model["transport"].duplicate(true)}


static func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size():
		return false
	for name: String in names:
		if not value.has(name):
			return false
	return true


static func valid(model: Variant) -> bool:
	if not _fields(model, ["year", "transport"]) or not YearCheckpoint.valid(model["year"]) or not YearGame.expanded(model["year"]):
		return false
	var year: Dictionary = model["year"]
	var t: Variant = model["transport"]
	if not _fields(t, FIELDS):
		return false
	for field: String in ["sequence", "initial_stock", "gathered", "produced", "claimed"]:
		if not SaveIO._integer(t[field], 1 if field in ["sequence", "initial_stock"] else 0, 1000000):
			return false
	if not _fields(t["sites"], TransportGame.ROLES) or not _fields(t["ports"], TransportGame.ROLES) or not _fields(t["inventory"], TransportGame.ROLES):
		return false
	var coords: Array[Vector2i] = [TransportGame.SOURCE, TransportGame.MILL, TransportGame.STORE]
	for index: int in range(TransportGame.ROLES.size()):
		var role: String = TransportGame.ROLES[index]
		if not SaveIO._integer(t["sites"][role], 0, 126) or int(t["sites"][role]) != TransportGame.tile_index(year, coords[index]) or typeof(t["ports"][role]) != TYPE_BOOL:
			return false
		if not _fields(t["inventory"][role], ["wood", "planks"]):
			return false
		for resource: String in ["wood", "planks"]:
			if not SaveIO._integer(t["inventory"][role][resource], 0, 1000000):
				return false
	for field: String in ["land", "water"]:
		var expected: Array[int] = TransportGame.indices(year, TransportGame.LAND if field == "land" else TransportGame.WATER)
		if not t[field] is Array or t[field].size() != expected.size():
			return false
		for index: int in range(expected.size()):
			if not SaveIO._integer(t[field][index], 0, 126) or int(t[field][index]) != expected[index]:
				return false
	if year["structures"][t["sites"]["source"]] != "" or year["structures"][t["sites"]["mill"]] != "sawmill" or year["structures"][t["sites"]["store"]] != "granary":
		return false
	if int(t["inventory"]["source"]["planks"]) != 0 or int(t["inventory"]["store"]["wood"]) != 0:
		return false
	for job: Dictionary in year["jobs"]:
		if TransportGame.protected_order(model, job["id"], int(job["tile"])):
			return false
	if not t["work"] is Array or not t["shipments"] is Array or t["work"].size() + t["shipments"].size() > TransportGame.MAX_ORDERS:
		return false
	var ids: Dictionary = {}
	var work_kinds: Dictionary = {}
	for job: Variant in t["work"]:
		if not _fields(job, ["id", "kind", "batches", "progress", "duration", "paused"]):
			return false
		if not job["kind"] is String or job["kind"] not in ["cut", "saw"] or work_kinds.has(job["kind"]) or typeof(job["paused"]) != TYPE_BOOL:
			return false
		if not SaveIO._integer(job["id"], 1, int(t["sequence"]) - 1) or ids.has(int(job["id"])) or not SaveIO._integer(job["batches"], 1, 100) or not SaveIO._integer(job["duration"], 1, 30) or not SaveIO._integer(job["progress"], 0, int(job["duration"]) - 1):
			return false
		ids[int(job["id"])] = true
		work_kinds[job["kind"]] = true
		for other: Dictionary in year["jobs"]:
			if int(other["tile"]) == int(t["sites"]["source" if job["kind"] == "cut" else "mill"]):
				return false
	for job: Variant in t["shipments"]:
		if not _fields(job, ["id", "resource", "origin", "target", "amount", "mode", "capacity", "speed", "current", "loaded", "returning", "paused"]):
			return false
		if not job["resource"] is String or job["resource"] not in ["wood", "planks"] or not job["mode"] is String or job["mode"] not in ["land", "boat"]:
			return false
		if not job["origin"] is String or not job["target"] is String or job["origin"] != ("source" if job["resource"] == "wood" else "mill") or job["target"] != ("mill" if job["resource"] == "wood" else "store"):
			return false
		for field: String in ["loaded", "returning", "paused"]:
			if typeof(job[field]) != TYPE_BOOL:
				return false
		if not SaveIO._integer(job["id"], 1, int(t["sequence"]) - 1) or ids.has(int(job["id"])) or not SaveIO._integer(job["capacity"], 1, 100) or not SaveIO._integer(job["amount"], 1, int(job["capacity"])) or not SaveIO._integer(job["speed"], 1, 4) or not SaveIO._integer(job["current"], 0, 126):
			return false
		ids[int(job["id"])] = true
		# JSON numbers arrive as float Variants; membership must use canonical
		# integer indices before checking a cargo position in the corridor.
		var allowed: Array[int] = []
		allowed.assign(t["land"] if job["mode"] == "land" else t["water"])
		allowed.append(int(t["sites"][job["origin"]]))
		allowed.append(int(t["sites"][job["target"]]))
		if int(job["current"]) not in allowed or (not job["loaded"] and (job["returning"] or int(job["current"]) != int(t["sites"][job["origin"]]))):
			return false
	var accounting: Dictionary = TransportGame.ledger(model)
	if not accounting["forest_exact"] or not accounting["wood_exact"] or not accounting["planks_exact"]:
		return false
	var forest: bool = int(year["stock"][t["sites"]["source"]]) + int(accounting["forest_reserved"]) > 0
	if year["board"]["tiles"][t["sites"]["source"]]["feature"] != ("forest" if forest else "none"):
		return false
	return TransportGame.free_workers(model) >= 0 and int(year["stats"]["planks"]) >= int(t["claimed"])


static func decode(value: Variant) -> Dictionary:
	var bad: Dictionary = {"error": "msg.save_corrupt", "state": {}}
	if not value is Dictionary or not value.get("format") is String or not value.get("ruleset") is String:
		return bad
	if value["format"] != FORMAT or value["ruleset"] != TransportGame.RULESET or not SaveIO._integer(value.get("version"), 1, 1):
		return {"error": "msg.save_unsupported", "state": {}}
	if not _fields(value, ["format", "version", "ruleset", "year", "transport"]):
		return bad
	var nested: Dictionary = YearCheckpoint.decode(value["year"])
	if not String(nested["error"]).is_empty():
		return nested
	var model: Dictionary = {"year": nested["state"], "transport": value["transport"]}
	if not valid(model):
		return bad
	model["transport"] = _canonical(value["transport"])
	return {"error": "", "state": model}


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_canonical(entry))
		return result
	return int(value) if typeof(value) == TYPE_FLOAT else value
