class_name TransportGame
extends RefCounted
## A versioned wood -> planks pilot wrapped around an unchanged year365_v2.
## All quantities are integer units. Views, routes and preview never use RNG.

const RULESET: String = "transport365_v1"
const ROLES: Array[String] = ["source", "mill", "store"]
const SOURCE: Vector2i = Vector2i(-4, 0)
const MILL: Vector2i = Vector2i(-2, -1)
const STORE: Vector2i = Vector2i(-1, -2)
const LAND: Array[Vector2i] = [SOURCE, Vector2i(-3, 0), MILL, STORE]
const WATER: Array[Vector2i] = [Vector2i(-4, -1), Vector2i(-3, -2), Vector2i(-2, -2)]
const MAX_ORDERS: int = 16


static func config() -> Dictionary:
	return DataDB.balance()["transport_pilot_v1"]


static func tile_index(year: Dictionary, coord: Vector2i) -> int:
	for index: int in range(year["board"]["tiles"].size()):
		var tile: Dictionary = year["board"]["tiles"][index]
		if int(tile["q"]) == coord.x and int(tile["r"]) == coord.y:
			return index
	return -1


static func indices(year: Dictionary, coords: Array[Vector2i]) -> Array[int]:
	var result: Array[int] = []
	for coord: Vector2i in coords:
		result.append(tile_index(year, coord))
	return result


static func create(seed_value: int = 42, goal: String = "none", project: String = "food") -> Dictionary:
	var year: Dictionary = YearGame.new_expanded(seed_value, goal, project)
	if year.is_empty():
		return {}
	var sites: Dictionary = {"source": tile_index(year, SOURCE), "mill": tile_index(year, MILL), "store": tile_index(year, STORE)}
	_relocate_village(year)
	# The pilot has authored corridors on the seeded 127-hex year map. Ordinary
	# year games do not call this setup and retain their generated terrain.
	for coord: Vector2i in LAND + WATER:
		var index: int = tile_index(year, coord)
		var tile: Dictionary = year["board"]["tiles"][index]
		tile["elevation"] = 3
		tile["water"] = 0.0
		tile["feature"] = "none"
		tile["building"] = "none"
		tile["is_river"] = false
		tile["is_sea"] = false
		tile["is_source"] = false
		tile["start_house"] = false
		year["structures"][index] = ""
		year["health"][index] = 0
		year["deposits"][index] = ""
		year["stock"][index] = 0
		year["crop_growth"][index] = 0
		year["crop_stress"][index] = 0
		year["sapling_ready"][index] = 0
		year["upgrades"][index] = ""
		year["gate_half"][index] = false
	for coord: Vector2i in WATER:
		var index: int = tile_index(year, coord)
		var tile: Dictionary = year["board"]["tiles"][index]
		tile["elevation"] = 0
		tile["water"] = float(config()["initial_water"])
		tile["is_river"] = true
		for neighbor: Vector2i in Hex.neighbors(coord):
			var other: int = tile_index(year, neighbor)
			if other >= 0 and neighbor not in WATER:
				year["board"]["tiles"][other]["elevation"] = maxi(3, int(year["board"]["tiles"][other]["elevation"]))
	year["board"]["tiles"][sites["source"]]["feature"] = "forest"
	year["stock"][sites["source"]] = int(config()["source_stock"])
	year["structures"][sites["mill"]] = "sawmill"
	year["health"][sites["mill"]] = 100
	year["structures"][sites["store"]] = "granary"
	year["board"]["tiles"][sites["store"]]["building"] = "granary"
	year["health"][sites["store"]] = 100
	var transport: Dictionary = {
		"sites": sites, "land": indices(year, LAND), "water": indices(year, WATER),
		"ports": {"source": true, "mill": true, "store": true},
		"inventory": {"source": {"wood": 0, "planks": 0}, "mill": {"wood": 0, "planks": 0}, "store": {"wood": 0, "planks": 0}},
		"work": [], "shipments": [], "sequence": 1,
		"initial_stock": int(config()["source_stock"]), "gathered": 0, "produced": 0, "claimed": 0,
	}
	return {"year": year, "transport": transport}


