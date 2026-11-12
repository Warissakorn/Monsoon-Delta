class_name YearPresentation
extends RefCounted
## Disposable presentation adapters. Never pass this GameState to a resolver or save.

static func board(year: Dictionary) -> GameState:
	var state: GameState = YearGame.board_of(year)
	if YearClassic.enabled(year):
		state.ruleset = GameState.ruleset_for(true, true, true)
		for index: int in range(state.tiles.size()):
			state.tiles[index].brace_turns = int(year["brace_days"][index])
			state.tiles[index].soil_moisture = int(year["soil_moisture"][index])
			state.tiles[index].irrigation_policy = String(year["irrigation_policy"][index])
	state.population = int(year["population"])
	state.food = int(year["resources"]["food"])
	state.wood = int(year["resources"]["wood"])
	state.turn = 4 if DailyProduction.season(maxi(1, int(year["day"]))) in ["early_rain", "flood"] else 1
	# Route anchors for workplaces occupy the same footprint as storage. Their
	# geometry is supplied by YearVillageView rather than a classic granary.
	for index: int in range(state.tiles.size()):
		var tile: Tile = state.tiles[index]
		if year["structures"][index] in ["sawmill", "kiln", "workshop", "camp"]:
			tile.building = C.Building.GRANARY
		if int(year["health"][index]) == 0:
			tile.building = C.Building.NONE
		if tile.feature == C.Feature.PADDY:
			tile.paddy_yield = int(year["crop_growth"][index]) / 15
	# Actual upgrade flags, not invented construction ages, select richer meshes.
	SettlementProgress.initialize(state)
	if YearHeritage.enabled(year):
		var period: int = int(YearHeritage.config()["maturity_days"])
		state.year = int(year["day"]) / period + 1
		state.settlement_progress["condition"] = year["settlement_progress"]["condition"]
		for index: int in range(state.tiles.size()):
			var record: Dictionary = YearHeritage.building(year, index)
			var id: String = YearHeritage.key(year, index)
			if record.is_empty() or not state.settlement_progress["buildings"].has(id):
				continue
			var visual: Dictionary = state.settlement_progress["buildings"][id]
			visual["built_year"] = state.year - YearHeritage.age(year, index) / period
			visual["stage"] = int(record["stage"])
	if YearGame.expanded(year):
		for index: int in range(state.tiles.size()):
			var tile: Tile = state.tiles[index]
			var key: String = "%d,%d" % [tile.q, tile.r]
			if state.settlement_progress["buildings"].has(key) and not String(year["upgrades"][index]).is_empty():
				state.settlement_progress["buildings"][key]["stage"] = maxi(1, int(state.settlement_progress["buildings"][key]["stage"]))
	return state


static func preview(year: Dictionary, after: Dictionary) -> Dictionary:
	if after.is_empty():
		return {}
	var state: GameState = board(after)
	var report: TurnReport = TurnReport.new()
	for index: int in range(state.tiles.size()):
		if int(after["health"][index]) == 0 and int(year["health"][index]) > 0:
			report.destroyed.append({"coord": state.tiles[index].coord, "building": C.Building.NONE})
	return {"state": state, "report": report}


static func resources(year: Dictionary) -> Dictionary:
	var result: Dictionary = year["resources"].duplicate(true)
	result["people"] = int(year["population"])
	result["labor"] = int(year["population"]) - YearGame.workers(year)
	result["housing"] = YearGame.housing(year)
	return result
