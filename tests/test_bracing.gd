extends TestCase


func _house(building: int = C.Building.HOUSE, depth: float = 0.0, rain: bool = true) -> GameState:
	var state: GameState = TestMaps.small(0, 0)
	state.ruleset = "bracing_v1"
	state.turn = 4 if rain else 1
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.year_mods.assign([
		{"key": "water_iterations", "op": "set", "value": 1},
		{"key": "dry_inflow", "op": "set", "value": 0},
		{"key": "evaporation_dry", "op": "set", "value": 0},
	])
	state.recompute_mods()
	state.tiles[0].building = building
	state.tiles[0].water = depth
	return state


func _brace(state: GameState) -> String:
	return GameFlow.apply_command(state, Command.new("brace_house", state.tiles[0].coord))


func test_new_game_ruleset_is_explicit_and_rejects_unsupported_values() -> void:
	assert_eq(GameFlow.new_game({"seed": 42}).ruleset, "legacy")
	assert_true(GameFlow.new_game({"seed": 42, "ruleset": "bracing_v1"}).has_bracing())
	for invalid: Variant in ["", "seasonal_works_v1", "BRACING_V1", 1, true]:
		assert_eq(GameFlow.new_game({"seed": 42, "ruleset": invalid}), null)


func test_only_bracing_ruleset_can_use_command_and_legacy_shape_is_preserved() -> void:
	var state: GameState = _house()
	state.ruleset = "legacy"
	var before: Dictionary = state.to_dict()
	assert_eq(_brace(state), "err.locked")
	assert_eq(state.to_dict(), before)
	assert_true(not before.has("ruleset"))
	assert_true(not before.tiles[0].has("brace_turns"))
	assert_true(not state.tiles[0].to_dict().has("brace_turns"))
	state.ruleset = "bracing_v1"
	assert_eq(state.to_dict().tiles[0]["brace_turns"], 0)


func test_cost_and_duplicate_validation_in_both_seasons_on_wet_house() -> void:
	for rain: bool in [false, true]:
		var state: GameState = _house(C.Building.HOUSE, 0.6, rain)
		assert_eq(CommandRules.cost(state, Command.new("brace_house", Vector2i.ZERO)), Vector2i(2, 1))
		assert_eq(_brace(state), "")
		assert_eq(state.labor, 8)
		assert_eq(state.wood, 9)
		assert_eq(state.tiles[0].brace_turns, 1)
		var before: Dictionary = state.to_dict()
		assert_eq(_brace(state), "err.braced")
		assert_eq(state.to_dict(), before)
		assert_eq(state.undo.size(), 1)


func test_bracing_rejects_hall_raft_granary_and_non_houses_without_charge() -> void:
	for building: int in C.Building.values():
		if building in [C.Building.HOUSE, C.Building.STILT_HOUSE]:
			continue
		var state: GameState = _house(building)
		var before: Dictionary = state.to_dict()
		assert_eq(_brace(state), "err.target", "building %d" % building)
		assert_eq(state.to_dict(), before)
		assert_true(state.undo.is_empty())


func test_affordability_param_and_phase_validation_do_not_mutate() -> void:
	var state: GameState = _house()
	state.labor = 1
	assert_eq(_brace(state), "err.labor")
	state.labor = 2
	state.wood = 0
	assert_eq(_brace(state), "err.wood")
	state.wood = 1
	assert_eq(CommandRules.check(state, Command.new("brace_house", Vector2i.ZERO, 0)), "err.param")
	state.phase = C.Phase.HARVEST
	assert_eq(_brace(state), "err.phase")
	assert_eq(state.tiles[0].brace_turns, 0)
	assert_eq(state.labor, 2)
	assert_eq(state.wood, 1)


func test_brace_damage_thresholds_and_prevention_receipts() -> void:
	var cases: Array[Dictionary] = [
		{"building": C.Building.HOUSE, "depth": 0.0, "level": 0, "survives": true, "held": false},
		{"building": C.Building.HOUSE, "depth": 0.1, "level": 1, "survives": true, "held": true},
		{"building": C.Building.HOUSE, "depth": 0.5, "level": 2, "survives": false, "held": false},
		{"building": C.Building.STILT_HOUSE, "depth": 0.3, "level": 1, "survives": true, "held": false},
		{"building": C.Building.STILT_HOUSE, "depth": 0.5, "level": 2, "survives": true, "held": true},
		{"building": C.Building.STILT_HOUSE, "depth": 1.0, "level": 3, "survives": false, "held": false},
	]
	for entry: Dictionary in cases:
		var state: GameState = _house(entry.building, entry.depth)
		assert_eq(_brace(state), "")
		var report: TurnReport = TurnResolver.resolve_turn(state)
		assert_eq(state.tiles[0].building, entry.building if entry.survives else C.Building.NONE)
		assert_eq(state.tiles[0].brace_turns, 0)
		assert_eq(report.destroyed.size(), 0 if entry.survives else 1)
		assert_eq(state.stats["houses_lost"], 0 if entry.survives else 1)
		assert_eq(report.brace_results.size(), 1)
		var result: Dictionary = report.brace_results[0]
		assert_eq(result["coord"], Vector2i.ZERO)
		assert_eq(result["level"], entry.level)
		assert_eq(result["prevented_loss"], entry.held)
		assert_true(result["expired"])
		assert_eq(result["protected_threshold"], result["base_threshold"] + 1)


