class_name Scoring
extends RefCounted
## Calculate the run score without changing simulation state.

const StateModel = preload("res://core/game_state.gd")
const Constants = preload("res://core/constants.gd")
const Database = preload("res://core/data_db.gd")


static func score(state: StateModel) -> int:
	var config: Dictionary = Database.balance()["scoring"]
	var base: float = state.population * float(config["population"]) + state.food
	if state.outcome == Constants.Outcome.WIN:
		if int(state.stats.get("houses_lost", 0)) == 0:
			base += float(config["no_houses_lost"])
		if not bool(state.stats.get("hall_ever_wet", false)):
			base += float(config["hall_dry"])
	var multiplier: float = 1.0 + state.difficulty * float(config["difficulty_step"])
	return roundi(base * multiplier)
