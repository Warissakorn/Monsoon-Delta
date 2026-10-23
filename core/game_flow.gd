class_name GameFlow
extends RefCounted


static func new_game(cfg: Dictionary) -> GameState:
	var seed_value: Variant = cfg.get("seed", 0)
	var map_type: Variant = cfg.get("map_type", "plains")
	var leader: Variant = cfg.get("leader", "farmer")
	var difficulty: Variant = cfg.get("difficulty", 0)
	var run_mode: Variant = cfg.get("run_mode", "classic")
	var ruleset: Variant = cfg.get("ruleset", "legacy")
	var village_goal: Variant = cfg.get("village_goal", "none")
	if typeof(seed_value) != TYPE_INT or typeof(map_type) != TYPE_STRING:
		return null
	if map_type != "plains" or typeof(leader) != TYPE_STRING:
		return null
	var leaders: Dictionary = DataDB.balance()["leaders"]
	if not leaders.has(leader) or typeof(difficulty) != TYPE_INT:
		return null
	if difficulty < 0 or difficulty > 10:
		return null
	if typeof(run_mode) != TYPE_STRING or typeof(village_goal) != TYPE_STRING:
		return null
	if typeof(ruleset) != TYPE_STRING or ruleset not in GameState.RULESETS:
		return null
	if not DataDB.balance()["run_modes"].has(run_mode) or not DataDB.balance()["village_goals"].has(village_goal):
		return null
	for flag: String in ["is_daily", "is_tutorial", "living_village"]:
		if cfg.has(flag) and typeof(cfg[flag]) != TYPE_BOOL:
			return null
	var state: GameState = MapGen.generate(seed_value)
	if state == null:
		return null
	state.map_type = map_type
	state.leader = leader
	state.difficulty = difficulty
	state.run_mode = run_mode
	state.ruleset = ruleset
	state.village_goal = village_goal
	state.goal_achieved_year = 0
	state.is_daily = bool(cfg.get("is_daily", false))
	state.is_tutorial = bool(cfg.get("is_tutorial", false))
	state.cards.clear()
	state.card_offer.clear()
	state.pending_event = ""
	state.recompute_mods()
	state.population = maxi(0, roundi(float(state.mod("start_population"))))
	state.food = maxi(0, roundi(float(state.mod("start_food"))))
	state.wood = maxi(0, roundi(float(state.mod("start_wood"))))
	state.rng.seed = SeedUtil.derive_seed(state.seed, 1)
	state.year = 1
	state.turn = 1
	state.stats = {
		"houses_lost": 0, "paddies_lost": 0, "hall_ever_wet": false,
		"max_population": state.population, "food_produced": 0, "reached_year": 1,
	}
	state.outcome = C.Outcome.NONE
	state.harvest_report.clear()
	state.final_score = 0
	start_year(state)
	if bool(cfg.get("living_village", false)):
		SettlementProgress.initialize(state)
	return state


static func start_year(s: GameState) -> void:
	if s == null or s.outcome != C.Outcome.NONE:
		return
	s.undo.clear()
	s.redo.clear()
	for tile: Tile in s.tiles:
		if tile.feature == C.Feature.SAPLING:
			tile.feature = C.Feature.FOREST
		elif tile.feature == C.Feature.PADDY:
			if tile.paddy_dead:
				tile.soil_moisture = 0
			tile.paddy_yield = 0
			tile.paddy_dead = false
			tile.paddy_rain_turns = 0
	s.year_mods.clear()
	s.recompute_mods()
	s.food += roundi(float(s.mod("year_start_food")))
	s.wood += roundi(float(s.mod("year_start_wood")))
	s.stats["reached_year"] = s.year
	# Cards and events enter in M5. M3 skips these phases without consuming RNG
	# or exposing choices that do not yet have an implementation.
	s.card_offer.clear()
	s.pending_event = ""
	Forecast.generate(s)
	begin_turn(s)


static func begin_turn(s: GameState) -> void:
	if s == null or s.outcome != C.Outcome.NONE:
		return
	s.phase = C.Phase.PLANNING
	var labor: int = s.population
	if s.turn == 1 or s.turn == C.DRY_TURNS + 1:
		labor += roundi(float(s.mod("season_first_turn_labor")))
	if s.is_rain():
		labor += roundi(float(s.mod("rain_turn_labor")))
	s.labor = maxi(0, labor)
	s.labor_max = s.labor
	s.undo.clear()
	s.redo.clear()


