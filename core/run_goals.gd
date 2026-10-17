class_name RunGoals
extends RefCounted
## Optional village ambitions are checked after harvest and keep their medal.


static func progress(s: GameState) -> Dictionary:
	var goals: Dictionary = DataDB.balance()["village_goals"]
	var goal: Dictionary = goals.get(s.village_goal, goals["none"])
	var forests: int = 0
	for tile: Tile in s.tiles:
		if tile.feature == C.Feature.FOREST:
			forests += 1
	return {
		"population": s.population,
		"forests": forests,
		"paddy_food": int(s.harvest_report.get("paddy_food", 0)),
		"required_population": int(goal["population"]),
		"required_forests": int(goal["forests"]),
		"required_paddy_food": int(goal["paddy_food"]),
		"achieved": s.village_goal != "none" and s.goal_achieved_year > 0,
		"achieved_year": s.goal_achieved_year,
		"score": int(goal["bonus"]),
	}


static func evaluate(s: GameState) -> void:
	if s.village_goal == "none" or s.goal_achieved_year > 0 or s.harvest_report.is_empty():
		return
	var current: Dictionary = progress(s)
	if current["population"] >= current["required_population"] and current["forests"] >= current["required_forests"] and current["paddy_food"] >= current["required_paddy_food"]:
		s.goal_achieved_year = s.year
