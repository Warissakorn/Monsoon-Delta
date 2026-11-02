class_name ResourceLedger
extends RefCounted
## Compact committed facts for a session report, never part of a checkpoint.
const KEYS: Array[String] = ["labor", "food", "wood", "people", "housing"]


static func capture(state: GameState) -> Dictionary:
	return {"labor": state.labor, "food": state.food, "wood": state.wood, "people": state.population, "housing": state.capacity()}


static func for_turn(before: Dictionary, state: GameState, report: TurnReport, harvest: Dictionary, growth_cost: int) -> Dictionary:
	var ledger: Dictionary = {"before": before.duplicate(true), "after": capture(state), "causes": []}
	_add(ledger, "food", "fish", report.fish_food)
	if not harvest.is_empty():
		_add(ledger, "food", "rice", int(harvest["paddy_food"]))
		_add(ledger, "food", "feeding", -int(harvest["eaten"]))
		_add(ledger, "food", "birth_food", -int(harvest["born"]) * maxi(0, growth_cost))
		_add(ledger, "food", "spoilage", -int(harvest["spoiled"]))
		_add(ledger, "people", "hunger", -int(harvest["left_hunger"]))
		_add(ledger, "people", "housing", -int(harvest["left_housing"]))
		_add(ledger, "people", "births", int(harvest["born"]))
	var homes_lost: bool = false
	for item: Dictionary in report.destroyed:
		if int(item["building"]) in [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE]:
			homes_lost = true
	if homes_lost:
		_add(ledger, "housing", "homes_lost", int(ledger["after"]["housing"]) - int(before["housing"]))
	if state.phase == C.Phase.PLANNING:
		_add(ledger, "labor", "next_turn", int(ledger["after"]["labor"]) - int(before["labor"]))
	# Preserve exact totals if another rule introduces a change for which no
	# named cause is available. Do not guess a production/consumption reason.
	for key: String in KEYS:
		var accounted: int = 0
		for cause: Dictionary in ledger["causes"]:
			if cause["resource"] == key:
				accounted += int(cause["amount"])
		var delta: int = int(ledger["after"][key]) - int(before[key])
		_add(ledger, key, "other", delta - accounted)
	return ledger


static func _add(ledger: Dictionary, resource: String, reason: String, amount: int) -> void:
	if amount != 0:
		ledger["causes"].append({"resource": resource, "reason": reason, "amount": amount})