static func _relocate_village(year: Dictionary) -> void:
	# The authored pilot must not erase a seeded hall or home. Only new runs
	# relocate conflicting buildings; existing checkpoints retain their board.
	var corridor: Array[int] = indices(year, LAND + WATER)
	var hall: int = year["structures"].find("hall")
	var center: Dictionary = year["board"]["tiles"][hall]
	var origin: Vector2i = Vector2i(int(center["q"]), int(center["r"]))
	var occupied: Array[int] = []
	for index: int in corridor:
		if year["structures"][index] != "":
			occupied.append(index)
	for index: int in occupied:
		var chosen: int = -1
		var nearest: int = 100
		for other: int in range(year["structures"].size()):
			var tile: Dictionary = year["board"]["tiles"][other]
			if other in corridor or not YearGame.target_matches(year, "build_house", other):
				continue
			var distance: int = Hex.distance(origin, Vector2i(int(tile["q"]), int(tile["r"])))
			if distance < nearest:
				chosen = other
				nearest = distance
		assert(chosen >= 0, "The 127-hex pilot needs room for its seeded village")
		var source: Dictionary = year["board"]["tiles"][index]
		var target: Dictionary = year["board"]["tiles"][chosen]
		year["structures"][chosen] = year["structures"][index]
		year["health"][chosen] = year["health"][index]
		target["building"] = source["building"]
		target["start_house"] = source["start_house"]
		target["elevation"] = maxi(3, int(target["elevation"]))
		source["building"] = "none"
		source["start_house"] = false
		year["structures"][index] = ""
		year["health"][index] = 0


static func workers(model: Dictionary) -> int:
	var count: int = 0
	for job: Dictionary in model["transport"]["work"] + model["transport"]["shipments"]:
		if not job["paused"]:
			count += 1
	return count


static func free_workers(model: Dictionary) -> int:
	return int(model["year"]["population"]) - YearGame.workers(model["year"]) - workers(model)


static func protected_order(model: Dictionary, id: String, index: int) -> bool:
	var sites: Dictionary = model["transport"]["sites"]
	return index == int(sites["source"]) or (index == int(sites["mill"]) and id != "repair") or (index == int(sites["store"]) and id in ["demolish", "improve_granary_storage", "improve_granary_raised"])


static func order_work(model: Dictionary, kind: String, batches: int) -> String:
	var year: Dictionary = model["year"]
	var t: Dictionary = model["transport"]
	if year["outcome"] != "running":
		return "year.error.finished"
	if kind not in ["cut", "saw"] or batches < 1 or batches > 100:
		return "transport.error.order"
	if free_workers(model) < 1:
		return "year.error.workers"
	if t["work"].size() + t["shipments"].size() >= MAX_ORDERS:
		return "transport.error.queue"
	var role: String = "source" if kind == "cut" else "mill"
	var index: int = int(t["sites"][role])
	for job: Dictionary in t["work"]:
		if job["kind"] == kind:
			return "year.error.occupied"
	for job: Dictionary in year["jobs"]:
		if int(job["tile"]) == index:
			return "year.error.occupied"
	if float(year["board"]["tiles"][index]["water"]) >= 0.5 or (kind == "saw" and int(year["health"][index]) == 0):
		return "transport.status.site"
	if kind == "cut":
		if int(year["stock"][index]) < batches * 2:
			return "transport.error.stock"
		year["stock"][index] = int(year["stock"][index]) - batches * 2
	else:
		if int(t["inventory"]["mill"]["wood"]) < batches * 2:
			return "transport.error.stock"
		t["inventory"]["mill"]["wood"] = int(t["inventory"]["mill"]["wood"]) - batches * 2
	t["work"].append({"id": int(t["sequence"]), "kind": kind, "batches": batches, "progress": 0, "duration": int(config()[kind + "_days"]), "paused": false})
	t["sequence"] = int(t["sequence"]) + 1
	return ""