func test_brace_uses_current_rounded_modifier_threshold() -> void:
	var state: GameState = _house(C.Building.HOUSE, 0.5)
	state.mods["house_destroy_level"] = 1.6
	assert_eq(_brace(state), "")
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(report.brace_results[0]["base_threshold"], 2)
	assert_eq(report.brace_results[0]["protected_threshold"], 3)
	assert_eq(state.tiles[0].building, C.Building.HOUSE)


func test_brace_expires_when_unused_and_can_be_bought_next_turn() -> void:
	var state: GameState = _house(C.Building.HOUSE, 0.0, false)
	assert_eq(_brace(state), "")
	var report: TurnReport = GameFlow.end_turn(state)
	assert_true(not report.brace_results[0]["prevented_loss"])
	assert_eq(state.tiles[0].brace_turns, 0)
	assert_eq(state.turn, 2)
	assert_eq(_brace(state), "")
	assert_eq(state.wood, 8)


func test_surviving_house_is_vulnerable_again_after_one_turn() -> void:
	var state: GameState = _house(C.Building.HOUSE, 0.3)
	assert_eq(_brace(state), "")
	TurnResolver.resolve_turn(state)
	assert_eq(state.tiles[0].building, C.Building.HOUSE)
	var next: TurnReport = TurnResolver.resolve_turn(state)
	assert_eq(state.tiles[0].building, C.Building.NONE)
	assert_true(next.brace_results.is_empty())


func test_hall_loss_does_not_skip_brace_expiry_or_damage_receipt() -> void:
	var state: GameState = TestMaps.small(1, 0)
	state.ruleset = "bracing_v1"
	state.turn = 4
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	for tile: Tile in state.tiles:
		tile.water = 0.6
	state.tiles[0].building = C.Building.HALL
	state.tiles[1].building = C.Building.STILT_HOUSE
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", state.tiles[1].coord)), "")
	var report: TurnReport = GameFlow.end_turn(state)
	assert_eq(state.outcome, C.Outcome.LOSE_HALL)
	assert_eq(state.phase, C.Phase.GAME_OVER)
	assert_eq(state.tiles[1].brace_turns, 0)
	assert_eq(state.tiles[1].building, C.Building.STILT_HOUSE)
	assert_true(report.brace_results[0]["prevented_loss"])


func test_preview_and_visual_recording_are_read_only_and_match_resolution() -> void:
	var state: GameState = _house(C.Building.HOUSE, 0.3)
	assert_eq(_brace(state), "")
	var before: Dictionary = state.to_dict()
	var prediction: Dictionary = GameFlow.preview(state)
	assert_eq(state.to_dict(), before)
	assert_eq(state.tiles[0].brace_turns, 1)
	var without_visuals: GameState = state.duplicate_state()
	var quiet_report: TurnReport = TurnResolver.resolve_turn(without_visuals, false)
	var actual: TurnReport = TurnResolver.resolve_turn(state, true)
	assert_eq(state.to_dict(), prediction["state"].to_dict())
	assert_eq(state.to_dict(), without_visuals.to_dict())
	assert_eq(actual.brace_results, prediction["report"].brace_results)
	assert_eq(actual.brace_results, quiet_report.brace_results)
	assert_eq(actual.to_dict()["brace_results"][0]["coord"], [0, 0])


func test_undo_redo_and_demolition_restore_brace_and_resource_snapshots() -> void:
	var state: GameState = _house()
	var before: Dictionary = state.to_dict()
	assert_eq(_brace(state), "")
	var braced: Dictionary = state.to_dict()
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), before)
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), braced)
	assert_eq(GameFlow.apply_command(state, Command.new("demolish", Vector2i.ZERO)), "")
	assert_eq(state.tiles[0].brace_turns, 0)
	assert_eq(state.wood, 10, "only half the 2-wood house price is refunded; brace wood is spent")
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), braced)
	state = GameFlow.redo(state)
	assert_eq(state.tiles[0].brace_turns, 0)
	assert_eq(GameFlow.apply_command(state, Command.new("house", Vector2i.ZERO)), "")
	assert_eq(state.tiles[0].brace_turns, 0, "replacement house never inherits old braces")


func test_target_discovery_and_session_history_preserve_rules_and_receipts() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var session: GameSession = GameSession.new()
	session.save_path = "user://tests/bracing_history.json"
	session.state = GameFlow.new_game({"seed": 42, "ruleset": "bracing_v1"})
	var before: Dictionary = session.state.to_dict()
	var targets: Array[Vector2i] = CommandRules.valid_targets(session.state, "brace_house")
	assert_eq(targets.size(), 3)
	assert_eq(session.state.to_dict(), before)
	assert_eq(session.apply(Command.new("brace_house", targets[0])), "")
	session.advance_turn()
	var history: Array[Dictionary] = session.turn_history()
	assert_eq(history[0]["report"]["brace_results"].size(), 1)
	history[0]["report"]["brace_results"].clear()
	assert_eq(session.turn_history()[0]["report"]["brace_results"].size(), 1)
	SaveIO.delete_save(session.save_path)
