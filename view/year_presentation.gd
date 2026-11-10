class_name YearPresentation
extends RefCounted
## Disposable presentation adapters. Never pass this GameState to a resolver or save.

static func board(year: Dictionary) -> GameState:
	var state: GameState = YearGame.board_of(year)
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
	if YearGame.expanded(year):
		for index: int in range(state.tiles.size()):
			var tile: Tile = state.tiles[index]
			var key: String = "%d,%d" % [tile.q, tile.r]
			if state.settlement_progress["buildings"].has(key) and not String(year["upgrades"][index]).is_empty():
				state.settlement_progress["buildings"][key]["stage"] = 1
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
