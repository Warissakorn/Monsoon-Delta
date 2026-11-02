class_name AreaDevelopment
extends RefCounted
## A proposed local command is simulated on copies using ordinary game rules.


static func category(tile: Tile) -> String:
	if tile.is_source:
		return "source"
	if tile.is_sea:
		return "sea"
	if tile.building != C.Building.NONE:
		return C.enum_name(C.Building, tile.building)
	if tile.feature == C.Feature.PADDY:
		return "paddy_dead" if tile.paddy_dead else "paddy"
	if tile.feature != C.Feature.NONE:
		return C.enum_name(C.Feature, tile.feature)
	if tile.is_river:
		return "river"
	if tile.water >= 0.05:
		return "wetland"
	return "upland" if tile.elevation >= 2 else "lowland"


static func options(state: GameState, coord: Vector2i) -> Array[String]:
	var result: Array[String] = []
	if state == null:
		return result
	var tile: Tile = state.get_tile(coord)
	if tile == null or tile.is_source or tile.is_sea:
		return result
	for id: String in CommandRules.DEFS:
		if id == "brace_house" and not state.has_bracing():
			continue
		if id == "irrigation_policy" and not state.has_irrigation():
			continue
		var unlock: String = String(CommandRules.DEFS[id].get("unlock", ""))
		if not unlock.is_empty() and float(state.mod(unlock)) <= 0.0:
			continue
		if CommandRules.supports_target(tile, id):
			result.append(id)
	return result


static func preview(state: GameState, cmd: Command) -> Dictionary:
	if state == null:
		return {"error": "err.phase"}
	if cmd == null:
		return {"error": "err.unknown"}
	var error: String = CommandRules.check(state, cmd)
	if not error.is_empty():
		return {"error": error}
	var planned: GameState = state.duplicate_state()
	error = GameFlow.apply_command(planned, cmd)
	if not error.is_empty():
		return {"error": error}
	var prediction: Dictionary = GameFlow.preview(planned)
	var projected: GameState = prediction["state"]
	var harvest: Dictionary = {}
	if state.turn == C.TURNS_PER_YEAR and projected.outcome == C.Outcome.NONE:
		projected = projected.duplicate_state()
		Harvest.do_harvest(projected)
		harvest = projected.harvest_report.duplicate(true)
	return {"error": "", "state": planned, "prediction": prediction, "harvest": harvest, "outcome": projected.outcome}