static func apply_command(s: GameState, cmd: Command) -> String:
	var error: String = CommandRules.check(s, cmd)
	if not error.is_empty():
		return error
	s.undo.push(s.to_dict())
	s.redo.clear()
	CommandRules.apply(s, cmd)
	return ""


static func undo(s: GameState) -> GameState:
	if s == null or s.phase != C.Phase.PLANNING or s.undo.is_empty():
		return s
	s.redo.push(s.to_dict())
	var snapshot: Dictionary = s.undo.pop()
	var restored: GameState = GameState.from_dict(snapshot)
	restored.undo = s.undo
	restored.redo = s.redo
	return restored


static func redo(s: GameState) -> GameState:
	if s == null or s.phase != C.Phase.PLANNING or s.redo.is_empty():
		return s
	s.undo.push(s.to_dict())
	var snapshot: Dictionary = s.redo.pop()
	var restored: GameState = GameState.from_dict(snapshot)
	restored.undo = s.undo
	restored.redo = s.redo
	return restored


static func preview(s: GameState) -> Dictionary:
	if s == null:
		return {}
	var copy: GameState = s.duplicate_state()
	var report: TurnReport = TurnResolver.resolve_turn(copy, true)
	return {"state": copy, "report": report}


static func end_turn(s: GameState) -> TurnReport:
	if s == null or s.phase != C.Phase.PLANNING:
		return null
	s.undo.clear()
	s.redo.clear()
	var report: TurnReport = TurnResolver.resolve_turn(s, true)
	if s.outcome != C.Outcome.NONE:
		_finish_game(s)
	elif s.turn == C.TURNS_PER_YEAR:
		Harvest.do_harvest(s)
		s.phase = C.Phase.HARVEST
	else:
		s.turn += 1
		begin_turn(s)
	return report


static func continue_after_harvest(s: GameState) -> void:
	if s == null or s.phase != C.Phase.HARVEST:
		return
	s.undo.clear()
	s.redo.clear()
	if s.outcome != C.Outcome.NONE:
		_finish_game(s)
	else:
		s.year += 1
		s.turn = 1
		start_year(s)


static func _finish_game(s: GameState) -> void:
	s.phase = C.Phase.GAME_OVER
	s.undo.clear()
	s.redo.clear()
	s.final_score = Scoring.score(s)


# M2's repeatable rain sandbox remains available independently of game turns.
static func sandbox_new(seed_value: int) -> GameState:
	var state: GameState = MapGen.generate(seed_value)
	if state != null:
		state.turn = 4
	return state


static func sandbox_edit(s: GameState, coord: Vector2i, amount: int) -> bool:
	if amount != -1 and amount != 1:
		return false
	var tile: Tile = s.get_tile(coord)
	if tile == null or tile.is_source or tile.is_sea:
		return false
	if tile.building != C.Building.NONE or tile.feature != C.Feature.NONE:
		return false
	var settings: Dictionary = DataDB.balance()["sandbox"]
	var next_elevation: int = tile.elevation + amount
	if next_elevation < int(settings["elevation_min"]) or next_elevation > int(settings["elevation_max"]):
		return false
	tile.elevation = next_elevation
	return true


static func sandbox_step(s: GameState, inflow: float) -> Dictionary:
	s.turn = 4
	var before: float = _land_water(s)
	var report: Dictionary = WaterSim.simulate(s, maxf(0.0, inflow), true)
	var absorbed: float = WaterSim.absorb(s)
	var after: float = _land_water(s)
	var expected_after: float = before + float(report["inflow"]) - float(report["to_sea"]) + float(report["from_sea"]) - absorbed
	var balance_error: float = after - expected_after
	var errors: Array[String] = []
	if absf(balance_error) > 1e-3:
		errors.append("mass_balance")
	for tile in s.tiles:
		if not is_finite(tile.water) or tile.water < 0.0:
			errors.append("invalid_water")
			break
	report.merge({
		"before": before,
		"after": after,
		"absorbed": absorbed,
		"evaporated": 0.0,
		"expected_after": expected_after,
		"balance_error": balance_error,
		"valid": errors.is_empty(),
		"errors": errors,
	})
	return report


static func _land_water(s: GameState) -> float:
	var total: float = 0.0
	for tile in s.tiles:
		if not tile.is_sea:
			total += tile.water
	return total