static func dispatch(model: Dictionary, resource: String, amount: int, mode: String) -> String:
	var t: Dictionary = model["transport"]
	if model["year"]["outcome"] != "running":
		return "year.error.finished"
	if resource not in ["wood", "planks"] or not config()["modes"].has(mode) or amount < 1:
		return "transport.error.order"
	var policy: Dictionary = config()["modes"][mode]
	if amount > int(policy["capacity"]):
		return "transport.error.capacity"
	if free_workers(model) < 1:
		return "year.error.workers"
	if t["work"].size() + t["shipments"].size() >= MAX_ORDERS:
		return "transport.error.queue"
	var origin: String = "source" if resource == "wood" else "mill"
	var target: String = "mill" if resource == "wood" else "store"
	if int(t["inventory"][origin][resource]) < amount:
		return "transport.error.stock"
	t["inventory"][origin][resource] = int(t["inventory"][origin][resource]) - amount
	t["shipments"].append({"id": int(t["sequence"]), "resource": resource, "origin": origin, "target": target, "amount": amount, "mode": mode, "capacity": int(policy["capacity"]), "speed": int(policy["speed"]), "current": int(t["sites"][origin]), "loaded": false, "returning": false, "paused": false})
	t["sequence"] = int(t["sequence"]) + 1
	return ""


static func edit(model: Dictionary, action: String, id: int = -1, role: String = "", amount: int = 0) -> String:
	var year: Dictionary = model["year"]
	var t: Dictionary = model["transport"]
	if year["outcome"] != "running":
		return "year.error.finished"
	if action == "port":
		if role not in ROLES:
			return "transport.error.order"
		t["ports"][role] = not t["ports"][role]
		return ""
	if action == "claim":
		if amount < 1 or amount > int(t["inventory"]["store"]["planks"]):
			return "transport.error.stock"
		t["inventory"]["store"]["planks"] = int(t["inventory"]["store"]["planks"]) - amount
		t["claimed"] = int(t["claimed"]) + amount
		year["resources"]["planks"] = int(year["resources"]["planks"]) + amount
		year["stats"]["planks"] = int(year["stats"]["planks"]) + amount
		return ""
	for field: String in ["work", "shipments"]:
		for job: Dictionary in t[field]:
			if int(job["id"]) != id:
				continue
			if action == "pause":
				if job["paused"] and free_workers(model) < 1:
					return "year.error.workers"
				job["paused"] = not job["paused"]
				return ""
			if action != "cancel":
				return "transport.error.order"
			if field == "work":
				if job["kind"] == "cut":
					year["stock"][t["sites"]["source"]] = int(year["stock"][t["sites"]["source"]]) + int(job["batches"]) * 2
				else:
					t["inventory"]["mill"]["wood"] = int(t["inventory"]["mill"]["wood"]) + int(job["batches"]) * 2
				t[field].erase(job)
			elif not job["loaded"]:
				t["inventory"][job["origin"]][job["resource"]] = int(t["inventory"][job["origin"]][job["resource"]]) + int(job["amount"])
				t[field].erase(job)
			else:
				job["returning"] = true
			return ""
	return "transport.error.order"


