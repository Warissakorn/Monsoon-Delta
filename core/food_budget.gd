class_name FoodBudget
extends RefCounted
## Read-only food planning. Rice and harvest accounting use the real rules.
## Only the supplied current-turn preview is read; no future rain is sampled.


static func describe(state: GameState, prediction: Dictionary) -> Dictionary:
	var per_person: int = maxi(0, roundi(float(state.mod("food_per_person"))))
	var result: Dictionary = {
		"planning": state.phase == C.Phase.PLANNING,
		"stored": state.food, "population": state.population,
		"per_person": per_person, "needed": maxi(0, state.population) * per_person,
		"rice": 0, "turns_left": maxi(0, C.TURNS_PER_YEAR - state.turn + 1),
		"growth_cost": maxi(0, roundi(float(state.mod("food_per_growth")))),
		"rot_percent": roundi(clampf(float(state.mod("rot_fraction")), 0.0, 1.0) * 100.0),
		"next": {},
	}
	# A harvest-phase board still contains its old rice counters. Do not count
	# those counters again after the food has already entered the store.
	if not result["planning"]:
		return result
	result["rice"] = _rice(state)
	if prediction.is_empty():
		return result
	var predicted: GameState = prediction["state"]
	var report: TurnReport = prediction["report"]
	var next: Dictionary = {
		"kind": "turn", "stored": predicted.food,
		"rice": _rice(predicted), "fish": report.fish_food,
		"needed": maxi(0, predicted.population) * maxi(0, roundi(float(predicted.mod("food_per_person")))),
		"harvest": {}, "capacity": maxi(0, predicted.capacity()),
		"outcome": predicted.outcome, "new_goal": false,
	}
	if report.outcome == C.Outcome.LOSE_HALL:
		# Production and harvest do not occur after the hall is lost.
		next["kind"] = "hall_loss"
		next["rice"] = 0
	elif state.turn == C.TURNS_PER_YEAR:
		var harvested: GameState = predicted.duplicate_state()
		Harvest.do_harvest(harvested)
		next["kind"] = "harvest"
		next["harvest"] = harvested.harvest_report.duplicate(true)
		next["outcome"] = harvested.outcome
		next["new_goal"] = state.goal_achieved_year == 0 and harvested.goal_achieved_year > 0
	next["available"] = int(next["stored"]) + int(next["rice"])
	next["gap"] = maxi(0, int(next["needed"]) - int(next["available"]))
	result["next"] = next
	return result


static func _rice(state: GameState) -> int:
	var total: int = 0
	for amount: int in Harvest.paddy_food_by_tile(state).values():
		total += amount
	return total
