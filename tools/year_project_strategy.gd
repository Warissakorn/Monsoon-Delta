class_name YearProjectStrategy
extends RefCounted
## Reference replay for expanded years. Only public orders/research; no injected state.


static func _ensure(s: Dictionary, id: String, commands: Array, batches: int = 1) -> void:
	if YearStrategy._has_job(s, id):
		return
	var index: int = YearStrategy.target(s, id)
	if index >= 0:
		YearStrategy._order(s, id, index, batches, false, commands)


static func plan(s: Dictionary, commands: Array = []) -> void:
	YearStrategy.plan(s, true, commands)
	# Recover production sites as well as the hall and homes.
	for index: int in range(s["structures"].size()):
		if s["structures"][index] in ["", "hall", "house", "stilt_house"] or int(s["health"][index]) >= 90:
			continue
		if YearGame.check_order(s, "repair", index).is_empty():
			YearStrategy._order(s, "repair", index, 1, false, commands)
	for pair: Array in [["gather_clay", "clay", 12], ["gather_fiber", "fiber", 10]]:
		if int(s["resources"][pair[1]]) < int(pair[2]):
			_ensure(s, pair[0], commands, 3)
	# A highland camp brings remote forests and deposits into work range.
	if "camp" not in s["structures"] and not YearStrategy._has_job(s, "build_camp"):
		var best: int = -1
		var score: int = -1000
		for index: int in range(s["structures"].size()):
			var distance: int = YearExpansion.distance_to_work(s, index)
			if distance < 4 or distance > 5 or not YearGame.check_order(s, "build_camp", index).is_empty():
				continue
			var value: int = int(s["board"]["tiles"][index]["elevation"]) * 10 - distance
			if value > score:
				best = index
				score = value
		if best >= 0:
			YearStrategy._order(s, "build_camp", best, 1, false, commands)
	for id: String in ["build_sawmill", "build_kiln"]:
		if YearGame.config(s)["jobs"][id]["builds"] not in s["structures"]:
			_ensure(s, id, commands)
	for pair: Array in [["saw_planks", "planks"], ["fire_bricks", "bricks"]]:
		if int(s["resources"][pair[1]]) < 8:
			_ensure(s, pair[0], commands, 4)
	for id: String in ["build_granary", "build_workshop", "build_reservoir", "build_gate"]:
		if YearGame.config(s)["jobs"][id]["builds"] not in s["structures"]:
			_ensure(s, id, commands)
	if int(s["stats"]["kits"]) < 6:
		_ensure(s, "assemble_kits", commands, 2)
	if YearGame.housing(s) < 8:
		_ensure(s, "build_house", commands)
	if "sawmill_efficient" not in s["upgrades"]:
		_ensure(s, "improve_sawmill_efficient", commands)
	if "granary_storage" not in s["upgrades"]:
		_ensure(s, "improve_granary_storage", commands)
	if s["project"] == "water" and "gate_control" not in s["upgrades"]:
		_ensure(s, "improve_gate_control", commands)
	for id: String in ["agriculture1", "agriculture2", "housing3", "water1", "water2"]:
		if YearGame.learn(s, id).is_empty():
			commands.append({"action": "learn", "id": id})