static func route(model: Dictionary, start: int, destination: int, mode: String) -> Array[int]:
	var t: Dictionary = model["transport"]
	var allowed: Array[int] = []
	allowed.assign(t["land"] if mode == "land" else t["water"])
	if mode == "boat":
		for role: String in ROLES:
			var bank: int = int(t["sites"][role])
			if bank in [start, destination] and t["ports"][role]:
				allowed.append(bank)
	if start not in allowed or destination not in allowed or not passable(model, start, mode) or not passable(model, destination, mode):
		return []
	var previous: Dictionary = {start: -1}
	var queue: Array[int] = [start]
	var cursor: int = 0
	while cursor < queue.size():
		var at: int = queue[cursor]
		cursor += 1
		if at == destination:
			var path: Array[int] = []
			while at >= 0:
				path.push_front(at)
				at = int(previous[at])
			return path
		for neighbor: int in allowed:
			if previous.has(neighbor) or not passable(model, neighbor, mode) or not adjacent(model["year"], at, neighbor):
				continue
			if mode == "boat" and at not in t["water"] and neighbor not in t["water"]:
				continue
			if mode == "boat" and at in t["water"] and neighbor in t["water"]:
				var a: Dictionary = model["year"]["board"]["tiles"][at]
				var b: Dictionary = model["year"]["board"]["tiles"][neighbor]
				if absf(float(a["elevation"]) + float(a["water"]) - float(b["elevation"]) - float(b["water"])) > 0.5:
					continue
			if mode == "land" and absi(int(model["year"]["board"]["tiles"][at]["elevation"]) - int(model["year"]["board"]["tiles"][neighbor]["elevation"])) > 1:
				continue
			previous[neighbor] = at
			queue.append(neighbor)
	return []


static func adjacent(year: Dictionary, a: int, b: int) -> bool:
	var first: Dictionary = year["board"]["tiles"][a]
	var second: Dictionary = year["board"]["tiles"][b]
	return Hex.distance(Vector2i(int(first["q"]), int(first["r"])), Vector2i(int(second["q"]), int(second["r"]))) == 1


static func passable(model: Dictionary, index: int, mode: String) -> bool:
	var year: Dictionary = model["year"]
	var t: Dictionary = model["transport"]
	var tile: Dictionary = year["board"]["tiles"][index]
	if index in t["sites"].values():
		if float(tile["water"]) >= 0.5 or (year["structures"][index] != "" and int(year["health"][index]) == 0):
			return false
		return true
	if mode == "boat":
		return index in t["water"] and float(tile["water"]) >= 0.2 and not tile["is_sea"] and not tile["is_source"]
	return index in t["land"] and float(tile["water"]) < 0.05 and not tile["is_river"] and year["structures"][index] not in ["gate", "reservoir", "waterwheel"]


static func shipment_status(model: Dictionary, job: Dictionary) -> String:
	if job["paused"]:
		return "daily.paused"
	var target: int = int(model["transport"]["sites"][job["origin"] if job["returning"] else job["target"]])
	if route(model, int(job["current"]), target, job["mode"]).is_empty():
		return "transport.status.blocked"
	return "transport.status.returning" if job["returning"] else ("transport.status.moving" if job["loaded"] else "transport.status.reserved")


static func work_status(model: Dictionary, job: Dictionary) -> String:
	if job["paused"]:
		return "daily.paused"
	var index: int = int(model["transport"]["sites"]["source" if job["kind"] == "cut" else "mill"])
	if not passable(model, index, "land"):
		return "transport.status.site"
	for other: Dictionary in model["year"]["jobs"]:
		if int(other["tile"]) == index:
			return "transport.status.site"
	return "year.job.working"


static func ledger(model: Dictionary) -> Dictionary:
	var t: Dictionary = model["transport"]
	var result: Dictionary = {"wood_available": 0, "wood_reserved": 0, "wood_transit": 0, "planks_available": 0, "planks_reserved": 0, "planks_transit": 0, "forest_reserved": 0, "processing": 0}
	for role: String in ROLES:
		for resource: String in ["wood", "planks"]:
			result[resource + "_available"] += int(t["inventory"][role][resource])
	for job: Dictionary in t["work"]:
		result["forest_reserved" if job["kind"] == "cut" else "processing"] += int(job["batches"]) * 2
	for job: Dictionary in t["shipments"]:
		result[String(job["resource"]) + ("_transit" if job["loaded"] else "_reserved")] += int(job["amount"])
	result["forest_exact"] = int(t["initial_stock"]) == int(model["year"]["stock"][t["sites"]["source"]]) + int(result["forest_reserved"]) + int(t["gathered"])
	result["wood_exact"] = int(t["gathered"]) == int(result["wood_available"]) + int(result["wood_reserved"]) + int(result["wood_transit"]) + int(result["processing"]) + int(t["produced"]) * 2
	result["planks_exact"] = int(t["produced"]) == int(result["planks_available"]) + int(result["planks_reserved"]) + int(result["planks_transit"]) + int(t["claimed"])
	return result


static func _tick(model: Dictionary, events: Array) -> void:
	var year: Dictionary = model["year"]
	var t: Dictionary = model["transport"]
	for job: Dictionary in t["work"].duplicate():
		if work_status(model, job) != "year.job.working":
			continue
		job["progress"] = int(job["progress"]) + 1
		if int(job["progress"]) < int(job["duration"]):
			continue
		if job["kind"] == "cut":
			t["inventory"]["source"]["wood"] = int(t["inventory"]["source"]["wood"]) + 2
			t["gathered"] = int(t["gathered"]) + 2
		else:
			t["inventory"]["mill"]["planks"] = int(t["inventory"]["mill"]["planks"]) + 1
			t["produced"] = int(t["produced"]) + 1
		job["progress"] = 0
		job["batches"] = int(job["batches"]) - 1
		if int(job["batches"]) == 0:
			t["work"].erase(job)
		events.append("transport.event.work")
	for job: Dictionary in t["shipments"].duplicate():
		if shipment_status(model, job) in ["daily.paused", "transport.status.blocked"]:
			continue
		if not job["loaded"]:
			job["loaded"] = true
			events.append("transport.event.loaded")
			continue
		var target: int = int(t["sites"][job["origin"] if job["returning"] else job["target"]])
		var path: Array[int] = route(model, int(job["current"]), target, job["mode"])
		job["current"] = path[mini(int(job["speed"]), path.size() - 1)]
		if int(job["current"]) == target:
			var role: String = job["origin"] if job["returning"] else job["target"]
			t["inventory"][role][job["resource"]] = int(t["inventory"][role][job["resource"]]) + int(job["amount"])
			t["shipments"].erase(job)
			events.append("transport.event.returned" if job["returning"] else "transport.event.arrived")
	if int(year["stock"][t["sites"]["source"]]) == 0:
		var pending: bool = false
		for job: Dictionary in t["work"]:
			pending = pending or job["kind"] == "cut"
		if not pending:
			year["board"]["tiles"][t["sites"]["source"]]["feature"] = "none"


static func advance(model: Dictionary, days: int) -> Dictionary:
	var report: Dictionary = {"days": 0, "events": []}
	if days < 1 or days > 365:
		return report
	for step: int in range(days):
		if model["year"]["outcome"] != "running":
			break
		var events: Array = []
		_tick(model, events)
		events.append_array(YearGame.resolve_day(model["year"]))
		# A population loss may require pausing couriers as well as year jobs.
		var all_jobs: Array = model["transport"]["shipments"] + model["transport"]["work"]
		all_jobs.reverse()
		for job: Dictionary in all_jobs:
			if free_workers(model) >= 0:
				break
			if not job["paused"]:
				job["paused"] = true
				events.append("transport.event.labor")
		for job: Dictionary in model["transport"]["shipments"]:
			if shipment_status(model, job) == "transport.status.blocked":
				events.append("transport.event.blocked")
				break
		for job: Dictionary in model["transport"]["work"]:
			if work_status(model, job) == "transport.status.site":
				events.append("transport.event.blocked")
				break
		report["days"] += 1
		report["events"].append_array(events)
		if not events.is_empty():
			break
	return report


static func preview(model: Dictionary, days: int = 1) -> Dictionary:
	var copy: Dictionary = model.duplicate(true)
	return {"state": copy, "report": advance(copy, days)}
